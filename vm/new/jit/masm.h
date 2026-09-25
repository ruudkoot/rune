/* The macro-assembler of vm/new's JIT (docs/plans/jit.md, D3, M4): the
   operations the emitters of the instructions are written in, over the
   encoder (x64.h), and the conventions the code keeps. Everything an
   instruction does to a Value, a frame, the heap or the VM goes through
   here; the emitters (emit.c) say what, not how.

   The registers the code keeps, all preserved across a call into C by both
   conventions:
     r12  the VM
     r13  vm->stack, the value stack
     rbp  the frame's base, as an index into the stack
     r14  the frame's registers: r13 + 16 * rbp
     r15  the count of instructions executed
   Register k of the frame is the 16 bytes at [r14 + 16 k]. The frame's
   stack pointer is rbp + nlocals, plus what a primitive's arguments push.
   rax, rcx, rdx, rsi, rdi, r8 to r11 and xmm0, xmm1 are scratch; rbx is
   free. The machine stack holds only the call into C in progress: the
   enter stub aligns it, and the code never pushes.

   "The VM is exact where C can look" (docs/native.md): SYNC writes the
   stack pointer, the pc and the count to the VM before any call into C,
   and RELOAD takes the stack, the frame and its registers back after one,
   since a call may move the stack, and a raise the frame. */
#ifndef RUNE_JIT_MASM_H
#define RUNE_JIT_MASM_H

#include "x64.h"
#include "vm.h"
#include "jit.h"

enum { VMR = R12, STACKR = R13, BASEI = RBP, BASER = R14, COUNTR = R15 };

/* A slow path, emitted after the function's code: where it begins, where
   it goes back to, and what it is. */
enum SlowKind { SLOW_FATAL, SLOW_ALLOC };
typedef struct Slow {
    X64Label here;
    X64Label back;
    int kind;
    uint32_t pc;          /* the pc after the instruction, for SYNC */
    int32_t a, b, c, d, e, g;   /* what the kind needs */
    uint32_t n;
    const uint8_t *L;
} Slow;

typedef struct Masm {
    X64 a;
    int win;              /* the Windows convention for calls into C */
    uint32_t nlocals;     /* the function's registers */
    uint32_t nslots;      /* the registers and what a primitive's arguments push: the frame's slots */
    uint32_t nfields;     /* the fields of the object ms_alloc last made, or UINT32_MAX where the object in hand is another's */
    const void *leave;    /* the leave stub: where the code hands the VM back */
    Slow *slow;
    int nslow, slow_cap;
} Masm;

/* An emitter that names a register the frame has not, or a field the
   object has not, is a mistake of the VM's own, not of the program's: the
   operations here say so and stop (abort), on every machine, where the
   code it would have made faults only where the stray read leaves what is
   mapped. */
void ms_init(Masm *m, uint32_t nlocals, uint32_t maxstack, int win, const void *leave);
void ms_free(Masm *m);

/* the register the i-th argument of a call into C goes in (0: the VM) */
int ms_arg(const Masm *m, int i);

/* values in the frame's registers */
void ms_copy(Masm *m, int32_t d, int32_t s);                       /* R(d) := R(s) */
void ms_set(Masm *m, int32_t d, int tag, int64_t payload);         /* R(d) := a value of tag and payload */
void ms_set_reg(Masm *m, int32_t d, int tag, int r);               /* R(d) := tag and the payload in r */
void ms_load_tag(Masm *m, int r, int32_t s);                       /* r := the tag of R(s) */
void ms_load_payload(Masm *m, int r, int32_t s);                   /* r := the payload of R(s) */
void ms_load_value(Masm *m, int32_t d, int base, int32_t disp);    /* R(d) := the Value at [base + disp] */
void ms_store_value(Masm *m, int base, int32_t disp, int32_t s);   /* [base + disp] := R(s) */
void ms_check_tag(Masm *m, int32_t s, int tag, X64Label *unless);  /* to unless where R(s) has another tag */
void ms_load_obj(Masm *m, int r, int32_t s, int kind, X64Label *unless);   /* r := the object R(s) points to, of that kind */
void ms_load_tag_of_con(Masm *m, int r, int32_t s, X64Label *unless);      /* r := the tag of the constructor value in R(s) */

/* the VM */
void ms_sync(Masm *m, uint32_t pc, int pushed);
void ms_reload(Masm *m);
void ms_frame(Masm *m, int r);                                     /* r := &vm->frames[vm->fp] */
/* a helper the code calls into: any function, cast to this type */
typedef void (*MsHelper)(void);
void ms_call(Masm *m, MsHelper helper);                            /* the VM as argument 0, the others set already */
void ms_count(Masm *m, uint32_t k);
void ms_handback(Masm *m, int code);                               /* the VM handed back with that answer */
void ms_handback_rax(Masm *m);                                     /* with the answer in rax */

/* the heap: rax := an object of n fields, or to slow where it would not
   fit or --gc-stress asks; the header written, the counts kept */
void ms_alloc(Masm *m, int kind, int contag, uint32_t n, X64Label *slow);
void ms_store_field(Masm *m, int obj, uint32_t i, int32_t s);       /* field i of the object in obj := R(s): where a barrier goes */

/* slow paths */
Slow *ms_slow(Masm *m, int kind, uint32_t pc);
void ms_emit_slow_paths(Masm *m, void (*emit)(Masm *m, Slow *s));

/* the stubs, into their own buffers: enter(VM *vm, const void *at) and
   leave, which returns what rax says */
void ms_emit_enter(X64 *a, int win);
void ms_emit_leave(X64 *a, int win);

#endif
