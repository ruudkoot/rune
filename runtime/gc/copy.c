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

/* A field copied, a selector shortcut first (D17's C: gc_shortcut_walk,
   gc.h), entered only for a suspension or an indirection, one comparison;
   an indirection is copied as it is. In line, as it was: out of line, it
   cost --nursery 0's collections 14% more instructions. */
#if defined(__GNUC__)
__attribute__((always_inline))
#endif
static inline void copy_value(VM *vm, Value *v) {
    if (!val_is_ptr(*v)) return;
    if (obj_kind(val_ptr(*v)) >= K_THUNK) {
        gc_shortcut_walk(vm, v, 0, 0, vm->prog.reruns);
        if (!val_is_ptr(*v)) return;
    }
    *v = mk_ptr(copy_obj(vm, val_ptr(*v)));
}
#define COPY_VALUE(v) copy_value(vm, (v))
#define COPY_OBJ(o) (*(o) = copy_obj(vm, *(o)))
static void copy_objp(VM *vm, Obj **o) { vm->gc_counts.other_roots++; *o = copy_obj(vm, *o); }

/* An object copied, its fields copied: where the program keeps its
   globals by CAF tables (caf.c, mode 1), one whose code may run taking its
   function's table; and after the frames' closures (mode 2), one of those
   that a field reaches, the frames' alone so far, taking its function's
   too (late). */
static void copy_late_global(VM *vm, Value *v);
static inline void copy_late_value(VM *vm, Value *v) {
    copy_value(vm, v);
    if (val_is_ptr(*v)) {
        Obj *o = val_ptr(*v);
        if (caf_only_take(o) && caf_code_due(o)) caf_code(vm, o, copy_late_global);
    }
}
static void copy_late_global(VM *vm, Value *v) { copy_late_value(vm, v); }
static inline void copy_fields(VM *vm, Obj *o, int mode) {
    Value *f = obj_fields(o);
    uint32_t n = obj_scanned_fields(o);   /* every field; of an indirection, the first */
    if (mode == 1 && caf_runs(o) && caf_code_due(o)) caf_code(vm, o, copy_value);
    if (mode == 2) {
        if (caf_runs(o) && !caf_only_has(o) && caf_code_due(o)) caf_code(vm, o, copy_late_global);
        for (uint32_t i = 0; i < n; i++) copy_late_value(vm, &f[i]);
    } else
        for (uint32_t i = 0; i < n; i++) copy_value(vm, &f[i]);
}
/* the scan, chunk by chunk in the order they were filled (the last grows,
   and others are added after it, while it is scanned), and the large
   objects marked, from where it stopped (*cp, *atp) until neither has more;
   in line, so that each mode is a loop of its own and the copier without
   tables tests nothing more than it did */
#if defined(__GNUC__)
__attribute__((always_inline))
#endif
static inline void copy_scan(VM *vm, Chunk **cp, size_t *atp, int mode) {
    Chunk *c = *cp;
    size_t at = *atp;
    for (;;) {
        while (c) {
            while (at < c->used) {
                Obj *o = (Obj *)(chunk_payload(c) + at);
                if (obj_has_fields(o)) copy_fields(vm, o, mode);
                at += obj_size(o);
            }
            if (!c->next) break;
            c = c->next;
            at = 0;
        }
        if (!vm->gc.nqueue) break;
        copy_fields(vm, vm->gc.queue[--vm->gc.nqueue], mode);
    }
    *cp = c;
    *atp = at;
}

/* The value stack as roots. Every slot, where the engine does not say what
   is live (the stack bytecode; VM.frame_live). Where it does, the registers
   of a frame that waits for a call are roots as far as they are live there,
   and a dead one that holds a pointer is made unit: it is not copied, and it
   must not stay behind pointing into the space that is left, since the frame
   becomes the one that runs again, whose registers are all roots (what it is
   doing when a collection comes is not known here). Of a frame's header in
   the stack (runtime/register: native-frames.md, M4) only the closure is
   visited, made unit where the frame does not read one, and a stale word
   is made unit where it is a pointer (FrameRef.closure_slot, stale_slot;
   GC_BELOW_FRAME, gc.h); the other slots between frames are visited. Above
   sp the stack's clean part is made unit (vm_clean_stack, performance M6):
   a frame made there later takes its slots as they are.

   The stack's summary (vm.h, GcState.stack_roots): a walk sets the bit of
   every slot it visits below the frame that runs and clears the others'
   -- this walk, and a minor collection's, of the frames from the
   watermark up (minor.c, minor_stack). A frame below the lowest that has
   run since the summary was made (GcState.stack_low, and the watermark,
   below which no frame has run since the last collection) has not run,
   returned or been returned into, so that its slots are as the walk left
   them: roots where it visited them, unit or an immediate elsewhere (a
   collection moves what a root points to, never which slots are roots).
   The next walk visits those slots by their bits and decodes only the
   frames above (gc_stack_frames): in a deep recursion, few -- the frames
   that ran since the last collection -- where it decoded them all at
   every full collection. A walk where the engine says nothing of what is
   live (the stack bytecode, the debugger's mode) leaves no summary. */
