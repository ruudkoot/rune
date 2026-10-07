/* The macro-assembler of runtime/register's JIT (masm.h). */
#include "masm.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OFF(field) ((int32_t)offsetof(VM, field))
#define SLOT(k) slot(m, k)

/* The layout as the code here writes it (runtime/value.h has it in C; this
   branch's is the tagged word of docs/plans/heap-layout.md, M5): a Value
   of 8 bytes, whose low bit says an immediate (2n+1: an int, a word, a
   char, a nullary constructor's tag, unit as 1; or a real in its
   encoding) from a pointer, and an object's header of kind, contag and
   len before its fields. A change of layout is a change to value.h and to
   the operations here, and these say so at compile time. */
#define VALUE_SIZE ((int32_t)sizeof(Value))
#define VALUE_SHIFT 3
#define FIELD_OFF(i) ((int32_t)(sizeof(Obj) + sizeof(Value) * (i)))
#define IMM(n) ((int64_t)(((uint64_t)(int64_t)(n) << 1) | 1u))   /* the word of the immediate n */
_Static_assert(sizeof(Value) == 8, "masm.c writes 8-byte values");
_Static_assert((1 << VALUE_SHIFT) == sizeof(Value), "masm.c scales an index by 8");
/* raw homes for ints and words: only where they are 64 bits, and asked for */
#if defined(RUNE_INT64) && defined(RUNE_RAW_HOMES)
#define RUNE_RAW_NUMS 1
#endif

_Static_assert(offsetof(Obj, kind) == 0 && offsetof(Obj, contag) == 2 && offsetof(Obj, len) == 4 && sizeof(Obj) == 8, "masm.c reads the header as kind, contag, len, then the fields");

/* A measuring build (docs/plans/performance-64bit.md, experiments 1 and
   5): every conversion between a raw number and its word that compiled
   code makes is counted as it runs, by the instruction that makes it and
   by whether it is that instruction's own work, a write-back at a
   safepoint or a reload of the homes; runevm --jit-stats prints the
   table. */
#ifdef RUNE_JIT_CONV
uint64_t jit_conv[3][256][13];
enum { CONV_REAL_DEC, CONV_REAL_ENC, CONV_REAL_BOX, CONV_NUM_DEC, CONV_NUM_ENC, CONV_NUM_BOX,
       /* a field read into a register that is not a raw home, by what the
          section says the register holds: a real, any value, something
          else, or nothing said (tier 1) */
       CONV_LOAD_REAL_SLOT, CONV_LOAD_ANY, CONV_LOAD_OTHER, CONV_LOAD_T1,
       /* a field written from a register of reals: one with a home, one without */
       CONV_STORE_REAL_HOME, CONV_STORE_REAL_SLOT,
       /* a field written from a register of 64-bit ints or words */
       CONV_STORE_NUM };
static int conv_rep(const Masm *m, int32_t r) { return m->reps && (uint32_t)r < m->nlocals ? m->reps[r] : -1; }
uint64_t jit_conv_prim[PRIM__COUNT][2];   /* a primitive's own decodes and encodes of reals */
static void conv_at(Masm *m, int what, uint32_t pc) {
    int op = m->conv_code ? m->conv_code[pc] : 0;
    as_count(&m->a, &jit_conv[m->conv_ctx][op][what]);
    if (op == m->conv_prim_op && m->conv_ctx == 0 && what <= CONV_REAL_ENC) {
        int32_t prim = read_i32(m->conv_code + pc + 1);
        if (prim >= 0 && prim < PRIM__COUNT) as_count(&m->a, &jit_conv_prim[prim][what]);
    }
}
#define CONV(m, what) conv_at((m), (what), (m)->cur_pc)
#else
#define CONV(m, what) ((void)0)
#endif

/* The object at r is of the kind, else to unless. The header's first byte
   is the kind and the collector's four bits (value.h), which are zero while
   no collector sets one, so the byte is compared whole: one instruction.
   Under RUNE_GC_BITS, the VM whose collector sets them, the kind's four
   bits are tested alone and nothing else is touched: the bits the kind has
   not must be clear, and each it has set. (A collector that used the bits
   would load the byte and mask it, three instructions with a register this
   does not ask for; what is here is the test that every reader is ready,
   not that sequence's price.) */
static void kind_is(Masm *m, int r, int kind, AsmLabel *unless) {
#ifdef RUNE_GC_BITS
    as_test8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), OBJ_KIND_MASK & ~kind);
    as_jcc(&m->a, CC_NE, unless);
    for (int bit = 1; bit <= OBJ_KIND_MASK; bit <<= 1)
        if (kind & bit) {
            as_test8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), bit);
            as_jcc(&m->a, CC_E, unless);
        }
#else
    as_cmp8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), kind);
    as_jcc(&m->a, CC_NE, unless);
#endif
}

/* an emitter's mistake (masm.h) */
static void bug(const char *what, long long k, long long of) {
    fprintf(stderr, "runevm: jit: internal error: %s: %lld of %lld\n", what, k, of);
    abort();
}
/* where register k of the frame is, from r14 */
static int32_t slot(const Masm *m, int32_t k) {
    if (k < 0 || (uint32_t)k >= m->nslots) bug("a register the frame does not have", k, m->nslots);
    return VALUE_SIZE * k;
}

/* every field nothing, but those given: the record of a caller that sets
   no more (tests/register/masm_test.c) makes code that knows nothing of
   the region (placed 0, no trampolines), homes or representations */
void ms_init(Masm *m, uint32_t nlocals, uint32_t maxstack, int win, const void *leave) {
    memset(m, 0, sizeof *m);
    as_init(&m->a);
    m->win = win;
    m->nlocals = nlocals;
    m->nslots = nlocals + maxstack;
    m->nfields = UINT32_MAX;
    m->leave = leave;
}
void ms_free(Masm *m) {
    for (int i = 0; i < m->nslow; i++) { as_label_free(&m->slow[i]->here); as_label_free(&m->slow[i]->back); free(m->slow[i]); }
    free(m->slow);
    as_free(&m->a);
}

int ms_arg(const Masm *m, int i) { return as_arg(m->win, i); }

/* ---- values ---- */

static int is_xmm(const Home *h) { return h && h->kind == HOME_XMM; }
/* A home that holds its value raw, not as its word: a real's double, and
   the 64 bits of an Int64.int or a Word64.word -- a number past 63 has no
   word but a box's address, and arithmetic on the bits themselves needs no
   test for one. A raw home's slot may be behind (cur_reals says which are
   not). With RUNE_RAW_HOMES where the VM keeps ints and words of 64 bits
   (RUNE_INT64), an int's and a word's homes are raw too: a switch, because
   it cuts both ways there (docs/plans/heap-layout.md, M4): code whose
   words pass 63 bits runs in a quarter of the instructions, and code whose
   ints are small pays a decoding and an encoding wherever a value crosses
   a slot, which a call does. */
static int word_tag(int tag) { return tag == T_WORD || tag == T_WORD64; }
static int is_raw_gpr(const Home *h) {
    if (!h || h->kind != HOME_GPR) return 0;
    if (h->tag == T_INT64 || h->tag == T_WORD64) return 1;
#ifdef RUNE_RAW_NUMS
    return h->tag == T_INT || h->tag == T_WORD;
#else
    return 0;
#endif
}
static int is_raw(const Home *h) { return is_xmm(h) || is_raw_gpr(h); }
const Home *ms_word_home(const Masm *m, int32_t s) {
    const Home *h = ms_home(m, s);
    return h && !is_raw(h) ? h : NULL;
}
static int real_current(const Masm *m, int32_t s) { return s >= 0 && s < 64 && ((m->cur_reals >> s) & 1); }
static void real_behind(Masm *m, int32_t s) { if (s >= 0 && s < 64) m->cur_reals &= ~((uint64_t)1 << s); }
static void real_made(Masm *m, int32_t s) { if (s >= 0 && s < 64) m->cur_reals |= (uint64_t)1 << s; }
/* the word of a real in its home is wanted where its slot is behind: an
   emitter that did not say ms_need_word at the instruction's start */
static void want_current(const Masm *m, int32_t s) {
    if (!real_current(m, s)) bug("the word of a real whose slot is behind (ms_need_word)", s, (long long)m->cur_pc);
}

/* R_S2 := the word of the real in xmm where it has an immediate (value.h,
   real_encode: 2^61 added and the sum rotated left by two, an immediate
   where the low bit is then set); +0.0, which becomes 2^63, has the VM's
   box; else to fail. R_S3 clobbered. */
