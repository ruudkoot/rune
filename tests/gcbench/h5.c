/* h5.c -- H5, the old-space allocators of alloc.h replaying a census
   trace, their fragmentation, and the cost of reading what they built.

   The replay. The trace's ids are walked in order (trace.h). A nursery of
   N bytes is collected at every N/every-th sample of the trace (N a
   multiple of the trace's interval), where liveness is exact: the objects
   born since the last minor and alive at that sample (death >= the
   sample) are promoted, in id order, into the allocator: header and id
   written. With N = 0 there is no nursery and every object is allocated
   in the old space at its birth. A major collection runs at a minor when
   the old space holds more than FACTOR times what lived after the last
   major (and at least MIN bytes): every object of the old space is told
   live or dead (death >= the sample), the allocator sweeps (bump: slides
   the live objects down). The fragmentation after a major is 1 - live /
   footprint; the footprint is what the allocator holds (alloc.h).

   The traversal. After the replay, the live objects are read in id order,
   header and id; with graph=1 also the header of every object each one
   points to (graph.bin: the pointee at the end of its allocation), when
   that object is in the old space and alive: how far apart the allocator
   put what the program put together. Rows: promote (cycles per object
   promoted, the allocator's work), major (per object swept), traverse
   (per live object). The fragmentation goes to stderr as "# H5-frag" lines
   and, with frag=FILE, into FILE (the roadmap's
   results/gcbench-fragmentation.md).

   The ops replay (ops=FILE) places and frees what the simulator's
   old-space operation stream says (`gcsim --ops`, tools/heapsim), so that
   every allocator sees the same sequence: a line "a ID SIZE ADDR WHERE"
   places object ID of SIZE bytes (WHERE 3 the old space, 4 the
   large-object space, 5 the mutable space), "f ID" frees it, "m ..." moves
   it (ignored: these allocators do not move); a run of frees is one
   major, run when the next placement (or the end) comes. One line a major
   to MAJORS: the file, the allocator, its index, the live bytes, the
   footprint and the large-object bytes.

   check=1: after every major, and at the end, every object of the old
   space still holds its header and its id, no two overlap, the footprint
   covers them, and the live bytes are the trace's for that sample.
   `gcbench alloc-test` checks the allocators without a trace (below).

   gcbench h5 trace=DIR|NAME [alloc=bump,immix,segfit,bestfit,firstfit,nextfit]
              [nursery=1M] [factor=2] [min=4M] [line=128] [exact=0]
              [graph=1] [reserve=1G] [bytes=...] [frag=FILE] [reps=3]
   gcbench h5 ops=FILE [alloc=...] [majors=FILE] [frag=FILE] */
#include "gcb.h"
#include "trace.h"
#include "alloc.h"

typedef struct { uint32_t id, size; char *addr; uint64_t foff; } h5_ent;
typedef struct {
    h5_ent *e; size_t n, cap;
    size_t live_bytes;                 /* bytes in the old space (promoted, not yet found dead) */
    uint64_t promoted_objs, promoted_bytes, majors;
    size_t peak_fp, peak_occ;
    double frag_sum, frag_max; size_t frag_n;
    size_t last_live, last_fp;
} h5_state;

static void h5_write(char *p, const trec *r, size_t sz, uint32_t id) {
    obj *o = (obj *)p;
    if (t_has_fields(r->kind)) hdr(o, K_TUPLE, 0, r->len);
    else hdr(o, K_STRING, 0, (uint32_t)(sz - 8));
    FIELDS(o)[0] = (val)id << 1 | 1;   /* the id, as an immediate */
}
static void h5_push(h5_state *s, uint32_t id, uint32_t size, char *addr, uint64_t foff) {
    if (s->n == s->cap) { s->cap = s->cap ? 2 * s->cap : 1u << 20; s->e = realloc(s->e, s->cap * sizeof *s->e); if (!s->e) die("H5: out of memory"); }
    s->e[s->n].id = id; s->e[s->n].size = size; s->e[s->n].addr = addr; s->e[s->n].foff = foff; s->n++;
}

