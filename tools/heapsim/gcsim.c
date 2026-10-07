/* gcsim.c -- the second-generation collector's simulator (docs/plans/
   garbage-collector-v2.md, *The simulator*): replays a census trace of
   format 2 (docs/census.md) through a nursery and
   an old space whose objects have addresses, and prints one tab-separated row
   (--header names the columns). --events FILE writes one line per collection
   (the input of timeline.py), --ops FILE the old space's sequence of
   placements and frees (the input of gcbench's replay allocators).

   gcsim --trace DIR [--size native|L0|W4] [--band lo|hi|near]
         [--nursery N] [--promote 1|2] [--big T|off] [--los T|off]
         --old copy|mc|mlton|immix|sticky-immix|segfit|bestfit|nextfit|firstfit|chez
         [--heap-size H] [--heap-fill P] [--limit B | --limit-x F] ...
   (gcsim --help lists every option; README.md says what each model is.)

   Liveness. death.bin gives, per object, the last census sample at which it
   was alive. Let D(i) be the window it died in: window k runs from sample k
   to sample k+1; an object that never survived a sample dies in its birth
   window. At a point P in window k an object is dead when D < T(P), with
   T(P) = k at a sample itself (exact) and, strictly inside a window, k+1
   under --band lo (everything that dies before the next sample is dead) and
   k under --band hi (everything that died since the last sample is alive).
   A collection that falls on a sample is exact in both bands.

   The models see no object graph: an object is reachable when the census
   says it is alive. What that hides (nepotism: dead old objects keeping
   young ones alive through the remembered set, and the order a Cheney or
   marking traversal would visit objects in) is listed in README.md.
   built as bin/gcsim by the Makefile (make bin/gcsim) */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdarg.h>
#include <inttypes.h>
#include <math.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include "census/layouts.h"

#define NEVER UINT32_MAX
#define U64 PRIu64

static void die(const char *fmt, ...) {
    va_list a; va_start(a, fmt); fprintf(stderr, "gcsim: "); vfprintf(stderr, fmt, a); fputc('\n', stderr); va_end(a); exit(2);
}
/* every allocation goes through these two: past the --max-mb address-space limit (setrlimit) they stop the run with a message */
static size_t max_mb = 4096;
static void *xcalloc(size_t n, size_t s) { void *p = calloc(n ? n : 1, s ? s : 1); if (!p) die("out of memory: %zu x %zu bytes past the --max-mb %zu limit", n, s, max_mb); return p; }
static void *xrealloc(void *p, size_t n) { p = realloc(p, n ? n : 1); if (!p) die("out of memory: %zu bytes past the --max-mb %zu limit", n, max_mb); return p; }
static size_t round_up(size_t x, size_t a) { return (x + a - 1) / a * a; }

typedef struct { uint32_t *v; size_t n, cap; } Vec32;
static void v_push(Vec32 *v, uint32_t x) {
    if (v->n == v->cap) { v->cap = v->cap ? v->cap * 2 : 1024; v->v = xrealloc(v->v, v->cap * sizeof *v->v); }
    v->v[v->n++] = x;
}

static uint64_t rng = 0x9E3779B97F4A7C15ull;
static uint64_t rnd(void) { uint64_t z = (rng += 0x9E3779B97F4A7C15ull); z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull; z = (z ^ (z >> 27)) * 0x94D049BB133111EBull; return z ^ (z >> 31); }

/* ---- open-addressing hash map u64 -> u32, cleared in O(1) by a generation ---- */
typedef struct { uint64_t *keys; uint32_t *vals, *gen; size_t cap, n; uint32_t cur; } HMap;
static void hm_init(HMap *h, size_t cap) { h->cap = cap; h->n = 0; h->cur = 1; h->keys = xcalloc(cap, 8); h->vals = xcalloc(cap, 4); h->gen = xcalloc(cap, 4); }
static uint64_t hm_hash(uint64_t k) { k ^= k >> 33; k *= 0xff51afd7ed558ccdull; k ^= k >> 33; k *= 0xc4ceb9fe1a85ec53ull; k ^= k >> 33; return k; }
static void hm_grow(HMap *h);
static uint32_t *hm_find(HMap *h, uint64_t key, int insert) {
    if (insert && h->n * 2 >= h->cap) hm_grow(h);
    size_t i = hm_hash(key) & (h->cap - 1);
    for (;;) {
        if (h->gen[i] != h->cur) {
            if (!insert) return NULL;
            h->gen[i] = h->cur; h->keys[i] = key; h->vals[i] = 0; h->n++;
            return &h->vals[i];
        }
        if (h->keys[i] == key) return &h->vals[i];
        i = (i + 1) & (h->cap - 1);
    }
}
static void hm_grow(HMap *h) {
    HMap g; hm_init(&g, h->cap * 2);
    for (size_t i = 0; i < h->cap; i++) if (h->gen[i] == h->cur) *hm_find(&g, h->keys[i], 1) = h->vals[i];
    free(h->keys); free(h->vals); free(h->gen); *h = g;
}
static void hm_clear(HMap *h) { h->cur++; h->n = 0; if (h->cur == 0) { memset(h->gen, 0, h->cap * 4); h->cur = 1; } }

/* ======================================================================
   Options
   ====================================================================== */
enum { SZ_NATIVE, SZ_L0, SZ_W4 };
enum { OLD_COPY, OLD_MC, OLD_MLTON, OLD_IMMIX, OLD_STICKY, OLD_SEGFIT, OLD_BF, OLD_NF, OLD_FF, OLD_CHEZ };
static const char *old_names[] = { "copy", "mc", "mlton", "immix", "sticky-immix", "segfit", "bestfit", "nextfit", "firstfit", "chez" };
enum { FULL_APPEL, FULL_PROMOTE };
static struct {
    const char *trace, *workload, *events, *ops, *learn, *pretenure, *footprint;
    int size_model, size_set, band_hi, promote, old, full, ptr_bytes, bitmap, minor_at_samples, mutable_space;
    size_t nursery, big, los, heap0, limit; int big_set, los_set;
    double limit_x;
    unsigned fill;
    /* immix */
    size_t block, line; int exact_lines, defrag; double headroom;
    /* segregated fit, LOS */
    size_t page;
    /* free lists (OCaml 4) */
    unsigned increment, percent_free, max_overhead;
    /* mark-compact */
    int jonkers;
    /* Chez */
    size_t segment; double dense;
    /* pretenuring */
    double pretenure_x, learn_until, pretenure_from; uint64_t pretenure_min;
    /* SATB */
    int satb; double satb_k, satb_theta; size_t slice;
    /* the placement-order test */
    int shuffle; uint64_t seed; int order;   /* 0 allocation order, 1 breadth first (Cheney), 2 depth first, over graph.bin */
    /* tests */
    size_t major_every; int check, trigger_sim, no_stores;
    uint32_t major_at[16]; int nmajor_at; uint32_t satb_at;
    double phase[4]; int nphase;
} O = {
    .size_model = SZ_NATIVE, .promote = 1, .old = OLD_COPY, .full = FULL_APPEL, .ptr_bytes = 8,
    .nursery = 1u << 20, .heap0 = 4u << 20, .fill = 50,
    .block = 32768, .line = 128, .defrag = 1, .headroom = 0.02,
    .page = 4096, .increment = 15, .percent_free = 120, .max_overhead = 500,
    .segment = 16384, .dense = 0.75,
    .pretenure_x = 80, .learn_until = 1.0, .pretenure_min = 65536,
    .satb_k = 2.0, .satb_theta = 0.75,
    .phase = { 0.01, 0.05, 0.10, 0.25 }, .nphase = 4,
};

/* ======================================================================
   The trace
   ====================================================================== */
typedef struct { uint8_t kind, site_kind; uint16_t contag; uint32_t len, site, func; } AllocRec;   /* 16 B */
enum { K_TUPLE = 1, K_CON, K_CLOSURE, K_STRING, K_REF, K_ARRAY, K_EXN, K_EXNCON, K_FORWARD, K_REAL, K_BOX, K_BYTES, K_REALS };
static int kind_has_fields(int k) { return k != K_STRING && k != K_REAL && k != K_BOX && k != K_BYTES && k != K_REALS; }
static int kind_mutable_ptrs(int k) { return k == K_REF || k == K_ARRAY; }

static uint32_t N, nsamples;
static uint32_t *osize, *oD;         /* modeled size; the window of death */
static uint8_t *okind;
static uint16_t *onptr;              /* pointer fields at fill (saturating) */
static uint32_t *osite;              /* allocation site (pc), for pretenuring */
static uint32_t *onat;               /* the native size, when the model is not the trace's own (else NULL) */
static uint32_t *ofld;               /* --order: the index of the object's first field in graph.bin */
static uint32_t *graph; static size_t graph_len;
static uint32_t *sample_id;          /* [k] the first id born after sample k; [0] = 1, [nsamples+1] = N+1 */
static uint64_t *sample_clock;       /* modeled bytes allocated when sample k ran */
static uint64_t *sample_nclock;      /* native bytes (the store clock's unit) */
static uint64_t *sample_instr;       /* instructions at sample k (0 = unknown) */
static uint32_t *sample_depth, *sample_low;   /* stack slots at sample k; the slots below this were suspended since sample k-1 (base_low) */
static uint32_t *sample_frames, *sample_ptrs;  /* frames on the stack; slots holding a pointer */
static uint64_t *sample_live_trace;  /* the census's own live bytes at sample k (its sizes) */
static uint64_t *sample_live;        /* modeled live bytes at sample k, from death.bin */
static int have_stack, have_instr, have_oldid;
static uint64_t total_bytes, total_native, total_instr, max_live;
static unsigned hdr_bytes = 8, word_bytes = 8;
static const char *trace_format = "census-W8";

static void *map_file(const char *name, size_t *len, int must) {
    char p[4096]; snprintf(p, sizeof p, "%s/%s", O.trace, name);
    int fd = open(p, O_RDONLY);
    if (fd < 0) { if (must) die("%s: %s", p, strerror(errno)); *len = 0; return NULL; }
    struct stat st; if (fstat(fd, &st)) die("%s: %s", p, strerror(errno));
    *len = (size_t)st.st_size;
    void *m = *len ? mmap(NULL, *len, PROT_READ, MAP_PRIVATE, fd, 0) : NULL;
    if (*len && m == MAP_FAILED) die("%s: mmap: %s", p, strerror(errno));
    close(fd);
    return m;
}

/* the size of an object under the size model, from its kind and length */
static uint32_t model_size(int kind, uint32_t len, uint32_t native) {
    switch (O.size_model) {
    case SZ_NATIVE: return native;
    case SZ_L0: return (uint32_t)l0_obj_size((uint8_t)kind, len);
    case SZ_W4: {   /* a 4-byte word and header: fields 4 bytes, raw doubles 8, aligned to 4 (8 for doubles) */
        size_t pay = kind == K_STRING || kind == K_BYTES ? len : kind == K_REAL || kind == K_BOX ? 8 : kind == K_REALS ? (size_t)len * 8 : (size_t)len * 4;
        if (pay < 4) pay = 4;
        size_t s = 4 + pay;
        return (uint32_t)round_up(s, kind == K_REAL || kind == K_BOX || kind == K_REALS ? 8 : 4);
    }
    }
    return native;
}
static uint64_t obj_fields(uint32_t id) {
    if (!kind_has_fields(okind[id])) return 0;
    uint32_t s = osize[id];
    unsigned w = O.size_model == SZ_L0 ? 16 : O.size_model == SZ_W4 ? 4 : 8;
    unsigned h = O.size_model == SZ_W4 ? 4 : 8;
    return s > h ? (s - h) / w : 0;
}

/* the store stream: 24-byte records with the old value's id */
typedef struct { uint64_t clock; uint32_t src, dst, oldid, field; uint8_t site, flags; } Store;
typedef struct { uint32_t clock8, src, new_id, old_id, field; uint8_t site, flags, rep, src_kind; } StoreRec2;   /* format 2, 24 B */
_Static_assert(sizeof(StoreRec2) == 24, "format 2 store record");
typedef struct { uint64_t clock, live_bytes, live_objs, instructions, last_id; uint32_t sp, fp, fp_low, base_low, sp_ptrs, flags; } SampleRec2;
_Static_assert(sizeof(SampleRec2) == 64, "format 2 sample record");
typedef struct { FILE *f; StoreRec2 buf2[4096]; size_t n, i; int eof; } StoreReader;
static StoreReader SR;
static void sr_open(void) {
    char p[4096]; snprintf(p, sizeof p, "%s/stores.bin", O.trace);
    SR.f = fopen(p, "rb"); SR.n = SR.i = 0; SR.eof = SR.f == NULL;
}
static int sr_next(Store *s) {
    if (SR.i == SR.n) {
        if (SR.eof) return 0;
        SR.n = fread(SR.buf2, sizeof(StoreRec2), 4096, SR.f); SR.i = 0;
        if (SR.n == 0) { SR.eof = 1; return 0; }
    }
    StoreRec2 *r = &SR.buf2[SR.i++];
    s->clock = (uint64_t)r->clock8 * 8; s->src = r->src; s->dst = r->new_id; s->oldid = r->old_id; s->field = r->field; s->site = r->site; s->flags = r->flags;
    return 1;
}

typedef struct { FILE *f; const char *name; uint8_t *buf; size_t n, i, cap; } Stream;   /* a trace file read in order */
static void st_open(Stream *s, const char *name, size_t cap) {
    char p[4096]; snprintf(p, sizeof p, "%s/%s", O.trace, name);
    s->f = fopen(p, "rb"); if (!s->f) die("%s: %s", p, strerror(errno));
    s->name = name; s->cap = cap; s->buf = xcalloc(cap, 1); s->n = s->i = 0;
}
static const uint8_t *st_get(Stream *s, size_t k) {   /* the next k bytes (k divides the buffer's refills: k <= 64) */
    if (s->n - s->i < k) {
        memmove(s->buf, s->buf + s->i, s->n - s->i); s->n -= s->i; s->i = 0;
        s->n += fread(s->buf + s->n, 1, s->cap - s->n, s->f);
        if (s->n < k) die("%s: too short", s->name);
    }
    const uint8_t *p = s->buf + s->i; s->i += k; return p;
}
static void st_close(Stream *s) { fclose(s->f); free(s->buf); }
static size_t file_size(const char *name) { char p[4096]; snprintf(p, sizeof p, "%s/%s", O.trace, name); struct stat st; if (stat(p, &st)) die("%s: %s", p, strerror(errno)); return (size_t)st.st_size; }
/* format 2 (docs/census.md): W8 sizes, 64-byte samples with the
   instruction clock and the stack, 24-byte stores with the old value */
static uint64_t w8_size(int kind, uint32_t len) {
    size_t pay = kind == K_STRING || kind == K_BYTES ? len : kind == K_REAL || kind == K_BOX ? 8 : (size_t)len * 8;
    pay = (pay + 7) & ~(size_t)7; if (pay < 8) pay = 8;
    return 8 + pay;
}
static int is_v2(void) {
    char p[4096]; snprintf(p, sizeof p, "%s/meta.txt", O.trace);
    FILE *f = fopen(p, "r"); if (!f) return 0;
    char line[256]; int v = 0; unsigned long long n;
    while (fgets(line, sizeof line, f)) {
        if (!strncmp(line, "format 2", 8)) v = 1;
        if (sscanf(line, "instructions %llu", &n) == 1) total_instr = n;
    }
    fclose(f);
    return v;
}
static void load_v2(void) {
    size_t len = file_size("alloc.bin");
    if (len % 16 || len < 32) die("alloc.bin: bad size");
    N = (uint32_t)(len / 16 - 1);
    if (file_size("death.bin") < ((size_t)N + 1) * 4) die("death.bin too short");
    SampleRec2 *recs = map_file("samples.bin", &len, 1);
    if (len % 64) die("samples.bin: bad size (format 2: 64 bytes a record)");
    nsamples = (uint32_t)(len / 64);
    sample_id = xcalloc(nsamples + 2, 4); sample_clock = xcalloc(nsamples + 2, 8); sample_nclock = xcalloc(nsamples + 2, 8);
    sample_instr = xcalloc(nsamples + 2, 8); sample_depth = xcalloc(nsamples + 2, 4); sample_low = xcalloc(nsamples + 2, 4);
    sample_frames = xcalloc(nsamples + 2, 4); sample_ptrs = xcalloc(nsamples + 2, 4); sample_live_trace = xcalloc(nsamples + 2, 8);
    for (uint32_t k = 1; k <= nsamples; k++) {
        const SampleRec2 *r = &recs[k - 1];
        sample_nclock[k] = r->clock; sample_live_trace[k] = r->live_bytes; sample_instr[k] = r->instructions;
        sample_depth[k] = r->sp; sample_low[k] = r->base_low; sample_frames[k] = r->fp + 1; sample_ptrs[k] = r->sp_ptrs;
        sample_id[k] = (uint32_t)(r->last_id + 1);
        if (k > 1 && sample_id[k] < sample_id[k - 1]) die("samples.bin: last_id not monotone");
    }
    munmap(recs, len);
    sample_id[0] = 1; sample_id[nsamples + 1] = N + 1; sample_instr[nsamples + 1] = total_instr;
    have_stack = have_instr = have_oldid = 1;
    osize = xcalloc((size_t)N + 1, 4); oD = xcalloc((size_t)N + 1, 4); okind = xcalloc((size_t)N + 1, 1);
    onptr = xcalloc((size_t)N + 1, 2); osite = xcalloc((size_t)N + 1, 4);
    if (O.size_model != SZ_NATIVE) onat = xcalloc((size_t)N + 1, 4);
    Stream sa, sf, sd; st_open(&sa, "alloc.bin", 1 << 20); st_open(&sf, "fields.bin", 1 << 20); st_open(&sd, "death.bin", 1 << 20);
    st_get(&sa, 16); st_get(&sd, 4);
    uint64_t clock0 = 0, clockm = 0, fidx = 0; uint32_t k = 0;
    if (O.order) {
        size_t gl; graph = map_file("graph.bin", &gl, 1); graph_len = gl / 4;
        ofld = xcalloc((size_t)N + 2, 4);
    }
    for (uint32_t id = 1; id <= N; id++) {
        while (k < nsamples && sample_id[k + 1] <= id) { k++; sample_clock[k] = clockm; if (sample_nclock[k] != clock0) die("samples.bin: sample %u at clock %" U64 ", the ids say %" U64, k, sample_nclock[k], clock0); }
        AllocRec a; memcpy(&a, st_get(&sa, 16), 16);
        uint32_t nat = (uint32_t)w8_size(a.kind, a.len);
        okind[id] = a.kind; osite[id] = a.site;
        osize[id] = O.size_model == SZ_NATIVE ? nat : model_size(a.kind, a.len, nat);
        if (onat) onat[id] = nat;
        uint32_t d; memcpy(&d, st_get(&sd, 4), 4);
        oD[id] = d == 0xFFFFFFFFu ? NEVER : d == 0 ? k : d;
        if (ofld) { if (fidx > UINT32_MAX) die("graph.bin: over 2^32 fields"); ofld[id] = (uint32_t)fidx; if (kind_has_fields(a.kind)) fidx += a.len; }
        if (kind_has_fields(a.kind)) {
            unsigned np = 0;
            for (uint32_t f = 0; f < a.len; f += 32) {
                uint32_t m = a.len - f < 32 ? a.len - f : 32;
                const uint8_t *q = st_get(&sf, 2 * m);
                for (uint32_t j = 0; j < m; j++) if ((q[2 * j] & 3) == 1) np++;
            }
            onptr[id] = np > 65535 ? 65535 : (uint16_t)np;
        }
        clock0 += nat; clockm += osize[id];
    }
    while (k < nsamples) { k++; sample_clock[k] = clockm; }
    sample_clock[nsamples + 1] = clockm; sample_nclock[nsamples + 1] = clock0;
    total_bytes = clockm; total_native = clock0;
    if (ofld) { ofld[N + 1] = (uint32_t)fidx; if (fidx != graph_len) die("graph.bin has %zu fields, alloc.bin says %" U64, graph_len, fidx); }
    st_close(&sa); st_close(&sf); st_close(&sd);
}