static void encode_real(Masm *m, int xmm, AsmLabel *fail) {
    CONV(m, CONV_REAL_ENC);
#ifdef RUNE_REAL_BOXED
    (void)xmm;
    as_jmp(&m->a, fail);
#else
    AsmLabel ok; as_label_init(&ok);
    as_fmov_rf(&m->a, R_S2, xmm);
    as_mov_ri(&m->a, R_S3, (int64_t)REAL_ROT_OFF);
    as_add_rr(&m->a, R_S2, R_S3);
    as_ror_ri(&m->a, R_S2, 62);
    as_test_ri(&m->a, R_S2, 1);
    as_jcc(&m->a, CC_NE, &ok);
    as_shl_ri(&m->a, R_S3, 2);
    as_cmp_rr(&m->a, R_S2, R_S3);
    as_jcc(&m->a, CC_NE, fail);
    as_ld64(&m->a, R_S2, VMR, OFF(real_boxes) + 8 * REAL_BOX_ZERO);
    as_bind(&m->a, &ok);
    as_label_free(&ok);
#endif
}
/* xmm := the real of the word in R_S2: an immediate, decoded (the word
   rotated back and 2^61 taken off), or a box, read. To unless where it is
   neither; with unless NULL the word is trusted to be a real's (tier 2, a
   register the section says is one). R_S3 clobbered. */
static void decode_real(Masm *m, int xmm, AsmLabel *unless) {
    CONV(m, CONV_REAL_DEC);
    AsmLabel box, done; as_label_init(&box); as_label_init(&done);
    as_test_ri(&m->a, R_S2, 1);
    as_jcc(&m->a, CC_E, &box);
#ifdef RUNE_REAL_BOXED
    /* every real is a box; a register trusted to be a real that is an
       immediate is one not yet defined, unit: zero */
    if (unless) as_jmp(&m->a, unless);
    else { as_fzero(&m->a, xmm); as_jmp(&m->a, &done); }
#else
    as_ror_ri(&m->a, R_S2, 2);
    as_mov_ri(&m->a, R_S3, (int64_t)REAL_ROT_OFF);
    as_sub_rr(&m->a, R_S2, R_S3);
    as_fmov_fr(&m->a, xmm, R_S2);
    as_jmp(&m->a, &done);
#endif
    as_bind(&m->a, &box);
    if (unless) {
        as_test_rr(&m->a, R_S2, R_S2);
        as_jcc(&m->a, CC_E, unless);
        kind_is(m, R_S2, K_REAL, unless);
    }
    as_fld(&m->a, xmm, R_S2, (int32_t)sizeof(Obj));
    as_bind(&m->a, &done);
    as_label_free(&box); as_label_free(&done);
}

/* A real's home to its slot: encoded, or boxed by the slow path, which
   may collect (pushed: what is above the frame's registers on the stack,
   for the collector; live: the pc whose live homes the slow path saves).
   Nothing where the slot is up to date. */
static void real_to_slot(Masm *m, int32_t s, const Home *h, int pushed, uint32_t live) {
    if (real_current(m, s)) return;
    Slow *sl = ms_slow(m, SLOW_BOXREAL, m->cur_pc);
    if (!sl) return;
    sl->a = s; sl->b = h->reg; sl->c = pushed; sl->n = live;
    int which = m->nslow - 1;
    encode_real(m, h->reg, &m->slow[which]->here);
    as_st64(&m->a, BASER, SLOT(s), R_S2);
    as_bind(&m->a, &m->slow[which]->back);
    real_made(m, s);
}
/* R_S2 := the word of the 64-bit int or word in r, which is left as it
   was; to fail where it has no immediate (it is past 63 bits) */
static void encode_num(Masm *m, int r, int tag, AsmLabel *fail) {
    CONV(m, CONV_NUM_ENC);
    if (word_tag(tag)) {
        as_test_rr(&m->a, r, r);
        as_jcc(&m->a, CC_S, fail);
        as_lea(&m->a, R_S2, r, r, 1, 1);
    } else {
        as_mov_rr(&m->a, R_S2, r);
        as_add_rr(&m->a, R_S2, R_S2);
        as_jcc(&m->a, CC_O, fail);
        as_lea(&m->a, R_S2, R_S2, -1, 1, 1);
    }
}
/* reg := the 64 bits of the int or word whose word is in R_S2: an
   immediate's payload, or its box's bits. To unless where it is neither;
   with unless NULL the word is trusted (tier 2, a register the section
   says holds an int or a word; unit, a register not yet defined, is 0). */
static void decode_num(Masm *m, int reg, int tag, AsmLabel *unless) {
    CONV(m, CONV_NUM_DEC);
    AsmLabel box, done; as_label_init(&box); as_label_init(&done);
    as_test_ri(&m->a, R_S2, 1);
    as_jcc(&m->a, CC_E, &box);
    if (reg != R_S2) as_mov_rr(&m->a, reg, R_S2);
    if (word_tag(tag)) as_shr_ri(&m->a, reg, 1); else as_sar_ri(&m->a, reg, 1);
    as_jmp(&m->a, &done);
    as_bind(&m->a, &box);
    if (unless) {
        as_test_rr(&m->a, R_S2, R_S2);
        as_jcc(&m->a, CC_E, unless);
        kind_is(m, R_S2, K_BOX, unless);
    }
    as_ld64(&m->a, reg, R_S2, (int32_t)sizeof(Obj));
    as_bind(&m->a, &done);
    as_label_free(&box); as_label_free(&done);
}
/* A raw int's or word's home to its slot: its word, or boxed by the slow
   path where it has none, as a real's (real_to_slot). */
static void num_to_slot(Masm *m, int32_t s, const Home *h, int pushed, uint32_t live) {
    if (real_current(m, s)) return;
    Slow *sl = ms_slow(m, SLOW_BOXNUM, m->cur_pc);
    if (!sl) return;
    sl->a = s; sl->b = h->reg; sl->c = pushed; sl->n = live;
    int which = m->nslow - 1;
    encode_num(m, h->reg, h->tag, &m->slow[which]->here);
    as_st64(&m->a, BASER, SLOT(s), R_S2);
    as_bind(&m->a, &m->slow[which]->back);
    real_made(m, s);
}
/* A home holds its value's word, as the slot does: written back and loaded
   by a plain move -- but a raw one (is_raw), whose slot is brought up to
   date where a word is wanted and read back by decoding it. */
static void home_to_slot(Masm *m, int32_t s, const Home *h) {
    if (is_raw(h)) { want_current(m, s); return; }
    as_st64(&m->a, BASER, SLOT(s), h->reg);
}
static void slot_to_home(Masm *m, int32_t s, const Home *h) {
    if (is_xmm(h)) {
        as_ld64(&m->a, R_S2, BASER, SLOT(s));
        decode_real(m, h->reg, NULL);
        real_made(m, s);   /* the slot is the home's word */
        return;
    }
    if (is_raw_gpr(h)) {
        as_ld64(&m->a, R_S2, BASER, SLOT(s));
        decode_num(m, h->reg, h->tag, NULL);
        real_made(m, s);
        return;
    }
    as_ld64(&m->a, h->reg, BASER, SLOT(s));
}
void ms_begin(Masm *m, uint32_t pc) { m->cur_pc = pc; m->cur_reals = 0; m->cur_def = 0; }
void ms_need_word(Masm *m, int32_t s) {
    const Home *h = ms_home(m, s);
    if (is_xmm(h)) real_to_slot(m, s, h, 0, m->cur_pc);
    else if (is_raw_gpr(h)) num_to_slot(m, s, h, 0, m->cur_pc);
}

