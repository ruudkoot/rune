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

#if defined(__GNUC__) && !defined(RUNE_SWITCH)
#define THREADED 1
/* a computed goto is not ISO C, which -pedantic says of every one */
#pragma GCC diagnostic ignored "-Wpedantic"
#else
#define THREADED 0
#endif

/* The words the bodies are written in (src/isa/regs.sml). */
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
    }
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
}

int vm_run(VM *vm) {
    vm_start(vm);
    return vm_loop(vm);
}

/* The loop alone: a VM resumed from an image (vm/image.c) enters it here,
   its built-in exceptions and frames being those of the image. */
int vm_loop(VM *vm) {
    make_room(vm);
    return vm->trace ? loop_traced(vm) : loop_fast(vm);
}
