/* Primitive operations. Each primitive pops its arguments and pushes a result,
   or raises an SML exception (returning 1 after unwinding the machine).
   Arguments are read from the stack (not popped) until the result exists, so
   that a garbage collection during allocation keeps them alive. */
#include "version.h"
#include "vm.h"
#include <math.h>
#include <errno.h>
#include <fenv.h>
#include <float.h>
#include "sys.h"

#define ARG(n) (vm->stack[vm->sp - 1 - (size_t)(n)])   /* ARG(0) is the last argument */

static int ret(VM *vm, int arity, Value v) {
    vm->sp -= (size_t)arity;
    vm_push(vm, v);
    return 0;
}

static void check_tag(VM *vm, Value v, int tag, const char *prim) {
    if (v.tag != tag) vm_fatal(vm, "primitive %s: wrong argument type", prim);
}

static Obj *check_obj(VM *vm, Value v, int kind, const char *prim) {
    if (v.tag != T_PTR || v.u.p->kind != kind) vm_fatal(vm, "primitive %s: wrong argument type", prim);
    return v.u.p;
}

/* String.maxSize: a longer result raises Size. */
#define MAX_STRING 0x3fffffff

enum { EXN_MATCH = 0, EXN_BIND, EXN_OVERFLOW, EXN_DIV, EXN_SUBSCRIPT, EXN_SIZE, EXN_CHR, EXN_DOMAIN };

static int raise_with(VM *vm, int arity, int k) {
    vm->sp -= (size_t)arity;
    return vm_raise_builtin(vm, k);
}

/* SOME v (allocates) */
static Value mk_some(VM *vm, Value v) {
    vm_push(vm, v);
    Obj *c = vm_alloc_fields(vm, K_CON, 1, 1);
    OBJ_FIELDS(c)[0] = vm_pop(vm);
    return mk_ptr(c);
}

/* --- overflow-checked arithmetic --- */
static int add_ov(int64_t a, int64_t b, int64_t *r) {
#if defined(__GNUC__)
    return __builtin_add_overflow(a, b, r);
#else
    if ((b > 0 && a > INT64_MAX - b) || (b < 0 && a < INT64_MIN - b)) return 1;
    *r = a + b; return 0;
#endif
}
static int sub_ov(int64_t a, int64_t b, int64_t *r) {
#if defined(__GNUC__)
    return __builtin_sub_overflow(a, b, r);
#else
    if ((b < 0 && a > INT64_MAX + b) || (b > 0 && a < INT64_MIN + b)) return 1;
    *r = a - b; return 0;
#endif
}
static int mul_ov(int64_t a, int64_t b, int64_t *r) {
#if defined(__GNUC__)
    return __builtin_mul_overflow(a, b, r);
#else
    if (a == 0 || b == 0) { *r = 0; return 0; }
    if ((a == -1 && b == INT64_MIN) || (b == -1 && a == INT64_MIN)) return 1;
    int64_t p = a * b;
    if (p / b != a) return 1;
    *r = p; return 0;
#endif
}

/* ================================================================ poly */
static int p_poly_eq(VM *vm) { return ret(vm, 2, mk_bool(values_equal(ARG(1), ARG(0)))); }
/* exn values are K_EXN [constructor, payload]; a constructor is K_EXNCON [name]. */
static int p_exn_name(VM *vm) {
    Obj *e = check_obj(vm, ARG(0), K_EXN, "exn_name");
    Value con = OBJ_FIELDS(e)[0];
    if (con.tag != T_PTR || con.u.p->kind != K_EXNCON) vm_fatal(vm, "primitive exn_name: malformed exception value");
    return ret(vm, 1, OBJ_FIELDS(con.u.p)[0]);
}
static int p_ptr_eq(VM *vm) {
    Value a = ARG(1), b = ARG(0);
    int eq = a.tag == b.tag && (a.tag == T_PTR ? a.u.p == b.u.p : a.u.i == b.u.i);
    return ret(vm, 2, mk_bool(eq));
}

/* ================================================================ int */
#define INT2(name) int64_t x = ARG(1).u.i, y = ARG(0).u.i; check_tag(vm, ARG(1), T_INT, name); check_tag(vm, ARG(0), T_INT, name)
#define INT1(name) int64_t x = ARG(0).u.i; check_tag(vm, ARG(0), T_INT, name)

static int p_int_add(VM *vm) { INT2("int_add"); int64_t r; if (add_ov(x, y, &r)) return raise_with(vm, 2, EXN_OVERFLOW); return ret(vm, 2, mk_int(r)); }
static int p_int_sub(VM *vm) { INT2("int_sub"); int64_t r; if (sub_ov(x, y, &r)) return raise_with(vm, 2, EXN_OVERFLOW); return ret(vm, 2, mk_int(r)); }
static int p_int_mul(VM *vm) { INT2("int_mul"); int64_t r; if (mul_ov(x, y, &r)) return raise_with(vm, 2, EXN_OVERFLOW); return ret(vm, 2, mk_int(r)); }
static int p_int_div(VM *vm) {
    INT2("int_div");
    if (y == 0) return raise_with(vm, 2, EXN_DIV);
    if (x == INT64_MIN && y == -1) return raise_with(vm, 2, EXN_OVERFLOW);
    int64_t q = x / y;
    if ((x % y != 0) && ((x < 0) != (y < 0))) q--;
    return ret(vm, 2, mk_int(q));
}
static int p_int_mod(VM *vm) {
    INT2("int_mod");
    if (y == 0) return raise_with(vm, 2, EXN_DIV);
    if (y == -1) return ret(vm, 2, mk_int(0));
    int64_t r = x % y;
    if (r != 0 && ((r < 0) != (y < 0))) r += y;
    return ret(vm, 2, mk_int(r));
}
static int p_int_quot(VM *vm) {
    INT2("int_quot");
    if (y == 0) return raise_with(vm, 2, EXN_DIV);
    if (x == INT64_MIN && y == -1) return raise_with(vm, 2, EXN_OVERFLOW);
    return ret(vm, 2, mk_int(x / y));
}
static int p_int_rem(VM *vm) {
    INT2("int_rem");
    if (y == 0) return raise_with(vm, 2, EXN_DIV);
    if (y == -1) return ret(vm, 2, mk_int(0));
    return ret(vm, 2, mk_int(x % y));
}
static int p_int_neg(VM *vm) { INT1("int_neg"); if (x == INT64_MIN) return raise_with(vm, 1, EXN_OVERFLOW); return ret(vm, 1, mk_int(-x)); }
static int p_int_abs(VM *vm) { INT1("int_abs"); if (x == INT64_MIN) return raise_with(vm, 1, EXN_OVERFLOW); return ret(vm, 1, mk_int(x < 0 ? -x : x)); }
static int p_int_lt(VM *vm) { INT2("int_lt"); return ret(vm, 2, mk_bool(x < y)); }
static int p_int_le(VM *vm) { INT2("int_le"); return ret(vm, 2, mk_bool(x <= y)); }
static int p_int_gt(VM *vm) { INT2("int_gt"); return ret(vm, 2, mk_bool(x > y)); }
static int p_int_ge(VM *vm) { INT2("int_ge"); return ret(vm, 2, mk_bool(x >= y)); }

static int p_int_to_string(VM *vm) {
    INT1("int_to_string");
    char buf[32];
    if (x < 0) {
        /* avoid overflow on INT64_MIN */
        snprintf(buf, sizeof buf, "~%llu", (unsigned long long)(0 - (uint64_t)x));
    } else {
        snprintf(buf, sizeof buf, "%lld", (long long)x);
    }
    Obj *s = vm_string_from(vm, buf, (uint32_t)strlen(buf));
    return ret(vm, 1, mk_ptr(s));
}

/* Parses an optional sign (~, -, +) and decimal digits; prefix semantics like Int.fromString. */
static int p_int_from_string(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "int_from_string");
    const char *b = OBJ_BYTES(s);
    uint32_t n = s->len, i = 0;
    while (i < n && (b[i] == ' ' || b[i] == '\t' || b[i] == '\n' || b[i] == '\r')) i++;
    int neg = 0;
    if (i < n && (b[i] == '~' || b[i] == '-')) { neg = 1; i++; }
    else if (i < n && b[i] == '+') i++;
    if (i >= n || b[i] < '0' || b[i] > '9') return ret(vm, 1, mk_con0(0));
    uint64_t acc = 0;
    int overflow = 0;
    while (i < n && b[i] >= '0' && b[i] <= '9') {
        int d = b[i] - '0';
        if (acc > (UINT64_MAX - (uint64_t)d) / 10) overflow = 1;
        else acc = acc * 10 + (uint64_t)d;
        i++;
    }
    if (overflow || acc > (neg ? (uint64_t)INT64_MAX + 1 : (uint64_t)INT64_MAX)) return raise_with(vm, 1, EXN_OVERFLOW);
    int64_t v = neg ? (int64_t)(0 - acc) : (int64_t)acc;
    Value r = mk_some(vm, mk_int(v));
    return ret(vm, 1, r);
}
static int p_int_to_char(VM *vm) { INT1("int_to_char"); if (x < 0 || x > 255) return raise_with(vm, 1, EXN_CHR); return ret(vm, 1, mk_char(x)); }
static int p_int_to_real(VM *vm) { INT1("int_to_real"); return ret(vm, 1, mk_real((double)x)); }

/* ================================================================ word */
#define WORD2(name) uint64_t x = ARG(1).u.w, y = ARG(0).u.w; check_tag(vm, ARG(1), T_WORD, name); check_tag(vm, ARG(0), T_WORD, name)
#define WORD1(name) uint64_t x = ARG(0).u.w; check_tag(vm, ARG(0), T_WORD, name)

static int p_word_add(VM *vm) { WORD2("word_add"); return ret(vm, 2, mk_word(x + y)); }
static int p_word_sub(VM *vm) { WORD2("word_sub"); return ret(vm, 2, mk_word(x - y)); }
static int p_word_mul(VM *vm) { WORD2("word_mul"); return ret(vm, 2, mk_word(x * y)); }
static int p_word_div(VM *vm) { WORD2("word_div"); if (y == 0) return raise_with(vm, 2, EXN_DIV); return ret(vm, 2, mk_word(x / y)); }
static int p_word_mod(VM *vm) { WORD2("word_mod"); if (y == 0) return raise_with(vm, 2, EXN_DIV); return ret(vm, 2, mk_word(x % y)); }
static int p_word_lt(VM *vm) { WORD2("word_lt"); return ret(vm, 2, mk_bool(x < y)); }
static int p_word_le(VM *vm) { WORD2("word_le"); return ret(vm, 2, mk_bool(x <= y)); }
static int p_word_gt(VM *vm) { WORD2("word_gt"); return ret(vm, 2, mk_bool(x > y)); }
static int p_word_ge(VM *vm) { WORD2("word_ge"); return ret(vm, 2, mk_bool(x >= y)); }
static int p_word_andb(VM *vm) { WORD2("word_andb"); return ret(vm, 2, mk_word(x & y)); }
static int p_word_orb(VM *vm) { WORD2("word_orb"); return ret(vm, 2, mk_word(x | y)); }
static int p_word_xorb(VM *vm) { WORD2("word_xorb"); return ret(vm, 2, mk_word(x ^ y)); }
static int p_word_notb(VM *vm) { WORD1("word_notb"); return ret(vm, 1, mk_word(~x)); }
static int p_word_neg(VM *vm) { WORD1("word_neg"); return ret(vm, 1, mk_word(0 - x)); }
static int p_word_lsl(VM *vm) { WORD2("word_lsl"); return ret(vm, 2, mk_word(y >= 64 ? 0 : x << y)); }
static int p_word_lsr(VM *vm) { WORD2("word_lsr"); return ret(vm, 2, mk_word(y >= 64 ? 0 : x >> y)); }
static int p_word_to_int(VM *vm) { WORD1("word_to_int"); if (x > (uint64_t)INT64_MAX) return raise_with(vm, 1, EXN_OVERFLOW); return ret(vm, 1, mk_int((int64_t)x)); }
static int p_word_to_int_x(VM *vm) { WORD1("word_to_int_x"); return ret(vm, 1, mk_int((int64_t)x)); }
static int p_word_from_int(VM *vm) { INT1("word_from_int"); return ret(vm, 1, mk_word((uint64_t)x)); }
static int p_word_to_string(VM *vm) {
    WORD1("word_to_string");
    char buf[32];
    snprintf(buf, sizeof buf, "%llX", (unsigned long long)x);
    return ret(vm, 1, mk_ptr(vm_string_from(vm, buf, (uint32_t)strlen(buf))));
}

/* ================================================================ real */
#define REAL2(name) double x = ARG(1).u.d, y = ARG(0).u.d; check_tag(vm, ARG(1), T_REAL, name); check_tag(vm, ARG(0), T_REAL, name)
#define REAL1(name) double x = ARG(0).u.d; check_tag(vm, ARG(0), T_REAL, name)

