/* What runtime/register's loops share (runtime/register/interp.c, which
   has loop_fast and loop_traced, and runtime/register/debug_loop.c, which
   has the debugger's): the words the bodies of src/isa/regs.sml are
   written in that are the same in each. Each file defines the rest --
   HANDOVER, BACKWARD, POLL, RAISED and the others of the JIT and the
   debugger -- and includes reg_loop.h. Two files, so that the debug loop
   is no part of what the compiler weighs as it compiles the others. */
#ifndef RUNE_REGISTER_WORDS_H
#define RUNE_REGISTER_WORDS_H

#include "regvm.h"
#include "live.h"
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
/* the frame just pushed records where its return goes: the register of
   the RESULT at pc, the caller's next instruction, if that is one (M7) */
#define RESULT_OF(at_pc) \
    (vm->frames[vm->fp].result = code[(at_pc)] == ROP_RESULT ? (uint32_t)read_i32(code + (at_pc) + 1) : UINT32_MAX)
/* The object v points to, which must be of that kind; the program stops
   with "expected <what>" where it is not, the VM told where it is. */
static inline Obj *expect_obj(VM *vm, Value v, int kind, const char *what, Value *sp, uint32_t pc, uint64_t count) {
    if (!val_is(v, T_PTR) || obj_kind(val_ptr(v)) != kind) {
        SYNC();
        vm_fatal(vm, "expected %s", what);
    }
    return val_ptr(v);
}

#endif
