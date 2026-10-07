/* h2.c -- H2, the cost of copying and of marking, per object and per byte:
   the synthetic heaps of heapgen.h (four shapes, objects of 16 to 256
   bytes, in creation order or shuffled, small enough for the caches or
   far larger), traced by each loop of collect.h. A row a (collector,
   shape, size, order, live size): cycles, instructions and misses per
   object traced; per byte is per object over the size.

   check=1: every collection copies or marks every object and byte of the
   heap, and after a copy every pointer of to-space points at the start of
   an object of to-space; a repetition is one collection.

   gcbench h2 [gc=copy,copy-pf,mark-hdr,mark-bm,mark-bm-pf,mark-hdr-edge,mark-bm-edge]
              [shape=list,tree,graph,array] [size=16,24,32,64,128,256]
              [live=32K,1M]  (and live=128M for the heap far above the caches) [order=alloc,shuf] [reps=5] [reps_big=3] */
#include "gcb.h"
#include "heapgen.h"
#include "collect.h"

enum { G_COPY, G_COPY_PF, G_MARK_HDR, G_MARK_BM, G_MARK_BM_PF, G_MARK_HDR_EDGE, G_MARK_BM_EDGE, G_N };
static const char *gc_names[] = { "copy", "copy-pf", "mark-hdr", "mark-bm", "mark-bm-pf", "mark-hdr-edge", "mark-bm-edge" };

/* check=1: to-space parses, and every pointer in it is to the start of
   one of its objects (a bitmap of the starts) */
static int h2_verify_copy(char *to, size_t bytes) {
    uint64_t *starts = calloc(bytes / 512 + 1, sizeof *starts);
    for (char *p = to; p < to + bytes; p += osize((obj *)p)) {
        if (okind((obj *)p) == K_FORWARD) { free(starts); return 0; }
        size_t b = (size_t)(p - to) >> 3; starts[b >> 6] |= (uint64_t)1 << (b & 63);
    }
    int ok = 1;
    for (char *p = to; ok && p < to + bytes; p += osize((obj *)p)) {
        obj *o = (obj *)p;
        if (!has_fields(o)) continue;
        for (uint32_t i = 0; i < o->len; i++) {
            val v = FIELDS(o)[i];
            if (!is_ptr(v)) continue;
            char *q = (char *)ptr_of(v);
            size_t b = (size_t)(q - to) >> 3;
            if (q < to || q >= to + bytes || !((starts[b >> 6] >> (b & 63)) & 1)) { ok = 0; break; }
        }
    }
    free(starts);
    return ok;
}

static void h2_one(int g, int shape, size_t osz, size_t live, int shuffle, int reps) {
    hg_t h;
    hg_plan(&h, shape, osz, live, shuffle);
    if (h.osz != osz) { hg_free(&h); return; }   /* tree and graph start at 24 bytes */
    h.base = region(h.cap, MAP_TOUCH);
    char *to = NULL;
    mk_t m;
    size_t ptrs = shape == SH_ARRAY ? h.k : shape == SH_LIST ? 1 : 2;
    if (g <= G_COPY_PF) to = region(h.cap, MAP_TOUCH);
    else mk_init(&m, h.base, h.cap, h.n * (g >= G_MARK_HDR_EDGE ? ptrs : 1) + 16);
    hg_fill(&h);
    reps_t r; reps_init(&r);
    int bad = 0;
    /* a repetition is ROUNDS collections (8 MiB traced at least), each
       timed alone: the rebuild of from-space between copies is not counted */
    size_t rounds = (8u << 20) / h.cap; if (rounds < 1 || gcb_check) rounds = 1;
    for (int k = 0; k < reps; k++) {
        phase p; ph_clear(&p);
        for (size_t j = 0; j < rounds; j++) {
            if (g <= G_COPY_PF) {
                if (k || j) hg_fill(&h);
                val root = h.root;
                ph_begin(&p);
                size_t bytes = g == G_COPY ? cheney(&root, 1, to) : cheney_pf(&root, 1, to);
                ph_end(&p);
                if (bytes != h.cap || cc_objs != h.n) bad = 1;
                else if (gcb_check && !h2_verify_copy(to, bytes)) bad = 2;
            } else {
                if (g == G_MARK_BM || g == G_MARK_BM_PF || g == G_MARK_BM_EDGE) mk_clear_bits(&m);
                ph_begin(&p);
                switch (g) {
                case G_MARK_HDR: mark_hdr(&m, h.root); break;
                case G_MARK_BM: mark_bm(&m, h.root); break;
                case G_MARK_BM_PF: mark_bm_pf(&m, h.root); break;
                case G_MARK_HDR_EDGE: mark_hdr_edge(&m, h.root); break;
                default: mark_bm_edge(&m, h.root); break;
                }
                ph_end(&p);
                if (m.marked != h.n || m.marked_bytes != h.cap) bad = 1;
                mk_next_cycle(&m);
            }
        }
        reps_add(&r, &p.acc);
    }
    char cas[128], hn[96];
    hg_name(&h, hn, sizeof hn, live);
    snprintf(cas, sizeof cas, "%s/%s", gc_names[g], hn);
    if (bad) gcb_fail("H2 %s: %s", cas, bad == 2 ? "to-space has a pointer that is not to one of its objects" : "the wrong count copied or marked");
    reps_out(&r, "H2", cas, "obj", (double)h.n * (double)rounds);
    if (to) region_free(to, h.cap); else mk_done(&m);
    region_free(h.base, h.cap);
    hg_free(&h);
}

static void exp_h2(void) {
    double sizes[32], lives[16];
    int nsz = opt_list("size", "16,24,32,64,128,256", sizes, 32);
    int nlv = opt_list("live", "32K,1M", lives, 16);
    const char *gcs = opt_s("gc", "copy,copy-pf,mark-hdr,mark-bm,mark-bm-pf,mark-hdr-edge,mark-bm-edge");
    const char *shapes = opt_s("shape", "list,tree,graph,array");
    const char *orders = opt_s("order", "alloc,shuf");
    int reps = (int)opt_n("reps", 5), reps_big = (int)opt_n("reps_big", 3);
    for (int li = 0; li < nlv; li++)
        for (int si = 0; si < nsz; si++)
            for (int shape = 0; shape < 4; shape++) {
                if (!in_list(shapes, shape_names[shape])) continue;
                for (int ord = 0; ord < 2; ord++) {
                    if (!in_list(orders, ord ? "shuf" : "alloc")) continue;
                    for (int g = 0; g < G_N; g++)
                        if (in_list(gcs, gc_names[g]))
                            h2_one(g, shape, (size_t)sizes[si], (size_t)lives[li], ord, lives[li] > (32 << 20) ? reps_big : reps);
                }
            }
}
