/* Rune virtual machine: shared declarations. C99, no dependencies beyond libc. */
#ifndef RUNE_VM_H
#define RUNE_VM_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "opcodes.h"
#include "prims_table.h"

/* ---------------------------------------------------------------- values */

/* The layout of a value and of an object: vm/value.h, the one place that
   knows it. */
#include "value.h"

/* ---------------------------------------------------------------- program */

/* A block of a function, as the compiler laid it out: where it begins and
   the registers of its parameters (the representations section,
   docs/bytecode.md). */
typedef struct MetaBlock {
    uint32_t pc;
    uint32_t nparams;
    uint32_t *params;
} MetaBlock;

typedef struct Function {
    uint32_t code_offset;
    uint32_t code_end;
    uint32_t maxstack;   /* how deep its operand stack goes: the loader works it out (vm/isa_stack.c) */
    uint32_t nlocals;
    char *name;
    /* The representations section of the register bytecode (docs/bytecode.md;
       docs/plans/jit.md, M8): what the compiler says of the function beside
       its code, for the JIT's tier 2. has_meta is 0 where the file says
       nothing (the stack bytecode, a hand-made file). */
    int has_meta;
    uint32_t arity;
    uint8_t *reps;       /* nlocals of them: what each register holds (REP_*) */
    uint32_t nblocks;
    MetaBlock *blocks;
    uint32_t nloops;
    uint32_t *loops;     /* the pcs of the loop heads */
} Function;

/* What a register holds, as the compiler says (Low.rep; the numbers are the
   file's) */
enum Rep { REP_ANY = 0, REP_INT, REP_WORD, REP_REAL, REP_CHAR, REP_CON0, REP_PTR, REP_CON, REP_UNIT, REP__COUNT };

/* Where an instruction came from: the file, line and column the compiler
   recorded for the instructions from `pc` up to the next entry's, and the
   functions inlined on the way there (inl, a number of Program.inlines;
   0: none). */
typedef struct LineEntry {
    uint32_t pc;
    uint32_t file;
    uint32_t line;
    uint32_t col;
    uint32_t inl;
} LineEntry;

/* A function whose code was inlined into another's: its name, where it was
   called from -- line 0 where it was called in tail position, taking the
   place of the function it was called from, as a tail call's frame does --
   and the inlined function that call is in itself (parent, a number below
   this one's; 0: none). Numbered from 1. */
typedef struct Inlined {
    char *name;
    uint32_t file;
    uint32_t line;
    uint32_t col;
    uint32_t parent;
} Inlined;

typedef struct Program {
    uint32_t nconsts;
    Value *consts;
    uint32_t nglobals;
    uint32_t nfuncs;
    Function *funcs;
    uint32_t code_len;
    uint8_t *code;
    /* debug information: the files the program was compiled from, and the
       position of every instruction, in order of pc */
    uint32_t nfiles;
    char **files;
    uint32_t nlines;
    LineEntry *lines;
    uint32_t ninlines;
    Inlined *inlines;
} Program;
/* the representations section freed with the program (vm/loader.c) */
void program_free_meta(Program *p);

/* ---------------------------------------------------------------- machine */

typedef struct Frame {
    uint32_t func;
    uint32_t ret_pc;
    size_t base;     /* stack index of local 0 */
    Obj *closure;    /* NULL for the toplevel */
    /* In a program runeopt made (vm/native.c), the native code at ret_pc.
       An image does not carry it: it is an address of one process. */
    const void *native_ret;
    /* In vm/new, the register of the caller's RESULT, which the return
       writes into, or UINT32_MAX where the caller takes the value from the
       stack (docs/plans/jit.md, M7). Not in an image: made again from the
       code at ret_pc when one is read (vm/new/interp.c, make_room). */
    uint32_t result;
} Frame;

typedef struct Handler {
    uint32_t pc;
    size_t sp;
    size_t fp;
    /* In vm/new, the native code of the handler where the frame that
       installed it runs compiled (vm/new/jit.h); NULL for the interpreter.
       An image does not carry it. */
    const void *native;
} Handler;

