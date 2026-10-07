/* A program runeopt made (docs/native.md): its main, and what its
   code calls. The code is the bytecode translated an instruction at a time,
   with the value stack, the frames and the handlers kept where the
   interpreter keeps them, so the collector, a trace, Runtime.stats and an
   image see the same machine they see under runevm-stack. Each helper below is the
   case of the interpreter's loop that it is named after, taken out of the
   loop: those of the instructions whose bodies are shared (src/isa/isa.sml)
   call the same function the interpreter does (runtime/stack/ops.h); CALL, TAILCALL,
   CALLK, RET and RAISE, which say where the code goes on, are written again
   here, and a change to the one is a change to the other.

   What runeopt writes into the program, beside its code: the .rbc, which is
   loaded as runevm-stack loads it; for each function where its code begins and the
   highest its stack goes above its locals; where the code of each handler
   begins, in order of pc; and the runtime options it was made with. An
   address in a table is an offset from the start of the table, which keeps
   the program position independent. */
#define _POSIX_C_SOURCE 200809L     /* unsetenv, strdup */
#include "vm.h"
#include "sys/sys.h"
#include "stack/ops.h"

#include <errno.h>
#include <fenv.h>

extern const unsigned char rune_rbc[];
extern const uint32_t rune_rbc_size;
extern const int32_t rune_functions[];     /* 3 per function: the glue's entry, which takes the frame's
                                              base first - rune_functions, the entry of a call
                                              of the code (M10) - rune_functions, highest stack */
extern const int32_t rune_handlers[];      /* 2 per handler, by pc: pc, code - rune_handlers */
extern const uint32_t rune_nhandlers;
extern const char rune_options[];
extern const int32_t rune_resume[];        /* 2 per place, by pc: pc, code - rune_resume */
extern const uint32_t rune_nresume;
void rune_enter(VM *vm, const void *code); /* in the generated code: never returns */

static const void *entry(uint32_t f) {
    return (const char *)rune_functions + rune_functions[3 * f];
}

/* A frame of function f begins at vm->sp with its argument: its locals, the
   rest of them unit, and room for the highest its stack goes, which the code
   then need not check at every push. What CALL does in runtime/stack/interp.c after
   the frame is pushed. */
static const void *enter(VM *vm, uint32_t f, Value arg) {
    Function *fn = &vm->prog.funcs[f];
    size_t need = vm->sp + fn->nlocals + (size_t)rune_functions[3 * f + 2];
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
    Value *slot = &vm->stack[vm->sp];
    slot[0] = arg;
    for (uint32_t i = 1; i < fn->nlocals; i++) slot[i] = mk_unit();
    vm->sp += fn->nlocals;
    vm->pc = fn->code_offset;
    return entry(f);
}

static uint32_t callee(VM *vm, Obj *c) {
    int64_t fidx = val_imm(obj_field(c, 0));
    if (fidx < 0 || (uint64_t)fidx >= vm->prog.nfuncs) vm_fatal(vm, "bad function index");
    return (uint32_t)fidx;
}

/* CALL, with vm->pc already the instruction after it, which is where the
   frame returns to: `back` is the native code there. */
const void *native_call(VM *vm, void *back) {
    Value arg = vm_pop(vm);
    Value cv = vm_pop(vm);
    Obj *c = vm_expect_obj(vm, cv, K_CLOSURE, "closure in call");
    uint32_t f = callee(vm, c);
    vm_push_frame(vm, f, c, vm->pc, vm->sp);
    vm->frames[vm->fp].native_ret = back;
    return enter(vm, f, arg);
}

const void *native_tailcall(VM *vm) {
    Value arg = vm_pop(vm);
    Value cv = vm_pop(vm);
    Obj *c = vm_expect_obj(vm, cv, K_CLOSURE, "closure in call");
    uint32_t f = callee(vm, c);
    Frame *fr = &vm->frames[vm->fp];
    vm->sp = fr->base;
    fr->func = f;
    fr->closure = c;
    return enter(vm, f, arg);
}

/* CALLK (middle-end M8) when the array of frames is full: a frame of
   function f at the n arguments on top of the stack, which are its first
   locals, with no closure, the rest of its locals unit. */
const void *native_callk(VM *vm, uint32_t f, uint32_t n, void *back) {
    size_t at = vm->sp - n;
    vm_push_frame(vm, f, NULL, vm->pc, at);
    vm->frames[vm->fp].native_ret = back;
    Function *fn = &vm->prog.funcs[f];
    size_t need = at + fn->nlocals + (size_t)rune_functions[3 * f + 2];
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
    Value *slot = &vm->stack[at];
    for (uint32_t i = n; i < fn->nlocals; i++) slot[i] = mk_unit();
    vm->sp = at + fn->nlocals;
    vm->pc = fn->code_offset;
    return entry(f);
}

