/* The nursery and the minor collection (docs/plans/garbage-collector-v2.md,
   M3; D2, D6). The nursery is alloc's room; a minor collection copies every
   object of it that is reached into the old space -- the heap's last chunk
   and those after it, or the large-object space for a large one -- and
   empties it. What reaches the nursery from the old space is in the cards
   the barrier marked (gc_write) and in the large objects made since the
   last minor collection, whose fill has no barrier (gc.born). */
#include "gc/gc.h"
#include "sys/sys.h"
#include <string.h>

void gc_write(Obj *o, Value *f) { gc_remember(o, f); }

static void out_of_memory(void) {
    fprintf(stderr, "runevm: out of memory\n");
    exit(2);
}

void gc_queue(VM *vm, Obj *o) {
    if (vm->gc.nqueue == vm->gc.queue_cap) {
        size_t cap = vm->gc.queue_cap ? 2 * vm->gc.queue_cap : 64;
        Obj **q = realloc(vm->gc.queue, cap * sizeof *q);
        if (!q) out_of_memory();
        vm->gc.queue = q;
        vm->gc.queue_cap = cap;
    }
    vm->gc.queue[vm->gc.nqueue++] = o;
}

void gc_born(VM *vm, Obj *o) {
    if (vm->gc.nborn == vm->gc.born_cap) {
        size_t cap = vm->gc.born_cap ? 2 * vm->gc.born_cap : 64;
        Obj **b = realloc(vm->gc.born, cap * sizeof *b);
        if (!b) out_of_memory();
        vm->gc.born = b;
        vm->gc.born_cap = cap;
    }
    vm->gc.born[vm->gc.nborn++] = o;
}

/* The nursery of bytes (at least 4 KiB; 0: none), and the size from which an
   object goes to the large-object space: 8 KiB (D5), or a quarter of a
   smaller nursery. From a heap with none, the objects already made are
   old: their chunk is closed, and its crossing map made. */
void nursery_start(VM *vm, size_t bytes) {
    bytes &= ~(size_t)7;
    if (bytes && bytes < 4096) bytes = 4096;
    if (vm->gc.nursery) {
        sys_mem_release(vm->gc.nursery, vm->gc.nursery->size);
        vm->gc.nursery = NULL;
    } else if (vm->gc.last) {
        /* alloc was the room of the last chunk: what it filled is the chunk's */
        vm->gc.last->used = vm->alloc.used;
        if (bytes) {
            vm->gc.closed += vm->alloc.used;
            vm->gc.old_boxes = vm->box_bytes_live;
            if (vm->gc.old_kind != OLD_COPY) mark_adopt(vm);
            else
                for (Chunk *k = vm->gc.first; k; k = k->next)
                    for (size_t at = 0; at < k->used; at += obj_size((Obj *)(chunk_payload(k) + at)))
                        chunk_note(k, at, obj_size((Obj *)(chunk_payload(k) + at)));
        }
    }
    vm->gc.nursery_size = bytes;
    if (!bytes) vm->gc.old_kind = OLD_COPY;   /* a non-moving old space is behind a nursery alone */
    vm->gc.los_min = bytes / 4 < 8192 ? bytes / 4 : 8192;
    if (bytes) {
        Chunk *c = chunk_take(vm, bytes > CHUNK_ROOM ? bytes : 0, CHUNK_NURSERY);
        vm->gc.nursery = c;
        vm->alloc.used = 0;
    }
    alloc_view(vm);
}

/* ---- the minor collection ---- */

/* An object copied: the common sizes as moves the compiler knows, as
   copy.c's copy_obj */
static inline void copy_small(Obj *n, const Obj *o, size_t size) {
    switch (size) {
    case OBJ_SIZE_FIELDS(1): memcpy(n, o, OBJ_SIZE_FIELDS(1)); break;
    case OBJ_SIZE_FIELDS(2): memcpy(n, o, OBJ_SIZE_FIELDS(2)); break;
    case OBJ_SIZE_FIELDS(3): memcpy(n, o, OBJ_SIZE_FIELDS(3)); break;
    case OBJ_SIZE_FIELDS(4): memcpy(n, o, OBJ_SIZE_FIELDS(4)); break;
    case OBJ_SIZE_FIELDS(5): memcpy(n, o, OBJ_SIZE_FIELDS(5)); break;
    case OBJ_SIZE_FIELDS(6): memcpy(n, o, OBJ_SIZE_FIELDS(6)); break;
    default: memcpy(n, o, size); break;
    }
}

