/* The heap's chunks (runtime/gc/gc.h): taken from the system aligned to
   their size, given back to a pool that the next collection takes from (so
   that its pages are not faulted in again, as the semispace kept between
   collections once did), and listed in the order they were filled. */
#include "gc/gc.h"
#include "sys/sys.h"
#include <string.h>

static void out_of_memory(void) {
    fprintf(stderr, "runevm: out of memory\n");
    exit(2);
}

/* the header and tables of a chunk of size bytes, for its first use (the
   system's memory is zero, so its tables are clear) */
static void chunk_layout(Chunk *c, size_t size) {
    c->size = size;
    c->dirty_at = (uint32_t)(GC_CARDS + (size >> GC_CARD_SHIFT));
    c->cross_at = (uint32_t)(c->dirty_at + (size >> GC_BLOCK_SHIFT));
    c->units_at = (uint32_t)(c->cross_at + 2 * (size >> GC_CARD_SHIFT));
    c->marks_at = (uint32_t)(c->units_at + 2 * (size >> GC_UNIT_SHIFT));
    c->bits_at = (uint32_t)((c->marks_at + (size >> GC_UNIT_SHIFT) + 7) & ~(size_t)7);
    c->lines_at = (uint32_t)(c->bits_at + (size >> 6));
    c->blocks_at = (uint32_t)(c->lines_at + (size >> IX_LINE_SHIFT));
    c->payload = (uint32_t)CHUNK_PAYLOAD(size);
}

Chunk *chunk_take(VM *vm, size_t bytes, int kind) {
    Chunk *c;
    if (bytes <= CHUNK_ROOM && vm->gc.pool) {
        c = vm->gc.pool;
        vm->gc.pool = c->next;
        vm->gc.pooled--;
        /* the tables of its last use cleared: the cards, the dirty bytes,
           the crossing map, the units and their marks (the bits are their
           user's, mark.c) */
        memset((char *)c + GC_CARDS, 0, c->bits_at - GC_CARDS);
    } else {
        size_t size = CHUNK_SIZE;
        if (bytes > CHUNK_ROOM) {
            /* a run of chunks, rounded up to whole ones, whose tables cover it */
            if (bytes > SIZE_MAX / 2) out_of_memory();
            for (size = 2 * CHUNK_SIZE; size - CHUNK_PAYLOAD(size) < bytes; size += CHUNK_SIZE)
                if (size > SIZE_MAX - CHUNK_SIZE) out_of_memory();
        }
        c = sys_mem_reserve(size, CHUNK_SIZE, vm->gc.hint);
        if (!c) out_of_memory();
        vm->gc.hint = (char *)c + size;
        chunk_layout(c, size);
    }
    c->next = NULL;
    c->used = 0;
    c->base = 0;
    c->kind = (uint32_t)kind;
    c->units_free = 0;
    return c;
}

/* A pool of one heap's worth, as many chunks as the heap's size takes, and
   one more: what the semispace kept between collections held. A run of
   chunks goes back to the system, being of a size the next may not want. */
void chunk_give(VM *vm, Chunk *c) {
    free(c->lines);
    c->lines = NULL;
    if (c->size == CHUNK_SIZE && vm->gc.pooled <= vm->gc.size / CHUNK_SIZE) {
        c->next = vm->gc.pool;
        vm->gc.pool = c;
        vm->gc.pooled++;
    } else sys_mem_release(c, c->size);
}

void chunk_append(VM *vm, Chunk *c) {
    if (vm->gc.last) vm->gc.last->next = c;
    else vm->gc.first = c;
    vm->gc.last = c;
}

