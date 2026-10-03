/* runtime/census/layouts.h -- the size models of the candidate heap layouts
   (docs/plans/heap-layout.md, *The candidate layouts*). Shared verbatim by
   the census VM (runtime/census/census.c: the first-order sizes of census.txt), the
   trace simulator and the layout harness (heap-layout M2), so that the
   three cannot disagree. Sizes in bytes. C17, no dependencies. */
#ifndef HEAP_LAYOUTS_H
#define HEAP_LAYOUTS_H
#include <stddef.h>
#include <stdint.h>

/* vm.h's kinds and tags, repeated so this header stands alone */
enum { LK_TUPLE = 1, LK_CON, LK_CLOSURE, LK_STRING, LK_REF, LK_ARRAY, LK_EXN, LK_EXNCON };
enum { LT_UNIT = 0, LT_INT, LT_WORD, LT_REAL, LT_CHAR, LT_CON0, LT_PTR };
/* bits classes of FORMAT.md */
enum { BC_8 = 0, BC_31, BC_48, BC_51, BC_62, BC_63, BC_64, BC_REAL_BOXED = 7 };

/* The layouts. L5 is a variant flag (LV_PAIRS) on L1 or L4. L1r = L1 | LV_REALIMM. */
enum Layout {
    L0 = 0,   /* today: 16-byte tagged cells, 8-byte header, payload rounded to 16, min 16 */
    L1,       /* 8-byte word, low-bit tag; 63-bit int/word immediate; reals boxed */
    L2,       /* 8-byte word, low-bit tag; 64-bit int/word: small immediate, boxed when > 63 bits */
    L3,       /* 8-byte NaN-boxing: reals immediate, ints/words <= 48 (or 51) bits immediate */
    L4,       /* 8-byte untagged, type-directed: unboxed where the rep is known, boxed when polymorphic */
    L_COUNT
};
enum {
    LV_HDR4     = 1 << 0,  /* 4-byte header (L1-L4) */
    LV_ALIGN16  = 1 << 1,  /* objects aligned to 16 (L1-L4) */
    LV_COMPACT  = 1 << 2,  /* compact arrays/vectors: all-char/byte 1 B/elt, all-real 8 B, all-int/word 8 B */
    LV_MUTSEG   = 1 << 3,  /* mutable objects segregated (no size effect; the barrier model) */
    LV_PAIRS    = 1 << 4,  /* headerless 2-field CON/TUPLE objects (L5): 16 bytes, kind in the pointer */
    LV_REALIMM  = 1 << 5,  /* L1: reals immediate when value-encodable (BC 0), boxed otherwise (Koka) */
    LV_L4UNIFORM= 1 << 6,  /* L4: box every INT/WORD/REAL field of CON/CONN/REF/ARRAY objects and of
                              tuples with any polymorphic source (upper bound); default L4-mono boxes
                              only fields whose source rep is polymorphic */
    LV_NAN51    = 1 << 7   /* L3: 51-bit ints instead of 48 */
};

typedef struct { unsigned header, width, align, minpay; } LayoutParams;

static inline LayoutParams layout_params(enum Layout L, unsigned v) {
    LayoutParams p;
    if (L == L0) { p.header = 8; p.width = 16; p.align = 16; p.minpay = 16; return p; }
    p.header = (v & LV_HDR4) ? 4 : 8;
    p.width = 8;
    p.align = (v & LV_ALIGN16) ? 16 : 8;
    p.minpay = 8;                       /* room for a forwarding pointer */
    return p;
}

static inline size_t layout_roundup(size_t x, size_t a) { return (x + a - 1) & ~(a - 1); }

/* L0's exact rule (runtime/heap.c:7-15): 8 + round16(max(16, payload)) */
static inline size_t l0_obj_size(uint8_t kind, uint32_t len) {
    size_t payload = (kind == LK_STRING) ? (size_t)len : (size_t)len * 16;
    size_t s = (payload + 15) & ~(size_t)15;
    if (s < 16) s = 16;
    return 8 + s;
}

/* Is an array/vector compact under LV_COMPACT? elem_tag/elem_bc describe the
   elements when they are all alike (the census reports arrays whose every
   field, at allocation and in every store, has the same tag); returns the
   bytes per element, or 0 when not compact. */
static inline unsigned layout_compact_elem(unsigned v, uint8_t kind, int homogeneous, uint8_t elem_tag, uint8_t elem_bc) {
    if (!(v & LV_COMPACT) || !homogeneous) return 0;
    if (kind != LK_ARRAY && kind != LK_TUPLE) return 0;   /* vectors are TUPLEs */
    if (elem_tag == LT_CHAR) return 1;
    if (elem_tag == LT_WORD && elem_bc == BC_8) return 1;
    if (elem_tag == LT_REAL || elem_tag == LT_INT || elem_tag == LT_WORD) return 8;
    return 0;
}

/* The size of one object under layout L with variant flags v. elem_bytes is
   layout_compact_elem's answer (0 for an ordinary object). Boxes that a
   layout adds for the object's *fields* are counted separately
   (layout_needs_box). */
static inline size_t layout_obj_size(enum Layout L, unsigned v, uint8_t kind, uint32_t len, unsigned elem_bytes) {
    if (L == L0 && !elem_bytes) return l0_obj_size(kind, len);
    LayoutParams p = layout_params(L, v);
    if ((v & LV_PAIRS) && L != L0 && (kind == LK_CON || kind == LK_TUPLE) && len == 2)
        return 2 * p.width;             /* headerless pair: two words, the kind in the pointer's tag */
    size_t payload;
    if (kind == LK_STRING) payload = len;
    else if (elem_bytes) payload = (size_t)len * elem_bytes;
    else payload = (size_t)len * p.width;
    if (payload < p.minpay) payload = p.minpay;
    return layout_roundup(p.header + payload, p.align);
}

/* A box for a value the layout cannot hold immediate: header + 8 bytes. */
static inline size_t layout_box_size(enum Layout L, unsigned v) {
    LayoutParams p = layout_params(L, v);
    return layout_roundup(p.header + 8, p.align);
}

/* Whether a value of tag/bits-class at a position needs a box under L.
   poly: the position is polymorphic (the source register's rep is ANY, or
   the L4-uniform rule applies). Returns 0 = immediate, 1 = boxed,
   2 = unrepresentable (L1: a 64-bit int or word; reported, not boxed). */
static inline int layout_needs_box(enum Layout L, unsigned v, uint8_t tag, uint8_t bc, int poly) {
    switch (L) {
    case L0: return 0;
    case L1:
        if (tag == LT_REAL) return ((v & LV_REALIMM) && bc == 0) ? 0 : 1;
        if ((tag == LT_INT || tag == LT_WORD) && bc == BC_64) return 2;
        return 0;
    case L2:
        if (tag == LT_REAL) return ((v & LV_REALIMM) && bc == 0) ? 0 : 1;
        if ((tag == LT_INT || tag == LT_WORD) && bc == BC_64) return 1;
        return 0;
    case L3:
        if (tag == LT_INT || tag == LT_WORD)
            return (bc > ((v & LV_NAN51) ? BC_51 : BC_48)) ? 1 : 0;
        return 0;
    case L4:
        if ((tag == LT_INT || tag == LT_WORD || tag == LT_REAL) && poly) return 1;
        return 0;
    default: return 0;
    }
}

static inline const char *layout_name(enum Layout L) {
    static const char *n[] = { "L0", "L1", "L2", "L3", "L4" };
    return (unsigned)L < L_COUNT ? n[L] : "?";
}
#endif
