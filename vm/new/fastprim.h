/* The common case of the primitives runeopt does inline (docs/native.md,
   Primitives done inline; runeopt --inlined lists them), done in vm/new's
   loop from the registers, with nothing pushed: PRIM asks prim_fast first
   (src/isa/regs.sml). It gives the result vm/prims.c would give, or 0 to
   say the primitive is to give it -- an overflow, a divisor of zero or of
   ~1, an index out of bounds, a real or a pointer for `=`, an argument of
   the wrong kind, which the primitive raises or reports -- and never a
   different result: tests/opt/prims.sml runs every one on its edge cases on
   both VMs (scripts/check-new.sh), and a PRIM counts one either way. A
   primitive that stores into the heap (ref_set, array_update) stores
   through HEAP_STORE, where a collector's write barrier goes. */
#ifndef RUNE_FASTPRIM_H
#define RUNE_FASTPRIM_H

#include "vm.h"

#define HEAP_STORE(obj, i, v) (OBJ_FIELDS(obj)[i] = (v))

/* LESS, EQUAL or GREATER, the nullary constructors 0, 1 and 2 */
static inline Value fast_order(int lt, int gt) { return mk_con0(1 + gt - lt); }

static inline int fast_add(int64_t a, int64_t b, int64_t *r) {
#if defined(__GNUC__)
    return !__builtin_add_overflow(a, b, r);
#else
    if ((b > 0 && a > INT64_MAX - b) || (b < 0 && a < INT64_MIN - b)) return 0;
    *r = a + b; return 1;
#endif
}
static inline int fast_sub(int64_t a, int64_t b, int64_t *r) {
#if defined(__GNUC__)
    return !__builtin_sub_overflow(a, b, r);
#else
    if ((b < 0 && a > INT64_MAX + b) || (b > 0 && a < INT64_MIN + b)) return 0;
    *r = a - b; return 1;
#endif
}
static inline int fast_mul(int64_t a, int64_t b, int64_t *r) {
#if defined(__GNUC__)
    return !__builtin_mul_overflow(a, b, r);
#else
    if (a == 0 || b == 0) { *r = 0; return 1; }
    if ((a == -1 && b == INT64_MIN) || (b == -1 && a == INT64_MIN)) return 0;
    int64_t p = a * b;
    if (p / b != a) return 0;
    *r = p; return 1;
#endif
}

/* prim of the n registers of L, into *out: 1 when done, 0 for the
   primitive to do. The arguments are read where they are and every one is
   read before *out is written, since *out may be one of them. In the loop,
   inlined: a call for each PRIM, with the switch's table behind it, cost
   as much as the work. */
