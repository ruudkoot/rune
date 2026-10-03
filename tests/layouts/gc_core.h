/* gc_core.h -- the copying collector every layout shares. Included by a
   layout header after it has defined `val`, `struct obj`, HDR_SIZE and
   the lay_* hooks listed here (declared below, defined by the layout
   before or after this include; all static inline).

   The heap is two semispaces of equal size, mmap'd with MAP_POPULATE and
   touched at start so that page faults stay out of the timing. Headered
   objects bump upward from the base (hp_free/hp_limit, plain globals as
   the VM's vm->heap_used). Under -DPAIRS headerless 16-byte pairs live in
   4 KiB pages taken downward from the top (hp_limit moves down): a page
   holds pairs of one SHAPE (which words are pointers; L1 has one shape
   because every word is self-describing, L4 has three), so the Cheney scan
   of to-space can walk the pairs of a page knowing what to forward -- the
   BiBOP idea Chez uses for the same reason (IMPLEMENTATION.md, "Scheme
   Objects"; gc.c sweep_space per space). Forwarding a pair: L1 writes a
   marker word that no L1 value can be (an even, non-canonical address) into
   word 0 and the new address into word 1, as Chez's forward_marker; L4's
   raw words can be any pattern, so it keeps a side bitmap (one bit per 16
   bytes of from-space) and writes the new address into word 0.

   Roots: the shadow stack root_stack[0..root_sp) of vals (L4 adds a raw
   stack that is not scanned). Collection is measured by rdtscp around
   gc_collect (gc_cycles), the mutator gets the rest. */
#ifndef HARNESS_GC_CORE_H
#define HARNESS_GC_CORE_H
#include <sys/mman.h>

#ifndef NSHAPES
#define NSHAPES 1
#endif
#define PAIR_PAGE 4096
#define ROOT_MAX (1u << 22)

/* hooks a layout defines */
static inline size_t lay_obj_size(const obj *o);          /* bytes of a headered object */
static inline int lay_is_forwarded(const obj *o);
static inline obj *lay_forward_of(const obj *o);
static inline void lay_set_forward(obj *o, obj *n);
static inline void lay_scan_obj(obj *o);                   /* gc_forward on every pointer field */
static inline int lay_is_ptr(val v);                       /* a heap pointer, pair or object */
static inline obj *lay_ptr_obj(val v);
static inline val lay_obj_retag(val old, obj *n);
static inline int lay_is_ind(const obj *o);                /* a thunk that has its value: an indirection to it */
static inline val lay_ind_value(const obj *o);
#ifdef PAIRS
static inline int lay_is_pair(val v);
static inline uint64_t *lay_pair_addr(val v);
static inline int lay_pair_shape(val v);
static inline val lay_pair_retag(val old, uint64_t *n);
static inline void lay_scan_pair(int shape, uint64_t *p);
#endif

/* ---- the mutator's hot state (globals, as vm->heap_from/heap_used) ---- */
static char *hp_free, *hp_limit;
#ifdef PAIRS
static char *pp_free[NSHAPES], *pp_end[NSHAPES];
#endif

struct space {
    char *base; size_t size;
    char *free, *page_top;
#ifdef PAIRS
    char *pp_free[NSHAPES], *pp_end[NSHAPES];
    int pp_page[NSHAPES], pg_first[NSHAPES];
    int32_t *pg_next; uint8_t *pg_shape;
#endif
};
static struct space sp_a, sp_b, *sp_cur = &sp_a, *sp_oth = &sp_b;

static val root_stack_mem[ROOT_MAX];
static val *root_sp = root_stack_mem;
#define PROOT_PUSH(v) (*root_sp++ = (v), root_sp - 1)
#define ROOT_POP() (--root_sp)
#define ROOT_MARK_T val *
#define ROOT_MARK() (root_sp)
#define ROOT_RESET(m) (root_sp = (m))

static uint64_t gc_cycles, gc_count, gc_bytes_copied;
static uint64_t gc_ind_skipped, gc_ind_bytes;   /* indirections a collection took out, by reference, and their bytes */
static char *gc_old_limit;                      /* what is below it survived a collection: old, to a generational eye */
static size_t heap_semispace;

