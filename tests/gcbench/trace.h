/* trace.h -- a census trace of the word layout (format 2, layout W8: the
   census VM's, docs/census.md), mapped read-only: alloc.bin (16 bytes an
   object, record N = id N), death.bin (u32 an id: the last sample it was
   alive at), samples.bin (64 bytes a collection), and graph.bin /
   stores.bin when asked for. The ids are walked in order with their birth
   clock (the sum of the sizes before them) and the interval their death
   lies in, which is what H1 and H5 replay. `gcbench mktrace` writes a
   synthetic trace in the same format (trace_make, below). */
#ifndef GCB_TRACE_H
#define GCB_TRACE_H
#include "gcb.h"
#include <fcntl.h>
#include <sys/stat.h>

typedef struct { uint8_t kind, site_kind; uint16_t contag; uint32_t len, site, func; } trec;
typedef struct { uint64_t clock, live_bytes, live_objs, instructions, last_id; uint32_t sp, fp, fp_low, base_low, sp_ptrs, flags; } tsample;
typedef struct { uint32_t clock8, src_id, new_id, old_id, field; uint8_t site, flags, rep, src_kind; } tstore;
_Static_assert(sizeof(trec) == 16 && sizeof(tsample) == 64 && sizeof(tstore) == 24, "the census's record sizes");

typedef struct {
    char dir[512];
    size_t nids;              /* records in alloc.bin (ids 0..nids-1; 0 a dummy) */
    const trec *alloc;
    const uint32_t *death;
    const tsample *samp; size_t nsamp;
    const uint32_t *graph; size_t ngraph;    /* optional */
    const tstore *stores; size_t nstores;   /* optional */
    uint64_t every, bytes;
} trace_t;

#define DEATH_NEVER 0xFFFFFFFFu
/* the trace's kinds (value.h's ObjKind) */
#define T_KIND_TUPLE 1
#define T_KIND_CON 2
#define T_KIND_CLOSURE 3
#define T_KIND_STRING 4
#define T_KIND_REF 5
#define T_KIND_ARRAY 6
#define T_KIND_REAL 10
#define T_KIND_BOX 11
#define T_KIND_BYTES 12
#define T_KIND_REALS 13
/* the census's w8_obj_size */
static inline size_t w8_size(uint8_t kind, uint32_t len) {
    size_t pay = (kind == T_KIND_STRING || kind == T_KIND_BYTES) ? len
               : (kind == T_KIND_REAL || kind == T_KIND_BOX) ? 8 : (size_t)len * 8;
    pay = (pay + 7) & ~(size_t)7;
    if (pay < 8) pay = 8;
    return 8 + pay;
}
static inline int t_has_fields(uint8_t kind) {
    return !(kind == T_KIND_STRING || kind == T_KIND_REAL || kind == T_KIND_BOX || kind == T_KIND_BYTES || kind == T_KIND_REALS);
}

static const void *t_map(const char *dir, const char *name, size_t *bytes, int need) {
    char path[600]; snprintf(path, sizeof path, "%s/%s", dir, name);
    int fd = open(path, O_RDONLY);
    if (fd < 0) { if (need) { fprintf(stderr, "gcbench: cannot open %s\n", path); exit(2); } *bytes = 0; return NULL; }
    struct stat st;
    if (fstat(fd, &st)) die("fstat of a trace file failed");
    *bytes = (size_t)st.st_size;
    void *p = *bytes ? mmap(NULL, *bytes, PROT_READ, MAP_PRIVATE, fd, 0) : NULL;
    close(fd);
    if (p == MAP_FAILED) die("mmap of a trace file failed");
    return p;
}
static void trace_open(trace_t *t, const char *dir, int with_graph, int with_stores) {
    memset(t, 0, sizeof *t);
    snprintf(t->dir, sizeof t->dir, "%s", dir);
    size_t b;
    t->alloc = t_map(dir, "alloc.bin", &b, 1); t->nids = b / sizeof(trec);
    t->death = t_map(dir, "death.bin", &b, 1);
    if (b / 4 != t->nids) die("death.bin and alloc.bin disagree");
    t->samp = t_map(dir, "samples.bin", &b, 1); t->nsamp = b / sizeof(tsample);
    if (with_graph) { t->graph = t_map(dir, "graph.bin", &b, 1); t->ngraph = b / 4; }
    if (with_stores) { t->stores = t_map(dir, "stores.bin", &b, 1); t->nstores = b / sizeof(tstore); }
    char path[600]; snprintf(path, sizeof path, "%s/meta.txt", dir);
    FILE *f = fopen(path, "r");
    if (f) {   /* "NAME VALUE" lines; one whose value is not a number ("layout W8") is passed over */
        char line[256], k[64]; unsigned long long v;
        while (fgets(line, sizeof line, f)) {
            if (sscanf(line, "%63s %llu", k, &v) != 2) continue;
            if (!strcmp(k, "every")) t->every = v;
            else if (!strcmp(k, "bytes")) t->bytes = v;
            else if (!strcmp(k, "format") && v != 2) die("not a format-2 trace");
        }
        fclose(f);
    }
}
/* the clock of sample k (k >= 1) */
static inline uint64_t t_sample_clock(const trace_t *t, uint32_t k) { return t->samp[k - 1].clock; }

