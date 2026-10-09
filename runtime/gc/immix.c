/* The mark-region old space (docs/plans/garbage-collector-v2.md, M4 A; D3,
   D4): on the frame of mark.c, the chunks cut into blocks of 32 KiB and
   lines of 64 bytes. A full collection marks the lines its objects cover
   (exactly: the marker has the size at hand), and the sweep makes each
   block's free lines its holes: promotion bumps into the holes of the
   blocks with free lines, an object of more than a line that its hole does
   not take goes to an overflow block, and a block with no line used is
   free for any of them. Before it marks, a full collection chooses the
   blocks with the most free lines, as many as hold live bytes up to the
   nursery's size, and evacuates them: an object reached in one is copied
   into a free block, and every reference to it then finds its forwarding
   header, so that the block is free at the sweep. While it marks, the
   lines are being made again, so what it places goes into free blocks
   alone. A chunk whose blocks are all free goes back to the pool. */
#include "gc/gc.h"
#include <string.h>

#define LINES_PER_BLOCK ((size_t)1 << (IX_BLOCK_SHIFT - IX_LINE_SHIFT))

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

/* the first line of block b that objects may take: the chunk's tables take
   the first lines of its first blocks */
static size_t first_line(const Chunk *c, size_t b) {
    size_t l = b * LINES_PER_BLOCK, p = c->payload >> IX_LINE_SHIFT;
    return l > p ? l : p;
}

/* A block's free lines, and where it goes after a sweep: to the free
   blocks, those with free lines, or neither */
static size_t free_lines(Chunk *c, size_t b) {
    const uint8_t *lines = chunk_lines(c);
    size_t n = 0;
    for (size_t l = first_line(c, b); l < (b + 1) * LINES_PER_BLOCK; l++) n += !lines[l];
    return n;
}

/* the blocks of a chunk, after a sweep or for a chunk new to the space */
static int list_blocks(VM *vm, Chunk *c) {
    size_t nb = c->size >> IX_BLOCK_SHIFT, used = 0;
    IxBlock *blocks = chunk_blocks(c);
    for (size_t b = c->payload >> IX_BLOCK_SHIFT; b < nb; b++) {
        size_t f = free_lines(c, b), all = (b + 1) * LINES_PER_BLOCK - first_line(c, b);
        blocks[b].free = (uint16_t)f;
        blocks[b].candidate = 0;
        if (f == all) push(&vm->gc.ix_free, &vm->gc.ix_nfree, &vm->gc.ix_free_cap, (char *)c + (b << IX_BLOCK_SHIFT));
        else {
            used++;
            if (f) push(&vm->gc.ix_recycle, &vm->gc.ix_nrecycle, &vm->gc.ix_recycle_cap, (char *)c + (b << IX_BLOCK_SHIFT));
        }
    }
    return used != 0;
}

static void reset_holes(VM *vm) {
    vm->gc.ix_cursor = vm->gc.ix_limit = vm->gc.ix_block = NULL;
    vm->gc.ix_ocursor = vm->gc.ix_olimit = NULL;
}

/* A chunk new to the space: its tables clear, every block free */
static void new_chunk(VM *vm) {
    Chunk *c = chunk_take(vm, 0, CHUNK_MARK);
    memset(chunk_bits(c), 0, c->size >> 6);
    memset(chunk_lines(c), 0, c->size >> IX_LINE_SHIFT);
    memset(chunk_blocks(c), 0, (c->size >> IX_BLOCK_SHIFT) * sizeof(IxBlock));
    c->top = chunk_room(c);   /* holes anywhere: the bits are searched to its end */
    chunk_append(vm, c);
    /* in order, so that the last pushed, the first taken, is its first block */
    size_t nb = c->size >> IX_BLOCK_SHIFT;
    for (size_t b = nb; b-- > (c->payload >> IX_BLOCK_SHIFT); )
        push(&vm->gc.ix_free, &vm->gc.ix_nfree, &vm->gc.ix_free_cap, (char *)c + (b << IX_BLOCK_SHIFT));
}

