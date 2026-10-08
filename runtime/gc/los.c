/* The large-object space (docs/plans/garbage-collector-v2.md, D5): objects
   of los_min bytes or more, never moved. Its chunks are cut into units of
   4 KiB, whose map (gc.h) says the unit each one's object begins at, or
   that it is free; an object takes a run of whole units, the first that is
   free in its chunks, or a chunk run of its own when it is larger than a
   chunk holds. A full collection marks the objects it reaches, in the map's
   marks, and los_sweep frees the runs it did not, and a chunk that is
   empty. Every chunk carries cards (gc.h), so a store into a large object
   is remembered as one into any old object. */
#include "gc/gc.h"
#include "sys/sys.h"
#include <string.h>

static size_t units_of(size_t bytes) { return (bytes + ((size_t)1 << GC_UNIT_SHIFT) - 1) >> GC_UNIT_SHIFT; }
static size_t unit_of(Chunk *c, const Obj *o) { return (size_t)((const char *)o - chunk_payload(c)) >> GC_UNIT_SHIFT; }

/* a chunk of the space, its units all free */
static Chunk *los_chunk(VM *vm, size_t bytes) {
    Chunk *c = chunk_take(vm, bytes > CHUNK_ROOM / 2 ? bytes : 0, CHUNK_LOS);
    size_t n = chunk_room(c) >> GC_UNIT_SHIFT;
    memset(chunk_units(c), 0xFF, n * sizeof(uint16_t));
    c->units_free = n;
    c->next = vm->gc.los;
    vm->gc.los = c;
    return c;
}

/* the first run of want free units of c, taken; its first unit, or -1 */
static long take_run(Chunk *c, size_t want) {
    uint16_t *units = chunk_units(c);
    size_t n = chunk_room(c) >> GC_UNIT_SHIFT, run = 0;
    for (size_t u = 0; u < n; u++) {
        if (units[u] != LOS_FREE) { run = 0; continue; }
        if (++run < want) continue;
        size_t first = u + 1 - want;
        for (size_t v = first; v <= u; v++) units[v] = (uint16_t)first;
        c->units_free -= want;
        return (long)first;
    }
    return -1;
}

/* the place of an object of size bytes: the first run of units that holds
   it, in a chunk of the space or a new one */
static Obj *los_place(VM *vm, size_t size) {
    size_t want = units_of(size);
    if (size > CHUNK_ROOM / 2) {
        /* more than half a chunk: a chunk of its own, of its size (D5) */
        Chunk *c = los_chunk(vm, size);
        long first = take_run(c, want);
        (void)first;
        return (Obj *)chunk_payload(c);
    }
    for (Chunk *c = vm->gc.los; c; c = c->next) {
        if (c->size != CHUNK_SIZE || c->units_free < want) continue;   /* not one object's own */
        long first = take_run(c, want);
        if (first >= 0) return (Obj *)(chunk_payload(c) + ((size_t)first << GC_UNIT_SHIFT));
    }
    Chunk *c = los_chunk(vm, 0);
    long first = take_run(c, want);
    return (Obj *)(chunk_payload(c) + ((size_t)first << GC_UNIT_SHIFT));
}

/* ... marked where the low-pause collector's cycle marks: newer than its
   snapshot (cycle.c) */
Obj *los_alloc(VM *vm, size_t size) {
    vm->gc.los_bytes += size;
    Obj *o = los_place(vm, size);
    if (vm->gc.marking) {
        Chunk *c = chunk_of(o);
        chunk_marks(c)[unit_of(c, o)] = 1;
    }
    return o;
}

void los_mark(VM *vm, Obj *o) {
    Chunk *c = chunk_of(o);
    size_t u = unit_of(c, o);
    if (chunk_marks(c)[u]) return;
    chunk_marks(c)[u] = 1;
    if (obj_has_fields(o)) gc_queue(vm, o);
}

/* ---- walking ---- */

static Obj *first_in(Chunk *c, size_t u) {
    uint16_t *units = chunk_units(c);
    size_t n = chunk_room(c) >> GC_UNIT_SHIFT;
    for (; u < n; u++) if (units[u] == u) return (Obj *)(chunk_payload(c) + (u << GC_UNIT_SHIFT));
    return NULL;
}

Obj *los_next(VM *vm, Obj *o) {
    (void)vm;
    Chunk *c = chunk_of(o);
    Obj *n = first_in(c, unit_of(c, o) + units_of(obj_size(o)));
    for (c = c->next; !n && c; c = c->next) n = first_in(c, 0);
    return n;
}

Obj *los_first(VM *vm) {
    Obj *n = NULL;
    for (Chunk *c = vm->gc.los; !n && c; c = c->next) n = first_in(c, 0);
    return n;
}

/* After a full collection: every run it did not mark freed, every mark
   cleared, and every card (no young object is left to need one); a chunk
   left empty given back */
void los_sweep(VM *vm) {
    Chunk **at = &vm->gc.los;
    while (*at) {
        Chunk *c = *at;
        uint16_t *units = chunk_units(c);
        uint8_t *marks = chunk_marks(c);
        size_t n = chunk_room(c) >> GC_UNIT_SHIFT;
        for (size_t u = 0; u < n; ) {
            if (units[u] != u) { u++; continue; }
            Obj *o = (Obj *)(chunk_payload(c) + (u << GC_UNIT_SHIFT));
            size_t size = obj_size(o), k = units_of(size);
            if (!marks[u]) {
                for (size_t v = u; v < u + k && v < n; v++) units[v] = LOS_FREE;
                c->units_free += k;
                vm->gc.los_bytes -= size;
            }
            marks[u] = 0;
            u += k;
        }
        memset(chunk_cards(c), 0, c->size >> GC_CARD_SHIFT);
        memset(chunk_dirty(c), 0, c->size >> GC_BLOCK_SHIFT);
        if (c->units_free == n) {
            *at = c->next;
            chunk_give(vm, c);
        } else at = &c->next;
    }
}

void los_release(VM *vm) {
    for (Chunk *c = vm->gc.los, *n; c; c = n) { n = c->next; sys_mem_release(c, c->size); }
    vm->gc.los = NULL;
    vm->gc.los_bytes = 0;
}
