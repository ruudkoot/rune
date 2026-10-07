/* alloc.h -- old-space allocators over real memory, for H5 and for the
   gate's prototypes (docs/plans/garbage-collector-v2.md, *The candidate
   collectors*). Each places objects of value.h's layout (an 8-byte header,
   8-byte aligned, 16 bytes at least) and is told at a major collection
   which of its objects live and which died; it reports its footprint (the
   memory it holds: blocks, pools, chunks and large objects, page-rounded).

   bump      one contiguous space; a major slides the live objects down in
             address order (Lisp-2 order: a compacting or copying old space
             that keeps promotion order). The caller moves the objects:
             ga_compact gives every live object its new address.
   immix     mark-region (Blackburn and McKinley, PLDI 2008): blocks of 32
             KiB, lines of LINE bytes (64, 128, 256); a small object marks
             the line it starts in and the next line is skipped as "may be
             straddled" (the implicit mark); an object over a line marks
             every line it covers. Allocation bumps through the holes of the
             recyclable blocks in address order, then takes free blocks; an
             object over a line that does not fit the hole goes to an
             overflow block; over 8 KiB to the large-object space. No
             evacuation (defragmentation) is modelled.
   segfit    OCaml 5's segregated fit (runtime/shared_heap.c, sizeclasses.h):
             32 size classes up to 128 words with the header, pools of 4096
             words with a 4-word header and the class's wastage at the start;
             a pool all free is released; larger objects to the large-object
             space.
   bestfit   OCaml 4's best fit (runtime/freelist.c, policy 2): exact free
             lists for 2..17 words with the header, a splay tree by size above
             them; a block is split and the rest put back; the heap grows by
             chunks of max(1 MiB, 15% of the heap); the major's sweep
             coalesces neighbouring free blocks, chunk by chunk.
   firstfit, nextfit   the same heap with one address-ordered free list,
             allocation from the end of the block found (OCaml 4's policies
             1 and 0).

   Use: ga_new(kind, line, reserve); p = ga_alloc(g, bytes); at a major:
   ga_major_begin(g); ga_live(g, p, bytes) / ga_dead(g, p, bytes) for every
   object; ga_major_end(g); ga_footprint(g). The caller writes the objects.
   C17; one translation unit (static functions). */
#ifndef GCB_ALLOC_H
#define GCB_ALLOC_H
#include "gcb.h"

enum { GA_BUMP, GA_IMMIX, GA_SEGFIT, GA_BESTFIT, GA_FIRSTFIT, GA_NEXTFIT, GA_N };
static const char *ga_names[] = { "bump", "immix", "segfit", "bestfit", "firstfit", "nextfit" };

