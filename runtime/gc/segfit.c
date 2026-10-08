/* The segregated old space (docs/plans/garbage-collector-v2.md, M4 B; D3,
   D4 D): on the frame of mark.c, the chunks cut into blocks of 32 KiB, each
   given to one size class and cut into its cells. The classes are the
   multiples of 8 bytes to 128, then each an eighth larger than the last
   (rounded up to 8), to the largest object the old space holds, so that a
   cell wastes at most an eighth. A cell is free where its bit is clear: the
   sweep counts each block's bits, gives an empty block back to the free
   blocks (for any class) and puts one with free cells on its class's list,
   and placement finds the free cells of a block as it walks it -- the sweep
   of its cells is done lazily, by the allocation that wants them. While a
   full collection marks, the bits are being made again, so what it places
   goes into free blocks alone. A chunk whose blocks are all free goes back
   to the pool. Objects that were in the heap before it became this space
   (heap_init's) lie side by side in blocks of no class, which become free
   when nothing in them is reached. */
#include "gc/gc.h"
#include <string.h>

#define BLOCK ((size_t)1 << SF_BLOCK_SHIFT)
#define SF_MIXED 0xFF   /* a block of objects side by side, of no class */

static void out_of_memory(void) {
    fprintf(stderr, "runevm: out of memory\n");
    exit(2);
}

static void push(char ***list, size_t *n, size_t *cap, char *block) {
    if (*n == *cap) {
        size_t c = *cap ? 2 * *cap : 64;
        char **l = realloc(*list, c * sizeof *l);
        if (!l) out_of_memory();
        *list = l;
        *cap = c;
    }
    (*list)[(*n)++] = block;
}

/* the classes, made once a VM: by eights to 128 bytes, then an eighth
   larger each, to 8 KiB, the largest object of the old space being below
   the large-object space's threshold */
static void classes(VM *vm) {
    if (vm->gc.sf_class_of) return;
    int n = 0;
    for (uint32_t s = 16;; ) {
        vm->gc.sf_size[n++] = s;
        if (s >= 8192 || n == SF_CLASSES) break;
        uint32_t next = s < 128 ? s + 8 : (s + s / 8 + 7) & ~7u;
        s = next > 8192 ? 8192 : next;
    }
    vm->gc.sf_nclasses = n;
    vm->gc.sf_class_of = malloc(8192 / 8 + 1);
    if (!vm->gc.sf_class_of) out_of_memory();
    int k = 0;
    for (size_t e = 0; e <= 8192 / 8; e++) {
        while (k < n - 1 && vm->gc.sf_size[k] < 8 * e) k++;
        vm->gc.sf_class_of[e] = (uint8_t)k;
    }
}

/* a block's first byte that cells may take (the chunk's tables take the
   start of its first blocks), and its cells of a size */
static char *block_first(char *block) {
    Chunk *c = chunk_of(block);
    char *p = chunk_payload(c);
    return block > p ? block : p;
}
static uint32_t cells_of(char *block, uint32_t size) {
    return (uint32_t)((size_t)(block + BLOCK - block_first(block)) / size);
}
static SfBlock *descriptor(char *block) {
    Chunk *c = chunk_of(block);
    return &chunk_sfblocks(c)[(size_t)(block - (char *)c) >> SF_BLOCK_SHIFT];
}

/* A chunk new to the space: its tables clear, every block free */
static void new_chunk(VM *vm) {
    Chunk *c = chunk_take(vm, 0, CHUNK_MARK);
    memset(chunk_bits(c), 0, c->size >> 6);
    memset(chunk_sfblocks(c), 0, (c->size >> SF_BLOCK_SHIFT) * sizeof(SfBlock));
    c->top = chunk_room(c);
    chunk_append(vm, c);
    for (size_t b = c->size >> SF_BLOCK_SHIFT; b-- > (c->payload >> SF_BLOCK_SHIFT); )
        push(&vm->gc.sf_free, &vm->gc.sf_nfree, &vm->gc.sf_free_cap, (char *)c + (b << SF_BLOCK_SHIFT));
}

Obj *segfit_place(VM *vm, size_t size) {
    int k = vm->gc.sf_class_of[size >> 3];
    SfClass *cl = &vm->gc.sf[k];
    uint32_t cs = vm->gc.sf_size[k];
    for (;;) {
        if (cl->block) {
            Chunk *c = chunk_of(cl->block);
            char *first = block_first(cl->block);
            while (cl->next < cl->cells) {
                char *cell = first + (size_t)cl->next++ * cs;
                size_t off = (size_t)(cell - (char *)c);
                if (chunk_bit(c, off)) continue;
                chunk_bit_set(c, off);
                c->used += size;
                vm->gc.closed += size;
                return (Obj *)cell;
            }
        }
        /* the class's next block with free cells, or a free block */
        char *block;
        if (!vm->gc.sf_in_full && cl->at < cl->n) block = cl->list[cl->at++];
        else {
            if (!vm->gc.sf_nfree) new_chunk(vm);
            block = vm->gc.sf_free[--vm->gc.sf_nfree];
            descriptor(block)->cls = (uint8_t)(k + 1);
        }
        cl->block = block;
        cl->first = block_first(block);
        cl->size = cs;
        cl->next = 0;
        cl->cells = cells_of(block, cs);
    }
}

