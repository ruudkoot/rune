/* L0.h -- today's layout: a 16-byte tagged value built exactly as vm.h's
   mk_* build it (a header word, then the payload), an 8-byte object header
   {kind, pad, contag, len}, payload rounded to 16 and at least 16, objects
   8-byte aligned (runtime/heap.c). No variants. */
#ifndef HARNESS_L0_H
#define HARNESS_L0_H
#include "../common.h"
#if defined(PAIRS) || defined(HDR4) || defined(ALIGN16) || defined(FLATREAL) || defined(COMPACTBYTES) || defined(REALIMM) || defined(NAN51)
#error "L0 is fixed: no layout variants"
#endif

enum { T_UNIT = 0, T_INT, T_WORD, T_REAL, T_CHAR, T_CON0, T_PTR };
typedef struct obj obj;
typedef struct val {
    union {
        struct { uint8_t tag; uint8_t pad[7]; };
        uint64_t hdr;
    };
    union { int64_t i; uint64_t w; double d; obj *p; } u;
} val;
struct obj { uint8_t kind; uint8_t pad; uint16_t contag; uint32_t len; };
#define HDR_SIZE 8
#define FIELDS(o) ((val *)((char *)(o) + HDR_SIZE))
#define FIELDS_RAW(o) ((void *)((char *)(o) + HDR_SIZE))
#define VALUE_HDR(t) ((uint64_t)(t))
#define MKV(t, f, x) val v; v.hdr = VALUE_HDR(t); v.u.f = (x); return v

ALWAYS_INLINE val mk_unit(void) { MKV(T_UNIT, i, 0); }
ALWAYS_INLINE val mk_int(int64_t i) { MKV(T_INT, i, i); }
ALWAYS_INLINE val mk_word(uint64_t w) { MKV(T_WORD, w, w); }
ALWAYS_INLINE val mk_real(double d) { MKV(T_REAL, d, d); }
ALWAYS_INLINE val mk_char(int c) { MKV(T_CHAR, i, c); }
ALWAYS_INLINE val mk_con0(int t) { MKV(T_CON0, i, t); }
ALWAYS_INLINE val ptr_val(obj *p) { MKV(T_PTR, p, p); }
ALWAYS_INLINE val mk_bool(int b) { return mk_con0(b ? 1 : 0); }
#undef MKV
ALWAYS_INLINE int is_int(val v) { return v.tag == T_INT; }
ALWAYS_INLINE int64_t unbox_int(val v) { return v.u.i; }
ALWAYS_INLINE uint64_t unbox_word(val v) { return v.u.w; }
ALWAYS_INLINE double unbox_real(val v) { return v.u.d; }
ALWAYS_INLINE int unbox_char(val v) { return (int)v.u.i; }
ALWAYS_INLINE int con0_tag(val v) { return (int)v.u.i; }
ALWAYS_INLINE int unbox_bool(val v) { return (int)v.u.i; }
ALWAYS_INLINE int is_ptr(val v) { return v.tag == T_PTR; }
ALWAYS_INLINE obj *ptr_of(val v) { return v.u.p; }
#define NIL mk_con0(0)
#define SINK_VAL(v) __asm__ __volatile__("" :: "r"((v).hdr), "r"((v).u.w) : "memory")
ALWAYS_INLINE int is_nil(val v) { return v.tag == T_CON0; }
ALWAYS_INLINE int val_eq_imm(val a, val b) { return a.hdr == b.hdr && a.u.w == b.u.w; }

#define MONO_INT(x) mk_int(x)
#define MONO_REAL(x) mk_real(x)
#define MONO_INT_OF(v) unbox_int(v)
#define MONO_REAL_OF(v) unbox_real(v)
#define POLY_VAL_INT(x) mk_int(x)
#define POLY_VAL_REAL(x) mk_real(x)
#define POLY_INT_OF(v) unbox_int(v)
#define POLY_REAL_OF(v) unbox_real(v)
#define POLY_PTRBIT 1
#define POLY_ALLOCATES 0
#define REAL_ALLOCATES 0
#define WORD_ALLOCATES 0
#define ARR_REAL_VAL(d) mk_real(d)
#define ARR_REAL_OF(v) unbox_real(v)
#define ARR_REAL_PTRBIT 0
#define ARR_REAL_ALLOCATES 0
#define POLY_TO_MONO_INT(v) (v)
#define MONO_TO_POLY_INT(v) (v)
#define WORD_PTRBIT 0
#define CON_INT_VAL(x) MONO_INT(x)
#define CON_INTBIT 0

/* MONO arithmetic: the compiler knows both are ints, no tag test */
ALWAYS_INLINE int add_ov(val a, val b, val *r) { int64_t x; if (__builtin_add_overflow(a.u.i, b.u.i, &x)) return 1; *r = mk_int(x); return 0; }
ALWAYS_INLINE int sub_ov(val a, val b, val *r) { int64_t x; if (__builtin_sub_overflow(a.u.i, b.u.i, &x)) return 1; *r = mk_int(x); return 0; }
ALWAYS_INLINE int mul_ov(val a, val b, val *r) { int64_t x; if (__builtin_mul_overflow(a.u.i, b.u.i, &x)) return 1; *r = mk_int(x); return 0; }