/* The --jit options of vm/new (vm/new/jit.h, docs/plans/jit.md): the mode;
   --jit-stats; --jit-only=SPEC, which functions alone get code; the
   thresholds of --jit=baseline, in calls of a function and in its work,
   the iterations of its loops and the calls it makes (0: the defaults);
   --jit-stress=N, every Nth call into compiled code invalidating it
   instead. */
typedef struct JitOptions {
    int mode;
    int stats;
    int perf_map;            /* --jit-perf-map: /tmp/perf-PID.map, for perf record (M7) */
    int profile;             /* --jit-profile: the profiles of tier 1's code, shown by --jit-stats (M8) */
    const char *only;
    uint32_t calls, work;
    uint32_t stress;
    uint32_t tier;           /* --jit-tier=N: the tier functions are compiled at (0: the mode's; M9) */
    uint32_t deopt_stress;   /* --deopt-stress=N: code leaves for the interpreter at every Nth instruction boundary (M11) */
} JitOptions;

#define NUM_BUILTIN_EXNS 8

typedef struct VM {
    Program prog;

    Value *stack;
    size_t sp, stack_cap;
    size_t stack_limit;      /* the most bytes the value stack, the frames or the handlers may take (--stack-size): a runaway recursion stops here, not at the machine's memory */

    Frame *frames;
    size_t fp, frames_cap;   /* fp = index of current frame; frames_cap capacity */
    int frames_active;       /* 1 once the toplevel frame exists */

    Handler *handlers;
    size_t hp, handlers_cap;

    Value *globals;
    uint8_t *global_set;

    Obj *builtin_exns[NUM_BUILTIN_EXNS];

    /* heap (Cheney semispace) */
    char *heap_from, *heap_to;
    size_t heap_size;        /* size of one semispace */
    size_t heap_used;
#ifdef RUNE_CENSUS
    size_t census_used_stock;  /* heap_used as the stock VM would count it (8-byte headers): the collector's trigger */
#endif
    size_t gc_count;
    size_t live_last;        /* bytes the last collection kept, and the one before it: */
    size_t live_before;      /* vm_gc guesses from them whether the heap must grow */
    int64_t gc_user_us;      /* processor time spent collecting, in microseconds */
    int64_t gc_sys_us;
    uint64_t bytes_allocated;  /* not size_t: --count prints the same where it is 32 bits */
    uint64_t objects_allocated;
    uint64_t copied;         /* bytes every collection copied, in all (--stats) */
    size_t max_live;         /* the most a collection kept (--stats) */
    uint64_t instructions;   /* executed so far */
    size_t gc_stress;        /* --gc-stress N: collect before every Nth allocation; 0 = off */
    unsigned heap_fill;      /* --heap-fill P: the heap grows until at most P% of it is in use
                                after a collection; 50 unless the option says otherwise */
    size_t heap_limit;       /* maximum semispace size; 0 = unlimited */
    size_t equality_work;    /* comparison steps; 0 = the default 1000000 */

    uint32_t pc;
    int trace;
    int stats;
    int count;               /* --count: report the deterministic counters at exit */
    int emulate_fork;        /* --emulate-fork: fork as Windows must, by a second VM (vm/image.c) */
    int checked;             /* --checked: DECON tests its tag (decision D14), for the test suites */
    int native;              /* a program runeopt made, whose code is not bytecode (vm/native.c) */
    JitOptions jit;          /* the --jit options, vm/new's (vm/new/jit.h); all 0 in runevm */

    int argc;
    char **argv;             /* arguments after the bytecode file */
    const char *progname;
    int owns_args;           /* argv and progname were read from an image (vm/image.c) */

    /* open files indexed by handle: 0 stdin, 1 stdout, 2 stderr (never closed);
       handles are never reused, a closed slot is NULL */
    FILE **files;
    uint8_t *file_modes;     /* each file's mode of file_open, which an image of the VM carries */
    char **file_paths;       /* the path each was opened by, for an image that a process does not
                                inherit descriptors from (Runtime.save); NULL for the standard streams */
    size_t nfiles, files_cap;
    int io_errno;            /* errno of the last failed file_open / file_write */
} VM;

