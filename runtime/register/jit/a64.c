/* The aarch64 encoder (a64.h): what each function emits is one
   instruction, or the few a large immediate needs. The encodings are the
   ARM's (Arm Architecture Reference Manual, C6 and C7), checked against
   llvm-mc in tests/register/a64_test.c. */
#include "a64.h"

#include <stdlib.h>
#include <string.h>

enum { FIX_B26, FIX_B19, FIX_ADR, FIX_TABLE };
enum { SCRATCH = X16 };   /* the encoder's own: IP0, which no code of the JIT keeps anything in */

void a64_init(A64 *a) { memset(a, 0, sizeof *a); }
void a64_free(A64 *a) { free(a->buf); memset(a, 0, sizeof *a); }
int a64_room(A64 *a, size_t more) {
    if (a->n + more <= a->cap) return 1;
    size_t cap = a->cap ? a->cap * 2 : 1024;
    while (cap < a->n + more) cap *= 2;
    uint8_t *p = realloc(a->buf, cap);
    if (!p) { a->failed = 1; return 0; }
    a->buf = p; a->cap = cap;
    return 1;
}
static void put32(uint8_t *p, uint32_t w) { p[0] = (uint8_t)w; p[1] = (uint8_t)(w >> 8); p[2] = (uint8_t)(w >> 16); p[3] = (uint8_t)(w >> 24); }
static uint32_t get32(const uint8_t *p) { return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24; }
void a64_word(A64 *a, uint32_t w) { if (a64_room(a, 4)) { put32(a->buf + a->n, w); a->n += 4; } }
void a64_u32(A64 *a, uint32_t v) { a64_word(a, v); }
void a64_u64(A64 *a, uint64_t v) { a64_word(a, (uint32_t)v); a64_word(a, (uint32_t)(v >> 32)); }

void a64_label_init(A64Label *l) { l->at = -1; l->fix = NULL; l->nfix = l->cap = 0; }
void a64_label_free(A64Label *l) { free(l->fix); l->fix = NULL; l->nfix = l->cap = 0; }
int a64_bound(const A64Label *l) { return l->at >= 0; }

/* a reference to l at `at`, resolved now or when l is bound */
static void patch(A64 *a, size_t at, int kind, size_t table, int64_t target) {
    uint8_t *p = a->buf + at;
    int64_t rel = target - (int64_t)at;
    switch (kind) {
    case FIX_B26:
        if (rel < -(1 << 27) || rel >= (1 << 27) || (rel & 3)) { a->failed = 1; return; }
        put32(p, get32(p) | ((uint32_t)(rel >> 2) & 0x3FFFFFF));
        break;
    case FIX_B19:
        if (rel < -(1 << 20) || rel >= (1 << 20) || (rel & 3)) { a->failed = 1; return; }
        put32(p, get32(p) | (((uint32_t)(rel >> 2) & 0x7FFFF) << 5));
        break;
    case FIX_ADR:
        if (rel < -(1 << 20) || rel >= (1 << 20)) { a->failed = 1; return; }
        put32(p, get32(p) | (((uint32_t)rel & 3) << 29) | ((((uint32_t)rel >> 2) & 0x7FFFF) << 5));
        break;
    case FIX_TABLE:
        put32(p, (uint32_t)(target - (int64_t)table));
        break;
    }
}
static void refer(A64 *a, A64Label *l, size_t at, int kind, size_t table) {
    if (l->at >= 0) { patch(a, at, kind, table, l->at); return; }
    if (l->nfix == l->cap) {
        int cap = l->cap ? l->cap * 2 : 4;
        A64Fix *f = realloc(l->fix, (size_t)cap * sizeof *f);
        if (!f) { a->failed = 1; return; }
        l->fix = f; l->cap = cap;
    }
    l->fix[l->nfix].at = at; l->fix[l->nfix].kind = kind; l->fix[l->nfix].table = table;
    l->nfix++;
}
void a64_bind(A64 *a, A64Label *l) {
    l->at = (int64_t)a->n;
    for (int i = 0; i < l->nfix; i++) patch(a, l->fix[i].at, l->fix[i].kind, l->fix[i].table, l->at);
    l->nfix = 0;
}

/* ---- the instructions ---- */
#define R(x) ((uint32_t)((x) & 31))
static void rrr(A64 *a, uint32_t op, int rd, int rn, int rm) { a64_word(a, op | R(rm) << 16 | R(rn) << 5 | R(rd)); }