/* a walk over the ids in order: the birth clock and the death interval */
typedef struct {
    const trace_t *t;
    size_t id;              /* the current id */
    uint64_t birth, size;   /* its birth clock and its size */
    uint64_t dlo, dhi;      /* it died in (dlo, dhi]; dhi = UINT64_MAX: never */
    uint32_t next;          /* the first sample after the birth (1-based) */
    uint64_t clock;         /* the clock after this id */
} twalk;
static void tw_init(twalk *w, const trace_t *t) { memset(w, 0, sizeof *w); w->t = t; w->next = 1; }
/* the next id; 0 at the end */
static inline int tw_next(twalk *w) {
    const trace_t *t = w->t;
    if (w->id + 1 >= t->nids) return 0;
    w->id++;
    const trec *r = &t->alloc[w->id];
    w->birth = w->clock;
    w->size = w8_size(r->kind, r->len);
    w->clock += w->size;
    while (w->next <= t->nsamp && t->samp[w->next - 1].last_id < w->id) w->next++;
    uint32_t d = t->death[w->id];
    if (d == DEATH_NEVER || d >= t->nsamp) { w->dlo = w->dhi = UINT64_MAX; }
    else if (d == 0) { w->dlo = w->birth; w->dhi = w->next <= t->nsamp ? t_sample_clock(t, w->next) : UINT64_MAX; }
    else { w->dlo = t_sample_clock(t, d); w->dhi = t_sample_clock(t, d + 1); }
    return 1;
}
/* a trace directory: trace=DIR, a path, or trace=NAME, a directory under
   $GCB_TRACES (else under the current one) */
static const char *trace_dir(const char *opt) {
    static char buf[600];
    if (!opt) die("this experiment needs trace=DIR: a census trace (docs/census.md) or one `gcbench mktrace` wrote");
    const char *base = getenv("GCB_TRACES");
    if (strchr(opt, '/') || !base) return opt;
    snprintf(buf, sizeof buf, "%s/%s", base, opt);
    return buf;
}

/* ---- gcbench mktrace dir=DIR [objects=200K] [every=32K] [seed=1] ----
   A synthetic trace in the census's format: alloc.bin, death.bin,
   samples.bin, graph.bin and meta.txt (no fields.bin or stores.bin, which
   gcbench does not read). The objects: mostly constructors and tuples of
   one to eight fields, closures, strings, boxed reals, refs and arrays, a
   few arrays of 9 to 21 KiB (the large-object paths). Their lifetimes: a
   twentieth live to the end, three in twenty die after about 2 MiB of
   allocation, the rest after about 2 KiB. A sample is taken as the clock
   passes every EVERY bytes, and one at the end; a field points at an
   older object half of the time. It is for check.sh and for trying H1 and
   H5 without the census: no number of the roadmap comes from one. */