static int p_real_add(VM *vm) { REAL2("real_add"); return ret(vm, 2, mk_real(x + y)); }
static int p_real_sub(VM *vm) { REAL2("real_sub"); return ret(vm, 2, mk_real(x - y)); }
static int p_real_mul(VM *vm) { REAL2("real_mul"); return ret(vm, 2, mk_real(x * y)); }
static int p_real_div(VM *vm) { REAL2("real_div"); return ret(vm, 2, mk_real(x / y)); }
static int p_real_neg(VM *vm) { REAL1("real_neg"); return ret(vm, 1, mk_real(-x)); }
/* The 64 bits of a real, IEEE 754 binary64, and back (PackReal). */
static int p_real_to_bits(VM *vm) {
    REAL1("real_to_bits");
    uint64_t w;
    memcpy(&w, &x, sizeof w);
    return ret(vm, 1, mk_word(w));
}
static int p_real_from_bits(VM *vm) {
    WORD1("real_from_bits");
    double d;
    memcpy(&d, &x, sizeof d);
    return ret(vm, 1, mk_real(d));
}
static int p_real_abs(VM *vm) { REAL1("real_abs"); return ret(vm, 1, mk_real(fabs(x))); }
static int p_real_lt(VM *vm) { REAL2("real_lt"); return ret(vm, 2, mk_bool(x < y)); }
static int p_real_le(VM *vm) { REAL2("real_le"); return ret(vm, 2, mk_bool(x <= y)); }
static int p_real_gt(VM *vm) { REAL2("real_gt"); return ret(vm, 2, mk_bool(x > y)); }
static int p_real_ge(VM *vm) { REAL2("real_ge"); return ret(vm, 2, mk_bool(x >= y)); }
static int p_real_eq(VM *vm) { REAL2("real_eq"); return ret(vm, 2, mk_bool(x == y)); }

static int real_to_int(VM *vm, double r) {
    if (isnan(r)) return raise_with(vm, 1, EXN_DOMAIN);
    if (r >= 9223372036854775808.0 || r < -9223372036854775808.0) return raise_with(vm, 1, EXN_OVERFLOW);
    return ret(vm, 1, mk_int((int64_t)r));
}
static int p_real_floor(VM *vm) { REAL1("real_floor"); return real_to_int(vm, floor(x)); }
static int p_real_ceil(VM *vm) { REAL1("real_ceil"); return real_to_int(vm, ceil(x)); }
static int p_real_round(VM *vm) {
    REAL1("real_round");
    double r = floor(x + 0.5);
    /* round half to even */
    if (r - x == 0.5 && fmod(r, 2.0) != 0.0) r -= 1.0;
    return real_to_int(vm, r);
}
static int p_real_trunc(VM *vm) { REAL1("real_trunc"); return real_to_int(vm, trunc(x)); }

/* SML rendering: ~ for minus, E for exponent, always a fractional part or exponent. */
static void format_real(double d, char *out, size_t n) {
    if (isnan(d)) { snprintf(out, n, "nan"); return; }
    if (isinf(d)) { snprintf(out, n, d > 0 ? "inf" : "~inf"); return; }
    char tmp[64];
    snprintf(tmp, sizeof tmp, "%.12g", d);
    char mant[64], expo[16];
    char *e = strchr(tmp, 'e');
    if (e) { *e = 0; snprintf(expo, sizeof expo, "%s", e + 1); } else expo[0] = 0;
    snprintf(mant, sizeof mant, "%s", tmp);
    size_t o = 0;
    for (size_t i = 0; mant[i] && o + 1 < n; i++) out[o++] = mant[i] == '-' ? '~' : mant[i];
    if (!strchr(mant, '.') && !expo[0] && o + 2 < n) { out[o++] = '.'; out[o++] = '0'; }
    if (expo[0]) {
        const char *x = expo;
        int neg = 0;
        if (*x == '-') { neg = 1; x++; } else if (*x == '+') x++;
        while (*x == '0' && x[1]) x++;
        if (o + 1 < n) out[o++] = 'E';
        if (neg && o + 1 < n) out[o++] = '~';
        while (*x && o + 1 < n) out[o++] = *x++;
    }
    out[o] = 0;
}

static int p_real_to_string(VM *vm) {
    REAL1("real_to_string");
    char buf[80];
    format_real(x, buf, sizeof buf);
    return ret(vm, 1, mk_ptr(vm_string_from(vm, buf, (uint32_t)strlen(buf))));
}

/* A numeral in C syntax (~ read as -) to a double, or with single to the
   nearest binary32 value; NONE when it does not start as a number. */
/* Reading a numeral in the current rounding mode. glibc's strtod and strtof
   round in the mode; mingw's round to the nearest whatever it is. So the
   numeral is read to the nearest, and then stepped to the other neighbour
   when the mode asks for it: the exact decimal expansion of the nearest,
   which printf gives with enough digits, is compared with the numeral. The
   result is the same with every C library. */

/* The significant digits of a decimal numeral [s, end), into digits (which
   has room for end - s + 1), and the exponent of the first one: the numeral
   is d.ddd * 10^exp. "" for zero. An exponent is kept to what cannot
   overflow; a numeral that needs more is not finite and not zero, and is
   not compared. */
static void decimal_digits(const char *s, const char *end, char *digits, long long *exp) {
    size_t n = 0;
    long long e = 0, point = -1, first = -1, pos = 0;
    for (; s < end && (*s == '-' || *s == '+'); s++) {}
    for (; s < end && ((*s >= '0' && *s <= '9') || *s == '.'); s++) {
        if (*s == '.') { point = pos; continue; }
        if (first < 0 && *s == '0') { pos++; continue; }
        if (first < 0) first = pos;
        digits[n++] = *s;
        pos++;
    }
    if (s < end && (*s == 'e' || *s == 'E')) {
        e = strtoll(s + 1, NULL, 10);
        if (e > 1000000000LL) e = 1000000000LL;
        if (e < -1000000000LL) e = -1000000000LL;
    }
    while (n > 0 && digits[n - 1] == '0') n--;
    digits[n] = 0;
    if (point < 0) point = pos;
    *exp = first < 0 ? 0 : e + point - first - 1;
}

/* -1, 0 or 1 as the magnitude of the numeral [s, end) is below, equal to or
   above |x|. */
static int decimal_compare(const char *s, const char *end, double x) {
    /* 767 significant digits are the most a double has */
    char x_text[1200];
    int n = snprintf(x_text, sizeof x_text, "%.780e", fabs(x));
    char *a = malloc((size_t)(end - s) + 1), *b = malloc((size_t)n + 1);
    if (!a || !b) { free(a); free(b); return 0; }
    long long ea, eb;
    decimal_digits(s, end, a, &ea);
    decimal_digits(x_text, x_text + n, b, &eb);
    int c;
    if (!a[0] || !b[0]) c = (a[0] != 0) - (b[0] != 0);
    else if (ea != eb) c = ea < eb ? -1 : 1;
    else { c = strcmp(a, b); c = c < 0 ? -1 : c > 0 ? 1 : 0; }
    free(a);
    free(b);
    return c;
}

static double parse_rounded(const char *buf, char **end, int single) {
    int mode = fegetround();
    fesetround(FE_TONEAREST);
    errno = 0;
    double x = single ? (double)strtof(buf, end) : strtod(buf, end);
    int range = errno == ERANGE;
    fesetround(mode);
    if (mode == FE_TONEAREST || *end == buf || isnan(x)) return x;
    for (const char *c = buf; c < *end; c++)
        if (!((*c >= '0' && *c <= '9') || *c == '.' || *c == '-' || *c == '+' || *c == 'e' || *c == 'E'))
            return x;   /* inf, nan, hexadecimal: nothing to round */
    int negative = buf[0] == '-';
    double big = single ? FLT_MAX : DBL_MAX;
    if (isinf(x)) {
        /* beyond the largest finite number: where the mode rounds toward
           zero, the result is that number */
        if (range && (mode == FE_TOWARDZERO || (mode == FE_DOWNWARD && !negative) || (mode == FE_UPWARD && negative)))
            return negative ? -big : big;
        return x;
    }
    int c = decimal_compare(buf, *end, x);   /* the numeral against |x| */
    if (c == 0) return x;
    /* the numeral is further from zero than x (c > 0), or nearer */
    int above = negative ? c < 0 : c > 0;    /* the numeral is above x */
    double toward;
    if (mode == FE_UPWARD) { if (!above) return x; toward = INFINITY; }
    else if (mode == FE_DOWNWARD) { if (above) return x; toward = -INFINITY; }
    else { if (c > 0) return x; toward = 0.0; }   /* FE_TOWARDZERO */
    if (single) return (double)nextafterf((float)x, (float)toward);
    return nextafter(x, toward);
}

static int real_parse(VM *vm, const char *name, int single) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, name);
    uint32_t n = s->len;
    const char *b = OBJ_BYTES(s);
    char *buf = malloc((size_t)n + 1);   /* a numeral may have any number of digits */
    if (!buf) vm_fatal(vm, "out of memory");
    uint32_t i = 0, o = 0;
    while (i < n && (b[i] == ' ' || b[i] == '\t' || b[i] == '\n')) i++;
    for (; i < n; i++) buf[o++] = b[i] == '~' ? '-' : b[i];
    buf[o] = 0;
    if (o == 0 || !((buf[0] >= '0' && buf[0] <= '9') || buf[0] == '-' || buf[0] == '+' || buf[0] == '.')) {
        free(buf);
        return ret(vm, 1, mk_con0(0));
    }
    char *end;
    double d = parse_rounded(buf, &end, single);
    int none = end == buf;
    free(buf);
    if (none) return ret(vm, 1, mk_con0(0));
    Value r = mk_some(vm, mk_real(d));
    return ret(vm, 1, r);
}
static int p_real_from_string(VM *vm) { return real_parse(vm, "real_from_string", 0); }
static int p_real_single_from_string(VM *vm) { return real_parse(vm, "real_single_from_string", 1); }
/* Real32: a double rounded to binary32 in the current rounding mode. */
static int p_real_to_single(VM *vm) {
    REAL1("real_to_single");
    volatile float f = (float)x;
    return ret(vm, 1, mk_real((double)f));
}
static int p_real_sqrt(VM *vm) { REAL1("real_sqrt"); return ret(vm, 1, mk_real(sqrt(x))); }
static int p_real_exp(VM *vm) { REAL1("real_exp"); return ret(vm, 1, mk_real(exp(x))); }
static int p_real_ln(VM *vm) { REAL1("real_ln"); return ret(vm, 1, mk_real(log(x))); }
static int p_real_sin(VM *vm) { REAL1("real_sin"); return ret(vm, 1, mk_real(sin(x))); }
static int p_real_cos(VM *vm) { REAL1("real_cos"); return ret(vm, 1, mk_real(cos(x))); }
static int p_real_tan(VM *vm) { REAL1("real_tan"); return ret(vm, 1, mk_real(tan(x))); }
static int p_real_atan(VM *vm) { REAL1("real_atan"); return ret(vm, 1, mk_real(atan(x))); }
static int p_real_atan2(VM *vm) { REAL2("real_atan2"); return ret(vm, 2, mk_real(atan2(x, y))); }
static int p_real_pow(VM *vm) { REAL2("real_pow"); return ret(vm, 2, mk_real(pow(x, y))); }
static int p_real_is_nan(VM *vm) { REAL1("real_is_nan"); return ret(vm, 1, mk_bool(isnan(x))); }

/* --- the parts of REAL and MATH that need the C library (all ISO C99) --- */
static int p_real_floor_r(VM *vm) { REAL1("real_floor_r"); return ret(vm, 1, mk_real(floor(x))); }
static int p_real_ceil_r(VM *vm) { REAL1("real_ceil_r"); return ret(vm, 1, mk_real(ceil(x))); }
static int p_real_trunc_r(VM *vm) { REAL1("real_trunc_r"); return ret(vm, 1, mk_real(trunc(x))); }
/* Ties to even whatever the rounding mode is; x - floor x is exact. */
static int p_real_round_r(VM *vm) {
    REAL1("real_round_r");
    if (isnan(x) || isinf(x)) return ret(vm, 1, mk_real(x));
    double below = floor(x), d = x - below, r;
    if (d < 0.5) r = below;
    else if (d > 0.5) r = below + 1.0;
    else r = fmod(below, 2.0) == 0.0 ? below : below + 1.0;
    return ret(vm, 1, mk_real(copysign(r, x)));
}
static int p_real_sign_bit(VM *vm) { REAL1("real_sign_bit"); return ret(vm, 1, mk_bool(signbit(x) != 0)); }
static int p_real_copy_sign(VM *vm) { REAL2("real_copy_sign"); return ret(vm, 2, mk_real(copysign(x, y))); }
static int p_real_frexp_man(VM *vm) { REAL1("real_frexp_man"); int e; return ret(vm, 1, mk_real(frexp(x, &e))); }
static int p_real_frexp_exp(VM *vm) {
    REAL1("real_frexp_exp");
    int e = 0;
    if (!isnan(x) && !isinf(x) && x != 0.0) (void)frexp(x, &e);
    return ret(vm, 1, mk_int(e));
}
static int p_real_ldexp(VM *vm) {
    check_tag(vm, ARG(1), T_REAL, "real_ldexp");
    check_tag(vm, ARG(0), T_INT, "real_ldexp");
    double x = ARG(1).u.d;
    int64_t n = ARG(0).u.i;
    if (n > 100000) n = 100000;
    if (n < -100000) n = -100000;
    return ret(vm, 2, mk_real(ldexp(x, (int)n)));
}
static int p_real_next_after(VM *vm) { REAL2("real_next_after"); return ret(vm, 2, mk_real(nextafter(x, y))); }
static int p_real_rem(VM *vm) { REAL2("real_rem"); return ret(vm, 2, mk_real(fmod(x, y))); }

/* printf of a finite real with n digits after the point; the longest result
   is that of %f for the largest real, 309 digits before the point. */