int gc_stack_room(VM *vm, size_t n) {
    size_t words = (n + 63) / 64;
    if (words <= vm->gc.stack_words) return 1;
    size_t cap = vm->gc.stack_words ? vm->gc.stack_words : 64;
    while (cap < words) cap *= 2;
    uint64_t *r = realloc(vm->gc.stack_roots, cap * sizeof *r);
    if (!r) return 0;
    vm->gc.stack_roots = r;
    uint64_t *a = realloc(vm->gc.stack_aside, cap * sizeof *a);
    if (!a) return 0;
    vm->gc.stack_aside = a;
    vm->gc.stack_words = cap;
    return 1;
}

size_t gc_stack_frames(VM *vm, FrameRef **out, size_t *from, size_t bound) {
    size_t low = vm->gc.stack_low, w = vm_frames_low(vm), id = vm_frame_id(vm);
    if (w < low) low = w;
    if (id < low) low = id;
    if (bound > vm->gc.stack_valid) bound = vm->gc.stack_valid;
    *from = 0;
    if (low && bound) {
        /* the frames from the lowest that ran: the slots below the first's
           header those of frames that did not, where the summary has them */
        size_t n = vm_frames_from(vm, low, out);
        if (n && (*out)[0].head <= bound) { *from = (*out)[0].head; return n; }
    }
    return vm_frames_from(vm, 0, out);
}

size_t gc_stack_record(VM *vm, const FrameRef *fr, size_t nf, size_t from) {
    size_t rec = nf ? fr[nf - 1].head : 0;
    if (rec > vm->sp || (rec && !gc_stack_room(vm, rec))) return 0;
    if (rec) gc_bits_clear(vm->gc.stack_roots, from, rec);
    return rec;
}

/* the summary's slots below from visited, as many as were roots */
static size_t stack_replay(VM *vm, size_t from, void (*visit)(VM *, Value *)) {
    const uint64_t *b = vm->gc.stack_roots;
    size_t n = 0;
    for (size_t w = 0; w << 6 < from; w++) {
        uint64_t x = b[w];
        if ((w + 1) << 6 > from) x &= ((uint64_t)1 << (from & 63)) - 1;
        for (; x; x &= x - 1, n++) visit(vm, &vm->stack[(w << 6) + (size_t)__builtin_ctzll(x)]);
    }
    return n;
}

void gc_stack_roots(VM *vm, void (*visit)(VM *, Value *)) {
    size_t at = 0, live = 0, from = 0, nf = 0;
    FrameRef *fr = NULL;
    int cafs = 0;
    if (!vm->frame_live) vm->gc.stack_valid = 0;   /* every slot a root: no summary */
    else if (!(cafs = caf_frames_reuse(&fr, &nf, &from)))
        nf = gc_stack_frames(vm, &fr, &from, SIZE_MAX);   /* the frames, the top level's first (native-frames.md, M3), from the lowest that ran */
    /* the summary made again of the slots below the frame that runs; the
       CAF tables' part (caf_frames) for no slot past those below from,
       where they did not make it */
    size_t rec = vm->frame_live ? gc_stack_record(vm, fr, nf, from) : 0;
    if (!cafs && vm->gc.stack_aside_valid > from) vm->gc.stack_aside_valid = from;
    if (from) {
        live += stack_replay(vm, from, visit);
        at = from;
    }
#define STACK_VISIT(vm_, v_) (live++, visit((vm_), (v_)), gc_stack_bit((vm_), (v_), rec))
    for (size_t k = 0; k + 1 < nf; k++) {
        const FrameRef *f = &fr[k];
        size_t end = fr[k + 1].base < vm->sp ? fr[k + 1].base : vm->sp;
        uint32_t n = vm->prog.funcs[f->func].nlocals;
        uint64_t regs = vm_callback_live(vm, f);
        GC_BELOW_FRAME(vm, f, at, end, STACK_VISIT);
        for (uint32_t r = 0; r < n && at < end; r++, at++) {
            if (r >= 64 || ((regs >> r) & 1)) STACK_VISIT(vm, &vm->stack[at]);
            else if (val_is_ptr(vm->stack[at])) vm->stack[at] = mk_unit();
        }
        vm->gc_counts.frames++;
    }
    if (nf && vm_frame_top_live(vm, &fr[nf - 1])) {
        /* the frame that runs, where runtime/register's compiled code said
           what of it is live (VM.top_live, M6): as a frame that waits, since
           a register it has not written may hold what an earlier frame there
           wrote, and none is filled with unit */
        const FrameRef *f = &fr[nf - 1];
        uint32_t n = vm->prog.funcs[f->func].nlocals;
        GC_BELOW_FRAME(vm, f, at, vm->sp, STACK_VISIT);
        for (uint32_t r = 0; r < n && at < vm->sp; r++, at++) {
            if (r >= 64 || ((vm->top_live >> r) & 1)) STACK_VISIT(vm, &vm->stack[at]);
            else if (val_is_ptr(vm->stack[at])) vm->stack[at] = mk_unit();
        }
    }
    for (; at < vm->sp; at++) STACK_VISIT(vm, &vm->stack[at]);
#undef STACK_VISIT
    vm_clean_stack(vm);   /* above sp nothing is to point into what the collection leaves (M6) */
    if (vm->frame_live) gc_stack_recorded(vm, rec);
    vm->gc_counts.slots += vm->sp;
    vm->gc_counts.live_slots += live;
}