static void load_trace(void) {
    if (!is_v2()) die("%s: not a trace of format 2 (no 'format 2' in meta.txt; docs/census.md)", O.trace);
    load_v2();
    hdr_bytes = O.size_model == SZ_W4 ? 4 : 8; word_bytes = O.size_model == SZ_W4 ? 4 : O.size_model == SZ_L0 ? 16 : 8;
    /* modeled live bytes at every sample, from death.bin: alive at samples w+1 .. D */
    sample_live = xcalloc(nsamples + 3, 8);
    int64_t *diff = xcalloc(nsamples + 3, 8);
    uint32_t k = 0;
    for (uint32_t id = 1; id <= N; id++) {
        while (k < nsamples && sample_id[k + 1] <= id) k++;
        uint32_t D = oD[id];
        uint32_t lo = k + 1, hi = D == NEVER ? nsamples : D;
        if (D != NEVER && D <= k) continue;   /* died in its birth window */
        if (lo <= hi) { diff[lo] += osize[id]; diff[hi + 1] -= osize[id]; }
    }
    int64_t acc = 0;
    for (uint32_t j = 1; j <= nsamples; j++) { acc += diff[j]; sample_live[j] = (uint64_t)acc; if ((uint64_t)acc > max_live) max_live = (uint64_t)acc; }
    free(diff);
    if (!have_instr) for (uint32_t j = 0; j <= nsamples + 1; j++) sample_instr[j] = total_native ? (uint64_t)((double)total_instr * (double)sample_nclock[j] / (double)total_native) : 0;
}

/* ======================================================================
   Where objects are, and the state of the run
   ====================================================================== */
enum { W_NONE = 0, W_YOUNG, W_SURV, W_OLD, W_LOS, W_MUT, W_FREED };
static uint8_t *owhere;
static uint32_t *oaddr;             /* address in 8-byte granules within its space's region */
static uint32_t *olink;             /* the death lists */
static uint32_t *dl_head;           /* [D] old objects dying in window D */
static uint32_t dl_next;            /* lists below this have been swept */
static Vec32 dl_carry;              /* objects a sweep had to keep (born after a SATB snapshot) */

typedef struct { uint32_t id, k, T; int exact; uint64_t clock; } Point;
static uint32_t cur_k;              /* the window of the current point */
static uint64_t cur_clock;          /* modeled bytes allocated before the current object */
static uint32_t cur_id;
static Point point_at(uint32_t id) {
    Point p; p.id = id; p.k = cur_k; p.exact = sample_id[cur_k] == id;
    if (p.exact) p.T = cur_k;
    else if (O.band_hi == 2) p.T = cur_clock - sample_clock[cur_k] >= sample_clock[cur_k + 1] - cur_clock ? cur_k + 1 : cur_k;   /* near: the nearer sample's side */
    else p.T = cur_k + (O.band_hi ? 0 : 1);
    p.clock = cur_clock; return p;
}
static int dead_at(uint32_t id, uint32_t T) { return oD[id] < T; }

/* ======================================================================
   Events: one line per collection
   ====================================================================== */
enum { EV_MINOR, EV_MAJOR, EV_FULL, EV_COMPACT, EV_SATB_START, EV_SATB_SLICE, EV_SATB_END, EV_STICKY_MINOR };
static const char *ev_names[] = { "minor", "major", "full", "compact", "satb-start", "satb-slice", "satb-end", "sticky-minor" };
typedef struct {
    int kind; const char *how;
    uint64_t clock, instr; uint32_t depth, low, frames, stack_ptrs;
    uint64_t slots, cards, cards_ptr, cards_any, remset, born_rem, born_rem_fields, mut_scan_bytes, mut_scan_objs;
    uint64_t copied_objs, copied_bytes, promoted_objs, promoted_bytes;
    uint64_t marked_objs, marked_bytes, marked_fields, marked_ptrs;
    uint64_t swept_objs, swept_bytes, sweep_scan_bytes;
    uint64_t moved_objs, moved_bytes, evac_objs, evac_bytes;
    uint64_t heap_scan_objs, heap_scan_bytes;
    uint64_t satb_work, lazy_sweep_bytes;
    uint64_t live_old, occupancy, committed, reserved, metadata, old_committed, los_committed;
    double frag_int, frag_ext, free_usable;
    uint64_t held, usable, whole;     /* bytes: held by live objects' allocation units; free and usable; in wholly free units */
} Ev;
static FILE *ev_file, *ops_file;
static uint64_t ev_seq;

/* ======================================================================
   Counters of the run
   ====================================================================== */
static struct {
    uint64_t minors, majors, fulls, fulls_instead, compactions, mc_majors, copy_majors, satb_cycles, satb_degenerate;
    uint64_t nursery_alloc, direct_bytes, big_bytes, big_objs, los_bytes, los_objs, mut_bytes, mut_objs;
    uint64_t surv_first, surv_first_objs, promoted, promoted_objs, surv_copied, copied_minor, copied_major, copied_major_objs;
    uint64_t marked_major, marked_major_objs, marked_fields, swept_bytes, swept_objs, sweep_scan;
    uint64_t moved_bytes, moved_objs, evac_bytes, evac_objs, heap_scan_bytes, heap_scan_objs, marked_ptrs;
    uint64_t remset_total, remset_max, cards_total, cards_max, cards_ptr_total, cards_any_total, born_rem_total, born_rem_fields;
    uint64_t mut_scan_total, mut_scan_max;
    uint64_t stores, stores_site[3], stores_old_src, oy_site[3], stores_ptr;
    uint64_t satb_log, satb_log_old, satb_float_total, satb_float_max, satb_work_total, satb_occ_peak, satb_active_bytes;
    uint64_t pt_bytes, pt_objs, pt_saved, pt_garbage;
    uint64_t marked_phase[4];
    uint64_t slots_total, low_slots_total;
    uint64_t max_live_old, max_occupancy;
    uint64_t peak_committed, peak_reserved, peak_metadata, peak_total, final_committed;
    double committed_integral;       /* committed x bytes allocated */
    uint64_t integral_clock;
    uint64_t limit_over, limit_over_max, grow_forced;
    double frag_int_max, frag_ext_max, frag_int_sum, frag_ext_sum, overhead_sum; uint64_t frag_n;
    uint64_t max_surv_space;
} S;

/* ======================================================================
   Old-space bookkeeping common to the models
   ====================================================================== */
static uint64_t old_occ, old_objs_n;     /* bytes and objects placed and not yet freed (old space proper) */
static uint64_t los_occ, los_committed;  /* the LOS: object bytes, page-rounded bytes */
static uint64_t mut_occ, mut_committed;  /* the mutable space */
static uint64_t live_phase[4];           /* old + LOS + mutable bytes born before each phase end */
static uint32_t phase_id[4];             /* the first id born after each phase end */
/* the policy of the non-moving old generations (old space + LOS + mutable space):
   without a limit, a major runs when the occupancy (bytes placed and not
   yet freed) reaches trig_occ = live/fill after the last major, and the
   space commits what it needs (fragmentation shows as footprint); with a
   limit, a major runs when an allocation would commit past old_cap = the
   limit (fragmentation shows as more majors), and one that fails right
   after a major that freed too little overflows the limit (counted) */
static uint64_t old_cap;                 /* the bytes old + LOS + mutable may commit (the limit; unbounded without) */
static uint64_t rel_cap;                 /* free blocks, pools, segments are given back above this after a major */
static uint64_t trig_occ;                /* without a limit: the occupancy that starts a major */
static uint64_t old_alloc_since_major;   /* bytes placed in the old generation since the last major */
static uint64_t limit_bytes;             /* --limit or --limit-x x max live (0 = none) */
static Vec32 survivors;                  /* --promote 2: the ids in the survivor space */
static uint64_t surv_bytes;
static uint64_t nursery_used;
static uint32_t young_lo;                /* the first id of the nursery's current contents */
static Vec32 born_rem;                   /* objects placed in old space since the last minor, with pointer fields */
static Vec32 pt_since;                   /* pretenured since the last minor */

static void phase_add(uint32_t id, int64_t sign) {
    for (int c = 0; c < O.nphase; c++) if (id < phase_id[c]) live_phase[c] += (uint64_t)((int64_t)osize[id] * sign);
}
static void dl_push(uint32_t id) {
    uint32_t D = oD[id];
    if (D == NEVER) return;
    olink[id] = dl_head[D]; dl_head[D] = id;
}

static void ops_line(char c, uint32_t id) {
    if (!ops_file) return;
    if (c == 'a' || c == 'm') fprintf(ops_file, "%c %u %u %u %u\n", c, id, osize[id], oaddr[id], (unsigned)owhere[id]);
    else fprintf(ops_file, "%c %u\n", c, id);
}

/* forward declarations of the old space's operations (the models below) */
static int os_alloc(uint32_t id);
static void os_free(uint32_t id);
static void os_grow(size_t need);
static uint64_t os_committed(void), os_reserved(void), os_meta(void);
static void os_frag(Ev *e);
static int os_moving(void) { return O.old == OLD_COPY || O.old == OLD_MC || O.old == OLD_MLTON; }

/* ======================================================================
   The large-object space: one mapping per object, page-rounded, never moved
   ====================================================================== */
enum { LOS_HDR = 16 };
static uint64_t los_next_addr = 0;          /* granules, in the LOS region */
static uint64_t los_budget;                 /* with a copying old space: its own budget, grown like heap.c */
static uint64_t los_pages(uint32_t id) { return round_up((size_t)osize[id] + LOS_HDR, O.page); }
static void los_place(uint32_t id) {
    owhere[id] = W_LOS; oaddr[id] = (uint32_t)(los_next_addr + LOS_HDR / 8);
    los_next_addr = (los_next_addr + los_pages(id) / 8) & 0x7FFFFFFFull;   /* addresses serve the cards only: wrap at 16 GiB */
    los_occ += osize[id]; los_committed += los_pages(id);
    S.los_bytes += osize[id]; S.los_objs++;
    phase_add(id, 1); dl_push(id); ops_line('a', id);
}
static void los_free(uint32_t id) { los_occ -= osize[id]; los_committed -= los_pages(id); }

/* ======================================================================
   Footprint and events
   ====================================================================== */
static uint64_t meta_rs_peak, meta_satb_peak;
static uint64_t footprint_committed(void) {
    uint64_t n = O.old == OLD_STICKY ? 0 : O.nursery;
    if (O.promote == 2) n += 2 * S.max_surv_space;
    return n + os_committed() + los_committed + mut_committed;
}
static uint64_t footprint_meta(void) {
    uint64_t m = os_meta();
    /* the card table and crossing map cover old + mutable space (a byte per 512-byte card each), when there is a nursery */
    if (O.nursery || O.old == OLD_STICKY) m += 2 * ((os_committed() + mut_committed) / 512);
    m += meta_rs_peak + meta_satb_peak;
    return m;
}
static void footprint_tick(void) {
    uint64_t c = footprint_committed(), r = os_reserved() + los_committed + mut_committed + (O.old == OLD_STICKY ? 0 : O.nursery), m = footprint_meta();
    if (cur_clock > S.integral_clock) { S.committed_integral += (double)c * (double)(cur_clock - S.integral_clock); S.integral_clock = cur_clock; }
    if (c > S.peak_committed) S.peak_committed = c;
    if (r > S.peak_reserved) S.peak_reserved = r;
    if (m > S.peak_metadata) S.peak_metadata = m;
    if (c + m > S.peak_total) S.peak_total = c + m;
    uint64_t occ = old_occ + los_occ + mut_occ;
    if (occ > S.max_occupancy) S.max_occupancy = occ;
}
/* a transient: the copying collector's from- and to-space at once */
static void footprint_transient(uint64_t extra) {
    uint64_t c = footprint_committed() + extra;
    if (c > S.peak_committed) S.peak_committed = c;
    if (c + footprint_meta() > S.peak_total) S.peak_total = c + footprint_meta();
    if (os_reserved() + extra > S.peak_reserved) S.peak_reserved = os_reserved() + extra + los_committed + mut_committed + O.nursery;
}

static uint64_t instr_at(uint64_t clock) {   /* the instruction clock, interpolated between samples by modeled bytes */
    uint32_t k = cur_k;
    while (k > 0 && sample_clock[k] > clock) k--;
    uint64_t c0 = sample_clock[k], c1 = sample_clock[k + 1], i0 = sample_instr[k], i1 = sample_instr[k + 1];
    if (k + 1 > nsamples) { c1 = total_bytes; i1 = sample_instr[nsamples + 1] ? sample_instr[nsamples + 1] : total_instr; }
    if (c1 <= c0) return i0;
    return i0 + (uint64_t)((double)(i1 - i0) * (double)(clock - c0) / (double)(c1 - c0));
}
static uint32_t low_since = UINT32_MAX;     /* the lowest stack slot touched since the last minor (samples) */

static void ev_begin(Ev *e, int kind, Point P) {
    memset(e, 0, sizeof *e); e->kind = kind; e->how = "-"; e->clock = P.clock; e->instr = instr_at(P.clock);
    uint32_t ks = P.exact ? P.k : (P.k + 1 <= nsamples ? P.k + 1 : P.k);
    e->depth = have_stack ? sample_depth[ks] : 0;
    e->frames = have_stack ? sample_frames[ks] : 0;
    e->stack_ptrs = have_stack ? sample_ptrs[ks] : 0;
    uint32_t low = low_since; if (have_stack && ks > P.k && sample_low[ks] < low) low = sample_low[ks];
    e->low = have_stack ? (low == UINT32_MAX ? 0 : (low > e->depth ? e->depth : low)) : 0;
}
static const char *ev_cols =
    "seq\tkind\thow\tclock\tinstr\tdepth\tlow\tframes\tstack_ptrs\tslots\tcards\tcards_ptr\tcards_any\tremset\tborn_rem\tborn_rem_fields\tmut_scan_bytes\tmut_scan_objs\t"
    "copied_objs\tcopied_bytes\tpromoted_objs\tpromoted_bytes\tmarked_objs\tmarked_bytes\tmarked_fields\tmarked_ptrs\t"
    "swept_objs\tswept_bytes\tsweep_scan_bytes\tmoved_objs\tmoved_bytes\tevac_objs\tevac_bytes\theap_scan_objs\theap_scan_bytes\t"
    "satb_work\tlazy_sweep_bytes\tlive_old\toccupancy\tcommitted\treserved\tmetadata\told_committed\tlos_committed\tfrag_int\tfrag_ext\tfree_usable\theld\tusable\twhole";
static void ev_end(Ev *e) {
    e->live_old = old_occ + los_occ + mut_occ;
    e->occupancy = old_occ + los_occ + mut_occ;
    e->old_committed = os_committed(); e->los_committed = los_committed;
    footprint_tick();
    e->committed = footprint_committed(); e->reserved = os_reserved() + los_committed + mut_committed + (O.old == OLD_STICKY ? 0 : O.nursery); e->metadata = footprint_meta();
    ev_seq++;
    if (!ev_file) return;
    fprintf(ev_file, "%" U64 "\t%s\t%s\t%" U64 "\t%" U64 "\t%u\t%u\t%u\t%u\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t"
            "%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t"
            "%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t"
            "%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%" U64 "\t%.4f\t%.4f\t%.4f\t%" U64 "\t%" U64 "\t%" U64 "\n",
            ev_seq, ev_names[e->kind], e->how, e->clock, e->instr, e->depth, e->low, e->frames, e->stack_ptrs, e->slots, e->cards, e->cards_ptr, e->cards_any, e->remset, e->born_rem, e->born_rem_fields, e->mut_scan_bytes, e->mut_scan_objs,
            e->copied_objs, e->copied_bytes, e->promoted_objs, e->promoted_bytes, e->marked_objs, e->marked_bytes, e->marked_fields, e->marked_ptrs,
            e->swept_objs, e->swept_bytes, e->sweep_scan_bytes, e->moved_objs, e->moved_bytes, e->evac_objs, e->evac_bytes, e->heap_scan_objs, e->heap_scan_bytes,
            e->satb_work, e->lazy_sweep_bytes, e->live_old, e->occupancy, e->committed, e->reserved, e->metadata, e->old_committed, e->los_committed, e->frag_int, e->frag_ext, e->free_usable, e->held, e->usable, e->whole);
}
/* what every major adds to the run's totals */
static void major_totals(Ev *e) {
    S.marked_major += e->marked_bytes; S.marked_major_objs += e->marked_objs; S.marked_fields += e->marked_fields; S.marked_ptrs += e->marked_ptrs;
    S.swept_bytes += e->swept_bytes; S.swept_objs += e->swept_objs; S.sweep_scan += e->sweep_scan_bytes;
    S.moved_bytes += e->moved_bytes; S.moved_objs += e->moved_objs; S.evac_bytes += e->evac_bytes; S.evac_objs += e->evac_objs;
    S.heap_scan_bytes += e->heap_scan_bytes; S.heap_scan_objs += e->heap_scan_objs;
    uint64_t live = old_occ + los_occ + mut_occ;
    if (live > S.max_live_old) S.max_live_old = live;
    for (int c = 0; c < O.nphase; c++) S.marked_phase[c] += live_phase[c];
    os_frag(e);
    if (e->frag_int > S.frag_int_max) S.frag_int_max = e->frag_int;
    if (e->frag_ext > S.frag_ext_max) S.frag_ext_max = e->frag_ext;
    S.frag_int_sum += e->frag_int; S.frag_ext_sum += e->frag_ext; S.frag_n++;
    uint64_t oc = os_committed() + los_committed + mut_committed;
    if (live) S.overhead_sum += (double)oc / (double)live;
    if (limit_bytes && oc > limit_bytes) S.limit_over++;   /* a major that ended over the limit */
}


/* ---- the old generation's live counters (old space + LOS + mutable space) ---- */
static uint64_t gen_objs, gen_fields, gen_ptrs, los_objs_n, mut_objs_n;
static Vec32 old_ids;     /* non-moving old spaces: every object placed, freed ones removed lazily */
static Vec32 order;       /* moving old spaces: the ids in address order */
static void gen_add(uint32_t id) { gen_objs++; gen_fields += obj_fields(id); gen_ptrs += onptr[id]; phase_add(id, 1); }
static void gen_sub(uint32_t id) { gen_objs--; gen_fields -= obj_fields(id); gen_ptrs -= onptr[id]; phase_add(id, -1); }