void ms_copy(Masm *m, int32_t d, int32_t s) {
    const Home *hd = ms_home(m, d), *hs = ms_home(m, s);
    if (d == s) return;
    if (is_xmm(hd)) {
        if (is_xmm(hs)) as_fmov(&m->a, hd->reg, hs->reg);
        else if (hs) bug("a real's home given what is in a general register", d, s);
        else { as_ld64(&m->a, R_S2, BASER, SLOT(s)); decode_real(m, hd->reg, NULL); }
        real_behind(m, d);
        return;
    }
    if (is_xmm(hs)) {
        if (hd) bug("a general register given a real's home", d, s);
        want_current(m, s);   /* its slot has its word */
        as_fld(&m->a, F_S0, BASER, SLOT(s));
        as_fst(&m->a, BASER, SLOT(d), F_S0);
        return;
    }
    if (is_raw_gpr(hd)) {   /* a number's 64 bits */
        if (is_raw_gpr(hs)) as_mov_rr(&m->a, hd->reg, hs->reg);
        else if (hs) { as_mov_rr(&m->a, hd->reg, hs->reg); as_sar_ri(&m->a, hd->reg, 1); }   /* a char's or a tag's word */
        else { as_ld64(&m->a, R_S2, BASER, SLOT(s)); decode_num(m, hd->reg, hd->tag, NULL); }
        real_behind(m, d);
        return;
    }
    if (is_raw_gpr(hs)) {
        if (hd) bug("a home of words given an int's 64 bits", d, s);
        want_current(m, s);
        as_fld(&m->a, F_S0, BASER, SLOT(s));
        as_fst(&m->a, BASER, SLOT(d), F_S0);
        return;
    }
    if (hd && hs) as_mov_rr(&m->a, hd->reg, hs->reg);
    else if (hd) slot_to_home(m, s, hd);
    else if (hs) home_to_slot(m, d, hs);
    else {
        as_fld(&m->a, F_S0, BASER, SLOT(s));   /* eight bytes through xmm0: no general register is needed */
        as_fst(&m->a, BASER, SLOT(d), F_S0);
    }
}
void ms_move(Masm *m, int32_t d, int32_t s) {
    if (d != s && !is_raw(ms_home(m, d))) ms_need_word(m, s);
    ms_copy(m, d, s);
}
/* the word of the value of tag and payload */
static int64_t word_of(int tag, int64_t payload) { return tag == T_PTR ? payload : IMM(payload); }
void ms_set(Masm *m, int32_t d, int tag, int64_t payload) {
    const Home *h = ms_home(m, d);
    int64_t w = word_of(tag, payload);
    if (is_xmm(h)) bug("a real's home set to an immediate that is none", d, tag);
    if (is_raw_gpr(h)) { as_mov_ri(&m->a, h->reg, payload); real_behind(m, d); return; }
    if (h) { as_mov_ri(&m->a, h->reg, w); return; }
    if (w >= INT32_MIN && w <= INT32_MAX) as_st64i(&m->a, BASER, SLOT(d), (int32_t)w);
    else { as_mov_ri(&m->a, R_S0, w); as_st64(&m->a, BASER, SLOT(d), R_S0); }
}
void ms_set_bits(Masm *m, int32_t d, int r) {
    const Home *h = ms_home(m, d);
    if (is_xmm(h)) {   /* a real's word: into the home as the double */
        if (r != R_S2) as_mov_rr(&m->a, R_S2, r);
        decode_real(m, h->reg, NULL);
        real_behind(m, d);
        return;
    }
    if (is_raw_gpr(h)) {   /* an int's or a word's word: into the home as its 64 bits */
        if (r != R_S2) as_mov_rr(&m->a, R_S2, r);
        decode_num(m, h->reg, h->tag, NULL);
        real_behind(m, d);
        return;
    }
    if (h) as_mov_rr(&m->a, h->reg, r);
    else as_st64(&m->a, BASER, SLOT(d), r);
}
void ms_set_reg(Masm *m, int32_t d, int tag, int r) {
    const Home *h = ms_home(m, d);
    if (is_raw_gpr(h)) { as_mov_rr(&m->a, h->reg, r); real_behind(m, d); return; }   /* the payload is the home's */
    if (tag != T_PTR) as_lea(&m->a, r, r, r, 1, 1);   /* 2n+1; the flags are left as they were */
    ms_set_bits(m, d, r);
}
void ms_load_bits(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (is_raw(h)) { want_current(m, s); as_ld64(&m->a, r, BASER, SLOT(s)); return; }
    if (h) as_mov_rr(&m->a, r, h->reg);
    else as_ld64(&m->a, r, BASER, SLOT(s));
}
void ms_load_payload(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (is_raw_gpr(h)) { as_mov_rr(&m->a, r, h->reg); return; }
    ms_load_bits(m, r, s);
    as_sar_ri(&m->a, r, 1);
}
void ms_load_value(Masm *m, int32_t d, int base, int32_t disp) {
    const Home *h = ms_home(m, d);
    if (is_xmm(h)) {
        as_ld64(&m->a, R_S2, base, disp);
        decode_real(m, h->reg, NULL);
        real_behind(m, d);
        return;
    }
    if (is_raw_gpr(h)) {
        as_ld64(&m->a, R_S2, base, disp);
        decode_num(m, h->reg, h->tag, NULL);
        real_behind(m, d);
        return;
    }
#ifdef RUNE_JIT_CONV
    { int r = conv_rep(m, d); CONV(m, r < 0 ? CONV_LOAD_T1 : r == REP_REAL ? CONV_LOAD_REAL_SLOT : r == REP_ANY ? CONV_LOAD_ANY : CONV_LOAD_OTHER); }
#endif
    if (h) { as_ld64(&m->a, h->reg, base, disp); return; }
    as_fld(&m->a, F_S0, base, disp);
    as_fst(&m->a, BASER, SLOT(d), F_S0);
}
void ms_store_value(Masm *m, int base, int32_t disp, int32_t s) {
    const Home *h = ms_home(m, s);
#ifdef RUNE_JIT_CONV
    if (is_xmm(h)) CONV(m, CONV_STORE_REAL_HOME);
    else if (conv_rep(m, s) == REP_REAL) CONV(m, CONV_STORE_REAL_SLOT);
    else if (conv_rep(m, s) == REP_INT64 || conv_rep(m, s) == REP_WORD64) CONV(m, CONV_STORE_NUM);
#endif
    if (h && !is_raw(h)) { as_st64(&m->a, base, disp, h->reg); return; }
    if (h) want_current(m, s);   /* a raw home: its slot has its word */
    as_fld(&m->a, F_S0, BASER, SLOT(s));
    as_fst(&m->a, base, disp, F_S0);
}
void ms_value_to(Masm *m, int base, int32_t disp, int32_t s) { ms_store_value(m, base, disp, s); }
void ms_value_from(Masm *m, int32_t d, int base, int32_t disp) { ms_load_value(m, d, base, disp); }
void ms_cmp_bits(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (is_raw(h)) want_current(m, s);
    if (h && !is_raw(h)) as_cmp_rr(&m->a, r, h->reg);
    else as_cmp_rm(&m->a, r, BASER, SLOT(s));
}
void ms_test_false(Masm *m, int32_t s) {
    const Home *h = ms_home(m, s);
    if (is_raw(h)) bug("a real or a number tested as a bool", s, 0);
    if (h) as_cmp_ri(&m->a, h->reg, (int32_t)IMM(0));
    else as_cmp_mi(&m->a, BASER, SLOT(s), (int32_t)IMM(0));
}
void ms_bool_flags(Masm *m, int r) { as_cmp_ri(&m->a, r, (int32_t)IMM(0)); }
void ms_load_xmm(Masm *m, int xmm, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h && !is_raw(h)) { as_fmov_fr(&m->a, xmm, h->reg); return; }
    if (h) want_current(m, s);
    as_fld(&m->a, xmm, BASER, SLOT(s));
}
void ms_xmm_to(Masm *m, int base, int32_t disp, int xmm) { as_fst(&m->a, base, disp, xmm); }
void ms_unit_to(Masm *m, int base, int32_t disp) { as_st64i(&m->a, base, disp, (int32_t)IMM(0)); }
void ms_next_value(Masm *m, int r) { as_add_ri(&m->a, r, VALUE_SIZE); }

/* whether the word of R(s), wanted as an immediate of tag, must be tested:
   a slot's always; a home's holds what its representation says, which
   under RUNE_INT64 is, for an int or a word, an immediate or its box */
static int imm_tested(const Masm *m, int32_t s, int tag) {
    if (!ms_home(m, s)) return 1;
#ifdef RUNE_INT64
    return tag == T_INT || tag == T_WORD;
#else
    (void)tag;
    return 0;
#endif
}
void ms_check_tag(Masm *m, int32_t s, int tag, AsmLabel *unless) {
    const Home *h = ms_home(m, s);
    if (is_xmm(h)) { if (tag != T_REAL) as_jmp(&m->a, unless); return; }
    if (is_raw_gpr(h)) { if (tag == T_PTR || tag == T_REAL) as_jmp(&m->a, unless); return; }   /* a number, whatever its size */
    if (tag == T_PTR) {
        if (h) { as_jmp(&m->a, unless); return; }   /* a home holds no object the program sees */
        as_test8_mi(&m->a, BASER, SLOT(s), 1);
        as_jcc(&m->a, CC_NE, unless);
        return;
    }
    if (!imm_tested(m, s, tag)) return;
    if (h) as_test_ri(&m->a, h->reg, 1);
    else as_test8_mi(&m->a, BASER, SLOT(s), 1);
    as_jcc(&m->a, CC_E, unless);
}

