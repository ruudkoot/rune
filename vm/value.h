/* vm/value.h -- THE LAYOUT (docs/plans/heap-layout.md, *The architecture*,
   M3): how a value is represented and how an object is laid out, in one
   place. Every test of a tag, every construction of a value, every unboxing
   of a payload, every read and write of a header, every field access, the
   size of an object and its forwarding, and the image's encoding of a value
   are the functions here, and nothing outside this header names a tag
   byte, a header field or an offset: vm/prims.c, vm/runtime.c, vm/heap.c,
   vm/image.c, vm/loader.c, the loops (src/isa/stack.sml and regs.sml, whose
   bodies are C) and vm/new/fastprim.h are written over these names. The
   JIT's macro-assembler (vm/new/jit/masm.c) is the same operations as
   machine code, and runeopt's templates are generated from it
   (src/opt/x64_layout.sml). A change of layout is a change here and in
   masm.c, and nowhere else; vm/native_offsets.h names what the generated
   code needs of it.

   Today's layout: a Value is 16 bytes -- a tag byte (enum Tag), seven bytes
   of padding and an 8-byte payload -- and an object has an 8-byte header
   (kind, pad, contag, len) and a payload of Values, or of bytes for a
   string, rounded up to 16 bytes and at least 16 (a forwarding pointer
   fits). Included by vm.h; the census VM's header is one word longer
   (vm/census.h). */
#ifndef RUNE_VALUE_H
#define RUNE_VALUE_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>


enum Tag { T_UNIT = 0, T_INT, T_WORD, T_REAL, T_CHAR, T_CON0, T_PTR };

typedef struct Obj Obj;

/* 16 bytes on every VM, which the heap's layout and the counts of --count
   both depend on and an image relies on (vm/image.c). The padding is written
   out rather than left to the machine: the i386 System V ABI aligns an
   `int64_t` to 4, where x86-64, PowerPC and the Windows compilers align it to
   8, and without this a Value is 12 bytes there and every object of the heap
   a different size (make test-portability). A narrower Value on 32-bit
   machines would save 0.46% of the heap and cost more than that: the reasons
   are written down under "8-byte values" in docs/plans/performance.md,
   which is also where the padding of the payload is weighed.

   The tag and its padding are also one 64-bit word, the header (hdr), so
   that a value made by mk_int and the others is two words in two registers
   and is stored in two stores. Built a byte at a time it goes through
   memory, and the 16-byte load that copies it then waits tens of cycles for
   the byte store to retire (docs/plans/jit.md, M2). That takes an unnamed
   member, which C11 has: a compiler without it gets the byte alone and the
   same layout. */
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L && defined(__BYTE_ORDER__)
#define RUNE_VALUE_HDR 1
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#define VALUE_HDR(t) ((uint64_t)(t) << 56)   /* the tag is the first byte, whichever end that is */
#else
#define VALUE_HDR(t) ((uint64_t)(t))
#endif
typedef struct Value {
    union {
        struct {
            uint8_t tag;
            uint8_t pad[7];
        };
        uint64_t hdr;
    };
    union {
        int64_t i;   /* T_INT, T_CHAR, T_CON0 (constructor tag) */
        uint64_t w;  /* T_WORD */
        double d;    /* T_REAL */
        Obj *p;      /* T_PTR */
    } u;
} Value;
#else
#define RUNE_VALUE_HDR 0
typedef struct Value {
    uint8_t tag;
    uint8_t pad[7];
    union {
        int64_t i;   /* T_INT, T_CHAR, T_CON0 (constructor tag) */
        uint64_t w;  /* T_WORD */
        double d;    /* T_REAL */
        Obj *p;      /* T_PTR */
    } u;
} Value;
#endif

enum ObjKind {
    K_TUPLE = 1,  /* len fields; also vectors */
    K_CON,        /* contag; 1 field, the argument -- or the n fields of an argument that is a tuple of n (CONN) */
    K_CLOSURE,    /* field 0 = T_INT function index; fields 1.. = environment */
    K_STRING,     /* len bytes */
    K_REF,        /* 1 field */
    K_ARRAY,      /* len fields */
    K_EXN,        /* 2 fields: constructor, payload */
    K_EXNCON,     /* 1 field: name string; identity is the address */
    K_FORWARD     /* GC forwarding: first payload word is the new address */
};

struct Obj {
    uint8_t kind;
    uint8_t pad;
    uint16_t contag;
    uint32_t len;   /* number of fields, or byte length for strings */
#ifdef RUNE_CENSUS
    uint64_t id;    /* the census VM (vm/census.h): the object's number in allocation order */
#endif
    /* payload follows: Value fields[] or char bytes[] */
};

#define OBJ_FIELDS(o) ((Value *)((char *)(o) + sizeof(Obj)))
#define OBJ_BYTES(o) ((char *)(o) + sizeof(Obj))