/* RET: the native code of the caller, or the end of the run. */
const void *native_ret(VM *vm) {
    Frame *fr = &vm->frames[vm->fp];
    Value v = vm_pop(vm);
    vm->sp = fr->base;
    vm->pc = fr->ret_pc;
    if (vm->fp == 0) { vm_push(vm, v); vm_exit(vm, 0); }
    const void *back = fr->native_ret;
    vm_frame_pop(vm);
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
    if (!val_is(v, T_PTR) || obj_kind(val_ptr(v)) != K_EXN) vm_fatal(vm, "RAISE of non-exception");
    vm_raise(vm, v);
    return native_handler(vm);
}

/* ---------------------------------------------------------------- images */

/* An entry of a table of the code, by pc: its native code, or NULL. */
static const void *lookup(const int32_t *table, uint32_t n, uint32_t pc) {
    uint32_t lo = 0, hi = n;
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2;
        uint32_t at = (uint32_t)table[2 * mid];
        if (at == pc) return (const char *)table + table[2 * mid + 1];
        if (at < pc) lo = mid + 1; else hi = mid;
    }
    return NULL;
}

/* Whether a world read from an image runs the program this one carries: the
   same code, functions, globals and constants. Nothing else can be carried
   on, since the native code is the translation of that program alone
   (docs/native.md, Images). */
static int same_program(const VM *world) {
    VM *mine = calloc(1, sizeof(VM));
    if (!mine) return 0;
    vm_init(mine, 1u << 16);
    char err[256];
    /* The constants as a program starts with them: a real is read by
       strtod, which rounds as the mode is, and the image has put its own. */
    int mode = fegetround();
    fesetround(FE_TONEAREST);
    int same = load_program_mem(mine, rune_rbc, rune_rbc_size, err, sizeof err);
    fesetround(mode);
    const Program *a = &mine->prog, *b = &world->prog;
    same = same && a->nconsts == b->nconsts && a->nglobals == b->nglobals && a->nfuncs == b->nfuncs
        && a->code_len == b->code_len && memcmp(a->code, b->code, a->code_len) == 0;
    for (uint32_t i = 0; same && i < a->nfuncs; i++)
        same = a->funcs[i].code_offset == b->funcs[i].code_offset && a->funcs[i].code_end == b->funcs[i].code_end
            && a->funcs[i].nlocals == b->funcs[i].nlocals && strcmp(a->funcs[i].name, b->funcs[i].name) == 0;
    for (uint32_t i = 0; same && i < a->nconsts; i++) {
        Value x = a->consts[i], y = b->consts[i];
        if (a->const_kinds[i] != b->const_kinds[i] || val_tag(x) != val_tag(y)) same = 0;
        else if (val_is(x, T_PTR))
            same = obj_kind(val_ptr(x)) == K_STRING && obj_kind(val_ptr(y)) == K_STRING && obj_len(val_ptr(x)) == obj_len(val_ptr(y))
                && memcmp(obj_bytes(val_ptr(x)), obj_bytes(val_ptr(y)), obj_len(val_ptr(x))) == 0;
        /* a number by what it is, not by its word: a box is another address in each VM */
        else if (a->const_kinds[i] == CONST_REAL) same = real_bits(val_real(x)) == real_bits(val_real(y));
        else if (a->const_kinds[i] == CONST_INT64 || a->const_kinds[i] == CONST_WORD64) same = val_word64(x) == val_word64(y);
        else same = val_word(x) == val_word(y);
    }
    vm_destroy(mine);
    return same;
}

/* A world of this program, read from an image, made ready for its native
   code: every frame is given the native code it returns to, every handler
   and the place the world stopped at must be places of this code, and the
   stack has room for what every frame pushes. The native code to carry on
   at, or NULL and why. */
static const void *prepare_resume(VM *vm, char *err, size_t errlen) {
    if (!vm->frames_active) { snprintf(err, errlen, "the image has no frames"); return NULL; }
    size_t need = vm->sp;
    for (size_t i = 0; i <= vm->fp; i++) {
        Frame *fr = &vm->frames[i];
        if (i > 0) {
            fr->native_ret = lookup(rune_resume, rune_nresume, fr->ret_pc);
            if (!fr->native_ret) { snprintf(err, errlen, "a frame of the image returns where no call does"); return NULL; }
        }
        size_t top = fr->base + vm->prog.funcs[fr->func].nlocals + (size_t)rune_functions[3 * fr->func + 2];
        if (top > need) need = top;
    }
    for (size_t j = 0; j < vm->hp; j++)
        if (!lookup(rune_handlers, rune_nhandlers, vm->handlers[j].pc)) {
            snprintf(err, errlen, "a handler of the image is not one of the program"); return NULL;
        }
    const void *code = lookup(rune_resume, rune_nresume, vm->pc);
    if (!code) { snprintf(err, errlen, "the image stopped where the program does not save"); return NULL; }
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
    vm->native = 1;
    return code;
}