/* ---- check=1: what the allocator holds is what was put there ---- */
typedef struct { char *addr; size_t size; } h5_span;
static int cmp_span(const void *a, const void *b) {
    const h5_span *x = a, *y = b;
    return (x->addr > y->addr) - (x->addr < y->addr);
}
/* no two of the N spans overlap, and each is 8-byte aligned (sorts SP) */
static int h5_disjoint(h5_span *sp, size_t n, const char *what) {
    qsort(sp, n, sizeof *sp, cmp_span);
    for (size_t i = 0; i < n; i++) {
        if ((uintptr_t)sp[i].addr & 7) { gcb_fail("%s: an object at an address not a multiple of 8", what); return 0; }
        if (i + 1 < n && sp[i].addr + sp[i].size > sp[i + 1].addr) { gcb_fail("%s: two objects overlap", what); return 0; }
    }
    return 1;
}
static void h5_verify(const galloc *g, const h5_state *s, const trace_t *t, const char *what) {
    h5_span *sp = malloc((s->n ? s->n : 1) * sizeof *sp);
    size_t live = 0;
    for (size_t i = 0; i < s->n; i++) {
        const h5_ent *e = &s->e[i];
        const obj *o = (const obj *)e->addr;
        const trec *r = &t->alloc[e->id];
        int kind = t_has_fields(r->kind) ? K_TUPLE : K_STRING;
        if (okind(o) != kind || osize(o) != e->size || FIELDS(o)[0] != ((val)e->id << 1 | 1)) {
            gcb_fail("%s: object %u lost its header or its id", what, e->id);
            free(sp);
            return;
        }
        sp[i].addr = e->addr; sp[i].size = e->size; live += e->size;
    }
    h5_disjoint(sp, s->n, what);
    if (ga_footprint(g) < live) gcb_fail("%s: a footprint of %zu bytes for %zu live", what, ga_footprint(g), live);
    free(sp);
}

static void h5_major(galloc *g, h5_state *s, const trace_t *t, uint32_t sample, phase *ph) {
    ph_begin(ph);
    ga_major_begin(g);
    size_t k = 0, live = 0;
    for (size_t i = 0; i < s->n; i++) {
        h5_ent *e = &s->e[i];
        if (t->death[e->id] >= sample) { ga_live(g, e->addr, e->size); s->e[k++] = *e; live += e->size; }
        else ga_dead(g, e->addr, e->size);
    }
    s->n = k;
    ga_major_end(g);
    if (g->kind == GA_BUMP) {
        char **a = malloc(k * sizeof *a); uint32_t *z = malloc(k * sizeof *z);
        for (size_t i = 0; i < k; i++) { a[i] = s->e[i].addr; z[i] = s->e[i].size; }
        ga_compact(g, a, z, k);
        for (size_t i = 0; i < k; i++) s->e[i].addr = a[i];
        free(a); free(z);
    }
    ph_end(ph);
    s->live_bytes = live;
    size_t fp = ga_footprint(g);
    double fr = fp ? 1.0 - (double)live / (double)fp : 0;
    s->frag_sum += fr; s->frag_n++; if (fr > s->frag_max) s->frag_max = fr;
    s->majors++; s->last_live = live; s->last_fp = fp;
    if (gcb_check) {
        char what[64]; snprintf(what, sizeof what, "H5 %s major %llu", ga_names[g->kind], (unsigned long long)s->majors);
        h5_verify(g, s, t, what);
        if (live != t->samp[sample - 1].live_bytes)
            gcb_fail("%s: %zu bytes live in the old space, the trace's sample %u says %llu", what, live, sample,
                     (unsigned long long)t->samp[sample - 1].live_bytes);
    }
}

