/* h8.c -- H8, the stack as roots: what a minor collection pays per frame
   and per slot. The stack and the frames are the VM's (runtime/vm.h:
   Frame {func, ret_pc, base, closure, native_ret, result}, a value stack of
   registers), and the scan is runtime/heap.c's stack_roots: for every
   frame that waits for a call, the liveness of its registers at the
   return point (runtime/register/live.c's reg_frame_live: a binary
   search over the function's return pcs, reached through a function
   pointer as vm->frame_live is), every live register a root, a dead one
   holding a pointer made unit. Which registers of a function hold
   pointers is fixed per function (PTR of them, at random), as their
   representations are; which pointers are young (YOUNG of them) varies. A root is what a minor collection asks of
   it: a pointer into the nursery or not (the copy itself is H2's).

   Variants: `all` (every slot a root: no liveness, the stack bytecode's
   way), `live` (the binary search per frame, as today), `hash` (one global
   table from return pc to live mask, OCaml's frame descriptors' way),
   `bits` (the binary search, then no branch on a slot's data).

   check=1: the binary search and the hash give every return point the same
   mask; on every version of the stack `all` finds every young pointer,
   and `live`, `hash` and `bits` find the same roots, no more than `all`,
   and leave the same stack; a repetition is one scan.

   gcbench h8 [frames=100,10K,1M] [locals=4,16,64] [rets=4,64,1024]
              [funcs=1,64,4096] [ptr=0.5] [young=0.1] [how=all,live,hash,bits] [reps=5] */
#include "gcb.h"

typedef struct { uint32_t func, ret_pc; size_t base; obj *closure; const void *native_ret; uint32_t result; } frame_t;
typedef struct { uint32_t nlocals, nlive; uint32_t *live_pc; uint64_t *live_at; uint64_t ptrs; } func_t;

static func_t *h8_funcs;
static uint32_t h8_nfuncs;
static NOINLINE uint64_t h8_frame_live(uint32_t func, uint32_t ret_pc) {
    if (func >= h8_nfuncs) return ~(uint64_t)0;
    const func_t *fn = &h8_funcs[func];
    uint32_t lo = 0, hi = fn->nlive;   /* the return points are in the order of the code */
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2;
        if (fn->live_pc[mid] < ret_pc) lo = mid + 1; else hi = mid;
    }
    return lo < fn->nlive && fn->live_pc[lo] == ret_pc ? fn->live_at[lo] : ~(uint64_t)0;
}
/* the global table: open addressing on the return pc (pcs are unique across functions) */
static uint32_t *h8_hkey; static uint64_t *h8_hval; static uint32_t h8_hmask;
static NOINLINE uint64_t h8_frame_live_hash(uint32_t func, uint32_t ret_pc) {
    (void)func;
    uint32_t i = (ret_pc * 0x9E3779B1u) & h8_hmask;
    for (;;) {
        uint32_t k = h8_hkey[i];
        if (k == ret_pc) return h8_hval[i];
        if (k == 0) return ~(uint64_t)0;
        i = (i + 1) & h8_hmask;
    }
}
static uint64_t (*volatile h8_live_fn)(uint32_t, uint32_t);

static char *h8_young_lo, *h8_young_hi;
static size_t h8_roots;
ALWAYS_INLINE void h8_root(val *v) {
    val x = *v;
    if (is_ptr(x) && (char *)ptr_of(x) >= h8_young_lo && (char *)ptr_of(x) < h8_young_hi) h8_roots++;
}
/* stack_roots of runtime/heap.c, with the liveness function given */
static NOINLINE void h8_scan(frame_t *frames, size_t fp, val *stack, size_t sp, int use_live) {
    size_t at = 0;
    uint64_t (*live_fn)(uint32_t, uint32_t) = h8_live_fn;
    for (size_t k = 0; k < fp; k++) {
        const frame_t *f = &frames[k];
        size_t end = frames[k + 1].base < sp ? frames[k + 1].base : sp;
        uint32_t n = h8_funcs[f->func].nlocals;
        uint64_t live = use_live ? live_fn(f->func, frames[k + 1].ret_pc) : ~(uint64_t)0;
        for (; at < f->base && at < end; at++) h8_root(&stack[at]);
        for (uint32_t r = 0; r < n && at < end; r++, at++) {
            if (r >= 64 || ((live >> r) & 1)) h8_root(&stack[at]);
            else if (is_ptr(stack[at])) stack[at] = NIL;
        }
    }
    for (; at < sp; at++) h8_root(&stack[at]);
}

/* the same with no branch on the data of a slot: a dead slot is made unit
   (when it holds a pointer) by a conditional move, a live one counted as a
   root by arithmetic (the young test still a compare); the registers past
   the 64th are not modelled (LOCALS <= 64) */
