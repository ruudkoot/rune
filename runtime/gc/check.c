/* --gc-verify: the heap checked before and after every pass of the
   collector, so that one that breaks it is caught at the collection that
   did (make test-heap runs tests/lang so). What holds of the heap: each
   chunk parses, object by object, to exactly the bytes it holds; every
   header names a kind of today and none is a forwarding one; the boxes in
   it are the bytes box_bytes_live counts; the chunks hold what the heap
   says it holds; and every pointer in a field, on the stack or among the
   other roots is to the start of an object in one of its chunks. heap_check
   says what does not hold, or NULL (tests/runtime/heap_test.c breaks a
   heap to see it); a collection under --gc-verify stops on it. */
#include "gc/gc.h"
#include <string.h>

typedef struct Check {
    VM *vm;
    Chunk **chunks;      /* the heap's, by address, to find a pointer's among */
    size_t n;
    uint8_t *starts;     /* a bit for every 8 bytes of the heap's run (heap_number): an object begins there */
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

static void check_ptr(Check *c, const void *p, const char *what) {
    if (!p || c->failed) return;
    Chunk *k = chunk_in(c, p);
    uintptr_t in = k ? (uintptr_t)((const char *)p - chunk_payload(k)) : 0;
    if (!k || (const char *)p < chunk_payload(k) || in >= chunk_used(c->vm, k) || in % 8 != 0) { check_fail(c, what, p); return; }
    uint64_t at = k->base + in;
    if (!(c->starts[at / 64] >> (at / 8 % 8) & 1)) check_fail(c, what, p);
}

static void check_value(Check *c, const Value *v, const char *what) {
    if (val_is_ptr(*v)) check_ptr(c, val_ptr(*v), what);
}

const char *heap_check(VM *vm, const void **at) {
    Check c = { vm, NULL, 0, NULL, NULL, NULL };
    heap_number(vm);
    uint64_t total = 0, closed = 0;
    for (Chunk *k = heap_first(vm); k; k = k->next) {
        c.n++;
        total += chunk_used(vm, k);
        if (k != vm->gc.last) closed += k->used;
    }
    c.chunks = malloc((c.n ? c.n : 1) * sizeof *c.chunks);
    c.starts = calloc(total / 64 + 1, 1);
    if (!c.chunks || !c.starts) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
    c.n = 0;
    for (Chunk *k = heap_first(vm); k; k = k->next) c.chunks[c.n++] = k;
    qsort(c.chunks, c.n, sizeof *c.chunks, by_address);
    if (closed != vm->gc.closed) check_fail(&c, "the chunks hold other than the heap counts", NULL);
    if (vm->alloc.from != chunk_payload(vm->gc.last) || vm->alloc.used > vm->alloc.size || vm->alloc.size > chunk_room(vm->gc.last))
        check_fail(&c, "alloc is not the room of the last chunk", vm->alloc.from);

    size_t boxes = 0;
    for (Chunk *k = heap_first(vm); k && !c.failed; k = k->next) {
        size_t used = chunk_used(vm, k);
        for (size_t at = 0; at < used && !c.failed; ) {
            Obj *o = (Obj *)(chunk_payload(k) + at);
            size_t size = 0;
            if (used - at < OBJ_HEADER_SIZE) check_fail(&c, "a header cut off at the end of a chunk", o);
            else if (obj_kind(o) < K_TUPLE || obj_kind(o) > K_LAST || obj_kind(o) == K_FORWARD) check_fail(&c, "a header of no kind", o);
            else if ((size = obj_size(o)) < OBJ_HEADER_SIZE || size > used - at) check_fail(&c, "an object past the end of its chunk", o);
            else {
                if (obj_kind(o) == K_REAL || obj_kind(o) == K_BOX) boxes += size;
                uint64_t start = k->base + at;
                c.starts[start / 64] |= (uint8_t)(1u << (start / 8 % 8));
                at += size;
            }
        }
    }
    if (!c.failed && boxes != vm->box_bytes_live) check_fail(&c, "boxes not as box_bytes_live counts them", NULL);
    for (Chunk *k = heap_first(vm); k && !c.failed; k = k->next) {
        size_t used = chunk_used(vm, k);
        for (size_t at = 0; at < used && !c.failed; ) {
            Obj *o = (Obj *)(chunk_payload(k) + at);
            if (obj_has_fields(o)) {
                const Value *f = obj_fields(o);
                for (uint32_t i = 0; i < obj_scanned_fields(o); i++) check_value(&c, &f[i], "a field that is no object's");
            }
            at += obj_size(o);
        }
    }
    for (size_t i = 0; i < vm->sp && !c.failed; i++) check_value(&c, &vm->stack[i], "a slot of the stack that is no object's");
#define CHECK_VALUE(v) check_value(&c, (v), "a root that is no object's")
#define CHECK_OBJ(o) check_ptr(&c, *(o), "a root that is no object")
    if (!c.failed) OTHER_ROOTS(vm, CHECK_VALUE, CHECK_OBJ);
#undef CHECK_VALUE
#undef CHECK_OBJ
    free(c.chunks);
    free(c.starts);
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
