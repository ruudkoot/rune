/* gcb.h -- what every experiment of tests/gcbench shares (docs/plans/
   garbage-collector-v2.md, *The experiments*, *The harness*; README.md).

   * The object model is runtime/value.h's: an 8-byte header {kind:u8,
     pad:u8, contag:u16, len:u32}, the kind in the low nibble and the
     collector's nibble above it (0x30 age, 0x40 remembered, 0x80 pinned),
     an 8-byte aligned payload, 16 bytes at least; values are tests/layouts'
     L1 word (low bit 1 an immediate, else a pointer; 0 is no value). The
     kinds and helpers are tests/layouts/common.h's, numbered apart from
     value.h's: only which kinds have fields matters here.
   * The counters are read in the process, by perf_event_open and rdpmc
     (about 35 cycles a counter on the reference machine, where a read() is
     about 2,000): cycles:u, instructions:u and four programmable events
     chosen by GCB_EV (the sets below), so that a phase (the mutator, a
     collection) is counted apart from the rest. Where the counters do not
     open (no permission, no PMU, GCB_EV=none) the cycles are the TSC's,
     the other counters zero and the event set "tsc".
   * A measurement runs its work REPS times and keeps the repetition with
     the fewest cycles (and its counters); measure.sh runs the process
     several times on an idle machine and keeps the least again.
   * check=1 (any experiment): the experiment's own invariants are checked
     (gcb_fail counts what fails, and the process exits 1), and work that
     only steadies a timing is done once (check.sh).
   C17 on Linux and x86-64 (perf_event_open, rdpmc, rdtscp), gcc or clang. */
#ifndef GCB_H
#define GCB_H
#define _GNU_SOURCE
#include "../layouts/common.h"
#include <linux/perf_event.h>
#include <sys/syscall.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <unistd.h>
#include <math.h>
#include <errno.h>
#include <stdarg.h>

/* ---- the object model (runtime/value.h) ---- */
typedef uint64_t val;
typedef struct obj { uint8_t kind; uint8_t pad; uint16_t contag; uint32_t len; } obj;
_Static_assert(sizeof(obj) == 8, "value.h's header is 8 bytes");
#define KIND_MASK 0x0f
#define GC_AGE 0x30
#define GC_AGE_ONE 0x10
#define GC_REMEMBERED 0x40
#define GC_PINNED 0x80
#define GC_MARK 0x10            /* a mark-sweep's colour, kept where the age is */
enum { K_FREE = 13 };           /* a free block of an allocator (len = its bytes) */

#define FIELDS(o) ((val *)((char *)(o) + 8))
static inline int okind(const obj *o) { return o->kind & KIND_MASK; }
static inline int is_ptr(val v) { return !(v & 1) && v != 0; }
static inline obj *ptr_of(val v) { return (obj *)(uintptr_t)v; }
static inline val ptr_val(const obj *o) { return (val)(uintptr_t)o; }
static inline val mk_int(int64_t i) { return ((uint64_t)i << 1) | 1; }
static inline int64_t int_of(val v) { return (int64_t)v >> 1; }
#define NIL ((val)1)
static inline int is_raw_kind(int k) { return k == K_STRING || k == K_BOX; }
/* bytes of an object of this kind and length: 8 + payload rounded to 8,
   the payload 8 at least (room for a forwarding pointer) */
static inline size_t size_of(int kind, uint32_t len) {
    size_t p = kind == K_STRING ? len : kind == K_BOX ? 8 : (size_t)len * 8;
    if (p < 8) p = 8;
    return (8 + p + 7) & ~(size_t)7;
}
static inline size_t osize(const obj *o) { return size_of(okind(o), o->len); }
static inline int has_fields(const obj *o) { return !is_raw_kind(okind(o)); }
static inline void hdr(obj *o, int kind, int contag, uint32_t len) {
    o->kind = (uint8_t)kind; o->pad = 0; o->contag = (uint16_t)contag; o->len = len;
}
/* the number of fields an object of SIZE bytes has (the inverse of size_of) */
static inline uint32_t fields_for(size_t size) { return (uint32_t)((size - 8) / 8); }

/* ---- the self-checks (check=1) ---- */
static int gcb_check;             /* check=1 was given */
static unsigned long gcb_failures;
static void gcb_fail(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "gcbench: FAILED: ");
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
    gcb_failures++;
}

