/* The oracle of tests/lib/random/kat.sml: Vigna's splitmix64.c
   (prng.di.unimi.it), the split and mixGamma of Java's SplittableRandom,
   and Lemire's bounded draw ("Fast random integer generation in an
   interval", 2019), in C. tests/lib/run-lib-tests.sh compiles it and
   compares its output with that of kat.sml line by line. */
#include <stdint.h>
#include <stdio.h>

typedef struct { uint64_t seed, gamma; } gen;

static const uint64_t golden = 0x9e3779b97f4a7c15ull;

static uint64_t mix64(uint64_t z) {
  z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ull;
  z = (z ^ (z >> 27)) * 0x94d049bb133111ebull;
  return z ^ (z >> 31);
}

static uint64_t mix_gamma(uint64_t z) {
  z = (z ^ (z >> 33)) * 0xff51afd7ed558ccdull;
  z = (z ^ (z >> 33)) * 0xc4ceb9fe1a85ec53ull;
  z = (z ^ (z >> 33)) | 1ull;
  return __builtin_popcountll(z ^ (z >> 1)) < 24 ? z ^ 0xaaaaaaaaaaaaaaaaull : z;
}

static uint64_t next(gen *g) { g->seed += g->gamma; return mix64(g->seed); }

static gen split(gen *g) {
  gen h;
  h.seed = next(g);
  g->seed += g->gamma;
  h.gamma = mix_gamma(g->seed);
  return h;
}

static uint64_t below(gen *g, uint64_t n) {
  unsigned __int128 m = (unsigned __int128) next(g) * n;
  uint64_t l = (uint64_t) m;
  if (l < n) {
    uint64_t t = -n % n;
    while (l < t) { m = (unsigned __int128) next(g) * n; l = (uint64_t) m; }
  }
  return (uint64_t) (m >> 64);
}

static void words(const char *what, gen g, int k) {
  for (int i = 0; i < k; i++) printf("%s %016llX\n", what, (unsigned long long) next(&g));
}

int main(void) {
  gen g0 = {0, golden}, g1 = {0x0123456789ABCDEFull, golden};
  words("seed-0", g0, 10);
  words("seed-0123456789ABCDEF", g1, 10);
  gen a = {42, golden};
  gen b = split(&a);
  words("split-left", a, 5);
  words("split-right", b, 5);
  printf("split-right-gamma %016llX\n", (unsigned long long) b.gamma);
  uint64_t ns[] = {1, 6, 1000, 0x8000000000000001ull, 0xFFFFFFFFFFFFFFFFull};
  for (int j = 0; j < 5; j++) {
    gen c = {7, golden};
    for (int i = 0; i < 5; i++)
      printf("below-%016llX %016llX\n", (unsigned long long) ns[j], (unsigned long long) below(&c, ns[j]));
  }
  return 0;
}
