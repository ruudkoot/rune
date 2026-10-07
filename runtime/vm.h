/* Rune virtual machine: shared declarations. C99, no dependencies beyond libc. */
#ifndef RUNE_VM_H
#define RUNE_VM_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "isa.h"
#include "prims_table.h"

/* ---------------------------------------------------------------- values */

/* The layout of a value and of an object: runtime/value.h, the one place that
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
    uint32_t maxstack;   /* how deep its operand stack goes: the loader works it out (runtime/stack/isa_stack.c) */
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
    /* What is live where a frame of the function waits for a call
       (runtime/register/live.c), made when the collector first asks: the
       pcs calls return to, in a table of nlive slots by a hash of the pc,
       and the registers live at each. Not in a file or an image; they go
       with the program (program_free_meta). */
    int live_made;
    uint32_t nlive;
    uint32_t *live_pc;
    uint64_t *live_at;
} Function;

/* What a register holds, as the compiler says (Low.rep; the numbers are the
   file's) */
enum Rep { REP_ANY = 0, REP_INT, REP_WORD, REP_REAL, REP_CHAR, REP_CON0, REP_PTR, REP_CON, REP_UNIT,
           REP_INT64, REP_WORD64,   /* Int64.int, Word64.word: an immediate or a K_BOX */
           REP__COUNT };

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

/* the kinds of a constant, as a bytecode file numbers them */
enum ConstKind { CONST_INT = 0, CONST_WORD = 1, CONST_REAL = 2, CONST_STRING = 3, CONST_CHAR = 4,
                 CONST_INT64 = 5, CONST_WORD64 = 6, CONST__COUNT };