/* heap.c */
void heap_init(VM *vm, size_t semispace_bytes);
Obj *vm_alloc(VM *vm, uint8_t kind, uint16_t contag, uint32_t len, size_t payload_bytes);
Obj *vm_alloc_fields(VM *vm, uint8_t kind, uint16_t contag, uint32_t nfields);
Obj *vm_alloc_string(VM *vm, uint32_t len);
Obj *vm_string_from(VM *vm, const char *s, uint32_t len);
size_t obj_size(const Obj *o);      /* header and payload, rounded as the heap lays it out */
void vm_gc(VM *vm, size_t needed);
int heap_relocate(VM *vm, uintptr_t old_base);  /* after an image is read: 0 when it is not sound */

/* runtime.c: all of a VM but its dispatch loop and its command line. What
   the loop does at every instruction is inline here, where it can be made
   part of the loop; only what grows an array is not. */
/* A function that never returns: the loop needs nothing kept for after it. */
#if defined(__GNUC__)
#define VM_NORETURN __attribute__((noreturn))
#else
#define VM_NORETURN
#endif

void vm_init(VM *vm, size_t heap);           /* the standard files and the heap */
VM_NORETURN void vm_fatal(VM *vm, const char *fmt, ...);
VM_NORETURN void vm_limit(VM *vm, const char *message);
void vm_grow_stack(VM *vm, size_t need);     /* make room for `need` values in total */
void vm_grow_frames(VM *vm);                 /* make room for another frame */
static inline void vm_push(VM *vm, Value v) {
    if (vm->sp >= vm->stack_cap) vm_grow_stack(vm, vm->sp + 1);
    vm->stack[vm->sp++] = v;
}
static inline Value vm_pop(VM *vm) {
    if (vm->sp == 0) vm_fatal(vm, "stack underflow");
    return vm->stack[--vm->sp];
}
static inline Value *vm_top(VM *vm, size_t depth) {    /* pointer to stack[sp-1-depth] */
    if (vm->sp <= depth) vm_fatal(vm, "stack underflow");
    return &vm->stack[vm->sp - 1 - depth];
}
/* The object v points to, which must be of that kind; the instructions stop
   the program with "expected <what>" where it is not. */
static inline Obj *vm_expect_obj(VM *vm, Value v, int kind, const char *what) {
    if (v.tag != T_PTR || v.u.p->kind != kind) vm_fatal(vm, "expected %s", what);
    return v.u.p;
}
static inline void vm_push_frame(VM *vm, uint32_t func, Obj *closure, uint32_t ret_pc, size_t base) {
    size_t idx = vm->frames_active ? vm->fp + 1 : 0;
    if (idx >= vm->frames_cap) vm_grow_frames(vm);
    vm->frames[idx].func = func;
    vm->frames[idx].closure = closure;
    vm->frames[idx].ret_pc = ret_pc;
    vm->frames[idx].base = base;
    vm->frames[idx].native_ret = NULL;   /* native code sets its own (vm/native.c, vm/new) */
    vm->frames[idx].result = UINT32_MAX; /* vm/new's loop and code set it */
    vm->fp = idx;
    vm->frames_active = 1;
}
/* Every normal end of a run (halt, the exit primitive, an uncaught exception)
   goes through vm_exit, which flushes and prints what --count and --stats ask for. */
VM_NORETURN void vm_exit(VM *vm, int status);
int vm_raise(VM *vm, Value exn);            /* unwinds; returns 1 (never returns on uncaught) */
int vm_raise_builtin(VM *vm, int k);
void vm_push_handler(VM *vm, uint32_t pc);
void vm_start(VM *vm);                       /* the builtin exceptions, and function 0 called with () */
void vm_cons(VM *vm);                        /* stack: ..., hd, tl  ->  ..., hd :: tl */
int values_equal(VM *vm, Value a, Value b);
void vm_print_trace(VM *vm, FILE *out);
void vm_release(VM *vm);                     /* free what a VM holds, but not the VM */
void vm_destroy(VM *vm);                     /* and the VM */

