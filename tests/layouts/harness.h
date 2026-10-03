/* harness.h -- picks the layout and adds the helpers every kernel uses that
   are the same in every layout (refs, arrays, closures, strings). The
   layout header defines the representation, the immediates, alloc,
   field_get/field_set, pairs and poly_eq; see layouts/iface.h. */
#ifndef HARNESS_H
#define HARNESS_H
#include "common.h"
#include "layouts/iface.h"

/* element kinds of K_ARRAY objects, kept in the header's contag */
enum { EK_VAL = 0, EK_REAL = 1, EK_BYTE = 2 };

#if LAYOUT_ID == 0
#include "layouts/L0.h"
#elif LAYOUT_ID == 1
#include "layouts/L1.h"
#elif LAYOUT_ID == 2
#include "layouts/L2.h"
#elif LAYOUT_ID == 3
#include "layouts/L3.h"
#elif LAYOUT_ID == 4
#include "layouts/L4.h"
#else
#error "unknown LAYOUT"
#endif

/* ---- the write barrier hook: a card mark beside the store ---- */
#ifdef BARRIER_CARD
uint8_t card_table[1u << 20];
#define CARD_MARK(o) (card_table[((uintptr_t)(o) >> 9) & ((1u << 20) - 1)] = 1)
#else
#define CARD_MARK(o) ((void)0)
#endif

/* ---- guards: collect before an allocation with the given values rooted;
   m* say whether a value is a pointer (L4 keeps raw values off the scanned
   stack). After the guard the allocation cannot collect. ---- */
#define GUARD0(sz) do { if (UNLIKELY(!heap_fits(sz))) gc_collect(sz); } while (0)
#define GUARD1(sz, a, ma) do { if (UNLIKELY(!heap_fits(sz))) { \
    val *_a = root_push_m(a, ma); gc_collect(sz); a = *_a; root_pop_m(ma); } } while (0)
#define GUARD2(sz, a, ma, b, mb) do { if (UNLIKELY(!heap_fits(sz))) { \
    val *_a = root_push_m(a, ma), *_b = root_push_m(b, mb); gc_collect(sz); \
    b = *_b; a = *_a; root_pop_m(mb); root_pop_m(ma); } } while (0)
#define GUARD3(sz, a, ma, b, mb, c, mc) do { if (UNLIKELY(!heap_fits(sz))) { \
    val *_a = root_push_m(a, ma), *_b = root_push_m(b, mb), *_c = root_push_m(c, mc); gc_collect(sz); \
    c = *_c; b = *_b; a = *_a; root_pop_m(mc); root_pop_m(mb); root_pop_m(ma); } } while (0)
#define GUARD4(sz, a, ma, b, mb, c, mc, d, md) do { if (UNLIKELY(!heap_fits(sz))) { \
    val *_a = root_push_m(a, ma), *_b = root_push_m(b, mb), *_c = root_push_m(c, mc), *_d = root_push_m(d, md); gc_collect(sz); \
    d = *_d; c = *_c; b = *_b; a = *_a; root_pop_m(md); root_pop_m(mc); root_pop_m(mb); root_pop_m(ma); } } while (0)

/* ---- refs ---- */
ALWAYS_INLINE obj *ref_new(val v, int isptr) {
    size_t sz = alloc_size(K_REF, 0, 1);
    GUARD1(sz, v, isptr);
    obj *o = alloc(K_REF, 0, 1, isptr ? 1u : 0u);
    field_set(o, 0, v);
    return o;
}
ALWAYS_INLINE val ref_get(obj *r) { return field_get(r, 0); }
ALWAYS_INLINE void ref_set(obj *r, val v) { field_set(r, 0, v); }

/* ---- arrays of values ---- */
static NOINLINE obj *array_new(uint32_t n, val init, int isptr) {
    size_t sz = alloc_size(K_ARRAY, EK_VAL, n);
    GUARD1(sz, init, isptr);
    obj *o = alloc(K_ARRAY, EK_VAL, n, isptr ? 0xFFu : 0u);
    for (uint32_t i = 0; i < n; i++) field_set(o, i, init);
    return o;
}
ALWAYS_INLINE val array_get(obj *a, uint32_t i) { return field_get(a, i); }
ALWAYS_INLINE void array_set(obj *a, uint32_t i, val v) { field_set(a, i, v); }

/* ---- real arrays: boxed elements where the layout boxes reals, flat
   doubles with -DFLATREAL (an EK_REAL array the collector skips) ---- */