/* ---- ints and words ----
   The operands of an arithmetic or a comparison come into R_S0 and R_S1 in
   the form the arithmetic is done in, and the result goes from that form
   into its register (ms_set_num). The form is the word itself, 2n+1: the
   machine's overflow of a sum of words is the overflow of 63 bits. With
   ints and words of 63 bits (D2 B) a word wraps where its word does and
   nothing is ever a box; with 64 bits kept (RUNE_INT64, D2 A) an operand
   that is a box, or a result past 63 bits, is the primitive's C to do.
   With raw homes as well (RUNE_RAW_HOMES) the form is the 64 bits: an
   operand's are its immediate's payload or its box's, read in line, tier
   2's homes hold them as they are, the machine's overflow is the int's, a
   word's arithmetic has no test at all, and a result is given its word, or
   its box by a helper, only when it goes to a slot. R_S2 is clobbered. */
void ms_two_words(Masm *m, int32_t x, int32_t y, AsmLabel *heap) {
    ms_load_bits(m, R_S0, x);
    ms_load_bits(m, R_S1, y);
    as_mov_rr(&m->a, R_S2, R_S0);
    as_and_rr(&m->a, R_S2, R_S1);
    as_test_ri(&m->a, R_S2, 1);
    as_jcc(&m->a, CC_E, heap);
}
/* ---- the 64 bits of a number ----
   An Int64.int and a Word64.word (and, under RUNE_RAW_HOMES, an int and a
   word): the operands come into R_S0 and R_S1 as their 64 bits, an
   immediate's payload or its box's read in line, tier 2's homes hold them
   as they are, the machine's overflow is the int's, a word's arithmetic
   has no test at all, and a result is given its word, or its box by a
   helper, only when it goes to a slot. R_S2 is clobbered. */
/* reg := the 64 bits of the number, char or tag in R(s); to slow where it
   is none (a slot the section does not vouch for) */
static void load_num(Masm *m, int reg, int32_t s, int tag, AsmLabel *slow) {
    const Home *h = ms_home(m, s);
    if (is_xmm(h)) bug("a real read as a number", s, tag);
    if (is_raw_gpr(h)) { as_mov_rr(&m->a, reg, h->reg); return; }
    if (h) { as_mov_rr(&m->a, reg, h->reg); as_sar_ri(&m->a, reg, 1); return; }   /* a char or a tag: its word */
    as_ld64(&m->a, R_S2, BASER, SLOT(s));
    if (tag == T_CHAR || tag == T_CON0) {   /* never a box */
        as_test_ri(&m->a, R_S2, 1);
        as_jcc(&m->a, CC_E, slow);
        as_mov_rr(&m->a, reg, R_S2);
        as_sar_ri(&m->a, reg, 1);
        return;
    }
    int rep = m->reps && (uint32_t)s < m->nlocals ? m->reps[s] : REP_ANY;
    int trusted = rep == REP_INT64 || rep == REP_WORD64 || rep == REP_INT || rep == REP_WORD;
    decode_num(m, reg, tag, trusted ? NULL : slow);
}
void ms_one_num64(Masm *m, int32_t x, int tag, AsmLabel *slow) { load_num(m, R_S0, x, tag, slow); }
void ms_two_num64(Masm *m, int32_t x, int32_t y, int tag, AsmLabel *slow) {
    load_num(m, R_S0, x, tag, slow);
    load_num(m, R_S1, y, tag, slow);
}
void ms_int64_arith(Masm *m, int op, AsmLabel *slow) {
    switch (op) {
    case MS_ADD: as_add_rr(&m->a, R_S0, R_S1); as_jcc(&m->a, CC_O, slow); break;
    case MS_SUB: as_sub_rr(&m->a, R_S0, R_S1); as_jcc(&m->a, CC_O, slow); break;
    case MS_MUL: as_mul_jo(&m->a, R_S0, R_S1, slow); break;
    default: bug("an operation ints do not have", op, MS_MUL);
    }
}
void ms_int64_neg(Masm *m, AsmLabel *slow) {
    as_mov_ri(&m->a, R_S1, 0);
    as_sub_rr(&m->a, R_S1, R_S0);
    as_jcc(&m->a, CC_O, slow);
    as_mov_rr(&m->a, R_S0, R_S1);
}
void ms_word64_arith(Masm *m, int op) {   /* modulo 2^64, as the machine's */
    switch (op) {
    case MS_ADD: as_add_rr(&m->a, R_S0, R_S1); break;
    case MS_SUB: as_sub_rr(&m->a, R_S0, R_S1); break;
    case MS_MUL: as_mul_rr(&m->a, R_S0, R_S1); break;
    case MS_AND: as_and_rr(&m->a, R_S0, R_S1); break;
    case MS_OR: as_or_rr(&m->a, R_S0, R_S1); break;
    case MS_XOR: as_xor_rr(&m->a, R_S0, R_S1); break;
    default: bug("an operation words do not have", op, MS_XOR);
    }
}
void ms_word64_not(Masm *m) { as_not(&m->a, R_S0); }
void ms_set_num64(Masm *m, int32_t d, int tag, int r, AsmLabel *slow) {
    const Home *h = ms_home(m, d);
    if (is_xmm(h)) bug("a number into a real's home", d, tag);
    if (is_raw_gpr(h)) { if (r != h->reg) as_mov_rr(&m->a, h->reg, r); real_behind(m, d); return; }
    if (tag == T_CHAR || tag == T_CON0) {   /* always an immediate */
        as_lea(&m->a, R_S2, r, r, 1, 1);
        if (h) as_mov_rr(&m->a, h->reg, R_S2); else as_st64(&m->a, BASER, SLOT(d), R_S2);
        return;
    }
    if (h) bug("an int or a word into a home of words", d, tag);
    /* into a slot: its word, or where it has none its box, which a helper
       makes from the bits (the primitive need not be done again in C);
       where there is no such helper (runeopt's templates) the slow path is
       the primitive's */
    if (!m->box_num) {
        encode_num(m, r, tag, slow);
        as_st64(&m->a, BASER, SLOT(d), R_S2);
        return;
    }
    Slow *sl = ms_slow(m, SLOW_BOXNUM, m->cur_pc);
    if (!sl) return;
    sl->a = d; sl->b = r; sl->c = 0; sl->n = m->cur_pc;
    int which = m->nslow - 1;
    encode_num(m, r, tag, &m->slow[which]->here);
    as_st64(&m->a, BASER, SLOT(d), R_S2);
    as_bind(&m->a, &m->slow[which]->back);
}
/* R_S1 := the count of a shift, the payload of the word in R(y); to slow
   where it is no immediate */
void ms_shift_count(Masm *m, int32_t y, AsmLabel *slow) {
#ifdef RUNE_RAW_NUMS
    load_num(m, R_S1, y, T_WORD, slow);
#else
    ms_load_bits(m, R_S1, y);
    if (imm_tested(m, y, T_WORD)) { as_test_ri(&m->a, R_S1, 1); as_jcc(&m->a, CC_E, slow); }
    as_shr_ri(&m->a, R_S1, 1);
#endif
}
#ifndef RUNE_INT64
/* Between the 64 bits in R_S0 and the word of an int or a word, which is 63:
   as an int, to slow where the number is past an int's bits (signed; or
   unsigned, above an int's largest); as a word, its low 63 bits. */
