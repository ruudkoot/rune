/* The macro-assembler of runtime/register's JIT (masm.h). */
#include "masm.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OFF(field) ((int32_t)offsetof(VM, field))
#define SLOT(k) slot(m, k)

/* The layout as the code here writes it (runtime/value.h has it in C; this
   branch's is the tagged word of docs/plans/heap-layout.md, M4): a Value
   of 8 bytes, whose low bit says an immediate (2n+1: an int, a word, a
   char, a nullary constructor's tag, unit as 1; or a real in Koka's
   encoding) from a pointer, and an object's header of kind, contag and
   len before its fields. A change of layout is a change to value.h and to
   the operations here, and these say so at compile time. */
#define VALUE_SIZE ((int32_t)sizeof(Value))
#define VALUE_SHIFT 3
#define FIELD_OFF(i) ((int32_t)(sizeof(Obj) + sizeof(Value) * (i)))
#define IMM(n) ((int64_t)(((uint64_t)(int64_t)(n) << 1) | 1u))   /* the word of the immediate n */
_Static_assert(sizeof(Value) == 8, "masm.c writes 8-byte values");
_Static_assert((1 << VALUE_SHIFT) == sizeof(Value), "masm.c scales an index by 8");
_Static_assert(offsetof(Obj, kind) == 0 && offsetof(Obj, contag) == 2 && offsetof(Obj, len) == 4 && sizeof(Obj) == 8, "masm.c reads the header as kind, contag, len, then the fields");

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
    m->cur_reals = 0;
    m->box_real = NULL;
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

static int is_xmm(const Home *h) { return h && h->kind == HOME_XMM; }
static int real_current(const Masm *m, int32_t s) { return s >= 0 && s < 64 && ((m->cur_reals >> s) & 1); }
static void real_behind(Masm *m, int32_t s) { if (s >= 0 && s < 64) m->cur_reals &= ~((uint64_t)1 << s); }
static void real_made(Masm *m, int32_t s) { if (s >= 0 && s < 64) m->cur_reals |= (uint64_t)1 << s; }
/* the word of a real in its home is wanted where its slot is behind: an
   emitter that did not say ms_need_word at the instruction's start */
static void want_current(const Masm *m, int32_t s) {
    if (!real_current(m, s)) bug("the word of a real whose slot is behind (ms_need_word)", s, (long long)m->cur_pc);
}

/* R_S2 := the word of the real in xmm where it has an immediate (value.h,
   real_encode: an exponent of 0, of all ones, or of 0x201 to 0x5fe); else
   to fail. R_S3 clobbered. */
static void encode_real(Masm *m, int xmm, AsmLabel *fail) {
#ifdef RUNE_REAL_BOXED
    (void)xmm;
    as_jmp(&m->a, fail);
#else
    AsmLabel ok, mid; as_label_init(&ok); as_label_init(&mid);
    as_fmov_rf(&m->a, R_S2, xmm);
    as_ror_ri(&m->a, R_S2, 52);              /* left by 12: the sign and the exponent lowest */
    as_mov_rr(&m->a, R_S3, R_S2);
    as_and_ri(&m->a, R_S3, 0x7ff);
    as_test_rr(&m->a, R_S3, R_S3);
    as_jcc(&m->a, CC_E, &ok);                /* 0 stays 0 */
    as_cmp_ri(&m->a, R_S3, 0x7ff);
    as_jcc(&m->a, CC_NE, &mid);
    as_mov_ri(&m->a, R_S3, 0x3ff);
    as_jmp(&m->a, &ok);
    as_bind(&m->a, &mid);
    as_sub_ri(&m->a, R_S3, 0x201);           /* 0x201..0x5fe to 0..0x3fd, anything else past it */
    as_cmp_ri(&m->a, R_S3, 0x3fd);
    as_jcc(&m->a, CC_A, fail);
    as_add_ri(&m->a, R_S3, 1);
    as_bind(&m->a, &ok);
    as_and_ri(&m->a, R_S2, ~0x7ff);
    as_lea(&m->a, R_S2, R_S2, R_S3, 2, 1);
    as_label_free(&ok); as_label_free(&mid);
#endif
}
/* xmm := the real of the word in R_S2: an immediate, decoded (the exponent
   of ten bits back to eleven: 0 and all ones are zero's and infinity's,
   the rest is 0x200 short; then the word rotated back), or a box, read.
   To unless where it is neither; with unless NULL the word is trusted to
   be a real's (tier 2, a register the section says is one). R_S3
   clobbered. */