static NOINLINE void h8_scan_bits(frame_t *frames, size_t fp, val *stack, size_t sp) {
    size_t at = 0, roots = 0;
    uint64_t (*live_fn)(uint32_t, uint32_t) = h8_live_fn;
    uintptr_t lo = (uintptr_t)h8_young_lo, span = (uintptr_t)(h8_young_hi - h8_young_lo);
    for (size_t k = 0; k < fp; k++) {
        const frame_t *f = &frames[k];
        uint32_t n = h8_funcs[f->func].nlocals;
        uint64_t live = live_fn(f->func, frames[k + 1].ret_pc);
        at = f->base;
        for (uint32_t r = 0; r < n; r++, at++) {
            val v = stack[at];
            uint64_t isp = (uint64_t)is_ptr(v), lv = (live >> r) & 1;
            stack[at] = (isp & ~lv & 1) ? NIL : v;
            roots += isp & lv & (uint64_t)((uintptr_t)v - lo < span);
        }
    }
    for (; at < sp; at++) { val v = stack[at]; roots += (uint64_t)is_ptr(v) & (uint64_t)((uintptr_t)v - lo < span); }
    h8_roots = roots;
}

static void h8_verify(frame_t *frames, size_t fp, val *stack, const val *saved, size_t sp, size_t nv, const char *cas) {
    for (uint32_t i = 0; i < h8_nfuncs; i++)
        for (uint32_t j = 0; j < h8_funcs[i].nlive; j++)
            if (h8_frame_live(i, h8_funcs[i].live_pc[j]) != h8_frame_live_hash(i, h8_funcs[i].live_pc[j])) {
                gcb_fail("H8 %s: the hash and the binary search disagree on a return point", cas);
                return;
            }
    val *after = malloc(sp * sizeof(val));
    uint64_t (*keep)(uint32_t, uint32_t) = h8_live_fn;
    int ok = 1;
    for (size_t v = 0; ok && v < nv; v++) {
        size_t young = 0, roots[4];
        for (size_t i = 0; i < sp; i++) {
            val x = saved[v * sp + i];
            young += is_ptr(x) && (char *)ptr_of(x) >= h8_young_lo && (char *)ptr_of(x) < h8_young_hi;
        }
        for (int w = 0; ok && w < 4; w++) {   /* all, live, hash, bits */
            if (w == 3 && h8_funcs[0].nlocals > 64) { roots[3] = roots[1]; break; }   /* bits models 64 registers */
            memcpy(stack, saved + v * sp, sp * sizeof(val));
            h8_roots = 0;
            h8_live_fn = w == 2 ? h8_frame_live_hash : h8_frame_live;
            if (w == 3) h8_scan_bits(frames, fp, stack, sp); else h8_scan(frames, fp, stack, sp, w != 0);
            roots[w] = h8_roots;
            if (w == 1) memcpy(after, stack, sp * sizeof(val));
            else if (w > 1 && memcmp(after, stack, sp * sizeof(val))) { gcb_fail("H8 %s: the %s scan leaves another stack than live's", cas, w == 2 ? "hash" : "bits"); ok = 0; }
        }
        if (ok && roots[0] != young) { gcb_fail("H8 %s: all finds %zu roots of %zu young pointers", cas, roots[0], young); ok = 0; }
        if (ok && (roots[2] != roots[1] || roots[3] != roots[1] || roots[1] > roots[0])) {
            gcb_fail("H8 %s: roots found: all %zu, live %zu, hash %zu, bits %zu", cas, roots[0], roots[1], roots[2], roots[3]);
            ok = 0;
        }
    }
    h8_live_fn = keep;
    free(after);
}