/* interp.c */
int vm_run(VM *vm);                          /* vm_start, then the loop */
int vm_loop(VM *vm);                         /* the dispatch loop alone, from vm->pc */
/* The options of the JIT (--jit=MODE, --jit-stats, --jit-check), which
   vm/new takes and runevm refuses: 1 when the option is taken, 0 when it is
   not one. vm_jit_check runs --jit-check and gives the exit status. */
int vm_jit_arg(const char *arg, JitOptions *jit, int *check);
int vm_jit_check(void);
/* RUNEVM_JIT in the environment, the mode where no --jit= is given: taken
   by vm/new, ignored by runevm (the compiler runs on it); 0 for a mode
   that is none. */
int vm_jit_env(const char *mode, int *out);

/* In a program runeopt made (vm/native.c), whether a world read from an
   image runs the program it carries; NULL in runevm, which runs any. */
extern int (*vm_same_program)(const VM *world);

/* image.c: fork as a second VM that is handed this one's state */
int64_t vm_fork(VM *vm);                     /* the child's pid in the parent, or -1 */
int vm_resume(VM *vm, const char *token, char *err, size_t errlen);   /* in the child */
int vm_save(VM *vm, const char *path);       /* the whole VM in a file (Runtime.save); 0 on failure */
int vm_restore(VM *vm, const char *path, char *err, size_t errlen);  /* runevm --restore FILE */
int vm_become(VM *vm, const char *path);     /* Runtime.restore: this world becomes that one; 0 on failure */

/* loader.c */
int load_program(VM *vm, const char *path, char *err, size_t errlen);
int load_program_mem(VM *vm, const uint8_t *data, size_t size, char *err, size_t errlen);
/* Where every instruction begins, or NULL: a program from a .rbc or from an
   image is checked the same way. The caller frees it. */
uint8_t *validate_program(Program *p, char *err, size_t errlen);

/* What each VM's instruction set gives (vm/isa_stack.c, vm/new/isa_regs.c):
   the fingerprint an .rbc must carry, and the first bytes of an image. */
#define ISA_IMAGE_MAGIC_SIZE sizeof("runevm image 7 isa 00000000")
extern const uint32_t isa_fingerprint;
extern const char isa_image_magic[ISA_IMAGE_MAGIC_SIZE];
const LineEntry *line_at(const Program *p, uint32_t pc);

/* The frames a trace shows for a VM frame of the function `name` stopped at
   the line entry e: the functions inlined there and its own, innermost
   first, at most max of them in out; how many. */
typedef struct TraceFrame {
    const char *name;
    uint32_t file, line, col;
} TraceFrame;
uint32_t trace_frames(const Program *p, const LineEntry *e, const char *name, TraceFrame *out, uint32_t max);
void disassemble(const Program *p, FILE *out);

/* byte length of an instruction, or 0 for an invalid opcode */
static inline int instr_length(uint8_t op) {
    if (op >= OP__COUNT) return 0;
    return 1 + 4 * op_nargs[op];
}

/* prims.c */
/* What a primitive gives back to the dispatch loop: 0 for an ordinary return
   (`ret`), 1 where it raised, and this where it has replaced the program the
   loop is running (vm/image.c, Runtime.restore). */
#define PRIM_NEW_WORLD 2
typedef int (*PrimFn)(VM *vm);
extern const PrimFn prim_table[PRIM__COUNT];

/* utilities */
static inline int32_t read_i32(const uint8_t *p) {
    uint32_t u = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
    return (int32_t)u;
}
static inline uint32_t read_u32(const uint8_t *p) { return (uint32_t)read_i32(p); }

#include "census.h"

#endif
