/* h7.c -- H7, the order a collector leaves the live objects in, and what
   the mutator pays for it afterwards. Two structures are built in a bump
   arena the way an SML program builds them, garbage between them:

   map   a functional binary search tree (CON: key, left, right; 32 bytes)
         made by N insertions of random keys with path copying: the old
         paths are garbage, the live tree is spread over the arena
   list  N cons cells (24 bytes), each followed by a dead object of 16 to
         64 bytes

   Then the live data is laid out four ways:
   holes   where it was allocated (a non-moving collector: mark-sweep, Immix
           without evacuation)
   slide   compacted in address order (Lisp-2 / Jonkers sliding: the
           allocation order without the gaps)
   bfs     Cheney's breadth-first copy from the root (collect.h)
   dfs     a depth-first copy (an explicit stack: a node, then its first
           child's subtree, then the second's), what hierarchical copying
           approximates (Wilson, Lam and Moher 1991)
   and the mutator runs over it: map-find (N lookups of random keys),
   map-walk (an in-order traversal), list-sum. Rows: cycles per node
   visited, with the misses.

   check=1: every layout holds the live bytes the marking found, and every
   operation gives the same result on every layout.

   gcbench h7 [n=256K,1M] [reps=5] */
#include "gcb.h"
#include "collect.h"

static char *a7_free, *a7_end;
static obj *a7_alloc(size_t sz, int kind, int contag, uint32_t len) {
    if (a7_free + sz > a7_end) die("H7: the arena is full");
    obj *o = (obj *)a7_free; a7_free += sz; hdr(o, kind, contag, len); return o;
}
/* insert K into the tree T with path copying (recursive: the depth is ~2 ln N) */
static val map_insert(val t, int64_t k) {
    if (t == NIL) { obj *o = a7_alloc(32, K_CON, 1, 3); FIELDS(o)[0] = mk_int(k); FIELDS(o)[1] = NIL; FIELDS(o)[2] = NIL; return ptr_val(o); }
    obj *n = ptr_of(t);
    int64_t key = int_of(FIELDS(n)[0]);
    if (k == key) return t;
    val l = FIELDS(n)[1], r = FIELDS(n)[2];
    if (k < key) l = map_insert(l, k); else r = map_insert(r, k);
    obj *o = a7_alloc(32, K_CON, 1, 3);
    FIELDS(o)[0] = mk_int(key); FIELDS(o)[1] = l; FIELDS(o)[2] = r;
    return ptr_val(o);
}
static NOINLINE int64_t map_find_all(val t, size_t n, uint64_t seed, int64_t range) {
    int64_t found = 0;
    for (size_t i = 0; i < n; i++) {
        int64_t k = (int64_t)(xorshift64(&seed) % (uint64_t)range);
        val x = t;
        while (x != NIL) {
            const obj *o = ptr_of(x);
            int64_t key = int_of(FIELDS(o)[0]);
            if (k == key) { found++; break; }
            x = FIELDS(o)[k < key ? 1 : 2];
        }
    }
    return found;
}
static int64_t map_walk(val t) {
    int64_t s = 0;
    while (t != NIL) {   /* in order: recursion on the left, a loop on the right */
        const obj *o = ptr_of(t);
        s += map_walk(FIELDS(o)[1]) + int_of(FIELDS(o)[0]);
        t = FIELDS(o)[2];
    }
    return s;
}
static NOINLINE int64_t list_sum(val l) { int64_t s = 0; while (l != NIL) { const obj *o = ptr_of(l); s += int_of(FIELDS(o)[0]); l = FIELDS(o)[1]; } return s; }

/* the depth-first copy */
static NOINLINE void copy_dfs(val *root, char *to, val **stack) {
    val **st = stack; size_t sp = 0;
    cc_free = to; cc_objs = 0;
    st[sp++] = root;
    while (sp) {
        val *slot = st[--sp];
        val v = *slot;
        if (!is_ptr(v)) continue;
        obj *o = ptr_of(v);
        if (okind(o) == K_FORWARD) { obj *n; memcpy(&n, FIELDS(o), 8); *slot = ptr_val(n); continue; }
        obj *n = cc_copy(o);
        *slot = ptr_val(n);
        if (has_fields(n)) for (uint32_t i = n->len; i-- > 0; ) st[sp++] = &FIELDS(n)[i];
    }
}
/* sliding order: the marked objects copied in address order, then the
   pointers fixed through the forwarding words left behind */
static NOINLINE void copy_slide(char *from, char *from_end, char *to, mk_t *m) {
    char *t = to;
    for (char *p = from; p < from_end; ) {
        obj *o = (obj *)p;
        size_t sz = osize(o);
        if (hdr_marked(m, o)) { memcpy(t, o, sz); o->kind = K_FORWARD; memcpy(FIELDS(o), &t, 8); t += sz; }
        p += sz;
    }
    for (char *p = to; p < t; ) {
        obj *o = (obj *)p;
        if (has_fields(o)) for (uint32_t i = 0; i < o->len; i++) {
            val v = FIELDS(o)[i];
            if (is_ptr(v)) { obj *f = ptr_of(v), *n; memcpy(&n, FIELDS(f), 8); FIELDS(o)[i] = ptr_val(n); }
        }
        p += osize(o);
    }
    cc_free = t;
}

