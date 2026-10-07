/* h6k.h -- the kernels of H6, included once per barrier with BAR defined
   (gen.h's B_*) and KN(name) giving the function its suffix. Every value
   that must live across an allocation is in a root slot (G_ROOT), as the
   VM's registers are on its stack. */

/* inttable: tests/layouts' kernel, the compiler's int table of refs
   ((int * 'a ref) list array ref, count : int ref): stores of a fresh
   cons into a bucket of the array, of the count, of the new array */
static NOINLINE void KN(it_grow)(val *bs, val *cs) {
    uint32_t cap = ptr_of(g_get(*bs, 0))->len;
    if (int_of(g_get(*cs, 0)) <= 2 * (int64_t)cap) return;
    size_t m = g_rsp;
    val *ns = G_ROOT(h6_array(2 * cap, NIL));
    val *ls = G_ROOT(NIL), *e = G_ROOT(NIL), *tl = G_ROOT(NIL);
    for (uint32_t i = 0; i < cap; i++) {
        *ls = g_get(g_get(*bs, 0), i);
        while (*ls != NIL) {
            *e = g_get(*ls, 0);
            uint32_t j = (uint32_t)((uint64_t)int_of(g_get(*e, 0)) % (2 * cap));
            *tl = g_get(*ns, j);
            val cell = h6_cons(e, tl);
            g_store(BAR, ptr_of(*ns), j, cell);
            *ls = g_get(*ls, 1);
        }
    }
    g_store(BAR, ptr_of(*bs), 0, *ns);
    g_rsp = m;
}
static NOINLINE void KN(it_insert)(val *bs, val *cs, int64_t k, val v) {
    obj *arr = ptr_of(g_get(*bs, 0));
    uint32_t i = (uint32_t)((uint64_t)k % arr->len);
    for (val l = FIELDS(arr)[i]; l != NIL; l = g_get(l, 1)) {
        val e = g_get(l, 0);
        if (int_of(g_get(e, 0)) == k) { g_store(BAR, ptr_of(g_get(e, 1)), 0, v); return; }
    }
    size_t m = g_rsp;
    val *rs = G_ROOT(h6_ref(v));
    val *ks = G_ROOT(mk_int(k));
    val *es = G_ROOT(h6_tuple(ks, rs));
    val *tl = G_ROOT(g_get(g_get(*bs, 0), i));
    val cell = h6_cons(es, tl);
    g_store(BAR, ptr_of(g_get(*bs, 0)), i, cell);
    obj *c = ptr_of(*cs);
    g_store(BAR, c, 0, mk_int(int_of(FIELDS(c)[0]) + 1));
    g_rsp = m;
    KN(it_grow)(bs, cs);
}
static NOINLINE void KN(inttable)(int64_t n) {
    size_t m = g_rsp;
    uint32_t cap = 16; while (cap < (uint64_t)n / 8) cap *= 2;
    val *bs = G_ROOT(NIL);
    *bs = h6_array(cap, NIL);
    *bs = h6_ref(*bs);   /* (a young array in a ref: no store, a fill) */
    val *cs = G_ROOT(h6_ref(mk_int(0)));
    uint64_t seed = 0x2545F4914F6CDD1DULL;
    for (int64_t i = 0; i < n; i++) {
        int64_t k = (int64_t)(xorshift64(&seed) % (uint64_t)(2 * n));
        KN(it_insert)(bs, cs, k, mk_int(i));
    }
    seed = 0x2545F4914F6CDD1DULL;
    int64_t sum = 0;
    for (int64_t i = 0; i < n; i++) {
        int64_t k = (int64_t)(xorshift64(&seed) % (uint64_t)(2 * n));
        obj *arr = ptr_of(g_get(*bs, 0));
        for (val l = FIELDS(arr)[(uint64_t)k % arr->len]; l != NIL; l = g_get(l, 1)) {
            val e = g_get(l, 0);
            if (int_of(g_get(e, 0)) == k) {
                val *vs = G_ROOT(g_get(g_get(e, 1), 0));
                obj *s = g_alloc(16, K_CON, 1, 1); FIELDS(s)[0] = *vs;   /* SOME (!r) */
                sum += int_of(FIELDS(s)[0]);
                g_rsp--;
                break;
            }
        }
    }
    h6_ck += (uint64_t)sum + (uint64_t)int_of(g_get(*cs, 0));
    g_rsp = m;
}

