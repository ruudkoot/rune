/* The JIT of vm/new (docs/plans/jit.md): its code objects and the driver's
   protocol (jit.h); the compiler is vm/new/jit (compile.c), tier 1 from
   M4. Under --jit=all every function tier 1 can compile is compiled when
   the program is first seen; the rest stay interpreted. */
#include "jit.h"
#include "sys.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* the mode, and the thresholds of --jit=baseline, where no option gives
   them (M6, the sweep) */
#define JIT_DEFAULT_MODE JIT_BASELINE
#define DEFAULT_CALLS 100
#define DEFAULT_WORK 100

static void free_tables(JitProgram *jit) {
    for (uint32_t i = 0; jit->codes && i < jit->nfuncs; i++) {
        free(jit->codes[i].osr_pcs); free(jit->codes[i].osr_offs); free(jit->codes[i].callers);
    }
}

void jit_depend(JitProgram *jit, uint32_t callee, uint32_t caller) {
    CodeObject *co = &jit->codes[callee];
    for (uint32_t i = 0; i < co->ncallers; i++) if (co->callers[i] == caller) return;
    if (co->ncallers == co->callers_cap) {
        uint32_t cap = co->callers_cap ? co->callers_cap * 2 : 4;
        uint32_t *c = realloc(co->callers, cap * sizeof *c);
        if (!c) return;   /* not recorded: the caller keeps jumping into dead code, which is the same code */
        co->callers = c;
        co->callers_cap = cap;
    }
    co->callers[co->ncallers++] = caller;
}

static JitProgram *the_program;   /* one VM per process, for --jit-stats */
static VM *the_vm;

static void jit_make(VM *vm, JitProgram *jit) {
    Program *p = &vm->prog;
    free_tables(jit);
    free(jit->codes);
    jit->codes = calloc(p->nfuncs ? p->nfuncs : 1, sizeof(CodeObject));
    free(jit->fill_from);
    jit->fill_from = malloc((p->nfuncs ? p->nfuncs : 1) * sizeof *jit->fill_from);
    if (jit->fill_from) for (uint32_t i = 0; i < p->nfuncs; i++) jit->fill_from[i] = UINT32_MAX;
    if (!jit->codes) { fprintf(stderr, "runevm: out of memory (code objects)\n"); exit(2); }
    jit->code = p->code;
    jit->nfuncs = p->nfuncs;
    jit->compiled = 0;
    /* the code of the program before is left where it is: a frame of an
       image never returns into it, since native_ret is not carried */
    jit->code_used = jit->code_mem ? jit->code_used : 0;
    /* what each function's calls must fill: worked out for all now, since
       a call through a closure reads it from the table at run time */
    if (jit->fill_from) for (uint32_t i = 0; i < p->nfuncs; i++) jit_fill_from(vm, jit, i);
    jit->calls_threshold = vm->jit.calls ? vm->jit.calls : DEFAULT_CALLS;
    jit->work_threshold = vm->jit.work ? vm->jit.work : DEFAULT_WORK;
    jit->stress = vm->jit.stress;
    if (vm->jit.mode == JIT_ALL) {
        /* --jit-only=LO-HI compiles functions LO to HI alone: for finding,
           by halving, a function whose code is wrong; =odd or =even
           compiles every other function, so that calls, returns and raises
           cross between the tiers both ways (scripts/check-jit.sh). An
           option, not a variable of the environment, which a program can
           read: --count must not see the difference. */
        uint32_t lo = 0, hi = p->nfuncs, step = 1;
        const char *only = vm->jit.only;
        if (only) {
            unsigned long a = 0, b = 0;
            if (sscanf(only, "%lu-%lu", &a, &b) == 2 && a <= b) { lo = (uint32_t)a; hi = b < p->nfuncs ? (uint32_t)b + 1 : p->nfuncs; }
            else if (strcmp(only, "odd") == 0) { lo = 1; step = 2; }
            else if (strcmp(only, "even") == 0) { step = 2; }
        }
        for (uint32_t i = lo; i < hi; i += step) jit_tier_up(vm, jit, i);
    }
}

/* --jit-perf-map: a line per function compiled, in the form perf reads
   (tools/perf/Documentation/jit-interface.txt): start, size, name */
static void perf_map(VM *vm, JitProgram *jit, uint32_t f) {
    static FILE *map;
    if (!map) {
        char name[64];
        snprintf(name, sizeof name, "/tmp/perf-%lld.map", (long long)sys_getpid());
        map = fopen(name, "w");
        if (!map) return;
    }
    fprintf(map, "%llx %x jit:%s\n", (unsigned long long)(uintptr_t)jit->codes[f].entry, (unsigned)jit->codes[f].size, vm->prog.funcs[f].name);
    fflush(map);
}

void jit_tier_up(VM *vm, JitProgram *jit, uint32_t f) {
    if (jit->full || jit->codes[f].entry) return;
    clock_t t0 = clock();
    if (!jit_compile(vm, jit, f) && jit->code_used + (1u << 20) > jit->code_cap) jit->full = 1;
    else if (vm->jit.perf_map && jit->codes[f].entry) perf_map(vm, jit, f);
    jit->compile_seconds += (double)(clock() - t0) / CLOCKS_PER_SEC;
}

const void *jit_osr(const CodeObject *co, uint32_t pc) {
    uint32_t lo = 0, hi = co->nosr;
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2;
        if (co->osr_pcs[mid] < pc) lo = mid + 1;
        else if (co->osr_pcs[mid] > pc) hi = mid;
        else return (const char *)co->entry + co->osr_offs[mid];
    }
    return NULL;
}

