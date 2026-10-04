/* runtime/value.h -- THE LAYOUT (docs/plans/heap-layout.md, *The architecture*,
   M3): how a value is represented and how an object is laid out, in one
   place. Every test of a tag, every construction of a value, every unboxing
   of a payload, every read and write of a header, every field access, the
   size of an object and its forwarding, and the image's encoding of a value
   are the functions here, and nothing outside this header names a tag
   byte, a header field or an offset: runtime/prims.c, runtime/runtime.c, runtime/heap.c,
   runtime/image.c, runtime/loader.c, the loops (src/isa/stack.sml and regs.sml, whose
   bodies are C) and runtime/register/fastprim.h are written over these names. The
   JIT's macro-assembler (runtime/register/jit/masm.c) is the same operations as
   machine code, and runeopt's templates are generated from it
   (src/opt/x64_layout.sml). A change of layout is a change here and in
   masm.c, and nowhere else; runtime/native/native_offsets.h names what the generated
   code needs of it.

   This branch's layout: the tagged 8-byte word (below), and an object with
   an 8-byte header (kind, pad, contag, len) and a payload of words, or of
   bytes for a string, rounded up to a word and at least one (a forwarding
   pointer fits): the least object is 16 bytes. Included by vm.h. */
#ifndef RUNE_VALUE_H
#define RUNE_VALUE_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>


enum Tag { T_UNIT = 0, T_INT, T_WORD, T_REAL, T_CHAR, T_CON0, T_PTR,
           T_INT64, T_WORD64 };   /* Int64.int and Word64.word: an immediate, or a K_BOX past 63 bits */

typedef struct Obj Obj;

/* THE TAGGED WORD (heap-layout M5: D1 B, D2 B, D3 C).
   A Value is one 64-bit word. Its low bit says what it is:
     1  an immediate: an int, a word, a char, a constructor tag or unit as
        2n+1 (63 bits; unit is 1), or a real in its encoding (below);
     0  a pointer to an object, 8-byte aligned, or NULL (0).
   The type of an immediate is the program's, not the word's: an int and a
   char with the same payload are the same word, which SML's typing keeps
   apart. int and word are the immediate's 63 bits (D2 B): Overflow is
   raised where an int would need a 64th, and a word wraps there. What does
   not fit the word is a small object: a real outside the encoding's range
   is a K_REAL box, and an Int64.int or a Word64.word, the types that keep
   64 bits, is an immediate where it fits 63 and a K_BOX where it does not;
   the readers of those types test for the box. Under RUNE_INT64 (D2 A,
   behind its switch: a compiler given --int-bits=64) int and word keep 64
   bits the same way. Under RUNE_REAL_BOXED (D3 B) every real that reaches a
   value is boxed. */
typedef uint64_t Value;
#define RUNE_VALUE_HDR 0
#define VALUE_TAG_BITS 1

enum ObjKind {
    K_TUPLE = 1,  /* len fields; also vectors */
    K_CON,        /* contag; 1 field, the argument -- or the n fields of an argument that is a tuple of n (CONN) */
    K_CLOSURE,    /* field 0 = the function index, an immediate; fields 1.. = environment */
    K_STRING,     /* len bytes */
    K_REF,        /* 1 field */
    K_ARRAY,      /* len fields */
    K_EXN,        /* 2 fields: constructor, payload */
    K_EXNCON,     /* 1 field: name string; identity is the address */
    K_FORWARD,    /* GC forwarding: first payload word is the new address */
    K_REAL,       /* a boxed real: 8 raw bytes, the double */
    K_BOX         /* an Int64.int or a Word64.word beyond 63 bits (an int or word too, under RUNE_INT64): 8 raw bytes */
};

struct Obj {
    uint8_t kind;
    uint8_t pad;
    uint16_t contag;
    uint32_t len;   /* number of fields, or byte length for strings; 1 for a box */
#ifdef RUNE_CENSUS
    uint64_t id;
#endif
    /* payload follows: Value fields[] or char bytes[] */
};

#define OBJ_FIELDS(o) ((Value *)((char *)(o) + sizeof(Obj)))
#define OBJ_BYTES(o) ((char *)(o) + sizeof(Obj))