static int real_printf(VM *vm, const char *name, const char *format) {
    check_tag(vm, ARG(1), T_REAL, name);
    check_tag(vm, ARG(0), T_INT, name);
    double x = ARG(1).u.d;
    int64_t n = ARG(0).u.i;
    if (n < 0 || n > 100000) return raise_with(vm, 2, EXN_SIZE);
    size_t cap = (size_t)n + 400;
    char *buf = malloc(cap);
    if (!buf) vm_fatal(vm, "out of memory");
    int len = snprintf(buf, cap, format, (int)n, x);
    Obj *s = vm_string_from(vm, buf, (uint32_t)len);
    free(buf);
    return ret(vm, 2, mk_ptr(s));
}
static int p_real_fmt_e(VM *vm) { return real_printf(vm, "real_fmt_e", "%.*e"); }
static int p_real_fmt_f(VM *vm) { return real_printf(vm, "real_fmt_f", "%.*f"); }
static int p_real_shortest(VM *vm) {
    REAL1("real_shortest");
    char buf[64];
    int len = 0;
    for (int k = 0; k <= 16; k++) {
        len = snprintf(buf, sizeof buf, "%.*e", k, x);
        if (strtod(buf, NULL) == x) break;
    }
    return ret(vm, 1, mk_ptr(vm_string_from(vm, buf, (uint32_t)len)));
}
static const int rounding_modes[4] = { FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO };
static int p_real_set_round(VM *vm) {
    INT1("real_set_round");
    if (x < 0 || x > 3) vm_fatal(vm, "primitive real_set_round: bad mode");
    fesetround(rounding_modes[x]);
    return ret(vm, 1, mk_unit());
}
static int p_real_get_round(VM *vm) {
    int mode = fegetround(), k = 0;
    for (int i = 0; i < 4; i++) if (rounding_modes[i] == mode) k = i;
    return ret(vm, 1, mk_int(k));
}
static int p_real_sinh(VM *vm) { REAL1("real_sinh"); return ret(vm, 1, mk_real(sinh(x))); }
static int p_real_cosh(VM *vm) { REAL1("real_cosh"); return ret(vm, 1, mk_real(cosh(x))); }
static int p_real_tanh(VM *vm) { REAL1("real_tanh"); return ret(vm, 1, mk_real(tanh(x))); }

/* ================================================================ char */
#define CHAR2(name) int64_t x = ARG(1).u.i, y = ARG(0).u.i; check_tag(vm, ARG(1), T_CHAR, name); check_tag(vm, ARG(0), T_CHAR, name)
static int p_char_ord(VM *vm) { check_tag(vm, ARG(0), T_CHAR, "char_ord"); return ret(vm, 1, mk_int(ARG(0).u.i)); }
static int p_char_lt(VM *vm) { CHAR2("char_lt"); return ret(vm, 2, mk_bool(x < y)); }
static int p_char_le(VM *vm) { CHAR2("char_le"); return ret(vm, 2, mk_bool(x <= y)); }
static int p_char_gt(VM *vm) { CHAR2("char_gt"); return ret(vm, 2, mk_bool(x > y)); }
static int p_char_ge(VM *vm) { CHAR2("char_ge"); return ret(vm, 2, mk_bool(x >= y)); }

/* ================================================================ string */
static int str_cmp(Obj *a, Obj *b) {
    uint32_t n = a->len < b->len ? a->len : b->len;
    int c = n ? memcmp(OBJ_BYTES(a), OBJ_BYTES(b), n) : 0;
    if (c != 0) return c < 0 ? -1 : 1;
    if (a->len == b->len) return 0;
    return a->len < b->len ? -1 : 1;
}
#define STR2(name) Obj *a = check_obj(vm, ARG(1), K_STRING, name); Obj *b = check_obj(vm, ARG(0), K_STRING, name)

static int p_string_size(VM *vm) { Obj *s = check_obj(vm, ARG(0), K_STRING, "string_size"); return ret(vm, 1, mk_int(s->len)); }
static int p_string_sub(VM *vm) {
    Obj *s = check_obj(vm, ARG(1), K_STRING, "string_sub");
    check_tag(vm, ARG(0), T_INT, "string_sub");
    int64_t i = ARG(0).u.i;
    if (i < 0 || (uint64_t)i >= s->len) return raise_with(vm, 2, EXN_SUBSCRIPT);
    return ret(vm, 2, mk_char((unsigned char)OBJ_BYTES(s)[i]));
}
static int p_string_concat(VM *vm) {
    STR2("string_concat");
    uint64_t n = (uint64_t)a->len + b->len;
    if (n > MAX_STRING) return raise_with(vm, 2, EXN_SIZE);
    Obj *r = vm_alloc_string(vm, (uint32_t)n);
    a = ARG(1).u.p; b = ARG(0).u.p;   /* may have moved */
    memcpy(OBJ_BYTES(r), OBJ_BYTES(a), a->len);
    memcpy(OBJ_BYTES(r) + a->len, OBJ_BYTES(b), b->len);
    return ret(vm, 2, mk_ptr(r));
}
static int p_string_extract(VM *vm) {
    Obj *s = check_obj(vm, ARG(2), K_STRING, "string_extract");
    check_tag(vm, ARG(1), T_INT, "string_extract");
    check_tag(vm, ARG(0), T_INT, "string_extract");
    int64_t i = ARG(1).u.i, n = ARG(0).u.i;
    if (i < 0 || n < 0 || (uint64_t)i + (uint64_t)n > s->len) return raise_with(vm, 3, EXN_SUBSCRIPT);
    Obj *r = vm_alloc_string(vm, (uint32_t)n);
    s = ARG(2).u.p;
    if (n) memcpy(OBJ_BYTES(r), OBJ_BYTES(s) + i, (size_t)n);
    return ret(vm, 3, mk_ptr(r));
}
static int p_string_lt(VM *vm) { STR2("string_lt"); return ret(vm, 2, mk_bool(str_cmp(a, b) < 0)); }
static int p_string_le(VM *vm) { STR2("string_le"); return ret(vm, 2, mk_bool(str_cmp(a, b) <= 0)); }
static int p_string_gt(VM *vm) { STR2("string_gt"); return ret(vm, 2, mk_bool(str_cmp(a, b) > 0)); }
static int p_string_ge(VM *vm) { STR2("string_ge"); return ret(vm, 2, mk_bool(str_cmp(a, b) >= 0)); }
static int p_string_compare(VM *vm) { STR2("string_compare"); return ret(vm, 2, mk_int(str_cmp(a, b))); }
static int p_string_from_char(VM *vm) {
    check_tag(vm, ARG(0), T_CHAR, "string_from_char");
    char c = (char)ARG(0).u.i;
    return ret(vm, 1, mk_ptr(vm_string_from(vm, &c, 1)));
}

/* Walks an SML list; returns its length or -1 if malformed. */
static int64_t list_length(Value l) {
    int64_t n = 0;
    for (;;) {
        if (l.tag == T_CON0) return n;
        if (l.tag != T_PTR || l.u.p->kind != K_CON) return -1;
        Value cell = OBJ_FIELDS(l.u.p)[0];
        if (cell.tag != T_PTR || cell.u.p->kind != K_TUPLE || cell.u.p->len != 2) return -1;
        l = OBJ_FIELDS(cell.u.p)[1];
        n++;
    }
}
static Value list_head(Value l) { return OBJ_FIELDS(OBJ_FIELDS(l.u.p)[0].u.p)[0]; }
static Value list_tail(Value l) { return OBJ_FIELDS(OBJ_FIELDS(l.u.p)[0].u.p)[1]; }

/* ================================================================ system */
static int push_string_value(VM *vm, const char *s) {
    Obj *o = vm_string_from(vm, s, (uint32_t)strlen(s));
    return ret(vm, 1, mk_ptr(o));
}

static int p_sys_errno(VM *vm) { return ret(vm, 1, mk_int(sys_errno())); }
static int p_sys_error_msg(VM *vm) { INT1("sys_error_msg"); return push_string_value(vm, sys_error_msg((int)x)); }
static int p_sys_error_name(VM *vm) { INT1("sys_error_name"); return push_string_value(vm, sys_error_name((int)x)); }
static int p_sys_error_of_name(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "sys_error_of_name");
    char *name = malloc((size_t)s->len + 1);
    if (!name) vm_fatal(vm, "out of memory");
    memcpy(name, OBJ_BYTES(s), s->len);
    name[s->len] = 0;
    int e = sys_error_of_name(name);
    free(name);
    return ret(vm, 1, mk_int(e));
}

static int p_time_now(VM *vm) { return ret(vm, 1, mk_int(sys_time_now())); }
static int p_time_user(VM *vm) { return ret(vm, 1, mk_int(sys_time_user())); }
static int p_time_sys(VM *vm) { return ret(vm, 1, mk_int(sys_time_sys())); }
static int p_time_gc_user(VM *vm) { return ret(vm, 1, mk_int(vm->gc_user_us)); }
static int p_time_gc_sys(VM *vm) { return ret(vm, 1, mk_int(vm->gc_sys_us)); }
static int p_time_sleep(VM *vm) { INT1("time_sleep"); sys_time_sleep(x); return ret(vm, 1, mk_unit()); }

/* A list of the ints in xs, built on the VM stack so that the collector sees
   every cell while the next one is allocated. */
static int push_int_list(VM *vm, const int64_t *xs, int n, int arity) {
    vm_push(vm, mk_con0(0));
    for (int i = n; i > 0; i--) {
        vm_push(vm, mk_int(xs[i - 1]));
        vm_cons(vm);
    }
    Value l = vm_pop(vm);
    return ret(vm, arity, l);
}

/* The ints of a list, at most n of them; -1 when the list is malformed or
   longer than n. */
static int int_list(Value l, int32_t *out, int n) {
    int64_t len = list_length(l);
    if (len < 0 || len > n) return -1;
    for (int i = 0; i < (int)len; i++) {
        Value head = list_head(l);
        if (head.tag != T_INT) return -1;
        out[i] = (int32_t)head.u.i;
        l = list_tail(l);
    }
    return (int)len;
}

/* The strings a system call left one after another, as a list. */
static int push_strings(VM *vm, const char *packed, int arity) {
    int n = 0;
    for (const char *p = packed; p && *p; p += strlen(p) + 1) n++;
    vm_push(vm, mk_con0(0));
    /* backwards, so that the list comes out in order */
    for (int i = n; i > 0; i--) {
        const char *p = packed;
        for (int k = 1; k < i; k++) p += strlen(p) + 1;
        Obj *s = vm_string_from(vm, p, (uint32_t)strlen(p));
        vm_push(vm, mk_ptr(s));
        vm_cons(vm);
    }
    Value l = vm_pop(vm);
    return ret(vm, arity, l);
}

static int p_date_parts(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "date_parts");
    check_tag(vm, ARG(0), T_INT, "date_parts");
    int32_t parts[9];
    if (sys_date_parts(ARG(1).u.i, (int)ARG(0).u.i, parts) != 0) return push_int_list(vm, NULL, 0, 2);
    int64_t wide[9];
    for (int i = 0; i < 9; i++) wide[i] = parts[i];
    return push_int_list(vm, wide, 9, 2);
}

static int p_date_seconds(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "date_seconds");
    int32_t parts[9];
    for (int i = 0; i < 9; i++) parts[i] = 0;
    parts[8] = -1;
    if (int_list(ARG(1), parts, 9) < 0) vm_fatal(vm, "primitive date_seconds: malformed list");
    int64_t t = sys_date_seconds(parts, (int)ARG(0).u.i);
    if (t == -1) return push_int_list(vm, NULL, 0, 2);
    int64_t wide[10];
    wide[0] = t;
    for (int i = 0; i < 9; i++) wide[i + 1] = parts[i];
    return push_int_list(vm, wide, 10, 2);
}

static int p_date_offset(VM *vm) {
    INT1("date_offset");
    int32_t offset = 0;
    if (sys_date_offset(x, &offset) != 0) return raise_with(vm, 1, EXN_DOMAIN);
    return ret(vm, 1, mk_int(offset));
}

/* Date.fmt: strftime of the C locale, written here so that every platform
   formats the same. The library passes only the directives of the
   specification, aAbBcdHIjmMpSUwWxXyYZ% (lib/basis/date.sml), and a date
   that is valid, with a year that fits a C int. The rules are glibc's: %Y
   without padding and with a sign ("-5"), %y the year modulo 100 counted
   from below (95 for -5), %c as %a %b %e %H:%M:%S %Y. Only %Z, the name of
   the local zone, is asked of the system (sys_date_format), and only for a
   local date: the library writes the zone of any other. parts[] is as
   sys_date_parts fills it. */
