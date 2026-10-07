/* h3.c -- H3 and H4: the mark bit in the header against a side bitmap,
   what clearing the marks costs per cycle, and the sweep: object by
   object, by the bitmap, by Immix's line marks, by a bitmap per pool of
   one size; then lazy sweeping into allocation against an eager sweep.

   The heap: N objects of SIZE bytes side by side (value.h's header), a
   share LIVE of them marked, independently at random (or in runs of 16
   with runs=1), the marks in all three forms (the header's GC_MARK, a bit
   for every 8 bytes, a byte for every 128-byte line with Immix's rule: a
   small object marks the line it starts in and the next line is skipped
   by the hole search), set before the timing. Rows per object of the heap
   (per byte: over SIZE):

   clear-hdr        a walk over every object clearing its header's mark
                    (what a header mark costs when its sense is not flipped)
   clear-bm         memset of the bitmap (heap / 64 bytes)
   clear-lines      memset of the line marks (heap / 128 bytes)
   sweep-hdr        every header read; a run of dead objects becomes one
                    free block (a header and a link written), OCaml 4's way
   sweep-bm         the bitmap's set bits walked; only the live objects'
                    headers read (for their size); the gaps become free blocks
   sweep-lines      the line marks of every 32 KiB block: holes counted,
                    blocks classified (free, recyclable, full); nothing written
   sweep-pool       pools of 32 KiB of one size: popcount of the pool's
                    bitmap words, the pool classified; nothing written
   sweep-pool-list  the same, then a free list threaded through the dead
                    slots (OCaml 5's sweep)
   alloc-eager      sweep-pool-list over the whole heap, then every free
                    slot allocated (a header written): per object allocated
   alloc-lazy       pool by pool: its free list built, then its slots
                    allocated at once (lazy sweeping, Boehm's; the pool is
                    in cache when it is allocated into)
   alloc-bm         pool by pool, allocation straight from the bitmap
                    (tzcnt over the inverted words), no list

   check=1: the sweeps by headers and by the bitmap free the same bytes, the
   dead ones; the pool sweep threads, and every allocation finds, one slot
   for every dead object; clear-hdr leaves no mark; a repetition is one
   round.

   gcbench h3 [heap=1M,128M] [size=16,32,64] [live=0.1,0.5,0.9] [runs=0] [reps=5] */
#include "gcb.h"

#define H3_POOL 32768
#define H3_LINE 128

typedef struct {
    char *base; size_t n, osz, bytes;
    uint64_t *bits;           /* a bit for every 8 bytes */
    uint8_t *lines;           /* a byte for every line */
    uint64_t *pbits;          /* per pool: a bit for every slot */
    size_t slots_per_pool, pool_words, npools;
    uint8_t *live;            /* the plan */
    size_t nlive;
} h3_heap;

static void h3_build(h3_heap *h, size_t bytes, size_t osz, double live, int runs) {
    memset(h, 0, sizeof *h);
    h->osz = osz;
    h->slots_per_pool = H3_POOL / osz;
    h->npools = bytes / H3_POOL;
    h->n = h->npools * h->slots_per_pool;
    h->bytes = h->npools * H3_POOL;
    h->base = region(h->bytes, MAP_TOUCH);
    h->bits = region(rup(h->bytes / 64 + 64, 4096), MAP_TOUCH);
    h->lines = region(rup(h->bytes / H3_LINE + 64, 4096), MAP_TOUCH);
    h->pool_words = (h->slots_per_pool + 63) / 64;
    h->pbits = region(rup(h->npools * h->pool_words * 8 + 64, 4096), MAP_TOUCH);
    h->live = malloc(h->n);
    uint64_t seed = 0xABCDEFULL ^ (uint64_t)(live * 1000) ^ osz;
    for (size_t i = 0; i < h->n; i += runs ? 16 : 1) {
        uint8_t l = rnd_unit(&seed) < live;
        for (size_t j = i; j < h->n && j < i + (runs ? 16 : 1); j++) { h->live[j] = l; h->nlive += l; }
    }
}
/* the objects written and marked in every form (outside the timing) */
static void h3_reset(h3_heap *h) {
    memset(h->bits, 0, h->bytes / 64 + 8);
    memset(h->lines, 0, h->bytes / H3_LINE + 8);
    memset(h->pbits, 0, h->npools * h->pool_words * 8);
    uint32_t len = fields_for(h->osz);
    for (size_t p = 0; p < h->npools; p++)
        for (size_t s = 0; s < h->slots_per_pool; s++) {
            size_t i = p * h->slots_per_pool + s;
            char *a = h->base + p * H3_POOL + s * h->osz;
            obj *o = (obj *)a;
            hdr(o, K_TUPLE, 0, len);
            if (h->live[i]) {
                o->kind |= GC_MARK;
                size_t b = (size_t)(a - h->base) >> 3; h->bits[b >> 6] |= (uint64_t)1 << (b & 63);
                h->lines[(size_t)(a - h->base) / H3_LINE] = 1;
                if (h->osz > H3_LINE) for (size_t l = (size_t)(a - h->base) / H3_LINE; l <= (size_t)(a - h->base + h->osz - 1) / H3_LINE; l++) h->lines[l] = 1;
                h->pbits[p * h->pool_words + s / 64] |= (uint64_t)1 << (s % 64);
            }
        }
    /* the tail of each pool past the last slot is not an object: make it a free block */
    size_t tail = H3_POOL - h->slots_per_pool * h->osz;
    if (tail >= 8) for (size_t p = 0; p < h->npools; p++) { obj *o = (obj *)(h->base + p * H3_POOL + h->slots_per_pool * h->osz); o->kind = K_FREE; o->pad = 0; o->contag = 0; o->len = (uint32_t)tail; }
}
static size_t h3_sz(const obj *o) { return okind(o) == K_FREE ? o->len : osize(o); }

