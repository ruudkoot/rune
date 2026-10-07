/* Cheney semispace copying collector. Objects are 8-byte aligned; the payload
   is rounded up to what runtime/value.h says (a word under this layout) and
   is at least that, so that a forwarding pointer always fits. */
#include "vm.h"
#include "sys/sys.h"
#include <string.h>

/* The census VM (runtime/census/census.h) carries an id word in every header, 8 bytes
   more per object: the sizes the stock VM counts and collects by are kept
   apart (STOCK, USED_STOCK), so that --count prints the stock numbers and
   a collection happens where the stock VM's would, and each semispace is
   made half again as large as its stock size, room for the extra word of
   every object (at most a third more, 32 bytes for the stock 24). */
#ifdef RUNE_CENSUS
#define STOCK(size) ((size) - 8)
#define REAL_SPACE(n) ((n) + (n) / 2)
#define USED_STOCK(vm) ((vm)->census_used_stock)
#define ADD_STOCK(vm, size) ((vm)->census_used_stock += STOCK(size))
#else
#define STOCK(size) (size)
#define REAL_SPACE(n) (n)
#define USED_STOCK(vm) ((vm)->alloc.used)
#define ADD_STOCK(vm, size) ((void)0)
#endif

size_t obj_size(const Obj *o) { return obj_size_of(obj_kind(o), obj_len(o)); }

/* what the word cannot hold, as a small raw object (runtime/value.h) */
static Value alloc_box(VM *vm, int kind, uint64_t bits) {
    Obj *o = vm_alloc(vm, (uint8_t)kind, 0, 1, 8);
    memcpy(obj_bytes(o), &bits, 8);
    return mk_ptr(o);
}
Value mk_real(VM *vm, double d) {
    Value v;
    if (mk_real_imm(d, &v)) return v;
    int k = real_box_of(real_bits(d));
    if (k >= 0 && vm->real_boxes[k]) return mk_ptr(vm->real_boxes[k]);
    return alloc_box(vm, K_REAL, real_bits(d));
}
/* the VM's boxes of zero, the infinities and NaN (value.h): made as the VM
   starts, so that every engine has them at the same place in its heap; with
   every real boxed (RUNE_REAL_BOXED, the switch that measures boxing) none */
static void real_boxes_make(VM *vm) {
#ifdef RUNE_REAL_BOXED
    (void)vm;
#else
    static const uint64_t bits[REAL_BOXES] = REAL_BOX_BITS;
    /* before the program: no collection is due (--gc-stress counts from its
       first allocation), and --stats counts the boxes the program makes */
    size_t stress = vm->gc_stress;
    vm->gc_stress = 0;
    for (int k = 0; k < REAL_BOXES; k++) vm->real_boxes[k] = val_ptr(alloc_box(vm, K_REAL, bits[k]));
    vm->gc_stress = stress;
    vm->boxes_allocated = 0;
    vm->box_bytes_allocated = 0;
#endif
}
Value mk_int_vm(VM *vm, int64_t i) {
    if (int_fits(i)) return mk_imm(i);
#ifdef RUNE_INT64
    return alloc_box(vm, K_BOX, (uint64_t)i);
#else
    vm_fatal(vm, "an int beyond 63 bits: %lld", (long long)i);
    return mk_unit();
#endif
}
Value mk_box_vm(VM *vm, uint64_t bits) { return alloc_box(vm, K_BOX, bits); }
Value mk_int64_vm(VM *vm, int64_t i) { return int_fits(i) ? mk_imm(i) : alloc_box(vm, K_BOX, (uint64_t)i); }
Value mk_word64_vm(VM *vm, uint64_t w) { return word_fits(w) ? mk_imm((int64_t)w) : alloc_box(vm, K_BOX, w); }
Value mk_word_vm(VM *vm, uint64_t w) {
    if (word_fits(w)) return mk_imm((int64_t)w);
#ifdef RUNE_INT64
    return alloc_box(vm, K_BOX, w);
#else
    (void)vm;
    return mk_imm((int64_t)(w & ((UINT64_C(1) << 63) - 1)));
#endif
}