static void h5_one(const trace_t *t, int kind, size_t nursery, double factor, size_t minheap, size_t line, int exact,
                   int graph, size_t reserve, uint64_t max_bytes, int reps, FILE *frag) {
    galloc *g = ga_new(kind, line, reserve);
    g->exact = exact;
    h5_state s; memset(&s, 0, sizeof s);
    phase ph_prom, ph_major; ph_clear(&ph_prom); ph_clear(&ph_major);
    uint32_t every_n = nursery ? (uint32_t)(nursery / (t->every ? t->every : 262144)) : 0;
    if (nursery && every_n == 0) every_n = 1;
    size_t after_last = 0;   /* live after the last major */
    uint64_t foff = 0, clock = 0;
    size_t id = 1;
    uint32_t smp = 1;
    while (id < t->nids && clock < max_bytes) {
        /* the batch: the ids up to the sample AT (every_n samples on with a
           nursery; every sample without one, each a possible major) */
        uint32_t at = nursery ? smp + every_n - 1 : smp;
        if (at > t->nsamp) break;
        size_t last = (size_t)t->samp[at - 1].last_id;
        smp = at + 1;
        ph_begin(&ph_prom);
        for (; id <= last && id < t->nids; id++) {
            const trec *r = &t->alloc[id];
            size_t sz = w8_size(r->kind, r->len);
            uint64_t f = foff;
            if (t_has_fields(r->kind)) foff += r->len;
            clock += sz;
            if (nursery && t->death[id] < at) continue;   /* died in the nursery */
            char *p = ga_alloc(g, sz);
            h5_write(p, r, sz, (uint32_t)id);
            h5_push(&s, (uint32_t)id, (uint32_t)sz, p, f);
            s.promoted_objs++; s.promoted_bytes += sz; s.live_bytes += sz;
        }
        ph_end(&ph_prom);
        size_t fp = ga_footprint(g);
        if (fp > s.peak_fp) s.peak_fp = fp;
        if (s.live_bytes > s.peak_occ) s.peak_occ = s.live_bytes;
        size_t limit = (size_t)(factor * (double)(after_last > minheap ? after_last : minheap));
        if (s.live_bytes > limit) { h5_major(g, &s, t, at, &ph_major); after_last = s.live_bytes; }
    }
    char cas[128], hb[32], row[160];
    snprintf(cas, sizeof cas, "%s%s/n=%s/f=%.2g", ga_names[kind], kind == GA_IMMIX ? (exact ? "-exact" : "") : "", human((double)nursery, hb), factor);
    if (kind == GA_IMMIX) { size_t l = strlen(cas); snprintf(cas + l, sizeof cas - l, "/line=%zu", g->line); }
    if (gcb_check) { char what[160]; snprintf(what, sizeof what, "H5 %s at the end", cas); h5_verify(g, &s, t, what); }
    snprintf(row, sizeof row, "promote/%s", cas);
    out_row("H5", row, "obj", (double)s.promoted_objs, &ph_prom.acc, (double)ctrs_cyc(&ph_prom.acc), 1);
    if (s.majors) {
        snprintf(row, sizeof row, "major/%s", cas);
        out_row("H5", row, "obj", (double)s.promoted_objs, &ph_major.acc, (double)ctrs_cyc(&ph_major.acc), 1);
    }
    /* the traversal of what lives at the end, REPS times, the least kept */
    {
        uint64_t *where = NULL;
        if (graph && t->graph) {
            where = calloc(t->nids, sizeof *where);
            for (size_t i = 0; i < s.n; i++) where[s.e[i].id] = (uint64_t)(uintptr_t)s.e[i].addr;
        }
        reps_t r; reps_init(&r);
        uint64_t acc = 0;
        for (int k = 0; k < reps; k++) {
            ctrs a, b, d;
            pc_read(&a);
            for (size_t i = 0; i < s.n; i++) {
                const h5_ent *e = &s.e[i];
                const obj *o = (const obj *)e->addr;
                acc += o->len + FIELDS(o)[0];
                if (where && t_has_fields(t->alloc[e->id].kind)) {
                    const uint32_t *gp = t->graph + e->foff;
                    for (uint32_t j = 0, n = o->len; j < n; j++) {
                        uint32_t tid = gp[j];
                        if (tid && where[tid]) acc += ((const obj *)(uintptr_t)where[tid])->len;
                    }
                }
            }
            pc_read(&b);
            ctrs_sub(&d, &b, &a);
            reps_add(&r, &d);
        }
        SINK(acc);
        snprintf(row, sizeof row, "traverse%s/%s", where ? "-graph" : "", cas);
        reps_out(&r, "H5", row, "obj", (double)s.n);
        free(where);
    }
    size_t internal = g->internal;
    const char *tname = strrchr(t->dir, '/') ? strrchr(t->dir, '/') + 1 : t->dir;
    char line_buf[1024];
    snprintf(line_buf, sizeof line_buf, "%s\t%s\t%.4f\t%zu\t%.2f\t%zu\t%llu\t%llu\t%llu\t%.2f\t%.2f\t%.4f\t%.4f\t%.2f\t%.2f\t%.2f\t%.2f",
             tname, cas, s.peak_occ ? (double)s.peak_fp / (double)s.peak_occ : 0.0, nursery, factor, (size_t)minheap >> 20, (unsigned long long)s.majors, (unsigned long long)s.promoted_objs,
             (unsigned long long)(s.promoted_bytes >> 20), (double)s.peak_fp / 1048576.0, (double)s.peak_occ / 1048576.0,
             s.frag_n ? s.frag_sum / (double)s.frag_n : 0.0, s.frag_max, (double)s.last_live / 1048576.0, (double)s.last_fp / 1048576.0,
             (double)internal / 1048576.0, (double)g->los.bytes / 1048576.0);
    fprintf(stderr, "# H5-frag\t%s\n", line_buf);
    if (frag) { fprintf(frag, "%s\n", line_buf); fflush(frag); }
    free(s.e);
    ga_delete(g);
}