/* A young object reached: its copy in the old space, made once */
static Obj *promote(VM *vm, Obj *o) {
    if (obj_forwarded(o)) return obj_forwarding(o);
    vm->gc_counts.objects++;
    size_t size = obj_size(o);
    Obj *n;
    if (size >= vm->gc.los_min) {
        /* a large object made in the nursery (by compiled code, which knows
           no large-object space) goes there now, and is scanned with the
           objects promoted */
        n = los_alloc(vm, size);
        memcpy(n, o, size);
        gc_queue(vm, n);
    } else if (vm->gc.old_kind == OLD_IMMIX) {
        /* bumped into a hole of the old space, and scanned there (minor_into) */
        n = immix_place_fast(vm, size);
        copy_small(n, o, size);
    } else if (vm->gc.old_kind == OLD_SEGFIT) {
        /* a cell of its class, scanned from the queue */
        n = segfit_place_fast(vm, size);
        copy_small(n, o, size);
        if (vm->gc.marking) cycle_black(vm, n, size);   /* newer than the cycle's snapshot (cycle.c) */
        if (obj_has_fields(n)) gc_queue(vm, n);
    } else if (vm->gc.old_kind != OLD_COPY) {
        /* placed where the old space has room, and scanned from the queue */
        n = old_place(vm, size);
        memcpy(n, o, size);
        if (obj_has_fields(n)) gc_queue(vm, n);
    } else {
        Chunk *to = vm->gc.last;
        if (size > chunk_room(to) - to->used) {
            to = chunk_take(vm, 0, CHUNK_OLD);
            chunk_append(vm, to);
        }
        n = (Obj *)(chunk_payload(to) + to->used);
        copy_small(n, o, size);
        chunk_note(to, to->used, size);
        to->used += size;
        vm->gc.closed += size;
    }
    if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) vm->gc.old_boxes += size;
#ifdef RUNE_GC_BITS
    {
        int age = obj_gc_bits(n) & OBJ_GC_AGE;
        if (age != OBJ_GC_AGE) age += OBJ_GC_AGE_ONE;
        obj_set_gc_bits(n, age | ((size & 8) ? OBJ_GC_REMEMBERED : 0) | ((vm->gc_count & 1) ? OBJ_GC_PINNED : 0));
    }
#endif
    vm->gc_counts.promoted += size;
    obj_forward(o, n);
    return n;
}

static int promote_value(VM *vm, Value *v) {
    if (!val_is_ptr(*v) || !gc_in_nursery(vm, val_ptr(*v))) return 0;
    *v = mk_ptr(promote(vm, val_ptr(*v)));
    return 1;
}
static void promote_obj(VM *vm, Obj **o) {
    if (*o && gc_in_nursery(vm, *o)) *o = promote(vm, *o);
}

/* The stack, as the full collection takes it (copy.c, stack_roots): the
   registers of a waiting frame as far as they are live, a dead one that
   holds a pointer made unit -- from the frame of the watermark up (D9):
   the frames below it have not run since the last minor collection, which
   left nothing young in them. */
static void minor_stack(VM *vm, size_t low) {
    size_t at = vm->frames_active && low ? vm->frames[low].base : 0, dead = 0, from = at;
    if (vm->frame_live && vm->frames_active)
        for (size_t k = low; k < vm->fp; k++) {
            const Frame *f = &vm->frames[k];
            size_t end = vm->frames[k + 1].base < vm->sp ? vm->frames[k + 1].base : vm->sp;
            uint32_t n = vm->prog.funcs[f->func].nlocals;
            uint64_t live = vm->frame_live(vm, f->func, vm->frames[k + 1].ret_pc);
            for (; at < f->base && at < end; at++) promote_value(vm, &vm->stack[at]);
            for (uint32_t r = 0; r < n && at < end; r++, at++) {
                if (r >= 64 || ((live >> r) & 1)) promote_value(vm, &vm->stack[at]);
                else {
                    dead++;
                    if (val_is_ptr(vm->stack[at])) vm->stack[at] = mk_unit();
                }
            }
            vm->gc_counts.frames++;
        }
    for (; at < vm->sp; at++) promote_value(vm, &vm->stack[at]);
    vm->gc_counts.slots += vm->sp - from;
    vm->gc_counts.live_slots += vm->sp - from - dead;
}

