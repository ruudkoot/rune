/* --gc-verify: the heap checked before and after every pass of the
   collector, so that one that breaks it is caught at the collection that
   did (make test-heap runs tests/lang so). What holds of the heap: each
   chunk of the old space parses, object by object, to exactly the bytes it
   holds -- a non-moving one by its bits -- and so do the nursery and the
   large-object space; every header
   names a kind of today and none is a forwarding one; the boxes in it are
   the bytes box_bytes_live counts; the chunks hold what the heap says it
   holds; every pointer in a field, on the stack or among the other roots
   is to the start of an object of the heap; and every field of an old
   object that holds a pointer into the nursery is in a card the barrier
   marked, in a block marked dirty, or in a large object made since the
   last minor collection (D6); and no slot or frame below the stack's
   watermark holds a young pointer (D9). heap_check says what does not hold, or NULL
   (tests/runtime/heap_test.c breaks a heap to see it); a collection under
   --gc-verify stops on it. */
#include "gc/gc.h"
#include <string.h>

typedef struct Check {
    VM *vm;
    Chunk **chunks;      /* the old space's and the large objects', by address, to find a pointer's among */
    size_t n;
    uint8_t *starts;     /* a bit for every 8 bytes of the old space's run (heap_number): an object begins there */
    uint8_t *young;      /* the same for the nursery */
    const char *failed;  /* the first thing found not to hold */
    const void *at;
} Check;

static void check_fail(Check *c, const char *what, const void *at) {
    if (!c->failed) { c->failed = what; c->at = at; }
}

static int by_address(const void *a, const void *b) {
    uintptr_t x = (uintptr_t)*(Chunk *const *)a, y = (uintptr_t)*(Chunk *const *)b;
    return x < y ? -1 : x > y;
}

/* the heap's chunk p is in, or NULL */
static Chunk *chunk_in(const Check *c, const void *p) {
    Chunk *want = chunk_of(p);
    size_t lo = 0, hi = c->n;
    while (lo < hi) {
        size_t mid = lo + (hi - lo) / 2;
        if ((uintptr_t)c->chunks[mid] < (uintptr_t)want) lo = mid + 1; else hi = mid;
    }
    return lo < c->n && c->chunks[lo] == want ? want : NULL;
}

static void set_bit(uint8_t *bits, uint64_t at) { bits[at / 64] |= (uint8_t)(1u << (at / 8 % 8)); }
static int bit(const uint8_t *bits, uint64_t at) { return bits[at / 64] >> (at / 8 % 8) & 1; }

static void check_ptr(Check *c, const void *p, const char *what) {
    if (!p || c->failed) return;
    VM *vm = c->vm;
    if (gc_in_nursery(vm, p)) {
        uintptr_t at = (uintptr_t)((const char *)p - vm->alloc.from);
        if (at >= vm->alloc.used || at % 8 != 0 || !bit(c->young, at)) check_fail(c, what, p);
        return;
    }
    Chunk *k = chunk_in(c, p);
    uintptr_t in = k ? (uintptr_t)((const char *)p - chunk_payload(k)) : 0;
    if (!k || (const char *)p < chunk_payload(k) || in % 8 != 0) { check_fail(c, what, p); return; }
    if (k->kind == CHUNK_MARK) {
        if (in >= k->top || !chunk_bit(k, k->payload + in)) check_fail(c, what, p);
        return;
    }
    if (k->kind == CHUNK_LOS) {
        size_t u = in >> GC_UNIT_SHIFT;
        if (in % ((size_t)1 << GC_UNIT_SHIFT) != 0 || u >= chunk_room(k) >> GC_UNIT_SHIFT || chunk_units(k)[u] != u)
            check_fail(c, what, p);
        return;
    }
    if (in >= chunk_used(vm, k) || !bit(c->starts, k->base + in)) check_fail(c, what, p);
}

static void check_value(Check *c, const Value *v, const char *what) {
    if (val_is_ptr(*v)) check_ptr(c, val_ptr(*v), what);
}

/* an old object's fields: each a pointer to an object, and one into the
   nursery remembered (born: the object is a large one made since the last
   minor collection) */
