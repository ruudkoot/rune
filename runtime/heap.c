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
#define USED_STOCK(vm) ((vm)->heap_used)
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

/* A semispace: 8-aligned, as malloc gives it, so that bits 1 and 2 of a
   pointer into it are clear (value.h, what the layout keeps open). */
static char *space_new(size_t bytes) {
    char *p = malloc(bytes);
    if (p && ((uintptr_t)p & 7) != 0) { fprintf(stderr, "runevm: a heap that is not 8-aligned\n"); exit(2); }
    return p;
}

void heap_init(VM *vm, size_t semispace_bytes) {
    if (vm->heap_limit && semispace_bytes > vm->heap_limit) semispace_bytes = vm->heap_limit;
    vm->heap_size = semispace_bytes;
    vm->heap_from = space_new(REAL_SPACE(semispace_bytes));
    vm->heap_to = NULL;
    vm->heap_used = 0;
#ifdef RUNE_CENSUS
    vm->census_used_stock = 0;
#endif
    vm->heap_fill = 50;
    vm->gc_count = 0;
    vm->live_last = 0;
    vm->live_before = 0;
    vm->gc_user_us = 0;
    vm->gc_sys_us = 0;
    vm->bytes_allocated = 0;
    vm->objects_allocated = 0;
    vm->boxes_allocated = 0;
    vm->box_bytes_allocated = 0;
    vm->box_bytes_live = 0;
    vm->copied = 0;
    vm->max_live = 0;
    if (!vm->heap_from) { fprintf(stderr, "runevm: cannot allocate heap\n"); exit(2); }
    real_boxes_make(vm);
}

Obj *vm_alloc(VM *vm, uint8_t kind, uint16_t contag, uint32_t len, size_t payload_bytes) {
    size_t size = obj_alloc_size(payload_bytes);
    CENSUS_FLUSH();
    if (STOCK(size) > vm->heap_size - USED_STOCK(vm) ||
        (vm->gc_stress && (vm->objects_allocated + vm->boxes_allocated) % vm->gc_stress == 0) ||
        CENSUS_FORCED()) {
        vm_gc(vm, STOCK(size));
    }
    Obj *o = (Obj *)(vm->heap_from + vm->heap_used);
    vm->heap_used += size;
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

static char *to_space;
static size_t to_used;
#ifdef RUNE_CENSUS
static size_t to_used_stock;
#endif

static size_t to_boxes;   /* of to_used, the boxes (vm.h, box_bytes_live) */
static Obj *copy_obj(Obj *o) {
    if (obj_forwarded(o)) return obj_forwarding(o);
    size_t size = obj_size(o);
    if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) to_boxes += size;
    Obj *n = (Obj *)(to_space + to_used);
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
    to_used += size;
#ifdef RUNE_CENSUS
    to_used_stock += STOCK(size);
#endif
    CENSUS_SURVIVE(n, size);
    obj_forward(o, n);
    return n;
}

static void copy_value(Value *v) {
    if (val_is_ptr(*v)) *v = mk_ptr(copy_obj(val_ptr(*v)));
}

/* The heap is two semispaces, both kept: the one collected from is the next
   one collected into, as long as the heap stays the size it is. A new one
   for every collection, as before, cost the kernel's work of giving fresh
   pages every time. */
static void collect_into(VM *vm, size_t new_size) {
    if (vm->heap_to && new_size == vm->heap_size) to_space = vm->heap_to;
    else {
        free(vm->heap_to);
        to_space = space_new(REAL_SPACE(new_size));
        if (!to_space) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
    }
    vm->heap_to = NULL;
    to_used = 0;
    to_boxes = 0;
#ifdef RUNE_CENSUS
    to_used_stock = 0;
    census_collect_begin();
#endif

    /* roots */
    for (size_t i = 0; i < vm->sp; i++) copy_value(&vm->stack[i]);
    for (uint32_t i = 0; i < vm->prog.nglobals; i++) copy_value(&vm->globals[i]);
    for (uint32_t i = 0; i < vm->prog.nconsts; i++) copy_value(&vm->prog.consts[i]);
    if (vm->frames_active)
        for (size_t i = 0; i <= vm->fp; i++)
            if (vm->frames[i].closure) vm->frames[i].closure = copy_obj(vm->frames[i].closure);
    for (int i = 0; i < NUM_BUILTIN_EXNS; i++)
        if (vm->builtin_exns[i]) vm->builtin_exns[i] = copy_obj(vm->builtin_exns[i]);
    for (int i = 0; i < REAL_BOXES; i++)
        if (vm->real_boxes[i]) vm->real_boxes[i] = copy_obj(vm->real_boxes[i]);

    /* scan */
    size_t scan = 0;
    while (scan < to_used) {
        Obj *o = (Obj *)(to_space + scan);
        size_t size = obj_size(o);
        if (obj_has_fields(o)) {
            Value *f = obj_fields(o);
            for (uint32_t i = 0; i < obj_len(o); i++) copy_value(&f[i]);
        }
        scan += size;
    }

    if (new_size == vm->heap_size) vm->heap_to = vm->heap_from;
    else free(vm->heap_from);
    vm->heap_from = to_space;
    vm->heap_used = to_used;
    vm->box_bytes_live = to_boxes;
#ifdef RUNE_CENSUS
    USED_STOCK(vm) = to_used_stock;
#endif
    vm->heap_size = new_size;
    vm->gc_count++;
    vm->copied += to_used;
    if (to_used > vm->max_live) vm->max_live = to_used;
    to_space = NULL;
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
        if (vm->heap_limit && want > vm->heap_limit / 2) return vm->heap_limit;
        if (want > SIZE_MAX / 2) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
        want *= 2;
    }
    return want;
}

