/* The copier, today's collector: Cheney's, every live object copied at
   every collection, from the heap's chunks into chunks of its own, which
   become the heap. Objects are 8-byte aligned; the payload is rounded up
   to what runtime/value.h says (a word under this layout) and is at least
   that, so that a forwarding pointer always fits. */
#include "gc/gc.h"
#include "sys/sys.h"
#include <string.h>

/* The heap's last chunk during a collection is the one copied into; one an
   object does not fit is followed by another, or by a run of its own. */
static Chunk *copy_next(VM *vm, size_t size) {
    Chunk *c = chunk_take(vm, size > CHUNK_ROOM ? size : 0, CHUNK_OLD);
    chunk_append(vm, c);
    return c;
}

/* What a collection in progress has is the VM's (GcState, vm.h): the chunks
   copied into, how much is in them, and how much of that is boxes. */
static Obj *copy_obj(VM *vm, Obj *o) {
    if (obj_forwarded(o)) return obj_forwarding(o);
    /* with a nursery, a large object stays where it is, marked (los.c) */
    if (vm->gc.nursery && !gc_in_nursery(vm, o) && chunk_of(o)->kind == CHUNK_LOS) {
        los_mark(vm, o);
        return o;
    }
    vm->gc_counts.objects++;
    size_t size = obj_size(o);
    if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) vm->gc.to_boxes += size;
    if (vm->gc.nursery && size >= vm->gc.los_min) {
        /* a large one of the nursery (compiled code made it) goes there now */
        Obj *n = los_alloc(vm, size);
        memcpy(n, o, size);
        los_mark(vm, n);
        vm->copied += size;
        obj_forward(o, n);
        return n;
    }
    Chunk *to = vm->gc.last;
    if (size > chunk_room(to) - to->used) to = copy_next(vm, size);
    Obj *n = (Obj *)(chunk_payload(to) + to->used);
    /* Most objects have one to three fields: a copy of a size the compiler
       knows is a few moves, where one of any size is a call of memcpy, which
       was 4.5% of the time of the compiler compiling itself natively. */
    switch (size) {
    case OBJ_SIZE_FIELDS(1): memcpy(n, o, OBJ_SIZE_FIELDS(1)); break;
    case OBJ_SIZE_FIELDS(2): memcpy(n, o, OBJ_SIZE_FIELDS(2)); break;
    case OBJ_SIZE_FIELDS(3): memcpy(n, o, OBJ_SIZE_FIELDS(3)); break;
    case OBJ_SIZE_FIELDS(4): memcpy(n, o, OBJ_SIZE_FIELDS(4)); break;
    case OBJ_SIZE_FIELDS(5): memcpy(n, o, OBJ_SIZE_FIELDS(5)); break;
    case OBJ_SIZE_FIELDS(6): memcpy(n, o, OBJ_SIZE_FIELDS(6)); break;
    default: memcpy(n, o, size); break;
    }
#ifdef RUNE_GC_BITS
    /* The stress of the header's bits (value.h): every copy is a collection
       older, to three, and has the other two bits by what is at hand, so
       that a reader of a kind that does not mask them, in C or in compiled
       code, fails a suite. */
    {
        int age = obj_gc_bits(n) & OBJ_GC_AGE;
        if (age != OBJ_GC_AGE) age += OBJ_GC_AGE_ONE;
        obj_set_gc_bits(n, age | ((size & 8) ? OBJ_GC_REMEMBERED : 0) | ((vm->gc_count & 1) ? OBJ_GC_PINNED : 0));
    }
#endif
    if (vm->gc.nursery) chunk_note(to, to->used, size);
    to->used += size;
    vm->gc.to_used += size;
#ifdef RUNE_CENSUS
    vm->gc.to_used_stock += STOCK(size);
#endif
    CENSUS_SURVIVE(n, size);
    obj_forward(o, n);
    return n;
}