/* A primitive that did not return a value: 1, it raised; 2, Runtime.restore
   made this the world of an image, of this program (vm_become asks
   same_program), which carries on where it was saved. */
const void *native_unusual(VM *vm, int r) {
    if (r == 1) return native_handler(vm);
    char err[256];
    const void *code = prepare_resume(vm, err, sizeof err);
    if (!code) vm_fatal(vm, "Runtime.restore: %s", err);
    return code;
}

/* The instructions whose slow paths are their bodies in src/isa/stack.sml,
   as the interpreter runs them (runtime/stack/ops.h). */
void native_tuple(VM *vm, int32_t a) { op_TUPLE(vm, a, 0); }
void native_con(VM *vm, int32_t a) { op_CON(vm, a, 0); }
void native_conn(VM *vm, int32_t a, int32_t b) { op_CONN(vm, a, b); }
void native_closure(VM *vm, int32_t a, int32_t b) { op_CLOSURE(vm, a, b); }
void native_setenv(VM *vm, int32_t a) { op_SETENV(vm, a, 0); }
void native_newexn(VM *vm, int32_t a) { op_NEWEXN(vm, a, 0); }
void native_mkexn(VM *vm) { op_MKEXN(vm, 0, 0); }

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
    case 11: vm_fatal(vm, "JUMPIFNOTTAG on non-constructor"); break;
    case 12: vm_fatal(vm, "SWITCH on non-constructor"); break;
    case 13: vm_fatal(vm, "DECON of a constructor of tag %d where %d is wanted", a >> 16, a & 0xffff); break;
    case 14: vm_fatal(vm, "expected %s", "constructor with fields"); break;
    case 15: vm_fatal(vm, "constructor field %d out of range", a); break;
    case 16: vm_fatal(vm, "FIELD of a constructor of tag %d where %d is wanted", a >> 16, a & 0xffff); break;
    default: vm_fatal(vm, "unknown check %d", what);
    }
}

/* ---------------------------------------------------------------- main */

typedef struct Options {
    size_t heap, gc_stress, heap_fill, heap_limit, equality_work, nursery;
    int old_kind;
    int stats, count, emulate_fork, checked, gc_verify;
    char *restore, *gc_log;
} Options;

/* A size in bytes or a count, as runevm-stack takes it (runtime/main.c). */
static int size_arg(const char *text, size_t *out) {
    char *end;
    errno = 0;
    unsigned long long v = strtoull(text, &end, 10);
    if (errno != 0 || end == text || *end != 0 || text[0] < '0' || text[0] > '9' || v > SIZE_MAX) return 0;
    *out = (size_t)v;
    return 1;
}

/* The options of runevm-stack that a native program takes, written as runevm-stack takes
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
        else if (strcmp(w, "--checked") == 0) o->checked = 1;
        else if (strcmp(w, "--gc-verify") == 0) o->gc_verify = 1;
        else if (strcmp(w, "--heap-size") == 0 && i + 1 < n && size_arg(words[i + 1], &o->heap)) {
            if (o->heap < 4096) o->heap = 4096;
            i++;
        } else if (strcmp(w, "--heap-limit") == 0 && i + 1 < n && size_arg(words[i + 1], &o->heap_limit) && o->heap_limit >= 4096)
            i++;
        else if (strcmp(w, "--equality-work") == 0 && i + 1 < n && size_arg(words[i + 1], &o->equality_work) && o->equality_work > 0)
            i++;
        else if (strcmp(w, "--gc-stress") == 0 && i + 1 < n && size_arg(words[i + 1], &o->gc_stress) && o->gc_stress > 0)
            i++;
        else if (strcmp(w, "--nursery") == 0 && i + 1 < n && size_arg(words[i + 1], &o->nursery))
            i++;
        else if (strcmp(w, "--old-space") == 0 && i + 1 < n && (strcmp(words[i + 1], "copy") == 0 || strcmp(words[i + 1], "mark") == 0
                                                               || strcmp(words[i + 1], "segfit") == 0)) {
            i++;
            o->old_kind = strcmp(words[i], "mark") == 0 ? OLD_MARK : strcmp(words[i], "segfit") == 0 ? OLD_SEGFIT : OLD_COPY;
        }
        else if (strcmp(w, "--heap-fill") == 0 && i + 1 < n && size_arg(words[i + 1], &o->heap_fill)
                 && o->heap_fill >= 1 && o->heap_fill <= 100)
            i++;
        else if ((strcmp(w, "--restore") == 0 || strcmp(w, "--gc-log") == 0) && i + 1 < n) {
            char **to = strcmp(w, "--restore") == 0 ? &o->restore : &o->gc_log;
            free(*to);
            *to = malloc(strlen(words[i + 1]) + 1);
            if (!*to) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
            strcpy(*to, words[++i]);
        } else {
            fprintf(stderr, "runevm: %s: %s is not an option of a native program "
                    "(--count, --stats, --heap-size N, --heap-limit N, --equality-work N, --heap-fill P, --gc-stress N, --nursery N, --old-space S, --gc-verify, --checked, --emulate-fork, "
                    "--restore FILE, --gc-log FILE)\n", where, w);
            exit(2);
        }
    }
    free(copy);
}

/* The name from RUNEVM_NAME, kept for as long as the program runs. */
static char *program_name;

