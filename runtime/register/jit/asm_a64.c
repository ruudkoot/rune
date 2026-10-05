/* The portable assembler (asm.h) for aarch64, over the encoder (a64.h):
   x17 is the implementation's own register, x16 the encoder's. */
#include "asm.h"
#if JIT_TARGET == 2

void as_init(Asm *a) { a64_init(a); }
void as_free(Asm *a) { a64_free(a); }
void as_label_init(AsmLabel *l) { a64_label_init(l); }
void as_label_free(AsmLabel *l) { a64_label_free(l); }
void as_bind(Asm *a, AsmLabel *l) { a64_bind(a, l); }
int as_bound(const AsmLabel *l) { return a64_bound(l); }
int as_dangling(const AsmLabel *l) { return l->nfix > 0; }
void as_u32(Asm *a, uint32_t v) { a64_u32(a, v); }
void as_u64(Asm *a, uint64_t v) { a64_u64(a, v); }
void as_offset32_at(Asm *a, size_t at, size_t table_at, AsmLabel *l) { a64_offset32_at(a, at, table_at, l); }
size_t as_align4(Asm *a) { return a->n; }   /* every instruction is a word: it is aligned */

void as_mov_rr(Asm *a, int rd, int rs) { if (rd != rs) a64_mov_rr(a, rd, rs); }
void as_mov_ri(Asm *a, int rd, int64_t v) { a64_mov_ri(a, rd, v); }
void as_ld64(Asm *a, int rd, int base, int32_t disp) { a64_ldr(a, rd, base, disp); }
void as_ld32(Asm *a, int rd, int base, int32_t disp) { a64_ldr32(a, rd, base, disp); }
void as_ld32s(Asm *a, int rd, int base, int32_t disp) { a64_ldrsw(a, rd, base, disp); }
void as_ld32sx(Asm *a, int rd, int base, int index) { a64_ldrsw_rr(a, rd, base, index, 1); }
void as_ld16(Asm *a, int rd, int base, int32_t disp) { a64_ldrh(a, rd, base, disp); }
void as_ld8(Asm *a, int rd, int base, int32_t disp) { a64_ldrb(a, rd, base, disp); }
void as_st64(Asm *a, int base, int32_t disp, int rs) { a64_str(a, rs, base, disp); }
void as_st32(Asm *a, int base, int32_t disp, int rs) { a64_str32(a, rs, base, disp); }
void as_st8(Asm *a, int base, int32_t disp, int rs) { a64_strb(a, rs, base, disp); }
void as_st64i(Asm *a, int base, int32_t disp, int32_t v) { if (v == 0) a64_str(a, XZR, base, disp); else { a64_mov_ri(a, R_T, v); a64_str(a, R_T, base, disp); } }
void as_st32i(Asm *a, int base, int32_t disp, int32_t v) { if (v == 0) a64_str32(a, XZR, base, disp); else { a64_mov_ri(a, R_T, v); a64_str32(a, R_T, base, disp); } }
void as_st8i(Asm *a, int base, int32_t disp, int v) { if (v == 0) a64_strb(a, XZR, base, disp); else { a64_mov_ri(a, R_T, v); a64_strb(a, R_T, base, disp); } }
void as_lea(Asm *a, int rd, int base, int index, int scale, int32_t disp) {
    if (index >= 0) {
        int shift = scale == 8 ? 3 : scale == 4 ? 2 : scale == 2 ? 1 : 0;
        a64_add_rr_lsl(a, rd, base, index, shift);
        if (disp) a64_add_ri(a, rd, rd, disp);
    } else a64_add_ri(a, rd, base, disp);
}
void as_lea_label(Asm *a, int rd, AsmLabel *l) { a64_adr(a, rd, l); }
void as_ld128(Asm *a, int f, int base, int32_t disp) { a64_ldrq(a, f, base, disp); }
void as_st128(Asm *a, int base, int32_t disp, int f) { a64_strq(a, f, base, disp); }
void as_ld128x(Asm *a, int f, int base, int index) { a64_ldrq_rr(a, f, base, index); }
void as_st128x(Asm *a, int base, int index, int f) { a64_strq_rr(a, f, base, index); }

