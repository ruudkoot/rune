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
    x64_init(&m->a);
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
    for (int i = 0; i < m->nslow; i++) { x64_label_free(&m->slow[i].here); x64_label_free(&m->slow[i].back); }
    free(m->slow);
    x64_free(&m->a);
}

int ms_arg(const Masm *m, int i) {
    static const int sysv[4] = { RDI, RSI, RDX, RCX };
    static const int win[4] = { RCX, RDX, R8, R9 };
    return m->win ? win[i] : sysv[i];
}

/* ---- values ---- */

/* a home's value, as a Value, into its slot (tier 2) */
static void home_to_slot(Masm *m, int32_t s, const Home *h) {
    x64_mov_mi(&m->a, BASER, SLOT(s), h->tag);
    if (h->kind == HOME_GPR) x64_mov_mr(&m->a, BASER, PAYLOAD(s), h->reg);
    else x64_movsd_mx(&m->a, BASER, PAYLOAD(s), h->reg);
}
/* a home loaded from its slot */
static void slot_to_home(Masm *m, int32_t s, const Home *h) {
    if (h->kind == HOME_GPR) x64_mov_rm(&m->a, h->reg, BASER, PAYLOAD(s));
    else x64_movsd_xm(&m->a, h->reg, BASER, PAYLOAD(s));
}
/* a Value at [base + disp] written from a home, or loaded into one */
static void home_to_mem(Masm *m, int base, int32_t disp, const Home *h) {
    x64_mov_mi(&m->a, base, disp, h->tag);
    if (h->kind == HOME_GPR) x64_mov_mr(&m->a, base, disp + 8, h->reg);
    else x64_movsd_mx(&m->a, base, disp + 8, h->reg);
}
static void mem_to_home(Masm *m, const Home *h, int base, int32_t disp) {
    if (h->kind == HOME_GPR) x64_mov_rm(&m->a, h->reg, base, disp + 8);
    else x64_movsd_xm(&m->a, h->reg, base, disp + 8);
}