static void copy_value(VM *vm, Value *v) {
    if (val_is_ptr(*v)) *v = mk_ptr(copy_obj(vm, val_ptr(*v)));
}
#define COPY_VALUE(v) copy_value(vm, (v))
#define COPY_OBJ(o) (*(o) = copy_obj(vm, *(o)))

/* The value stack as roots. Every slot, where the engine does not say what
   is live (the stack bytecode; VM.frame_live). Where it does, the registers
   of a frame that waits for a call are roots as far as they are live there,
   and a dead one that holds a pointer is made unit: it is not copied, and it
   must not stay behind pointing into the space that is left, since the frame
   becomes the one that runs again, whose registers are all roots (what it is
   doing when a collection comes is not known here). */
void gc_stack_roots(VM *vm, void (*visit)(VM *, Value *)) {
    size_t at = 0, dead = 0;
    if (vm->frame_live && vm->frames_active)
        for (size_t k = 0; k < vm->fp; k++) {
            const Frame *f = &vm->frames[k];
            size_t end = vm->frames[k + 1].base < vm->sp ? vm->frames[k + 1].base : vm->sp;
            uint32_t n = vm->prog.funcs[f->func].nlocals;
            uint64_t live = vm->frame_live(vm, f->func, vm->frames[k + 1].ret_pc);
            for (; at < f->base && at < end; at++) visit(vm, &vm->stack[at]);
            for (uint32_t r = 0; r < n && at < end; r++, at++) {
                if (r >= 64 || ((live >> r) & 1)) visit(vm, &vm->stack[at]);
                else {
                    dead++;
                    if (val_is_ptr(vm->stack[at])) vm->stack[at] = mk_unit();
                }
            }
            vm->gc_counts.frames++;
        }
    for (; at < vm->sp; at++) visit(vm, &vm->stack[at]);
    vm->gc_counts.slots += vm->sp;
    vm->gc_counts.live_slots += vm->sp - dead;
}

/* A collection: the heap's chunks are set aside, the live objects copied
   into chunks taken afresh (from the pool first: the chunks the last
   collection gave back, whose pages are there already), and the chunks set
   aside given back. The heap then has new_size; how much of it alloc may
   fill is alloc_view's. */
static void collect_into(VM *vm, size_t new_size) {
    Chunk *from = vm->gc.first;
    if (!vm->gc.nursery) vm->gc.last->used = vm->alloc.used;
    vm->gc.first = vm->gc.last = NULL;
    vm->gc.closed = 0;
    vm->gc.to_used = 0;
    vm->gc.to_boxes = 0;
    vm->gc.nqueue = 0;
    chunk_append(vm, chunk_take(vm, 0, CHUNK_OLD));
#ifdef RUNE_CENSUS
    vm->gc.to_used_stock = 0;
    census_collect_begin();
#endif

    gc_stack_roots(vm, copy_value);
#define COPY_ROOT_VALUE(v) (vm->gc_counts.other_roots++, COPY_VALUE(v))
#define COPY_ROOT_OBJ(o) (vm->gc_counts.other_roots++, COPY_OBJ(o))
    OTHER_ROOTS(vm, COPY_ROOT_VALUE, COPY_ROOT_OBJ);
#undef COPY_ROOT_VALUE
#undef COPY_ROOT_OBJ

    /* scan, chunk by chunk in the order they were filled (the last grows,
       and others are added after it, while it is scanned), and the large
       objects marked, until neither has more */
    Chunk *c = vm->gc.first;
    size_t at = 0;
    for (;;) {
        while (c) {
            while (at < c->used) {
                Obj *o = (Obj *)(chunk_payload(c) + at);
                if (obj_has_fields(o)) {
                    Value *f = obj_fields(o);
                    uint32_t n = obj_scanned_fields(o);   /* every field; of an indirection, the first */
                    for (uint32_t i = 0; i < n; i++) copy_value(vm, &f[i]);
                }
                at += obj_size(o);
            }
            if (!c->next) break;
            c = c->next;
            at = 0;
        }
        if (!vm->gc.nqueue) break;
        Obj *o = vm->gc.queue[--vm->gc.nqueue];
        Value *f = obj_fields(o);
        uint32_t n = obj_scanned_fields(o);
        for (uint32_t i = 0; i < n; i++) copy_value(vm, &f[i]);
    }

    vm->gc.size = new_size;
    for (Chunk *k = from, *n; k; k = n) { n = k->next; chunk_give(vm, k); }
    if (vm->gc.nursery) {
        /* the nursery is empty, the old space all that was copied, and no
           large object is new any more */
        vm->gc.closed = vm->gc.to_used;
        vm->alloc.used = 0;
        vm->gc.nborn = 0;
        los_sweep(vm);
        vm->gc.old_boxes = vm->gc.to_boxes;
        vm->fp_low = vm->fp;   /* nothing young is left on the stack */
        vm->gc.fulls++;
    } else vm->gc.closed = vm->gc.to_used - vm->gc.last->used;
    alloc_view(vm);
    vm->box_bytes_live = vm->gc.to_boxes;
#ifdef RUNE_CENSUS
    USED_STOCK(vm) = vm->gc.to_used_stock;
#endif
    vm->gc_count++;
    vm->copied += vm->gc.to_used;
    if (heap_used(vm) > vm->max_live) vm->max_live = heap_used(vm);
}