/* The fields of o that lie in [lo, hi), promoted: from the first in the
   card, not from the object's first (a large array has many cards) */
static int scan_range(VM *vm, Obj *o, const char *lo, const char *hi) {
    if (!obj_has_fields(o)) return 0;
    Value *f = obj_fields(o);
    size_t n = obj_scanned_fields(o);
    size_t first = (const char *)f < lo ? (size_t)(lo - (const char *)f) / sizeof(Value) : 0;
    size_t end = (const char *)(f + n) > hi ? (size_t)(hi - (const char *)f) / sizeof(Value) : n;
    int young = 0;
    for (size_t i = first; i < end; i++) {
        vm->gc_counts.fields++;
        young |= promote_value(vm, &f[i]);
    }
    return young;
}

/* A dirty card: the objects of it, from the one that covers its first byte
   (the crossing map, or the unit map of a large object's chunk), their
   fields in it promoted */
static void scan_card(VM *vm, Chunk *c, size_t k) {
    size_t lo = k << GC_CARD_SHIFT, hi = lo + ((size_t)1 << GC_CARD_SHIFT);
    if (hi <= c->payload) return;
    const char *base = (const char *)c;
    int young = 0;
    if (c->kind == CHUNK_LOS) {
        size_t u = (lo - c->payload) >> GC_UNIT_SHIFT;
        uint16_t start = chunk_units(c)[u];
        if (start != LOS_FREE) young = scan_range(vm, (Obj *)(chunk_payload(c) + ((size_t)start << GC_UNIT_SHIFT)), base + lo, base + hi);
    } else if (c->kind == CHUNK_MARK) {
        /* the objects of the card from the bits: the one that covers its
           first byte, and those that begin in it */
        size_t at = chunk_object_covering(c, lo - c->payload);
        if (at == CHUNK_END) at = chunk_bits_next(c, lo - c->payload);
        for (; at != CHUNK_END && c->payload + at < hi; at = chunk_bits_next(c, at + obj_size((Obj *)(chunk_payload(c) + at))))
            young |= scan_range(vm, (Obj *)(chunk_payload(c) + at), base + lo, base + hi);
    } else {
        size_t end = c->payload + c->used;
        size_t at = lo - ((size_t)chunk_cross(c)[k] << 3);
        while (at < hi && at < end) {
            Obj *o = (Obj *)(void *)(base + at);
            young |= scan_range(vm, o, base + lo, base + hi);
            at += obj_size(o);
        }
    }
    vm->gc_counts.cards_young += (uint64_t)young;
}

/* The dirty blocks of a chunk, and their dirty cards, cleared as they are
   scanned: no young object is left after a minor collection to need them */
static void scan_dirty(VM *vm, Chunk *c) {
    uint8_t *dirty = chunk_dirty(c), *cards = chunk_cards(c);
    size_t blocks = c->size >> GC_BLOCK_SHIFT, per = (size_t)1 << (GC_BLOCK_SHIFT - GC_CARD_SHIFT);
    for (size_t b = 0; b < blocks; b++) {
        /* eight dirty bytes at a time where they are clear: a minor
           collection visits every chunk's, and most are */
        if (!(b & 7) && blocks - b >= 8) {
            uint64_t eight;
            memcpy(&eight, dirty + b, 8);
            if (!eight) { b += 7; continue; }
        }
        if (!dirty[b]) continue;
        dirty[b] = 0;
        vm->gc_counts.cards_scanned += per;
        for (size_t k = b * per; k < (b + 1) * per; k++) {
            if (!cards[k]) continue;
            cards[k] = 0;
            vm->gc_counts.cards_dirty++;
            scan_card(vm, c, k);
        }
    }
}

static void scan_object(VM *vm, Obj *o) {
    if (!obj_has_fields(o)) return;
    Value *f = obj_fields(o);
    uint32_t n = obj_scanned_fields(o);
    for (uint32_t i = 0; i < n; i++) promote_value(vm, &f[i]);
}