void ms_copy(Masm *m, int32_t d, int32_t s) {
    const Home *hd = ms_home(m, d), *hs = ms_home(m, s);
    if (d == s) return;
    if (hd && hs) {
        if (hd->kind == HOME_GPR && hs->kind == HOME_GPR) x64_mov_rr(&m->a, hd->reg, hs->reg);
        else if (hd->kind == HOME_XMM && hs->kind == HOME_XMM) x64_movaps_xx(&m->a, hd->reg, hs->reg);
        else if (hd->kind == HOME_GPR) x64_movq_rx(&m->a, hd->reg, hs->reg);
        else x64_movq_xr(&m->a, hd->reg, hs->reg);
    } else if (hd) slot_to_home(m, s, hd);
    else if (hs) home_to_slot(m, d, hs);
    else {
        x64_movups_xm(&m->a, XMM0, BASER, SLOT(s));
        x64_movups_mx(&m->a, BASER, SLOT(d), XMM0);
    }
}
void ms_set(Masm *m, int32_t d, int tag, int64_t payload) {
    const Home *h = ms_home(m, d);
    if (h) {
        if (h->kind == HOME_GPR) x64_mov_ri(&m->a, h->reg, payload);
        else { x64_mov_ri(&m->a, RAX, payload); x64_movq_xr(&m->a, h->reg, RAX); }
        return;
    }
    x64_mov_mi(&m->a, BASER, SLOT(d), tag);
    if (payload >= INT32_MIN && payload <= INT32_MAX) x64_mov_mi(&m->a, BASER, PAYLOAD(d), (int32_t)payload);
    else { x64_mov_ri(&m->a, RAX, payload); x64_mov_mr(&m->a, BASER, PAYLOAD(d), RAX); }
}
void ms_set_reg(Masm *m, int32_t d, int tag, int r) {
    const Home *h = ms_home(m, d);
    if (h) {
        if (h->kind == HOME_GPR) x64_mov_rr(&m->a, h->reg, r);
        else x64_movq_xr(&m->a, h->reg, r);
        return;
    }
    x64_mov_mi(&m->a, BASER, SLOT(d), tag);
    x64_mov_mr(&m->a, BASER, PAYLOAD(d), r);
}
void ms_load_tag(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) x64_mov_ri(&m->a, r, h->tag);
    else x64_movzx8_rm(&m->a, r, BASER, SLOT(s));
}
void ms_load_payload(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) { if (h->kind == HOME_GPR) x64_mov_rr(&m->a, r, h->reg); else x64_movq_rx(&m->a, r, h->reg); }
    else x64_mov_rm(&m->a, r, BASER, PAYLOAD(s));
}
void ms_load_value(Masm *m, int32_t d, int base, int32_t disp) {
    const Home *h = ms_home(m, d);
    if (h) { mem_to_home(m, h, base, disp); return; }
    x64_movups_xm(&m->a, XMM0, base, disp);
    x64_movups_mx(&m->a, BASER, SLOT(d), XMM0);
}
void ms_store_value(Masm *m, int base, int32_t disp, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) { home_to_mem(m, base, disp, h); return; }
    x64_movups_xm(&m->a, XMM0, BASER, SLOT(s));
    x64_movups_mx(&m->a, base, disp, XMM0);
}
void ms_value_to(Masm *m, int base, int32_t disp, int32_t s) { ms_store_value(m, base, disp, s); }
void ms_value_from(Masm *m, int32_t d, int base, int32_t disp) { ms_load_value(m, d, base, disp); }
void ms_load_real(Masm *m, int xmm, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) x64_movaps_xx(&m->a, xmm, h->reg);   /* a real's home is an xmm */
    else x64_movsd_xm(&m->a, xmm, BASER, PAYLOAD(s));
}
void ms_set_real(Masm *m, int32_t d, int xmm) {
    const Home *h = ms_home(m, d);
    if (h) { x64_movaps_xx(&m->a, h->reg, xmm); return; }
    x64_mov_mi(&m->a, BASER, SLOT(d), T_REAL);
    x64_movsd_mx(&m->a, BASER, PAYLOAD(d), xmm);
}
void ms_cmp_payload(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h && h->kind == HOME_GPR) x64_cmp_rr(&m->a, r, h->reg);
    else if (h) { x64_movq_rx(&m->a, RDX, h->reg); x64_cmp_rr(&m->a, r, RDX); }
    else x64_cmp_rm(&m->a, r, BASER, PAYLOAD(s));
}
void ms_test_false(Masm *m, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) x64_test_rr(&m->a, h->reg, h->reg);   /* a bool's home is a general register */
    else x64_cmp_mi(&m->a, BASER, PAYLOAD(s), 0);
}
void ms_load_xmm(Masm *m, int xmm, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h) home_to_slot(m, s, h);   /* the slot made whole first */
    x64_movups_xm(&m->a, xmm, BASER, SLOT(s));
}
void ms_check_tag(Masm *m, int32_t s, int tag, X64Label *unless) {
    const Home *h = ms_home(m, s);
    if (h) {
        if (h->tag != tag) x64_jmp(&m->a, unless);   /* never the tag: always the other way */
        return;
    }
    x64_cmp8_mi(&m->a, BASER, SLOT(s), tag);
    x64_jcc(&m->a, CC_NE, unless);
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
void ms_load_obj(Masm *m, int r, int32_t s, int kind, X64Label *unless) {
    m->nfields = UINT32_MAX;   /* an object of the program's, whose length the code tests */
    if (ms_trusts(m, s, kind)) { x64_mov_rm(&m->a, r, BASER, PAYLOAD(s)); return; }   /* tier 2: the section says so (M10) */
    ms_check_tag(m, s, T_PTR, unless);
    x64_mov_rm(&m->a, r, BASER, PAYLOAD(s));
    x64_cmp8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), kind);
    x64_jcc(&m->a, CC_NE, unless);
}
/* a nullary constructor's tag is its payload; one with an argument's is in
   the object's header */
