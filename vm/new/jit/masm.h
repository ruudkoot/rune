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
enum SlowKind { SLOW_FATAL, SLOW_ALLOC, SLOW_GROW, SLOW_FRAMES, SLOW_RET, SLOW_PRIM, SLOW_GROW_RAX, SLOW_TAKEN, SLOW_DEOPT };
typedef struct Slow {
    X64Label here;
    X64Label back;
    int kind;
    uint32_t pc;          /* the pc after the instruction, for SYNC */
    uint32_t cur;         /* the instruction's own pc: what is live at its entry is written back (tier 2) */
    int32_t a, b, c, d, e, g;   /* what the kind needs */
    uint32_t n;
    const uint8_t *L;
} Slow;

/* Where a register's value lives while the function's code runs (tier 2,
   docs/plans/jit.md M9): in its slot, as tier 1 keeps every one, or in a
   machine register -- a general one for an int, a word, a char or a
   nullary constructor, an xmm for a real -- the payload alone, the tag
   being the representation's. A home is written back to the slot, with
   its tag, at every safepoint (ms_sync) and loaded again after
   (ms_reload), so that C, the interpreter and an image see the slot; a
   pointer never has a home, so the collector's roots are the slots as
   before. */
enum HomeKind { HOME_SLOT = 0, HOME_GPR, HOME_XMM };
typedef struct Home {
    uint8_t kind;
    uint8_t reg;          /* the machine register */
    uint8_t tag;          /* the tag the value has: T_INT, T_WORD, T_CHAR, T_CON0, T_REAL */
} Home;

typedef struct Masm {
    X64 a;
    int win;              /* the Windows convention for calls into C */
    uint32_t nlocals;     /* the function's registers */
    uint32_t nslots;      /* the registers and what a primitive's arguments push: the frame's slots */
    uint32_t nfields;     /* the fields of the object ms_alloc last made, or UINT32_MAX where the object in hand is another's */
    const void *leave;    /* the leave stub: where the code hands the VM back */
    Slow *slow;
    int nslow, slow_cap;
    /* tier 2: the homes, one per register (NULL: every value in its slot),
       and which registers are live after each pc of the function (a bit
       per register, from `from`; NULL: all), for what a safepoint writes
       back and loads again */
    const Home *homes;
    const uint64_t *live;
    uint32_t from;
    uint32_t sync_pc;     /* the pc of the last ms_sync, for the reload after */
    uint32_t cur_pc;      /* the pc of the instruction being emitted: what is live at its entry is written back */
    /* tier 2 (M10): the representations of the registers, trusted for the
       shape of a value -- a register the section says holds a pointer
       holds a pointer to an object of the kind the instruction expects,
       and a tuple or a constructor has the fields it names -- so that the
       tag, kind and length tests the loop and tier 1 make are left out;
       NULL: every value tested */
    const uint8_t *reps;
} Masm;
/* whether the shape of R(s) is trusted for an object of kind (REP_PTR; a
   constructor with fields for K_CON from a datatype with nullary ones too) */
int ms_trusts(const Masm *m, int32_t s, int kind);
/* whether R(s) is an immediate by the section: an int, a word, a char or a nullary constructor */
int ms_immediate(const Masm *m, int32_t s);

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
/* the ones the emitters of M5 to M7 wrote against the slots directly,
   through here from M9, so that a register's home may be elsewhere */
void ms_value_to(Masm *m, int base, int32_t disp, int32_t s);      /* [base + disp] := R(s), as a Value (16 bytes) */
void ms_value_from(Masm *m, int32_t d, int base, int32_t disp);    /* R(d) := the Value at [base + disp] */
void ms_load_real(Masm *m, int xmm, int32_t s);                    /* xmm := the real in R(s) */
void ms_set_real(Masm *m, int32_t d, int xmm);                     /* R(d) := the real in xmm */
void ms_cmp_payload(Masm *m, int r, int32_t s);                    /* flags := r against the payload of R(s) */
void ms_test_false(Masm *m, int32_t s);                            /* flags: ZF where the bool in R(s) is false */
void ms_load_xmm(Masm *m, int xmm, int32_t s);                     /* xmm := R(s), as a Value (16 bytes) */
/* tier 2: the homes live at pc written back to their slots, with their
   tags; and loaded again from the slots */
void ms_writeback(Masm *m, uint32_t pc);
void ms_reload_homes(Masm *m, uint32_t pc);
/* the home of register s, or NULL where it is its slot */
static inline const Home *ms_home(const Masm *m, int32_t s) {
    return m->homes && (uint32_t)s < m->nlocals && m->homes[s].kind != HOME_SLOT ? &m->homes[s] : NULL;
}

/* the VM */
void ms_sync(Masm *m, uint32_t pc, int pushed);
void ms_reload(Masm *m);
void ms_frame(Masm *m, int r);                                     /* r := &vm->frames[vm->fp] */
/* a helper the code calls into: any function, cast to this type */
typedef void (*MsHelper)(void);
void ms_call(Masm *m, MsHelper helper);                            /* the VM as argument 0, the others set already */
/* a call into C that touches nothing of the VM, with nothing synced or
   reloaded (M7) -- but the homes (tier 2), which C and the arguments'
   registers clobber: the emitter writes them back (ms_writeback) before
   it sets the arguments, and this loads them again after */
void ms_call_lean(Masm *m, MsHelper helper);
void ms_count(Masm *m, uint32_t k);
void ms_handback(Masm *m, int code);                               /* the VM handed back with that answer */
/* the code left at the boundary after an instruction, for the interpreter
   to go on at pc (M11, OSR exit): the homes live there written back, the
   VM made exact, and the count less the `remaining` instructions of the
   run counted at its start that the interpreter will count itself */
void ms_exit(Masm *m, uint32_t pc, uint32_t remaining);
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
