/* The portable assembler of vm/new's JIT (docs/plans/jit.md, M12): the
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
    R_VM = X19, R_STACK = X20, R_BASEI = X21, R_BASER = X22, R_COUNT = X23,
    R_H0 = X24, R_H1 = X25, R_H2 = X26,
    R_S0 = X0, R_S1 = X9, R_S2 = X10, R_S3 = X11, R_S4 = X12, R_S5 = X13, R_S6 = X14,
    R_T = X17, R_SP = XSP, R_GO = X27   /* R_GO: where the enter stub is to jump, kept across its reload */
};
enum AsmFReg { F_S0 = V0, F_S1 = V1, F_H0 = V8 };   /* the homes: V8 to V21 */
enum AsmCond {
    CC_E = A64_EQ, CC_NE = A64_NE, CC_L = A64_LT, CC_LE = A64_LE, CC_G = A64_GT, CC_GE = A64_GE,
    CC_B = A64_LO, CC_BE = A64_LS, CC_A = A64_HI, CC_AE = A64_HS, CC_O = A64_VS, CC_NO = A64_VC,
    CC_S = A64_MI, CC_NS = A64_PL,
    CC_FA = 16, CC_FAE = 17, CC_FE = 18   /* after as_fcmp: above, above or equal, equal; false on a NaN */
};
#else
#include "x64.h"
typedef X64 Asm;
typedef X64Label AsmLabel;
enum AsmReg {
    R_VM = R12, R_STACK = R13, R_BASEI = RBP, R_BASER = R14, R_COUNT = R15,
    R_H0 = RBX, R_H1 = RSI, R_H2 = RDI,
    R_S0 = RAX, R_S1 = RCX, R_S2 = RDX, R_S3 = R8, R_S4 = R9, R_S5 = R10, R_S6 = R11,
    R_T = R11, R_SP = RSP, R_GO = R11
};
enum AsmFReg { F_S0 = XMM0, F_S1 = XMM1, F_H0 = XMM2 };   /* the homes: XMM2 to XMM15 */
enum AsmCondMore { CC_FA = CC_A, CC_FAE = CC_AE, CC_FE = 16 };
#endif
#define AS_NHOMES_F 14

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
void as_call_r(Asm *a, int r);
void as_ret(Asm *a);
void as_trap(Asm *a);
void as_setcc(Asm *a, int rd, int cc);
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
