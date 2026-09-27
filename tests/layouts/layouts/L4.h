/* L4.h -- untagged, type-directed. A MONO position (the compiler knows
   the type is int/word/real/char/bool) holds the raw 64 bits. A pointer
   position holds a pointer (even) or a nullary constructor as an odd
   immediate (con0 t = 2t+1; unit = 1; nil = 1), which the collector skips
   by its low bit. A POLY position ('a) holds a pointer, or a raw word under
   -DL4_MONO (whole-program monomorphisation: an int list's cells hold raw
   ints and the allocation site says so), or a K_BOX under -DL4_UNIFORM
   (polymorphic containers and calls box their ints and reals).
   The header's second byte is a POINTER BITMAP: bit i = field i is a
   pointer (fields past 7 follow bit 7; arrays are homogeneous: 0xFF or 0).
   Chosen over "non-pointers first + skip count" because it needs no field
   reordering (a CONN's fields keep the source order, so a pattern match
   reads them where the tuple would have them), fits the byte the header
   already has, and the scan is a bit test per field instead of a loop
   bound -- the same cost. The roots are two shadow stacks: PROOT (pointer
   values, scanned) and RROOT (raw values, kept for the store/reload cost
   a stack map's spills have, never scanned). -DPAIRS: headerless pairs of
   three SHAPES in pointer bits 1-2 -- 010 (ptr,ptr), 100 (raw,ptr),
   110 (raw,raw) -- each in its own pages, forwarded through a side bitmap
   (a raw word can be any pattern, so no in-band marker exists). A
   datatype's two-field constructors are headerless only when their
   shapes differ (the kernels' do: Leaf (raw,raw) vs Node (ptr,ptr); a cons
   is the only two-field constructor of list). Objects: objs8.h. */
#ifndef HARNESS_L4_H
#define HARNESS_L4_H
#include "../common.h"
#if !defined(L4_MONO) && !defined(L4_UNIFORM)
#error "L4 needs -DL4_MONO or -DL4_UNIFORM"
#endif
#ifdef HDR4
#error "HDR4 leaves no room for L4's pointer bitmap"
#endif
#ifdef REALIMM
#error "REALIMM is an L1/L2 variant"
#endif
#define LAYOUT_TWO_STACKS 1

typedef uint64_t val;
typedef struct obj obj;
#ifdef PAIRS
#define PTR_MASK (~(uint64_t)7)
#else
#define PTR_MASK (~(uint64_t)0)
#endif

/* ---- MONO values: raw ---- */
ALWAYS_INLINE val mk_unit(void) { return 1; }
ALWAYS_INLINE val mk_int(int64_t i) { return (val)i; }
ALWAYS_INLINE int is_int(val v) { (void)v; return 1; }
ALWAYS_INLINE int64_t unbox_int(val v) { return (int64_t)v; }
ALWAYS_INLINE val mk_word(uint64_t w) { return w; }
ALWAYS_INLINE uint64_t unbox_word(val v) { return v; }
ALWAYS_INLINE val mk_real(double d) { uint64_t u; memcpy(&u, &d, 8); return u; }
ALWAYS_INLINE double unbox_real(val v) { double d; memcpy(&d, &v, 8); return d; }
ALWAYS_INLINE val mk_char(int c) { return (val)c; }
ALWAYS_INLINE int unbox_char(val v) { return (int)v; }
ALWAYS_INLINE val mk_bool(int b) { return (val)(b != 0); }
ALWAYS_INLINE int unbox_bool(val v) { return (int)v; }
/* nullary constructors in pointer positions */
ALWAYS_INLINE val mk_con0(int t) { return ((uint64_t)t << 1) | 1; }
ALWAYS_INLINE int con0_tag(val v) { return (int)(v >> 1); }
ALWAYS_INLINE int is_ptr(val v) { return !(v & 1); }
ALWAYS_INLINE obj *ptr_of(val v) { return (obj *)(v & PTR_MASK); }
ALWAYS_INLINE val ptr_val(obj *o) { return (val)o; }
#define NIL ((val)1)
#define SINK_VAL(v) SINK(v)
ALWAYS_INLINE int is_nil(val v) { return v == 1; }
ALWAYS_INLINE int val_eq_imm(val a, val b) { return a == b; }
static inline int lay_is_ptr(val v) { return !(v & 1); }