static void t_write(const char *dir, const char *name, const void *p, size_t bytes) {
    char path[600]; snprintf(path, sizeof path, "%s/%s", dir, name);
    FILE *f = fopen(path, "wb");
    if (!f || (bytes && fwrite(p, 1, bytes, f) != bytes) || fclose(f)) { fprintf(stderr, "gcbench: cannot write %s\n", path); exit(2); }
}
static void trace_make(const char *dir, size_t n, uint64_t every, uint64_t seed) {
    if (mkdir(dir, 0777) && errno != EEXIST) { fprintf(stderr, "gcbench: cannot make %s\n", dir); exit(2); }
    trec *rec = calloc(n + 1, sizeof *rec);
    uint64_t *dies = malloc((n + 1) * sizeof *dies);
    uint32_t *death = calloc(n + 1, sizeof *death);
    size_t scap = 1024, ns = 0, ngraph = 0;
    tsample *samp = calloc(scap, sizeof *samp);
    if (!rec || !dies || !death || !samp) die("mktrace: out of memory");
    uint64_t s = seed ? seed : 1, clock = 0, next = every;
    for (size_t id = 1; id <= n; id++) {
        trec *r = &rec[id];
        double u = rnd_unit(&s);
        uint8_t k; uint32_t len;
        if (u < 0.55) { k = rnd_below(&s, 2) ? T_KIND_CON : T_KIND_TUPLE; len = 1 + (uint32_t)rnd_below(&s, 3); }
        else if (u < 0.70) { k = T_KIND_TUPLE; len = 4 + (uint32_t)rnd_below(&s, 5); }
        else if (u < 0.78) { k = T_KIND_CLOSURE; len = 2 + (uint32_t)rnd_below(&s, 5); }
        else if (u < 0.86) { k = T_KIND_STRING; len = 1 + (uint32_t)rnd_below(&s, 120); }
        else if (u < 0.90) { k = T_KIND_REAL; len = 1; }
        else if (u < 0.95) { k = T_KIND_REF; len = 1; }
        else if (u < 0.997) { k = T_KIND_ARRAY; len = 1 + (uint32_t)rnd_below(&s, 256); }
        else if (u < 0.998) { k = T_KIND_BYTES; len = 1 + (uint32_t)rnd_below(&s, 4096); }
        else { k = T_KIND_ARRAY; len = 1100 + (uint32_t)rnd_below(&s, 1600); }
        r->kind = k; r->len = len; r->contag = k == T_KIND_CON ? (uint16_t)rnd_below(&s, 4) : 0;
        r->site = (uint32_t)(id % 97); r->func = (uint32_t)(id % 13);
        if (t_has_fields(k)) ngraph += len;
        uint64_t size = w8_size(k, len);
        double v = rnd_unit(&s), mean = v < 0.05 ? 0 : v < 0.20 ? 2097152.0 : 2048.0;
        dies[id] = mean == 0 ? UINT64_MAX : clock + size + (uint64_t)(-mean * log(1.0 - rnd_unit(&s)));
        clock += size;
        if (clock >= next) {   /* a collection, after this id */
            if (ns == scap) { scap *= 2; samp = realloc(samp, scap * sizeof *samp); if (!samp) die("mktrace: out of memory"); }
            memset(&samp[ns], 0, sizeof samp[ns]);
            samp[ns].clock = clock; samp[ns].last_id = id; ns++;
            while (next <= clock) next += every;
        }
    }
    /* the final collection, at exit */
    if (ns == scap) { scap++; samp = realloc(samp, scap * sizeof *samp); if (!samp) die("mktrace: out of memory"); }
    memset(&samp[ns], 0, sizeof samp[ns]);
    samp[ns].clock = clock; samp[ns].last_id = n; samp[ns].flags = 2; ns++;
    /* death: the last sample an object is alive at (allocated before it and
       dying after its clock), 0 for none, DEATH_NEVER at the final one;
       each sample's live bytes and objects from the same intervals */
    int64_t *dbytes = calloc(ns + 1, sizeof *dbytes), *dobjs = calloc(ns + 1, sizeof *dobjs);
    if (!dbytes || !dobjs) die("mktrace: out of memory");
    size_t first = 0;   /* 0-based: the first sample whose last_id >= id */
    for (size_t id = 1; id <= n; id++) {
        while (first < ns && samp[first].last_id < id) first++;
        size_t lo = first, hi = ns;   /* past the samples [first, lo) whose clock < dies */
        while (lo < hi) { size_t mid = lo + (hi - lo) / 2; if (samp[mid].clock < dies[id]) lo = mid + 1; else hi = mid; }
        if (lo == first) { death[id] = 0; continue; }
        death[id] = lo == ns ? DEATH_NEVER : (uint32_t)lo;   /* sample lo (1-based) is the last alive */
        int64_t size = (int64_t)w8_size(rec[id].kind, rec[id].len);
        dbytes[first] += size; dbytes[lo] -= size;
        dobjs[first]++; dobjs[lo]--;
    }
    int64_t lb = 0, lob = 0;
    for (size_t k = 0; k < ns; k++) { lb += dbytes[k]; lob += dobjs[k]; samp[k].live_bytes = (uint64_t)lb; samp[k].live_objs = (uint64_t)lob; }
    /* graph.bin: a field of an object with fields points half of the time
       at an older object, near it */
    uint32_t *graph = malloc((ngraph ? ngraph : 1) * sizeof *graph);
    if (!graph) die("mktrace: out of memory");
    size_t gi = 0;
    for (size_t id = 1; id <= n; id++) {
        if (!t_has_fields(rec[id].kind)) continue;
        for (uint32_t j = 0; j < rec[id].len; j++) {
            uint64_t back = 1 + rnd_below(&s, 16);
            graph[gi++] = id > back && rnd_below(&s, 2) ? (uint32_t)(id - back) : 0;
        }
    }
    t_write(dir, "alloc.bin", rec, (n + 1) * sizeof *rec);
    t_write(dir, "death.bin", death, (n + 1) * sizeof *death);
    t_write(dir, "samples.bin", samp, ns * sizeof *samp);
    t_write(dir, "graph.bin", graph, ngraph * sizeof *graph);
    char meta[256];
    int ml = snprintf(meta, sizeof meta, "format 2\nevery %llu\nbytes %llu\nobjects %zu\nsamples %zu\nsynthetic 1\n",
                      (unsigned long long)every, (unsigned long long)clock, n, ns);
    t_write(dir, "meta.txt", meta, (size_t)ml);
    fprintf(stderr, "# mktrace %s: %zu objects, %.1f MiB, %zu samples, %.1f MiB live at the end\n",
            dir, n, (double)clock / 1048576.0, ns, (double)samp[ns - 1].live_bytes / 1048576.0);
    free(rec); free(dies); free(death); free(samp); free(dbytes); free(dobjs); free(graph);
}
static void exp_mktrace(void) {
    const char *dir = opt_s("dir", NULL);
    if (!dir) die("mktrace needs dir=DIR");
    size_t every = (size_t)opt_n("every", 32768);
    if (every < 8) die("mktrace: every= is too small");
    trace_make(dir, (size_t)opt_n("objects", 200000), every, (uint64_t)opt_n("seed", 1));
}
#endif