static uint64_t h3_sink;
static size_t h3_freed;   /* what the last sweep freed: bytes (sweep-hdr, sweep-bm) or slots (sweep-pool-list) */
static NOINLINE void clear_hdr(h3_heap *h) {
    for (char *p = h->base, *e = h->base + h->bytes; p < e; ) { obj *o = (obj *)p; o->kind &= (uint8_t)~GC_MARK; p += h3_sz(o); }
}
static NOINLINE void sweep_hdr(h3_heap *h) {
    char *freelist = NULL; size_t nfree = 0, fbytes = 0;
    char *p = h->base, *e = h->base + h->bytes;
    while (p < e) {
        obj *o = (obj *)p;
        if (o->kind & GC_MARK) { p += h3_sz(o); continue; }
        char *q = p + h3_sz(o);
        while (q < e && !(((obj *)q)->kind & GC_MARK)) q += h3_sz((obj *)q);
        obj *f = (obj *)p; f->kind = K_FREE; f->len = (uint32_t)(q - p);
        /* a block of 16 bytes or more goes on the list; an 8-byte one (a
           pool's tail) has no room for the link and is left for the next sweep */
        if (q - p >= 16) { *(char **)FIELDS(f) = freelist; freelist = p; nfree++; }
        fbytes += (size_t)(q - p);
        p = q;
    }
    h3_sink += nfree + fbytes;
    h3_freed = fbytes;
}
static NOINLINE void sweep_bm(h3_heap *h) {
    char *freelist = NULL; size_t nfree = 0, fbytes = 0;
    char *prev_end = h->base;
    size_t words = h->bytes / 512;
    for (size_t w = 0; w < words; w++) {
        uint64_t x = h->bits[w];
        while (x) {
            unsigned b = (unsigned)__builtin_ctzll(x); x &= x - 1;
            char *a = h->base + ((w * 64 + b) << 3);
            if (a > prev_end) {   /* the gap a free block, on the list if it has room for the link */
                obj *f = (obj *)prev_end; f->kind = K_FREE; f->len = (uint32_t)(a - prev_end);
                if (a - prev_end >= 16) { *(char **)FIELDS(f) = freelist; freelist = prev_end; nfree++; }
                fbytes += (size_t)(a - prev_end);
            }
            prev_end = a + osize((obj *)a);
        }
    }
    if (prev_end < h->base + h->bytes) { nfree++; fbytes += (size_t)(h->base + h->bytes - prev_end); }
    h3_sink += nfree + fbytes;
    h3_freed = fbytes;
}
static NOINLINE void sweep_lines(h3_heap *h) {
    size_t nl = H3_POOL / H3_LINE, blocks = h->bytes / H3_POOL, holes = 0, freel = 0, nfreeb = 0, nrec = 0;
    for (size_t b = 0; b < blocks; b++) {
        const uint8_t *m = h->lines + b * nl;
        size_t used = 0, l = 0;
        while (l < nl) {
            if (m[l]) { used++; l++; if (l < nl && !m[l]) l++; continue; }   /* the next line implicitly */
            holes++;
            while (l < nl && !m[l]) { freel++; l++; }
        }
        if (!used) nfreeb++; else if (used < nl) nrec++;
    }
    h3_sink += holes + freel + nfreeb + nrec;
}
static NOINLINE void sweep_pool(h3_heap *h, int list) {
    size_t full = 0, empty = 0, partial = 0, nfree = 0;
    for (size_t p = 0; p < h->npools; p++) {
        const uint64_t *w = h->pbits + p * h->pool_words;
        size_t live = 0;
        for (size_t i = 0; i < h->pool_words; i++) live += (size_t)__builtin_popcountll(w[i]);
        if (live == 0) empty++; else if (live == h->slots_per_pool) full++; else partial++;
        if (list && live < h->slots_per_pool) {
            char *fl = NULL, *pb = h->base + p * H3_POOL;
            for (size_t i = 0; i < h->pool_words; i++) {
                uint64_t x = ~w[i];
                if (i == h->pool_words - 1 && h->slots_per_pool % 64) x &= ((uint64_t)1 << (h->slots_per_pool % 64)) - 1;
                while (x) { unsigned b = (unsigned)__builtin_ctzll(x); x &= x - 1; char *s = pb + (i * 64 + b) * h->osz; *(char **)s = fl; fl = s; nfree++; }
            }
            *(char **)(pb + H3_POOL - 8) = fl;   /* the pool's list head, kept in its last word for the allocator */
        }
    }
    h3_sink += full + empty + partial + nfree;
    h3_freed = nfree;
}
/* allocate every free slot of pool P from its list (the head in the pool's last word) */
ALWAYS_INLINE size_t pool_alloc_list(h3_heap *h, size_t p, uint32_t len) {
    char *pb = h->base + p * H3_POOL, *fl = *(char **)(pb + H3_POOL - 8);
    size_t n = 0;
    while (fl) { char *nx = *(char **)fl; hdr((obj *)fl, K_TUPLE, 0, len); fl = nx; n++; }
    return n;
}
static NOINLINE size_t alloc_eager(h3_heap *h) {
    sweep_pool(h, 1);
    size_t n = 0; uint32_t len = fields_for(h->osz);
    for (size_t p = 0; p < h->npools; p++) n += pool_alloc_list(h, p, len);
    return n;
}
static NOINLINE size_t alloc_lazy(h3_heap *h) {
    size_t n = 0; uint32_t len = fields_for(h->osz);
    for (size_t p = 0; p < h->npools; p++) {
        const uint64_t *w = h->pbits + p * h->pool_words;
        char *fl = NULL, *pb = h->base + p * H3_POOL;
        for (size_t i = h->pool_words; i-- > 0; ) {
            uint64_t x = ~w[i];
            if (i == h->pool_words - 1 && h->slots_per_pool % 64) x &= ((uint64_t)1 << (h->slots_per_pool % 64)) - 1;
            while (x) { unsigned b = 63 - (unsigned)__builtin_clzll(x); x &= ~((uint64_t)1 << b); char *s = pb + (i * 64 + b) * h->osz; *(char **)s = fl; fl = s; }
        }
        while (fl) { char *nx = *(char **)fl; hdr((obj *)fl, K_TUPLE, 0, len); fl = nx; n++; }
    }
    return n;
}
static NOINLINE size_t alloc_bm(h3_heap *h) {
    size_t n = 0; uint32_t len = fields_for(h->osz);
    for (size_t p = 0; p < h->npools; p++) {
        const uint64_t *w = h->pbits + p * h->pool_words;
        char *pb = h->base + p * H3_POOL;
        for (size_t i = 0; i < h->pool_words; i++) {
            uint64_t x = ~w[i];
            if (i == h->pool_words - 1 && h->slots_per_pool % 64) x &= ((uint64_t)1 << (h->slots_per_pool % 64)) - 1;
            while (x) { unsigned b = (unsigned)__builtin_ctzll(x); x &= x - 1; hdr((obj *)(pb + (i * 64 + b) * h->osz), K_TUPLE, 0, len); n++; }
        }
    }
    return n;
}