static void free_one(uint32_t id, Ev *e) {
    switch (owhere[id]) {
    case W_LOS: los_free(id); los_objs_n--; break;
    case W_MUT: mut_occ -= osize[id]; mut_objs_n--; break;
    default: os_free(id); old_occ -= osize[id]; old_objs_n--; break;
    }
    gen_sub(id); owhere[id] = W_FREED; e->swept_objs++; e->swept_bytes += osize[id]; ops_line('f', id);
}
/* sweep the death lists: free every object of a non-moving space (and of the
   LOS and the mutable space) that died in a window below T and was born
   before `born_before` (a SATB cycle allocates black: later objects wait for
   the next sweep) */
static void sweep_lists(uint32_t T, uint32_t born_before, Ev *e) {
    Vec32 keep = { 0 };
    for (size_t i = 0; i < dl_carry.n; i++) {
        uint32_t id = dl_carry.v[i];
        if (owhere[id] < W_OLD || owhere[id] > W_MUT) continue;
        if (!dead_at(id, T) || id >= born_before) v_push(&keep, id); else free_one(id, e);
    }
    free(dl_carry.v); dl_carry = keep;
    for (; dl_next < T && dl_next <= nsamples; dl_next++) {
        for (uint32_t id = dl_head[dl_next], nx; id; id = nx) {
            nx = olink[id];
            if (owhere[id] < W_OLD || owhere[id] > W_MUT) continue;
            if (id >= born_before) v_push(&dl_carry, id); else free_one(id, e);
        }
        dl_head[dl_next] = 0;
    }
}
/* bytes placed in the old generation that are dead at T but not yet swept */
static uint64_t unswept_dead(uint32_t T, uint32_t from) {
    uint64_t b = 0;
    for (size_t i = 0; i < dl_carry.n; i++) { uint32_t id = dl_carry.v[i]; if (owhere[id] >= W_OLD && owhere[id] <= W_MUT && dead_at(id, T)) b += osize[id]; }
    for (uint32_t d = from; d < T && d <= nsamples; d++)
        for (uint32_t id = dl_head[d]; id; id = olink[id]) if (owhere[id] >= W_OLD && owhere[id] <= W_MUT) b += osize[id];
    return b;
}
static void compact_ids(Vec32 *v) {   /* drop the ids no longer in the old space proper */
    size_t j = 0;
    for (size_t i = 0; i < v->n; i++) if (owhere[v->v[i]] == W_OLD) v->v[j++] = v->v[i];
    v->n = j;
}

/* the growth target of a non-moving old space after a major: live/fill, or the limit */
static uint64_t cap_after(uint64_t live, uint64_t step) {
    if (limit_bytes) return limit_bytes;
    uint64_t t = live / O.fill * 100 + live % O.fill * 100 / O.fill;
    if (t < O.heap0) t = O.heap0;
    return round_up(t, step);
}
static void note_over(void) {   /* the old generation's commitment against the limit: the largest excess */
    uint64_t c = os_committed() + los_committed + mut_committed;
    if (limit_bytes && c > limit_bytes && c - limit_bytes > S.limit_over_max) S.limit_over_max = c - limit_bytes;
}

/* ======================================================================
   copy: a two-space copying old space with runtime/heap.c's policy
   (fill_of, grown, the survivor guess, the second pass when it grows)
   ====================================================================== */
static struct { uint64_t size, used, live_last, live_before, to_kept; } CP;
static uint64_t fill_of(uint64_t n) { return n / 100 * O.fill + n % 100 * O.fill / 100; }
static uint64_t grown(uint64_t size, uint64_t used, uint64_t needed) {
    uint64_t want = size ? size : 4096;
    while (used > fill_of(want) || needed > fill_of(want) - used) { if (want > UINT64_MAX / 4) die("heap wraps"); want *= 2; }
    return want;
}
enum { CM_COPY, CM_SLIDE };
/* the moving spaces' collection: drop the dead from `order`, lay the live
   out again from address 0 in the same order (Cheney order is not known
   without the graph; sliding keeps this order exactly) */
static uint64_t compact_order(uint32_t T, Ev *e, int mode) {
    size_t j = 0; uint64_t live = 0, scanned_objs = 0, scanned_bytes = 0;
    for (size_t i = 0; i < order.n; i++) {
        uint32_t id = order.v[i];
        if (owhere[id] != W_OLD) continue;
        scanned_objs++; scanned_bytes += osize[id];
        if (dead_at(id, T)) { old_occ -= osize[id]; old_objs_n--; gen_sub(id); owhere[id] = W_FREED; e->swept_objs++; e->swept_bytes += osize[id]; ops_line('f', id); continue; }
        uint32_t na = (uint32_t)(live / 8);
        if (mode == CM_COPY || na != oaddr[id]) { e->moved_objs++; e->moved_bytes += osize[id]; }
        oaddr[id] = na; live += osize[id];
        e->marked_objs++; e->marked_bytes += osize[id]; e->marked_fields += obj_fields(id); e->marked_ptrs += onptr[id];
        order.v[j++] = id;
        ops_line('m', id);
    }
    order.n = j;
    if (mode == CM_SLIDE) { e->heap_scan_objs = scanned_objs; e->heap_scan_bytes = scanned_bytes; }
    return live;
}
static void los_budget_after(void) { if (O.los && os_moving()) los_budget = grown(los_budget ? los_budget : O.heap0, los_occ, 0); }
static void cp_collect_into(uint64_t new_size, Point P, const char *how, int kind) {
    Ev e; ev_begin(&e, kind, P); e.how = how;
    uint64_t now = CP.size + CP.to_kept, during = CP.size + new_size;
    if (during > now) footprint_transient(during - now);
    sweep_lists(P.T, UINT32_MAX, &e);
    uint64_t live = compact_order(P.T, &e, CM_COPY);
    CP.used = live; CP.to_kept = new_size == CP.size ? CP.size : 0; CP.size = new_size;
    S.copied_major += live; S.copied_major_objs += e.moved_objs; S.copy_majors++; S.majors++;
    if (kind == EV_FULL) S.fulls++;
    los_budget_after();
    major_totals(&e); note_over(); ev_end(&e);
}
/* --full appel (the prototype of the roadmap's experiments, a nursery in front of today's copier):
   the copier of today over old space and the nursery together; the
   nursery's live objects are promoted (copied after the old space's live
   ones) and the sizing is heap.c's on everything copied */
static Vec32 full_young;
static void cp_full(Point P, uint64_t needed) {
    full_young.n = 0;
    for (size_t i = 0; i < survivors.n; i++) { uint32_t id = survivors.v[i]; if (owhere[id] == W_SURV) { if (dead_at(id, P.T)) owhere[id] = W_FREED; else v_push(&full_young, id); } }
    survivors.n = 0; surv_bytes = 0;
    for (uint32_t id = young_lo; id < P.id; id++) {
        if (owhere[id] != W_YOUNG) continue;
        if (dead_at(id, P.T)) owhere[id] = W_FREED; else v_push(&full_young, id);
    }
    uint64_t guess = CP.live_last;
    if (CP.live_last > CP.live_before) { guess += CP.live_last - CP.live_before; if (guess < CP.live_last || guess > CP.size) guess = CP.size; }
    needed += O.nursery;   /* the prototype reserves room for a full nursery's promotion (heap.c vm_gc, nursery mode) */
    uint64_t ns = grown(CP.size, guess, needed);
    /* the first pass: old live, then the nursery's */
    Ev e; ev_begin(&e, EV_FULL, P); e.how = "full";
    uint64_t now = CP.size + CP.to_kept, during = CP.size + ns;
    if (during > now) footprint_transient(during - now);
    sweep_lists(P.T, UINT32_MAX, &e);
    uint64_t live = compact_order(P.T, &e, CM_COPY);
    CP.used = live; CP.to_kept = ns == CP.size ? CP.size : 0; CP.size = ns;
    for (size_t i = 0; i < full_young.n; i++) {
        uint32_t id = full_young.v[i];
        owhere[id] = W_OLD; oaddr[id] = (uint32_t)(CP.used / 8); CP.used += osize[id]; v_push(&order, id);
        old_occ += osize[id]; old_objs_n++; gen_add(id); ops_line('a', id);
        e.moved_objs++; e.moved_bytes += osize[id]; e.promoted_objs++; e.promoted_bytes += osize[id];
        S.promoted += osize[id]; S.promoted_objs++;
    }
    S.copied_major += e.moved_bytes; S.copied_major_objs += e.moved_objs; S.copy_majors++; S.majors++; S.fulls++;
    los_budget_after(); major_totals(&e); note_over(); ev_end(&e);
    nursery_used = 0; young_lo = P.id;
    uint64_t want = grown(CP.size, CP.used, needed);
    if (want != CP.size || CP.used > CP.size) cp_collect_into(want > CP.size ? want : CP.size, P, "full-grow", EV_FULL);
    CP.live_before = CP.live_last; CP.live_last = CP.used;
}
static void cp_vm_gc(Point P, uint64_t needed, int kind) {
    uint64_t guess = CP.live_last;
    if (CP.live_last > CP.live_before) { guess += CP.live_last - CP.live_before; if (guess < CP.live_last || guess > CP.size) guess = CP.size; }
    cp_collect_into(grown(CP.size, guess, needed), P, "copy", kind);
    uint64_t want = grown(CP.size, CP.used, needed);
    if (want != CP.size) cp_collect_into(want, P, "copy-grow", kind);
    CP.live_before = CP.live_last; CP.live_last = CP.used;
}

/* ======================================================================
   mc: a mark-compact old space (Lisp-2 sliding or Jonkers threaded): one
   heap, bump allocation, every major slides the live objects down in order
   mlton: MLton's choice per major between copying (when a second heap of the
   desired size fits under the limit) and mark-compact (Jonkers), with
   sizeofHeapDesired's ratios (live 8, grow 8, copy 4, markCompact 1.04)
   ====================================================================== */
static struct { uint64_t size, used, live_last, hw; } MC;   /* hw: the bump pointer's high water since the last major (the pages touched) */
static uint64_t mc_target(uint64_t live, uint64_t needed) {
    uint64_t t = limit_bytes ? (limit_bytes > los_committed ? limit_bytes - los_committed : 0) : cap_after(live, O.page);
    if (t < live + needed) t = round_up(live + needed, O.page);
    if (t < O.page) t = O.page;
    return t;
}
static void mc_major(Point P, uint64_t needed) {
    Ev e; ev_begin(&e, EV_MAJOR, P); e.how = O.jonkers ? "jonkers" : "lisp2";
    sweep_lists(P.T, UINT32_MAX, &e);
    uint64_t live = compact_order(P.T, &e, CM_SLIDE);
    if (!O.jonkers) meta_rs_peak = meta_rs_peak > e.marked_objs * O.ptr_bytes ? meta_rs_peak : e.marked_objs * O.ptr_bytes;   /* Lisp-2's forwarding words, as a side table */
    MC.used = MC.hw = live; MC.size = mc_target(live, needed); MC.live_last = live;   /* the pages above the compacted top go back */
    S.mc_majors++; S.majors++;
    major_totals(&e); note_over(); ev_end(&e);
}
static uint64_t ml_desired(uint64_t live, uint64_t cur) {
    double ram = limit_bytes ? (double)(limit_bytes > los_committed ? limit_bytes - los_committed : O.page) : 1e18;
    live = round_up(live ? live : 1, O.page);
    double ratio = ram / (double)live;
    uint64_t res;
    if (ratio >= 8.0 + 8.0) {
        res = live * 8;
        if (0.5 * (double)cur <= (double)res && (double)res <= 1.1 * (double)cur) res = cur; else res = round_up(res, O.page);
    } else if (ratio >= 2.0 * 4.0) res = (uint64_t)(ram / 2) / O.page * O.page;
    else if (ratio >= 4.0 + 8.0) {
        res = (uint64_t)ram - 8 * live;
        if ((double)cur <= (double)res && (double)res <= 1.1 * (double)cur) res = cur; else res = round_up(res, O.page);
    } else if (ratio >= 1.04) res = (uint64_t)ram;
    else res = round_up((uint64_t)((double)live * 1.04), O.page);
    return res;
}
static void ml_major(Point P, uint64_t needed) {
    uint64_t desired = ml_desired(MC.live_last + needed, 0);
    int copy = !limit_bytes || MC.size + desired + los_committed <= limit_bytes;
    Ev e; ev_begin(&e, EV_MAJOR, P); e.how = copy ? "copy" : "jonkers";
    if (copy) footprint_transient(desired);
    sweep_lists(P.T, UINT32_MAX, &e);
    uint64_t live = compact_order(P.T, &e, copy ? CM_COPY : CM_SLIDE);
    MC.used = MC.hw = live; MC.live_last = live;
    if (copy) { MC.size = desired > live + needed ? desired : round_up(live + needed, O.page); S.copied_major += live; S.copy_majors++; }
    else S.mc_majors++;
    uint64_t want = ml_desired(live + needed, MC.size);
    if (want < live + needed) want = round_up(live + needed, O.page);
    MC.size = want;
    S.majors++;
    major_totals(&e); note_over(); ev_end(&e);
}

/* ======================================================================
   immix: a mark-region old space (Blackburn & McKinley 2008). Blocks of
   --block bytes, lines of --line bytes; a line's count is the live objects
   that mark it (a small object, at most a line, marks the line it starts in
   and the next line is skipped implicitly; a medium object marks every line
   it touches; --exact-lines marks every line touched by any object).
   Allocation bumps through holes: the current block's, then recyclable
   blocks' in address order, then free blocks; a medium object that does not
   fit the current hole goes to an overflow block. At a major, opportunistic
   evacuation (--defrag) empties the blocks with the most holes into free
   blocks, within a headroom of --headroom of the committed blocks.
   sticky-immix: the same space with no copying nursery: every object is
   allocated into it, a minor (every --nursery bytes) frees the young dead
   and leaves the young survivors in place (sticky mark bits).
   ====================================================================== */
enum { BK_UNCOMMITTED = 0, BK_FREE, BK_RECYC, BK_FULL, BK_CUR, BK_OVERFLOW };
static struct {
    uint32_t nb, cap, lpb; uint64_t B, L;
    uint8_t *st, *cand, *dirty; uint16_t *lc, *bholes; uint32_t *blive;
    int have_cur, have_ov; uint32_t cur, ovb; uint64_t cursor, limit, ocur, olim;
    Vec32 recyc, freeb, uncommitted; size_t recyc_i;
    uint64_t committed;     /* blocks */
    uint64_t young;         /* sticky-immix: young bytes in the space */
    int defrag_next;        /* the last major left too little free space */
} IX;
static void ix_init(void) {
    IX.B = O.block; IX.L = O.line; IX.lpb = (uint32_t)(IX.B / IX.L);
    if (IX.B % IX.L || IX.lpb < 2) die("--block must be a multiple of --line");
    if (O.los > IX.B) die("immix needs a LOS threshold of at most a block (--los)");
}
static void ix_ensure(uint32_t nb) {
    if (nb <= IX.cap) return;
    uint32_t nc = IX.cap ? IX.cap : 256; while (nc < nb) nc *= 2;
    IX.st = xrealloc(IX.st, nc); memset(IX.st + IX.cap, 0, nc - IX.cap);
    IX.cand = xrealloc(IX.cand, nc); memset(IX.cand + IX.cap, 0, nc - IX.cap);
    IX.dirty = xrealloc(IX.dirty, nc); memset(IX.dirty + IX.cap, 0, nc - IX.cap);
    IX.bholes = xrealloc(IX.bholes, nc * 2ull); memset(IX.bholes + IX.cap, 0, (nc - IX.cap) * 2ull);
    IX.blive = xrealloc(IX.blive, nc * 4ull); memset(IX.blive + IX.cap, 0, (nc - IX.cap) * 4ull);
    IX.lc = xrealloc(IX.lc, (size_t)nc * IX.lpb * 2); memset(IX.lc + (size_t)IX.cap * IX.lpb, 0, (size_t)(nc - IX.cap) * IX.lpb * 2);
    IX.cap = nc;
}
static uint64_t gen_committed_other(void) { return los_committed + mut_committed; }
static int ix_new_block(void) {   /* a free block, or a newly committed one within the cap; -1 if none */
    while (IX.freeb.n) { uint32_t b = IX.freeb.v[--IX.freeb.n]; if (IX.st[b] == BK_FREE) return (int)b; }
    if ((IX.committed + 1) * IX.B + gen_committed_other() > old_cap) return -1;
    uint32_t b;
    if (IX.uncommitted.n) b = IX.uncommitted.v[--IX.uncommitted.n];
    else { b = IX.nb++; ix_ensure(IX.nb); }
    IX.committed++; IX.st[b] = BK_FREE;
    return (int)b;
}
static void ix_mark_lines(uint32_t id, int delta) {
    uint64_t a = (uint64_t)oaddr[id] * 8, s = osize[id];
    uint32_t b = (uint32_t)(a / IX.B); uint64_t off = a % IX.B;
    uint32_t l0 = (uint32_t)(off / IX.L), l1 = (uint32_t)((off + s - 1) / IX.L);
    uint16_t *lc = IX.lc + (size_t)b * IX.lpb;
    if (s <= IX.L && !O.exact_lines) l1 = l0;
    for (uint32_t l = l0; l <= l1; l++) lc[l] = (uint16_t)(lc[l] + delta);
    IX.blive[b] = (uint32_t)((int64_t)IX.blive[b] + (delta > 0 ? (int64_t)s : -(int64_t)s));
    if (delta < 0) IX.dirty[b] = 1;
}
static void ix_put(uint32_t id, uint64_t addr) { oaddr[id] = (uint32_t)(addr / 8); ix_mark_lines(id, 1); }
static int ix_usable(uint32_t b, uint32_t j) {
    const uint16_t *lc = IX.lc + (size_t)b * IX.lpb;
    if (lc[j]) return 0;
    if (!O.exact_lines && j > 0 && lc[j - 1]) return 0;
    return 1;
}
static int ix_hole(uint32_t b, uint32_t from, uint32_t *hs, uint32_t *he) {
    uint32_t j = from;
    while (j < IX.lpb && !ix_usable(b, j)) j++;
    if (j >= IX.lpb) return 0;
    uint32_t e = j;
    const uint16_t *lc = IX.lc + (size_t)b * IX.lpb;
    while (e < IX.lpb && lc[e] == 0) e++;
    *hs = j; *he = e; return 1;
}
static int ix_alloc(uint32_t id) {
    uint64_t s = osize[id];
    if (s > IX.B) die("immix: object %u of %" U64 " bytes is larger than a block (--los)", id, s);
    if (IX.have_cur && IX.cursor + s <= IX.limit) { ix_put(id, IX.cursor); IX.cursor += s; return 1; }
    if (s > IX.L && IX.have_cur) {   /* medium: overflow allocation */
        if (IX.have_ov && IX.ocur + s <= IX.olim) { ix_put(id, IX.ocur); IX.ocur += s; return 1; }
        int b = ix_new_block(); if (b < 0) return 0;
        if (IX.have_ov) IX.st[IX.ovb] = BK_FULL;
        IX.st[b] = BK_OVERFLOW; IX.ovb = (uint32_t)b; IX.have_ov = 1; IX.ocur = (uint64_t)b * IX.B; IX.olim = IX.ocur + IX.B;
        ix_put(id, IX.ocur); IX.ocur += s; return 1;
    }
    for (;;) {
        if (IX.have_cur) {
            uint64_t base = (uint64_t)IX.cur * IX.B;
            uint32_t from = (uint32_t)((IX.limit - base + IX.L - 1) / IX.L);
            uint32_t hs, he;
            if (from < IX.lpb && ix_hole(IX.cur, from, &hs, &he)) {
                IX.cursor = base + hs * IX.L; IX.limit = base + he * IX.L;
                if (IX.cursor + s <= IX.limit) { ix_put(id, IX.cursor); IX.cursor += s; return 1; }
                continue;
            }
            IX.st[IX.cur] = BK_FULL; IX.have_cur = 0;
        }
        while (IX.recyc_i < IX.recyc.n) {
            uint32_t b = IX.recyc.v[IX.recyc_i++];
            if (IX.st[b] != BK_RECYC) continue;
            IX.st[b] = BK_CUR; IX.cur = b; IX.have_cur = 1; IX.cursor = IX.limit = (uint64_t)b * IX.B;
            break;
        }
        if (IX.have_cur) continue;
        int b = ix_new_block(); if (b < 0) return 0;
        IX.st[b] = BK_CUR; IX.cur = (uint32_t)b; IX.have_cur = 1; IX.cursor = (uint64_t)b * IX.B; IX.limit = IX.cursor + IX.B;
        ix_put(id, IX.cursor); IX.cursor += s; return 1;   /* a free block always holds an object below a block */
    }
}
static void ix_free(uint32_t id) { ix_mark_lines(id, -1); }
/* a block's state from its line counts: free, recyclable (it has a usable hole) or full */
static void ix_state(uint32_t b) {
    if (IX.st[b] == BK_UNCOMMITTED) return;
    IX.dirty[b] = 0;
    if (IX.blive[b] == 0) { IX.st[b] = BK_FREE; IX.bholes[b] = 0; return; }
    uint32_t holes = 0, j = 0, hs, he;
    while (j < IX.lpb && ix_hole(b, j, &hs, &he)) { holes++; j = he; }
    IX.bholes[b] = (uint16_t)holes;
    IX.st[b] = holes ? BK_RECYC : BK_FULL;
}
static void ix_rebuild_lists(void) {
    IX.recyc.n = 0; IX.recyc_i = 0; IX.freeb.n = 0;
    for (uint32_t b = 0; b < IX.nb; b++) {
        if (IX.st[b] == BK_RECYC) v_push(&IX.recyc, b);
        else if (IX.st[b] == BK_FREE) v_push(&IX.freeb, b);
    }
    /* free blocks are taken from the end of the stack: lowest address first */
    for (size_t i = 0, j = IX.freeb.n ? IX.freeb.n - 1 : 0; i < j; i++, j--) { uint32_t t = IX.freeb.v[i]; IX.freeb.v[i] = IX.freeb.v[j]; IX.freeb.v[j] = t; }
}
static void ix_release_above_cap(void) {   /* decommit free blocks the cap no longer covers */
    while (IX.freeb.n && IX.committed * IX.B + gen_committed_other() > rel_cap) {
        uint32_t b = IX.freeb.v[0];
        memmove(IX.freeb.v, IX.freeb.v + 1, (IX.freeb.n - 1) * 4); IX.freeb.n--;   /* the highest address goes first */
        IX.st[b] = BK_UNCOMMITTED; IX.committed--; v_push(&IX.uncommitted, b);
    }
}
static int ix_cmp_cand(const void *a, const void *b) {
    uint32_t x = *(const uint32_t *)a, y = *(const uint32_t *)b;
    if (IX.bholes[x] != IX.bholes[y]) return IX.bholes[x] > IX.bholes[y] ? -1 : 1;
    if (IX.blive[x] != IX.blive[y]) return IX.blive[x] < IX.blive[y] ? -1 : 1;
    return x < y ? -1 : x > y;
}
/* opportunistic evacuation, after the dead are swept: the most fragmented
   blocks (most holes, then least live) are emptied into free blocks while
   the headroom lasts; what does not fit stays in place */
