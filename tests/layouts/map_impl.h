/* map_impl.h -- ordmap.sml's AVL tree (T of int * map * key * 'a * map, a
   5-field CONN node, tag 1; E = nullary tag 0) instantiated twice by
   kernels.c: MAP_NAME, MAP_KEYPTR (the key field is a pointer), MAP_CMP(a,b).
   The key and value of an insert sit in root slots for the whole insert,
   as the SML's local `go` closes over them. */
#define MAPFN_(a, b) a##_##b
#define MAPFN__(a, b) MAPFN_(a, b)
#define MAPFN(x) MAPFN__(MAP_NAME, x)
#define NODE_MASK ((1u << 1) | (1u << 4) | ((uint32_t)MAP_KEYPTR << 2) | ((uint32_t)POLY_PTRBIT << 3))

static inline int64_t MAPFN(height)(val t) { return is_nil(t) ? 0 : MONO_INT_OF(field_get(ptr_of(t), 0)); }

static NOINLINE val MAPFN(mk)(val l, val k, val v, val r) {
    size_t sz = alloc_size(K_CON, 1, 5);
    GUARD4(sz, l, 1, k, MAP_KEYPTR, v, POLY_PTRBIT, r, 1);
    int64_t hl = MAPFN(height)(l), hr = MAPFN(height)(r);
    obj *o = alloc(K_CON, 1, 5, NODE_MASK);
    field_set(o, 0, MONO_INT((hl > hr ? hl : hr) + 1));
    field_set(o, 1, l); field_set(o, 2, k); field_set(o, 3, v); field_set(o, 4, r);
    return ptr_val(o);
}

static NOINLINE val MAPFN(rotL)(val t) {
    obj *o = ptr_of(t);
    val r = field_get(o, 4);
    if (is_nil(r)) return t;
    val *ts = PROOT_PUSH(t);
    obj *ro = ptr_of(r);
    val inner = MAPFN(mk)(field_get(o, 1), field_get(o, 2), field_get(o, 3), field_get(ro, 1));
    o = ptr_of(*ts); ro = ptr_of(field_get(o, 4));
    val res = MAPFN(mk)(inner, field_get(ro, 2), field_get(ro, 3), field_get(ro, 4));
    ROOT_POP();
    return res;
}

static NOINLINE val MAPFN(rotR)(val t) {
    obj *o = ptr_of(t);
    val l = field_get(o, 1);
    if (is_nil(l)) return t;
    val *ts = PROOT_PUSH(t);
    obj *lo = ptr_of(l);
    val inner = MAPFN(mk)(field_get(lo, 4), field_get(o, 2), field_get(o, 3), field_get(o, 4));
    o = ptr_of(*ts); lo = ptr_of(field_get(o, 1));
    val res = MAPFN(mk)(field_get(lo, 1), field_get(lo, 2), field_get(lo, 3), inner);
    ROOT_POP();
    return res;
}

static NOINLINE val MAPFN(bal)(val l, val k, val v, val r) {
    int64_t hl = MAPFN(height)(l), hr = MAPFN(height)(r);
    if (hl > hr + 1) {
        obj *lo = ptr_of(l);
        if (MAPFN(height)(field_get(lo, 1)) >= MAPFN(height)(field_get(lo, 4)))
            return MAPFN(rotR)(MAPFN(mk)(l, k, v, r));
        val *ks = root_push_m(k, MAP_KEYPTR), *vs = root_push_m(v, POLY_PTRBIT), *rs = PROOT_PUSH(r);
        val nl = MAPFN(rotL)(l);
        r = *rs; v = *vs; k = *ks;
        ROOT_POP(); root_pop_m(POLY_PTRBIT); root_pop_m(MAP_KEYPTR);
        return MAPFN(rotR)(MAPFN(mk)(nl, k, v, r));
    }
    if (hr > hl + 1) {
        obj *ro = ptr_of(r);
        if (MAPFN(height)(field_get(ro, 4)) >= MAPFN(height)(field_get(ro, 1)))
            return MAPFN(rotL)(MAPFN(mk)(l, k, v, r));
        val *ls = PROOT_PUSH(l), *ks = root_push_m(k, MAP_KEYPTR), *vs = root_push_m(v, POLY_PTRBIT);
        val nr = MAPFN(rotR)(r);
        v = *vs; k = *ks; l = *ls;
        root_pop_m(POLY_PTRBIT); root_pop_m(MAP_KEYPTR); ROOT_POP();
        return MAPFN(rotL)(MAPFN(mk)(l, k, v, nr));
    }
    return MAPFN(mk)(l, k, v, r);
}

/* insert's `go`: k and v in the root slots ks and vs */
static NOINLINE val MAPFN(ins)(val t, val *ks, val *vs) {
    if (is_nil(t)) return MAPFN(mk)(NIL, *ks, *vs, NIL);
    obj *o = ptr_of(t);
    int c = MAP_CMP(*ks, field_get(o, 2));
    if (c < 0) {
        val *ts = PROOT_PUSH(t);
        val nl = MAPFN(ins)(field_get(o, 1), ks, vs);
        o = ptr_of(*ts); ROOT_POP();
        return MAPFN(bal)(nl, field_get(o, 2), field_get(o, 3), field_get(o, 4));
    }
    if (c > 0) {
        val *ts = PROOT_PUSH(t);
        val nr = MAPFN(ins)(field_get(o, 4), ks, vs);
        o = ptr_of(*ts); ROOT_POP();
        return MAPFN(bal)(field_get(o, 1), field_get(o, 2), field_get(o, 3), nr);
    }
    /* EQUAL: T (h, l, k, v, r) with the new key and value */
    val *ts = PROOT_PUSH(t);
    size_t sz = alloc_size(K_CON, 1, 5);
    GUARD0(sz);
    o = ptr_of(*ts); ROOT_POP();
    obj *n = alloc(K_CON, 1, 5, NODE_MASK);
    field_set(n, 0, field_get(o, 0)); field_set(n, 1, field_get(o, 1));
    field_set(n, 2, *ks); field_set(n, 3, *vs); field_set(n, 4, field_get(o, 4));
    return ptr_val(n);
}

/* find: SOME v is a CON object of one field (Rune: 24 bytes today) */
static NOINLINE val MAPFN(find)(val t, val k) {
    while (!is_nil(t)) {
        obj *o = ptr_of(t);
        int c = MAP_CMP(k, field_get(o, 2));
        if (c == 0) {
            val v = field_get(o, 3);
            size_t sz = alloc_size(K_CON, 1, 1);
            GUARD1(sz, v, POLY_PTRBIT);
            obj *s = alloc(K_CON, 1, 1, POLY_PTRBIT);
            field_set(s, 0, v);
            return ptr_val(s);
        }
        t = c < 0 ? field_get(o, 1) : field_get(o, 4);
    }
    return NIL;   /* NONE */
}
#undef MAPFN
#undef MAPFN_
#undef MAPFN__
#undef NODE_MASK
#undef MAP_NAME
#undef MAP_KEYPTR
#undef MAP_CMP