void heap_chunks_release(VM *vm) {
    for (Chunk *c = vm->gc.first, *n; c; c = n) { n = c->next; free(c->lines); sys_mem_release(c, c->size); }
    for (Chunk *c = vm->gc.pool, *n; c; c = n) { n = c->next; sys_mem_release(c, c->size); }
    los_release(vm);
    if (vm->gc.nursery) sys_mem_release(vm->gc.nursery, vm->gc.nursery->size);
    vm->gc.first = vm->gc.last = vm->gc.pool = vm->gc.nursery = NULL;
    vm->gc.pooled = 0;
    free(vm->gc.born);
    free(vm->gc.queue);
    free(vm->gc.segs);
    vm->gc.born = vm->gc.queue = NULL;
    vm->gc.segs = NULL;
    vm->gc.nborn = vm->gc.born_cap = vm->gc.nqueue = vm->gc.queue_cap = vm->gc.nsegs = vm->gc.segs_cap = 0;
    /* the mark-region space's lists of blocks (immix.c) */
    free(vm->gc.ix_recycle);
    free(vm->gc.ix_free);
    vm->gc.ix_recycle = vm->gc.ix_free = NULL;
    vm->gc.ix_nrecycle = vm->gc.ix_recycle_cap = vm->gc.ix_recycle_at = vm->gc.ix_nfree = vm->gc.ix_free_cap = 0;
    vm->gc.ix_cursor = vm->gc.ix_limit = vm->gc.ix_block = vm->gc.ix_ocursor = vm->gc.ix_olimit = NULL;
    vm->alloc.from = NULL;
    vm->alloc.size = vm->alloc.used = 0;
}

/* The fast paths bump alloc.used against alloc.size. With a nursery, its
   room. With none, the room of the last chunk, and no more than the heap's
   size leaves for it, so that where a collection is due they leave for the
   slow path as they did when the heap was one semispace of that size
   (runtime/heap.c, vm_alloc). The census VM counts the heap's size by the
   stock sizes, which alloc does not hold: it interprets alone, and
   vm_alloc asks it of every allocation. */
void alloc_view(VM *vm) {
    if (vm->gc.nursery) {
        vm->alloc.from = chunk_payload(vm->gc.nursery);
        vm->alloc.size = vm->gc.nursery_size;
        return;
    }
    Chunk *c = vm->gc.last;
    vm->alloc.from = chunk_payload(c);
    vm->alloc.used = c->used;
    size_t room = chunk_room(c);
#ifndef RUNE_CENSUS
    size_t left = vm->gc.size > vm->gc.closed ? vm->gc.size - vm->gc.closed : 0;
    if (left < room) room = left < c->used ? c->used : left;
#endif
    vm->alloc.size = room;
}

Obj *alloc_next(VM *vm, size_t size) {
    vm->gc.last->used = vm->alloc.used;
    vm->gc.closed += vm->alloc.used;
    if (size > CHUNK_ROOM) {
        /* a run of its own, closed as soon as it holds the object, and a
           chunk after it for the objects that follow */
        Chunk *run = chunk_take(vm, size, CHUNK_OLD);
        run->used = size;
        chunk_append(vm, run);
        vm->gc.closed += size;
        chunk_append(vm, chunk_take(vm, 0, CHUNK_OLD));
        alloc_view(vm);
        return (Obj *)chunk_payload(run);
    }
    chunk_append(vm, chunk_take(vm, 0, CHUNK_OLD));
    alloc_view(vm);
    Obj *o = (Obj *)vm->alloc.from;
    vm->alloc.used = size;
    return o;
}


/* ---- images (runtime/image.c) ---- */

/* The run of objects an image holds: the old space's chunks in their order,
   then the large objects, then the nursery's; a chunk's base is its first
   object's offset, a large object's chunk's its first object's. */
/* a non-moving chunk's lines: for each 64 bytes, the offset from the
   chunk's base of the first object that begins there or after, so that
   heap_offset_of walks the bits of one line */
static void number_lines(Chunk *c) {
    size_t nlines = c->size >> 6, next = 0;
    if (!c->lines && !(c->lines = malloc(nlines * sizeof *c->lines))) out_of_memory();
    uint32_t off = 0;
    for (size_t at = chunk_bits_next(c, 0); at != CHUNK_END; ) {
        size_t size = obj_size((Obj *)(chunk_payload(c) + at));
        for (size_t line = (c->payload + at) >> 6; next <= line; next++) c->lines[next] = off;
        off += (uint32_t)size;
        at = chunk_bits_next(c, at + size);
    }
    for (; next < nlines; next++) c->lines[next] = off;
}

void heap_number(VM *vm) {
    uint64_t base = 0;
    for (Chunk *c = heap_first(vm); c; c = c->next) {
        c->base = base;
        base += chunk_used(vm, c);
        if (c->kind == CHUNK_MARK) number_lines(c);
    }
    Chunk *last_los = NULL;
    for (Obj *o = los_first(vm); o; o = los_next(vm, o)) {
        if (chunk_of(o) != last_los) { last_los = chunk_of(o); last_los->base = base; }
        base += obj_size(o);
    }
    if (vm->gc.nursery) vm->gc.nursery->base = base;
}

