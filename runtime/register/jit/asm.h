/* The portable assembler of runtime/register's JIT (docs/plans/jit.md, M12): the
   operations the macro-assembler (masm.h) and the emitters (emit.c) are
   written in, with one implementation per target -- x86-64 over x64.h
   (asm_x64.c), aarch64 over a64.h (asm_a64.c). The names of the
   registers the code keeps, of its scratch registers and of the
   conditions are the target's numbers under portable names, so that an
   emitter says R_S0 and means rax or x0.

   What the operations promise, on every target:
   * add, sub, cmp, test and neg set the flags a following jcc or setcc
     reads; and, or, xor, the shifts, mul and the moves leave the flags
     undefined -- an emitter that wants them tests again.
   * a memory operand is [base + disp], or [base + index * scale + disp]
     for lea, and [base + index] for the 16-byte moves; disp is 32-bit.
   * an immediate of a move is 64-bit; of the arithmetic 32-bit, signed.
   * as_shl_rr and as_shr_rr take the count in R_S1.
   * as_divmod takes the dividend in R_S0 and leaves the quotient there
     and the remainder in R_S2; a divisor of 0 or -1 is the emitter's to
     test first.
   * as_mul_jo multiplies and jumps where the product overflowed.
   * as_setcc gives 0 or 1 in the whole register; with CC_FE on x86-64 it
     uses R_S6 too.
   * as_push and as_pop move the stack by 16, so that it stays aligned.
   * R_T (x86-64: none needed; aarch64: x17) is the implementation's own,
     and x16 the aarch64 encoder's: no emitter names them.
   The stubs, the arguments of a call into C and what a call clobbers are
   the target's, in masm.c under JIT_TARGET. */
#ifndef RUNE_JIT_ASM_H
#define RUNE_JIT_ASM_H

#include <stddef.h>
#include <stdint.h>

#ifndef JIT_TARGET
#if defined(__x86_64__) || defined(_M_X64)
#define JIT_TARGET 1
#elif defined(__aarch64__)
#define JIT_TARGET 2
#else
#define JIT_TARGET 0
#endif
#endif

#if JIT_TARGET == 2
#include "a64.h"
typedef A64 Asm;
typedef A64Label AsmLabel;
enum AsmReg {
    R_VM = X19, R_BASEI = X21, R_BASER = X22, R_COUNT = X23,
    R_H1 = X25, R_H2 = X26,   /* two homes that emit.c's calls name as scratch, once no home is live */
    R_S0 = X0, R_S1 = X9, R_S2 = X10, R_S3 = X11, R_S4 = X12, R_S5 = X13, R_S6 = X14,
    R_T = X17, R_SP = XSP, R_GO = X27   /* R_GO: where the enter stub is to jump, kept across its reload */
};
enum AsmFReg { F_S0 = V0, F_S1 = V1 };
/* Tier 2's homes, in the order they are given out: the registers C keeps
   first. General: x24 to x26, x20, x28 and x27 (R_GO, which the enter
   stub alone uses, before any home is loaded), then six that a call into
   C clobbers, x15 and x4 to x8 -- no emitter names them, and C's
   arguments here are x0 to x3. Reals: v8 to v15, whose doubles C keeps,
   then v16 to v31 and v2 to v7. */
