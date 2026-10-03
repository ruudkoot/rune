/* The common case of the primitives runeopt does inline (docs/native.md,
   Primitives done inline; runeopt --inlined lists them), done in runtime/register's
   loop from the registers, with nothing pushed: PRIM asks prim_fast first
   (src/isa/regs.sml). It gives the result runtime/prims.c would give, or 0 to
   say the primitive is to give it -- an overflow, a divisor of zero or of
   ~1, an index out of bounds, a real or a pointer for `=`, an argument of
   the wrong kind, which the primitive raises or reports -- and never a
   different result: tests/opt/prims.sml runs every one on its edge cases on
   both VMs (scripts/check-register.sh), and a PRIM counts one either way. A
   primitive that stores into the heap (ref_set, array_update) stores
   through HEAP_STORE, where a collector's write barrier goes. */
#ifndef RUNE_FASTPRIM_H
#define RUNE_FASTPRIM_H

#include "vm.h"
#include <math.h>

#ifdef RUNE_CENSUS
/* the value stored is always the last argument, register L[n-1] */
#define HEAP_STORE(obj, i, v) (census_store_fast((obj), (uint32_t)(i), (v), read_i32(L + 4 * (size_t)(n - 1))), obj_set_field((obj), (uint32_t)(i), (v)))
void census_store_fast(Obj *o, uint32_t i, Value v, int32_t reg);
#else
#define HEAP_STORE(obj, i, v) obj_set_field((obj), (uint32_t)(i), (v))
#endif

/* LESS, EQUAL or GREATER, the nullary constructors 0, 1 and 2 */
static inline Value fast_order(int lt, int gt) { return mk_con0(1 + gt - lt); }
/* the word (heap-layout M4): a fast path never allocates, so a result the
   word cannot hold -- an int beyond 63 bits, a word with its top bit set
   (a box under RUNE_INT64), a real outside the encoding -- answers 0 and the
   primitive does it; without RUNE_INT64 a word wraps at 63 bits */
