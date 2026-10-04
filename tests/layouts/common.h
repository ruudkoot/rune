/* common.h -- what every layout header and every kernel share: the object
   kinds (vm.h's, plus K_BOX for a raw 8-byte payload the layout cannot hold
   immediate), the cycle counter, the checksum, and the helpers. C17. */
#ifndef HARNESS_COMMON_H
#define HARNESS_COMMON_H
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <x86intrin.h>

/* vm.h's ObjKind, plus K_BOX: one raw 8-byte payload (a real in L1/L2, a
   64-bit int/word in L1/L2/L3, an int/real at a polymorphic position in
   L4); the collector never scans a box's payload. */
enum { K_TUPLE = 1, K_CON, K_CLOSURE, K_STRING, K_REF, K_ARRAY, K_EXN, K_EXNCON, K_FORWARD, K_BOX,
       /* a lazy front end's two (docs/plans/heap-layout.md, *A lazy front end*):
          a suspension, and what it becomes once it has its value */
       K_THUNK, K_IND };

#define LIKELY(x) __builtin_expect(!!(x), 1)
#define UNLIKELY(x) __builtin_expect(!!(x), 0)
#define NOINLINE __attribute__((noinline))
#define ALWAYS_INLINE static inline __attribute__((always_inline))
/* keep a value alive / stop hoisting: the value must be produced */
#define SINK(x) __asm__ __volatile__("" :: "r"(x) : "memory")
#define SINK_D(x) __asm__ __volatile__("" :: "x"(x) : "memory")

static inline uint64_t cycles_now(void) { unsigned aux; return __rdtscp(&aux); }

/* FNV-1a over 64-bit words: every kernel result goes through ck_add */
static uint64_t ck_h = 0xcbf29ce484222325ULL;
static inline void ck_add(uint64_t x) { ck_h ^= x; ck_h *= 0x100000001b3ULL; }
static inline void ck_add_d(double d) { uint64_t u; memcpy(&u, &d, 8); ck_add(u); }
static inline void ck_add_bytes(const char *p, size_t n) { for (size_t i = 0; i < n; i++) ck_add((unsigned char)p[i]); }

static inline void die(const char *msg) { fprintf(stderr, "harness: %s\n", msg); exit(2); }

static inline uint64_t xorshift64(uint64_t *s) {
    uint64_t x = *s; x ^= x << 13; x ^= x >> 7; x ^= x << 17; return *s = x;
}
#endif
