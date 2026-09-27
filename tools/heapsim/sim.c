/* sim.c -- trace-driven heap simulator: replays a census trace (docs/census.md)
   under a candidate layout (layouts.h) and a collector model, printing one
   tab-separated line.

   sim --trace DIR --layout L0..L4 [--variant F,F,...] --collector copier|nursery|sticky|los|mutseg
       [--heap-size N] [--heap-fill P] [--nursery N] [--promote 1|2] [--los T]
       --band lo|hi [--real-level store|call|result] [--workload NAME] [--header] [--check]

   Liveness comes from death.bin at the census's forced samples; between two
   samples an object's state is known only as a band: --band lo counts an
   object live at a point between samples k and k+1 only when it survived
   sample k+1, --band hi when it survived sample k (and everything born since
   sample k). At a sample itself liveness is exact.
   built as bin/heapsim by the Makefile (make bin/heapsim) */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include "layouts.h"

typedef struct { uint8_t kind, site_kind; uint16_t contag; uint32_t len, site, func; } AllocRec;
typedef struct { uint32_t clock16, src, dst; uint16_t field; uint8_t site, flags; } StoreRec;
typedef struct { uint64_t clock, live_bytes, live_objs; } SampleRec;
#define DEATH_INF 0xFFFFFFFFu
enum { NCLS = 4 };
static const size_t cls_threshold[NCLS] = { 0, 2048, 8192, 32768 };
enum { REP_ANY = 0, REP_UNKNOWN = 15 };

static void die(const char *m) { fprintf(stderr, "sim: %s\n", m); exit(2); }
static void *xcalloc(size_t n, size_t s) { void *p = calloc(n ? n : 1, s); if (!p) die("out of memory"); return p; }

/* ---- options ---- */
static const char *trace_dir, *workload;
static enum Layout L = L0; static unsigned V = 0; static char variant_str[128] = "-";
static enum { C_COPIER, C_NURSERY, C_STICKY, C_LOS, C_MUTSEG } collector = C_COPIER;
static const char *collector_name = "copier";
static size_t heap_size0 = 4u << 20, nursery = 1u << 20, los_t = 0;
static unsigned heap_fill = 50; static int promote = 1, band_hi = 0, real_level = 0, do_check = 0, gc_trace = 0, no_stores = 0;
static uint64_t cur_clock0;
static uint64_t probes[64]; static int nprobes, probe_i;

/* ---- trace ---- */
static AllocRec *alloc_rec; static uint32_t N;
static uint8_t *fields; static size_t fields_bytes;
static uint32_t *death;
static SampleRec *samples; static uint32_t nsamples;
static uint32_t *sample_id;        /* [k] = first id born after sample k; [0] = 1; [nsamples+1] = N+1 */
static int samples_zero_based;
static uint64_t *sample_clockL;    /* L bytes allocated (boxes included) when sample k ran */
static uint32_t *size_L, *box_bytes, *clock16_L;
static uint8_t *homog;             /* bit 7 homogeneous, bits 0-2 elem tag, bits 3-5 elem bc */
typedef struct { uint32_t id, size, j, d; } SBox;   /* a store's box: allocated before id, born in window j, last alive at sample d */
static SBox *sboxes; static size_t nsboxes, sboxes_cap;
static uint64_t *diffc[NCLS], *Wc[NCLS], *Sge[NCLS], *Blo[NCLS];
static size_t box_size;

/* ---- counters ---- */
static uint64_t bytes_L0, bytes_alloc, boxes_by_tag[8], box_bytes_by_tag[8], unrepresentable, objects_total;
static uint64_t stores_by_site[3], oy_by_site[3], setenv_old_src, compact_objs, pair_objs, hist_boxes, hist_box_bytes;

/* ---- mmap helpers ---- */
static void *map_file(const char *name, size_t *len) {
    char p[4096]; snprintf(p, sizeof p, "%s/%s", trace_dir, name);
    int fd = open(p, O_RDONLY); if (fd < 0) { perror(p); exit(2); }
    struct stat st; if (fstat(fd, &st)) { perror(p); exit(2); }
    *len = (size_t)st.st_size;
    void *m = *len ? mmap(NULL, *len, PROT_READ, MAP_PRIVATE, fd, 0) : NULL;
    if (*len && m == MAP_FAILED) { perror(p); exit(2); }
    close(fd);
    return m;
}

/* sequential reader of stores.bin */
typedef struct { FILE *f; StoreRec buf[4096]; size_t n, i; int eof; } StoreReader;
static void sr_open(StoreReader *r) {
    char p[4096]; snprintf(p, sizeof p, "%s/stores.bin", trace_dir);
    r->f = fopen(p, "rb"); r->n = r->i = 0; r->eof = r->f == NULL;
}
static int sr_next(StoreReader *r, StoreRec *s) {
    if (r->i == r->n) {
        if (r->eof) return 0;
        r->n = fread(r->buf, sizeof(StoreRec), 4096, r->f); r->i = 0;
        if (r->n == 0) { r->eof = 1; return 0; }
    }
    *s = r->buf[r->i++];
    return 1;
}
static void sr_close(StoreReader *r) { if (r->f) fclose(r->f); }

/* ---- open-addressing hash map u64 -> u32 (for pending store boxes) and a set (remset) ---- */
typedef struct { uint64_t *keys; uint32_t *vals; uint32_t *gen; size_t cap, n; uint32_t cur_gen; } HMap;
static void hm_init(HMap *h, size_t cap) { h->cap = cap; h->n = 0; h->cur_gen = 1; h->keys = xcalloc(cap, 8); h->vals = xcalloc(cap, 4); h->gen = xcalloc(cap, 4); }
static uint64_t hm_hash(uint64_t k) { k ^= k >> 33; k *= 0xff51afd7ed558ccdull; k ^= k >> 33; k *= 0xc4ceb9fe1a85ec53ull; k ^= k >> 33; return k; }
static void hm_grow(HMap *h);
static uint32_t *hm_find(HMap *h, uint64_t key, int insert) {   /* returns slot value or NULL */
    if (insert && h->n * 2 >= h->cap) hm_grow(h);
    size_t i = hm_hash(key) & (h->cap - 1);
    for (;;) {
        if (h->gen[i] != h->cur_gen) {
            if (!insert) return NULL;
            h->gen[i] = h->cur_gen; h->keys[i] = key; h->vals[i] = 0; h->n++;
            return &h->vals[i];
        }
        if (h->keys[i] == key) return &h->vals[i];
        i = (i + 1) & (h->cap - 1);
    }
}
static void hm_grow(HMap *h) {
    HMap g; hm_init(&g, h->cap * 2); g.cur_gen = h->cur_gen;
    for (size_t i = 0; i < h->cap; i++) if (h->gen[i] == h->cur_gen) *hm_find(&g, h->keys[i], 1) = h->vals[i];
    free(h->keys); free(h->vals); free(h->gen); *h = g;
}
static void hm_clear(HMap *h) { h->cur_gen++; h->n = 0; }
/* delete: mark slot as of an old generation is unsafe with linear probing; the
   pending-box map instead stores 0 = closed and lets entries be overwritten */

