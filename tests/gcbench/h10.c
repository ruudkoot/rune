/* h10.c -- H10, the baselines that turn the models' units into time:
   the latency of a dependent load at each level of the hierarchy (a
   pointer chain through the cache lines of a buffer, in a random cyclic
   order, so that neither the prefetchers nor the out-of-order core hide
   it), with 4 KiB pages and with transparent huge pages; and the
   bandwidth of memcpy, of memset (stores to lines that are not cached,
   which is what allocation does) and of a sequential read.

   latpg is the same chain page by page (a TLB miss every 64 loads), which
   tells the TLB's share of the plain chain's latency from the caches'.

   check=1: the chain is one cycle through every line of the buffer; a
   repetition is 64K loads or one pass of the buffer.

   gcbench h10 [sizes=16K,...,1G] [huge=0|1|both] [what=lat,latpg,bw] [reps=5] */
#include "gcb.h"

/* PG: the chain visits the 64 lines of a page in a random order before it
   goes on to another page (the pages in a random order): the same lines as
   the plain chain, a TLB miss for every 64 loads instead of nearly every one */
static void lat_one(size_t size, int huge, int reps, int pg) {
    size_t n = size / 64;
    char *buf = region(size, huge ? MAP_HUGE : MAP_TOUCH);
    if (huge) fprintf(stderr, "# lat %zu: AnonHugePages %ld KiB\n", size, anon_huge_kb());
    uint32_t *perm = malloc(n * sizeof *perm);
    for (size_t i = 0; i < n; i++) perm[i] = (uint32_t)i;
    uint64_t seed = 0x1234567ULL ^ size;
    if (!pg) shuffle_u32(perm, n, &seed);
    else {
        size_t np = n / 64;
        uint32_t *pages = malloc(np * sizeof *pages);
        for (size_t i = 0; i < np; i++) pages[i] = (uint32_t)i;
        shuffle_u32(pages, np, &seed);
        for (size_t i = 0; i < np; i++) {
            uint32_t lines[64]; for (uint32_t j = 0; j < 64; j++) lines[j] = j;
            shuffle_u32(lines, 64, &seed);
            for (uint32_t j = 0; j < 64; j++) perm[i * 64 + j] = pages[i] * 64 + lines[j];
        }
        free(pages);
    }
    for (size_t i = 0; i < n; i++) *(char **)(buf + (size_t)perm[i] * 64) = buf + (size_t)perm[(i + 1) % n] * 64;
    free(perm);
    size_t steps = size <= (32u << 20) ? (16u << 20) : (4u << 20);
    if (gcb_check) {
        steps = 65536;
        char *q = buf; size_t k = 0;
        do { q = *(char **)q; k++; } while (q != buf && k <= n);
        if (k != n) gcb_fail("H10 lat %zu: the chain is a cycle of %zu lines, not %zu", size, k, n);
    }
    char *p = buf;
    for (size_t i = 0; i < n; i++) p = *(char **)p;   /* warm: every line and page once */
    reps_t r; reps_init(&r);
    for (int k = 0; k < reps; k++) {
        ctrs a, b, d;
        pc_read(&a);
        for (size_t i = 0; i < steps; i += 8) {
            p = *(char **)p; p = *(char **)p; p = *(char **)p; p = *(char **)p;
            p = *(char **)p; p = *(char **)p; p = *(char **)p; p = *(char **)p;
        }
        pc_read(&b);
        ctrs_sub(&d, &b, &a);
        reps_add(&r, &d);
    }
    SINK(p);
    char cas[64], hb[32];
    snprintf(cas, sizeof cas, "%s/%s/%s", pg ? "latpg" : "lat", huge ? "2M" : "4K", human((double)size, hb));
    reps_out(&r, "H10", cas, "load", (double)steps);
    region_free(buf, size);
}

enum { BW_MEMCPY, BW_MEMSET, BW_READ };
static NOINLINE uint64_t read_sum(const uint64_t *p, size_t words) {
    uint64_t s0 = 0, s1 = 0, s2 = 0, s3 = 0;
    for (size_t i = 0; i < words; i += 4) { s0 += p[i]; s1 += p[i + 1]; s2 += p[i + 2]; s3 += p[i + 3]; }
    return s0 + s1 + s2 + s3;
}
static void bw_one(size_t size, int what, int huge, int reps) {
    char *src = region(size, huge ? MAP_HUGE : MAP_TOUCH);
    char *dst = region(size, huge ? MAP_HUGE : MAP_TOUCH);
    memset(src, 1, size);
    /* enough rounds for 256 MiB moved a repetition */
    size_t rounds = (256u << 20) / size; if (rounds < 1 || gcb_check) rounds = 1;
    reps_t r; reps_init(&r);
    uint64_t s = 0;
    for (int k = 0; k < reps + 1; k++) {
        ctrs a, b, d;
        pc_read(&a);
        for (size_t i = 0; i < rounds; i++) {
            if (what == BW_MEMCPY) { memcpy(dst, src, size); SINK(dst); }
            else if (what == BW_MEMSET) { memset(dst, (int)i, size); SINK(dst); }
            else s += read_sum((const uint64_t *)src, size / 8);
        }
        pc_read(&b);
        ctrs_sub(&d, &b, &a);
        if (k) reps_add(&r, &d);   /* the first round warms */
    }
    SINK(s);
    static const char *names[] = { "memcpy", "memset", "read" };
    char cas[64], hb[32];
    snprintf(cas, sizeof cas, "%s/%s/%s", names[what], huge ? "2M" : "4K", human((double)size, hb));
    reps_out(&r, "H10", cas, "byte", (double)size * (double)rounds);
    region_free(src, size); region_free(dst, size);
}

static void exp_h10(void) {
    double sizes[64];
    int ns = opt_list("sizes", "8K,16K,32K,64K,128K,256K,512K,1M,2M,4M,8M,16M,32M,64M,128M,256M,1G", sizes, 64);
    int reps = (int)opt_n("reps", 5);
    const char *hs = opt_s("huge", "both"), *what = opt_s("what", "lat,bw");
    int h0 = strcmp(hs, "1") != 0, h1 = strcmp(hs, "0") != 0;
    for (int h = 0; h < 2; h++) {
        if ((h == 0 && !h0) || (h == 1 && !h1)) continue;
        if (in_list(what, "lat")) for (int i = 0; i < ns; i++) lat_one((size_t)sizes[i], h, reps, 0);
        if (in_list(what, "latpg")) for (int i = 0; i < ns; i++) lat_one((size_t)sizes[i], h, reps, 1);
        if (in_list(what, "bw"))
            for (int w = 0; w < 3; w++)
                for (int i = 0; i < ns; i++) bw_one((size_t)sizes[i], w, h, reps);
    }
}
