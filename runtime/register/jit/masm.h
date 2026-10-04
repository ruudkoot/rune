/* The macro-assembler of runtime/register's JIT (docs/plans/jit.md, D3, M4): the
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
   Register k of the frame is the word at [r14 + 8 k]. The frame's
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

#include "asm.h"
#include "vm.h"
#include "register/jit.h"

enum { VMR = R_VM, STACKR = R_STACK, BASEI = R_BASEI, BASER = R_BASER, COUNTR = R_COUNT };

/* A slow path, emitted after the function's code: where it begins, where
   it goes back to, and what it is. */
enum SlowKind { SLOW_FATAL, SLOW_ALLOC, SLOW_GROW, SLOW_FRAMES, SLOW_RET, SLOW_PRIM, SLOW_GROW_RAX, SLOW_TAKEN, SLOW_DEOPT, SLOW_BOXREAL, SLOW_BOXNUM };
typedef struct Slow {
    AsmLabel here;
    AsmLabel back;
    int kind;
    uint32_t pc;          /* the pc after the instruction, for SYNC */
    uint32_t cur;         /* the instruction's own pc: what is live at its entry is written back (tier 2) */
    int32_t a, b, c, d, e, g;   /* what the kind needs */
    uint32_t n;
    const uint8_t *L;
} Slow;

/* Where a register's value lives while the function's code runs (tier 2,
   docs/plans/jit.md M9): in its slot, as tier 1 keeps every one, or in a
   machine register. A general one for a char or a nullary constructor
   holds the value's word as the slot would (docs/plans/heap-layout.md, M4:
   the tagged word), and so does an int's or a word's where they are 63
   bits (D2 B): writing it back is one store and arithmetic is done on the
   words. A home is written back to the slot at every safepoint (ms_sync)
   and loaded again after (ms_reload), so that C, the interpreter and an
   image see the slot, and the collector's roots are the slots as before.

   A raw home holds the value itself and not its word: a real's is an xmm
   register with the double, and where the VM keeps ints and words of 64
   bits (RUNE_INT64, D2 A) an int's or a word's general register holds the
   64 bits, so that arithmetic between homes costs what it did and needs no
   test for a box. A raw home's slot holds a word and may be behind: the
   word is made when something needs it -- a safepoint, a store into the
   heap, a move to a register that has no such home -- by encoding the
   value, or, where it has no immediate, by a helper that boxes it. That
   helper may collect, so it is called only where a collection may happen:
   from a write-back, from ms_need_word, which an emitter calls at the
   start of an instruction that will store the register's word, and from
   ms_set_num, where a result goes to a slot. Within an instruction the
   masm remembers which slots it has brought up to date (cur_reals); a
   store of a raw home's word that finds its slot behind is an emitter's
   mistake, said at compile time. */
#define MS_REAL_HOMES 1
enum HomeKind { HOME_SLOT = 0, HOME_GPR, HOME_XMM };
typedef struct Home {
    uint8_t kind;
    uint8_t reg;          /* the machine register */
    uint8_t tag;          /* the tag the value has: T_INT, T_WORD, T_CHAR, T_CON0, T_REAL */
} Home;

typedef struct Masm {
    Asm a;
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
    /* the registers with a real's home whose slot holds the home's word:
       brought up to date in the code of the instruction being emitted, in
       a straight line from where it was done, and not written since */
    uint64_t cur_reals;
    void (*box_real)(void);   /* the helper that boxes a real into a slot (compile.c, jit_h_box_real) */
    void (*box_num)(void);    /* and the one that boxes an int or a word of 64 bits (jit_h_box_num) */
} Masm;
/* whether the shape of R(s) is trusted for an object of kind (REP_PTR; a
   constructor with fields for K_CON from a datatype with nullary ones too) */
