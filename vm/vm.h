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

enum Tag { T_UNIT = 0, T_INT, T_WORD, T_REAL, T_CHAR, T_CON0, T_PTR };

typedef struct Obj Obj;

/* 16 bytes on every VM, which the heap's layout and the counts of --count
   both depend on and an image relies on (vm/image.c). The padding is written
   out rather than left to the machine: the i386 System V ABI aligns an
   `int64_t` to 4, where x86-64, PowerPC and the Windows compilers align it to
   8, and without this a Value is 12 bytes there and every object of the heap
   a different size (make test-portability). A narrower Value on 32-bit
   machines would save 0.46% of the heap and cost more than that: the reasons
   are written down under "8-byte values" in docs/plans/performance.md,
   which is also where the padding of the payload is weighed. */
typedef struct Value {
    uint8_t tag;
    uint8_t pad[7];
    union {
        int64_t i;   /* T_INT, T_CHAR, T_CON0 (constructor tag) */
        uint64_t w;  /* T_WORD */
        double d;    /* T_REAL */
        Obj *p;      /* T_PTR */
    } u;
} Value;

enum ObjKind {
    K_TUPLE = 1,  /* len fields; also vectors */
    K_CON,        /* contag; 1 field */
    K_CLOSURE,    /* field 0 = T_INT function index; fields 1.. = environment */
    K_STRING,     /* len bytes */
    K_REF,        /* 1 field */
    K_ARRAY,      /* len fields */
    K_EXN,        /* 2 fields: constructor, payload */
    K_EXNCON,     /* 1 field: name string; identity is the address */
    K_FORWARD     /* GC forwarding: first payload word is the new address */
};

struct Obj {
    uint8_t kind;
    uint8_t pad;
    uint16_t contag;
    uint32_t len;   /* number of fields, or byte length for strings */
    /* payload follows: Value fields[] or char bytes[] */
};

#define OBJ_FIELDS(o) ((Value *)((char *)(o) + sizeof(Obj)))
#define OBJ_BYTES(o) ((char *)(o) + sizeof(Obj))

static inline Value mk_unit(void) { Value v; v.tag = T_UNIT; v.u.i = 0; return v; }
static inline Value mk_int(int64_t i) { Value v; v.tag = T_INT; v.u.i = i; return v; }
static inline Value mk_word(uint64_t w) { Value v; v.tag = T_WORD; v.u.w = w; return v; }
static inline Value mk_real(double d) { Value v; v.tag = T_REAL; v.u.d = d; return v; }
static inline Value mk_char(int64_t c) { Value v; v.tag = T_CHAR; v.u.i = c; return v; }
static inline Value mk_con0(int64_t t) { Value v; v.tag = T_CON0; v.u.i = t; return v; }
static inline Value mk_ptr(Obj *p) { Value v; v.tag = T_PTR; v.u.p = p; return v; }
static inline Value mk_bool(int b) { return mk_con0(b ? 1 : 0); }

/* ---------------------------------------------------------------- program */

typedef struct Function {
    uint32_t code_offset;
    uint32_t code_end;
    uint32_t maxstack;   /* how deep its operand stack goes: the loader works it out (vm/isa_stack.c) */
    uint32_t nlocals;
    char *name;
} Function;

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

/* ---------------------------------------------------------------- machine */

typedef struct Frame {
    uint32_t func;
    uint32_t ret_pc;
    size_t base;     /* stack index of local 0 */
    Obj *closure;    /* NULL for the toplevel */
    /* In a program runeopt made (vm/native.c), the native code at ret_pc.
       An image does not carry it: it is an address of one process. */
    const void *native_ret;
} Frame;

typedef struct Handler {
    uint32_t pc;
    size_t sp;
    size_t fp;
} Handler;

#define NUM_BUILTIN_EXNS 8

typedef struct VM {
    Program prog;

    Value *stack;
    size_t sp, stack_cap;

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
    size_t gc_count;
    size_t live_last;        /* bytes the last collection kept, and the one before it: */
    size_t live_before;      /* vm_gc guesses from them whether the heap must grow */
    int64_t gc_user_us;      /* processor time spent collecting, in microseconds */
    int64_t gc_sys_us;
    uint64_t bytes_allocated;  /* not size_t: --count prints the same where it is 32 bits */
    uint64_t objects_allocated;
    uint64_t instructions;   /* executed so far */
    size_t gc_stress;        /* --gc-stress N: collect before every Nth allocation; 0 = off */
    unsigned heap_fill;      /* --heap-fill P: the heap grows until at most P% of it is in use
                                after a collection; 50 unless the option says otherwise */

    uint32_t pc;
    int trace;
    int stats;
    int count;               /* --count: report the deterministic counters at exit */
    int emulate_fork;        /* --emulate-fork: fork as Windows must, by a second VM (vm/image.c) */
    int checked;             /* --checked: DECON tests its tag (decision D14), for the test suites */
    int native;              /* a program runeopt made, whose code is not bytecode (vm/native.c) */

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
int values_equal(Value a, Value b);
void vm_print_trace(VM *vm, FILE *out);
void vm_release(VM *vm);                     /* free what a VM holds, but not the VM */
void vm_destroy(VM *vm);                     /* and the VM */

/* interp.c */
int vm_run(VM *vm);                          /* vm_start, then the loop */
int vm_loop(VM *vm);                         /* the dispatch loop alone, from vm->pc */

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
#define ISA_IMAGE_MAGIC_SIZE sizeof("runevm image 5 isa 00000000")
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

#endif