ALWAYS_INLINE int add_ov(val a, val b, val *r) { int64_t x; if (__builtin_add_overflow((int64_t)a, (int64_t)b, &x)) return 1; *r = (val)x; return 0; }
ALWAYS_INLINE int sub_ov(val a, val b, val *r) { int64_t x; if (__builtin_sub_overflow((int64_t)a, (int64_t)b, &x)) return 1; *r = (val)x; return 0; }
ALWAYS_INLINE int mul_ov(val a, val b, val *r) { int64_t x; if (__builtin_mul_overflow((int64_t)a, (int64_t)b, &x)) return 1; *r = (val)x; return 0; }

#define MONO_INT(x) mk_int(x)
#define MONO_REAL(x) mk_real(x)
#define MONO_INT_OF(v) unbox_int(v)
#define MONO_REAL_OF(v) unbox_real(v)
#define REAL_ALLOCATES 0
#define WORD_ALLOCATES 0
#define WORD_PTRBIT 0
#define CON_INT_VAL(x) MONO_INT(x)
#define CON_INTBIT 0

#ifdef PAIRS
#define NSHAPES 3
#define PAIR_FWD_BITMAP 1
/* shape 0 = (ptr,ptr), 1 = (raw,ptr), 2 = (raw,raw) */
ALWAYS_INLINE int lay_shape_of_mask(uint32_t mask) {
    switch (mask & 3) { case 3: return 0; case 2: return 1; case 0: return 2; default: __builtin_unreachable(); }
}
ALWAYS_INLINE uint64_t lay_pair_bits(int kind, int contag, uint32_t mask) { (void)kind; (void)contag; return (uint64_t)(lay_shape_of_mask(mask) + 1) << 1; }
/* the kernels' two-field constructors: (raw,raw) is Leaf (tag 0), the
   pointer-bearing shapes are Node and :: (tag 1) */
#define PAIR_CONTAG(v) ((((v) >> 1) & 3) == 3 ? 0 : 1)
#define LAY_PAIR_SHAPE(v) ((int)(((v) >> 1) & 3) - 1)
#endif

/* ---- POLY positions ---- */
#ifdef L4_UNIFORM
#define POLY_VAL_INT(x) box_raw(BOX_INT, (uint64_t)(x))
#define POLY_VAL_REAL(x) mk_real_box(x)
#define POLY_INT_OF(v) ((int64_t)unbox_raw(v))
#define POLY_REAL_OF(v) unbox_real(unbox_raw(v))
#define POLY_TO_MONO_INT(v) unbox_raw(v)
#define MONO_TO_POLY_INT(v) box_raw(BOX_INT, (v))
#define POLY_PTRBIT 1
#define POLY_ALLOCATES 1
#define IROOT_PUSH(v) PROOT_PUSH(v)
#define IROOT_POP() ROOT_POP()
#define ARR_REAL_VAL(d) mk_real_box(d)
#define ARR_REAL_OF(v) unbox_real(unbox_raw(v))
#define ARR_REAL_PTRBIT 1
#define ARR_REAL_ALLOCATES 1
#else
#define POLY_VAL_INT(x) mk_int(x)
#define POLY_VAL_REAL(x) mk_real(x)
#define POLY_INT_OF(v) unbox_int(v)
#define POLY_REAL_OF(v) unbox_real(v)
#define POLY_TO_MONO_INT(v) (v)
#define MONO_TO_POLY_INT(v) (v)
#define POLY_PTRBIT 0
#define POLY_ALLOCATES 0
#define IROOT_PUSH(v) RROOT_PUSH(v)
#define IROOT_POP() RROOT_POP()
#define ARR_REAL_VAL(d) mk_real(d)
#define ARR_REAL_OF(v) unbox_real(v)
#define ARR_REAL_PTRBIT 0
#define ARR_REAL_ALLOCATES 0
#endif