void jit_invalidate(VM *vm, JitProgram *jit, uint32_t f) {
    CodeObject *co = &jit->codes[f];
    if (!co->entry) return;
    uintptr_t lo = (uintptr_t)co->entry, hi = lo + co->size;
    for (size_t i = 0; i <= vm->fp; i++) {
        uintptr_t r = (uintptr_t)vm->frames[i].native_ret;
        if (r >= lo && r < hi) vm->frames[i].native_ret = NULL;
    }
    for (size_t i = 0; i < vm->hp; i++) {
        uintptr_t r = (uintptr_t)vm->handlers[i].native;
        if (r >= lo && r < hi) vm->handlers[i].native = NULL;
    }
    co->entry = NULL;
    co->tier = 0;
    co->calls = co->work = 0;
    free(co->osr_pcs); free(co->osr_offs);
    co->osr_pcs = co->osr_offs = NULL;
    co->nosr = 0;
    jit->dead_bytes += co->size;
    co->size = 0;
    jit->invalidated++;
    /* the functions whose code jumps straight into this one's go with it */
    uint32_t n = co->ncallers;
    uint32_t *callers = co->callers;
    co->ncallers = co->callers_cap = 0;
    co->callers = NULL;
    for (uint32_t i = 0; i < n; i++) jit_invalidate(vm, jit, callers[i]);
    free(callers);
}

JitProgram *jit_program(VM *vm) {
    if (vm->jit.mode == JIT_DEFAULT) vm->jit.mode = JIT_DEFAULT_MODE;
    if (vm->jit.mode == JIT_OFF) return NULL;
    if (!the_program) {
        the_program = calloc(1, sizeof(JitProgram));
        if (!the_program) { fprintf(stderr, "runevm: out of memory (JIT)\n"); exit(2); }
        if (vm->jit.stats) the_program->prim_calls = calloc(PRIM__COUNT, sizeof(uint64_t));
        the_vm = vm;
        if (vm->jit.stats) atexit(jit_print_stats);
    }
    if (the_program->code != vm->prog.code || the_program->nfuncs != vm->prog.nfuncs) jit_make(vm, the_program);
    return the_program;
}

int jit_run(VM *vm, JitProgram *jit, const void *at) {
    int (*enter)(VM *, const void *);
    memcpy(&enter, &jit->enter_at, sizeof enter);
    int r = enter(vm, at);
    if (r == RUN_INTERP) jit->handed_interp++;
    return r;
}

void jit_print_stats(void) {
    JitProgram *jit = the_program;
    if (!jit) return;
    fprintf(stderr, "runevm: jit: %llu of %u functions compiled in %.3f s, %llu bytes of code (%llu dead); handed to native code %llu times, back %llu; entered mid-way %llu times; %llu invalidated\n",
            (unsigned long long)jit->compiled, jit->nfuncs, jit->compile_seconds, (unsigned long long)jit->code_used,
            (unsigned long long)jit->dead_bytes, (unsigned long long)jit->handed_native, (unsigned long long)jit->handed_interp,
            (unsigned long long)jit->osr_entries, (unsigned long long)jit->invalidated);
    /* the primitives called from code, most called first: what is not in
       line yet, or in line and out of its fast case */
    if (jit->prim_calls) {
        uint64_t total = 0;
        for (int p = 0; p < PRIM__COUNT; p++) total += jit->prim_calls[p];
        if (total) {
            fprintf(stderr, "runevm: jit: %llu primitives called from code:", (unsigned long long)total);
            for (int k = 0; k < 8; k++) {
                int best = -1;
                for (int p = 0; p < PRIM__COUNT; p++) if (jit->prim_calls[p] && (best < 0 || jit->prim_calls[p] > jit->prim_calls[best])) best = p;
                if (best < 0) break;
                fprintf(stderr, " %s %llu", prim_names[best], (unsigned long long)jit->prim_calls[best]);
                jit->prim_calls[best] = 0;
            }
            fprintf(stderr, "\n");
        }
    }
}

/* A function of no arguments that returns 42, as this machine's code, or
   nothing where no machine is known here: the executable memory of the
   system layer, written, made executable and run. */
int jit_check(void) {
#if defined(__x86_64__) || defined(_M_X64)
    static const unsigned char code[] = { 0xb8, 42, 0, 0, 0, 0xc3 };       /* mov eax, 42; ret */
#elif defined(__aarch64__)
    static const unsigned char code[] = { 0x40, 0x05, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 };   /* mov w0, #42; ret */
#else
    static const unsigned char code[] = { 0 };
    printf("jit-check: no code for this machine\n");
    return 0;
#endif
    size_t size = 4096;
    unsigned char *mem = sys_code_alloc(size);
    if (!mem) { printf("jit-check: cannot allocate executable memory: %s\n", sys_error_msg(sys_errno())); return 1; }
    for (size_t i = 0; i < sizeof code; i++) mem[i] = code[i];
    if (!sys_code_protect(mem, size, 1)) { printf("jit-check: cannot make the memory executable: %s\n", sys_error_msg(sys_errno())); return 1; }
    sys_code_flush(mem, size);
    /* an object pointer is not a function pointer in ISO C: the bytes of
       one become the other through memcpy */
    int (*f)(void);
    void *at = mem;
    memcpy(&f, &at, sizeof f);
    int got = f();
    sys_code_free(mem, size);
    if (got != 42) { printf("jit-check: the code answered %d, not 42\n", got); return 1; }
    printf("jit-check: ok\n");
    return 0;
}