static void ix_defrag(Ev *e) {
    uint64_t headroom = (uint64_t)ceil(O.headroom * (double)IX.committed); if (headroom < 1) headroom = 1;
    Vec32 c = { 0 };
    for (uint32_t b = 0; b < IX.nb; b++) {
        if (IX.st[b] == BK_UNCOMMITTED || IX.blive[b] == 0) continue;
        ix_state(b);
        if (IX.bholes[b] > 0) v_push(&c, b);
    }
    if (!c.n) { free(c.v); return; }
    qsort(c.v, c.n, 4, ix_cmp_cand);
    uint64_t budget = headroom * IX.B, sel = 0;
    for (size_t i = 0; i < c.n; i++) { if (sel + IX.blive[c.v[i]] > budget) break; IX.cand[c.v[i]] = 1; sel += IX.blive[c.v[i]]; }
    free(c.v);
    /* the copy targets: free blocks, bump allocated */
    uint64_t cur = 0, lim = 0; uint64_t used_blocks = 0;
    compact_ids(&old_ids);
    for (size_t i = 0; i < old_ids.n; i++) {
        uint32_t id = old_ids.v[i];
        uint32_t b = (uint32_t)((uint64_t)oaddr[id] * 8 / IX.B);
        if (!IX.cand[b]) continue;
        uint64_t s = osize[id];
        if (cur + s > lim) {
            if (used_blocks >= headroom) continue;
            int nb = ix_new_block();
            if (nb < 0) continue;
            IX.st[nb] = BK_FULL; cur = (uint64_t)nb * IX.B; lim = cur + IX.B; used_blocks++;
        }
        ix_mark_lines(id, -1); oaddr[id] = (uint32_t)(cur / 8); ix_mark_lines(id, 1); cur += s;
        e->evac_objs++; e->evac_bytes += s; ops_line('m', id);
    }
    for (uint32_t b = 0; b < IX.nb; b++) IX.cand[b] = 0;
}
static void ix_frag(Ev *e) {
    uint64_t held = 0, usable = 0, whole = 0, C = IX.committed * IX.B;
    for (uint32_t b = 0; b < IX.nb; b++) {
        if (IX.st[b] == BK_UNCOMMITTED) continue;
        if (IX.blive[b] == 0) { whole += IX.B; continue; }
        const uint16_t *lc = IX.lc + (size_t)b * IX.lpb;
        for (uint32_t j = 0; j < IX.lpb; j++) { if (lc[j]) held += IX.L; else if (ix_usable(b, j)) usable += IX.L; }
    }
    if (!C) return;
    e->held = held; e->usable = usable + whole; e->whole = whole;
    if (IX.L == 8 && O.exact_lines && held != old_occ - IX.young) die("immix: 8-byte lines hold %" U64 " bytes, the live objects %" U64, held, old_occ - IX.young);
    e->frag_int = held > old_occ ? (double)(held - old_occ) / (double)C : 0;
    e->frag_ext = (double)(C - held - whole) / (double)C;
    e->free_usable = (double)(usable + whole) / (double)C;
}

/* ======================================================================
   segfit: segregated fit with OCaml 5's size classes (runtime/caml/
   sizeclasses.h: 32 classes up to 128 words, 4096-word pools with a 4-word
   header and the class's wastage); a pool holds one class; the lowest free
   slot is taken; an empty pool goes back to the free pools. Objects above
   128 words go to the LOS (page-rounded).
   ====================================================================== */
enum { SF_NCLS = 32, SF_POOLW = 4096, SF_HDRW = 4, SF_MAXW = 128 };
static const unsigned sf_wsize[SF_NCLS] = { 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 17, 19, 22, 25, 28, 32, 33, 37, 42, 47, 53, 59, 65, 73, 81, 89, 99, 108, 118, 128 };
static const unsigned char sf_waste[SF_NCLS] = { 0, 0, 0, 0, 2, 0, 4, 4, 2, 0, 4, 12, 12, 7, 0, 17, 4, 28, 0, 22, 18, 3, 11, 21, 62, 4, 42, 87, 33, 96, 80, 124 };
static unsigned char sf_cls_of[SF_MAXW + 1];
#define SF_NONE UINT32_MAX
static struct {
    uint32_t np, cap;
    uint8_t *cls, *st;          /* st: 0 uncommitted, 1 free, 2 in a class */
    uint16_t *nfree, *nslots, *hint;
    uint64_t *bits;             /* 64 words per pool */
    uint32_t cur[SF_NCLS]; Vec32 avail[SF_NCLS], freep, uncommitted;
    uint64_t committed;         /* pools */
} SF;
static void sf_init(void) {
    for (unsigned w = 1, c = 0; w <= SF_MAXW; w++) { while (sf_wsize[c] < w) c++; sf_cls_of[w] = (unsigned char)c; }
    for (int c = 0; c < SF_NCLS; c++) SF.cur[c] = SF_NONE;
    for (int c = 0; c < SF_NCLS; c++) if (SF_HDRW + sf_waste[c] + (SF_POOLW - SF_HDRW - sf_waste[c]) / sf_wsize[c] * sf_wsize[c] != SF_POOLW) die("sizeclasses: wastage of class %d", c);
    if (O.los == 0 || O.los > SF_MAXW * 8 + 1) die("segfit needs a LOS threshold of at most %d bytes (--los)", SF_MAXW * 8 + 1);
}
static void sf_ensure(uint32_t n) {
    if (n <= SF.cap) return;
    uint32_t nc = SF.cap ? SF.cap : 256; while (nc < n) nc *= 2;
#define GROW(p, sz) p = xrealloc(p, (size_t)nc * (sz)); memset((char *)p + (size_t)SF.cap * (sz), 0, (size_t)(nc - SF.cap) * (sz))
    GROW(SF.cls, 1); GROW(SF.st, 1); GROW(SF.nfree, 2); GROW(SF.nslots, 2); GROW(SF.hint, 2); GROW(SF.bits, 64 * 8);
#undef GROW
    SF.cap = nc;
}
static uint32_t sf_new_pool(void) {
    while (SF.freep.n) { uint32_t p = SF.freep.v[--SF.freep.n]; if (SF.st[p] == 1) return p; }
    if ((SF.committed + 1) * (SF_POOLW * 8ull) + gen_committed_other() > old_cap) return SF_NONE;
    uint32_t p = SF.uncommitted.n ? SF.uncommitted.v[--SF.uncommitted.n] : SF.np++;
    sf_ensure(SF.np); SF.committed++; SF.st[p] = 1;
    return p;
}
static int sf_alloc(uint32_t id) {
    unsigned w = (osize[id] + 7) / 8;
    if (w > SF_MAXW) die("segfit: object of %u words above the classes (LOS threshold?)", w);
    unsigned c = sf_cls_of[w];
    uint32_t p = SF.cur[c];
    if (p == SF_NONE || SF.nfree[p] == 0) {
        p = SF_NONE;
        while (SF.avail[c].n) { uint32_t q = SF.avail[c].v[--SF.avail[c].n]; if (SF.st[q] == 2 && SF.cls[q] == c && SF.nfree[q] > 0) { p = q; break; } }
        if (p == SF_NONE) {
            p = sf_new_pool(); if (p == SF_NONE) return 0;
            SF.st[p] = 2; SF.cls[p] = (uint8_t)c; SF.nslots[p] = SF.nfree[p] = (uint16_t)((SF_POOLW - SF_HDRW - sf_waste[c]) / sf_wsize[c]);
            SF.hint[p] = 0; memset(SF.bits + (size_t)p * 64, 0, 64 * 8);
        }
        SF.cur[c] = p;
    }
    uint64_t *bits = SF.bits + (size_t)p * 64;
    unsigned wi = SF.hint[p];
    while (bits[wi] == UINT64_MAX) wi++;
    unsigned slot = wi * 64 + (unsigned)__builtin_ctzll(~bits[wi]);
    bits[wi] |= 1ull << (slot & 63); SF.hint[p] = (uint16_t)wi; SF.nfree[p]--;
    oaddr[id] = (uint32_t)((uint64_t)p * SF_POOLW + SF_HDRW + sf_waste[c] + (uint64_t)slot * sf_wsize[c]);
    return 1;
}
static void sf_free(uint32_t id) {
    uint64_t a = oaddr[id]; uint32_t p = (uint32_t)(a / SF_POOLW); unsigned c = SF.cls[p];
    unsigned slot = (unsigned)((a % SF_POOLW - SF_HDRW - sf_waste[c]) / sf_wsize[c]);
    SF.bits[(size_t)p * 64 + slot / 64] &= ~(1ull << (slot & 63));
    if (slot / 64 < SF.hint[p]) SF.hint[p] = (uint16_t)(slot / 64);
    if (SF.nfree[p]++ == 0 && SF.cur[c] != p) v_push(&SF.avail[c], p);
    if (SF.nfree[p] == SF.nslots[p]) {   /* empty: back to the free pools */
        SF.st[p] = 1; if (SF.cur[c] == p) SF.cur[c] = SF_NONE; v_push(&SF.freep, p);
    }
}
static void sf_release_above_cap(void) {
    /* the free pools of the highest addresses go first */
    Vec32 keep = { 0 };
    for (size_t i = 0; i < SF.freep.n; i++) if (SF.st[SF.freep.v[i]] == 1) v_push(&keep, SF.freep.v[i]);
    free(SF.freep.v); SF.freep = keep;
    while (SF.freep.n && SF.committed * (SF_POOLW * 8ull) + gen_committed_other() > rel_cap) {
        size_t hi = 0; for (size_t i = 1; i < SF.freep.n; i++) if (SF.freep.v[i] > SF.freep.v[hi]) hi = i;
        uint32_t p = SF.freep.v[hi]; SF.freep.v[hi] = SF.freep.v[--SF.freep.n];
        SF.st[p] = 0; SF.committed--; v_push(&SF.uncommitted, p);
    }
}
static void sf_frag(Ev *e) {
    uint64_t held = 0, whole = 0, usable = 0, C = SF.committed * SF_POOLW * 8ull;
    for (uint32_t p = 0; p < SF.np; p++) {
        if (SF.st[p] == 1) { whole += SF_POOLW * 8ull; continue; }
        if (SF.st[p] != 2) continue;
        held += (uint64_t)(SF.nslots[p] - SF.nfree[p]) * sf_wsize[SF.cls[p]] * 8;
        usable += (uint64_t)SF.nfree[p] * sf_wsize[SF.cls[p]] * 8;
    }
    e->held = held; e->usable = usable + whole; e->whole = whole;
    if (!C) return;
    e->frag_int = held > old_occ ? (double)(held - old_occ) / (double)C : 0;
    e->frag_ext = (double)(C - held - whole) / (double)C;
    e->free_usable = (double)(whole + usable) / (double)C;
}

/* ======================================================================
   bestfit / nextfit / firstfit: OCaml 4's free-list old space
   (runtime/freelist.c; best fit the default since 4.10). The heap is made
   of chunks (an increment of --increment % of the heap, at least the
   request, rounded to a page); a chunk never coalesces with another. An
   allocation takes the low end of the block the policy picks; a remainder
   below 16 bytes is a fragment until a sweep merges it. A sweep merges
   every adjacent pair of free blocks. Compaction is OCaml's: after a major,
   when free / live >= --max-overhead %, the live objects slide into one
   chunk of live x (1 + percent_free/100).
   ====================================================================== */
