/* Division by a constant (docs/plans/functors-units.md, M1): how tier 2
   divides where the divisor is a constant it knows (compile.c, the known
   registers) -- an int's div, mod, quot and rem, a word's div and mod,
   and the same of Int64.int and Word64.word -- worked out when the code is
   compiled. The divisor 0, and -1 of a signed division, have no plan: the
   general path raises Div for the first, and Overflow for the least int
   divided by the second. A power of two goes by shifts and masks; any
   other divisor by the high half of a multiplication by a magic number,
   and the floor's or the truncation's fix-up (Granlund and Montgomery,
   "Division by invariant integers using multiplication", PLDI 1994;
   Warren, Hacker's Delight, 2nd ed., chapter 10). The steps are
   ms_div_const's (masm.c); tests/register/divconst_test.c runs them
   against C's division. The arithmetic here is of 64 bits alone, since
   the VMs of the machines without a 128-bit integer compile it too. */
#ifndef RUNE_JIT_DIVPLAN_H
#define RUNE_JIT_DIVPLAN_H

#include <stdint.h>

/* the operation: the floor's quotient and remainder (div, mod), the
   truncation's (quot, rem; signed alone) */
enum { DIV_DIV, DIV_MOD, DIV_QUOT, DIV_REM };
/* the plan's kind */
enum {
    DP_ONE,      /* c = 1 */
    DP_POW2,     /* |c| = 2^k: shifts and masks */
    DP_UFLOOR,   /* signed div and mod by c > 0: with s = n >> 63 (0 or -1), the quotient is
                    s ^ floor((n ^ s) / c), n ^ s being below 2^63: m and sh, unsigned */
    DP_SMAGIC,   /* signed quot and rem, and div and mod by c < 0: trunc(n / c) by the signed
                    magic m, sh and add, then the floor's fix-up */
    DP_UMAGIC    /* unsigned: floor(n / c) = hi(m n) >> sh; add: m is 2^64 more than its 64 bits */
};
typedef struct {
    int op;        /* DIV_DIV to DIV_REM */
    int sign;      /* 1: signed (an int's), 0: unsigned (a word's) */
    int kind;      /* DP_ONE to DP_UMAGIC */
    uint64_t c;    /* the divisor's 64 bits (signed: two's complement) */
    uint64_t m;    /* the magic multiplier */
    int sh;        /* the shift after the multiplication */
    int k;         /* DP_POW2: log2 |c| */
    int add;       /* DP_SMAGIC: 1 where n is added to the high half, -1 where it is
                      subtracted; DP_UMAGIC: 1 for the 65-bit form */
} DivPlan;

/* the bits of x: 0 for 0, 64 for 2^63 and above */
static inline int dp_bits(uint64_t x) { int n = 0; while (x) { n++; x >>= 1; } return n; }
static inline int dp_is_pow2(uint64_t x) { return x && !(x & (x - 1)); }

/* floor(2^e / d) for d >= 1 and e <= 128, as hi:lo, and the remainder:
   the long division, a bit at a time */
static inline uint64_t dp_pow_div(int e, uint64_t d, uint64_t *hi, uint64_t *lo) {
    uint64_t qh = 0, ql = 0, r = 0;
    for (int i = e; i >= 0; i--) {
        uint64_t carry = r >> 63;
        r = (r << 1) | (uint64_t)(i == e);
        qh = (qh << 1) | (ql >> 63);
        ql <<= 1;
        if (carry || r >= d) { r -= d; ql |= 1; }
    }
    *hi = qh; *lo = ql;
    return r;
}

/* floor(n / d) for 0 <= n < 2^N (N 63 or 64), d >= 3 not a power of two:
   m = floor(2^(N+l) / d) + 1 with the least l for which 2^(N+l) <= m d <=
   2^(N+l) + 2^l (Granlund and Montgomery, theorem 4.2; m d - 2^(N+l) is d
   less the remainder), and N + l at least 64, so that the quotient is
   hi(m n) >> (N + l - 64). Then m is below 2^64 for N = 63, and may be
   2^64 more than its 64 bits m' for N = 64: their figure 4.1's form,
   t = hi(m' n), q = (t + (n - t) / 2) >> (N + l - 65). */
static inline void dp_umagic(DivPlan *p, uint64_t d, int N) {
    int lmax = dp_bits(d - 1);   /* ceil(log2 d), for which the bound always holds */
    for (int l = 64 - N; l <= lmax; l++) {
        uint64_t qh, ql;
        uint64_t r = dp_pow_div(N + l, d, &qh, &ql);
        if (l < lmax && d - r > ((uint64_t)1 << l)) continue;
        /* m = q + 1 */
        uint64_t m = ql + 1;
        int over = qh != 0 || m == 0;
        int sh = N + l - 64;
        p->m = m;
        if (over) { p->add = 1; p->sh = sh - 1; } else { p->add = 0; p->sh = sh; }
        return;
    }
}

/* the signed magic number of Hacker's Delight's figure 10-1, for 64 bits:
   trunc(n / d) = q + (q < 0), q = (hi(m n) [+ n or - n]) >> sh, for |d| >= 2
   and every n of 64 bits */
static inline void dp_smagic(DivPlan *p, int64_t d) {
    const uint64_t two63 = (uint64_t)1 << 63;
    uint64_t ad = d < 0 ? 0 - (uint64_t)d : (uint64_t)d;
    uint64_t t = two63 + ((uint64_t)d >> 63);
    uint64_t anc = t - 1 - t % ad;   /* |nc| */
    int q = 63;
    uint64_t q1 = two63 / anc, r1 = two63 - q1 * anc;
    uint64_t q2 = two63 / ad, r2 = two63 - q2 * ad, delta;
    do {
        q++;
        q1 *= 2; r1 *= 2;
        if (r1 >= anc) { q1++; r1 -= anc; }
        q2 *= 2; r2 *= 2;
        if (r2 >= ad) { q2++; r2 -= ad; }
        delta = ad - r2;
    } while (q1 < delta || (q1 == delta && r1 == 0));
    uint64_t m = q2 + 1;
    if (d < 0) m = 0 - m;
    p->m = m;
    p->sh = q - 64;
    p->add = d > 0 && (int64_t)m < 0 ? 1 : d < 0 && (int64_t)m > 0 ? -1 : 0;
}

/* The plan for op on a dividend of `bits` bits (63 or 64; an unsigned
   one's below 2^bits, a signed one's of either width) and the divisor c:
   1, or 0 where there is none (c 0, or -1 signed). */
static inline int div_plan(DivPlan *p, int op, int sign, uint64_t c, int bits) {
    if (c == 0 || (sign && c == ~(uint64_t)0)) return 0;
    if (!sign && op != DIV_DIV && op != DIV_MOD) return 0;
    p->op = op; p->sign = sign; p->c = c;
    p->m = 0; p->sh = 0; p->k = 0; p->add = 0;
    uint64_t ac = sign && (int64_t)c < 0 ? 0 - c : c;   /* |c|; 2^63 for the least */
    if (c == 1) p->kind = DP_ONE;
    else if (dp_is_pow2(ac)) { p->kind = DP_POW2; p->k = dp_bits(ac) - 1; }
    else if (!sign) { p->kind = DP_UMAGIC; dp_umagic(p, c, bits); }
    else if ((int64_t)c > 0 && (op == DIV_DIV || op == DIV_MOD)) { p->kind = DP_UFLOOR; dp_umagic(p, c, 63); }
    else { p->kind = DP_SMAGIC; dp_smagic(p, (int64_t)c); }
    return 1;
}

#endif