enum { C_CLEAR_HDR, C_CLEAR_BM, C_CLEAR_LINES, C_SWEEP_HDR, C_SWEEP_BM, C_SWEEP_LINES, C_SWEEP_POOL, C_SWEEP_POOL_LIST, C_ALLOC_EAGER, C_ALLOC_LAZY, C_ALLOC_BM, C_N3 };
static const char *h3_names[] = { "clear-hdr", "clear-bm", "clear-lines", "sweep-hdr", "sweep-bm", "sweep-lines", "sweep-pool", "sweep-pool-list", "alloc-eager", "alloc-lazy", "alloc-bm" };

/* check=1: what the last round of case K left (the heap as it left it) */
static void h3_verify(h3_heap *h, int k, size_t nalloc, const char *cas) {
    size_t dead = h->n - h->nlive, dead_bytes = h->bytes - h->nlive * h->osz;
    if ((k == C_SWEEP_HDR || k == C_SWEEP_BM) && h3_freed != dead_bytes)
        gcb_fail("H3 %s: freed %zu bytes, not the %zu dead ones", cas, h3_freed, dead_bytes);
    if (k == C_SWEEP_POOL_LIST && h3_freed != dead) gcb_fail("H3 %s: %zu slots on the free lists, not the %zu dead ones", cas, h3_freed, dead);
    if (k >= C_ALLOC_EAGER && nalloc != dead) gcb_fail("H3 %s: %zu allocations into the %zu dead slots", cas, nalloc, dead);
    if (k == C_CLEAR_HDR)
        for (char *p = h->base, *e = h->base + h->bytes; p < e; p += h3_sz((obj *)p))
            if (((obj *)p)->kind & GC_MARK) { gcb_fail("H3 %s: a mark left", cas); break; }
}

