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

typedef struct Value {
    uint8_t tag;
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
    uint32_t nlocals;
    char *name;
} Function;

/* Where an instruction came from: the file, line and column the compiler
   recorded for the instructions from `pc` up to the next entry's. */
typedef struct LineEntry {
    uint32_t pc;
    uint32_t file;
    uint32_t line;
    uint32_t col;
} LineEntry;

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
} Program;

/* ---------------------------------------------------------------- machine */

typedef struct Frame {
    uint32_t func;
    uint32_t ret_pc;
    size_t base;     /* stack index of local 0 */
    Obj *closure;    /* NULL for the toplevel */
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
    int64_t gc_user_us;      /* processor time spent collecting, in microseconds */
    int64_t gc_sys_us;
    uint64_t bytes_allocated;  /* not size_t: --count prints the same where it is 32 bits */
    uint64_t objects_allocated;
    uint64_t instructions;   /* executed so far */
    size_t gc_stress;        /* --gc-stress N: collect before every Nth allocation; 0 = off */

    uint32_t pc;
    int trace;
    int stats;
    int count;               /* --count: report the deterministic counters at exit */
    int emulate_fork;        /* --emulate-fork: fork as Windows must, by a second VM (vm/image.c) */

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

/* interp.c */
void vm_grow_stack(VM *vm, size_t need);     /* make room for `need` values in total */
static inline void vm_push(VM *vm, Value v) {
    if (vm->sp >= vm->stack_cap) vm_grow_stack(vm, vm->sp + 1);
    vm->stack[vm->sp++] = v;
}
Value vm_pop(VM *vm);
Value *vm_top(VM *vm, size_t depth);  /* pointer to stack[sp-1-depth] */
void vm_fatal(VM *vm, const char *fmt, ...);
/* Every normal end of a run (halt, the exit primitive, an uncaught exception)
   goes through vm_exit, which flushes and prints what --count and --stats ask for. */
void vm_exit(VM *vm, int status);
int vm_raise(VM *vm, Value exn);            /* unwinds; returns 1 (never returns on uncaught) */
int vm_raise_builtin(VM *vm, int k);
int vm_run(VM *vm);
int vm_loop(VM *vm);                         /* the dispatch loop alone, from vm->pc */
void vm_cons(VM *vm);                        /* stack: ..., hd, tl  ->  ..., hd :: tl */
int values_equal(Value a, Value b);

/* image.c: fork as a second VM that is handed this one's state */
int64_t vm_fork(VM *vm);                     /* the child's pid in the parent, or -1 */
int vm_resume(VM *vm, const char *token, char *err, size_t errlen);   /* in the child */
int vm_save(VM *vm, const char *path);       /* the whole VM in a file (Runtime.save); 0 on failure */
int vm_restore(VM *vm, const char *path, char *err, size_t errlen);  /* runevm --restore FILE */

/* loader.c */
int load_program(VM *vm, const char *path, char *err, size_t errlen);
const LineEntry *line_at(const Program *p, uint32_t pc);
void vm_print_trace(VM *vm, FILE *out);
void disassemble(const Program *p, FILE *out);

/* byte length of an instruction, or 0 for an invalid opcode */
static inline int instr_length(uint8_t op) {
    if (op >= OP__COUNT) return 0;
    return 1 + 4 * op_nargs[op];
}

/* prims.c */
typedef int (*PrimFn)(VM *vm);
extern const PrimFn prim_table[PRIM__COUNT];

/* utilities */
static inline int32_t read_i32(const uint8_t *p) {
    uint32_t u = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
    return (int32_t)u;
}
static inline uint32_t read_u32(const uint8_t *p) { return (uint32_t)read_i32(p); }

#endif
