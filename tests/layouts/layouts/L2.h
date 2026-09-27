/* L2.h -- L1 with 64-bit int/word semantics: immediate when the value fits
   63 bits, a K_BOX (BOX_INT / BOX_WORD) otherwise. add_ov/sub_ov/mul_ov
   take the tagged fast path when both operands are immediate and the 63-bit
   result does not overflow; otherwise they compute in 64 bits and box, and
   raise Overflow only at 64 bits. Every consumer tests for the box. */
#ifndef HARNESS_L2_H
#define HARNESS_L2_H
#define HARNESS_L2 1
#include "L1.h"

ALWAYS_INLINE val mk_int(int64_t i) {
    int64_t t;
    if (LIKELY(!__builtin_add_overflow(i, i, &t))) return (val)t | 1;
    return box_raw(BOX_INT, (uint64_t)i);
}
ALWAYS_INLINE int is_int(val v) { return (v & 1) || obj_kind((obj *)v) == K_BOX; }
ALWAYS_INLINE int64_t unbox_int(val v) { if (LIKELY(v & 1)) return (int64_t)v >> 1; return (int64_t)unbox_raw(v); }
ALWAYS_INLINE val mk_word(uint64_t w) { if (LIKELY(!(w >> 63))) return (w << 1) | 1; return box_raw(BOX_WORD, w); }
ALWAYS_INLINE uint64_t unbox_word(val v) { if (LIKELY(v & 1)) return v >> 1; return unbox_raw(v); }

ALWAYS_INLINE int add_ov(val a, val b, val *r) {
    int64_t x;
    if (LIKELY(a & b & 1) && LIKELY(!__builtin_add_overflow((int64_t)a, (int64_t)(b - 1), &x))) { *r = (val)x; return 0; }
    int64_t s;
    if (__builtin_add_overflow(unbox_int(a), unbox_int(b), &s)) return 1;
    *r = mk_int(s); return 0;
}
ALWAYS_INLINE int sub_ov(val a, val b, val *r) {
    int64_t x;
    if (LIKELY(a & b & 1) && LIKELY(!__builtin_sub_overflow((int64_t)a, (int64_t)(b - 1), &x))) { *r = (val)x; return 0; }
    int64_t s;
    if (__builtin_sub_overflow(unbox_int(a), unbox_int(b), &s)) return 1;
    *r = mk_int(s); return 0;
}
ALWAYS_INLINE int mul_ov(val a, val b, val *r) {
    int64_t x;
    if (LIKELY(a & b & 1) && LIKELY(!__builtin_mul_overflow((int64_t)a >> 1, (int64_t)(b - 1), &x))) { *r = (val)x | 1; return 0; }
    int64_t s;
    if (__builtin_mul_overflow(unbox_int(a), unbox_int(b), &s)) return 1;
    *r = mk_int(s); return 0;
}
#endif