#if defined(__GNUC__)
__attribute__((always_inline))
#endif
static inline int prim_fast(int prim, uint32_t n, const Value *base, const uint8_t *L, Value *out) {
    const Value *x, *y, *z;
    Value r;
    if (n == 0 || n > 3) return 0;
    x = &base[read_i32(L)];
    y = n > 1 ? &base[read_i32(L + 4)] : x;
    z = n > 2 ? &base[read_i32(L + 8)] : x;
#define INT2 if (x->tag != T_INT || y->tag != T_INT) return 0
#define WORD2 if (x->tag != T_WORD || y->tag != T_WORD) return 0
#define REAL2 if (x->tag != T_REAL || y->tag != T_REAL) return 0
#define CHAR2 if (x->tag != T_CHAR || y->tag != T_CHAR) return 0
#define OBJ(v, k) if ((v)->tag != T_PTR || (v)->u.p->kind != (k)) return 0
    switch (prim) {
    /* `=` on two values that are neither pointers nor reals: tags and bits */
    case PRIM_poly_eq:
        if (x->tag == T_PTR || y->tag == T_PTR || x->tag == T_REAL || y->tag == T_REAL) return 0;
        r = mk_bool(x->tag == y->tag && x->u.i == y->u.i); break;
    case PRIM_imm_eq:
        if (x->tag == T_PTR || y->tag == T_PTR) return 0;
        r = mk_bool(x->tag == y->tag && x->u.i == y->u.i); break;

    case PRIM_int_add: { INT2; int64_t v; if (!fast_add(x->u.i, y->u.i, &v)) return 0; r = mk_int(v); break; }
    case PRIM_int_sub: { INT2; int64_t v; if (!fast_sub(x->u.i, y->u.i, &v)) return 0; r = mk_int(v); break; }
    case PRIM_int_mul: { INT2; int64_t v; if (!fast_mul(x->u.i, y->u.i, &v)) return 0; r = mk_int(v); break; }
    /* a divisor of 0 or ~1 (where the quotient may overflow) is the primitive's */
    case PRIM_int_div: {
        INT2; if (y->u.i == 0 || y->u.i == -1) return 0;
        int64_t q = x->u.i / y->u.i;
        if ((x->u.i % y->u.i != 0) && ((x->u.i < 0) != (y->u.i < 0))) q--;
        r = mk_int(q); break;
    }
    case PRIM_int_mod: {
        INT2; if (y->u.i == 0 || y->u.i == -1) return 0;
        int64_t m = x->u.i % y->u.i;
        if (m != 0 && ((m < 0) != (y->u.i < 0))) m += y->u.i;
        r = mk_int(m); break;
    }
    case PRIM_int_quot: INT2; if (y->u.i == 0 || y->u.i == -1) return 0; r = mk_int(x->u.i / y->u.i); break;
    case PRIM_int_rem: INT2; if (y->u.i == 0 || y->u.i == -1) return 0; r = mk_int(x->u.i % y->u.i); break;
    case PRIM_int_neg: if (x->tag != T_INT || x->u.i == INT64_MIN) return 0; r = mk_int(-x->u.i); break;
    case PRIM_int_lt: INT2; r = mk_bool(x->u.i < y->u.i); break;
    case PRIM_int_le: INT2; r = mk_bool(x->u.i <= y->u.i); break;
    case PRIM_int_gt: INT2; r = mk_bool(x->u.i > y->u.i); break;
    case PRIM_int_ge: INT2; r = mk_bool(x->u.i >= y->u.i); break;
    case PRIM_int_order: INT2; r = fast_order(x->u.i < y->u.i, x->u.i > y->u.i); break;
    case PRIM_int_to_char: if (x->tag != T_INT || x->u.i < 0 || x->u.i > 255) return 0; r = mk_char(x->u.i); break;

    case PRIM_word_add: WORD2; r = mk_word(x->u.w + y->u.w); break;
    case PRIM_word_sub: WORD2; r = mk_word(x->u.w - y->u.w); break;
    case PRIM_word_mul: WORD2; r = mk_word(x->u.w * y->u.w); break;
    case PRIM_word_div: WORD2; if (y->u.w == 0) return 0; r = mk_word(x->u.w / y->u.w); break;
    case PRIM_word_mod: WORD2; if (y->u.w == 0) return 0; r = mk_word(x->u.w % y->u.w); break;
    case PRIM_word_lt: WORD2; r = mk_bool(x->u.w < y->u.w); break;
    case PRIM_word_le: WORD2; r = mk_bool(x->u.w <= y->u.w); break;
    case PRIM_word_gt: WORD2; r = mk_bool(x->u.w > y->u.w); break;
    case PRIM_word_ge: WORD2; r = mk_bool(x->u.w >= y->u.w); break;
    case PRIM_word_order: WORD2; r = fast_order(x->u.w < y->u.w, x->u.w > y->u.w); break;
    case PRIM_word_andb: WORD2; r = mk_word(x->u.w & y->u.w); break;
    case PRIM_word_orb: WORD2; r = mk_word(x->u.w | y->u.w); break;
    case PRIM_word_xorb: WORD2; r = mk_word(x->u.w ^ y->u.w); break;
    case PRIM_word_notb: if (x->tag != T_WORD) return 0; r = mk_word(~x->u.w); break;
    case PRIM_word_lsl: WORD2; r = mk_word(y->u.w >= 64 ? 0 : x->u.w << y->u.w); break;
    case PRIM_word_lsr: WORD2; r = mk_word(y->u.w >= 64 ? 0 : x->u.w >> y->u.w); break;
    case PRIM_word_to_int: if (x->tag != T_WORD || x->u.w > (uint64_t)INT64_MAX) return 0; r = mk_int((int64_t)x->u.w); break;
    case PRIM_word_to_int_x: if (x->tag != T_WORD) return 0; r = mk_int((int64_t)x->u.w); break;
    case PRIM_word_from_int: if (x->tag != T_INT) return 0; r = mk_word((uint64_t)x->u.i); break;

    case PRIM_real_add: REAL2; r = mk_real(x->u.d + y->u.d); break;
    case PRIM_real_sub: REAL2; r = mk_real(x->u.d - y->u.d); break;
    case PRIM_real_mul: REAL2; r = mk_real(x->u.d * y->u.d); break;
    case PRIM_real_div: REAL2; r = mk_real(x->u.d / y->u.d); break;
    case PRIM_real_neg: if (x->tag != T_REAL) return 0; r = mk_real(-x->u.d); break;
    case PRIM_real_lt: REAL2; r = mk_bool(x->u.d < y->u.d); break;
    case PRIM_real_le: REAL2; r = mk_bool(x->u.d <= y->u.d); break;
    case PRIM_real_gt: REAL2; r = mk_bool(x->u.d > y->u.d); break;
    case PRIM_real_ge: REAL2; r = mk_bool(x->u.d >= y->u.d); break;
    case PRIM_real_eq: REAL2; r = mk_bool(x->u.d == y->u.d); break;

    case PRIM_char_ord: if (x->tag != T_CHAR) return 0; r = mk_int(x->u.i); break;
    case PRIM_char_lt: CHAR2; r = mk_bool(x->u.i < y->u.i); break;
    case PRIM_char_le: CHAR2; r = mk_bool(x->u.i <= y->u.i); break;
    case PRIM_char_gt: CHAR2; r = mk_bool(x->u.i > y->u.i); break;
    case PRIM_char_ge: CHAR2; r = mk_bool(x->u.i >= y->u.i); break;
    case PRIM_char_order: CHAR2; r = fast_order(x->u.i < y->u.i, x->u.i > y->u.i); break;

    case PRIM_string_size: OBJ(x, K_STRING); r = mk_int(x->u.p->len); break;
    case PRIM_string_sub:
        OBJ(x, K_STRING); if (y->tag != T_INT || y->u.i < 0 || (uint64_t)y->u.i >= x->u.p->len) return 0;
        r = mk_char((unsigned char)OBJ_BYTES(x->u.p)[y->u.i]); break;
    case PRIM_ref_get: OBJ(x, K_REF); r = OBJ_FIELDS(x->u.p)[0]; break;
    case PRIM_ref_set: OBJ(x, K_REF); HEAP_STORE(x->u.p, 0, *y); r = mk_unit(); break;
    case PRIM_array_length: OBJ(x, K_ARRAY); r = mk_int(x->u.p->len); break;
    case PRIM_array_sub:
        OBJ(x, K_ARRAY); if (y->tag != T_INT || y->u.i < 0 || (uint64_t)y->u.i >= x->u.p->len) return 0;
        r = OBJ_FIELDS(x->u.p)[y->u.i]; break;
    case PRIM_array_update:
        OBJ(x, K_ARRAY); if (y->tag != T_INT || y->u.i < 0 || (uint64_t)y->u.i >= x->u.p->len) return 0;
        HEAP_STORE(x->u.p, y->u.i, *z); r = mk_unit(); break;
    case PRIM_vector_length: OBJ(x, K_TUPLE); r = mk_int(x->u.p->len); break;
    case PRIM_vector_sub:
        OBJ(x, K_TUPLE); if (y->tag != T_INT || y->u.i < 0 || (uint64_t)y->u.i >= x->u.p->len) return 0;
        r = OBJ_FIELDS(x->u.p)[y->u.i]; break;
    default:
        return 0;
    }
#undef INT2
#undef WORD2
#undef REAL2
#undef CHAR2
#undef OBJ
    *out = r;
    return 1;
}

#endif