/* ---- the large-object space: one mapping an object, page-rounded ---- */
typedef struct { size_t bytes, objects; } los_t;
static void *los_alloc(los_t *l, size_t sz) {
    size_t b = rup(sz, 4096);
    void *p = mmap(NULL, b, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (p == MAP_FAILED) die("los: mmap failed");
    l->bytes += b; l->objects++;
    return p;
}
static void los_free(los_t *l, void *p, size_t sz) { size_t b = rup(sz, 4096); munmap(p, b); l->bytes -= b; l->objects--; }

/* ---- OCaml 5's size classes (runtime/caml/sizeclasses.h, generated) ---- */
#define SF_POOL_WORDS 4096
#define SF_POOL_BYTES (SF_POOL_WORDS * 8)
#define SF_POOL_HDR_WORDS 4
#define SF_MAX_WORDS 128
#define SF_NCLASS 32
static const unsigned sf_wsize[SF_NCLASS] = { 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 17, 19, 22, 25, 28, 32, 33, 37, 42, 47, 53, 59, 65, 73, 81, 89, 99, 108, 118, 128 };
static const unsigned char sf_wastage[SF_NCLASS] = { 0, 0, 0, 0, 2, 0, 4, 4, 2, 0, 4, 12, 12, 7, 0, 17, 4, 28, 0, 22, 18, 3, 11, 21, 62, 4, 42, 87, 33, 96, 80, 124 };
static unsigned char sf_class_of[SF_MAX_WORDS + 1];
static void sf_init_classes(void) {
    for (unsigned w = 1, c = 0; w <= SF_MAX_WORDS; w++) { while (sf_wsize[c] < w) c++; sf_class_of[w] = (unsigned char)c; }
}

typedef struct sf_pool {      /* a pool's descriptor, out of band (OCaml keeps 4 words in the pool) */
    struct sf_pool *next;      /* in its class's list of pools with room */
    char *free;                /* the free list through the slots */
    char *bump, *end;          /* slots never used */
    uint32_t live, cls, in_use;
} sf_pool;

/* ---- the free-list heap of bestfit/firstfit/nextfit: walkable chunks of
   blocks, a free block has kind K_FREE and its bytes in len ---- */
typedef struct bf_node { obj h; struct bf_node *left, *right, *same; } bf_node;   /* a free block over 136 bytes, in the tree */
typedef struct { obj h; char *next; } fl_block;                                 /* a free block on a list */
#define BF_SMALL_MAX 136   /* 17 words with the header */
typedef struct { char *base; size_t bytes; } chunk_t;

typedef struct {
    int kind;
    char *base; size_t reserve;   /* the address space reserved for the allocator */
    char *top;                    /* what has been carved out of it */
    los_t los;
    size_t los_threshold;
    /* bump */
    char *bfree;
    /* immix */
    size_t line, nlines, nblocks_max;
    uint8_t *marks;               /* nlines a block */
    uint8_t *bstate;              /* 0 unused (never carved), 1 in use, 2 free (on the free list) */
    uint32_t *freeblk; size_t nfree;
    uint32_t *recyc; size_t nrecyc, irecyc;
    char *cur, *lim;              /* the hole being filled */
    uint32_t curblk; size_t curline;   /* the line the hole search continues from */
    char *ocur, *olim;            /* the overflow block */
    size_t blocks_used;
    int exact;                    /* mark every line an object covers, no implicit mark */
    /* segfit */
    sf_pool *avail[SF_NCLASS], *cur_pool[SF_NCLASS];
    sf_pool *pdesc;                       /* one a pool of the reservation */
    uint32_t *pools; size_t npools;       /* the pools in use */
    uint32_t *pfree; size_t npfree;       /* released pools, for reuse */
    size_t pools_used;
    size_t internal;              /* bytes lost to rounding up to the class (live objects) */
    /* bestfit & co */
    chunk_t *chunks; size_t nchunks;
    size_t heap_bytes;
    char *small[BF_SMALL_MAX / 8 + 1];
    bf_node *root;
    char *flist, *ftail;          /* firstfit/nextfit: the address-ordered list */
    char *rover, *rover_prev;     /* nextfit: where the next search starts, and the block before it */
    size_t free_bytes;
} galloc;

static void ga_reserve(galloc *g, size_t reserve, size_t align) {
    char *p = mmap(NULL, reserve + align, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0);
    if (p == MAP_FAILED) die("alloc: cannot reserve the address space");
    g->base = (char *)rup((uintptr_t)p, align);
    g->reserve = reserve;
    g->top = g->base;
}
static char *ga_carve(galloc *g, size_t bytes) {
    if (g->top + bytes > g->base + g->reserve) die("alloc: the reservation is exhausted");
    char *p = g->top; g->top += bytes; return p;
}

/* ================= bump ================= */
static void *bump_alloc(galloc *g, size_t sz) {
    char *p = g->bfree;
    if (p + sz > g->base + g->reserve) die("bump: the reservation is exhausted");
    g->bfree = p + sz;
    return p;
}

/* ================= immix ================= */
#define IX_BLOCK 32768
static inline size_t ix_block_of(const galloc *g, const char *p) { return (size_t)(p - g->base) / IX_BLOCK; }
static uint32_t ix_take_free_block(galloc *g) {
    uint32_t b;
    if (g->nfree) b = g->freeblk[--g->nfree];
    else { ga_carve(g, IX_BLOCK); b = (uint32_t)(g->top - g->base) / IX_BLOCK - 1; }
    g->bstate[b] = 1; g->blocks_used++;
    memset(g->marks + (size_t)b * g->nlines, 0, g->nlines);
    return b;
}
/* the next hole at or after line L of block B (lines free at the last sweep,
   a free line after a marked one skipped unless exact); 0 if none */
static int ix_hole_in(galloc *g, uint32_t b, size_t l) {
    const uint8_t *m = g->marks + (size_t)b * g->nlines;
    size_t n = g->nlines;
    while (l < n) {
        if (m[l]) { l++; if (!g->exact && l < n && !m[l]) l++; continue; }
        size_t e = l; while (e < n && !m[e]) e++;
        g->cur = g->base + (size_t)b * IX_BLOCK + l * g->line;
        g->lim = g->base + (size_t)b * IX_BLOCK + e * g->line;
        g->curblk = b; g->curline = e;
        return 1;
    }
    return 0;
}
static void ix_next_hole(galloc *g) {
    if (g->curblk != UINT32_MAX && ix_hole_in(g, g->curblk, g->curline)) return;
    while (g->irecyc < g->nrecyc) {
        uint32_t b = g->recyc[g->irecyc++];
        if (ix_hole_in(g, b, 0)) return;
    }
    uint32_t b = ix_take_free_block(g);
    g->cur = g->base + (size_t)b * IX_BLOCK; g->lim = g->cur + IX_BLOCK;
    g->curblk = b; g->curline = g->nlines;
}
static void *ix_alloc(galloc *g, size_t sz) {
    if (sz > g->los_threshold) return los_alloc(&g->los, sz);
    if (g->cur + sz <= g->lim) { char *p = g->cur; g->cur += sz; return p; }
    if (sz > g->line) {   /* medium: the overflow block */
        if (g->ocur + sz > g->olim) { uint32_t b = ix_take_free_block(g); g->ocur = g->base + (size_t)b * IX_BLOCK; g->olim = g->ocur + IX_BLOCK; }
        char *p = g->ocur; g->ocur += sz; return p;
    }
    do ix_next_hole(g); while (g->cur + sz > g->lim);
    char *p = g->cur; g->cur += sz; return p;
}
static void ix_major_begin(galloc *g) {
    size_t carved = (size_t)(g->top - g->base) / IX_BLOCK;
    memset(g->marks, 0, carved * g->nlines);
}
static void ix_live(galloc *g, char *p, size_t sz) {
    size_t off = (size_t)(p - g->base);
    size_t l0 = off / g->line, l1 = (off + sz - 1) / g->line;
    if (!g->exact && sz <= g->line) l1 = l0;   /* the next line implicitly */
    for (size_t l = l0; l <= l1; l++) g->marks[l] = 1;   /* marks of consecutive blocks are consecutive */
}
static void ix_major_end(galloc *g) {
    size_t carved = (size_t)(g->top - g->base) / IX_BLOCK;
    g->nfree = 0; g->nrecyc = 0; g->irecyc = 0; g->blocks_used = 0;
    for (size_t b = 0; b < carved; b++) {
        const uint8_t *m = g->marks + b * g->nlines;
        size_t used = 0; for (size_t l = 0; l < g->nlines; l++) used += m[l];
        if (used == 0) { g->bstate[b] = 2; g->freeblk[g->nfree++] = (uint32_t)b; }
        else { g->bstate[b] = 1; g->blocks_used++; if (used < g->nlines) g->recyc[g->nrecyc++] = (uint32_t)b; }
    }
    /* free blocks are taken lowest first */
    for (size_t i = 0; i < g->nfree / 2; i++) { uint32_t t = g->freeblk[i]; g->freeblk[i] = g->freeblk[g->nfree - 1 - i]; g->freeblk[g->nfree - 1 - i] = t; }
    g->cur = g->lim = NULL; g->ocur = g->olim = NULL; g->curblk = UINT32_MAX;
}

/* ================= segfit ================= */
static sf_pool *sf_new_pool(galloc *g, unsigned c) {
    uint32_t ix;
    if (g->npfree) ix = g->pfree[--g->npfree];
    else { ga_carve(g, SF_POOL_BYTES); ix = (uint32_t)((size_t)(g->top - g->base) / SF_POOL_BYTES) - 1; }
    char *mem = g->base + (size_t)ix * SF_POOL_BYTES;
    sf_pool *p = &g->pdesc[ix];
    memset(p, 0, sizeof *p);
    p->cls = c; p->in_use = 1;
    size_t slot = sf_wsize[c] * 8;
    p->bump = mem + (SF_POOL_HDR_WORDS + sf_wastage[c]) * 8;
    p->end = p->bump + ((size_t)(mem + SF_POOL_BYTES - p->bump) / slot) * slot;
    g->pools[g->npools++] = ix;
    g->pools_used++;
    return p;
}
static void *sf_alloc(galloc *g, size_t sz) {
    size_t w = sz / 8;
    if (w > SF_MAX_WORDS) return los_alloc(&g->los, sz);
    unsigned c = sf_class_of[w];
    size_t slot = sf_wsize[c] * 8;
    sf_pool *p = g->cur_pool[c];
    for (;;) {
        if (p) {
            if (p->free) { char *s = p->free; p->free = *(char **)s; p->live++; g->internal += slot - sz; return s; }
            if (p->bump + slot <= p->end) { char *s = p->bump; p->bump += slot; p->live++; g->internal += slot - sz; return s; }
        }
        if (g->avail[c]) { p = g->avail[c]; g->avail[c] = p->next; }
        else p = sf_new_pool(g, c);
        g->cur_pool[c] = p;
    }
}
static inline sf_pool *sf_pool_of(const galloc *g, const char *s) { return &g->pdesc[(size_t)(s - g->base) / SF_POOL_BYTES]; }
static void sf_dead(galloc *g, char *s, size_t sz) {
    if (sz / 8 > SF_MAX_WORDS) { los_free(&g->los, s, sz); return; }
    sf_pool *p = sf_pool_of(g, s);
    *(char **)s = p->free; p->free = s; p->live--;
    g->internal -= sf_wsize[p->cls] * 8 - sz;
}
static void sf_major_end(galloc *g) {
    for (unsigned c = 0; c < SF_NCLASS; c++) { g->avail[c] = NULL; g->cur_pool[c] = NULL; }
    size_t k = 0;
    for (size_t i = 0; i < g->npools; i++) {
        sf_pool *p = &g->pdesc[g->pools[i]];
        if (p->live == 0) { p->in_use = 0; g->pfree[g->npfree++] = g->pools[i]; g->pools_used--; continue; }
        g->pools[k++] = g->pools[i];
        if (p->free || p->bump < p->end) { p->next = g->avail[p->cls]; g->avail[p->cls] = p; }
    }
    g->npools = k;
}

/* ================= the free-list heap ================= */
/* a splay tree of free blocks by size (top-down splay, Sleator and Tarjan) */
static size_t bf_size(const bf_node *n) { return n->h.len; }
static bf_node *bf_splay(bf_node *t, size_t sz) {
    if (!t) return NULL;
    bf_node N, *l = &N, *r = &N; N.left = N.right = NULL;
    for (;;) {
        if (sz < bf_size(t)) {
            if (!t->left) break;
            if (sz < bf_size(t->left)) { bf_node *y = t->left; t->left = y->right; y->right = t; t = y; if (!t->left) break; }
            r->left = t; r = t; t = t->left;
        } else if (sz > bf_size(t)) {
            if (!t->right) break;
            if (sz > bf_size(t->right)) { bf_node *y = t->right; t->right = y->left; y->left = t; t = y; if (!t->right) break; }
            l->right = t; l = t; t = t->right;
        } else break;
    }
    l->right = t->left; r->left = t->right; t->left = N.right; t->right = N.left;
    return t;
}
static void bf_tree_insert(galloc *g, bf_node *n) {
    size_t sz = bf_size(n);
    n->same = NULL;
    if (!g->root) { n->left = n->right = NULL; g->root = n; return; }
    bf_node *t = bf_splay(g->root, sz);
    if (bf_size(t) == sz) { n->same = t->same; t->same = n; g->root = t; return; }
    if (sz < bf_size(t)) { n->left = t->left; n->right = t; t->left = NULL; }
    else { n->right = t->right; n->left = t; t->right = NULL; }
    g->root = n;
}
/* the smallest block of SZ bytes or more, out of the tree */
static bf_node *bf_tree_take(galloc *g, size_t sz) {
    if (!g->root) return NULL;
    bf_node *t = bf_splay(g->root, sz);
    if (bf_size(t) < sz) {   /* the successor: the least of the right subtree */
        if (!t->right) { g->root = t; return NULL; }
        bf_node *r = bf_splay(t->right, sz);   /* every key there is > sz-ish: brings the least up */
        t->right = r;
        g->root = t;
        /* r's left subtree is empty (r is the least of the subtree after splaying for a smaller key) */
        if (r->same) { bf_node *s = r->same; r->same = s->same; return s; }
        t->right = r->right;
        return r;
    }
    if (t->same) { bf_node *s = t->same; t->same = s->same; g->root = t; return s; }
    /* remove t */
    if (!t->left) g->root = t->right;
    else { bf_node *x = bf_splay(t->left, sz); x->right = t->right; g->root = x; }
    return t;
}
static void fh_set_free(char *p, size_t bytes) { obj *o = (obj *)p; o->kind = K_FREE; o->pad = 0; o->contag = 0; o->len = (uint32_t)bytes; }
/* put a free block into the index of the heap's policy */
static void fh_index(galloc *g, char *p, size_t bytes) {
    fh_set_free(p, bytes);
    if (bytes < 16) return;   /* a fragment: found again by the sweep */
    g->free_bytes += bytes;
    if (g->kind == GA_BESTFIT) {
        if (bytes <= BF_SMALL_MAX) { ((fl_block *)p)->next = g->small[bytes / 8]; g->small[bytes / 8] = p; }
        else bf_tree_insert(g, (bf_node *)p);
    } else {   /* address order: chunks are carved upwards and the sweep walks upwards */
        ((fl_block *)p)->next = NULL;
        if (g->ftail) ((fl_block *)g->ftail)->next = p; else g->flist = p;
        g->ftail = p;
    }
}
static void fh_grow(galloc *g, size_t need) {
    size_t inc = g->heap_bytes * 15 / 100;
    if (inc < (1u << 20)) inc = 1u << 20;
    if (inc < need) inc = rup(need, 4096);
    inc = rup(inc, 4096);
    char *c = ga_carve(g, inc);
    g->chunks = realloc(g->chunks, (g->nchunks + 1) * sizeof *g->chunks);
    g->chunks[g->nchunks].base = c; g->chunks[g->nchunks].bytes = inc; g->nchunks++;
    g->heap_bytes += inc;
    fh_index(g, c, inc);   /* (no block spans two chunks, as OCaml's chunks are apart) */
}
/* split block P of BYTES for an object of SZ taken from its end; the rest
   stays (list policies) or is indexed again (best fit) */
static void *bf_alloc(galloc *g, size_t sz) {
    for (int tries = 0; tries < 2; tries++) {
        char *p = NULL; size_t bytes = 0;
        for (size_t s = sz; s <= BF_SMALL_MAX; s += 8)
            if (g->small[s / 8]) { p = g->small[s / 8]; g->small[s / 8] = ((fl_block *)p)->next; bytes = s; break; }
        if (!p) { bf_node *n = bf_tree_take(g, sz); if (n) { p = (char *)n; bytes = bf_size(n); } }
        if (p) {
            g->free_bytes -= bytes;
            size_t rest = bytes - sz;
            if (rest == 0) return p;
            fh_index(g, p, rest);   /* the front stays free */
            return p + rest;
        }
        fh_grow(g, sz);
    }
    die("bestfit: no block after growing");
    return NULL;
}
/* unlink P (whose predecessor is PREV, NULL for the head) */
static void fl_unlink(galloc *g, char *prev, char *p) {
    char *nx = ((fl_block *)p)->next;
    if (prev) ((fl_block *)prev)->next = nx; else g->flist = nx;
    if (g->ftail == p) g->ftail = prev;
    g->rover = nx; g->rover_prev = prev;
}
static void *fl_alloc(galloc *g, size_t sz) {
    for (int tries = 0; tries < 2; tries++) {
        int from_rover = g->kind == GA_NEXTFIT && g->rover;
        char *start = from_rover ? g->rover : g->flist, *start_prev = from_rover ? g->rover_prev : NULL;
        for (int pass = 0; pass < 2; pass++) {
            char *p = pass ? g->flist : start, *prev = pass ? NULL : start_prev, *stop = pass ? start : NULL;
            for (; p && p != stop; prev = p, p = ((fl_block *)p)->next) {
                size_t bytes = ((obj *)p)->len;
                if (bytes < sz) continue;
                size_t rest = bytes - sz;
                g->free_bytes -= rest >= 16 ? sz : bytes;
                if (rest >= 16) { ((obj *)p)->len = (uint32_t)rest; g->rover = p; g->rover_prev = prev; return p + rest; }
                fl_unlink(g, prev, p);
                if (rest) fh_set_free(p, rest);   /* an 8-byte fragment, found by the sweep */
                return p + rest;
            }
            if (!from_rover) break;
        }
        fh_grow(g, sz);
    }
    die("firstfit: no block after growing");
    return NULL;
}
static void fh_major_begin(galloc *g) { (void)g; }
static void fh_dead(galloc *g, char *p, size_t sz) { (void)g; fh_set_free(p, sz); }
/* the sweep: walk every chunk, merge free neighbours, index the result */
static void fh_major_end(galloc *g) {
    memset(g->small, 0, sizeof g->small); g->root = NULL;
    g->flist = g->ftail = g->rover = g->rover_prev = NULL; g->free_bytes = 0;
    for (size_t c = 0; c < g->nchunks; c++) {
        char *p = g->chunks[c].base, *end = p + g->chunks[c].bytes;
        while (p < end) {
            obj *o = (obj *)p;
            if (okind(o) != K_FREE) { p += osize(o); continue; }
            char *q = p + o->len;
            while (q < end && okind((obj *)q) == K_FREE) q += ((obj *)q)->len;
            fh_index(g, p, (size_t)(q - p));
            p = q;
        }
    }
}

/* ================= the interface ================= */
static galloc *ga_new(int kind, size_t line, size_t reserve) {
    galloc *g = calloc(1, sizeof *g);
    g->kind = kind;
    sf_init_classes();
    ga_reserve(g, reserve, kind == GA_SEGFIT ? SF_POOL_BYTES : kind == GA_IMMIX ? IX_BLOCK : 4096);
    switch (kind) {
    case GA_BUMP: g->bfree = g->base; break;
    case GA_IMMIX:
        g->line = line ? line : 128; g->nlines = IX_BLOCK / g->line;
        g->nblocks_max = reserve / IX_BLOCK;
        g->marks = calloc(g->nblocks_max, g->nlines);
        g->bstate = calloc(g->nblocks_max, 1);
        g->freeblk = malloc(g->nblocks_max * sizeof *g->freeblk);
        g->recyc = malloc(g->nblocks_max * sizeof *g->recyc);
        g->los_threshold = 8192;
        g->curblk = UINT32_MAX;
        break;
    case GA_SEGFIT:
        g->pdesc = calloc(reserve / SF_POOL_BYTES + 1, sizeof *g->pdesc);
        g->pools = malloc((reserve / SF_POOL_BYTES + 1) * sizeof *g->pools);
        g->pfree = malloc((reserve / SF_POOL_BYTES + 1) * sizeof *g->pfree);
        break;
    default: break;
    }
    return g;
}
static void ga_delete(galloc *g) {
    munmap(g->base, g->reserve);   /* (the alignment slack stays mapped: a small leak) */
    free(g->marks); free(g->bstate); free(g->freeblk); free(g->recyc); free(g->pdesc); free(g->pools); free(g->pfree); free(g->chunks);
    free(g);
}
static void *ga_alloc(galloc *g, size_t sz) {
    switch (g->kind) {
    case GA_BUMP: return bump_alloc(g, sz);
    case GA_IMMIX: return ix_alloc(g, sz);
    case GA_SEGFIT: return sf_alloc(g, sz);
    case GA_BESTFIT: return bf_alloc(g, sz);
    default: return fl_alloc(g, sz);
    }
}
static void ga_major_begin(galloc *g) {
    if (g->kind == GA_IMMIX) ix_major_begin(g);
    else if (g->kind >= GA_BESTFIT) fh_major_begin(g);
}
static void ga_live(galloc *g, void *p, size_t sz) {
    if (g->kind == GA_IMMIX && sz <= g->los_threshold) ix_live(g, p, sz);
}
static void ga_dead(galloc *g, void *p, size_t sz) {
    switch (g->kind) {
    case GA_IMMIX: if (sz > g->los_threshold) los_free(&g->los, p, sz); break;
    case GA_SEGFIT: sf_dead(g, p, sz); break;
    case GA_BESTFIT: case GA_FIRSTFIT: case GA_NEXTFIT: fh_dead(g, p, sz); break;
    default: break;
    }
}
static void ga_major_end(galloc *g) {
    if (g->kind == GA_IMMIX) ix_major_end(g);
    else if (g->kind == GA_SEGFIT) sf_major_end(g);
    else if (g->kind >= GA_BESTFIT) fh_major_end(g);
}
/* bump: the live objects (addresses in increasing order, N of them, sizes
   given) slide down; NEWADDR receives each one's new address */
static void ga_compact(galloc *g, char **addr, const uint32_t *size, size_t n) {
    char *to = g->base;
    for (size_t i = 0; i < n; i++) { if (addr[i] != to) memmove(to, addr[i], size[i]); addr[i] = to; to += size[i]; }
    g->bfree = to;
}
static size_t ga_footprint(const galloc *g) {
    switch (g->kind) {
    case GA_BUMP: return rup((size_t)(g->bfree - g->base), 4096);
    case GA_IMMIX: return g->blocks_used * IX_BLOCK + g->los.bytes;
    case GA_SEGFIT: return g->pools_used * SF_POOL_BYTES + g->los.bytes;
    default: return g->heap_bytes;
    }
}
#endif
