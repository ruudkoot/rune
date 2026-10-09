/* The heap as the VM sees it: objects allocated, the boxes of the
   representation, and what C holds across a collection. The collector,
   and the chunks the heap is made of, are runtime/gc/. */
#include "gc/gc.h"
#include "sys/sys.h"
#include <string.h>


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

void heap_init(VM *vm, size_t size) {
    if (vm->heap_limit && size > vm->heap_limit) size = vm->heap_limit;
    vm->gc.first = vm->gc.last = vm->gc.pool = NULL;
    vm->gc.pooled = 0;
    vm->gc.closed = 0;
    vm->gc.size = size;
    chunk_append(vm, chunk_take(vm, 0, CHUNK_OLD));
    alloc_view(vm);
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
#ifdef RUNE_BARRIER_CARDS
    heap_cards(vm);
#endif
    real_boxes_make(vm);
}

/* The slow path of every allocation (the fast paths of the JIT and of
   runeopt's code bump alloc in line, and come here where it has no room):
   a collection where the heap's size would be passed, as when the heap was
   one semispace of that size, or where --gc-stress or the census asks;
   then the object in the room of the last chunk, or, where the chunk is
   full, in the next (runtime/gc/chunk.c, alloc_next). */
/* With a nursery: a large object straight into the large-object space,
   after a full collection where the heap's size would be passed; any other
   in the nursery, after a minor collection where it is full -- or a full
   one, where what the nursery holds could take the old space past its
   size -- and wherever --gc-stress asks for one. */
static Obj *alloc_young(VM *vm, size_t size, int stress, int *large) {
    /* --gc-stress-cycles: the collection --gc-stress makes a minor one,
       which begins the low-pause collector's cycle or marks a slice of it */
    int minor = stress && vm->gc.stress_cycles;
    if (minor) stress = 0;
    if (size >= vm->gc.los_min) {
        if (minor) collect_minor(vm);
        if (stress || USED_STOCK(vm) > vm->gc.size || STOCK(size) > vm->gc.size - USED_STOCK(vm)) vm_gc(vm, STOCK(size));
        *large = 1;
        return los_alloc(vm, size);
    }
    if (minor || stress || size > vm->alloc.size - vm->alloc.used) {
        /* a slice point of the low-pause collector's cycle, where the object
           fits the nursery: a slice of the cycle's marking (cycle.c) */
        if (!minor && !stress && vm->alloc.size < vm->gc.nursery_size && size <= vm->gc.nursery_size - vm->alloc.used) cycle_slice(vm);
        else if (USED_STOCK(vm) > vm->gc.size) vm_gc(vm, 0);
        else collect_minor(vm);
        /* the next slice point nearer than the object's end: moved past it */
        if (size > vm->alloc.size - vm->alloc.used) vm->alloc.size = vm->alloc.used + size;
    }
    Obj *o = (Obj *)(vm->alloc.from + vm->alloc.used);
    vm->alloc.used += size;
    return o;
}

Obj *vm_alloc(VM *vm, uint8_t kind, uint16_t contag, uint32_t len, size_t payload_bytes) {
    size_t size = obj_alloc_size(payload_bytes);
    CENSUS_FLUSH();
    int stress = vm->gc_stress && (vm->objects_allocated + vm->boxes_allocated) % vm->gc_stress == 0, large = 0;
    Obj *o;
    if (vm->gc.nursery) o = alloc_young(vm, size, stress, &large);
    else {
        if (STOCK(size) > vm->gc.size - USED_STOCK(vm) || stress || CENSUS_FORCED()) vm_gc(vm, STOCK(size));
        if (size <= vm->alloc.size - vm->alloc.used) {
            o = (Obj *)(vm->alloc.from + vm->alloc.used);
            vm->alloc.used += size;
        } else o = alloc_next(vm, size);
    }
    ADD_STOCK(vm, size);
    if (kind == K_REAL || kind == K_BOX) { vm->box_bytes_allocated += STOCK(size); vm->boxes_allocated++; vm->box_bytes_live += size; }
    else { vm->bytes_allocated += STOCK(size); vm->objects_allocated++; }
    obj_init(o, kind, contag, len);
    if (large) {
        vm->gc.large_objects++;
        vm->gc.large_bytes += size;
        if (obj_has_fields(o)) gc_born(vm, o);
    }
    CENSUS_ALLOC(vm, o, size);
    return o;
}

void heap_nursery(VM *vm, size_t bytes) { vm->gc.nursery_min = bytes; nursery_start(vm, bytes); }

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
/* whether o is in the large-object space, where nothing moves */
static int in_place(const VM *vm, const Obj *o) {
    return vm->gc.nursery && !gc_in_nursery(vm, o) && chunk_of(o)->kind == CHUNK_LOS;
}
void *vm_pin(VM *vm, size_t h, size_t *bytes) {
    Obj *o = raw_array(vm, h);
    if (!o) return NULL;
    size_t n = obj_payload_bytes(obj_kind(o), obj_len(o));
    if (in_place(vm, o)) {
        /* a large object never moves: C has the object itself (D17) */
        if (bytes) *bytes = n;
        return obj_bytes(o);
    }
    void *copy = malloc(n ? n : 1);
    if (!copy) return NULL;
    memcpy(copy, obj_bytes(o), n);
    if (bytes) *bytes = n;
    return copy;
}
void vm_unpin(VM *vm, size_t h, void *copy) {
    Obj *o = raw_array(vm, h);
    if (o && copy == (void *)obj_bytes(o) && in_place(vm, o)) return;   /* pinned in place */
    if (o && copy) memcpy(obj_bytes(o), copy, obj_payload_bytes(obj_kind(o), obj_len(o)));
    free(copy);
}
