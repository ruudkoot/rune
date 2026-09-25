/* The JIT of vm/new (docs/plans/jit.md): its code objects and the driver's
   protocol (jit.h), and, in M3, no compiler yet -- every entry --jit=all
   makes is a stub that hands the frame back to the interpreter, so that the
   protocol is run by every call of every suite before a line of machine
   code exists. The compiler comes in M4. */
#include "jit.h"
#include "sys.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static JitProgram *the_program;   /* one VM per process, for --jit-stats */
static VM *the_vm;

/* The stub: an "entry" that is no code. The driver knows it by address and
   answers RUN_INTERP for it, counting the hand-back. */
static const int stub_entry = 0;
const void *const jit_stub = &stub_entry;

static void jit_make(VM *vm, JitProgram *jit) {
    Program *p = &vm->prog;
    free(jit->codes);
    jit->codes = calloc(p->nfuncs ? p->nfuncs : 1, sizeof(CodeObject));
    if (!jit->codes) { fprintf(stderr, "runevm: out of memory (code objects)\n"); exit(2); }
    jit->code = p->code;
    jit->nfuncs = p->nfuncs;
    jit->compiled = 0;
    if (vm->jit_mode == JIT_ALL) {
        for (uint32_t i = 0; i < p->nfuncs; i++) {
            jit->codes[i].tier = 1;
            jit->codes[i].entry = jit_stub;   /* published last */
            jit->compiled++;
        }
    }
}

JitProgram *jit_program(VM *vm) {
    if (vm->jit_mode == JIT_OFF) return NULL;
    if (!the_program) {
        the_program = calloc(1, sizeof(JitProgram));
        if (!the_program) { fprintf(stderr, "runevm: out of memory (JIT)\n"); exit(2); }
        the_vm = vm;
        if (vm->jit_stats) atexit(jit_print_stats);
    }
    if (the_program->code != vm->prog.code || the_program->nfuncs != vm->prog.nfuncs) jit_make(vm, the_program);
    return the_program;
}

int jit_run(VM *vm, JitProgram *jit, const void *at) {
    (void)vm;
    if (at == jit_stub) {
        jit->handed_interp++;
        return RUN_INTERP;
    }
    fprintf(stderr, "runevm: no code to run at %p\n", at);
    exit(2);
}

void jit_print_stats(void) {
    JitProgram *jit = the_program;
    if (!jit) return;
    fprintf(stderr, "runevm: jit: %llu of %u functions with an entry; handed to native code %llu times, back %llu\n",
            (unsigned long long)jit->compiled, jit->nfuncs,
            (unsigned long long)jit->handed_native, (unsigned long long)jit->handed_interp);
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