static inline size_t round_up(size_t x, size_t a) { return (x + a - 1) & ~(a - 1); }

static void *map_touched(size_t bytes) {
    void *p = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE, -1, 0);
    if (p == MAP_FAILED) die("mmap failed");
    for (size_t i = 0; i < bytes; i += 4096) ((volatile char *)p)[i] = 0;
    return p;
}

static void space_init(struct space *s, size_t bytes) {
    s->base = map_touched(bytes);
    s->size = bytes;
    s->free = s->base;
    s->page_top = s->base + bytes;
#ifdef PAIRS
    size_t npages = bytes / PAIR_PAGE;
    s->pg_next = malloc(npages * sizeof(int32_t));
    s->pg_shape = malloc(npages);
    memset(s->pg_next, 0, npages * sizeof(int32_t));
    for (int i = 0; i < NSHAPES; i++) { s->pp_free[i] = s->pp_end[i] = NULL; s->pp_page[i] = -1; s->pg_first[i] = -1; }
#endif
}

static void space_reset(struct space *s) {
    s->free = s->base;
    s->page_top = s->base + s->size;
#ifdef PAIRS
    for (int i = 0; i < NSHAPES; i++) { s->pp_free[i] = s->pp_end[i] = NULL; s->pp_page[i] = -1; s->pg_first[i] = -1; }
#endif
}

static inline void space_save(struct space *s) {
    s->free = hp_free; s->page_top = hp_limit;
#ifdef PAIRS
    for (int i = 0; i < NSHAPES; i++) { s->pp_free[i] = pp_free[i]; s->pp_end[i] = pp_end[i]; }
#endif
}
static inline void space_load(const struct space *s) {
    hp_free = s->free; hp_limit = s->page_top;
#ifdef PAIRS
    for (int i = 0; i < NSHAPES; i++) { pp_free[i] = s->pp_free[i]; pp_end[i] = s->pp_end[i]; }
#endif
}

#ifdef PAIRS
#ifdef PAIR_FWD_BITMAP
static uint8_t *fwd_bits;   /* one bit per 16 bytes of from-space */
#endif
/* a fresh page for shape s in space sp (the mutator's or the to-space's) */
static char *space_take_page(struct space *sp, int s) {
    if (sp->page_top - PAIR_PAGE < sp->free) return NULL;
    sp->page_top -= PAIR_PAGE;
    int idx = (int)((sp->page_top - sp->base) / PAIR_PAGE);
    sp->pg_next[idx] = -1;
    sp->pg_shape[idx] = (uint8_t)s;
    if (sp->pp_page[s] >= 0) sp->pg_next[sp->pp_page[s]] = idx; else sp->pg_first[s] = idx;
    sp->pp_page[s] = idx;
    sp->pp_free[s] = sp->page_top;
    sp->pp_end[s] = sp->page_top + PAIR_PAGE;
    return sp->page_top;
}
#endif

static void gc_collect(size_t need);

/* ---- allocation ---- */
static inline int heap_fits(size_t bytes) { return hp_free + bytes <= hp_limit; }

ALWAYS_INLINE char *heap_bump(size_t sz) {
    char *p = hp_free;
    if (UNLIKELY(p + sz > hp_limit)) { gc_collect(sz); p = hp_free; }
    hp_free = p + sz;
    return p;
}

#ifdef PAIRS
static NOINLINE char *pair_page_slow(int s) {
    for (int tries = 0; tries < 2; tries++) {
        space_save(sp_cur);
        if (space_take_page(sp_cur, s)) { space_load(sp_cur); return pp_free[s]; }
        gc_collect(PAIR_PAGE);
        if (pp_free[s] + 16 <= pp_end[s]) return pp_free[s];
    }
    die("heap full (pairs)");
    return NULL;
}
ALWAYS_INLINE uint64_t *pair_bump(int s) {
    char *p = pp_free[s];
    if (UNLIKELY(p + 16 > pp_end[s])) p = pair_page_slow(s);
    pp_free[s] = p + 16;
    return (uint64_t *)p;
}
static inline int pair_fits(int s) { return pp_free[s] + 16 <= pp_end[s]; }
#endif