#ifdef RUNE_BARRIER_CARDS
uint8_t *rune_cards;   /* the measuring barrier's table (value.h): written, never read */
/* the table, made once for the process, and where compiled code of this VM
   finds it: a VM that an image became has not been through heap_init */
void heap_cards(VM *vm) {
    if (!rune_cards) rune_cards = calloc(CARD_COUNT, 1);
    if (!rune_cards) { fprintf(stderr, "runevm: cannot allocate the cards\n"); exit(2); }
    vm->jit_cards = rune_cards;
}
#endif

/* A semispace: 8-aligned, as malloc gives it, so that bits 1 and 2 of a
   pointer into it are clear (value.h, what the layout keeps open). */
static char *space_new(size_t bytes) {
    char *p = malloc(bytes);
    if (p && ((uintptr_t)p & 7) != 0) { fprintf(stderr, "runevm: a heap that is not 8-aligned\n"); exit(2); }
    return p;
}

void heap_init(VM *vm, size_t semispace_bytes) {
    if (vm->heap_limit && semispace_bytes > vm->heap_limit) semispace_bytes = vm->heap_limit;
    vm->alloc.size = semispace_bytes;
    vm->alloc.from = space_new(REAL_SPACE(semispace_bytes));
    vm->gc.kept = NULL;
    vm->alloc.used = 0;
#ifdef RUNE_CENSUS
    vm->census_used_stock = 0;
#endif
    vm->heap_fill = 50;
    vm->gc_count = 0;
    vm->live_last = 0;
    vm->live_before = 0;
    vm->gc_user_us = 0;
    vm->gc_sys_us = 0;
    vm->gc_longest_us = 0;
    vm->gc_calls = 0;
    vm->gc_ns = 0;
    vm->gc_longest_ns = 0;
    vm->bytes_allocated = 0;
    vm->objects_allocated = 0;
    vm->boxes_allocated = 0;
    vm->box_bytes_allocated = 0;
    vm->box_bytes_live = 0;
    vm->copied = 0;
    vm->max_live = 0;
    if (!vm->alloc.from) { fprintf(stderr, "runevm: cannot allocate heap\n"); exit(2); }
#ifdef RUNE_BARRIER_CARDS
    heap_cards(vm);
#endif
    real_boxes_make(vm);
}

Obj *vm_alloc(VM *vm, uint8_t kind, uint16_t contag, uint32_t len, size_t payload_bytes) {
    size_t size = obj_alloc_size(payload_bytes);
    CENSUS_FLUSH();
    if (STOCK(size) > vm->alloc.size - USED_STOCK(vm) ||
        (vm->gc_stress && (vm->objects_allocated + vm->boxes_allocated) % vm->gc_stress == 0) ||
        CENSUS_FORCED()) {
        vm_gc(vm, STOCK(size));
    }
    Obj *o = (Obj *)(vm->alloc.from + vm->alloc.used);
    vm->alloc.used += size;
    ADD_STOCK(vm, size);
    if (kind == K_REAL || kind == K_BOX) { vm->box_bytes_allocated += STOCK(size); vm->boxes_allocated++; vm->box_bytes_live += size; }
    else { vm->bytes_allocated += STOCK(size); vm->objects_allocated++; }
    obj_init(o, kind, contag, len);
    CENSUS_ALLOC(vm, o, size);
    return o;
}

Obj *vm_alloc_fields(VM *vm, uint8_t kind, uint16_t contag, uint32_t nfields) {
    Obj *o = vm_alloc(vm, kind, contag, nfields, obj_payload_bytes(kind, nfields));
    Value *f = obj_fields(o);
    for (uint32_t i = 0; i < nfields; i++) f[i] = mk_unit();
    return o;
}

Obj *vm_alloc_string(VM *vm, uint32_t len) {
    return vm_alloc(vm, K_STRING, 0, len, len);
}

Obj *vm_string_from(VM *vm, const char *s, uint32_t len) {
    Obj *o = vm_alloc_string(vm, len);
    if (len) memcpy(obj_bytes(o), s, len);
    return o;
}

