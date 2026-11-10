/* Optional GMP arithmetic over Rune-owned, immutable magnitude bytes.
   No GMP object or allocation survives a returning primitive call. */
#include "intinf.h"
#include <limits.h>

/* ---- IntInf.int's arithmetic (haskell98 M31) ----
   A value of IntInf.int is an immediate where its number fits the word's
   63 bits, and otherwise a K_TUPLE of two fields: whether it is negative,
   and its magnitude, a K_STRING of little-endian bytes with no high zero
   byte, larger than every immediate's (intinf.h). The primitives' slow
   paths (runtime/prims.c) come here. A number is worked on as 32-bit
   digits in C memory, read from the arguments before anything is
   allocated in the heap and freed before the primitive returns, so no
   heap pointer is held across an allocation and no byte order of the
   machine is part of a value. GMP's multiplication and division are used
   where the VM selects GMP and an operand is large (gmp_arith below). */
typedef struct Big {
    uint32_t *d;           /* the digits, least significant first; d[n - 1] != 0 */
    size_t n;
    int neg;               /* 0 for zero */
    uint32_t local[4];     /* d for four digits or fewer */
} Big;

static void big_init(Big *b) { b->d = b->local; b->n = 0; b->neg = 0; }
static void big_free(Big *b) { if (b->d != b->local) free(b->d); b->d = b->local; b->n = 0; }
/* room for n digits, zeroed */
static uint32_t *big_room(VM *vm, Big *b, size_t n) {
    big_free(b);
    if (n <= 4) { memset(b->local, 0, sizeof b->local); return b->d; }
    uint32_t *d = calloc(n, sizeof *d);
    if (!d) vm_limit(vm, "intinf scratch allocation failed");
    b->d = d;
    return d;
}
static void big_trim(Big *b) {
    while (b->n && b->d[b->n - 1] == 0) b->n--;
    if (!b->n) b->neg = 0;
}
static void big_of_int64(Big *b, int64_t x) {
    uint64_t m = x < 0 ? (uint64_t)0 - (uint64_t)x : (uint64_t)x;
    big_init(b);
    b->local[0] = (uint32_t)m;
    b->local[1] = (uint32_t)(m >> 32);
    b->n = 2;
    b->neg = x < 0;
    big_trim(b);
}
static unsigned bit_length32(uint32_t x) { unsigned n = 0; while (x) { n++; x >>= 1; } return n; }
static uint64_t big_bits(const Big *b) { return b->n ? ((uint64_t)b->n - 1) * 32 + bit_length32(b->d[b->n - 1]) : 0; }

/* Whether a sign and a canonical magnitude of so many bits are a number an
   immediate holds: the immediates run from -2^62 to 2^62 - 1. */
static int fits_immediate(int neg, const unsigned char *bytes, uint32_t length, uint64_t bits) {
    if (bits < 63) return 1;
    if (bits > 63 || !neg) return 0;
    for (uint32_t i = 0; i + 1 < length; i++) if (bytes[i]) return 0;
    return bytes[length - 1] == 0x40;   /* 2^62 exactly */
}

/* The bits of a magnitude string, checked: a string with no high zero
   byte, within the budget. What is wrong is a bytecode error. */
static uint64_t magnitude_bits(VM *vm, Value value, const char *prim) {
    if (!val_is(value, T_PTR) || obj_kind(val_ptr(value)) != K_STRING)
        vm_fatal(vm, "primitive %s: wrong magnitude type", prim);
    Obj *s = val_ptr(value);
    const unsigned char *bytes = (const unsigned char *)obj_bytes(s);
    uint32_t length = obj_len(s);
    if (!length) return 0;
    if (bytes[length - 1] == 0) vm_fatal(vm, "primitive %s: noncanonical magnitude", prim);
    uint64_t bits = ((uint64_t)length - 1) * 8 + bit_length32(bytes[length - 1]);
    vm_intinf_check(vm, bits);
    return bits;
}

/* The pair of a large value, its sign read; a bytecode error where v is
   no IntInf.int, or a pair an immediate would hold. */
static Obj *large_pair(VM *vm, Value v, int *neg, uint64_t *bits, const char *prim) {
    if (!val_is_ptr(v) || obj_kind(val_ptr(v)) != K_TUPLE || obj_len(val_ptr(v)) != 2)
        vm_fatal(vm, "primitive %s: wrong argument type", prim);
    Obj *pair = val_ptr(v);
    Value sign = obj_field(pair, 0);
    if (!val_is_imm(sign) || (val_imm(sign) != 0 && val_imm(sign) != 1))
        vm_fatal(vm, "primitive %s: wrong argument type", prim);
    *neg = (int)val_imm(sign);
    *bits = magnitude_bits(vm, obj_field(pair, 1), prim);
    Obj *s = val_ptr(obj_field(pair, 1));
    if (fits_immediate(*neg, (const unsigned char *)obj_bytes(s), obj_len(s), *bits))
        vm_fatal(vm, "primitive %s: a large IntInf.int that an immediate holds", prim);
    return pair;
}