/* ---- the layout's box rule for a value ---- */
static int needs_box(uint8_t kind, uint8_t tag, uint8_t bc, unsigned rep, int anypoly) {
    if (tag != LT_INT && tag != LT_WORD && tag != LT_REAL) return 0;
    int poly = rep == REP_ANY || rep == REP_UNKNOWN;
    if (V & LV_L4UNIFORM) {
        if (kind == LK_CON || kind == LK_REF || kind == LK_ARRAY || kind == LK_EXN || kind == LK_EXNCON) poly = 1;
        else if (anypoly) poly = 1;
    }
    return layout_needs_box(L, V, tag, bc, poly);
}

static void add_sbox(uint32_t id, uint32_t j, uint32_t d) {
    if (nsboxes == sboxes_cap) { sboxes_cap = sboxes_cap ? sboxes_cap * 2 : 1 << 16; sboxes = realloc(sboxes, sboxes_cap * sizeof *sboxes); if (!sboxes) die("out of memory"); }
    sboxes[nsboxes++] = (SBox){ id, (uint32_t)box_size, j, d };
}

/* ---- pass 1: alloc + fields + stores, in one merged walk of the clock ---- */
static HMap pending;   /* (src<<16|field) -> index+1 of the open store box */
static void process_store(const StoreRec *s, uint32_t k, uint32_t id) {
    unsigned site = s->site < 3 ? s->site : 2;
    stores_by_site[site]++;
    if (s->src == 0 || s->src > N) return;
    uint8_t tag = (s->flags >> 1) & 7, rep = s->flags >> 4;
    uint8_t kind = alloc_rec[s->src].kind;
    if ((homog[s->src] & 0x80) && (homog[s->src] & 7) != tag) homog[s->src] &= 0x7f;
    if (L == L0) return;
    uint64_t key = ((uint64_t)s->src << 16) | s->field;
    uint32_t *slot = hm_find(&pending, key, 0);
    if (slot && *slot) { SBox *b = &sboxes[*slot - 1]; if (b->d > k) b->d = k; *slot = 0; }
    if (tag != LT_INT && tag != LT_WORD && tag != LT_REAL) return;
    /* stores.bin carries no bits class: an array's elements keep the class of
       their fill, other stored ints/words are taken as small, reals as
       value-encodable (approximation, see the report) */
    uint8_t bc = (tag == LT_REAL) ? 0 : BC_31;
    if (kind == LK_ARRAY && (homog[s->src] & 0x80) && (homog[s->src] & 7) == tag) bc = (homog[s->src] >> 3) & 7;
    int r = needs_box(kind, tag, bc, rep, 0);
    if (r == 2) { unrepresentable++; return; }
    if (r == 1) {
        add_sbox(id, k, death[s->src]);
        boxes_by_tag[tag]++; box_bytes_by_tag[tag] += box_size;
        *hm_find(&pending, key, 1) = (uint32_t)nsboxes;
    }
}

static void pass1(void) {
    uint64_t clock0 = 0; uint32_t k = 0; size_t foff = 0;
    sample_id[0] = 1;
    StoreReader sr; StoreRec st; int have = 0;
    if (no_stores) sr.f = NULL; else { sr_open(&sr); have = sr_next(&sr, &st); }
    if (L != L0) hm_init(&pending, 1 << 16);
    for (uint32_t id = 1; id <= N; id++) {
        while (k < nsamples && samples[k + 1].clock <= clock0) { k++; sample_id[k] = id; }
        while (have && (uint64_t)st.clock16 <= clock0 / 16) { process_store(&st, k, id); have = sr_next(&sr, &st); }
        const AllocRec *a = &alloc_rec[id];
        if (a->kind != LK_STRING) {
            if (foff + (size_t)a->len * 2 > fields_bytes) die("fields.bin too short");
            const uint8_t *f = fields + foff;
            int anypoly = 0, hom = (a->kind == LK_ARRAY || (a->kind == LK_TUPLE && a->site_kind == 1)) && a->len > 0;
            uint8_t et = 0, ebc = 0;
            for (uint32_t i = 0; i < a->len; i++) {
                uint8_t tag = f[2 * i] & 7, bc = f[2 * i + 1] & 7, rep = f[2 * i + 1] >> 3;
                if (i == 0) { et = tag; ebc = bc; }
                else if (tag != et) hom = 0;
                else if (bc > ebc) ebc = bc;
                if (rep == REP_ANY || rep == REP_UNKNOWN) anypoly = 1;
            }
            if (hom) homog[id] = 0x80 | et | (ebc << 3);
            if (L != L0) {
                uint32_t nb = 0;
                for (uint32_t i = 0; i < a->len; i++) {
                    uint8_t tag = f[2 * i] & 7, bc = f[2 * i + 1] & 7, rep = f[2 * i + 1] >> 3;
                    if (a->kind == LK_CLOSURE && i == 0) continue;   /* the function index */
                    int r = needs_box(a->kind, tag, bc, rep, anypoly);
                    if (r == 2) unrepresentable++;
                    else if (r == 1) { nb++; boxes_by_tag[tag]++; box_bytes_by_tag[tag] += box_size; }
                }
                box_bytes[id] = (uint32_t)(nb * box_size);
            }
            foff += (size_t)a->len * 2;
        }
        clock0 += l0_obj_size(a->kind, a->len);
    }
    while (have) { process_store(&st, k, N + 1); have = sr_next(&sr, &st); }
    sr_close(&sr);
    while (k < nsamples) { k++; sample_id[k] = N + 1; }
    sample_id[nsamples + 1] = N + 1;
    bytes_L0 = clock0;
    if (foff != fields_bytes) fprintf(stderr, "sim: warning: fields.bin has %zu bytes, %zu expected from alloc.bin\n", fields_bytes, foff);
}

