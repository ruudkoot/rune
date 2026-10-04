/* kernels.c -- the SML-shaped kernels, written against layouts/iface.h.
   Every live value that must survive an allocation sits in a root slot
   (PROOT_PUSH / RROOT_PUSH / IROOT_PUSH) and is re-read from it afterwards;
   the constructors' fast paths never spill (see harness.h GUARDn). Every
   result feeds ck_add; SINK stops the compiler from removing work. */
#include "harness.h"

#if defined(L1_UNBOXED_LOCALS) || defined(UNBOXED_LOCALS)
#define UNBOXED 1
#else
#define UNBOXED 0
#endif

/* ================= closures' function table ================= */
enum { FN_ADDK = 0, FN_ADD2, FN_MUL3, FN_COUNT };
static val fn_addk(obj *clo, val x) {
    val r;
    if (add_ov(POLY_TO_MONO_INT(x), closure_env(clo, 0), &r)) die("overflow");
    return MONO_TO_POLY_INT(r);
}
static val fn_add2(obj *clo, val x) {   /* fn x => x + a + b */
    val r;
    if (add_ov(POLY_TO_MONO_INT(x), closure_env(clo, 0), &r)) die("overflow");
    if (add_ov(r, closure_env(clo, 1), &r)) die("overflow");
    return MONO_TO_POLY_INT(r);
}
static val fn_mul3(obj *clo, val x) {   /* fn x => x * a + b - c */
    val r;
    if (mul_ov(POLY_TO_MONO_INT(x), closure_env(clo, 0), &r)) die("overflow");
    if (add_ov(r, closure_env(clo, 1), &r)) die("overflow");
    if (sub_ov(r, closure_env(clo, 2), &r)) die("overflow");
    return MONO_TO_POLY_INT(r);
}
fnptr fntab[FN_COUNT] = { fn_addk, fn_add2, fn_mul3 };
fnptr *volatile fntab_p = fntab;

/* ================= lists ================= */
static NOINLINE val list_tabulate(int64_t n) {
    val *acc = PROOT_PUSH(NIL);
    for (int64_t i = n - 1; i >= 0; i--) {
        val x = POLY_VAL_INT(i);
        *acc = cons(x, *acc);
    }
    val r = *acc; ROOT_POP();
    return r;
}
/* map f (x :: xs) = f x :: map f xs */
static NOINLINE val list_map(val f, val l) {
    if (is_nil(l)) return NIL;
    val *fs = PROOT_PUSH(f), *ls = PROOT_PUSH(l);
    val h = closure_call(f, head(l));
    val *hs = IROOT_PUSH(h);
    val t = list_map(*fs, tail(*ls));
    h = *hs; IROOT_POP();
    val r = cons(h, t);
    ROOT_POP(); ROOT_POP();
    return r;
}
/* foldl (op +) 0 */
static NOINLINE val list_sum(val l) {
    val acc = MONO_INT(0);
    while (!is_nil(l)) {
        if (add_ov(acc, POLY_TO_MONO_INT(head(l)), &acc)) die("overflow");
        l = tail(l);
    }
    return acc;
}
static NOINLINE int64_t list_length(val l) {
    int64_t n = 0;
    while (!is_nil(l)) { n++; l = tail(l); }
    return n;
}
static NOINLINE val list_rev(val l) {
    val *ls = PROOT_PUSH(l), *acc = PROOT_PUSH(NIL);
    while (!is_nil(*ls)) {
        val h = head(*ls);
        *acc = cons(h, *acc);
        *ls = tail(*ls);
    }
    val r = *acc; ROOT_POP(); ROOT_POP();
    return r;
}
static NOINLINE val list_append(val l, val r) {
    if (is_nil(l)) return r;
    val *ls = PROOT_PUSH(l);
    val t = list_append(tail(l), r);
    val h = head(*ls);
    ROOT_POP();
    return cons(h, t);
}

#define LIST_ELEMS 100000
static NOINLINE void k_list_ops(int64_t n) {
    int64_t rounds = n / LIST_ELEMS; if (rounds < 1) rounds = 1;
    for (int64_t r = 0; r < rounds; r++) {
        ROOT_MARK_T mark = ROOT_MARK();
        val *ls = PROOT_PUSH(list_tabulate(LIST_ELEMS));
        val env[1] = { MONO_INT(1) };
        val *fs = PROOT_PUSH(closure_new(FN_ADDK, 1, env, 0));
        val *ms = PROOT_PUSH(list_map(*fs, *ls));
        ck_add((uint64_t)MONO_INT_OF(list_sum(*ms)));
        val *rs = PROOT_PUSH(list_rev(*ms));
        val a = list_append(*ls, *rs);
        ck_add((uint64_t)list_length(a));
        ck_add((uint64_t)MONO_INT_OF(list_sum(*rs)));
        ROOT_RESET(mark);
    }
}

/* ================= closures ================= */
static NOINLINE void k_closures(int64_t n) {
    int64_t rounds = n / LIST_ELEMS; if (rounds < 1) rounds = 1;
    ROOT_MARK_T mark = ROOT_MARK();
    val *ls = PROOT_PUSH(list_tabulate(LIST_ELEMS));
    for (int64_t r = 0; r < rounds; r++) {
        ROOT_MARK_T m2 = ROOT_MARK();
        val e1[1] = { MONO_INT(r + 1) };
        val e2[2] = { MONO_INT(r + 2), MONO_INT(3) };
        val e3[3] = { MONO_INT(3), MONO_INT(r), MONO_INT(7) };
        val *f1 = PROOT_PUSH(closure_new(FN_ADDK, 1, e1, 0));
        val *f2 = PROOT_PUSH(closure_new(FN_ADD2, 2, e2, 0));
        val *f3 = PROOT_PUSH(closure_new(FN_MUL3, 3, e3, 0));
        val m = list_map(*f1, *ls); ck_add((uint64_t)MONO_INT_OF(list_sum(m)));
        m = list_map(*f2, *ls); ck_add((uint64_t)MONO_INT_OF(list_sum(m)));
        m = list_map(*f3, *ls); ck_add((uint64_t)MONO_INT_OF(list_sum(m)));
        ROOT_RESET(m2);
    }
    ROOT_RESET(mark);
}

