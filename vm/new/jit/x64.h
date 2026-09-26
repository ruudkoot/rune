/* An x86-64 encoder for the code vm/new's JIT makes (docs/plans/jit.md,
   D3, M4): a buffer of bytes, labels bound and patched, and the
   instructions the macro-assembler (masm.h) is written in. Nothing here
   knows a Value or a VM. The System V and Windows conventions differ only
   in which registers a call into C takes and keeps, which masm.c knows. */
#ifndef RUNE_JIT_X64_H
#define RUNE_JIT_X64_H

#include <stddef.h>
#include <stdint.h>

enum X64Reg { RAX = 0, RCX, RDX, RBX, RSP, RBP, RSI, RDI, R8, R9, R10, R11, R12, R13, R14, R15 };
enum X64Xmm { XMM0 = 0, XMM1, XMM2, XMM3 };
/* the condition of a jcc or setcc: the low four bits of its opcode */
enum X64Cond { CC_O = 0, CC_NO, CC_B, CC_AE, CC_E, CC_NE, CC_BE, CC_A, CC_S, CC_NS, CC_P, CC_NP, CC_L, CC_GE, CC_LE, CC_G };

/* A label: where it is bound in the buffer, or -1; and the places that
   refer to it before it is, each a rel32 to patch when it is. */
typedef struct X64Label {
    int32_t at;
    int32_t *refs;      /* a rel32 to patch at refs[i]; or -(at + 1) for a table entry at at */
    int32_t *tables;    /* for a table entry, the table's start */
    int nrefs, refs_cap;
} X64Label;

typedef struct X64 {
    uintptr_t base;     /* where the code will be placed, for a jump to an address (0: unknown) */
    uint8_t *buf;
    size_t n, cap;
    int failed;         /* out of memory, or a label never bound: the code is not to be used */
} X64;

void x64_init(X64 *a);
void x64_free(X64 *a);
size_t x64_size(const X64 *a);
/* room for n more bytes; 0 when there is none, and the encoder is failed */
int x64_room(X64 *a, size_t n);
void x64_byte(X64 *a, uint8_t b);
void x64_u32(X64 *a, uint32_t v);
void x64_u64(X64 *a, uint64_t v);

void x64_label_init(X64Label *l);
void x64_label_free(X64Label *l);
void x64_bind(X64 *a, X64Label *l);
int x64_bound(const X64Label *l);

/* moves */
void x64_mov_rr(X64 *a, int dst, int src);                      /* dst := src, 64 bits */
void x64_mov_ri(X64 *a, int dst, int64_t imm);                  /* dst := imm */
void x64_mov_rm(X64 *a, int dst, int base, int32_t disp);       /* dst := [base + disp], 64 bits */
void x64_mov_mr(X64 *a, int base, int32_t disp, int src);       /* [base + disp] := src, 64 bits */
void x64_mov_mi(X64 *a, int base, int32_t disp, int32_t imm);   /* [base + disp] := imm, sign-extended to 64 bits */
void x64_mov32_mi(X64 *a, int base, int32_t disp, int32_t imm); /* [base + disp] := imm, 32 bits */
void x64_mov32_rm(X64 *a, int dst, int base, int32_t disp);     /* dst := [base + disp], 32 bits zero-extended */
void x64_mov32_mr(X64 *a, int base, int32_t disp, int src);     /* [base + disp] := src, 32 bits */
void x64_movzx8_rm(X64 *a, int dst, int base, int32_t disp);    /* dst := byte [base + disp], zero-extended */
void x64_movzx16_rm(X64 *a, int dst, int base, int32_t disp);   /* dst := word [base + disp], zero-extended */
void x64_mov8_mi(X64 *a, int base, int32_t disp, int imm8);     /* byte [base + disp] := imm8 */
void x64_mov8_mr(X64 *a, int base, int32_t disp, int src);      /* byte [base + disp] := low byte of src (rax..rdx) */
void x64_movzx8_rr(X64 *a, int dst, int src);                   /* dst := low byte of src, zero-extended */
void x64_mov_rmi(X64 *a, int dst, int base, int index, int scale, int32_t disp);   /* dst := [base + index*scale + disp] */
void x64_lea(X64 *a, int dst, int base, int index, int scale, int32_t disp);       /* index -1: none */
void x64_lea_rip(X64 *a, int dst, X64Label *l);                                    /* dst := the address of l */
void x64_movsxd_rmi(X64 *a, int dst, int base, int index, int scale, int32_t disp);  /* dst := [base + index*scale + disp], 32 bits sign-extended */
/* 16 bytes at a time, unaligned, through an xmm register */
void x64_movups_xm(X64 *a, int xmm, int base, int32_t disp);
void x64_movups_mx(X64 *a, int base, int32_t disp, int xmm);
void x64_movups_xmi(X64 *a, int xmm, int base, int index, int scale, int32_t disp);
void x64_movups_mix(X64 *a, int base, int index, int scale, int32_t disp, int xmm);