/* ---- pass 2: sizes under L, L-clocks, the per-class liveness prefix arrays ---- */
static unsigned cls_of(size_t size) { unsigned c = 0; while (c + 1 < NCLS && size >= cls_threshold[c + 1]) c++; return c; }
static void diff_add(unsigned cls, uint32_t j, uint32_t d, uint64_t size) {
    if (d == DEATH_INF) d = nsamples + 1;
    if (d <= j) return;
    for (unsigned c = 0; c <= cls; c++) { diffc[c][j + 1] += size; diffc[c][d + 1] -= size; Wc[c][j] += size; }
}
static void pass2(void) {
    uint64_t clockL = 0; uint32_t k = 0; size_t bx = 0;
    for (unsigned c = 0; c < NCLS; c++) { diffc[c] = xcalloc(nsamples + 3, 8); Wc[c] = xcalloc(nsamples + 3, 8); Sge[c] = xcalloc(nsamples + 3, 8); Blo[c] = xcalloc(nsamples + 3, 8); }
    sample_clockL[0] = 0;
    for (uint32_t id = 1; id <= N; id++) {
        while (k < nsamples && sample_id[k + 1] == id) { k++; sample_clockL[k] = clockL; }
        while (bx < nsboxes && sboxes[bx].id == id) { diff_add(0, sboxes[bx].j, sboxes[bx].d, sboxes[bx].size); clockL += sboxes[bx].size; bx++; }
        const AllocRec *a = &alloc_rec[id];
        unsigned elem = layout_compact_elem(V, a->kind, homog[id] >> 7, homog[id] & 7, (homog[id] >> 3) & 7);
        size_t s = layout_obj_size(L, V, a->kind, a->len, elem);
        if (elem) {   /* a compact array's elements are unboxed by definition: withdraw their boxes */
            compact_objs++;
            if (box_bytes[id]) {
                uint64_t nb = box_bytes[id] / box_size; uint8_t et = homog[id] & 7;
                boxes_by_tag[et] -= nb; box_bytes_by_tag[et] -= nb * box_size; box_bytes[id] = 0;
            }
        }
        if ((V & LV_PAIRS) && L != L0 && (a->kind == LK_CON || a->kind == LK_TUPLE) && a->len == 2) pair_objs++;
        size_L[id] = (uint32_t)s;
        if (box_bytes[id]) diff_add(0, k, death[id], box_bytes[id]);
        clockL += box_bytes[id];
        clock16_L[id] = (uint32_t)(clockL / 16);
        diff_add(cls_of(s), k, death[id], s);
        clockL += s;
    }
    while (k < nsamples) { k++; sample_clockL[k] = clockL; }
    sample_clockL[nsamples + 1] = clockL;
    bytes_alloc = clockL;
    for (unsigned c = 0; c < NCLS; c++) {
        uint64_t acc = 0;
        for (uint32_t i = 0; i <= nsamples + 1; i++) { acc += diffc[c][i]; Sge[c][i] = acc; }
        for (uint32_t i = 0; i <= nsamples; i++) Blo[c][i] = Sge[c][i + 1] - Wc[c][i];
    }
}

/* ---- the copier (vm/heap.c's policy) ---- */
typedef struct {
    size_t size, used, live_last, live_before, count, to_size, max_footprint, max_size;
    uint64_t copied, copied_cls[NCLS];
    size_t los_cls;                 /* class excluded from the semispace (LOS), 0 = none */
    size_t max_live;                /* the largest to_used of any collection (measure-tree's `max live`) */
} Heap;
static size_t fill_of(size_t n) { return n / 100 * heap_fill + n % 100 * heap_fill / 100; }
static size_t grown(size_t size, size_t used, size_t needed) {
    size_t want = size;
    while (used > fill_of(want) || needed > fill_of(want) - used) { if (want > SIZE_MAX / 2) die("heap wraps"); want *= 2; }
    return want;
}
static void heap_init(Heap *h, size_t size) { memset(h, 0, sizeof *h); h->size = size; h->max_footprint = size; h->max_size = size; }
static void collect_into(Heap *h, size_t new_size, const uint64_t live[NCLS]) {
    size_t to = new_size;   /* a fresh to-space, or the kept one of the same size */
    if (h->size + to > h->max_footprint) h->max_footprint = h->size + to;
    uint64_t small = live[0] - (h->los_cls ? live[h->los_cls] : 0);
    h->used = small; h->copied += small;
    if (small > h->max_live) h->max_live = small;
    for (unsigned c = 0; c < NCLS; c++) h->copied_cls[c] += live[c];
    h->to_size = new_size == h->size ? h->size : 0;
    h->size = new_size; h->count++;
    if (new_size > h->max_size) h->max_size = new_size;
}
static void vm_gc(Heap *h, size_t needed, const uint64_t live[NCLS]) {
    size_t size0 = h->size, used0 = h->used, count0 = h->count;
    size_t guess = h->live_last;
    if (h->live_last > h->live_before) {
        guess += h->live_last - h->live_before;
        if (guess < h->live_last || guess > h->size) guess = h->size;
    }
    collect_into(h, grown(h->size, guess, needed), live);
    size_t want = grown(h->size, h->used, needed);
    if (want != h->size) collect_into(h, want, live);
    h->live_before = h->live_last; h->live_last = h->used;
    if (gc_trace) fprintf(stderr, "gc: at %" PRIu64 " needed %zu size %zu used %zu guess %zu live %zu new_size %zu second %d\n",
                          cur_clock0, needed, size0, used0, guess, h->used, h->size, (int)(h->count - count0 - 1));
}

/* ---- the run ---- */
typedef struct {
    /* liveness cursor */
    uint32_t k; uint64_t acc_all[NCLS], acc_lo[NCLS];
    /* copier / los */
    Heap heap; size_t los_used, los_budget, los_live_max; uint64_t los_bytes, los_objects, band_lo_sum, band_hi_sum;
    /* nursery / sticky */
    uint32_t cycle_start_id, cycle_start_k, prev_start_id; size_t bx_cycle_start;
    uint64_t nursery_alloc, surv_first, promoted, minors, majors, copied_minor, copied_major, marked_minor, marked_major, sweep_bytes;
    uint64_t old_live[NCLS], *old_by_death[NCLS], old_total, sticky_size, sticky_max, max_cycle_surv, minor_surv_cls[NCLS];
    HMap rem_entries, rem_cards; uint64_t rem_max_entries, rem_max_cards, rem_total_entries, rem_total_cards;
} Run;
static Run R;