void a64_mov_rr(A64 *a, int rd, int rn) { rrr(a, 0xAA000000, rd, XZR, rn); }
void a64_mov_sp(A64 *a, int rd, int rn) { a64_word(a, 0x91000000 | R(rn) << 5 | R(rd)); }
void a64_mov_ri(A64 *a, int rd, int64_t v) {
    uint64_t u = (uint64_t)v;
    /* movz or movn of one half, the fewer of the halves that are not all
       zero or all one deciding, then movk for the rest; nothing to add
       for 0 or -1 */
    int zeros = 0, ones = 0;
    for (int i = 0; i < 4; i++) { uint64_t h = (u >> (16 * i)) & 0xFFFF; zeros += h == 0; ones += h == 0xFFFF; }
    uint64_t skip = ones > zeros ? 0xFFFF : 0;
    int first = 1;
    for (int i = 0; i < 4; i++) {
        uint64_t h = (u >> (16 * i)) & 0xFFFF;
        if (h == skip) continue;
        if (!first) a64_word(a, 0xF2800000 | (uint32_t)i << 21 | (uint32_t)h << 5 | R(rd));
        else if (skip) a64_word(a, 0x92800000 | (uint32_t)i << 21 | (uint32_t)(~h & 0xFFFF) << 5 | R(rd));
        else a64_word(a, 0xD2800000 | (uint32_t)i << 21 | (uint32_t)h << 5 | R(rd));
        first = 0;
    }
    if (first) a64_word(a, (skip ? 0x92800000u : 0xD2800000u) | R(rd));   /* 0 or -1: one word, hw 0 */
}
void a64_add_rr(A64 *a, int rd, int rn, int rm) { rrr(a, 0x8B000000, rd, rn, rm); }
void a64_add_rr_lsl(A64 *a, int rd, int rn, int rm, int shift) { a64_word(a, 0x8B000000 | R(rm) << 16 | (uint32_t)(shift & 63) << 10 | R(rn) << 5 | R(rd)); }
void a64_adds_rr(A64 *a, int rd, int rn, int rm) { rrr(a, 0xAB000000, rd, rn, rm); }
void a64_sub_rr(A64 *a, int rd, int rn, int rm) { rrr(a, 0xCB000000, rd, rn, rm); }
void a64_subs_rr(A64 *a, int rd, int rn, int rm) { rrr(a, 0xEB000000, rd, rn, rm); }
void a64_and_rr(A64 *a, int rd, int rn, int rm) { rrr(a, 0x8A000000, rd, rn, rm); }
void a64_ands_rr(A64 *a, int rd, int rn, int rm) { rrr(a, 0xEA000000, rd, rn, rm); }
void a64_orr_rr(A64 *a, int rd, int rn, int rm) { rrr(a, 0xAA000000, rd, rn, rm); }
void a64_eor_rr(A64 *a, int rd, int rn, int rm) { rrr(a, 0xCA000000, rd, rn, rm); }
void a64_orn_rr(A64 *a, int rd, int rn, int rm) { rrr(a, 0xAA200000, rd, rn, rm); }
void a64_mul(A64 *a, int rd, int rn, int rm) { a64_word(a, 0x9B007C00 | R(rm) << 16 | R(rn) << 5 | R(rd)); }
void a64_smulh(A64 *a, int rd, int rn, int rm) { a64_word(a, 0x9B407C00 | R(rm) << 16 | R(rn) << 5 | R(rd)); }
void a64_sdiv(A64 *a, int rd, int rn, int rm) { rrr(a, 0x9AC00C00, rd, rn, rm); }
void a64_udiv(A64 *a, int rd, int rn, int rm) { rrr(a, 0x9AC00800, rd, rn, rm); }
void a64_msub(A64 *a, int rd, int rn, int rm, int ra) { a64_word(a, 0x9B008000 | R(rm) << 16 | R(ra) << 10 | R(rn) << 5 | R(rd)); }
void a64_madd(A64 *a, int rd, int rn, int rm, int ra) { a64_word(a, 0x9B000000 | R(rm) << 16 | R(ra) << 10 | R(rn) << 5 | R(rd)); }
void a64_lslv(A64 *a, int rd, int rn, int rm) { rrr(a, 0x9AC02000, rd, rn, rm); }
void a64_lsrv(A64 *a, int rd, int rn, int rm) { rrr(a, 0x9AC02400, rd, rn, rm); }
void a64_asrv(A64 *a, int rd, int rn, int rm) { rrr(a, 0x9AC02800, rd, rn, rm); }
void a64_lsl_ri(A64 *a, int rd, int rn, int shift) {
    shift &= 63;
    if (shift == 0) { a64_mov_rr(a, rd, rn); return; }
    a64_word(a, 0xD3400000 | (uint32_t)((64 - shift) & 63) << 16 | (uint32_t)(63 - shift) << 10 | R(rn) << 5 | R(rd));
}
void a64_lsr_ri(A64 *a, int rd, int rn, int shift) { a64_word(a, 0xD3400000 | (uint32_t)(shift & 63) << 16 | 63u << 10 | R(rn) << 5 | R(rd)); }
void a64_asr_ri(A64 *a, int rd, int rn, int shift) { a64_word(a, 0x93400000 | (uint32_t)(shift & 63) << 16 | 63u << 10 | R(rn) << 5 | R(rd)); }
void a64_ubfx(A64 *a, int rd, int rn, int lsb, int width) { a64_word(a, 0xD3400000 | (uint32_t)lsb << 16 | (uint32_t)(lsb + width - 1) << 10 | R(rn) << 5 | R(rd)); }
void a64_sxtw(A64 *a, int rd, int rn) { a64_word(a, 0x93407C00 | R(rn) << 5 | R(rd)); }
void a64_and_mask(A64 *a, int rd, int rn, int bits) { a64_word(a, 0x92400000 | (uint32_t)(bits - 1) << 10 | R(rn) << 5 | R(rd)); }