/* a free block, whole: its first line to its end */
static char *free_block(VM *vm, char **limit) {
    if (!vm->gc.ix_nfree) new_chunk(vm);
    char *block = vm->gc.ix_free[--vm->gc.ix_nfree];
    Chunk *c = chunk_of(block);
    size_t b = (size_t)(block - (char *)c) >> IX_BLOCK_SHIFT;
    *limit = block + ((size_t)1 << IX_BLOCK_SHIFT);
    return (char *)c + (first_line(c, b) << IX_LINE_SHIFT);
}

/* the next run of free lines of the block, at or after from */
static int next_hole(VM *vm, char *block, char *from) {
    Chunk *c = chunk_of(block);
    size_t b = (size_t)(block - (char *)c) >> IX_BLOCK_SHIFT, end = (b + 1) * LINES_PER_BLOCK;
    size_t l = (size_t)(from - (char *)c) >> IX_LINE_SHIFT;
    if (l < first_line(c, b)) l = first_line(c, b);
    const uint8_t *lines = chunk_lines(c);
    while (l < end && lines[l]) l++;
    if (l >= end) return 0;
    size_t e = l;
    while (e < end && !lines[e]) e++;
    vm->gc.ix_block = block;
    vm->gc.ix_cursor = (char *)c + (l << IX_LINE_SHIFT);
    vm->gc.ix_limit = (char *)c + (e << IX_LINE_SHIFT);
    return 1;
}

/* the next hole: the rest of the block, the next block with free lines, a
   free block (while a full collection marks, a free block alone) */
static void next(VM *vm) {
    if (!vm->gc.ix_in_full) {
        if (vm->gc.ix_block && next_hole(vm, vm->gc.ix_block, vm->gc.ix_limit)) return;
        while (vm->gc.ix_recycle_at < vm->gc.ix_nrecycle) {
            char *block = vm->gc.ix_recycle[vm->gc.ix_recycle_at++];
            if (next_hole(vm, block, block)) return;
        }
    }
    char *limit;
    char *start = free_block(vm, &limit);
    vm->gc.ix_block = (char *)((uintptr_t)start & ~(((uintptr_t)1 << IX_BLOCK_SHIFT) - 1));
    vm->gc.ix_cursor = start;
    vm->gc.ix_limit = limit;
}

#define lines_mark ix_lines_mark

Obj *immix_place(VM *vm, size_t size) {
    char *p = vm->gc.ix_cursor;
    if (!p || size > (size_t)(vm->gc.ix_limit - p)) {
        if (size > IX_LINE) {
            /* a medium object: the overflow block, which a hole of a line or two does not waste */
            p = vm->gc.ix_ocursor;
            if (!p || size > (size_t)(vm->gc.ix_olimit - p)) p = vm->gc.ix_ocursor = free_block(vm, &vm->gc.ix_olimit);
            vm->gc.ix_ocursor = p + size;
            goto placed;
        }
        do next(vm); while (size > (size_t)(vm->gc.ix_limit - vm->gc.ix_cursor));
        p = vm->gc.ix_cursor;
    }
    vm->gc.ix_cursor = p + size;
placed:;
    Chunk *c = chunk_of(p);
    size_t off = (size_t)(p - (char *)c);
    chunk_bit_set(c, off);
    lines_mark(c, off, size);
    c->used += size;
    vm->gc.closed += size;
    return (Obj *)p;
}

/* After mark_adopt: the adopted chunks' lines from their objects, and
   their blocks listed */