#ifdef FLATREAL
static NOINLINE obj *real_array_new(uint32_t n) {
    obj *o = alloc(K_ARRAY, EK_REAL, n, 0);
    memset(FIELDS_RAW(o), 0, (size_t)n * 8);
    return o;
}
ALWAYS_INLINE void real_array_set(obj *a, uint32_t i, double d) { ((double *)FIELDS_RAW(a))[i] = d; CARD_MARK(a); }
ALWAYS_INLINE double real_array_get(obj *a, uint32_t i) { return ((double *)FIELDS_RAW(a))[i]; }
#else
static NOINLINE obj *real_array_new(uint32_t n) {
    obj *o = alloc(K_ARRAY, EK_VAL, n, ARR_REAL_PTRBIT ? 0xFFu : 0u);
    /* Array.array (n, 0.0): one value stored n times */
    val z = ARR_REAL_VAL(0.0);
    for (uint32_t i = 0; i < n; i++) field_set(o, i, z);
    return o;
}
ALWAYS_INLINE void real_array_set(obj *a, uint32_t i, double d) {
#if ARR_REAL_ALLOCATES
    if (UNLIKELY(!heap_fits(alloc_size(K_BOX, 0, 1)))) { val *_a = PROOT_PUSH(ptr_val(a)); gc_collect(alloc_size(K_BOX, 0, 1)); a = ptr_of(*_a); ROOT_POP(); }
#endif
    val v = ARR_REAL_VAL(d);
    field_set(a, i, v);
}
ALWAYS_INLINE double real_array_get(obj *a, uint32_t i) { return ARR_REAL_OF(field_get(a, i)); }
#endif

/* ---- char arrays: one value per char, or bytes with -DCOMPACTBYTES ---- */
#ifdef COMPACTBYTES
static NOINLINE obj *char_array_new(uint32_t n) {
    obj *o = alloc(K_ARRAY, EK_BYTE, n, 0);
    memset(FIELDS_RAW(o), ' ', n);
    return o;
}
ALWAYS_INLINE void char_array_set(obj *a, uint32_t i, int c) { ((char *)FIELDS_RAW(a))[i] = (char)c; CARD_MARK(a); }
ALWAYS_INLINE int char_array_get(obj *a, uint32_t i) { return (unsigned char)((char *)FIELDS_RAW(a))[i]; }
#else
static NOINLINE obj *char_array_new(uint32_t n) {
    obj *o = alloc(K_ARRAY, EK_VAL, n, 0);
    val z = mk_char(' ');
    for (uint32_t i = 0; i < n; i++) field_set(o, i, z);
    return o;
}
ALWAYS_INLINE void char_array_set(obj *a, uint32_t i, int c) { field_set(a, i, mk_char(c)); }
ALWAYS_INLINE int char_array_get(obj *a, uint32_t i) { return unbox_char(field_get(a, i)); }
#endif

/* ---- strings ---- */
typedef obj str;
ALWAYS_INLINE str *string_new(uint32_t len) { return alloc_bytes(len); }
ALWAYS_INLINE char *string_bytes(str *s) { return (char *)FIELDS_RAW(s); }
ALWAYS_INLINE uint32_t string_len(str *s) { return obj_len(s); }
static NOINLINE val string_concat(val a, val b) {
    uint32_t la = string_len(ptr_of(a)), lb = string_len(ptr_of(b));
    size_t sz = alloc_size(K_STRING, 0, la + lb);
    GUARD2(sz, a, 1, b, 1);
    str *o = alloc_bytes(la + lb);
    memcpy(string_bytes(o), string_bytes(ptr_of(a)), la);
    memcpy(string_bytes(o) + la, string_bytes(ptr_of(b)), lb);
    return ptr_val(o);
}
static NOINLINE val string_sub(val s, uint32_t i, uint32_t n) {
    size_t sz = alloc_size(K_STRING, 0, n);
    GUARD1(sz, s, 1);
    str *o = alloc_bytes(n);
    memcpy(string_bytes(o), string_bytes(ptr_of(s)) + i, n);
    return ptr_val(o);
}
/* CharArray.vector */
static NOINLINE val char_array_to_string(obj *a) {
    uint32_t n = obj_len(a);
    size_t sz = alloc_size(K_STRING, 0, n);
    if (UNLIKELY(!heap_fits(sz))) { val *_a = PROOT_PUSH(ptr_val(a)); gc_collect(sz); a = ptr_of(*_a); ROOT_POP(); }
    str *o = alloc_bytes(n);
    char *p = string_bytes(o);
    for (uint32_t i = 0; i < n; i++) p[i] = (char)char_array_get(a, i);
    return ptr_val(o);
}
/* String.compare */
ALWAYS_INLINE int string_compare(val a, val b) {
    str *x = ptr_of(a), *y = ptr_of(b);
    uint32_t la = string_len(x), lb = string_len(y);
    int c = memcmp(string_bytes(x), string_bytes(y), la < lb ? la : lb);
    if (c) return c;
    return la < lb ? -1 : la > lb;
}

/* ---- closures: field 0 the function index (a MONO int), then the free
   variables; the call goes through a table reached by a volatile pointer,
   as the VM's CALL reaches its function table ---- */