/* An IntInf.int's number as digits. */
static void big_of_value(VM *vm, Big *b, Value v, const char *prim) {
    if (val_is_imm(v)) { big_of_int64(b, val_imm(v)); return; }
    int neg;
    uint64_t bits;
    Obj *pair = large_pair(vm, v, &neg, &bits, prim);
    Obj *s = val_ptr(obj_field(pair, 1));
    const unsigned char *bytes = (const unsigned char *)obj_bytes(s);
    uint32_t length = obj_len(s);
    big_init(b);
    size_t n = ((size_t)length + 3) / 4;
    uint32_t *d = big_room(vm, b, n);
    for (uint32_t i = 0; i < length; i++) d[i / 4] |= (uint32_t)bytes[i] << (8 * (i % 4));
    b->n = n;
    b->neg = neg;
    big_trim(b);
}

/* The IntInf.int of a number: an immediate where it fits, else a pair
   made within the budget. */
static Value big_value(VM *vm, Big *b) {
    big_trim(b);
    if (b->n <= 2) {
        uint64_t m = (b->n > 0 ? (uint64_t)b->d[0] : 0) | (b->n > 1 ? (uint64_t)b->d[1] << 32 : 0);
        if (!b->neg && m <= (uint64_t)IMM_MAX) return mk_imm((int64_t)m);
        if (b->neg && m <= (uint64_t)IMM_MAX + 1) return mk_imm(-(int64_t)m);
    }
    uint64_t bits = big_bits(b);
    vm_intinf_check(vm, bits);
    uint64_t length = (bits + 7) / 8;
    if (length > UINT32_C(0x3fffffff)) vm_limit(vm, "intinf magnitude exceeds string representation");
    Obj *s = vm_alloc_string(vm, (uint32_t)length);
    unsigned char *bytes = (unsigned char *)obj_bytes(s);
    for (uint64_t i = 0; i < length; i++) bytes[i] = (unsigned char)(b->d[i / 4] >> (8 * (i % 4)));
    vm_push(vm, mk_ptr(s));
    Obj *pair = vm_alloc_fields(vm, K_TUPLE, 0, 2);
    obj_fill_field(pair, 0, mk_bool(b->neg));
    obj_fill_field(pair, 1, vm_pop(vm));
    return mk_ptr(pair);
}

static int mag_cmp(const Big *a, const Big *b) {
    if (a->n != b->n) return a->n < b->n ? -1 : 1;
    for (size_t i = a->n; i-- > 0;)
        if (a->d[i] != b->d[i]) return a->d[i] < b->d[i] ? -1 : 1;
    return 0;
}
/* r := |a| + |b| */
static void mag_add(VM *vm, Big *r, const Big *a, const Big *b) {
    if (a->n < b->n) { const Big *t = a; a = b; b = t; }
    uint32_t *d = big_room(vm, r, a->n + 1);
    uint64_t k = 0;
    for (size_t i = 0; i < a->n; i++) {
        uint64_t t = (uint64_t)a->d[i] + (i < b->n ? b->d[i] : 0) + k;
        d[i] = (uint32_t)t;
        k = t >> 32;
    }
    d[a->n] = (uint32_t)k;
    r->n = a->n + 1;
}
/* r := |a| - |b|, where |a| >= |b| */
static void mag_sub(VM *vm, Big *r, const Big *a, const Big *b) {
    uint32_t *d = big_room(vm, r, a->n);
    uint64_t borrow = 0;
    for (size_t i = 0; i < a->n; i++) {
        uint64_t t = (uint64_t)a->d[i] - (i < b->n ? b->d[i] : 0) - borrow;
        d[i] = (uint32_t)t;
        borrow = (t >> 32) & 1;
    }
    r->n = a->n;
}
/* r := a + b, or a - b where negate */
static void big_addsub(VM *vm, Big *r, const Big *a, const Big *b, int negate) {
    int bneg = b->n ? b->neg ^ negate : 0;
    if (a->neg == bneg) { mag_add(vm, r, a, b); r->neg = a->neg; }
    else if (mag_cmp(a, b) >= 0) { mag_sub(vm, r, a, b); r->neg = a->neg; }
    else { mag_sub(vm, r, b, a); r->neg = bneg; }
    big_trim(r);
}
/* r := a * b, schoolbook; the budget is checked first, by the least size
   of the product */
