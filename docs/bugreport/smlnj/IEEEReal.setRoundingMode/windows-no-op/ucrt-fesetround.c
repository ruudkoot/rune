/* Microsoft's C library (UCRT): fesetround with the x87 value 2 that SML/NJ's
   runtime passes for "upward" is rejected; with UCRT's FE_UPWARD it works.
   Build and run in a Visual Studio x86 command prompt: cl ucrt-fesetround.c */
#include <stdio.h>
#include <fenv.h>
int main (void) {
    volatile double one = 1.0, three = 3.0;
    int r; int g; double q;
    printf ("UCRT: FE_TONEAREST %#x FE_DOWNWARD %#x FE_UPWARD %#x FE_TOWARDZERO %#x\n", FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO);
    r = fesetround (2); g = fegetround (); q = one / three;
    printf ("fesetround(2), fp-dep.h's FE_UPWARD: returns %d, then fegetround() is %#x and 1/3 is %.17g\n", r, g, q);
    r = fesetround (FE_UPWARD); g = fegetround (); q = one / three;
    printf ("fesetround(FE_UPWARD): returns %d, then fegetround() is %#x and 1/3 is %.17g\n", r, g, q);
    fesetround (FE_TONEAREST);
    return 0;
}
