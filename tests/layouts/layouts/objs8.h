/* objs8.h -- the object machinery of the 8-byte-word layouts (L1-L4): the
   header {kind, mask, contag, len} (-DHDR4: kind:4 | contag:8 | len:20),
   sizes, allocation, forwarding, fields, boxes and headerless pairs.
   Included by a layout after it defined: val, PTR_MASK, is_ptr, ptr_of,
   ptr_val, lay_is_ptr, and for -DPAIRS: NSHAPES, lay_shape_of_mask(mask),
   lay_pair_bits(kind, contag, mask), PAIR_CONTAG(v); optionally
   LAYOUT_TWO_STACKS (L4: root_push_m/root_pop_m are the layout's).
   After it the layout defines lay_scan_obj, lay_scan_pair and poly_eq. */
#ifndef HARNESS_OBJS8_H
#define HARNESS_OBJS8_H

#ifdef HDR4
struct obj { uint32_t h; };
#define HDR_SIZE 4
ALWAYS_INLINE int obj_kind(obj *o) { return o->h & 15; }
ALWAYS_INLINE int obj_contag(obj *o) { return (o->h >> 4) & 255; }
ALWAYS_INLINE uint32_t obj_len(obj *o) { return o->h >> 12; }
ALWAYS_INLINE uint32_t obj_mask(obj *o) { (void)o; return 0; }
ALWAYS_INLINE void hdr_init(obj *o, int kind, int contag, uint32_t len, uint32_t mask) {
    (void)mask; o->h = (uint32_t)kind | ((uint32_t)contag << 4) | (len << 12);
}
ALWAYS_INLINE void hdr_set_kind(obj *o, int kind) { o->h = (o->h & ~15u) | (uint32_t)kind; }
#else
struct obj { uint8_t kind; uint8_t mask; uint16_t contag; uint32_t len; };
#define HDR_SIZE 8
ALWAYS_INLINE int obj_kind(obj *o) { return o->kind; }
ALWAYS_INLINE int obj_contag(obj *o) { return o->contag; }
ALWAYS_INLINE uint32_t obj_len(obj *o) { return o->len; }
ALWAYS_INLINE uint32_t obj_mask(obj *o) { return o->mask; }
ALWAYS_INLINE void hdr_init(obj *o, int kind, int contag, uint32_t len, uint32_t mask) {
    o->kind = (uint8_t)kind; o->mask = (uint8_t)mask; o->contag = (uint16_t)contag; o->len = len;
}
ALWAYS_INLINE void hdr_set_kind(obj *o, int kind) { o->kind = (uint8_t)kind; }
#endif
#ifdef ALIGN16
#define OBJ_ALIGN 16
#else
#define OBJ_ALIGN 8
#endif
#define FIELDS(o) ((val *)((char *)(o) + HDR_SIZE))
#define FIELDS_RAW(o) ((void *)((char *)(o) + HDR_SIZE))

ALWAYS_INLINE size_t obj_payload_bytes(int kind, int contag, uint32_t n) {
    if (kind == K_STRING) return n;
    if (kind == K_BOX) return 8;
    if (kind == K_ARRAY && contag == EK_BYTE) return n;
    return (size_t)n * 8;
}
ALWAYS_INLINE size_t alloc_size(int kind, int contag, uint32_t n) {
    size_t p = obj_payload_bytes(kind, contag, n);
    if (p < 8) p = 8;
    return (HDR_SIZE + p + (OBJ_ALIGN - 1)) & ~(size_t)(OBJ_ALIGN - 1);
}
static inline size_t lay_obj_size(const obj *o) { obj *m = (obj *)o; return alloc_size(obj_kind(m), obj_contag(m), obj_len(m)); }
static inline int lay_is_forwarded(const obj *o) { return obj_kind((obj *)o) == K_FORWARD; }
static inline obj *lay_forward_of(const obj *o) { obj *n; memcpy(&n, FIELDS_RAW(o), 8); return n; }
static inline void lay_set_forward(obj *o, obj *n) { hdr_set_kind(o, K_FORWARD); memcpy(FIELDS_RAW(o), &n, 8); }
#ifdef EVAL_CODE
/* a pointer to an object with a header may carry the code "known to be
   evaluated", which the collector keeps */
static inline obj *lay_ptr_obj(val v) { return (obj *)(v & ~(val)6); }
static inline val lay_obj_retag(val old, obj *n) { return (val)n | (old & 6); }
#else
static inline obj *lay_ptr_obj(val v) { return (obj *)v; }
static inline val lay_obj_retag(val old, obj *n) { (void)old; return (val)n; }
#endif
static inline void lay_scan_obj(obj *o);
/* an indirection: what a thunk becomes once it has its value, which is its
   field 0 (a pointer field: the mask says so where a layout has one) */