static void big_mul(VM *vm, Big *r, const Big *a, const Big *b) {
    if (!a->n || !b->n) { big_free(r); r->neg = 0; return; }
    vm_intinf_check(vm, big_bits(a) + big_bits(b) - 1);
    uint32_t *d = big_room(vm, r, a->n + b->n);
    for (size_t i = 0; i < a->n; i++) {
        uint64_t k = 0;
        for (size_t j = 0; j < b->n; j++) {
            uint64_t t = (uint64_t)a->d[i] * b->d[j] + d[i + j] + k;
            d[i + j] = (uint32_t)t;
            k = t >> 32;
        }
        d[i + b->n] = (uint32_t)k;
    }
    r->n = a->n + b->n;
    r->neg = a->neg ^ b->neg;
    big_trim(r);
}
/* q := |a| / |b| and r := |a| mod |b|, for b nonzero: Knuth's algorithm D
   (The Art of Computer Programming, 4.3.1), as Warren's Hacker's Delight
   writes it (divmnu) for 32-bit digits; signs are the caller's */
static void mag_divmod(VM *vm, Big *q, Big *r, const Big *a, const Big *b) {
    size_t m = a->n, n = b->n;
    if (m < n) {
        big_free(q);
        uint32_t *d = big_room(vm, r, m);
        memcpy(d, a->d, m * sizeof *d);
        r->n = m;
        return;
    }
    uint32_t *qd = big_room(vm, q, m - n + 1);
    q->n = m - n + 1;
    if (n == 1) {
        uint64_t k = 0, v = b->d[0];
        for (size_t j = m; j-- > 0;) {
            uint64_t t = (k << 32) | a->d[j];
            qd[j] = (uint32_t)(t / v);
            k = t % v;
        }
        uint32_t *rd = big_room(vm, r, 1);
        rd[0] = (uint32_t)k;
        r->n = 1;
        return;
    }
    const uint64_t base = UINT64_C(1) << 32;
    unsigned s = 32 - bit_length32(b->d[n - 1]);   /* 0 to 31: the divisor's top digit normalised */
    Big vb, ub;
    big_init(&vb); big_init(&ub);
    uint32_t *vn = big_room(vm, &vb, n), *un = big_room(vm, &ub, m + 1);
    for (size_t i = n - 1; i > 0; i--) vn[i] = (uint32_t)(((uint64_t)b->d[i] << s) | ((uint64_t)b->d[i - 1] >> (32 - s)));
    vn[0] = (uint32_t)((uint64_t)b->d[0] << s);
    un[m] = (uint32_t)((uint64_t)a->d[m - 1] >> (32 - s));
    for (size_t i = m - 1; i > 0; i--) un[i] = (uint32_t)(((uint64_t)a->d[i] << s) | ((uint64_t)a->d[i - 1] >> (32 - s)));
    un[0] = (uint32_t)((uint64_t)a->d[0] << s);
    for (size_t j = m - n + 1; j-- > 0;) {
        uint64_t num = ((uint64_t)un[j + n] << 32) | un[j + n - 1];
        uint64_t qhat = num / vn[n - 1], rhat = num % vn[n - 1];
        while (qhat >= base || qhat * vn[n - 2] > ((rhat << 32) | un[j + n - 2])) {
            qhat--;
            rhat += vn[n - 1];
            if (rhat >= base) break;
        }
        /* un[j..j+n] -= qhat * vn, in unsigned words: a borrow is a
           difference that wrapped, whose high half is then nonzero */
        uint64_t carry = 0, borrow = 0, t;
        for (size_t i = 0; i < n; i++) {
            uint64_t p = qhat * vn[i] + carry;
            carry = p >> 32;
            t = (uint64_t)un[i + j] - (p & 0xFFFFFFFFu) - borrow;
            un[i + j] = (uint32_t)t;
            borrow = (t >> 32) != 0;
        }
        t = (uint64_t)un[j + n] - carry - borrow;
        un[j + n] = (uint32_t)t;
        qd[j] = (uint32_t)qhat;
        if ((t >> 32) != 0) {   /* subtracted once too often: add the divisor back */
            qd[j]--;
            uint64_t c = 0;
            for (size_t i = 0; i < n; i++) {
                uint64_t u = (uint64_t)un[i + j] + vn[i] + c;
                un[i + j] = (uint32_t)u;
                c = u >> 32;
            }
            un[j + n] = (uint32_t)((uint64_t)un[j + n] + c);
        }
    }
    uint32_t *rd = big_room(vm, r, n);
    for (size_t i = 0; i + 1 < n; i++) rd[i] = (uint32_t)(((uint64_t)un[i] >> s) | ((uint64_t)un[i + 1] << (32 - s)));
    rd[n - 1] = (uint32_t)((uint64_t)un[n - 1] >> s);
    r->n = n;
    big_free(&vb); big_free(&ub);
}
/* q and r of a by b, nonzero: truncating, or by the floor */
static void big_divmod(VM *vm, Big *q, Big *r, const Big *a, const Big *b, int floor) {
    mag_divmod(vm, q, r, a, b);
    q->neg = a->neg ^ b->neg;
    r->neg = a->neg;
    big_trim(q); big_trim(r);
    if (floor && r->n && a->neg != b->neg) {
        /* a negative quotient one less, and a remainder of b's sign: q - 1, r + b */
        Big one, t;
        big_of_int64(&one, 1);
        big_init(&t);
        big_addsub(vm, &t, q, &one, 1);
        big_free(q); *q = t; if (q->d == t.local) q->d = q->local;
        big_init(&t);
        big_addsub(vm, &t, r, b, 0);
        big_free(r); *r = t; if (r->d == t.local) r->d = r->local;
    }
}