/* ================= ordmap: int keys and string keys ================= */
static inline int int_cmp(val a, val b) { int64_t x = MONO_INT_OF(a), y = MONO_INT_OF(b); return (x > y) - (x < y); }
#define MAP_NAME imap
#define MAP_KEYPTR 0
#define MAP_CMP int_cmp
#include "map_impl.h"
#define MAP_NAME smap
#define MAP_KEYPTR 1
#define MAP_CMP string_compare
#include "map_impl.h"

static NOINLINE void k_intmap(int64_t n) {
    ROOT_MARK_T mark = ROOT_MARK();
    val *ms = PROOT_PUSH(NIL);
    val *ks = RROOT_PUSH(MONO_INT(0));
    val *vs = IROOT_PUSH(POLY_VAL_INT(0));
    uint64_t seed = 88172645463325252ull;
    for (int64_t i = 0; i < n; i++) {
        int64_t k = (int64_t)(xorshift64(&seed) & 0x3FFFFFFF);
        *ks = MONO_INT(k);
        *vs = POLY_VAL_INT(k ^ 0x5555);
        *ms = imap_ins(*ms, ks, vs);
    }
    seed = 88172645463325252ull;
    int64_t sum = 0, found = 0;
    for (int64_t i = 0; i < n; i++) {
        int64_t k = (int64_t)(xorshift64(&seed) & 0x3FFFFFFF);
        val opt = imap_find(*ms, MONO_INT(k));
        if (!is_nil(opt)) { sum += POLY_INT_OF(field_get(ptr_of(opt), 0)); found++; }
    }
    ck_add((uint64_t)sum); ck_add((uint64_t)found); ck_add((uint64_t)imap_height(*ms));
    ROOT_RESET(mark);
}

/* a key string "k" + 8 hex digits */
static NOINLINE val key_string(uint64_t k) {
    str *s = string_new(9);
    char *p = string_bytes(s);
    p[0] = 'k';
    for (int i = 0; i < 8; i++) p[8 - i] = "0123456789abcdef"[(k >> (4 * i)) & 15];
    return ptr_val(s);
}
static NOINLINE void k_strmap(int64_t n) {
    ROOT_MARK_T mark = ROOT_MARK();
    val *ms = PROOT_PUSH(NIL);
    val *ks = PROOT_PUSH(NIL);
    val *vs = IROOT_PUSH(POLY_VAL_INT(0));
    uint64_t seed = 88172645463325252ull;
    for (int64_t i = 0; i < n; i++) {
        int64_t k = (int64_t)(xorshift64(&seed) & 0x3FFFFFFF);
        *ks = key_string((uint64_t)k);
        *vs = POLY_VAL_INT(k ^ 0x5555);
        *ms = smap_ins(*ms, ks, vs);
    }
    seed = 88172645463325252ull;
    int64_t sum = 0, found = 0;
    for (int64_t i = 0; i < n; i++) {
        int64_t k = (int64_t)(xorshift64(&seed) & 0x3FFFFFFF);
        *ks = key_string((uint64_t)k);
        val opt = smap_find(*ms, *ks);
        if (!is_nil(opt)) { sum += POLY_INT_OF(field_get(ptr_of(opt), 0)); found++; }
    }
    ck_add((uint64_t)sum); ck_add((uint64_t)found); ck_add((uint64_t)smap_height(*ms));
    ROOT_RESET(mark);
}

/* ================= inttable: (int * 'a ref) list array ================= */
/* buckets : (int * 'a ref) list array ref, count : int ref; an element is
   a 2-tuple (k, r) -- headerless under -DPAIRS -- and r a ref object. */