static void live_now(uint64_t lo[NCLS], uint64_t hi[NCLS]) {
    uint32_t k = R.k;
    for (unsigned c = 0; c < NCLS; c++) {
        if (R.acc_all[0] == 0) { lo[c] = hi[c] = Sge[c][k]; }
        else { lo[c] = Blo[c][k] + R.acc_lo[c]; hi[c] = Sge[c][k] + R.acc_all[c]; }
    }
}
static void copier_alloc(size_t size, uint32_t d) {
    unsigned cls = cls_of(size);
    while (probe_i < nprobes && probes[probe_i] <= cur_clock0) {   /* --probe: the band at this L0 clock */
        uint64_t lo[NCLS], hi[NCLS]; live_now(lo, hi);
        fprintf(stderr, "probe: at %" PRIu64 " lo %" PRIu64 " hi %" PRIu64 " %s\n", probes[probe_i], lo[0], hi[0], probes[probe_i] == cur_clock0 ? "" : "(next object)");
        probe_i++;
    }
    int large = collector == C_LOS && size >= los_t;
    int trigger = large ? (R.los_used + size > R.los_budget) : (size > R.heap.size - R.heap.used);
    if (trigger) {
        uint64_t lo[NCLS], hi[NCLS]; live_now(lo, hi);
        R.band_lo_sum += lo[0]; R.band_hi_sum += hi[0];
        const uint64_t *live = band_hi ? hi : lo;
        vm_gc(&R.heap, large ? 0 : size, live);
        if (collector == C_LOS) {
            R.los_used = live[R.heap.los_cls];
            if (R.los_used > R.los_live_max) R.los_live_max = R.los_used;
            R.los_budget = grown(R.los_budget, R.los_used, large ? size : 0);
        }
    }
    if (large) { R.los_used += size; R.los_bytes += size; R.los_objects++; }
    else R.heap.used += size;
    int lo_alive = d == DEATH_INF || d >= R.k + 1;
    for (unsigned c = 0; c <= cls; c++) { R.acc_all[c] += size; if (lo_alive) R.acc_lo[c] += size; }
}
static void advance_sample(void) {   /* the cursor reaches sample k+1 */
    R.k++;
    memset(R.acc_all, 0, sizeof R.acc_all); memset(R.acc_lo, 0, sizeof R.acc_lo);
}

/* old space of the nursery models: promoted objects, exact liveness by death sample */
static void old_dies(uint32_t k) {   /* objects with death k-1 are dead at sample k */
    if (k == 0) return;
    for (unsigned c = 0; c < NCLS; c++) R.old_live[c] -= R.old_by_death[c][k - 1];
}
static void old_promote(size_t size, uint32_t d) {
    unsigned cls = cls_of(size);
    if (d == DEATH_INF) d = nsamples + 1;
    if (collector == C_STICKY) { R.marked_minor += size; R.old_total += size; }
    else {
        if (size > R.heap.size - R.heap.used) {
            uint64_t live[NCLS]; for (unsigned c = 0; c < NCLS; c++) live[c] = R.old_live[c];
            size_t before = R.heap.copied; vm_gc(&R.heap, size, live);
            R.copied_major += R.heap.copied - before; R.majors = R.heap.count;
        }
        R.heap.used += size; R.copied_minor += size;
    }
    R.promoted += size;
    for (unsigned c = 0; c <= cls; c++) { R.old_live[c] += size; R.old_by_death[c][d] += size; }
}
static int survives(uint32_t d, uint32_t k) { return d == DEATH_INF || d >= k; }
static void minor_at(uint32_t k, uint32_t id) {
    uint64_t surv = 0;
    size_t bx = R.bx_cycle_start, bx_end = bx;
    while (bx_end < nsboxes && sboxes[bx_end].id < id) bx_end++;
    if (promote == 2) {
        /* age 1: survivors of the previous minor, born in [prev_start, cycle_start) */
        size_t pb = R.bx_cycle_start; while (pb > 0 && sboxes[pb - 1].id >= R.prev_start_id) pb--;
        for (uint32_t i = R.prev_start_id; i < R.cycle_start_id; i++) {
            if (!survives(death[i], R.cycle_start_k)) continue;
            if (survives(death[i], k)) { old_promote(size_L[i], death[i]); if (box_bytes[i]) old_promote(box_bytes[i], death[i]); }
        }
        for (size_t b = pb; b < R.bx_cycle_start; b++) if (survives(sboxes[b].d, R.cycle_start_k) && survives(sboxes[b].d, k)) old_promote(sboxes[b].size, sboxes[b].d);
    }
    for (uint32_t i = R.cycle_start_id; i < id; i++) {
        if (!survives(death[i], k)) continue;
        uint64_t s = size_L[i] + box_bytes[i];
        surv += s;
        R.minor_surv_cls[cls_of(size_L[i])] += size_L[i];
        if (promote == 1) { old_promote(size_L[i], death[i]); if (box_bytes[i]) old_promote(box_bytes[i], death[i]); }
        else if (collector != C_STICKY) R.copied_minor += s;
        else R.marked_minor += s;
    }
    for (size_t b = bx; b < bx_end; b++) {
        if (!survives(sboxes[b].d, k)) continue;
        surv += sboxes[b].size;
        if (promote == 1) old_promote(sboxes[b].size, sboxes[b].d);
        else if (collector != C_STICKY) R.copied_minor += sboxes[b].size;
        else R.marked_minor += sboxes[b].size;
    }
    R.surv_first += surv; if (surv > R.max_cycle_surv) R.max_cycle_surv = surv;
    R.minors++;
    if (collector == C_STICKY) {
        if (R.old_total + nursery > R.sticky_size) {
            R.marked_major += R.old_live[0]; R.sweep_bytes += R.sticky_size; R.majors++;
            R.old_total = R.old_live[0];
            R.sticky_size = grown(R.sticky_size, R.old_total, nursery);
        }
        if (R.sticky_size > R.sticky_max) R.sticky_max = R.sticky_size;
    }
    /* the remembered set of the cycle that ends */
    if (R.rem_entries.n > R.rem_max_entries) R.rem_max_entries = R.rem_entries.n;
    if (R.rem_cards.n > R.rem_max_cards) R.rem_max_cards = R.rem_cards.n;
    R.rem_total_entries += R.rem_entries.n; R.rem_total_cards += R.rem_cards.n;
    hm_clear(&R.rem_entries); hm_clear(&R.rem_cards);
    R.prev_start_id = R.cycle_start_id; R.cycle_start_id = id; R.cycle_start_k = k; R.bx_cycle_start = bx_end;
}
static void nursery_store(const StoreRec *s) {
    if (s->src == 0 || s->src > N) return;
    uint32_t old_bound = promote == 2 ? R.prev_start_id : R.cycle_start_id;
    if (s->src >= old_bound) return;                      /* a young source: no barrier entry */
    unsigned site = s->site < 3 ? s->site : 2;
    if (site == 0) setenv_old_src++;
    if (s->dst == 0 || s->dst < old_bound) return;        /* not a young pointer */
    oy_by_site[site]++;
    if (collector == C_MUTSEG && site == 0) return;       /* no barrier on closures */
    LayoutParams p = layout_params(L, V);
    uint64_t addr = (uint64_t)clock16_L[s->src] * 16 + p.header + (uint64_t)s->field * p.width;
    *hm_find(&R.rem_entries, ((uint64_t)s->src << 16) | s->field, 1) = 1;
    *hm_find(&R.rem_cards, addr / 512, 1) = 1;
}