/* An object read from an image: side by side with the others, in blocks
   of no class, so that the run of the image stays in few segments
   (chunk.c, heap_read_take); such a block is free when nothing in it is
   reached */
Obj *segfit_bump(VM *vm, size_t size) {
    char *p = vm->gc.sf_bump;
    if (!p || size > (size_t)(vm->gc.sf_bump_limit - p)) {
        if (!vm->gc.sf_nfree) new_chunk(vm);
        char *block = vm->gc.sf_free[--vm->gc.sf_nfree];
        descriptor(block)->cls = SF_MIXED;
        p = block_first(block);
        vm->gc.sf_bump_limit = block + BLOCK;
    }
    vm->gc.sf_bump = p + size;
    Chunk *c = chunk_of(p);
    chunk_bit_set(c, (size_t)(p - (char *)c));
    c->used += size;
    vm->gc.closed += size;
    return (Obj *)p;
}

static void forget_blocks(VM *vm) {
    vm->gc.sf_bump = vm->gc.sf_bump_limit = NULL;
    for (int k = 0; k < vm->gc.sf_nclasses; k++) {
        vm->gc.sf[k].block = NULL;
        vm->gc.sf[k].n = vm->gc.sf[k].at = 0;
    }
}

/* After mark_adopt: the classes, and the adopted chunks' blocks -- of no
   class where objects lie, free where none do */
void segfit_adopted(VM *vm) {
    classes(vm);
    forget_blocks(vm);
    vm->gc.sf_nfree = 0;
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        SfBlock *blocks = chunk_sfblocks(c);
        memset(blocks, 0, (c->size >> SF_BLOCK_SHIFT) * sizeof(SfBlock));
        size_t end = c->payload + c->top;
        for (size_t b = c->size >> SF_BLOCK_SHIFT; b-- > (c->payload >> SF_BLOCK_SHIFT); ) {
            if ((b << SF_BLOCK_SHIFT) < end) blocks[b].cls = SF_MIXED;
            else push(&vm->gc.sf_free, &vm->gc.sf_nfree, &vm->gc.sf_free_cap, (char *)c + (b << SF_BLOCK_SHIFT));
        }
        c->top = chunk_room(c);
    }
}

/* Before a full collection marks: the blocks of every class forgotten, so
   that what is placed while it marks goes into free blocks */
void segfit_full_begin(VM *vm) {
    forget_blocks(vm);
    vm->gc.sf_in_full = 1;
}

/* the bits set in a block */
static size_t marked(Chunk *c, size_t b) {
    const uint64_t *bits = chunk_bits(c) + (b << (SF_BLOCK_SHIFT - 9));
    size_t n = 0;
    for (size_t w = 0; w < (BLOCK >> 9); w++) n += (size_t)__builtin_popcountll(bits[w]);
    return n;
}

/* After a full collection marked: each block's bits counted -- none, and it
   is free; free cells, and it goes on its class's list -- and a chunk with
   every block free given back */
void segfit_sweep(VM *vm) {
    forget_blocks(vm);
    vm->gc.sf_nfree = 0;
    Chunk **at = &vm->gc.first, *last = NULL;
    while (*at) {
        Chunk *c = *at;
        SfBlock *blocks = chunk_sfblocks(c);
        size_t free0 = vm->gc.sf_nfree, used = 0;
        for (size_t b = c->size >> SF_BLOCK_SHIFT; b-- > (c->payload >> SF_BLOCK_SHIFT); ) {
            char *block = (char *)c + (b << SF_BLOCK_SHIFT);
            size_t m = blocks[b].cls ? marked(c, b) : 0;
            if (!m) {
                blocks[b].cls = 0;
                push(&vm->gc.sf_free, &vm->gc.sf_nfree, &vm->gc.sf_free_cap, block);
                continue;
            }
            used++;
            if (blocks[b].cls == SF_MIXED) continue;
            SfClass *cl = &vm->gc.sf[blocks[b].cls - 1];
            uint32_t cells = cells_of(block, vm->gc.sf_size[blocks[b].cls - 1]);
            blocks[b].free = (uint16_t)(cells - m);
            if (cells > m) push(&cl->list, &cl->n, &cl->cap, block);
        }
        if (!used && c->next) {
            vm->gc.sf_nfree = free0;
            *at = c->next;
            chunk_give(vm, c);
            continue;
        }
        last = c;
        at = &c->next;
    }
    vm->gc.last = last;
    vm->gc.sf_in_full = 0;
}
