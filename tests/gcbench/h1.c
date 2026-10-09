/* h1.c -- H1, the nursery's size against L1, L2 and L3: an allocation
   kernel whose objects have the sizes and the lifetimes of a census trace
   (trace.h; the roadmap's is the bootstrap's, sampled every 32 KiB), in
   front of a nursery of a given size and a minor collection that copies
   the survivors into an old space.
   The mutator and the minor collections are counted apart (gcb.h's
   phases), and each gets its misses per KiB allocated.

   The kernel. Object i of the trace is allocated with its size and kind
   (raw or with fields) and its header and every field written; it dies at
   a clock in the interval its death lies in (trace.h: between the last
   sample that saw it alive and the next): band=lo just after the first
   (at its birth, if no sample saw it), band=mid uniformly, band=hi at the
   second. lo is exact at the samples and optimistic between them: with a
   trace sampled every 32 KiB, survival is exact for a nursery that is a
   multiple of 32 KiB collected at the samples, and below it for others. Liveness is made by reachability,
   without nepotism: every object is put on the chain of the objects that
   die in the same 4 KiB of clock (field 0 points to the previous one, the
   chain's head is a root), and when the clock passes those 4 KiB the
   head is cleared and the chain is garbage. A raw object, or one with no
   field, goes on its chain through a cons cell of 24 bytes allocated after
   it (the bytes are counted; about 2% more). The other fields are
   immediates. A minor collection's roots are the heads written since the
   last one; it copies what they reach in the nursery into the old space
   (Cheney, runtime/heap.c's copy_obj) and promotes at the first survival.
   There are no old-to-young pointers (an old chain is only ever pointed
   at), so no barrier: H6 is the barrier's experiment. The old space is
   never collected (it is mapped and touched before the timing).

   With pf=D the allocation issues prefetchw D bytes ahead of the bump
   pointer (HotSpot's AllocatePrefetch).

   check=1: after every minor collection no root and no object promoted
   since the last one points into the nursery, and the old space parses;
   every prefetch distance promotes the same bytes in the same minors.

   gcbench h1 trace=DIR|NAME [bytes=512M] [nursery=64K,...,32M] [pf=0,256]
              [band=lo|mid|hi] [huge=0] [reps=3] */
#include "gcb.h"
#include "trace.h"

#define H1_GSHIFT 12
typedef struct { uint32_t size; uint32_t dbucket; uint8_t raw; uint8_t pad[3]; } h1_obj;   /* the replay, one an object */

static h1_obj *h1_rep; static size_t h1_n; static uint64_t h1_bytes;
static uint32_t h1_nbuckets;

/* where in its interval an object dies: 0 lo (just after the last sample
   that saw it alive; at its birth if none did), 1 uniform, 2 hi (just
   before the first sample that did not) */
static int h1_band;
static void h1_prepare(const char *dir, uint64_t max_bytes) {
    trace_t t; trace_open(&t, dir, 0, 0);
    twalk w; tw_init(&w, &t);
    size_t cap = t.nids;
    h1_rep = malloc(cap * sizeof *h1_rep);
    uint64_t seed = 0xD1E5ULL;
    h1_n = 0; h1_bytes = 0;
    uint64_t maxd = 0;
    while (tw_next(&w) && w.birth < max_bytes) {
        h1_obj *o = &h1_rep[h1_n++];
        const trec *r = &t.alloc[w.id];
        o->size = (uint32_t)w.size;
        o->raw = !t_has_fields(r->kind) || r->len == 0;
        uint64_t d;
        if (w.dhi == UINT64_MAX) d = UINT64_MAX;
        else {
            d = h1_band == 0 ? w.dlo + 1 : h1_band == 2 ? w.dhi : w.dlo + 1 + rnd_below(&seed, w.dhi - w.dlo);
            if (d < w.birth + w.size) d = w.birth + w.size;
        }
        o->dbucket = d == UINT64_MAX ? UINT32_MAX : (uint32_t)(d >> H1_GSHIFT);
        if (d != UINT64_MAX && d > maxd) maxd = d;
        h1_bytes = w.clock;
    }
    /* the wheel reaches past the replay's end (the clock expires buckets up
       to it) and past every death; the last bucket holds the immortal ones
       and is never expired */
    if (h1_bytes > maxd) maxd = h1_bytes;
    h1_nbuckets = (uint32_t)(maxd >> H1_GSHIFT) + 3;
    for (size_t i = 0; i < h1_n; i++) if (h1_rep[i].dbucket == UINT32_MAX) h1_rep[i].dbucket = h1_nbuckets - 1;
    fprintf(stderr, "# H1 trace %s: %zu objects, %.1f MiB, %u buckets of 4 KiB\n", dir, h1_n, (double)h1_bytes / 1048576.0, h1_nbuckets);
}

/* ---- the heap ---- */
static char *n_base, *n_free, *n_limit;   /* the nursery */
static char *o_base, *o_free, *o_limit;   /* the old space */
static val *h1_head;                       /* the chains' heads (roots), one a bucket */
static uint8_t *h1_dirty; static uint32_t *h1_dlist; static size_t h1_ndirty;
static phase h1_gc;
/* objects over a quarter of the nursery go to the old space at once (as the
   prototype's), remembered until the next minor: their field 0 may point
   at a young object of their chain */