void ms_load_tag_of_con(Masm *m, int r, int32_t s, X64Label *unless) {
    const Home *h = ms_home(m, s);
    if (h) { x64_mov_rr(&m->a, r, h->reg); return; }   /* a nullary constructor: its tag is its payload */
    X64Label ptr, done;
    x64_label_init(&ptr); x64_label_init(&done);
    x64_cmp8_mi(&m->a, BASER, SLOT(s), T_CON0);
    x64_jcc(&m->a, CC_NE, &ptr);
    x64_mov_rm(&m->a, r, BASER, PAYLOAD(s));
    x64_jmp(&m->a, &done);
    x64_bind(&m->a, &ptr);
    /* not nullary: a pointer to a constructor, which the section
       vouches for at tier 2 (M10); else tested */
    int trusted = m->reps && (uint32_t)s < m->nlocals && m->reps[s] == REP_CON;
    if (!trusted) { x64_cmp8_mi(&m->a, BASER, SLOT(s), T_PTR); x64_jcc(&m->a, CC_NE, unless); }
    x64_mov_rm(&m->a, r, BASER, PAYLOAD(s));
    if (!trusted) { x64_cmp8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), K_CON); x64_jcc(&m->a, CC_NE, unless); }
    x64_movzx16_rm(&m->a, r, r, (int32_t)offsetof(Obj, contag));
    x64_bind(&m->a, &done);
    x64_label_free(&ptr); x64_label_free(&done);
}

/* ---- the VM ---- */
void ms_sync(Masm *m, uint32_t pc, int pushed) {
    ms_writeback(m, m->cur_pc);
    m->sync_pc = pc;
    x64_mov32_mi(&m->a, VMR, OFF(pc), (int32_t)pc);
    x64_lea(&m->a, RAX, BASEI, -1, 1, (int32_t)(m->nlocals + (uint32_t)pushed));
    x64_mov_mr(&m->a, VMR, OFF(sp), RAX);
    x64_mov_mr(&m->a, VMR, OFF(instructions), COUNTR);
}
/* r := &vm->frames[vm->fp] */
void ms_frame(Masm *m, int r) {
    x64_mov_rm(&m->a, r, VMR, OFF(fp));
    x64_imul_rri(&m->a, r, r, (int32_t)sizeof(Frame));
    x64_add_rm(&m->a, r, VMR, OFF(frames));
}
void ms_reload(Masm *m) {
    m->nfields = UINT32_MAX;
    x64_mov_rm(&m->a, STACKR, VMR, OFF(stack));
    ms_frame(m, RCX);
    x64_mov_rm(&m->a, BASEI, RCX, (int32_t)offsetof(Frame, base));
    x64_mov_rr(&m->a, BASER, BASEI);
    x64_shl_ri(&m->a, BASER, 4);
    x64_add_rr(&m->a, BASER, STACKR);
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
    x64_mov_rr(&m->a, ms_arg(m, 0), VMR);
    x64_mov_ri(&m->a, RAX, (int64_t)at);
    if (m->win) x64_sub_ri(&m->a, RSP, 32);
    x64_call_r(&m->a, RAX);
    if (m->win) x64_add_ri(&m->a, RSP, 32);
}
/* lea, not add: the flags of a comparison just made live through it to
   the branch after (emit.c, a fused compare and branch, M7) */
void ms_count(Masm *m, uint32_t k) { if (k) x64_lea(&m->a, COUNTR, COUNTR, -1, 1, (int32_t)k); }
void ms_exit(Masm *m, uint32_t pc, uint32_t remaining) {
    ms_writeback(m, pc);
    x64_mov32_mi(&m->a, VMR, OFF(pc), (int32_t)pc);
    x64_lea(&m->a, RAX, BASEI, -1, 1, (int32_t)m->nlocals);
    x64_mov_mr(&m->a, VMR, OFF(sp), RAX);
    x64_lea(&m->a, RAX, COUNTR, -1, 1, -(int32_t)remaining);
    x64_mov_mr(&m->a, VMR, OFF(instructions), RAX);
    ms_handback(m, RUN_INTERP);
}
void ms_handback(Masm *m, int code) {
    x64_mov_ri(&m->a, RAX, code);
    ms_handback_rax(m);
}
void ms_handback_rax(Masm *m) {
    x64_mov_ri(&m->a, R11, (int64_t)(intptr_t)m->leave);
    x64_jmp_r(&m->a, R11);
}

