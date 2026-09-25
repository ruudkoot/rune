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
void ms_copy(Masm *m, int32_t d, int32_t s) {
    if (d == s) return;
    x64_movups_xm(&m->a, XMM0, BASER, SLOT(s));
    x64_movups_mx(&m->a, BASER, SLOT(d), XMM0);
}
void ms_set(Masm *m, int32_t d, int tag, int64_t payload) {
    x64_mov_mi(&m->a, BASER, SLOT(d), tag);
    if (payload >= INT32_MIN && payload <= INT32_MAX) x64_mov_mi(&m->a, BASER, PAYLOAD(d), (int32_t)payload);
    else { x64_mov_ri(&m->a, RAX, payload); x64_mov_mr(&m->a, BASER, PAYLOAD(d), RAX); }
}
void ms_set_reg(Masm *m, int32_t d, int tag, int r) {
    x64_mov_mi(&m->a, BASER, SLOT(d), tag);
    x64_mov_mr(&m->a, BASER, PAYLOAD(d), r);
}
void ms_load_tag(Masm *m, int r, int32_t s) { x64_movzx8_rm(&m->a, r, BASER, SLOT(s)); }
void ms_load_payload(Masm *m, int r, int32_t s) { x64_mov_rm(&m->a, r, BASER, PAYLOAD(s)); }
void ms_load_value(Masm *m, int32_t d, int base, int32_t disp) {
    x64_movups_xm(&m->a, XMM0, base, disp);
    x64_movups_mx(&m->a, BASER, SLOT(d), XMM0);
}
void ms_store_value(Masm *m, int base, int32_t disp, int32_t s) {
    x64_movups_xm(&m->a, XMM0, BASER, SLOT(s));
    x64_movups_mx(&m->a, base, disp, XMM0);
}
void ms_check_tag(Masm *m, int32_t s, int tag, X64Label *unless) {
    x64_cmp8_mi(&m->a, BASER, SLOT(s), tag);
    x64_jcc(&m->a, CC_NE, unless);
}
void ms_load_obj(Masm *m, int r, int32_t s, int kind, X64Label *unless) {
    m->nfields = UINT32_MAX;   /* an object of the program's, whose length the code tests */
    ms_check_tag(m, s, T_PTR, unless);
    x64_mov_rm(&m->a, r, BASER, PAYLOAD(s));
    x64_cmp8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), kind);
    x64_jcc(&m->a, CC_NE, unless);
}
/* a nullary constructor's tag is its payload; one with an argument's is in
   the object's header */
void ms_load_tag_of_con(Masm *m, int r, int32_t s, X64Label *unless) {
    X64Label ptr, done;
    x64_label_init(&ptr); x64_label_init(&done);
    x64_cmp8_mi(&m->a, BASER, SLOT(s), T_CON0);
    x64_jcc(&m->a, CC_NE, &ptr);
    x64_mov_rm(&m->a, r, BASER, PAYLOAD(s));
    x64_jmp(&m->a, &done);
    x64_bind(&m->a, &ptr);
    x64_cmp8_mi(&m->a, BASER, SLOT(s), T_PTR);
    x64_jcc(&m->a, CC_NE, unless);
    x64_mov_rm(&m->a, r, BASER, PAYLOAD(s));
    x64_cmp8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), K_CON);
    x64_jcc(&m->a, CC_NE, unless);
    x64_movzx16_rm(&m->a, r, r, (int32_t)offsetof(Obj, contag));
    x64_bind(&m->a, &done);
    x64_label_free(&ptr); x64_label_free(&done);
}

/* ---- the VM ---- */
void ms_sync(Masm *m, uint32_t pc, int pushed) {
    x64_mov32_mi(&m->a, VMR, OFF(pc), (int32_t)pc);
    x64_lea(&m->a, RAX, BASEI, -1, 1, (int32_t)(m->nlocals + (uint32_t)pushed));
    x64_mov_mr(&m->a, VMR, OFF(sp), RAX);
    x64_mov_mr(&m->a, VMR, OFF(instructions), COUNTR);
}
/* r := &vm->frames[vm->fp] */
void ms_frame(Masm *m, int r) {
    x64_mov_rm(&m->a, r, VMR, OFF(fp));
    x64_shl_ri(&m->a, r, 5);                    /* sizeof(Frame) is 32 */
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
void ms_count(Masm *m, uint32_t k) { if (k) x64_add_ri(&m->a, COUNTR, (int32_t)k); }
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
    return s;
}
void ms_emit_slow_paths(Masm *m, void (*emit)(Masm *m, Slow *s)) {
    for (int i = 0; i < m->nslow; i++) {
        x64_bind(&m->a, &m->slow[i].here);
        emit(m, &m->slow[i]);
    }
}

/* ---- the stubs ---- */
void ms_emit_enter(X64 *a, int win) {
    Masm m;
    m.a = *a; m.win = win; m.nlocals = m.nslots = 0; m.nfields = UINT32_MAX; m.leave = NULL; m.slow = NULL; m.nslow = m.slow_cap = 0;
    x64_push_r(&m.a, RBP); x64_push_r(&m.a, RBX); x64_push_r(&m.a, R12);
    x64_push_r(&m.a, R13); x64_push_r(&m.a, R14); x64_push_r(&m.a, R15);
    if (win) { x64_push_r(&m.a, RDI); x64_push_r(&m.a, RSI); }
    x64_sub_ri(&m.a, RSP, 8);
    x64_mov_rr(&m.a, R11, win ? RDX : RSI);     /* where to go */
    x64_mov_rr(&m.a, VMR, win ? RCX : RDI);
    ms_reload(&m);
    x64_mov_rm(&m.a, COUNTR, VMR, OFF(instructions));
    x64_jmp_r(&m.a, R11);
    *a = m.a;
}
void ms_emit_leave(X64 *a, int win) {
    x64_add_ri(a, RSP, 8);
    if (win) { x64_pop_r(a, RSI); x64_pop_r(a, RDI); }
    x64_pop_r(a, R15); x64_pop_r(a, R14); x64_pop_r(a, R13);
    x64_pop_r(a, R12); x64_pop_r(a, RBX); x64_pop_r(a, RBP);
    x64_ret(a);
}