static inline uint64_t h5_num(char **p) { char *q = *p; while (*q == ' ') q++; uint64_t v = 0; while (*q >= '0' && *q <= '9') v = v * 10 + (uint64_t)(*q++ - '0'); *p = q; return v; }
static void h5_ops(const char *path, int kind, size_t line, int exact, size_t reserve, FILE *frag, FILE *majors) {
    FILE *f = fopen(path, "r");
    if (!f) die("H5: cannot open the ops file");
    galloc *g = ga_new(kind, line, reserve);
    g->exact = exact;
    size_t cap = 1u << 22;
    char **addr = calloc(cap, sizeof *addr); uint32_t *size = calloc(cap, sizeof *size), *pos = calloc(cap, sizeof *pos);
    uint8_t *los = calloc(cap, 1);
    uint32_t *live = malloc(cap * sizeof *live); size_t nlive = 0;
    uint32_t *dead = malloc(cap * sizeof *dead); size_t ndead = 0, dead_cap = cap;
    if (!addr || !size || !pos || !los || !live || !dead) die("H5: out of memory (ops)");
    size_t live_bytes = 0, los_bytes = 0, peak_fp = 0, peak_occ = 0, majors_n = 0, moves = 0, placed = 0, placed_bytes = 0;
    double frag_sum = 0, frag_max = 0;
    size_t last_live = 0, last_fp = 0;
    char buf[256];
    phase ph; ph_clear(&ph);
    int eof = 0;
    while (!eof) {
        char *l = fgets(buf, sizeof buf, f);
        if (!l) eof = 1;
        char op = l ? l[0] : 0;
        if ((op == 'a' || eof) && ndead) {   /* the major */
            ph_begin(&ph);
            ga_major_begin(g);
            for (size_t i = 0; i < ndead; i++) {
                uint32_t id = dead[i];
                if (!los[id]) ga_dead(g, addr[id], size[id]); else los_bytes -= size[id];
                live_bytes -= size[id];
                uint32_t p = pos[id]; live[p] = live[--nlive]; pos[live[p]] = p;
            }
            ndead = 0;
            if (kind == GA_IMMIX) for (size_t i = 0; i < nlive; i++) { uint32_t id = live[i]; if (!los[id]) ga_live(g, addr[id], size[id]); }
            ga_major_end(g);
            ph_end(&ph);
            size_t fp = ga_footprint(g), held = live_bytes - los_bytes;
            double fr = fp ? 1.0 - (double)held / (double)fp : 0;
            frag_sum += fr; if (fr > frag_max) frag_max = fr;
            majors_n++; last_live = held; last_fp = fp;
            if (majors) fprintf(majors, "%s\t%s\t%zu\t%zu\t%zu\t%zu\n", path, ga_names[kind], majors_n, held, fp, los_bytes);
            if (gcb_check) {   /* every placed object keeps its header; none overlap */
                h5_span *sp = malloc((nlive ? nlive : 1) * sizeof *sp); size_t n = 0;
                for (size_t i = 0; i < nlive; i++) {
                    uint32_t id = live[i];
                    if (los[id]) continue;
                    const obj *o = (const obj *)addr[id];
                    if (okind(o) != K_TUPLE || osize(o) != size[id]) { gcb_fail("H5 ops %s major %zu: object %u lost its header", ga_names[kind], majors_n, id); break; }
                    sp[n].addr = addr[id]; sp[n].size = size[id]; n++;
                }
                char what[64]; snprintf(what, sizeof what, "H5 ops %s major %zu", ga_names[kind], majors_n);
                h5_disjoint(sp, n, what);
                if (fp < held) gcb_fail("%s: a footprint of %zu bytes for %zu live", what, fp, held);
                free(sp);
            }
        }
        if (!l) break;
        char *p = l + 1;
        if (op == 'a') {
            uint64_t id = h5_num(&p), sz = h5_num(&p); (void)h5_num(&p); uint64_t where = h5_num(&p);
            if (sz < 16 || sz % 8) die("H5: an ops placement of a size that is no object's");
            if (id >= cap) {
                size_t nc = cap; while (nc <= id) nc *= 2;
                addr = realloc(addr, nc * sizeof *addr); size = realloc(size, nc * sizeof *size); pos = realloc(pos, nc * sizeof *pos);
                los = realloc(los, nc); live = realloc(live, nc * sizeof *live);
                if (!addr || !size || !pos || !los || !live) die("H5: out of memory (ops)");
                memset(addr + cap, 0, (nc - cap) * sizeof *addr); memset(los + cap, 0, nc - cap);
                cap = nc;
            }
            size[id] = (uint32_t)sz; los[id] = where == 4;
            if (where == 4) { addr[id] = NULL; los_bytes += sz; }
            else { char *q = ga_alloc(g, sz); obj *o = (obj *)q; hdr(o, K_TUPLE, 0, (uint32_t)((sz - 8) / 8)); addr[id] = q; }
            pos[id] = (uint32_t)nlive; live[nlive++] = (uint32_t)id;
            live_bytes += sz; placed++; placed_bytes += sz;
            size_t fp = ga_footprint(g), held = live_bytes - los_bytes;
            if (fp > peak_fp) peak_fp = fp;
            if (held > peak_occ) peak_occ = held;
        } else if (op == 'f') {
            uint64_t id = h5_num(&p);
            if (id >= cap || !size[id]) die("H5: an ops free of an object never placed");
            if (ndead == dead_cap) { dead_cap *= 2; dead = realloc(dead, dead_cap * sizeof *dead); if (!dead) die("H5: out of memory (ops)"); }
            dead[ndead++] = (uint32_t)id;
        } else if (op == 'm') moves++;
    }
    fclose(f);
    const char *base = strrchr(path, '/') ? strrchr(path, '/') + 1 : path;
    char cas[160];
    snprintf(cas, sizeof cas, "ops:%s/%s%s", base, ga_names[kind], kind == GA_IMMIX ? (exact ? "-exact" : "") : "");
    if (kind == GA_IMMIX) { size_t n = strlen(cas); snprintf(cas + n, sizeof cas - n, "/line=%zu", g->line); }
    char row[512];
    snprintf(row, sizeof row, "%s\t%s\t%.4f\t-\t-\t-\t%zu\t%zu\t%zu\t%.2f\t%.2f\t%.4f\t%.4f\t%.2f\t%.2f\t%.2f\t%.2f",
             base, cas, peak_occ ? (double)peak_fp / (double)peak_occ : 0.0, majors_n, placed, placed_bytes >> 20,
             (double)peak_fp / 1048576.0, (double)peak_occ / 1048576.0, majors_n ? frag_sum / (double)majors_n : 0.0, frag_max,
             (double)last_live / 1048576.0, (double)last_fp / 1048576.0, (double)g->internal / 1048576.0, (double)los_bytes / 1048576.0);
    fprintf(stderr, "# H5-frag\t%s\t(moves ignored: %zu)\n", row, moves);
    if (frag) { fprintf(frag, "%s\n", row); fflush(frag); }
    char name[200]; snprintf(name, sizeof name, "ops-major/%s", cas);
    out_row("H5", name, "major", (double)(majors_n ? majors_n : 1), &ph.acc, (double)ctrs_cyc(&ph.acc), 1);
    free(addr); free(size); free(pos); free(los); free(live); free(dead);
    ga_delete(g);
}