static void check_old(Check *c, Obj *o, int born) {
    if (!obj_has_fields(o)) return;
    Value *f = obj_fields(o);
    Chunk *k = chunk_of(o);
    for (uint32_t i = 0; i < obj_scanned_fields(o) && !c->failed; i++) {
        check_value(c, &f[i], "a field that is no object's");
        if (!born && val_is_ptr(f[i]) && gc_in_nursery(c->vm, val_ptr(f[i]))) {
            uintptr_t at = (uintptr_t)((char *)&f[i] - (char *)k);
            if (!chunk_cards(k)[at >> GC_CARD_SHIFT] || !chunk_dirty(k)[at >> GC_BLOCK_SHIFT])
                check_fail(c, "an old object's field that holds a young pointer, not remembered", &f[i]);
        }
    }
}

/* the objects of [from, from + used), each a header of a kind, in the bits */
static size_t check_parse(Check *c, char *from, size_t used, uint8_t *bits, uint64_t base) {
    size_t boxes = 0;
    for (size_t at = 0; at < used && !c->failed; ) {
        Obj *o = (Obj *)(from + at);
        size_t size = 0;
        if (used - at < OBJ_HEADER_SIZE) check_fail(c, "a header cut off at the end of a chunk", o);
        else if (obj_kind(o) < K_TUPLE || obj_kind(o) > K_LAST || obj_kind(o) == K_FORWARD) check_fail(c, "a header of no kind", o);
        else if ((size = obj_size(o)) < OBJ_HEADER_SIZE || size > used - at) check_fail(c, "an object past the end of its chunk", o);
        else {
            if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) boxes += size;
            set_bit(bits, base + at);
            at += size;
        }
    }
    return boxes;
}

/* a non-moving chunk's objects, where its bits say: each a header of a
   kind, within the chunk's top and before the next object; what they hold
   is what the chunk says it holds */
static size_t check_marked(Check *c, Chunk *k) {
    size_t boxes = 0, held = 0;
    for (size_t at = chunk_bits_next(k, 0); at != CHUNK_END && !c->failed; ) {
        Obj *o = (Obj *)(chunk_payload(k) + at);
        size_t size, next;
        if (obj_kind(o) < K_TUPLE || obj_kind(o) > K_LAST || obj_kind(o) == K_FORWARD) { check_fail(c, "a header of no kind", o); break; }
        size = obj_size(o);
        next = chunk_bits_next(k, at + 8);
        if (size < OBJ_HEADER_SIZE || at + size > k->top || (next != CHUNK_END && at + size > next)) { check_fail(c, "an object past the next one's start", o); break; }
        if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) boxes += size;
        held += size;
        at = next;
    }
    if (!c->failed && held != k->used) check_fail(c, "a chunk holds other than it counts", k);
    return boxes;
}

static int is_born(const VM *vm, const Obj *o) {
    for (size_t i = 0; i < vm->gc.nborn; i++) if (vm->gc.born[i] == o) return 1;
    return 0;
}