enum { FL_NB = 4096 };     /* exact buckets, in 8-byte granules, below 32 KiB */
#define FL_NIL UINT32_MAX
static struct {
    uint64_t *addr, *size; uint32_t n, cap;
    uint32_t *bnext, *bprev; uint32_t bhead[FL_NB]; uint64_t bbits[FL_NB / 64]; Vec32 big;
    uint64_t *tree; uint32_t tn;
    uint32_t rover;
    uint64_t heap, next_base, nchunks, minobj;
    uint64_t *pa, *ps; size_t pn, pcap;
    uint64_t free_bytes;
} FL;
static int fl_bucket(uint64_t s) { return s / 8 < FL_NB ? (int)(s / 8) : -1; }
static void fl_bucket_add(uint32_t i) {
    uint64_t s = FL.size[i];
    if (s < FL.minobj) return;
    int b = fl_bucket(s);
    if (b < 0) { v_push(&FL.big, i); return; }
    FL.bprev[i] = FL_NIL; FL.bnext[i] = FL.bhead[b];
    if (FL.bhead[b] != FL_NIL) FL.bprev[FL.bhead[b]] = i;
    FL.bhead[b] = i; FL.bbits[b / 64] |= 1ull << (b % 64);
}
static void fl_bucket_del(uint32_t i, uint64_t s) {
    if (s < FL.minobj) return;
    int b = fl_bucket(s);
    if (b < 0) { for (size_t k = 0; k < FL.big.n; k++) if (FL.big.v[k] == i) { FL.big.v[k] = FL.big.v[--FL.big.n]; return; } return; }
    if (FL.bprev[i] != FL_NIL) FL.bnext[FL.bprev[i]] = FL.bnext[i]; else FL.bhead[b] = FL.bnext[i];
    if (FL.bnext[i] != FL_NIL) FL.bprev[FL.bnext[i]] = FL.bprev[i];
    if (FL.bhead[b] == FL_NIL) FL.bbits[b / 64] &= ~(1ull << (b % 64));
}
static void fl_tree_set(uint32_t i) {
    if (!FL.tree) return;
    uint32_t p = FL.tn + i; FL.tree[p] = FL.size[i] >= FL.minobj ? FL.size[i] : 0;
    for (p /= 2; p >= 1; p /= 2) { uint64_t a = FL.tree[2 * p], b = FL.tree[2 * p + 1]; FL.tree[p] = a > b ? a : b; }
}
static void fl_tree_build(void) {
    if (O.old == OLD_BF) return;
    uint32_t tn = 1; while (tn < FL.n + 1) tn *= 2;
    if (tn != FL.tn || !FL.tree) { free(FL.tree); FL.tree = xcalloc(2 * (size_t)tn, 8); FL.tn = tn; }
    memset(FL.tree, 0, 2 * (size_t)tn * 8);
    for (uint32_t i = 0; i < FL.n; i++) FL.tree[tn + i] = FL.size[i] >= FL.minobj ? FL.size[i] : 0;
    for (uint32_t p = tn - 1; p >= 1; p--) { uint64_t a = FL.tree[2 * p], b = FL.tree[2 * p + 1]; FL.tree[p] = a > b ? a : b; }
}
static uint32_t fl_tree_first(uint32_t from, uint64_t s) {   /* the first block at index >= from with size >= s */
    if (from >= FL.n) return FL_NIL;
    /* walk up from the leaf, then down */
    uint32_t p = FL.tn + from;
    if (FL.tree[p] >= s) return from;
    for (;;) {
        if (p == 1) return FL_NIL;
        if (!(p & 1) && FL.tree[p + 1] >= s) { p = p + 1; break; }
        p /= 2;
    }
    while (p < FL.tn) p = FL.tree[2 * p] >= s ? 2 * p : 2 * p + 1;
    uint32_t i = p - FL.tn;
    return i < FL.n ? i : FL_NIL;
}
static void fl_rebuild(void) {
    for (int b = 0; b < FL_NB; b++) FL.bhead[b] = FL_NIL;
    memset(FL.bbits, 0, sizeof FL.bbits); FL.big.n = 0;
    if (O.old == OLD_BF) { FL.bnext = xrealloc(FL.bnext, (size_t)(FL.cap ? FL.cap : 1) * 4); FL.bprev = xrealloc(FL.bprev, (size_t)(FL.cap ? FL.cap : 1) * 4); for (uint32_t i = 0; i < FL.n; i++) fl_bucket_add(i); }
    else fl_tree_build();
    FL.free_bytes = 0; for (uint32_t i = 0; i < FL.n; i++) FL.free_bytes += FL.size[i];
}
static void fl_push_block(uint64_t a, uint64_t s) {
    if (FL.n == FL.cap) {
        FL.cap = FL.cap ? FL.cap * 2 : 1024;
        FL.addr = xrealloc(FL.addr, FL.cap * 8ull); FL.size = xrealloc(FL.size, FL.cap * 8ull);
        if (O.old == OLD_BF) { FL.bnext = xrealloc(FL.bnext, FL.cap * 4ull); FL.bprev = xrealloc(FL.bprev, FL.cap * 4ull); }
    }
    FL.addr[FL.n] = a; FL.size[FL.n] = s; FL.n++;
}
static void fl_init(void) { FL.minobj = O.size_model == SZ_W4 ? 8 : 16; FL.next_base = 0; for (int b = 0; b < FL_NB; b++) FL.bhead[b] = FL_NIL; }
static uint64_t fl_chunk_for(uint64_t need) {
    uint64_t c = FL.heap / 100 * O.increment; if (c < need) c = need;
    if (c < 15 * O.page) c = 15 * O.page;
    return round_up(c, O.page);
}
static int fl_add_chunk(uint64_t need, int force) {
    uint64_t c = fl_chunk_for(need);
    if (!force && FL.heap + c + gen_committed_other() > old_cap) {
        /* a smaller chunk that still fits the cap */
        uint64_t room = old_cap > FL.heap + gen_committed_other() ? old_cap - FL.heap - gen_committed_other() : 0;
        room = room / O.page * O.page;
        if (room < need) return 0;
        c = room;
    }
    uint64_t base = FL.next_base; FL.next_base += c + O.page;   /* a gap: chunks never touch */
    fl_push_block(base, c); FL.heap += c; FL.nchunks++; FL.free_bytes += c;
    if (O.old == OLD_BF) fl_bucket_add(FL.n - 1); else fl_tree_build();
    return 1;
}
static uint32_t fl_find(uint64_t s) {
    if (O.old == OLD_BF) {
        int b0 = fl_bucket(s); if (b0 >= 0 && (uint64_t)b0 * 8 < s) b0++;
        if (b0 >= 0) {
            for (int w = b0 / 64; w < FL_NB / 64; w++) {
                uint64_t m = FL.bbits[w]; if (w == b0 / 64) m &= ~0ull << (b0 % 64);
                if (m) return FL.bhead[w * 64 + __builtin_ctzll(m)];
            }
        }
        uint32_t best = FL_NIL;
        for (size_t k = 0; k < FL.big.n; k++) { uint32_t i = FL.big.v[k]; if (FL.size[i] >= s && (best == FL_NIL || FL.size[i] < FL.size[best] || (FL.size[i] == FL.size[best] && FL.addr[i] < FL.addr[best]))) best = i; }
        return best;
    }
    if (O.old == OLD_FF) return fl_tree_first(0, s);
    uint32_t i = fl_tree_first(FL.rover, s);
    if (i == FL_NIL) i = fl_tree_first(0, s);
    return i;
}
static void fl_take(uint32_t i, uint32_t id) {
    uint64_t s = osize[id], old = FL.size[i];
    if (O.old == OLD_BF) fl_bucket_del(i, old);
    oaddr[id] = (uint32_t)(FL.addr[i] / 8);
    FL.addr[i] += s; FL.size[i] -= s; FL.free_bytes -= s;
    if (O.old == OLD_BF) fl_bucket_add(i); else fl_tree_set(i);
    if (O.old == OLD_NF) FL.rover = i;
}
static int fl_alloc(uint32_t id) {
    uint64_t s = osize[id];
    uint32_t i = fl_find(s);
    if (i == FL_NIL) { if (!fl_add_chunk(s, 0)) return 0; i = fl_find(s); if (i == FL_NIL) die("freelist: a new chunk does not fit %" U64, s); }
    fl_take(i, id);
    return 1;
}
static void fl_free(uint32_t id) {
    if (FL.pn == FL.pcap) { FL.pcap = FL.pcap ? FL.pcap * 2 : 4096; FL.pa = xrealloc(FL.pa, FL.pcap * 8); FL.ps = xrealloc(FL.ps, FL.pcap * 8); }
    FL.pa[FL.pn] = (uint64_t)oaddr[id] * 8; FL.ps[FL.pn] = osize[id]; FL.pn++;
}
static int cmp_u64pair(const void *a, const void *b) { const uint64_t *x = a, *y = b; return x[0] < y[0] ? -1 : x[0] > y[0]; }
static void fl_coalesce(void) {   /* the sweep: merge the free blocks and the dead into maximal free blocks */
    size_t m = 0; for (uint32_t i = 0; i < FL.n; i++) if (FL.size[i]) m++;
    m += FL.pn;
    uint64_t *v = xcalloc(m ? m * 2 : 2, 8); size_t k = 0;
    for (uint32_t i = 0; i < FL.n; i++) if (FL.size[i]) { v[2 * k] = FL.addr[i]; v[2 * k + 1] = FL.size[i]; k++; }
    for (size_t i = 0; i < FL.pn; i++) { v[2 * k] = FL.pa[i]; v[2 * k + 1] = FL.ps[i]; k++; }
    FL.pn = 0;
    qsort(v, k, 16, cmp_u64pair);
    FL.n = 0;
    for (size_t i = 0; i < k; i++) {
        if (FL.n && FL.addr[FL.n - 1] + FL.size[FL.n - 1] == v[2 * i]) FL.size[FL.n - 1] += v[2 * i + 1];
        else fl_push_block(v[2 * i], v[2 * i + 1]);
    }
    free(v);
    if (FL.rover >= FL.n) FL.rover = 0;
    fl_rebuild();
}
static int cmp_by_addr(const void *a, const void *b) { uint32_t x = oaddr[*(const uint32_t *)a], y = oaddr[*(const uint32_t *)b]; return x < y ? -1 : x > y; }
/* OCaml's compaction: slide the live objects into one new chunk */
static void fl_compact(Point P) {
    Ev e; ev_begin(&e, EV_COMPACT, P); e.how = O.jonkers ? "jonkers" : "lisp2";
    compact_ids(&old_ids);
    qsort(old_ids.v, old_ids.n, 4, cmp_by_addr);
    uint64_t live = old_occ;
    uint64_t c = round_up(live / 100 * (100 + O.percent_free) + O.page, O.page);
    if (limit_bytes && c + gen_committed_other() > limit_bytes) c = round_up(live + O.page, O.page);
    e.heap_scan_bytes = FL.heap; e.heap_scan_objs = old_ids.n;
    uint64_t base = 0; FL.next_base = c + O.page;   /* every chunk goes: the new one starts the address space again */
    uint64_t a = base;
    for (size_t i = 0; i < old_ids.n; i++) {
        uint32_t id = old_ids.v[i];
        oaddr[id] = (uint32_t)(a / 8); a += osize[id];
        e.moved_objs++; e.moved_bytes += osize[id]; e.marked_objs++; e.marked_bytes += osize[id]; e.marked_fields += obj_fields(id); e.marked_ptrs += onptr[id];
        ops_line('m', id);
    }
    footprint_transient(c);
    FL.n = 0; FL.pn = 0; fl_push_block(a, base + c - a); FL.heap = c; FL.nchunks = 1; FL.rover = 0;
    fl_rebuild();
    S.compactions++;
    S.moved_bytes += e.moved_bytes; S.moved_objs += e.moved_objs; S.heap_scan_bytes += e.heap_scan_bytes; S.heap_scan_objs += e.heap_scan_objs;
    note_over(); ev_end(&e);
}
static void fl_frag(Ev *e) {
    uint64_t C = FL.heap, whole = 0, usable = 0;
    for (uint32_t i = 0; i < FL.n; i++) { if (FL.size[i] >= O.page) whole += FL.size[i]; if (FL.size[i] >= FL.minobj) usable += FL.size[i]; }
    e->held = old_occ; e->usable = usable; e->whole = whole;
    if (!C) return;
    e->frag_int = 0;
    e->frag_ext = (double)(C - old_occ - whole) / (double)C;
    e->free_usable = (double)usable / (double)C;
}

/* ======================================================================
   chez: Chez Scheme's per-segment choice (c/gc.c:1029-1035): segments of
   --segment bytes, bump allocation into the current one; at a major a
   segment is marked in place when it was never marked (filled by the
   allocator or by copying) or when it was at least --dense full at its last
   marking, and its live objects are copied out to fresh segments otherwise.
   A marked segment's holes are not reused until it is copied.
   ====================================================================== */
#define CZ_NEVER UINT32_MAX
static struct {
    uint32_t ns, cap; uint64_t SEG;
    uint8_t *st, *copy;          /* st: 0 uncommitted, 1 free, 2 used */
    uint32_t *live, *mlast;
    int have_cur; uint32_t cur; uint64_t cursor, limit;
    Vec32 freeseg, uncommitted; uint64_t committed;
} CZ;
static void cz_init(void) { CZ.SEG = O.segment; if (O.los == 0 || O.los > CZ.SEG) die("chez needs a LOS threshold of at most a segment (--los)"); }
static void cz_ensure(uint32_t n) {
    if (n <= CZ.cap) return;
    uint32_t nc = CZ.cap ? CZ.cap : 256; while (nc < n) nc *= 2;
    CZ.st = xrealloc(CZ.st, nc); memset(CZ.st + CZ.cap, 0, nc - CZ.cap);
    CZ.copy = xrealloc(CZ.copy, nc); memset(CZ.copy + CZ.cap, 0, nc - CZ.cap);
    CZ.live = xrealloc(CZ.live, nc * 4ull); memset(CZ.live + CZ.cap, 0, (nc - CZ.cap) * 4ull);
    CZ.mlast = xrealloc(CZ.mlast, nc * 4ull); for (uint32_t i = CZ.cap; i < nc; i++) CZ.mlast[i] = CZ_NEVER;
    CZ.cap = nc;
}
static int cz_new_seg(int force) {
    while (CZ.freeseg.n) { uint32_t s = CZ.freeseg.v[--CZ.freeseg.n]; if (CZ.st[s] == 1) { CZ.st[s] = 2; CZ.mlast[s] = CZ_NEVER; return (int)s; } }
    if (!force && (CZ.committed + 1) * CZ.SEG + gen_committed_other() > old_cap) return -1;
    uint32_t s = CZ.uncommitted.n ? CZ.uncommitted.v[--CZ.uncommitted.n] : CZ.ns++;
    cz_ensure(CZ.ns); CZ.committed++; CZ.st[s] = 2; CZ.mlast[s] = CZ_NEVER; CZ.live[s] = 0;
    return (int)s;
}
static int cz_alloc(uint32_t id) {
    uint64_t s = osize[id];
    if (!CZ.have_cur || CZ.cursor + s > CZ.limit) {
        int g = cz_new_seg(0); if (g < 0) return 0;
        CZ.cur = (uint32_t)g; CZ.have_cur = 1; CZ.cursor = (uint64_t)g * CZ.SEG; CZ.limit = CZ.cursor + CZ.SEG;
    }
    oaddr[id] = (uint32_t)(CZ.cursor / 8); CZ.cursor += s; CZ.live[CZ.cur] += (uint32_t)s;
    return 1;
}
static void cz_free(uint32_t id) { CZ.live[(uint64_t)oaddr[id] * 8 / CZ.SEG] -= osize[id]; }
static void cz_major_post(Ev *e) {
    uint64_t dense = (uint64_t)(O.dense * (double)CZ.SEG);
    CZ.have_cur = 0;
    for (uint32_t g = 0; g < CZ.ns; g++) {
        CZ.copy[g] = 0;
        if (CZ.st[g] != 2) continue;
        if (CZ.live[g] == 0) { CZ.st[g] = 1; v_push(&CZ.freeseg, g); continue; }
        if (CZ.mlast[g] == CZ_NEVER || CZ.mlast[g] >= dense) CZ.mlast[g] = CZ.live[g];
        else CZ.copy[g] = 1;
    }
    compact_ids(&old_ids);
    uint64_t cur = 0, lim = 0; int g2 = -1;
    for (size_t i = 0; i < old_ids.n; i++) {
        uint32_t id = old_ids.v[i];
        uint32_t g = (uint32_t)((uint64_t)oaddr[id] * 8 / CZ.SEG);
        if (!CZ.copy[g]) continue;
        uint64_t s = osize[id];
        if (g2 < 0 || cur + s > lim) { g2 = cz_new_seg(1); cur = (uint64_t)g2 * CZ.SEG; lim = cur + CZ.SEG; }
        CZ.live[g] -= (uint32_t)s; oaddr[id] = (uint32_t)(cur / 8); cur += s; CZ.live[g2] += (uint32_t)s;
        e->evac_objs++; e->evac_bytes += s; ops_line('m', id);
    }
    for (uint32_t g = 0; g < CZ.ns; g++) if (CZ.copy[g]) { CZ.copy[g] = 0; CZ.st[g] = 1; CZ.live[g] = 0; v_push(&CZ.freeseg, g); }
    /* the last copy target becomes the allocation segment */
    if (g2 >= 0) { CZ.cur = (uint32_t)g2; CZ.have_cur = 1; CZ.cursor = cur; CZ.limit = lim; }
}
static void cz_release_above_cap(void) {
    while (CZ.freeseg.n && CZ.committed * CZ.SEG + gen_committed_other() > rel_cap) {
        uint32_t g = CZ.freeseg.v[--CZ.freeseg.n];
        if (CZ.st[g] != 1) continue;
        CZ.st[g] = 0; CZ.committed--; v_push(&CZ.uncommitted, g);
    }
}
static void cz_frag(Ev *e) {
    uint64_t C = CZ.committed * CZ.SEG, whole = 0;
    for (uint32_t g = 0; g < CZ.ns; g++) if (CZ.st[g] == 1) whole += CZ.SEG;
    e->held = old_occ; e->usable = whole + (CZ.have_cur ? CZ.limit - CZ.cursor : 0); e->whole = whole;
    if (!C) return;
    e->frag_int = 0;
    e->frag_ext = (double)(C - old_occ - whole) / (double)C;
    e->free_usable = (double)whole / (double)C;
}

/* ======================================================================
   The old space's operations, by model
   ====================================================================== */
static int os_alloc(uint32_t id) {
    uint64_t s = osize[id];
    switch (O.old) {
    case OLD_COPY:
        if (s > CP.size - CP.used) return 0;
        oaddr[id] = (uint32_t)(CP.used / 8); CP.used += s; v_push(&order, id); return 1;
    case OLD_MC: case OLD_MLTON:
        if (s > MC.size - MC.used) return 0;
        oaddr[id] = (uint32_t)(MC.used / 8); MC.used += s; if (MC.used > MC.hw) MC.hw = MC.used; v_push(&order, id); return 1;
    case OLD_IMMIX: case OLD_STICKY: return ix_alloc(id);
    case OLD_SEGFIT: return sf_alloc(id);
    case OLD_BF: case OLD_NF: case OLD_FF: return fl_alloc(id);
    case OLD_CHEZ: return cz_alloc(id);
    }
    return 0;
}
static void os_free(uint32_t id) {
    switch (O.old) {
    case OLD_IMMIX: case OLD_STICKY: ix_free(id); break;
    case OLD_SEGFIT: sf_free(id); break;
    case OLD_BF: case OLD_NF: case OLD_FF: fl_free(id); break;
    case OLD_CHEZ: cz_free(id); break;
    default: break;
    }
}
static void os_grow(uint64_t need) {   /* room for `need` beyond what a major left */
    S.grow_forced++;
    switch (O.old) {
    case OLD_COPY: { Point P = point_at(cur_id); cp_collect_into(grown(CP.size, CP.used, need), P, "copy-grow", EV_MAJOR); break; }
    case OLD_MC: case OLD_MLTON: MC.size = round_up(MC.used + need, O.page); break;   /* hw follows the allocation */
    case OLD_IMMIX: case OLD_STICKY: old_cap = (IX.committed + (need + IX.B - 1) / IX.B + 1) * IX.B + gen_committed_other(); break;
    case OLD_SEGFIT: old_cap = (SF.committed + 1) * SF_POOLW * 8ull + gen_committed_other(); break;
    case OLD_BF: case OLD_NF: case OLD_FF: fl_add_chunk(need, 1); old_cap = FL.heap + gen_committed_other(); break;
    case OLD_CHEZ: old_cap = (CZ.committed + 1) * CZ.SEG + gen_committed_other(); break;
    }
    note_over();
}
static uint64_t os_committed(void) {
    switch (O.old) {
    case OLD_COPY: return CP.size + CP.to_kept;
    case OLD_MC: case OLD_MLTON: return MC.hw;   /* the pages touched; the heap's size is reserved */
    case OLD_IMMIX: case OLD_STICKY: return IX.committed * IX.B;
    case OLD_SEGFIT: return SF.committed * SF_POOLW * 8ull;
    case OLD_BF: case OLD_NF: case OLD_FF: return FL.heap;
    case OLD_CHEZ: return CZ.committed * CZ.SEG;
    }
    return 0;
}
static uint64_t os_reserved(void) {   /* address space: blocks ever committed (block spaces keep their range) */
    switch (O.old) {
    case OLD_IMMIX: case OLD_STICKY: return (uint64_t)IX.nb * IX.B;
    case OLD_SEGFIT: return (uint64_t)SF.np * SF_POOLW * 8ull;
    case OLD_CHEZ: return (uint64_t)CZ.ns * CZ.SEG;
    case OLD_MC: case OLD_MLTON: return MC.size;
    default: return os_committed();
    }
}
static uint64_t os_meta(void) {
    uint64_t c = os_committed(), m = 0;
    unsigned gran = O.size_model == SZ_W4 ? 4 : 8;
    if (O.bitmap && !os_moving()) m += c / gran / 8;            /* a side mark bitmap: a bit per granule */
    switch (O.old) {
    case OLD_IMMIX: case OLD_STICKY: m += (uint64_t)IX.committed * IX.lpb + (uint64_t)IX.nb * (8 + 2 * O.ptr_bytes); break;  /* line marks, block descriptors */
    case OLD_SEGFIT: m += (uint64_t)SF.np * 2 * O.ptr_bytes; break;   /* the pools' list links (the pool header is in the pool) */
    case OLD_CHEZ: m += (uint64_t)CZ.ns * (16 + 2 * O.ptr_bytes) + c / gran / 8; break;   /* segment info, mark masks */
    case OLD_MC: case OLD_MLTON: m += c / gran / 8; break;      /* the mark bitmap the compactor walks */
    default: break;
    }
    return m;
}
static void os_frag(Ev *e) {
    e->frag_int = e->frag_ext = 0; e->free_usable = 0;
    switch (O.old) {
    case OLD_IMMIX: case OLD_STICKY: ix_frag(e); break;
    case OLD_SEGFIT: sf_frag(e); break;
    case OLD_BF: case OLD_NF: case OLD_FF: fl_frag(e); break;
    case OLD_CHEZ: cz_frag(e); break;
    case OLD_COPY: if (CP.size) e->free_usable = (double)(CP.size - CP.used) / (double)(CP.size + CP.to_kept); break;
    case OLD_MC: case OLD_MLTON: if (MC.size) e->free_usable = (double)(MC.size - MC.used) / (double)MC.size; break;
    }
}
static uint64_t os_step(void) {
    switch (O.old) {
    case OLD_IMMIX: case OLD_STICKY: return IX.B;
    case OLD_SEGFIT: return SF_POOLW * 8ull;
    case OLD_CHEZ: return CZ.SEG;
    default: return O.page;
    }
}

