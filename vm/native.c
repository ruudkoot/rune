/* A program runeopt made (docs/plans/codegen.md): its main, and what its
   code calls. The code is the bytecode translated an instruction at a time,
   with the value stack, the frames and the handlers kept where the
   interpreter keeps them, so the collector, a trace, Runtime.stats and an
   image see the same machine they see under runevm. Each helper below is the
   case of vm/interp.c that it is named after, taken out of the loop: a change
   to the one is a change to the other.

   What runeopt writes into the program, beside its code: the .rbc, which is
   loaded as runevm loads it; for each function where its code begins and the
   highest its stack goes above its locals; where the code of each handler
   begins, in order of pc; and the runtime options it was made with. An
   address in a table is an offset from the start of the table, which keeps
   the program position independent. */
#include "vm.h"
#include "sys.h"

#include <errno.h>

extern const unsigned char rune_rbc[];
extern const uint32_t rune_rbc_size;
extern const int32_t rune_functions[];     /* 2 per function: entry - rune_functions, highest stack */
extern const int32_t rune_handlers[];      /* 2 per handler, by pc: pc, code - rune_handlers */
extern const uint32_t rune_nhandlers;
extern const char rune_options[];
void rune_enter(VM *vm, const void *code); /* in the generated code: never returns */

static const void *entry(uint32_t f) {
    return (const char *)rune_functions + rune_functions[2 * f];
}

/* A frame of function f begins at vm->sp with its argument: its locals, the
   rest of them unit, and room for the highest its stack goes, which the code
   then need not check at every push. What CALL does in vm/interp.c after
   the frame is pushed. */
static const void *enter(VM *vm, uint32_t f, Value arg) {
    Function *fn = &vm->prog.funcs[f];
    size_t need = vm->sp + fn->nlocals + (size_t)rune_functions[2 * f + 1];
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
    Value *slot = &vm->stack[vm->sp];
    slot[0] = arg;
    for (uint32_t i = 1; i < fn->nlocals; i++) slot[i] = mk_unit();
    vm->sp += fn->nlocals;
    vm->pc = fn->code_offset;
    return entry(f);
}

static Obj *expect_obj(VM *vm, Value v, int kind, const char *what) {
    if (v.tag != T_PTR || v.u.p->kind != kind) vm_fatal(vm, "expected %s", what);
    return v.u.p;
}

static uint32_t callee(VM *vm, Obj *c) {
    int64_t fidx = OBJ_FIELDS(c)[0].u.i;
    if (fidx < 0 || (uint64_t)fidx >= vm->prog.nfuncs) vm_fatal(vm, "bad function index");
    return (uint32_t)fidx;
}

/* CALL, with vm->pc already the instruction after it, which is where the
   frame returns to: `back` is the native code there. */
const void *native_call(VM *vm, void *back) {
    Value arg = vm_pop(vm);
    Value cv = vm_pop(vm);
    Obj *c = expect_obj(vm, cv, K_CLOSURE, "closure in call");
    uint32_t f = callee(vm, c);
    vm_push_frame(vm, f, c, vm->pc, vm->sp);
    vm->frames[vm->fp].native_ret = back;
    return enter(vm, f, arg);
}

const void *native_tailcall(VM *vm) {
    Value arg = vm_pop(vm);
    Value cv = vm_pop(vm);
    Obj *c = expect_obj(vm, cv, K_CLOSURE, "closure in call");
    uint32_t f = callee(vm, c);
    Frame *fr = &vm->frames[vm->fp];
    vm->sp = fr->base;
    fr->func = f;
    fr->closure = c;
    return enter(vm, f, arg);
}

/* RET: the native code of the caller, or the end of the run. */
const void *native_ret(VM *vm) {
    Frame *fr = &vm->frames[vm->fp];
    Value v = vm_pop(vm);
    vm->sp = fr->base;
    vm->pc = fr->ret_pc;
    if (vm->fp == 0) { vm_push(vm, v); vm_exit(vm, 0); }
    const void *back = fr->native_ret;
    vm->fp--;
    vm_push(vm, v);
    return back;
}

