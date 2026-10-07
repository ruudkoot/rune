/* runtime/gc: the collector, over a heap of chunks (docs/runtime.md, *The
   heap*; docs/plans/garbage-collector-v2.md, M2 and M3). What the files of
   this folder share with each other, with the heap's allocation
   (runtime/heap.c) and with images (runtime/image.c); the rest of the
   runtime knows the heap by vm.h alone. */
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

/* A chunk: CHUNK_SIZE bytes aligned to CHUNK_SIZE, its header and tables
   first and its objects after them, from its payload; or a run of whole
   chunks, for a nursery or for an object too large for one. An object
   begins in the first CHUNK_SIZE bytes of its chunk (but in a nursery's),
   so the chunk of any pointer to an object is the pointer masked
   (chunk_of), with no table. A chunk aligned to 2 MiB is one that a huge
   page can back (D10, D11).

   The tables, at offsets from the chunk that its size gives:
   - the cards (D6), a byte for every 512 bytes of the chunk, by the
     offset from the chunk, at GC_CARDS: 1 where a field there was given a
     pointer into the nursery since the last minor collection;
   - the dirty bytes, one for every 32 KiB, at dirty_at: 1 where one of
     its cards is, so that a minor collection visits only those;
   - the crossing map, for an old chunk, an entry for every card: the
     words back from the card's first byte to the start of the object that
     covers it (objects of an old chunk are smaller than los_min, so an
     entry of 16 bits holds it);
   - the units of the large-object space (los.c), one for every 4 KiB: the
     unit its object begins at, or LOS_FREE; and a mark for every unit.
   Every chunk has them all, so that one goes from the pool to any use. */
#define CHUNK_SIZE ((size_t)2 << 20)
#define GC_CARD_SHIFT 9
#define GC_BLOCK_SHIFT 15
#define GC_UNIT_SHIFT 12
#define GC_CARDS ((size_t)128)
enum { CHUNK_OLD, CHUNK_LOS, CHUNK_NURSERY };
struct Chunk {
    uint32_t dirty_at;   /* the dirty bytes' offset from the chunk: first, for compiled code's barrier (masm.c) */
    uint32_t payload;    /* the payload's */
    Chunk *next;     /* in the heap's list, the large-object space's, or the pool */
    size_t size;     /* the bytes of the mapping: CHUNK_SIZE, or a multiple of it */
    size_t used;     /* the bytes of objects in it (the last chunk's is alloc.used while alloc fills it) */
    uint64_t base;   /* an image's: the offset of its first object (runtime/image.c) */
    uint32_t cross_at, units_at, marks_at;
    uint32_t kind;
    size_t units_free;   /* a large-object chunk's free units */
};
typedef char chunk_header_fits[sizeof(Chunk) <= GC_CARDS ? 1 : -1];

/* the layout of a chunk of size bytes: the tables after the header, and the
   payload from the next 4 KiB, so that the units of the large-object space
   are pages */
#define CHUNK_TABLES(size) (GC_CARDS + ((size) >> GC_CARD_SHIFT) + ((size) >> GC_BLOCK_SHIFT) \
                            + 2 * ((size) >> GC_CARD_SHIFT) + 3 * ((size) >> GC_UNIT_SHIFT))
#define CHUNK_PAYLOAD(size) ((CHUNK_TABLES(size) + 4095) & ~(size_t)4095)
/* the largest object a chunk holds; one larger gets a run of its own */
#define CHUNK_ROOM (CHUNK_SIZE - CHUNK_PAYLOAD(CHUNK_SIZE))

static inline Chunk *chunk_of(const void *p) { return (Chunk *)((uintptr_t)p & ~(uintptr_t)(CHUNK_SIZE - 1)); }
static inline char *chunk_payload(Chunk *c) { return (char *)c + c->payload; }
static inline size_t chunk_room(const Chunk *c) { return c->size - c->payload; }
static inline uint8_t *chunk_cards(Chunk *c) { return (uint8_t *)c + GC_CARDS; }
static inline uint8_t *chunk_dirty(Chunk *c) { return (uint8_t *)c + c->dirty_at; }
static inline uint16_t *chunk_cross(Chunk *c) { return (uint16_t *)(void *)((char *)c + c->cross_at); }
static inline uint16_t *chunk_units(Chunk *c) { return (uint16_t *)(void *)((char *)c + c->units_at); }
static inline uint8_t *chunk_marks(Chunk *c) { return (uint8_t *)c + c->marks_at; }

/* chunk.c: chunks from the system and back; the heap's list */
Chunk *chunk_take(VM *vm, size_t bytes, int kind);   /* a chunk whose payload holds bytes, empty, its tables clear */
void chunk_give(VM *vm, Chunk *c);          /* to the pool, or back to the system */
void chunk_append(VM *vm, Chunk *c);        /* last in the heap's list */
void heap_chunks_release(VM *vm);           /* every chunk the VM has, at its end */
/* alloc made again the room the fast paths bump into (vm.h, AllocState):
   the nursery's, or, with none, the heap's last chunk's, as far as the
   heap's size allows */
void alloc_view(VM *vm);
/* with no nursery: the heap's last chunk is full; the next, or a run of its
   own for an object larger than a chunk; the object's place */