/* imp-for (examples/benchmarks/imp-for): for (0, w, f) as a ref and a
   closure per call, x := !x + 1 innermost; depth 4 */
static NOINLINE void KN(for_loop)(int depth, int64_t w, val *x) {
    size_t m = g_rsp;
    val *i = G_ROOT(h6_ref(mk_int(0)));
    val *f = G_ROOT(h6_closure(x));   /* fn _ => ... captures x */
    while (int_of(g_get(*i, 0)) < w) {
        if (depth <= 1) { obj *xo = ptr_of(g_get(*f, 1)); g_store(BAR, xo, 0, mk_int(int_of(FIELDS(xo)[0]) + 1)); }
        else KN(for_loop)(depth - 1, w, x);
        obj *io = ptr_of(*i);
        g_store(BAR, io, 0, mk_int(int_of(FIELDS(io)[0]) + 1));
    }
    g_rsp = m;
}
static NOINLINE void KN(impfor)(int64_t n) {
    size_t m = g_rsp;
    int64_t w = 2; while (w * w * w * w < n) w++;
    for (int64_t r = 0; r < 4; r++) {
        val *x = G_ROOT(h6_ref(mk_int(0)));
        KN(for_loop)(4, w, x);
        h6_ck += (uint64_t)int_of(g_get(*x, 0));
        g_rsp--;
    }
    g_rsp = m;
}

/* lazy_update_old (tests/layouts): 64K thunks survive a collection, then
   are forced in an order of their own; every update gives an old thunk a
   young value */
#define H6_LZ 65536
static NOINLINE void KN(lazyold)(int64_t n) {
    size_t m = g_rsp;
    int64_t rounds = n / H6_LZ; if (rounds < 1) rounds = 1;
    val *as = G_ROOT(h6_array(H6_LZ, NIL));
    uint64_t seed = 0x9E3779B97F4A7C15ULL;
    int64_t acc = 0;
    for (int64_t r = 0; r < rounds; r++) {
        for (uint32_t i = 0; i < H6_LZ; i++) {
            obj *th = g_alloc(16, K_THUNK, 0, 1);
            FIELDS(th)[0] = mk_int((int64_t)i + r);
            g_store(BAR, ptr_of(*as), i, ptr_val(th));
        }
        g_minor();   /* the thunks are old now */
        uint32_t stride = (uint32_t)xorshift64(&seed) | 1u, at = (uint32_t)xorshift64(&seed);
        for (uint32_t k = 0; k < H6_LZ; k++) {
            at += stride;
            val t = g_get(*as, at & (H6_LZ - 1));
            if (okind(ptr_of(t)) == K_THUNK) {
                val *ts = G_ROOT(t);
                int64_t x = int_of(g_get(t, 0));
                obj *v = g_alloc(24, K_CON, 0, 2);   /* the value: a fresh constructor */
                FIELDS(v)[0] = mk_int(x); FIELDS(v)[1] = mk_int(x + 1);
                obj *to = ptr_of(*ts);
                to->kind = (uint8_t)((to->kind & ~KIND_MASK) | K_IND);   /* value.h obj_become_ind */
                g_store(BAR, to, 0, ptr_val(v));
                g_rsp--;
                acc += x;
            } else acc += int_of(g_get(g_get(t, 0), 0));
        }
    }
    h6_ck += (uint64_t)acc;
    g_rsp = m;
}

/* r := x :: !r, the accumulator in a ref that SML code keeps: an old ref
   given a fresh cons at every step, emptied every 1,000 */
static NOINLINE void KN(refcons)(int64_t n) {
    size_t m = g_rsp;
    val *r = G_ROOT(h6_ref(NIL));
    val *hd = G_ROOT(NIL), *tl = G_ROOT(NIL);
    int64_t len = 0;
    for (int64_t i = 0; i < n; i++) {
        *hd = mk_int(i); *tl = g_get(*r, 0);
        val c = h6_cons(hd, tl);
        g_store(BAR, ptr_of(*r), 0, c);
        if (i % 1000 == 999) { len += 1000; g_store(BAR, ptr_of(*r), 0, NIL); }
    }
    h6_ck += (uint64_t)len;
    g_rsp = m;
}