/* add and sub with an immediate: the forms of imm12 the machine has, else
   the value in x16 and the register form (so rn may not be x16) */
static void arith_ri(A64 *a, uint32_t op_imm, uint32_t op_reg, int rd, int rn, int64_t v) {
    if (v >= 0 && v < 4096) { a64_word(a, op_imm | (uint32_t)v << 10 | R(rn) << 5 | R(rd)); return; }
    if (v >= 0 && (v & 0xFFF) == 0 && (v >> 12) < 4096) { a64_word(a, op_imm | 1u << 22 | (uint32_t)(v >> 12) << 10 | R(rn) << 5 | R(rd)); return; }
    a64_mov_ri(a, SCRATCH, v);
    rrr(a, op_reg, rd, rn, SCRATCH);
}
void a64_add_ri(A64 *a, int rd, int rn, int64_t v) { if (v < 0 && v > -4096) a64_sub_ri(a, rd, rn, -v); else arith_ri(a, 0x91000000, 0x8B000000, rd, rn, v); }
void a64_sub_ri(A64 *a, int rd, int rn, int64_t v) { if (v < 0 && v > -4096) a64_add_ri(a, rd, rn, -v); else arith_ri(a, 0xD1000000, 0xCB000000, rd, rn, v); }
void a64_adds_ri(A64 *a, int rd, int rn, int64_t v) { if (v < 0 && v > -4096) a64_subs_ri(a, rd, rn, -v); else arith_ri(a, 0xB1000000, 0xAB000000, rd, rn, v); }
void a64_subs_ri(A64 *a, int rd, int rn, int64_t v) { if (v < 0 && v > -4096) a64_adds_ri(a, rd, rn, -v); else arith_ri(a, 0xF1000000, 0xEB000000, rd, rn, v); }
void a64_cmp_rr(A64 *a, int rn, int rm) { rrr(a, 0xEB000000, XZR, rn, rm); }
void a64_cmp_ri(A64 *a, int rn, int64_t v) { a64_subs_ri(a, XZR, rn, v); }
void a64_cmp_rr_asr(A64 *a, int rn, int rm, int shift) { a64_word(a, 0xEB800000 | R(rm) << 16 | (uint32_t)(shift & 63) << 10 | R(rn) << 5 | R(XZR)); }
void a64_tst_rr(A64 *a, int rn, int rm) { rrr(a, 0xEA000000, XZR, rn, rm); }

/* loads and stores with an offset: the unsigned scaled form, the signed
   unscaled form (ldur/stur), else the offset in x16 and the register form */