static void h8_one(size_t nframes, uint32_t nlocals, uint32_t nrets, uint32_t nfuncs, double pptr, double pyoung, int how, int reps) {
    uint64_t seed = 0x5EED0000ULL + nframes * 7 + nlocals * 13 + nrets * 17 + nfuncs;
    /* the functions: return pcs spread over each function's code, random live masks */
    h8_nfuncs = nfuncs;
    h8_funcs = calloc(nfuncs, sizeof *h8_funcs);
    uint32_t pc = 1;
    size_t tsize = 1; while (tsize < (size_t)nfuncs * nrets * 2) tsize <<= 1;
    h8_hkey = calloc(tsize, sizeof *h8_hkey); h8_hval = calloc(tsize, sizeof *h8_hval); h8_hmask = (uint32_t)tsize - 1;
    for (uint32_t i = 0; i < nfuncs; i++) {
        func_t *fn = &h8_funcs[i];
        fn->nlocals = nlocals; fn->nlive = nrets;
        /* which registers hold pointers: fixed per function, as its
           registers' representations are (Function.reps) */
        fn->ptrs = 0;
        for (uint32_t b = 0; b < 64; b++) if (rnd_unit(&seed) < pptr) fn->ptrs |= (uint64_t)1 << b;
        fn->live_pc = malloc(nrets * sizeof *fn->live_pc); fn->live_at = malloc(nrets * sizeof *fn->live_at);
        for (uint32_t j = 0; j < nrets; j++) {
            pc += 1 + (uint32_t)rnd_below(&seed, 12);
            fn->live_pc[j] = pc;
            fn->live_at[j] = rnd(&seed);
            uint32_t hi = (pc * 0x9E3779B1u) & h8_hmask;
            while (h8_hkey[hi]) hi = (hi + 1) & h8_hmask;
            h8_hkey[hi] = pc; h8_hval[hi] = fn->live_at[j];
        }
        pc += 16;
    }
    /* the stack: frame k of a random function, waiting at one of its return points */
    frame_t *frames = region(rup((nframes + 1) * sizeof(frame_t), 4096), MAP_TOUCH);
    size_t sp = nframes * nlocals;
    val *stack = region(rup(sp * sizeof(val), 4096), MAP_TOUCH), *saved = malloc(sp * sizeof(val));
    size_t young_bytes = 1u << 20;
    char *young = malloc(young_bytes), *old = malloc(young_bytes);
    h8_young_lo = young; h8_young_hi = young + young_bytes;
    for (size_t k = 0; k <= nframes; k++) {
        frame_t *f = &frames[k];
        f->func = (uint32_t)rnd_below(&seed, nfuncs);
        f->base = k * nlocals;
        f->closure = NULL; f->native_ret = NULL; f->result = 0;
    }
    for (size_t k = 1; k <= nframes; k++) {
        const func_t *caller = &h8_funcs[frames[k - 1].func];
        frames[k].ret_pc = caller->live_pc[rnd_below(&seed, caller->nlive)];
    }
    /* NV versions of the stack's contents, which young object each pointer
       is, so that the branch predictor does not learn one stack by heart */
    size_t nv = (64u << 20) / (sp * sizeof(val)); if (nv > 8) nv = 8; if (nv < 1) nv = 1;
    saved = realloc(saved, nv * sp * sizeof(val));
    for (size_t v = 0; v < nv; v++)
        for (size_t k = 0; k < nframes; k++) {
            uint64_t ptrs = h8_funcs[frames[k].func].ptrs;
            for (uint32_t r = 0; r < nlocals; r++) {
                size_t i = k * nlocals + r;
                if (r < 64 && ((ptrs >> r) & 1)) {
                    char *where = rnd_unit(&seed) < pyoung ? young : old;
                    saved[v * sp + i] = ptr_val((obj *)(where + 8 * rnd_below(&seed, young_bytes / 8)));
                } else saved[v * sp + i] = mk_int((int64_t)i);
            }
        }
    h8_live_fn = how == 2 ? h8_frame_live_hash : h8_frame_live;
    /* fp: the running frame is the last; the frames below it wait */
    size_t fp = nframes - 1;
    static const char *hows[] = { "all", "live", "hash", "bits" };
    char cas[128], hb[32];
    snprintf(cas, sizeof cas, "%s/frames=%s/locals=%u/rets=%u/funcs=%u", hows[how], human((double)nframes, hb), nlocals, nrets, nfuncs);
    if (gcb_check) h8_verify(frames, fp, stack, saved, sp, nv, cas);
    size_t rounds = (4u << 20) / sp; if (rounds < 1 || gcb_check) rounds = 1;
    reps_t r; reps_init(&r);
    size_t roots = 0;
    for (int k = 0; k < reps; k++) {
        phase p; ph_clear(&p);
        for (size_t j = 0; j < rounds; j++) {
            memcpy(stack, saved + (j % nv) * sp, sp * sizeof(val));
            h8_roots = 0;
            ph_begin(&p);
            if (how == 3) h8_scan_bits(frames, fp, stack, sp);
            else h8_scan(frames, fp, stack, sp, how != 0);
            ph_end(&p);
            roots = h8_roots;
        }
        reps_add(&r, &p.acc);
    }
    fprintf(stderr, "# H8 %s: %zu roots young of %zu slots\n", cas, roots, sp);
    reps_out(&r, "H8", cas, "frame", (double)fp * (double)rounds);
    for (uint32_t i = 0; i < nfuncs; i++) { free(h8_funcs[i].live_pc); free(h8_funcs[i].live_at); }
    free(h8_funcs); free(h8_hkey); free(h8_hval);
    region_free(frames, rup((nframes + 1) * sizeof(frame_t), 4096));
    region_free(stack, rup(sp * sizeof(val), 4096));
    free(saved); free(young); free(old);
}

static void exp_h8(void) {
    double fr[16], lo[16], re[16], fu[16];
    int nfr = opt_list("frames", "100,10K,1M", fr, 16), nlo = opt_list("locals", "4,16,64", lo, 16);
    int nre = opt_list("rets", "4,64,1024", re, 16), nfu = opt_list("funcs", "1,64,4096", fu, 16);
    double pptr = opt_n("ptr", 0.5), pyoung = opt_n("young", 0.1);
    const char *hows = opt_s("how", "all,live,hash,bits");
    int reps = (int)opt_n("reps", 5);
    static const char *names[] = { "all", "live", "hash", "bits" };
    for (int a = 0; a < nfr; a++)
        for (int b = 0; b < nlo; b++)
            for (int c = 0; c < nre; c++)
                for (int d = 0; d < nfu; d++)
                    for (int how = 0; how < 4; how++) {
                        if (!in_list(hows, names[how])) continue;
                        if (how == 0 && (c > 0 || d > 0)) continue;   /* no lookup: the tables do not matter */
                        h8_one((size_t)fr[a], (uint32_t)lo[b], (uint32_t)re[c], (uint32_t)fu[d], pptr, pyoung, how, reps);
                    }
}
