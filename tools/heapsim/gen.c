/* gen.c -- a synthetic allocation-trace generator in the census VM's format
   (docs/census.md, format 2: the word layout's sizes, layouts.h
   w8_obj_size), for unit-testing the simulators. It also computes, with
   exact liveness (every object has a planned death clock), what the stock
   collector (runtime/heap.c's policy) would do on the trace, so sim's
   copier can be checked against an independent implementation, and it
   writes death.bin/samples.bin from the same death clocks by different code
   paths than sim reads them with. --pattern writes the traces of gcsim's
   closed-form tests (pattern_main).

   gen --out DIR [--objects N] [--sample BYTES] [--seed S] [--heap-size H] [--heap-fill P]
   gen --out DIR --pattern alt|satb|line1|nurs [--size S] [--count M] [--keep K] [--nursery-bytes N] [--windows W] [--stores K]
   prints one line:  truth objects N bytes B samples K collections C semispace S copied X live Y
   (--pattern: pattern P objects N bytes B samples K)
   built as bin/heapsim-gen by the Makefile */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <errno.h>
#include <sys/stat.h>
#include "census/layouts.h"

enum { K_TUPLE = 1, K_CON, K_CLOSURE, K_STRING, K_REF, K_ARRAY, K_EXN, K_EXNCON };
enum { T_UNIT = 0, T_INT, T_WORD, T_REAL, T_CHAR, T_CON0, T_PTR };
#define INF UINT64_MAX

static uint64_t rng_state = 0x9E3779B97F4A7C15ull;
static uint64_t rnd(void) {           /* splitmix64 */
    uint64_t z = (rng_state += 0x9E3779B97F4A7C15ull);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
    return z ^ (z >> 31);
}
static uint64_t rnd_below(uint64_t n) { return n ? rnd() % n : 0; }
static int chance(int pct) { return (int)rnd_below(100) < pct; }

static size_t objsize(uint8_t kind, uint32_t len) { return w8_obj_size(kind, len); }

/* per object */
static uint64_t *ob_b, *ob_e;      /* birth clock, death clock (INF) */
static uint8_t *ob_kind;
static uint32_t *ob_len;
static uint32_t nobj, cap;
static uint64_t clock_now;         /* bytes allocated so far */
static uint64_t *sample_clock;     /* index 1.. */
static uint32_t *sample_last;      /* the objects allocated before sample k */
static uint64_t nstores;
static uint32_t nsamples, scap;
static uint64_t sample_every, next_sample;

static FILE *f_alloc, *f_fields, *f_stores;

static void put_u8(FILE *f, unsigned v) { fputc((int)v, f); }
static void put_u16(FILE *f, unsigned v) { put_u8(f, v & 255); put_u8(f, v >> 8); }
static void put_u32(FILE *f, uint32_t v) { for (int i = 0; i < 4; i++) put_u8(f, (v >> (8 * i)) & 255); }
static void put_u64(FILE *f, uint64_t v) { for (int i = 0; i < 8; i++) put_u8(f, (unsigned)((v >> (8 * i)) & 255)); }

/* a field's two bytes: byte 0 the word (1 a pointer) and the pointee's
   kind, byte 1 the rep and the bits class */
static void field(unsigned tag, unsigned pkind, unsigned bc, unsigned rep) {
    put_u8(f_fields, tag == 6 /* T_PTR */ ? (1 | ((pkind & 15) << 2)) : 0);
    put_u8(f_fields, (rep & 15) | ((bc & 7) << 4));
}

/* allocate: returns the id; fields must be written by the caller (len of them) */
static uint32_t alloc(uint8_t kind, uint16_t contag, uint32_t len, uint64_t lifetime, uint32_t site, uint32_t func, uint8_t site_kind) {
    if (clock_now >= next_sample) {
        if (nsamples + 2 > scap) { scap = scap ? scap * 2 : 1024; sample_clock = realloc(sample_clock, scap * sizeof *sample_clock); sample_last = realloc(sample_last, scap * sizeof *sample_last); }
        sample_clock[++nsamples] = clock_now; sample_last[nsamples] = nobj;
        next_sample += sample_every;
    }
    if (nobj + 2 > cap) {
        cap = cap ? cap * 2 : 1 << 16;
        ob_b = realloc(ob_b, cap * sizeof *ob_b); ob_e = realloc(ob_e, cap * sizeof *ob_e);
        ob_kind = realloc(ob_kind, cap); ob_len = realloc(ob_len, cap * sizeof *ob_len);
    }
    uint32_t id = ++nobj;
    ob_b[id] = clock_now;
    ob_e[id] = lifetime == INF ? INF : clock_now + lifetime;
    ob_kind[id] = kind; ob_len[id] = len;
    put_u8(f_alloc, kind); put_u8(f_alloc, site_kind); put_u16(f_alloc, contag);
    put_u32(f_alloc, len); put_u32(f_alloc, site); put_u32(f_alloc, func);
    clock_now += objsize(kind, len);
    return id;
}