/* ---- collection ---- */
static struct space *gc_to;

static obj *gc_copy_obj(obj *o) {
    if (lay_is_forwarded(o)) return lay_forward_of(o);
    size_t size = lay_obj_size(o);
    obj *n = (obj *)gc_to->free;
    if (UNLIKELY(gc_to->free + size > gc_to->page_top)) die("out of memory in gc");
    /* fixed-size copies for the common sizes, as runtime/heap.c copy_obj */
    switch (size) {
    case 16: memcpy(n, o, 16); break;
    case 24: memcpy(n, o, 24); break;
    case 32: memcpy(n, o, 32); break;
    case 40: memcpy(n, o, 40); break;
    case 48: memcpy(n, o, 48); break;
    case 56: memcpy(n, o, 56); break;
    default: memcpy(n, o, size); break;
    }
    gc_to->free += size;
    gc_bytes_copied += size;
    lay_set_forward(o, n);
    return n;
}

#ifdef PAIRS
static uint64_t *gc_copy_pair(uint64_t *p, int shape, val old, val *slot) {
    (void)old; (void)slot;
#ifdef PAIR_FWD_BITMAP
    size_t bit = ((char *)p - sp_cur->base) >> 4;
    if (fwd_bits[bit >> 3] & (1u << (bit & 7))) return (uint64_t *)p[0];
#else
    if (p[0] == PAIR_FWD_MARK) return (uint64_t *)p[1];
#endif
    if (UNLIKELY(gc_to->pp_free[shape] + 16 > gc_to->pp_end[shape]))
        if (!space_take_page(gc_to, shape)) die("out of memory in gc (pairs)");
    uint64_t *n = (uint64_t *)gc_to->pp_free[shape];
    gc_to->pp_free[shape] += 16;
    n[0] = p[0]; n[1] = p[1];
    gc_bytes_copied += 16;
#ifdef PAIR_FWD_BITMAP
    fwd_bits[bit >> 3] |= (uint8_t)(1u << (bit & 7));
    p[0] = (uint64_t)n;
#else
    p[0] = PAIR_FWD_MARK; p[1] = (uint64_t)n;
#endif
    return n;
}
#endif

#ifdef HARNESS_DEBUG
static const char *gc_dbg_where; static size_t gc_dbg_index;
#define GC_DBG_AT(w, i) (gc_dbg_where = (w), gc_dbg_index = (i))
static void gc_dbg_check(val v, val *slot) {
    uintptr_t a = (uintptr_t)v & ~(uintptr_t)7, lo = (uintptr_t)sp_cur->base, hi = lo + sp_cur->size;
    if (a < lo || a >= hi) {
        fprintf(stderr, "gc: bad pointer %#lx in %s[%zu] slot %p (from-space %#lx..%#lx, gc #%llu)\n",
                (unsigned long)(uintptr_t)v, gc_dbg_where, gc_dbg_index, (void *)slot, (unsigned long)lo, (unsigned long)hi, (unsigned long long)gc_count);
        abort();
    }
}
#else
#define GC_DBG_AT(w, i) ((void)0)
#define gc_dbg_check(v, s) ((void)0)
#endif
static inline void gc_forward(val *slot) {
    val v = *slot;
    if (!lay_is_ptr(v)) return;
    gc_dbg_check(v, slot);
#ifdef PAIRS
    if (lay_is_pair(v)) { *slot = lay_pair_retag(v, gc_copy_pair(lay_pair_addr(v), lay_pair_shape(v), v, slot)); return; }
#endif
    obj *o = lay_ptr_obj(v);
    /* an indirection is not copied: what points at it is made to point at
       its value (the short-circuit every lazy collector does). One compare
       of the kind the copy reads next; no strict kernel has one. */
    while (UNLIKELY(lay_is_ind(o))) {
        gc_ind_skipped++; gc_ind_bytes += lay_obj_size(o);
        v = lay_ind_value(o);
        *slot = v;
        if (!lay_is_ptr(v)) return;
#ifdef PAIRS
        if (lay_is_pair(v)) { *slot = lay_pair_retag(v, gc_copy_pair(lay_pair_addr(v), lay_pair_shape(v), v, slot)); return; }
#endif
        o = lay_ptr_obj(v);
    }
    *slot = lay_obj_retag(v, gc_copy_obj(o));
}