static void exp_h5(void) {
    const char *ops = opt_s("ops", NULL);
    if (ops) {
        const char *as = opt_s("alloc", "segfit,bestfit,firstfit,nextfit,immix");
        const char *fp = opt_s("frag", NULL), *mp = opt_s("majors", NULL);
        FILE *frag = fp ? fopen(fp, "a") : NULL, *majors = mp ? fopen(mp, "a") : NULL;
        for (int k = 0; k < GA_N; k++)
            if (in_list(as, ga_names[k])) h5_ops(ops, k, (size_t)opt_n("line", 128), (int)opt_n("exact", 0), (size_t)opt_n("reserve", 1073741824.0), frag, majors);
        if (frag) fclose(frag);
        if (majors) fclose(majors);
        return;
    }
    const char *dir = trace_dir(opt_s("trace", NULL));
    trace_t t; trace_open(&t, dir, (int)opt_n("graph", 1), 0);
    const char *as = opt_s("alloc", "bump,immix,segfit,bestfit,firstfit,nextfit");
    double ns[16]; int nn = opt_list("nursery", "1M", ns, 16);
    double fs[8]; int nf = opt_list("factor", "2", fs, 8);
    size_t minheap = (size_t)opt_n("min", 4194304.0), line = (size_t)opt_n("line", 128);
    int exact = (int)opt_n("exact", 0), graph = (int)opt_n("graph", 1), reps = (int)opt_n("reps", 3);
    size_t reserve = (size_t)opt_n("reserve", 1073741824.0);
    uint64_t max_bytes = (uint64_t)opt_n("bytes", 1e18);
    const char *fp = opt_s("frag", NULL);
    FILE *frag = fp ? fopen(fp, "a") : NULL;
    fprintf(stderr, "# H5-frag\ttrace\tcase\tpeak_fp/peak_occ\tnursery\tfactor\tmin_MiB\tmajors\tpromoted_objs\tpromoted_MiB\tpeak_footprint_MiB\tpeak_occupancy_MiB\tmean_frag\tmax_frag\tfinal_live_MiB\tfinal_footprint_MiB\tinternal_MiB\tlos_MiB\n");
    for (int a = 0; a < nn; a++)
        for (int b = 0; b < nf; b++)
            for (int k = 0; k < GA_N; k++)
                if (in_list(as, ga_names[k])) h5_one(&t, k, (size_t)ns[a], fs[b], minheap, line, exact, graph, reserve, max_bytes, reps, frag);
    if (frag) fclose(frag);
}

