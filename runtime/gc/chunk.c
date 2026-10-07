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

Chunk *chunk_take(VM *vm, size_t bytes) {
    Chunk *c;
    if (bytes <= CHUNK_ROOM && vm->gc.pool) {
        c = vm->gc.pool;
        vm->gc.pool = c->next;
        vm->gc.pooled--;
    } else {
        size_t size = CHUNK_SIZE;
        if (bytes > CHUNK_ROOM) {
            /* a run of chunks for one object, rounded up to whole ones */
            if (bytes > SIZE_MAX - CHUNK_HEADER - CHUNK_SIZE) out_of_memory();
            size = (bytes + CHUNK_HEADER + CHUNK_SIZE - 1) / CHUNK_SIZE * CHUNK_SIZE;
        }
        c = sys_mem_reserve(size, CHUNK_SIZE, vm->gc.hint);
        if (!c) out_of_memory();
        vm->gc.hint = (char *)c + size;
        c->size = size;
    }
    c->next = NULL;
    c->used = 0;
    c->base = 0;
    return c;
}

/* A pool of one heap's worth, as many chunks as the heap's size takes, and
   one more: what the semispace kept between collections held. A run of
   chunks goes back to the system, being of a size the next may not want. */
void chunk_give(VM *vm, Chunk *c) {
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
    for (Chunk *c = vm->gc.first, *n; c; c = n) { n = c->next; sys_mem_release(c, c->size); }
    for (Chunk *c = vm->gc.pool, *n; c; c = n) { n = c->next; sys_mem_release(c, c->size); }
    vm->gc.first = vm->gc.last = vm->gc.pool = NULL;
    vm->gc.pooled = 0;
    vm->alloc.from = NULL;
    vm->alloc.size = vm->alloc.used = 0;
}

/* The fast paths bump alloc.used against alloc.size: the room of the last
   chunk, and no more than the heap's size leaves for it, so that where a
   collection is due they leave for the slow path as they did when the heap
   was one semispace of that size (runtime/heap.c, vm_alloc). The census VM
   counts the heap's size by the stock sizes, which alloc does not hold: it
   interprets alone, and vm_alloc asks it of every allocation. */
void alloc_view(VM *vm) {
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
        Chunk *run = chunk_take(vm, size);
        run->used = size;
        chunk_append(vm, run);
        vm->gc.closed += size;
        chunk_append(vm, chunk_take(vm, 0));
        alloc_view(vm);
        return (Obj *)chunk_payload(run);
    }
    chunk_append(vm, chunk_take(vm, 0));
    alloc_view(vm);
    Obj *o = (Obj *)vm->alloc.from;
    vm->alloc.used = size;
    return o;
}

/* ---- images (runtime/image.c) ---- */

void heap_number(VM *vm) {
    uint64_t base = 0;
    for (Chunk *c = heap_first(vm); c; c = c->next) {
        c->base = base;
        base += chunk_used(vm, c);
    }
}

/* The heap an image is read into: empty, of the size it was written with */
void heap_read_begin(VM *vm, size_t size) {
    heap_chunks_release(vm);
    vm->gc.size = size;
    vm->gc.closed = 0;
    chunk_append(vm, chunk_take(vm, 0));
    vm->gc.last->used = 0;
}

/* The next object of the image's run, of bytes: after the last, or in a
   chunk of its own where it does not fit; each chunk's base is the offset
   of its first object in the run, for heap_relocate. The last chunk's
   bytes are in its used until alloc_view, after the whole run. */