static NOINLINE void table_grow(val *bs, val *cs) {
    obj *arr = ptr_of(ref_get(ptr_of(*bs)));
    uint32_t cap = obj_len(arr);
    if (MONO_INT_OF(ref_get(ptr_of(*cs))) <= 2 * (int64_t)cap) return;
    val *ns = PROOT_PUSH(ptr_val(array_new(2 * cap, NIL, 1)));
    val *ls = PROOT_PUSH(NIL);
    for (uint32_t i = 0; i < cap; i++) {
        *ls = array_get(ptr_of(ref_get(ptr_of(*bs))), i);
        while (!is_nil(*ls)) {
            val e = head(*ls);
            uint32_t j = (uint32_t)((uint64_t)MONO_INT_OF(pair_get(e, 0)) % (2 * cap));
            val cell = cons_p(e, array_get(ptr_of(*ns), j));
            array_set(ptr_of(*ns), j, cell);
            *ls = tail(*ls);
        }
    }
    ref_set(ptr_of(*bs), *ns);
    ROOT_POP(); ROOT_POP();
}
static NOINLINE void table_insert(val *bs, val *cs, int64_t k, val *vs) {
    obj *arr = ptr_of(ref_get(ptr_of(*bs)));
    uint32_t cap = obj_len(arr);
    uint32_t i = (uint32_t)((uint64_t)k % cap);
    for (val l = array_get(arr, i); !is_nil(l); l = tail(l)) {
        val e = head(l);
        if (MONO_INT_OF(pair_get(e, 0)) == k) { ref_set(ptr_of(pair_get(e, 1)), *vs); return; }
    }
    obj *r = ref_new(*vs, POLY_PTRBIT);
    val e = mk_pair(K_TUPLE, 0, MONO_INT(k), ptr_val(r), 2);
    arr = ptr_of(ref_get(ptr_of(*bs)));
    val cell = cons_p(e, array_get(arr, i));
    arr = ptr_of(ref_get(ptr_of(*bs)));
    array_set(arr, i, cell);
    obj *c = ptr_of(*cs);
    ref_set(c, MONO_INT(MONO_INT_OF(ref_get(c)) + 1));
    table_grow(bs, cs);
}
/* find: SOME (!r) is a CON object of one field (Rune: 24 bytes today) */
static NOINLINE val table_find(val *bs, int64_t k) {
    obj *arr = ptr_of(ref_get(ptr_of(*bs)));
    uint32_t i = (uint32_t)((uint64_t)k % obj_len(arr));
    for (val l = array_get(arr, i); !is_nil(l); l = tail(l)) {
        val e = head(l);
        if (MONO_INT_OF(pair_get(e, 0)) == k) {
            val v = ref_get(ptr_of(pair_get(e, 1)));
            size_t sz = alloc_size(K_CON, 1, 1);
            GUARD1(sz, v, POLY_PTRBIT);
            obj *s = alloc(K_CON, 1, 1, POLY_PTRBIT);
            field_set(s, 0, v);
            return ptr_val(s);
        }
    }
    return NIL;
}
static NOINLINE void k_inttable(int64_t n) {
    ROOT_MARK_T mark = ROOT_MARK();
    uint32_t cap = 16; while (cap < (uint64_t)n / 8) cap *= 2;
    val *as = PROOT_PUSH(ptr_val(array_new(cap, NIL, 1)));
    val *bs = PROOT_PUSH(ptr_val(ref_new(*as, 1)));
    val *cs = PROOT_PUSH(ptr_val(ref_new(MONO_INT(0), 0)));
    val *vs = IROOT_PUSH(POLY_VAL_INT(0));
    uint64_t seed = 0x2545F4914F6CDD1Dull;
    for (int64_t i = 0; i < n; i++) {
        int64_t k = (int64_t)(xorshift64(&seed) % (uint64_t)(2 * n));
        *vs = POLY_VAL_INT(i);
        table_insert(bs, cs, k, vs);
    }
    seed = 0x2545F4914F6CDD1Dull;
    int64_t sum = 0, found = 0;
    for (int64_t i = 0; i < n; i++) {
        int64_t k = (int64_t)(xorshift64(&seed) % (uint64_t)(2 * n));
        val opt = table_find(bs, k);
        if (!is_nil(opt)) { sum += POLY_INT_OF(field_get(ptr_of(opt), 0)); found++; }
    }
    ck_add((uint64_t)sum); ck_add((uint64_t)found);
    ck_add((uint64_t)MONO_INT_OF(ref_get(ptr_of(*cs))));
    ck_add(obj_len(ptr_of(ref_get(ptr_of(*bs)))));
    ROOT_RESET(mark);
}

/* ================= int_loop: tak and fib on tagged ints ================= */
static val tak(val x, val y, val z) {
    if (!(unbox_int(y) < unbox_int(x))) return z;
    val one = MONO_INT(1), a, b, c;
    if (sub_ov(x, one, &a) | sub_ov(y, one, &b) | sub_ov(z, one, &c)) die("overflow");
    return tak(tak(a, y, z), tak(b, z, x), tak(c, x, y));
}
static val fib(val n) {
    if (unbox_int(n) < 2) return n;
    val a, b, r;
    if (sub_ov(n, MONO_INT(1), &a) | sub_ov(n, MONO_INT(2), &b)) die("overflow");
    if (add_ov(fib(a), fib(b), &r)) die("overflow");
    return r;
}
static volatile int64_t tak_args[3] = { 24, 16, 8 };
static volatile int64_t fib_arg = 32;
static NOINLINE void k_int_loop(int64_t n) {
    for (int64_t r = 0; r < n; r++) {
        val t = tak(MONO_INT(tak_args[0]), MONO_INT(tak_args[1]), MONO_INT(tak_args[2]));
        ck_add((uint64_t)MONO_INT_OF(t));
        val f = fib(MONO_INT(fib_arg));
        ck_add((uint64_t)MONO_INT_OF(f));
    }
}

/* ================= word_loop: xorshift64 and a hash with the top bit set ================= */
/* naive: every primitive's result is a word value (a box in L1); with
   -DL1_UNBOXED_LOCALS the locals are raw and only the store boxes */
static NOINLINE void k_word_loop(int64_t n) {
    ROOT_MARK_T mark = ROOT_MARK();
    val w0 = mk_word(0);
    val *rs = PROOT_PUSH(ptr_val(ref_new(w0, WORD_PTRBIT)));
#if UNBOXED
    uint64_t s = 0x9E3779B97F4A7C15ull, h = 0;
    for (int64_t i = 0; i < n; i++) {
        s ^= s << 13; s ^= s >> 7; s ^= s << 17;
        h = ((h ^ s) * 0x100000001b3ull) | (1ull << 63);
        val hv = mk_word(h);
        ref_set(ptr_of(*rs), hv);
    }
    ck_add(s); ck_add(h);
#else
    val *ss = root_push_m(mk_word(0x9E3779B97F4A7C15ull), WORD_PTRBIT);
    val *hs = root_push_m(mk_word(0), WORD_PTRBIT);
    val *t2 = root_push_m(mk_word(0), WORD_PTRBIT);
    for (int64_t i = 0; i < n; i++) {
        val t1 = mk_word(unbox_word(*ss) << 13);
        *t2 = mk_word(unbox_word(*ss) ^ unbox_word(t1));
        val t3 = mk_word(unbox_word(*t2) >> 7);
        *t2 = mk_word(unbox_word(*t2) ^ unbox_word(t3));
        val t5 = mk_word(unbox_word(*t2) << 17);
        *ss = mk_word(unbox_word(*t2) ^ unbox_word(t5));
        val x = mk_word(unbox_word(*hs) ^ unbox_word(*ss));
        val m = mk_word(unbox_word(x) * 0x100000001b3ull);
        *hs = mk_word(unbox_word(m) | (1ull << 63));
        ref_set(ptr_of(*rs), *hs);
    }
    ck_add(unbox_word(*ss)); ck_add(unbox_word(*hs));
#endif
    ck_add(unbox_word(ref_get(ptr_of(*rs))));
    ROOT_RESET(mark);
}

/* ================= real_regs: an nbody step loop ================= */
/* 5 bodies as records of 7 reals (x y z vx vy vz m); the pair loop keeps
   dx, dy, dz, d2, mag in locals: naive = each a real value (a box in L1)
   held in a root slot; UNBOXED = doubles. */