ALWAYS_INLINE void obj_become_ind(obj *o) { hdr_init(o, K_IND, 0, obj_len(o), 1); }
static inline int lay_is_ind(const obj *o) { return obj_kind((obj *)o) == K_IND; }
static inline val lay_ind_value(const obj *o) { return FIELDS((obj *)o)[0]; }
#ifdef PAIRS
#ifdef EVAL_CODE
static inline int lay_is_pair(val v) { return (v & 6) != 0 && (v & 6) != EVAL_CODE; }
#else
static inline int lay_is_pair(val v) { return (v & 6) != 0; }
#endif
static inline uint64_t *lay_pair_addr(val v) { return (uint64_t *)(v & ~(uint64_t)7); }
static inline int lay_pair_shape(val v) { (void)v; return LAY_PAIR_SHAPE(v); }   /* the layout's: one shape in L1, three in L4 */
static inline val lay_pair_retag(val old, uint64_t *n) { return (val)n | (old & 7); }
static inline void lay_scan_pair(int shape, uint64_t *p);
#endif

#include "../gc_core.h"

#ifdef LAYOUT_TWO_STACKS
static inline val *root_push_m(val v, int isptr);
static inline void root_pop_m(int isptr);
#else
ALWAYS_INLINE val *root_push_m(val v, int isptr) { (void)isptr; return PROOT_PUSH(v); }
ALWAYS_INLINE void root_pop_m(int isptr) { (void)isptr; ROOT_POP(); }
#define RROOT_PUSH(v) PROOT_PUSH(v)
#define IROOT_PUSH(v) PROOT_PUSH(v)
#define RROOT_POP() ROOT_POP()
#define IROOT_POP() ROOT_POP()
#endif

ALWAYS_INLINE obj *alloc(int kind, int contag, uint32_t n, uint32_t ptrmask) {
    obj *o = heap_alloc_obj(alloc_size(kind, contag, n));
    hdr_init(o, kind, contag, n, ptrmask);
    return o;
}
ALWAYS_INLINE obj *alloc_bytes(uint32_t len) { return alloc(K_STRING, 0, len, 0); }
ALWAYS_INLINE val field_get(obj *o, uint32_t i) { return FIELDS(o)[i]; }
#ifdef BARRIER_CARD
extern uint8_t card_table[];
#endif
ALWAYS_INLINE void field_set(obj *o, uint32_t i, val v) {
    FIELDS(o)[i] = v;
#ifdef BARRIER_CARD
    card_table[((uintptr_t)o >> 9) & ((1u << 20) - 1)] = 1;
#endif
}
/* every field forwarded (tagged layouts: gc_forward tests each) */
ALWAYS_INLINE void scan_fields_all(obj *o) {
    val *f = FIELDS(o);
    for (uint32_t i = 0, n = obj_len(o); i < n; i++) gc_forward(&f[i]);
}

/* a box: one raw 8-byte payload, contag says what (never scanned) */
enum { BOX_REAL = 1, BOX_WORD = 2, BOX_INT = 3 };
ALWAYS_INLINE val box_raw(int what, uint64_t bits) {
    obj *o = alloc(K_BOX, what, 1, 0);
    memcpy(FIELDS_RAW(o), &bits, 8);
    return (val)o;
}
ALWAYS_INLINE uint64_t unbox_raw(val v) { uint64_t b; memcpy(&b, FIELDS_RAW(ptr_of(v)), 8); return b; }

/* ---- pairs ---- */
ALWAYS_INLINE val mk_pair(int kind, int contag, val a, val b, uint32_t mask) {
#ifdef PAIRS
    int s = lay_shape_of_mask(mask);
    uint64_t tag = lay_pair_bits(kind, contag, mask);
    if (UNLIKELY(!pair_fits(s))) {
        val *_a = root_push_m(a, mask & 1), *_b = root_push_m(b, (mask >> 1) & 1);
        pair_page_slow(s); b = *_b; a = *_a; root_pop_m((mask >> 1) & 1); root_pop_m(mask & 1);
    }
    uint64_t *p = pair_bump(s);
    p[0] = a; p[1] = b;
    return (val)p | tag;
#else
    size_t sz = alloc_size(kind, contag, 2);
    if (UNLIKELY(!heap_fits(sz))) {
        val *_a = root_push_m(a, mask & 1), *_b = root_push_m(b, (mask >> 1) & 1);
        gc_collect(sz); b = *_b; a = *_a; root_pop_m((mask >> 1) & 1); root_pop_m(mask & 1);
    }
    obj *o = alloc(kind, contag, 2, mask);
    FIELDS(o)[0] = a; FIELDS(o)[1] = b;
    return (val)o;
#endif
}
ALWAYS_INLINE val pair_get(val p, int i) {
#ifdef PAIRS
    return ((val *)(p & ~(uint64_t)7))[i];
#else
    return FIELDS((obj *)p)[i];
#endif
}
ALWAYS_INLINE val cons(val hd, val tl) { return mk_pair(K_CON, 1, hd, tl, POLY_PTRBIT | 2); }
ALWAYS_INLINE val cons_p(val hd, val tl) { return mk_pair(K_CON, 1, hd, tl, 3); }
ALWAYS_INLINE val head(val l) { return pair_get(l, 0); }
ALWAYS_INLINE val tail(val l) { return pair_get(l, 1); }
ALWAYS_INLINE int con_tag(val v) {
#ifdef PAIRS
    if (lay_is_pair(v)) return PAIR_CONTAG(v);
#endif
    return obj_contag(ptr_of(v));
}
#endif