int ms_trusts(const Masm *m, int32_t s, int kind);
/* whether R(s) is an immediate by the section: an int, a word, a char or a nullary constructor */
int ms_immediate(const Masm *m, int32_t s);
/* T_INT or T_WORD where R(s) is one by the section and the VM keeps 64 bits of them (else 0): compared by its bits, not by its word */
int ms_number(const Masm *m, int32_t s);

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
void ms_set_reg(Masm *m, int32_t d, int tag, int r);               /* R(d) := the value of tag whose payload is in r; r is left holding its word */
void ms_set_bits(Masm *m, int32_t d, int r);                       /* R(d) := the word in r */
void ms_load_bits(Masm *m, int r, int32_t s);                      /* r := the word of R(s) */
void ms_load_payload(Masm *m, int r, int32_t s);                   /* r := the payload of the immediate in R(s), signed */
void ms_load_value(Masm *m, int32_t d, int base, int32_t disp);    /* R(d) := the Value at [base + disp] */
void ms_store_value(Masm *m, int base, int32_t disp, int32_t s);   /* [base + disp] := R(s) */
void ms_check_tag(Masm *m, int32_t s, int tag, AsmLabel *unless);  /* to unless where R(s) has another tag */
void ms_load_obj(Masm *m, int r, int32_t s, int kind, AsmLabel *unless);   /* r := the object R(s) points to, of that kind */
void ms_load_obj_tested(Masm *m, int r, int32_t s, int kind, AsmLabel *unless);   /* the same, tested whatever the section says: a program's own error to report */
void ms_load_tag_of_con(Masm *m, int r, int32_t s, AsmLabel *unless);      /* r := the tag of the constructor value in R(s) */
/* the ones the emitters of M5 to M7 wrote against the slots directly,
   through here from M9, so that a register's home may be elsewhere */
void ms_value_to(Masm *m, int base, int32_t disp, int32_t s);      /* [base + disp] := R(s), as a Value (16 bytes) */
void ms_value_from(Masm *m, int32_t d, int base, int32_t disp);    /* R(d) := the Value at [base + disp] */
void ms_load_real(Masm *m, int xmm, int32_t s, AsmLabel *unless);  /* xmm := the real in R(s), an immediate decoded or a box read; to unless where it is neither; R_S2 and R_S3 clobbered */
void ms_set_real(Masm *m, int32_t d, int xmm, AsmLabel *slow);     /* R(d) := the real in xmm as an immediate; to slow where it has none (the box is a helper's to make); R_S2 and R_S3 clobbered */
void ms_cmp_bits(Masm *m, int r, int32_t s);                       /* flags := r against the word of R(s) */
void ms_test_false(Masm *m, int32_t s);                            /* flags: ZF where the bool in R(s) is false */
void ms_bool_flags(Masm *m, int r);                                /* flags: ZF where the bool whose word is in r is false */
void ms_load_xmm(Masm *m, int xmm, int32_t s);                     /* xmm := R(s), the value whole */
void ms_xmm_to(Masm *m, int base, int32_t disp, int xmm);          /* [base + disp] := the value ms_load_xmm put in xmm */
void ms_unit_to(Masm *m, int base, int32_t disp);                  /* [base + disp] := unit */
void ms_next_value(Masm *m, int r);                                /* r := r + the size of a value */

/* Ints, words, chars and nullary constructors as their words (the tagged
   word: 2n+1), in R_S0 and R_S1: arithmetic and comparison are done on
   the words, and R_S2 is clobbered. To slow where an operand is no
   immediate (under RUNE_INT64 an int or a word past 63 bits is a box) or
   the result is none: the primitive's own C does those. */
enum MsArith { MS_ADD, MS_SUB, MS_MUL, MS_AND, MS_OR, MS_XOR };
void ms_one_imm(Masm *m, int32_t x, int tag, AsmLabel *slow);              /* R_S0 := the word of R(x), an immediate */
void ms_two_imm(Masm *m, int32_t x, int32_t y, int tag, AsmLabel *slow);   /* R_S0, R_S1 := the words of R(x), R(y), immediates both */
void ms_two_words(Masm *m, int32_t x, int32_t y, AsmLabel *heap);          /* R_S0, R_S1 := the words of R(x), R(y), whatever they hold; to heap where either is no immediate */
void ms_int_arith(Masm *m, int op, AsmLabel *slow);                /* R_S0 := R_S0 op R_S1 (MS_ADD, MS_SUB, MS_MUL), to slow on overflow */
void ms_int_neg(Masm *m, AsmLabel *slow);                          /* R_S0 := ~R_S0, to slow on overflow */
void ms_int_to_char(Masm *m, AsmLabel *slow);                      /* the int in R_S0 as a char: to slow where it is not 0 to 255 */
void ms_word_arith(Masm *m, int op, AsmLabel *slow);               /* R_S0 := R_S0 op R_S1 for words: modulo the word size, or to slow where the result is no immediate */
void ms_word_not(Masm *m, AsmLabel *slow);                         /* R_S0 := notb R_S0 */
void ms_word_to_int(Masm *m, int x, AsmLabel *slow);               /* the word in R_S0 as an int: x for toIntX; to slow where it is none */
void ms_int_to_word(Masm *m, AsmLabel *slow);                      /* the int in R_S0 as a word */
void ms_untag(Masm *m, int r, int tag);                            /* r := the payload of the immediate word in r: unsigned for T_WORD */
void ms_set_num(Masm *m, int32_t d, int tag, int r, AsmLabel *slow);       /* R(d) := the int, word or char of tag that the arithmetic left in r, in its form; to slow where a slot wants a word it has none for; R_S2 clobbered */
void ms_set_payload(Masm *m, int32_t d, int tag, int r, AsmLabel *slow);   /* the same for a payload in r (a quotient, a length) */
void ms_set_word(Masm *m, int32_t d, int r, AsmLabel *slow);       /* R(d) := the word whose payload, 64 bits, is in r; to slow where it is no immediate */
/* tier 2: the homes live at pc written back to their slots, with their
   tags; and loaded again from the slots */