#define NBODIES 5
#define BODY_MASK (REAL_ALLOCATES ? 0x7Fu : 0u)
static NOINLINE obj *body_new(double x, double y, double z, double vx, double vy, double vz, double m) {
    double f[7] = { x, y, z, vx, vy, vz, m };
    size_t sz = alloc_size(K_TUPLE, 0, 7) + 7 * alloc_size(K_BOX, 0, 1);
    GUARD0(sz);   /* room for the record and its boxes: no collection below */
    val fv[7];
    for (int i = 0; i < 7; i++) fv[i] = MONO_REAL(f[i]);
    obj *o = alloc(K_TUPLE, 0, 7, BODY_MASK);
    for (int i = 0; i < 7; i++) field_set(o, i, fv[i]);
    return o;
}
#define BODY(bs, i) ptr_of(array_get(ptr_of(*(bs)), (uint32_t)(i)))
#define RF(o, i) MONO_REAL_OF(field_get((o), (i)))
#define RSTORE(bs, i, f, d) do { val _v = MONO_REAL(d); field_set(BODY(bs, i), (f), _v); } while (0)
static NOINLINE void nbody_advance(val *bs, double dt) {
#if UNBOXED || !REAL_ALLOCATES
    for (int i = 0; i < NBODIES; i++) {
        for (int j = i + 1; j < NBODIES; j++) {
            obj *bi = BODY(bs, i), *bj = BODY(bs, j);
            double dx = RF(bi, 0) - RF(bj, 0), dy = RF(bi, 1) - RF(bj, 1), dz = RF(bi, 2) - RF(bj, 2);
            double d2 = dx * dx + dy * dy + dz * dz;
            double mag = dt / (d2 * __builtin_sqrt(d2));
            /* the same association as the naive path below: (m * mag) first */
            double mjm = RF(bj, 6) * mag, mim = RF(bi, 6) * mag;
            RSTORE(bs, i, 3, RF(BODY(bs, i), 3) - dx * mjm);
            RSTORE(bs, i, 4, RF(BODY(bs, i), 4) - dy * mjm);
            RSTORE(bs, i, 5, RF(BODY(bs, i), 5) - dz * mjm);
            RSTORE(bs, j, 3, RF(BODY(bs, j), 3) + dx * mim);
            RSTORE(bs, j, 4, RF(BODY(bs, j), 4) + dy * mim);
            RSTORE(bs, j, 5, RF(BODY(bs, j), 5) + dz * mim);
        }
    }
    for (int i = 0; i < NBODIES; i++) {
        RSTORE(bs, i, 0, RF(BODY(bs, i), 0) + dt * RF(BODY(bs, i), 3));
        RSTORE(bs, i, 1, RF(BODY(bs, i), 1) + dt * RF(BODY(bs, i), 4));
        RSTORE(bs, i, 2, RF(BODY(bs, i), 2) + dt * RF(BODY(bs, i), 5));
    }
#else
    /* naive: every intermediate is a real value in a root slot (the JIT's
       register file), re-read after each allocating operation */
    ROOT_MARK_T mark = ROOT_MARK();
    val *R = root_push_m(MONO_REAL(0), 1);
    for (int k = 1; k < 8; k++) root_push_m(MONO_REAL(0), 1);
#define RR(k) (R[k])
#define ROP(k, e) do { double _d = (e); RR(k) = MONO_REAL(_d); } while (0)
#define RV(k) MONO_REAL_OF(RR(k))
    for (int i = 0; i < NBODIES; i++) {
        for (int j = i + 1; j < NBODIES; j++) {
            ROP(0, RF(BODY(bs, i), 0) - RF(BODY(bs, j), 0));
            ROP(1, RF(BODY(bs, i), 1) - RF(BODY(bs, j), 1));
            ROP(2, RF(BODY(bs, i), 2) - RF(BODY(bs, j), 2));
            ROP(3, RV(0) * RV(0));
            ROP(4, RV(1) * RV(1)); ROP(3, RV(3) + RV(4));
            ROP(4, RV(2) * RV(2)); ROP(3, RV(3) + RV(4));
            ROP(4, __builtin_sqrt(RV(3))); ROP(4, RV(3) * RV(4)); ROP(4, dt / RV(4));   /* mag */
            ROP(5, RF(BODY(bs, j), 6) * RV(4));   /* mj * mag */
            ROP(6, RF(BODY(bs, i), 6) * RV(4));   /* mi * mag */
            ROP(7, RV(0) * RV(5)); RSTORE(bs, i, 3, RF(BODY(bs, i), 3) - RV(7));
            ROP(7, RV(1) * RV(5)); RSTORE(bs, i, 4, RF(BODY(bs, i), 4) - RV(7));
            ROP(7, RV(2) * RV(5)); RSTORE(bs, i, 5, RF(BODY(bs, i), 5) - RV(7));
            ROP(7, RV(0) * RV(6)); RSTORE(bs, j, 3, RF(BODY(bs, j), 3) + RV(7));
            ROP(7, RV(1) * RV(6)); RSTORE(bs, j, 4, RF(BODY(bs, j), 4) + RV(7));
            ROP(7, RV(2) * RV(6)); RSTORE(bs, j, 5, RF(BODY(bs, j), 5) + RV(7));
        }
    }
    for (int i = 0; i < NBODIES; i++) {
        ROP(0, dt * RF(BODY(bs, i), 3)); RSTORE(bs, i, 0, RF(BODY(bs, i), 0) + RV(0));
        ROP(0, dt * RF(BODY(bs, i), 4)); RSTORE(bs, i, 1, RF(BODY(bs, i), 1) + RV(0));
        ROP(0, dt * RF(BODY(bs, i), 5)); RSTORE(bs, i, 2, RF(BODY(bs, i), 2) + RV(0));
    }
#undef RR
#undef ROP
#undef RV
    ROOT_RESET(mark);
#endif
}
static NOINLINE void k_real_regs(int64_t n) {
    ROOT_MARK_T mark = ROOT_MARK();
    val *bs = PROOT_PUSH(ptr_val(array_new(NBODIES, NIL, 1)));
    static const double init[NBODIES][7] = {
        { 0, 0, 0, 0, 0, 0, 39.47 },
        { 4.84, -1.16, -0.10, 0.606, 2.81, -0.02, 0.037 },
        { 8.34, 4.12, -0.40, -1.01, 1.82, 0.008, 0.011 },
        { 12.89, -15.11, -0.22, 1.08, 0.868, -0.01, 0.0017 },
        { 15.37, -25.91, 0.179, 0.979, 0.594, -0.034, 0.002 } };
    for (int i = 0; i < NBODIES; i++) {
        obj *b = body_new(init[i][0], init[i][1], init[i][2], init[i][3], init[i][4], init[i][5], init[i][6]);
        array_set(ptr_of(*bs), (uint32_t)i, ptr_val(b));
    }
    for (int64_t s = 0; s < n; s++) nbody_advance(bs, 0.01);
    for (int i = 0; i < NBODIES; i++) for (int f = 0; f < 6; f++) ck_add_d(RF(BODY(bs, i), f));
    ROOT_RESET(mark);
}

