/* Reduced from GMP 6.3.0 mpn/generic/div_qr_1n_pi1.c method 2 and the
   powerpc64 longlong.h helpers it uses. Clang 18 defines __GNUC__ as 4.2,
   so GMP takes the mulhdu asm, not the gcc >= 4.8 128-bit multiply.
   The division steps follow that GMP routine (FSF, dual GPL/LGPL) so the
   failure can be built without libgmp. -O1 and -O2 fail; -O0 and -DXER pass.
   clang -O2 --target=powerpc64-linux-gnu -B/usr/powerpc64-linux-gnu/bin \
     -L/usr/powerpc64-linux-gnu/lib -I/usr/powerpc64-linux-gnu/include \
     -Wl,-dynamic-linker,/usr/powerpc64-linux-gnu/lib/ld64.so.1 \
     repro.c -o repro
   qemu-ppc64 -L /usr/powerpc64-linux-gnu ./repro
   The same command with -DXER passes.
*/
#include <stdio.h>

typedef unsigned long mp_limb_t;
typedef long mp_size_t;
typedef mp_limb_t *mp_ptr;
typedef const mp_limb_t *mp_srcptr;

#ifdef XER
#define CLOBBER : "cc", "xer"
#else
#define CLOBBER : "cc"
#endif

#define umul_ppmm(ph, pl, m0, m1)                                       \
  do {                                                                  \
    mp_limb_t __m0 = (m0), __m1 = (m1);                                 \
    __asm__ ("mulhdu %0,%1,%2" : "=r" (ph) : "%r" (__m0), "r" (__m1));  \
    (pl) = __m0 * __m1;                                                 \
  } while (0)

#define add_ssaaaa(sh, sl, ah, al, bh, bl)                              \
  do {                                                                  \
    if (__builtin_constant_p (bh) && (bh) == 0)                         \
      __asm__ ("add%I4c %1,%3,%4\n\taddze %0,%2"                        \
               : "=r" (sh), "=&r" (sl)                                  \
               : "r"  ((mp_limb_t)(ah)),                                \
                 "%r" ((mp_limb_t)(al)), "rI" ((mp_limb_t)(bl))         \
                 CLOBBER);                                              \
    else if (__builtin_constant_p (bh) && (bh) == ~(mp_limb_t) 0)       \
      __asm__ ("add%I4c %1,%3,%4\n\taddme %0,%2"                        \
               : "=r" (sh), "=&r" (sl)                                  \
               : "r"  ((mp_limb_t)(ah)),                                \
                 "%r" ((mp_limb_t)(al)), "rI" ((mp_limb_t)(bl))         \
                 CLOBBER);                                              \
    else                                                                \
      __asm__ ("add%I5c %1,%4,%5\n\tadde %0,%2,%3"                      \
               : "=r" (sh), "=&r" (sl)                                  \
               : "r"  ((mp_limb_t)(ah)), "r" ((mp_limb_t)(bh)),          \
                 "%r" ((mp_limb_t)(al)), "rI" ((mp_limb_t)(bl))          \
                 CLOBBER);                                              \
  } while (0)

#define add_mssaaaa(m, s1, s0, a1, a0, b1, b0)                          \
  __asm__ ("add%I6c %2, %5, %6\n\t"                                     \
           "adde %1, %3, %4\n\t"                                        \
           "subfe %0, %0, %0\n\t"                                       \
           "nor %0, %0, %0"                                             \
           : "=r" (m), "=r" (s1), "=&r" (s0)                            \
           : "r" (a1), "r" (b1), "%r" (a0), "rI" (b0)                   \
             CLOBBER)

#define ADDC_LIMB(cout, w, x, y)                                        \
  do {                                                                  \
    mp_limb_t __x = (x), __y = (y), __w = __x + __y;                    \
    (w) = __w;                                                          \
    (cout) = __w < __x;                                                 \
  } while (0)

#define mpn_incr_u(p, incr)                                             \
  do {                                                                  \
    mp_limb_t __x;                                                      \
    mp_ptr __p = (p);                                                   \
    if (__builtin_constant_p (incr) && (incr) == 1)                     \
      while (++(*(__p++)) == 0)                                        \
        ;                                                               \
    else {                                                              \
      __x = *__p + (incr);                                              \
      *__p = __x;                                                       \
      if (__x < (incr))                                                 \
        while (++(*(++__p)) == 0)                                      \
          ;                                                             \
    }                                                                   \
  } while (0)