static void decode_real(Masm *m, int xmm, AsmLabel *unless) {
    AsmLabel box, join, done; as_label_init(&box); as_label_init(&join); as_label_init(&done);
    as_test_ri(&m->a, R_S2, 1);
    as_jcc(&m->a, CC_E, &box);
#ifdef RUNE_REAL_BOXED
    if (unless) as_jmp(&m->a, unless); else as_trap(&m->a);   /* every real is a box */
#else
    {
        AsmLabel mid; as_label_init(&mid);
        as_mov_rr(&m->a, R_S3, R_S2);
        as_shr_ri(&m->a, R_S3, 1);
        as_and_ri(&m->a, R_S3, 0x3ff);
        as_test_rr(&m->a, R_S3, R_S3);
        as_jcc(&m->a, CC_E, &join);
        as_cmp_ri(&m->a, R_S3, 0x3ff);
        as_jcc(&m->a, CC_NE, &mid);
        as_mov_ri(&m->a, R_S3, 0x7ff);
        as_jmp(&m->a, &join);
        as_bind(&m->a, &mid);
        as_add_ri(&m->a, R_S3, 0x200);
        as_label_free(&mid);
    }
    as_bind(&m->a, &join);
    as_and_ri(&m->a, R_S2, ~0x7ff);
    as_or_rr(&m->a, R_S2, R_S3);
    as_ror_ri(&m->a, R_S2, 12);
    as_fmov_fr(&m->a, xmm, R_S2);
    as_jmp(&m->a, &done);
#endif
    as_bind(&m->a, &box);
    if (unless) {
        as_test_rr(&m->a, R_S2, R_S2);
        as_jcc(&m->a, CC_E, unless);
        as_cmp8_mi(&m->a, R_S2, (int32_t)offsetof(Obj, kind), K_REAL);
        as_jcc(&m->a, CC_NE, unless);
    }
    as_fld(&m->a, xmm, R_S2, (int32_t)sizeof(Obj));
    as_bind(&m->a, &done);
    as_label_free(&box); as_label_free(&join); as_label_free(&done);
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
    encode_real(m, h->reg, &m->slow[which].here);
    as_st64(&m->a, BASER, SLOT(s), R_S2);
    as_bind(&m->a, &m->slow[which].back);
    real_made(m, s);
}
/* A home holds its value's word, as the slot does: written back and loaded
   by a plain move -- but a real's, which holds the double. */