/* --gc-verify: the summary against the frames below the lowest that ran,
   decoded again as gc_stack_roots decodes them: every slot that would be
   visited has its bit, and every other is not a pointer; every closure
   the CAF tables would take last has its bit, and its frame's table is
   among the summary's (caf.c) */
const char *gc_stack_check(VM *vm) {
    if (!vm->frame_live || !vm->gc.stack_valid) return NULL;
    FrameRef *fr;
    size_t from;
    (void)gc_stack_frames(vm, &fr, &from, SIZE_MAX);
    if (!from) return NULL;
    if (from > vm->sp) return "the stack's summary describes slots above sp";
    size_t nf = vm_frames_from(vm, 0, &fr), k = 0, at = 0;
    const uint64_t *bits = vm->gc.stack_roots, *aside = vm->gc.stack_aside;
    size_t aside_to = vm->gc.stack_aside_valid < from ? vm->gc.stack_aside_valid : from;
#define BIT(b_, i_) ((int)(((b_)[(i_) >> 6] >> ((i_) & 63)) & 1))
    for (; k + 1 < nf && at < from; k++) {
        const FrameRef *f = &fr[k];
        size_t end = fr[k + 1].base < vm->sp ? fr[k + 1].base : vm->sp;
        size_t below = f->closure_slot ? f->head : f->base;
        for (; at < below && at < end && at < from; at++)
            if (!BIT(bits, at)) return "a slot between frames that the stack's summary does not visit";
        if (at >= from) break;
        if (f->closure_slot && at == below && f->base <= end) {
            for (size_t h = f->head; h < f->base && h < from; h++) {
                int closure = vm->stack + h == f->closure_slot;
                if (BIT(bits, h) != (closure && f->closure != NULL))
                    return "a word of a frame's header that the stack's summary has otherwise";
                if (closure && !f->closure && val_is_ptr(vm->stack[h])) return "a closure of a frame that reads none, a pointer";
                if (closure && h < aside_to && BIT(aside, h) != (f->closure != NULL))
                    return "a frame's closure that the stack's summary sets aside otherwise";
            }
            if (f->stale_slot && (size_t)(f->stale_slot - vm->stack) < from && val_is_ptr(*f->stale_slot))
                return "a stale word of a frame's header, a pointer";
            at = f->base;
        }
        uint32_t n = vm->prog.funcs[f->func].nlocals;
        uint64_t live = vm_callback_live(vm, f);
        for (uint32_t r = 0; r < n && at < end && at < from; r++, at++) {
            int root = r >= 64 || ((live >> r) & 1);
            if (root != BIT(bits, at)) return "a register that the stack's summary has otherwise";
            if (!root && val_is_ptr(vm->stack[at])) return "a dead register below the frames that ran, a pointer";
        }
    }
#undef BIT
    if (aside_to && vm->caf) return caf_stack_check(vm, fr, nf, aside_to);
    return NULL;
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

    Chunk *c = vm->gc.first;
    size_t at = 0;
    if (caf_begin(vm)) {
        /* a program with suspensions: a global kept only where live code
           reaches it (caf.c), the frames' closures last */
        caf_frames(vm, copy_value, 1);
        gc_stack_roots(vm, copy_value);   /* the frames caf_frames walked, their closures set aside */
        caf_frames_forget();
        caf_roots(vm, copy_value, copy_objp);   /* (the stack VM's frames' closures set aside too) */
        caf_back(vm);
        copy_scan(vm, &c, &at, 1);
        CafAside *a;
        size_t na = caf_aside(&a);
        for (size_t i = 0; i < na; i++) {
            Obj *o;
            if (a[i].slot) { copy_value(vm, a[i].slot); o = val_is_ptr(*a[i].slot) ? val_ptr(*a[i].slot) : NULL; }
            else { *a[i].root = copy_obj(vm, *a[i].root); o = *a[i].root; }
            if (o && caf_runs(o)) caf_only_add(o);
        }
        copy_scan(vm, &c, &at, 2);
        caf_end(vm);
    } else {
        gc_stack_roots(vm, copy_value);
#define COPY_ROOT_VALUE(v) (vm->gc_counts.other_roots++, COPY_VALUE(v))
#define COPY_ROOT_OBJ(o) (vm->gc_counts.other_roots++, COPY_OBJ(o))
        OTHER_ROOTS(vm, COPY_ROOT_VALUE, COPY_ROOT_OBJ);
#undef COPY_ROOT_VALUE
#undef COPY_ROOT_OBJ
        copy_scan(vm, &c, &at, 0);
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
        vm_frames_mark_low(vm, vm_frame_id(vm));   /* nothing young is left on the stack */
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

/* Lazy ML's suspension does not go under evaluation, so a force of it from
   inside its own code runs it again, updates it, and returns: the outer
   run goes on with its frame's closure an indirection, and updates it again
   (D57, M26; E14's k_outlive). An indirection a frame from low up runs is
   pinned: no field is given what it holds, the frame's own closure slot
   among them, so the second update writes it and every holder sees it.
   Frames below low have not run since the last minor collection, which
   pinned what they ran; a full collection starts from 0. Nothing where no
   function of the program says UPDATE and not BLACKHOLE (Program's reruns):
   no program of SML, and none of Haskell's, whose suspensions say BLACKHOLE
   at their entry and so are not run again while they run. */
void gc_pin_running(VM *vm, size_t low) {
    if (!vm->prog.reruns) return;
    FrameRef *fr = NULL;
    size_t nf = vm_frames_from(vm, low, &fr);
    for (size_t k = 0; k < nf; k++) {
        Obj *c = fr[k].closure;
        if (c && obj_kind(c) == K_IND) obj_set_contag(c, IND_RUNNING);
    }
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

/* the adaptive nursery (docs/plans/garbage-collector-v2.md, D2): half of
   what the heap has room for, within --nursery and --nursery-max */
static void nursery_adapt(VM *vm) {
    if (vm->gc.nursery && vm->gc.nursery_max && vm->alloc.used == 0) {
        size_t room = vm->gc.size > USED_STOCK(vm) ? (vm->gc.size - USED_STOCK(vm)) / 2 : 0;
        size_t want = room < vm->gc.nursery_min ? vm->gc.nursery_min : room > vm->gc.nursery_max ? vm->gc.nursery_max : room;
        want &= ~(size_t)65535;
        if (want >= 4096 && want != vm->gc.nursery_size) nursery_start(vm, want);
    }
}

/* After the low-pause collector's cycle ended in a minor collection's
   pause (cycle.c): the heap's size and the nursery's made again from what
   it left, as after a full collection */
void gc_after_cycle(VM *vm) {
    vm->gc.size = grown(vm, vm->gc.size, USED_STOCK(vm), 0);
    vm->live_before = vm->live_last;
    vm->live_last = USED_STOCK(vm);
    nursery_adapt(vm);
}

/* Runtime.collect: a full collection, a cycle that marks ended first */
void vm_collect(VM *vm) {
    vm->gc.full_wanted = 1;
    vm_gc(vm, 0);
    vm->gc.full_wanted = 0;
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
        /* a non-moving old space grows without a collection into it; where
           the low-pause collector's cycle marks, it is ended first, and is
           the collection where that leaves room (cycle.c) */
        size_t count = vm->gc_count;
        uint64_t minors = vm->gc.minors;
        int marking = cycle_complete(vm);
        int ended = marking && !vm->gc.full_wanted
                    && USED_STOCK(vm) <= vm->gc.size && needed <= vm->gc.size - USED_STOCK(vm);
        /* one call one collection, as Runtime.stats counts them: the
           cycle's end, or the full collection after it -- of the whole heap,
           and no minor one */
        if (marking) {
            vm->gc_count = count + (size_t)ended;
            vm->gc.minors = minors;
        }
        if (!ended) collect_pass(vm, vm->gc.size);
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
    nursery_adapt(vm);
    CENSUS_GC_END(vm);
    int64_t user = sys_time_user() - user0, sys = sys_time_sys() - sys0;
    vm->gc_user_us += user;
    vm->gc_sys_us += sys;
    if (user + sys > vm->gc_longest_us) vm->gc_longest_us = user + sys;
    if (vm->gc_ns - ns0 > vm->gc_longest_ns) vm->gc_longest_ns = vm->gc_ns - ns0;
}