typedef val (*fnptr)(obj *clo, val arg);
extern fnptr fntab[];
extern fnptr *volatile fntab_p;
static NOINLINE val closure_new(int fn, int nfree, val *env, uint32_t envmask) {
    size_t sz = alloc_size(K_CLOSURE, 0, 1 + nfree);
    if (UNLIKELY(!heap_fits(sz))) {
        val *slots[8];
        for (int i = 0; i < nfree; i++) slots[i] = root_push_m(env[i], (envmask >> i) & 1);
        gc_collect(sz);
        for (int i = nfree - 1; i >= 0; i--) { env[i] = *slots[i]; root_pop_m((envmask >> i) & 1); }
    }
    obj *o = alloc(K_CLOSURE, 0, 1 + nfree, envmask << 1);
    field_set(o, 0, MONO_INT(fn));
    for (int i = 0; i < nfree; i++) field_set(o, 1 + i, env[i]);
    return ptr_val(o);
}
ALWAYS_INLINE val closure_env(obj *clo, int i) { return field_get(clo, 1 + i); }
ALWAYS_INLINE val closure_call(val clo, val arg) {
    obj *c = ptr_of(clo);
    int fn = (int)MONO_INT_OF(field_get(c, 0));
    fnptr *t = fntab_p;
    return t[fn](c, arg);
}

/* ---- suspensions, for a lazy front end (docs/plans/heap-layout.md, *A lazy
   front end*). A lazy value is a pointer to a thunk (K_THUNK: the index of
   its code in the header's tag, then its free variables, one at least), to
   an indirection (K_IND: what a thunk becomes once it has its value, in
   field 0, until a collection takes the indirection out), or to the value
   itself. Where the layout keeps a pointer code for it (L1 with -DPAIRS
   -DPAIR_CODES=2: EVAL_CODE), a pointer to a value with a header carries
   the code, and a pair's own code says as much: a case rules a thunk out
   without the header. A thunk's code is given the thunk, reads its free
   variables before it allocates, and returns the value, evaluated. ---- */
#ifdef EVAL_CODE
#define EVALUATED(v) ((v) | EVAL_CODE)
#else
#define EVALUATED(v) (v)
#endif
typedef val (*thunkfn)(obj *thunk);
extern thunkfn thunktab[];
extern thunkfn *volatile thunktab_p;
static uint64_t lazy_forced, lazy_old_to_young;

static NOINLINE val thunk_new1(int code, val fv, int isptr) {
    size_t sz = alloc_size(K_THUNK, code, 1);
    GUARD1(sz, fv, isptr);
    obj *o = alloc(K_THUNK, code, 1, isptr ? 1u : 0u);
    FIELDS(o)[0] = fv;
    return ptr_val(o);
}
/* a MONO int and a pointer */
static NOINLINE val thunk_new2(int code, val k, val p) {
    size_t sz = alloc_size(K_THUNK, code, 2);
    GUARD2(sz, k, 0, p, 1);
    obj *o = alloc(K_THUNK, code, 2, 2u);
    FIELDS(o)[0] = k; FIELDS(o)[1] = p;
    return ptr_val(o);
}
/* the update: the thunk becomes an indirection to its value. The store is
   the write barrier's (field_set): an old thunk given a young value is what
   a lazy program gives a generational collector to remember. */
ALWAYS_INLINE void thunk_update(obj *t, val v) {
    obj_become_ind(t);
    field_set(t, 0, v);
    if ((char *)t < gc_old_limit && is_ptr(v) && (char *)ptr_of(v) >= gc_old_limit) lazy_old_to_young++;
}
static NOINLINE val lazy_force(val t) {
    val *ts = PROOT_PUSH(t);
    thunkfn *tab = thunktab_p;
    val v = tab[obj_contag(ptr_of(t))](ptr_of(t));
    thunk_update(ptr_of(*ts), v);
    ROOT_POP();
    lazy_forced++;
    return v;
}
/* to weak head normal form by the header: a value, or through the
   indirections to one, or the thunk forced */
static NOINLINE val lazy_whnf_slow(val v) {
    for (;;) {
        obj *o = ptr_of(v);
        int k = obj_kind(o);
        if (k == K_IND) { v = field_get(o, 0); if (!is_ptr(v)) return v; continue; }
        if (k == K_THUNK) return lazy_force(v);
        return v;
    }
}
/* the same as a program would do it for a value of any lazy type: a pair's
   code is a value's; else the header */
ALWAYS_INLINE val lazy_whnf(val v) {
#ifdef PAIRS
    if (v & 6) return v;
#endif
    obj *o = ptr_of(v);
    int k = obj_kind(o);
    if (LIKELY(k != K_IND && k != K_THUNK)) return v;
    return lazy_whnf_slow(v);
}
#endif