#if RUNE_VALUE_HDR
#define RUNE_MK(t, field, x) Value v; v.hdr = VALUE_HDR(t); v.u.field = (x); return v
#else
#define RUNE_MK(t, field, x) Value v; v.tag = (t); v.u.field = (x); return v
#endif
static inline Value mk_unit(void) { RUNE_MK(T_UNIT, i, 0); }
static inline Value mk_int(int64_t i) { RUNE_MK(T_INT, i, i); }
static inline Value mk_word(uint64_t w) { RUNE_MK(T_WORD, w, w); }
static inline Value mk_real(double d) { RUNE_MK(T_REAL, d, d); }
static inline Value mk_char(int64_t c) { RUNE_MK(T_CHAR, i, c); }
static inline Value mk_con0(int64_t t) { RUNE_MK(T_CON0, i, t); }
static inline Value mk_ptr(Obj *p) { RUNE_MK(T_PTR, p, p); }
#undef RUNE_MK
static inline Value mk_bool(int b) { return mk_con0(b ? 1 : 0); }

/* ---- reading a value: the tag, and the payload as what the tag says ---- */
static inline int val_tag(Value v) { return v.tag; }
static inline int val_is(Value v, int tag) { return v.tag == tag; }
static inline int val_is_ptr(Value v) { return v.tag == T_PTR; }
/* an int, a char or a nullary constructor's tag: the signed payload */
static inline int64_t val_imm(Value v) { return v.u.i; }
static inline int64_t val_int(Value v) { return v.u.i; }
static inline int64_t val_char(Value v) { return v.u.i; }
static inline int64_t val_con0(Value v) { return v.u.i; }
static inline uint64_t val_word(Value v) { return v.u.w; }
static inline double val_real(Value v) { return v.u.d; }
static inline Obj *val_ptr(Value v) { return v.u.p; }
/* the payload's 64 bits, whatever the tag: for an image, a hash, the census */
static inline uint64_t val_bits(Value v) { return v.u.w; }
/* a value from a tag and its payload's bits (an image, the loader) */
static inline Value mk_tagged(int tag, uint64_t bits) {
    Value v;
#if RUNE_VALUE_HDR
    v.hdr = VALUE_HDR(tag);
#else
    v.tag = (uint8_t)tag;
    memset(v.pad, 0, sizeof v.pad);
#endif
    v.u.w = bits;
    return v;
}
/* two values that are the same immediate: the same tag and payload (imm_eq;
   values_equal's case for the tags that are not a real or a pointer) */
static inline int val_same_imm(Value a, Value b) { return a.tag == b.tag && a.u.w == b.u.w; }
/* whether a value's payload is what a pointer is not: needs no scan */
static inline int val_is_immediate(Value v) { return v.tag != T_PTR; }

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
static inline int obj_has_fields(const Obj *o) { return o->kind != K_STRING; }

/* ---- sizes ---- */
/* the payload of an object, rounded to what the heap allocates: PAYLOAD_MIN
   bytes at least, so that a forwarding pointer fits, and a multiple of
   PAYLOAD_ALIGN (runeopt's image reader has the same numbers through
   src/opt/x64_layout.sml) */
#define PAYLOAD_ALIGN 16
#define PAYLOAD_MIN 16
static inline size_t payload_size(size_t bytes) {
    size_t r = (bytes + PAYLOAD_ALIGN - 1) & ~(size_t)(PAYLOAD_ALIGN - 1);
    return r < PAYLOAD_MIN ? PAYLOAD_MIN : r;
}
/* the payload a new object of kind and len needs, before rounding */
static inline size_t obj_payload_bytes(int kind, uint32_t len) {
    return kind == K_STRING ? (size_t)len : (size_t)len * sizeof(Value);
}
static inline size_t obj_size_of(int kind, uint32_t len) { return sizeof(Obj) + payload_size(obj_payload_bytes(kind, len)); }
/* what the heap gives an object of that payload: the header and the rounded payload */
static inline size_t obj_alloc_size(size_t payload_bytes) { return sizeof(Obj) + payload_size(payload_bytes); }
/* the same as constant expressions (a case label): the size of an object of n fields */
#define PAYLOAD_SIZE_CONST(b) (((b) + PAYLOAD_ALIGN - 1) / PAYLOAD_ALIGN * PAYLOAD_ALIGN < PAYLOAD_MIN ? PAYLOAD_MIN : ((b) + PAYLOAD_ALIGN - 1) / PAYLOAD_ALIGN * PAYLOAD_ALIGN)
#define OBJ_SIZE_FIELDS(n) (sizeof(Obj) + PAYLOAD_SIZE_CONST((n) * sizeof(Value)))
/* the least an object takes: its header (an image's scan stops short of one) */
#define OBJ_HEADER_SIZE sizeof(Obj)

/* ---- forwarding (vm/heap.c): a copied object points at its copy ---- */
static inline int obj_forwarded(const Obj *o) { return o->kind == K_FORWARD; }
static inline Obj *obj_forwarding(const Obj *o) { Obj *n; memcpy(&n, obj_bytes_c(o), sizeof n); return n; }
static inline void obj_forward(Obj *o, Obj *to) { o->kind = K_FORWARD; memcpy(OBJ_BYTES(o), &to, sizeof to); }

#endif
