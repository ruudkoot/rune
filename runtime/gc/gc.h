/* runtime/gc: the collector, over a heap of chunks (docs/runtime.md, *The
   heap*; docs/plans/garbage-collector-v2.md, M2). What the files of this
   folder share with each other, with the heap's allocation (runtime/heap.c)
   and with images (runtime/image.c); the rest of the runtime knows the heap
   by vm.h alone. */
#ifndef RUNE_GC_H
#define RUNE_GC_H

#include "vm.h"

/* The census VM (runtime/census/census.h) carries an id word in every header, 8 bytes
   more per object: the sizes the stock VM counts and collects by are kept
   apart (STOCK, USED_STOCK), so that --count prints the stock numbers and
   a collection happens where the stock VM's would. */
#ifdef RUNE_CENSUS
#define STOCK(size) ((size) - 8)
#define USED_STOCK(vm) ((vm)->census_used_stock)
#define ADD_STOCK(vm, size) ((vm)->census_used_stock += STOCK(size))
#else
#define STOCK(size) (size)
#define USED_STOCK(vm) heap_used(vm)
#define ADD_STOCK(vm, size) ((void)0)
#endif

/* A chunk: CHUNK_SIZE bytes aligned to CHUNK_SIZE, this header first and the
   objects after it, side by side from the payload's start; or, for an object
   too large for one, a run of whole chunks that holds it alone. An object
   begins in the first CHUNK_SIZE bytes of its chunk, so the chunk of any
   pointer to an object is the pointer masked (chunk_of), with no table.
   A chunk aligned to 2 MiB is one that a huge page can back (D10, D11). */
#define CHUNK_SIZE ((size_t)2 << 20)
#define CHUNK_HEADER ((size_t)64)    /* the header, rounded up to a cache line */
struct Chunk {
    Chunk *next;     /* in the heap's list, or in the pool */
    size_t size;     /* the bytes of the mapping: CHUNK_SIZE, or a multiple of it for a large object */
    size_t used;     /* the bytes of objects in it (the last chunk's is alloc.used while it is filled) */
    uint64_t base;   /* an image's: the offset of its first object (runtime/image.c) */
};
typedef char chunk_header_fits[sizeof(Chunk) <= CHUNK_HEADER ? 1 : -1];

static inline Chunk *chunk_of(const void *p) { return (Chunk *)((uintptr_t)p & ~(uintptr_t)(CHUNK_SIZE - 1)); }
static inline char *chunk_payload(Chunk *c) { return (char *)c + CHUNK_HEADER; }
static inline size_t chunk_room(const Chunk *c) { return c->size - CHUNK_HEADER; }
/* the largest object a chunk of its own size holds; one larger gets a run */
#define CHUNK_ROOM (CHUNK_SIZE - CHUNK_HEADER)

/* chunk.c: chunks from the system and back; the heap's list */
Chunk *chunk_take(VM *vm, size_t bytes);    /* a chunk whose payload holds bytes, empty */
void chunk_give(VM *vm, Chunk *c);          /* to the pool, or back to the system */
void chunk_append(VM *vm, Chunk *c);        /* last in the heap's list */
void heap_chunks_release(VM *vm);           /* every chunk the VM has, at its end */
/* alloc made the view of the heap's last chunk again, as far as the heap's
   size allows (vm.h, AllocState) */
void alloc_view(VM *vm);
/* the heap's last chunk is full: the next, or a run of its own for an
   object larger than a chunk (which comes back; NULL otherwise) */
Obj *alloc_next(VM *vm, size_t size);

/* Walking the heap, object by object, chunk by chunk in the list's order:
   for (Chunk *c = heap_first(vm); c; c = c->next)
       for (size_t at = 0; at < chunk_used(vm, c); at += obj_size(o)) ... */
static inline Chunk *heap_first(const VM *vm) { return vm->gc.first; }
static inline size_t chunk_used(const VM *vm, const Chunk *c) { return c == vm->gc.last ? vm->alloc.used : c->used; }

/* Images (runtime/image.c): the heap is written as one run of objects in
   the list's order, a pointer as the offset of its object in that run;
   heap_number gives each chunk its base, heap_offset_of is a pointer's
   offset. Read back, heap_read_take gives the place for the next object of
   the run, and heap_relocate turns offsets into pointers. */
void heap_number(VM *vm);
static inline uint64_t heap_offset_of(const void *p) {
    Chunk *c = chunk_of(p);
    return c->base + (uint64_t)((const char *)p - chunk_payload(c));
}
void heap_read_begin(VM *vm, size_t size);
Obj *heap_read_take(VM *vm, size_t bytes);

/* copy.c: the copier, today's collector */
void collect_pass(VM *vm, size_t new_size);

/* check.c: --gc-verify */
void heap_verify(VM *vm, const char *when);

/* log.c: --gc-log, one line for a pass */
typedef struct PassMark {
    uint64_t bytes, objects, instrs, boxes, box_bytes;
    size_t used_before;
    int64_t t0, cpu0;
} PassMark;
void log_pass_begin(VM *vm, PassMark *m);
void log_pass_end(VM *vm, const PassMark *m, int64_t pause);

/* The roots, listed once, for the collector, the check and a heap that
   moved (heap_relocate): the value stack, and these. V takes the address of
   a value, O of a pointer to an object that is there. */
#define OTHER_ROOTS(vm, V, O) \
    do { \
        for (uint32_t i_ = 0; i_ < (vm)->prog.nglobals; i_++) V(&(vm)->globals[i_]); \
        for (uint32_t i_ = 0; i_ < (vm)->prog.nconsts; i_++) V(&(vm)->prog.consts[i_]); \
        if ((vm)->frames_active) \
            for (size_t i_ = 0; i_ <= (vm)->fp; i_++) \
                if ((vm)->frames[i_].closure) O(&(vm)->frames[i_].closure); \
        for (int i_ = 0; i_ < NUM_BUILTIN_EXNS; i_++) \
            if ((vm)->builtin_exns[i_]) O(&(vm)->builtin_exns[i_]); \
        for (int i_ = 0; i_ < REAL_BOXES; i_++) \
            if ((vm)->real_boxes[i_]) O(&(vm)->real_boxes[i_]); \
        for (size_t i_ = 0; i_ < (vm)->nhandles; i_++) V(&(vm)->handles[i_]); \
    } while (0)

#endif