/* ======================================================================
   The engine
   ====================================================================== */
static HMap rs_a, rs_b, *rs = &rs_a;       /* remembered slots (src<<16|field) -> the young object stored */
static HMap cards_oy, cards_ptr, cards_any; /* dirty cards: old->young stores, pointer stores, any store, into old objects */
static uint64_t last_minor_clock, last_major_clock;
static uint64_t mut_stores_nobarrier;
static struct { int active; uint32_t T0, id0; uint64_t work, done, last_clock, peak, clock0; } SB;
/* pretenuring */
static HMap site_ix; static uint64_t *site_alloc, *site_surv; static uint32_t *site_pc; static uint32_t nsites, site_cap;
static HMap pt_sites; static uint32_t learn_until_id = UINT32_MAX, pt_from_id = 0;

static int is_young(uint32_t id) { return id && id <= N && (owhere[id] == W_YOUNG || owhere[id] == W_SURV); }
static int in_old_gen(uint32_t id) { return id && id <= N && owhere[id] >= W_OLD && owhere[id] <= W_MUT; }
static uint64_t slot_addr(uint32_t src, unsigned field) {
    uint64_t base = owhere[src] == W_LOS ? (1ull << 40) : owhere[src] == W_MUT ? (1ull << 41) : 0;
    return base + (uint64_t)oaddr[src] * 8 + hdr_bytes + (uint64_t)field * (O.size_model == SZ_L0 ? 16 : word_bytes);
}
static void on_store(const Store *s) {
    S.stores++; S.stores_site[s->site < 3 ? s->site : 2]++;
    if (s->dst) S.stores_ptr++;
    if (s->src == 0 || s->src > N) return;
    if (SB.active && (s->flags & 1)) {
        S.satb_log++;
        if (s->oldid && in_old_gen(s->oldid) && s->oldid < SB.id0) S.satb_log_old++;
    }
    if (!in_old_gen(s->src)) return;
    S.stores_old_src++;
    if (O.nursery == 0 && O.old != OLD_STICKY) return;   /* nothing is young: no barrier to count (the sets are cleared only by minors) */
    if (owhere[s->src] == W_MUT) { mut_stores_nobarrier++; return; }   /* the mutable space is scanned whole: no barrier */
    uint64_t card = slot_addr(s->src, s->field) / 512;
    *hm_find(&cards_any, card, 1) = 1;
    if (s->dst) *hm_find(&cards_ptr, card, 1) = 1;
    if (is_young(s->dst)) {
        S.oy_site[s->site < 3 ? s->site : 2]++;
        *hm_find(rs, ((uint64_t)s->src << 32) | s->field, 1) = s->dst;
        *hm_find(&cards_oy, card, 1) = 1;
    }
}

static void major(Point P, uint64_t needed);
static void satb_end(Point P, int degenerate);
static void ev_stack(Ev *e) { e->slots = e->depth; S.slots_total += e->depth; S.low_slots_total += e->depth > e->low ? e->depth - e->low : 0; }

/* place an object in the old space proper: collect when it does not fit, grow when that did not help */
static int major_worth_it(void) {   /* a non-moving space under a limit: has enough been placed since the last major? */
    if (os_moving() || !limit_bytes) return 1;
    uint64_t g = limit_bytes / 100; if (g < os_step()) g = os_step();
    return old_alloc_since_major >= g;
}
static void place_old(uint32_t id) {
    owhere[id] = W_OLD;
    if (!os_alloc(id)) {
        Point P = point_at(cur_id);
        if (major_worth_it()) major(P, osize[id]);
        if (!os_alloc(id)) { os_grow(osize[id]); if (!os_alloc(id)) die("cannot place object %u of %u bytes", id, osize[id]); }
    }
    old_occ += osize[id]; old_objs_n++; gen_add(id); old_alloc_since_major += osize[id];
    if (!os_moving()) { dl_push(id); v_push(&old_ids, id); if (old_ids.n > 2 * old_objs_n + (1u << 20)) compact_ids(&old_ids); }
    ops_line('a', id);
}
static void place_los(uint32_t id) {
    uint64_t pages = los_pages(id);
    int over = os_moving() ? (los_committed + pages > (los_budget ? los_budget : O.heap0))
                           : (os_committed() + los_committed + mut_committed + pages > old_cap);
    if (over) {
        Point P = point_at(cur_id);
        if (major_worth_it()) major(P, 0);
        if (os_moving()) { if (los_committed + pages > los_budget) los_budget = grown(los_budget, los_committed, pages); }
        else if (os_committed() + los_committed + mut_committed + pages > old_cap) { old_cap = os_committed() + los_committed + mut_committed + pages; S.grow_forced++; }
    }
    los_place(id); los_objs_n++; gen_add(id); note_over(); old_alloc_since_major += osize[id];
}
static void place_mut(uint32_t id) {
    owhere[id] = W_MUT; oaddr[id] = (uint32_t)(mut_occ / 8);   /* an address for its cards; the space is scanned whole */
    mut_occ += osize[id]; mut_objs_n++; S.mut_bytes += osize[id]; S.mut_objs++;
    uint64_t c = round_up(mut_occ, 32768); if (c > mut_committed) mut_committed = c;
    gen_add(id); dl_push(id); ops_line('a', id); old_alloc_since_major += osize[id];
}

/* --promote 2: the survivor space; its two halves each as large as the most it held */
static void surv_put(uint32_t id) { owhere[id] = W_SURV; v_push(&survivors, id); surv_bytes += osize[id]; }

/* --order bfs|dfs: a Cheney-like order of a minor's survivors from their
   fill-time pointers (graph.bin): the survivors no other survivor points to
   (the roots' targets, newest first) start the walk; what the walk does not
   reach follows in allocation order */
static uint8_t *ord_mark;
static Vec32 ord_out, ord_q;
static void order_walk(Vec32 *v) {
    if (!O.order || !graph || v->n < 2) return;
    if (!ord_mark) ord_mark = xcalloc((size_t)N + 2, 1);
    for (size_t i = 0; i < v->n; i++) ord_mark[v->v[i]] = 1;            /* 1: in the set */
    for (size_t i = 0; i < v->n; i++) {                                    /* 2: pointed to by another survivor */
        uint32_t id = v->v[i];
        if (!kind_has_fields(okind[id])) continue;
        for (uint32_t f = ofld[id]; f < ofld[id + 1]; f++) { uint32_t t = graph[f]; if (t && t <= N && t != id && ord_mark[t] == 1) ord_mark[t] = 2; }
    }
    ord_out.n = 0;
    for (size_t r = v->n; r-- > 0; ) {
        uint32_t root = v->v[r];
        if (ord_mark[root] != 1) continue;
        ord_q.n = 0; v_push(&ord_q, root); ord_mark[root] = 3;            /* 3: placed */
        for (size_t qi = 0; qi < ord_q.n; ) {
            uint32_t id;
            if (O.order == 1) id = ord_q.v[qi++]; else id = ord_q.v[--ord_q.n];
            v_push(&ord_out, id);
            if (!kind_has_fields(okind[id])) continue;
            if (O.order == 1) { for (uint32_t f = ofld[id]; f < ofld[id + 1]; f++) { uint32_t t = graph[f]; if (t && t <= N && (ord_mark[t] == 1 || ord_mark[t] == 2)) { ord_mark[t] = 3; v_push(&ord_q, t); } } }
            else { for (uint32_t f = ofld[id + 1]; f-- > ofld[id]; ) { uint32_t t = graph[f]; if (t && t <= N && (ord_mark[t] == 1 || ord_mark[t] == 2)) { ord_mark[t] = 3; v_push(&ord_q, t); } } }
            if (O.order == 2) qi = 0;
        }
    }
    for (size_t i = 0; i < v->n; i++) if (ord_mark[v->v[i]] != 3) { v_push(&ord_out, v->v[i]); ord_mark[v->v[i]] = 3; }
    for (size_t i = 0; i < v->n; i++) ord_mark[v->v[i]] = 0;
    memcpy(v->v, ord_out.v, v->n * 4);
}
static void shuffle(Vec32 *v) { for (size_t i = v->n; i > 1; i--) { size_t j = rnd() % i; uint32_t t = v->v[i - 1]; v->v[i - 1] = v->v[j]; v->v[j] = t; } }
static uint32_t site_index(uint32_t pc) {
    uint32_t *p = hm_find(&site_ix, pc, 1);
    if (!*p) {
        if (nsites == site_cap) { site_cap = site_cap ? site_cap * 2 : 4096; site_alloc = xrealloc(site_alloc, site_cap * 8ull); site_surv = xrealloc(site_surv, site_cap * 8ull); site_pc = xrealloc(site_pc, site_cap * 4ull); }
        site_alloc[nsites] = site_surv[nsites] = 0; site_pc[nsites] = pc; *p = ++nsites;
    }
    return *p - 1;
}

/* a minor collection at P: the nursery's (and the survivor space's) live
   objects are promoted or kept, the remembered set and the cards are
   consumed, the stack and the roots scanned */
static Vec32 to_old, to_surv;
static void minor(Point P) {
    Ev e; ev_begin(&e, EV_MINOR, P);
    int instead = 0;   /* a full collection took the minor's place */
    ev_stack(&e);
    e.remset = rs->n; e.cards = cards_oy.n; e.cards_ptr = cards_ptr.n; e.cards_any = cards_any.n;
    e.born_rem = born_rem.n; for (size_t i = 0; i < born_rem.n; i++) e.born_rem_fields += obj_fields(born_rem.v[i]);
    if (O.mutable_space) { e.mut_scan_bytes = mut_occ; e.mut_scan_objs = mut_objs_n; }
    to_old.n = to_surv.n = 0;
    /* age 1: what the previous minor kept in the survivor space */
    for (size_t i = 0; i < survivors.n; i++) {
        uint32_t id = survivors.v[i];
        if (owhere[id] != W_SURV) continue;
        if (dead_at(id, P.T)) owhere[id] = W_FREED; else v_push(&to_old, id);
    }
    uint64_t surv_bytes_before = surv_bytes;
    survivors.n = 0; surv_bytes = 0;
    /* age 0: the nursery */
    uint64_t surv = 0, survo = 0;
    for (uint32_t id = young_lo; id < P.id; id++) {
        if (owhere[id] != W_YOUNG) continue;
        int alive = !dead_at(id, P.T);
        if (O.learn && id < learn_until_id) { uint32_t si = site_index(osite[id]); site_alloc[si] += osize[id]; if (alive) site_surv[si] += osize[id]; }
        if (!alive) { owhere[id] = W_FREED; continue; }
        surv += osize[id]; survo++;
        v_push(O.promote == 1 ? &to_old : &to_surv, id);
    }
    S.surv_first += surv; S.surv_first_objs += survo;
    if (O.shuffle) { shuffle(&to_old); shuffle(&to_surv); }
    if (O.order) { order_walk(&to_old); order_walk(&to_surv); }
    uint64_t to_old_bytes = 0; for (size_t i = 0; i < to_old.n; i++) to_old_bytes += osize[to_old.v[i]];
    /* the copying old space, the prototype's way: when old space has less
       room than the nursery holds, a full collection instead of the minor */
    if (O.old == OLD_COPY && O.full == FULL_APPEL && CP.size - CP.used < nursery_used + surv_bytes_before) {
        /* give the full collection back what the minor sorted: the survivor space (age 1) and the nursery (age 0) */
        if (O.promote == 2) { for (size_t i = 0; i < to_old.n; i++) { owhere[to_old.v[i]] = W_SURV; v_push(&survivors, to_old.v[i]); } }
        else for (size_t i = 0; i < to_old.n; i++) owhere[to_old.v[i]] = W_YOUNG;
        for (size_t i = 0; i < to_surv.n; i++) owhere[to_surv.v[i]] = W_YOUNG;
        to_old.n = to_surv.n = 0;
        cp_full(P, 0);
        instead = 1;
        last_major_clock = cur_clock;
    } else {
        for (size_t i = 0; i < to_old.n; i++) {
            uint32_t id = to_old.v[i];
            if (O.los && osize[id] >= O.los) place_los(id); else place_old(id);
            e.promoted_objs++; e.promoted_bytes += osize[id]; e.copied_objs++; e.copied_bytes += osize[id];
        }
        for (size_t i = 0; i < to_surv.n; i++) { surv_put(to_surv.v[i]); e.copied_objs++; e.copied_bytes += osize[to_surv.v[i]]; S.surv_copied += osize[to_surv.v[i]]; }
        S.promoted += e.promoted_bytes; S.promoted_objs += e.promoted_objs; S.copied_minor += e.copied_bytes;
    }
    if (surv_bytes > S.max_surv_space) S.max_surv_space = surv_bytes;
    /* pretenured objects since the last minor: would they have been copied? */
    for (size_t i = 0; i < pt_since.n; i++) { uint32_t id = pt_since.v[i]; if (dead_at(id, P.T)) S.pt_garbage += osize[id]; else S.pt_saved += osize[id]; }
    pt_since.n = 0;
    if (instead) { e.remset = e.cards = e.cards_ptr = e.cards_any = e.born_rem = e.born_rem_fields = e.mut_scan_bytes = 0; }
    /* the remembered set: what the minor consumed; under --promote 2 the slots that still point into the survivor space stay */
    S.remset_total += e.remset; if (e.remset > S.remset_max) S.remset_max = e.remset;
    S.cards_total += e.cards; if (e.cards > S.cards_max) S.cards_max = e.cards;
    S.cards_ptr_total += e.cards_ptr; S.cards_any_total += e.cards_any;
    S.born_rem_total += e.born_rem; S.born_rem_fields += e.born_rem_fields;
    S.mut_scan_total += e.mut_scan_bytes; if (e.mut_scan_bytes > S.mut_scan_max) S.mut_scan_max = e.mut_scan_bytes;
    { uint64_t m = (uint64_t)e.remset * O.ptr_bytes; if (m > meta_rs_peak) meta_rs_peak = m; }
    HMap *nrs = rs == &rs_a ? &rs_b : &rs_a;
    hm_clear(nrs); hm_clear(&cards_oy); hm_clear(&cards_ptr); hm_clear(&cards_any);
    if (O.promote == 2)
        for (size_t i = 0; i < rs->cap; i++) if (rs->gen[i] == rs->cur && owhere[rs->vals[i]] == W_SURV && in_old_gen((uint32_t)(rs->keys[i] >> 32))) {
            uint32_t src = (uint32_t)(rs->keys[i] >> 32);
            *hm_find(nrs, rs->keys[i], 1) = rs->vals[i];
            *hm_find(&cards_oy, slot_addr(src, (unsigned)(rs->keys[i] & 0xFFFFFFFFu)) / 512, 1) = 1;
        }
    hm_clear(rs); rs = nrs;
    born_rem.n = 0;
    nursery_used = 0; young_lo = P.id; low_since = UINT32_MAX; last_minor_clock = cur_clock;
    if (instead) { S.fulls_instead++; return; }
    S.minors++;
    if (SB.active) {
        uint64_t inc = (uint64_t)(O.satb_k * (double)(cur_clock - SB.last_clock)); SB.last_clock = cur_clock;
        if (SB.done + inc > SB.work) inc = SB.work - SB.done;
        SB.done += inc; e.satb_work = inc; S.satb_work_total += inc;
    }
    ev_end(&e);
    if (SB.active && SB.done >= SB.work) satb_end(P, 0);
}

/* sticky-immix's minor: the young dead are freed in place, the young survivors become old where they are */
static void sticky_minor(Point P) {
    Ev e; ev_begin(&e, EV_STICKY_MINOR, P);
    ev_stack(&e);
    e.remset = rs->n; e.cards = cards_oy.n; e.cards_ptr = cards_ptr.n; e.cards_any = cards_any.n;
    e.born_rem = born_rem.n; for (size_t i = 0; i < born_rem.n; i++) e.born_rem_fields += obj_fields(born_rem.v[i]);
    uint64_t surv = 0, survo = 0;
    for (uint32_t id = young_lo; id < P.id; id++) {
        if (owhere[id] != W_YOUNG) continue;
        if (O.learn && id < learn_until_id) { uint32_t si = site_index(osite[id]); site_alloc[si] += osize[id]; if (!dead_at(id, P.T)) site_surv[si] += osize[id]; }
        if (dead_at(id, P.T)) { ix_free(id); old_occ -= osize[id]; IX.young -= osize[id]; owhere[id] = W_FREED; e.swept_objs++; e.swept_bytes += osize[id]; ops_line('f', id); continue; }
        owhere[id] = W_OLD; IX.young -= osize[id]; old_objs_n++; gen_add(id); dl_push(id); v_push(&old_ids, id);
        if (old_ids.n > 2 * old_objs_n + (1u << 20)) compact_ids(&old_ids);
        surv += osize[id]; survo++; e.marked_objs++; e.marked_bytes += osize[id]; e.marked_fields += obj_fields(id);
    }
    S.surv_first += surv; S.surv_first_objs += survo;
    for (size_t i = 0; i < pt_since.n; i++) { uint32_t id = pt_since.v[i]; if (dead_at(id, P.T)) S.pt_garbage += osize[id]; else S.pt_saved += osize[id]; }
    pt_since.n = 0;
    S.remset_total += e.remset; if (e.remset > S.remset_max) S.remset_max = e.remset;
    S.cards_total += e.cards; if (e.cards > S.cards_max) S.cards_max = e.cards;
    S.cards_ptr_total += e.cards_ptr; S.cards_any_total += e.cards_any;
    S.born_rem_total += e.born_rem; S.born_rem_fields += e.born_rem_fields;
    { uint64_t m = (uint64_t)e.remset * O.ptr_bytes; if (m > meta_rs_peak) meta_rs_peak = m; }
    hm_clear(rs); hm_clear(&cards_oy); hm_clear(&cards_ptr); hm_clear(&cards_any); born_rem.n = 0;
    /* the blocks the minor freed lines in may be recyclable now; the allocator starts over */
    for (uint32_t b = 0; b < IX.nb; b++) if (IX.dirty[b] || IX.st[b] == BK_CUR || IX.st[b] == BK_OVERFLOW) ix_state(b);
    IX.have_cur = IX.have_ov = 0; ix_rebuild_lists();
    S.marked_major += 0; S.minors++;
    young_lo = P.id; low_since = UINT32_MAX; last_minor_clock = cur_clock; nursery_used = 0;
    ev_end(&e);
}