/* the old value is not modelled: never a pointer */
static void store(uint32_t src, uint32_t dst, unsigned fld, unsigned site, unsigned rep) {
    put_u32(f_stores, (uint32_t)(clock_now / 8));
    put_u32(f_stores, src); put_u32(f_stores, dst);
    put_u32(f_stores, 0);
    put_u32(f_stores, fld); put_u8(f_stores, site);
    put_u8(f_stores, dst ? 2 : 0);
    put_u8(f_stores, rep & 15); put_u8(f_stores, ob_kind[src]);
    nstores++;
}

/* lifetimes: 0..4 KiB short, up to 256 KiB medium, up to 8 MiB long, INF */
static uint64_t life_short(void) { return rnd_below(4096); }
static uint64_t life_medium(void) { return 4096 + rnd_below(256 << 10); }
static uint64_t life_long(void) { return (256 << 10) + rnd_below(8 << 20); }
static uint64_t life_mixed(void) {
    unsigned r = (unsigned)rnd_below(100);
    if (r < 70) return life_short();
    if (r < 90) return life_medium();
    if (r < 98) return life_long();
    return INF;
}

static int alive_at(uint32_t id, uint64_t c) { return ob_b[id] < c && ob_e[id] > c; }

/* --- the stock collector, exactly, with exact liveness --- */
static unsigned heap_fill = 50;
static size_t fill_of(size_t n) { return n / 100 * heap_fill + n % 100 * heap_fill / 100; }
static size_t grown(size_t size, size_t used, size_t needed) {
    size_t want = size;
    while (used > fill_of(want) || needed > fill_of(want) - used) want *= 2;
    return want;
}
static size_t live_at(uint64_t c, uint32_t upto) {
    size_t s = 0;
    for (uint32_t i = 1; i < upto; i++) if (alive_at(i, c)) s += objsize(ob_kind[i], ob_len[i]);
    return s;
}
static void truth(size_t heap_size, size_t *ncoll, size_t *semispace, uint64_t *copied, size_t *live_exit) {
    size_t heap_used = 0, live_last = 0, live_before = 0, gc = 0; uint64_t cp = 0;
    for (uint32_t id = 1; id <= nobj; id++) {
        size_t size = objsize(ob_kind[id], ob_len[id]);
        if (size > heap_size - heap_used) {
            size_t live = live_at(ob_b[id], id);
            size_t guess = live_last;
            if (live_last > live_before) {
                guess += live_last - live_before;
                if (guess < live_last || guess > heap_size) guess = heap_size;
            }
            size_t ns = grown(heap_size, guess, size);
            heap_used = live; heap_size = ns; gc++; cp += live;
            size_t want = grown(heap_size, heap_used, size);
            if (want != heap_size) { heap_size = want; gc++; cp += live; }
            live_before = live_last; live_last = heap_used;
        }
        heap_used += size;
    }
    *ncoll = gc; *semispace = heap_size; *copied = cp; *live_exit = heap_used;
}

/* ---- --pattern: closed-form traces ----
   Every object's death window is chosen, and the samples fall where the
   pattern says, so each model's answer can be written down beforehand
   (tools/heapsim/test2.sh holds them to it).
     alt   --size S --count M: M objects of S bytes; the odd ones (the first
           included) die before sample 1, the even ones never; then M/2 more
           of S bytes that never die (sample 2), then one more (sample 3).
     satb  --size S --count M: M objects of S bytes, the odd ones dying in
           window 1 (after sample 1); M more that never die (sample 2); one
           more (sample 3).
     line1 --size S --count M --keep K: M objects of S bytes; object i lives
           for ever when (i-1) % K == 0, else dies before sample 1; one more.
     nurs  --nursery-bytes N --windows W --size S --stores K: window 0 an
           immortal array of 255 fields (2048 bytes) and short-lived
           objects to N bytes; windows 1..W-1 N/S objects each, the first
           half dying in the window, the second half in the next; K stores of
           young objects into the array's fields 0..K-1 in windows 2..W-1;
           a sample every N bytes. */
