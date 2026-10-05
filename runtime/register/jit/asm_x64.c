/* The portable assembler (asm.h) for x86-64: each operation is the
   encoder's, but for the few the conventions of asm.h shape. */
#include "asm.h"
/* also the build of a machine the JIT does not run on (JIT_TARGET 0: a
   32-bit x86, PowerPC), where the emitters are compiled and never
   called, as x64.c always was */
#if JIT_TARGET != 2

void as_init(Asm *a) { x64_init(a); }
void as_free(Asm *a) { x64_free(a); }
void as_label_init(AsmLabel *l) { x64_label_init(l); }
void as_label_free(AsmLabel *l) { x64_label_free(l); }
void as_bind(Asm *a, AsmLabel *l) { x64_bind(a, l); }
int as_bound(const AsmLabel *l) { return x64_bound(l); }
int as_dangling(const AsmLabel *l) { return l->nrefs > 0; }
void as_u32(Asm *a, uint32_t v) { x64_u32(a, v); }
void as_u64(Asm *a, uint64_t v) { x64_u64(a, v); }
void as_offset32_at(Asm *a, size_t at, size_t table_at, AsmLabel *l) { x64_offset32_at(a, at, table_at, l); }
size_t as_align4(Asm *a) { return a->n; }

void as_mov_rr(Asm *a, int rd, int rs) { x64_mov_rr(a, rd, rs); }
void as_mov_ri(Asm *a, int rd, int64_t v) { x64_mov_ri(a, rd, v); }
void as_ld64(Asm *a, int rd, int base, int32_t disp) { x64_mov_rm(a, rd, base, disp); }
void as_ld32(Asm *a, int rd, int base, int32_t disp) { x64_mov32_rm(a, rd, base, disp); }
void as_ld32s(Asm *a, int rd, int base, int32_t disp) { x64_movsxd_rmi(a, rd, base, -1, 1, disp); }
void as_ld32sx(Asm *a, int rd, int base, int index) { x64_movsxd_rmi(a, rd, base, index, 4, 0); }
void as_ld16(Asm *a, int rd, int base, int32_t disp) { x64_movzx16_rm(a, rd, base, disp); }
void as_ld8(Asm *a, int rd, int base, int32_t disp) { x64_movzx8_rm(a, rd, base, disp); }
void as_st64(Asm *a, int base, int32_t disp, int rs) { x64_mov_mr(a, base, disp, rs); }
void as_st32(Asm *a, int base, int32_t disp, int rs) { x64_mov32_mr(a, base, disp, rs); }
void as_st8(Asm *a, int base, int32_t disp, int rs) { x64_mov8_mr(a, base, disp, rs); }
void as_st64i(Asm *a, int base, int32_t disp, int32_t v) { x64_mov_mi(a, base, disp, v); }
void as_st32i(Asm *a, int base, int32_t disp, int32_t v) { x64_mov32_mi(a, base, disp, v); }
void as_st8i(Asm *a, int base, int32_t disp, int v) { x64_mov8_mi(a, base, disp, v); }
void as_lea(Asm *a, int rd, int base, int index, int scale, int32_t disp) { x64_lea(a, rd, base, index, scale, disp); }
void as_lea_label(Asm *a, int rd, AsmLabel *l) { x64_lea_rip(a, rd, l); }
void as_ld128(Asm *a, int f, int base, int32_t disp) { x64_movups_xm(a, f, base, disp); }
void as_st128(Asm *a, int base, int32_t disp, int f) { x64_movups_mx(a, base, disp, f); }
void as_ld128x(Asm *a, int f, int base, int index) { x64_movups_xmi(a, f, base, index, 1, 0); }
void as_st128x(Asm *a, int base, int index, int f) { x64_movups_mix(a, base, index, 1, 0, f); }