#define FAST_INT(v) do { if (!int_fits(v)) return 0; r = mk_int(v); } while (0)
#ifdef RUNE_INT64
#define FAST_WORD(w) do { if (!word_fits(w)) return 0; FAST_WORD(w); } while (0)
#else
#define FAST_WORD(w) do { FAST_WORD((w) & (UINT64_C(1) << 63) - 1); } while (0)
#endif
#define FAST_REAL(d) do { if (!mk_real_imm((d), &r)) return 0; } while (0)

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
#define INT2 if (!val_is(*x, T_INT) || !val_is(*y, T_INT)) return 0
#define WORD2 if (!val_is(*x, T_WORD) || !val_is(*y, T_WORD)) return 0
#define REAL2 if (!val_is(*x, T_REAL) || !val_is(*y, T_REAL)) return 0
#define CHAR2 if (!val_is(*x, T_CHAR) || !val_is(*y, T_CHAR)) return 0
#define OBJ(v, k) if (!val_is(*(v), T_PTR) || obj_kind(val_ptr(*(v))) != (k)) return 0
    switch (prim) {
    /* `=` on two values that are neither pointers nor reals: tags and bits */
    case PRIM_poly_eq:
        if (val_is(*x, T_PTR) || val_is(*y, T_PTR) || val_is(*x, T_REAL) || val_is(*y, T_REAL)) return 0;
        r = mk_bool(val_tag(*x) == val_tag(*y) && val_imm(*x) == val_imm(*y)); break;
    case PRIM_imm_eq:
        if (val_is(*x, T_PTR) || val_is(*y, T_PTR)) return 0;
        r = mk_bool(val_tag(*x) == val_tag(*y) && val_imm(*x) == val_imm(*y)); break;

    case PRIM_int_add: { INT2; int64_t v; if (!fast_add(val_imm(*x), val_imm(*y), &v) || !int_fits(v)) return 0; r = mk_int(v); break; }
    case PRIM_int_sub: { INT2; int64_t v; if (!fast_sub(val_imm(*x), val_imm(*y), &v) || !int_fits(v)) return 0; r = mk_int(v); break; }
    case PRIM_int_mul: { INT2; int64_t v; if (!fast_mul(val_imm(*x), val_imm(*y), &v) || !int_fits(v)) return 0; r = mk_int(v); break; }
    /* a divisor of 0 or ~1 (where the quotient may overflow) is the primitive's */
    case PRIM_int_div: {
        INT2; if (val_imm(*y) == 0 || val_imm(*y) == -1) return 0;
        int64_t q = val_imm(*x) / val_imm(*y);
        if ((val_imm(*x) % val_imm(*y) != 0) && ((val_imm(*x) < 0) != (val_imm(*y) < 0))) q--;
        FAST_INT(q); break;
    }
    case PRIM_int_mod: {
        INT2; if (val_imm(*y) == 0 || val_imm(*y) == -1) return 0;
        int64_t m = val_imm(*x) % val_imm(*y);
        if (m != 0 && ((m < 0) != (val_imm(*y) < 0))) m += val_imm(*y);
        FAST_INT(m); break;
    }
    case PRIM_int_quot: INT2; if (val_imm(*y) == 0 || val_imm(*y) == -1) return 0; FAST_INT(val_imm(*x) / val_imm(*y)); break;
    case PRIM_int_rem: INT2; if (val_imm(*y) == 0 || val_imm(*y) == -1) return 0; FAST_INT(val_imm(*x) % val_imm(*y)); break;
    case PRIM_int_neg: if (!val_is(*x, T_INT) || val_imm(*x) == INT64_MIN) return 0; FAST_INT(-val_imm(*x)); break;
    case PRIM_int_lt: INT2; r = mk_bool(val_imm(*x) < val_imm(*y)); break;
    case PRIM_int_le: INT2; r = mk_bool(val_imm(*x) <= val_imm(*y)); break;
    case PRIM_int_gt: INT2; r = mk_bool(val_imm(*x) > val_imm(*y)); break;
    case PRIM_int_ge: INT2; r = mk_bool(val_imm(*x) >= val_imm(*y)); break;
    case PRIM_int_order: INT2; r = fast_order(val_imm(*x) < val_imm(*y), val_imm(*x) > val_imm(*y)); break;
    case PRIM_int_to_char: if (!val_is(*x, T_INT) || val_imm(*x) < 0 || val_imm(*x) > 255) return 0; r = mk_char(val_imm(*x)); break;

    case PRIM_word_add: WORD2; FAST_WORD(val_word(*x) + val_word(*y)); break;
    case PRIM_word_sub: WORD2; FAST_WORD(val_word(*x) - val_word(*y)); break;
    case PRIM_word_mul: WORD2; FAST_WORD(val_word(*x) * val_word(*y)); break;
    case PRIM_word_div: WORD2; if (val_word(*y) == 0) return 0; FAST_WORD(val_word(*x) / val_word(*y)); break;
    case PRIM_word_mod: WORD2; if (val_word(*y) == 0) return 0; FAST_WORD(val_word(*x) % val_word(*y)); break;
    case PRIM_word_lt: WORD2; r = mk_bool(val_word(*x) < val_word(*y)); break;
    case PRIM_word_le: WORD2; r = mk_bool(val_word(*x) <= val_word(*y)); break;
    case PRIM_word_gt: WORD2; r = mk_bool(val_word(*x) > val_word(*y)); break;
    case PRIM_word_ge: WORD2; r = mk_bool(val_word(*x) >= val_word(*y)); break;
    case PRIM_word_order: WORD2; r = fast_order(val_word(*x) < val_word(*y), val_word(*x) > val_word(*y)); break;
    case PRIM_word_andb: WORD2; FAST_WORD(val_word(*x) & val_word(*y)); break;
    case PRIM_word_orb: WORD2; FAST_WORD(val_word(*x) | val_word(*y)); break;
    case PRIM_word_xorb: WORD2; FAST_WORD(val_word(*x) ^ val_word(*y)); break;
    case PRIM_word_notb: if (!val_is(*x, T_WORD)) return 0; FAST_WORD(~val_word(*x)); break;
    case PRIM_word_lsl: WORD2; FAST_WORD(val_word(*y) >= 64 ? 0 : val_word(*x) << val_word(*y)); break;
    case PRIM_word_lsr: WORD2; FAST_WORD(val_word(*y) >= 64 ? 0 : val_word(*x) >> val_word(*y)); break;
    case PRIM_word_to_int: if (!val_is(*x, T_WORD) || val_word(*x) > (uint64_t)INT64_MAX) return 0; FAST_INT((int64_t)val_word(*x)); break;
    case PRIM_word_to_int_x: if (!val_is(*x, T_WORD)) return 0; FAST_INT((int64_t)val_word(*x)); break;
    case PRIM_word_from_int: if (!val_is(*x, T_INT)) return 0; FAST_WORD((uint64_t)val_imm(*x)); break;

    case PRIM_real_add: REAL2; FAST_REAL(val_real(*x) + val_real(*y)); break;
    case PRIM_real_sub: REAL2; FAST_REAL(val_real(*x) - val_real(*y)); break;
    case PRIM_real_mul: REAL2; FAST_REAL(val_real(*x) * val_real(*y)); break;
    case PRIM_real_div: REAL2; FAST_REAL(val_real(*x) / val_real(*y)); break;
    case PRIM_real_neg: if (!val_is(*x, T_REAL)) return 0; FAST_REAL(-val_real(*x)); break;
    case PRIM_real_sqrt: if (!val_is(*x, T_REAL)) return 0; FAST_REAL(sqrt(val_real(*x))); break;
    case PRIM_real_lt: REAL2; r = mk_bool(val_real(*x) < val_real(*y)); break;
    case PRIM_real_le: REAL2; r = mk_bool(val_real(*x) <= val_real(*y)); break;
    case PRIM_real_gt: REAL2; r = mk_bool(val_real(*x) > val_real(*y)); break;
    case PRIM_real_ge: REAL2; r = mk_bool(val_real(*x) >= val_real(*y)); break;
    case PRIM_real_eq: REAL2; r = mk_bool(val_real(*x) == val_real(*y)); break;

    case PRIM_char_ord: if (!val_is(*x, T_CHAR)) return 0; FAST_INT(val_imm(*x)); break;
    case PRIM_char_lt: CHAR2; r = mk_bool(val_imm(*x) < val_imm(*y)); break;
    case PRIM_char_le: CHAR2; r = mk_bool(val_imm(*x) <= val_imm(*y)); break;
    case PRIM_char_gt: CHAR2; r = mk_bool(val_imm(*x) > val_imm(*y)); break;
    case PRIM_char_ge: CHAR2; r = mk_bool(val_imm(*x) >= val_imm(*y)); break;
    case PRIM_char_order: CHAR2; r = fast_order(val_imm(*x) < val_imm(*y), val_imm(*x) > val_imm(*y)); break;

    case PRIM_string_size: OBJ(x, K_STRING); FAST_INT(obj_len(val_ptr(*x))); break;
    case PRIM_string_sub:
        OBJ(x, K_STRING); if (!val_is(*y, T_INT) || val_imm(*y) < 0 || (uint64_t)val_imm(*y) >= obj_len(val_ptr(*x))) return 0;
        r = mk_char((unsigned char)obj_bytes(val_ptr(*x))[val_imm(*y)]); break;
    case PRIM_ref_get: OBJ(x, K_REF); r = obj_field(val_ptr(*x), 0); break;
    case PRIM_ref_set: OBJ(x, K_REF); HEAP_STORE(val_ptr(*x), 0, *y); r = mk_unit(); break;
    case PRIM_array_length: OBJ(x, K_ARRAY); FAST_INT(obj_len(val_ptr(*x))); break;
    case PRIM_array_sub:
        OBJ(x, K_ARRAY); if (!val_is(*y, T_INT) || val_imm(*y) < 0 || (uint64_t)val_imm(*y) >= obj_len(val_ptr(*x))) return 0;
        r = obj_field(val_ptr(*x), val_imm(*y)); break;
    case PRIM_array_update:
        OBJ(x, K_ARRAY); if (!val_is(*y, T_INT) || val_imm(*y) < 0 || (uint64_t)val_imm(*y) >= obj_len(val_ptr(*x))) return 0;
        HEAP_STORE(val_ptr(*x), val_imm(*y), *z); r = mk_unit(); break;
    case PRIM_vector_length: OBJ(x, K_TUPLE); FAST_INT(obj_len(val_ptr(*x))); break;
    case PRIM_vector_sub:
        OBJ(x, K_TUPLE); if (!val_is(*y, T_INT) || val_imm(*y) < 0 || (uint64_t)val_imm(*y) >= obj_len(val_ptr(*x))) return 0;
        r = obj_field(val_ptr(*x), val_imm(*y)); break;
    default:
        return 0;
    }
#undef INT2
#undef WORD2
#undef REAL2
#undef CHAR2
#undef OBJ
    CENSUS_PRIM_RESULT(prim, r);
    *out = r;
    return 1;
}

#endif