int main(int argc, char **argv) {
    Options o = { .heap = 4u << 20, .heap_fill = 50, .nursery = (size_t)1 << 20, .old_kind = OLD_SEGFIT };
    vm_same_program = same_program;
    options(rune_options, "runeopt --options", &o);
    /* The options are the runtime's, as runevm-stack's are, and not part of what
       the program sees of its environment, nor of what its children get. */
    const char *env = getenv("RUNEVM_OPTIONS");
    if (env) { options(env, "RUNEVM_OPTIONS", &o); unsetenv("RUNEVM_OPTIONS"); }

    /* A world to carry on: an image Runtime.save wrote (--restore FILE), or
       the child of a fork emulated by a second process (runtime/image.c), which is
       started as `runevm --resume TOKEN` whichever program it is. Its state,
       flags and arguments included, are the image's. */
    int child = argc == 3 && strcmp(argv[0], "runevm") == 0 && strcmp(argv[1], "--resume") == 0;
    if (o.restore || child) {
        VM *vm = calloc(1, sizeof(VM));
        char err[256];
        if (!vm) { fprintf(stderr, "runevm: out of memory\n"); return 2; }
        vm->heap_limit = o.heap_limit;
        vm->equality_work = o.equality_work;
        vm->gc.nursery_size = o.nursery;
        vm->gc.old_kind = o.old_kind;
        int ok = child ? vm_resume(vm, argv[2], err, sizeof err) : vm_restore(vm, o.restore, err, sizeof err);
        if (ok && !same_program(vm)) { ok = 0; snprintf(err, sizeof err, "the image is of another program"); }
        const void *code = ok ? prepare_resume(vm, err, sizeof err) : NULL;
        if (!code) {
            fprintf(stderr, "runevm: %s: %s\n", child ? "--resume" : "--restore", err);
            vm_destroy(vm);
            return 2;
        }
        free(o.restore);
        vm->gc_verify = o.gc_verify;
        if (o.gc_log && !child) heap_log_open(vm, o.gc_log);
        rune_enter(vm, code);
    }

    VM *vm = calloc(1, sizeof(VM));
    if (!vm) { fprintf(stderr, "runevm: out of memory\n"); return 2; }
    vm->native = 1;
    vm->stats = o.stats;
    vm->count = o.count;
    vm->gc_stress = o.gc_stress;
    vm->gc_verify = o.gc_verify;
    vm->emulate_fork = o.emulate_fork;
    vm->checked = o.checked;
    /* the name the program has under runevm-stack, where bin/runevm-native runs it
       for the suites: the path of its .rbc */
    const char *name = getenv("RUNEVM_NAME");
    if (name) { program_name = strdup(name); unsetenv("RUNEVM_NAME"); }
    vm->progname = program_name ? program_name : argv[0];
    vm->argc = argc - 1;
    vm->argv = argv + 1;
    vm->heap_limit = o.heap_limit;
    vm->equality_work = o.equality_work;
    vm_init(vm, o.heap);
    vm->heap_fill = (unsigned)o.heap_fill;
    vm->gc.old_kind = o.old_kind;
    heap_nursery(vm, o.nursery);
    if (o.gc_log) heap_log_open(vm, o.gc_log);

    char err[256];
    if (!load_program_mem(vm, rune_rbc, rune_rbc_size, err, sizeof err)) {
        fprintf(stderr, "runevm: %s: %s\n", argv[0], err);
        vm_destroy(vm);
        return 2;
    }
    vm_start(vm);
    size_t need = vm->sp + (size_t)rune_functions[2];
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
    rune_enter(vm, entry(0));
    return 0;
}