size_t vm_intinf_max_bits(const VM *vm) {
    return vm->intinf_max_bits ? vm->intinf_max_bits : INTINF_DEFAULT_BITS;
}
size_t vm_intinf_gmp_memory(const VM *vm) {
    return vm->intinf_gmp_memory ? vm->intinf_gmp_memory : INTINF_DEFAULT_GMP_MEMORY;
}
void vm_intinf_check(VM *vm, uint64_t bits) {
    if (bits > vm_intinf_max_bits(vm))
        vm_limit(vm, "intinf magnitude limit exceeded (--intinf-max-bits)");
}
int vm_intinf_mode(const char *text, int *mode) {
    if (strcmp(text, "auto") == 0) *mode = INTINF_AUTO;
    else if (strcmp(text, "sml") == 0) *mode = INTINF_SML;
    else if (strcmp(text, "gmp") == 0) *mode = INTINF_GMP;
    else return 0;
    return 1;
}

uint64_t vm_intinf_validate(VM *vm, Value value, int negative) {
    if (!val_is(value, T_PTR) || obj_kind(val_ptr(value)) != K_STRING)
        vm_fatal(vm, "intinf GMP primitive: wrong magnitude type");
    Obj *s = val_ptr(value);
    const unsigned char *bytes = (const unsigned char *)obj_bytes(s);
    uint32_t length = obj_len(s);
    if (length && bytes[length - 1] == 0)
        vm_fatal(vm, "intinf GMP primitive: noncanonical magnitude");
    if (!length && negative) vm_fatal(vm, "intinf GMP primitive: negative zero");
    uint64_t bits = 0;
    if (length) {
        unsigned top = bytes[length - 1], top_bits = 0;
        while (top) { top >>= 1; top_bits++; }
        bits = ((uint64_t)length - 1) * 8 + top_bits;
    }
    vm_intinf_check(vm, bits);
    return bits;
}

#if defined(RUNE_HAVE_GMP) && RUNE_HAVE_GMP
#include <gmp.h>
#if __GNU_MP_VERSION < 6 || (__GNU_MP_VERSION == 6 && __GNU_MP_VERSION_MINOR < 3)
#error GMP 6.3.0 or newer is required
#endif

/* GMP's hooks are process-global. Rune currently has one executing VM and
   no concurrent runtime threads. Install before creating any GMP object;
   embedding with other GMP users needs an allocator-ownership protocol. */
static VM *active;
static int installed;
static int supported_cache = -1;