static FILE *p_alloc, *p_fields, *p_death, *p_stores;
static uint64_t p_clock; static uint32_t p_n;
static uint64_t *p_samples; static uint32_t p_nsamples, p_scap; static uint64_t *p_sample_last;
static uint64_t *p_birth; static uint32_t *p_size, *p_dwin; static uint32_t p_cap;
static uint32_t p_alloc_obj(uint8_t kind, uint32_t len, uint32_t dwin) {   /* dwin: the window it dies in, UINT32_MAX never */
    if (p_n + 2 > p_cap) { p_cap = p_cap ? p_cap * 2 : 1 << 16; p_birth = realloc(p_birth, p_cap * 8ull); p_size = realloc(p_size, p_cap * 4ull); p_dwin = realloc(p_dwin, p_cap * 4ull); }
    uint32_t id = ++p_n;
    p_birth[id] = p_clock; p_size[id] = (uint32_t)objsize(kind, len); p_dwin[id] = dwin;
    put_u8(p_alloc, kind); put_u8(p_alloc, 0); put_u16(p_alloc, 0); put_u32(p_alloc, len); put_u32(p_alloc, 1000 + kind); put_u32(p_alloc, 1);
    if (kind != K_STRING) for (uint32_t f = 0; f < len; f++) { put_u8(p_fields, 0); put_u8(p_fields, 15); }
    p_clock += p_size[id];
    return id;
}
static void p_sample(void) {
    if (p_nsamples + 2 > p_scap) { p_scap = p_scap ? p_scap * 2 : 64; p_samples = realloc(p_samples, p_scap * 8ull); p_sample_last = realloc(p_sample_last, p_scap * 8ull); }
    p_nsamples++; p_samples[p_nsamples] = p_clock; p_sample_last[p_nsamples] = p_n;
}
static void p_store(uint32_t src, uint32_t dst, uint32_t field) {
    put_u32(p_stores, (uint32_t)(p_clock / 8)); put_u32(p_stores, src); put_u32(p_stores, dst); put_u32(p_stores, 0);
    put_u32(p_stores, field); put_u8(p_stores, 2); put_u8(p_stores, 2); put_u8(p_stores, 6); put_u8(p_stores, K_ARRAY);
}
static int pattern_main(const char *out, const char *pattern, uint32_t size, uint32_t count, uint32_t keep, uint64_t nbytes, uint32_t windows, uint32_t nstores) {
    if (mkdir(out, 0755) && errno != EEXIST) { perror(out); return 2; }
    char path[4096];
#define POPEN(var, name) snprintf(path, sizeof path, "%s/%s", out, name); var = fopen(path, "wb"); if (!var) { perror(path); return 2; }
    POPEN(p_alloc, "alloc.bin"); POPEN(p_fields, "fields.bin"); POPEN(p_stores, "stores.bin");
    for (int i = 0; i < 16; i++) put_u8(p_alloc, 0);
    if (size < 16 || size % 8) { fprintf(stderr, "gen: --size must be a multiple of 8, at least 16\n"); return 2; }
    uint32_t len = (size - 8) / 8;
    if (!strcmp(pattern, "alt")) {
        for (uint32_t i = 1; i <= count; i++) p_alloc_obj(K_TUPLE, len, i % 2 ? 0 : UINT32_MAX);
        p_sample();
        for (uint32_t i = 0; i < count / 2; i++) p_alloc_obj(K_TUPLE, len, UINT32_MAX);
        p_sample();
        p_alloc_obj(K_TUPLE, 1, UINT32_MAX);
        p_sample();
    } else if (!strcmp(pattern, "satb")) {
        /* SATB: M objects, the odd ones dying just after sample 1 (window 1), then M black objects that live */
        for (uint32_t i = 1; i <= count; i++) p_alloc_obj(K_TUPLE, len, i % 2 ? 1 : UINT32_MAX);
        p_sample();
        for (uint32_t i = 0; i < count; i++) p_alloc_obj(K_TUPLE, len, UINT32_MAX);
        p_sample();
        p_alloc_obj(K_TUPLE, 1, UINT32_MAX);
        p_sample();
    } else if (!strcmp(pattern, "line1")) {
        for (uint32_t i = 1; i <= count; i++) p_alloc_obj(K_TUPLE, len, (i - 1) % keep == 0 ? UINT32_MAX : 0);
        p_sample();
        p_alloc_obj(K_TUPLE, 1, UINT32_MAX);
        p_sample();
    } else if (!strcmp(pattern, "nurs")) {
        uint32_t arr = p_alloc_obj(K_ARRAY, 255, UINT32_MAX);
        while (p_clock + size <= nbytes) p_alloc_obj(K_TUPLE, len, 0);
        if (p_clock != nbytes) { fprintf(stderr, "gen: --nursery-bytes must be a multiple of --size past 2048\n"); return 2; }
        p_sample();
        uint32_t per = (uint32_t)(nbytes / size);
        for (uint32_t w = 1; w < windows; w++) {
            uint32_t first = p_n + 1;
            for (uint32_t i = 0; i < per; i++) p_alloc_obj(K_TUPLE, len, i < per / 2 ? w : w + 1);
            if (w >= 2) for (uint32_t j = 0; j < nstores; j++) p_store(arr, first + per / 2 + j % (per - per / 2), j);
            p_sample();
        }
    } else { fprintf(stderr, "gen: unknown pattern %s\n", pattern); return 2; }
    fclose(p_alloc); fclose(p_fields); fclose(p_stores);
    /* death.bin: the last sample at which each object was alive; samples.bin: 64 bytes a sample */
    POPEN(p_death, "death.bin");
    put_u32(p_death, 0);
    uint64_t *live_b = calloc(p_nsamples + 2, 8), *live_o = calloc(p_nsamples + 2, 8);
    for (uint32_t id = 1; id <= p_n; id++) {
        /* born in window w (the samples before it), dies in window dwin: alive at samples w+1 .. dwin */
        uint32_t w = 0; while (w < p_nsamples && p_sample_last[w + 1] < id) w++;
        uint32_t d = p_dwin[id];
        uint32_t last = d == UINT32_MAX ? p_nsamples : d;
        uint32_t rec = d == UINT32_MAX ? 0xFFFFFFFFu : (last >= w + 1 ? last : 0);
        put_u32(p_death, rec);
        for (uint32_t k = w + 1; k <= last && k <= p_nsamples; k++) { live_b[k] += p_size[id]; live_o[k]++; }
    }
    fclose(p_death);
    FILE *f; POPEN(f, "samples.bin");
    for (uint32_t k = 1; k <= p_nsamples; k++) {
        put_u64(f, p_samples[k]); put_u64(f, live_b[k]); put_u64(f, live_o[k]); put_u64(f, p_samples[k] / 4); put_u64(f, p_sample_last[k]);
        put_u32(f, 100); put_u32(f, 5); put_u32(f, 3); put_u32(f, 40); put_u32(f, 50); put_u32(f, k == p_nsamples ? 2 : 1);
    }
    fclose(f);
    POPEN(f, "meta.txt");
    fprintf(f, "format 2\nlayout W8\nobjects %u\nbytes %" PRIu64 "\nsamples %u\ninstructions %" PRIu64 "\npattern %s\n", p_n, p_clock, p_nsamples, p_clock / 4, pattern);
    fclose(f);
    POPEN(f, "DONE"); fprintf(f, "pattern %s\n", pattern); fclose(f);
    printf("pattern %s objects %u bytes %" PRIu64 " samples %u\n", pattern, p_n, p_clock, p_nsamples);
    return 0;
}

