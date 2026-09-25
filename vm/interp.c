/* The interpreter loop: an instruction at a time, from vm->pc. What each
   instruction does is its body in src/isa/stack.sml, from which runeisa
   writes the cases of the loop (interp_cases.h, and the labels of
   interp_labels.h) and the functions of those it shares with the code of
   runeopt (ops.h).

   The loop keeps the stack pointer, the frame, its base, the pc and the
   count of instructions in its own variables (performance.md, item 15), and
   gives them to the VM (SYNC) before whatever reads them there -- the
   collector, a raise, a primitive, a frame pushed, a fatal error -- and
   takes them back (RELOAD) after whatever may have changed them. A push
   does not check for room: the loader has worked out how deep each
   function's stack goes (Function.maxstack), and a call makes room for it.
   Where the compiler has computed goto (__GNUC__), each case goes straight
   to the next; elsewhere, and with -DRUNE_SWITCH, a switch does. A second
   copy of the loop prints every instruction (runevm --trace), so that the
   first need not ask. */
#include "vm.h"
#include "ops.h"

#if defined(__GNUC__) && !defined(RUNE_SWITCH)
#define THREADED 1
/* a computed goto is not ISO C, which -pedantic says of every one */
#pragma GCC diagnostic ignored "-Wpedantic"
#else
#define THREADED 0
#endif

/* The words the bodies are written in (src/isa/stack.sml). */
#define PUSH(v) (*sp++ = (v))
#define POP() (*--sp)
#define TOP(k) (sp[-1 - (k)])
#define LOCALV(l) (base[(l)])
#define FRAME fr
#define PC pc
#define JUMP_TO(o) (pc = (uint32_t)(o))
#define SYNC() (vm->sp = (size_t)(sp - vm->stack), vm->pc = pc, vm->instructions = count)
#define RELOAD() (code = p->code, pc = vm->pc, fr = &vm->frames[vm->fp], base = vm->stack + fr->base, \
                  sp = vm->stack + vm->sp)
#define ENTER(slot, fn) (fr = &vm->frames[vm->fp], base = (slot), sp = (slot) + (fn)->nlocals, \
                         pc = (fn)->code_offset)
#define RETURN_TO(back) (fr = &vm->frames[vm->fp], base = vm->stack + fr->base, pc = (back))
#define FATAL(...) (SYNC(), vm_fatal(vm, __VA_ARGS__))
#define EXPECT(v, kind, what) expect_obj(vm, (v), (kind), (what), sp, pc, count)

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
#include "loop.h"
#undef LOOP_NAME
#undef TRACED

#define LOOP_NAME loop_traced
#define TRACED 1
#include "loop.h"
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
    }
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
}

int vm_run(VM *vm) {
    vm_start(vm);
    return vm_loop(vm);
}

/* The JIT is vm/new's (docs/plans/jit.md): this VM has none. */
int vm_jit_arg(const char *arg, int *mode, int *stats, int *check) {
    (void)mode; (void)stats; (void)check;
    fprintf(stderr, "runevm: %s: this VM has no JIT (bin/runevm-new has)\n", arg);
    return 0;
}
int vm_jit_check(void) { return 2; }

/* The loop alone: a VM resumed from an image (vm/image.c) enters it here,
   its built-in exceptions and frames being those of the image. */
int vm_loop(VM *vm) {
    make_room(vm);
    return vm->trace ? loop_traced(vm) : loop_fast(vm);
}