/* ================= real_array ================= */
#define RARR_N 1000000
static NOINLINE void k_real_array(int64_t n) {
    int64_t rounds = n / RARR_N; if (rounds < 1) rounds = 1;
    ROOT_MARK_T mark = ROOT_MARK();
    val *as = PROOT_PUSH(ptr_val(real_array_new(RARR_N)));
    double sum = 0;
    for (int64_t r = 0; r < rounds; r++) {
        for (uint32_t i = 0; i < RARR_N; i++) real_array_set(ptr_of(*as), i, (double)i * 0.5 + (double)r);
        for (uint32_t i = 0; i < RARR_N; i++) sum += real_array_get(ptr_of(*as), i);
        SINK_D(sum);
    }
    ck_add_d(sum);
    ROOT_RESET(mark);
}

/* ================= strings ================= */
static NOINLINE void k_strings(int64_t n) {
    ROOT_MARK_T mark = ROOT_MARK();
    str *b = string_new(64);
    for (int i = 0; i < 64; i++) string_bytes(b)[i] = (char)('a' + i % 26);
    val *base = PROOT_PUSH(ptr_val(b));
    val *ss = PROOT_PUSH(string_sub(*base, 0, 40));
    val *buf = PROOT_PUSH(ptr_val(char_array_new(40)));
    for (int64_t i = 0; i < n; i++) {
        val u = string_sub(*ss, (uint32_t)((i * 7) % 24), 16);
        val *us = PROOT_PUSH(u);
        val v = string_sub(*base, (uint32_t)((i * 13) % 48), 16);
        val t = string_concat(*us, v);
        ROOT_POP();
        val *ts = PROOT_PUSH(t);
        val w = string_sub(*ss, 0, 8);
        *ss = string_concat(*ts, w);
        ROOT_POP();
        /* a CharArray buffer: each char bumped, then CharArray.vector */
        obj *a = ptr_of(*buf);
        const char *p = string_bytes(ptr_of(*ss));
        for (uint32_t j = 0; j < 40; j++) char_array_set(a, j, (unsigned char)p[j] + 1);
        val out = char_array_to_string(ptr_of(*buf));
        uint64_t first; memcpy(&first, string_bytes(ptr_of(out)), 8);
        ck_add(first);
        uint64_t eight; memcpy(&eight, string_bytes(ptr_of(*ss)), 8);
        ck_add(eight);
    }
    ck_add_bytes(string_bytes(ptr_of(*ss)), 40);
    ROOT_RESET(mark);
}

/* ================= poly_eq_tree ================= */
/* datatype t = Leaf of int * int | Node of t * t: two CONN objects of two
   fields (headerless pairs under -DPAIRS) */
static NOINLINE val tree_build(int depth, int64_t *counter) {
    if (depth == 0) {
        int64_t c = (*counter)++;
        val a = CON_INT_VAL(c), b;
        val *as = root_push_m(a, CON_INTBIT);
        b = CON_INT_VAL(c * 3);
        a = *as; root_pop_m(CON_INTBIT);
        return mk_pair(K_CON, 0, a, b, CON_INTBIT | (CON_INTBIT << 1));
    }
    val l = tree_build(depth - 1, counter);
    val *ls = PROOT_PUSH(l);
    val r = tree_build(depth - 1, counter);
    l = *ls; ROOT_POP();
    return mk_pair(K_CON, 1, l, r, 3);
}
#define TREE_DEPTH 17
static NOINLINE void k_poly_eq_tree(int64_t n) {
    ROOT_MARK_T mark = ROOT_MARK();
    int64_t c1 = 0, c2 = 0;
    val *t1 = PROOT_PUSH(tree_build(TREE_DEPTH, &c1));
    val *t2 = PROOT_PUSH(tree_build(TREE_DEPTH, &c2));
    int64_t rounds = n / (1 << TREE_DEPTH); if (rounds < 1) rounds = 1;
    int64_t eq = 0;
    for (int64_t r = 0; r < rounds; r++) { eq += poly_eq(*t1, *t2); SINK(eq); }
    ck_add((uint64_t)eq); ck_add((uint64_t)c1);
    ROOT_RESET(mark);
}

/* ================= gc_churn ================= */
/* a live tree Node of int * tree * tree (CONN, 3 fields) of about L bytes
   in L0's sizes; then rounds of short-lived cons cells */