static int supported(void) {
    if (supported_cache < 0) {
        unsigned major = 0, minor = 0, patch = 0;
        supported_cache = sscanf(gmp_version, "%u.%u.%u", &major, &minor, &patch) == 3 &&
            (major > 6 || (major == 6 && minor >= 3)) && major == __GNU_MP_VERSION &&
            mp_bits_per_limb == GMP_NUMB_BITS && GMP_NAIL_BITS == 0;
    }
    return supported_cache;
}
static VM *allocation_vm(void) {
    if (!active) {
        fputs("runevm: GMP allocation outside an intinf primitive\n", stderr);
        abort();
    }
    return active;
}
static size_t charged(size_t size) { return size ? size : 1; }
static void total(VM *vm, size_t size) {
    if (vm->intinf_gmp_allocations != UINT64_MAX) vm->intinf_gmp_allocations++;
    vm->intinf_gmp_allocated = size > UINT64_MAX - vm->intinf_gmp_allocated
        ? UINT64_MAX : vm->intinf_gmp_allocated + size;
    if (vm->intinf_gmp_live > vm->intinf_gmp_peak) vm->intinf_gmp_peak = vm->intinf_gmp_live;
}
static void *allocate(size_t size) {
    VM *vm = allocation_vm();
    size = charged(size);
    size_t limit = vm_intinf_gmp_memory(vm);
    if (vm->intinf_gmp_live > limit || size > limit - vm->intinf_gmp_live)
        vm_limit(vm, "intinf GMP memory limit exceeded (--intinf-gmp-memory)");
    void *p = malloc(size);
    if (!p) vm_limit(vm, "intinf GMP allocation failed");
    vm->intinf_gmp_live += size;
    total(vm, size);
    return p;
}
static void *resize(void *p, size_t old_size, size_t new_size) {
    VM *vm = allocation_vm();
    old_size = charged(old_size); new_size = charged(new_size);
    if (old_size > vm->intinf_gmp_live) vm_fatal(vm, "intinf GMP allocation accounting is inconsistent");
    size_t held = vm->intinf_gmp_live - old_size, limit = vm_intinf_gmp_memory(vm);
    if (held > limit || new_size > limit - held)
        vm_limit(vm, "intinf GMP memory limit exceeded (--intinf-gmp-memory)");
    void *next = realloc(p, new_size);
    if (!next) vm_limit(vm, "intinf GMP allocation failed");
    vm->intinf_gmp_live = held + new_size;
    total(vm, new_size);
    return next;
}
static void release(void *p, size_t size) {
    VM *vm = allocation_vm();
    size = charged(size);
    if (size > vm->intinf_gmp_live) vm_fatal(vm, "intinf GMP allocation accounting is inconsistent");
    vm->intinf_gmp_live -= size;
    free(p);
}
static void enter(VM *vm) {
    if (!vm_intinf_available(vm)) vm_fatal(vm, "intinf GMP backend is unavailable");
    if (active || vm->intinf_gmp_live) vm_fatal(vm, "intinf GMP primitive is reentrant or retains allocations");
    if (!installed) {
        mp_set_memory_functions(allocate, resize, release);
        installed = 1;
    }
    active = vm;
    if (vm->intinf_gmp_calls != UINT64_MAX) vm->intinf_gmp_calls++;
}
static void leave(VM *vm) {
    if (vm->intinf_gmp_live) vm_fatal(vm, "intinf GMP primitive retained allocations");
    active = NULL;
}

typedef struct Magnitude {
    const unsigned char *bytes;
    uint32_t length;
    uint64_t bits;
    int negative;
} Magnitude;

static Magnitude magnitude(VM *vm, Value value, int negative) {
    uint64_t bits = vm_intinf_validate(vm, value, negative);
    Obj *s = val_ptr(value);
    Magnitude m = { (const unsigned char *)obj_bytes(s), obj_len(s), bits, negative };
    return m;
}
static void import(mpz_t value, Magnitude m) {
    mpz_init(value);
    mpz_import(value, m.length, -1, 1, 1, 0, m.bytes);
    if (m.negative) mpz_neg(value, value);
}
static Value export(VM *vm, const mpz_t value) {
    int sign = mpz_sgn(value);
    size_t bits = sign ? mpz_sizeinbase(value, 2) : 0;
    vm_intinf_check(vm, bits);
    uint64_t length = ((uint64_t)bits + 7) / 8;
    if (length > UINT32_C(0x3fffffff)) vm_limit(vm, "intinf magnitude exceeds string representation");
    Obj *s = vm_alloc_string(vm, (uint32_t)length);
    size_t written = 0;
    mpz_export(obj_bytes(s), &written, -1, 1, 1, 0, value);
    if (written != length) vm_fatal(vm, "intinf GMP export length is inconsistent");
    vm_push(vm, mk_ptr(s));
    Obj *pair = vm_alloc_fields(vm, K_TUPLE, 0, 2);
    obj_fill_field(pair, 0, mk_bool(sign < 0));
    obj_fill_field(pair, 1, vm_pop(vm));
    return mk_ptr(pair);
}

/* Multiplication and division by GMP, where the VM selects it: 1 when
   done, 0 for the caller's own arithmetic. */
