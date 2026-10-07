/* collect.h -- the tracing loops H2, H3 and H7 time, each over a heap of
   value.h's objects reachable from one root:

   * cheney: runtime/heap.c's copy_obj and collect_into (a copy of a size
     known at compile time for one to six fields, else memcpy; the kind
     made K_FORWARD and the new address in the first payload word), the
     scan a linear walk of to-space. cheney_pf adds a prefetch of what the
     fields of the objects PF_AHEAD bytes ahead of the scan point to (they
     are still in from-space), the copying form of Cher, Hosking and
     Vijaykumar's buffered prefetch (ASPLOS 2004).
   * mark: depth first with an explicit stack, the mark a bit in the header
     (GC_MARK of the kind byte, its sense flipped every cycle so that no
     clearing is needed) or a side bitmap (a bit for every 8 bytes, 1.56%
     of the heap). Node enqueuing tests and sets the mark when an object is
     discovered and pushes only what it marked; edge enqueuing pushes every
     pointer and tests when it pops, through a FIFO of PF_FIFO entries with
     a prefetch at its entrance (Garner, Blackburn and Frampton, ISMM 2007,
     after Cher et al.); the bitmap's node enqueuing can prefetch the object
     when it pushes it (Boehm, ISMM 2000), since the mark did not touch it. */
#ifndef GCB_COLLECT_H
#define GCB_COLLECT_H
#include "gcb.h"

/* ---- Cheney ---- */
static char *cc_free;
static size_t cc_objs;
ALWAYS_INLINE obj *cc_copy(obj *o) {
    if (okind(o) == K_FORWARD) { obj *n; memcpy(&n, FIELDS(o), 8); return n; }
    size_t sz = osize(o);
    obj *n = (obj *)cc_free;
    switch (sz) {
    case 16: memcpy(n, o, 16); break;
    case 24: memcpy(n, o, 24); break;
    case 32: memcpy(n, o, 32); break;
    case 40: memcpy(n, o, 40); break;
    case 48: memcpy(n, o, 48); break;
    case 56: memcpy(n, o, 56); break;
    default: memcpy(n, o, sz); break;
    }
    cc_free += sz;
    cc_objs++;
    o->kind = K_FORWARD;
    memcpy(FIELDS(o), &n, 8);
    return n;
}
ALWAYS_INLINE void cc_value(val *v) { if (is_ptr(*v)) *v = ptr_val(cc_copy(ptr_of(*v))); }
static NOINLINE size_t cheney(val *roots, size_t nroots, char *to) {
    cc_free = to; cc_objs = 0;
    for (size_t i = 0; i < nroots; i++) cc_value(&roots[i]);
    char *scan = to;
    while (scan < cc_free) {
        obj *o = (obj *)scan;
        if (has_fields(o)) { val *f = FIELDS(o); for (uint32_t i = 0, n = o->len; i < n; i++) cc_value(&f[i]); }
        scan += osize(o);
    }
    return (size_t)(cc_free - to);
}
#ifndef PF_AHEAD
#define PF_AHEAD 512
#endif
static NOINLINE size_t cheney_pf(val *roots, size_t nroots, char *to) {
    cc_free = to; cc_objs = 0;
    for (size_t i = 0; i < nroots; i++) cc_value(&roots[i]);
    char *scan = to, *pf = to;
    while (scan < cc_free) {
        /* the prefetch point runs ahead of the scan over to-space objects
           whose fields still point into from-space */
        while (pf < cc_free && pf < scan + PF_AHEAD) {
            obj *p = (obj *)pf;
            if (has_fields(p)) { val *f = FIELDS(p); for (uint32_t i = 0, n = p->len; i < n; i++) if (is_ptr(f[i])) __builtin_prefetch(ptr_of(f[i]), 1, 3); }
            pf += osize(p);
        }
        obj *o = (obj *)scan;
        if (has_fields(o)) { val *f = FIELDS(o); for (uint32_t i = 0, n = o->len; i < n; i++) cc_value(&f[i]); }
        scan += osize(o);
    }
    return (size_t)(cc_free - to);
}

/* ---- marking ---- */
typedef struct {
    char *base; size_t bytes;   /* the heap the bitmap covers */
    uint64_t *bits;              /* a bit for every 8 bytes */
    uint8_t sense;               /* GC_MARK or 0: what "marked" is this cycle */
    val *stack; size_t stack_cap;
    size_t marked, marked_bytes;
} mk_t;
static void mk_init(mk_t *m, char *base, size_t bytes, size_t stack_entries) {
    memset(m, 0, sizeof *m);
    m->base = base; m->bytes = bytes;
    m->bits = region(rup(bytes / 64 + 8, 4096), MAP_TOUCH);
    m->stack_cap = stack_entries;
    m->stack = region(rup(stack_entries * sizeof(val), 4096), MAP_NOPOP);
    m->sense = GC_MARK;
}
static void mk_done(mk_t *m) {
    region_free(m->bits, rup(m->bytes / 64 + 8, 4096));
    region_free(m->stack, rup(m->stack_cap * sizeof(val), 4096));
}
static NOINLINE void mk_clear_bits(mk_t *m) { memset(m->bits, 0, m->bytes / 64 + 8); }
/* the next cycle: header marks flip their sense, bitmaps are cleared by the caller */
static void mk_next_cycle(mk_t *m) { m->sense ^= GC_MARK; m->marked = m->marked_bytes = 0; }

