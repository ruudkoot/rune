/* L1.h -- an 8-byte word: low bit 1 = immediate (63-bit int, char, con0,
   unit = 1), low bit 0 = pointer. Reals boxed (K_BOX: header + 8 bytes)
   unless -DREALIMM encodes the value-encodable ones as Koka's box.h does
   (strategy A1: the 11-bit exponent squeezed into 10 bits). Word64 is a
   boxed type (a 63-bit immediate cannot hold it). Objects: objs8.h.
   -DPAIRS (L5): 2-field CON/TUPLE objects are headerless 16-byte pairs,
   kind and constructor tag in pointer bits 1-2 (010 tuple, 100 CON tag 0,
   110 CON tag 1; 000 = headered object); one shape, since every word is
   self-describing; forwarding by an in-band marker (Chez's forward_marker):
   an even non-canonical address that no L1 value can be.
   L2.h defines HARNESS_L2 and includes this file. */
#ifndef HARNESS_L1_H
#define HARNESS_L1_H
#include "../common.h"
#ifdef NAN51
#error "NAN51 is an L3 variant"
#endif

typedef uint64_t val;
typedef struct obj obj;
#ifdef PAIRS
#define PTR_MASK (~(uint64_t)7)
#else
#define PTR_MASK (~(uint64_t)0)
#endif

/* ---- immediates ---- */
ALWAYS_INLINE val mk_unit(void) { return 1; }
ALWAYS_INLINE val mk_char(int c) { return ((uint64_t)c << 1) | 1; }
ALWAYS_INLINE val mk_con0(int t) { return ((uint64_t)t << 1) | 1; }
ALWAYS_INLINE val mk_bool(int b) { return ((uint64_t)(b != 0) << 1) | 1; }
ALWAYS_INLINE int unbox_char(val v) { return (int)(v >> 1); }
ALWAYS_INLINE int con0_tag(val v) { return (int)(v >> 1); }
ALWAYS_INLINE int unbox_bool(val v) { return (int)(v >> 1); }
ALWAYS_INLINE int is_ptr(val v) { return !(v & 1); }
ALWAYS_INLINE obj *ptr_of(val v) { return (obj *)(v & PTR_MASK); }
ALWAYS_INLINE val ptr_val(obj *o) { return (val)o; }
#define NIL ((val)1)
#define SINK_VAL(v) SINK(v)
ALWAYS_INLINE int is_nil(val v) { return v == 1; }
ALWAYS_INLINE int val_eq_imm(val a, val b) { return a == b; }
static inline int lay_is_ptr(val v) { return !(v & 1); }

#ifndef HARNESS_L2
/* L1: 63-bit ints, immediate always (the kernels stay within 62 bits) */
ALWAYS_INLINE val mk_int(int64_t i) { return ((uint64_t)i << 1) | 1; }
ALWAYS_INLINE int is_int(val v) { return (int)(v & 1); }
ALWAYS_INLINE int64_t unbox_int(val v) { return (int64_t)v >> 1; }
ALWAYS_INLINE int add_ov(val a, val b, val *r) { int64_t x; if (__builtin_add_overflow((int64_t)a, (int64_t)(b - 1), &x)) return 1; *r = (val)x; return 0; }
ALWAYS_INLINE int sub_ov(val a, val b, val *r) { int64_t x; if (__builtin_sub_overflow((int64_t)a, (int64_t)(b - 1), &x)) return 1; *r = (val)x; return 0; }
ALWAYS_INLINE int mul_ov(val a, val b, val *r) { int64_t x; if (__builtin_mul_overflow((int64_t)a >> 1, (int64_t)(b - 1), &x)) return 1; *r = (val)x | 1; return 0; }
#endif

#define MONO_INT(x) mk_int(x)
#define MONO_REAL(x) mk_real(x)
#define MONO_INT_OF(v) unbox_int(v)
#define MONO_REAL_OF(v) unbox_real(v)
#define POLY_VAL_INT(x) mk_int(x)
#define POLY_VAL_REAL(x) mk_real(x)
#define POLY_INT_OF(v) unbox_int(v)
#define POLY_REAL_OF(v) unbox_real(v)
#define POLY_TO_MONO_INT(v) (v)
#define MONO_TO_POLY_INT(v) (v)
#define POLY_PTRBIT 1
#define POLY_ALLOCATES 0
#define REAL_ALLOCATES 1
#define WORD_ALLOCATES 1
#define WORD_PTRBIT 1
#define CON_INT_VAL(x) MONO_INT(x)
#define CON_INTBIT 0
#define ARR_REAL_VAL(d) mk_real(d)
#define ARR_REAL_OF(v) unbox_real(v)
#define ARR_REAL_PTRBIT 1
#define ARR_REAL_ALLOCATES 1