int main(int argc, char **argv) {
    const char *out = NULL; uint32_t want_objects = 300000; uint64_t seed = 1; size_t heap_size = 4u << 20;
    const char *pattern = NULL; uint32_t psize = 32, pcount = 4096, pkeep = 8, pwin = 8, pstores = 100; uint64_t pnb = 65536;
    sample_every = 64 << 10;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--pattern") && i + 1 < argc) { pattern = argv[++i]; continue; }
        if (!strcmp(argv[i], "--size") && i + 1 < argc) { psize = (uint32_t)strtoul(argv[++i], 0, 0); continue; }
        if (!strcmp(argv[i], "--count") && i + 1 < argc) { pcount = (uint32_t)strtoul(argv[++i], 0, 0); continue; }
        if (!strcmp(argv[i], "--keep") && i + 1 < argc) { pkeep = (uint32_t)strtoul(argv[++i], 0, 0); continue; }
        if (!strcmp(argv[i], "--windows") && i + 1 < argc) { pwin = (uint32_t)strtoul(argv[++i], 0, 0); continue; }
        if (!strcmp(argv[i], "--stores") && i + 1 < argc) { pstores = (uint32_t)strtoul(argv[++i], 0, 0); continue; }
        if (!strcmp(argv[i], "--nursery-bytes") && i + 1 < argc) { pnb = strtoull(argv[++i], 0, 0); continue; }
        if (!strcmp(argv[i], "--out") && i + 1 < argc) out = argv[++i];
        else if (!strcmp(argv[i], "--objects") && i + 1 < argc) want_objects = (uint32_t)strtoull(argv[++i], 0, 0);
        else if (!strcmp(argv[i], "--sample") && i + 1 < argc) sample_every = strtoull(argv[++i], 0, 0);
        else if (!strcmp(argv[i], "--seed") && i + 1 < argc) seed = strtoull(argv[++i], 0, 0);
        else if (!strcmp(argv[i], "--heap-size") && i + 1 < argc) heap_size = strtoull(argv[++i], 0, 0);
        else if (!strcmp(argv[i], "--heap-fill") && i + 1 < argc) heap_fill = (unsigned)strtoul(argv[++i], 0, 0);
        else { fprintf(stderr, "usage: gen --out DIR [--objects N] [--sample BYTES] [--seed S] [--heap-size H] [--heap-fill P]\n"
                               "       gen --out DIR --pattern alt|satb|line1|nurs [--size S] [--count M] [--keep K] [--nursery-bytes N] [--windows W] [--stores K]\n"); return 2; }
    }
    if (!out) { fprintf(stderr, "gen: --out DIR required\n"); return 2; }
    if (pattern) return pattern_main(out, pattern, psize, pcount, pkeep, pnb, pwin, pstores);
    rng_state = seed * 0x9E3779B97F4A7C15ull + 12345; for (int w = 0; w < 4; w++) rng_state = (rng_state ^ (rng_state >> 29)) * 0xBF58476D1CE4E5B9ull + seed;
    if (mkdir(out, 0755) && errno != EEXIST) { perror(out); return 2; }
    char path[4096];
