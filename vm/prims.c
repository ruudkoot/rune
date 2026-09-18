/* Primitive operations. Each primitive pops its arguments and pushes a result,
   or raises an SML exception (returning 1 after unwinding the machine).
   Arguments are read from the stack (not popped) until the result exists, so
   that a garbage collection during allocation keeps them alive. */
#include "vm.h"
#include <math.h>
#include <errno.h>

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

static int p_real_from_string(VM *vm) {
    Obj *s = check_obj(vm, ARG(0), K_STRING, "real_from_string");
    char buf[128];
    uint32_t n = s->len < sizeof buf - 1 ? s->len : (uint32_t)(sizeof buf - 1);
    const char *b = OBJ_BYTES(s);
    uint32_t i = 0, o = 0;
    while (i < n && (b[i] == ' ' || b[i] == '\t' || b[i] == '\n')) i++;
    for (; i < n; i++) buf[o++] = b[i] == '~' ? '-' : b[i];
    buf[o] = 0;
    if (o == 0 || !((buf[0] >= '0' && buf[0] <= '9') || buf[0] == '-' || buf[0] == '+' || buf[0] == '.'))
        return ret(vm, 1, mk_con0(0));
    char *end;
    errno = 0;
    double d = strtod(buf, &end);
    if (end == buf) return ret(vm, 1, mk_con0(0));
    Value r = mk_some(vm, mk_real(d));
    return ret(vm, 1, r);
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
    else { f = fopen(path, m); if (!f) vm->io_errno = errno; }
    free(path);
    if (!f) return ret(vm, 2, mk_con0(0));
    if (vm->nfiles == vm->files_cap) {
        vm->files_cap *= 2;
        vm->files = realloc(vm->files, vm->files_cap * sizeof(FILE *));
        if (!vm->files) vm_fatal(vm, "out of memory");
    }
    int64_t h = (int64_t)vm->nfiles;
    vm->files[vm->nfiles++] = f;
    Value r = mk_some(vm, mk_int(h));   /* may collect; the path string is no longer needed */
    return ret(vm, 2, r);
}
static int p_file_close(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "file_close");
    int64_t i = ARG(0).u.i;
    if (i >= 3 && (uint64_t)i < vm->nfiles && vm->files[i]) { fclose(vm->files[i]); vm->files[i] = NULL; }
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
static int p_file_error(VM *vm) {
    const char *m = strerror(vm->io_errno);
    return ret(vm, 1, mk_ptr(vm_string_from(vm, m, (uint32_t)strlen(m))));
}
static int p_exit(VM *vm) {
    check_tag(vm, ARG(0), T_INT, "exit");
    vm_exit(vm, (int)ARG(0).u.i);
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

/* ================================================================ table (generated order from prims.def) */
#define PRIM_ENTRY(name) p_##name,
const PrimFn prim_table[PRIM__COUNT] = {
    RUNE_PRIM_LIST(PRIM_ENTRY)
};