static obj **h1_rem; static size_t h1_nrem; static uint64_t h1_large_bytes;
static uint64_t h1_minors;
static uint64_t h1_clock;                  /* the replay's allocation clock (the trace's bytes) */

ALWAYS_INLINE int h1_young(val v) { return is_ptr(v) && (char *)ptr_of(v) >= n_base && (char *)ptr_of(v) < n_limit; }
ALWAYS_INLINE obj *h1_copy(obj *o) {
    if (okind(o) == K_FORWARD) { obj *n; memcpy(&n, FIELDS(o), 8); return n; }
    size_t sz = osize(o);
    obj *n = (obj *)o_free;
    if (UNLIKELY(o_free + sz > o_limit)) die("H1: the old space overflowed");
    switch (sz) {
    case 16: memcpy(n, o, 16); break;
    case 24: memcpy(n, o, 24); break;
    case 32: memcpy(n, o, 32); break;
    case 40: memcpy(n, o, 40); break;
    case 48: memcpy(n, o, 48); break;
    case 56: memcpy(n, o, 56); break;
    default: memcpy(n, o, sz); break;
    }
    o_free += sz;
    o->kind = K_FORWARD;
    memcpy(FIELDS(o), &n, 8);
    return n;
}
ALWAYS_INLINE void h1_value(val *v) { if (h1_young(*v)) *v = ptr_val(h1_copy(ptr_of(*v))); }
/* check=1, after a minor: the old space from where the last check stopped
   (what was promoted or allocated there large since) parses, and neither
   it nor a root points into the nursery; older objects are never written */
static char *h1_checked;
static void h1_verify(void) {
    for (char *p = h1_checked; p < o_free; ) {
        obj *o = (obj *)p;
        size_t sz = osize(o);
        if (okind(o) == K_FORWARD || p + sz > o_free) { gcb_fail("H1: the old space does not parse at %zu", (size_t)(p - o_base)); return; }
        if (has_fields(o))
            for (uint32_t i = 0; i < o->len; i++)
                if (h1_young(FIELDS(o)[i])) { gcb_fail("H1: an old object points into the nursery after a minor"); return; }
        p += sz;
    }
    h1_checked = o_free;
    for (uint32_t b = 0; b < h1_nbuckets; b++)
        if (h1_young(h1_head[b])) { gcb_fail("H1: a root points into the nursery after a minor"); return; }
}
static NOINLINE void h1_minor(void) {
    ph_begin(&h1_gc);
    char *scan = o_free;
    for (size_t i = 0; i < h1_ndirty; i++) { uint32_t b = h1_dlist[i]; h1_dirty[b] = 0; h1_value(&h1_head[b]); }
    h1_ndirty = 0;
    for (size_t i = 0; i < h1_nrem; i++) { obj *o = h1_rem[i]; if (has_fields(o)) { val *f = FIELDS(o); for (uint32_t j = 0, n = o->len; j < n; j++) h1_value(&f[j]); } }
    h1_nrem = 0;
    while (scan < o_free) {
        obj *o = (obj *)scan;
        if (has_fields(o)) { val *f = FIELDS(o); for (uint32_t i = 0, n = o->len; i < n; i++) h1_value(&f[i]); }
        scan += osize(o);
    }
    if (o_free > o_limit) die("H1: the old space overflowed");
    n_free = n_base;
    h1_minors++;
    ph_end(&h1_gc);
    if (gcb_check) h1_verify();
}

ALWAYS_INLINE void h1_push(val v, uint32_t b) {
    if (!h1_dirty[b]) { h1_dirty[b] = 1; h1_dlist[h1_ndirty++] = b; }
    h1_head[b] = v;
}

/* the replay: PF = prefetchw distance (0 none) */
static NOINLINE void h1_run(size_t pf) {
    uint32_t expired = 0;
    h1_clock = 0;
    for (size_t i = 0; i < h1_n; i++) {
        const h1_obj *r = &h1_rep[i];
        size_t sz = r->size, need = sz + (r->raw ? 24 : 0);
        char *p;
        int large = need > (size_t)(n_limit - n_base) / 4;
        if (UNLIKELY(large)) {
            if (o_free + sz > o_limit) die("H1: the old space overflowed (a large object)");
            p = o_free; o_free += sz; h1_large_bytes += sz;
        } else {
            if (UNLIKELY(n_free + need > n_limit)) h1_minor();
            p = n_free;
            n_free = p + sz;
        }
        if (pf) __builtin_prefetch(p + pf, 1, 3);
        obj *o = (obj *)p;
        uint32_t b = r->dbucket;
        if (r->raw) {
            hdr(o, K_STRING, 0, (uint32_t)(sz - 8));
            memset(FIELDS(o), 0, sz - 8);
            if (UNLIKELY(large) && n_free + 24 > n_limit) h1_minor();
            obj *c = (obj *)n_free; n_free += 24;
            hdr(c, K_CON, 1, 2);
            FIELDS(c)[0] = ptr_val(o); FIELDS(c)[1] = h1_head[b];
            h1_push(ptr_val(c), b);
        } else {
            uint32_t len = (uint32_t)((sz - 8) / 8);
            hdr(o, K_TUPLE, 0, len);
            val *f = FIELDS(o);
            f[0] = h1_head[b];
            for (uint32_t j = 1; j < len; j++) f[j] = mk_int((int64_t)j);
            if (UNLIKELY(large)) h1_rem[h1_nrem++] = o;
            h1_push(ptr_val(o), b);
        }
        h1_clock += sz;
        uint32_t now = (uint32_t)(h1_clock >> H1_GSHIFT);
        while (expired < now && expired < h1_nbuckets - 1) h1_head[expired++] = NIL;
    }
}