static void import_big(mpz_t value, const Big *b) {
    mpz_init(value);
    mpz_import(value, b->n, -1, sizeof(uint32_t), 0, 0, b->d);
    if (b->neg) mpz_neg(value, value);
}
static void export_big(VM *vm, Big *b, const mpz_t value) {
    size_t bits = mpz_sgn(value) ? mpz_sizeinbase(value, 2) : 0;
    vm_intinf_check(vm, bits);
    size_t n = (bits + 31) / 32, written = 0;
    uint32_t *d = big_room(vm, b, n ? n : 1);
    if (n) mpz_export(d, &written, -1, sizeof(uint32_t), 0, 0, value);
    if (written != n) vm_fatal(vm, "intinf GMP export length is inconsistent");
    b->n = n;
    b->neg = mpz_sgn(value) < 0;
}
static int gmp_arith(VM *vm, unsigned op, const Big *a, const Big *b, Big *q, Big *r) {
    if (!vm_intinf_available(vm)) return 0;
    if (op == INTINF_MUL && a->n && b->n) vm_intinf_check(vm, big_bits(a) + big_bits(b) - 1);
    enter(vm);
    mpz_t x, y, z, w;
    import_big(x, a); import_big(y, b); mpz_init(z); mpz_init(w);
    if (op == INTINF_MUL) mpz_mul(z, x, y);
    else if (op == INTINF_DIV || op == INTINF_MOD) mpz_fdiv_qr(z, w, x, y);
    else mpz_tdiv_qr(z, w, x, y);
    export_big(vm, q, z);
    export_big(vm, r, w);
    mpz_clear(w); mpz_clear(z); mpz_clear(y); mpz_clear(x);
    leave(vm);
    return 1;
}

Value vm_intinf_binary(VM *vm, unsigned op, int na, Value a, int nb, Value b) {
    Magnitude ma = magnitude(vm, a, na), mb = magnitude(vm, b, nb);
    if (op > 5) vm_fatal(vm, "intinf GMP primitive: invalid operation");
    if (op == 2 && ma.bits && mb.bits) vm_intinf_check(vm, ma.bits + mb.bits - 1);
    enter(vm);
    mpz_t x, y, z;
    import(x, ma); import(y, mb); mpz_init(z);
    switch (op) {
    case 0: mpz_add(z, x, y); break;
    case 1: mpz_sub(z, x, y); break;
    case 2: mpz_mul(z, x, y); break;
    case 3: mpz_and(z, x, y); break;
    case 4: mpz_ior(z, x, y); break;
    case 5: mpz_xor(z, x, y); break;
    }
    Value result = export(vm, z);
    mpz_clear(z); mpz_clear(y); mpz_clear(x);
    leave(vm);
    return result;
}
Value vm_intinf_divmod(VM *vm, int floor, int na, Value a, int nb, Value b) {
    Magnitude ma = magnitude(vm, a, na), mb = magnitude(vm, b, nb);
    /* The primitive wrapper raises SML Div before importing either argument. */
    if (!mb.length) vm_fatal(vm, "intinf GMP primitive: unchecked zero divisor");
    enter(vm);
    mpz_t x, y, q, r;
    import(x, ma); import(y, mb); mpz_init(q); mpz_init(r);
    if (floor) mpz_fdiv_qr(q, r, x, y); else mpz_tdiv_qr(q, r, x, y);
    vm_push(vm, export(vm, q));
    vm_push(vm, export(vm, r));
    Obj *pair = vm_alloc_fields(vm, K_TUPLE, 0, 2);
    obj_fill_field(pair, 1, vm_pop(vm));
    obj_fill_field(pair, 0, vm_pop(vm));
    mpz_clear(r); mpz_clear(q); mpz_clear(y); mpz_clear(x);
    leave(vm);
    return mk_ptr(pair);
}
Value vm_intinf_shift(VM *vm, int left, int negative, Value a, uint64_t count) {
    Magnitude m = magnitude(vm, a, negative);
    if (left && m.bits && count > vm_intinf_max_bits(vm) - m.bits)
        vm_limit(vm, "intinf magnitude limit exceeded (--intinf-max-bits)");
    enter(vm);
    mpz_t x, z;
    import(x, m); mpz_init(z);
    if (!m.bits) mpz_set_ui(z, 0);
    else if (!left && count >= m.bits) mpz_set_si(z, negative ? -1 : 0);
    else {
        if (count > ULONG_MAX) vm_limit(vm, "intinf shift count exceeds GMP range");
        if (left) mpz_mul_2exp(z, x, (mp_bitcnt_t)count);
        else mpz_fdiv_q_2exp(z, x, (mp_bitcnt_t)count);
    }
    Value result = export(vm, z);
    mpz_clear(z); mpz_clear(x);
    leave(vm);
    return result;
}
Value vm_intinf_power(VM *vm, int negative, Value a, uint64_t exponent) {
    Magnitude m = magnitude(vm, a, negative);
    if (m.bits > 1 && exponent > (vm_intinf_max_bits(vm) - 1) / (m.bits - 1))
        vm_limit(vm, "intinf magnitude limit exceeded (--intinf-max-bits)");
    /* Zero and unit values do not require converting an enormous exponent. */
    if (m.bits <= 1) exponent = exponent ? 2 + (exponent & 1) : 0;
    if (exponent > ULONG_MAX) vm_limit(vm, "intinf exponent exceeds GMP range");
    enter(vm);
    mpz_t x, z;
    import(x, m); mpz_init(z);
    mpz_pow_ui(z, x, (unsigned long)exponent);
    Value result = export(vm, z);
    mpz_clear(z); mpz_clear(x);
    leave(vm);
    return result;
}
Value vm_intinf_decimal(VM *vm, Value a) {
    Magnitude m = magnitude(vm, a, 0);
    enter(vm);
    mpz_t x;
    import(x, m);
    /* NULL asks GMP to allocate through our tracked hooks. Its documented
       final allocation is exactly strlen(text)+1, including the terminator. */
    char *text = mpz_get_str(NULL, 10, x);
    size_t length = strlen(text);
    mpz_clear(x);
    if (length > UINT32_C(0x3fffffff))
        vm_limit(vm, "intinf decimal text exceeds string representation");
    /* No borrowed Rune pointer is used after this allocation. The input
       remains on the primitive's argument stack; text is independent. */
    Obj *result = vm_alloc_string(vm, (uint32_t)length);
    memcpy(obj_bytes(result), text, length);
    release(text, length + 1);
    leave(vm);
    return mk_ptr(result);
}
#else
static int supported(void) { return 0; }
static int gmp_arith(VM *vm, unsigned op, const Big *a, const Big *b, Big *q, Big *r) {
    (void)vm; (void)op; (void)a; (void)b; (void)q; (void)r;
    return 0;
}
static Value unavailable(VM *vm) {
    vm_fatal(vm, "intinf GMP backend is unavailable");
    return mk_unit();
}
Value vm_intinf_binary(VM *vm, unsigned op, int na, Value a, int nb, Value b) {
    (void)op; (void)na; (void)a; (void)nb; (void)b;
    return unavailable(vm);
}
Value vm_intinf_divmod(VM *vm, int floor, int na, Value a, int nb, Value b) {
    (void)floor; (void)na; (void)a; (void)nb; (void)b;
    return unavailable(vm);
}
Value vm_intinf_shift(VM *vm, int left, int negative, Value a, uint64_t count) {
    (void)left; (void)negative; (void)a; (void)count;
    return unavailable(vm);
}
Value vm_intinf_power(VM *vm, int negative, Value a, uint64_t exponent) {
    (void)negative; (void)a; (void)exponent;
    return unavailable(vm);
}
Value vm_intinf_decimal(VM *vm, Value a) {
    (void)a;
    return unavailable(vm);
}
#endif