typedef struct Program {
    uint32_t nconsts;
    Value *consts;
    uint8_t *const_kinds;   /* what the bytecode said each is (CONST_INT ...): a value does not say, and an image must */
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
/* the representations section freed with the program (runtime/loader.c) */
void program_free_meta(Program *p);

/* ---------------------------------------------------------------- machine */

typedef struct Frame {
    uint32_t func;
    uint32_t ret_pc;
    size_t base;     /* stack index of local 0 */
    Obj *closure;    /* NULL for the toplevel */
    /* In a program runeopt made (runtime/native/native.c), the native code at ret_pc.
       An image does not carry it: it is an address of one process. */
    const void *native_ret;
    /* In runtime/register, the register of the caller's RESULT, which the return
       writes into, or UINT32_MAX where the caller takes the value from the
       stack (docs/plans/jit.md, M7). Not in an image: made again from the
       code at ret_pc when one is read (runtime/register/interp.c, make_room). */
    uint32_t result;
} Frame;

typedef struct Handler {
    uint32_t pc;
    size_t sp;
    size_t fp;
    /* In runtime/register, the native code of the handler where the frame that
       installed it runs compiled (runtime/register/jit.h); NULL for the interpreter.
       An image does not carry it. */
    const void *native;
} Handler;

/* The --jit options of runtime/register (runtime/register/jit.h, docs/plans/jit.md): the mode;
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

/* Where the next object goes: the state of the thread that allocates. There
   is one thread, and one of these, in the VM; a nursery of a thread's own or
   a buffer it bumps in is this struct and the fast path of vm_alloc, of the
   JIT's ms_alloc and of runeopt's template, changed together
   (docs/plans/heap-layout.md, M7; D6, D8). It is the room the fast paths
   bump into, from..from+size, of which used is taken: the chunk of the heap
   being filled (runtime/gc/), as far as the heap's size allows, so that an
   allocation leaves the fast path where the chunk is full or a collection
   is due (runtime/heap.c, vm_alloc). */
typedef struct AllocState {
    char *from;      /* the payload of the chunk objects go into */
    size_t size;     /* how far into it they may go */
    size_t used;     /* how much of it is taken */
} AllocState;

typedef struct Chunk Chunk;   /* runtime/gc/gc.h */
/* where a run of an image's objects was read to (runtime/gc/chunk.c, heap_read_take) */
typedef struct HeapSeg { uint64_t base; char *at; size_t len; } HeapSeg;

/* The collector's own (runtime/gc/): nothing of it is a variable of the
   file, so every VM of a process collects by itself. The heap is a list of
   chunks of 2 MiB, the one alloc fills last; its size is what a semispace
   was, the bytes of objects it may hold before it is collected, and
   collected into a list of its own (runtime/gc/copy.c). */
typedef struct GcState {
    Chunk *first, *last; /* the heap's chunks, in the order they were filled; last is alloc's */
    size_t closed;       /* the bytes of objects in every chunk but last */
    size_t size;         /* the heap's size: collected when its objects would pass it */
    Chunk *pool;         /* chunks given back by a collection, for the next to take */
    size_t pooled;
    void *hint;          /* where the next chunk is asked for (sys_mem_reserve) */
    size_t to_used;      /* during a collection: the bytes copied */
    size_t to_boxes;     /* of them, the boxes (box_bytes_live) */
    size_t to_used_stock;   /* the census VM's count of to_used by the stock sizes */
    int reloc_ok;        /* heap_relocate */
    /* The nursery (runtime/gc/minor.c; docs/plans/garbage-collector-v2.md,
       M3): its chunk, and the bytes it holds, alloc's room; none (NULL, 0)
       makes alloc the room of the heap's last chunk */
    Chunk *nursery;
    size_t nursery_size;
    /* The large-object space (runtime/gc/los.c): objects of los_min bytes
       or more, in its chunks; its bytes count with the old space's; those
       with fields made since the last minor collection, and a full
       collection's to scan */
    Chunk *los;
    size_t los_min, los_bytes;
    Obj **born;
    size_t nborn, born_cap;
    Obj **queue;
    size_t nqueue, queue_cap;
    uint64_t minors, fulls, promoted, large_objects, large_bytes;
    size_t old_boxes;    /* of box_bytes_live, the old space's (the nursery's die with it) */
    HeapSeg *segs;       /* an image read back, until heap_relocate */
    size_t nsegs, segs_cap;
} GcState;

typedef struct VM {
    /* First what compiled code reads and writes most, in 128 bytes:
       runtime/register's JIT (and runeopt's code) names a field by its
       offset from the VM, and on x86-64 an offset below 128 makes every
       instruction that names it three bytes shorter -- a tenth of the
       code the compiler compiles to was those bytes. The order of the
       rest is nothing's concern. */
    uint64_t instructions;   /* executed so far */
    uint32_t pc;
    int checked;             /* --checked: DECON tests its tag (decision D14), for the test suites */
    Frame *frames;
    size_t fp, frames_cap;   /* fp = index of current frame; frames_cap capacity */
    Value *stack;
    size_t sp, stack_cap;
    AllocState alloc;        /* where the next object goes (runtime/gc/) */
    uint64_t bytes_allocated;  /* not size_t: --count prints the same where it is 32 bits */
    uint64_t objects_allocated;
    size_t gc_stress;        /* --gc-stress N: collect before every Nth allocation; 0 = off */
    /* the stack's watermark (runtime/gc/minor.c; docs/plans/garbage-collector-v2.md,
       D9): no frame below it has run since the last minor collection, so
       its slots hold no young pointer; every pop of a frame lowers it to
       the frame it returns to (vm_frame_pop) */
    size_t fp_low;
    Value *globals;
    uint8_t *global_set;
    int gc_verify;           /* --gc-verify: the heap checked before and after every collection (runtime/gc/check.c) */

    Program prog;

    size_t stack_limit;      /* the most bytes the value stack, the frames or the handlers may take (--stack-size): a runaway recursion stops here, not at the machine's memory */

    int frames_active;       /* 1 once the toplevel frame exists */

    Handler *handlers;
    size_t hp, handlers_cap;

    Obj *builtin_exns[NUM_BUILTIN_EXNS];

    GcState gc;              /* the collector's own */
#ifdef RUNE_CENSUS
    size_t census_used_stock;  /* alloc.used as the stock VM would count it (8-byte headers): the collector's trigger */
#endif
    size_t gc_count;
    size_t live_last;        /* bytes the last collection kept, and the one before it: */
    size_t live_before;      /* vm_gc guesses from them whether the heap must grow */
    int64_t gc_user_us;      /* processor time spent collecting, in microseconds */
    int64_t gc_sys_us;
    int64_t gc_longest_us;   /* the longest of the collections, both times together (--stats): what the program waited at once */
    /* What --gc-log and RUNE_MEMSTAT report (runtime/heap.c; docs/runtime.md):
       the log, the calls of vm_gc, the monotonic time of every collection in
       all and of the longest, and what the pass in progress has counted */
    FILE *gc_log;
    int64_t gc_log_t0;       /* sys_clock_ns when the log was opened */
    uint64_t gc_calls;
    int64_t gc_ns;
    int64_t gc_longest_ns;
    struct {
        uint64_t objects;    /* objects copied */
        uint64_t slots;      /* slots of the value stack looked at */
        uint64_t live_slots; /* of them, the ones that were roots (the rest were dead registers) */
        uint64_t frames;     /* waiting frames whose live registers were asked for */
        uint64_t other_roots;
        uint64_t promoted;   /* bytes copied out of the nursery */
        uint64_t cards_dirty;    /* a minor's dirty cards, */
        uint64_t cards_scanned;  /* and the cards of the dirty blocks it looked at */
        uint64_t remembered;     /* large objects scanned whole */
        uint64_t cards_young;    /* dirty cards that held a pointer into the nursery */
        uint64_t fields;         /* fields scanned in dirty cards and remembered objects */
    } gc_counts;
    /* The boxes of the representation -- a real with no immediate, an int
       or a word past 63 bits under RUNE_INT64 -- are counted apart: they
       are the layout's, not the program's, and where one is made is the
       engine's (tier 2 boxes a real when a safepoint wants its word, the
       loop when it is produced), so --count leaves them out and stays the
       same on every engine and under every layout; --stats reports them. */
    uint64_t boxes_allocated;
    uint64_t box_bytes_allocated;
    size_t box_bytes_live;     /* of alloc.used, what is boxes: Runtime.stats's live leaves them out, as its bytes do */
    uint64_t copied;         /* bytes every collection copied, in all (--stats) */
    size_t max_live;         /* the most a collection kept (--stats) */
    unsigned heap_fill;      /* --heap-fill P: the heap grows until at most P% of it is in use
                                after a collection; 50 unless the option says otherwise */
    size_t heap_limit;       /* maximum semispace size; 0 = unlimited */
    size_t equality_work;    /* comparison steps; 0 = the default 1000000 */

    int trace;
    int stats;
    int count;               /* --count: report the deterministic counters at exit */
    int emulate_fork;        /* --emulate-fork: fork as Windows must, by a second VM (runtime/image.c) */
    int native;              /* a program runeopt made, whose code is not bytecode (runtime/native/native.c) */
    JitOptions jit;          /* the --jit options, runtime/register's (runtime/register/jit.h); all 0 in runevm-stack */
    uint64_t jit_fspill[32]; /* tier 2's reals in their homes, raw, across the helper that boxes one: a cell for each of the machine's registers, by its number (jit/masm.c) */
    uint64_t jit_gspill[32]; /* and its general homes, an int's or a word's 64 bits among them, and the number being boxed where it is in no home */

    int argc;
    char **argv;             /* arguments after the bytecode file */
    const char *progname;
    int owns_args;           /* argv and progname were read from an image (runtime/image.c) */

    /* open files indexed by handle: 0 stdin, 1 stdout, 2 stderr (never closed);
       handles are never reused, a closed slot is NULL */
    FILE **files;
    uint8_t *file_modes;     /* each file's mode of file_open, which an image of the VM carries */
    char **file_paths;       /* the path each was opened by, for an image that a process does not
                                inherit descriptors from (Runtime.save); NULL for the standard streams */
    size_t nfiles, files_cap;
    int io_errno;            /* errno of the last failed file_open / file_write */
    Obj *real_boxes[REAL_BOXES];   /* the boxes of the reals that have no immediate and are everywhere
                                      (value.h): made as the VM starts, roots, in an image */
    /* Which registers of function FUNC are live while a frame of it waits
       for the call that returns to RET_PC (bit r for register r; those past
       the 64th are live), for the collector's roots (heap.c). NULL where
       the engine does not say, and every slot of the stack is a root: the
       stack bytecode, a program runeopt made. */
    uint64_t (*frame_live)(struct VM *vm, uint32_t func, uint32_t ret_pc);
    /* The values that C holds across a collection (docs/plans/heap-layout.md,
       D9 and M8): a handle is an index here, the table is a root, and what a
       handle names is found again after the object moved. The free entries
       are a list through the table (each holds the next one's number as an
       immediate; handles_free is the first's, plus one, 0 for none). An
       image has no handles: they are a process's. */
    Value *handles;
    size_t nhandles, handles_cap, handles_free;
#ifdef RUNE_BARRIER_CARDS
    uint8_t *jit_cards;      /* the measuring barrier's table, where compiled code finds it (value.h, BARRIER) */
#endif
} VM;

/* Whether p points into the room objects are made in (alloc). Young and
   old are told apart by address, not by a bit of the header
   (docs/plans/heap-layout.md, D7): this is the test a nursery will make, of
   its own range, when alloc is the nursery (docs/plans/garbage-collector-v2.md,
   M3). Nothing asks it yet. */
static inline int heap_is_young(const VM *vm, const void *p) {
    return (uintptr_t)((const char *)p - vm->alloc.from) < (uintptr_t)vm->alloc.size;
}
/* The bytes of objects in the heap (boxes too), as the collector counts them:
   the old space's chunks, the large objects and alloc's room */
static inline size_t heap_used(const VM *vm) { return vm->gc.closed + vm->gc.los_bytes + vm->alloc.used; }

/* THE BARRIER's body (runtime/value.h, obj_set_field;
   docs/plans/garbage-collector-v2.md, D6): where there is a nursery, a
   pointer into it stored into an object that is not in it marks the card
   of the field (runtime/gc/minor.c, gc_write), so that the next minor
   collection finds it; every other store is the store alone. And the
   measuring card mark, in the build that measures one. */
void gc_write(Obj *o, Value *f);
static inline void gc_barrier(VM *vm, Obj *o, Value *f, Value v) {
#ifdef RUNE_BARRIER_CARDS
    rune_cards[((uintptr_t)f >> CARD_SHIFT) & (CARD_COUNT - 1)] = 1;
#endif
    if (vm->gc.nursery && val_is_ptr(v) && heap_is_young(vm, val_ptr(v)) && !heap_is_young(vm, o)) gc_write(o, f);
}

/* heap.c */
void heap_init(VM *vm, size_t size);   /* a heap of that size (runtime/gc/) */
void heap_nursery(VM *vm, size_t bytes);   /* --nursery: a nursery of bytes before the heap (0: none) */
Obj *vm_alloc(VM *vm, uint8_t kind, uint16_t contag, uint32_t len, size_t payload_bytes);
Obj *vm_alloc_fields(VM *vm, uint8_t kind, uint16_t contag, uint32_t nfields);
Obj *vm_alloc_string(VM *vm, uint32_t len);
Obj *vm_string_from(VM *vm, const char *s, uint32_t len);
/* header and payload, rounded as the heap lays it out: inline, being asked
   of every object every collection visits */
static inline size_t obj_size(const Obj *o) { return obj_size_of(obj_kind(o), obj_len(o)); }
void vm_gc(VM *vm, size_t needed);
int heap_relocate(VM *vm, uintptr_t old_base);  /* after an image is read: 0 when it is not sound */
/* --gc-log FILE: one line per pass of the collector into FILE, and its last
   lines when the VM exits (docs/runtime.md, *Watching it*) */
void heap_log_open(VM *vm, const char *path);
void heap_log_close(VM *vm);
/* --gc-verify: what of the heap does not hold, and where, or NULL (docs/runtime.md, *Watching it*) */
const char *heap_check(VM *vm, const void **at);
/* The handles (VM.handles): a value kept for C across collections. */
size_t vm_handle_new(VM *vm, Value v);            /* a handle for the value */
Value vm_handle_get(const VM *vm, size_t h);      /* the value, where it is now */
void vm_handle_set(VM *vm, size_t h, Value v);
void vm_handle_free(VM *vm, size_t h);
/* An array of bytes or of reals for C to keep a pointer to across calls
   that may collect: no object stays where it is under the copier, so C gets
   a copy that does (D9: copying in and out around the call, until there is
   a space that does not move), and gives it back. vm_pin copies the
   object's payload out and returns the copy, NULL where there is no memory
   or the handle names no such array; vm_unpin copies it back into the
   object, wherever it is by then, and frees the copy. */
void *vm_pin(VM *vm, size_t h, size_t *bytes);
void vm_unpin(VM *vm, size_t h, void *copy);
#ifdef RUNE_BARRIER_CARDS
void heap_cards(VM *vm);
#endif

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
    if (!val_is(v, T_PTR) || !val_ptr(v) || obj_kind(val_ptr(v)) != kind) vm_fatal(vm, "expected %s", what);
    return val_ptr(v);
}
static inline void vm_push_frame(VM *vm, uint32_t func, Obj *closure, uint32_t ret_pc, size_t base) {
    size_t idx = vm->frames_active ? vm->fp + 1 : 0;
    if (idx >= vm->frames_cap) vm_grow_frames(vm);
    vm->frames[idx].func = func;
    vm->frames[idx].closure = closure;
    vm->frames[idx].ret_pc = ret_pc;
    vm->frames[idx].base = base;
    vm->frames[idx].native_ret = NULL;   /* native code sets its own (runtime/native/native.c, runtime/register) */
    vm->frames[idx].result = UINT32_MAX; /* runtime/register's loop and code set it */
    vm->fp = idx;
    vm->frames_active = 1;
}
/* The frame on top popped, in every engine (and the frames down to a
   handler's, vm_raise): the watermark follows the frame that runs again */
