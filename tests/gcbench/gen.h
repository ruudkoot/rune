/* gen.h -- a generational heap for H6, with the barrier as a parameter:
   a nursery (bump), an old space the minor collection promotes into (bump,
   never collected here; touched before the timing), a crossing map for its
   cards, a shadow stack of roots, and a minor collection whose
   remembered set is the one the barrier in force keeps.

   The barriers (G_STORE: a store into field i of an object that exists,
   value.h's obj_set_field):
   none        the store alone; the minor scans the whole old space
   card        RUNE_BARRIER_CARDS (value.h's BARRIER): one byte for every 512
               bytes of address, in a table of 2^20 the address is folded
               into, marked at every store (of the slot's address, as the
               JIT's array_update passes it); the minor scans the bytes of
               the old space's cards and the fields of the dirty ones
   card-young  the same marked only when an old object is given a young
               value (a pointer into the nursery: one compare of the
               difference), and a card dirtied the first time goes on a
               list: the minor scans the list
   ssb-byte    object remembering: an old object given a young value goes
               on a sequential store buffer once, a side byte (one for every
               16 bytes of old space) saying it is there; the minor scans
               the remembered objects whole
   ssb-hdr     the same with the header's REMEMBERED bit (value.h 0x40)
   dart        Dart's combined barrier (runtime/vm/raw_object.h:829):
               (source tags >> 2) & target tags & mask, the target's header
               loaded; the tags in the header's pad byte (NEW, NOT_MARKED on
               the target side; OLD_AND_NOT_REMEMBERED, ALWAYS_SET two bits
               above them on the source side); the slow path remembers the
               object as ssb-hdr does. Incremental marking off (mask = NEW).
   satb-off    card-young plus a snapshot (deletion) barrier, Yuasa's: when
               marking, the old value is logged; marking is off
   satb-on     the same with marking on: every old pointer value logged
               into a 4096-entry buffer (a full buffer is counted and reset)

   check=1: after every minor collection neither a root nor an object of
   the old space points into the nursery, which is what the barrier's
   remembered set is for, and the old space parses. */
#ifndef GCB_GEN_H
#define GCB_GEN_H
#include "gcb.h"

enum { B_NONE, B_CARD, B_CARDY, B_SSB_BYTE, B_SSB_HDR, B_DART, B_SATB_OFF, B_SATB_ON, B_N };
static const char *bar_names[] = { "none", "card", "card-young", "ssb-byte", "ssb-hdr", "dart", "satb-off", "satb-on" };

/* Dart's tags, in the pad byte */
#define DT_NEW 1u
#define DT_NOTMARKED 2u
#define DT_OLDNOTREM 4u    /* DT_NEW << 2 */
#define DT_ALWAYS 8u       /* DT_NOTMARKED << 2 */
#define DT_YOUNG_TAGS (DT_NEW | DT_NOTMARKED | DT_ALWAYS)
#define DT_OLD_TAGS (DT_OLDNOTREM | DT_NOTMARKED | DT_ALWAYS)

static int g_bar;
static char *g_nbase, *g_nfree, *g_nlimit; static uintptr_t g_nsize;
static char *g_obase, *g_ofree, *g_olimit; static size_t g_ocap;
static val *g_roots; static size_t g_rsp;
#define G_ROOT(v) (g_roots[g_rsp] = (v), &g_roots[g_rsp++])

#define G_CARD_SHIFT 9
#define G_CARD_COUNT ((size_t)1 << 20)
static uint8_t *g_cards;                 /* the masked table */
static uintptr_t *g_cardlist; static size_t g_ncardlist, g_cardlist_cap;
static uint32_t *g_cross;                /* per old-space card: bytes back to the object over its first word */
static obj **g_ssb; static size_t g_nssb, g_ssb_cap;
static uint8_t *g_rembyte;
static int g_marking; static val *g_satb; static size_t g_nsatb;
#define G_SATB_CAP 4096
static uint64_t g_stores, g_o2y, g_slow, g_minors, g_promoted, g_cards_scanned, g_ssb_scanned, g_satb_logged, g_satb_flushes, g_large;
static phase g_gcph;