/* ---- memory ---- */
static inline size_t rup(size_t x, size_t a) { return (x + a - 1) & ~(a - 1); }
enum { MAP_TOUCH = 1, MAP_HUGE = 2, MAP_NOPOP = 4 };
static void *region(size_t bytes, int how) {
    int fl = MAP_PRIVATE | MAP_ANONYMOUS;
    if (!(how & (MAP_HUGE | MAP_NOPOP))) fl |= MAP_POPULATE;
    void *p;
    if (how & MAP_HUGE) {
        /* a huge page needs a 2 MiB aligned range: map more, trim the ends */
        size_t h = (size_t)2 << 20, len = rup(bytes, h) + h;
        char *q = mmap(NULL, len, PROT_READ | PROT_WRITE, fl, -1, 0);
        if (q == MAP_FAILED) die("mmap failed");
        char *a = (char *)rup((uintptr_t)q, h);
        if (a > q) munmap(q, (size_t)(a - q));
        char *end = a + rup(bytes, h);
        if (q + len > end) munmap(end, (size_t)(q + len - end));
        p = a;
        madvise(p, rup(bytes, h), MADV_HUGEPAGE);
    } else {
        p = mmap(NULL, bytes, PROT_READ | PROT_WRITE, fl, -1, 0);
        if (p == MAP_FAILED) die("mmap failed");
    }
    if (how & (MAP_TOUCH | MAP_HUGE))
        for (size_t i = 0; i < bytes; i += 4096) ((volatile char *)p)[i] = 0;
    return p;
}
/* (a huge region keeps the tail of its last 2 MiB mapped: a small leak) */
static void region_free(void *p, size_t bytes) { munmap(p, bytes); }

/* ---- random numbers (deterministic) ---- */
__extension__ typedef unsigned __int128 gcb_u128;
static inline uint64_t rnd(uint64_t *s) { return xorshift64(s); }
static inline uint64_t rnd_below(uint64_t *s, uint64_t n) { return (uint64_t)(((gcb_u128)xorshift64(s) * n) >> 64); }
static inline double rnd_unit(uint64_t *s) { return (double)(xorshift64(s) >> 11) * (1.0 / 9007199254740992.0); }
static void shuffle_u32(uint32_t *a, size_t n, uint64_t *s) {
    for (size_t i = n; i > 1; i--) { size_t j = rnd_below(s, i); uint32_t t = a[i - 1]; a[i - 1] = a[j]; a[j] = t; }
}

/* ---- counters: perf_event_open + rdpmc ----
   The raw codes are Haswell's (Intel SDM vol. 3B, 19.6); on another
   processor they count something else or do not open, and GCB_EV=none
   leaves the TSC alone. */
#define NCTR 6   /* cycles, instructions, four events */
typedef struct { uint64_t c[NCTR]; uint64_t tsc; } ctrs;
static struct { const char *name; const char *ev[4]; uint64_t cfg[4]; } evsets[] = {
    { "mem", { "l1d_repl", "l2_miss", "llc_miss", "dtlb_ld_walk" }, { 0x0151, 0x3f24, 0x412e, 0x0108 } },
    { "l2",  { "l2_dmd_rd_miss", "l2_rfo_miss", "l2_pf_miss", "dtlb_st_walk" }, { 0x2124, 0x2224, 0x3024, 0x0149 } },
    /* (MEM_LOAD_UOPS_RETIRED, 0xd1, does not schedule more than two at a
       time under Hyper-V: not used) */
    { "br",  { "br_miss", "l1d_repl", "l2_dmd_rd_miss", "llc_miss" }, { 0x00c5, 0x0151, 0x2124, 0x412e } },
    { "tlb", { "dtlb_ld_walk", "dtlb_walk_cyc", "dtlb_st_walk", "stlb_hit" }, { 0x0108, 0x1008, 0x0149, 0x6008 } },
};
static int pc_set;                 /* index into evsets */
static int pc_ok;                  /* the counters opened */
static struct perf_event_mmap_page *pc_pg[NCTR];
static double tsc_ghz = 3.2;

static long pc_open1(uint32_t type, uint64_t config, int group) {
    struct perf_event_attr a; memset(&a, 0, sizeof a);
    a.size = sizeof a; a.type = type; a.config = config;
    a.exclude_kernel = 1; a.exclude_hv = 1; a.pinned = group < 0;
    return syscall(SYS_perf_event_open, &a, 0, -1, group, 0);
}
/* the TSC's rate: the kernel's (the first "cpu MHz" of /proc/cpuinfo, the
   TSC being invariant: 3192.6 on the reference machine, where a calibration
   against CLOCK_MONOTONIC under WSL2 wanders by 3%). Where that line is the
   core's current clock instead, the ns columns are approximate. */
