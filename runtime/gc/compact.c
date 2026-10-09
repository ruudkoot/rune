/* The mark-compact old space (docs/plans/garbage-collector-v2.md, D3 C;
   measured beside the two collectors in M5): on the frame of mark.c, an
   old space that promotion bumps through and every full collection slides
   down. After the marking, the live objects of the old space's chunks, in
   the chunks' order and in each chunk's, are given places from the first
   chunk's payload on, each where the last ended, or at the next chunk's
   payload where it does not fit (fwd_next); a table gives the place of the
   first object that begins in each 128 bytes, so that an object's place is
   found by walking the few before it in its 128 bytes (compact_forward).
   Every pointer to the old space -- in the roots, in the live objects and
   in the large objects reached -- is made the place of its object; then
   the objects are moved, in the same order, each to a place no later than
   where it was, and the chunks' bits made again; a chunk left with
   nothing goes back. The table is made for the collection and freed. */
#include "gc/gc.h"
#include <string.h>

#define GRAIN_SHIFT 7   /* 128 bytes a table entry */

static void out_of_memory(void) {
    fprintf(stderr, "runevm: out of memory\n");
    exit(2);
}

/* the place after d for an object of size: d, or the next chunk's payload
   where the object does not fit the room left in d's chunk */
static char *fwd_next(char *d, size_t size) {
    Chunk *c = chunk_of(d);
    if (size <= (size_t)(chunk_payload(c) + chunk_room(c) - d)) return d;
    return chunk_payload(c->next);
}

/* the place after an object that ends at e: e, or the next chunk's payload
   where e is the end of its chunk's room -- so that a place is always
   within its chunk, and chunk_of finds it (the address just past a chunk is
   the next aligned one's, which need not be the next of the list) */
static char *fwd_after(char *e) {
    Chunk *c = chunk_of(e - 1);
    if (e == chunk_payload(c) + chunk_room(c) && c->next) return chunk_payload(c->next);
    return e;
}

typedef struct Compact {
    char ***fwd;      /* a chunk's table, by its index in the list */
    size_t nchunks;
} Compact;

/* the index of a chunk in the list, kept in its base during a compaction */
static size_t index_of(Chunk *c) { return (size_t)c->base; }

/* the place of the old object at o, which is the start of a live one */
static char *compact_forward(Compact *k, Chunk *c, char *o) {
    size_t off = (size_t)(o - (char *)c), g = off >> GRAIN_SHIFT;
    char *d = k->fwd[index_of(c)][g];
    for (size_t at = chunk_bits_next(c, (g << GRAIN_SHIFT) > c->payload ? (g << GRAIN_SHIFT) - c->payload : 0); ; ) {
        Obj *p = (Obj *)(chunk_payload(c) + at);
        size_t size = obj_size(p);
        d = fwd_next(d, size);
        if ((char *)p == o) return d;
        d = fwd_after(d + size);
        at = chunk_bits_next(c, at + size);
    }
}

static Compact *the_compaction;   /* for the visitors below; one VM collects at a time on a thread */

static void forward_value(VM *vm, Value *v) {
    (void)vm;
    if (!val_is_ptr(*v)) return;
    char *o = (char *)val_ptr(*v);
    Chunk *c = chunk_of(o);
    if (c->kind != CHUNK_MARK) return;
    *v = mk_ptr((Obj *)compact_forward(the_compaction, c, o));
}
static void forward_obj(VM *vm, Obj **o) {
    if (!*o) return;
    Value v = mk_ptr(*o);
    forward_value(vm, &v);
    *o = val_ptr(v);
}
static void forward_fields(VM *vm, Obj *o) {
    if (!obj_has_fields(o)) return;
    Value *f = obj_fields(o);
    uint32_t n = obj_scanned_fields(o);
    for (uint32_t i = 0; i < n; i++) forward_value(vm, &f[i]);
}
#define FORWARD_VALUE(v) forward_value(vm, (v))
#define FORWARD_OBJ(o) forward_obj(vm, (o))