/* A pass of the copier, as --gc-log sees it: timed on the monotonic clock,
   with what it counted, one line of the log each (log.c). A collection
   that grows the heap is two passes, two lines with the same call number.
   The clock is read where there is no log too: the sum and the longest
   collection are RUNE_MEMSTAT's (runtime.c, vm_exit). Under --gc-verify
   the heap is checked before and after (check.c). */
void collect_pass(VM *vm, size_t new_size) {
    if (vm->gc_verify) heap_verify(vm, "before");
    PassMark m;
    log_pass_begin(vm, &m);
    memset(&vm->gc_counts, 0, sizeof vm->gc_counts);
    if (vm->gc.old_kind != OLD_COPY) {
        mark_full(vm);
        vm->gc.size = new_size;
    } else collect_into(vm, new_size);
    int64_t pause = sys_clock_ns() - m.t0;
    vm->gc_ns += pause;
    log_pass_end(vm, &m, "full", pause);
    if (vm->gc_verify) heap_verify(vm, "after");
}

/* heap_fill% of n bytes, rounded down, which for 50 is n / 2 */
static size_t fill_of(const VM *vm, size_t n) {
    return n / 100 * vm->heap_fill + n % 100 * vm->heap_fill / 100;
}

/* The size, doubled from size as often as it must be, at which a heap that
   holds used bytes and must take needed more is at most heap_fill% full,
   half unless --heap-fill says otherwise, to avoid thrashing; written so
   that nothing wraps where a size_t is 32 bits. */
/* the largest size a heap is given: what a size_t counts less a quarter --
   on a 32-bit VM 3 GiB, so that the address space, not the arithmetic of
   doubling, is where a heap stops (a chunk the system will not give) */
#define HEAP_MOST (SIZE_MAX - SIZE_MAX / 4)

