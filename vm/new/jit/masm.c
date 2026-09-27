/* The macro-assembler of vm/new's JIT (masm.h). */
#include "masm.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OFF(field) ((int32_t)offsetof(VM, field))
#define SLOT(k) slot(m, k)
#define PAYLOAD(k) (slot(m, k) + 8)

/* an emitter's mistake (masm.h) */
static void bug(const char *what, long long k, long long of) {
    fprintf(stderr, "runevm: jit: internal error: %s: %lld of %lld\n", what, k, of);
    abort();
}
/* where register k of the frame is, from r14 */
static int32_t slot(const Masm *m, int32_t k) {
    if (k < 0 || (uint32_t)k >= m->nslots) bug("a register the frame does not have", k, m->nslots);
    return 16 * k;
}

void ms_init(Masm *m, uint32_t nlocals, uint32_t maxstack, int win, const void *leave) {
    as_init(&m->a);
    m->win = win;
    m->nlocals = nlocals;
    m->nslots = nlocals + maxstack;
    m->nfields = UINT32_MAX;
    m->leave = leave;
    m->homes = NULL;
    m->live = NULL;
    m->from = 0;
    m->sync_pc = 0;
    m->cur_pc = 0;
    m->reps = NULL;
    m->slow = NULL;
    m->nslow = m->slow_cap = 0;
}
void ms_free(Masm *m) {
    for (int i = 0; i < m->nslow; i++) { as_label_free(&m->slow[i].here); as_label_free(&m->slow[i].back); }
    free(m->slow);
    as_free(&m->a);
}

int ms_arg(const Masm *m, int i) { return as_arg(m->win, i); }

/* ---- values ---- */

/* a home's value, as a Value, into its slot (tier 2) */
static void home_to_slot(Masm *m, int32_t s, const Home *h) {
    as_st64i(&m->a, BASER, SLOT(s), h->tag);
    if (h->kind == HOME_GPR) as_st64(&m->a, BASER, PAYLOAD(s), h->reg);
    else as_fst(&m->a, BASER, PAYLOAD(s), h->reg);
}
/* a home loaded from its slot */
static void slot_to_home(Masm *m, int32_t s, const Home *h) {
    if (h->kind == HOME_GPR) as_ld64(&m->a, h->reg, BASER, PAYLOAD(s));
    else as_fld(&m->a, h->reg, BASER, PAYLOAD(s));
}
/* a Value at [base + disp] written from a home, or loaded into one */
static void home_to_mem(Masm *m, int base, int32_t disp, const Home *h) {
    as_st64i(&m->a, base, disp, h->tag);
    if (h->kind == HOME_GPR) as_st64(&m->a, base, disp + 8, h->reg);
    else as_fst(&m->a, base, disp + 8, h->reg);
}
static void mem_to_home(Masm *m, const Home *h, int base, int32_t disp) {
    if (h->kind == HOME_GPR) as_ld64(&m->a, h->reg, base, disp + 8);
    else as_fld(&m->a, h->reg, base, disp + 8);
}

