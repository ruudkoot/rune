/* The low-pause collector's cycle (docs/plans/garbage-collector-v2.md, D7,
   M6): the segregated old space (segfit.c) and the large objects marked
   incrementally, from a snapshot of what is reachable when the cycle
   begins, in short slices between the program's allocations, so that no
   pause marks the whole heap.

   A cycle begins in the pause of a minor collection, the nursery empty,
   where the old space has filled half of the room the last collection
   left (CYCLE_BEGIN8): the roots -- the whole stack, the globals and the
   rest of OTHER_ROOTS -- are marked, and each object they reach that has
   fields is gray, to be scanned. A chunk's marks of the cycle are a bit
   for every 8 bytes in the room of the line bytes (gc.h, chunk_cmarks),
   apart from its bits, which say where objects lie and which placement
   reads, so that the program and promotion go on while it marks; a large
   object's mark is the large-object space's.

   Then, while it marks, alloc's room ends at a slice point every
   CYCLE_EVERY bytes of the nursery, and the allocation that reaches one
   marks a slice in a pause of its own (cycle_slice): gray objects taken and
   the objects their fields reach marked, as many bytes as the cycle's pace
   asks for the bytes allocated since the last, at most CYCLE_SLICE of
   work. The pace, made again at every minor collection, is CYCLE_PACE
   times what marks what is left of the old space as promotion, at the
   survival of that collection, fills what is left of the heap's room --
   bytes, never time, so that the schedule is the same in every run. A
   slice that runs out of work before its bytes brings the next sooner.

   What the snapshot reaches stays reached: while the cycle marks, the
   barrier marks the value a store overwrites in an object that is not
   young (gc_shade_old, vm.h's gc_barrier: before the store, in every
   engine), and an object promoted or a large object made is marked where
   it is placed (cycle_black, allocated black). What is newer than the
   snapshot is not the snapshot's, so a store into it needs nothing; and a
   young object is never marked, what the snapshot reaches being reached
   through old ones, the cycle having begun with an empty nursery.

   When nothing is gray, the cycle ends in the next minor collection's
   pause: each chunk's marks become its bits -- what was not marked is free
   -- its blocks sorted by the count of their objects the cycle marked
   (segfit_sweep), the chunks left empty pooled, to go back to the system a
   few at each pause after (pool_trim), and the large objects not marked
   freed. Where the heap reaches its size before that, the collection that
   would be a full one ends the cycle instead, all that is gray marked at
   once (cycle_complete, vm_gc), and is a full one only where that leaves
   too little room. */
#include "gc/gc.h"
#include "sys/sys.h"
#include <string.h>

#ifndef CYCLE_EVERY
#define CYCLE_EVERY ((size_t)128 << 10)       /* the bytes allocated between two slices */
#endif
#ifndef CYCLE_PACE
#define CYCLE_PACE 1.5                        /* the margin over marking in step with promotion */
#endif
#ifndef CYCLE_SLICE_LEAST
#define CYCLE_SLICE_LEAST ((size_t)16 << 10)  /* the least a slice marks */
#endif
#define CYCLE_EVERY_LEAST ((size_t)8 << 10)   /* the least, where slices fall behind */
#define CYCLE_STRESS_EVERY ((size_t)64)       /* under --gc-stress-cycles */
#ifndef CYCLE_BEGIN8
#define CYCLE_BEGIN8 4                        /* a cycle begins where the old space has filled this many eighths of the room the last collection left */
#endif
#ifndef CYCLE_SLICE
#define CYCLE_SLICE ((size_t)1 << 20)         /* the most a slice marks */
#endif
#define CYCLE_STRESS_SLICE ((size_t)256)      /* a slice's budget under --gc-stress-cycles */
#define CYCLE_TRIM 2                          /* the chunks a pause gives back to the system, of those a cycle's end left in the pool */
#define CYCLE_PART 1024                       /* an object of more fields is scanned a part at a time */
#define CYCLE_FIELD_WORK 8                    /* the work of a field scanned, in bytes of a field */
#define CYCLE_OBJECT_WORK 64                  /* the work of an object marked */

static void out_of_memory(void) {
    fprintf(stderr, "runevm: out of memory\n");
    exit(2);
}

static void push_gray(VM *vm, Obj *o) {
    if (vm->gc.ngray == vm->gc.gray_cap) {
        size_t cap = vm->gc.gray_cap ? 2 * vm->gc.gray_cap : 256;
        Obj **g = realloc(vm->gc.gray, cap * sizeof *g);
        if (!g) out_of_memory();
        vm->gc.gray = g;
        vm->gc.gray_cap = cap;
    }
    vm->gc.gray[vm->gc.ngray++] = o;
}

