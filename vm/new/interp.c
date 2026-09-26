/* vm/new's loop (docs/plans/jit.md, M2): the register bytecode an
   instruction at a time, from vm->pc. What each instruction does is its
   body in src/isa/regs.sml, from which runeisa writes the cases of the loop
   (reg_cases.h, and the labels of reg_labels.h). Everything else -- frames,
   handlers, primitives, the collector, images -- is the runtime
   vm/portable's runevm has, from build/librune.a: a register is a slot of
   its frame on the VM's stack, so the runtime sees it as it sees a local.

   The loop keeps the frame's registers (base), the stack pointer, the pc
   and the count of instructions in its own variables, and gives them to
   the VM (SYNC) before whatever reads them there -- the collector, a raise,
   a primitive, a handler pushed, a fatal error -- and takes them back
   (RELOAD) after whatever may have changed them, or moved the stack. A push
   does not check for room: the checker has worked out how deep each
   function's stack goes above its registers (Function.maxstack,
   vm/new/isa_regs.c), and a call makes room for it (ROOM). Where the
   compiler has computed goto (__GNUC__), each case goes straight to the
   next; elsewhere, and with -DRUNE_SWITCH, a switch does. A second copy of
   the loop prints every instruction (--trace), so that the first need not
   ask. */
#include "regvm.h"
#include "fastprim.h"
#include "jit.h"

#ifndef RUNE_JIT
#define RUNE_JIT 1
#endif

#define RUN_JIT (RUNE_JIT != 0)

#if defined(__GNUC__) && !defined(RUNE_SWITCH)
#define THREADED 1
/* a computed goto is not ISO C, which -pedantic says of every one */
#pragma GCC diagnostic ignored "-Wpedantic"
#else
#define THREADED 0
#endif

/* The words the bodies are written in (src/isa/regs.sml). The loop is
   given the JIT's view of the program (jit), NULL where --jit is off. */
#define R(x) (base[(x)])
#define LIST(i) read_i32(L + 4 * (size_t)(i))
#define PUSH(v) (*sp++ = (v))
#define POP() (*--sp)
#define SYNC() (vm->sp = (size_t)(sp - vm->stack), vm->pc = pc, vm->instructions = count)
#define RELOAD() (code = p->code, pc = vm->pc, fr = &vm->frames[vm->fp], base = vm->stack + fr->base, \
                  sp = vm->stack + vm->sp)
#define ENTER(slot, fn) (fr = &vm->frames[vm->fp], base = (slot), sp = (slot) + (fn)->nlocals, \
                         pc = (fn)->code_offset)
/* room on the stack for a frame of fn whose registers begin at top: its
   registers and its deepest stack above them; growing the stack moves it */
#define ROOM(top, fn) \
    do { \
        if ((top) + (fn)->nlocals + (fn)->maxstack > vm->stack_cap) { \
            SYNC(); \
            vm_grow_stack(vm, (top) + (fn)->nlocals + (fn)->maxstack); \
            base = vm->stack + fr->base; \
            sp = vm->stack + vm->sp; \
        } \
    } while (0)
#define FATAL(...) (SYNC(), vm_fatal(vm, __VA_ARGS__))
#define EXPECT(v, kind, what) expect_obj(vm, (v), (kind), (what), sp, pc, count)
/* the frame on top handed to the driver, where function f has native code
   (vm/new/jit.h): the VM made exact first */
#define HANDOVER(f) \
    do { \
        if (jit) { \
            CodeObject *co_ = &jit->codes[(f)]; \
            if (vm->jit.mode == JIT_BASELINE) { \
                /* the caller's work too: called once but calling for ever, it \
                   is compiled here and entered when this callee returns */ \
                CodeObject *me_ = &jit->codes[fr->func]; \
                if (!me_->entry && ++me_->work >= jit->work_threshold) jit_tier_up(vm, jit, fr->func); \
                if (!co_->entry && ++co_->calls >= jit->calls_threshold) jit_tier_up(vm, jit, (f)); \
            } \
            if (co_->entry && jit->stress && ++jit->stress_count % jit->stress == 0) jit_invalidate(vm, jit, (f)); \
            if (co_->entry) { SYNC(); jit->at = co_->entry; jit->handed_native++; return RUN_NATIVE; } \
        } \
    } while (0)