static void run(void) {
    memset(&R, 0, sizeof R);
    heap_init(&R.heap, heap_size0);
    R.cycle_start_id = R.prev_start_id = 1;
    if (collector == C_LOS) { R.heap.los_cls = cls_of(los_t); R.los_budget = heap_size0; }
    int nurserylike = collector == C_NURSERY || collector == C_STICKY || collector == C_MUTSEG;
    StoreReader sr; StoreRec st; int have = 0;
    if (nurserylike) {
        for (unsigned c = 0; c < NCLS; c++) R.old_by_death[c] = xcalloc(nsamples + 3, 8);
        hm_init(&R.rem_entries, 1 << 12); hm_init(&R.rem_cards, 1 << 12);
        R.sticky_size = grown(heap_size0, 0, nursery); R.sticky_max = R.sticky_size;
        if (no_stores) sr.f = NULL; else { sr_open(&sr); have = sr_next(&sr, &st); }
    }
    uint64_t clock0 = 0, last_minor_clockL = 0; size_t bx = 0;
    for (uint32_t id = 1; id <= N; id++) {
        while (R.k < nsamples && sample_id[R.k + 1] == id) {
            advance_sample();
            if (nurserylike) {
                old_dies(R.k);
                if (sample_clockL[R.k] - last_minor_clockL >= nursery) { minor_at(R.k, id); last_minor_clockL = sample_clockL[R.k]; }
            }
        }
        if (nurserylike) while (have && (uint64_t)st.clock16 <= clock0 / 16) { nursery_store(&st); have = sr_next(&sr, &st); }
        cur_clock0 = clock0;
        while (bx < nsboxes && sboxes[bx].id == id) {
            if (nurserylike) R.nursery_alloc += sboxes[bx].size; else copier_alloc(sboxes[bx].size, sboxes[bx].d);
            bx++;
        }
        if (box_bytes[id]) {
            if (nurserylike) R.nursery_alloc += box_bytes[id];
            else for (uint32_t b = 0; b < box_bytes[id] / box_size; b++) copier_alloc(box_size, death[id]);
        }
        if (nurserylike) R.nursery_alloc += size_L[id]; else copier_alloc(size_L[id], death[id]);
        clock0 += l0_obj_size(alloc_rec[id].kind, alloc_rec[id].len);
    }
    if (nurserylike) { while (have) { nursery_store(&st); have = sr_next(&sr, &st); } sr_close(&sr); }
}

/* ---- census.txt histograms for --real-level call/result ---- */
static int tag_of(const char *t) {
    static const char *n[] = { "UNIT", "INT", "WORD", "REAL", "CHAR", "CON0", "PTR" };
    for (int i = 0; i < 7; i++) if (!strcmp(t, n[i])) return i;
    return -1;
}
static unsigned bc_of_bits(unsigned b) { return b <= 8 ? BC_8 : b <= 31 ? BC_31 : b <= 48 ? BC_48 : b <= 51 ? BC_51 : b <= 62 ? BC_62 : b <= 63 ? BC_63 : BC_64; }
static void hist_value(unsigned tag, unsigned bc, int poly, uint64_t n) {
    int r = layout_needs_box(L, V, (uint8_t)tag, (uint8_t)bc, poly);
    if (r == 2) unrepresentable += n;
    else if (r == 1) { hist_boxes += n; hist_box_bytes += n * box_size; boxes_by_tag[tag] += n; box_bytes_by_tag[tag] += n * box_size; }
}
static void census_hist(void) {
    if (real_level == 0 || L == L0) return;
    char p[4096]; snprintf(p, sizeof p, "%s/census.txt", trace_dir);
    FILE *f = fopen(p, "r"); if (!f) { fprintf(stderr, "sim: warning: no census.txt for --real-level\n"); return; }
    char line[8192]; int section = 0;   /* 1 = prim results, 2 = calls */
    while (fgets(line, sizeof line, f)) {
        if (!strncmp(line, "## prim results", 15)) { section = 1; continue; }
        if (!strncmp(line, "## calls", 8)) { section = 2; continue; }
        if (line[0] == '#') { section = 0; continue; }
        if (section == 1 && real_level == 2) {
            char name[64], tagname[16]; int off;
            if (sscanf(line, "%63s %15s %n", name, tagname, &off) < 2) continue;
            int tag = tag_of(tagname); if (tag != LT_INT && tag != LT_WORD && tag != LT_REAL) continue;
            const char *bar = strchr(line, '|'); if (!bar) continue;
            /* a primitive's result has no source rep: polymorphic under L4-mono only when the prim is generic; taken as monomorphic */
            for (const char *q = bar + 1; ; ) {
                unsigned b; unsigned long long n; int used;
                if (sscanf(q, " %u:%llu%n", &b, &n, &used) != 2) break;
                hist_value((unsigned)tag, tag == LT_REAL ? (b ? BC_REAL_BOXED : 0) : bc_of_bits(b), 0, n);
                q += used;
            }
        } else if (section == 2 && real_level == 1) {
            char op[16], tagname[16], rep[16]; int off;
            if (sscanf(line, "%15s %15s %15s %n", op, tagname, rep, &off) < 3) continue;
            if (!strcmp(tagname, "total")) continue;
            int tag = tag_of(tagname); if (tag != LT_INT && tag != LT_WORD && tag != LT_REAL) continue;
            int poly = !strcmp(rep, "ANY") || !strcmp(rep, "unknown");
            if (tag == LT_REAL) {
                unsigned long long enc, boxed;
                if (sscanf(line + off, "%*s enc %llu boxed %llu", &enc, &boxed) != 2) continue;
                hist_value(LT_REAL, 0, poly, enc); hist_value(LT_REAL, BC_REAL_BOXED, poly, boxed);
            } else {
                unsigned long long c[6];
                if (sscanf(line + off, "%llu %llu %llu %llu %llu %llu", &c[0], &c[1], &c[2], &c[3], &c[4], &c[5]) != 6) continue;
                /* count, >31, >48, >51, >62, >63 */
                hist_value((unsigned)tag, BC_31, poly, c[0] - c[1]); hist_value((unsigned)tag, BC_48, poly, c[1] - c[2]);
                hist_value((unsigned)tag, BC_51, poly, c[2] - c[3]); hist_value((unsigned)tag, BC_62, poly, c[3] - c[4]);
                hist_value((unsigned)tag, BC_63, poly, c[4] - c[5]); hist_value((unsigned)tag, BC_64, poly, c[5]);
            }
        }
    }
    fclose(f);
}