/* --- collection --- */

/* What a collection in progress has is the VM's (GcState, vm.h): the space
   copied into, how much of it is taken, and how much of that is boxes. */
static Obj *copy_obj(VM *vm, Obj *o) {
    if (obj_forwarded(o)) return obj_forwarding(o);
    vm->gc_counts.objects++;
    size_t size = obj_size(o);
    if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) vm->gc.to_boxes += size;
    Obj *n = (Obj *)(vm->gc.to + vm->gc.to_used);
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

/* The roots, listed once, for the collector and for a heap that moved
   (heap_relocate): the value stack, and these. V takes the address of a
   value, O of a pointer to an object that is there. */
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
#define COPY_VALUE(v) copy_value(vm, (v))
#define COPY_OBJ(o) (*(o) = copy_obj(vm, *(o)))

/* The value stack as roots. Every slot, where the engine does not say what
   is live (the stack bytecode; VM.frame_live). Where it does, the registers
   of a frame that waits for a call are roots as far as they are live there,
   and a dead one that holds a pointer is made unit: it is not copied, and it
   must not stay behind pointing into the space that is left, since the frame
   becomes the one that runs again, whose registers are all roots (what it is
   doing when a collection comes is not known here). */
static void stack_roots(VM *vm) {
    size_t at = 0, dead = 0;
    if (vm->frame_live && vm->frames_active)
        for (size_t k = 0; k < vm->fp; k++) {
            const Frame *f = &vm->frames[k];
            size_t end = vm->frames[k + 1].base < vm->sp ? vm->frames[k + 1].base : vm->sp;
            uint32_t n = vm->prog.funcs[f->func].nlocals;
            uint64_t live = vm->frame_live(vm, f->func, vm->frames[k + 1].ret_pc);
            for (; at < f->base && at < end; at++) copy_value(vm, &vm->stack[at]);
            for (uint32_t r = 0; r < n && at < end; r++, at++) {
                if (r >= 64 || ((live >> r) & 1)) copy_value(vm, &vm->stack[at]);
                else {
                    dead++;
                    if (val_is_ptr(vm->stack[at])) vm->stack[at] = mk_unit();
                }
            }
            vm->gc_counts.frames++;
        }
    for (; at < vm->sp; at++) copy_value(vm, &vm->stack[at]);
    vm->gc_counts.slots += vm->sp;
    vm->gc_counts.live_slots += vm->sp - dead;
}

/* The heap is two semispaces, both kept: the one collected from is the next
   one collected into, as long as the heap stays the size it is. A new one
   for every collection, as before, cost the kernel's work of giving fresh
   pages every time. */
static void collect_into(VM *vm, size_t new_size) {
    if (vm->gc.kept && new_size == vm->alloc.size) vm->gc.to = vm->gc.kept;
    else {
        free(vm->gc.kept);
        vm->gc.to = space_new(REAL_SPACE(new_size));
        if (!vm->gc.to) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
    }
    vm->gc.kept = NULL;
    vm->gc.to_used = 0;
    vm->gc.to_boxes = 0;
#ifdef RUNE_CENSUS
    vm->gc.to_used_stock = 0;
    census_collect_begin();
#endif

    stack_roots(vm);
#define COPY_ROOT_VALUE(v) (vm->gc_counts.other_roots++, COPY_VALUE(v))
#define COPY_ROOT_OBJ(o) (vm->gc_counts.other_roots++, COPY_OBJ(o))
    OTHER_ROOTS(vm, COPY_ROOT_VALUE, COPY_ROOT_OBJ);
#undef COPY_ROOT_VALUE
#undef COPY_ROOT_OBJ

    /* scan */
    size_t scan = 0;
    while (scan < vm->gc.to_used) {
        Obj *o = (Obj *)(vm->gc.to + scan);
        size_t size = obj_size(o);
        if (obj_has_fields(o)) {
            Value *f = obj_fields(o);
            uint32_t n = obj_scanned_fields(o);   /* every field; of an indirection, the first */
            for (uint32_t i = 0; i < n; i++) copy_value(vm, &f[i]);
        }
        scan += size;
    }

    if (new_size == vm->alloc.size) vm->gc.kept = vm->alloc.from;
    else free(vm->alloc.from);
    vm->alloc.from = vm->gc.to;
    vm->alloc.used = vm->gc.to_used;
    vm->box_bytes_live = vm->gc.to_boxes;
#ifdef RUNE_CENSUS
    USED_STOCK(vm) = vm->gc.to_used_stock;
#endif
    vm->alloc.size = new_size;
    vm->gc_count++;
    vm->copied += vm->gc.to_used;
    if (vm->gc.to_used > vm->max_live) vm->max_live = vm->gc.to_used;
    vm->gc.to = NULL;
}