Obj *alloc_next(VM *vm, size_t size);
/* an object of size bytes placed at offset at of an old chunk: its cards'
   entries in the crossing map */
void chunk_note(Chunk *c, size_t at, size_t size);

/* Walking the old space, object by object, chunk by chunk in the list's order:
   for (Chunk *c = heap_first(vm); c; c = c->next)
       for (size_t at = 0; at < chunk_used(vm, c); at += obj_size(o)) ... */
static inline Chunk *heap_first(const VM *vm) { return vm->gc.first; }
static inline size_t chunk_used(const VM *vm, const Chunk *c) {
    return c == vm->gc.last && !vm->gc.nursery ? vm->alloc.used : c->used;
}

/* The nursery (minor.c; D2): one region of nursery_size bytes, which alloc
   is the room of; its objects are copied into the old space by a minor
   collection, every one that is reached (promotion at the first survival).
   The old space is the heap's chunks, which a full collection copies
   (copy.c), and the large-object space (los.c), which it marks. */
void nursery_start(VM *vm, size_t bytes);   /* the nursery made, of bytes; 0: none */
void collect_minor(VM *vm);
void gc_queue(VM *vm, Obj *o);              /* an old object whose fields a collection is to scan */
void gc_born(VM *vm, Obj *o);               /* a large object with fields, made: scanned whole by the next minor */
static inline int gc_in_nursery(const VM *vm, const void *p) {
    return vm->gc.nursery && (uintptr_t)((const char *)p - vm->alloc.from) < (uintptr_t)vm->alloc.size;
}
/* the card of field f of the old object o, and its block's dirty byte (D6) */
static inline void gc_remember(Obj *o, Value *f) {
    Chunk *c = chunk_of(o);
    uintptr_t at = (uintptr_t)((char *)f - (char *)c);
    chunk_cards(c)[at >> GC_CARD_SHIFT] = 1;
    chunk_dirty(c)[at >> GC_BLOCK_SHIFT] = 1;
}

/* los.c: the large-object space (D5): objects of los_min bytes or more, in
   runs of 4 KiB units of its chunks (a chunk run of their own when larger
   than a chunk holds), never moved; marked by a full collection, which
   frees the runs it did not mark. One with fields made since the last
   minor collection is remembered whole, its fill having no barrier. */
#define LOS_FREE 0xFFFFu
Obj *los_alloc(VM *vm, size_t size);        /* the place of an object of size bytes */
void los_mark(VM *vm, Obj *o);              /* a full collection reached it: marked, its fields to scan */
void los_sweep(VM *vm);                     /* after a full collection: the runs not marked freed */
void los_release(VM *vm);
/* walking the large objects: los_first gives the first, los_next the one
   after o, NULL at the end */
Obj *los_first(VM *vm);
Obj *los_next(VM *vm, Obj *o);

/* Images (runtime/image.c): the heap is written as one run of objects in
   the old space's order, then the large objects, then the nursery's, a
   pointer as the offset of its object in that run; heap_number gives each
   chunk and large object its base, heap_offset_of is a pointer's offset.
   Read back, heap_read_take gives the place for the next object of the
   run (all of them old), and heap_relocate turns offsets into pointers. */
void heap_number(VM *vm);
uint64_t heap_offset_of(VM *vm, const void *p);
void heap_read_begin(VM *vm, size_t size);
Obj *heap_read_take(VM *vm, size_t bytes);

/* copy.c: the copier: with no nursery the collector; with one, the full
   collection of the old space and the nursery */
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
void log_pass_end(VM *vm, const PassMark *m, const char *kind, int64_t pause);

/* The roots, listed once, for the collector, the check and a heap that
   moved (heap_relocate): the value stack, and these. V takes the address of
   a value, O of a pointer to an object that is there. A minor collection
   takes the frames' closures from the stack's watermark up (OTHER_ROOTS_FROM):
   those below it have not changed since the last. */
#define OTHER_ROOTS(vm, V, O) OTHER_ROOTS_FROM(vm, V, O, 0)
#define OTHER_ROOTS_FROM(vm, V, O, frame0) \
    do { \
        for (uint32_t i_ = 0; i_ < (vm)->prog.nglobals; i_++) V(&(vm)->globals[i_]); \
        for (uint32_t i_ = 0; i_ < (vm)->prog.nconsts; i_++) V(&(vm)->prog.consts[i_]); \
        if ((vm)->frames_active) \
            for (size_t i_ = (frame0); i_ <= (vm)->fp; i_++) \
                if ((vm)->frames[i_].closure) O(&(vm)->frames[i_].closure); \
        for (int i_ = 0; i_ < NUM_BUILTIN_EXNS; i_++) \
            if ((vm)->builtin_exns[i_]) O(&(vm)->builtin_exns[i_]); \
        for (int i_ = 0; i_ < REAL_BOXES; i_++) \
            if ((vm)->real_boxes[i_]) O(&(vm)->real_boxes[i_]); \
        for (size_t i_ = 0; i_ < (vm)->nhandles; i_++) V(&(vm)->handles[i_]); \
    } while (0)

#endif