/* ---- gcbench alloc-test [objects=40K] [rounds=6] [reserve=256M] [seed=1] ----
   alloc.h without a trace, every allocator:

   * the closed forms: 2N objects of 32 bytes, then every other one dead
     (bump compacts to the live bytes, Immix frees no line, segfit keeps
     its pools, the free-list heaps free the dead bytes); then only the
     first object of every 128-byte line alive (Immix frees no line);
   * a shadow heap: ROUNDS rounds, each OBJECTS/2 allocations of 16 bytes
     to 20 KiB (small objects, Immix's medium ones, both large-object
     spaces) with every word of every object written with its id, then a
     major that kills a share of what lives (from a third to two thirds).
     After the allocations and after the major every live object still
     holds its header and its id in every word, no two overlap, each lies
     in the reservation unless it is large, the footprint covers them,
     segfit's pools count them, and the free-list heaps parse: live objects
     and free blocks tile every chunk, and the free blocks of 16 bytes or
     more are what the allocator counts as free. */
static void h5_closed_forms(void) {
    const size_t N = 1u << 16, S = 32;
    for (int k = 0; k < GA_N; k++) {
        for (int pattern = 0; pattern < 2; pattern++) {
            galloc *g = ga_new(k, 128, (size_t)1 << 30);
            char **a = malloc(2 * N * sizeof *a); uint32_t *z = malloc(2 * N * sizeof *z);
            for (size_t i = 0; i < 2 * N; i++) { a[i] = ga_alloc(g, S); hdr((obj *)a[i], K_TUPLE, 0, 3); z[i] = (uint32_t)S; }
            size_t fp0 = ga_footprint(g), live = 0, nl = 0;
            ga_major_begin(g);
            char **la = malloc(2 * N * sizeof *la);
            for (size_t i = 0; i < 2 * N; i++) {
                int alive = pattern == 0 ? (i % 2 == 0) : ((size_t)(a[i] - g->base) % 128 == 0);
                if (alive) { ga_live(g, a[i], S); la[nl++] = a[i]; live += S; } else ga_dead(g, a[i], S);
            }
            ga_major_end(g);
            if (k == GA_BUMP) ga_compact(g, la, z, nl);
            size_t fp1 = ga_footprint(g);
            const char *expect = "";
            int ok = 1;
            if (k == GA_BUMP) { ok = (size_t)(g->bfree - g->base) == live; expect = "compacted = live"; }
            else if (k == GA_IMMIX) { ok = fp1 == fp0 && g->nrecyc == 0; expect = "no line free: every block full"; }
            else if (k == GA_SEGFIT) { ok = fp1 == fp0; expect = "pools kept, half their slots free"; }
            else { ok = g->free_bytes >= (pattern == 0 ? N * S : 0); expect = "the dead bytes free"; }
            fprintf(stderr, "# alloc-test %s pattern %d: footprint %zu -> %zu, live %zu (%s): %s\n", ga_names[k], pattern, fp0, fp1, live, expect, ok ? "ok" : "WRONG");
            if (!ok) gcb_fail("alloc-test %s pattern %d: not %s", ga_names[k], pattern, expect);
            free(a); free(z); free(la);
            ga_delete(g);
        }
    }
}