/* An object of the old space or a large one, reached: marked, and gray
   where it has fields to scan */
static void shade(VM *vm, Obj *o) {
    Chunk *c = chunk_of(o);
    size_t size;
    if (c->kind == CHUNK_LOS) {
        uint8_t *m = &chunk_marks(c)[(size_t)((char *)o - chunk_payload(c)) >> GC_UNIT_SHIFT];
        if (*m) return;
        *m = 1;
        size = obj_size(o);
    } else {
        size_t off = (size_t)((char *)o - (char *)c);
        uint64_t *w = &chunk_cmarks(c)[off >> 9], bit = (uint64_t)1 << (off >> 3 & 63);
        if (*w & bit) return;
        *w |= bit;
        chunk_sfblocks(c)[off >> SF_BLOCK_SHIFT].marked++;
        size = obj_size(o);
        c->marked += size;
        if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) vm->gc.cycle_boxes += size;
    }
    vm->gc.cycle_marked += size;
    vm->gc_counts.objects++;
    if (obj_has_fields(o)) push_gray(vm, o);
}

static void shade_value(VM *vm, Value *v) {
    if (val_is_ptr(*v) && !gc_in_nursery(vm, val_ptr(*v))) shade(vm, val_ptr(*v));
}
static void shade_obj(VM *vm, Obj **o) {
    if (*o && !gc_in_nursery(vm, *o)) shade(vm, *o);
}

/* THE BARRIER's part while a cycle marks (vm.h, gc_barrier): the value a
   store into o overwrites, where o is not young and the value is an old
   object */
void gc_shade_old(VM *vm, Obj *o, Value old) {
    if (!val_is_ptr(old) || gc_in_nursery(vm, o) || gc_in_nursery(vm, val_ptr(old))) return;
    shade(vm, val_ptr(old));
}

/* Gray objects scanned until want bytes more are marked, or the work of
   the scan reaches most: CYCLE_FIELD_WORK for each field scanned and
   CYCLE_OBJECT_WORK for each object marked (an object marked is a header
   read, a miss of the cache where its fields are not: a large array of
   leaves marks many bytes for little time). An object of many fields (a
   large array) is scanned CYCLE_PART fields at a time, where it stopped
   kept apart (gray_part, gray_at) and taken up first, so that a slice
   stays near its bounds. */
static size_t mark_some(VM *vm, size_t want, size_t most) {
    size_t done = 0, marked0 = vm->gc.cycle_marked;
    uint64_t objects0 = vm->gc_counts.objects;
    while (vm->gc.cycle_marked - marked0 < want && done < most) {
        Obj *o;
        uint32_t i = 0;
        if (vm->gc.gray_part) { o = vm->gc.gray_part; i = vm->gc.gray_at; vm->gc.gray_part = NULL; }
        else if (vm->gc.ngray) o = vm->gc.gray[--vm->gc.ngray];
        else break;
        Value *f = obj_fields(o);
        uint32_t n = obj_scanned_fields(o);   /* of one made an indirection since, the first */
        if (i >= n) continue;
        uint32_t end = n - i > CYCLE_PART ? i + CYCLE_PART : n;
        for (uint32_t k = i; k < end; k++) shade_value(vm, &f[k]);
        vm->gc_counts.fields += end - i;
        done += (size_t)(end - i) * CYCLE_FIELD_WORK + (size_t)(vm->gc_counts.objects - objects0) * CYCLE_OBJECT_WORK;
        objects0 = vm->gc_counts.objects;
        if (end < n) { vm->gc.gray_part = o; vm->gc.gray_at = end; }
    }
    return done;
}
static int gray_left(const VM *vm) { return vm->gc.ngray || vm->gc.gray_part; }

/* The cycle begun: the roots marked (the nursery is empty) */
static void cycle_begin(VM *vm) {
    vm->gc.marking = 1;
    vm->gc.cycle_marked = 0;
    vm->gc.cycle_boxes = 0;
    vm->gc.cycle_work = USED_STOCK(vm);
    vm->gc.cycle_alloc = vm->bytes_allocated + vm->box_bytes_allocated;
    vm->gc.gray_part = NULL;
    for (Chunk *c = vm->gc.first; c; c = c->next) c->marked = 0;
    gc_stack_roots(vm, shade_value);
#define SHADE_VALUE(v) (vm->gc_counts.other_roots++, shade_value(vm, (v)))
#define SHADE_OBJ(o) (vm->gc_counts.other_roots++, shade_obj(vm, (o)))
    OTHER_ROOTS(vm, SHADE_VALUE, SHADE_OBJ);
#undef SHADE_VALUE
#undef SHADE_OBJ
}