/* ---- the two root stacks ---- */
#include "objs8.h"
#ifdef L4_UNIFORM
ALWAYS_INLINE val mk_real_box(double d) { return box_raw(BOX_REAL, mk_real(d)); }
#endif
static val rroot_stack_mem[ROOT_MAX];
static val *rroot_sp = rroot_stack_mem;
#define RROOT_PUSH(v) (*rroot_sp++ = (v), rroot_sp - 1)
#define RROOT_POP() (--rroot_sp)
ALWAYS_INLINE val *root_push_m(val v, int isptr) { return isptr ? PROOT_PUSH(v) : RROOT_PUSH(v); }
ALWAYS_INLINE void root_pop_m(int isptr) { if (isptr) ROOT_POP(); else RROOT_POP(); }
typedef struct { val *p, *r; } l4_mark;
#undef ROOT_MARK_T
#undef ROOT_MARK
#undef ROOT_RESET
#define ROOT_MARK_T l4_mark
#define ROOT_MARK() ((l4_mark){ root_sp, rroot_sp })
#define ROOT_RESET(m) (root_sp = (m).p, rroot_sp = (m).r)

/* ---- scanning by the bitmap ---- */
static inline void lay_scan_obj(obj *o) {
    int k = obj_kind(o);
    if (k == K_STRING || k == K_BOX) return;
    uint32_t m = obj_mask(o);
    if (!m) return;
    val *f = FIELDS(o);
    uint32_t n = obj_len(o);
    if (m == 0xFF) { for (uint32_t i = 0; i < n; i++) gc_forward(&f[i]); return; }
    for (uint32_t i = 0; i < n; i++) if ((m >> (i < 7 ? i : 7)) & 1) gc_forward(&f[i]);
}
#ifdef PAIRS
static inline void lay_scan_pair(int shape, uint64_t *p) {
    if (shape == 0) { gc_forward(&p[0]); gc_forward(&p[1]); }
    else if (shape == 1) gc_forward(&p[1]);
}
#endif

/* ---- structural equality, driven by the headers' bitmaps ---- */
static int poly_eq(val a, val b) {
    if (a == b) return 1;
    if ((a | b) & 1) return 0;
#ifdef PAIRS
    if ((a | b) & 6) {
        if ((a & 7) != (b & 7)) return 0;
        val *p = (val *)(a & ~(uint64_t)7), *q = (val *)(b & ~(uint64_t)7);
        switch (lay_pair_shape(a)) {
        case 0: return poly_eq(p[0], q[0]) && poly_eq(p[1], q[1]);
        case 1: return p[0] == q[0] && poly_eq(p[1], q[1]);
        default: return p[0] == q[0] && p[1] == q[1];
        }
    }
#endif
    obj *x = (obj *)a, *y = (obj *)b;
    int k = obj_kind(x);
    if (k != obj_kind(y) || obj_contag(x) != obj_contag(y) || obj_len(x) != obj_len(y) || obj_mask(x) != obj_mask(y)) return 0;
    if (k == K_STRING) return memcmp(FIELDS_RAW(x), FIELDS_RAW(y), obj_len(x)) == 0;
    if (k == K_BOX) return memcmp(FIELDS_RAW(x), FIELDS_RAW(y), 8) == 0;
    if (k == K_REF || k == K_ARRAY) return 0;
    val *f = FIELDS(x), *g = FIELDS(y);
    uint32_t m = obj_mask(x);
    for (uint32_t i = 0, n = obj_len(x); i < n; i++) {
        if ((m >> (i < 7 ? i : 7)) & 1) { if (!poly_eq(f[i], g[i])) return 0; }
        else if (f[i] != g[i]) return 0;
    }
    return 1;
}
#endif