/* ---- --no-stores: store-level boxes and the pointer-store counts from census.txt ---- */
static uint64_t census_ptr_stores, census_oy_stores;
static void census_stores(void) {
    char p[4096]; snprintf(p, sizeof p, "%s/census.txt", trace_dir);
    FILE *f = fopen(p, "r"); if (!f) { fprintf(stderr, "sim: warning: --no-stores and no census.txt\n"); return; }
    char line[8192]; int section = 0; uint64_t real_enc = 0, real_boxed = 0, real_stores = 0;
    static const char *sites[] = { "SETENV", "ref_set", "array_update" };
    while (fgets(line, sizeof line, f)) {
        unsigned long long a, b, c;
        if (!strncmp(line, "## stores:", 10)) {
            char *q = strstr(line, "new value a pointer "); if (q) census_ptr_stores = strtoull(q + 20, 0, 10);
            q = strstr(line, "old->young ("); if (q) { q = strchr(q, ')'); if (q) census_oy_stores = strtoull(q + 1, 0, 10); }
            continue;
        }
        if (!strncmp(line, "## by site x new tag x age", 26)) { section = 1; continue; }
        if (!strncmp(line, "## reals:", 9)) { section = 2; continue; }
        if (line[0] == '#') { section = 0; continue; }
        if (section == 1) {
            char site[32], tagname[16], sa[16], da[16];
            if (sscanf(line, "%31s %15s %15s %15s %llu", site, tagname, sa, da, &a) != 5) continue;
            int si = -1; for (int i = 0; i < 3; i++) if (!strcmp(site, sites[i])) si = i;
            if (si < 0) continue;
            stores_by_site[si] += a;
            int tag = tag_of(tagname);
            if (tag == LT_REAL) real_stores += a;
            else if ((tag == LT_INT || tag == LT_WORD) && L != L0) {
                /* no bits class in the census's table: taken as small; under L4-uniform a REF/ARRAY store is boxed */
                int r = layout_needs_box(L, V, (uint8_t)tag, BC_31, (V & LV_L4UNIFORM) && si != 0);
                if (r == 1) { boxes_by_tag[tag] += a; box_bytes_by_tag[tag] += a * box_size; }
            }
        } else if (section == 2) {
            if (sscanf(line, "stored later %llu %llu %llu", &a, &b, &c) == 3) { real_enc = b; real_boxed = c; }   /* total enc boxed zeros share */
        }
    }
    fclose(f);
    if (L != L0 && real_stores) {
        /* the reals row splits stored reals by value-encodability; the table by site gives their total */
        uint64_t enc = real_enc + real_boxed ? real_stores * real_enc / (real_enc + real_boxed) : real_stores, boxed = real_stores - enc;
        int poly_uniform = (V & LV_L4UNIFORM) != 0;
        uint64_t n = 0;
        if (layout_needs_box(L, V, LT_REAL, 0, poly_uniform) == 1) n += enc;
        if (layout_needs_box(L, V, LT_REAL, BC_REAL_BOXED, poly_uniform) == 1) n += boxed;
        boxes_by_tag[LT_REAL] += n; box_bytes_by_tag[LT_REAL] += n * box_size;
    }
}

/* ---- output ---- */
static const char *cols =
    "workload\tlayout\tvariant\tcollector\tparams\tband\tobjects\tbytes_L0\tbytes_allocated\textra_boxes\textra_box_bytes\t"
    "boxes_int\tboxes_word\tboxes_real\tbox_bytes_int\tbox_bytes_word\tbox_bytes_real\tunrepresentable\thist_boxes\t"
    "bytes_copied\tbytes_copied_minor\tbytes_copied_major\tbytes_marked_minor\tbytes_marked_major\tsweep_bytes\t"
    "collections_minor\tcollections_major\tmax_heap\tmax_semispace\tfinal_semispace\tfinal_live\t"
    "max_remset_entries\tmax_remset_cards\tremset_entries_total\tremset_cards_total\t"
    "oy_setenv\toy_ref\toy_array\tsetenv_old_src\tstores_setenv\tstores_ref\tstores_array\t"
    "survival_fraction\tpromoted_fraction\tmax_cycle_survivors\tnursery_effective\t"
    "los_bytes\tlos_objects\tlos_live_max\tlos_copied_2k\tlos_copied_8k\tlos_copied_32k\t"
    "samples\tband_width_pct\tcompact_objects\tpair_objects\treal_level\tmax_live\tstores_mode";