static void exp_h1(void) {
    const char *dir = trace_dir(opt_s("trace", NULL));
    uint64_t max_bytes = (uint64_t)opt_n("bytes", 512.0 * 1048576);
    double ns[32], pfs[8];
    int nn = opt_list("nursery", "64K,128K,256K,512K,1M,2M,4M,8M,16M,32M", ns, 32);
    int npf = opt_list("pf", "0,256", pfs, 8);
    int huge = (int)opt_n("huge", 0), reps = (int)opt_n("reps", 3);
    const char *band = opt_s("band", "lo");
    h1_band = !strcmp(band, "hi") ? 2 : !strcmp(band, "mid") ? 1 : 0;
    h1_prepare(dir, max_bytes);
    h1_head = malloc((size_t)h1_nbuckets * sizeof *h1_head);
    h1_dirty = calloc(h1_nbuckets, 1);
    h1_dlist = malloc((size_t)h1_nbuckets * sizeof *h1_dlist);
    h1_rem = malloc(h1_n * sizeof *h1_rem);
    size_t old_cap = rup((size_t)(h1_bytes * 0.6) + (64u << 20), 4096);
    o_base = region(old_cap, MAP_TOUCH);
    for (int a = 0; a < nn; a++) {
        uint64_t minors0 = 0, promoted0 = 0;   /* the first prefetch distance's */
        for (int c = 0; c < npf; c++) {
            size_t nsz = (size_t)ns[a], pf = (size_t)pfs[c];
            n_base = region(nsz + 4096, huge ? MAP_HUGE : MAP_TOUCH);
            n_limit = n_base + nsz;
            reps_t rm, rg; reps_init(&rm); reps_init(&rg);
            uint64_t minors = 0, promoted = 0;
            for (int k = 0; k < reps; k++) {
                for (uint32_t b = 0; b < h1_nbuckets; b++) h1_head[b] = NIL;
                memset(h1_dirty, 0, h1_nbuckets); h1_ndirty = 0;
                n_free = n_base; o_free = o_base; o_limit = o_base + old_cap; h1_nrem = 0; h1_large_bytes = 0; h1_checked = o_base;
                ph_clear(&h1_gc); h1_minors = 0;
                ctrs a0, a1, tot, mut;
                pc_read(&a0);
                h1_run(pf);
                pc_read(&a1);
                ctrs_sub(&tot, &a1, &a0);
                ctrs_sub(&mut, &tot, &h1_gc.acc);
                reps_add(&rm, &mut);
                reps_add(&rg, &h1_gc.acc);
                minors = h1_minors; promoted = (uint64_t)(o_free - o_base);
            }
            if (c == 0) { minors0 = minors; promoted0 = promoted; }
            else if (gcb_check && (minors != minors0 || promoted != promoted0))
                gcb_fail("H1 n=%zu: pf=%zu made %llu minors and %llu bytes in the old space, pf=%zu %llu and %llu", nsz, pf,
                         (unsigned long long)minors, (unsigned long long)promoted, (size_t)pfs[0], (unsigned long long)minors0, (unsigned long long)promoted0);
            char cas[96], hb[32];
            double kib = (double)h1_bytes / 1024.0;
            snprintf(cas, sizeof cas, "mutator/n=%s/pf=%zu/%s%s", human((double)nsz, hb), pf, band, huge ? "/huge" : "");
            reps_out(&rm, "H1", cas, "KiB", kib);
            snprintf(cas, sizeof cas, "minor/n=%s/pf=%zu/%s%s", human((double)nsz, hb), pf, band, huge ? "/huge" : "");
            reps_out(&rg, "H1", cas, "KiB", kib);
            fprintf(stderr, "# H1 n=%s pf=%zu band=%s: large %.1f MiB to the old space at once\n", human((double)nsz, hb), pf, band, (double)h1_large_bytes / 1048576.0);
            fprintf(stderr, "# H1 n=%s pf=%zu band=%s: %llu minors, promoted %.1f MiB of %.1f MiB (survival %.2f%%)\n",
                    human((double)nsz, hb), pf, band, (unsigned long long)minors, (double)promoted / 1048576.0,
                    (double)h1_bytes / 1048576.0, 100.0 * (double)promoted / (double)h1_bytes);
            region_free(n_base, nsz + 4096);
        }
    }
    region_free(o_base, old_cap);
}
