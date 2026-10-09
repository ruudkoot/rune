/* heapgen.h -- synthetic heaps for H2, H3 and H7: N objects of one size,
   in one of four shapes, placed in creation order or shuffled.

   shape  pointer fields                         the rest
   list   field 0: the next cell                 immediates
   tree   fields 0, 1: the children (heap order) immediates (24 bytes at least)
   graph  field 0: the next object, 1: a random one   immediates (24 at least)
   array  field 0: the next object, every other field a random object

   Creation order is the order an SML program builds them: a list or a
   chain from its tail (the head last), a tree children first (post-order).
   `shuffle` places the objects in a random order instead: an old heap's
   layout, where the mutator's order is lost. The root is object 0; every
   object is reachable from it. The random targets are a hash of (object,
   field), so a heap rebuilt is the same heap. */
#ifndef GCB_HEAPGEN_H
#define GCB_HEAPGEN_H
#include "gcb.h"

enum { SH_LIST, SH_TREE, SH_GRAPH, SH_ARRAY };
static const char *shape_names[] = { "list", "tree", "graph", "array" };

typedef struct {
    int shape, shuffle;
    size_t osz, n, k;        /* object bytes, objects, fields an object */
    char *base; size_t cap;  /* the region the heap is built in */
    uint32_t *slot;          /* object i is at base + slot[i] * osz */
    val root;
} hg_t;

static inline uint64_t hg_hash(uint64_t x) {
    x ^= x >> 33; x *= 0xff51afd7ed558ccdULL; x ^= x >> 33; x *= 0xc4ceb9fe1a85ec53ULL; x ^= x >> 33; return x;
}
/* the target of field f of object i, or -1 for an immediate */
static inline int64_t hg_target(const hg_t *h, size_t i, size_t f) {
    switch (h->shape) {
    case SH_LIST: return f == 0 ? (i + 1 < h->n ? (int64_t)(i + 1) : -1) : -1;
    case SH_TREE: if (f < 2) { size_t c = 2 * i + 1 + f; return c < h->n ? (int64_t)c : -1; } return -1;
    case SH_GRAPH:
        if (f == 0) return i + 1 < h->n ? (int64_t)(i + 1) : -1;
        if (f == 1) return (int64_t)(hg_hash(i * 64 + f) % h->n);
        return -1;
    default:
        if (f == 0) return i + 1 < h->n ? (int64_t)(i + 1) : -1;
        return (int64_t)(hg_hash(i * 64 + f) % h->n);
    }
}
static void hg_postorder(uint32_t *slot, size_t n) {
    /* node i of a heap-numbered tree gets its post-order index, iteratively */
    size_t *st = malloc(1024 * sizeof *st); size_t sp = 0; uint32_t next = 0;
    /* (node, state): state 0 = children not yet done */
    st[sp++] = 0; st[sp++] = 0;
    while (sp) {
        size_t state = st[--sp], i = st[--sp];
        if (state == 0) {
            st[sp++] = i; st[sp++] = 1;
            size_t r = 2 * i + 2, l = 2 * i + 1;
            if (r < n) { st[sp++] = r; st[sp++] = 0; }
            if (l < n) { st[sp++] = l; st[sp++] = 0; }
        } else slot[i] = next++;
    }
    free(st);
}
/* plan a heap of LIVE bytes (rounded down to whole objects) */
static void hg_plan(hg_t *h, int shape, size_t osz, size_t live, int shuffle) {
    memset(h, 0, sizeof *h);
    if ((shape == SH_TREE || shape == SH_GRAPH) && osz < 24) osz = 24;
    h->shape = shape; h->osz = osz; h->shuffle = shuffle;
    h->k = fields_for(osz);
    h->n = live / osz; if (h->n < 2) h->n = 2;
    h->cap = h->n * osz;
    h->slot = malloc(h->n * sizeof *h->slot);
    if (shuffle) {
        for (size_t i = 0; i < h->n; i++) h->slot[i] = (uint32_t)i;
        uint64_t s = 0xC0FFEEULL + h->n;
        shuffle_u32(h->slot, h->n, &s);
    } else if (shape == SH_TREE) hg_postorder(h->slot, h->n);
    else for (size_t i = 0; i < h->n; i++) h->slot[i] = (uint32_t)(h->n - 1 - i);
}
static inline obj *hg_addr(const hg_t *h, size_t i) { return (obj *)(h->base + (size_t)h->slot[i] * h->osz); }
/* write the objects into h->base (which the caller has mapped, h->cap bytes) */
static void hg_fill(hg_t *h) {
    int kind = h->shape == SH_ARRAY ? K_ARRAY : h->shape == SH_TREE ? K_CON : K_TUPLE;
    for (size_t i = 0; i < h->n; i++) {
        obj *o = hg_addr(h, i);
        hdr(o, kind, 0, (uint32_t)h->k);
        val *f = FIELDS(o);
        for (size_t j = 0; j < h->k; j++) {
            int64_t t = hg_target(h, i, j);
            f[j] = t >= 0 ? ptr_val(hg_addr(h, (size_t)t)) : mk_int((int64_t)(i + j));
        }
    }
    h->root = ptr_val(hg_addr(h, 0));
}
static void hg_free(hg_t *h) { free(h->slot); h->slot = NULL; }
static void hg_name(const hg_t *h, char *buf, size_t len, size_t live) {
    char hb[32];
    snprintf(buf, len, "%s/%zu/%s/%s", shape_names[h->shape], h->osz, h->shuffle ? "shuf" : "alloc", human((double)live, hb));
}
#endif