/* the immediates: 63 bits, 2n+1 */
#define IMM_MIN (-(INT64_C(1) << 62))
#define IMM_MAX ((INT64_C(1) << 62) - 1)
static inline int int_fits(int64_t i) { return i >= IMM_MIN && i <= IMM_MAX; }
static inline int word_fits(uint64_t w) { return (w >> 63) == 0; }
static inline Value mk_imm(int64_t i) { return ((uint64_t)i << 1) | 1u; }
static inline Value mk_unit(void) { return 1; }
/* an int, a char, a constructor tag that fit: the callers know they do
   (a length, an index, a tag); arithmetic goes through mk_int_vm below */
static inline Value mk_int(int64_t i) { return mk_imm(i); }
static inline Value mk_char(int64_t c) { return mk_imm(c); }
static inline Value mk_con0(int64_t t) { return mk_imm(t); }
static inline Value mk_bool(int b) { return mk_imm(b ? 1 : 0); }
static inline Value mk_word(uint64_t w) { return mk_imm((int64_t)w); }
static inline Value mk_ptr(Obj *p) { return (Value)(uintptr_t)p; }

/* A real in the word (D3 C, by the rotation the gate of M4 chose:
   docs/plans/real-encoding.md): the double's bits with 2^61 added, rotated
   left by two. The sum's bit 62 lands in the word's low bit, and it is set
   for the exponents 0x200 to 0x5ff, a normal number from 2^-511 up to
   2^513: those are immediates, and each comes back bit for bit by the
   rotation and the subtraction. The rest -- zero, the subnormals, the
   infinities, NaN, the normals outside that range -- are boxes (K_REAL),
   and the ones met everywhere, +0.0 and -0.0, the two infinities and the
   quiet NaN of either sign, are each one box that the VM keeps
   (vm->real_boxes, made as it starts), so that none of them allocates. */
static inline uint64_t real_bits(double d) { uint64_t b; memcpy(&b, &d, 8); return b; }
static inline double real_of_bits(uint64_t b) { double d; memcpy(&d, &b, 8); return d; }
#define REAL_ROT_OFF ((uint64_t)1 << 61)
static inline int real_encode(double d, Value *v) {
    uint64_t u = real_bits(d) + REAL_ROT_OFF;
    u = (u << 2) | (u >> 62);
    if (!(u & 1)) return 0;
    *v = u;
    return 1;
}
static inline double real_decode(Value v) { return real_of_bits(((v >> 2) | (v << 62)) - REAL_ROT_OFF); }
/* the VM's boxes: which holds the double of these bits, or -1 */
enum { REAL_BOX_ZERO, REAL_BOX_NEG_ZERO, REAL_BOX_INF, REAL_BOX_NEG_INF, REAL_BOX_NAN, REAL_BOX_NEG_NAN, REAL_BOXES };
#define REAL_BOX_BITS { UINT64_C(0), UINT64_C(0x8000000000000000), UINT64_C(0x7FF0000000000000), UINT64_C(0xFFF0000000000000), \
                        UINT64_C(0x7FF8000000000000), UINT64_C(0xFFF8000000000000) }
static inline int real_box_of(uint64_t bits) {
    switch (bits) {
    case UINT64_C(0): return REAL_BOX_ZERO;
    case UINT64_C(0x8000000000000000): return REAL_BOX_NEG_ZERO;
    case UINT64_C(0x7FF0000000000000): return REAL_BOX_INF;
    case UINT64_C(0xFFF0000000000000): return REAL_BOX_NEG_INF;
    case UINT64_C(0x7FF8000000000000): return REAL_BOX_NAN;
    case UINT64_C(0xFFF8000000000000): return REAL_BOX_NEG_NAN;   /* what 0.0 / 0.0 is on x86 */
    default: return -1;
    }
}
/* a real as a value without allocating: 0 where it needs a box (a fast
   path answers 0 and the primitive boxes) */
static inline int mk_real_imm(double d, Value *v) {
#ifdef RUNE_REAL_BOXED
    (void)d; (void)v; return 0;
#else
    return real_encode(d, v);
#endif
}

/* ---- reading a value: the tag, and the payload as what the tag says ---- */
static inline int val_is_imm(Value v) { return (v & 1u) != 0; }
static inline Obj *val_ptr(Value v) { return (Obj *)(uintptr_t)v; }
static inline int obj_kind(const Obj *o);
/* the tag: T_INT for any immediate (the program knows which of int, char,
   tag or unit), T_REAL and T_INT for the boxes, T_PTR for a pointer */