static NOINLINE val churn_build(int64_t n, int64_t *counter) {
    if (n <= 0) return NIL;
    int64_t c = (*counter)++;
    val l = churn_build((n - 1) / 2, counter);
    val *ls = PROOT_PUSH(l);
    val r = churn_build(n - 1 - (n - 1) / 2, counter);
    val *rs = PROOT_PUSH(r);
    size_t sz = alloc_size(K_CON, 0, 3);
    GUARD0(sz);
    obj *o = alloc(K_CON, 0, 3, 6);
    field_set(o, 0, MONO_INT(c)); field_set(o, 1, *ls); field_set(o, 2, *rs);
    ROOT_POP(); ROOT_POP();
    return ptr_val(o);
}
static NOINLINE int64_t churn_path(val t, uint64_t bits) {
    int64_t s = 0;
    while (!is_nil(t)) { obj *o = ptr_of(t); s += MONO_INT_OF(field_get(o, 0)); t = field_get(o, 1 + (bits & 1)); bits >>= 1; }
    return s;
}
static NOINLINE int64_t churn_sum(val t) {
    if (is_nil(t)) return 0;
    obj *o = ptr_of(t);
    return MONO_INT_OF(field_get(o, 0)) + churn_sum(field_get(o, 1)) + churn_sum(field_get(o, 2));
}
static void gc_churn(int64_t n, size_t live_bytes_l0) {
    ROOT_MARK_T mark = ROOT_MARK();
    int64_t nodes = (int64_t)(live_bytes_l0 / 56), counter = 0;
    val *ts = PROOT_PUSH(churn_build(nodes, &counter));
    uint64_t seed = 12345;
    int64_t acc = 0;
    for (int64_t r = 0; r < n; r++) {
        ROOT_MARK_T m2 = ROOT_MARK();
        val *ls = PROOT_PUSH(NIL);
        for (int64_t i = 0; i < 256; i++) { val x = POLY_VAL_INT(i + r); *ls = cons(x, *ls); }
        acc += list_length(*ls);
        acc += churn_path(*ts, xorshift64(&seed));
        ROOT_RESET(m2);
    }
    ck_add((uint64_t)acc); ck_add((uint64_t)churn_sum(*ts)); ck_add((uint64_t)counter);
    ROOT_RESET(mark);
}
static NOINLINE void k_gc_churn8(int64_t n) { gc_churn(n, 8u << 20); }
static NOINLINE void k_gc_churn64(int64_t n) { gc_churn(n, 64u << 20); }

/* ================= micro-benchmarks ================= */
static void micro_line(const char *op, uint64_t cycles, int64_t n) {
    printf("micro %-10s %8.2f cycles/op (n=%lld)\n", op, (double)cycles / (double)n, (long long)n);
}
static NOINLINE void k_micro(int64_t n) {
    if (n < 1000000) n = 1000000;
    ROOT_MARK_T mark = ROOT_MARK();
    /* tag test: 3 ints then a pointer, repeating (predictable), the pointer's field 0 read */
    {
        obj *o = alloc(K_TUPLE, 0, 2, 0); field_set(o, 0, MONO_INT(5)); field_set(o, 1, MONO_INT(6));
        val *os = PROOT_PUSH(ptr_val(o));
        val *arr = malloc(4096 * sizeof(val));
        for (int i = 0; i < 4096; i++) arr[i] = (i & 3) == 3 ? *os : MONO_INT(i);
        int64_t s = 0;
        uint64_t t0 = cycles_now();
        for (int64_t i = 0; i < n; i++) {
            val v = arr[i & 4095];
            if (is_int(v)) s += unbox_int(v); else s += MONO_INT_OF(field_get(ptr_of(v), 0));
        }
        micro_line("tagtest", cycles_now() - t0, n);
        SINK(s); free(arr);
    }
    /* int add with overflow check, dependent chain */
    {
        val acc = MONO_INT(0), x = MONO_INT(3);
        uint64_t t0 = cycles_now();
        for (int64_t i = 0; i < n; i++) { if (add_ov(acc, x, &acc)) die("ov"); SINK_VAL(acc); }
        micro_line("addov", cycles_now() - t0, n);
        ck_add((uint64_t)MONO_INT_OF(acc));
    }
    /* real add through the value representation, dependent chain; the
       heap is reset every 100k (no collection: 100k boxes are 1.6 MB) */
    {
        double a = 0.5, x = 1.25;
        uint64_t t0 = cycles_now();
        for (int64_t blk = 0; blk < n; blk += 100000) {
            heap_reset();
            val acc = MONO_REAL(a), xv = MONO_REAL(x);
            for (int64_t i = 0; i < 100000; i++) { acc = MONO_REAL(MONO_REAL_OF(acc) + MONO_REAL_OF(xv)); SINK_VAL(acc); }
            a = MONO_REAL_OF(acc);
        }
        micro_line("realadd", cycles_now() - t0, n);
        ck_add_d(a);
    }
    heap_reset(); ROOT_RESET(mark);
    /* field load: a MONO int field of a 5-field node, over 1024 nodes */
    {
        val *arr = malloc(1024 * sizeof(val));
        for (int i = 0; i < 1024; i++) {
            obj *o = alloc(K_CON, 1, 5, 0x12);
            for (int f = 0; f < 5; f++) field_set(o, (uint32_t)f, MONO_INT(i + f));
            arr[i] = ptr_val(o);
        }
        int64_t s = 0;
        uint64_t t0 = cycles_now();
        for (int64_t i = 0; i < n; i++) { s += MONO_INT_OF(field_get(ptr_of(arr[i & 1023]), 2)); SINK(s); }
        micro_line("fieldload", cycles_now() - t0, n);
        free(arr);
    }
    /* pointer chase through a cyclic list of 64 cells (tail after tail) */
    {
        val *ls = PROOT_PUSH(NIL);
        for (int i = 0; i < 64; i++) { val x = POLY_VAL_INT(i); *ls = cons(x, *ls); }
        val l = *ls;
        uint64_t t0 = cycles_now();
        for (int64_t i = 0; i < n; i++) { l = tail(l); if (is_nil(l)) l = *ls; }
        micro_line("chase", cycles_now() - t0, n);
        SINK_VAL(l);
        ROOT_POP();
    }
    /* cons: allocate cells, the heap reset every 100k cells (no collection;
       100k cells are 4 MB in L0, so with -s 8 the heap stays in the L3 cache
       and the number is the instructions' cost; with -s 64 it streams) */
    {
        uint64_t t0 = cycles_now();
        for (int64_t blk = 0; blk < n; blk += 100000) {
            heap_reset();
            val *ls = PROOT_PUSH(NIL);
            for (int64_t i = 0; i < 100000; i++) { val x = POLY_VAL_INT(i); *ls = cons(x, *ls); }
            SINK_VAL(*ls); ROOT_POP();
        }
        micro_line("cons", cycles_now() - t0, n);
    }
    heap_reset(); ROOT_RESET(mark);
}