static void tsc_calibrate(void) {
    FILE *f = fopen("/proc/cpuinfo", "r");
    char line[256];
    if (f) {
        while (fgets(line, sizeof line, f))
            if (!strncmp(line, "cpu MHz", 7)) { char *c = strchr(line, ':'); if (c) tsc_ghz = atof(c + 1) / 1000.0; break; }
        fclose(f);
    }
    if (!(tsc_ghz > 0)) tsc_ghz = 3.2;
}
static void pc_init(void) {
    const char *e = getenv("GCB_EV");
    pc_set = 0;
    tsc_calibrate();
    if (e && !strcmp(e, "none")) return;
    if (e) for (size_t i = 0; i < sizeof evsets / sizeof evsets[0]; i++) if (!strcmp(e, evsets[i].name)) pc_set = (int)i;
    int fd0 = (int)pc_open1(PERF_TYPE_HARDWARE, PERF_COUNT_HW_CPU_CYCLES, -1);
    if (fd0 < 0) { fprintf(stderr, "gcbench: no counters (perf_event_open: %s); the TSC only\n", strerror(errno)); return; }
    int fds[NCTR]; fds[0] = fd0;
    fds[1] = (int)pc_open1(PERF_TYPE_HARDWARE, PERF_COUNT_HW_INSTRUCTIONS, fd0);
    for (int i = 0; i < 4; i++) fds[2 + i] = (int)pc_open1(PERF_TYPE_RAW, evsets[pc_set].cfg[i], fd0);
    for (int i = 0; i < NCTR; i++) {
        if (fds[i] < 0) { fprintf(stderr, "gcbench: counter %d did not open; the TSC only\n", i); return; }
        pc_pg[i] = mmap(NULL, 4096, PROT_READ, MAP_SHARED, fds[i], 0);
        if (pc_pg[i] == MAP_FAILED || !pc_pg[i]->cap_user_rdpmc) { fprintf(stderr, "gcbench: no rdpmc; the TSC only\n"); return; }
    }
    pc_ok = 1;
}
static const char *pc_set_name(void) { return pc_ok ? evsets[pc_set].name : "tsc"; }
static inline uint64_t pc_read1(struct perf_event_mmap_page *pg) {
    uint32_t seq, idx; uint64_t cnt;
    do {
        seq = pg->lock; __asm__ __volatile__("" ::: "memory");
        idx = pg->index; cnt = (uint64_t)pg->offset;
        if (idx) {
            uint64_t pmc = __rdpmc((int)idx - 1);
            unsigned w = pg->pmc_width;
            pmc <<= 64 - w; pmc = (uint64_t)((int64_t)pmc >> (64 - w));
            cnt += pmc;
        }
        __asm__ __volatile__("" ::: "memory");
    } while (pg->lock != seq);
    return cnt;
}
static inline void pc_read(ctrs *c) {
    if (pc_ok) for (int i = 0; i < NCTR; i++) c->c[i] = pc_read1(pc_pg[i]);
    else memset(c->c, 0, sizeof c->c);
    unsigned aux; c->tsc = __rdtscp(&aux);
}
static inline void ctrs_add_delta(ctrs *acc, const ctrs *a, const ctrs *b) {
    for (int i = 0; i < NCTR; i++) acc->c[i] += b->c[i] - a->c[i];
    acc->tsc += b->tsc - a->tsc;
}
static inline void ctrs_sub(ctrs *d, const ctrs *a, const ctrs *b) {  /* d = a - b */
    for (int i = 0; i < NCTR; i++) d->c[i] = a->c[i] - b->c[i];
    d->tsc = a->tsc - b->tsc;
}
static inline uint64_t ctrs_cyc(const ctrs *c) { return pc_ok ? c->c[0] : c->tsc; }

/* ---- a phase counted apart: ph_begin/ph_end accumulate into a ctrs ---- */
typedef struct { ctrs acc, t0; } phase;
static inline void ph_begin(phase *p) { pc_read(&p->t0); }
static inline void ph_end(phase *p) { ctrs t1; pc_read(&t1); ctrs_add_delta(&p->acc, &p->t0, &t1); }
static inline void ph_clear(phase *p) { memset(p, 0, sizeof *p); }

/* ---- output: one TSV row a measurement ----
   exp case unit n cyc ins EV0..EV3 tsc ns cyc_med reps evset    (per unit)
   measure.sh merges the rows of several processes by (exp, case, evset),
   keeping the row with the fewest cycles. */