#ifdef PAIRS
static int gc_sc_page[NSHAPES]; static char *gc_sc_ptr[NSHAPES];
static int gc_scan_pairs(int s) {
    struct space *to = gc_to;
    int progress = 0;
    if (gc_sc_page[s] < 0) {
        if (to->pg_first[s] < 0) return 0;
        gc_sc_page[s] = to->pg_first[s];
        gc_sc_ptr[s] = to->base + (size_t)gc_sc_page[s] * PAIR_PAGE;
    }
    for (;;) {
        char *pbase = to->base + (size_t)gc_sc_page[s] * PAIR_PAGE;
        for (;;) {
            char *end = (gc_sc_page[s] == to->pp_page[s]) ? to->pp_free[s] : pbase + PAIR_PAGE;
            if (gc_sc_ptr[s] >= end) break;
            lay_scan_pair(s, (uint64_t *)gc_sc_ptr[s]);
            gc_sc_ptr[s] += 16;
            progress = 1;
        }
        if (gc_sc_ptr[s] == pbase + PAIR_PAGE && to->pg_next[gc_sc_page[s]] >= 0) {
            gc_sc_page[s] = to->pg_next[gc_sc_page[s]];
            gc_sc_ptr[s] = to->base + (size_t)gc_sc_page[s] * PAIR_PAGE;
            continue;
        }
        return progress;
    }
}
#endif

static NOINLINE void gc_collect(size_t need) {
    uint64_t t0 = cycles_now();
    space_save(sp_cur);
    gc_to = sp_oth;
    space_reset(gc_to);
#ifdef PAIRS
#ifdef PAIR_FWD_BITMAP
    {   /* clear the bits of the pair pages of from-space */
        size_t lo = (sp_cur->page_top - sp_cur->base) >> 7;
        memset(fwd_bits + lo, 0, (sp_cur->size >> 7) - lo);
    }
#endif
    for (int s = 0; s < NSHAPES; s++) { gc_sc_page[s] = -1; gc_sc_ptr[s] = NULL; }
#endif
    /* roots */
    for (val *r = root_stack_mem; r < root_sp; r++) { GC_DBG_AT("root", (size_t)(r - root_stack_mem)); gc_forward(r); }
    GC_DBG_AT("scan", 0);
    /* scan */
    char *scan = gc_to->base;
    for (;;) {
        int progress = 0;
        while (scan < gc_to->free) {
            obj *o = (obj *)scan;
            lay_scan_obj(o);
            scan += lay_obj_size(o);
            progress = 1;
        }
#ifdef PAIRS
        for (int s = 0; s < NSHAPES; s++) progress |= gc_scan_pairs(s);
#endif
        if (!progress) break;
    }
    struct space *t = sp_cur; sp_cur = sp_oth; sp_oth = t;
    space_load(sp_cur);
    gc_old_limit = hp_free;
    gc_count++;
    gc_cycles += cycles_now() - t0;
    if (need && hp_free + need > hp_limit) die("heap full: live data does not fit the semispace");
}

static void heap_init(size_t semispace_bytes) {
    heap_semispace = semispace_bytes;
    space_init(&sp_a, semispace_bytes);
    space_init(&sp_b, semispace_bytes);
    sp_cur = &sp_a; sp_oth = &sp_b;
    space_load(sp_cur);
#if defined(PAIRS) && defined(PAIR_FWD_BITMAP)
    fwd_bits = map_touched(semispace_bytes >> 7);
#endif
    /* touch the root stack's first pages */
    for (size_t i = 0; i < 64; i++) ((volatile char *)root_stack_mem)[i * 4096] = 0;
    root_sp = root_stack_mem;
}

static void heap_reset(void) {
    space_reset(sp_cur); space_reset(sp_oth);
    space_load(sp_cur);
    root_sp = root_stack_mem;
}

/* bump allocation of a headered object: the layout wraps this in alloc() */
ALWAYS_INLINE obj *heap_alloc_obj(size_t sz) {
    return (obj *)heap_bump(sz);
}
#endif