int vm_intinf_available(const VM *vm) {
    return vm->intinf_mode != INTINF_SML && supported();
}
int vm_intinf_configure(VM *vm) {
    if (vm->intinf_mode == INTINF_GMP && !supported()) {
        fputs("runevm: requested GMP backend is unavailable or unsupported\n", stderr);
        return 0;
    }
    return 1;
}
void vm_intinf_version(FILE *out) {
#if defined(RUNE_HAVE_GMP) && RUNE_HAVE_GMP
    fprintf(out, "GMP headers %d.%d.%d, library %s, %d-bit limbs, %s\n",
            __GNU_MP_VERSION, __GNU_MP_VERSION_MINOR, __GNU_MP_VERSION_PATCHLEVEL,
            gmp_version, mp_bits_per_limb, supported() ? "supported" : "unsupported");
    fprintf(out, "GMP target: %s\nGMP provenance: %s\nGMP build: %s\n",
            RUNE_GMP_TARGET, RUNE_GMP_PROVENANCE, RUNE_GMP_OPTIONS);
#else
    fputs("GMP disabled; SML arithmetic\n", out);
#endif
}
void vm_intinf_report(const VM *vm, FILE *out) {
    fprintf(out, "runevm: intinf: %s, max %zu bits, GMP memory limit %zu, "
            "%llu GMP calls, %llu GMP allocations, %llu GMP bytes requested, %zu GMP peak, %zu GMP live\n",
            vm_intinf_available(vm) ? "gmp" : "sml", vm_intinf_max_bits(vm), vm_intinf_gmp_memory(vm),
            (unsigned long long)vm->intinf_gmp_calls, (unsigned long long)vm->intinf_gmp_allocations,
            (unsigned long long)vm->intinf_gmp_allocated,
            vm->intinf_gmp_peak, vm->intinf_gmp_live);
}