ALWAYS_INLINE int hdr_marked(const mk_t *m, const obj *o) { return (o->kind & GC_MARK) == m->sense; }
ALWAYS_INLINE void hdr_mark(const mk_t *m, obj *o) { o->kind = (uint8_t)((o->kind & ~GC_MARK) | m->sense); }
ALWAYS_INLINE size_t bm_index(const mk_t *m, const obj *o) { return (size_t)((const char *)o - m->base) >> 3; }
ALWAYS_INLINE int bm_test_set(mk_t *m, const obj *o) {   /* 1 if it was marked already */
    size_t b = bm_index(m, o);
    uint64_t w = m->bits[b >> 6], bit = (uint64_t)1 << (b & 63);
    if (w & bit) return 1;
    m->bits[b >> 6] = w | bit;
    return 0;
}
ALWAYS_INLINE int bm_test(const mk_t *m, const obj *o) { size_t b = bm_index(m, o); return (int)((m->bits[b >> 6] >> (b & 63)) & 1); }

/* node enqueuing, header bit */
static NOINLINE void mark_hdr(mk_t *m, val root) {
    val *st = m->stack; size_t sp = 0;
    obj *r = ptr_of(root);
    hdr_mark(m, r); st[sp++] = root;
    size_t cnt = 1, bytes = 0;
    while (sp) {
        obj *o = ptr_of(st[--sp]);
        bytes += osize(o);
        if (!has_fields(o)) continue;
        val *f = FIELDS(o);
        for (uint32_t i = 0, n = o->len; i < n; i++) {
            val v = f[i];
            if (!is_ptr(v)) continue;
            obj *t = ptr_of(v);
            if (hdr_marked(m, t)) continue;
            hdr_mark(m, t); st[sp++] = v; cnt++;
        }
    }
    m->marked = cnt; m->marked_bytes = bytes;
}
/* node enqueuing, side bitmap; PF: prefetch the object when it is pushed */
ALWAYS_INLINE void mark_bm_body(mk_t *m, val root, int pf) {
    val *st = m->stack; size_t sp = 0;
    bm_test_set(m, ptr_of(root)); st[sp++] = root;
    size_t cnt = 1, bytes = 0;
    while (sp) {
        obj *o = ptr_of(st[--sp]);
        bytes += osize(o);
        if (!has_fields(o)) continue;
        val *f = FIELDS(o);
        for (uint32_t i = 0, n = o->len; i < n; i++) {
            val v = f[i];
            if (!is_ptr(v)) continue;
            if (bm_test_set(m, ptr_of(v))) continue;
            if (pf) __builtin_prefetch(ptr_of(v), 0, 3);
            st[sp++] = v; cnt++;
        }
    }
    m->marked = cnt; m->marked_bytes = bytes;
}
static NOINLINE void mark_bm(mk_t *m, val root) { mark_bm_body(m, root, 0); }
static NOINLINE void mark_bm_pf(mk_t *m, val root) { mark_bm_body(m, root, 1); }

#ifndef PF_FIFO
#define PF_FIFO 16
#endif
/* edge enqueuing through a prefetching FIFO; BM: the bitmap, else the header */
ALWAYS_INLINE void mark_edge_body(mk_t *m, val root, int bm) {
    val *st = m->stack; size_t sp = 0;
    val fifo[PF_FIFO]; unsigned head = 0, tail = 0;
    st[sp++] = root;
    size_t cnt = 0, bytes = 0;
    for (;;) {
        while (head - tail < PF_FIFO && sp) {
            val v = st[--sp];
            obj *t = ptr_of(v);
            if (bm) { size_t b = bm_index(m, t); __builtin_prefetch(&m->bits[b >> 6], 1, 3); __builtin_prefetch(t, 0, 3); }
            else __builtin_prefetch(t, 1, 3);
            fifo[head++ % PF_FIFO] = v;
        }
        if (head == tail) break;
        obj *o = ptr_of(fifo[tail++ % PF_FIFO]);
        if (bm) { if (bm_test_set(m, o)) continue; }
        else { if (hdr_marked(m, o)) continue; hdr_mark(m, o); }
        cnt++;
        bytes += osize(o);
        if (!has_fields(o)) continue;
        val *f = FIELDS(o);
        for (uint32_t i = 0, n = o->len; i < n; i++) if (is_ptr(f[i])) st[sp++] = f[i];
    }
    m->marked = cnt; m->marked_bytes = bytes;
}
static NOINLINE void mark_hdr_edge(mk_t *m, val root) { mark_edge_body(m, root, 0); }
static NOINLINE void mark_bm_edge(mk_t *m, val root) { mark_edge_body(m, root, 1); }
#endif