void ms_writeback(Masm *m, uint32_t pc);
void ms_reload_homes(Masm *m, uint32_t pc);
/* the instruction at pc begins: what the masm remembers of the last is forgotten */
void ms_begin(Masm *m, uint32_t pc);
/* R(s)'s word will be stored by this instruction: where s is a real in its
   home, its slot brought up to date now, at the instruction's start, where
   the helper that boxes may collect (nothing pushed, nothing kept in a
   scratch register) */
void ms_need_word(Masm *m, int32_t s);
void ms_move(Masm *m, int32_t d, int32_t s);                       /* the instruction MOVE: ms_need_word where it is wanted, then ms_copy */
void ms_emit_box(Masm *m, Slow *s);                                /* the slow path of a real, or of an int or a word of 64 bits, with no immediate (SLOW_BOXREAL, SLOW_BOXNUM) */
/* the home of register s where it holds the value's word, as a slot does:
   NULL for a slot and for a raw home (a real's, an int's or word's 64 bits) */
const Home *ms_word_home(const Masm *m, int32_t s);
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
void ms_alloc(Masm *m, int kind, int contag, uint32_t n, AsmLabel *slow);
void ms_store_field(Masm *m, int obj, uint32_t i, int32_t s);       /* field i of the object in obj := R(s): where a barrier goes */
void ms_load_field(Masm *m, int32_t d, int obj, uint32_t i);        /* R(d) := field i of the object in obj (a program's object: its length tested by the caller) */
void ms_load_len(Masm *m, int r, int obj);                          /* r := the length of the object in obj (fields, or bytes of a string) */
void ms_check_len(Masm *m, int obj, uint32_t n, AsmLabel *unless);  /* to unless where the object in obj has not exactly n fields */
void ms_load_contag(Masm *m, int r, int obj);                       /* r := the constructor tag of the object in obj */
void ms_need_len(Masm *m, int obj, uint32_t n, AsmLabel *unless);   /* to unless where the object in obj has not more than n fields (an index n is out) */
void ms_store_field_imm(Masm *m, int obj, uint32_t i, int tag, int32_t payload);   /* field i of the object in obj := the immediate value */
void ms_load_field_payload(Masm *m, int r, int obj, uint32_t i);    /* r := the payload of field i of the object in obj */
void ms_element(Masm *m, int obj, int index);                       /* obj := the address of element index of the object in obj (a vector or an array), index clobbered */
void ms_string_byte(Masm *m, int r, int obj, int index);            /* r := byte index of the string in obj; obj clobbered */
/* arrays of values outside the heap's objects: the constants, the globals,
   a frame's registers at an address */
void ms_load_nth(Masm *m, int32_t d, int base, uint32_t i);         /* R(d) := the i-th value at base */
void ms_store_nth(Masm *m, int base, uint32_t i, int32_t s);        /* the i-th value at base := R(s) */
void ms_slot_addr(Masm *m, int r, int32_t s);                       /* r := the address of R(s) */
void ms_fill_units(Masm *m, int base, uint32_t from, uint32_t to);  /* the values from..to-1 at base := unit */
void ms_field_from_nth(Masm *m, int obj, uint32_t i, int base, uint32_t k);   /* field i of the object in obj := the k-th value at base */
void ms_slot_from_nth_raw(Masm *m, int32_t d, int base, uint32_t k);
void ms_scale_index(Masm *m, int r);                               /* r := r * the size of a value: a count of values or registers as bytes */   /* the slot of R(d) := the k-th value at base, the slot itself whatever home d has (a callee's registers) */

/* slow paths */
Slow *ms_slow(Masm *m, int kind, uint32_t pc);
void ms_emit_slow_paths(Masm *m, void (*emit)(Masm *m, Slow *s));

/* the stubs, into their own buffers: enter(VM *vm, const void *at) and
   leave, which returns what rax says */
void ms_emit_enter(Asm *a, int win);
void ms_emit_leave(Asm *a, int win);

#endif