void ms_copy(Masm *m, int32_t d, int32_t s) {
    const Home *hd = ms_home(m, d), *hs = ms_home(m, s);
    if (d == s) return;
    if (hd && hs) {
        if (hd->kind == HOME_GPR && hs->kind == HOME_GPR) as_mov_rr(&m->a, hd->reg, hs->reg);
        else if (hd->kind == HOME_XMM && hs->kind == HOME_XMM) as_fmov(&m->a, hd->reg, hs->reg);
        else if (hd->kind == HOME_GPR) as_fmov_rf(&m->a, hd->reg, hs->reg);
        else as_fmov_fr(&m->a, hd->reg, hs->reg);
    } else if (hd) slot_to_home(m, s, hd);
    else if (hs) home_to_slot(m, d, hs);
    else {
        as_ld128(&m->a, F_S0, BASER, SLOT(s));
        as_st128(&m->a, BASER, SLOT(d), F_S0);
    }
}
void ms_set(Masm *m, int32_t d, int tag, int64_t payload) {
    const Home *h = ms_home(m, d);
    if (h) {
        if (h->kind == HOME_GPR) as_mov_ri(&m->a, h->reg, payload);
        else { as_mov_ri(&m->a, R_S0, payload); as_fmov_fr(&m->a, h->reg, R_S0); }
        return;
    }
    as_st64i(&m->a, BASER, SLOT(d), tag);
    if (payload >= INT32_MIN && payload <= INT32_MAX) as_st64i(&m->a, BASER, PAYLOAD(d), (int32_t)payload);
    else { as_mov_ri(&m->a, R_S0, payload); as_st64(&m->a, BASER, PAYLOAD(d), R_S0); }
}
void ms_set_reg(Masm *m, int32_t d, int tag, int r) {
    const Home *h = ms_home(m, d);
    if (h) {
        if (h->kind == HOME_GPR) as_mov_rr(&m->a, h->reg, r);
        else as_fmov_fr(&m->a, h->reg, r);
        return;
    }
    as_st64i(&m->a, BASER, SLOT(d), tag);
    as_st64(&m->a, BASER, PAYLOAD(d), r);
}
void ms_load_tag(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) as_mov_ri(&m->a, r, h->tag);
    else as_ld8(&m->a, r, BASER, SLOT(s));
}
void ms_load_payload(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) { if (h->kind == HOME_GPR) as_mov_rr(&m->a, r, h->reg); else as_fmov_rf(&m->a, r, h->reg); }
    else as_ld64(&m->a, r, BASER, PAYLOAD(s));
}
void ms_load_value(Masm *m, int32_t d, int base, int32_t disp) {
    const Home *h = ms_home(m, d);
    if (h) { mem_to_home(m, h, base, disp); return; }
    as_ld128(&m->a, F_S0, base, disp);
    as_st128(&m->a, BASER, SLOT(d), F_S0);
}
void ms_store_value(Masm *m, int base, int32_t disp, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) { home_to_mem(m, base, disp, h); return; }
    as_ld128(&m->a, F_S0, BASER, SLOT(s));
    as_st128(&m->a, base, disp, F_S0);
}
void ms_value_to(Masm *m, int base, int32_t disp, int32_t s) { ms_store_value(m, base, disp, s); }
void ms_value_from(Masm *m, int32_t d, int base, int32_t disp) { ms_load_value(m, d, base, disp); }
void ms_load_real(Masm *m, int xmm, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) as_fmov(&m->a, xmm, h->reg);   /* a real's home is an xmm */
    else as_fld(&m->a, xmm, BASER, PAYLOAD(s));
}
void ms_set_real(Masm *m, int32_t d, int xmm) {
    const Home *h = ms_home(m, d);
    if (h) { as_fmov(&m->a, h->reg, xmm); return; }
    as_st64i(&m->a, BASER, SLOT(d), T_REAL);
    as_fst(&m->a, BASER, PAYLOAD(d), xmm);
}
void ms_cmp_payload(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h && h->kind == HOME_GPR) as_cmp_rr(&m->a, r, h->reg);
    else if (h) { as_fmov_rf(&m->a, R_S2, h->reg); as_cmp_rr(&m->a, r, R_S2); }
    else as_cmp_rm(&m->a, r, BASER, PAYLOAD(s));
}
void ms_test_false(Masm *m, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) as_test_rr(&m->a, h->reg, h->reg);   /* a bool's home is a general register */
    else as_cmp_mi(&m->a, BASER, PAYLOAD(s), 0);
}
void ms_load_xmm(Masm *m, int xmm, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) home_to_slot(m, s, h);   /* the slot made whole first */
    as_ld128(&m->a, xmm, BASER, SLOT(s));
}
void ms_check_tag(Masm *m, int32_t s, int tag, AsmLabel *unless) {
    const Home *h = ms_home(m, s);
    if (h) {
        if (h->tag != tag) as_jmp(&m->a, unless);   /* never the tag: always the other way */
        return;
    }
    as_cmp8_mi(&m->a, BASER, SLOT(s), tag);
    as_jcc(&m->a, CC_NE, unless);
}
/* tier 2: the safepoints' write-back and reload of the homes live at pc */
static int live_at(const Masm *m, uint32_t pc, uint32_t r) {
    if (!m->live) return 1;
    return (m->live[pc - m->from] >> r) & 1;
}
void ms_writeback(Masm *m, uint32_t pc) {
    if (!m->homes) return;
    for (uint32_t r = 0; r < m->nlocals; r++)
        if (m->homes[r].kind != HOME_SLOT && live_at(m, pc, r)) home_to_slot(m, (int32_t)r, &m->homes[r]);
}
void ms_reload_homes(Masm *m, uint32_t pc) {
    if (!m->homes) return;
    for (uint32_t r = 0; r < m->nlocals; r++)
        if (m->homes[r].kind != HOME_SLOT && live_at(m, pc, r)) slot_to_home(m, (int32_t)r, &m->homes[r]);
}
int ms_immediate(const Masm *m, int32_t s) {
    if (!m->reps || (uint32_t)s >= m->nlocals) return 0;
    int rep = m->reps[s];
    return rep == REP_INT || rep == REP_WORD || rep == REP_CHAR || rep == REP_CON0;
}
int ms_trusts(const Masm *m, int32_t s, int kind) {
    if (!m->reps || (uint32_t)s >= m->nlocals) return 0;
    int rep = m->reps[s];
    return rep == REP_PTR || (rep == REP_CON && kind == K_CON);
}
void ms_load_obj(Masm *m, int r, int32_t s, int kind, AsmLabel *unless) {
    m->nfields = UINT32_MAX;   /* an object of the program's, whose length the code tests */
    if (ms_trusts(m, s, kind)) { as_ld64(&m->a, r, BASER, PAYLOAD(s)); return; }   /* tier 2: the section says so (M10) */
    ms_check_tag(m, s, T_PTR, unless);
    as_ld64(&m->a, r, BASER, PAYLOAD(s));
    as_cmp8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), kind);
    as_jcc(&m->a, CC_NE, unless);
}
/* a nullary constructor's tag is its payload; one with an argument's is in
   the object's header */