/* A pass of the copier, as --gc-log sees it: timed on the monotonic clock
   (and on the thread's processor time where it is written), with what it
   counted, one line of the log each (the columns are docs/runtime.md's).
   A collection that grows the heap is two passes, two lines with the same
   call number. The clocks are read where there is no log too: their sum
   and the longest collection are RUNE_MEMSTAT's (runtime.c, vm_exit). */
static void heap_verify(VM *vm, const char *when);

static void collect_pass(VM *vm, size_t new_size) {
    uint64_t bytes = vm->bytes_allocated, objects = vm->objects_allocated, instrs = vm->instructions;
    uint64_t boxes = vm->boxes_allocated, box_bytes = vm->box_bytes_allocated;
    size_t used_before = USED_STOCK(vm);
    memset(&vm->gc_counts, 0, sizeof vm->gc_counts);
    if (vm->gc_verify) heap_verify(vm, "before");
    int64_t cpu0 = vm->gc_log ? sys_thread_time_ns() : 0;
    int64_t t0 = sys_clock_ns();
    collect_into(vm, new_size);
    int64_t pause = sys_clock_ns() - t0;
    if (vm->gc_verify) heap_verify(vm, "after");
    vm->gc_ns += pause;
    if (!vm->gc_log) return;
    int64_t cpu = sys_thread_time_ns() - cpu0;
    uint64_t resident, peak_resident, peak_virtual;
    sys_mem_usage(&resident, &peak_resident, &peak_virtual);
    /* seq kind vmgc bytes objects instrs boxes box_bytes used_before copied
       copied_objs promoted slots live_slots frames other_roots cards_dirty
       cards_scanned remembered live_after heap_size pause_ns cpu_ns
       rss_bytes t_ns cards_young fields_scanned */
    fprintf(vm->gc_log, "%llu full %llu %llu %llu %llu %llu %llu %llu %llu %llu 0 %llu %llu %llu %llu 0 0 0 %llu %llu %lld %lld %llu %lld 0 0\n",
            (unsigned long long)vm->gc_count, (unsigned long long)vm->gc_calls,
            (unsigned long long)bytes, (unsigned long long)objects, (unsigned long long)instrs,
            (unsigned long long)boxes, (unsigned long long)box_bytes, (unsigned long long)used_before,
            (unsigned long long)USED_STOCK(vm), (unsigned long long)vm->gc_counts.objects,
            (unsigned long long)vm->gc_counts.slots, (unsigned long long)vm->gc_counts.live_slots,
            (unsigned long long)vm->gc_counts.frames, (unsigned long long)vm->gc_counts.other_roots,
            (unsigned long long)USED_STOCK(vm), (unsigned long long)vm->alloc.size,
            (long long)pause, (long long)cpu, (unsigned long long)resident, (long long)(t0 - vm->gc_log_t0));
}