/* ---- objects ---- */
ALWAYS_INLINE size_t l0_payload(size_t bytes) { size_t s = (bytes + 15) & ~(size_t)15; return s < 16 ? 16 : s; }
ALWAYS_INLINE size_t alloc_size(int kind, int contag, uint32_t n) {
    (void)contag;
    return HDR_SIZE + l0_payload(kind == K_STRING ? (size_t)n : (size_t)n * 16);
}
static inline size_t lay_obj_size(const obj *o) {
    return HDR_SIZE + l0_payload(o->kind == K_STRING ? (size_t)o->len : (size_t)o->len * 16);
}
static inline int lay_is_forwarded(const obj *o) { return o->kind == K_FORWARD; }
static inline obj *lay_forward_of(const obj *o) { return *(obj **)FIELDS_RAW(o); }
static inline void lay_set_forward(obj *o, obj *n) { o->kind = K_FORWARD; *(obj **)FIELDS_RAW(o) = n; }
static inline int lay_is_ptr(val v) { return v.tag == T_PTR; }
static inline obj *lay_ptr_obj(val v) { return v.u.p; }
static inline val lay_obj_retag(val old, obj *n) { old.u.p = n; return old; }
static inline void lay_scan_obj(obj *o);
/* an indirection: what a thunk becomes once it has its value, its field 0 */
ALWAYS_INLINE void obj_become_ind(obj *o) { o->kind = K_IND; o->contag = 0; }
static inline int lay_is_ind(const obj *o) { return o->kind == K_IND; }
static inline val lay_ind_value(const obj *o) { return FIELDS((obj *)o)[0]; }

#include "../gc_core.h"

static inline void lay_scan_obj(obj *o) {
    if (o->kind == K_STRING || o->kind == K_BOX) return;
    val *f = FIELDS(o);
    for (uint32_t i = 0, n = o->len; i < n; i++) gc_forward(&f[i]);
}
ALWAYS_INLINE val *root_push_m(val v, int isptr) { (void)isptr; return PROOT_PUSH(v); }
ALWAYS_INLINE void root_pop_m(int isptr) { (void)isptr; ROOT_POP(); }
#define RROOT_PUSH(v) PROOT_PUSH(v)
#define IROOT_PUSH(v) PROOT_PUSH(v)
#define RROOT_POP() ROOT_POP()
#define IROOT_POP() ROOT_POP()

ALWAYS_INLINE obj *alloc(int kind, int contag, uint32_t n, uint32_t ptrmask) {
    (void)ptrmask;
    obj *o = heap_alloc_obj(alloc_size(kind, contag, n));
    o->kind = (uint8_t)kind; o->pad = 0; o->contag = (uint16_t)contag; o->len = n;
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
ALWAYS_INLINE uint32_t obj_len(obj *o) { return o->len; }
ALWAYS_INLINE int obj_kind(obj *o) { return o->kind; }
ALWAYS_INLINE int obj_contag(obj *o) { return o->contag; }
ALWAYS_INLINE int con_tag(val v) { return ptr_of(v)->contag; }

/* ---- pairs (headered in L0) ---- */
ALWAYS_INLINE val mk_pair(int kind, int contag, val a, val b, uint32_t mask) {
    size_t sz = alloc_size(kind, contag, 2);
    if (UNLIKELY(!heap_fits(sz))) {
        val *_a = root_push_m(a, mask & 1), *_b = root_push_m(b, (mask >> 1) & 1);
        gc_collect(sz); b = *_b; a = *_a; root_pop_m((mask >> 1) & 1); root_pop_m(mask & 1);
    }
    obj *o = alloc(kind, contag, 2, mask);
    FIELDS(o)[0] = a; FIELDS(o)[1] = b;
    return ptr_val(o);
}
ALWAYS_INLINE val pair_get(val p, int i) { return FIELDS(ptr_of(p))[i]; }
ALWAYS_INLINE val cons(val hd, val tl) { return mk_pair(K_CON, 1, hd, tl, POLY_PTRBIT | 2); }
ALWAYS_INLINE val cons_p(val hd, val tl) { return mk_pair(K_CON, 1, hd, tl, 3); }
ALWAYS_INLINE val head(val l) { return pair_get(l, 0); }
ALWAYS_INLINE val tail(val l) { return pair_get(l, 1); }

/* ---- structural equality ---- */
static int poly_eq(val a, val b) {
    if (a.tag != b.tag) return 0;
    if (a.tag != T_PTR) return a.u.w == b.u.w;
    obj *x = a.u.p, *y = b.u.p;
    if (x == y) return 1;
    if (x->kind != y->kind || x->contag != y->contag || x->len != y->len) return 0;
    if (x->kind == K_STRING) return memcmp(FIELDS_RAW(x), FIELDS_RAW(y), x->len) == 0;
    if (x->kind == K_REF || x->kind == K_ARRAY) return 0;
    val *f = FIELDS(x), *g = FIELDS(y);
    for (uint32_t i = 0; i < x->len; i++) if (!poly_eq(f[i], g[i])) return 0;
    return 1;
}
#endif
