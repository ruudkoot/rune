/* L3.h -- NaN-boxing, JavaScriptCore's JSValue64 scheme (JSCJSValue.h:
   "USE(JSVALUE64)"): a double is its bits plus 2^49, so an encoded double
   never begins with 0x0000 or 0xFFFE..; a pointer has its top 16 bits 0;
   an int has the top 16 bits 0xFFFE and a 48-bit payload (-DNAN51: the top
   13 bits set and a 51-bit payload, the space above the highest encoded
   double 0xFFF2..). Other immediates (unit, con0, char, bool) sit under
   0x0001. NaN results are canonicalised to the positive quiet NaN, as JSC
   does, so no encoded double reaches the int range. Ints and words that do
   not fit the payload are K_BOXes. Objects: objs8.h. No -DPAIRS here (not
   asked for). */
#ifndef HARNESS_L3_H
#define HARNESS_L3_H
#include "../common.h"
#ifdef PAIRS
#error "PAIRS is an L1/L4 variant"
#endif
#ifdef REALIMM
#error "REALIMM is an L1/L2 variant"
#endif

typedef uint64_t val;
typedef struct obj obj;
#define PTR_MASK (~(uint64_t)0)
#define L3_DOUBLE_OFFSET (1ull << 49)
#define L3_MISC_TAG (1ull << 48)
#ifdef NAN51
#define L3_INT_TAG (0xFFF8ull << 48)
#define L3_INT_BITS 51
ALWAYS_INLINE int l3_is_int(val v) { return (v >> 51) == 0x1FFF; }
#else
#define L3_INT_TAG (0xFFFEull << 48)
#define L3_INT_BITS 48
ALWAYS_INLINE int l3_is_int(val v) { return (v >> 48) == 0xFFFE; }
#endif
#define L3_PAYLOAD_MASK ((1ull << L3_INT_BITS) - 1)

ALWAYS_INLINE val mk_unit(void) { return L3_MISC_TAG; }
ALWAYS_INLINE val mk_char(int c) { return L3_MISC_TAG | (uint64_t)c; }
ALWAYS_INLINE val mk_con0(int t) { return L3_MISC_TAG | (uint64_t)t; }
ALWAYS_INLINE val mk_bool(int b) { return L3_MISC_TAG | (uint64_t)(b != 0); }
ALWAYS_INLINE int unbox_char(val v) { return (int)(v & 0xFFFFFFFF); }
ALWAYS_INLINE int con0_tag(val v) { return (int)(v & 0xFFFFFFFF); }
ALWAYS_INLINE int unbox_bool(val v) { return (int)(v & 1); }
ALWAYS_INLINE int is_ptr(val v) { return (v >> 48) == 0; }
ALWAYS_INLINE obj *ptr_of(val v) { return (obj *)v; }
ALWAYS_INLINE val ptr_val(obj *o) { return (val)o; }
#define NIL (L3_MISC_TAG)
#define SINK_VAL(v) SINK(v)
ALWAYS_INLINE int is_nil(val v) { return v == L3_MISC_TAG; }
ALWAYS_INLINE int val_eq_imm(val a, val b) { return a == b; }
static inline int lay_is_ptr(val v) { return (v >> 48) == 0; }

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
#define REAL_ALLOCATES 0
#define WORD_ALLOCATES 1
#define WORD_PTRBIT 1
#define CON_INT_VAL(x) MONO_INT(x)
#define CON_INTBIT 0
#define ARR_REAL_VAL(d) mk_real(d)
#define ARR_REAL_OF(v) unbox_real(v)
#define ARR_REAL_PTRBIT 0
#define ARR_REAL_ALLOCATES 0

#include "objs8.h"

static inline void lay_scan_obj(obj *o) {
    int k = obj_kind(o);
    if (k == K_STRING || k == K_BOX) return;
    if (k == K_ARRAY && obj_contag(o) != EK_VAL) return;
    scan_fields_all(o);
}

/* ---- reals: immediate ---- */
ALWAYS_INLINE val mk_real(double d) {
    uint64_t u; memcpy(&u, &d, 8);
    if (UNLIKELY(d != d)) u = 0x7FF8000000000000ull;
    return u + L3_DOUBLE_OFFSET;
}
ALWAYS_INLINE double unbox_real(val v) { uint64_t u = v - L3_DOUBLE_OFFSET; double d; memcpy(&d, &u, 8); return d; }

/* ---- ints: 48 (51) bits immediate, else a box ---- */
ALWAYS_INLINE int l3_fits(int64_t i) { return ((i << (64 - L3_INT_BITS)) >> (64 - L3_INT_BITS)) == i; }
ALWAYS_INLINE val mk_int(int64_t i) {
    if (LIKELY(l3_fits(i))) return L3_INT_TAG | ((uint64_t)i & L3_PAYLOAD_MASK);
    return box_raw(BOX_INT, (uint64_t)i);
}
ALWAYS_INLINE int64_t unbox_int(val v) {
    if (LIKELY(l3_is_int(v))) return ((int64_t)(v << (64 - L3_INT_BITS))) >> (64 - L3_INT_BITS);
    return (int64_t)unbox_raw(v);
}
ALWAYS_INLINE int is_int(val v) { return l3_is_int(v) || (is_ptr(v) && obj_kind(ptr_of(v)) == K_BOX); }
ALWAYS_INLINE val mk_word(uint64_t w) {
    if (LIKELY(!(w >> L3_INT_BITS))) return L3_INT_TAG | w;
    return box_raw(BOX_WORD, w);
}
ALWAYS_INLINE uint64_t unbox_word(val v) {
    if (LIKELY(l3_is_int(v))) return v & L3_PAYLOAD_MASK;
    return unbox_raw(v);
}
/* both immediate: decode, add (no 64-bit overflow from 48/51-bit
   operands), re-encode or box; a box operand: the 64-bit path */
ALWAYS_INLINE int add_ov(val a, val b, val *r) {
    int64_t s;
    if (LIKELY(l3_is_int(a) && l3_is_int(b))) { s = unbox_int(a) + unbox_int(b); *r = mk_int(s); return 0; }
    if (__builtin_add_overflow(unbox_int(a), unbox_int(b), &s)) return 1;
    *r = mk_int(s); return 0;
}
ALWAYS_INLINE int sub_ov(val a, val b, val *r) {
    int64_t s;
    if (LIKELY(l3_is_int(a) && l3_is_int(b))) { s = unbox_int(a) - unbox_int(b); *r = mk_int(s); return 0; }
    if (__builtin_sub_overflow(unbox_int(a), unbox_int(b), &s)) return 1;
    *r = mk_int(s); return 0;
}
ALWAYS_INLINE int mul_ov(val a, val b, val *r) {
    int64_t s;
    if (__builtin_mul_overflow(unbox_int(a), unbox_int(b), &s)) return 1;
    *r = mk_int(s); return 0;
}

/* ---- structural equality ---- */
static int poly_eq(val a, val b) {
    if (a == b) return 1;
    if (!is_ptr(a) || !is_ptr(b)) return 0;
    obj *x = (obj *)a, *y = (obj *)b;
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