static int out_header_done;
static void out_header(void) {
    if (out_header_done) return;
    out_header_done = 1;
    printf("#exp\tcase\tunit\tn\tcyc\tins\t%s\t%s\t%s\t%s\ttsc\tns\tcyc_med\treps\tevset\n",
           evsets[pc_set].ev[0], evsets[pc_set].ev[1], evsets[pc_set].ev[2], evsets[pc_set].ev[3]);
}
static void out_row(const char *exp, const char *cas, const char *unit, double n, const ctrs *c, double cyc_med, int reps) {
    out_header();
    double d = n > 0 ? n : 1;
    printf("%s\t%s\t%s\t%.0f\t%.3f\t%.3f\t%.4f\t%.4f\t%.4f\t%.4f\t%.3f\t%.3f\t%.3f\t%d\t%s\n",
           exp, cas, unit, n, (double)ctrs_cyc(c) / d, (double)c->c[1] / d,
           (double)c->c[2] / d, (double)c->c[3] / d, (double)c->c[4] / d, (double)c->c[5] / d,
           (double)c->tsc / d, (double)c->tsc / tsc_ghz / d, cyc_med / d, reps, pc_set_name());
    fflush(stdout);
}

/* ---- repetitions: the least of REPS, with the median of the cycles ---- */
static int cmp_u64(const void *a, const void *b) { uint64_t x = *(const uint64_t *)a, y = *(const uint64_t *)b; return (x > y) - (x < y); }
typedef struct { ctrs best; uint64_t cyc[256]; int n; } reps_t;
static void reps_init(reps_t *r) { memset(r, 0, sizeof *r); }
static void reps_add(reps_t *r, const ctrs *d) {
    if (r->n == 0 || ctrs_cyc(d) < ctrs_cyc(&r->best)) r->best = *d;
    if (r->n < 256) r->cyc[r->n] = ctrs_cyc(d);
    r->n++;
}
static double reps_median(reps_t *r) {
    int n = r->n < 256 ? r->n : 256;
    if (!n) return 0;
    qsort(r->cyc, (size_t)n, sizeof r->cyc[0], cmp_u64);
    return (double)r->cyc[n / 2];
}
static void reps_out(reps_t *r, const char *exp, const char *cas, const char *unit, double n) {
    double med = reps_median(r);
    out_row(exp, cas, unit, n, &r->best, med, r->n);
}

/* ---- options: NAME=VALUE arguments after the subcommand ---- */
static int g_argc; static char **g_argv;
static const char *opt_s(const char *name, const char *dflt) {
    size_t l = strlen(name);
    for (int i = 0; i < g_argc; i++)
        if (!strncmp(g_argv[i], name, l) && g_argv[i][l] == '=') return g_argv[i] + l + 1;
    return dflt;
}
/* a number with an optional K/M/G suffix (powers of two) */
static double parse_num(const char *s) {
    char *e; double v = strtod(s, &e);
    if (*e == 'K' || *e == 'k') v *= 1024; else if (*e == 'M' || *e == 'm') v *= 1048576; else if (*e == 'G' || *e == 'g') v *= 1073741824.0;
    return v;
}
static double opt_n(const char *name, double dflt) { const char *s = opt_s(name, NULL); return s ? parse_num(s) : dflt; }
/* a comma-separated list of numbers into OUT (at most MAX); returns the count */
static int opt_list(const char *name, const char *dflt, double *out, int max) {
    const char *s = opt_s(name, dflt);
    int n = 0;
    char buf[1024]; snprintf(buf, sizeof buf, "%s", s);
    for (char *t = strtok(buf, ","); t && n < max; t = strtok(NULL, ",")) out[n++] = parse_num(t);
    return n;
}
/* whether NAME is an item of the comma-separated LIST */
static int in_list(const char *list, const char *name) {
    char l[1024], p[64];
    snprintf(l, sizeof l, ",%s,", list); snprintf(p, sizeof p, ",%s,", name);
    return strstr(l, p) != NULL;
}
static const char *human(double b, char *buf) {   /* 65536 -> 64K */
    if (b >= 1073741824.0 && fmod(b, 1073741824.0) == 0) sprintf(buf, "%.0fG", b / 1073741824.0);
    else if (b >= 1048576 && fmod(b, 1048576) == 0) sprintf(buf, "%.0fM", b / 1048576);
    else if (b >= 1024 && fmod(b, 1024) == 0) sprintf(buf, "%.0fK", b / 1024);
    else sprintf(buf, "%.0f", b);
    return buf;
}

/* the process's anonymous memory in transparent huge pages, in KiB */
static long anon_huge_kb(void) {
    FILE *f = fopen("/proc/self/smaps_rollup", "r");
    if (!f) return -1;
    char line[256]; long kb = -1;
    while (fgets(line, sizeof line, f)) if (!strncmp(line, "AnonHugePages:", 14)) kb = atol(line + 14);
    fclose(f);
    return kb;
}
static uint64_t minflt(void) { struct rusage u; getrusage(RUSAGE_SELF, &u); return (uint64_t)u.ru_minflt; }

/* every experiment's entry point */
typedef void (*exp_fn)(void);
#endif