uint64_t heap_offset_of(VM *vm, const void *p) {
    if (gc_in_nursery(vm, p)) return vm->gc.nursery->base + (uint64_t)((const char *)p - vm->alloc.from);
    Chunk *c = chunk_of(p);
    if (c->kind == CHUNK_MARK) {
        /* its line's first object's offset, and the objects of the line before it */
        size_t off = (size_t)((const char *)p - (const char *)c);
        uint64_t at = c->base + c->lines[off >> 6];
        for (size_t o = chunk_bits_next(c, (off & ~(size_t)63) - c->payload); o != CHUNK_END && c->payload + o < off; ) {
            size_t size = obj_size((Obj *)(chunk_payload(c) + o));
            at += size;
            o = chunk_bits_next(c, o + size);
        }
        return at;
    }
    if (c->kind != CHUNK_LOS) return c->base + (uint64_t)((const char *)p - chunk_payload(c));
    /* a large object: its chunk's base and the objects that begin before it in the chunk */
    uint64_t at = c->base;
    const uint16_t *units = chunk_units(c);
    size_t u = (size_t)((const char *)p - chunk_payload(c)) >> GC_UNIT_SHIFT;
    for (size_t v = 0; v < u; v++)
        if (units[v] == v) at += obj_size((Obj *)(chunk_payload(c) + (v << GC_UNIT_SHIFT)));
    return at;
}

/* Read back: the heap of the image's size, empty, with the nursery the VM
   was given (vm->gc.nursery_size, set before) */
void heap_read_begin(VM *vm, size_t size) {
    size_t nursery = vm->gc.nursery_size;
    heap_chunks_release(vm);
    vm->gc.size = size;
    vm->gc.closed = 0;
    vm->gc.los_bytes = 0;
    vm->fp_low = 0;   /* the frames read after it are scanned whole by the first minor collection */
    chunk_append(vm, chunk_take(vm, 0, CHUNK_OLD));
    nursery_start(vm, nursery);
    vm->alloc.used = 0;
}

/* the place the run continues at, for heap_relocate: base is the offset
   of the next object read, at its place */
static void read_segment(VM *vm, uint64_t base, char *at) {
    if (vm->gc.nsegs == vm->gc.segs_cap) {
        size_t cap = vm->gc.segs_cap ? 2 * vm->gc.segs_cap : 64;
        HeapSeg *s = realloc(vm->gc.segs, cap * sizeof *s);
        if (!s) out_of_memory();
        vm->gc.segs = s;
        vm->gc.segs_cap = cap;
    }
    vm->gc.segs[vm->gc.nsegs].base = base;
    vm->gc.segs[vm->gc.nsegs].at = at;
    vm->gc.segs[vm->gc.nsegs].len = 0;
    vm->gc.nsegs++;
}

/* The next object of the image's run, of bytes, all of them old: after the
   last, or in a chunk of its own where it does not fit, or, where there is
   a nursery, in the large-object space when it is large. Each takes its
   segment of the run. */
Obj *heap_read_take(VM *vm, size_t bytes) {
    HeapSeg *s = vm->gc.nsegs ? &vm->gc.segs[vm->gc.nsegs - 1] : NULL;
    uint64_t base = s ? s->base + s->len : 0;
    Obj *o;
    if (vm->gc.nursery && bytes >= vm->gc.los_min) {
        o = los_alloc(vm, bytes);
        read_segment(vm, base, (char *)o);
    } else if (vm->gc.old_kind != OLD_COPY) {
        o = old_place(vm, bytes);
        if (!s || s->at + s->len != (char *)o) read_segment(vm, base, (char *)o);
    } else {
        Chunk *c = vm->gc.last;
        if (bytes > chunk_room(c) - c->used) {
            if (!vm->gc.nursery) vm->gc.closed += c->used;
            c = chunk_take(vm, bytes > CHUNK_ROOM ? bytes : 0, CHUNK_OLD);
            chunk_append(vm, c);
            if (bytes > CHUNK_ROOM) {
                /* a run holds one object: the next goes into a chunk after it */
                c->used = bytes;
                vm->gc.closed += bytes;
                chunk_append(vm, chunk_take(vm, 0, CHUNK_OLD));
                read_segment(vm, base, chunk_payload(c));
                vm->gc.segs[vm->gc.nsegs - 1].len = bytes;
                return (Obj *)chunk_payload(c);
            }
        }
        o = (Obj *)(chunk_payload(c) + c->used);
        if (!s || s->at + s->len != (char *)o) read_segment(vm, base, (char *)o);
        if (vm->gc.nursery) {
            /* with a nursery every chunk of the old space is closed, the last too */
            chunk_note(c, c->used, bytes);
            vm->gc.closed += bytes;
        }
        c->used += bytes;
    }
    vm->gc.segs[vm->gc.nsegs - 1].len += bytes;
    return o;
}