void vm_gc(VM *vm, size_t needed) {
    /* The processor time of a collection, for Timer.checkCPUTimes and
       checkGCTime: read once around the whole of it, so that growing the
       heap counts as one collection and not two. */
    int64_t user0 = sys_time_user(), sys0 = sys_time_sys();
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
        if (guess < vm->live_last || guess > vm->heap_size) guess = vm->heap_size;
    }
    collect_into(vm, grown(vm, vm->heap_size, guess, needed));
    size_t want = grown(vm, vm->heap_size, USED_STOCK(vm), needed);
    if (want != vm->heap_size) collect_into(vm, want);
    if (needed > vm->heap_size - vm->heap_used) vm_limit(vm, "heap limit exceeded");
    vm->live_before = vm->live_last;
    vm->live_last = USED_STOCK(vm);
    CENSUS_GC_END(vm);
    vm->gc_user_us += sys_time_user() - user0;
    vm->gc_sys_us += sys_time_sys() - sys0;
}

/* --- relocation, for an image of the VM (runtime/image.c) --- */

/* The heap and every root were read as the parent had them, its addresses
   in them: each pointer moves by the distance between the two heaps. A
   pointer that is not into the heap's used part, or an object that is not
   one, makes the image unsound (0). */
static uintptr_t reloc_old;
static int reloc_ok;

static Obj *relocate_obj(VM *vm, Obj *o) {
    uintptr_t at = (uintptr_t)o;
    if (at < reloc_old || at - reloc_old >= vm->heap_used) { reloc_ok = 0; return NULL; }
    return (Obj *)(vm->heap_from + (at - reloc_old));
}

static void relocate_value(VM *vm, Value *v) {
    if (val_is_ptr(*v)) *v = mk_ptr(relocate_obj(vm, val_ptr(*v)));
}

int heap_relocate(VM *vm, uintptr_t old_base) {
    reloc_old = old_base;
    reloc_ok = 1;
    size_t scan = 0;
    while (reloc_ok && scan < vm->heap_used) {
        Obj *o = (Obj *)(vm->heap_from + scan);
        if (vm->heap_used - scan < OBJ_HEADER_SIZE || obj_kind(o) < K_TUPLE || obj_kind(o) > K_LAST || obj_kind(o) == K_FORWARD) return 0;
        size_t size = obj_size(o);
        if (size > vm->heap_used - scan) return 0;
        if (obj_has_fields(o)) {
            Value *f = obj_fields(o);
            for (uint32_t i = 0; i < obj_len(o); i++) relocate_value(vm, &f[i]);
        }
        scan += size;
    }
    for (size_t i = 0; i < vm->sp; i++) relocate_value(vm, &vm->stack[i]);
    for (uint32_t i = 0; i < vm->prog.nglobals; i++) relocate_value(vm, &vm->globals[i]);
    for (uint32_t i = 0; i < vm->prog.nconsts; i++) relocate_value(vm, &vm->prog.consts[i]);
    if (vm->frames_active)
        for (size_t i = 0; i <= vm->fp; i++)
            if (vm->frames[i].closure) vm->frames[i].closure = relocate_obj(vm, vm->frames[i].closure);
    for (int i = 0; i < NUM_BUILTIN_EXNS; i++)
        if (vm->builtin_exns[i]) vm->builtin_exns[i] = relocate_obj(vm, vm->builtin_exns[i]);
    for (int i = 0; i < REAL_BOXES; i++)
        if (vm->real_boxes[i]) vm->real_boxes[i] = relocate_obj(vm, vm->real_boxes[i]);
    return reloc_ok;
}