void heap_log_open(VM *vm, const char *path) {
    vm->gc_log = fopen(path, "w");
    if (!vm->gc_log) { fprintf(stderr, "runevm: --gc-log %s: cannot open\n", path); exit(2); }
    fprintf(vm->gc_log, "# rune-gc-log 1 nursery=0 heap=%zu fill=%u limit=%zu\n", vm->alloc.size, vm->heap_fill, vm->heap_limit);
    fprintf(vm->gc_log, "# seq kind vmgc bytes objects instrs boxes box_bytes used_before copied copied_objs promoted "
            "slots live_slots frames other_roots cards_dirty cards_scanned remembered live_after heap_size "
            "pause_ns cpu_ns rss_bytes t_ns cards_young fields_scanned\n");
    vm->gc_log_t0 = sys_clock_ns();
}

void heap_log_close(VM *vm) {
    if (!vm->gc_log) return;
    uint64_t resident, peak_resident, peak_virtual;
    sys_mem_usage(&resident, &peak_resident, &peak_virtual);
    fprintf(vm->gc_log, "# end bytes %llu objects %llu instrs %llu boxes %llu box_bytes %llu collections %llu gc_ns %llu "
            "vmpeak_kb %llu vmhwm_kb %llu\n",
            (unsigned long long)vm->bytes_allocated, (unsigned long long)vm->objects_allocated,
            (unsigned long long)vm->instructions, (unsigned long long)vm->boxes_allocated,
            (unsigned long long)vm->box_bytes_allocated, (unsigned long long)vm->gc_count,
            (unsigned long long)vm->gc_ns, (unsigned long long)(peak_virtual / 1024),
            (unsigned long long)(peak_resident / 1024));
    fprintf(vm->gc_log, "# wall_ns %lld\n", (long long)(sys_clock_ns() - vm->gc_log_t0));
    fclose(vm->gc_log);
    vm->gc_log = NULL;
}

/* --gc-verify: the heap checked before and after every pass of the
   collector, so that one that breaks it is caught at the collection that
   did (make test-heap runs tests/lang so). What holds of the copier's
   space: it parses, object by object, to exactly alloc.used; every header
   names a kind of today and none is a forwarding one; the boxes in it are
   the bytes box_bytes_live counts; and every pointer in a field, on the
   stack or among the other roots is to the start of an object in it.
   heap_check says what does not hold, or NULL (tests/runtime/heap_test.c
   breaks a heap to see it); a collection under --gc-verify stops on it. */
typedef struct Check {
    const VM *vm;
    uint8_t *starts;     /* a bit for every 8 bytes of the space: an object begins there */
    const char *failed;  /* the first thing found not to hold */
    const void *at;
} Check;

static void check_fail(Check *c, const char *what, const void *at) {
    if (!c->failed) { c->failed = what; c->at = at; }
}

static void check_ptr(Check *c, const void *p, const char *what) {
    if (!p) return;
    uintptr_t at = (uintptr_t)((const char *)p - c->vm->alloc.from);
    if (at >= c->vm->alloc.used || at % 8 != 0 || !(c->starts[at / 64] >> (at / 8 % 8) & 1)) check_fail(c, what, p);
}

static void check_value(Check *c, const Value *v, const char *what) {
    if (val_is_ptr(*v)) check_ptr(c, val_ptr(*v), what);
}

const char *heap_check(VM *vm, const void **at) {
    Check c = { vm, calloc(vm->alloc.used / 64 + 1, 1), NULL, NULL };
    if (!c.starts) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
    size_t scan = 0, boxes = 0;
    while (scan < vm->alloc.used && !c.failed) {
        Obj *o = (Obj *)(vm->alloc.from + scan);
        size_t size = 0;
        if (vm->alloc.used - scan < OBJ_HEADER_SIZE) check_fail(&c, "a header cut off at the end of the space", o);
        else if (obj_kind(o) < K_TUPLE || obj_kind(o) > K_LAST || obj_kind(o) == K_FORWARD) check_fail(&c, "a header of no kind", o);
        else if ((size = obj_size(o)) < OBJ_HEADER_SIZE || size > vm->alloc.used - scan) check_fail(&c, "an object past the end of the space", o);
        else {
            if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) boxes += size;
            c.starts[scan / 64] |= (uint8_t)(1u << (scan / 8 % 8));
            scan += size;
        }
    }
    if (!c.failed && boxes != vm->box_bytes_live) check_fail(&c, "boxes not as box_bytes_live counts them", NULL);
    for (scan = 0; scan < vm->alloc.used && !c.failed; scan += obj_size((Obj *)(vm->alloc.from + scan))) {
        Obj *o = (Obj *)(vm->alloc.from + scan);
        if (!obj_has_fields(o)) continue;
        const Value *f = obj_fields(o);
        for (uint32_t i = 0; i < obj_scanned_fields(o); i++) check_value(&c, &f[i], "a field that is no object's");
    }
    for (size_t i = 0; i < vm->sp && !c.failed; i++) check_value(&c, &vm->stack[i], "a slot of the stack that is no object's");
