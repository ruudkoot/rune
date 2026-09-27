/* The aarch64 encoder of vm/new's JIT (docs/plans/jit.md, M12): the
   second target, beside x64.h. A buffer of 32-bit words, labels bound
   and patched (a branch's imm26 or imm19, an adr's imm21, or a table's
   32-bit entry relative to the table's start), and the instructions the
   portable assembler (asm.h) is written in for this target. Nothing here
   knows a Value or a VM. Every function that takes an immediate says what
   it can encode; one that cannot sets `failed`, as the buffer does when
   it cannot grow, and the compiler leaves the function interpreted. */
#ifndef RUNE_JIT_A64_H
#define RUNE_JIT_A64_H

#include <stddef.h>
#include <stdint.h>

/* the general registers; SP and ZR are both 31, told apart by the instruction */
enum A64Reg { X0, X1, X2, X3, X4, X5, X6, X7, X8, X9, X10, X11, X12, X13, X14, X15,
              X16, X17, X18, X19, X20, X21, X22, X23, X24, X25, X26, X27, X28, X29, X30, XSP = 31, XZR = 31 };
/* the SIMD and floating-point registers, as doubles (d) or quads (q) */
enum A64VReg { V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15,
               V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27, V28, V29, V30, V31 };
/* the conditions, as the ARM encodes them */
enum A64Cond { A64_EQ = 0, A64_NE = 1, A64_HS = 2, A64_LO = 3, A64_MI = 4, A64_PL = 5, A64_VS = 6, A64_VC = 7,
               A64_HI = 8, A64_LS = 9, A64_GE = 10, A64_LT = 11, A64_GT = 12, A64_LE = 13, A64_AL = 14 };

typedef struct A64Fix { size_t at; int kind; size_t table; } A64Fix;
typedef struct A64Label {
    int64_t at;          /* the offset bound, or -1 */
    A64Fix *fix;         /* the references made before it was bound */
    int nfix, cap;
} A64Label;

typedef struct A64 {
    uintptr_t base;      /* where the code will run, for a branch to an address (a64_b_to); 0: unknown */
    uint8_t *buf;
    size_t n, cap;
    int failed;
} A64;

void a64_init(A64 *a);
void a64_free(A64 *a);
int a64_room(A64 *a, size_t more);
void a64_word(A64 *a, uint32_t w);
void a64_u32(A64 *a, uint32_t v);        /* raw data, for a table */
void a64_u64(A64 *a, uint64_t v);
void a64_label_init(A64Label *l);
void a64_label_free(A64Label *l);
void a64_bind(A64 *a, A64Label *l);
int a64_bound(const A64Label *l);

/* moves and immediates */
void a64_mov_rr(A64 *a, int rd, int rn);                 /* orr rd, xzr, rn */
void a64_mov_ri(A64 *a, int rd, int64_t v);              /* movz/movn and movk, as many as the value needs */
void a64_mov_sp(A64 *a, int rd, int rn);                 /* add rd, rn, #0: to or from sp */
/* arithmetic and logic on registers; the s forms set the flags */
void a64_add_rr(A64 *a, int rd, int rn, int rm);
void a64_add_rr_lsl(A64 *a, int rd, int rn, int rm, int shift);
void a64_adds_rr(A64 *a, int rd, int rn, int rm);
void a64_sub_rr(A64 *a, int rd, int rn, int rm);
void a64_subs_rr(A64 *a, int rd, int rn, int rm);
void a64_and_rr(A64 *a, int rd, int rn, int rm);
void a64_ands_rr(A64 *a, int rd, int rn, int rm);
void a64_orr_rr(A64 *a, int rd, int rn, int rm);
void a64_eor_rr(A64 *a, int rd, int rn, int rm);
void a64_orn_rr(A64 *a, int rd, int rn, int rm);
void a64_mul(A64 *a, int rd, int rn, int rm);
void a64_smulh(A64 *a, int rd, int rn, int rm);
void a64_sdiv(A64 *a, int rd, int rn, int rm);
void a64_udiv(A64 *a, int rd, int rn, int rm);
void a64_msub(A64 *a, int rd, int rn, int rm, int ra); /* rd := ra - rn * rm */
void a64_madd(A64 *a, int rd, int rn, int rm, int ra); /* rd := ra + rn * rm */
void a64_lslv(A64 *a, int rd, int rn, int rm);
void a64_lsrv(A64 *a, int rd, int rn, int rm);
void a64_asrv(A64 *a, int rd, int rn, int rm);
void a64_lsl_ri(A64 *a, int rd, int rn, int shift);      /* 0 to 63 */
void a64_lsr_ri(A64 *a, int rd, int rn, int shift);
void a64_asr_ri(A64 *a, int rd, int rn, int shift);
void a64_ubfx(A64 *a, int rd, int rn, int lsb, int width);
void a64_sxtw(A64 *a, int rd, int rn);
void a64_and_mask(A64 *a, int rd, int rn, int bits);     /* rd := rn & ((1 << bits) - 1), bits 1 to 63 */
/* arithmetic with an immediate: imm12, or imm12 << 12, else through x16 */
void a64_add_ri(A64 *a, int rd, int rn, int64_t v);
void a64_sub_ri(A64 *a, int rd, int rn, int64_t v);
void a64_adds_ri(A64 *a, int rd, int rn, int64_t v);
void a64_subs_ri(A64 *a, int rd, int rn, int64_t v);
/* compares: the flags */
void a64_cmp_rr(A64 *a, int rn, int rm);
void a64_cmp_rr_asr(A64 *a, int rn, int rm, int shift);   /* cmp rn, rm, asr #shift */
void a64_fmov_dz(A64 *a, int vd);                          /* vd := 0.0 */
void a64_cmp_ri(A64 *a, int rn, int64_t v);
void a64_tst_rr(A64 *a, int rn, int rm);
/* loads and stores: an unsigned offset a multiple of the size (to 4095 *
   size), a signed one from -256 to 255 (ldur/stur), else through x16; a
   register offset, scaled by the size or not */