void ms_num64_as_int(Masm *m, AsmLabel *slow) {
    as_add_rr(&m->a, R_S0, R_S0);
    as_jcc(&m->a, CC_O, slow);
    as_lea(&m->a, R_S0, R_S0, -1, 1, 1);
}
void ms_word64_as_int(Masm *m, AsmLabel *slow) {
    as_mov_rr(&m->a, R_S2, R_S0);
    as_shr_ri(&m->a, R_S2, 62);
    as_test_rr(&m->a, R_S2, R_S2);
    as_jcc(&m->a, CC_NE, slow);
    as_lea(&m->a, R_S0, R_S0, R_S0, 1, 1);
}
void ms_word64_as_word(Masm *m) { as_lea(&m->a, R_S0, R_S0, R_S0, 1, 1); }
#endif
#ifdef RUNE_RAW_NUMS
void ms_one_imm(Masm *m, int32_t x, int tag, AsmLabel *slow) { ms_one_num64(m, x, tag, slow); }
void ms_two_imm(Masm *m, int32_t x, int32_t y, int tag, AsmLabel *slow) { ms_two_num64(m, x, y, tag, slow); }
void ms_int_arith(Masm *m, int op, AsmLabel *slow) { ms_int64_arith(m, op, slow); }
void ms_int_neg(Masm *m, AsmLabel *slow) { ms_int64_neg(m, slow); }
void ms_int_to_char(Masm *m, AsmLabel *slow) {
    as_cmp_ri(&m->a, R_S0, 255);
    as_jcc(&m->a, CC_A, slow);   /* unsigned: negative is out too */
}
void ms_word_arith(Masm *m, int op, AsmLabel *slow) { (void)slow; ms_word64_arith(m, op); }
void ms_word_not(Masm *m, AsmLabel *slow) { (void)slow; ms_word64_not(m); }
/* a word as an int: toInt of one past 2^63 - 1 is Overflow, the
   primitive's; toIntX is the same bits */
void ms_word_to_int(Masm *m, int x, AsmLabel *slow) {
    if (x) return;
    as_test_rr(&m->a, R_S0, R_S0);
    as_jcc(&m->a, CC_S, slow);
}
void ms_int_to_word(Masm *m, AsmLabel *slow) { (void)m; (void)slow; }
void ms_untag(Masm *m, int r, int tag) { (void)m; (void)r; (void)tag; }   /* the form is the payload already */
void ms_set_num(Masm *m, int32_t d, int tag, int r, AsmLabel *slow) { ms_set_num64(m, d, tag, r, slow); }
void ms_set_payload(Masm *m, int32_t d, int tag, int r, AsmLabel *slow) { ms_set_num64(m, d, tag, r, slow); }
void ms_set_word(Masm *m, int32_t d, int r, AsmLabel *slow) { ms_set_num64(m, d, T_WORD, r, slow); }
#else
void ms_one_imm(Masm *m, int32_t x, int tag, AsmLabel *slow) {
    ms_load_bits(m, R_S0, x);
    if (imm_tested(m, x, tag)) { as_test_ri(&m->a, R_S0, 1); as_jcc(&m->a, CC_E, slow); }
}
void ms_two_imm(Masm *m, int32_t x, int32_t y, int tag, AsmLabel *slow) {
    int tx = imm_tested(m, x, tag), ty = imm_tested(m, y, tag);
    ms_load_bits(m, R_S0, x);
    ms_load_bits(m, R_S1, y);
    if (tx && ty) {   /* both low bits in one test */
        as_mov_rr(&m->a, R_S2, R_S0);
        as_and_rr(&m->a, R_S2, R_S1);
        as_test_ri(&m->a, R_S2, 1);
        as_jcc(&m->a, CC_E, slow);
    } else if (tx || ty) {
        as_test_ri(&m->a, tx ? R_S0 : R_S1, 1);
        as_jcc(&m->a, CC_E, slow);
    }
}
/* 2a+1 and 2b+1: the sum is (2a) + (2b+1), the difference (2a+1) - (2b+1)
   + 1, the product (2a) * b + 1, and the machine's overflow of each is the
   overflow of 63 bits */
void ms_int_arith(Masm *m, int op, AsmLabel *slow) {
    switch (op) {
    case MS_ADD:
        as_lea(&m->a, R_S0, R_S0, -1, 1, -1);
        as_add_rr(&m->a, R_S0, R_S1);
        as_jcc(&m->a, CC_O, slow);
        break;
    case MS_SUB:
        as_sub_rr(&m->a, R_S0, R_S1);
        as_jcc(&m->a, CC_O, slow);
        as_lea(&m->a, R_S0, R_S0, -1, 1, 1);
        break;
    case MS_MUL:
        as_sar_ri(&m->a, R_S1, 1);
        as_lea(&m->a, R_S0, R_S0, -1, 1, -1);
        as_mul_jo(&m->a, R_S0, R_S1, slow);
        as_lea(&m->a, R_S0, R_S0, -1, 1, 1);
        break;
    default: bug("an operation ints do not have", op, MS_MUL);
    }
}
void ms_int_neg(Masm *m, AsmLabel *slow) {
    as_mov_ri(&m->a, R_S1, 2);   /* 2 - (2n+1) = 2(-n)+1 */
    as_sub_rr(&m->a, R_S1, R_S0);
    as_jcc(&m->a, CC_O, slow);
    as_mov_rr(&m->a, R_S0, R_S1);
}
void ms_int_to_char(Masm *m, AsmLabel *slow) {
    as_cmp_ri(&m->a, R_S0, (int32_t)IMM(255));
    as_jcc(&m->a, CC_A, slow);   /* unsigned: negative is out too */
}
/* A word is 63 bits (RUNE_INT63) and arithmetic is modulo 2^63, which the
   words' own arithmetic modulo 2^64 gives; or 64 (RUNE_INT64), where a
   result past 63 bits is a box, which the primitive's C makes. */
void ms_word_arith(Masm *m, int op, AsmLabel *slow) {
    switch (op) {
    case MS_ADD:
        as_lea(&m->a, R_S0, R_S0, -1, 1, -1);
#ifdef RUNE_INT64
        as_add_jc(&m->a, R_S0, R_S1, slow);
#else
        (void)slow;
        as_add_rr(&m->a, R_S0, R_S1);
#endif
        break;
    case MS_SUB:
#ifdef RUNE_INT64
        as_sub_jb(&m->a, R_S0, R_S1, slow);
#else
        as_sub_rr(&m->a, R_S0, R_S1);
#endif
        as_lea(&m->a, R_S0, R_S0, -1, 1, 1);
        break;
    case MS_MUL:
#ifdef RUNE_INT64
        /* two numbers below 2^63: the signed product overflows where it is not below 2^63 */
        as_shr_ri(&m->a, R_S0, 1);
        as_shr_ri(&m->a, R_S1, 1);
        as_mul_jo(&m->a, R_S0, R_S1, slow);
        as_lea(&m->a, R_S0, R_S0, R_S0, 1, 1);
#else
        as_shr_ri(&m->a, R_S1, 1);
        as_lea(&m->a, R_S0, R_S0, -1, 1, -1);
        as_mul_rr(&m->a, R_S0, R_S1);
        as_lea(&m->a, R_S0, R_S0, -1, 1, 1);
#endif
        break;
    case MS_AND: as_and_rr(&m->a, R_S0, R_S1); break;
    case MS_OR: as_or_rr(&m->a, R_S0, R_S1); break;
    case MS_XOR: as_xor_rr(&m->a, R_S0, R_S1); as_lea(&m->a, R_S0, R_S0, -1, 1, 1); break;
    default: bug("an operation words do not have", op, MS_XOR);
    }
}
void ms_word_not(Masm *m, AsmLabel *slow) {
#ifdef RUNE_INT64
    as_jmp(&m->a, slow);   /* the complement of a word below 2^63 is not below it */
#else
    (void)slow;
    as_neg(&m->a, R_S0);   /* -(2w+1) = 2(~w)+1 */
#endif
}
/* A word as an int: the same bits, where the int has them -- a word of 62
   bits or fewer, whose word has its top bit clear. toIntX of 63 bits is
   the same word; of 64, an int past 63 bits is a box. */
void ms_word_to_int(Masm *m, int x, AsmLabel *slow) {
#ifndef RUNE_INT64
    if (x) return;
#else
    (void)x;
#endif
    as_test_rr(&m->a, R_S0, R_S0);
    as_jcc(&m->a, CC_S, slow);
}
void ms_int_to_word(Masm *m, AsmLabel *slow) {
#ifdef RUNE_INT64
    as_test_rr(&m->a, R_S0, R_S0);   /* a negative int is a word past 63 bits */
    as_jcc(&m->a, CC_S, slow);
#else
    (void)m; (void)slow;
#endif
}
void ms_untag(Masm *m, int r, int tag) {
    if (tag == T_WORD) as_shr_ri(&m->a, r, 1); else as_sar_ri(&m->a, r, 1);
}
void ms_set_word(Masm *m, int32_t d, int r, AsmLabel *slow) {
#ifdef RUNE_INT64
    as_test_rr(&m->a, r, r);
    as_jcc(&m->a, CC_S, slow);
#else
    (void)slow;
#endif
    ms_set_reg(m, d, T_WORD, r);
}