void immix_adopted(VM *vm) {
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        memset(chunk_lines(c), 0, c->size >> IX_LINE_SHIFT);
        memset(chunk_blocks(c), 0, (c->size >> IX_BLOCK_SHIFT) * sizeof(IxBlock));
        for (size_t at = chunk_bits_next(c, 0); at != CHUNK_END; ) {
            size_t size = obj_size((Obj *)(chunk_payload(c) + at));
            lines_mark(c, c->payload + at, size);
            at = chunk_bits_next(c, at + size);
        }
        c->top = chunk_room(c);
    }
    vm->gc.ix_nrecycle = vm->gc.ix_recycle_at = vm->gc.ix_nfree = 0;
    for (Chunk *c = vm->gc.first; c; c = c->next) list_blocks(vm, c);
    reset_holes(vm);
}

static int by_free(const void *a, const void *b) {
    const IxBlock *x = *(IxBlock *const *)a, *y = *(IxBlock *const *)b;
    return (int)y->free - (int)x->free;
}

/* Before a full collection marks: the candidates for evacuation -- the
   blocks with the most free lines, with live lines up to the nursery's
   size in all -- then every line cleared, to be marked again; and the
   holes forgotten, so that what is placed while it marks goes into the
   free blocks */
void immix_full_begin(VM *vm) {
    size_t n = 0, cap = 0;
    IxBlock **cand = NULL;
    for (Chunk *c = vm->gc.first; c; c = c->next) {
        IxBlock *blocks = chunk_blocks(c);
        for (size_t b = c->payload >> IX_BLOCK_SHIFT; b < c->size >> IX_BLOCK_SHIFT; b++) {
            size_t f = free_lines(c, b), all = (b + 1) * LINES_PER_BLOCK - first_line(c, b);
            blocks[b].free = (uint16_t)f;
            blocks[b].candidate = 0;
            if (!f || f == all) continue;
            blocks[b].live = (uint16_t)(all - f);
            if (n == cap) {
                cap = cap ? 2 * cap : 256;
                IxBlock **m = realloc(cand, cap * sizeof *m);
                if (!m) out_of_memory();
                cand = m;
            }
            cand[n++] = &blocks[b];
        }
    }
    if (n) qsort(cand, n, sizeof *cand, by_free);
    size_t budget = vm->gc.nursery_size, moved = 0;
    for (size_t i = 0; i < n; i++) {
        size_t live = (size_t)cand[i]->live << IX_LINE_SHIFT;
        if (moved + live > budget) break;
        cand[i]->candidate = 1;
        moved += live;
    }
    free(cand);
    for (Chunk *c = vm->gc.first; c; c = c->next) memset(chunk_lines(c), 0, c->size >> IX_LINE_SHIFT);
    reset_holes(vm);
    vm->gc.ix_nrecycle = vm->gc.ix_recycle_at = 0;
    vm->gc.ix_in_full = 1;
}

/* An old object the marker reached for the first time: its lines marked,
   or, in a block chosen for evacuation, its copy in a free block, which
   the marker queues */
Obj *immix_marked(VM *vm, Chunk *c, Obj *o, size_t size) {
    size_t off = (size_t)((char *)o - (char *)c);
    if (!chunk_blocks(c)[off >> IX_BLOCK_SHIFT].candidate) {
        lines_mark(c, off, size);
        return o;
    }
    Obj *n = immix_place(vm, size);
    memcpy(n, o, size);
    obj_forward(o, n);
    vm->gc.ix_evacuated += size;
    return n;
}

/* After a full collection marked: every block's free lines; a chunk with
   none used given back; the holes from the first block with free lines */
void immix_sweep(VM *vm) {
    vm->gc.ix_nrecycle = vm->gc.ix_recycle_at = vm->gc.ix_nfree = 0;
    Chunk **at = &vm->gc.first, *last = NULL;
    while (*at) {
        Chunk *c = *at;
        size_t free0 = vm->gc.ix_nfree;
        if (!list_blocks(vm, c) && c->next) {
            /* its blocks were listed free: taken off again with it */
            vm->gc.ix_nfree = free0;
            *at = c->next;
            chunk_give(vm, c);
            continue;
        }
        last = c;
        at = &c->next;
    }
    vm->gc.last = last;
    reset_holes(vm);
    vm->gc.ix_in_full = 0;
}