/* ---- the entry points of IntInf.int's primitives (intinf.h) ---- */
Value vm_intinf_arith(VM *vm, unsigned op, Value x, Value y, const char *prim) {
    Big a, b, q, r;
    big_of_value(vm, &a, x, prim);
    big_of_value(vm, &b, y, prim);
    big_init(&q); big_init(&r);
    int large = !val_is_imm(x) || !val_is_imm(y);
    Big *result = &q;
    switch (op) {
    case INTINF_ADD: big_addsub(vm, &q, &a, &b, 0); break;
    case INTINF_SUB: big_addsub(vm, &q, &a, &b, 1); break;
    case INTINF_MUL:
        if (!(large && gmp_arith(vm, op, &a, &b, &q, &r))) big_mul(vm, &q, &a, &b);
        break;
    case INTINF_QUOT: case INTINF_REM: case INTINF_DIV: case INTINF_MOD:
        if (!b.n) vm_fatal(vm, "primitive %s: unchecked zero divisor", prim);
        if (!(large && gmp_arith(vm, op, &a, &b, &q, &r)))
            big_divmod(vm, &q, &r, &a, &b, op == INTINF_DIV || op == INTINF_MOD);
        if (op == INTINF_REM || op == INTINF_MOD) result = &r;
        break;
    default:
        vm_fatal(vm, "primitive %s: invalid operation", prim);
    }
    big_free(&a); big_free(&b);
    Big *other = result == &q ? &r : &q;
    big_free(other);
    Value v = big_value(vm, result);
    big_free(result);
    return v;
}
int vm_intinf_compare(VM *vm, Value x, Value y, const char *prim) {
    if (val_is_imm(x) && val_is_imm(y)) return val_imm(x) < val_imm(y) ? -1 : val_imm(x) > val_imm(y);
    Big a, b;
    big_of_value(vm, &a, x, prim);
    big_of_value(vm, &b, y, prim);
    int c = a.neg != b.neg ? (a.neg ? -1 : 1) : a.neg ? -mag_cmp(&a, &b) : mag_cmp(&a, &b);
    big_free(&a); big_free(&b);
    return c;
}
Value vm_intinf_negate(VM *vm, Value x, const char *prim) {
    if (val_is_imm(x) && val_imm(x) != IMM_MIN) return mk_imm(-val_imm(x));
    Big a;
    big_of_value(vm, &a, x, prim);
    if (a.n) a.neg = !a.neg;
    Value v = big_value(vm, &a);
    big_free(&a);
    return v;
}
Value vm_intinf_of_int64(VM *vm, int64_t i) {
    if (int_fits(i)) return mk_imm(i);
    Big a;
    big_of_int64(&a, i);
    Value v = big_value(vm, &a);
    big_free(&a);
    return v;
}
int vm_intinf_to_int64(VM *vm, Value x, int64_t *out, const char *prim) {
    if (val_is_imm(x)) { *out = val_imm(x); return 1; }
    Big a;
    big_of_value(vm, &a, x, prim);
    int fits = 0;
    if (a.n <= 2) {
        uint64_t m = (uint64_t)a.d[0] | (a.n > 1 ? (uint64_t)a.d[1] << 32 : 0);
        if (!a.neg && m <= (uint64_t)INT64_MAX) { *out = (int64_t)m; fits = 1; }
        else if (a.neg && m <= (uint64_t)INT64_MAX + 1) { *out = -(int64_t)(m - 1) - 1; fits = 1; }
    }
    big_free(&a);
    return fits;
}
int vm_intinf_is_zero(VM *vm, Value x, const char *prim) {
    if (val_is_imm(x)) return val_imm(x) == 0;
    int neg;
    uint64_t bits;
    large_pair(vm, x, &neg, &bits, prim);
    return 0;
}
int vm_intinf_check_value(VM *vm, Value x, const char *prim) {
    if (val_is_imm(x)) return 1;
    int neg;
    uint64_t bits;
    large_pair(vm, x, &neg, &bits, prim);
    return 0;
}
Value vm_intinf_magnitude_of_small(VM *vm, int64_t i) {
    uint64_t m = i < 0 ? (uint64_t)0 - (uint64_t)i : (uint64_t)i;
    uint32_t length = 0;
    for (uint64_t t = m; t; t >>= 8) length++;
    Obj *s = vm_alloc_string(vm, length);
    unsigned char *bytes = (unsigned char *)obj_bytes(s);
    for (uint32_t k = 0; k < length; k++) bytes[k] = (unsigned char)(m >> (8 * k));
    return mk_ptr(s);
}
int vm_intinf_fits(VM *vm, int neg, Value magnitude, int64_t *small, const char *prim) {
    uint64_t bits = magnitude_bits(vm, magnitude, prim);
    Obj *s = val_ptr(magnitude);
    const unsigned char *bytes = (const unsigned char *)obj_bytes(s);
    uint32_t length = obj_len(s);
    if (!fits_immediate(neg, bytes, length, bits)) return 0;
    uint64_t m = 0;
    for (uint32_t k = length; k-- > 0;) m = (m << 8) | bytes[k];
    *small = neg ? -(int64_t)m : (int64_t)m;
    return 1;
}