/* the result of the arithmetic is its word already; a payload is given one,
   and a word's, which may be past 63 bits, is the primitive's to box */
void ms_set_num(Masm *m, int32_t d, int tag, int r, AsmLabel *slow) { (void)tag; (void)slow; ms_set_bits(m, d, r); }
void ms_set_payload(Masm *m, int32_t d, int tag, int r, AsmLabel *slow) {
    if (tag == T_WORD) ms_set_word(m, d, r, slow); else ms_set_reg(m, d, tag, r);
}
#endif

/* ---- reals: an immediate by the rotation, or a box (value.h) ---- */
void ms_load_real(Masm *m, int xmm, int32_t s, AsmLabel *unless) {
    const Home *h = ms_home(m, s);
    if (is_xmm(h)) { as_fmov(&m->a, xmm, h->reg); return; }
    ms_load_bits(m, R_S2, s);
    decode_real(m, xmm, unless);
}
void ms_set_real(Masm *m, int32_t d, int xmm, AsmLabel *slow) {
    const Home *h = ms_home(m, d);
    if (is_xmm(h)) { as_fmov(&m->a, h->reg, xmm); real_behind(m, d); return; }
    encode_real(m, xmm, slow);
    ms_set_bits(m, d, R_S2);
}

/* tier 2: the safepoints' write-back and reload of the homes live at pc */
static int live_at(const Masm *m, uint32_t pc, uint32_t r) {
    if (!m->live) return 1;
    return (m->live[pc - m->from] >> r) & 1;
}
/* a home's machine register as a bit: the general ones, then the reals' */
static uint64_t home_bit(const Home *h) {
    return (uint64_t)1 << (h->kind == HOME_XMM ? 32 + h->reg : h->reg);
}
/* whether a call into C leaves the home as it was (asm.h, by the convention) */
static int kept(const Masm *m, const Home *h) {
    return h->kind == HOME_XMM ? as_keeps_f(m->win, h->reg) : as_keeps_g(m->win, h->reg);
}
static void writeback(Masm *m, uint32_t pc, int pushed) {
    if (!m->homes) return;
#ifdef RUNE_JIT_CONV
    int ctx = m->conv_ctx;
    m->conv_ctx = 1;
#endif
    for (uint32_t r = 0; r < m->nlocals; r++) {
        const Home *h = &m->homes[r];
        if (h->kind == HOME_SLOT || !live_at(m, pc, r)) continue;
        if (h->kind == HOME_XMM) real_to_slot(m, (int32_t)r, h, pushed, pc);
        else if (is_raw_gpr(h)) num_to_slot(m, (int32_t)r, h, pushed, pc);
        else home_to_slot(m, (int32_t)r, h);
    }
#ifdef RUNE_JIT_CONV
    m->conv_ctx = ctx;
#endif
}
void ms_writeback(Masm *m, uint32_t pc) { writeback(m, pc, 0); }
/* At a call of an SML function: the homes the frame still needs -- live
   where the call returns, but for the register it returns into, which the
   return writes -- written back, the callee having the machine's
   registers. In a function with a handler, every home live at the call:
   what a handler needs is live at every call in its scope. An argument
   that dies at the call is not written back; the call stores it into the
   callee's register from its home, or from its word (ms_need_word) where
   the home holds a raw number. */
void ms_writeback_call(Masm *m, uint32_t pc, uint32_t after, int32_t result) {
    if (!m->homes) return;
    if (m->has_handlers) { writeback(m, pc, 0); return; }
#ifdef RUNE_JIT_CONV
    int ctx = m->conv_ctx;
    m->conv_ctx = 1;
#endif
    for (uint32_t r = 0; r < m->nlocals; r++) {
        const Home *h = &m->homes[r];
        if (h->kind == HOME_SLOT || !live_at(m, after, r) || (int32_t)r == result) continue;
        if (h->kind == HOME_XMM) real_to_slot(m, (int32_t)r, h, 0, pc);
        else if (is_raw_gpr(h)) num_to_slot(m, (int32_t)r, h, 0, pc);
        else home_to_slot(m, (int32_t)r, h);
    }
#ifdef RUNE_JIT_CONV
    m->conv_ctx = ctx;
#endif
}
/* where a general home waits in the VM across the helper that boxes; a
   register that is no home (a result on its way to a slot) has the cell
   after them */
_Static_assert(sizeof ((VM *)0)->jit_gspill == 32 * sizeof(uint64_t) && sizeof ((VM *)0)->jit_fspill == 32 * sizeof(uint64_t),
               "a cell of VM.jit_gspill and of VM.jit_fspill for each of the machine's registers");
static int32_t gspill(int reg) { return OFF(jit_gspill) + 8 * (reg & 31); }
static int32_t fspill(int f) { return OFF(jit_fspill) + 8 * (f & 31); }
/* The slow path of a raw home's write-back: the real, or the int or word
   of 64 bits, has no immediate, and the helper boxes it into the slot. It
   may collect, so the VM is given its stack pointer; and every live home
   that C does not keep waits in the VM and is loaded again after -- there
   and not in its slot, where a raw home's bits are no value. A home that
   waits is an immediate, a number's bits or a double: nothing a
   collection moves. */
void ms_emit_box(Masm *m, Slow *sp) {
    Slow s = *sp;
    uint32_t live = s.n;
    int real = s.kind == SLOW_BOXREAL;
#ifdef RUNE_JIT_CONV
    conv_at(m, real ? CONV_REAL_BOX : CONV_NUM_BOX, s.cur);
#endif
    int32_t at = real ? fspill(s.b) : gspill(s.b);
    for (uint32_t r = 0; m->homes && r < m->nlocals; r++) {
        const Home *h = &m->homes[r];
        if (h->kind == HOME_SLOT || !live_at(m, live, r) || kept(m, h)) continue;
        if (h->kind == HOME_GPR) as_st64(&m->a, VMR, gspill(h->reg), h->reg);
        else as_fst(&m->a, VMR, fspill(h->reg), h->reg);
    }
    /* the one to box, live or not: the helper takes it from there */
    if (real) as_fst(&m->a, VMR, at, s.b); else as_st64(&m->a, VMR, at, s.b);
    as_st32i(&m->a, VMR, OFF(pc), (int32_t)s.pc);
    as_lea(&m->a, R_S0, BASEI, -1, 1, (int32_t)(m->nlocals + (uint32_t)s.c));
    as_st64(&m->a, VMR, OFF(sp), R_S0);
    as_st64(&m->a, VMR, OFF(instructions), COUNTR);
    as_mov_ri(&m->a, ms_arg(m, 1), s.a);
    as_ld64(&m->a, ms_arg(m, 2), VMR, at);
    ms_call(m, (MsHelper)(real ? m->box_real : m->box_num));
    for (uint32_t r = 0; m->homes && r < m->nlocals; r++) {
        const Home *h = &m->homes[r];
        if (h->kind == HOME_SLOT || !live_at(m, live, r) || kept(m, h)) continue;
        if (h->kind == HOME_GPR) as_ld64(&m->a, h->reg, VMR, gspill(h->reg));
        else as_fld(&m->a, h->reg, VMR, fspill(h->reg));
    }
    if (real) { if (!as_keeps_f(m->win, s.b)) as_fld(&m->a, s.b, VMR, at); }
    else if (!as_keeps_g(m->win, s.b)) as_ld64(&m->a, s.b, VMR, at);
    as_jmp(&m->a, &s.back);
}
/* A call of a function of the C library on reals -- sin and the like,
   which is all their primitives do (prims.c) -- with its arguments in
   F_S0 and F_S1 and its result in F_S0. It touches nothing of the VM,
   so nothing is synced or reloaded: the homes C does not keep and that
   are live at the instruction's start or at after wait in the VM's
   cells as they are, the double or the 64 bits, and are loaded again
   (those at the start too: a slow path after the call writes them back
   for the primitive's C to read). d's does not: the result goes there.
   The call is through the function's trampoline, whose move of the VM
   into the first general argument the function never reads. */