static size_t grown(const VM *vm, size_t size, size_t used, size_t needed) {
    size_t want = size;
    if (vm->gc.old_kind != OLD_COPY && vm->gc.nursery) {
        /* a non-moving old space is not copied into a heap of a new size, so
           it need not double: the size that holds what lives and what is
           asked at heap_fill%, by steps of 1 MiB, never less than it was
           (D10) */
        size_t fill = vm->heap_fill ? vm->heap_fill : 50, total = used + needed;
        if (total < used) total = SIZE_MAX;
        size_t need = total / fill > HEAP_MOST / 100 ? HEAP_MOST : total / fill * 100 + total % fill * 100 / fill;
        need = need > HEAP_MOST - ((size_t)1 << 20) ? HEAP_MOST : (need + ((size_t)1 << 20) - 1) & ~(((size_t)1 << 20) - 1);
        if (need > want) want = need;
        if (vm->heap_limit && want > vm->heap_limit) want = vm->heap_limit;
        return want;
    }
    while (used > fill_of(vm, want) || needed > fill_of(vm, want) - used) {
        if (vm->heap_limit && want >= vm->heap_limit) return vm->heap_limit;
#ifdef RUNE_HEAP_GROW
        /* The experiment of docs/plans/heap-layout.md, M7: by RUNE_HEAP_GROW
           percent a step, to a multiple of 1 MiB, where the heap doubles. */
        size_t step = want / 100 * RUNE_HEAP_GROW;
        step = (step + 1048575) / 1048576 * 1048576;
        if (step > SIZE_MAX - want) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
        if (vm->heap_limit && want + step > vm->heap_limit) return vm->heap_limit;
        want += step;
#else
        if (vm->heap_limit && want > vm->heap_limit / 2) return vm->heap_limit;
        if (want > HEAP_MOST / 2) return want < HEAP_MOST ? HEAP_MOST : want;
        want *= 2;
#endif
    }
    return want;
}

void vm_gc(VM *vm, size_t needed) {
    /* The processor time of a collection, for Timer.checkCPUTimes and
       checkGCTime: read once around the whole of it, so that growing the
       heap counts as one collection and not two. */
    int64_t user0 = sys_time_user(), sys0 = sys_time_sys();
    int64_t ns0 = vm->gc_ns;
    vm->gc_calls++;
    CENSUS_GC_BEGIN(vm);
    /* Where the heap must grow, collecting into a heap of the same size
       and then again into a larger one made the largest collections of a
       run. So guess first whether it must: the survivors grow about as
       they grew between the last two collections. A guess too high grows
       the heap one collection early; one too low collects again below, as
       before. A heap of the current size or larger always holds what
       survives. */
    if (vm->gc.old_kind != OLD_COPY) {
        /* a non-moving old space grows without a collection into it */
        collect_pass(vm, vm->gc.size);
        vm->gc.size = grown(vm, vm->gc.size, USED_STOCK(vm), needed);
    } else {
        size_t guess = vm->live_last;
        if (vm->live_last > vm->live_before) {
            guess += vm->live_last - vm->live_before;
            /* no more than can survive: it would wrap, or grow the heap more
               than once on a guess */
            if (guess < vm->live_last || guess > vm->gc.size) guess = vm->gc.size;
        }
        collect_pass(vm, grown(vm, vm->gc.size, guess, needed));
        size_t want = grown(vm, vm->gc.size, USED_STOCK(vm), needed);
        if (want != vm->gc.size) collect_pass(vm, want);
    }
    if (USED_STOCK(vm) > vm->gc.size || needed > vm->gc.size - USED_STOCK(vm)) vm_limit(vm, "heap limit exceeded");
    vm->live_before = vm->live_last;
    vm->live_last = USED_STOCK(vm);
    /* the adaptive nursery (docs/plans/garbage-collector-v2.md, D2): half
       of what the heap has room for, within --nursery and --nursery-max */
    if (vm->gc.nursery && vm->gc.nursery_max && vm->alloc.used == 0) {
        size_t room = vm->gc.size > USED_STOCK(vm) ? (vm->gc.size - USED_STOCK(vm)) / 2 : 0;
        size_t want = room < vm->gc.nursery_min ? vm->gc.nursery_min : room > vm->gc.nursery_max ? vm->gc.nursery_max : room;
        want &= ~(size_t)65535;
        if (want >= 4096 && want != vm->gc.nursery_size) nursery_start(vm, want);
    }
    CENSUS_GC_END(vm);
    int64_t user = sys_time_user() - user0, sys = sys_time_sys() - sys0;
    vm->gc_user_us += user;
    vm->gc_sys_us += sys;
    if (user + sys > vm->gc_longest_us) vm->gc_longest_us = user + sys;
    if (vm->gc_ns - ns0 > vm->gc_longest_ns) vm->gc_longest_ns = vm->gc_ns - ns0;
}
