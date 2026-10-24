/* A test of division by a constant (functors-units M1; make
   test-register-jit): the plan of runtime/register/jit/divplan.h and the
   steps of masm.c's ms_div_const, made into a function of this machine
   for every operation and each of some two thousand divisors -- every
   size, both signs, the edges, the primes of Pickle.hash -- and run on
   dividends of every size, the edges and the multiples of the divisor
   around each, against C's division. Written over the portable
   assembler, so that the build for aarch64 runs it as well (under
   qemu-aarch64, the command in the head of the Makefile's rule). A
   signed plan is of every dividend of 64 bits (an int of 63 is one); an
   unsigned one of those below 2^63 (a word's payload) or of all (a word
   of 64 bits). */
#include "register/jit/masm.h"
#include "sys/sys.h"
#include <stdio.h>
#include <string.h>

typedef uint64_t (*Fn)(uint64_t);
static Fn as_fn(void *p) { Fn f; memcpy(&f, &p, sizeof f); return f; }

static uint64_t seed = 0x9E3779B97F4A7C15u;
static uint64_t next(void) { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return seed; }
/* a number of a random size: its bits 1 to 64, all but the top random */
static uint64_t sized(void) {
    int bits = (int)(next() % 64) + 1;
    uint64_t top = (uint64_t)1 << (bits - 1);
    return top | (next() & (top - 1));
}

/* the definition, in C's arithmetic: the truncation's, and the floor's
   from it where the remainder's sign is not the divisor's */
static uint64_t want(int op, int sign, uint64_t n, uint64_t c) {
    if (!sign) return op == DIV_DIV ? n / c : n % c;
    int64_t a = (int64_t)n, b = (int64_t)c;
    int64_t q = a / b, r = a % b;
    if (op == DIV_QUOT) return (uint64_t)q;
    if (op == DIV_REM) return (uint64_t)r;
    if (r != 0 && ((r < 0) != (b < 0))) { q--; r += b; }
    return (uint64_t)(op == DIV_DIV ? q : r);
}

static long checks, fails;
/* the ways a divisor is divided by: signed (an int's, of 63 or 64 bits),
   unsigned of 63 bits and of 64 */
static const struct { int sign, bits; } ways[] = { { 1, 64 }, { 0, 63 }, { 0, 64 } };
static const char *const op_names[] = { "div", "mod", "quot", "rem" };