void ms_call_pure(Masm *m, MsHelper f, uint32_t after, int32_t d) {
    for (uint32_t r = 0; m->homes && r < m->nlocals; r++) {
        const Home *h = &m->homes[r];
        if (h->kind == HOME_SLOT || (int32_t)r == d || kept(m, h) || !(live_at(m, m->cur_pc, r) || live_at(m, after, r))) continue;
        if (h->kind == HOME_GPR) as_st64(&m->a, VMR, gspill(h->reg), h->reg);
        else as_fst(&m->a, VMR, fspill(h->reg), h->reg);
    }
    ms_call(m, f);
    for (uint32_t r = 0; m->homes && r < m->nlocals; r++) {
        const Home *h = &m->homes[r];
        if (h->kind == HOME_SLOT || (int32_t)r == d || kept(m, h) || !(live_at(m, m->cur_pc, r) || live_at(m, after, r))) continue;
        if (h->kind == HOME_GPR) as_ld64(&m->a, h->reg, VMR, gspill(h->reg));
        else as_fld(&m->a, h->reg, VMR, fspill(h->reg));
    }
}
void ms_reload_clobbered(Masm *m, uint32_t pc) {
    if (!m->homes) return;
#ifdef RUNE_JIT_CONV
    int ctx = m->conv_ctx;
    m->conv_ctx = 2;
#endif
    for (uint32_t r = 0; r < m->nlocals; r++)
        if (m->homes[r].kind != HOME_SLOT && live_at(m, pc, r) && !kept(m, &m->homes[r])) slot_to_home(m, (int32_t)r, &m->homes[r]);
#ifdef RUNE_JIT_CONV
    m->conv_ctx = ctx;
#endif
}
void ms_reload_homes(Masm *m, uint32_t pc) {
    if (!m->homes) return;
#ifdef RUNE_JIT_CONV
    int ctx = m->conv_ctx;
    m->conv_ctx = 2;
#endif
    for (uint32_t r = 0; r < m->nlocals; r++)
        if (m->homes[r].kind != HOME_SLOT && live_at(m, pc, r)) slot_to_home(m, (int32_t)r, &m->homes[r]);
#ifdef RUNE_JIT_CONV
    m->conv_ctx = ctx;
#endif
}
/* an immediate by the section, whose word is the value: under RUNE_INT64
   an int or a word may be a box, and two boxes of one number are not one
   word */
int ms_immediate(const Masm *m, int32_t s) {
    if (!m->reps || (uint32_t)s >= m->nlocals) return 0;
    int rep = m->reps[s];
#ifdef RUNE_INT64
    return rep == REP_CHAR || rep == REP_CON0;
#else
    return rep == REP_INT || rep == REP_WORD || rep == REP_CHAR || rep == REP_CON0;
#endif
}
int ms_number(const Masm *m, int32_t s) {
    if (!m->reps || (uint32_t)s >= m->nlocals) return 0;
    if (m->reps[s] == REP_INT64) return T_INT64;
    if (m->reps[s] == REP_WORD64) return T_WORD64;
#ifdef RUNE_RAW_NUMS
    return m->reps[s] == REP_INT ? T_INT : m->reps[s] == REP_WORD ? T_WORD : 0;
#else
    return 0;
#endif
}
int ms_trusts(const Masm *m, int32_t s, int kind) {
    if (!m->reps || (uint32_t)s >= m->nlocals) return 0;
    int rep = m->reps[s];
    return rep == REP_PTR || (rep == REP_CON && kind == K_CON);
}
void ms_load_obj(Masm *m, int r, int32_t s, int kind, AsmLabel *unless) {
    m->nfields = UINT32_MAX;   /* an object of the program's, whose length the code tests */
    as_ld64(&m->a, r, BASER, SLOT(s));
    if (ms_trusts(m, s, kind)) return;   /* tier 2: the section says so (M10) */
    as_test_ri(&m->a, r, 1);
    as_jcc(&m->a, CC_NE, unless);
    kind_is(m, r, kind, unless);
}
void ms_load_obj_tested(Masm *m, int r, int32_t s, int kind, AsmLabel *unless) {
    const uint8_t *reps = m->reps;
    m->reps = NULL;
    ms_load_obj(m, r, s, kind, unless);
    m->reps = reps;
}
/* a nullary constructor's tag is its immediate; one with an argument's is
   in the object's header */
void ms_load_tag_of_con(Masm *m, int r, int32_t s, AsmLabel *unless) {
    const Home *h = ms_home(m, s);
    if (h) { as_mov_rr(&m->a, r, h->reg); as_sar_ri(&m->a, r, 1); return; }   /* a nullary constructor */
    AsmLabel ptr, done;
    as_label_init(&ptr); as_label_init(&done);
    as_ld64(&m->a, r, BASER, SLOT(s));
    as_test_ri(&m->a, r, 1);
    as_jcc(&m->a, CC_E, &ptr);
    as_sar_ri(&m->a, r, 1);
    as_jmp(&m->a, &done);
    as_bind(&m->a, &ptr);
    /* not nullary: a pointer to a constructor, which the section
       vouches for at tier 2 (M10); else tested */
    int trusted = m->reps && (uint32_t)s < m->nlocals && m->reps[s] == REP_CON;
    if (!trusted) kind_is(m, r, K_CON, unless);
    as_ld16(&m->a, r, r, (int32_t)offsetof(Obj, contag));
    as_bind(&m->a, &done);
    as_label_free(&ptr); as_label_free(&done);
}

/* ---- the VM ---- */
void ms_sync(Masm *m, uint32_t pc, int pushed) {
    writeback(m, m->cur_pc, pushed);
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
    ms_frame(m, R_S1);
    as_ld64(&m->a, BASEI, R_S1, (int32_t)offsetof(Frame, base));
    as_mov_rr(&m->a, BASER, BASEI);
    as_shl_ri(&m->a, BASER, VALUE_SHIFT);
    as_add_rm(&m->a, BASER, VMR, OFF(stack));   /* the stack itself has no register: only this and a RET want it */
    /* the homes live at the instruction's entry (the call clobbered them)
       and at its end (the helper may have written the slot of the one it
       defines) */
    if (m->homes) {
        /* Two registers that are never live together may have one home
           (compile.c): the ones live at the entry have theirs, and of the
           others the one the instruction defines has one that none of
           those has; a register live at sync_pc alone that is neither --
           sync_pc is no successor of a jump -- is not loaded over them.
           A home that C keeps still holds its register, unless that is
           the one the instruction defines, whose slot the helper may
           have written. */
        uint64_t taken = 0;
        for (uint32_t r = 0; r < m->nlocals; r++)
            if (m->homes[r].kind != HOME_SLOT && live_at(m, m->cur_pc, r)) {
                taken |= home_bit(&m->homes[r]);
                if (kept(m, &m->homes[r]) && !((m->cur_def >> r) & 1)) continue;
                slot_to_home(m, (int32_t)r, &m->homes[r]);
            }
        for (uint32_t r = 0; r < m->nlocals; r++)
            if (m->homes[r].kind != HOME_SLOT && !live_at(m, m->cur_pc, r) && live_at(m, m->sync_pc, r)
                && !(taken & home_bit(&m->homes[r]))) {
                taken |= home_bit(&m->homes[r]);
                slot_to_home(m, (int32_t)r, &m->homes[r]);
            }
    }
}
void ms_call_lean(Masm *m, MsHelper helper) {
    ms_call(m, helper);
    ms_reload_clobbered(m, m->cur_pc);
}
/* the helper's trampoline, where it has one and the code can reach it */
static const void *trampoline(const Masm *m, uint64_t at) {
    if (!m->placed || !m->tramp_from) return NULL;
    for (uint32_t i = ms_tramp_slot(at, m->tramp_mask); m->tramp_from[i]; i = (i + 1) & m->tramp_mask)
        if (m->tramp_from[i] == at) return m->tramp_to[i];
    return NULL;
}
/* A call into C, the VM its first argument: through the helper's
   trampoline in the code's region, which moves the VM, a direct call of
   five bytes (or one bl), where it has one; else the move, the address
   in a register and an indirect call (as_call_c) */
void ms_call(Masm *m, MsHelper helper) {
    uint64_t at;   /* a function pointer's bits, through memcpy: ISO C has no cast for them */
    memcpy(&at, &helper, sizeof at);
    const void *t = trampoline(m, at);
    if (t) { as_call_to(&m->a, t); return; }
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
    if (m->placed) { as_jmp_to(&m->a, m->leave); return; }   /* the leave stub is at the region's start, in reach */
    as_mov_ri(&m->a, R_S6, (int64_t)(intptr_t)m->leave);
    as_jmp_r(&m->a, R_S6);
}