static void home_to_slot(Masm *m, int32_t s, const Home *h) {
    if (is_xmm(h)) { want_current(m, s); return; }
    as_st64(&m->a, BASER, SLOT(s), h->reg);
}
static void slot_to_home(Masm *m, int32_t s, const Home *h) {
    if (is_xmm(h)) {
        as_ld64(&m->a, R_S2, BASER, SLOT(s));
        decode_real(m, h->reg, NULL);
        real_made(m, s);   /* the slot is the home's word */
        return;
    }
    as_ld64(&m->a, h->reg, BASER, SLOT(s));
}
void ms_begin(Masm *m, uint32_t pc) { m->cur_pc = pc; m->cur_reals = 0; }
void ms_need_word(Masm *m, int32_t s) {
    const Home *h = ms_home(m, s);
    if (is_xmm(h)) real_to_slot(m, s, h, 0, m->cur_pc);
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
    if (hd && hs) as_mov_rr(&m->a, hd->reg, hs->reg);
    else if (hd) slot_to_home(m, s, hd);
    else if (hs) home_to_slot(m, d, hs);
    else {
        as_fld(&m->a, F_S0, BASER, SLOT(s));   /* eight bytes through xmm0: no general register is needed */
        as_fst(&m->a, BASER, SLOT(d), F_S0);
    }
}
void ms_move(Masm *m, int32_t d, int32_t s) {
    if (d != s && !is_xmm(ms_home(m, d))) ms_need_word(m, s);
    ms_copy(m, d, s);
}
/* the word of the value of tag and payload */
static int64_t word_of(int tag, int64_t payload) { return tag == T_PTR ? payload : IMM(payload); }
void ms_set(Masm *m, int32_t d, int tag, int64_t payload) {
    const Home *h = ms_home(m, d);
    int64_t w = word_of(tag, payload);
    if (is_xmm(h)) bug("a real's home set to an immediate that is none", d, tag);
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
    if (h) as_mov_rr(&m->a, h->reg, r);
    else as_st64(&m->a, BASER, SLOT(d), r);
}
void ms_set_reg(Masm *m, int32_t d, int tag, int r) {
    if (tag != T_PTR) as_lea(&m->a, r, r, r, 1, 1);   /* 2n+1; the flags are left as they were */
    ms_set_bits(m, d, r);
}
void ms_load_bits(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (is_xmm(h)) { want_current(m, s); as_ld64(&m->a, r, BASER, SLOT(s)); return; }
    if (h) as_mov_rr(&m->a, r, h->reg);
    else as_ld64(&m->a, r, BASER, SLOT(s));
}
void ms_load_payload(Masm *m, int r, int32_t s) {
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
    if (h) { as_ld64(&m->a, h->reg, base, disp); return; }
    as_fld(&m->a, F_S0, base, disp);
    as_fst(&m->a, BASER, SLOT(d), F_S0);
}
void ms_store_value(Masm *m, int base, int32_t disp, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h && !is_xmm(h)) { as_st64(&m->a, base, disp, h->reg); return; }
    if (h) want_current(m, s);   /* a real: its slot has its word */
    as_fld(&m->a, F_S0, BASER, SLOT(s));
    as_fst(&m->a, base, disp, F_S0);
}
void ms_value_to(Masm *m, int base, int32_t disp, int32_t s) { ms_store_value(m, base, disp, s); }
void ms_value_from(Masm *m, int32_t d, int base, int32_t disp) { ms_load_value(m, d, base, disp); }
void ms_cmp_bits(Masm *m, int r, int32_t s) {
    const Home *h = ms_home(m, s);
    if (is_xmm(h)) want_current(m, s);
    if (h && !is_xmm(h)) as_cmp_rr(&m->a, r, h->reg);
    else as_cmp_rm(&m->a, r, BASER, SLOT(s));
}
void ms_test_false(Masm *m, int32_t s) {
    const Home *h = ms_home(m, s);
    if (is_xmm(h)) bug("a real tested as a bool", s, 0);
    if (h) as_cmp_ri(&m->a, h->reg, (int32_t)IMM(0));
    else as_cmp_mi(&m->a, BASER, SLOT(s), (int32_t)IMM(0));
}
void ms_bool_flags(Masm *m, int r) { as_cmp_ri(&m->a, r, (int32_t)IMM(0)); }
void ms_load_xmm(Masm *m, int xmm, int32_t s) {
    const Home *h = ms_home(m, s);
    if (h && !is_xmm(h)) { as_fmov_fr(&m->a, xmm, h->reg); return; }
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

/* ---- ints and words, on their words ---- */
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
void ms_two_words(Masm *m, int32_t x, int32_t y, AsmLabel *heap) {
    ms_load_bits(m, R_S0, x);
    ms_load_bits(m, R_S1, y);
    as_mov_rr(&m->a, R_S2, R_S0);
    as_and_rr(&m->a, R_S2, R_S1);
    as_test_ri(&m->a, R_S2, 1);
    as_jcc(&m->a, CC_E, heap);
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

/* ---- reals: Koka's encoding in the word, or a box (value.h) ---- */
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
/* the general homes first, so that the slow path of a real that must be
   boxed finds them in their slots */
static void writeback(Masm *m, uint32_t pc, int pushed) {
    if (!m->homes) return;
    for (uint32_t r = 0; r < m->nlocals; r++)
        if (m->homes[r].kind == HOME_GPR && live_at(m, pc, r)) home_to_slot(m, (int32_t)r, &m->homes[r]);
    for (uint32_t r = 0; r < m->nlocals; r++)
        if (m->homes[r].kind == HOME_XMM && live_at(m, pc, r)) real_to_slot(m, (int32_t)r, &m->homes[r], pushed, pc);
}
void ms_writeback(Masm *m, uint32_t pc) { writeback(m, pc, 0); }
/* The slow path of a real's write-back: the double has no immediate, and
   the helper boxes it into the slot. It may collect, so the VM is given
   its stack pointer, every live general home is in its slot (stored again
   here: ms_need_word comes with no write-back before it) and loaded
   again after, and the live reals, which C does not keep, wait in the VM. */
void ms_emit_box_real(Masm *m, Slow *sp) {
    Slow s = *sp;
    uint32_t live = s.n;
    for (uint32_t r = 0; r < m->nlocals; r++) {
        const Home *h = &m->homes[r];
        if (h->kind == HOME_GPR && live_at(m, live, r)) as_st64(&m->a, BASER, SLOT((int32_t)r), h->reg);
        if (h->kind == HOME_XMM && live_at(m, live, r)) as_fst(&m->a, VMR, OFF(jit_fspill) + 8 * (h->reg - F_H0), h->reg);
    }
    as_fst(&m->a, VMR, OFF(jit_fspill) + 8 * (s.b - F_H0), s.b);   /* the one to box, live or not */
    as_st32i(&m->a, VMR, OFF(pc), (int32_t)s.pc);
    as_lea(&m->a, R_S0, BASEI, -1, 1, (int32_t)(m->nlocals + (uint32_t)s.c));
    as_st64(&m->a, VMR, OFF(sp), R_S0);
    as_st64(&m->a, VMR, OFF(instructions), COUNTR);
    as_mov_ri(&m->a, ms_arg(m, 1), s.a);
    as_ld64(&m->a, ms_arg(m, 2), VMR, OFF(jit_fspill) + 8 * (s.b - F_H0));
    ms_call(m, (MsHelper)m->box_real);
    for (uint32_t r = 0; r < m->nlocals; r++) {
        const Home *h = &m->homes[r];
        if (h->kind == HOME_GPR && live_at(m, live, r)) as_ld64(&m->a, h->reg, BASER, SLOT((int32_t)r));
        if (h->kind == HOME_XMM && live_at(m, live, r)) as_fld(&m->a, h->reg, VMR, OFF(jit_fspill) + 8 * (h->reg - F_H0));
    }
    as_fld(&m->a, s.b, VMR, OFF(jit_fspill) + 8 * (s.b - F_H0));
    as_jmp(&m->a, &s.back);
}
void ms_reload_homes(Masm *m, uint32_t pc) {
    if (!m->homes) return;
    for (uint32_t r = 0; r < m->nlocals; r++)
        if (m->homes[r].kind != HOME_SLOT && live_at(m, pc, r)) slot_to_home(m, (int32_t)r, &m->homes[r]);
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
    as_cmp8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), kind);
    as_jcc(&m->a, CC_NE, unless);
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
    if (!trusted) { as_cmp8_mi(&m->a, r, (int32_t)offsetof(Obj, kind), K_CON); as_jcc(&m->a, CC_NE, unless); }
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
    as_ld64(&m->a, STACKR, VMR, OFF(stack));
    ms_frame(m, R_S1);
    as_ld64(&m->a, BASEI, R_S1, (int32_t)offsetof(Frame, base));
    as_mov_rr(&m->a, BASER, BASEI);
    as_shl_ri(&m->a, BASER, VALUE_SHIFT);
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
    uint32_t size = (uint32_t)obj_size_of(kind, n);
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