void as_add_rr(Asm *a, int rd, int rs) { x64_add_rr(a, rd, rs); }
void as_sub_rr(Asm *a, int rd, int rs) { x64_sub_rr(a, rd, rs); }
void as_and_rr(Asm *a, int rd, int rs) { x64_and_rr(a, rd, rs); }
void as_or_rr(Asm *a, int rd, int rs) { x64_or_rr(a, rd, rs); }
void as_xor_rr(Asm *a, int rd, int rs) { x64_xor_rr(a, rd, rs); }
void as_cmp_rr(Asm *a, int ra, int rb) { x64_cmp_rr(a, ra, rb); }
void as_test_rr(Asm *a, int ra, int rb) { x64_test_rr(a, ra, rb); }
void as_add_ri(Asm *a, int rd, int32_t v) { x64_add_ri(a, rd, v); }
void as_sub_ri(Asm *a, int rd, int32_t v) { x64_sub_ri(a, rd, v); }
void as_cmp_ri(Asm *a, int r, int32_t v) { x64_cmp_ri(a, r, v); }
void as_and_ri(Asm *a, int rd, int32_t v) { x64_and_ri(a, rd, v); }
void as_or_ri(Asm *a, int rd, int32_t v) { x64_or_ri(a, rd, v); }
void as_test_ri(Asm *a, int r, int32_t v) { x64_test_ri(a, r, v); }
void as_test8_mi(Asm *a, int base, int32_t disp, int v) { x64_test8_mi(a, base, disp, v); }
void as_ror_ri(Asm *a, int r, int n) { x64_ror_ri(a, r, n); }
void as_add_jc(Asm *a, int rd, int rs, AsmLabel *carry) { x64_add_rr(a, rd, rs); x64_jcc(a, CC_B, carry); }
void as_sub_jb(Asm *a, int rd, int rs, AsmLabel *borrow) { x64_sub_rr(a, rd, rs); x64_jcc(a, CC_B, borrow); }
void as_mul_rr(Asm *a, int rd, int rs) { x64_imul_rr(a, rd, rs); }
void as_mul_ri(Asm *a, int rd, int rs, int32_t v) { x64_imul_rri(a, rd, rs, v); }
void as_mul_jo(Asm *a, int rd, int rs, AsmLabel *overflow) { x64_imul_rr(a, rd, rs); x64_jcc(a, CC_O, overflow); }
void as_neg(Asm *a, int r) { x64_neg_r(a, r); }
void as_not(Asm *a, int r) { x64_not_r(a, r); }
void as_shl_ri(Asm *a, int r, int n) { x64_shl_ri(a, r, n); }
void as_shr_ri(Asm *a, int r, int n) { x64_shr_ri(a, r, n); }
void as_sar_ri(Asm *a, int r, int n) { x64_sar_ri(a, r, n); }
void as_shl_rr(Asm *a, int r) { x64_shl_rcl(a, r); }
void as_shr_rr(Asm *a, int r) { x64_shr_rcl(a, r); }
void as_divmod(Asm *a, int divisor) { x64_cqo(a); x64_idiv_r(a, divisor); }
void as_udivmod(Asm *a, int divisor) { x64_xor_rr(a, RDX, RDX); x64_div_r(a, divisor); }
void as_add_mi(Asm *a, int base, int32_t disp, int32_t v) { x64_add_mi(a, base, disp, v); }
void as_add_rm(Asm *a, int rd, int base, int32_t disp) { x64_add_rm(a, rd, base, disp); }
void as_cmp_rm(Asm *a, int r, int base, int32_t disp) { x64_cmp_rm(a, r, base, disp); }
void as_cmp_mi(Asm *a, int base, int32_t disp, int32_t v) { x64_cmp_mi(a, base, disp, v); }
void as_cmp8_mi(Asm *a, int base, int32_t disp, int v) { x64_cmp8_mi(a, base, disp, v); }
void as_cmp32_mi(Asm *a, int base, int32_t disp, int32_t v) { x64_cmp32_mi(a, base, disp, v); }

void as_jmp(Asm *a, AsmLabel *l) { x64_jmp(a, l); }
void as_jcc(Asm *a, int cc, AsmLabel *l) {
    if (cc == CC_FE) {   /* equal and ordered: not parity */
        X64Label no; x64_label_init(&no);
        x64_jcc(a, CC_P, &no);
        x64_jcc(a, CC_E, l);
        x64_bind(a, &no);
        x64_label_free(&no);
        return;
    }
    x64_jcc(a, cc, l);
}
void as_jmp_r(Asm *a, int r) { x64_jmp_r(a, r); }
void as_jmp_to(Asm *a, const void *at) { x64_jmp_to(a, at); }
void as_call_to(Asm *a, const void *at) { x64_call_to(a, at); }
void as_call_r(Asm *a, int r) { x64_call_r(a, r); }
void as_ret(Asm *a) { x64_ret(a); }
void as_trap(Asm *a) { x64_int3(a); }
void as_setcc(Asm *a, int rd, int cc) {
    if (cc == CC_FE) {   /* equal and ordered: the two bits, and R_S6 for the second */
        x64_setcc_r8(a, CC_E, rd);
        x64_setcc_r8(a, CC_NP, R_S6);
        x64_movzx8_rr(a, rd, rd);
        x64_movzx8_rr(a, R_S6, R_S6);
        x64_and_rr(a, rd, R_S6);
        return;
    }
    x64_setcc_r8(a, cc, rd);
    x64_movzx8_rr(a, rd, rd);
}
#ifdef RUNE_JIT_CONV
void as_count(Asm *a, uint64_t *counter) {
    x64_push_r(a, RAX); x64_push_r(a, RCX);
    x64_mov_ri(a, RAX, (int64_t)(intptr_t)counter);
    x64_mov_rm(a, RCX, RAX, 0);
    x64_lea(a, RCX, RCX, -1, 1, 1);
    x64_mov_mr(a, RAX, 0, RCX);
    x64_pop_r(a, RCX); x64_pop_r(a, RAX);
}
#endif
void as_push(Asm *a, int r) { x64_push_r(a, r); x64_sub_ri(a, RSP, 8); }
void as_pop(Asm *a, int r) { x64_add_ri(a, RSP, 8); x64_pop_r(a, r); }