#define OPEN(var, name) snprintf(path, sizeof path, "%s/%s", out, name); var = fopen(path, "wb"); if (!var) { perror(path); return 2; }
    OPEN(f_alloc, "alloc.bin"); OPEN(f_fields, "fields.bin"); OPEN(f_stores, "stores.bin");
    /* record 0 = no object */
    for (int i = 0; i < 16; i++) put_u8(f_alloc, 0);
    next_sample = sample_every;

    /* the old pool: refs, arrays and closures that live for ever, targets of stores */
    enum { NOLD = 64 };
    uint32_t old[NOLD];
    for (int i = 0; i < NOLD; i++) {
        int k = i % 3;
        if (k == 0) { old[i] = alloc(K_REF, 0, 1, INF, 0xFFFFFFFF, 0xFFFFFFFF, 2); field(T_INT, 0, 0, 1); }
        else if (k == 1) { uint32_t n = 4 + (uint32_t)rnd_below(60); old[i] = alloc(K_ARRAY, 0, n, INF, 100, 1, 1); for (uint32_t j = 0; j < n; j++) field(T_INT, 0, 0, 15); }
        else { old[i] = alloc(K_CLOSURE, 0, 3, INF, 200, 1, 0); field(T_INT, 0, 1, 1); field(T_UNIT, 0, 0, 8); field(T_UNIT, 0, 0, 8); }
    }
    uint32_t tree_last = 0, recent_ptr = 0; uint8_t recent_kind = K_TUPLE;
    while (nobj < want_objects) {
        unsigned r = (unsigned)rnd_below(100);
        uint32_t id;
        if (r < 55) {                                   /* short-lived tuples */
            uint32_t n = 2 + (uint32_t)rnd_below(3);
            id = alloc(K_TUPLE, 0, n, life_short(), 1000 + n, 7, 0);
            for (uint32_t j = 0; j < n; j++) {
                unsigned c = (unsigned)rnd_below(10);
                if (c < 5) field(T_INT, 0, chance(80) ? 0 : 1, chance(70) ? 1 : 0);
                else if (c < 8 && recent_ptr) field(T_PTR, recent_kind, 0, 6);
                else if (c < 9) field(T_CHAR, 0, 0, 4);
                else field(T_CON0, 0, 0, 5);
            }
            recent_ptr = id; recent_kind = K_TUPLE;
        } else if (r < 70) {                            /* the growing tree */
            uint32_t n = 1 + (uint32_t)rnd_below(3);
            uint64_t life = chance(30) ? INF : life_long();
            id = alloc(K_CON, (uint16_t)rnd_below(4), n, life, 2000 + n, 9, 0);
            for (uint32_t j = 0; j < n; j++) {
                if (j == 0 && tree_last) field(T_PTR, K_CON, 0, 7);
                else field(T_INT, 0, chance(90) ? 1 : 2, 1);
            }
            tree_last = id; recent_ptr = id; recent_kind = K_CON;
        } else if (r < 76) {                            /* strings */
            uint32_t n = 1 + (uint32_t)rnd_below(300);
            id = alloc(K_STRING, 0, n, life_mixed(), 3000, 11, 1);
        } else if (r < 81) {                            /* arrays: mostly homogeneous */
            uint32_t n = 8 + (uint32_t)rnd_below(500);
            unsigned et = (unsigned)rnd_below(3);       /* 0 int, 1 real, 2 char */
            int hetero = chance(20);
            id = alloc(K_ARRAY, 0, n, life_medium(), 4000 + et, 13, 1);
            for (uint32_t j = 0; j < n; j++) {
                if (hetero && j == n / 2) { field(T_PTR, K_TUPLE, 0, 15); continue; }
                if (et == 0) field(T_INT, 0, 1, 15);
                else if (et == 1) field(T_REAL, 0, chance(95) ? 0 : 7, 15);
                else field(T_CHAR, 0, 0, 15);
            }
        } else if (r < 86) {                            /* closures */
            uint32_t n = 2 + (uint32_t)rnd_below(4);
            id = alloc(K_CLOSURE, 0, n, life_mixed(), 5000 + n, 17, 0);
            field(T_INT, 0, 1, 1);
            for (uint32_t j = 1; j < n; j++) {
                if (chance(50) && recent_ptr) field(T_PTR, recent_kind, 0, 6);
                else if (chance(30)) field(T_REAL, 0, chance(90) ? 0 : 7, 3);
                else field(T_INT, 0, 0, chance(50) ? 1 : 0);
            }
            recent_ptr = id; recent_kind = K_CLOSURE;
        } else if (r < 91) {                            /* refs */
            id = alloc(K_REF, 0, 1, life_medium(), 6000, 19, 1);
            if (chance(50) && recent_ptr) field(T_PTR, recent_kind, 0, 15); else field(T_INT, 0, 0, 15);
        } else if (r < 97) {                            /* reals and 64-bit words in tuples */
            uint32_t n = 2 + (uint32_t)rnd_below(3);
            id = alloc(K_TUPLE, 0, n, chance(60) ? life_short() : life_medium(), 7000 + n, 23, 0);
            for (uint32_t j = 0; j < n; j++) {
                if (chance(60)) field(T_REAL, 0, chance(90) ? 0 : 7, chance(80) ? 3 : 0);
                else field(T_WORD, 0, chance(50) ? 6 : (chance(50) ? 4 : 0), chance(80) ? 2 : 0);
            }
            recent_ptr = id; recent_kind = K_TUPLE;
        } else {                                        /* exceptions */
            if (chance(50)) { id = alloc(K_EXNCON, 0, 1, INF, 8000, 29, 0); field(T_PTR, K_STRING, 0, 6); }
            else { id = alloc(K_EXN, 0, 2, life_short(), 8001, 29, 0); field(T_PTR, K_EXNCON, 0, 6); field(T_INT, 0, 0, 1); }
        }
        if (chance(30)) {                               /* a store into an old object */
            uint32_t src = old[rnd_below(NOLD)];
            unsigned site = ob_kind[src] == K_REF ? 1 : ob_kind[src] == K_ARRAY ? 2 : 0;
            unsigned fld = ob_kind[src] == K_CLOSURE ? 1 + (unsigned)rnd_below(2) : (unsigned)rnd_below(ob_len[src]);
            if (chance(60) && recent_ptr) store(src, recent_ptr, fld, site, 6);
            else if (chance(30)) store(src, 0, fld, site, chance(70) ? 3 : 0);
            else store(src, 0, fld, site, chance(70) ? 1 : 0);
        }
        if (chance(3)) {                                /* a store into a young ref */
            uint32_t src = nobj;                        /* the object just made, when it is a ref */
            if (ob_kind[src] == K_REF && recent_ptr) store(src, recent_ptr, 0, 1, 6);
        }
    }
    fclose(f_alloc); fclose(f_fields); fclose(f_stores);
    uint64_t total = clock_now;

    /* death.bin and samples.bin from the death clocks: object id is alive at
       sample k iff b < clock[k] < e. */
    FILE *f;
    OPEN(f, "death.bin");
    put_u32(f, 0);
    uint64_t *live_b = calloc(nsamples + 2, sizeof *live_b), *live_o = calloc(nsamples + 2, sizeof *live_o);
    for (uint32_t id = 1; id <= nobj; id++) {
        uint64_t b = ob_b[id], e = ob_e[id];
        /* k_lo = first k with clock[k] > b; k_hi = last k with clock[k] < e */
        uint32_t lo = 1, hi = nsamples, k_lo = nsamples + 1, k_hi = 0;
        while (lo <= hi) { uint32_t m = (lo + hi) / 2; if (sample_clock[m] > b) { k_lo = m; hi = m - 1; } else lo = m + 1; }
        lo = 1; hi = nsamples;
        while (lo <= hi) { uint32_t m = (lo + hi) / 2; if (sample_clock[m] < e) { k_hi = m; lo = m + 1; } else hi = m - 1; }
        uint32_t d;
        if (e >= total) d = 0xFFFFFFFFu;              /* alive at exit */
        else if (k_lo <= k_hi) d = k_hi;
        else d = 0;
        put_u32(f, d);
        if (k_lo <= k_hi) { live_b[k_lo] += objsize(ob_kind[id], ob_len[id]); live_b[k_hi + 1] -= objsize(ob_kind[id], ob_len[id]); live_o[k_lo]++; live_o[k_hi + 1]--; }
    }
    fclose(f);
    /* 64 bytes a sample: the clock, the live data, a mutator clock of an
       instruction every 4 bytes, the ids before it; the stack is not
       modelled; every sample forced (flags bit 0) */
    OPEN(f, "samples.bin");
    uint64_t lb = 0, lo_ = 0;
    for (uint32_t k = 1; k <= nsamples; k++) {
        lb += live_b[k]; lo_ += live_o[k];
        put_u64(f, sample_clock[k]); put_u64(f, lb); put_u64(f, lo_); put_u64(f, sample_clock[k] / 4); put_u64(f, sample_last[k]);
        for (int z = 0; z < 5; z++) put_u32(f, 0);
        put_u32(f, 1);
    }
    fclose(f);
    OPEN(f, "pcs.bin"); fclose(f);
    OPEN(f, "census.txt");
    fprintf(f, "synthetic trace (gen.c) seed %" PRIu64 "\nobjects %u bytes %" PRIu64 " samples %u\n", seed, nobj, total, nsamples);
    fclose(f);
    OPEN(f, "meta.txt");
    fprintf(f, "format 2\nlayout W8\nevery %" PRIu64 "\nfields 1\ngraph 0\nsummary 0\nobjects %u\nbytes %" PRIu64 "\ncount_objects %u\ncount_bytes %" PRIu64 "\n"
               "boxes 0\nbox_bytes 0\npretrace_objects 0\npretrace_bytes 0\nsamples %u\nstores %" PRIu64 "\ninstructions %" PRIu64 "\n",
            sample_every, nobj, total, nobj, total, nsamples, nstores, total / 4);
    fclose(f);
    OPEN(f, "DONE"); fprintf(f, "synthetic seed %" PRIu64 "\n", seed); fclose(f);

    size_t nc, ss, le; uint64_t cp;
    truth(heap_size, &nc, &ss, &cp, &le);
    printf("truth objects %u bytes %" PRIu64 " samples %u collections %zu semispace %zu copied %" PRIu64 " live %zu\n",
           nobj, total, nsamples, nc, ss, cp, le);
    return 0;
}