/* a JUMP back to t, the head of a loop (M6): the function's counter, its
   code where the counter says so, and on in the code at t where it has
   some, the frame being the same */
#define BACKWARD(t) \
    do { \
        if (jit) { \
            CodeObject *co_ = &jit->codes[fr->func]; \
            if (!co_->entry && vm->jit.mode == JIT_BASELINE && ++co_->work >= jit->work_threshold) jit_tier_up(vm, jit, fr->func); \
            if (co_->entry) { \
                const void *at_ = jit_osr(co_, (t)); \
                if (at_) { pc = (t); SYNC(); jit->at = at_; jit->osr_entries++; return RUN_NATIVE; } \
            } \
        } \
    } while (0)
/* on at pc in the code of function f, where it has some and a run begins
   there (M6): a return into a frame that kept no native address, a raise
   into a handler that kept none */
#define RESUME_NATIVE(f, at_pc) \
    do { \
        if (jit && jit->codes[(f)].entry) { \
            const void *at_ = jit_osr(&jit->codes[(f)], (at_pc)); \
            if (at_) { SYNC(); jit->at = at_; jit->osr_entries++; return RUN_NATIVE; } \
        } \
    } while (0)
/* a return into native code, at the address the frame kept */
#define RETURN_NATIVE(at_) do { SYNC(); jit->at = (at_); jit->handed_native++; return RUN_NATIVE; } while (0)
/* the program became another (Runtime.restore): the JIT's view of it again */
#define NEW_PROGRAM() (jit = RUN_JIT && !vm->trace ? jit_program(vm) : NULL)
/* after a raise (vm_raise, which left the handler it took at hp): on in the
   handler's native code where it has some, else the next instruction */
#define RAISED() \
    do { \
        if (jit && vm->handlers[vm->hp].native) RETURN_NATIVE(vm->handlers[vm->hp].native); \
        RESUME_NATIVE(fr->func, pc); \
        NEXT; \
    } while (0)

/* The object v points to, which must be of that kind; the program stops
   with "expected <what>" where it is not, the VM told where it is. */
static inline Obj *expect_obj(VM *vm, Value v, int kind, const char *what, Value *sp, uint32_t pc, uint64_t count) {
    if (v.tag != T_PTR || v.u.p->kind != kind) {
        SYNC();
        vm_fatal(vm, "expected %s", what);
    }
    return v.u.p;
}

#define LOOP_NAME loop_fast
#define TRACED 0
#include "reg_loop.h"
#undef LOOP_NAME
#undef TRACED

#define LOOP_NAME loop_traced
#define TRACED 1
#include "reg_loop.h"
#undef LOOP_NAME
#undef TRACED

/* Room on the stack for every frame there is to go as deep as its function
   does: the loop's pushes do not check. A frame made by vm_start or read
   from an image (vm/image.c) has not had it made yet. */
static void make_room(VM *vm) {
    size_t need = vm->sp + 1;
    for (size_t i = 0; i <= vm->fp; i++) {
        Frame *f = &vm->frames[i];
        Function *fn = &vm->prog.funcs[f->func];
        size_t n = f->base + fn->nlocals + fn->maxstack;
        if (n > need) need = n;
        f->native_ret = NULL;   /* a frame of an image, or of vm_start, returns into the interpreter */
    }
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
}

int vm_run(VM *vm) {
    vm_start(vm);
    return vm_loop(vm);
}

/* The driver (vm/new/jit.h): runs the frame on top at its tier, in the
   interpreter or in its native code, until the program ends. No engine
   calls another, so the machine stack never grows with the program's. A
   VM resumed from an image (vm/image.c) enters here too, its built-in
   exceptions and frames being those of the image. */