#define CHECK_VALUE(v) check_value(&c, (v), "a root that is no object's")
#define CHECK_OBJ(o) check_ptr(&c, *(o), "a root that is no object")
    if (!c.failed) OTHER_ROOTS(vm, CHECK_VALUE, CHECK_OBJ);
#undef CHECK_VALUE
#undef CHECK_OBJ
    free(c.starts);
    if (at) *at = c.at;
    return c.failed;
}

static void heap_verify(VM *vm, const char *when) {
    const void *at;
    const char *failed = heap_check(vm, &at);
    if (!failed) return;
    fprintf(stderr, "runevm: --gc-verify: %s collection %zu: %s (%p)\n", when, vm->gc_count + 1, failed, at);
    exit(2);
}

/* heap_fill% of n bytes, rounded down, which for 50 is n / 2 */
static size_t fill_of(const VM *vm, size_t n) {
    return n / 100 * vm->heap_fill + n % 100 * vm->heap_fill / 100;
}

/* The size, doubled from size as often as it must be, at which a heap that
   holds used bytes and must take needed more is at most heap_fill% full,
   half unless --heap-fill says otherwise, to avoid thrashing; written so
   that nothing wraps where a size_t is 32 bits. */
static size_t grown(const VM *vm, size_t size, size_t used, size_t needed) {
    size_t want = size;
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
        if (want > SIZE_MAX / 2) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
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
    /* Where the heap must grow, collecting into a space of the same size
       and then again into a larger one made the largest collections of a
       run. So guess first whether it must: the survivors grow about as
       they grew between the last two collections. A guess too high grows
       the heap one collection early; one too low collects again below, as
       before. A space of the current size or larger always holds what
       survives. */
    size_t guess = vm->live_last;
    if (vm->live_last > vm->live_before) {
        guess += vm->live_last - vm->live_before;
        /* no more than can survive: it would wrap, or grow the heap more
           than once on a guess */
        if (guess < vm->live_last || guess > vm->alloc.size) guess = vm->alloc.size;
    }
    collect_pass(vm, grown(vm, vm->alloc.size, guess, needed));
    size_t want = grown(vm, vm->alloc.size, USED_STOCK(vm), needed);
    if (want != vm->alloc.size) collect_pass(vm, want);
    if (needed > vm->alloc.size - vm->alloc.used) vm_limit(vm, "heap limit exceeded");
    vm->live_before = vm->live_last;
    vm->live_last = USED_STOCK(vm);
    CENSUS_GC_END(vm);
    int64_t user = sys_time_user() - user0, sys = sys_time_sys() - sys0;
    vm->gc_user_us += user;
    vm->gc_sys_us += sys;
    if (user + sys > vm->gc_longest_us) vm->gc_longest_us = user + sys;
    if ((int64_t)(vm->gc_ns - ns0) > vm->gc_longest_ns) vm->gc_longest_ns = (int64_t)(vm->gc_ns - ns0);
}

/* --- relocation, for an image of the VM (runtime/image.c) --- */

/* The heap and every root were read as the parent had them, its addresses
   in them: each pointer moves by the distance between the two heaps. A
   pointer that is not into the heap's used part, or an object that is not
   one, makes the image unsound (0). */