ALWAYS_INLINE int g_young(val v) { return !(v & 1) && (uintptr_t)v - (uintptr_t)g_nbase < g_nsize; }
ALWAYS_INLINE int g_old_obj(const obj *o) { return (uintptr_t)o - (uintptr_t)g_obase < (uintptr_t)g_ocap; }
ALWAYS_INLINE size_t g_card_ix(uintptr_t a) { return (a >> G_CARD_SHIFT) & (G_CARD_COUNT - 1); }

static NOINLINE void g_satb_flush(void) { g_satb_flushes++; g_nsatb = 0; }
/* a card dirtied for the first time since the last minor: on the list */
static NOINLINE void g_card_slow(uintptr_t slot) {
    g_cards[g_card_ix(slot)] = 1;
    g_cardlist[g_ncardlist++] = slot >> G_CARD_SHIFT;
    if (g_ncardlist == g_cardlist_cap) die("card list full");
    g_slow++;
}
static NOINLINE void g_ssb_push(obj *o) { g_ssb[g_nssb++] = o; if (g_nssb == g_ssb_cap) die("ssb full"); g_slow++; }

/* the store, by barrier (BAR a constant where it is inlined). g_o2y counts
   the stores that give an old object a young value (where the barrier
   finds out), g_slow the stores that take the out-of-line path (a card
   dirtied, an object remembered for the first time since the last minor). */
#define B_COUNT B_N   /* none, counting the stores: a pass that is not timed */
ALWAYS_INLINE void g_store(int bar, obj *o, uint32_t i, val v) {
    val *slot = &FIELDS(o)[i];
    switch (bar) {
    case B_NONE: *slot = v; break;
    case B_COUNT: *slot = v; g_stores++; if (g_young(v) && g_old_obj(o)) g_o2y++; break;
    case B_CARD: g_cards[g_card_ix((uintptr_t)slot)] = 1; *slot = v; break;
    case B_CARDY:
        *slot = v;
        if (g_young(v) && g_old_obj(o)) { g_o2y++; if (!g_cards[g_card_ix((uintptr_t)slot)]) g_card_slow((uintptr_t)slot); }
        break;
    case B_SSB_BYTE:
        *slot = v;
        if (g_young(v) && g_old_obj(o)) { g_o2y++; size_t ix = (size_t)((char *)o - g_obase) >> 4; if (!g_rembyte[ix]) { g_rembyte[ix] = 1; g_ssb_push(o); } }
        break;
    case B_SSB_HDR:
        *slot = v;
        if (g_young(v) && g_old_obj(o)) { g_o2y++; if (!(o->kind & GC_REMEMBERED)) { o->kind |= GC_REMEMBERED; g_ssb_push(o); } }
        break;
    case B_DART:
        *slot = v;
        if (is_ptr(v) && ((o->pad >> 2) & ptr_of(v)->pad & DT_NEW)) { o->pad &= (uint8_t)~DT_OLDNOTREM; g_ssb_push(o); }
        break;
    case B_SATB_OFF: case B_SATB_ON:
        if (UNLIKELY(g_marking)) { val old = *slot; if (is_ptr(old)) { g_satb[g_nsatb++] = old; g_satb_logged++; if (g_nsatb == G_SATB_CAP) g_satb_flush(); } }
        *slot = v;
        if (g_young(v) && g_old_obj(o)) { g_o2y++; if (!g_cards[g_card_ix((uintptr_t)slot)]) g_card_slow((uintptr_t)slot); }
        break;
    }
}