typedef struct { char *out; size_t n, cap; } Text;
static void put(Text *t, const char *s) {
    for (; *s; s++) if (t->n + 1 < t->cap) t->out[t->n++] = *s;
}
static void put_number(Text *t, long long v, int width, char pad) {
    char buf[32];
    int k = snprintf(buf, sizeof buf, "%lld", v);
    for (; k < width; k++) { char p[2] = { pad, 0 }; put(t, p); }
    put(t, buf);
}
static const char *const day_names[7] =
    { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" };
static const char *const month_names[12] =
    { "January", "February", "March", "April", "May", "June", "July", "August",
      "September", "October", "November", "December" };
static void put_name(Text *t, const char *const *names, int n, int i, int abbreviated) {
    if (i < 0 || i >= n) { put(t, "?"); return; }
    char buf[16];
    snprintf(buf, sizeof buf, abbreviated ? "%.3s" : "%s", names[i]);
    put(t, buf);
}
static void format_date(Text *t, const char *format, const int32_t parts[9], int local) {
    long long year = (long long)parts[5] + 1900;
    int hour = parts[2], wday = parts[6], yday = parts[7];
    for (const char *f = format; *f; f++) {
        if (*f != '%' || !f[1]) { char c[2] = { *f, 0 }; put(t, c); continue; }
        switch (*++f) {
        case 'a': put_name(t, day_names, 7, wday, 1); break;
        case 'A': put_name(t, day_names, 7, wday, 0); break;
        case 'b': put_name(t, month_names, 12, parts[4], 1); break;
        case 'B': put_name(t, month_names, 12, parts[4], 0); break;
        case 'c':
            format_date(t, "%a %b ", parts, local);
            put_number(t, parts[3], 2, ' ');
            format_date(t, " %H:%M:%S %Y", parts, local);
            break;
        case 'd': put_number(t, parts[3], 2, '0'); break;
        case 'H': put_number(t, hour, 2, '0'); break;
        case 'I': put_number(t, hour % 12 == 0 ? 12 : hour % 12, 2, '0'); break;
        case 'j': put_number(t, yday + 1, 3, '0'); break;
        case 'm': put_number(t, parts[4] + 1, 2, '0'); break;
        case 'M': put_number(t, parts[1], 2, '0'); break;
        case 'p': put(t, hour < 12 ? "AM" : "PM"); break;
        case 'S': put_number(t, parts[0], 2, '0'); break;
        case 'U': put_number(t, (yday + 7 - wday) / 7, 2, '0'); break;
        case 'w': put_number(t, wday, 1, '0'); break;
        case 'W': put_number(t, (yday + 7 - (wday + 6) % 7) / 7, 2, '0'); break;
        case 'x': format_date(t, "%m/%d/%y", parts, local); break;
        case 'X': format_date(t, "%H:%M:%S", parts, local); break;
        case 'y': put_number(t, (year % 100 + 100) % 100, 2, '0'); break;
        case 'Y': put_number(t, year, 1, '0'); break;
        case 'Z': {
            char zone[128];
            int k = local ? sys_date_format("%Z", parts, 1, zone, sizeof zone) : 0;
            if (k > 0 && (size_t)k < sizeof zone) { zone[k] = 0; put(t, zone); }
            break;
        }
        case '%': put(t, "%"); break;
        default: { char c[3] = { '%', *f, 0 }; put(t, c); }
        }
    }
}

static int p_date_format(VM *vm) {
    Obj *f = check_obj(vm, ARG(2), K_STRING, "date_format");
    check_tag(vm, ARG(0), T_INT, "date_format");
    int32_t parts[9];
    for (int i = 0; i < 9; i++) parts[i] = 0;
    if (int_list(ARG(1), parts, 9) < 0) vm_fatal(vm, "primitive date_format: malformed list");
    char *format = malloc((size_t)f->len + 1);
    if (!format) vm_fatal(vm, "out of memory");
    memcpy(format, OBJ_BYTES(f), f->len);
    format[f->len] = 0;
    size_t cap = (size_t)f->len * 16 + 256;
    char *out = malloc(cap);
    if (!out) vm_fatal(vm, "out of memory");
    Text t = { out, 0, cap };
    format_date(&t, format, parts, (int)ARG(0).u.i);
    free(format);
    Obj *s = vm_string_from(vm, out, (uint32_t)t.n);
    free(out);
    return ret(vm, 3, mk_ptr(s));
}

/* The string of a K_STRING argument, as a C string the caller frees. */
static char *c_string(VM *vm, Value v, const char *prim) {
    Obj *s = check_obj(vm, v, K_STRING, prim);
    char *out = malloc((size_t)s->len + 1);
    if (!out) vm_fatal(vm, "out of memory");
    memcpy(out, OBJ_BYTES(s), s->len);
    out[s->len] = 0;
    return out;
}

/* A primitive that takes a path and gives an int. */
#define PATH_INT(name, call)                                   \
    static int p_##name(VM *vm) {                              \
        char *path = c_string(vm, ARG(0), #name);              \
        int64_t r = call(path);                                \
        free(path);                                            \
        return ret(vm, 1, mk_int(r));                          \
    }
PATH_INT(os_mkdir, sys_mkdir)
PATH_INT(os_rmdir, sys_rmdir)
PATH_INT(os_chdir, sys_chdir)
PATH_INT(os_remove, sys_remove)
PATH_INT(os_file_kind, sys_file_kind)
PATH_INT(os_link_kind, sys_link_kind)
PATH_INT(os_file_size, sys_file_size)
PATH_INT(os_mod_time, sys_mod_time)

/* A primitive that takes a path and gives a string, empty on failure. */
#define PATH_STRING(name, call)                                \
    static int p_##name(VM *vm) {                              \
        char *path = c_string(vm, ARG(0), #name);              \
        const char *r = call(path);                            \
        free(path);                                            \
        return push_string_value(vm, r ? r : "");              \
    }
PATH_STRING(os_read_link, sys_read_link)
PATH_STRING(os_real_path, sys_real_path)

static int p_os_getcwd(VM *vm) {
    const char *dir = sys_getcwd();
    return push_string_value(vm, dir ? dir : "");
}

static int p_os_tmp_name(VM *vm) {
    const char *name = sys_tmp_name();
    return push_string_value(vm, name ? name : "");
}

static int p_os_rename(VM *vm) {
    char *from = c_string(vm, ARG(1), "os_rename");
    char *to = c_string(vm, ARG(0), "os_rename");
    int r = sys_rename(from, to);
    free(from);
    free(to);
    return ret(vm, 2, mk_int(r));
}

static int p_os_access(VM *vm) {
    char *path = c_string(vm, ARG(2), "os_access");
    check_tag(vm, ARG(1), T_INT, "os_access");
    check_tag(vm, ARG(0), T_INT, "os_access");
    int64_t flags = ARG(1).u.i;
    int r = sys_access(path, (flags & 1) != 0, (flags & 2) != 0, (flags & 4) != 0);
    free(path);
    return ret(vm, 3, mk_int(r));
}

static int p_os_set_time(VM *vm) {
    char *path = c_string(vm, ARG(2), "os_set_time");
    check_tag(vm, ARG(1), T_INT, "os_set_time");
    check_tag(vm, ARG(0), T_INT, "os_set_time");
    int r = sys_set_time(path, ARG(1).u.i, (int)ARG(0).u.i);
    free(path);
    return ret(vm, 3, mk_int(r));
}

static int p_os_file_id(VM *vm) {
    char *path = c_string(vm, ARG(0), "os_file_id");
    int64_t id[2];
    int ok = sys_file_id(path, &id[0], &id[1]);
    free(path);
    return push_int_list(vm, id, ok == 0 ? 2 : 0, 1);
}

static int p_os_open_dir(VM *vm) {
    char *path = c_string(vm, ARG(0), "os_open_dir");
    int r = sys_open_dir(path);
    free(path);
    return ret(vm, 1, mk_int(r));
}

static int p_os_read_dir(VM *vm) {
    INT1("os_read_dir");
    const char *name = sys_read_dir((int)x);
    if (!name) return ret(vm, 1, mk_con0(0));
    Obj *o = vm_string_from(vm, name, (uint32_t)strlen(name));
    Value r = mk_some(vm, mk_ptr(o));
    return ret(vm, 1, r);
}

static int p_os_rewind_dir(VM *vm) { INT1("os_rewind_dir"); return ret(vm, 1, mk_int(sys_rewind_dir((int)x))); }
static int p_os_close_dir(VM *vm) { INT1("os_close_dir"); return ret(vm, 1, mk_int(sys_close_dir((int)x))); }


/* A handle of the library is the descriptor the system gave, for these
   primitives; the ones of the VM's own table go through descriptor_of. */
static int p_posix_openf(VM *vm) {
    char *path = c_string(vm, ARG(2), "posix_openf");
    check_tag(vm, ARG(1), T_INT, "posix_openf");
    check_tag(vm, ARG(0), T_INT, "posix_openf");
    int fd = sys_openf(path, (int)ARG(1).u.i, (int)ARG(0).u.i);
    free(path);
    return ret(vm, 3, mk_int(fd));
}

static int p_posix_close(VM *vm) { INT1("posix_close"); return ret(vm, 1, mk_int(sys_close_fd((int)x))); }
static int p_posix_dup(VM *vm) { INT1("posix_dup"); return ret(vm, 1, mk_int(sys_dup((int)x))); }

static int p_posix_dup2(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "posix_dup2");
    check_tag(vm, ARG(0), T_INT, "posix_dup2");
    return ret(vm, 2, mk_int(sys_dup2((int)ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_posix_pipe(VM *vm) {
    int fds[2];
    int ok = sys_pipe(fds);
    int64_t out[2] = { fds[0], fds[1] };
    return push_int_list(vm, out, ok == 0 ? 2 : 0, 1);
}

static int p_posix_read(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "posix_read");
    check_tag(vm, ARG(0), T_INT, "posix_read");
    int64_t n = ARG(0).u.i;
    if (n < 0 || n > MAX_STRING) return raise_with(vm, 2, EXN_SIZE);
    char *buf = malloc((size_t)n ? (size_t)n : 1);
    if (!buf) vm_fatal(vm, "out of memory");
    int64_t got = sys_read_fd((int)ARG(1).u.i, buf, n);
    Obj *s = vm_string_from(vm, buf, got < 0 ? 0 : (uint32_t)got);
    free(buf);
    return ret(vm, 2, mk_ptr(s));
}

static int p_posix_write(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "posix_write");
    Obj *s = check_obj(vm, ARG(0), K_STRING, "posix_write");
    int64_t k = sys_write_fd((int)ARG(1).u.i, OBJ_BYTES(s), s->len);
    return ret(vm, 2, mk_int(k));
}

static int p_posix_lseek(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "posix_lseek");
    check_tag(vm, ARG(1), T_INT, "posix_lseek");
    check_tag(vm, ARG(0), T_INT, "posix_lseek");
    return ret(vm, 3, mk_int(sys_lseek_fd((int)ARG(2).u.i, ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_posix_fsync(VM *vm) { INT1("posix_fsync"); return ret(vm, 1, mk_int(sys_fsync((int)x))); }

static int p_posix_fcntl(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "posix_fcntl");
    check_tag(vm, ARG(1), T_INT, "posix_fcntl");
    check_tag(vm, ARG(0), T_INT, "posix_fcntl");
    return ret(vm, 3, mk_int(sys_fcntl((int)ARG(2).u.i, (int)ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_posix_ftruncate(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "posix_ftruncate");
    check_tag(vm, ARG(0), T_INT, "posix_ftruncate");
    return ret(vm, 2, mk_int(sys_ftruncate((int)ARG(1).u.i, ARG(0).u.i)));
}

static int p_posix_stat(VM *vm) {
    char *path = c_string(vm, ARG(2), "posix_stat");
    check_tag(vm, ARG(1), T_INT, "posix_stat");
    check_tag(vm, ARG(0), T_INT, "posix_stat");
    int64_t out[11];
    int ok = sys_stat_of(path[0] ? path : NULL, (int)ARG(1).u.i == 0, (int)ARG(0).u.i, out);
    free(path);
    return push_int_list(vm, out, ok == 0 ? 11 : 0, 3);
}

/* posix_lock (fd, command, type, whence, start, length) */
static int p_posix_lock(VM *vm) {
    for (int i = 0; i < 6; i++) check_tag(vm, ARG(i), T_INT, "posix_lock");
    int64_t out[5];
    int ok = sys_lock((int)ARG(5).u.i, (int)ARG(4).u.i, (int)ARG(3).u.i, (int)ARG(2).u.i,
                      ARG(1).u.i, ARG(0).u.i, out);
    return push_int_list(vm, out, ok == 0 ? 5 : 0, 6);
}

/* posix_pathconf (path, fd, name): of the descriptor when the path is "" */
static int p_posix_pathconf(VM *vm) {
    char *path = c_string(vm, ARG(2), "posix_pathconf");
    check_tag(vm, ARG(1), T_INT, "posix_pathconf");
    char *name = c_string(vm, ARG(0), "posix_pathconf");
    int64_t v;
    int ok = sys_pathconf(path[0] ? path : NULL, (int)ARG(1).u.i, name, &v);
    free(path);
    free(name);
    return push_int_list(vm, &v, ok == 0 ? 1 : 0, 3);
}

/* The terminal: posix_tcgetattr fd, posix_tcsetattr (fd, action, numbers),
   posix_tcop (op, fd, argument); see sys_tcgetattr for the numbers. */
static int p_posix_tcgetattr(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "posix_tcgetattr");
    int n = 6 + sys_nccs();
    int64_t *out = malloc((size_t)n * sizeof *out);
    if (!out) vm_fatal(vm, "out of memory");
    int ok = sys_tcgetattr((int)ARG(0).u.i, out);
    int r = push_int_list(vm, out, ok == 0 ? n : 0, 1);
    free(out);
    return r;
}

static int p_posix_tcsetattr(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "posix_tcsetattr");
    check_tag(vm, ARG(1), T_INT, "posix_tcsetattr");
    int n = 6 + sys_nccs();
    int32_t *narrow = malloc((size_t)n * sizeof *narrow);
    int64_t *in = malloc((size_t)n * sizeof *in);
    if (!narrow || !in) vm_fatal(vm, "out of memory");
    int r;
    if (int_list(ARG(0), narrow, n) != n) { sys_set_errno(EINVAL); r = -1; }
    else {
        for (int i = 0; i < n; i++) in[i] = narrow[i];
        r = sys_tcsetattr((int)ARG(2).u.i, (int)ARG(1).u.i, in);
    }
    free(narrow);
    free(in);
    return ret(vm, 3, mk_int(r));
}

static int p_posix_tcop(VM *vm) {
    for (int i = 0; i < 3; i++) check_tag(vm, ARG(i), T_INT, "posix_tcop");
    return ret(vm, 3, mk_int(sys_tcop((int)ARG(2).u.i, (int)ARG(1).u.i, ARG(0).u.i)));
}

/* socket_linger (fd, set, seconds): [seconds] afterwards (~1 when off), []
   on failure */
static int p_socket_linger(VM *vm) {
    for (int i = 0; i < 3; i++) check_tag(vm, ARG(i), T_INT, "socket_linger");
    int seconds = (int)ARG(0).u.i;
    int64_t out = 0;
    int ok = sys_linger((int)ARG(2).u.i, (int)ARG(1).u.i, &seconds);
    out = seconds;
    return push_int_list(vm, &out, ok == 0 ? 1 : 0, 3);
}
static int p_socket_query(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "socket_query");
    check_tag(vm, ARG(0), T_INT, "socket_query");
    return ret(vm, 2, mk_int(sys_socket_query((int)ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_posix_utime(VM *vm) {
    char *path = c_string(vm, ARG(2), "posix_utime");
    check_tag(vm, ARG(1), T_INT, "posix_utime");
    check_tag(vm, ARG(0), T_INT, "posix_utime");
    int r = sys_utime(path, ARG(1).u.i, ARG(0).u.i);
    free(path);
    return ret(vm, 3, mk_int(r));
}

static int p_posix_chmod(VM *vm) {
    char *path = c_string(vm, ARG(2), "posix_chmod");
    check_tag(vm, ARG(1), T_INT, "posix_chmod");
    check_tag(vm, ARG(0), T_INT, "posix_chmod");
    int r = sys_chmod(path[0] ? path : NULL, (int)ARG(1).u.i, (int)ARG(0).u.i);
    free(path);
    return ret(vm, 3, mk_int(r));
}

static int p_posix_chown(VM *vm) {
    char *path = c_string(vm, ARG(3), "posix_chown");
    check_tag(vm, ARG(2), T_INT, "posix_chown");
    check_tag(vm, ARG(1), T_INT, "posix_chown");
    check_tag(vm, ARG(0), T_INT, "posix_chown");
    int r = sys_chown(path[0] ? path : NULL, (int)ARG(2).u.i, ARG(1).u.i, ARG(0).u.i);
    free(path);
    return ret(vm, 4, mk_int(r));
}

#define TWO_PATHS(name, call)                                  \
    static int p_##name(VM *vm) {                              \
        char *from = c_string(vm, ARG(1), #name);              \
        char *to = c_string(vm, ARG(0), #name);                \
        int r = call(from, to);                                \
        free(from); free(to);                                  \
        return ret(vm, 2, mk_int(r));                          \
    }
TWO_PATHS(posix_link, sys_link)
TWO_PATHS(posix_symlink, sys_symlink)

static int p_posix_mkfifo(VM *vm) {
    char *path = c_string(vm, ARG(1), "posix_mkfifo");
    check_tag(vm, ARG(0), T_INT, "posix_mkfifo");
    int r = sys_mkfifo(path, (int)ARG(0).u.i);
    free(path);
    return ret(vm, 2, mk_int(r));
}

static int p_posix_umask(VM *vm) { INT1("posix_umask"); return ret(vm, 1, mk_int(sys_umask((int)x))); }

/* The strings of a user or a group, with the numbers written after them. */
static int push_strings_and_ints(VM *vm, const char *packed, const int64_t *xs, int n, int arity) {
    vm_push(vm, mk_con0(0));
    for (int i = n; i > 0; i--) {
        char buffer[32];
        snprintf(buffer, sizeof buffer, "%lld", (long long)xs[i - 1]);
        vm_push(vm, mk_ptr(vm_string_from(vm, buffer, (uint32_t)strlen(buffer))));
        vm_cons(vm);
    }
    int count = 0;
    for (const char *p = packed; p && *p; p += strlen(p) + 1) count++;
    for (int i = count; i > 0; i--) {
        const char *p = packed;
        for (int k = 1; k < i; k++) p += strlen(p) + 1;
        vm_push(vm, mk_ptr(vm_string_from(vm, p, (uint32_t)strlen(p))));
        vm_cons(vm);
    }
    Value l = vm_pop(vm);
    return ret(vm, arity, l);
}

static int p_posix_getpw(VM *vm) {
    char *name = c_string(vm, ARG(1), "posix_getpw");
    check_tag(vm, ARG(0), T_INT, "posix_getpw");
    int64_t ids[2];
    const char *packed = sys_getpw(name[0] ? name : NULL, ARG(0).u.i, ids);
    free(name);
    if (!packed) return push_int_list(vm, NULL, 0, 2);
    return push_strings_and_ints(vm, packed, ids, 2, 2);
}

static int p_posix_getgr(VM *vm) {
    char *name = c_string(vm, ARG(1), "posix_getgr");
    check_tag(vm, ARG(0), T_INT, "posix_getgr");
    int64_t id;
    const char *packed = sys_getgr(name[0] ? name : NULL, ARG(0).u.i, &id);
    free(name);
    if (!packed) return push_int_list(vm, NULL, 0, 2);
    /* the name, the number, then the members */
    const char *group_members = sys_group_members();
    vm_push(vm, mk_con0(0));
    int count = 0;
    for (const char *p = group_members; p && *p; p += strlen(p) + 1) count++;
    for (int i = count; i > 0; i--) {
        const char *p = group_members;
        for (int k = 1; k < i; k++) p += strlen(p) + 1;
        vm_push(vm, mk_ptr(vm_string_from(vm, p, (uint32_t)strlen(p))));
        vm_cons(vm);
    }
    char buffer[32];
    snprintf(buffer, sizeof buffer, "%lld", (long long)id);
    vm_push(vm, mk_ptr(vm_string_from(vm, buffer, (uint32_t)strlen(buffer))));
    vm_cons(vm);
    vm_push(vm, mk_ptr(vm_string_from(vm, packed, (uint32_t)strlen(packed))));
    vm_cons(vm);
    Value l = vm_pop(vm);
    return ret(vm, 2, l);
}

/* ================================================================ Windows */
/* A list of n strings of the given lengths (bytes, NULs among them), built
   on the VM stack so that the collector sees every cell. */
static int push_byte_strings(VM *vm, const char *const *strs, const size_t *lens, int n, int arity) {
    vm_push(vm, mk_con0(0));
    for (int i = n; i > 0; i--) {
        vm_push(vm, mk_ptr(vm_string_from(vm, strs[i - 1], (uint32_t)lens[i - 1])));
        vm_cons(vm);
    }
    Value l = vm_pop(vm);
    return ret(vm, arity, l);
}
static int push_c_strings(VM *vm, const char *const *strs, int n, int arity) {
    size_t lens[8] = { 0 };
    for (int i = 0; i < n; i++) lens[i] = strlen(strs[i]);
    return push_byte_strings(vm, strs, lens, n, arity);
}
static int p_win_reg_open(VM *vm) {
    check_tag(vm, ARG(3), T_INT, "win_reg_open");
    check_tag(vm, ARG(1), T_INT, "win_reg_open");
    check_tag(vm, ARG(0), T_INT, "win_reg_open");
    char *name = c_string(vm, ARG(2), "win_reg_open");
    int64_t out[2];
    int r = sys_win_reg_open((int)ARG(3).u.i, name, (int)ARG(1).u.i, (int)ARG(0).u.i, out);
    free(name);
    return push_int_list(vm, out, r == 0 ? 2 : 0, 4);
}
static int p_win_reg_close(VM *vm) { INT1("win_reg_close"); return ret(vm, 1, mk_int(sys_win_reg_close((int)x))); }
static int p_win_reg_delete(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "win_reg_delete");
    check_tag(vm, ARG(0), T_INT, "win_reg_delete");
    char *name = c_string(vm, ARG(1), "win_reg_delete");
    int r = sys_win_reg_delete((int)ARG(2).u.i, name, (int)ARG(0).u.i);
    free(name);
    return ret(vm, 3, mk_int(r));
}
static int p_win_reg_enum(VM *vm) {
    for (int i = 0; i < 3; i++) check_tag(vm, ARG(i), T_INT, "win_reg_enum");
    const char *name = sys_win_reg_enum((int)ARG(2).u.i, (int)ARG(1).u.i, (int)ARG(0).u.i);
    return push_c_strings(vm, &name, name ? 1 : 0, 3);
}
static int p_win_reg_query(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "win_reg_query");
    char *name = c_string(vm, ARG(0), "win_reg_query");
    int type = 0;
    int64_t length = 0;
    const char *data = sys_win_reg_query((int)ARG(1).u.i, name, &type, &length);
    free(name);
    if (!data || length < 0) return push_c_strings(vm, NULL, 0, 2);
    char kind[16];
    snprintf(kind, sizeof kind, "%d", type);
    const char *strs[2] = { kind, data };
    size_t lens[2] = { strlen(kind), (size_t)length };
    return push_byte_strings(vm, strs, lens, 2, 2);
}
static int p_win_reg_set(VM *vm) {
    check_tag(vm, ARG(3), T_INT, "win_reg_set");
    check_tag(vm, ARG(1), T_INT, "win_reg_set");
    char *name = c_string(vm, ARG(2), "win_reg_set");
    Obj *data = check_obj(vm, ARG(0), K_STRING, "win_reg_set");
    int r = sys_win_reg_set((int)ARG(3).u.i, name, (int)ARG(1).u.i, OBJ_BYTES(data), (int64_t)data->len);
    free(name);
    return ret(vm, 4, mk_int(r));
}
static int p_win_config(VM *vm) {
    INT1("win_config");
    const char *s = sys_win_config((int)x);
    return push_string_value(vm, s ? s : "");
}
static int p_win_version(VM *vm) {
    int64_t out[4];
    const char *csd = sys_win_version(out);
    if (!csd) return push_c_strings(vm, NULL, 0, 1);
    char n[4][24];
    for (int i = 0; i < 4; i++) snprintf(n[i], sizeof n[i], "%lld", (long long)out[i]);
    const char *strs[5] = { n[0], n[1], n[2], n[3], csd };
    return push_c_strings(vm, strs, 5, 1);
}
static int p_win_volume(VM *vm) {
    char *root = c_string(vm, ARG(0), "win_volume");
    int64_t out[2];
    const char *names = sys_win_volume(root, out);
    free(root);
    if (!names) return push_c_strings(vm, NULL, 0, 1);
    char serial[24], longest[24];
    snprintf(serial, sizeof serial, "%lld", (long long)out[0]);
    snprintf(longest, sizeof longest, "%lld", (long long)out[1]);
    const char *strs[4] = { names, names + strlen(names) + 1, serial, longest };
    return push_c_strings(vm, strs, 4, 1);
}
static int p_win_find_executable(VM *vm) {
    char *name = c_string(vm, ARG(0), "win_find_executable");
    const char *path = sys_win_find_executable(name);
    free(name);
    return push_c_strings(vm, &path, path ? 1 : 0, 1);
}
static int p_win_shell_execute(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "win_shell_execute");
    char *file = c_string(vm, ARG(2), "win_shell_execute");
    char *arg = c_string(vm, ARG(1), "win_shell_execute");
    int r = sys_win_shell_execute(file, arg, (int)ARG(0).u.i);
    free(file);
    free(arg);
    return ret(vm, 3, mk_int(r));
}
static int p_win_spawn(VM *vm) {
    int32_t given[3];
    if (int_list(ARG(0), given, 3) != 3) vm_fatal(vm, "primitive win_spawn: malformed descriptors");
    char *command = c_string(vm, ARG(2), "win_spawn");
    char *arg = c_string(vm, ARG(1), "win_spawn");
    int fds[3] = { given[0], given[1], given[2] };
    fflush(stdout);
    fflush(stderr);
    int64_t pid = sys_win_spawn(command, arg, fds);
    free(command);
    free(arg);
    return ret(vm, 3, mk_int(pid));
}
static int p_win_wait(VM *vm) {
    INT1("win_wait");
    int64_t code = 0;
    int r = sys_win_wait(x, &code);
    return push_int_list(vm, &code, r == 0 ? 1 : 0, 1);
}
static int p_win_dde_start(VM *vm) {
    char *service = c_string(vm, ARG(1), "win_dde_start");
    char *topic = c_string(vm, ARG(0), "win_dde_start");
    int r = sys_win_dde_start(service, topic);
    free(service);
    free(topic);
    return ret(vm, 2, mk_int(r));
}
static int p_win_dde_execute(VM *vm) {
    check_tag(vm, ARG(3), T_INT, "win_dde_execute");
    check_tag(vm, ARG(1), T_INT, "win_dde_execute");
    check_tag(vm, ARG(0), T_INT, "win_dde_execute");
    char *command = c_string(vm, ARG(2), "win_dde_execute");
    int r = sys_win_dde_execute((int)ARG(3).u.i, command, (int)ARG(1).u.i, ARG(0).u.i);
    free(command);
    return ret(vm, 4, mk_int(r));
}
static int p_win_dde_stop(VM *vm) { INT1("win_dde_stop"); return ret(vm, 1, mk_int(sys_win_dde_stop((int)x))); }

/* ================================================================ sockets */
static int push_last_addr(VM *vm, int ok, int arity) {
    if (ok != 0) return push_string_value(vm, "");
    Obj *o = vm_string_from(vm, sys_last_addr(), (uint32_t)sys_last_addr_len());
    return ret(vm, arity, mk_ptr(o));
}

static int p_socket_create(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "socket_create");
    check_tag(vm, ARG(1), T_INT, "socket_create");
    check_tag(vm, ARG(0), T_INT, "socket_create");
    return ret(vm, 3, mk_int(sys_socket((int)ARG(2).u.i, (int)ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_socket_pair(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "socket_pair");
    check_tag(vm, ARG(1), T_INT, "socket_pair");
    check_tag(vm, ARG(0), T_INT, "socket_pair");
    int fds[2];
    int ok = sys_socketpair((int)ARG(2).u.i, (int)ARG(1).u.i, (int)ARG(0).u.i, fds);
    int64_t out[2] = { fds[0], fds[1] };
    return push_int_list(vm, out, ok == 0 ? 2 : 0, 3);
}

#define SOCK_ADDR(name, call)                                               \
    static int p_##name(VM *vm) {                                           \
        check_tag(vm, ARG(1), T_INT, #name);                                \
        Obj *a = check_obj(vm, ARG(0), K_STRING, #name);                    \
        int r = call((int)ARG(1).u.i, OBJ_BYTES(a), (int)a->len);           \
        return ret(vm, 2, mk_int(r));                                       \
    }
SOCK_ADDR(socket_bind, sys_bind)
SOCK_ADDR(socket_connect, sys_connect)

static int p_socket_listen(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "socket_listen");
    check_tag(vm, ARG(0), T_INT, "socket_listen");
    return ret(vm, 2, mk_int(sys_listen((int)ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_socket_accept(VM *vm) { INT1("socket_accept"); return ret(vm, 1, mk_int(sys_accept((int)x))); }

static int p_socket_send(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "socket_send");
    Obj *b = check_obj(vm, ARG(1), K_STRING, "socket_send");
    check_tag(vm, ARG(0), T_INT, "socket_send");
    return ret(vm, 3, mk_int(sys_send((int)ARG(2).u.i, OBJ_BYTES(b), b->len, (int)ARG(0).u.i)));
}

static int p_socket_sendto(VM *vm) {
    check_tag(vm, ARG(3), T_INT, "socket_sendto");
    Obj *b = check_obj(vm, ARG(2), K_STRING, "socket_sendto");
    check_tag(vm, ARG(1), T_INT, "socket_sendto");
    Obj *a = check_obj(vm, ARG(0), K_STRING, "socket_sendto");
    int64_t k = sys_sendto((int)ARG(3).u.i, OBJ_BYTES(b), b->len, (int)ARG(1).u.i,
                           OBJ_BYTES(a), (int)a->len);
    return ret(vm, 4, mk_int(k));
}

static char *receive_buffer(VM *vm, int64_t n, const char *prim) {
    if (n < 0 || n > MAX_STRING) vm_fatal(vm, "primitive %s: bad length", prim);
    char *buf = malloc((size_t)n ? (size_t)n : 1);
    if (!buf) vm_fatal(vm, "out of memory");
    return buf;
}

static int p_socket_recv(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "socket_recv");
    check_tag(vm, ARG(1), T_INT, "socket_recv");
    check_tag(vm, ARG(0), T_INT, "socket_recv");
    int64_t n = ARG(1).u.i;
    char *buf = receive_buffer(vm, n, "socket_recv");
    int64_t got = sys_recv((int)ARG(2).u.i, buf, n, (int)ARG(0).u.i);
    Obj *s = vm_string_from(vm, buf, got < 0 ? 0 : (uint32_t)got);
    free(buf);
    return ret(vm, 3, mk_ptr(s));
}

static int p_socket_recvfrom(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "socket_recvfrom");
    check_tag(vm, ARG(1), T_INT, "socket_recvfrom");
    check_tag(vm, ARG(0), T_INT, "socket_recvfrom");
    int64_t n = ARG(1).u.i;
    char *buf = receive_buffer(vm, n, "socket_recvfrom");
    int64_t got = sys_recvfrom((int)ARG(2).u.i, buf, n, (int)ARG(0).u.i);
    if (got < 0) { free(buf); return push_int_list(vm, NULL, 0, 3); }
    /* the bytes, then the address, built on the stack so the collector sees them */
    vm_push(vm, mk_con0(0));
    vm_push(vm, mk_ptr(vm_string_from(vm, sys_last_addr(), (uint32_t)sys_last_addr_len())));
    vm_cons(vm);
    vm_push(vm, mk_ptr(vm_string_from(vm, buf, (uint32_t)got)));
    vm_cons(vm);
    free(buf);
    Value l = vm_pop(vm);
    return ret(vm, 3, l);
}

static int p_socket_shutdown(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "socket_shutdown");
    check_tag(vm, ARG(0), T_INT, "socket_shutdown");
    return ret(vm, 2, mk_int(sys_shutdown((int)ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_socket_name(VM *vm) { INT1("socket_name"); return push_last_addr(vm, sys_sock_name((int)x), 1); }
static int p_socket_peer(VM *vm) { INT1("socket_peer"); return push_last_addr(vm, sys_sock_peer((int)x), 1); }

static int p_socket_getopt(VM *vm) {
    check_tag(vm, ARG(2), T_INT, "socket_getopt");
    check_tag(vm, ARG(1), T_INT, "socket_getopt");
    check_tag(vm, ARG(0), T_INT, "socket_getopt");
    return ret(vm, 3, mk_int(sys_getsockopt((int)ARG(2).u.i, (int)ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_socket_setopt(VM *vm) {
    check_tag(vm, ARG(3), T_INT, "socket_setopt");
    check_tag(vm, ARG(2), T_INT, "socket_setopt");
    check_tag(vm, ARG(1), T_INT, "socket_setopt");
    check_tag(vm, ARG(0), T_INT, "socket_setopt");
    return ret(vm, 4, mk_int(sys_setsockopt((int)ARG(3).u.i, (int)ARG(2).u.i,
                                            (int)ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_socket_inet_addr(VM *vm) {
    char *host = c_string(vm, ARG(1), "socket_inet_addr");
    check_tag(vm, ARG(0), T_INT, "socket_inet_addr");
    int ok = sys_inet_addr(host, (int)ARG(0).u.i);
    free(host);
    return push_last_addr(vm, ok, 2);
}

static int p_socket_inet6_addr(VM *vm) {
    char *host = c_string(vm, ARG(1), "socket_inet6_addr");
    check_tag(vm, ARG(0), T_INT, "socket_inet6_addr");
    int ok = sys_inet6_addr(host, (int)ARG(0).u.i);
    free(host);
    return push_last_addr(vm, ok, 2);
}

static int p_socket_unix_addr(VM *vm) {
    char *path = c_string(vm, ARG(0), "socket_unix_addr");
    int ok = sys_unix_addr(path);
    free(path);
    return push_last_addr(vm, ok, 1);
}

static int p_socket_addr_family(VM *vm) {
    Obj *a = check_obj(vm, ARG(0), K_STRING, "socket_addr_family");
    return ret(vm, 1, mk_int(sys_addr_family(OBJ_BYTES(a), (int)a->len)));
}

static int p_socket_inet_parts(VM *vm) {
    Obj *a = check_obj(vm, ARG(0), K_STRING, "socket_inet_parts");
    int port = 0;
    const char *host = sys_inet_parts(OBJ_BYTES(a), (int)a->len, &port);
    if (!host) return push_int_list(vm, NULL, 0, 1);
    char buffer[32];
    snprintf(buffer, sizeof buffer, "%d", port);
    vm_push(vm, mk_con0(0));
    vm_push(vm, mk_ptr(vm_string_from(vm, buffer, (uint32_t)strlen(buffer))));
    vm_cons(vm);
    vm_push(vm, mk_ptr(vm_string_from(vm, host, (uint32_t)strlen(host))));
    vm_cons(vm);
    Value l = vm_pop(vm);
    return ret(vm, 1, l);
}

static int p_socket_inet6_parts(VM *vm) {
    Obj *a = check_obj(vm, ARG(0), K_STRING, "socket_inet6_parts");
    int port = 0;
    const char *host = sys_inet6_parts(OBJ_BYTES(a), (int)a->len, &port);
    if (!host) return push_int_list(vm, NULL, 0, 1);
    char buffer[32];
    snprintf(buffer, sizeof buffer, "%d", port);
    vm_push(vm, mk_con0(0));
    vm_push(vm, mk_ptr(vm_string_from(vm, buffer, (uint32_t)strlen(buffer))));
    vm_cons(vm);
    vm_push(vm, mk_ptr(vm_string_from(vm, host, (uint32_t)strlen(host))));
    vm_cons(vm);
    Value l = vm_pop(vm);
    return ret(vm, 1, l);
}

static int p_socket_unix_path(VM *vm) {
    Obj *a = check_obj(vm, ARG(0), K_STRING, "socket_unix_path");
    const char *path = sys_unix_path(OBJ_BYTES(a), (int)a->len);
    return push_string_value(vm, path ? path : "");
}

#define NETDB_NAME(name, call)                                  \
    static int p_##name(VM *vm) {                               \
        char *arg = c_string(vm, ARG(0), #name);                \
        const char *packed = call(arg);                         \
        free(arg);                                              \
        return push_strings(vm, packed ? packed : "", 1);       \
    }
NETDB_NAME(netdb_host_byname, sys_host_byname)
NETDB_NAME(netdb_host_byaddr, sys_host_byaddr)
NETDB_NAME(netdb_proto_byname, sys_proto_byname)

static int p_netdb_hostname(VM *vm) {
    const char *name = sys_hostname();
    return push_string_value(vm, name ? name : "");
}

static int p_netdb_proto_bynumber(VM *vm) {
    INT1("netdb_proto_bynumber");
    const char *packed = sys_proto_bynumber((int)x);
    return push_strings(vm, packed ? packed : "", 1);
}

static int p_netdb_serv_byname(VM *vm) {
    char *name = c_string(vm, ARG(1), "netdb_serv_byname");
    char *protocol = c_string(vm, ARG(0), "netdb_serv_byname");
    const char *packed = sys_serv_byname(name, protocol);
    free(name);
    free(protocol);
    return push_strings(vm, packed ? packed : "", 2);
}

static int p_netdb_serv_byport(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "netdb_serv_byport");
    char *protocol = c_string(vm, ARG(0), "netdb_serv_byport");
    const char *packed = sys_serv_byport((int)ARG(1).u.i, protocol);
    free(protocol);
    return push_strings(vm, packed ? packed : "", 2);
}

static int p_os_system(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "os_system");
    char *command = malloc((size_t)s->len + 1);
    if (!command) vm_fatal(vm, "out of memory");
    memcpy(command, OBJ_BYTES(s), s->len);
    command[s->len] = 0;
    fflush(stdout);
    int status = sys_system(command);
    free(command);
    return ret(vm, 1, mk_int(status));
}

static int p_os_getenv(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "os_getenv");
    char *name = malloc((size_t)s->len + 1);
    if (!name) vm_fatal(vm, "out of memory");
    memcpy(name, OBJ_BYTES(s), s->len);
    name[s->len] = 0;
    const char *value = sys_getenv(name);
    free(name);
    if (!value) return ret(vm, 1, mk_con0(0));
    Obj *o = vm_string_from(vm, value, (uint32_t)strlen(value));
    Value r = mk_some(vm, mk_ptr(o));
    return ret(vm, 1, r);
}

static int p_string_implode(VM *vm) {
    int64_t n = list_length(ARG(0));
    if (n < 0) vm_fatal(vm, "string_implode: malformed list");
    if (n > MAX_STRING) return raise_with(vm, 1, EXN_SIZE);
    Obj *r = vm_alloc_string(vm, (uint32_t)n);
    Value l = ARG(0);
    for (int64_t i = 0; i < n; i++) {
        Value c = list_head(l);
        if (c.tag != T_CHAR) vm_fatal(vm, "string_implode: non-char element");
        OBJ_BYTES(r)[i] = (char)c.u.i;
        l = list_tail(l);
    }
    return ret(vm, 1, mk_ptr(r));
}
static int p_string_explode(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "string_explode");
    uint32_t n = s->len;
    vm_push(vm, mk_con0(0));
    for (uint32_t i = n; i > 0; i--) {
        s = vm->stack[vm->sp - 2].u.p;
        vm_push(vm, mk_char((unsigned char)OBJ_BYTES(s)[i - 1]));
        vm_cons(vm);
    }
    Value l = vm_pop(vm);
    return ret(vm, 1, l);
}
static int p_string_concat_list(VM *vm) {
    Value l = ARG(0);
    uint64_t total = 0;
    int64_t n = list_length(l);
    if (n < 0) vm_fatal(vm, "string_concat_list: malformed list");
    for (Value x = l; x.tag == T_PTR; x = list_tail(x)) {
        Value s = list_head(x);
        if (s.tag != T_PTR || s.u.p->kind != K_STRING) vm_fatal(vm, "string_concat_list: non-string element");
        total += s.u.p->len;
    }
    if (total > MAX_STRING) return raise_with(vm, 1, EXN_SIZE);
    Obj *r = vm_alloc_string(vm, (uint32_t)total);
    uint32_t o = 0;
    for (Value x = ARG(0); x.tag == T_PTR; x = list_tail(x)) {
        Obj *s = list_head(x).u.p;
        memcpy(OBJ_BYTES(r) + o, OBJ_BYTES(s), s->len);
        o += s->len;
    }
    return ret(vm, 1, mk_ptr(r));
}

/* ================================================================ ref / array / vector */
static int p_ref_new(VM *vm) {
    Obj *r = vm_alloc_fields(vm, K_REF, 0, 1);
    OBJ_FIELDS(r)[0] = ARG(0);
    return ret(vm, 1, mk_ptr(r));
}
static int p_ref_get(VM *vm) { Obj *r = check_obj(vm, ARG(0), K_REF, "ref_get"); return ret(vm, 1, OBJ_FIELDS(r)[0]); }
static int p_ref_set(VM *vm) { Obj *r = check_obj(vm, ARG(1), K_REF, "ref_set"); OBJ_FIELDS(r)[0] = ARG(0); return ret(vm, 2, mk_unit()); }

static int p_array_new(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "array_new");
    int64_t n = ARG(1).u.i;
    if (n < 0 || n > 100000000) return raise_with(vm, 2, EXN_SIZE);
    Obj *a = vm_alloc_fields(vm, K_ARRAY, 0, (uint32_t)n);
    Value init = ARG(0);
    for (int64_t i = 0; i < n; i++) OBJ_FIELDS(a)[i] = init;
    return ret(vm, 2, mk_ptr(a));
}
static int p_array_length(VM *vm) { Obj *a = check_obj(vm, ARG(0), K_ARRAY, "array_length"); return ret(vm, 1, mk_int(a->len)); }
static int p_array_sub(VM *vm) {
    Obj *a = check_obj(vm, ARG(1), K_ARRAY, "array_sub");
    check_tag(vm, ARG(0), T_INT, "array_sub");
    int64_t i = ARG(0).u.i;
    if (i < 0 || (uint64_t)i >= a->len) return raise_with(vm, 2, EXN_SUBSCRIPT);
    return ret(vm, 2, OBJ_FIELDS(a)[i]);
}
static int p_array_update(VM *vm) {
    Obj *a = check_obj(vm, ARG(2), K_ARRAY, "array_update");
    check_tag(vm, ARG(1), T_INT, "array_update");
    int64_t i = ARG(1).u.i;
    if (i < 0 || (uint64_t)i >= a->len) return raise_with(vm, 3, EXN_SUBSCRIPT);
    OBJ_FIELDS(a)[i] = ARG(0);
    return ret(vm, 3, mk_unit());
}
static int from_list(VM *vm, int kind, const char *name) {
    int64_t n = list_length(ARG(0));
    if (n < 0) vm_fatal(vm, "%s: malformed list", name);
    if (n > 100000000) return raise_with(vm, 1, EXN_SIZE);
    Obj *a = vm_alloc_fields(vm, (uint8_t)kind, 0, (uint32_t)n);
    Value l = ARG(0);
    for (int64_t i = 0; i < n; i++) { OBJ_FIELDS(a)[i] = list_head(l); l = list_tail(l); }
    return ret(vm, 1, mk_ptr(a));
}
static int p_array_from_list(VM *vm) { return from_list(vm, K_ARRAY, "array_from_list"); }
static int p_vector_from_list(VM *vm) { return from_list(vm, K_TUPLE, "vector_from_list"); }
static int p_vector_length(VM *vm) { Obj *a = check_obj(vm, ARG(0), K_TUPLE, "vector_length"); return ret(vm, 1, mk_int(a->len)); }
static int p_vector_sub(VM *vm) {
    Obj *a = check_obj(vm, ARG(1), K_TUPLE, "vector_sub");
    check_tag(vm, ARG(0), T_INT, "vector_sub");
    int64_t i = ARG(0).u.i;
    if (i < 0 || (uint64_t)i >= a->len) return raise_with(vm, 2, EXN_SUBSCRIPT);
    return ret(vm, 2, OBJ_FIELDS(a)[i]);
}

/* ================================================================ I/O and system */
static int p_print(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "print");
    fwrite(OBJ_BYTES(s), 1, s->len, stdout);
    return ret(vm, 1, mk_unit());
}
static int p_print_err(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "print_err");
    fflush(stdout);
    fwrite(OBJ_BYTES(s), 1, s->len, stderr);
    return ret(vm, 1, mk_unit());
}
static int p_flush_out(VM *vm) { fflush(stdout); return ret(vm, 1, mk_unit()); }

/* Read one line (including its newline) from f; a final line without a
   newline gets one (Basis). Pops `arity` arguments, pushes string option. */
static int read_line(VM *vm, FILE *f, int arity) {
    size_t cap = 128, n = 0;
    char *buf = malloc(cap);
    int c;
    while ((c = fgetc(f)) != EOF) {
        if (n + 1 >= cap) { cap *= 2; buf = realloc(buf, cap); }
        buf[n++] = (char)c;
        if (c == '\n') break;
    }
    if (n == 0) { free(buf); return ret(vm, arity, mk_con0(0)); }
    if (buf[n - 1] != '\n') buf[n++] = '\n';
    Obj *s = vm_string_from(vm, buf, (uint32_t)n);
    free(buf);
    Value r = mk_some(vm, mk_ptr(s));
    return ret(vm, arity, r);
}
/* Read the rest of f into a string. */
static int read_all(VM *vm, FILE *f, int arity) {
    size_t cap = 4096, n = 0;
    char *buf = malloc(cap);
    size_t k;
    while ((k = fread(buf + n, 1, cap - n, f)) > 0) {
        n += k;
        if (n == cap) { cap *= 2; buf = realloc(buf, cap); }
    }
    Obj *s = vm_string_from(vm, buf, (uint32_t)n);
    free(buf);
    return ret(vm, arity, mk_ptr(s));
}
static int p_input_line(VM *vm) { return read_line(vm, stdin, 1); }
static int p_input_all(VM *vm) { return read_all(vm, stdin, 1); }

/* --- files: handles index vm->files; invalid or closed handles yield NULL --- */
static FILE *file_of(VM *vm, Value h, const char *prim) {
    check_tag(vm, h, T_INT, prim);
    int64_t i = h.u.i;
    if (i < 0 || (uint64_t)i >= vm->nfiles) return NULL;
    return vm->files[i];
}
static int p_file_open(VM *vm) {
    Obj *s = check_obj(vm, ARG(1), K_STRING, "file_open");
    check_tag(vm, ARG(0), T_INT, "file_open");
    int64_t mode = ARG(0).u.i;
    const char *m = mode == 0 ? "rb" : mode == 1 ? "wb" : mode == 2 ? "ab" : NULL;
    if (!m) vm_fatal(vm, "primitive file_open: bad mode");
    char *path = malloc((size_t)s->len + 1);
    if (!path) vm_fatal(vm, "out of memory");
    memcpy(path, OBJ_BYTES(s), s->len);
    path[s->len] = 0;
    FILE *f = NULL;
    if (strlen(path) != s->len) vm->io_errno = EINVAL;   /* embedded NUL */
    else { f = sys_fopen(path, m); if (!f) vm->io_errno = errno; }
    if (!f) { free(path); return ret(vm, 2, mk_con0(0)); }
    char *kept = path;
    if (vm->nfiles == vm->files_cap) {
        vm->files_cap *= 2;
        vm->files = realloc(vm->files, vm->files_cap * sizeof(FILE *));
        vm->file_modes = realloc(vm->file_modes, vm->files_cap);
        vm->file_paths = realloc(vm->file_paths, vm->files_cap * sizeof(char *));
        if (!vm->files || !vm->file_modes || !vm->file_paths) vm_fatal(vm, "out of memory");
    }
    int64_t h = (int64_t)vm->nfiles;
    vm->file_modes[vm->nfiles] = (uint8_t)mode;
    /* kept so that Runtime.save can name the file again: a saved image is
       read by a process that inherited no descriptor from this one */
    vm->file_paths[vm->nfiles] = kept;
    vm->files[vm->nfiles++] = f;
    Value r = mk_some(vm, mk_int(h));   /* may collect; the path string is no longer needed */
    return ret(vm, 2, r);
}
static int p_file_close(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "file_close");
    int64_t i = ARG(0).u.i;
    if (i >= 3 && (uint64_t)i < vm->nfiles && vm->files[i]) {
        fclose(vm->files[i]);
        vm->files[i] = NULL;
        free(vm->file_paths[i]);
        vm->file_paths[i] = NULL;
    }
    return ret(vm, 1, mk_unit());
}
static int p_file_write(VM *vm) {
    FILE *f = file_of(vm, ARG(1), "file_write");
    Obj *s = check_obj(vm, ARG(0), K_STRING, "file_write");
    if (!f) { vm->io_errno = EBADF; return ret(vm, 2, mk_bool(0)); }
    if (f == stderr) fflush(stdout);
    if (fwrite(OBJ_BYTES(s), 1, s->len, f) != s->len) { vm->io_errno = errno; return ret(vm, 2, mk_bool(0)); }
    return ret(vm, 2, mk_bool(1));
}
static int p_file_flush(VM *vm) {
    FILE *f = file_of(vm, ARG(0), "file_flush");
    if (f) fflush(f);
    return ret(vm, 1, mk_unit());
}
static int p_file_read_line(VM *vm) {
    FILE *f = file_of(vm, ARG(0), "file_read_line");
    if (!f) return ret(vm, 1, mk_con0(0));
    return read_line(vm, f, 1);
}
static int p_file_read_all(VM *vm) {
    FILE *f = file_of(vm, ARG(0), "file_read_all");
    if (!f) return ret(vm, 1, mk_ptr(vm_string_from(vm, "", 0)));
    return read_all(vm, f, 1);
}
/* Read at most n bytes; the empty string at end of file. */
static int p_file_read_vec(VM *vm) {
    FILE *f = file_of(vm, ARG(1), "file_read_vec");
    check_tag(vm, ARG(0), T_INT, "file_read_vec");
    int64_t n = ARG(0).u.i;
    if (n < 0 || n > MAX_STRING) return raise_with(vm, 2, EXN_SIZE);
    if (!f) return ret(vm, 2, mk_ptr(vm_string_from(vm, "", 0)));
    char *buf = malloc((size_t)n ? (size_t)n : 1);
    if (!buf) vm_fatal(vm, "out of memory");
    size_t got = fread(buf, 1, (size_t)n, f);
    Obj *s = vm_string_from(vm, buf, (uint32_t)got);
    free(buf);
    return ret(vm, 2, mk_ptr(s));
}

/* What a seekable file has left; ~1 for anything else, which the library
   reads as "cannot be told without waiting". */
static int p_file_avail(VM *vm) {
    FILE *f = file_of(vm, ARG(0), "file_avail");
    if (!f) return ret(vm, 1, mk_int(0));
    int64_t here = sys_ftell(f);
    if (here < 0) return ret(vm, 1, mk_int(-1));
    if (sys_fseek(f, 0, SEEK_END) != 0) return ret(vm, 1, mk_int(-1));
    int64_t end = sys_ftell(f);
    if (sys_fseek(f, here, SEEK_SET) != 0 || end < 0) return ret(vm, 1, mk_int(-1));
    return ret(vm, 1, mk_int(end - here));
}

static int p_file_errno(VM *vm) { return ret(vm, 1, mk_int(vm->io_errno)); }

/* file_tell h: the position of the file, in bytes, or -1 (not a file that
   has positions, or an invalid handle). */
static int p_file_tell(VM *vm) {
    FILE *f = file_of(vm, ARG(0), "file_tell");
    int64_t here = f ? sys_ftell(f) : -1;
    if (here < 0) vm->io_errno = errno;
    return ret(vm, 1, mk_int(here < 0 ? -1 : here));
}

/* file_seek (h, p): move to byte p from the start (flushing what is
   written first, as fseek does); 0, or -1 on failure. */
static int p_file_seek(VM *vm) {
    FILE *f = file_of(vm, ARG(1), "file_seek");
    check_tag(vm, ARG(0), T_INT, "file_seek");
    int ok = f && ARG(0).u.i >= 0 && sys_fseek(f, ARG(0).u.i, SEEK_SET) == 0;
    if (!ok) vm->io_errno = f ? errno : EBADF;
    return ret(vm, 2, mk_int(ok ? 0 : -1));
}

/* The handles of the library are indices of the VM's table; the system
   knows the descriptors of the files behind them. */
static int descriptor_of(VM *vm, Value h, const char *prim) {
    FILE *f = file_of(vm, h, prim);
    return f ? sys_fileno(f) : -1;
}

/* ================================================================ POSIX */
static int p_posix_const(VM *vm) {
    char *name = c_string(vm, ARG(0), "posix_const");
    int64_t v = sys_const(name);
    free(name);
    return ret(vm, 1, mk_int(v));
}

/* The strings of a list, as a NULL-terminated array the caller frees. */
static char **string_array(VM *vm, Value l, const char *prim, const char *first) {
    int64_t n = list_length(l);
    if (n < 0) vm_fatal(vm, "primitive %s: malformed list", prim);
    int extra = first ? 1 : 0;
    char **out = calloc((size_t)n + (size_t)extra + 1, sizeof *out);
    if (!out) vm_fatal(vm, "out of memory");
    if (first) {
        out[0] = malloc(strlen(first) + 1);
        if (!out[0]) vm_fatal(vm, "out of memory");
        strcpy(out[0], first);
    }
    for (int64_t i = 0; i < n; i++) {
        Obj *s = check_obj(vm, list_head(l), K_STRING, prim);
        out[i + extra] = malloc((size_t)s->len + 1);
        if (!out[i + extra]) vm_fatal(vm, "out of memory");
        memcpy(out[i + extra], OBJ_BYTES(s), s->len);
        out[i + extra][s->len] = 0;
        l = list_tail(l);
    }
    return out;
}

static void free_array(char **a) {
    if (!a) return;
    for (char **p = a; *p; p++) free(*p);
    free(a);
}

/* Where the system has no fork, or runevm is given --emulate-fork, the child
   is a second VM handed this one's state (vm/image.c), which is written
   while the argument is still on the stack. */
static int p_posix_fork(VM *vm) {
    fflush(stdout);
    fflush(stderr);
    if (vm->emulate_fork || !sys_has_fork()) return ret(vm, 1, mk_int(vm_fork(vm)));
    return ret(vm, 1, mk_int(sys_fork()));
}

static int exec_with(VM *vm, Value pathValue, Value argsValue, char **envp, int search, int arity) {
    char *path = c_string(vm, pathValue, "posix_exec");
    char **argv = string_array(vm, argsValue, "posix_exec", NULL);
    fflush(stdout);
    fflush(stderr);
    int r = sys_exec(path, argv, envp, search);
    free(path);
    free_array(argv);
    free_array(envp);
    return ret(vm, arity, mk_int(r));
}

static int p_posix_exec(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "posix_exec");
    return exec_with(vm, ARG(2), ARG(1), NULL, (int)ARG(0).u.i, 3);
}

/* posix_spawn (path, args, env, flags, fds) */
static int p_posix_spawn(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "posix_spawn");
    int32_t given[3];
    if (int_list(ARG(0), given, 3) != 3) vm_fatal(vm, "primitive posix_spawn: malformed descriptors");
    int64_t flags = ARG(1).u.i;
    char *path = c_string(vm, ARG(4), "posix_spawn");
    char **argv = string_array(vm, ARG(3), "posix_spawn", NULL);
    char **envp = (flags & 2) ? string_array(vm, ARG(2), "posix_spawn", NULL) : NULL;
    int fds[3] = { given[0], given[1], given[2] };
    fflush(stdout);
    fflush(stderr);
    int64_t pid = sys_spawn(path, argv, envp, (int)(flags & 1), fds);
    free(path);
    free_array(argv);
    free_array(envp);
    return ret(vm, 5, mk_int(pid));
}

static int p_posix_exece(VM *vm) {
    char **envp = string_array(vm, ARG(0), "posix_exece", NULL);
    return exec_with(vm, ARG(2), ARG(1), envp, 0, 3);
}

static int p_posix_waitpid(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "posix_waitpid");
    check_tag(vm, ARG(0), T_INT, "posix_waitpid");
    int64_t out[3];
    int ok = sys_waitpid(ARG(1).u.i, (int)ARG(0).u.i, out);
    return push_int_list(vm, out, ok == 0 ? 3 : 0, 2);
}

static int p_posix_kill(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "posix_kill");
    check_tag(vm, ARG(0), T_INT, "posix_kill");
    return ret(vm, 2, mk_int(sys_kill(ARG(1).u.i, (int)ARG(0).u.i)));
}

static int p_posix_alarm(VM *vm) { INT1("posix_alarm"); return ret(vm, 1, mk_int(sys_alarm((int)x))); }
static int p_posix_pause(VM *vm) { return ret(vm, 1, mk_int(sys_pause())); }
static int p_posix_getpid(VM *vm) { return ret(vm, 1, mk_int(sys_getpid())); }
static int p_posix_getppid(VM *vm) { return ret(vm, 1, mk_int(sys_getppid())); }
static int p_posix_getuid(VM *vm) { return ret(vm, 1, mk_int(sys_getuid())); }
static int p_posix_geteuid(VM *vm) { return ret(vm, 1, mk_int(sys_geteuid())); }
static int p_posix_getgid(VM *vm) { return ret(vm, 1, mk_int(sys_getgid())); }
static int p_posix_getegid(VM *vm) { return ret(vm, 1, mk_int(sys_getegid())); }
static int p_posix_setuid(VM *vm) { INT1("posix_setuid"); return ret(vm, 1, mk_int(sys_setuid(x))); }
static int p_posix_setgid(VM *vm) { INT1("posix_setgid"); return ret(vm, 1, mk_int(sys_setgid(x))); }

static int p_posix_getgroups(VM *vm) {
    int64_t groups[256];
    int n = sys_getgroups(groups, 256);
    return push_int_list(vm, groups, n < 0 ? 0 : n, 1);
}

static int p_posix_getlogin(VM *vm) {
    const char *name = sys_getlogin();
    return push_string_value(vm, name ? name : "");
}

static int p_posix_getpgrp(VM *vm) { return ret(vm, 1, mk_int(sys_getpgrp())); }
static int p_posix_setsid(VM *vm) { return ret(vm, 1, mk_int(sys_setsid())); }

static int p_posix_setpgid(VM *vm) {
    check_tag(vm, ARG(1), T_INT, "posix_setpgid");
    check_tag(vm, ARG(0), T_INT, "posix_setpgid");
    return ret(vm, 2, mk_int(sys_setpgid(ARG(1).u.i, ARG(0).u.i)));
}

static int p_posix_uname(VM *vm) { return push_strings(vm, sys_uname(), 1); }

static int p_posix_times(VM *vm) {
    int64_t out[5];
    int ok = sys_times(out);
    return push_int_list(vm, out, ok == 0 ? 5 : 0, 1);
}

static int p_posix_environ(VM *vm) { return push_strings(vm, sys_environ(), 1); }

static int p_posix_ctermid(VM *vm) {
    const char *name = sys_ctermid();
    return push_string_value(vm, name ? name : "");
}

/* These four take a descriptor of the system, as Posix and the sockets have
   them; file_descriptor gives the one of a handle of the VM's table. */
static int p_file_descriptor(VM *vm) {
    return ret(vm, 1, mk_int(descriptor_of(vm, ARG(0), "file_descriptor")));
}

static int p_posix_ttyname(VM *vm) {
    INT1("posix_ttyname");
    int fd = (int)x;
    const char *name = fd < 0 ? NULL : sys_ttyname(fd);
    return push_string_value(vm, name ? name : "");
}

static int p_posix_isatty(VM *vm) {
    INT1("posix_isatty");
    int fd = (int)x;
    return ret(vm, 1, mk_int(fd < 0 ? 0 : sys_isatty(fd)));
}

static int p_posix_sysconf(VM *vm) {
    char *name = c_string(vm, ARG(0), "posix_sysconf");
    int64_t v = sys_sysconf(name);
    free(name);
    return ret(vm, 1, mk_int(v));
}

static int p_os_desc_kind(VM *vm) {
    INT1("os_desc_kind");
    int fd = (int)x;
    return ret(vm, 1, mk_int(fd < 0 ? -1 : sys_desc_kind(fd)));
}

static int p_os_poll(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "os_poll");
    int64_t n = list_length(ARG(2));
    if (n < 0 || list_length(ARG(1)) != n) vm_fatal(vm, "primitive os_poll: malformed list");
    int32_t *fds = malloc((size_t)(n > 0 ? n : 1) * sizeof *fds);
    int32_t *events = malloc((size_t)(n > 0 ? n : 1) * sizeof *events);
    if (!fds || !events) vm_fatal(vm, "out of memory");
    if (int_list(ARG(2), fds, (int)n) != n || int_list(ARG(1), events, (int)n) != n)
        vm_fatal(vm, "primitive os_poll: malformed list");
    int *wide_fds = calloc((size_t)(n > 0 ? n : 1), sizeof *wide_fds);
    int *wide_events = calloc((size_t)(n > 0 ? n : 1), sizeof *wide_events);
    if (!wide_fds || !wide_events) vm_fatal(vm, "out of memory");
    for (int i = 0; i < (int)n; i++) {
        wide_fds[i] = fds[i];
        wide_events[i] = events[i];
    }
    int ready = sys_poll(wide_fds, wide_events, (int)n, ARG(0).u.i);
    int64_t *out = malloc((size_t)(n > 0 ? n : 1) * sizeof *out);
    if (!out) vm_fatal(vm, "out of memory");
    for (int i = 0; i < (int)n; i++) out[i] = wide_events[i];
    free(fds); free(events); free(wide_fds); free(wide_events);
    int r = push_int_list(vm, out, ready < 0 ? 0 : (int)n, 3);
    free(out);
    return r;
}

static int p_file_error(VM *vm) {
    const char *m = strerror(vm->io_errno);
    return ret(vm, 1, mk_ptr(vm_string_from(vm, m, (uint32_t)strlen(m))));
}
static int p_exit(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "exit");
    vm_exit(vm, (int)ARG(0).u.i);
    return 0;
}
/* Posix.Process.exit: at once, with nothing flushed. */
static int p_posix_exit(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "posix_exit");
    sys_exit_now((int)ARG(0).u.i);
    return 0;
}
static int p_command_args(VM *vm) {
    vm_push(vm, mk_con0(0));
    for (int i = vm->argc; i > 0; i--) {
        Obj *s = vm_string_from(vm, vm->argv[i - 1], (uint32_t)strlen(vm->argv[i - 1]));
        vm_push(vm, mk_ptr(s));
        vm_cons(vm);
    }
    Value l = vm_pop(vm);
    return ret(vm, 1, l);
}
static int p_command_name(VM *vm) {
    return ret(vm, 1, mk_ptr(vm_string_from(vm, vm->progname, (uint32_t)strlen(vm->progname))));
}

/* ================================================================ runtime (Runtime) */

/* The counters the VM keeps for the program it is running. None of these
   allocates, so a program reading all six sees one consistent set: only an
   allocation can move the numbers of the heap. */
static int p_rt_instructions(VM *vm) { return ret(vm, 1, mk_int((int64_t)vm->instructions)); }
static int p_rt_bytes(VM *vm) { return ret(vm, 1, mk_int((int64_t)vm->bytes_allocated)); }
static int p_rt_objects(VM *vm) { return ret(vm, 1, mk_int((int64_t)vm->objects_allocated)); }
static int p_rt_collections(VM *vm) { return ret(vm, 1, mk_int((int64_t)vm->gc_count)); }
static int p_rt_live(VM *vm) { return ret(vm, 1, mk_int((int64_t)vm->heap_used)); }
static int p_rt_heap_size(VM *vm) { return ret(vm, 1, mk_int((int64_t)vm->heap_size)); }

/* A collection on demand. It moves every object, so nothing of the heap may
   be held in a C variable across it; the argument on the stack is unit, and
   the collector walks the stack itself. */
static int p_rt_collect(VM *vm) { vm_gc(vm, 0); return ret(vm, 1, mk_unit()); }

/* One frame as (name, file, line, column), built on the VM stack: every
   allocation here can collect, and the strings must survive the next one. */
static void push_frame(VM *vm, const char *name, const char *file, int64_t line, int64_t col) {
    vm_push(vm, mk_ptr(vm_string_from(vm, name, (uint32_t)strlen(name))));
    vm_push(vm, mk_ptr(vm_string_from(vm, file, (uint32_t)strlen(file))));
    vm_push(vm, mk_int(line));
    vm_push(vm, mk_int(col));
    Obj *t = vm_alloc_fields(vm, K_TUPLE, 0, 4);
    for (int i = 0; i < 4; i++) OBJ_FIELDS(t)[i] = vm->stack[vm->sp - 4 + i];
    vm->sp -= 4;
    vm_push(vm, mk_ptr(t));
}

/* The frames, innermost first, leaving out the innermost `skip` of them --
   which is how Runtime keeps its own frames out of what it reports. Built
   from the outermost inwards so that each cons puts its frame at the head. */
static int p_rt_trace(VM *vm) {
    INT1("rt_trace");
    size_t skip = x < 0 ? 0 : (size_t)x;
    vm_push(vm, mk_con0(0));
    if (vm->frames_active && vm->fp + 1 > skip) {
        size_t last = vm->fp - skip;
        for (size_t i = 0; i <= last; i++) {
            uint32_t f = vm->frames[i].func;
            const char *name = f < vm->prog.nfuncs ? vm->prog.funcs[f].name : "?";
            uint32_t pc = (i == vm->fp) ? vm->pc : vm->frames[i + 1].ret_pc;
            const LineEntry *e = line_at(&vm->prog, pc > 0 ? pc - 1 : 0);
            if (e && e->file < vm->prog.nfiles)
                push_frame(vm, name, vm->prog.files[e->file], e->line, e->col);
            else
                push_frame(vm, name, "", 0, 0);
            vm_cons(vm);
        }
    }
    Value l = vm_pop(vm);
    return ret(vm, 1, l);
}

/* Runtime.save: 0 in the world that writes the image, and 1 -- `Restored` --
   in the world that starts again from it, which vm_resume pushes in place of
   this call's argument. ~1 says the image could not be written. */
static int p_rt_save(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "rt_save");
    char *path = malloc((size_t)s->len + 1);
    if (!path) vm_fatal(vm, "out of memory");
    memcpy(path, OBJ_BYTES(s), s->len);
    path[s->len] = 0;
    int ok = strlen(path) == s->len && vm_save(vm, path);
    free(path);
    return ret(vm, 1, mk_int(ok ? 0 : -1));
}

/* Runtime.restore: on success this world is gone and the loop carries on in
   the one the image holds, which read_image has already left ready -- so
   there is no result to return here, and none to return it onto. ~1 and the
   old world on failure. */
static int p_rt_restore(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "rt_restore");
    char *path = malloc((size_t)s->len + 1);
    if (!path) vm_fatal(vm, "out of memory");
    memcpy(path, OBJ_BYTES(s), s->len);
    path[s->len] = 0;
    int ok = strlen(path) == s->len && vm_become(vm, path);
    free(path);
    if (ok) return PRIM_NEW_WORLD;
    return ret(vm, 1, mk_int(-1));
}

static int p_rt_version(VM *vm) {
    return ret(vm, 1, mk_ptr(vm_string_from(vm, RUNE_VERSION, (uint32_t)strlen(RUNE_VERSION))));
}

/* ================================================================ table (generated order from prims.def) */
#define PRIM_ENTRY(name) p_##name,
const PrimFn prim_table[PRIM__COUNT] = {
    RUNE_PRIM_LIST(PRIM_ENTRY)
};