static inline int val_tag(Value v) {
    if (val_is_imm(v)) return T_INT;
    if (v == 0) return T_PTR;
    int k = obj_kind(val_ptr(v));
    return k == K_REAL ? T_REAL : k == K_BOX ? T_INT : T_PTR;
}
/* a number of the 64-bit types: an immediate or its box */
static inline int val_is_num64(Value v) { return val_is_imm(v) || (v != 0 && obj_kind(val_ptr(v)) == K_BOX); }
static inline int val_is(Value v, int tag) {
    switch (tag) {
    case T_PTR: return val_tag(v) == T_PTR;   /* a pointer the program sees: not a box */
    case T_REAL: return val_is_imm(v) || (v != 0 && obj_kind(val_ptr(v)) == K_REAL);
    case T_INT64: case T_WORD64: return val_is_num64(v);
    default:
#ifdef RUNE_INT64
        return val_is_num64(v);
#else
        return val_is_imm(v);
#endif
    }
}
static inline int val_is_ptr(Value v) { return !val_is_imm(v) && v != 0; }
static inline const char *obj_bytes_c(const Obj *o);
static inline uint64_t box_bits(Value v) { uint64_t b; memcpy(&b, obj_bytes_c(val_ptr(v)), 8); return b; }
/* an Int64.int and a Word64.word: the immediate's payload, or the box's 64 bits */
static inline int64_t val_int64(Value v) { return val_is_imm(v) ? (int64_t)v >> 1 : (int64_t)box_bits(v); }
static inline uint64_t val_word64(Value v) { return val_is_imm(v) ? v >> 1 : box_bits(v); }
/* an int, a char or a nullary constructor's tag: the signed payload */
static inline int64_t val_imm(Value v) {
#ifdef RUNE_INT64
    if (!val_is_imm(v)) return (int64_t)box_bits(v);
#endif
    return (int64_t)v >> 1;
}
static inline int64_t val_int(Value v) { return val_imm(v); }
static inline int64_t val_char(Value v) { return (int64_t)v >> 1; }
static inline int64_t val_con0(Value v) { return (int64_t)v >> 1; }
static inline uint64_t val_word(Value v) {
#ifdef RUNE_INT64
    if (!val_is_imm(v)) return box_bits(v);
#endif
    return v >> 1;
}
/* a word read as the int of the same bits (Word.toIntX): the word's top bit is the sign */
static inline int64_t word_as_int(uint64_t w) {
#ifdef RUNE_INT64
    return (int64_t)w;
#else
    return (int64_t)(w << 1) >> 1;
#endif
}
static inline double val_real(Value v) { return val_is_imm(v) ? real_decode(v) : real_of_bits(box_bits(v)); }
/* the word itself: for an image, a hash, the census */
static inline uint64_t val_bits(Value v) { return v; }
/* a value from an image's tag and bits: an immediate's word as it was; a
   pointer's is the reader's to relocate */
static inline Value mk_tagged(int tag, uint64_t bits) { (void)tag; return bits; }
/* two values that are the same immediate (imm_eq; values_equal's case for
   the tags that are not a real or a pointer) */
static inline int val_same_imm(Value a, Value b) {
    if (a == b) return 1;
    /* two boxes of one number: an Int64.int or a Word64.word past 63 bits.
       An immediate is never the number of a box, so one of each is two
       numbers -- which their payloads read as signed would not say (a box
       of 2^64 - 1 and the immediate 2^63 - 1 are both ~1 that way). */
    if (!val_is_imm(a) && !val_is_imm(b) && a != 0 && b != 0
        && obj_kind(val_ptr(a)) == K_BOX && obj_kind(val_ptr(b)) == K_BOX)
        return box_bits(a) == box_bits(b);
    return 0;
}
/* whether a value's payload is what a pointer is not: needs no scan */
static inline int val_is_immediate(Value v) { return val_is_imm(v); }

/* ---- an object: the header and the fields ---- */
static inline int obj_kind(const Obj *o) { return o->kind; }
static inline uint32_t obj_len(const Obj *o) { return o->len; }
static inline uint16_t obj_contag(const Obj *o) { return o->contag; }
/* the header of a fresh object; the fields are the caller's to fill */
static inline void obj_init(Obj *o, int kind, uint16_t contag, uint32_t len) {
    o->kind = (uint8_t)kind;
    o->pad = 0;
    o->contag = contag;
    o->len = len;
}
static inline Value *obj_fields(Obj *o) { return OBJ_FIELDS(o); }
static inline const Value *obj_fields_c(const Obj *o) { return (const Value *)((const char *)(o) + sizeof(Obj)); }
static inline char *obj_bytes(Obj *o) { return OBJ_BYTES(o); }
static inline const char *obj_bytes_c(const Obj *o) { return (const char *)(o) + sizeof(Obj); }
static inline Value obj_field(const Obj *o, uint32_t i) { return obj_fields_c(o)[i]; }
/* a field of a fresh object, being filled: no barrier */
static inline void obj_fill_field(Obj *o, uint32_t i, Value v) { OBJ_FIELDS(o)[i] = v; }
/* a store into an object that exists (ref_set, array_update, SETENV): where
   a write barrier goes (docs/plans/heap-layout.md, D7); none today */
