/* Optional GMP arithmetic over Rune-owned, immutable magnitude bytes.
   No GMP object or allocation survives a returning primitive call. */
#include "intinf.h"
#include <limits.h>

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
    if (!val_is(value, T_PTR) || obj_kind(val_ptr(value)) != K_STRING)
        vm_fatal(vm, "intinf GMP primitive: wrong magnitude type");
    Obj *s = val_ptr(value);
    Magnitude m;
    m.bytes = (const unsigned char *)obj_bytes(s);
    m.length = obj_len(s);
    m.negative = negative;
    if (m.length && m.bytes[m.length - 1] == 0)
        vm_fatal(vm, "intinf GMP primitive: noncanonical magnitude");
    if (!m.length && negative) vm_fatal(vm, "intinf GMP primitive: negative zero");
    m.bits = 0;
    if (m.length) {
        unsigned top = m.bytes[m.length - 1], bits = 0;
        while (top) { top >>= 1; bits++; }
        m.bits = ((uint64_t)m.length - 1) * 8 + bits;
    }
    vm_intinf_check(vm, m.bits);
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
#else
static int supported(void) { return 0; }
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