int vm_loop(VM *vm) {
    make_room(vm);
    int r = RUN_INTERP;
    for (;;) {
        /* the program may have become another (Runtime.restore) */
        JitProgram *jit = RUN_JIT && !vm->trace ? jit_program(vm) : NULL;   /* --trace: every instruction, interpreted */
        /* a frame handed to the interpreter whose function has code, at a
           place a run begins, goes on in the code (M6): the top level's
           frame at its first instruction, a frame of an image at its
           resume point */
        if (r == RUN_INTERP && jit) {
            uint32_t f = vm->frames[vm->fp].func;
            CodeObject *co = &jit->codes[f];
            /* a call from native code into an interpreted function lands here,
               at the function's first instruction: its counter (M6), which the
               interpreter's own calls keep in HANDOVER; compiled only here,
               never from native code, whose pages the compiler would make
               writable under it */
            if (!co->entry && vm->jit.mode == JIT_BASELINE && vm->pc == vm->prog.funcs[f].code_offset
                && ++co->calls >= jit->calls_threshold) jit_tier_up(vm, jit, f);
            const void *at = co->entry ? jit_osr(co, vm->pc) : NULL;
            if (at) { jit->at = at; jit->osr_entries++; r = RUN_NATIVE; }
        }
        if (r == RUN_NATIVE) r = jit_run(vm, jit, jit->at);
        else r = vm->trace ? loop_traced(vm, jit) : loop_fast(vm, jit);
        if (r == RUN_HALT) return 0;
    }
}

/* --jit-NAME=N: a count of at least 1 */
static int count_arg(const char *arg, size_t prefix, uint32_t *out) {
    char *end;
    unsigned long v = strtoul(arg + prefix, &end, 10);
    if (*end || v == 0 || v > 0xffffffffu) { fprintf(stderr, "runevm: %s: a count of at least 1\n", arg); return 0; }
    *out = (uint32_t)v;
    return 1;
}
int vm_jit_arg(const char *arg, JitOptions *jit, int *check) {
    if (!RUN_JIT) {
        fprintf(stderr, "runevm: %s: this VM is built without the JIT (RUNE_JIT=0)\n", arg);
        return 0;
    }
    if (strcmp(arg, "--jit-stats") == 0) { jit->stats = 1; return 1; }
    if (strncmp(arg, "--jit-only=", 11) == 0) {
        /* LO-HI, odd or even (vm/new/jit.c) */
        unsigned long a, b;
        const char *spec = arg + 11;
        if (strcmp(spec, "odd") == 0 || strcmp(spec, "even") == 0 || (sscanf(spec, "%lu-%lu", &a, &b) == 2 && a <= b)) { jit->only = spec; return 1; }
        fprintf(stderr, "runevm: %s: LO-HI, odd or even\n", arg);
        return 0;
    }
    if (strncmp(arg, "--jit-calls=", 12) == 0) return count_arg(arg, 12, &jit->calls);
    if (strncmp(arg, "--jit-work=", 11) == 0) return count_arg(arg, 11, &jit->work);
    if (strncmp(arg, "--jit-stress=", 13) == 0) return count_arg(arg, 13, &jit->stress);
    if (strcmp(arg, "--jit-check") == 0) { *check = 1; return 1; }
    if (strcmp(arg, "--jit=off") == 0) { jit->mode = JIT_OFF; return 1; }
    if (strcmp(arg, "--jit=baseline") == 0) { jit->mode = JIT_BASELINE; return 1; }
    if (strcmp(arg, "--jit=opt") == 0) { jit->mode = JIT_OPT; return 1; }
    if (strcmp(arg, "--jit=all") == 0) { jit->mode = JIT_ALL; return 1; }
    fprintf(stderr, "runevm: %s: the modes are off, baseline, opt and all\n", arg);
    return 0;
}

int vm_jit_check(void) { return jit_check(); }

int vm_jit_env(const char *mode, int *out) {
    JitOptions jit;
    int check = 0;
    char arg[64];
    memset(&jit, 0, sizeof jit);
    snprintf(arg, sizeof arg, "--jit=%s", mode);
    if (!vm_jit_arg(arg, &jit, &check)) { fprintf(stderr, "runevm: RUNEVM_JIT=%s: not a mode\n", mode); return 0; }
    *out = jit.mode;
    return 1;
}