static inline void obj_set_field(Obj *o, uint32_t i, Value v) { OBJ_FIELDS(o)[i] = v; }
/* whether the object's payload holds values the collector follows */
static inline int obj_has_fields(const Obj *o) { return o->kind != K_STRING && o->kind != K_REAL && o->kind != K_BOX; }

/* ---- sizes ---- */
/* the payload of an object, rounded to what the heap allocates: PAYLOAD_MIN
   bytes at least, so that a forwarding pointer fits, and a multiple of
   PAYLOAD_ALIGN: a word each under this layout, so that an object is its
   header and its fields, 8-aligned, and the least one 16 bytes (runeopt's
   image reader has the same numbers through src/opt/x64_layout.sml) */
#define PAYLOAD_ALIGN 8
#define PAYLOAD_MIN 8
static inline size_t payload_size(size_t bytes) {
    size_t r = (bytes + PAYLOAD_ALIGN - 1) & ~(size_t)(PAYLOAD_ALIGN - 1);
    return r < PAYLOAD_MIN ? PAYLOAD_MIN : r;
}
/* the payload a new object of kind and len needs, before rounding */
static inline size_t obj_payload_bytes(int kind, uint32_t len) {
    return kind == K_STRING ? (size_t)len : (kind == K_REAL || kind == K_BOX) ? 8 : (size_t)len * sizeof(Value);
}
static inline size_t obj_size_of(int kind, uint32_t len) { return sizeof(Obj) + payload_size(obj_payload_bytes(kind, len)); }
/* what the heap gives an object of that payload: the header and the rounded payload */
static inline size_t obj_alloc_size(size_t payload_bytes) { return sizeof(Obj) + payload_size(payload_bytes); }
/* the same as constant expressions (a case label): the size of an object of n fields */
#define PAYLOAD_SIZE_CONST(b) (((b) + PAYLOAD_ALIGN - 1) / PAYLOAD_ALIGN * PAYLOAD_ALIGN < PAYLOAD_MIN ? PAYLOAD_MIN : ((b) + PAYLOAD_ALIGN - 1) / PAYLOAD_ALIGN * PAYLOAD_ALIGN)
#define OBJ_SIZE_FIELDS(n) (sizeof(Obj) + PAYLOAD_SIZE_CONST((n) * sizeof(Value)))
/* the least an object takes: its header (an image's scan stops short of one) */
#define OBJ_HEADER_SIZE sizeof(Obj)

/* ---- what needs the heap (runtime/heap.c): a real or an int that does not fit the word ---- */
struct VM;
Value mk_real(struct VM *vm, double d);          /* encoded, or a K_REAL box: the VM's own for zero, the infinities and NaN */
Value mk_int_vm(struct VM *vm, int64_t i);       /* an int: an immediate; one that does not fit is a fatal error (the callers keep to 63 bits), or a K_BOX under RUNE_INT64 */
Value mk_word_vm(struct VM *vm, uint64_t w);     /* a word: its low 63 bits; or all 64, with a K_BOX, under RUNE_INT64 */
Value mk_int64_vm(struct VM *vm, int64_t i);     /* an Int64.int: an immediate, or a K_BOX */
Value mk_word64_vm(struct VM *vm, uint64_t w);   /* a Word64.word: an immediate, or a K_BOX */
Value mk_box_vm(struct VM *vm, uint64_t bits);   /* the K_BOX of a number that has no immediate */

/* ---- forwarding (runtime/heap.c): a copied object points at its copy ---- */
static inline int obj_forwarded(const Obj *o) { return o->kind == K_FORWARD; }
static inline Obj *obj_forwarding(const Obj *o) { Obj *n; memcpy(&n, obj_bytes_c(o), sizeof n); return n; }
static inline void obj_forward(Obj *o, Obj *to) { o->kind = K_FORWARD; memcpy(OBJ_BYTES(o), &to, sizeof to); }

#endif