typedef struct { char *addr; uint32_t size, id; } at_obj;
static int at_large(const galloc *g, size_t sz) {
    return (g->kind == GA_IMMIX && sz > g->los_threshold) || (g->kind == GA_SEGFIT && sz / 8 > SF_MAX_WORDS);
}
static void at_fill(char *p, size_t sz, uint32_t id) {
    hdr((obj *)p, K_TUPLE, 0, fields_for(sz));
    val *f = FIELDS(p);
    for (size_t i = 0, n = fields_for(sz); i < n; i++) f[i] = mk_int(id);
}
static void at_verify(galloc *g, const at_obj *o, size_t n, const char *when) {
    char what[96]; snprintf(what, sizeof what, "alloc-test %s %s", ga_names[g->kind], when);
    h5_span *sp = malloc((n ? n : 1) * sizeof *sp);
    size_t live = 0, small = 0;
    for (size_t i = 0; i < n; i++) {
        const obj *h = (const obj *)o[i].addr;
        int bad = okind(h) != K_TUPLE || osize(h) != o[i].size;
        for (size_t j = 0, m = fields_for(o[i].size); !bad && j < m; j++) bad = FIELDS(h)[j] != mk_int(o[i].id);
        if (bad) { gcb_fail("%s: object %u was overwritten", what, o[i].id); free(sp); return; }
        int inside = o[i].addr >= g->base && o[i].addr + o[i].size <= g->base + g->reserve;
        if (!inside && !at_large(g, o[i].size)) { gcb_fail("%s: object %u lies outside the reservation", what, o[i].id); free(sp); return; }
        sp[i].addr = o[i].addr; sp[i].size = o[i].size; live += o[i].size; small += !at_large(g, o[i].size);
    }
    h5_disjoint(sp, n, what);
    free(sp);
    if (ga_footprint(g) < live) gcb_fail("%s: a footprint of %zu bytes for %zu live", what, ga_footprint(g), live);
    if (g->kind == GA_SEGFIT) {
        size_t counted = 0;
        for (size_t i = 0; i < g->npools; i++) counted += g->pdesc[g->pools[i]].live;
        if (counted != small) gcb_fail("%s: the pools count %zu objects, %zu live", what, counted, small);
    }
    if (g->kind >= GA_BESTFIT) {
        size_t in_chunks = 0, free_counted = 0;
        for (size_t c = 0; c < g->nchunks; c++) {
            char *p = g->chunks[c].base, *end = p + g->chunks[c].bytes;
            while (p < end) {
                const obj *h = (const obj *)p;
                size_t sz = okind(h) == K_FREE ? h->len : osize(h);
                if (sz < 8 || sz % 8 || p + sz > end) { gcb_fail("%s: a chunk does not parse", what); return; }
                if (okind(h) == K_FREE) { if (sz >= 16) free_counted += sz; }
                else in_chunks++;
                p += sz;
            }
        }
        if (in_chunks != n) gcb_fail("%s: %zu objects in the chunks, %zu live", what, in_chunks, n);
        if (free_counted != g->free_bytes) gcb_fail("%s: free blocks of %zu bytes, the allocator counts %zu", what, free_counted, g->free_bytes);
    }
}
static size_t at_size(uint64_t *s) {
    double u = rnd_unit(s);
    size_t sz = u < 0.6 ? 16 + 8 * rnd_below(s, 7) : u < 0.85 ? 72 + 8 * rnd_below(s, 24)
              : u < 0.97 ? 264 + 8 * rnd_below(s, 224) : u < 0.995 ? 2056 + 8 * rnd_below(s, 768) : 8200 + 8 * rnd_below(s, 1536);
    return sz;
}
static void h5_shadow(int kind, size_t objects, int rounds, size_t reserve, uint64_t seed) {
    galloc *g = ga_new(kind, 128, reserve);
    size_t per = objects / 2 ? objects / 2 : 1, cap = per * (size_t)(rounds + 1);
    at_obj *o = malloc(cap * sizeof *o);
    char **a = malloc(cap * sizeof *a); uint32_t *z = malloc(cap * sizeof *z);
    size_t n = 0; uint32_t next_id = 1;
    uint64_t s = seed + (uint64_t)kind * 0x9E3779B97F4A7C15ULL;
    for (int r = 0; r < rounds; r++) {
        for (size_t i = 0; i < per; i++) {
            size_t sz = at_size(&s);
            char *p = ga_alloc(g, sz);
            at_fill(p, sz, next_id);
            o[n].addr = p; o[n].size = (uint32_t)sz; o[n].id = next_id++; n++;
        }
        char when[48]; snprintf(when, sizeof when, "round %d, allocated", r);
        at_verify(g, o, n, when);
        /* the major: survivors keep their order, which is address order for bump */
        double kill = 1.0 / 3 + rnd_unit(&s) / 3;
        ga_major_begin(g);
        size_t k = 0;
        for (size_t i = 0; i < n; i++) {
            if (rnd_unit(&s) < kill) ga_dead(g, o[i].addr, o[i].size);
            else { ga_live(g, o[i].addr, o[i].size); o[k++] = o[i]; }
        }
        n = k;
        ga_major_end(g);
        if (kind == GA_BUMP) {
            for (size_t i = 0; i < n; i++) { a[i] = o[i].addr; z[i] = o[i].size; }
            ga_compact(g, a, z, n);
            for (size_t i = 0; i < n; i++) o[i].addr = a[i];
        }
        snprintf(when, sizeof when, "round %d, after the major", r);
        at_verify(g, o, n, when);
    }
    fprintf(stderr, "# alloc-test %s: %u objects in %d rounds, %zu live at the end, footprint %.1f MiB\n",
            ga_names[kind], next_id - 1, rounds, n, (double)ga_footprint(g) / 1048576.0);
    /* the large objects still mapped go with the allocator's bookkeeping */
    for (size_t i = 0; i < n; i++) if (at_large(g, o[i].size)) los_free(&g->los, o[i].addr, o[i].size);
    free(o); free(a); free(z);
    ga_delete(g);
}
static void exp_alloc_test(void) {
    h5_closed_forms();
    size_t objects = (size_t)opt_n("objects", 40000), reserve = (size_t)opt_n("reserve", 268435456.0);
    int rounds = (int)opt_n("rounds", 6);
    uint64_t seed = (uint64_t)opt_n("seed", 1);
    for (int k = 0; k < GA_N; k++) h5_shadow(k, objects, rounds, reserve, seed);
    fprintf(stderr, "# alloc-test: %s\n", gcb_failures ? "FAILED" : "passed");
    if (gcb_failures) gcb_check = 1;   /* main reports the failures and exits 1 */
}