#ifdef PAIRS
#define NSHAPES 1
#define PAIR_FWD_MARK ((val)0xFFFFFFFFFFFFFFF8ull)
ALWAYS_INLINE int lay_shape_of_mask(uint32_t mask) { (void)mask; return 0; }
#if defined(PAIR_CODES) && PAIR_CODES == 2
/* Two of the three codes name a pair -- 010 a tuple or a constructor of
   tag 0, 100 a constructor of tag 1 -- and the third, 110, is kept for a
   lazy front end: "an object with a header, known to be evaluated"
   (docs/plans/heap-layout.md, *A lazy front end*). The strict kernels never
   set it; masking it off a pointer is all it costs them. */
ALWAYS_INLINE uint64_t lay_pair_bits(int kind, int contag, uint32_t mask) { (void)mask; return (kind == K_CON && contag) ? 4 : 2; }
#define PAIR_CONTAG(v) ((int)(((v) & 6) >> 1) - 1)
#define EVAL_CODE ((val)6)
#else
ALWAYS_INLINE uint64_t lay_pair_bits(int kind, int contag, uint32_t mask) { (void)mask; return kind == K_TUPLE ? 2 : (contag ? 6 : 4); }
#define PAIR_CONTAG(v) ((int)(((v) & 6) >> 1) - 2)
#endif
#define LAY_PAIR_SHAPE(v) 0
#elif defined(PAIR_CODES)
#error "PAIR_CODES is a variant of PAIRS"
#endif

#include "objs8.h"

static inline void lay_scan_obj(obj *o) {
    int k = obj_kind(o);
    if (k == K_STRING || k == K_BOX) return;
    if (k == K_ARRAY && obj_contag(o) != EK_VAL) return;
    scan_fields_all(o);
}
#ifdef PAIRS
static inline void lay_scan_pair(int shape, uint64_t *p) { (void)shape; gc_forward(&p[0]); gc_forward(&p[1]); }
#endif

#ifdef REALIMM
/* Koka box.h/box.c strategy A1: rotate the sign+exponent to the low 12
   bits, squeeze the exponent to 10 bits when it is in (0x200, 0x5FF), 0 or
   0x7FF; else a box. */
ALWAYS_INLINE uint64_t rotl64(uint64_t x, int n) { return (x << n) | (x >> (64 - n)); }
ALWAYS_INLINE uint64_t rotr64(uint64_t x, int n) { return (x >> n) | (x << (64 - n)); }
ALWAYS_INLINE val mk_real(double d) {
    uint64_t u; memcpy(&u, &d, 8);
    u = rotl64(u, 12);
    uint64_t exp = u & 0x7FF;
    u -= exp;
    if (exp == 0) { }
    else if (exp == 0x7FF) exp = 0x3FF;
    else if (exp > 0x200 && exp < 0x5FF) exp -= 0x200;
    else return box_raw(BOX_REAL, u | exp);   /* the bits, rotated; unbox rotates back */
    return (((u >> 1) | exp) << 1) | 1;
}
ALWAYS_INLINE double unbox_real(val v) {
    uint64_t u;
    if (v & 1) {
        u = v >> 1;
        uint64_t exp = u & 0x3FF;
        u -= exp;
        if (exp == 0) { }
        else if (exp == 0x3FF) exp = 0x7FF;
        else exp += 0x200;
        u = (u << 1) | exp;
    } else u = unbox_raw(v);
    u = rotr64(u, 12);
    double d; memcpy(&d, &u, 8); return d;
}
#else
ALWAYS_INLINE val mk_real(double d) { uint64_t u; memcpy(&u, &d, 8); return box_raw(BOX_REAL, u); }
ALWAYS_INLINE double unbox_real(val v) { uint64_t u = unbox_raw(v); double d; memcpy(&d, &u, 8); return d; }
#endif

#ifndef HARNESS_L2
/* Word64 is a boxed type in L1 */
ALWAYS_INLINE val mk_word(uint64_t w) { return box_raw(BOX_WORD, w); }
ALWAYS_INLINE uint64_t unbox_word(val v) { return unbox_raw(v); }
#endif

/* ---- structural equality ---- */
static int poly_eq(val a, val b) {
    if (a == b) return 1;
    if ((a | b) & 1) return 0;
#ifdef PAIRS
    if (lay_is_pair(a) || lay_is_pair(b)) {
        if ((a & 7) != (b & 7)) return 0;
        val *p = (val *)(a & ~(uint64_t)7), *q = (val *)(b & ~(uint64_t)7);
        return poly_eq(p[0], q[0]) && poly_eq(p[1], q[1]);
    }
#endif
    obj *x = ptr_of(a), *y = ptr_of(b);
    int k = obj_kind(x);
    if (k != obj_kind(y) || obj_contag(x) != obj_contag(y) || obj_len(x) != obj_len(y)) return 0;
    if (k == K_STRING) return memcmp(FIELDS_RAW(x), FIELDS_RAW(y), obj_len(x)) == 0;
    if (k == K_BOX) return memcmp(FIELDS_RAW(x), FIELDS_RAW(y), 8) == 0;
    if (k == K_REF || k == K_ARRAY) return 0;
    val *f = FIELDS(x), *g = FIELDS(y);
    for (uint32_t i = 0, n = obj_len(x); i < n; i++) if (!poly_eq(f[i], g[i])) return 0;
    return 1;
}
#endif