enum { L_HOLES, L_SLIDE, L_BFS, L_DFS };
static const char *lay_names[] = { "holes", "slide", "bfs", "dfs" };

static void exp_h7(void) {
    double ns[8]; int nn = opt_list("n", "256K,1M", ns, 8);
    int reps = (int)opt_n("reps", 5);
    for (int ni = 0; ni < nn; ni++) {
        size_t n = (size_t)ns[ni];
        for (int st = 0; st < 2; st++) {   /* 0 map, 1 list */
            size_t arena = st == 0 ? n * 32 * 40 : n * (24 + 64);
            char *base = region(arena, MAP_NOPOP);
            a7_free = base; a7_end = base + arena;
            uint64_t seed = 0x7777ULL + n;
            val root = NIL;
            int64_t range = (int64_t)n * 4;
            if (st == 0) for (size_t i = 0; i < n; i++) root = map_insert(root, (int64_t)(xorshift64(&seed) % (uint64_t)range));
            else for (size_t i = 0; i < n; i++) {
                obj *c = a7_alloc(24, K_CON, 1, 2); FIELDS(c)[0] = mk_int((int64_t)i); FIELDS(c)[1] = root; root = ptr_val(c);
                size_t g = 16 + 8 * rnd_below(&seed, 7);
                obj *d = a7_alloc(g, K_TUPLE, 0, fields_for(g)); for (uint32_t j = 0; j < d->len; j++) FIELDS(d)[j] = mk_int(j);
            }
            char *from_end = a7_free;
            /* marks, for the live size and for sliding */
            mk_t m; mk_init(&m, base, (size_t)(from_end - base), n * 4 + 16);
            mark_hdr(&m, root);
            size_t live = m.marked_bytes, nodes = m.marked;
            fprintf(stderr, "# H7 %s n=%zu: arena %.1f MiB used, live %.1f MiB (%zu nodes)\n", st ? "list" : "map", n, (double)(from_end - base) / 1048576.0, (double)live / 1048576.0, nodes);
            char *to = region(rup(live + 4096, 4096), MAP_TOUCH);
            val **dstack = malloc((nodes * 3 + 16) * sizeof *dstack);
            int64_t ck_ref[2] = { 0, 0 };   /* the results on the first layout */
            for (int lay = 0; lay < 4; lay++) {
                /* every layout is made from the arena as built, which the copies forward: rebuild by saving it */
                val r = root;
                char *save = NULL;
                if (lay != L_HOLES) {
                    save = malloc((size_t)(from_end - base)); memcpy(save, base, (size_t)(from_end - base));
                    if (lay == L_SLIDE) copy_slide(base, from_end, to, &m);
                    else if (lay == L_BFS) cheney(&r, 1, to);
                    else copy_dfs(&r, to, dstack);
                    if (lay == L_SLIDE) { obj *f = ptr_of(root), *nn2; memcpy(&nn2, FIELDS(f), 8); r = ptr_val(nn2); }
                    if (gcb_check && (size_t)(cc_free - to) != live)
                        gcb_fail("H7 %s n=%zu %s: %zu bytes laid out, %zu live", st ? "list" : "map", n, lay_names[lay], (size_t)(cc_free - to), live);
                }
                const char *ops[2] = { st == 0 ? "map-find" : "list-sum", st == 0 ? "map-walk" : NULL };
                for (int op = 0; op < 2; op++) {
                    if (!ops[op]) continue;
                    reps_t rr; reps_init(&rr);
                    int64_t ck = 0; double visits = 0;
                    for (int k = 0; k < reps; k++) {
                        ctrs a, b, d;
                        pc_read(&a);
                        if (st == 1) { ck = list_sum(r); visits = (double)n; }
                        else if (op == 0) { ck = map_find_all(r, n, 0x1234ULL, range); visits = (double)n * 2.0 * log((double)n); }
                        else { ck = map_walk(r); visits = (double)nodes; }
                        pc_read(&b);
                        ctrs_sub(&d, &b, &a);
                        reps_add(&rr, &d);
                    }
                    SINK(ck);
                    char cas[96], hb[32];
                    snprintf(cas, sizeof cas, "%s/%s/n=%s", ops[op], lay_names[lay], human((double)n, hb));
                    if (lay == 0) ck_ref[op] = ck;
                    else if (gcb_check && ck != ck_ref[op]) gcb_fail("H7 %s: checksum %lld, %lld laid out %s", cas, (long long)ck, (long long)ck_ref[op], lay_names[0]);
                    /* map-find: per lookup (its path ~2 ln n nodes long) */
                    if (st == 0 && op == 0) reps_out(&rr, "H7", cas, "lookup", (double)n);
                    else reps_out(&rr, "H7", cas, "node", visits);
                    fprintf(stderr, "# H7 %s: checksum %lld\n", cas, (long long)ck);
                }
                if (save) { memcpy(base, save, (size_t)(from_end - base)); free(save); }
            }
            free(dstack);
            mk_done(&m);
            region_free(to, rup(live + 4096, 4096));
            region_free(base, arena);
        }
    }
}