/* ---- the heap ---- */
void ms_alloc(Masm *m, int kind, int contag, uint32_t n, X64Label *slow) {
    uint32_t size = (uint32_t)sizeof(Obj) + 16 * (n ? n : 1);
    x64_cmp_mi(&m->a, VMR, OFF(gc_stress), 0);
    x64_jcc(&m->a, CC_NE, slow);
    x64_mov_rm(&m->a, RAX, VMR, OFF(heap_used));
    x64_lea(&m->a, RCX, RAX, -1, 1, (int32_t)size);
    x64_cmp_rm(&m->a, RCX, VMR, OFF(heap_size));
    x64_jcc(&m->a, CC_A, slow);
    x64_mov_mr(&m->a, VMR, OFF(heap_used), RCX);
    x64_add_mi(&m->a, VMR, OFF(bytes_allocated), (int32_t)size);
    x64_add_mi(&m->a, VMR, OFF(objects_allocated), 1);
    x64_add_rm(&m->a, RAX, VMR, OFF(heap_from));
    /* the header: kind, pad 0, contag; then len */
    x64_mov32_mi(&m->a, RAX, 0, (int32_t)((uint32_t)kind | ((uint32_t)contag << 16)));
    x64_mov32_mi(&m->a, RAX, 4, (int32_t)n);
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
    x64_label_init(&s->here);
    x64_label_init(&s->back);
    s->kind = kind;
    s->pc = pc;
    s->cur = m->cur_pc;
    return s;
}
void ms_emit_slow_paths(Masm *m, void (*emit)(Masm *m, Slow *s)) {
    for (int i = 0; i < m->nslow; i++) {
        x64_bind(&m->a, &m->slow[i].here);
        emit(m, &m->slow[i]);
    }
}

/* ---- the stubs ---- */
/* what the Windows convention has C keep and tier 2's homes use: xmm6 to
   xmm15, saved by the enter stub below its pushes (160 bytes) */
#define WIN_XMM_SAVE 160
void ms_emit_enter(X64 *a, int win) {
    Masm m;
    memset(&m, 0, sizeof m);
    m.a = *a; m.win = win; m.nfields = UINT32_MAX;
    x64_push_r(&m.a, RBP); x64_push_r(&m.a, RBX); x64_push_r(&m.a, R12);
    x64_push_r(&m.a, R13); x64_push_r(&m.a, R14); x64_push_r(&m.a, R15);
    if (win) {
        x64_push_r(&m.a, RDI); x64_push_r(&m.a, RSI);
        x64_sub_ri(&m.a, RSP, 8 + WIN_XMM_SAVE);
        for (int i = 6; i < 16; i++) x64_movups_mx(&m.a, RSP, 16 * (i - 6), XMM0 + i);
    } else x64_sub_ri(&m.a, RSP, 8);
    x64_mov_rr(&m.a, R11, win ? RDX : RSI);     /* where to go */
    x64_mov_rr(&m.a, VMR, win ? RCX : RDI);
    ms_reload(&m);
    x64_mov_rm(&m.a, COUNTR, VMR, OFF(instructions));
    x64_jmp_r(&m.a, R11);
    *a = m.a;
}
void ms_emit_leave(X64 *a, int win) {
    if (win) {
        for (int i = 6; i < 16; i++) x64_movups_xm(a, XMM0 + i, RSP, 16 * (i - 6));
        x64_add_ri(a, RSP, 8 + WIN_XMM_SAVE);
        x64_pop_r(a, RSI); x64_pop_r(a, RDI);
    } else x64_add_ri(a, RSP, 8);
    x64_pop_r(a, R15); x64_pop_r(a, R14); x64_pop_r(a, R13);
    x64_pop_r(a, R12); x64_pop_r(a, RBX); x64_pop_r(a, RBP);
    x64_ret(a);
}
