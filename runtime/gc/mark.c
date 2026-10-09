/* The frame of the non-moving old spaces (docs/plans/garbage-collector-v2.md,
   M4): chunks whose objects stay where they are placed, and the full
   collection that marks them. A chunk's bits (gc.h) are set where an
   object is placed -- promoted by a minor collection, by a full one, or
   read from an image -- and a full collection clears them and sets them
   again for what it reaches, so that they are at once its marks, the
   starts of its objects and what a walk of it visits: a dead object or a
   hole is never parsed. Its own placement bumps through a chunk and takes a
   chunk again only when a full collection found nothing in it; the old
   spaces measured at the gate place into the holes of their chunks. */
#include "gc/gc.h"
#include "sys/sys.h"
#include <string.h>

/* ---- the bits ---- */

size_t chunk_bits_next(Chunk *c, size_t at) {
    size_t off = c->payload + at, end = c->payload + c->top;
    if (off >= end) return CHUNK_END;
    const uint64_t *bits = chunk_bits(c);
    size_t w = off >> 9, last = (end - 1) >> 9;
    uint64_t word = bits[w] & (~(uint64_t)0 << (off >> 3 & 63));
    for (;;) {
        if (word) {
            size_t found = ((w << 6) + (size_t)__builtin_ctzll(word)) << 3;
            return found < end ? found - c->payload : CHUNK_END;
        }
        if (++w > last) return CHUNK_END;
        word = bits[w];
    }
}

/* The object whose bytes hold payload offset at: the last bit at or before
   it, if that object reaches it. No object of these chunks is as large as
   a large one (8 KiB at most: 16 words of bits), so the search goes no
   further back. */
size_t chunk_object_covering(Chunk *c, size_t at) {
    size_t off = c->payload + at;
    const uint64_t *bits = chunk_bits(c);
    size_t w = off >> 9, lowest = c->payload >> 9;
    uint64_t word = bits[w] & (~(uint64_t)0 >> (63 - (off >> 3 & 63)));
    for (;;) {
        if (word) {
            size_t found = ((w << 6) + 63 - (size_t)__builtin_clzll(word)) << 3;
            return found + obj_size((Obj *)((char *)c + found)) > off ? found - c->payload : CHUNK_END;
        }
        if (w == lowest || (off >> 9) - w > 16) return CHUNK_END;
        word = bits[--w];
    }
}

static void bits_clear(Chunk *c) { memset(chunk_bits(c), 0, c->size >> 6); }

/* ---- placement ---- */

static Chunk *mark_chunk(VM *vm) {
    Chunk *c = chunk_take(vm, 0, CHUNK_MARK);
    bits_clear(c);
    c->top = 0;
    chunk_append(vm, c);
    return c;
}

Obj *mark_place(VM *vm, size_t size) {
    Chunk *c = vm->gc.last;
    if (!c || c->kind != CHUNK_MARK || size > chunk_room(c) - c->top) c = mark_chunk(vm);
    size_t at = c->top;
    c->top += size;
    c->used += size;
    vm->gc.closed += size;
    chunk_bit_set(c, c->payload + at);
    return (Obj *)(chunk_payload(c) + at);
}

/* The place of an object put into the old space: by the old space's own
   placement (the frame's, mark_place, or a measured one's) */
Obj *old_place(VM *vm, size_t size) {
    switch (vm->gc.old_kind) {
    case OLD_IMMIX: return immix_place(vm, size);
    case OLD_SEGFIT: return segfit_place(vm, size);
    default: return mark_place(vm, size);
    }
}

/* The heap's chunks made non-moving where a nursery is made in front of a
   heap that has objects already (heap_init's, an image's first): their
   objects lie side by side, and each gets its bit. */
void mark_adopt(VM *vm) {
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        if (c->kind == CHUNK_MARK) continue;
        bits_clear(c);
        c->kind = CHUNK_MARK;
        c->top = c->used;
        for (size_t at = 0; at < c->used; at += obj_size((Obj *)(chunk_payload(c) + at)))
            chunk_bit_set(c, c->payload + at);
    }
    if (vm->gc.old_kind == OLD_IMMIX) immix_adopted(vm);
    if (vm->gc.old_kind == OLD_SEGFIT) segfit_adopted(vm);
}

/* ---- the full collection ---- */