/* ================= a lazy front end's kernels =================
   No lazy program runs on Rune: these stand in for one
   (docs/plans/heap-layout.md, *A lazy front end* and M4). What a lazy value
   is, and how it is forced, is harness.h's. */
enum { TH_CON = 0, TH_FROM, TH_FILTER, TH_SIEVE, TH_COUNT };

/* datatype t = A of int | B of int * int * int | C of int * int * int * int:
   three constructors, each with a header */
static NOINLINE val t_new(int64_t seed) {
    int tag = (int)(seed % 3);
    uint32_t n = tag == 0 ? 1 : tag == 1 ? 3 : 4;
    size_t sz = alloc_size(K_CON, tag, n);
    GUARD0(sz);
    obj *o = alloc(K_CON, tag, n, 0);
    for (uint32_t i = 0; i < n; i++) FIELDS(o)[i] = MONO_INT(seed + i);
    return EVALUATED(ptr_val(o));
}
static val th_con(obj *t) { return t_new(MONO_INT_OF(field_get(t, 0))); }

/* case v of A x => x | B (_, y, _) => 3 * y | C (_, _, _, z) => ~z */
ALWAYS_INLINE int64_t t_case(val v) {
    obj *o = ptr_of(v);
    switch (obj_contag(o)) {
    case 0: return MONO_INT_OF(field_get(o, 0));
    case 1: return MONO_INT_OF(field_get(o, 1)) * 3;
    default: return -MONO_INT_OF(field_get(o, 3));
    }
}
/* Three ways for a case to know its scrutinee is a value. By the header:
   its kind says a value, an indirection or a thunk. */
ALWAYS_INLINE val whnf_header(val v) {
    if (LIKELY(obj_kind(ptr_of(v)) == K_CON)) return v;
    return lazy_whnf_slow(v);
}
/* By the pointer's code, where the layout keeps one for "evaluated"
   (EVAL_CODE); elsewhere this is the header's way again. */
ALWAYS_INLINE val whnf_code(val v) {
#ifdef EVAL_CODE
    if (LIKELY((v & 6) == EVAL_CODE)) return v;
    return lazy_whnf_slow(v);
#else
    return whnf_header(v);
#endif
}
/* By entering it, as GHC did before 2007 (Marlow, Yakushev & Peyton Jones,
   "Faster laziness using dynamic pointer tagging"): an indirect call
   through what the object is, which returns at once for a value. */
typedef val (*enterfn)(val v);
static val enter_value(val v) { return v; }
static val enter_other(val v) { return lazy_whnf_slow(v); }
static enterfn entertab[16] = { [K_CON] = enter_value, [K_THUNK] = enter_other, [K_IND] = enter_other };
static enterfn *volatile entertab_p = entertab;
ALWAYS_INLINE val whnf_enter(val v) { enterfn *t = entertab_p; return t[obj_kind(ptr_of(v))](v); }

#define LAZY_N (1u << 14)
#define LAZY_SCAN(NAME, WHNF) \
static NOINLINE int64_t NAME(val *as, uint32_t n) { \
    int64_t acc = 0; \
    for (uint32_t i = 0; i < n; i++) acc += t_case(WHNF(array_get(ptr_of(*as), i))); \
    return acc; \
}
LAZY_SCAN(scan_header, whnf_header)
LAZY_SCAN(scan_code, whnf_code)
LAZY_SCAN(scan_enter, whnf_enter)

/* An array of LAZY_N values of t, scanned by a case round after round;
   before each round `share` percent of its elements, picked at random, are
   made thunks again. So of a round's scrutinees share percent are thunks,
   those of the round before are indirections until a collection takes them
   out, and the rest are values. */
static void lazy_case(int64_t n, int64_t (*scan)(val *, uint32_t), unsigned share) {
    ROOT_MARK_T mark = ROOT_MARK();
    int64_t rounds = n / LAZY_N; if (rounds < 1) rounds = 1;
    val *as = PROOT_PUSH(ptr_val(array_new(LAZY_N, NIL, 1)));
    for (uint32_t i = 0; i < LAZY_N; i++) { val v = t_new(i); array_set(ptr_of(*as), i, v); }
    uint64_t seed = 88172645463325252ULL;
    int64_t acc = 0;
    for (int64_t r = 0; r < rounds; r++) {
        if (share)
            for (uint32_t i = 0; i < LAZY_N; i++)
                if (xorshift64(&seed) % 100 < share) {
                    val th = thunk_new1(TH_CON, MONO_INT((int64_t)i + r), 0);
                    array_set(ptr_of(*as), i, th);
                }
        acc += scan(as, LAZY_N);
    }
    ck_add((uint64_t)acc);
    ROOT_RESET(mark);
}
#define LAZY_CASE(WAY, SHARE) static NOINLINE void k_lazy_case_##WAY##SHARE(int64_t n) { lazy_case(n, scan_##WAY, SHARE); }
LAZY_CASE(header, 0) LAZY_CASE(header, 1) LAZY_CASE(header, 10) LAZY_CASE(header, 50)
LAZY_CASE(code, 0) LAZY_CASE(code, 1) LAZY_CASE(code, 10) LAZY_CASE(code, 50)
LAZY_CASE(enter, 0) LAZY_CASE(enter, 1) LAZY_CASE(enter, 10) LAZY_CASE(enter, 50)

/* A stream of ints whose every tail is a suspension -- Cons of int * stream
   susp, two fields: a headerless pair under -DPAIRS -- and the sieve over
   it: every element taken forces a thunk for each prime before it, each
   updated with a cell that holds the next thunk. The update path, the
   indirections a collection takes out, and the bytes they hold until then. */