static void usage(void) {
    fprintf(stderr, "usage: sim --trace DIR --layout L0..L4 [--variant F,F] --collector copier|nursery|sticky|los|mutseg\n"
                    "           [--heap-size N] [--heap-fill P] [--nursery N] [--promote 1|2] [--los T] --band lo|hi\n"
                    "           [--real-level store|call|result] [--workload NAME] [--header] [--check]\n");
    exit(2);
}
static size_t size_arg(const char *s) {
    char *e; unsigned long long v = strtoull(s, &e, 0);
    if (*e == 'K' || *e == 'k') v <<= 10; else if (*e == 'M' || *e == 'm') v <<= 20; else if (*e == 'G' || *e == 'g') v <<= 30; else if (*e) usage();
    return (size_t)v;
}
static const struct { const char *name; unsigned flag; } vnames[] = {
    { "HDR4", LV_HDR4 }, { "ALIGN16", LV_ALIGN16 }, { "COMPACT", LV_COMPACT }, { "MUTSEG", LV_MUTSEG }, { "PAIRS", LV_PAIRS },
    { "REALIMM", LV_REALIMM }, { "L4UNIFORM", LV_L4UNIFORM }, { "NAN51", LV_NAN51 } };
static void parse_variant(const char *s) {
    char buf[256]; snprintf(buf, sizeof buf, "%s", s);
    for (char *t = strtok(buf, ",+"); t; t = strtok(NULL, ",+")) {
        int ok = 0;
        for (size_t i = 0; i < sizeof vnames / sizeof *vnames; i++) if (!strcasecmp(t, vnames[i].name)) { V |= vnames[i].flag; ok = 1; }
        if (!ok) { fprintf(stderr, "sim: unknown variant %s\n", t); usage(); }
    }
    snprintf(variant_str, sizeof variant_str, "%s", s);
}