#define AS_NHOMES_G 12
#define AS_NHOMES_F 30
static inline int as_home_g(int win, int k) {
    static const uint8_t homes[AS_NHOMES_G] = { X24, X25, X26, X20, X28, X27, X15, X4, X5, X6, X7, X8 };
    (void)win;
    return homes[k];
}
static inline int as_home_f(int win, int k) { (void)win; return k < 24 ? V8 + k : V2 + (k - 24); }
/* what a call into C keeps (AAPCS64): x19 to x28, and the low halves of v8 to v15 */
static inline int as_keeps_g(int win, int r) { (void)win; return r >= X19 && r <= X28; }
static inline int as_keeps_f(int win, int f) { (void)win; return f >= V8 && f <= V15; }
enum AsmCond {
    CC_E = A64_EQ, CC_NE = A64_NE, CC_L = A64_LT, CC_LE = A64_LE, CC_G = A64_GT, CC_GE = A64_GE,
    CC_B = A64_LO, CC_BE = A64_LS, CC_A = A64_HI, CC_AE = A64_HS, CC_O = A64_VS, CC_NO = A64_VC,
    CC_S = A64_MI, CC_NS = A64_PL,
    CC_FA = 16, CC_FAE = 17, CC_FE = 18   /* after as_fcmp: above, above or equal, equal; false on a NaN */
};
#else
#ifdef RUNE_ASM_TEXT
/* the text backend (asm_text.h): x86-64's names and conditions, the code
   as lines of assembler for runeopt's templates */
#include "x64.h"
#include "asm_text.h"
typedef AsmText Asm;
typedef AsmTextLabel AsmLabel;
#else
#include "x64.h"
typedef X64 Asm;
typedef X64Label AsmLabel;
#endif
/* The VM is in r13 and not in r12: a memory operand whose base is r12
   (or rsp) is a byte longer, and nearly everything the code reads of the
   VM is one; r13 as a base costs a displacement, which a field of the VM
   has anyway. (runeopt's code keeps its VM in r12 and its stack in r13,
   src/opt/x64.sml, and the text backend writes its templates so.) */
enum AsmReg {
#ifdef RUNE_ASM_TEXT
    R_VM = R12,
#else
    R_VM = R13,
#endif
    R_BASEI = RBP, R_BASER = R14, R_COUNT = R15,
    R_H1 = RSI, R_H2 = RDI,   /* two homes that emit.c's calls name as scratch, once no home is live */
    R_S0 = RAX, R_S1 = RCX, R_S2 = RDX, R_S3 = R8, R_S4 = R9, R_S5 = R10, R_S6 = R11,   /* R_S4 and R_S5 are homes too */
    R_T = R11, R_SP = RSP, R_GO = R11
};
enum AsmFReg { F_S0 = XMM0, F_S1 = XMM1 };
enum AsmCondMore { CC_FA = CC_A, CC_FAE = CC_AE, CC_FE = 16 };
/* Tier 2's homes, in the order they are given out, by the convention of
   the calls into C (win: Windows's). General: rbx and r12, which C keeps
   everywhere; rsi and rdi, which Windows's C keeps and Linux's takes its
   first two arguments in; r10; and r9, Windows's fourth argument. Reals:
   Linux's C keeps none, and xmm2 to xmm7 are a byte shorter to name than
   xmm8 to xmm15; Windows's keeps xmm6 to xmm15, so those first there. */
#define AS_NHOMES_G 6
#define AS_NHOMES_F 14
static inline int as_home_g(int win, int k) {
    static const uint8_t homes[AS_NHOMES_G] = { RBX, R12, RSI, RDI, R10, R9 };
    (void)win;
    return homes[k];
}
static inline int as_home_f(int win, int k) { return !win ? XMM2 + k : k < 10 ? XMM6 + k : XMM2 + (k - 10); }
/* what a call into C keeps: rbx, rbp and r12 to r15, and on Windows rsi,
   rdi and xmm6 to xmm15 too */
static inline int as_keeps_g(int win, int r) { return r == RBX || r == RBP || (r >= R12 && r <= R15) || (win && (r == RSI || r == RDI)); }
static inline int as_keeps_f(int win, int f) { return win && f >= XMM6; }
#endif
/* The homes of tier 2 (compile.c gives them out, masm.c saves them) are
   the target's, above: as_home_g and as_home_f say which register the
   kth is, and as_keeps_g and as_keeps_f which registers a call into C
   leaves as they were -- a home in one is not loaded again after such a
   call. A general home is a register no emitter uses as scratch while a
   home is live: R_S0 to R_S3 and R_S6 are scratch anywhere, and R_S4,
   R_S5, R_H1 and R_H2 only where an instruction has read its last home
   and no slow path of it is still to come (emit.c's calls, after the
   argument is stored). */