static void test(uint64_t c) {
    Masm m;
    ms_init(&m, 1, 1, 0, NULL);
    size_t at[3][4];
    DivPlan plans[3][4];
    int have[3][4];
    for (int w = 0; w < 3; w++)
        for (int op = 0; op < 4; op++) {
            have[w][op] = div_plan(&plans[w][op], op, ways[w].sign, c, ways[w].bits);
            if (!have[w][op]) continue;
            at[w][op] = m.a.n;
            as_mov_rr(&m.a, R_S0, ms_arg(&m, 0));
            ms_div_const(&m, &plans[w][op]);
            as_ret(&m.a);
        }
    size_t size = (m.a.n + 4095) & ~(size_t)4095;
    uint8_t *code = size ? sys_code_alloc(size) : NULL;
    if (size && (!code || m.a.failed)) { printf("FAIL no code for %llx\n", (unsigned long long)c); fails++; ms_free(&m); return; }
    if (size) {
        memcpy(code, m.a.buf, m.a.n);
        sys_code_protect(code, size, 1);
        sys_code_flush(code, m.a.n);
    }
    /* the dividends: the edges, around multiples of c, near the ends and
       random ones */
    uint64_t ns[400];
    int nn = 0;
    static const uint64_t edges[] = {
        0, 1, 2, 3, ~(uint64_t)0, ~(uint64_t)1, (uint64_t)1 << 63, ((uint64_t)1 << 63) + 1, ((uint64_t)1 << 63) - 1,
        ((uint64_t)1 << 63) - 2, (uint64_t)1 << 62, ((uint64_t)1 << 62) - 1, ~(((uint64_t)1 << 62) - 1), (uint64_t)1 << 32
    };
    for (size_t i = 0; i < sizeof edges / sizeof edges[0]; i++) ns[nn++] = edges[i];
    for (int k = -12; k <= 12; k++)
        for (int e = -2; e <= 2; e++) ns[nn++] = c * (uint64_t)(int64_t)k + (uint64_t)(int64_t)e;
    for (int e = -2; e <= 2 && c != 0; e++) {
        int64_t sc = (int64_t)c == -1 ? 1 : (int64_t)c;
        ns[nn++] = (~(uint64_t)0 / c) * c + (uint64_t)(int64_t)e;                           /* the unsigned end */
        ns[nn++] = (uint64_t)((INT64_MAX / sc) * sc) + (uint64_t)(int64_t)e;                /* the signed ends */
        ns[nn++] = (uint64_t)((INT64_MIN / sc) * sc) + (uint64_t)(int64_t)e;
        ns[nn++] = (uint64_t)((((int64_t)1 << 62) - 1) / sc * sc) + (uint64_t)(int64_t)e;   /* and an int's */
    }
    while (nn < (int)(sizeof ns / sizeof ns[0])) { uint64_t n = sized(); ns[nn++] = next() & 1 ? 0 - n : n; }
    for (int w = 0; w < 3; w++)
        for (int op = 0; op < 4; op++) {
            if (!have[w][op]) continue;
            Fn f = as_fn(code + at[w][op]);
            for (int i = 0; i < nn; i++) {
                uint64_t n = ns[i];
                if (!ways[w].sign && ways[w].bits == 63) n &= ~((uint64_t)1 << 63);
                uint64_t got = f(n), exp = want(op, ways[w].sign, n, c);
                checks++;
                if (got != exp && fails++ < 20)
                    printf("FAIL %s %s%d: %llx by %llx gives %llx, not %llx (plan %d, m %llx, sh %d, add %d)\n",
                           op_names[op], ways[w].sign ? "int" : "word", ways[w].bits, (unsigned long long)n,
                           (unsigned long long)c, (unsigned long long)got, (unsigned long long)exp, plans[w][op].kind,
                           (unsigned long long)plans[w][op].m, plans[w][op].sh, plans[w][op].add);
            }
        }
    if (code) sys_code_free(code, size);
    ms_free(&m);
}

int main(void) {
    static const uint64_t fixed[] = {
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 25, 31, 100, 641, 1000, 65536, 65537,
        1000003, 16777213, 16777199, 16777183, 16777153, 16777216,              /* Pickle.hash's primes */
        2147483647, 2147483648u, 2147483649u, 4294967291u, 4294967295u, 4294967296u,
        ((uint64_t)1 << 61) - 1, (uint64_t)1 << 61, ((uint64_t)1 << 61) + 1, ((uint64_t)1 << 62) - 1,
        (uint64_t)1 << 62, ((uint64_t)1 << 62) + 1, 4611686018427387847u, 3074457345618258602u,
        1537228672809129301u, 0x5555555555555555u, 0xAAAAAAAAAAAAAAABu, ((uint64_t)1 << 63) - 1,
        (uint64_t)1 << 63, ((uint64_t)1 << 63) + 1, ~(uint64_t)1, ~(uint64_t)0
    };
    size_t nf = sizeof fixed / sizeof fixed[0];
    for (size_t i = 0; i < nf; i++) { test(fixed[i]); test(0 - fixed[i]); }
    test(0);
    for (int i = 0; i < 2000; i++) { uint64_t c = sized(); test(next() & 1 ? 0 - c : c); }
    /* that 0 and the signed -1 have no plan, and the rest one */
    DivPlan p;
    if (div_plan(&p, DIV_DIV, 1, 0, 64) || div_plan(&p, DIV_MOD, 0, 0, 63) || div_plan(&p, DIV_QUOT, 1, ~(uint64_t)0, 64)
        || !div_plan(&p, DIV_MOD, 0, ~(uint64_t)0, 64)) { printf("FAIL the plans of 0 and -1\n"); fails++; }
    /* x mod 16777213, Pickle.hash's: the unsigned magic of 64 bits, no add */
    if (!div_plan(&p, DIV_MOD, 1, 16777213, 63) || p.kind != DP_UFLOOR || p.add) { printf("FAIL the plan of mod 16777213\n"); fails++; }
    if (fails) printf("divconst: %ld of %ld checks failed\n", fails, checks);
    else printf("divconst: ok (%ld checks)\n", checks);
    return fails != 0;
}