static Obj *relocate_obj(VM *vm, Obj *o) {
    uintptr_t at = (uintptr_t)o;
    if (at < vm->gc.reloc_old || at - vm->gc.reloc_old >= vm->alloc.used) { vm->gc.reloc_ok = 0; return NULL; }
    return (Obj *)(vm->alloc.from + (at - vm->gc.reloc_old));
}

static void relocate_value(VM *vm, Value *v) {
    if (val_is_ptr(*v)) *v = mk_ptr(relocate_obj(vm, val_ptr(*v)));
}

/* ---- the handles: what C holds across a collection (vm.h) ---- */
size_t vm_handle_new(VM *vm, Value v) {
    if (vm->handles_free) {
        size_t h = vm->handles_free - 1;
        vm->handles_free = (size_t)val_imm(vm->handles[h]);
        vm->handles[h] = v;
        return h;
    }
    if (vm->nhandles == vm->handles_cap) {
        size_t cap = vm->handles_cap ? vm->handles_cap * 2 : 16;
        Value *t = realloc(vm->handles, cap * sizeof *t);
        if (!t) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
        vm->handles = t; vm->handles_cap = cap;
    }
    vm->handles[vm->nhandles] = v;
    return vm->nhandles++;
}
Value vm_handle_get(const VM *vm, size_t h) { return h < vm->nhandles ? vm->handles[h] : mk_unit(); }
void vm_handle_set(VM *vm, size_t h, Value v) { if (h < vm->nhandles) vm->handles[h] = v; }
void vm_handle_free(VM *vm, size_t h) {
    if (h >= vm->nhandles) return;
    vm->handles[h] = mk_imm((int64_t)vm->handles_free);
    vm->handles_free = h + 1;
}

/* the array of bytes or of reals a handle names, or NULL */
static Obj *raw_array(const VM *vm, size_t h) {
    Value v = vm_handle_get(vm, h);
    if (!val_is_ptr(v) || !val_ptr(v)) return NULL;
    Obj *o = val_ptr(v);
    return obj_kind(o) == K_BYTES || obj_kind(o) == K_REALS ? o : NULL;
}
void *vm_pin(VM *vm, size_t h, size_t *bytes) {
    Obj *o = raw_array(vm, h);
    if (!o) return NULL;
    size_t n = obj_payload_bytes(obj_kind(o), obj_len(o));
    void *copy = malloc(n ? n : 1);
    if (!copy) return NULL;
    memcpy(copy, obj_bytes(o), n);
    if (bytes) *bytes = n;
    return copy;
}
void vm_unpin(VM *vm, size_t h, void *copy) {
    Obj *o = raw_array(vm, h);
    if (o && copy) memcpy(obj_bytes(o), copy, obj_payload_bytes(obj_kind(o), obj_len(o)));
    free(copy);
}

int heap_relocate(VM *vm, uintptr_t old_base) {
    vm->gc.reloc_old = old_base;
    vm->gc.reloc_ok = 1;
    size_t scan = 0;
    while (vm->gc.reloc_ok && scan < vm->alloc.used) {
        Obj *o = (Obj *)(vm->alloc.from + scan);
        if (vm->alloc.used - scan < OBJ_HEADER_SIZE || obj_kind(o) < K_TUPLE || obj_kind(o) > K_LAST || obj_kind(o) == K_FORWARD) return 0;
        size_t size = obj_size(o);
        if (size > vm->alloc.used - scan) return 0;
        if (obj_has_fields(o)) {
            Value *f = obj_fields(o);
            for (uint32_t i = 0; i < obj_len(o); i++) relocate_value(vm, &f[i]);
        }
        scan += size;
    }
    /* every slot of the stack, dead registers too: they are values still */
    for (size_t i = 0; i < vm->sp; i++) relocate_value(vm, &vm->stack[i]);
#define RELOCATE_VALUE(v) relocate_value(vm, (v))
#define RELOCATE_OBJ(o) (*(o) = relocate_obj(vm, *(o)))
    OTHER_ROOTS(vm, RELOCATE_VALUE, RELOCATE_OBJ);
#undef RELOCATE_VALUE
#undef RELOCATE_OBJ
    return vm->gc.reloc_ok;
}
