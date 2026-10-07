/* h9.c -- H9, pages and memory: what the kernel charges a collector that
   takes memory from it and gives it back. Time is the TSC's (the counters
   count user mode only; these costs are the kernel's), per 4 KiB page
   unless said; page faults from getrusage beside it (stderr).

   touch/4K, touch/2M   first touch of fresh anonymous memory, one write per
                        page (MADV_HUGEPAGE on a 2 MiB aligned range for 2M)
   mmap-munmap          mmap of a block and munmap of it, untouched: per call
   mmap-touch-munmap    the same with every page written: per page
   malloc-touch-free    glibc malloc of the block, every page written, free:
                        per page (glibc maps blocks over its threshold itself)
   dontneed             madvise(MADV_DONTNEED) of a touched block: per page
   refault              the first write after it (a zero page again): per page
   free-lazy            madvise(MADV_FREE): per page; then the write after it
   (Windows: VirtualAlloc(MEM_RESERVE) and (MEM_COMMIT) for the reservation
   and the commit, VirtualFree(MEM_DECOMMIT) for dontneed; not measurable here.)

   check=1: a page given back with MADV_DONTNEED reads as zeros again, which
   is what a collector that returns memory relies on; two iterations a
   repetition.

   gcbench h9 [block=32K,256K,1M,32M] [touch=256M] [reps=5] */
#include "gcb.h"

static void h9_row(const char *cas, const char *unit, double n, ctrs *best, int reps, uint64_t faults) {
    out_row("H9", cas, unit, n, best, (double)ctrs_cyc(best), reps);
    fprintf(stderr, "# H9 %s: %.3f page faults per %s\n", cas, (double)faults / n, unit);
}
#define H9_TIME(body, best, faults) do { \
    ctrs a_, b_, d_; uint64_t f0_ = minflt(); pc_read(&a_); body; pc_read(&b_); \
    ctrs_sub(&d_, &b_, &a_); if (!(best).tsc || d_.tsc < (best).tsc) { best = d_; faults = minflt() - f0_; } } while (0)

/* madvise(ADVICE) of a touched block, then a write to every page: both timed */
static void h9_advise(char *blk, size_t bs, size_t iters, int advice, int reps, const char *n1, const char *n2) {
    size_t pages = bs / 4096;
    ctrs bd, br; memset(&bd, 0, sizeof bd); memset(&br, 0, sizeof br); uint64_t fd = 0, fr = 0;
    for (int r = 0; r < reps; r++) {
        ctrs acc_d, acc_r; memset(&acc_d, 0, sizeof acc_d); memset(&acc_r, 0, sizeof acc_r);
        uint64_t fdd = 0, frr = 0;
        for (size_t i = 0; i < iters; i++) {
            ctrs a, b, c;
            uint64_t f0 = minflt();
            pc_read(&a); madvise(blk, bs, advice); pc_read(&b);
            uint64_t f1 = minflt();
            if (gcb_check && advice == MADV_DONTNEED)
                for (size_t j = 0; j < bs; j += 4096)
                    if (((volatile char *)blk)[j]) { gcb_fail("H9: a page after MADV_DONTNEED does not read as zero"); break; }
            for (size_t j = 0; j < bs; j += 4096) blk[j] = 1;
            pc_read(&c);
            fdd += f1 - f0; frr += minflt() - f1;
            ctrs_add_delta(&acc_d, &a, &b); ctrs_add_delta(&acc_r, &b, &c);
        }
        if (!bd.tsc || acc_d.tsc < bd.tsc) { bd = acc_d; fd = fdd; }
        if (!br.tsc || acc_r.tsc < br.tsc) { br = acc_r; fr = frr; }
    }
    char cas[96], hb[32];
    snprintf(cas, sizeof cas, "%s/%s", n1, human((double)bs, hb)); h9_row(cas, "page", (double)(iters * pages), &bd, reps, fd);
    snprintf(cas, sizeof cas, "%s/%s", n2, human((double)bs, hb)); h9_row(cas, "page", (double)(iters * pages), &br, reps, fr);
}

static void exp_h9(void) {
    double blocks[16]; int nb = opt_list("block", "32K,256K,1M,32M", blocks, 16);
    size_t touch = (size_t)opt_n("touch", 256.0 * 1048576);
    int reps = (int)opt_n("reps", 5);
    char cas[96], hb[32];
    for (int huge = 0; huge < 2; huge++) {
        ctrs best; memset(&best, 0, sizeof best); uint64_t faults = 0;
        for (int r = 0; r < reps; r++) {
            size_t h = (size_t)2 << 20;
            char *q = mmap(NULL, touch + h, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
            if (q == MAP_FAILED) die("mmap");
            char *p = (char *)rup((uintptr_t)q, h);
            madvise(p, touch, huge ? MADV_HUGEPAGE : MADV_NOHUGEPAGE);
            H9_TIME(for (size_t i = 0; i < touch; i += 4096) p[i] = 1, best, faults);
            if (r == 0 && huge) fprintf(stderr, "# H9 touch/2M: AnonHugePages %ld KiB\n", anon_huge_kb());
            munmap(q, touch + h);
        }
        snprintf(cas, sizeof cas, "touch/%s/%s", huge ? "2M" : "4K", human((double)touch, hb));
        h9_row(cas, "page", (double)(touch / 4096), &best, reps, faults);
    }
    for (int bi = 0; bi < nb; bi++) {
        size_t bs = (size_t)blocks[bi], pages = bs / 4096;
        size_t iters = (64u << 20) / bs; if (iters < 4) iters = 4; if (iters > 4096) iters = 4096;
        if (gcb_check) iters = 2;
        ctrs best; uint64_t faults;
        memset(&best, 0, sizeof best); faults = 0;
        for (int r = 0; r < reps; r++)
            H9_TIME(for (size_t i = 0; i < iters; i++) { void *p = mmap(NULL, bs, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0); SINK(p); munmap(p, bs); }, best, faults);
        snprintf(cas, sizeof cas, "mmap-munmap/%s", human((double)bs, hb)); h9_row(cas, "call", (double)iters, &best, reps, faults);
        memset(&best, 0, sizeof best); faults = 0;
        for (int r = 0; r < reps; r++)
            H9_TIME(for (size_t i = 0; i < iters; i++) { char *p = mmap(NULL, bs, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0); for (size_t j = 0; j < bs; j += 4096) p[j] = 1; munmap(p, bs); }, best, faults);
        snprintf(cas, sizeof cas, "mmap-touch-munmap/%s", human((double)bs, hb)); h9_row(cas, "page", (double)(iters * pages), &best, reps, faults);
        memset(&best, 0, sizeof best); faults = 0;
        for (int r = 0; r < reps; r++)
            H9_TIME(for (size_t i = 0; i < iters; i++) { char *p = malloc(bs); for (size_t j = 0; j < bs; j += 4096) p[j] = 1; SINK(p); free(p); }, best, faults);
        snprintf(cas, sizeof cas, "malloc-touch-free/%s", human((double)bs, hb)); h9_row(cas, "page", (double)(iters * pages), &best, reps, faults);
        char *blk = region(bs, MAP_TOUCH);
        h9_advise(blk, bs, iters, MADV_DONTNEED, reps, "dontneed", "refault");
        h9_advise(blk, bs, iters, MADV_FREE, reps, "free-lazy", "free-lazy-rewrite");
        region_free(blk, bs);
    }
}