/* a major collection of the old generation */
static void nm_post(Ev *e, Point P, int defrag) {
    (void)P;
    switch (O.old) {
    case OLD_IMMIX: case OLD_STICKY:
        if (defrag) ix_defrag(e);
        for (uint32_t b = 0; b < IX.nb; b++) ix_state(b);
        IX.have_cur = IX.have_ov = 0;
        break;
    case OLD_BF: case OLD_NF: case OLD_FF: fl_coalesce(); break;
    case OLD_CHEZ: cz_major_post(e); break;
    default: break;
    }
}
/* after a major of a non-moving old generation: without a limit, the next
   major at live/fill of occupancy (plus what the triggering allocation
   needs); with a limit, the limit, unless the space cannot keep 2% of the
   limit usable: then it overflows by 5% of the limit rather than thrash */
static void nm_set_cap(uint64_t live, uint64_t usable, uint64_t needed) {
    uint64_t step = os_step(), committed = os_committed() + gen_committed_other();
    if (!limit_bytes) {
        uint64_t t = live / O.fill * 100 + live % O.fill * 100 / O.fill + needed;
        trig_occ = t > O.heap0 ? t : O.heap0;
        old_cap = UINT64_MAX / 4; rel_cap = round_up(trig_occ, step);
        return;
    }
    uint64_t unusable = committed > usable ? committed - usable : 0;
    uint64_t floor_free = limit_bytes / 50; if (floor_free < needed + step) floor_free = needed + step;
    if (unusable + floor_free <= limit_bytes) old_cap = limit_bytes;
    else old_cap = round_up(unusable + limit_bytes / 20 + needed, step);
    rel_cap = old_cap;
}
static void nm_cap_and_release(uint64_t live, uint64_t needed) {
    Ev f; memset(&f, 0, sizeof f); os_frag(&f);
    nm_set_cap(live, (uint64_t)(f.free_usable * (double)os_committed()), needed);
    switch (O.old) {
    case OLD_IMMIX: case OLD_STICKY: ix_rebuild_lists(); ix_release_above_cap(); break;
    case OLD_SEGFIT: sf_release_above_cap(); break;
    case OLD_CHEZ: cz_release_above_cap(); break;
    case OLD_BF: case OLD_NF: case OLD_FF: if (FL.heap + gen_committed_other() > old_cap) old_cap = FL.heap + gen_committed_other(); break;   /* chunks are not given back (until a compaction) */
    default: break;
    }
}
static void nm_major(Point P, uint64_t needed) {
    Ev e; ev_begin(&e, EV_MAJOR, P); e.how = old_names[O.old];
    ev_stack(&e);
    int defrag = 0;
    if ((O.old == OLD_IMMIX || O.old == OLD_STICKY) && O.defrag && !O.satb)
        defrag = IX.recyc_i < IX.recyc.n || IX.defrag_next;
    if (O.old == OLD_STICKY) {   /* the young are collected with the rest: survivors become old */
        for (uint32_t id = young_lo; id < P.id; id++) {
            if (owhere[id] != W_YOUNG) continue;
            if (dead_at(id, P.T)) { ix_free(id); old_occ -= osize[id]; IX.young -= osize[id]; owhere[id] = W_FREED; e.swept_objs++; e.swept_bytes += osize[id]; ops_line('f', id); continue; }
            owhere[id] = W_OLD; IX.young -= osize[id]; old_objs_n++; gen_add(id); dl_push(id); v_push(&old_ids, id);
        }
        young_lo = P.id; nursery_used = 0;
        hm_clear(rs); hm_clear(&cards_oy); hm_clear(&cards_ptr); hm_clear(&cards_any); born_rem.n = 0;
    }
    uint64_t committed0 = os_committed();
    sweep_lists(P.T, UINT32_MAX, &e);
    e.marked_objs = gen_objs; e.marked_bytes = old_occ + los_occ + mut_occ; e.marked_fields = gen_fields; e.marked_ptrs = gen_ptrs;
    e.sweep_scan_bytes = committed0 + los_committed + mut_committed;
    nm_post(&e, P, defrag);
    uint64_t live = old_occ + los_occ + mut_occ;
    nm_cap_and_release(live, needed);
    if (O.old == OLD_IMMIX || O.old == OLD_STICKY) IX.defrag_next = IX.freeb.n * IX.B < (uint64_t)(O.headroom * (double)IX.committed * (double)IX.B);
    S.majors++;
    major_totals(&e); note_over(); ev_end(&e);
    /* OCaml's compaction, after a major that left too much free */
    if ((O.old == OLD_BF || O.old == OLD_NF || O.old == OLD_FF) && O.max_overhead && S.majors >= 3 && old_occ) {
        uint64_t freeb = FL.heap - old_occ;
        if (FL.heap > 2 * 15 * O.page && (double)freeb * 100.0 / (double)old_occ >= O.max_overhead) { fl_compact(P); nm_cap_and_release(live, needed); }
    }
}
static void major(Point P, uint64_t needed) {
    old_alloc_since_major = 0;
    if (SB.active) { satb_end(P, 1); return; }
    switch (O.old) {
    case OLD_COPY: if (O.nursery && O.full == FULL_APPEL) cp_full(P, needed); else cp_vm_gc(P, needed, EV_MAJOR); break;
    case OLD_MC: mc_major(P, needed); break;
    case OLD_MLTON: ml_major(P, needed); break;
    default: nm_major(P, needed); break;
    }
    last_major_clock = cur_clock;
}

/* SATB: a cycle starts when the old generation is --satb-start full; it marks
   --satb k bytes per byte allocated; objects allocated during it are black;
   at its end the dead of the snapshot are swept (lazily) and what died
   during it floats to the next cycle */
static int satb_capable(void) { return O.old == OLD_IMMIX || O.old == OLD_SEGFIT || O.old == OLD_BF || O.old == OLD_NF || O.old == OLD_FF || O.old == OLD_CHEZ; }
static void satb_start(Point P) {
    Ev e; ev_begin(&e, EV_SATB_START, P);
    ev_stack(&e);
    SB.active = 1; SB.T0 = P.T; SB.id0 = P.id; SB.last_clock = SB.clock0 = cur_clock; SB.done = 0;
    SB.work = old_occ + los_occ + mut_occ - unswept_dead(P.T, dl_next);
    SB.peak = old_occ + los_occ + mut_occ;
    S.satb_cycles++;
    ev_end(&e);
}
static void satb_end(Point P, int degenerate) {
    Ev e; ev_begin(&e, EV_SATB_END, P); e.how = degenerate ? "degenerate" : "lazy";
    if (degenerate) { e.satb_work = SB.work - SB.done; S.satb_degenerate++; S.satb_work_total += e.satb_work; ev_stack(&e); }
    uint64_t floating = 0;
    for (uint32_t d = SB.T0; d < P.T && d <= nsamples; d++)
        for (uint32_t id = dl_head[d]; id; id = olink[id]) if (owhere[id] >= W_OLD && owhere[id] <= W_MUT && id < SB.id0) floating += osize[id];
    S.satb_float_total += floating; if (floating > S.satb_float_max) S.satb_float_max = floating;
    uint64_t occ = old_occ + los_occ + mut_occ; if (occ > SB.peak) SB.peak = occ;
    if (SB.peak > S.satb_occ_peak) S.satb_occ_peak = SB.peak;
    uint64_t committed0 = os_committed();
    sweep_lists(SB.T0, SB.id0, &e);
    e.marked_objs = gen_objs; e.marked_bytes = SB.work; e.marked_fields = gen_fields; e.marked_ptrs = gen_ptrs;
    e.lazy_sweep_bytes = committed0 + los_committed + mut_committed;
    nm_post(&e, P, 0);
    nm_cap_and_release(old_occ + los_occ + mut_occ - floating, 0);
    { uint64_t m = (S.satb_log ? S.satb_log : 0) * O.ptr_bytes; (void)m; }
    SB.active = 0; S.satb_active_bytes += cur_clock - SB.clock0;
    S.majors++;
    major_totals(&e); note_over(); ev_end(&e);
    last_major_clock = cur_clock;
}

/* allocation of one object */
static void alloc_object(uint32_t id) {
    uint32_t s = osize[id];
    int kind = okind[id];
    if (O.old == OLD_STICKY) {
        if (O.los && s >= O.los) { place_los(id); if (onptr[id]) v_push(&born_rem, id); return; }
        if (cur_clock - last_minor_clock >= O.nursery && O.nursery && !O.minor_at_samples) sticky_minor(point_at(id));
        owhere[id] = W_YOUNG;
        if (!ix_alloc(id)) {
            Point P = point_at(id);
            owhere[id] = W_NONE;
            major(P, s);
            owhere[id] = W_YOUNG;
            if (!ix_alloc(id)) { os_grow(s); if (!ix_alloc(id)) die("sticky: cannot place %u", id); }
        }
        old_occ += s; IX.young += s; nursery_used += s; S.nursery_alloc += s;
        ops_line('a', id);
        return;
    }
    int direct = 0;
    if (pt_sites.cap && id >= pt_from_id && hm_find(&pt_sites, osite[id], 0)) direct = 1;
    else if (O.mutable_space && kind_mutable_ptrs(kind)) direct = 2;
    else if (O.nursery == 0) direct = 3;
    else if ((O.big && s > O.big) || s > O.nursery) direct = 4;
    if (direct) {
        S.direct_bytes += s;
        if (direct == 4) { S.big_bytes += s; S.big_objs++; }
        if (direct == 2) place_mut(id);
        else if (O.los && s >= O.los) place_los(id);
        else place_old(id);
        if (direct == 1) { S.pt_bytes += s; S.pt_objs++; if (O.nursery) v_push(&pt_since, id); }
        if (direct != 3 && direct != 2 && kind_has_fields(okind[id])) v_push(&born_rem, id);
        return;
    }
    if (!O.minor_at_samples && nursery_used + s > O.nursery) minor(point_at(id));
    owhere[id] = W_YOUNG; nursery_used += s; S.nursery_alloc += s;
}

static uint64_t cap_sim;   /* --trigger-sim: sim.c's sticky trigger, a doubling cap that must hold the old space and a nursery */
static void after_minor_policies(uint32_t id) {
    Point P = point_at(id);
    if (O.trigger_sim) {
        if (old_occ + los_occ + O.nursery > cap_sim) { major(P, 0); cap_sim = grown(cap_sim, old_occ + los_occ, O.nursery); old_cap = UINT64_MAX / 4; }
        return;
    }
    if (O.major_every && cur_clock - last_major_clock >= O.major_every) { major(P, 0); return; }
    uint64_t occ = old_occ + los_occ + mut_occ;
    if (O.satb && satb_capable()) {
        if (!SB.active && !O.satb_at && occ >= (uint64_t)(O.satb_theta * (double)(limit_bytes ? old_cap : trig_occ))) satb_start(P);
        else if (!limit_bytes && occ >= trig_occ + trig_occ / 2) major(P, 0);   /* marking too slow: finish the cycle now */
        return;
    }
    if (!limit_bytes && !os_moving() && occ >= trig_occ) major(P, 0);
}

static void run(void) {
    uint64_t nclock = 0; Store st; int have = 0; int pending_check = 0;
    if (O.no_stores) { SR.f = NULL; SR.eof = 1; } else sr_open();
    have = sr_next(&st);
    old_cap = limit_bytes ? limit_bytes : UINT64_MAX / 4; rel_cap = limit_bytes ? limit_bytes : O.heap0; trig_occ = O.heap0;
    if (O.trigger_sim) { old_cap = UINT64_MAX / 4; cap_sim = grown(O.heap0, 0, O.nursery); }
    CP.size = O.heap0; MC.size = limit_bytes ? (limit_bytes > O.heap0 ? O.heap0 : limit_bytes) : O.heap0;
    los_budget = O.heap0;
    young_lo = 1;
    for (uint32_t id = 1; id <= N; id++) {
        cur_id = id;
        while (cur_k < nsamples && sample_id[cur_k + 1] <= id) {
            cur_k++;
            if (have_stack && sample_low[cur_k] < low_since) low_since = sample_low[cur_k];
            for (int j = 0; j < O.nmajor_at; j++) if (O.major_at[j] == cur_k && sample_id[cur_k] == id) {   /* tests: a major exactly at this sample */
                if (O.nursery && O.old != OLD_STICKY && nursery_used) minor(point_at(id));
                else if (O.old == OLD_STICKY && nursery_used) sticky_minor(point_at(id));
                major(point_at(id), 0);
            }
            if (O.satb && O.satb_at == cur_k && sample_id[cur_k] == id && !SB.active) satb_start(point_at(id));   /* tests: a cycle exactly at this sample */
            if (O.minor_at_samples && (O.nursery || O.old == OLD_STICKY) && sample_clock[cur_k] - last_minor_clock >= O.nursery) {
                cur_clock = sample_clock[cur_k];
                if (O.old == OLD_STICKY) sticky_minor(point_at(id)); else minor(point_at(id));
                after_minor_policies(id);
            }
        }
        while (have && st.clock <= nclock) { on_store(&st); have = sr_next(&st); }
        cur_id = id;
        if (pending_check) { pending_check = 0; after_minor_policies(id); }   /* the point after the previous object: exact at a sample */
        uint64_t m0 = S.minors;
        alloc_object(id);
        if (S.minors != m0 && !O.minor_at_samples) after_minor_policies(id);
        else if ((O.nursery == 0 || O.old == OLD_STICKY || owhere[id] >= W_OLD) && !O.trigger_sim && !os_moving() && !limit_bytes && old_occ + los_occ + mut_occ >= trig_occ) pending_check = 1;
        else if (O.nursery == 0 && O.old != OLD_STICKY && O.major_every && cur_clock + osize[id] - last_major_clock >= O.major_every) pending_check = 1;
        if (SB.active && O.slice && cur_clock - SB.last_clock >= O.slice) {
            Point P = point_at(id); Ev e; ev_begin(&e, EV_SATB_SLICE, P);
            uint64_t inc = (uint64_t)(O.satb_k * (double)(cur_clock - SB.last_clock)); SB.last_clock = cur_clock;
            if (SB.done + inc > SB.work) inc = SB.work - SB.done;
            SB.done += inc; e.satb_work = inc; S.satb_work_total += inc; ev_end(&e);
            if (SB.done >= SB.work) satb_end(P, 0);
        }
        cur_clock += osize[id];
        nclock += onat ? onat[id] : osize[id];
    }
    while (have) { on_store(&st); have = sr_next(&st); }
    if (SR.f) fclose(SR.f);
    footprint_tick();
}

/* ======================================================================
   Output: one row; the header and the row come from the same table
   ====================================================================== */
typedef struct { const char *name; int t; uint64_t u; double d; const char *s; } Col;
static Col cols[256]; static int ncols;
static void cu(const char *n, uint64_t v) { cols[ncols++] = (Col){ n, 0, v, 0, NULL }; }
static void cd(const char *n, double v) { cols[ncols++] = (Col){ n, 1, 0, v, NULL }; }
static void cs(const char *n, const char *v) { cols[ncols++] = (Col){ n, 2, 0, 0, v }; }
static double ratio(uint64_t a, uint64_t b) { return b ? (double)a / (double)b : 0; }
static void build_cols(void) {
    static char cfg[256];
    {
        int n = snprintf(cfg, sizeof cfg, "%s,n=%zu,p=%d,big=%zu,los=%zu,fill=%u", old_names[O.old], O.nursery, O.promote, O.big, O.los, O.fill);
#define ADD(...) n += snprintf(cfg + n, sizeof cfg - (size_t)n, __VA_ARGS__)
        if (O.limit_x > 0) ADD(",limit=%gx", O.limit_x); else if (O.limit) ADD(",limit=%zu", O.limit);
        if (O.old == OLD_IMMIX || O.old == OLD_STICKY) { ADD(",line=%zu,block=%zu", O.line, O.block); if (O.exact_lines) ADD(",exact"); if (!O.defrag) ADD(",nodefrag"); }
        if (O.jonkers) ADD(",jonkers");
        if (O.satb) ADD(",satb=%g/%g", O.satb_k, O.satb_theta);
        if (O.mutable_space) ADD(",mut");
        if (O.shuffle) ADD(",shuffle=%" U64, O.seed);
        if (O.order) ADD(",order=%s", O.order == 1 ? "bfs" : "dfs");
        if (O.size_model == SZ_W4) ADD(",W4");
        if (O.ptr_bytes == 4) ADD(",ptr4");
        if (O.pretenure) ADD(",pretenure=%g", O.pretenure_x);
        if (O.no_stores) ADD(",nostores");
        if (O.full == FULL_PROMOTE) ADD(",full=promote");
#undef ADD
    }
    ncols = 0;
    cs("workload", O.workload ? O.workload : "-"); cs("format", trace_format);
    cs("size", O.size_model == SZ_NATIVE ? "native" : O.size_model == SZ_L0 ? "L0" : "W4");
    cs("old", old_names[O.old]); cs("config", cfg); cs("band", O.band_hi == 2 ? "near" : O.band_hi ? "hi" : "lo");
    cu("nursery", O.nursery); cu("promote", (uint64_t)O.promote); cu("big", O.big); cu("los", O.los);
    cu("heap0", O.heap0); cu("fill", O.fill); cu("limit", limit_bytes); cd("limit_x", O.limit_x);
    cu("block", O.block); cu("line", O.line); cu("exact_lines", (uint64_t)O.exact_lines); cu("defrag", (uint64_t)O.defrag); cd("headroom", O.headroom);
    cu("ptr_bytes", (uint64_t)O.ptr_bytes); cu("bitmap", (uint64_t)O.bitmap);
    cd("satb_k", O.satb ? O.satb_k : 0); cd("satb_theta", O.satb ? O.satb_theta : 0);
    cu("objects", N); cu("bytes", total_bytes); cu("samples", nsamples); cu("instructions", total_instr); cu("max_live", max_live);
    cu("minors", S.minors); cu("majors", S.majors); cu("fulls", S.fulls); cu("fulls_instead", S.fulls_instead); cu("copy_majors", S.copy_majors); cu("mc_majors", S.mc_majors); cu("compactions", S.compactions);
    cu("satb_cycles", S.satb_cycles); cu("satb_degenerate", S.satb_degenerate);
    cu("nursery_alloc", S.nursery_alloc); cu("surv_first", S.surv_first); cd("survival", ratio(S.surv_first, S.nursery_alloc));
    cu("promoted", S.promoted); cd("promoted_frac", ratio(S.promoted, S.nursery_alloc)); cu("promoted_objs", S.promoted_objs);
    cu("surv_copied", S.surv_copied); cu("copied_minor", S.copied_minor); cu("copied_major", S.copied_major);
    cu("copied_total", S.copied_minor + S.copied_major);
    cu("marked_major", S.marked_major); cu("marked_major_objs", S.marked_major_objs); cu("marked_fields", S.marked_fields); cu("marked_ptrs", S.marked_ptrs);
    cu("swept_bytes", S.swept_bytes); cu("swept_objs", S.swept_objs); cu("sweep_scan", S.sweep_scan);
    cu("moved_bytes", S.moved_bytes); cu("moved_objs", S.moved_objs); cu("evac_bytes", S.evac_bytes); cu("evac_objs", S.evac_objs);
    cu("heap_scan_bytes", S.heap_scan_bytes); cu("heap_scan_objs", S.heap_scan_objs);
    cu("direct_bytes", S.direct_bytes); cu("big_bytes", S.big_bytes); cu("big_objs", S.big_objs); cu("los_bytes", S.los_bytes); cu("los_objs", S.los_objs);
    cu("mut_bytes", S.mut_bytes); cu("mut_objs", S.mut_objs);
    cu("remset_max", S.remset_max); cu("remset_total", S.remset_total); cu("cards_max", S.cards_max); cu("cards_total", S.cards_total);
    cu("cards_ptr_total", S.cards_ptr_total); cu("cards_any_total", S.cards_any_total); cu("born_rem_total", S.born_rem_total); cu("born_rem_fields", S.born_rem_fields);
    cu("mut_scan_total", S.mut_scan_total); cu("mut_scan_max", S.mut_scan_max); cu("mut_stores", mut_stores_nobarrier);
    cu("stores", S.stores); cu("stores_setenv", S.stores_site[0]); cu("stores_ref", S.stores_site[1]); cu("stores_array", S.stores_site[2]);
    cu("stores_ptr", S.stores_ptr); cu("stores_old_src", S.stores_old_src); cu("oy_setenv", S.oy_site[0]); cu("oy_ref", S.oy_site[1]); cu("oy_array", S.oy_site[2]);
    cu("satb_log", S.satb_log); cu("satb_log_old", S.satb_log_old); cu("satb_float_total", S.satb_float_total); cu("satb_float_max", S.satb_float_max);
    cu("satb_float_mean", S.satb_cycles ? S.satb_float_total / S.satb_cycles : 0);
    cu("satb_work", S.satb_work_total); cu("satb_occ_peak", S.satb_occ_peak);
    { /* the marking duty: the share of the allocation during which a cycle was active */ cd("satb_duty", ratio(S.satb_active_bytes, total_bytes)); }
    cu("pt_bytes", S.pt_bytes); cu("pt_objs", S.pt_objs); cu("pt_saved", S.pt_saved); cu("pt_garbage", S.pt_garbage);
    for (int c = 0; c < 4; c++) { static char nm[4][32]; snprintf(nm[c], 32, "phase%02.0f_share", O.phase[c] * 100); cd(nm[c], ratio(S.marked_phase[c], S.marked_major)); }
    cu("slots_total", S.slots_total); cu("watermark_slots_total", S.low_slots_total);
    cu("max_live_old", S.max_live_old); cu("max_occupancy", S.max_occupancy);
    cu("peak_committed", S.peak_committed); cu("peak_reserved", S.peak_reserved); cu("peak_metadata", S.peak_metadata); cu("peak_total", S.peak_total);
    cd("mean_committed", S.integral_clock ? S.committed_integral / (double)S.integral_clock : 0);
    cu("final_committed", footprint_committed());
    cu("final_semispace", O.old == OLD_COPY ? CP.size : O.old == OLD_MC || O.old == OLD_MLTON ? MC.size : os_committed());
    cd("peak_over_live", ratio(S.peak_committed, max_live));
    cd("frag_int_mean", S.frag_n ? S.frag_int_sum / (double)S.frag_n : 0); cd("frag_int_max", S.frag_int_max);
    cd("frag_ext_mean", S.frag_n ? S.frag_ext_sum / (double)S.frag_n : 0); cd("frag_ext_max", S.frag_ext_max);
    cd("overhead_mean", S.frag_n ? S.overhead_sum / (double)S.frag_n : 0);
    cu("limit_over", S.limit_over); cu("limit_over_max", S.limit_over_max); /* majors ending over the limit; the largest excess, bytes */ cu("grow_forced", S.grow_forced);
    cu("max_surv_space", S.max_surv_space);
    { struct rusage ru; getrusage(RUSAGE_SELF, &ru); cu("sim_maxrss_kb", (uint64_t)ru.ru_maxrss); }
}
static void print_header(void) { build_cols(); for (int i = 0; i < ncols; i++) printf("%s%s", i ? "\t" : "", cols[i].name); putchar('\n'); }
static void print_row(void) {
    build_cols();
    for (int i = 0; i < ncols; i++) {
        if (i) putchar('\t');
        if (cols[i].t == 0) printf("%" U64, cols[i].u); else if (cols[i].t == 1) printf("%.6g", cols[i].d); else printf("%s", cols[i].s);
    }
    putchar('\n');
}

