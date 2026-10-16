/* The two longlong.h helpers a GMP 6.3.0 fat build compiles in when
   config.guess reports haswell, broadwell, skylake, bd4 or zen.
   No libgmp. On a CPU without LZCNT, "rep; bsr" executes as BSR.
   On a CPU without BMI2, mulx raises SIGILL.
   cc -O2 -o repro repro.c
   ./repro
   qemu-x86_64 -cpu qemu64 ./repro
   qemu-x86_64 -cpu max ./repro
*/
#include <stdint.h>
#include <stdio.h>
#include <signal.h>
#include <setjmp.h>

static jmp_buf ill_env;
static void on_ill(int sig) { (void)sig; longjmp(ill_env, 1); }

/* longlong.h, HAVE_HOST_CPU_haswell branch. The comment in GMP says this
   is lzcnt, spelled for older assemblers. */
static uint64_t clz_rep_bsr(uint64_t x) {
    uint64_t count;
    __asm__("rep;bsr\t%1, %q0" : "=r"(count) : "rm"(x));
    return count;
}

/* longlong.h, the generic x86-64 branch. */
static uint64_t clz_bsr(uint64_t x) {
    uint64_t index;
    __asm__("bsr\t%1, %0" : "=r"(index) : "rm"(x));
    return index ^ 63;
}

/* longlong.h umul_ppmm, X86_ASM_MULX && HAVE_HOST_CPU_haswell. */
static int mulx_or_sigill(uint64_t u, uint64_t v, uint64_t *lo, uint64_t *hi) {
    struct sigaction sa, old;
    sa.sa_handler = on_ill;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGILL, &sa, &old);
    if (setjmp(ill_env)) {
        sigaction(SIGILL, &old, 0);
        return 1;
    }
    uint64_t w0, w1;
    __asm__("mulx\t%3, %q0, %q1"
            : "=r"(w0), "=r"(w1)
            : "d"(u), "rm"(v));
    *lo = w0;
    *hi = w1;
    sigaction(SIGILL, &old, 0);
    return 0;
}

int main(void) {
    /* Magnitude of IntInf.<< (IntInf.fromInt (~9), 0w31), which is 9<<31. */
    const uint64_t limb = 9ull << 31;
    uint64_t reported = clz_rep_bsr(limb);
    uint64_t generic = clz_bsr(limb);
    /* mpz_sizeinbase base 2 does GMP_LIMB_BITS - count_leading_zeros. */
    uint64_t bits = 64 - reported;
    uint64_t nbytes = (bits + 7) / 8;
    uint64_t exported = 0;
    for (uint64_t i = 0; i < nbytes && i < 8; i++)
        exported |= ((limb >> (8 * i)) & 0xff) << (8 * i);

    printf("rep;bsr -> %llu (generic bsr^63 -> %llu)\n",
           (unsigned long long)reported, (unsigned long long)generic);
    printf("sizeinbase bits %llu, export bytes %llu, value %llu\n",
           (unsigned long long)bits, (unsigned long long)nbytes,
           (unsigned long long)exported);
    printf("expected export 19327352832\n");

    uint64_t lo = 0, hi = 0;
    if (mulx_or_sigill(3, 5, &lo, &hi))
        printf("mulx: SIGILL\n");
    else
        printf("mulx: 3*5 -> hi %llu lo %llu\n",
               (unsigned long long)hi, (unsigned long long)lo);

    int bad = exported != 19327352832ull || reported != generic;
    return bad ? 1 : 0;
}