static void mem(A64 *a, uint32_t op_unsigned, uint32_t op_unscaled, uint32_t op_reg, int size, int rt, int rn, int32_t off) {
    if (off >= 0 && off % size == 0 && off / size < 4096) { a64_word(a, op_unsigned | (uint32_t)(off / size) << 10 | R(rn) << 5 | R(rt)); return; }
    if (off >= -256 && off < 256) { a64_word(a, op_unscaled | ((uint32_t)off & 0x1FF) << 12 | R(rn) << 5 | R(rt)); return; }
    a64_mov_ri(a, SCRATCH, off);
    a64_word(a, op_reg | R(SCRATCH) << 16 | R(rn) << 5 | R(rt));
}
void a64_ldr(A64 *a, int rt, int rn, int32_t off) { mem(a, 0xF9400000, 0xF8400000, 0xF8606800, 8, rt, rn, off); }
void a64_str(A64 *a, int rt, int rn, int32_t off) { mem(a, 0xF9000000, 0xF8000000, 0xF8206800, 8, rt, rn, off); }
void a64_ldr32(A64 *a, int rt, int rn, int32_t off) { mem(a, 0xB9400000, 0xB8400000, 0xB8606800, 4, rt, rn, off); }
void a64_str32(A64 *a, int rt, int rn, int32_t off) { mem(a, 0xB9000000, 0xB8000000, 0xB8206800, 4, rt, rn, off); }
void a64_ldrsw(A64 *a, int rt, int rn, int32_t off) { mem(a, 0xB9800000, 0xB8800000, 0xB8A06800, 4, rt, rn, off); }
void a64_ldrb(A64 *a, int rt, int rn, int32_t off) { mem(a, 0x39400000, 0x38400000, 0x38606800, 1, rt, rn, off); }
void a64_strb(A64 *a, int rt, int rn, int32_t off) { mem(a, 0x39000000, 0x38000000, 0x38206800, 1, rt, rn, off); }
void a64_ldrh(A64 *a, int rt, int rn, int32_t off) { mem(a, 0x79400000, 0x78400000, 0x78606800, 2, rt, rn, off); }
void a64_ldr_rr(A64 *a, int rt, int rn, int rm, int scaled) { a64_word(a, 0xF8606800 | (scaled ? 1u << 12 : 0) | R(rm) << 16 | R(rn) << 5 | R(rt)); }
void a64_str_rr(A64 *a, int rt, int rn, int rm, int scaled) { a64_word(a, 0xF8206800 | (scaled ? 1u << 12 : 0) | R(rm) << 16 | R(rn) << 5 | R(rt)); }
void a64_ldrsw_rr(A64 *a, int rt, int rn, int rm, int scaled) { a64_word(a, 0xB8A06800 | (scaled ? 1u << 12 : 0) | R(rm) << 16 | R(rn) << 5 | R(rt)); }
void a64_ldrq(A64 *a, int vt, int rn, int32_t off) { mem(a, 0x3DC00000, 0x3CC00000, 0x3CE06800, 16, vt, rn, off); }
void a64_strq(A64 *a, int vt, int rn, int32_t off) { mem(a, 0x3D800000, 0x3C800000, 0x3CA06800, 16, vt, rn, off); }
void a64_ldrq_rr(A64 *a, int vt, int rn, int rm) { a64_word(a, 0x3CE06800 | R(rm) << 16 | R(rn) << 5 | R(vt)); }
void a64_strq_rr(A64 *a, int vt, int rn, int rm) { a64_word(a, 0x3CA06800 | R(rm) << 16 | R(rn) << 5 | R(vt)); }
void a64_ldrd(A64 *a, int vt, int rn, int32_t off) { mem(a, 0xFD400000, 0xFC400000, 0xFC606800, 8, vt, rn, off); }
void a64_strd(A64 *a, int vt, int rn, int32_t off) { mem(a, 0xFD000000, 0xFC000000, 0xFC206800, 8, vt, rn, off); }

static void pair(A64 *a, uint32_t op, int rt, int rt2, int rn, int32_t off) {
    if (off % 8 || off < -512 || off > 504) { a->failed = 1; return; }
    a64_word(a, op | ((uint32_t)(off / 8) & 0x7F) << 15 | R(rt2) << 10 | R(rn) << 5 | R(rt));
}
void a64_stp_pre(A64 *a, int rt, int rt2, int rn, int32_t off) { pair(a, 0xA9800000, rt, rt2, rn, off); }
void a64_ldp_post(A64 *a, int rt, int rt2, int rn, int32_t off) { pair(a, 0xA8C00000, rt, rt2, rn, off); }
void a64_stp(A64 *a, int rt, int rt2, int rn, int32_t off) { pair(a, 0xA9000000, rt, rt2, rn, off); }
void a64_ldp(A64 *a, int rt, int rt2, int rn, int32_t off) { pair(a, 0xA9400000, rt, rt2, rn, off); }
void a64_stpd(A64 *a, int vt, int vt2, int rn, int32_t off) { pair(a, 0x6D000000, vt, vt2, rn, off); }
void a64_ldpd(A64 *a, int vt, int vt2, int rn, int32_t off) { pair(a, 0x6D400000, vt, vt2, rn, off); }
void a64_push(A64 *a, int rt) { a64_word(a, 0xF81F0C00 | R(XSP) << 5 | R(rt)); }
void a64_pop(A64 *a, int rt) { a64_word(a, 0xF8410400 | R(XSP) << 5 | R(rt)); }