void as_init(Asm *a);
void as_free(Asm *a);
void as_label_init(AsmLabel *l);
void as_label_free(AsmLabel *l);
void as_bind(Asm *a, AsmLabel *l);
int as_bound(const AsmLabel *l);
int as_dangling(const AsmLabel *l);                          /* referred to and never bound: the code is not to be used */
void as_u32(Asm *a, uint32_t v);
void as_u64(Asm *a, uint64_t v);
void as_offset32_at(Asm *a, size_t at, size_t table_at, AsmLabel *l);
size_t as_align4(Asm *a);                                   /* the buffer padded to a multiple of 4 (a table on aarch64); its offset */

void as_mov_rr(Asm *a, int rd, int rs);
void as_mov_ri(Asm *a, int rd, int64_t v);
void as_ld64(Asm *a, int rd, int base, int32_t disp);
void as_ld32(Asm *a, int rd, int base, int32_t disp);       /* zero-extended */
void as_ld32s(Asm *a, int rd, int base, int32_t disp);      /* sign-extended */
void as_ld32sx(Asm *a, int rd, int base, int index);        /* rd := [base + 4 * index], sign-extended: a table's entry */
void as_ld16(Asm *a, int rd, int base, int32_t disp);       /* zero-extended */
void as_ld8(Asm *a, int rd, int base, int32_t disp);        /* zero-extended */
void as_st64(Asm *a, int base, int32_t disp, int rs);
void as_st32(Asm *a, int base, int32_t disp, int rs);
void as_st8(Asm *a, int base, int32_t disp, int rs);
void as_st64i(Asm *a, int base, int32_t disp, int32_t v);   /* sign-extended to 64 bits */
void as_st32i(Asm *a, int base, int32_t disp, int32_t v);
void as_st8i(Asm *a, int base, int32_t disp, int v);
void as_lea(Asm *a, int rd, int base, int index, int scale, int32_t disp);   /* index -1: none; scale 1, 2, 4, 8 */
void as_lea_label(Asm *a, int rd, AsmLabel *l);
void as_ld128(Asm *a, int f, int base, int32_t disp);
void as_st128(Asm *a, int base, int32_t disp, int f);
void as_ld128x(Asm *a, int f, int base, int index);
void as_st128x(Asm *a, int base, int index, int f);

void as_add_rr(Asm *a, int rd, int rs);
void as_sub_rr(Asm *a, int rd, int rs);
void as_and_rr(Asm *a, int rd, int rs);
void as_or_rr(Asm *a, int rd, int rs);
void as_xor_rr(Asm *a, int rd, int rs);
void as_cmp_rr(Asm *a, int ra, int rb);
void as_test_rr(Asm *a, int ra, int rb);
void as_add_ri(Asm *a, int rd, int32_t v);
void as_sub_ri(Asm *a, int rd, int32_t v);
void as_cmp_ri(Asm *a, int r, int32_t v);
void as_and_ri(Asm *a, int rd, int32_t v);                  /* flags undefined, as and */
void as_or_ri(Asm *a, int rd, int32_t v);
void as_test_ri(Asm *a, int r, int32_t v);                  /* the flags of r & v, for CC_E and CC_NE */
void as_test8_mi(Asm *a, int base, int32_t disp, int v);    /* the flags of the byte at [base + disp] & v */
void as_ror_ri(Asm *a, int r, int n);                       /* rotate right by n, 1 to 63 */
void as_add_jc(Asm *a, int rd, int rs, AsmLabel *carry);    /* rd += rs; to carry where the sum, unsigned, is past 64 bits */
void as_sub_jb(Asm *a, int rd, int rs, AsmLabel *borrow);   /* rd -= rs; to borrow where rd, unsigned, was below rs */
void as_mul_rr(Asm *a, int rd, int rs);
void as_mul_ri(Asm *a, int rd, int rs, int32_t v);
void as_mul_jo(Asm *a, int rd, int rs, AsmLabel *overflow);
void as_neg(Asm *a, int r);
void as_not(Asm *a, int r);
void as_shl_ri(Asm *a, int r, int n);
void as_shr_ri(Asm *a, int r, int n);
void as_sar_ri(Asm *a, int r, int n);
void as_shl_rr(Asm *a, int r);                              /* by R_S1 */
void as_shr_rr(Asm *a, int r);
void as_divmod(Asm *a, int divisor);                        /* signed: R_S0 / divisor, R_S0 % divisor into R_S2 */
void as_udivmod(Asm *a, int divisor);
void as_add_mi(Asm *a, int base, int32_t disp, int32_t v);
void as_add_rm(Asm *a, int rd, int base, int32_t disp);
void as_cmp_rm(Asm *a, int r, int base, int32_t disp);
void as_cmp_mi(Asm *a, int base, int32_t disp, int32_t v);
void as_cmp8_mi(Asm *a, int base, int32_t disp, int v);
void as_cmp32_mi(Asm *a, int base, int32_t disp, int32_t v);