void as_add_rr(Asm *a, int rd, int rs) { a64_adds_rr(a, rd, rd, rs); }
void as_sub_rr(Asm *a, int rd, int rs) { a64_subs_rr(a, rd, rd, rs); }
void as_and_rr(Asm *a, int rd, int rs) { a64_and_rr(a, rd, rd, rs); }
void as_or_rr(Asm *a, int rd, int rs) { a64_orr_rr(a, rd, rd, rs); }
void as_xor_rr(Asm *a, int rd, int rs) { a64_eor_rr(a, rd, rd, rs); }
void as_cmp_rr(Asm *a, int ra, int rb) { a64_cmp_rr(a, ra, rb); }
void as_test_rr(Asm *a, int ra, int rb) { a64_tst_rr(a, ra, rb); }
void as_add_ri(Asm *a, int rd, int32_t v) { a64_adds_ri(a, rd, rd, v); }
void as_sub_ri(Asm *a, int rd, int32_t v) { a64_subs_ri(a, rd, rd, v); }
void as_cmp_ri(Asm *a, int r, int32_t v) { a64_cmp_ri(a, r, v); }
void as_and_ri(Asm *a, int rd, int32_t v) { a64_mov_ri(a, R_T, v); a64_and_rr(a, rd, rd, R_T); }
void as_or_ri(Asm *a, int rd, int32_t v) { a64_mov_ri(a, R_T, v); a64_orr_rr(a, rd, rd, R_T); }
/* a test of the low bits -- a tag's, of bit 0, is the commonest
   instruction the code has -- is one instruction: the mask is an
   immediate the machine has */
void as_test_ri(Asm *a, int r, int32_t v) {
    for (int bits = 1; bits < 32; bits++)
        if (v == (int32_t)(((uint32_t)1 << bits) - 1)) { a64_tst_mask(a, r, bits); return; }
    a64_mov_ri(a, R_T, v); a64_tst_rr(a, r, R_T);
}
void as_test8_mi(Asm *a, int base, int32_t disp, int v) { a64_ldrb(a, R_T, base, disp); a64_mov_ri(a, X16, v); a64_tst_rr(a, R_T, X16); }
void as_ror_ri(Asm *a, int r, int n) { a64_ror_ri(a, r, r, n); }
/* after adds the carry is set where the sum went past 64 bits; after subs it is clear where it borrowed */
void as_add_jc(Asm *a, int rd, int rs, AsmLabel *carry) { a64_adds_rr(a, rd, rd, rs); a64_bcond(a, A64_HS, carry); }
void as_sub_jb(Asm *a, int rd, int rs, AsmLabel *borrow) { a64_subs_rr(a, rd, rd, rs); a64_bcond(a, A64_LO, borrow); }
void as_mul_rr(Asm *a, int rd, int rs) { a64_mul(a, rd, rd, rs); }
void as_mul_ri(Asm *a, int rd, int rs, int32_t v) { a64_mov_ri(a, R_T, v); a64_mul(a, rd, rs, R_T); }
void as_mul_jo(Asm *a, int rd, int rs, AsmLabel *overflow) {
    /* the high half of the product against the sign of the low: not the
       same, and the product does not fit */
    a64_smulh(a, R_T, rd, rs);
    a64_mul(a, rd, rd, rs);
    a64_cmp_rr_asr(a, R_T, rd, 63);
    a64_bcond(a, A64_NE, overflow);
}
void as_neg(Asm *a, int r) { a64_subs_rr(a, r, XZR, r); }
void as_not(Asm *a, int r) { a64_orn_rr(a, r, XZR, r); }
void as_shl_ri(Asm *a, int r, int n) { a64_lsl_ri(a, r, r, n); }
void as_shr_ri(Asm *a, int r, int n) { a64_lsr_ri(a, r, r, n); }
void as_sar_ri(Asm *a, int r, int n) { a64_asr_ri(a, r, r, n); }
void as_shl_rr(Asm *a, int r) { a64_lslv(a, r, r, R_S1); }
void as_shr_rr(Asm *a, int r) { a64_lsrv(a, r, r, R_S1); }
void as_divmod(Asm *a, int divisor) {
    a64_sdiv(a, R_T, R_S0, divisor);
    a64_msub(a, R_S2, R_T, divisor, R_S0);
    a64_mov_rr(a, R_S0, R_T);
}
void as_udivmod(Asm *a, int divisor) {
    a64_udiv(a, R_T, R_S0, divisor);
    a64_msub(a, R_S2, R_T, divisor, R_S0);
    a64_mov_rr(a, R_S0, R_T);
}
void as_add_mi(Asm *a, int base, int32_t disp, int32_t v) { a64_ldr(a, R_T, base, disp); a64_add_ri(a, R_T, R_T, v); a64_str(a, R_T, base, disp); }
void as_add_rm(Asm *a, int rd, int base, int32_t disp) { a64_ldr(a, R_T, base, disp); a64_add_rr(a, rd, rd, R_T); }
void as_cmp_rm(Asm *a, int r, int base, int32_t disp) { a64_ldr(a, R_T, base, disp); a64_cmp_rr(a, r, R_T); }
void as_cmp_mi(Asm *a, int base, int32_t disp, int32_t v) { a64_ldr(a, R_T, base, disp); a64_cmp_ri(a, R_T, v); }
void as_cmp8_mi(Asm *a, int base, int32_t disp, int v) { a64_ldrb(a, R_T, base, disp); a64_cmp_ri(a, R_T, v); }
void as_cmp32_mi(Asm *a, int base, int32_t disp, int32_t v) { a64_ldr32(a, R_T, base, disp); a64_cmp_ri(a, R_T, v); }