void a64_b(A64 *a, A64Label *l) { size_t at = a->n; a64_word(a, 0x14000000); if (!a->failed) refer(a, l, at, FIX_B26, 0); }
void a64_bcond(A64 *a, int cond, A64Label *l) { size_t at = a->n; a64_word(a, 0x54000000 | (uint32_t)(cond & 15)); if (!a->failed) refer(a, l, at, FIX_B19, 0); }
void a64_br(A64 *a, int rn) { a64_word(a, 0xD61F0000 | R(rn) << 5); }
void a64_blr(A64 *a, int rn) { a64_word(a, 0xD63F0000 | R(rn) << 5); }
void a64_ret(A64 *a) { a64_word(a, 0xD65F03C0); }
void a64_b_to(A64 *a, const void *at) {
    int64_t rel = (int64_t)((int64_t)(uintptr_t)at - (int64_t)(a->base + a->n));
    if (a->base && rel >= -(1 << 27) && rel < (1 << 27) && !(rel & 3)) { a64_word(a, 0x14000000 | ((uint32_t)(rel >> 2) & 0x3FFFFFF)); return; }
    a64_mov_ri(a, SCRATCH, (int64_t)(intptr_t)at);
    a64_br(a, SCRATCH);
}
void a64_adr(A64 *a, int rd, A64Label *l) { size_t at = a->n; a64_word(a, 0x10000000 | R(rd)); if (!a->failed) refer(a, l, at, FIX_ADR, 0); }
void a64_cset(A64 *a, int rd, int cond) { a64_word(a, 0x9A9F07E0 | (uint32_t)((cond ^ 1) & 15) << 12 | R(rd)); }
void a64_csel(A64 *a, int rd, int rn, int rm, int cond) { a64_word(a, 0x9A800000 | R(rm) << 16 | (uint32_t)(cond & 15) << 12 | R(rn) << 5 | R(rd)); }
void a64_brk(A64 *a) { a64_word(a, 0xD4200000); }

void a64_fmov_dx(A64 *a, int vd, int rn) { a64_word(a, 0x9E670000 | R(rn) << 5 | R(vd)); }
void a64_fmov_dz(A64 *a, int vd) { a64_fmov_dx(a, vd, XZR); }
void a64_fmov_xd(A64 *a, int rd, int vn) { a64_word(a, 0x9E660000 | R(vn) << 5 | R(rd)); }
void a64_fmov_dd(A64 *a, int vd, int vn) { a64_word(a, 0x1E604000 | R(vn) << 5 | R(vd)); }
void a64_fadd(A64 *a, int vd, int vn, int vm) { rrr(a, 0x1E602800, vd, vn, vm); }
void a64_fsub(A64 *a, int vd, int vn, int vm) { rrr(a, 0x1E603800, vd, vn, vm); }
void a64_fmul(A64 *a, int vd, int vn, int vm) { rrr(a, 0x1E600800, vd, vn, vm); }
void a64_fdiv(A64 *a, int vd, int vn, int vm) { rrr(a, 0x1E601800, vd, vn, vm); }
void a64_fsqrt(A64 *a, int vd, int vn) { a64_word(a, 0x1E61C000 | R(vn) << 5 | R(vd)); }
void a64_fneg(A64 *a, int vd, int vn) { a64_word(a, 0x1E614000 | R(vn) << 5 | R(vd)); }
void a64_fcmp(A64 *a, int vn, int vm) { a64_word(a, 0x1E602000 | R(vm) << 16 | R(vn) << 5); }
void a64_scvtf(A64 *a, int vd, int rn) { a64_word(a, 0x9E620000 | R(rn) << 5 | R(vd)); }
void a64_fcvtzs(A64 *a, int rd, int vn) { a64_word(a, 0x9E780000 | R(vn) << 5 | R(rd)); }

void a64_offset32_at(A64 *a, size_t at, size_t table_at, A64Label *l) { refer(a, l, at, FIX_TABLE, table_at); }