/* arithmetic, 64 bits */
void x64_add_rr(X64 *a, int dst, int src);
void x64_sub_rr(X64 *a, int dst, int src);
void x64_and_rr(X64 *a, int dst, int src);
void x64_or_rr(X64 *a, int dst, int src);
void x64_xor_rr(X64 *a, int dst, int src);
void x64_cmp_rr(X64 *a, int a_, int b);
void x64_test_rr(X64 *a, int a_, int b);
void x64_add_ri(X64 *a, int dst, int32_t imm);
void x64_sub_ri(X64 *a, int dst, int32_t imm);
void x64_and_ri(X64 *a, int dst, int32_t imm);
void x64_cmp_ri(X64 *a, int r, int32_t imm);
void x64_imul_rr(X64 *a, int dst, int src);
void x64_neg_r(X64 *a, int r);
void x64_not_r(X64 *a, int r);
void x64_shl_ri(X64 *a, int r, int imm);
void x64_shr_ri(X64 *a, int r, int imm);
void x64_sar_ri(X64 *a, int r, int imm);
void x64_shl_rcl(X64 *a, int r);     /* by cl */
void x64_shr_rcl(X64 *a, int r);
void x64_cqo(X64 *a);
void x64_idiv_r(X64 *a, int r);
void x64_div_r(X64 *a, int r);
void x64_add_mi(X64 *a, int base, int32_t disp, int32_t imm);   /* [base + disp] += imm, 64 bits */
void x64_add_mr(X64 *a, int base, int32_t disp, int src);
void x64_add_rm(X64 *a, int dst, int base, int32_t disp);       /* dst += [base + disp] */
void x64_sub_mr(X64 *a, int base, int32_t disp, int src);
void x64_cmp_mr(X64 *a, int base, int32_t disp, int src);       /* [base + disp] against src */
void x64_cmp_rm(X64 *a, int r, int base, int32_t disp);         /* r against [base + disp] */
void x64_cmp_mi(X64 *a, int base, int32_t disp, int32_t imm);   /* 64-bit compare with a sign-extended imm */
void x64_cmp8_mi(X64 *a, int base, int32_t disp, int imm8);     /* byte compare */
void x64_cmp32_mi(X64 *a, int base, int32_t disp, int32_t imm);
void x64_setcc_r8(X64 *a, int cc, int r);    /* the low byte of r (rax..rbx: no REX needed) */

/* SSE2 on doubles */
void x64_movsd_xm(X64 *a, int xmm, int base, int32_t disp);
void x64_movsd_mx(X64 *a, int base, int32_t disp, int xmm);
void x64_addsd(X64 *a, int dst, int src);
void x64_subsd(X64 *a, int dst, int src);
void x64_mulsd(X64 *a, int dst, int src);
void x64_divsd(X64 *a, int dst, int src);
void x64_ucomisd(X64 *a, int a_, int b);
void x64_xorpd(X64 *a, int dst, int src);
void x64_movq_rx(X64 *a, int r, int xmm);    /* r := the bits of xmm */
void x64_movq_xr(X64 *a, int xmm, int r);

/* control */
void x64_jmp(X64 *a, X64Label *l);
void x64_jcc(X64 *a, int cc, X64Label *l);
void x64_jmp_r(X64 *a, int r);
void x64_jmp_to(X64 *a, const void *target);   /* jmp rel32 to an address, from base + here; fails when out of reach */
void x64_jmp_m(X64 *a, int base, int index, int scale, int32_t disp);   /* jmp [base + index*scale + disp] */
void x64_call_r(X64 *a, int r);
void x64_ret(X64 *a);
void x64_push_r(X64 *a, int r);
void x64_pop_r(X64 *a, int r);
void x64_int3(X64 *a);
/* a table entry: the offset of l from the table's start at table_at, written
   now or when l is bound, 32 bits at at */
void x64_offset32_at(X64 *a, size_t at, size_t table_at, X64Label *l);
void x64_u64_at(X64 *a, size_t at, uint64_t v);

#endif