static void exp_h3(void) {
    double heaps[8], sizes[8], lives[8];
    int nh = opt_list("heap", "1M,128M", heaps, 8), ns = opt_list("size", "16,32,64", sizes, 8), nl = opt_list("live", "0.1,0.5,0.9", lives, 8);
    int runs = (int)opt_n("runs", 0), reps = (int)opt_n("reps", 5);
    const char *which = opt_s("what", "clear-hdr,clear-bm,clear-lines,sweep-hdr,sweep-bm,sweep-lines,sweep-pool,sweep-pool-list,alloc-eager,alloc-lazy,alloc-bm");
    for (int a = 0; a < nh; a++)
        for (int b = 0; b < ns; b++)
            for (int c = 0; c < nl; c++) {
                h3_heap h;
                h3_build(&h, (size_t)heaps[a], (size_t)sizes[b], lives[c], runs);
                size_t rounds = (16u << 20) / h.bytes; if (rounds < 1 || gcb_check) rounds = 1;
                size_t nalloc = 0;
                for (int k = 0; k < C_N3; k++) {
                    if (!in_list(which, h3_names[k])) continue;
                    reps_t r; reps_init(&r);
                    h3_freed = 0;
                    for (int rep = 0; rep < reps; rep++) {
                        phase ph; ph_clear(&ph);
                        for (size_t j = 0; j < rounds; j++) {
                            h3_reset(&h);
                            ph_begin(&ph);
                            switch (k) {
                            case C_CLEAR_HDR: clear_hdr(&h); break;
                            case C_CLEAR_BM: memset(h.bits, 0, h.bytes / 64); SINK(h.bits); break;
                            case C_CLEAR_LINES: memset(h.lines, 0, h.bytes / H3_LINE); SINK(h.lines); break;
                            case C_SWEEP_HDR: sweep_hdr(&h); break;
                            case C_SWEEP_BM: sweep_bm(&h); break;
                            case C_SWEEP_LINES: sweep_lines(&h); break;
                            case C_SWEEP_POOL: sweep_pool(&h, 0); break;
                            case C_SWEEP_POOL_LIST: sweep_pool(&h, 1); break;
                            case C_ALLOC_EAGER: nalloc = alloc_eager(&h); break;
                            case C_ALLOC_LAZY: nalloc = alloc_lazy(&h); break;
                            default: nalloc = alloc_bm(&h); break;
                            }
                            ph_end(&ph);
                        }
                        reps_add(&r, &ph.acc);
                    }
                    char cas[128], hb[32];
                    snprintf(cas, sizeof cas, "%s/heap=%s/size=%zu/live=%.2g%s", h3_names[k], human((double)h.bytes, hb), h.osz, lives[c], runs ? "/runs" : "");
                    if (gcb_check) h3_verify(&h, k, nalloc, cas);
                    int per_alloc = k >= C_ALLOC_EAGER;
                    reps_out(&r, "H3", cas, per_alloc ? "alloc" : "obj", (double)(per_alloc ? nalloc : h.n) * (double)rounds);
                }
                region_free(h.base, h.bytes);
                region_free(h.bits, rup(h.bytes / 64 + 64, 4096));
                region_free(h.lines, rup(h.bytes / H3_LINE + 64, 4096));
                region_free(h.pbits, rup(h.npools * h.pool_words * 8 + 64, 4096));
                free(h.live);
            }
}