ALWAYS_INLINE val stream_cons(int64_t x, val tl) { return mk_pair(K_CON, 0, MONO_INT(x), tl, 2); }
/* from n = Cons (n, delay (fn () => from (n + 1))) */
static val th_from(obj *t) {
    int64_t n = MONO_INT_OF(field_get(t, 0));
    return stream_cons(n, thunk_new1(TH_FROM, MONO_INT(n + 1), 0));
}
/* filter p s: the first x of s that p does not divide, and the rest filtered */
static val th_filter(obj *t) {
    int64_t p = MONO_INT_OF(field_get(t, 0));
    val s = field_get(t, 1);
    for (;;) {
        val c = lazy_whnf(s);
        int64_t x = MONO_INT_OF(pair_get(c, 0));
        val rest = pair_get(c, 1);
        if (x % p != 0) return stream_cons(x, thunk_new2(TH_FILTER, MONO_INT(p), rest));
        s = rest;
    }
}
/* sieve (Cons (p, s)) = Cons (p, delay (fn () => sieve (filter p s))) */
static val th_sieve(obj *t) {
    val c = lazy_whnf(field_get(t, 0));
    int64_t p = MONO_INT_OF(pair_get(c, 0));
    val f = thunk_new2(TH_FILTER, MONO_INT(p), pair_get(c, 1));
    return stream_cons(p, thunk_new1(TH_SIEVE, f, 1));
}
thunkfn thunktab[TH_COUNT] = { th_con, th_from, th_filter, th_sieve };
thunkfn *volatile thunktab_p = thunktab;

static NOINLINE void k_lazy_stream(int64_t n) {
    ROOT_MARK_T mark = ROOT_MARK();
    val from = thunk_new1(TH_FROM, MONO_INT(2), 0);
    val *s = PROOT_PUSH(thunk_new1(TH_SIEVE, from, 1));
    int64_t sum = 0, last = 0;
    for (int64_t i = 0; i < n; i++) {
        val c = lazy_whnf(*s);
        last = MONO_INT_OF(pair_get(c, 0));
        sum += last;
        *s = pair_get(c, 1);
    }
    ck_add((uint64_t)sum); ck_add((uint64_t)last);
    ROOT_RESET(mark);
}

/* Old thunks given young values: LAZY_N suspensions that have survived a
   collection, forced in an order of its own. Every update stores a pointer
   to a fresh value into an old object, which a generational collector must
   remember: the count is printed (old to young), and with -DBARRIER_CARD
   the cards the updates dirty. */
static NOINLINE void k_lazy_update_old(int64_t n) {
    ROOT_MARK_T mark = ROOT_MARK();
    int64_t rounds = n / LAZY_N; if (rounds < 1) rounds = 1;
    val *as = PROOT_PUSH(ptr_val(array_new(LAZY_N, NIL, 1)));
    uint64_t seed = 0x9E3779B97F4A7C15ULL;
    int64_t acc = 0;
    for (int64_t r = 0; r < rounds; r++) {
        for (uint32_t i = 0; i < LAZY_N; i++) {
            val th = thunk_new1(TH_CON, MONO_INT((int64_t)i + r), 0);
            array_set(ptr_of(*as), i, th);
        }
        gc_collect(0);   /* the thunks are old now */
        uint32_t stride = (uint32_t)xorshift64(&seed) | 1u, at = (uint32_t)xorshift64(&seed);
        for (uint32_t k = 0; k < LAZY_N; k++) {
            at += stride;
            acc += t_case(lazy_whnf(array_get(ptr_of(*as), at & (LAZY_N - 1))));
        }
    }
    ck_add((uint64_t)acc);
    ROOT_RESET(mark);
}

/* ================= the table ================= */
typedef struct { const char *name; void (*fn)(int64_t); int64_t n; unsigned semispace_mib; } kernel_def;
static const kernel_def kernels[] = {
    { "list_ops",     k_list_ops,     4000000,  64 },
    { "intmap",       k_intmap,       400000,   64 },
    { "strmap",       k_strmap,       300000,   64 },
    { "inttable",     k_inttable,     400000,   64 },
    { "closures",     k_closures,     2000000,  64 },
    { "int_loop",     k_int_loop,     8,        64 },
    { "word_loop",    k_word_loop,    60000000, 64 },
    { "real_regs",    k_real_regs,    1000000,  64 },
    { "real_array",   k_real_array,   100000000, 64 },
    { "strings",      k_strings,      4000000,  64 },
    { "poly_eq_tree", k_poly_eq_tree, 20000000, 64 },
    { "gc_churn8",    k_gc_churn8,    200000,   64 },
    { "gc_churn64",   k_gc_churn64,   200000,   128 },
    { "micro",        k_micro,        20000000, 64 },
    { "lazy_case_header0",  k_lazy_case_header0,  160000000, 64 },
    { "lazy_case_header1",  k_lazy_case_header1,  100000000, 64 },
    { "lazy_case_header10", k_lazy_case_header10, 40000000,  64 },
    { "lazy_case_header50", k_lazy_case_header50, 12000000,  64 },
    { "lazy_case_code0",    k_lazy_case_code0,    160000000, 64 },
    { "lazy_case_code1",    k_lazy_case_code1,    100000000, 64 },
    { "lazy_case_code10",   k_lazy_case_code10,   40000000,  64 },
    { "lazy_case_code50",   k_lazy_case_code50,   12000000,  64 },
    { "lazy_case_enter0",   k_lazy_case_enter0,   160000000, 64 },
    { "lazy_case_enter1",   k_lazy_case_enter1,   100000000, 64 },
    { "lazy_case_enter10",  k_lazy_case_enter10,  40000000,  64 },
    { "lazy_case_enter50",  k_lazy_case_enter50,  12000000,  64 },
    { "lazy_stream",        k_lazy_stream,        6000,      64 },
    { "lazy_update_old",    k_lazy_update_old,    8000000,   64 },
    { NULL, NULL, 0, 0 }
};