void native_halt(VM *vm) {
    vm_exit(vm, 0);
}

/* The native code of the handler vm_raise has made vm->pc: the table is in
   order of pc, and every handler of the program is in it. */
const void *native_handler(VM *vm) {
    uint32_t lo = 0, hi = rune_nhandlers;
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2;
        uint32_t pc = (uint32_t)rune_handlers[2 * mid];
        if (pc == vm->pc) return (const char *)rune_handlers + rune_handlers[2 * mid + 1];
        if (pc < vm->pc) lo = mid + 1; else hi = mid;
    }
    vm_fatal(vm, "no native code for the handler at %u", vm->pc);
    return NULL;
}

const void *native_raise(VM *vm) {
    Value v = vm_pop(vm);
    if (v.tag != T_PTR || v.u.p->kind != K_EXN) vm_fatal(vm, "RAISE of non-exception");
    vm_raise(vm, v);
    return native_handler(vm);
}

/* A primitive that did not return a value: 1, it raised; 2, it replaced the
   program, which Runtime.restore does not do in a native program yet (M9 of
   the plan: it raises OS.SysErr instead, see p_rt_restore). */
const void *native_unusual(VM *vm, int r) {
    if (r == 1) return native_handler(vm);
    vm_fatal(vm, "a primitive replaced the program");
    return NULL;
}

void native_tuple(VM *vm, int32_t a) {
    Obj *t = vm_alloc_fields(vm, K_TUPLE, 0, (uint32_t)a);
    Value *f = OBJ_FIELDS(t);
    for (int32_t i = 0; i < a; i++) f[i] = vm->stack[vm->sp - (size_t)a + (size_t)i];
    vm->sp -= (size_t)a;
    vm_push(vm, mk_ptr(t));
}

void native_con(VM *vm, int32_t a) {
    Obj *c = vm_alloc_fields(vm, K_CON, (uint16_t)a, 1);
    OBJ_FIELDS(c)[0] = *vm_top(vm, 0);
    *vm_top(vm, 0) = mk_ptr(c);
}

void native_closure(VM *vm, int32_t a, int32_t b) {
    Obj *c = vm_alloc_fields(vm, K_CLOSURE, 0, (uint32_t)b + 1);
    Value *f = OBJ_FIELDS(c);
    f[0] = mk_int(a);
    for (int32_t i = 0; i < b; i++) f[i + 1] = vm->stack[vm->sp - (size_t)b + (size_t)i];
    vm->sp -= (size_t)b;
    vm_push(vm, mk_ptr(c));
}

void native_setenv(VM *vm, int32_t a) {
    Value v = vm_pop(vm);
    Value cv = vm_pop(vm);
    Obj *c = expect_obj(vm, cv, K_CLOSURE, "closure");
    if ((uint32_t)a + 1 >= c->len) vm_fatal(vm, "environment slot %d out of range", a);
    OBJ_FIELDS(c)[a + 1] = v;
}

void native_newexn(VM *vm, int32_t a) {
    Obj *c = vm_alloc_fields(vm, K_EXNCON, 0, 1);
    OBJ_FIELDS(c)[0] = vm->prog.consts[a];
    vm_push(vm, mk_ptr(c));
}

void native_mkexn(VM *vm) {
    Obj *e = vm_alloc_fields(vm, K_EXN, 0, 2);
    Value con = vm->stack[vm->sp - 2];
    if (con.tag != T_PTR || con.u.p->kind != K_EXNCON) vm_fatal(vm, "MKEXN on non-constructor");
    OBJ_FIELDS(e)[0] = con;
    OBJ_FIELDS(e)[1] = vm->stack[vm->sp - 1];
    vm->sp -= 2;
    vm_push(vm, mk_ptr(e));
}

/* The checks the code makes itself end here, with vm->pc already the
   instruction after the one that failed, as the interpreter has it; `what`
   is the number the code gives the message. */