/* ---- the minor collection ---- */
static const char *g_bar_name(void) { return g_bar < B_N ? bar_names[g_bar] : "counting"; }
static void g_verify(void) {
    for (size_t i = 0; i < g_rsp; i++) if (g_young(g_roots[i])) { gcb_fail("H6 %s: a root points into the nursery after a minor", g_bar_name()); return; }
    for (char *p = g_obase; p < g_ofree; ) {
        obj *o = (obj *)p;
        size_t sz = osize(o);
        if (okind(o) == K_FORWARD || p + sz > g_ofree) { gcb_fail("H6 %s: the old space does not parse", g_bar_name()); return; }
        if (has_fields(o))
            for (uint32_t i = 0; i < o->len; i++)
                if (g_young(FIELDS(o)[i])) { gcb_fail("H6 %s: an old object points into the nursery after a minor (the barrier missed a store)", g_bar_name()); return; }
        p += sz;
    }
}
static inline void g_cross_fill(char *a, size_t s) {
    uintptr_t cs = rup((uintptr_t)a, (uintptr_t)1 << G_CARD_SHIFT);
    for (; cs < (uintptr_t)a + s; cs += (uintptr_t)1 << G_CARD_SHIFT)
        g_cross[(cs - (uintptr_t)g_obase) >> G_CARD_SHIFT] = (uint32_t)(cs - (uintptr_t)a);
}
ALWAYS_INLINE obj *g_copy(obj *o) {
    if (okind(o) == K_FORWARD) { obj *n; memcpy(&n, FIELDS(o), 8); return n; }
    size_t sz = osize(o);
    obj *n = (obj *)g_ofree;
    if (UNLIKELY(g_ofree + sz > g_olimit)) die("H6: the old space overflowed");
    switch (sz) {
    case 16: memcpy(n, o, 16); break;
    case 24: memcpy(n, o, 24); break;
    case 32: memcpy(n, o, 32); break;
    case 40: memcpy(n, o, 40); break;
    case 48: memcpy(n, o, 48); break;
    default: memcpy(n, o, sz); break;
    }
    n->pad = DT_OLD_TAGS;
    g_ofree += sz;
    g_cross_fill((char *)n, sz);
    o->kind = K_FORWARD;
    memcpy(FIELDS(o), &n, 8);
    return n;
}
ALWAYS_INLINE void g_fwd(val *v) { if (g_young(*v)) *v = ptr_val(g_copy(ptr_of(*v))); }
static inline void g_scan_obj(obj *o) {
    if (!has_fields(o)) return;
    val *f = FIELDS(o);
    for (uint32_t i = 0, n = o->len; i < n; i++) g_fwd(&f[i]);
}
/* the fields of old objects that lie in card CARD (an address >> 9), below LIMIT */
static void g_scan_card(uintptr_t card, char *limit) {
    char *cs = (char *)(card << G_CARD_SHIFT), *ce = cs + ((size_t)1 << G_CARD_SHIFT);
    if (cs >= limit) return;
    char *p = cs - g_cross[(size_t)(cs - g_obase) >> G_CARD_SHIFT];
    if (ce > limit) ce = limit;
    g_cards_scanned++;
    while (p < ce) {
        obj *o = (obj *)p;
        size_t sz = osize(o);
        if (has_fields(o)) {
            val *f = FIELDS(o), *fe = f + o->len;
            val *a = (char *)f < cs ? (val *)cs : f, *b = (char *)fe > ce ? (val *)ce : fe;
            for (; a < b; a++) g_fwd(a);
        }
        p += sz;
    }
}
static NOINLINE void g_minor(void) {
    ph_begin(&g_gcph);
    char *old_end = g_ofree, *scan = g_ofree;
    for (size_t i = 0; i < g_rsp; i++) g_fwd(&g_roots[i]);
    switch (g_bar) {
    case B_NONE: case B_COUNT:
        for (char *p = g_obase; p < old_end; ) { obj *o = (obj *)p; g_scan_obj(o); p += osize(o); }
        break;
    case B_CARD: {
        uintptr_t c0 = (uintptr_t)g_obase >> G_CARD_SHIFT, c1 = ((uintptr_t)old_end + ((uintptr_t)1 << G_CARD_SHIFT) - 1) >> G_CARD_SHIFT;
        for (uintptr_t c = c0; c < c1; c++) if (g_cards[g_card_ix(c << G_CARD_SHIFT)]) g_scan_card(c, old_end);
        memset(g_cards, 0, G_CARD_COUNT);   /* the nursery's cards too: the whole table */
        break;
    }
    case B_CARDY: case B_SATB_OFF: case B_SATB_ON:
        for (size_t i = 0; i < g_ncardlist; i++) { g_scan_card(g_cardlist[i], old_end); g_cards[g_card_ix(g_cardlist[i] << G_CARD_SHIFT)] = 0; }
        g_ncardlist = 0;
        break;
    case B_SSB_BYTE: case B_SSB_HDR: case B_DART:
        for (size_t i = 0; i < g_nssb; i++) {
            obj *o = g_ssb[i];
            g_scan_obj(o);
            g_ssb_scanned++;
            if (g_bar == B_SSB_BYTE) g_rembyte[(size_t)((char *)o - g_obase) >> 4] = 0;
            else if (g_bar == B_SSB_HDR) o->kind &= (uint8_t)~GC_REMEMBERED;
            else o->pad |= DT_OLDNOTREM;
        }
        g_nssb = 0;
        break;
    }
    while (scan < g_ofree) { obj *o = (obj *)scan; g_scan_obj(o); scan += osize(o); }
    g_promoted += (uint64_t)(g_ofree - old_end);
    g_nfree = g_nbase;
    g_minors++;
    ph_end(&g_gcph);
    if (gcb_check) g_verify();
}