int main(int argc, char **argv) {
    int header = 0;
    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (!strcmp(a, "--header")) header = 1;
        else if (!strcmp(a, "--check")) do_check = 1;
        else if (!strcmp(a, "--gc-trace")) gc_trace = 1;
        else if (!strcmp(a, "--no-stores")) no_stores = 1;
        else if (!strcmp(a, "--probe") && i + 1 < argc) { char *t = strtok(argv[++i], ","); while (t && nprobes < 64) { probes[nprobes++] = strtoull(t, 0, 0); t = strtok(NULL, ","); } }
        else if (i + 1 >= argc) usage();
        else if (!strcmp(a, "--trace")) trace_dir = argv[++i];
        else if (!strcmp(a, "--workload")) workload = argv[++i];
        else if (!strcmp(a, "--layout")) { const char *l = argv[++i]; if (l[0] != 'L' || l[1] < '0' || l[1] > '4' || l[2]) usage(); L = (enum Layout)(l[1] - '0'); }
        else if (!strcmp(a, "--variant")) parse_variant(argv[++i]);
        else if (!strcmp(a, "--collector")) {
            const char *c = argv[++i]; collector_name = c;
            if (!strcmp(c, "copier")) collector = C_COPIER; else if (!strcmp(c, "nursery")) collector = C_NURSERY;
            else if (!strcmp(c, "sticky")) collector = C_STICKY; else if (!strcmp(c, "los")) collector = C_LOS;
            else if (!strcmp(c, "mutseg")) collector = C_MUTSEG; else usage();
        }
        else if (!strcmp(a, "--heap-size")) { heap_size0 = size_arg(argv[++i]); if (heap_size0 < 4096) heap_size0 = 4096; }
        else if (!strcmp(a, "--heap-fill")) { heap_fill = (unsigned)strtoul(argv[++i], 0, 0); if (heap_fill < 1 || heap_fill > 100) usage(); }
        else if (!strcmp(a, "--nursery")) nursery = size_arg(argv[++i]);
        else if (!strcmp(a, "--promote")) { promote = atoi(argv[++i]); if (promote != 1 && promote != 2) usage(); }
        else if (!strcmp(a, "--los")) los_t = size_arg(argv[++i]);
        else if (!strcmp(a, "--band")) { const char *b = argv[++i]; if (!strcmp(b, "lo")) band_hi = 0; else if (!strcmp(b, "hi")) band_hi = 1; else usage(); }
        else if (!strcmp(a, "--real-level")) { const char *r = argv[++i]; real_level = !strcmp(r, "store") ? 0 : !strcmp(r, "call") ? 1 : !strcmp(r, "result") ? 2 : -1; if (real_level < 0) usage(); }
        else usage();
    }
    if (header) { puts(cols); if (!trace_dir) return 0; }
    if (!trace_dir) usage();
    if (collector == C_LOS) { if (!los_t) los_t = 8192; if (los_t != 2048 && los_t != 8192 && los_t != 32768) die("--los must be 2K, 8K or 32K"); }
    if (!workload) { const char *s = strrchr(trace_dir, '/'); workload = s && s[1] ? s + 1 : trace_dir; }
    if (L == L0 && V) die("variants apply to L1-L4 only (L0 is exact today's layout)");
    box_size = layout_box_size(L, V);

    size_t len;
    alloc_rec = map_file("alloc.bin", &len); if (len % 16 || len < 32) die("alloc.bin: bad size"); N = (uint32_t)(len / 16 - 1);
    fields = map_file("fields.bin", &fields_bytes);
    death = map_file("death.bin", &len); if (len < ((size_t)N + 1) * 4) die("death.bin too short");
    {   /* docs/census.md: sample k = record k (record 0 a placeholder). The census
           VM writes record k-1 for sample k (no placeholder; death.bin's k
           means "alive at record k-1", verified against live_bytes of every
           record). A record 0 that is all zero means the former. */
        SampleRec *recs = map_file("samples.bin", &len); if (len % 24) die("samples.bin: bad size");
        uint32_t nrec = (uint32_t)(len / 24);
        int zero_based = nrec > 0 && !(recs[0].clock == 0 && recs[0].live_bytes == 0 && recs[0].live_objs == 0);
        nsamples = zero_based ? nrec : (nrec ? nrec - 1 : 0);
        samples = xcalloc(nsamples + 2, sizeof *samples);
        for (uint32_t k = 1; k <= nsamples; k++) samples[k] = recs[zero_based ? k - 1 : k];
        samples_zero_based = zero_based;
    }
    if (alloc_rec[0].kind != 0) fprintf(stderr, "sim: warning: alloc.bin record 0 is not empty (kind %u)\n", alloc_rec[0].kind);
    for (uint32_t k = 2; k <= nsamples; k++) if (samples[k].clock < samples[k - 1].clock) die("samples.bin not monotone");
    objects_total = N;

    sample_id = xcalloc(nsamples + 2, 4); sample_clockL = xcalloc(nsamples + 2, 8);
    size_L = xcalloc((size_t)N + 1, 4); box_bytes = xcalloc((size_t)N + 1, 4); clock16_L = xcalloc((size_t)N + 1, 4); homog = xcalloc((size_t)N + 1, 1);
    pass1();
    pass2();
    census_hist();
    if (no_stores) census_stores();

    if (do_check) {
        /* the reading of death.bin/samples.bin against the census's own survivor counts (L0, no boxes) */
        uint64_t bad = 0, maxdiff = 0;
        for (uint32_t k = 1; k <= nsamples; k++) {
            uint64_t s = Sge[0][k]; uint64_t d = s > samples[k].live_bytes ? s - samples[k].live_bytes : samples[k].live_bytes - s;
            if (d) { bad++; if (d > maxdiff) maxdiff = d; if (bad <= 5) fprintf(stderr, "check: sample %u clock %" PRIu64 " live %" PRIu64 " (census) vs %" PRIu64 " (death.bin+sizes)\n", k, samples[k].clock, samples[k].live_bytes, s); }
        }
        uint64_t alive_exit = Sge[0][nsamples + 1];
        printf("check %s: objects %u bytes_L0 %" PRIu64 " samples %u mismatching_samples %" PRIu64 " max_diff %" PRIu64 " alive_at_exit %" PRIu64 " stores %" PRIu64 " last_sample_clock %" PRIu64 "\n",
               workload, N, bytes_L0, nsamples, bad, maxdiff, alive_exit, stores_by_site[0] + stores_by_site[1] + stores_by_site[2], nsamples ? samples[nsamples].clock : 0);
        return bad ? 1 : 0;
    }

    run();

    char params[128];
    if (collector == C_COPIER) snprintf(params, sizeof params, "heap=%zu,fill=%u", heap_size0, heap_fill);
    else if (collector == C_LOS) snprintf(params, sizeof params, "heap=%zu,fill=%u,los=%zu", heap_size0, heap_fill, los_t);
    else if (collector == C_STICKY) snprintf(params, sizeof params, "nursery=%zu,heap=%zu,fill=%u", nursery, heap_size0, heap_fill);
    else snprintf(params, sizeof params, "nursery=%zu,promote=%d,heap=%zu,fill=%u", nursery, promote, heap_size0, heap_fill);
    uint64_t extra_boxes = boxes_by_tag[LT_INT] + boxes_by_tag[LT_WORD] + boxes_by_tag[LT_REAL];
    uint64_t extra_box_bytes = box_bytes_by_tag[LT_INT] + box_bytes_by_tag[LT_WORD] + box_bytes_by_tag[LT_REAL];
    int nurserylike = collector == C_NURSERY || collector == C_STICKY || collector == C_MUTSEG;
    uint64_t cminor = nurserylike ? R.copied_minor : 0, cmajor = nurserylike ? R.copied_major : R.heap.copied;
    uint64_t coll_minor = nurserylike ? R.minors : 0, coll_major = nurserylike ? R.majors : R.heap.count;
    size_t max_heap, final_semi, final_live;
    if (collector == C_STICKY) { max_heap = R.sticky_max; final_semi = R.sticky_size; final_live = R.old_total + (R.nursery_alloc - (sample_clockL[R.cycle_start_k])); }
    else if (nurserylike) { max_heap = nursery + (promote == 2 ? R.max_cycle_surv : 0) + R.heap.max_footprint; final_semi = R.heap.size; final_live = R.heap.used + (bytes_alloc - sample_clockL[R.cycle_start_k]); }
    else { max_heap = R.heap.max_footprint + (collector == C_LOS ? R.los_live_max : 0); final_semi = R.heap.size; final_live = R.heap.used; }
    double surv = R.nursery_alloc ? (double)R.surv_first / (double)R.nursery_alloc : 0, prom = R.nursery_alloc ? (double)R.promoted / (double)R.nursery_alloc : 0;
    double bw = R.band_lo_sum ? 100.0 * (double)(R.band_hi_sum - R.band_lo_sum) / (double)R.band_lo_sum : 0;
    uint64_t los2 = nurserylike ? R.minor_surv_cls[1] + R.old_by_death[1][0] : R.heap.copied_cls[1];   /* placeholder replaced below */
    (void)los2;
    uint64_t losc[NCLS];
    for (unsigned c = 1; c < NCLS; c++) {
        if (nurserylike) {
            uint64_t minor = 0; for (unsigned cc = c; cc < NCLS; cc++) minor += R.minor_surv_cls[cc];
            losc[c] = minor + R.heap.copied_cls[c];
        } else losc[c] = R.heap.copied_cls[c];
    }
    printf("%s\t%s\t%s\t%s\t%s\t%s\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t"
           "%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t"
           "%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t"
           "%" PRIu64 "\t%" PRIu64 "\t%zu\t%zu\t%zu\t%zu\t"
           "%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t"
           "%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t"
           "%.4f\t%.4f\t%" PRIu64 "\t%" PRIu64 "\t"
           "%" PRIu64 "\t%" PRIu64 "\t%zu\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t"
           "%u\t%.3f\t%" PRIu64 "\t%" PRIu64 "\t%s\t%zu\t%s\n",
           workload, layout_name(L), variant_str, collector_name, params, band_hi ? "hi" : "lo", objects_total, bytes_L0, bytes_alloc + hist_box_bytes, extra_boxes, extra_box_bytes,
           boxes_by_tag[LT_INT], boxes_by_tag[LT_WORD], boxes_by_tag[LT_REAL], box_bytes_by_tag[LT_INT], box_bytes_by_tag[LT_WORD], box_bytes_by_tag[LT_REAL], unrepresentable, hist_boxes,
           cminor + cmajor, cminor, cmajor, R.marked_minor, R.marked_major, R.sweep_bytes,
           coll_minor, coll_major, max_heap, R.heap.max_size, final_semi, final_live,
           R.rem_max_entries, R.rem_max_cards, R.rem_total_entries, R.rem_total_cards,
           oy_by_site[0], oy_by_site[1], oy_by_site[2], setenv_old_src, stores_by_site[0], stores_by_site[1], stores_by_site[2],
           surv, prom, R.max_cycle_surv, R.minors ? R.nursery_alloc / R.minors : 0,
           R.los_bytes, R.los_objects, R.los_live_max, losc[1], losc[2], losc[3],
           nsamples, bw, compact_objs, pair_objs, real_level == 0 ? "store" : real_level == 1 ? "call" : "result", R.heap.max_live, no_stores ? "census-only" : "file");
    return 0;
}