/* ---- the heap ---- */
void ms_alloc(Masm *m, int kind, int contag, uint32_t n, AsmLabel *slow) {
    uint32_t size = (uint32_t)obj_size_of(kind, n);
    as_cmp_mi(&m->a, VMR, OFF(gc_stress), 0);
    as_jcc(&m->a, CC_NE, slow);
    as_ld64(&m->a, R_S0, VMR, OFF(alloc.used));
    as_lea(&m->a, R_S1, R_S0, -1, 1, (int32_t)size);
    as_cmp_rm(&m->a, R_S1, VMR, OFF(alloc.size));
    as_jcc(&m->a, CC_A, slow);
    as_st64(&m->a, VMR, OFF(alloc.used), R_S1);
    as_add_mi(&m->a, VMR, OFF(bytes_allocated), (int32_t)size);
    as_add_mi(&m->a, VMR, OFF(objects_allocated), 1);
    as_add_rm(&m->a, R_S0, VMR, OFF(alloc.from));
    /* the header: kind, pad 0, contag; then len */
    as_st32i(&m->a, R_S0, 0, (int32_t)((uint32_t)kind | ((uint32_t)contag << 16)));
    as_st32i(&m->a, R_S0, 4, (int32_t)n);
    m->nfields = n;
}
void ms_store_field(Masm *m, int obj, uint32_t i, int32_t s) {
    if (i >= m->nfields) bug("a field the object does not have", i, m->nfields);
    ms_store_value(m, obj, FIELD_OFF(i), s);
}
void ms_load_field(Masm *m, int32_t d, int obj, uint32_t i) {
    ms_load_value(m, d, obj, FIELD_OFF(i));
}
void ms_load_len(Masm *m, int r, int obj) { as_ld32(&m->a, r, obj, (int32_t)offsetof(Obj, len)); }
void ms_check_len(Masm *m, int obj, uint32_t n, AsmLabel *unless) {
    as_cmp32_mi(&m->a, obj, (int32_t)offsetof(Obj, len), (int32_t)n);
    as_jcc(&m->a, CC_NE, unless);
}
void ms_load_contag(Masm *m, int r, int obj) { as_ld16(&m->a, r, obj, (int32_t)offsetof(Obj, contag)); }
void ms_need_len(Masm *m, int obj, uint32_t n, AsmLabel *unless) {
    as_cmp32_mi(&m->a, obj, (int32_t)offsetof(Obj, len), (int32_t)n);
    as_jcc(&m->a, CC_BE, unless);
}
/* THE BARRIER, in compiled code: a store into an object that exists is
   this one operation, the store and what it does beside it (value.h,
   BARRIER), so that the barrier has what C's has -- the object, the field
   and the value -- and may come before the store. Today it is the store
   alone; under RUNE_BARRIER_CARDS it then marks the card of the field's
   address, as C's does, with the register that held the object, which no
   emitter needs again. runeopt's `:=` and `Array.update` are its template
   (setField). */
void ms_set_field(Masm *m, int obj, uint32_t i, int32_t s) {
    ms_store_field(m, obj, i, s);
#ifdef RUNE_BARRIER_CARDS
    as_add_ri(&m->a, obj, FIELD_OFF(i));
    as_shr_ri(&m->a, obj, CARD_SHIFT);
    as_and_ri(&m->a, obj, (int32_t)(CARD_COUNT - 1));
    as_add_rm(&m->a, obj, VMR, OFF(jit_cards));
    as_st8i(&m->a, obj, 0, 1);
#endif
}
void ms_store_field_imm(Masm *m, int obj, uint32_t i, int tag, int32_t payload) {
    as_st64i(&m->a, obj, FIELD_OFF(i), (int32_t)word_of(tag, payload));
}
void ms_load_field_payload(Masm *m, int r, int obj, uint32_t i) {
    as_ld64(&m->a, r, obj, FIELD_OFF(i));
    as_sar_ri(&m->a, r, 1);
}
void ms_element(Masm *m, int obj, int index) {
    ms_scale_index(m, index);
    as_add_rr(&m->a, obj, index);
}
void ms_string_byte(Masm *m, int r, int obj, int index) {
    as_add_rr(&m->a, obj, index);
    as_ld8(&m->a, r, obj, (int32_t)sizeof(Obj));
}
void ms_load_nth(Masm *m, int32_t d, int base, uint32_t i) { ms_load_value(m, d, base, (int32_t)(VALUE_SIZE * i)); }
/* R(d) := a real known as the code is made (a constant), where d's home
   holds a real's double: the double's bits, not its word decoded each time
   the code runs. ms_real_home says whether d has such a home. */
int ms_real_home(const Masm *m, int32_t d) { return is_xmm(ms_home(m, d)); }
int ms_num_home(const Masm *m, int32_t d) { return is_raw_gpr(ms_home(m, d)); }
void ms_set_real_known(Masm *m, int32_t d, uint64_t bits) {
    const Home *h = ms_home(m, d);
    if (bits == 0) as_fzero(&m->a, h->reg);
    else { as_mov_ri(&m->a, R_S2, (int64_t)bits); as_fmov_fr(&m->a, h->reg, R_S2); }
    real_behind(m, d);
}
void ms_store_nth(Masm *m, int base, uint32_t i, int32_t s) { ms_store_value(m, base, (int32_t)(VALUE_SIZE * i), s); }
void ms_slot_addr(Masm *m, int r, int32_t s) { as_lea(&m->a, r, BASER, -1, 1, SLOT(s)); }
void ms_fill_units(Masm *m, int base, uint32_t from, uint32_t to) {
    for (uint32_t i = from; i < to; i++) ms_unit_to(m, base, (int32_t)(VALUE_SIZE * i));
}
void ms_field_from_nth(Masm *m, int obj, uint32_t i, int base, uint32_t k) {
    as_fld(&m->a, F_S0, base, (int32_t)(VALUE_SIZE * k));
    as_fst(&m->a, obj, FIELD_OFF(i), F_S0);
}
void ms_scale_index(Masm *m, int r) { as_shl_ri(&m->a, r, VALUE_SHIFT); }
void ms_slot_from_nth_raw(Masm *m, int32_t d, int base, uint32_t k) {
    as_fld(&m->a, F_S0, base, (int32_t)(VALUE_SIZE * k));
    as_fst(&m->a, BASER, SLOT(d), F_S0);
}

/* ---- slow paths ---- */
Slow *ms_slow(Masm *m, int kind, uint32_t pc) {
    if (m->nslow == m->slow_cap) {
        int cap = m->slow_cap ? m->slow_cap * 2 : 8;
        Slow **all = realloc(m->slow, (size_t)cap * sizeof *all);
        if (!all) { m->a.failed = 1; return NULL; }
        m->slow = all;
        m->slow_cap = cap;
    }
    /* a record of its own, so that a pointer to one, or to its labels,
       holds while the emitter that has it adds another slow path */
    Slow *s = calloc(1, sizeof *s);
    if (!s) { m->a.failed = 1; return NULL; }
    m->slow[m->nslow++] = s;
    as_label_init(&s->here);
    as_label_init(&s->back);
    s->kind = kind;
    s->pc = pc;
    s->cur = m->cur_pc;
    return s;
}
void ms_emit_slow_paths(Masm *m, void (*emit)(Masm *m, Slow *s)) {
    for (int i = 0; i < m->nslow; i++) {
        as_bind(&m->a, &m->slow[i]->here);
        emit(m, m->slow[i]);
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
/* the stub of the fatal errors (compile.c, jit_fatal): rax the number of
   the error's record, rcx the value its message may want, the machine
   stack as the code keeps it; the helper never returns */
void ms_emit_fatal(Asm *a, int win, MsHelper helper) {
    Masm m;
    memset(&m, 0, sizeof m);
    m.a = *a; m.win = win; m.nfields = UINT32_MAX;
    as_mov_rr(&m.a, ms_arg(&m, 2), R_S1);   /* first: rcx is the first argument on Windows */
    as_mov_rr(&m.a, ms_arg(&m, 1), R_S0);
    ms_call(&m, helper);
    as_trap(&m.a);
    *a = m.a;
}
void ms_emit_leave(Asm *a, int win) {
    as_stub_leave(a, win);
}