void native_fatal(VM *vm, int what, int32_t a) {
    switch (what) {
    case 0: vm_fatal(vm, "expected %s", "tuple"); break;
    case 1: vm_fatal(vm, "expected %s", "constructor with argument"); break;
    case 2: vm_fatal(vm, "expected %s", "exception"); break;
    case 3: vm_fatal(vm, "environment slot %d out of range", a); break;
    case 4: vm_fatal(vm, "SELF outside a closure"); break;
    case 5: vm_fatal(vm, "global %d read before initialization", a); break;
    case 6: vm_fatal(vm, "tuple index %d out of range", a); break;
    case 7: vm_fatal(vm, "CONTAG on non-constructor"); break;
    case 8: vm_fatal(vm, "JUMPIFNOT on non-bool"); break;
    case 9: vm_fatal(vm, "JUMPIF on non-bool"); break;
    case 10: vm_fatal(vm, "POPHANDLER with no handler"); break;
    default: vm_fatal(vm, "unknown check %d", what);
    }
}

/* ---------------------------------------------------------------- main */

typedef struct Options {
    size_t heap, gc_stress;
    int stats, count, emulate_fork;
} Options;

/* A size in bytes or a count, as runevm takes it (vm/main.c). */
static int size_arg(const char *text, size_t *out) {
    char *end;
    errno = 0;
    unsigned long long v = strtoull(text, &end, 10);
    if (errno != 0 || end == text || *end != 0 || text[0] == '-' || v > SIZE_MAX) return 0;
    *out = (size_t)v;
    return 1;
}

/* The options of runevm that a native program takes, written as runevm takes
   them, from `where`: those runeopt was given, then RUNEVM_OPTIONS. */
static void options(const char *text, const char *where, Options *o) {
    char *copy = malloc(strlen(text) + 1);
    if (!copy) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
    strcpy(copy, text);
    char *words[64];
    int n = 0;
    for (char *t = strtok(copy, " \t\n"); t && n < 64; t = strtok(NULL, " \t\n")) words[n++] = t;
    for (int i = 0; i < n; i++) {
        const char *w = words[i];
        if (strcmp(w, "--count") == 0) o->count = 1;
        else if (strcmp(w, "--stats") == 0) o->stats = 1;
        else if (strcmp(w, "--emulate-fork") == 0) o->emulate_fork = 1;
        else if (strcmp(w, "--heap-size") == 0 && i + 1 < n && size_arg(words[i + 1], &o->heap)) {
            if (o->heap < 4096) o->heap = 4096;
            i++;
        } else if (strcmp(w, "--gc-stress") == 0 && i + 1 < n && size_arg(words[i + 1], &o->gc_stress) && o->gc_stress > 0)
            i++;
        else {
            fprintf(stderr, "runevm: %s: %s is not an option of a native program "
                    "(--count, --stats, --heap-size N, --gc-stress N, --emulate-fork)\n", where, w);
            exit(2);
        }
    }
    free(copy);
}

int main(int argc, char **argv) {
    Options o = { 4u << 20, 0, 0, 0, 0 };
    options(rune_options, "runeopt --options", &o);
    const char *env = getenv("RUNEVM_OPTIONS");
    if (env) options(env, "RUNEVM_OPTIONS", &o);

    VM *vm = calloc(1, sizeof(VM));
    if (!vm) { fprintf(stderr, "runevm: out of memory\n"); return 2; }
    vm->native = 1;
    vm->stats = o.stats;
    vm->count = o.count;
    vm->gc_stress = o.gc_stress;
    vm->emulate_fork = o.emulate_fork;
    vm->progname = argv[0];
    vm->argc = argc - 1;
    vm->argv = argv + 1;
    vm_init(vm, o.heap);

    char err[256];
    if (!load_program_mem(vm, rune_rbc, rune_rbc_size, err, sizeof err)) {
        fprintf(stderr, "runevm: %s: %s\n", argv[0], err);
        vm_destroy(vm);
        return 2;
    }
    vm_start(vm);
    size_t need = vm->sp + (size_t)rune_functions[1];
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
    rune_enter(vm, entry(0));
    return 0;
}