static inline void vm_frame_pop(VM *vm) {
    vm->fp--;
    if (vm->fp < vm->fp_low) vm->fp_low = vm->fp;
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
   runtime/register takes and runevm-stack refuses: 1 when the option is taken, 0 when it is
   not one. vm_jit_check runs --jit-check and gives the exit status. */
int vm_jit_arg(const char *arg, JitOptions *jit, int *check);
int vm_jit_check(void);
/* RUNEVM_JIT in the environment, the mode where no --jit= is given: taken
   by runtime/register, ignored by runevm-stack (the compiler runs on it); 0 for a mode
   that is none. */
int vm_jit_env(const char *mode, int *out);

/* In a program runeopt made (runtime/native/native.c), whether a world read from an
   image runs the program it carries; NULL in runevm-stack, which runs any. */
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

/* What each VM's instruction set gives (runtime/stack/isa_stack.c, runtime/register/isa_regs.c):
   the fingerprint an .rbc must carry, and the first bytes of an image. */
#define ISA_IMAGE_MAGIC_SIZE sizeof("runevm image 10 isa 00000000")
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

/* prims.c */
/* What a primitive gives back to the dispatch loop: 0 for an ordinary return
   (`ret`), 1 where it raised, and this where it has replaced the program the
   loop is running (runtime/image.c, Runtime.restore). */
#define PRIM_NEW_WORLD 2
typedef int (*PrimFn)(VM *vm);
extern const PrimFn prim_table[PRIM__COUNT];

/* utilities */
static inline int32_t read_i32(const uint8_t *p) {
    uint32_t u = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
    return (int32_t)u;
}
static inline uint32_t read_u32(const uint8_t *p) { return (uint32_t)read_i32(p); }

#include "census/census.h"

#endif
