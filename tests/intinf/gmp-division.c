/* Minimized from GMP 6.3.0's PowerPC64 upstream t-div failure with clang 18
   under qemu. The runtime uses only mpz; the internal call here is a
   dependency regression test for this pinned version, not a Rune binding. */
#include <gmp.h>
#include <stdio.h>
#include <string.h>
#if __GNU_MP_VERSION != 6 || __GNU_MP_VERSION_MINOR != 3 || __GNU_MP_VERSION_PATCHLEVEL != 0
#error This internal-kernel regression probe is for the pinned GMP 6.3.0
#endif
#if GMP_NUMB_BITS == 64
extern mp_limb_t __gmpn_div_qr_1(mp_ptr, mp_limb_t *, mp_srcptr, mp_size_t, mp_limb_t);
#endif
int main(int argc, char **argv) {
    mpz_t n,d,q,r,want_q,want_r;
    mpz_inits(n,d,q,r,want_q,want_r,NULL);
    mpz_set_str(n,"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",16);
    mpz_set_str(d,"8000000000000003",16);
    /* q = 2^193 - 3*2^130 + 9*2^67 - 432; r = 1295.
       Thus q*(2^63+3)+r = 2^256-1 and 0 <= r < d. */
    mpz_set_str(want_q,"1fffffffffffffff40000000000000047fffffffffffffe50",16);
    mpz_set_ui(want_r,1295);
    mpz_fdiv_qr(q,r,n,d);
    int failed = mpz_cmp(q,want_q)!=0 || mpz_cmp(r,want_r)!=0;
    printf("mpz division: %s\n",failed ? "FAIL" : "pass");
#if GMP_NUMB_BITS == 64
    if (!(argc==2 && strcmp(argv[1],"--public-only")==0)) {
        mp_limb_t numerator[4] = {GMP_NUMB_MAX,GMP_NUMB_MAX,GMP_NUMB_MAX,GMP_NUMB_MAX};
        mp_limb_t quotient[4], high=0;
        mp_limb_t remainder=__gmpn_div_qr_1(quotient,&high,numerator,4,
                                         ((mp_limb_t)1<<63)+3);
        quotient[3]=high;
        mpz_import(q,4,-1,sizeof(mp_limb_t),0,0,quotient);
        int bad = mpz_cmp(q,want_q)!=0 || remainder!=1295;
        printf("pinned internal division: %s\n",bad ? "FAIL" : "pass");
        failed |= bad;
    }
#else
    (void)argc; (void)argv;
    puts("internal single-limb case: not applicable to 32-bit limbs");
#endif
    mpz_clears(n,d,q,r,want_q,want_r,NULL);
    return failed;
}
