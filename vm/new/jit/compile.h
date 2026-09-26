/* Compiling a function of the register bytecode to machine code, tier 1
   of vm/new's JIT (docs/plans/jit.md, M4): one instruction at a time, in
   the order of the bytecode, each doing what its case in the interpreter
   does, in the same frame, with every value in its slot -- runeopt's
   contract (docs/native.md) for the register bytecode, at run time. The
   emitters (emit.c) are written over the macro-assembler (masm.h); this is
   what runs them: the scan of a function, its labels and its runs, the
   slow paths, the helpers the code calls into, and where the code goes. */
#ifndef RUNE_JIT_COMPILE_H
#define RUNE_JIT_COMPILE_H

#include "masm.h"
#include "regvm.h"

/* The context of a function being compiled. */
typedef struct Jit {
    Masm m;
    VM *vm;
    JitProgram *jit;
    uint32_t f;             /* the function */
    uint32_t next;          /* the pc after the instruction being emitted */
    X64Label *labels;       /* one per byte of the function's code, bound where an instruction that is a target begins */
    uint32_t from, to;      /* the function's code */
    int unsupported;        /* an instruction tier 1 does not compile was met */
} Jit;

/* what native code says on a fatal error: the message of the interpreter */
enum JitFatal {
    FATAL_EXPECT_TUPLE, FATAL_EXPECT_CON, FATAL_EXPECT_CON_FIELDS, FATAL_EXPECT_CLOSURE, FATAL_EXPECT_EXN,
    FATAL_GLOBAL_UNSET, FATAL_ENV_RANGE, FATAL_SELF, FATAL_TUPLE_INDEX, FATAL_DECON_TAG, FATAL_CONTAG,
    FATAL_MKEXN, FATAL_JUMPIF, FATAL_JUMPIFNOT, FATAL_JUMPIFNOTTAG, FATAL_SWITCH, FATAL_FIELD_TAG, FATAL_FIELD_INDEX,
    FATAL_POPHANDLER, FATAL_RAISE
};

/* the label of the instruction at pc, for a jump */
X64Label *jit_label(Jit *j, uint32_t pc);
/* a fatal error at the instruction being emitted, out of line: the label to
   jump to; where the message wants a value found at run time, the code
   leaves it in rcx and says so with rcx_arg */
X64Label *jit_fatal(Jit *j, int what, int32_t a, int32_t b, int rcx_arg);
/* an allocation's slow path: the object of n fields made by the helper,
   then filled and stored by fill, as the fast path did */
enum { FILL_LIST, FILL_ONE, FILL_CLOSURE, FILL_NEWEXN, FILL_MKEXN };
X64Label *jit_alloc_slow(Jit *j, int kind, int contag, uint32_t n, int fill, int32_t d, int32_t a, int32_t b, const uint8_t *L);
/* fill the object in rax as fill says, then R(d) := it */
void jit_fill(Jit *j, int kind, int fill, uint32_t n, int32_t d, int32_t a, int32_t b, const uint8_t *L);
/* an instruction tier 1 does not compile: the function stays interpreted */
void jit_unsupported(Jit *j);

/* the helpers native code calls */
int jit_h_prim(VM *vm, int prim, int32_t d, const uint8_t *L);
Obj *jit_h_alloc(VM *vm, int kind, int contag, uint32_t n);
int jit_h_ret(VM *vm, int32_t s);
void jit_h_fatal(VM *vm, int what, int32_t a, int32_t b);
void jit_h_grow(VM *vm, size_t need);
void jit_h_grow_frames(VM *vm);
const void *jit_h_call(VM *vm, int32_t a, int32_t b, const void *after);
const void *jit_h_tailcall(VM *vm, int32_t a, int32_t b);
void jit_h_push_handler(VM *vm, int32_t pc, const void *native);
const void *jit_h_raise(VM *vm, int32_t s);
int jit_h_primpush(VM *vm, int prim, const uint8_t *L);

/* the compiler: 1 when function f now has an entry, 0 when it stays interpreted */
int jit_compile(VM *vm, JitProgram *jit, uint32_t f);
/* the code region and its stubs, made once; 0 on failure */
int jit_region_init(VM *vm, JitProgram *jit);

#endif