static int cond(int cc) { return cc == CC_FA ? A64_GT : cc == CC_FAE ? A64_GE : cc == CC_FE ? A64_EQ : cc; }
void as_jmp(Asm *a, AsmLabel *l) { a64_b(a, l); }
void as_jcc(Asm *a, int cc, AsmLabel *l) { a64_bcond(a, cond(cc), l); }
void as_jmp_r(Asm *a, int r) { a64_br(a, r); }
void as_jmp_to(Asm *a, const void *at) { a64_b_to(a, at); }
void as_call_r(Asm *a, int r) { a64_blr(a, r); }
void as_ret(Asm *a) { a64_ret(a); }
void as_trap(Asm *a) { a64_brk(a); }
void as_setcc(Asm *a, int rd, int cc) { a64_cset(a, rd, cond(cc)); }
void as_push(Asm *a, int r) { a64_push(a, r); }
void as_pop(Asm *a, int r) { a64_pop(a, r); }

void as_fld(Asm *a, int f, int base, int32_t disp) { a64_ldrd(a, f, base, disp); }
void as_fst(Asm *a, int base, int32_t disp, int f) { a64_strd(a, f, base, disp); }
void as_fmov(Asm *a, int fd, int fs) { if (fd != fs) a64_fmov_dd(a, fd, fs); }
void as_fadd(Asm *a, int fd, int fs) { a64_fadd(a, fd, fd, fs); }
void as_fsub(Asm *a, int fd, int fs) { a64_fsub(a, fd, fd, fs); }
void as_fmul(Asm *a, int fd, int fs) { a64_fmul(a, fd, fd, fs); }
void as_fdiv(Asm *a, int fd, int fs) { a64_fdiv(a, fd, fd, fs); }
void as_fsqrt(Asm *a, int fd, int fs) { a64_fsqrt(a, fd, fs); }
void as_fcmp(Asm *a, int fa, int fb) { a64_fcmp(a, fa, fb); }
void as_fzero(Asm *a, int f) { a64_fmov_dz(a, f); }
void as_cvt_i2f(Asm *a, int f, int r) { a64_scvtf(a, f, r); }
void as_cvt_f2i(Asm *a, int r, int f, AsmLabel *unless) {
    a64_fcmp(a, f, f);              /* unordered with itself: a NaN, which fcvtzs makes 0 */
    a64_bcond(a, A64_VS, unless);
    a64_fcvtzs(a, r, f);            /* saturates past 64 bits: INT64_MIN or INT64_MAX */
}
void as_fmov_rf(Asm *a, int r, int f) { a64_fmov_xd(a, r, f); }
void as_fmov_fr(Asm *a, int f, int r) { a64_fmov_dx(a, f, r); }

/* AAPCS64: C keeps x19 to x28, x29 (the frame pointer), x30 (the return
   address) and the low halves of v8 to v15, all of which the code uses:
   saved in pairs, 112 bytes, the stack 16-aligned throughout */
void as_stub_enter(Asm *a, int win) {
    (void)win;
    a64_stp_pre(a, X29, X30, XSP, -112);
    a64_stp(a, X19, X20, XSP, 16);
    a64_stp(a, X21, X22, XSP, 32);
    a64_stp(a, X23, X24, XSP, 48);
    a64_stp(a, X25, X26, XSP, 64);
    a64_stp(a, X27, X28, XSP, 80);
    a64_stpd(a, V8, V9, XSP, 96);
    a64_sub_ri(a, XSP, XSP, 48);
    a64_stpd(a, V10, V11, XSP, 0);
    a64_stpd(a, V12, V13, XSP, 16);
    a64_stpd(a, V14, V15, XSP, 32);
    a64_mov_rr(a, R_GO, X1);     /* where to go */
    a64_mov_rr(a, R_VM, X0);
}
void as_stub_leave(Asm *a, int win) {
    (void)win;
    a64_ldpd(a, V10, V11, XSP, 0);
    a64_ldpd(a, V12, V13, XSP, 16);
    a64_ldpd(a, V14, V15, XSP, 32);
    a64_add_ri(a, XSP, XSP, 48);
    a64_ldpd(a, V8, V9, XSP, 96);
    a64_ldp(a, X27, X28, XSP, 80);
    a64_ldp(a, X25, X26, XSP, 64);
    a64_ldp(a, X23, X24, XSP, 48);
    a64_ldp(a, X21, X22, XSP, 32);
    a64_ldp(a, X19, X20, XSP, 16);
    a64_ldp_post(a, X29, X30, XSP, 112);
    a64_ret(a);
}
int as_arg(int win, int i) { (void)win; return X0 + i; }
void as_call_c(Asm *a, int win, uint64_t addr) {
    (void)win;
    a64_mov_ri(a, X16, (int64_t)addr);
    a64_blr(a, X16);
}

#endif