static Obj *mark_obj(VM *vm, Obj *o) {
    if (gc_in_nursery(vm, o)) {
        /* a young object reached: promoted, as a minor collection would */
        if (obj_forwarded(o)) return obj_forwarding(o);
        size_t size = obj_size(o);
        Obj *n;
        if (size >= vm->gc.los_min) {
            n = los_alloc(vm, size);
            memcpy(n, o, size);
            los_mark(vm, n);
        } else {
            n = old_place(vm, size);
            memcpy(n, o, size);
            if (obj_has_fields(n)) gc_queue(vm, n);
        }
        if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) vm->gc.to_boxes += size;
        vm->gc_counts.objects++;
        vm->gc.to_used += size;
        obj_forward(o, n);
        return n;
    }
    Chunk *c = chunk_of(o);
    if (c->kind == CHUNK_LOS) { los_mark(vm, o); return o; }
    size_t off = (size_t)((char *)o - (char *)c);
    if (!chunk_bit(c, off)) {
        if (obj_forwarded(o)) return obj_forwarding(o);   /* evacuated already (immix.c) */
        size_t size = obj_size(o);
        if (vm->gc.old_kind == OLD_IMMIX) {
            Obj *n = immix_marked(vm, c, o, size);
            if (n != o) {
                /* evacuated: placed, its bit set, to be scanned there */
                if (obj_kind(n) == K_REAL || obj_kind(n) == K_BOX) vm->gc.to_boxes += size;
                vm->gc_counts.objects++;
                vm->gc.to_used += size;
                if (obj_has_fields(n)) gc_queue(vm, n);
                return n;
            }
        }
        chunk_bit_set(c, off);
        c->used += size;
        vm->gc.closed += size;
        if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) vm->gc.to_boxes += size;
        vm->gc_counts.objects++;
        if (obj_has_fields(o)) gc_queue(vm, o);
    }
    return o;
}

static void mark_value(VM *vm, Value *v) {
    if (val_is_ptr(*v)) *v = mk_ptr(mark_obj(vm, val_ptr(*v)));
}
#define MARK_VALUE(v) (vm->gc_counts.other_roots++, mark_value(vm, (v)))
#define MARK_OBJ(o) (vm->gc_counts.other_roots++, *(o) = mark_obj(vm, *(o)))

/* Whether a full collection compacts the old space: where --heap-limit is
   set and the old space's chunks pass it by a quarter -- what lives in it
   spread over a quarter more than the limit -- or at every full collection
   under --gc-compact, to test it (D4). Not where they pass it by less: a
   heap at its limit holds that much, holes or no, and its holes are
   promotion's to fill, where a slide of a heap of gigabytes is a pause of
   seconds (Rune compiling MLton under a limit of 5 GiB compacted at every
   full collection near it, 18 s each; M7). */
static int at_limit(const VM *vm) {
    if (vm->gc.compact_always) return 1;
    if (!vm->heap_limit) return 0;
    size_t footprint = 0;
    for (const Chunk *c = vm->gc.first; c; c = c->next) footprint += c->size;
    return footprint - footprint / 5 > vm->heap_limit;   /* footprint > limit * 5/4, wrapping nowhere */
}

/* The frame's sweep: a chunk with nothing marked in it given back (but
   the one it places into, which starts again from its payload) */
static void mark_sweep(VM *vm) {
    Chunk **at = &vm->gc.first, *last = NULL;
    while (*at) {
        Chunk *c = *at;
        if (!c->used) {
            if (c != vm->gc.last) {
                *at = c->next;
                chunk_give(vm, c);
                continue;
            }
            c->top = 0;
        }
        last = c;
        at = &c->next;
    }
    vm->gc.last = last;
}

/* Every object reached marked, every young one promoted; then the old
   space swept by its own sweep, the large objects not reached freed, and
   the cards cleared: nothing young is left. */
void mark_full(VM *vm) {
    vm->gc.closed = 0;
    vm->gc.to_used = 0;
    vm->gc.to_boxes = 0;
    vm->gc.nqueue = 0;
    if (vm->gc.old_kind == OLD_IMMIX) immix_full_begin(vm);
    if (vm->gc.old_kind == OLD_SEGFIT) segfit_full_begin(vm);
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        bits_clear(c);
        c->used = 0;
    }
    gc_stack_roots(vm, mark_value);
    OTHER_ROOTS(vm, MARK_VALUE, MARK_OBJ);
    while (vm->gc.nqueue) {
        Obj *o = vm->gc.queue[--vm->gc.nqueue];
        Value *f = obj_fields(o);
        uint32_t n = obj_scanned_fields(o);   /* every field; of an indirection, the first */
        for (uint32_t i = 0; i < n; i++) mark_value(vm, &f[i]);
    }

    switch (vm->gc.old_kind) {
    case OLD_IMMIX:
        if (at_limit(vm)) {
            /* at the limit: slid down, its lines and blocks made again (D4) */
            compact_old(vm);
            vm->gc.ix_in_full = 0;
            immix_adopted(vm);
        } else immix_sweep(vm);
        break;
    case OLD_SEGFIT:
        if (at_limit(vm)) {
            /* at the limit: slid down into blocks of no class, which empty
               as their objects die (D4) */
            compact_old(vm);
            vm->gc.sf_in_full = 0;
            segfit_adopted(vm);
        } else segfit_sweep(vm, 0);
        break;
    case OLD_COMPACT: compact_old(vm); break;
    default: mark_sweep(vm); break;
    }
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        memset(chunk_cards(c), 0, c->size >> GC_CARD_SHIFT);
        memset(chunk_dirty(c), 0, c->size >> GC_BLOCK_SHIFT);
    }
    los_sweep(vm);
    vm->alloc.used = 0;
    vm->gc.nborn = 0;
    vm->gc.old_boxes = vm->gc.to_boxes;
    vm->box_bytes_live = vm->gc.to_boxes;
    vm->fp_low = vm->fp;
    vm->gc.fulls++;
    vm->gc_count++;
    vm->copied += vm->gc.to_used;
    if (heap_used(vm) > vm->max_live) vm->max_live = heap_used(vm);
}