void as_fld(Asm *a, int f, int base, int32_t disp) { x64_movsd_xm(a, f, base, disp); }
void as_fst(Asm *a, int base, int32_t disp, int f) { x64_movsd_mx(a, base, disp, f); }
void as_fmov(Asm *a, int fd, int fs) { x64_movaps_xx(a, fd, fs); }
void as_fadd(Asm *a, int fd, int fs) { x64_addsd(a, fd, fs); }
void as_fsub(Asm *a, int fd, int fs) { x64_subsd(a, fd, fs); }
void as_fmul(Asm *a, int fd, int fs) { x64_mulsd(a, fd, fs); }
void as_fdiv(Asm *a, int fd, int fs) { x64_divsd(a, fd, fs); }
void as_fsqrt(Asm *a, int fd, int fs) { x64_sqrtsd(a, fd, fs); }
void as_fcmp(Asm *a, int fa, int fb) { x64_ucomisd(a, fa, fb); }
void as_fzero(Asm *a, int f) { x64_xorpd(a, f, f); }
void as_cvt_i2f(Asm *a, int f, int r) { x64_cvtsi2sd(a, f, r); }
void as_cvt_f2i(Asm *a, int r, int f, AsmLabel *unless) { (void)unless; x64_cvttsd2si(a, r, f); }
void as_fmov_rf(Asm *a, int r, int f) { x64_movq_rx(a, r, f); }
void as_fmov_fr(Asm *a, int f, int r) { x64_movq_xr(a, f, r); }

/* the Windows convention has C keep xmm6 to xmm15, which the homes use:
   saved by the enter stub below its pushes (160 bytes) */
#define WIN_XMM_SAVE 160
void as_stub_enter(Asm *a, int win) {
    x64_push_r(a, RBP); x64_push_r(a, RBX); x64_push_r(a, R12);
    x64_push_r(a, R13); x64_push_r(a, R14); x64_push_r(a, R15);
    if (win) {
        x64_push_r(a, RDI); x64_push_r(a, RSI);
        x64_sub_ri(a, RSP, 8 + WIN_XMM_SAVE);
        for (int i = 6; i < 16; i++) x64_movups_mx(a, RSP, 16 * (i - 6), XMM0 + i);
    } else x64_sub_ri(a, RSP, 8);
    x64_mov_rr(a, R_GO, win ? RDX : RSI);     /* where to go */
    x64_mov_rr(a, R_VM, win ? RCX : RDI);
}
void as_stub_leave(Asm *a, int win) {
    if (win) {
        for (int i = 6; i < 16; i++) x64_movups_xm(a, XMM0 + i, RSP, 16 * (i - 6));
        x64_add_ri(a, RSP, 8 + WIN_XMM_SAVE);
        x64_pop_r(a, RSI); x64_pop_r(a, RDI);
    } else x64_add_ri(a, RSP, 8);
    x64_pop_r(a, R15); x64_pop_r(a, R14); x64_pop_r(a, R13);
    x64_pop_r(a, R12); x64_pop_r(a, RBX); x64_pop_r(a, RBP);
    x64_ret(a);
}
int as_arg(int win, int i) {
    static const int sysv[4] = { RDI, RSI, RDX, RCX };
    static const int winr[4] = { RCX, RDX, R8, R9 };
    return win ? winr[i] : sysv[i];
}
/* A trampoline: the code's region is far from C's, out of reach of a
   rel32, so a call of C there is the VM moved to the first argument, a
   64-bit address in a register and an indirect call, fifteen bytes, and
   on Windows eight more for the space its convention gives the callee.
   A call of the trampoline is five: it moves the VM, and on Linux jumps
   on through the address beside it, C returning to the caller; on
   Windows it makes the space and the call itself. */
size_t as_trampoline(Asm *a, int win, uint64_t addr) {
    while (a->n % 16) x64_byte(a, 0xCC);
    size_t at = a->n;
    x64_mov_rr(a, as_arg(win, 0), R_VM);                        /* 3 bytes */
    if (!win) {
        x64_byte(a, 0xFF); x64_byte(a, 0x25); x64_u32(a, 0);   /* jmp [rip + 0]: the address that follows, at 9 */
        x64_u64(a, addr);
    } else {
        x64_sub_ri(a, RSP, 40);                                 /* 32 for the callee, 8 to align: a call pushed 8 */
        x64_byte(a, 0xFF); x64_byte(a, 0x15); x64_u32(a, 11);  /* call [rip + 11]: from 13, the address at 24 */
        x64_add_ri(a, RSP, 40);
        x64_ret(a);
        while (a->n - at < 24) x64_byte(a, 0xCC);
        x64_u64(a, addr);
    }
    return at;
}
void as_call_c(Asm *a, int win, uint64_t addr) {
    x64_mov_ri(a, RAX, (int64_t)addr);
    if (win) x64_sub_ri(a, RSP, 32);
    x64_call_r(a, RAX);
    if (win) x64_add_ri(a, RSP, 32);
}

#endif
