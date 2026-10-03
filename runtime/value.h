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


enum Tag { T_UNIT = 0, T_INT, T_WORD, T_REAL, T_CHAR, T_CON0, T_PTR };

typedef struct Obj Obj;

/* THE TAGGED WORD (heap-layout M4, prototype 1: D1 B, D2 B or A, D3 C or B).
   A Value is one 64-bit word. Its low bit says what it is:
     1  an immediate: an int, a char, a constructor tag or unit as 2n+1
        (63 bits; unit is 1), or a real in Koka's encoding (below);
     0  a pointer to an object, 8-byte aligned, or NULL (0).
   The type of an immediate is the program's, not the word's: an int and a
   char with the same payload are the same word, which SML's typing keeps
   apart. What does not fit the word is a small object: a real outside the
   encoding's range is a K_REAL box, and, under RUNE_INT64 (D2 A: 64-bit
   integers and words kept), an int or word beyond 63 bits is a K_BOX; the
   readers test for the box. Without RUNE_INT64 (D2 B, the decision) an int
   is 63 bits and Overflow is raised where a 64th bit would be, and a word
   is 63 bits and wraps there. Under RUNE_REAL_BOXED (D3 B) every real that
   reaches a value is boxed. */
typedef uint64_t Value;
#define RUNE_VALUE_HDR 0
/* The prototype builds with 64-bit integers kept (D2 A) unless RUNE_INT63
   is given: the Basis Library still names 64 bits (Int.minInt, Word.wordSize)
   and the 63-bit build (D2 B) needs it at 63, which is M5's. */
#if !defined(RUNE_INT63) && !defined(RUNE_INT64)
#define RUNE_INT64 1
#endif
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
    K_BOX         /* a boxed int or word beyond 63 bits (RUNE_INT64): 8 raw bytes */
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

/* Koka's encoding of a double in 63 bits (kklib/src/box.c, strategy A1): the
   sign and the 11-bit exponent rotated to the bottom, the exponent squeezed
   to 10 bits -- zero and subnormals keep 0, infinity and NaN take 0x3ff, a
   normal in [2^-510, 2^512) has 0x200 taken off -- then the low bit set. The
   52 mantissa bits and the sign travel whole, so every encodable double
   comes back bit for bit; the rest are boxed (K_REAL). */
static inline uint64_t real_bits(double d) { uint64_t b; memcpy(&b, &d, 8); return b; }
static inline double real_of_bits(uint64_t b) { double d; memcpy(&d, &b, 8); return d; }
static inline int real_encode(double d, Value *v) {
    uint64_t u = real_bits(d);
    u = (u << 12) | (u >> 52);
    uint64_t e = u & 0x7ff;
    u -= e;
    if (e == 0) { }
    else if (e == 0x7ff) e = 0x3ff;
    else if (e > 0x200 && e < 0x5ff) e -= 0x200;
    else return 0;
    *v = (u & ~(uint64_t)0x7ff) | (e << 1) | 1u;
    return 1;
}
static inline double real_decode(Value v) {
    uint64_t e = (v >> 1) & 0x3ff;
    if (e == 0) { }
    else if (e == 0x3ff) e = 0x7ff;
    else e += 0x200;
    uint64_t u = (v & ~(uint64_t)0x7ff) | e;
    return real_of_bits((u >> 12) | (u << 52));
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
static inline int val_is(Value v, int tag) {
    switch (tag) {
    case T_PTR: return val_tag(v) == T_PTR;   /* a pointer the program sees: not a box */
    case T_REAL: return val_is_imm(v) || (v != 0 && obj_kind(val_ptr(v)) == K_REAL);
    default:
#ifdef RUNE_INT64
        return val_is_imm(v) || (v != 0 && obj_kind(val_ptr(v)) == K_BOX);
#else
        return val_is_imm(v);
#endif
    }
}
static inline int val_is_ptr(Value v) { return !val_is_imm(v) && v != 0; }
static inline const char *obj_bytes_c(const Obj *o);
static inline uint64_t box_bits(Value v) { uint64_t b; memcpy(&b, obj_bytes_c(val_ptr(v)), 8); return b; }
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
static inline double val_real(Value v) { return val_is_imm(v) ? real_decode(v) : real_of_bits(box_bits(v)); }
/* the word itself: for an image, a hash, the census */
static inline uint64_t val_bits(Value v) { return v; }
/* a value from an image's tag and bits: an immediate's word as it was; a
   pointer's is the reader's to relocate */
static inline Value mk_tagged(int tag, uint64_t bits) { (void)tag; return bits; }
/* two values that are the same immediate (imm_eq; values_equal's case for
   the tags that are not a real or a pointer) */
static inline int val_same_imm(Value a, Value b) { return a == b; }
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
Value mk_real(struct VM *vm, double d);          /* encoded, or a K_REAL box */
Value mk_int_vm(struct VM *vm, int64_t i);       /* an immediate, or under RUNE_INT64 a K_BOX; without it, a fatal error: the callers keep to 63 bits */
Value mk_word_vm(struct VM *vm, uint64_t w);     /* an immediate, or a K_BOX under RUNE_INT64; without it the word's low 63 bits */

/* ---- forwarding (runtime/heap.c): a copied object points at its copy ---- */
static inline int obj_forwarded(const Obj *o) { return o->kind == K_FORWARD; }
static inline Obj *obj_forwarding(const Obj *o) { Obj *n; memcpy(&n, obj_bytes_c(o), sizeof n); return n; }
static inline void obj_forward(Obj *o, Obj *to) { o->kind = K_FORWARD; memcpy(OBJ_BYTES(o), &to, sizeof to); }

#endif