void a64_ldr(A64 *a, int rt, int rn, int32_t off);       /* 64 bits */
void a64_str(A64 *a, int rt, int rn, int32_t off);
void a64_ldr32(A64 *a, int rt, int rn, int32_t off);     /* 32 bits, zero-extended */
void a64_str32(A64 *a, int rt, int rn, int32_t off);
void a64_ldrsw(A64 *a, int rt, int rn, int32_t off);     /* 32 bits, sign-extended */
void a64_ldrb(A64 *a, int rt, int rn, int32_t off);
void a64_strb(A64 *a, int rt, int rn, int32_t off);
void a64_ldrh(A64 *a, int rt, int rn, int32_t off);
void a64_ldr_rr(A64 *a, int rt, int rn, int rm, int scaled);
void a64_str_rr(A64 *a, int rt, int rn, int rm, int scaled);
void a64_ldrsw_rr(A64 *a, int rt, int rn, int rm, int scaled);
void a64_ldrq(A64 *a, int vt, int rn, int32_t off);      /* 16 bytes */
void a64_strq(A64 *a, int vt, int rn, int32_t off);
void a64_ldrq_rr(A64 *a, int vt, int rn, int rm);
void a64_strq_rr(A64 *a, int vt, int rn, int rm);
void a64_ldrd(A64 *a, int vt, int rn, int32_t off);      /* a double */
void a64_strd(A64 *a, int vt, int rn, int32_t off);
/* the stack: pairs and singles, pre- and post-indexed by 16 */
void a64_stp_pre(A64 *a, int rt, int rt2, int rn, int32_t off);   /* stp rt, rt2, [rn, #off]! */
void a64_ldp_post(A64 *a, int rt, int rt2, int rn, int32_t off);  /* ldp rt, rt2, [rn], #off */
void a64_stp(A64 *a, int rt, int rt2, int rn, int32_t off);
void a64_ldp(A64 *a, int rt, int rt2, int rn, int32_t off);
void a64_stpd(A64 *a, int vt, int vt2, int rn, int32_t off);
void a64_ldpd(A64 *a, int vt, int vt2, int rn, int32_t off);
void a64_push(A64 *a, int rt);                           /* str rt, [sp, #-16]! */
void a64_pop(A64 *a, int rt);                            /* ldr rt, [sp], #16 */
/* branches */
void a64_b(A64 *a, A64Label *l);
void a64_bcond(A64 *a, int cond, A64Label *l);
void a64_br(A64 *a, int rn);
void a64_blr(A64 *a, int rn);
void a64_ret(A64 *a);
void a64_b_to(A64 *a, const void *at);                   /* to an address: b where it is in range of base, else through x16 */
void a64_adr(A64 *a, int rd, A64Label *l);               /* rd := the address of l */
void a64_cset(A64 *a, int rd, int cond);
void a64_csel(A64 *a, int rd, int rn, int rm, int cond);
void a64_brk(A64 *a);
/* floating point, doubles */
void a64_fmov_dx(A64 *a, int vd, int rn);
void a64_fmov_xd(A64 *a, int rd, int vn);
void a64_fmov_dd(A64 *a, int vd, int vn);
void a64_fadd(A64 *a, int vd, int vn, int vm);
void a64_fsub(A64 *a, int vd, int vn, int vm);
void a64_fmul(A64 *a, int vd, int vn, int vm);
void a64_fdiv(A64 *a, int vd, int vn, int vm);
void a64_fsqrt(A64 *a, int vd, int vn);
void a64_fneg(A64 *a, int vd, int vn);
void a64_fcmp(A64 *a, int vn, int vm);
void a64_scvtf(A64 *a, int vd, int rn);
void a64_fcvtzs(A64 *a, int rd, int vn);
/* a table of 32-bit entries: the offset of label l from the table's start
   at table_at, written at `at` (both offsets into the code) */
void a64_offset32_at(A64 *a, size_t at, size_t table_at, A64Label *l);

#endif
