/* h6.c -- H6, the write barriers of gen.h on four kernels (h6k.h):
   inttable (tests/layouts'), an imp-for-like nest of loops over refs,
   lazy_update_old (tests/layouts') and an accumulator in a ref. Each
   kernel is compiled once per barrier, the barrier inlined at every store.
   A row a (barrier, kernel): the mutator's cycles and the minor
   collections' cycles, per store into an existing object; on stderr the
   stores, the old-to-young stores, the slow paths, the cards and
   remembered objects the minors scanned. none is the store alone, its
   minors scanning the whole old space (there is nothing else that finds
   the old-to-young pointers).

   check=1: every barrier's run gives the checksum of a run that counts the
   stores and scans the whole old space (gen.h's checks after each minor).

   gcbench h6 [kernel=inttable,impfor,lazyold,refcons] [bar=none,...,satb-on]
              [nursery=1M] [reps=5] [n_inttable=400K] [n_impfor=10M]
              [n_lazyold=2M] [n_refcons=10M] */
#include "gcb.h"
#include "gen.h"

static uint64_t h6_ck;
/* the allocators of the kernels: pointer arguments in root slots */
ALWAYS_INLINE val h6_ref(val v) { obj *o = g_alloc(16, K_REF, 0, 1); FIELDS(o)[0] = v; return ptr_val(o); }   /* V an immediate or rooted by the caller's re-read */
ALWAYS_INLINE val h6_cons(val *hd, val *tl) { obj *o = g_alloc(24, K_CON, 1, 2); FIELDS(o)[0] = *hd; FIELDS(o)[1] = *tl; return ptr_val(o); }
ALWAYS_INLINE val h6_tuple(val *a, val *b) { obj *o = g_alloc(24, K_TUPLE, 0, 2); FIELDS(o)[0] = *a; FIELDS(o)[1] = *b; return ptr_val(o); }
ALWAYS_INLINE val h6_closure(val *x) { obj *o = g_alloc(24, K_CLOSURE, 0, 2); FIELDS(o)[0] = mk_int(7); FIELDS(o)[1] = *x; return ptr_val(o); }
static NOINLINE val h6_array(uint32_t n, val init) {
    obj *o = g_alloc(size_of(K_ARRAY, n), K_ARRAY, 0, n);
    for (uint32_t i = 0; i < n; i++) FIELDS(o)[i] = init;
    return ptr_val(o);
}

#define KN2(name, b) name##_##b
#define KN1(name, b) KN2(name, b)
#define KN(name) KN1(name, BAR)
#define BAR 0
#include "h6k.h"
#undef BAR
#define BAR 1
#include "h6k.h"
#undef BAR
#define BAR 2
#include "h6k.h"
#undef BAR
#define BAR 3
#include "h6k.h"
#undef BAR
#define BAR 4
#include "h6k.h"
#undef BAR
#define BAR 5
#include "h6k.h"
#undef BAR
#define BAR 6
#include "h6k.h"
#undef BAR
#define BAR 7
#include "h6k.h"
#undef BAR
#define BAR 8
#include "h6k.h"
#undef BAR
_Static_assert(B_N == 8 && B_COUNT == 8, "one inclusion of h6k.h per barrier, and the counting pass");

typedef void (*h6fn)(int64_t);
#define H6_ROW(k) { k##_0, k##_1, k##_2, k##_3, k##_4, k##_5, k##_6, k##_7, k##_8 }
static const struct { const char *name; h6fn fn[B_N + 1]; const char *nopt; double ndflt; } h6_kernels[] = {
    { "inttable", H6_ROW(inttable), "n_inttable", 400000 },
    { "impfor",   H6_ROW(impfor),   "n_impfor",   10000000 },
    { "lazyold",  H6_ROW(lazyold),  "n_lazyold",  2000000 },
    { "refcons",  H6_ROW(refcons),  "n_refcons",  10000000 },
};

static void exp_h6(void) {
    const char *ks = opt_s("kernel", "inttable,impfor,lazyold,refcons");
    const char *bs = opt_s("bar", "none,card,card-young,ssb-byte,ssb-hdr,dart,satb-off,satb-on");
    size_t nursery = (size_t)opt_n("nursery", 1048576.0);
    int reps = (int)opt_n("reps", 5);
    g_init(nursery, (size_t)opt_n("old", 256.0 * 1048576));
    for (size_t k = 0; k < sizeof h6_kernels / sizeof h6_kernels[0]; k++) {
        if (!in_list(ks, h6_kernels[k].name)) continue;
        int64_t n = (int64_t)opt_n(h6_kernels[k].nopt, h6_kernels[k].ndflt);
        /* the counting pass */
        g_reset(B_NONE); h6_ck = 0;
        g_bar = B_COUNT;
        h6_kernels[k].fn[B_COUNT](n);
        uint64_t stores = g_stores, o2y = g_o2y, ck0 = h6_ck;
        fprintf(stderr, "# H6 %s n=%lld: %llu stores, %llu old-to-young, %llu minors, promoted %.1f MiB, %llu large\n",
                h6_kernels[k].name, (long long)n, (unsigned long long)stores, (unsigned long long)o2y,
                (unsigned long long)g_minors, (double)g_promoted / 1048576.0, (unsigned long long)g_large);
        for (int b = 0; b < B_N; b++) {
            if (!in_list(bs, bar_names[b])) continue;
            reps_t rm, rg; reps_init(&rm); reps_init(&rg);
            for (int r = 0; r < reps; r++) {
                g_reset(b); h6_ck = 0;
                ctrs a0, a1, tot, mut;
                pc_read(&a0);
                h6_kernels[k].fn[b](n);
                pc_read(&a1);
                ctrs_sub(&tot, &a1, &a0);
                ctrs_sub(&mut, &tot, &g_gcph.acc);
                reps_add(&rm, &mut); reps_add(&rg, &g_gcph.acc);
                if (h6_ck != ck0) { gcb_fail("H6 %s %s: the checksum differs from the counting pass's", h6_kernels[k].name, bar_names[b]); break; }
            }
            char cas[96], hb[32];
            snprintf(cas, sizeof cas, "mutator/%s/%s/n=%s", bar_names[b], h6_kernels[k].name, human((double)nursery, hb));
            reps_out(&rm, "H6", cas, "store", (double)stores);
            snprintf(cas, sizeof cas, "minor/%s/%s/n=%s", bar_names[b], h6_kernels[k].name, human((double)nursery, hb));
            reps_out(&rg, "H6", cas, "store", (double)stores);
            fprintf(stderr, "# H6 %s %s: slow %llu, o2y %llu, minors %llu, cards scanned %llu, remembered scanned %llu, satb logged %llu (%llu buffers)\n",
                    bar_names[b], h6_kernels[k].name, (unsigned long long)g_slow, (unsigned long long)g_o2y, (unsigned long long)g_minors,
                    (unsigned long long)g_cards_scanned, (unsigned long long)g_ssb_scanned, (unsigned long long)g_satb_logged, (unsigned long long)g_satb_flushes);
        }
    }
}