/* ---- relocation, for an image of the VM (runtime/image.c) ---- */

/* The heap and every root were read with each pointer the offset of its
   object in the image's run, plus old_base (so that none is 0): each is
   turned into where that object is now, found among the segments of the
   run by their bases. A pointer past the run makes the image unsound (0). */
typedef struct Reloc {
    VM *vm;
    uint64_t total;      /* the bytes of the run */
    uintptr_t old_base;
} Reloc;

static Obj *relocate_obj(Reloc *r, Obj *o) {
    uint64_t at = (uint64_t)((uintptr_t)o - r->old_base);
    HeapSeg *segs = r->vm->gc.segs;
    size_t n = r->vm->gc.nsegs;
    if ((uintptr_t)o < r->old_base || at >= r->total || !n) { r->vm->gc.reloc_ok = 0; return NULL; }
    size_t lo = 0, hi = n;
    while (hi - lo > 1) {
        size_t mid = lo + (hi - lo) / 2;
        if (segs[mid].base <= at) lo = mid; else hi = mid;
    }
    if (at - segs[lo].base >= segs[lo].len) { r->vm->gc.reloc_ok = 0; return NULL; }
    return (Obj *)(segs[lo].at + (size_t)(at - segs[lo].base));
}

static void relocate_value(Reloc *r, Value *v) {
    if (val_is_ptr(*v)) *v = mk_ptr(relocate_obj(r, val_ptr(*v)));
}

/* the fields of one object, which must be one */
static int relocate_fields(Reloc *r, Obj *o, size_t room) {
    if (room < OBJ_HEADER_SIZE || obj_kind(o) < K_TUPLE || obj_kind(o) > K_LAST || obj_kind(o) == K_FORWARD) return 0;
    size_t size = obj_size(o);
    if (size > room) return 0;
    if (obj_has_fields(o)) {
        Value *f = obj_fields(o);
        for (uint32_t i = 0; i < obj_len(o); i++) relocate_value(r, &f[i]);
    }
    return 1;
}

int heap_relocate(VM *vm, uintptr_t old_base) {
    Reloc r = { vm, 0, old_base };
    if (vm->gc.nsegs) r.total = vm->gc.segs[vm->gc.nsegs - 1].base + vm->gc.segs[vm->gc.nsegs - 1].len;
    vm->gc.reloc_ok = 1;
    for (size_t k = 0; k < vm->gc.nsegs && vm->gc.reloc_ok; k++) {
        HeapSeg *s = &vm->gc.segs[k];
        for (size_t at = 0; vm->gc.reloc_ok && at < s->len; ) {
            Obj *o = (Obj *)(s->at + at);
            if (!relocate_fields(&r, o, s->len - at)) return 0;
            at += obj_size(o);
        }
    }
    /* every slot of the stack, dead registers too: they are values still */
    for (size_t i = 0; i < vm->sp; i++) relocate_value(&r, &vm->stack[i]);
#define RELOCATE_VALUE(v) relocate_value(&r, (v))
#define RELOCATE_OBJ(o) (*(o) = relocate_obj(&r, *(o)))
    OTHER_ROOTS(vm, RELOCATE_VALUE, RELOCATE_OBJ);
#undef RELOCATE_VALUE
#undef RELOCATE_OBJ
    free(vm->gc.segs);
    vm->gc.segs = NULL;
    vm->gc.nsegs = vm->gc.segs_cap = 0;
    return vm->gc.reloc_ok;
}