const char *heap_check(VM *vm, const void **at) {
    Check c = { vm, NULL, 0, NULL, NULL, NULL, NULL };
    heap_number(vm);
    uint64_t total = 0, closed = 0, los = 0;
    for (Chunk *k = heap_first(vm); k; k = k->next) {
        c.n++;
        total += chunk_used(vm, k);
        if (k != vm->gc.last || vm->gc.nursery) closed += k->used;
    }
    for (Chunk *k = vm->gc.los; k; k = k->next) c.n++;
    c.chunks = malloc((c.n ? c.n : 1) * sizeof *c.chunks);
    c.starts = calloc(total / 64 + 1, 1);
    c.young = calloc((vm->gc.nursery ? vm->alloc.used : 0) / 64 + 1, 1);
    if (!c.chunks || !c.starts || !c.young) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
    c.n = 0;
    for (Chunk *k = heap_first(vm); k; k = k->next) c.chunks[c.n++] = k;
    for (Chunk *k = vm->gc.los; k; k = k->next) c.chunks[c.n++] = k;
    qsort(c.chunks, c.n, sizeof *c.chunks, by_address);
    if (closed != vm->gc.closed) check_fail(&c, "the chunks hold other than the heap counts", NULL);
    if (vm->gc.nursery ? vm->alloc.from != chunk_payload(vm->gc.nursery) || vm->alloc.size != vm->gc.nursery_size
                       : vm->alloc.from != chunk_payload(vm->gc.last) || vm->alloc.size > chunk_room(vm->gc.last))
        check_fail(&c, "alloc is not the room it should be", vm->alloc.from);
    if (vm->alloc.used > vm->alloc.size) check_fail(&c, "alloc holds more than its room", vm->alloc.from);

    size_t boxes = 0;
    for (Chunk *k = heap_first(vm); k && !c.failed; k = k->next)
        boxes += k->kind == CHUNK_MARK ? check_marked(&c, k) : check_parse(&c, chunk_payload(k), chunk_used(vm, k), c.starts, k->base);
    for (Obj *o = los_first(vm); o && !c.failed; o = los_next(vm, o)) {
        if (obj_kind(o) < K_TUPLE || obj_kind(o) > K_LAST || obj_kind(o) == K_FORWARD) check_fail(&c, "a large object of no kind", o);
        else los += obj_size(o);
    }
    if (!c.failed && los != vm->gc.los_bytes) check_fail(&c, "large objects other than the space counts", NULL);
    if (vm->gc.nursery && !c.failed) boxes += check_parse(&c, vm->alloc.from, vm->alloc.used, c.young, 0);
    if (!c.failed && boxes != vm->box_bytes_live) check_fail(&c, "boxes not as box_bytes_live counts them", NULL);

    for (Chunk *k = heap_first(vm); k && !c.failed; k = k->next)
        for (size_t a = chunk_object(vm, k, 0); a != CHUNK_END && !c.failed; ) {
            Obj *o = (Obj *)(chunk_payload(k) + a);
            if (vm->gc.nursery) check_old(&c, o, 0);
            else if (obj_has_fields(o)) {
                const Value *f = obj_fields(o);
                for (uint32_t i = 0; i < obj_scanned_fields(o); i++) check_value(&c, &f[i], "a field that is no object's");
            }
            a = chunk_object(vm, k, a + obj_size(o));
        }
    for (Obj *o = los_first(vm); o && !c.failed; o = los_next(vm, o)) check_old(&c, o, is_born(vm, o));
    if (vm->gc.nursery)
        for (size_t a = 0; a < vm->alloc.used && !c.failed; ) {
            Obj *o = (Obj *)(vm->alloc.from + a);
            if (obj_has_fields(o)) {
                const Value *f = obj_fields(o);
                for (uint32_t i = 0; i < obj_scanned_fields(o); i++) check_value(&c, &f[i], "a field that is no object's");
            }
            a += obj_size(o);
        }
    for (size_t i = 0; i < vm->sp && !c.failed; i++) check_value(&c, &vm->stack[i], "a slot of the stack that is no object's");
    /* below the stack's watermark (minor.c), nothing young: a pop of a frame
       that did not lower it would leave a frame unscanned */
    if (vm->gc.nursery && vm->frames_active && !c.failed) {
        if (vm->fp_low > vm->fp) check_fail(&c, "the stack's watermark above the frame that runs", NULL);
        size_t below = vm->fp_low && vm->fp_low <= vm->fp ? vm->frames[vm->fp_low].base : 0;
        for (size_t i = 0; i < below && i < vm->sp && !c.failed; i++)
            if (val_is_ptr(vm->stack[i]) && gc_in_nursery(vm, val_ptr(vm->stack[i])))
                check_fail(&c, "a slot below the stack's watermark that holds a young pointer", &vm->stack[i]);
        for (size_t k = 0; k < vm->fp_low && k <= vm->fp && !c.failed; k++)
            if (vm->frames[k].closure && gc_in_nursery(vm, vm->frames[k].closure))
                check_fail(&c, "a frame below the stack's watermark whose closure is young", &vm->frames[k]);
    }
#define CHECK_VALUE(v) check_value(&c, (v), "a root that is no object's")
#define CHECK_OBJ(o) check_ptr(&c, *(o), "a root that is no object")
    if (!c.failed) OTHER_ROOTS(vm, CHECK_VALUE, CHECK_OBJ);
#undef CHECK_VALUE
#undef CHECK_OBJ
    free(c.chunks);
    free(c.starts);
    free(c.young);
    if (at) *at = c.at;
    return c.failed;
}

void heap_verify(VM *vm, const char *when) {
    const void *at;
    const char *failed = heap_check(vm, &at);
    if (!failed) return;
    fprintf(stderr, "runevm: --gc-verify: %s collection %zu: %s (%p)\n", when, vm->gc_count + 1, failed, at);
    exit(2);
}