void as_jmp(Asm *a, AsmLabel *l);
void as_jcc(Asm *a, int cc, AsmLabel *l);
void as_jmp_r(Asm *a, int r);
void as_jmp_to(Asm *a, const void *at);
void as_call_to(Asm *a, const void *at);                    /* a call of code at an address the code reaches: its region's */
size_t as_trampoline(Asm *a, int win, uint64_t addr);       /* here, aligned: code that a call of it makes a call of C's addr with R_VM its first argument, by the convention; its offset */
void as_call_r(Asm *a, int r);
void as_ret(Asm *a);
void as_trap(Asm *a);
void as_setcc(Asm *a, int rd, int cc);
#ifdef RUNE_JIT_CONV
void as_count(Asm *a, uint64_t *counter);   /* *counter += 1; every register and the flags kept (a measuring build's; x86-64) */
#endif
void as_push(Asm *a, int r);
void as_pop(Asm *a, int r);

void as_fld(Asm *a, int f, int base, int32_t disp);         /* a double */
void as_fst(Asm *a, int base, int32_t disp, int f);
void as_fmov(Asm *a, int fd, int fs);
void as_fadd(Asm *a, int fd, int fs);
void as_fsub(Asm *a, int fd, int fs);
void as_fmul(Asm *a, int fd, int fs);
void as_fdiv(Asm *a, int fd, int fs);
void as_fsqrt(Asm *a, int fd, int fs);
void as_fcmp(Asm *a, int fa, int fb);
void as_fzero(Asm *a, int f);
void as_cvt_i2f(Asm *a, int f, int r);                      /* f := the double of the integer in r, rounded as the mode says */
/* r := the double in f truncated to an integer; to unless where it is a NaN
   on a machine whose conversion would give 0 for one (aarch64). A NaN on
   x86-64, and a double that 64 bits do not hold on either, give a number
   that 63 bits do not hold, which who asks for an int tests. */
void as_cvt_f2i(Asm *a, int r, int f, AsmLabel *unless);
void as_fmov_rf(Asm *a, int r, int f);                      /* the bits */
void as_fmov_fr(Asm *a, int f, int r);

/* the target's conventions: the enter stub's saving of what C keeps and
   its taking of the two arguments (the VM into R_VM, where to go into
   R_GO); the leave stub's restoring and returning; the register of the
   i-th argument of a call into C (0 to 3); and the call itself, of the
   function at addr, the arguments set (win: the Windows convention) */
void as_stub_enter(Asm *a, int win);
void as_stub_leave(Asm *a, int win);
int as_arg(int win, int i);
void as_call_c(Asm *a, int win, uint64_t addr);

#endif