#define udiv_qrnnd_preinv(q, r, nh, nl, d, di)                          \
  do {                                                                  \
    mp_limb_t _qh, _ql, _r, _mask;                                      \
    umul_ppmm (_qh, _ql, (nh), (di));                                   \
    add_ssaaaa (_qh, _ql, _qh, _ql, (nh) + 1, (nl));                    \
    _r = (nl) - _qh * (d);                                              \
    _mask = -(mp_limb_t) (_r > _ql);                                    \
    _qh += _mask;                                                       \
    _r += _mask & (d);                                                  \
    if (_r >= (d)) {                                                    \
      _r -= (d);                                                        \
      _qh++;                                                            \
    }                                                                   \
    (r) = _r;                                                           \
    (q) = _qh;                                                          \
  } while (0)

/* GMP 6.3.0 mpn_div_qr_1n_pi1, DIV_QR_1N_METHOD 2. */
static mp_limb_t
div_qr_1n_pi1 (mp_ptr qp, mp_srcptr up, mp_size_t n, mp_limb_t u1,
               mp_limb_t d, mp_limb_t dinv)
{
  mp_limb_t B2, u0, u2, q0, q1, p0, p1, t;
  mp_size_t j;

  B2 = -d * dinv;
  umul_ppmm (q1, q0, dinv, u1);
  umul_ppmm (p1, p0, B2, u1);
  q1 += u1;
  u0 = up[n - 1];
  qp[n - 1] = q1;
  add_mssaaaa (u2, u1, u0, u0, up[n - 2], p1, p0);

  for (j = n - 2; j-- > 0; ) {
    mp_limb_t q2, cy;
    umul_ppmm (p1, t, u1, dinv);
    ADDC_LIMB (cy, u0, u0, u2 & B2);
    u0 -= (-cy) & d;
    add_ssaaaa (q2, q1, -u2, u2 & dinv, 0, u1);
    add_ssaaaa (q2, q1, q2, q1, 0, q0);
    q0 = t;
    add_ssaaaa (q2, q1, q2, q1, 0, p1 + cy);
    umul_ppmm (p1, p0, u1, B2);
    qp[j + 1] = q1;
    mpn_incr_u (qp + j + 2, q2);
    add_mssaaaa (u2, u1, u0, u0, up[j], p1, p0);
  }

  q1 = (u2 > 0);
  u1 -= (-q1) & d;
  t = (u1 >= d);
  q1 += t;
  u1 -= (-t) & d;
  udiv_qrnnd_preinv (t, u0, u1, u0, d, dinv);
  add_ssaaaa (q1, q0, q1, q0, 0, t);
  mpn_incr_u (qp + 1, q1);
  qp[0] = q0;
  return u0;
}

int main(void) {
  /* mpn_div_qr_1 peels the top limb of 2^256-1 before the pi1 kernel. */
  const mp_limb_t up[4] = {~0ul, ~0ul, ~0ul, ~0ul};
  const mp_limb_t d = (1ul << 63) + 3;
  const mp_limb_t dinv = 0xfffffffffffffff4ul; /* mpn_invert_limb(d) */
  mp_limb_t qp[4] = {0, 0, 0, 0};
  mp_limb_t u1 = ~0ul - d;
  mp_limb_t r = div_qr_1n_pi1(qp, up, 3, u1, d, dinv);
  qp[3] = 1;

  /* 0x1fffffffffffffff40000000000000047fffffffffffffe50 */
  const mp_limb_t want[4] = {
    0xfffffffffffffe50ul,
    0x47ul,
    0xfffffffffffffff4ul,
    0x1ul
  };
  int bad = r != 0x50f;
  printf("r=0x%lx qp=%lx %lx %lx %lx\n", r, qp[3], qp[2], qp[1], qp[0]);
  for (int i = 0; i < 4; i++)
    bad |= qp[i] != want[i];
  printf("%s\n", bad ? "FAIL" : "pass");
  return bad;
}