/* The cycle ended, nothing gray and the nursery empty: the marks become
   the bits, the old ones cleared to be the next cycle's marks; the blocks
   counted and the empty chunks given back (segfit.c); the large objects
   not marked freed */
static void cycle_finish(VM *vm) {
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        uint32_t t = c->bits_at;
        c->bits_at = c->lines_at;
        c->lines_at = t;
        memset(chunk_cmarks(c), 0, c->size >> 6);
        c->used = c->marked;
        c->marked = 0;
    }
    segfit_sweep(vm, 1);
    size_t closed = 0;
    for (Chunk *c = vm->gc.first; c; c = c->next) closed += c->used;
    vm->gc.closed = closed;
    los_sweep(vm);
    vm->gc.old_boxes = vm->gc.cycle_boxes;
    vm->box_bytes_live = vm->gc.old_boxes;
    vm->gc.marking = 0;
    vm->alloc.size = vm->gc.nursery_size;   /* no slice point (slice_point) */
    vm->gc.cycles++;
    vm->gc_count++;
    if (heap_used(vm) > vm->max_live) vm->max_live = heap_used(vm);
}

/* What promotion may yet put into the old space before the heap's size is
   reached and a full collection comes: the heap's size less what it holds,
   and less the nursery, whose bytes it counts when the nursery is full */
static size_t cycle_room(const VM *vm) {
    size_t used = USED_STOCK(vm) + vm->gc.nursery_size;
    return vm->gc.size > used ? vm->gc.size - used : 0;
}

/* Where the next slice is: CYCLE_EVERY bytes more of the nursery, at most
   its end. While a cycle marks, alloc's room (vm.h, AllocState) ends there,
   so that the allocation that reaches it takes the slow path, which marks
   the slice (heap.c, alloc_young; cycle_slice); the nursery is still
   gc.nursery_size bytes, and nothing young lies past alloc.used. */
static void slice_point(VM *vm) {
    size_t every = vm->gc.stress_cycles && vm->gc_stress ? CYCLE_STRESS_EVERY : vm->gc.slice_every;
    size_t room = vm->gc.nursery_size - vm->alloc.used;
    vm->alloc.size = vm->gc.marking && gray_left(vm) && every < room ? vm->alloc.used + every : vm->gc.nursery_size;
    vm->gc.slice_from = vm->alloc.used;
}

/* After a minor collection (collect_minor), in its pause: where the low-
   pause collector has no cycle and the old space has filled CYCLE_BEGIN8
   eighths of the room the last collection left (or --gc-stress-cycles),
   one begun; where one marks and nothing is left gray, its end; and where
   it marks, the pace of its slices made again from what this minor
   collection promoted: CYCLE_PACE times what marks what is left as the
   promotion that the bytes allocated make at this survival fills what is
   left of the heap's room. A pass of the log of its own, in the minor
   collection's vm_gc call, so that the two are one pause. */
void cycle_step(VM *vm) {
    if (vm->gc.old_kind != OLD_SEGFIT || !vm->gc.nursery) return;
    pool_trim(vm, CYCLE_TRIM);
    int stress = vm->gc.stress_cycles && vm->gc_stress;
    uint64_t now = vm->bytes_allocated + vm->box_bytes_allocated;
    size_t allocated = (size_t)(now - vm->gc.cycle_alloc), promoted = vm->gc_counts.promoted;
    vm->gc.cycle_alloc = now;
    const char *kind = NULL;
    if (!vm->gc.marking) {
        size_t base = vm->live_last < vm->gc.size ? vm->live_last : vm->gc.size;
        if (stress || USED_STOCK(vm) >= base + (vm->gc.size - base) / 8 * CYCLE_BEGIN8) kind = "mark-begin";
    } else if (!gray_left(vm)) kind = "mark-end";
    else if (stress) kind = "mark";   /* a slice in the minor collection's pause too, so that a cycle ends however few bytes lie between */
    if (vm->gc.marking) {
        size_t left = vm->gc.cycle_work > vm->gc.cycle_marked ? vm->gc.cycle_work - vm->gc.cycle_marked : 0;
        size_t room = cycle_room(vm);
        double survival = allocated ? (double)promoted / (double)allocated : 1.0;
        if (survival < 0.01) survival = 0.01;
        vm->gc.cycle_rate = room ? CYCLE_PACE * (double)left * survival / (double)room : 1e9;
    }
    if (!kind) { slice_point(vm); return; }
    PassMark m;
    log_pass_begin(vm, &m);
    memset(&vm->gc_counts, 0, sizeof vm->gc_counts);
    size_t marked0 = vm->gc.marking ? vm->gc.cycle_marked : 0;
    if (kind[5] == 'b') vm->gc.slice_every = CYCLE_EVERY;
    if (kind[4] == 0) {
        mark_some(vm, CYCLE_STRESS_SLICE, CYCLE_STRESS_SLICE);
        vm->gc.slices++;
    } else if (kind[5] == 'b') {
        cycle_begin(vm);
        size_t left = vm->gc.cycle_work, room = cycle_room(vm);
        double survival = allocated ? (double)promoted / (double)allocated : 1.0;
        if (survival < 0.01) survival = 0.01;
        vm->gc.cycle_rate = room ? CYCLE_PACE * (double)left * survival / (double)room : 1e9;
    } else {
        cycle_finish(vm);
        gc_after_cycle(vm);
    }
    slice_point(vm);
    vm->gc.to_used = vm->gc.cycle_marked - marked0;   /* the log's: what this pass marked */
    int64_t pause = sys_clock_ns() - m.t0;
    vm->gc_ns += pause;
    log_pass_end(vm, &m, kind, pause);
    if (vm->gc_verify) heap_verify(vm, "after");
}