Obj *heap_read_take(VM *vm, size_t bytes) {
    Chunk *c = vm->gc.last;
    if (bytes > chunk_room(c) - c->used) {
        uint64_t base = c->base + c->used;
        vm->gc.closed += c->used;
        c = chunk_take(vm, bytes > CHUNK_ROOM ? bytes : 0);
        c->base = base;
        chunk_append(vm, c);
        if (bytes > CHUNK_ROOM) {
            /* a run holds one object: the next goes into a chunk after it */
            c->used = bytes;
            Chunk *next = chunk_take(vm, 0);
            next->base = base + bytes;
            vm->gc.closed += bytes;
            chunk_append(vm, next);
            return (Obj *)chunk_payload(c);
        }
    }
    Obj *o = (Obj *)(chunk_payload(c) + c->used);
    c->used += bytes;
    return o;
}

/* ---- relocation, for an image of the VM (runtime/image.c) ---- */

/* The heap and every root were read with each pointer the offset of its
   object in the image's run, plus old_base (so that none is 0): each is
   turned into where that object is now, found among the chunks by their
   bases. A pointer that is past the run, or an object that is not one,
   makes the image unsound (0). */
typedef struct Reloc {
    VM *vm;
    Chunk **chunks;      /* by base, which is the list's order */
    size_t n;
    uint64_t total;      /* the bytes of the run */
    uintptr_t old_base;
} Reloc;

static Obj *relocate_obj(Reloc *r, Obj *o) {
    uint64_t at = (uint64_t)((uintptr_t)o - r->old_base);
    if ((uintptr_t)o < r->old_base || at >= r->total) { r->vm->gc.reloc_ok = 0; return NULL; }
    size_t lo = 0, hi = r->n;
    while (hi - lo > 1) {
        size_t mid = lo + (hi - lo) / 2;
        if (r->chunks[mid]->base <= at) lo = mid; else hi = mid;
    }
    Chunk *c = r->chunks[lo];
    if (at - c->base >= chunk_used(r->vm, c)) { r->vm->gc.reloc_ok = 0; return NULL; }
    return (Obj *)(chunk_payload(c) + (size_t)(at - c->base));
}

static void relocate_value(Reloc *r, Value *v) {
    if (val_is_ptr(*v)) *v = mk_ptr(relocate_obj(r, val_ptr(*v)));
}

int heap_relocate(VM *vm, uintptr_t old_base) {
    Reloc r = { vm, NULL, 0, 0, old_base };
    for (Chunk *c = heap_first(vm); c; c = c->next) r.n++;
    r.chunks = malloc(r.n * sizeof *r.chunks);
    if (!r.chunks) out_of_memory();
    r.n = 0;
    for (Chunk *c = heap_first(vm); c; c = c->next) {
        r.chunks[r.n++] = c;
        r.total = c->base + chunk_used(vm, c);
    }
    vm->gc.reloc_ok = 1;
    for (Chunk *c = heap_first(vm); c && vm->gc.reloc_ok; c = c->next) {
        size_t used = chunk_used(vm, c);
        for (size_t at = 0; vm->gc.reloc_ok && at < used; ) {
            Obj *o = (Obj *)(chunk_payload(c) + at);
            if (used - at < OBJ_HEADER_SIZE || obj_kind(o) < K_TUPLE || obj_kind(o) > K_LAST || obj_kind(o) == K_FORWARD) { free(r.chunks); return 0; }
            size_t size = obj_size(o);
            if (size > used - at) { free(r.chunks); return 0; }
            if (obj_has_fields(o)) {
                Value *f = obj_fields(o);
                for (uint32_t i = 0; i < obj_len(o); i++) relocate_value(&r, &f[i]);
            }
            at += size;
        }
    }
    /* every slot of the stack, dead registers too: they are values still */
    for (size_t i = 0; i < vm->sp; i++) relocate_value(&r, &vm->stack[i]);
#define RELOCATE_VALUE(v) relocate_value(&r, (v))
#define RELOCATE_OBJ(o) (*(o) = relocate_obj(&r, *(o)))
    OTHER_ROOTS(vm, RELOCATE_VALUE, RELOCATE_OBJ);
#undef RELOCATE_VALUE
#undef RELOCATE_OBJ
    free(r.chunks);
    return vm->gc.reloc_ok;
}
