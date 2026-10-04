/* The aarch64 encoder against llvm-mc (docs/plans/jit.md, M12): each line
   an instruction and the bytes `llvm-mc -triple=aarch64 -show-encoding`
   gives for it. */
#include "register/jit/a64.h"

#include <stdio.h>
#include <string.h>

static int fails;
static void expect(const char *what, const A64 *a, const char *hex) {
    char got[256];
    size_t n = a->n < 120 ? a->n : 120;
    for (size_t i = 0; i < n; i++) sprintf(got + 2 * i, "%02x", a->buf[i]);
    got[2 * n] = 0;
    if (a->failed || strcmp(got, hex) != 0) { printf("FAIL %s: %s, expected %s%s\n", what, got, hex, a->failed ? " (failed)" : ""); fails++; }
}
#define T(what, hex, ...) do { A64 a; a64_init(&a); __VA_ARGS__; expect(what, &a, hex); a64_free(&a); } while (0)

int main(void) {
    T("mov x0, x1", "e00301aa", a64_mov_rr(&a, X0, X1));
    T("mov x9, #0x1234", "894682d2", a64_mov_ri(&a, X9, 0x1234));
    T("mov x9, #0x12340000", "8946a2d2", a64_mov_ri(&a, X9, 0x12340000));
    T("mov x9, #0x123456780000", "09cfaad28946c2f2", a64_mov_ri(&a, X9, 0x123456780000LL));
    T("mov x9, #-6", "a9008092", a64_mov_ri(&a, X9, -6));
    T("mov x9, #0", "090080d2", a64_mov_ri(&a, X9, 0));
    T("mov x9, #-1", "09008092", a64_mov_ri(&a, X9, -1));
    T("mov x0, sp", "e0030091", a64_mov_sp(&a, X0, XSP));
    T("add x0, x1, x2", "2000028b", a64_add_rr(&a, X0, X1, X2));
    T("add x0, x1, x2, lsl #4", "2010028b", a64_add_rr_lsl(&a, X0, X1, X2, 4));
    T("add x0, x1, #100", "20900191", a64_add_ri(&a, X0, X1, 100));
    T("add x0, x1, #4096", "20044091", a64_add_ri(&a, X0, X1, 4096));
    T("add x0, x1, #-17", "204400d1", a64_add_ri(&a, X0, X1, -17));
    T("adds x0, x1, x2", "200002ab", a64_adds_rr(&a, X0, X1, X2));
    T("sub x0, x1, x2", "200002cb", a64_sub_rr(&a, X0, X1, X2));
    T("sub x0, x1, #17", "204400d1", a64_sub_ri(&a, X0, X1, 17));
    T("subs x0, x1, x2", "200002eb", a64_subs_rr(&a, X0, X1, X2));
    T("cmp x0, x1", "1f0001eb", a64_cmp_rr(&a, X0, X1));
    T("cmp x0, #7", "1f1c00f1", a64_cmp_ri(&a, X0, 7));
    T("cmp x0, #-7", "1f1c00b1", a64_cmp_ri(&a, X0, -7));
    T("and x0, x1, x2", "2000028a", a64_and_rr(&a, X0, X1, X2));
    T("orr x0, x1, x2", "200002aa", a64_orr_rr(&a, X0, X1, X2));
    T("eor x0, x1, x2", "200002ca", a64_eor_rr(&a, X0, X1, X2));
    T("tst x0, x1", "1f0001ea", a64_tst_rr(&a, X0, X1));
    T("and x0, x1, #0xff", "201c4092", a64_and_mask(&a, X0, X1, 8));
    T("and x0, x1, #0xffff", "203c4092", a64_and_mask(&a, X0, X1, 16));
    T("lsl x0, x1, #4", "20ec7cd3", a64_lsl_ri(&a, X0, X1, 4));
    T("lsr x0, x1, #4", "20fc44d3", a64_lsr_ri(&a, X0, X1, 4));
    T("asr x0, x1, #63", "20fc7f93", a64_asr_ri(&a, X0, X1, 63));
    T("lsl x0, x1, x2", "2020c29a", a64_lslv(&a, X0, X1, X2));
    T("lsr x0, x1, x2", "2024c29a", a64_lsrv(&a, X0, X1, X2));
    T("asr x0, x1, x2", "2028c29a", a64_asrv(&a, X0, X1, X2));
    T("mul x0, x1, x2", "207c029b", a64_mul(&a, X0, X1, X2));
    T("smulh x0, x1, x2", "207c429b", a64_smulh(&a, X0, X1, X2));
    T("sdiv x0, x1, x2", "200cc29a", a64_sdiv(&a, X0, X1, X2));
    T("udiv x0, x1, x2", "2008c29a", a64_udiv(&a, X0, X1, X2));
    T("msub x0, x1, x2, x3", "208c029b", a64_msub(&a, X0, X1, X2, X3));
    T("madd x0, x1, x2, x3", "200c029b", a64_madd(&a, X0, X1, X2, X3));
    T("neg x0, x1", "e00301cb", a64_sub_rr(&a, X0, XZR, X1));
    T("mvn x0, x1", "e00321aa", a64_orn_rr(&a, X0, XZR, X1));
    T("ldr x0, [x1, #8]", "200440f9", a64_ldr(&a, X0, X1, 8));
    T("ldur x0, [x1, #-8]", "20805ff8", a64_ldr(&a, X0, X1, -8));
    T("str x0, [x1, #16]", "200800f9", a64_str(&a, X0, X1, 16));
    T("ldr w0, [x1, #4]", "200440b9", a64_ldr32(&a, X0, X1, 4));
    T("str w0, [x1, #4]", "200400b9", a64_str32(&a, X0, X1, 4));
    T("ldrb w0, [x1, #1]", "20044039", a64_ldrb(&a, X0, X1, 1));
    T("ldrh w0, [x1, #2]", "20044079", a64_ldrh(&a, X0, X1, 2));
    T("strb w0, [x1, #1]", "20040039", a64_strb(&a, X0, X1, 1));
    T("ldrsw x0, [x1, #4]", "200480b9", a64_ldrsw(&a, X0, X1, 4));
    T("ldr x0, [x1, x2]", "206862f8", a64_ldr_rr(&a, X0, X1, X2, 0));
    T("ldr x0, [x1, x2, lsl #3]", "207862f8", a64_ldr_rr(&a, X0, X1, X2, 1));
    T("str x0, [x1, x2]", "206822f8", a64_str_rr(&a, X0, X1, X2, 0));
    T("ldrsw x0, [x1, x2, lsl #2]", "2078a2b8", a64_ldrsw_rr(&a, X0, X1, X2, 1));
    T("ldr q0, [x1, #16]", "2004c03d", a64_ldrq(&a, V0, X1, 16));
    T("str q0, [x1, #32]", "2008803d", a64_strq(&a, V0, X1, 32));
    T("ldr q0, [x1, x2]", "2068e23c", a64_ldrq_rr(&a, V0, X1, X2));
    T("str q0, [x1, x2]", "2068a23c", a64_strq_rr(&a, V0, X1, X2));
    T("ldr d0, [x1, #8]", "200440fd", a64_ldrd(&a, V0, X1, 8));
    T("str d0, [x1, #8]", "200400fd", a64_strd(&a, V0, X1, 8));
    T("stp x29, x30, [sp, #-16]!", "fd7bbfa9", a64_stp_pre(&a, X29, X30, XSP, -16));
    T("ldp x29, x30, [sp], #16", "fd7bc1a8", a64_ldp_post(&a, X29, X30, XSP, 16));
    T("stp x19, x20, [sp, #16]", "f35301a9", a64_stp(&a, X19, X20, XSP, 16));
    T("ldp x19, x20, [sp, #16]", "f35341a9", a64_ldp(&a, X19, X20, XSP, 16));
    T("stp d8, d9, [sp, #32]", "e827026d", a64_stpd(&a, V8, V9, XSP, 32));
    T("str x0, [sp, #-16]!", "e00f1ff8", a64_push(&a, X0));
    T("ldr x0, [sp], #16", "e00741f8", a64_pop(&a, X0));
    T("sub sp, sp, #64", "ff0301d1", a64_sub_ri(&a, XSP, XSP, 64));
    T("add sp, sp, #64", "ff030191", a64_add_ri(&a, XSP, XSP, 64));
    T("sxtw x0, w1", "207c4093", a64_sxtw(&a, X0, X1));
    T("ubfx x0, x1, #8, #8", "203c48d3", a64_ubfx(&a, X0, X1, 8, 8));
    T("br x16", "00021fd6", a64_br(&a, X16));
    T("blr x16", "00023fd6", a64_blr(&a, X16));
    T("ret", "c0035fd6", a64_ret(&a));
    T("cset x0, eq", "e0179f9a", a64_cset(&a, X0, A64_EQ));
    T("cset x0, gt", "e0d79f9a", a64_cset(&a, X0, A64_GT));
    T("csel x0, x1, x2, eq", "2000829a", a64_csel(&a, X0, X1, X2, A64_EQ));
    T("brk #0", "000020d4", a64_brk(&a));
    T("fmov d0, x1", "2000679e", a64_fmov_dx(&a, V0, X1));
    T("fmov d0, xzr", "e003679e", a64_fmov_dz(&a, V0));
    T("cmp x16, x0, asr #63", "1ffe80eb", a64_cmp_rr_asr(&a, X16, X0, 63));
    T("fmov x0, d1", "2000669e", a64_fmov_xd(&a, X0, V1));
    T("fmov d0, d1", "2040601e", a64_fmov_dd(&a, V0, V1));
    T("fadd d0, d1, d2", "2028621e", a64_fadd(&a, V0, V1, V2));
    T("fsub d0, d1, d2", "2038621e", a64_fsub(&a, V0, V1, V2));
    T("fmul d0, d1, d2", "2008621e", a64_fmul(&a, V0, V1, V2));
    T("fdiv d0, d1, d2", "2018621e", a64_fdiv(&a, V0, V1, V2));
    T("fsqrt d0, d1", "20c0611e", a64_fsqrt(&a, V0, V1));
    T("fneg d0, d1", "2040611e", a64_fneg(&a, V0, V1));
    T("fcmp d0, d1", "0020611e", a64_fcmp(&a, V0, V1));
    T("scvtf d0, x1", "2000629e", a64_scvtf(&a, V0, X1));
    T("fcvtzs x0, d1", "2000789e", a64_fcvtzs(&a, X0, V1));
    /* branches and labels: forward and back, and the conditions */
    T("b forward", "02000014000020d4000020d4", { A64Label l; a64_label_init(&l); a64_b(&a, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.ne back", "000020d4e1ffff54", { A64Label l; a64_label_init(&l); a64_bind(&a, &l); a64_brk(&a); a64_bcond(&a, A64_NE, &l); a64_label_free(&l); });
    T("b.lo forward", "43000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_LO, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.hs", "42000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_HS, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.hi", "48000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_HI, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.ls", "49000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_LS, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.lt", "4b000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_LT, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.le", "4d000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_LE, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.gt", "4c000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_GT, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.ge", "4a000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_GE, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.vs", "46000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_VS, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.mi", "44000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_MI, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("b.pl", "45000054000020d4000020d4", { A64Label l; a64_label_init(&l); a64_bcond(&a, A64_PL, &l); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("adr x0, +16", "80000010000020d4000020d4000020d4000020d4", { A64Label l; a64_label_init(&l); a64_adr(&a, X0, &l); a64_brk(&a); a64_brk(&a); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    T("table entry", "0c000000000020d4000020d4000020d4", { A64Label l; a64_label_init(&l); a64_u32(&a, 0); a64_offset32_at(&a, 0, 0, &l); a64_brk(&a); a64_brk(&a); a64_bind(&a, &l); a64_brk(&a); a64_label_free(&l); });
    if (fails) { printf("a64: %d failures\n", fails); return 1; }
    printf("a64: ok\n");
    return 0;
}