/* At a slice point (heap.c, alloc_young): a pause of its own, between two
   minor collections, that marks the cycle's pace times the bytes allocated
   since the last, at least CYCLE_SLICE_LEAST and at most CYCLE_SLICE (a
   few hundred bytes under --gc-stress-cycles). Young objects are not
   marked: what the snapshot reaches it reaches through old ones. Where
   nothing is left gray the cycle ends at the next minor collection, whose
   pause finds the nursery empty. */
void cycle_slice(VM *vm) {
    vm->gc_calls++;
    PassMark m;
    log_pass_begin(vm, &m);
    memset(&vm->gc_counts, 0, sizeof vm->gc_counts);
    size_t marked0 = vm->gc.cycle_marked;
    pool_trim(vm, CYCLE_TRIM);
    if (vm->gc.stress_cycles && vm->gc_stress) mark_some(vm, CYCLE_STRESS_SLICE, CYCLE_STRESS_SLICE);
    else {
        /* where the slice's work ran out before its bytes, the next comes
           sooner -- pauses as long, more of them -- and where it had work
           to spare, later again */
        double want = vm->gc.cycle_rate * (double)(vm->alloc.used - vm->gc.slice_from);
        size_t w = want > (double)SIZE_MAX / 2 ? SIZE_MAX / 2 : want < (double)CYCLE_SLICE_LEAST ? CYCLE_SLICE_LEAST : (size_t)want;
        size_t done = mark_some(vm, w, CYCLE_SLICE);
        if (vm->gc.cycle_marked - marked0 < w && gray_left(vm)) {
            if (vm->gc.slice_every / 2 >= CYCLE_EVERY_LEAST) vm->gc.slice_every /= 2;
        } else if (done < CYCLE_SLICE / 2 && vm->gc.slice_every < CYCLE_EVERY) vm->gc.slice_every *= 2;
    }
    vm->gc.slices++;
    slice_point(vm);
    vm->gc.to_used = vm->gc.cycle_marked - marked0;
    int64_t pause = sys_clock_ns() - m.t0;
    vm->gc_ns += pause;
    log_pass_end(vm, &m, "mark", pause);
    /* not checked under --gc-verify: a slice marks, and changes nothing
       heap_check reads (the minor collections and the cycle's end are) */
}

/* Where a cycle marks: the nursery promoted, every gray object marked at
   once and the cycle ended -- vm_gc's, where the heap reaches its size
   before the cycle ends, or a full collection is asked for; 1 where there
   was a cycle */
int cycle_complete(VM *vm) {
    if (!vm->gc.marking) return 0;
    minor_pass(vm);
    PassMark m;
    log_pass_begin(vm, &m);
    memset(&vm->gc_counts, 0, sizeof vm->gc_counts);
    size_t marked0 = vm->gc.cycle_marked;
    while (gray_left(vm)) mark_some(vm, SIZE_MAX, SIZE_MAX);
    vm->gc.to_used = vm->gc.cycle_marked - marked0;
    cycle_finish(vm);
    int64_t pause = sys_clock_ns() - m.t0;
    vm->gc_ns += pause;
    log_pass_end(vm, &m, "mark-all", pause);
    if (vm->gc_verify) heap_verify(vm, "after");
    return 1;
}