/* ======================================================================
   main
   ====================================================================== */
static void usage(void) {
    fprintf(stderr,
"usage: gcsim --trace DIR [options]          (gcsim --header: the column names)\n"
"  --size native|L0|W4       object sizes: the trace's own (W8); L0 16-byte cells; W4 a 4-byte word and header\n"
"  --band lo|hi|near         liveness between samples (a collection at a sample is exact); near: the nearer sample's\n"
"  --nursery N               nursery bytes (0: none, every object goes to old space); --promote 1|2\n"
"  --big T|off               objects above T bypass the nursery (default N/4)\n"
"  --los T|off               objects of T bytes and more go to the LOS (default by model)\n"
"  --old MODEL               copy mc mlton immix sticky-immix segfit bestfit nextfit firstfit chez\n"
"  --heap-size H --heap-fill P   initial old space; growth target live/P (copy: heap.c's policy)\n"
"  --limit B | --limit-x F   a memory limit for old space + LOS (F x the trace's max live)\n"
"  --full appel|promote      copy with a nursery: a full collection when the promotion does not fit (appel),\n"
"                            or a major in the middle of the minor (promote; sim.c's nursery model)\n"
"  --block B --line L --exact-lines --no-defrag --headroom F    immix\n"
"  --segment B --dense F     chez;  --jonkers  mark-compact by threading (default Lisp-2)\n"
"  --increment P --percent-free P --max-overhead P   free lists (OCaml 4); --page B\n"
"  --ptr 8|4 --bitmap        metadata: pointer size, a side mark bitmap\n"
"  --mutable-space           refs and arrays in a space every minor scans, no barrier\n"
"  --learn FILE [--learn-until F]          write survival by allocation site\n"
"  --pretenure FILE [--pretenure-x X] [--pretenure-from F] [--pretenure-min B]\n"
"  --satb K [--satb-start THETA] [--slice B]   incremental snapshot marking, K bytes marked per byte allocated\n"
"  --shuffle SEED            shuffle each minor's survivors before promotion\n"
"  --order alloc|bfs|dfs     promotion order: allocation order, or a Cheney-like breadth-first (depth-first) walk of\n"
"                            the fill-time pointers among each minor's survivors (graph.bin), the unreferenced first\n"
"  --minor-at-samples        minors only at samples (sim.c's quantised nursery)\n"
"  --major-every B           force a major every B bytes (tests)\n"
"  --phase F1,F2,F3,F4       phase ends (fractions of the allocation) for the image-space shares\n"
"  --events FILE --ops FILE --workload NAME --check\n"
"  --no-stores               do not read stores.bin (no barrier, remset, card or SATB-log counts)\n"
"  --max-mb M                stop (out of memory) past M MiB of address space (default 4096)\n");
    exit(2);
}
static size_t size_arg(const char *s) {
    if (!strcmp(s, "off")) return 0;
    char *e; double v = strtod(s, &e);
    if (*e == 'K' || *e == 'k') v *= 1024; else if (*e == 'M' || *e == 'm') v *= 1048576; else if (*e == 'G' || *e == 'g') v *= 1073741824.0; else if (*e) usage();
    return (size_t)v;
}
int main(int argc, char **argv) {
    int header = 0;
    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
#define ARG (i + 1 < argc ? argv[++i] : (usage(), ""))
        if (!strcmp(a, "--header")) header = 1;
        else if (!strcmp(a, "--help")) usage();
        else if (!strcmp(a, "--check")) O.check = 1;
        else if (!strcmp(a, "--exact-lines")) O.exact_lines = 1;
        else if (!strcmp(a, "--no-defrag")) O.defrag = 0;
        else if (!strcmp(a, "--defrag")) O.defrag = 1;
        else if (!strcmp(a, "--jonkers")) O.jonkers = 1;
        else if (!strcmp(a, "--bitmap")) O.bitmap = 1;
        else if (!strcmp(a, "--mutable-space")) O.mutable_space = 1;
        else if (!strcmp(a, "--minor-at-samples")) O.minor_at_samples = 1;
        else if (!strcmp(a, "--trigger-sim")) O.trigger_sim = 1;
        else if (!strcmp(a, "--no-stores")) O.no_stores = 1;
        else if (!strcmp(a, "--trace")) O.trace = ARG;
        else if (!strcmp(a, "--max-mb")) max_mb = size_arg(ARG);
        else if (!strcmp(a, "--workload")) O.workload = ARG;
        else if (!strcmp(a, "--events")) O.events = ARG;
        else if (!strcmp(a, "--ops")) O.ops = ARG;
        else if (!strcmp(a, "--size")) { const char *v = ARG; O.size_set = 1; O.size_model = !strcmp(v, "native") ? SZ_NATIVE : !strcmp(v, "L0") ? SZ_L0 : !strcmp(v, "W4") ? SZ_W4 : (usage(), 0); }
        else if (!strcmp(a, "--band")) { const char *v = ARG; if (!strcmp(v, "hi")) O.band_hi = 1; else if (!strcmp(v, "lo")) O.band_hi = 0; else if (!strcmp(v, "near")) O.band_hi = 2; else usage(); }
        else if (!strcmp(a, "--nursery")) O.nursery = size_arg(ARG);
        else if (!strcmp(a, "--promote")) { O.promote = atoi(ARG); if (O.promote != 1 && O.promote != 2) usage(); }
        else if (!strcmp(a, "--big")) { O.big = size_arg(ARG); O.big_set = 1; }
        else if (!strcmp(a, "--los")) { O.los = size_arg(ARG); O.los_set = 1; }
        else if (!strcmp(a, "--old")) { const char *v = ARG; int k = -1; for (int j = 0; j < 10; j++) if (!strcmp(v, old_names[j])) k = j; if (k < 0) usage(); O.old = k; }
        else if (!strcmp(a, "--heap-size")) { O.heap0 = size_arg(ARG); if (O.heap0 < 4096) O.heap0 = 4096; }
        else if (!strcmp(a, "--heap-fill")) { O.fill = (unsigned)atoi(ARG); if (O.fill < 1 || O.fill > 100) usage(); }
        else if (!strcmp(a, "--limit")) O.limit = size_arg(ARG);
        else if (!strcmp(a, "--limit-x")) O.limit_x = atof(ARG);
        else if (!strcmp(a, "--full")) { const char *v = ARG; O.full = !strcmp(v, "promote") ? FULL_PROMOTE : !strcmp(v, "appel") ? FULL_APPEL : (usage(), 0); }
        else if (!strcmp(a, "--block")) O.block = size_arg(ARG);
        else if (!strcmp(a, "--line")) O.line = size_arg(ARG);
        else if (!strcmp(a, "--headroom")) O.headroom = atof(ARG);
        else if (!strcmp(a, "--segment")) O.segment = size_arg(ARG);
        else if (!strcmp(a, "--dense")) O.dense = atof(ARG);
        else if (!strcmp(a, "--page")) O.page = size_arg(ARG);
        else if (!strcmp(a, "--increment")) O.increment = (unsigned)atoi(ARG);
        else if (!strcmp(a, "--percent-free")) O.percent_free = (unsigned)atoi(ARG);
        else if (!strcmp(a, "--max-overhead")) O.max_overhead = (unsigned)atoi(ARG);
        else if (!strcmp(a, "--ptr")) { O.ptr_bytes = atoi(ARG); if (O.ptr_bytes != 4 && O.ptr_bytes != 8) usage(); }
        else if (!strcmp(a, "--learn")) O.learn = ARG;
        else if (!strcmp(a, "--learn-until")) O.learn_until = atof(ARG);
        else if (!strcmp(a, "--pretenure")) O.pretenure = ARG;
        else if (!strcmp(a, "--pretenure-x")) O.pretenure_x = atof(ARG);
        else if (!strcmp(a, "--pretenure-from")) O.pretenure_from = atof(ARG);
        else if (!strcmp(a, "--pretenure-min")) O.pretenure_min = size_arg(ARG);
        else if (!strcmp(a, "--satb")) { O.satb = 1; O.satb_k = atof(ARG); }
        else if (!strcmp(a, "--satb-start")) O.satb_theta = atof(ARG);
        else if (!strcmp(a, "--slice")) O.slice = size_arg(ARG);
        else if (!strcmp(a, "--shuffle")) { O.shuffle = 1; O.seed = strtoull(ARG, 0, 0); }
        else if (!strcmp(a, "--order")) { const char *v = ARG; O.order = !strcmp(v, "bfs") ? 1 : !strcmp(v, "dfs") ? 2 : !strcmp(v, "alloc") ? 0 : (usage(), 0); }
        else if (!strcmp(a, "--major-every")) O.major_every = size_arg(ARG);
        else if (!strcmp(a, "--satb-at-sample")) O.satb_at = (uint32_t)atoi(ARG);
        else if (!strcmp(a, "--major-at-samples")) { char *t = strtok(ARG, ","); while (t && O.nmajor_at < 16) { O.major_at[O.nmajor_at++] = (uint32_t)atoi(t); t = strtok(NULL, ","); } }
        else if (!strcmp(a, "--phase")) { char *t = strtok(ARG, ","); O.nphase = 0; while (t && O.nphase < 4) { O.phase[O.nphase++] = atof(t); t = strtok(NULL, ","); } while (O.nphase < 4) { O.phase[O.nphase] = 1; O.nphase++; } }
        else usage();
#undef ARG
    }
    if (header && !O.trace) { print_header(); return 0; }
    {   /* the guard: the whole address space of the run, mapped traces included */
        struct rlimit rl; rl.rlim_cur = rl.rlim_max = (rlim_t)max_mb << 20;
        struct rlimit old; getrlimit(RLIMIT_AS, &old);
        if (old.rlim_max != RLIM_INFINITY && rl.rlim_max > old.rlim_max) rl.rlim_cur = rl.rlim_max = old.rlim_max;
        if (setrlimit(RLIMIT_AS, &rl)) die("setrlimit: %s", strerror(errno));
    }
    if (!O.trace) usage();
    if (!O.workload) { const char *s = strrchr(O.trace, '/'); O.workload = s && s[1] ? s + 1 : O.trace; }
    if (!O.los_set) O.los = O.old == OLD_IMMIX || O.old == OLD_STICKY ? 8192 : O.old == OLD_SEGFIT ? SF_MAXW * 8 + 1 : O.old == OLD_CHEZ ? O.segment / 2 : 0;
    if (!O.big_set) O.big = O.nursery / 4;
    if (O.old == OLD_STICKY && O.promote != 1) die("sticky-immix promotes at the first survival");
    if (O.satb && !satb_capable()) die("--satb needs a non-moving old space (immix, segfit, bestfit, nextfit, firstfit, chez)");
    if (O.satb && O.old == OLD_CHEZ) die("--satb with chez: the copying of sparse segments is not incremental");
    if (O.shuffle) rng = O.seed * 0x9E3779B97F4A7C15ull + 1;

    load_trace();
    if (O.check) {
        uint64_t bad = 0, maxd = 0;
        for (uint32_t k = 1; k <= nsamples; k++) {
            uint64_t a = sample_live[k], b = sample_live_trace[k], d = a > b ? a - b : b - a;
            if (d) { bad++; if (d > maxd) maxd = d; if (bad <= 5) fprintf(stderr, "check: sample %u live %" U64 " (trace) vs %" U64 " (death + sizes)\n", k, b, a); }
        }
        printf("check %s: objects %u bytes %" U64 " samples %u mismatching %" U64 " max_diff %" U64 " max_live %" U64 "\n", O.workload, N, total_bytes, nsamples, bad, maxd, max_live);
        return bad && O.size_model == SZ_NATIVE ? 1 : 0;
    }
    limit_bytes = O.limit ? O.limit : O.limit_x > 0 ? (uint64_t)(O.limit_x * (double)max_live) : 0;
    owhere = xcalloc((size_t)N + 2, 1); oaddr = xcalloc((size_t)N + 2, 4); olink = xcalloc((size_t)N + 2, 4);
    dl_head = xcalloc(nsamples + 3, 4);
    hm_init(&rs_a, 1 << 12); hm_init(&rs_b, 1 << 12); hm_init(&cards_oy, 1 << 12); hm_init(&cards_ptr, 1 << 12); hm_init(&cards_any, 1 << 12);
    for (int c = 0; c < O.nphase; c++) {
        uint64_t end = (uint64_t)(O.phase[c] * (double)total_bytes), clk = 0; uint32_t id = 1;
        while (id <= N && clk < end) clk += osize[id++];
        phase_id[c] = id;
    }
    if (O.learn) { hm_init(&site_ix, 1 << 14); uint64_t end = (uint64_t)(O.learn_until * (double)total_bytes), clk = 0; uint32_t id = 1; while (id <= N && clk < end) clk += osize[id++]; learn_until_id = O.learn_until >= 1 ? UINT32_MAX : id; }
    if (O.pretenure) {
        FILE *f = fopen(O.pretenure, "r"); if (!f) die("%s: %s", O.pretenure, strerror(errno));
        hm_init(&pt_sites, 1 << 12); char line[256]; unsigned n = 0;
        while (fgets(line, sizeof line, f)) {
            unsigned long long pc, al, sv;
            if (sscanf(line, "%llu %llu %llu", &pc, &al, &sv) != 3) continue;
            if (al >= O.pretenure_min && (double)sv * 100.0 >= O.pretenure_x * (double)al) { *hm_find(&pt_sites, pc, 1) = 1; n++; }
        }
        fclose(f);
        uint64_t end = (uint64_t)(O.pretenure_from * (double)total_bytes), clk = 0; uint32_t id = 1; while (id <= N && clk < end) clk += osize[id++];
        pt_from_id = id;
        fprintf(stderr, "gcsim: %u sites pretenured (survival >= %g%%, allocated >= %" U64 ")\n", n, O.pretenure_x, O.pretenure_min);
    }
    switch (O.old) {
    case OLD_IMMIX: case OLD_STICKY: ix_init(); break;
    case OLD_SEGFIT: sf_init(); break;
    case OLD_BF: case OLD_NF: case OLD_FF: fl_init(); break;
    case OLD_CHEZ: cz_init(); break;
    default: break;
    }
    if (O.events) { ev_file = fopen(O.events, "w"); if (!ev_file) die("%s: %s", O.events, strerror(errno)); fprintf(ev_file, "# gcsim events: %s\n%s\n", O.workload, ev_cols); }
    if (O.ops) { ops_file = fopen(O.ops, "w"); if (!ops_file) die("%s: %s", O.ops, strerror(errno)); fprintf(ops_file, "# gcsim ops %s old=%s size=%s\n", O.workload, old_names[O.old], O.size_model == SZ_W4 ? "W4" : "W8"); }
    run();
    if (ev_file) fclose(ev_file);
    if (ops_file) fclose(ops_file);
    if (O.learn) {
        FILE *f = fopen(O.learn, "w"); if (!f) die("%s: %s", O.learn, strerror(errno));
        fprintf(f, "# site alloc_bytes survived_bytes (nursery %zu, first %g of the run)\n", O.nursery, O.learn_until);
        for (uint32_t i = 0; i < nsites; i++) fprintf(f, "%u %" U64 " %" U64 "\n", site_pc[i], site_alloc[i], site_surv[i]);
        fclose(f);
    }
    if (header) print_header();
    print_row();
    return 0;
}