void ms_load_tag_of_con(Masm *m, int r, int32_t s, AsmLabel *unless) {
    const Home *h = ms_home(m, s);
    if (h) { as_mov_rr(&m->a, r, h->reg); return; }   /* a nullary constructor: its tag is its payload */
    AsmLabel ptr, done;
    as_label_init(&ptr); as_label_init(&done);
    as_cmp8_mi(&m->a, BASER, SLOT(s), T_CON0);
    as_jcc(&m->a, CC_NE, &ptr);
    as_ld64(&m->a, r, BASER, PAYLOAD(s));
    as_jmp(&m->a, &done);
    as_bind(&m->a, &ptr);
    /* not nullary: a pointer to a constructor, which the section
       vouches for at tier 2 (M10); else tested */
    int trusted = m->reps && (uint32_t)s < m->nlocals && m->reps[s] == REP_CON;
    if (!trusted) { as_cmp8_mi(&m->a, BASER, SLOT(s), T_PTR); as_jcc(&m->a, CC_NE, unless); }
    as_ld64(&m->a, r, BASER, PAYLOAD(s));
    if (!trusted) { as_cmp8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), K_CON); as_jcc(&m->a, CC_NE, unless); }
    as_ld16(&m->a, r, r, (int32_t)offsetof(Obj, contag));
    as_bind(&m->a, &done);
    as_label_free(&ptr); as_label_free(&done);
}

/* ---- the VM ---- */
void ms_sync(Masm *m, uint32_t pc, int pushed) {
    ms_writeback(m, m->cur_pc);
    m->sync_pc = pc;
    as_st32i(&m->a, VMR, OFF(pc), (int32_t)pc);
    as_lea(&m->a, R_S0, BASEI, -1, 1, (int32_t)(m->nlocals + (uint32_t)pushed));
    as_st64(&m->a, VMR, OFF(sp), R_S0);
    as_st64(&m->a, VMR, OFF(instructions), COUNTR);
}
/* r := &vm->frames[vm->fp] */
void ms_frame(Masm *m, int r) {
    as_ld64(&m->a, r, VMR, OFF(fp));
    as_mul_ri(&m->a, r, r, (int32_t)sizeof(Frame));
    as_add_rm(&m->a, r, VMR, OFF(frames));
}
void ms_reload(Masm *m) {
    m->nfields = UINT32_MAX;
    as_ld64(&m->a, STACKR, VMR, OFF(stack));
    ms_frame(m, R_S1);
    as_ld64(&m->a, BASEI, R_S1, (int32_t)offsetof(Frame, base));
    as_mov_rr(&m->a, BASER, BASEI);
    as_shl_ri(&m->a, BASER, 4);
    as_add_rr(&m->a, BASER, STACKR);
    /* the homes live at the instruction's entry (the call clobbered them)
       and at its end (the helper may have written the slot of the one it
       defines) */
    if (m->homes)
        for (uint32_t r = 0; r < m->nlocals; r++)
            if (m->homes[r].kind != HOME_SLOT && (live_at(m, m->cur_pc, r) || live_at(m, m->sync_pc, r)))
                slot_to_home(m, (int32_t)r, &m->homes[r]);
}
void ms_call_lean(Masm *m, MsHelper helper) {
    ms_call(m, helper);
    ms_reload_homes(m, m->cur_pc);
}
void ms_call(Masm *m, MsHelper helper) {
    uint64_t at;   /* a function pointer's bits, through memcpy: ISO C has no cast for them */
    memcpy(&at, &helper, sizeof at);
    as_mov_rr(&m->a, ms_arg(m, 0), VMR);
    as_call_c(&m->a, m->win, at);
}
/* lea, not add: the flags of a comparison just made live through it to
   the branch after (emit.c, a fused compare and branch, M7) */