/* After a full collection marked: the old space slid down (above) */
void compact_old(VM *vm) {
    Compact k = { NULL, 0 };
    for (Chunk *c = vm->gc.first; c; c = c->next) c->base = k.nchunks++;
    if (!k.nchunks) return;
    k.fwd = calloc(k.nchunks, sizeof *k.fwd);
    if (!k.fwd) out_of_memory();

    /* the places: the table of each chunk, the first object's in each 128 bytes */
    char *d = chunk_payload(vm->gc.first);
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        size_t grains = c->size >> GRAIN_SHIFT;
        char **t = k.fwd[index_of(c)] = malloc(grains * sizeof *t);
        if (!t) out_of_memory();
        size_t next = 0;
        for (size_t at = chunk_bits_next(c, 0); at != CHUNK_END; ) {
            size_t size = obj_size((Obj *)(chunk_payload(c) + at));
            size_t g = (c->payload + at) >> GRAIN_SHIFT;
            for (; next <= g; next++) t[next] = d;
            d = fwd_after(fwd_next(d, size) + size);
            at = chunk_bits_next(c, at + size);
        }
        for (; next < grains; next++) t[next] = d;
    }

    /* every pointer made its object's place: the roots, the live objects,
       the large objects reached */
    the_compaction = &k;
    gc_stack_roots(vm, forward_value);
    OTHER_ROOTS(vm, FORWARD_VALUE, FORWARD_OBJ);
    for (Chunk *c = vm->gc.first; c; c = c->next)
        for (size_t at = chunk_bits_next(c, 0); at != CHUNK_END; ) {
            Obj *o = (Obj *)(chunk_payload(c) + at);
            forward_fields(vm, o);
            at = chunk_bits_next(c, at + obj_size(o));
        }
    for (Obj *o = los_first(vm); o; o = los_next(vm, o)) {
        Chunk *c = chunk_of(o);
        if (chunk_marks(c)[(size_t)((char *)o - chunk_payload(c)) >> GC_UNIT_SHIFT]) forward_fields(vm, o);
    }

    /* the objects moved, in order, each to a place no later than its own;
       the new bits kept apart until every chunk is walked */
    uint64_t **bits = calloc(k.nchunks, sizeof *bits);
    if (!bits) out_of_memory();
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        bits[index_of(c)] = calloc(c->size >> 9, sizeof(uint64_t));
        if (!bits[index_of(c)]) out_of_memory();
        c->used = 0;
    }
    d = chunk_payload(vm->gc.first);
    Chunk *last = vm->gc.first;   /* the last chunk anything is moved into */
    for (Chunk *c = vm->gc.first; c; c = c->next)
        for (size_t at = chunk_bits_next(c, 0); at != CHUNK_END; ) {
            Obj *o = (Obj *)(chunk_payload(c) + at);
            size_t size = obj_size(o);
            at = chunk_bits_next(c, at + size);   /* before the move: it may overwrite what follows */
            d = fwd_next(d, size);
            if ((char *)o != d) memmove(d, o, size);
            Chunk *to = chunk_of(d);
            size_t off = (size_t)(d - (char *)to);
            bits[index_of(to)][off >> 9] |= (uint64_t)1 << (off >> 3 & 63);
            to->used += size;
            last = to;
            d = fwd_after(d + size);
        }
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        memcpy(chunk_bits(c), bits[index_of(c)], (c->size >> 9) * sizeof(uint64_t));
        free(bits[index_of(c)]);
        free(k.fwd[index_of(c)]);
        c->top = c->used;
    }
    free(bits);
    free(k.fwd);
    the_compaction = NULL;

    /* the chunks after the last that holds anything given back; the last
       that does is where promotion bumps on */
    Chunk *rest = last->next;
    last->next = NULL;
    vm->gc.last = last;
    while (rest) {
        Chunk *n = rest->next;
        chunk_give(vm, rest);
        rest = n;
    }
    size_t closed = 0;
    for (Chunk *c = vm->gc.first; c; c = c->next) closed += c->used;
    vm->gc.closed = closed;
}