/* ---- allocation: an object over a quarter of the nursery goes to the old
   space at once (with its crossing map), with fields that are immediates
   or old (the caller's to keep it so) ---- */
static NOINLINE obj *g_alloc_slow(size_t sz) {
    if (sz > g_nsize / 4) {
        obj *o = (obj *)g_ofree;
        if (g_ofree + sz > g_olimit) die("H6: the old space overflowed");
        g_ofree += sz; g_cross_fill((char *)o, sz); g_large++;
        return o;
    }
    g_minor();
    obj *o = (obj *)g_nfree; g_nfree += sz;
    return o;
}
ALWAYS_INLINE obj *g_alloc(size_t sz, int kind, int contag, uint32_t len) {
    obj *o;
    if (LIKELY(g_nfree + sz <= g_nlimit)) { o = (obj *)g_nfree; g_nfree += sz; }
    else o = g_alloc_slow(sz);
    /* one 8-byte store: kind, Dart's young tags (an old large object gets the old ones), contag, len */
    uint64_t pad = g_old_obj(o) ? DT_OLD_TAGS : DT_YOUNG_TAGS;
    uint64_t h = (uint64_t)(uint8_t)kind | (pad << 8) | ((uint64_t)(uint16_t)contag << 16) | ((uint64_t)len << 32);
    memcpy(o, &h, 8);
    return o;
}
ALWAYS_INLINE val g_get(val o, uint32_t i) { return FIELDS(ptr_of(o))[i]; }

static void g_init(size_t nursery, size_t old_cap) {
    g_nsize = nursery;
    g_nbase = region(nursery, MAP_TOUCH); g_nlimit = g_nbase + nursery; g_nfree = g_nbase;
    g_ocap = old_cap;
    g_obase = region(old_cap, MAP_TOUCH); g_olimit = g_obase + old_cap; g_ofree = g_obase;
    g_roots = region(1u << 24, MAP_TOUCH); g_rsp = 0;
    g_cards = region(G_CARD_COUNT, MAP_TOUCH);
    g_cardlist_cap = 1u << 20; g_cardlist = region(g_cardlist_cap * sizeof *g_cardlist, MAP_TOUCH);
    g_cross = region(rup((old_cap >> G_CARD_SHIFT) * 4 + 4, 4096), MAP_TOUCH);
    g_ssb_cap = 1u << 22; g_ssb = region(g_ssb_cap * sizeof *g_ssb, MAP_TOUCH);
    g_rembyte = region(rup(old_cap / 16, 4096), MAP_TOUCH);
    g_satb = region(G_SATB_CAP * sizeof *g_satb, MAP_TOUCH);
}
static void g_reset(int bar) {
    g_bar = bar;
    g_nfree = g_nbase; g_ofree = g_obase; g_rsp = 0;
    memset(g_cards, 0, G_CARD_COUNT); g_ncardlist = 0; g_nssb = 0; g_nsatb = 0;
    memset(g_rembyte, 0, g_ocap / 16);
    g_marking = bar == B_SATB_ON;
    g_stores = g_o2y = g_slow = g_minors = g_promoted = g_cards_scanned = g_ssb_scanned = g_satb_logged = g_satb_flushes = g_large = 0;
    ph_clear(&g_gcph);
}
#endif