void ms_count(Masm *m, uint32_t k) { if (k) as_lea(&m->a, COUNTR, COUNTR, -1, 1, (int32_t)k); }
void ms_exit(Masm *m, uint32_t pc, uint32_t remaining) {
    ms_writeback(m, pc);
    as_st32i(&m->a, VMR, OFF(pc), (int32_t)pc);
    as_lea(&m->a, R_S0, BASEI, -1, 1, (int32_t)m->nlocals);
    as_st64(&m->a, VMR, OFF(sp), R_S0);
    as_lea(&m->a, R_S0, COUNTR, -1, 1, -(int32_t)remaining);
    as_st64(&m->a, VMR, OFF(instructions), R_S0);
    ms_handback(m, RUN_INTERP);
}
void ms_handback(Masm *m, int code) {
    as_mov_ri(&m->a, R_S0, code);
    ms_handback_rax(m);
}
void ms_handback_rax(Masm *m) {
    as_mov_ri(&m->a, R_S6, (int64_t)(intptr_t)m->leave);
    as_jmp_r(&m->a, R_S6);
}

/* ---- the heap ---- */
void ms_alloc(Masm *m, int kind, int contag, uint32_t n, AsmLabel *slow) {
    uint32_t size = (uint32_t)sizeof(Obj) + 16 * (n ? n : 1);
    as_cmp_mi(&m->a, VMR, OFF(gc_stress), 0);
    as_jcc(&m->a, CC_NE, slow);
    as_ld64(&m->a, R_S0, VMR, OFF(heap_used));
    as_lea(&m->a, R_S1, R_S0, -1, 1, (int32_t)size);
    as_cmp_rm(&m->a, R_S1, VMR, OFF(heap_size));
    as_jcc(&m->a, CC_A, slow);
    as_st64(&m->a, VMR, OFF(heap_used), R_S1);
    as_add_mi(&m->a, VMR, OFF(bytes_allocated), (int32_t)size);
    as_add_mi(&m->a, VMR, OFF(objects_allocated), 1);
    as_add_rm(&m->a, R_S0, VMR, OFF(heap_from));
    /* the header: kind, pad 0, contag; then len */
    as_st32i(&m->a, R_S0, 0, (int32_t)((uint32_t)kind | ((uint32_t)contag << 16)));
    as_st32i(&m->a, R_S0, 4, (int32_t)n);
    m->nfields = n;
}
void ms_store_field(Masm *m, int obj, uint32_t i, int32_t s) {
    if (i >= m->nfields) bug("a field the object does not have", i, m->nfields);
    ms_store_value(m, obj, (int32_t)(sizeof(Obj) + 16 * i), s);
}

/* ---- slow paths ---- */
Slow *ms_slow(Masm *m, int kind, uint32_t pc) {
    if (m->nslow == m->slow_cap) {
        int cap = m->slow_cap ? m->slow_cap * 2 : 8;
        Slow *s = realloc(m->slow, (size_t)cap * sizeof *s);
        if (!s) { m->a.failed = 1; return NULL; }
        m->slow = s;
        m->slow_cap = cap;
    }
    Slow *s = &m->slow[m->nslow++];
    memset(s, 0, sizeof *s);
    as_label_init(&s->here);
    as_label_init(&s->back);
    s->kind = kind;
    s->pc = pc;
    s->cur = m->cur_pc;
    return s;
}
void ms_emit_slow_paths(Masm *m, void (*emit)(Masm *m, Slow *s)) {
    for (int i = 0; i < m->nslow; i++) {
        as_bind(&m->a, &m->slow[i].here);
        emit(m, &m->slow[i]);
    }
}

/* ---- the stubs ---- */
/* the stubs: what C keeps saved and restored by the target (asm.h), the
   VM's registers loaded between */
void ms_emit_enter(Asm *a, int win) {
    Masm m;
    memset(&m, 0, sizeof m);
    m.a = *a; m.win = win; m.nfields = UINT32_MAX;
    as_stub_enter(&m.a, win);   /* the VM into VMR, where to go into R_GO */
    ms_reload(&m);
    as_ld64(&m.a, COUNTR, VMR, OFF(instructions));
    as_jmp_r(&m.a, R_GO);
    *a = m.a;
}
void ms_emit_leave(Asm *a, int win) {
    as_stub_leave(a, win);
}