static void minor_into(VM *vm) {
    Chunk *start = vm->gc.last;
    size_t start_at = start->used;
    vm->gc.nqueue = 0;
    if (vm->gc.old_kind == OLD_IMMIX) {
        /* what is promoted into a hole is scanned where it lies, from here */
        vm->gc.ix_track = 1;
        vm->gc.ix_scan = vm->gc.ix_cursor;
        vm->gc.ix_nranges = 0;
    }
    size_t low = vm->fp_low < vm->fp ? vm->fp_low : vm->fp;
    minor_stack(vm, low);
#define PROMOTE_ROOT_VALUE(v) (vm->gc_counts.other_roots++, promote_value(vm, (v)))
#define PROMOTE_ROOT_OBJ(o) (vm->gc_counts.other_roots++, promote_obj(vm, (o)))
    OTHER_ROOTS_FROM(vm, PROMOTE_ROOT_VALUE, PROMOTE_ROOT_OBJ, low);
#undef PROMOTE_ROOT_VALUE
#undef PROMOTE_ROOT_OBJ
    for (Chunk *c = vm->gc.first; c; c = c->next) scan_dirty(vm, c);
    for (Chunk *c = vm->gc.los; c; c = c->next) scan_dirty(vm, c);
    for (size_t i = 0; i < vm->gc.nborn; i++) {
        vm->gc_counts.remembered++;
        vm->gc_counts.fields += obj_has_fields(vm->gc.born[i]) ? obj_scanned_fields(vm->gc.born[i]) : 0;
        scan_object(vm, vm->gc.born[i]);
    }
    vm->gc.nborn = 0;
    /* Cheney's scan of what was promoted: the old space from where it ended,
       and the large objects that were made of young ones, until neither has
       more; the mark-region space's in the holes it filled, the ranges of
       those it left and the current one's (immix.c, next), and every other
       non-moving space's from the queue */
    if (vm->gc.old_kind == OLD_IMMIX) {
        for (;;) {
            if (vm->gc.ix_nranges) {
                char *hi = vm->gc.ix_ranges[--vm->gc.ix_nranges], *lo = vm->gc.ix_ranges[--vm->gc.ix_nranges];
                while (lo < hi) {
                    Obj *o = (Obj *)lo;
                    lo += obj_size(o);
                    scan_object(vm, o);
                }
                continue;
            }
            if (vm->gc.ix_scan && vm->gc.ix_scan < vm->gc.ix_cursor) {
                /* past it first: scanning it may leave the hole, and hand on what follows it */
                Obj *o = (Obj *)vm->gc.ix_scan;
                vm->gc.ix_scan += obj_size(o);
                scan_object(vm, o);
                continue;
            }
            if (!vm->gc.nqueue) break;
            scan_object(vm, vm->gc.queue[--vm->gc.nqueue]);
        }
        vm->gc.ix_track = 0;
    }
    Chunk *c = vm->gc.old_kind == OLD_COPY ? start : NULL;
    size_t at = start_at;
    for (;;) {
        while (c) {
            while (at < c->used) {
                Obj *o = (Obj *)(chunk_payload(c) + at);
                scan_object(vm, o);
                at += obj_size(o);
            }
            if (!c->next) break;
            c = c->next;
            at = 0;
        }
        if (!vm->gc.nqueue) break;
        scan_object(vm, vm->gc.queue[--vm->gc.nqueue]);
    }
    vm->alloc.used = 0;
    vm->fp_low = vm->fp;
    vm->box_bytes_live = vm->gc.old_boxes;
    vm->gc_count++;
    vm->gc.minors++;
    vm->gc.promoted += vm->gc_counts.promoted;
    vm->copied += vm->gc_counts.promoted;
    if (heap_used(vm) > vm->max_live) vm->max_live = heap_used(vm);
}

/* A minor collection, as --gc-log and --gc-verify see it (copy.c, collect_pass) */
void minor_pass(VM *vm) {
    if (vm->gc_verify) heap_verify(vm, "before");
    PassMark m;
    log_pass_begin(vm, &m);
    memset(&vm->gc_counts, 0, sizeof vm->gc_counts);
    minor_into(vm);
    int64_t pause = sys_clock_ns() - m.t0;
    vm->gc_ns += pause;
    log_pass_end(vm, &m, "minor", pause);
    if (vm->gc_verify) heap_verify(vm, "after");
}

/* A minor collection, a vm_gc call of its own (log.c's vmgc), and the low-
   pause collector's cycle begun or marked a slice of in the same pause */
void collect_minor(VM *vm) {
    vm->gc_calls++;
    minor_pass(vm);
    cycle_step(vm);
}
