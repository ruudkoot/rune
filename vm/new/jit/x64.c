/* The x86-64 encoder of vm/new's JIT (x64.h): the bytes of each
   instruction as the Intel manual gives them. A memory operand is
   [base + index*scale + disp], base and index registers; the encoder
   takes care of what the ModRM byte cannot say directly (rsp and r12 as a
   base need a SIB byte, rbp and r13 a displacement). */
#include "x64.h"

#include <stdlib.h>
#include <string.h>

void x64_init(X64 *a) { a->buf = NULL; a->n = 0; a->cap = 0; a->failed = 0; a->base = 0; }
void x64_jmp_to(X64 *a, const void *target) {
    int64_t rel = (int64_t)((uintptr_t)target - (a->base + a->n + 5));
    if (!a->base || rel < INT32_MIN || rel > INT32_MAX) { a->failed = 1; return; }
    x64_byte(a, 0xE9);
    x64_u32(a, (uint32_t)(int32_t)rel);
}
void x64_free(X64 *a) { free(a->buf); a->buf = NULL; a->n = a->cap = 0; }
size_t x64_size(const X64 *a) { return a->n; }

int x64_room(X64 *a, size_t n) {
    if (a->failed) return 0;
    if (a->n + n <= a->cap) return 1;
    size_t cap = a->cap ? a->cap : 4096;
    while (cap < a->n + n) cap *= 2;
    uint8_t *b = realloc(a->buf, cap);
    if (!b) { a->failed = 1; return 0; }
    a->buf = b;
    a->cap = cap;
    return 1;
}
void x64_byte(X64 *a, uint8_t b) { if (x64_room(a, 1)) a->buf[a->n++] = b; }
void x64_u32(X64 *a, uint32_t v) { for (int i = 0; i < 4; i++) x64_byte(a, (uint8_t)(v >> (8 * i))); }
void x64_u64(X64 *a, uint64_t v) { for (int i = 0; i < 8; i++) x64_byte(a, (uint8_t)(v >> (8 * i))); }
void x64_u64_at(X64 *a, size_t at, uint64_t v) {
    if (at + 8 > a->n) { a->failed = 1; return; }
    for (int i = 0; i < 8; i++) a->buf[at + i] = (uint8_t)(v >> (8 * i));
}

/* ---- labels ---- */
void x64_label_init(X64Label *l) { l->at = -1; l->refs = NULL; l->tables = NULL; l->nrefs = l->refs_cap = 0; }
void x64_label_free(X64Label *l) { free(l->refs); free(l->tables); l->refs = NULL; l->tables = NULL; l->nrefs = l->refs_cap = 0; }
int x64_bound(const X64Label *l) { return l->at >= 0; }
static void patch32(X64 *a, int32_t at, int32_t v) {
    for (int i = 0; i < 4; i++) a->buf[at + i] = (uint8_t)((uint32_t)v >> (8 * i));
}
/* A reference is a rel32 at refs[i], relative to the byte after it, or,
   when it is negative (-(at + 1)), an offset written at at relative to the
   table start kept in table[i]. */
void x64_bind(X64 *a, X64Label *l) {
    l->at = (int32_t)a->n;
    for (int i = 0; i < l->nrefs; i++) {
        if (l->refs[i] >= 0) patch32(a, l->refs[i], l->at - (l->refs[i] + 4));
        else patch32(a, -(l->refs[i] + 1), l->at - l->tables[i]);
    }
    l->nrefs = 0;
}
static int ref_room(X64 *a, X64Label *l) {
    if (l->nrefs == l->refs_cap) {
        int cap = l->refs_cap ? l->refs_cap * 2 : 4;
        int32_t *r = realloc(l->refs, (size_t)cap * sizeof *r);
        int32_t *t = realloc(l->tables, (size_t)cap * sizeof *t);
        if (!r || !t) { free(r == l->refs ? NULL : r); a->failed = 1; return 0; }
        l->refs = r; l->tables = t;
        l->refs_cap = cap;
    }
    return 1;
}
void x64_offset32_at(X64 *a, size_t at, size_t table_at, X64Label *l) {
    if (l->at >= 0) { patch32(a, (int32_t)at, l->at - (int32_t)table_at); return; }
    if (!ref_room(a, l)) return;
    l->refs[l->nrefs] = -((int32_t)at + 1);
    l->tables[l->nrefs] = (int32_t)table_at;
    l->nrefs++;
}
/* a rel32 to l, patched now or when l is bound */
static int ref_room(X64 *a, X64Label *l);
static void rel32(X64 *a, X64Label *l) {
    if (l->at >= 0) { x64_u32(a, (uint32_t)(l->at - ((int32_t)a->n + 4))); return; }
    if (!ref_room(a, l)) return;
    l->refs[l->nrefs] = (int32_t)a->n;
    l->tables[l->nrefs] = 0;
    l->nrefs++;
    x64_u32(a, 0);
}

/* ---- the prefix and the operand bytes ---- */
static void rex(X64 *a, int w, int reg, int index, int base) {
    int r = (reg >> 3) & 1, x = index >= 0 ? (index >> 3) & 1 : 0, b = (base >> 3) & 1;
    if (w || r || x || b) x64_byte(a, (uint8_t)(0x40 | (w << 3) | (r << 2) | (x << 1) | b));
}
/* a REX with no bits, which byte registers above rbx need to mean their low byte */
static void rex8(X64 *a, int w, int reg, int index, int base, int lowbyte) {
    int r = (reg >> 3) & 1, x = index >= 0 ? (index >> 3) & 1 : 0, b = (base >> 3) & 1;
    if (w || r || x || b || (lowbyte >= 4 && lowbyte < 8)) x64_byte(a, (uint8_t)(0x40 | (w << 3) | (r << 2) | (x << 1) | b));
}
static void modrm_rr(X64 *a, int reg, int rm) { x64_byte(a, (uint8_t)(0xC0 | ((reg & 7) << 3) | (rm & 7))); }
static void modrm_mem(X64 *a, int reg, int base, int index, int scale, int32_t disp) {
    int mod;
    if (disp == 0 && (base & 7) != 5) mod = 0;
    else if (disp >= -128 && disp <= 127) mod = 1;
    else mod = 2;
    if (index >= 0 || (base & 7) == 4) {
        int ss = scale == 8 ? 3 : scale == 4 ? 2 : scale == 2 ? 1 : 0;
        int idx = index >= 0 ? index & 7 : 4;
        x64_byte(a, (uint8_t)((mod << 6) | ((reg & 7) << 3) | 4));
        x64_byte(a, (uint8_t)((ss << 6) | (idx << 3) | (base & 7)));
    } else {
        x64_byte(a, (uint8_t)((mod << 6) | ((reg & 7) << 3) | (base & 7)));
    }
    if (mod == 1) x64_byte(a, (uint8_t)(int8_t)disp);
    else if (mod == 2) x64_u32(a, (uint32_t)disp);
}
/* one opcode byte (or two after 0x0F) with a register and a memory operand */
static void op_rm(X64 *a, int w, int op, int op2, int reg, int base, int index, int scale, int32_t disp) {
    rex(a, w, reg, index, base);
    if (op2 >= 0) x64_byte(a, (uint8_t)op);
    x64_byte(a, (uint8_t)(op2 >= 0 ? op2 : op));
    modrm_mem(a, reg, base, index, scale, disp);
}
static void op_rr(X64 *a, int w, int op, int op2, int reg, int rm) {
    rex(a, w, reg, -1, rm);
    if (op2 >= 0) x64_byte(a, (uint8_t)op);
    x64_byte(a, (uint8_t)(op2 >= 0 ? op2 : op));
    modrm_rr(a, reg, rm);
}

/* ---- moves ---- */
void x64_mov_rr(X64 *a, int dst, int src) { op_rr(a, 1, 0x89, -1, src, dst); }
void x64_mov_ri(X64 *a, int dst, int64_t imm) {
    if (imm >= INT32_MIN && imm <= INT32_MAX) { op_rr(a, 1, 0xC7, -1, 0, dst); x64_u32(a, (uint32_t)(int32_t)imm); }
    else { rex(a, 1, 0, -1, dst); x64_byte(a, (uint8_t)(0xB8 + (dst & 7))); x64_u64(a, (uint64_t)imm); }
}
void x64_mov_rm(X64 *a, int dst, int base, int32_t disp) { op_rm(a, 1, 0x8B, -1, dst, base, -1, 1, disp); }
void x64_mov_mr(X64 *a, int base, int32_t disp, int src) { op_rm(a, 1, 0x89, -1, src, base, -1, 1, disp); }
void x64_mov_mi(X64 *a, int base, int32_t disp, int32_t imm) { op_rm(a, 1, 0xC7, -1, 0, base, -1, 1, disp); x64_u32(a, (uint32_t)imm); }
void x64_mov32_mi(X64 *a, int base, int32_t disp, int32_t imm) { op_rm(a, 0, 0xC7, -1, 0, base, -1, 1, disp); x64_u32(a, (uint32_t)imm); }
void x64_mov32_rm(X64 *a, int dst, int base, int32_t disp) { op_rm(a, 0, 0x8B, -1, dst, base, -1, 1, disp); }
void x64_mov32_mr(X64 *a, int base, int32_t disp, int src) { op_rm(a, 0, 0x89, -1, src, base, -1, 1, disp); }
void x64_movzx8_rm(X64 *a, int dst, int base, int32_t disp) { op_rm(a, 1, 0x0F, 0xB6, dst, base, -1, 1, disp); }
void x64_movzx16_rm(X64 *a, int dst, int base, int32_t disp) { op_rm(a, 1, 0x0F, 0xB7, dst, base, -1, 1, disp); }
void x64_mov8_mi(X64 *a, int base, int32_t disp, int imm8) { op_rm(a, 0, 0xC6, -1, 0, base, -1, 1, disp); x64_byte(a, (uint8_t)imm8); }
void x64_mov8_mr(X64 *a, int base, int32_t disp, int src) {
    rex8(a, 0, src, -1, base, src);
    x64_byte(a, 0x88);
    modrm_mem(a, src, base, -1, 1, disp);
}
void x64_movzx8_rr(X64 *a, int dst, int src) {
    rex8(a, 1, dst, -1, src, src);
    x64_byte(a, 0x0F); x64_byte(a, 0xB6);
    modrm_rr(a, dst, src);
}
void x64_mov_rmi(X64 *a, int dst, int base, int index, int scale, int32_t disp) { op_rm(a, 1, 0x8B, -1, dst, base, index, scale, disp); }
void x64_lea(X64 *a, int dst, int base, int index, int scale, int32_t disp) { op_rm(a, 1, 0x8D, -1, dst, base, index, scale, disp); }
void x64_lea_rip(X64 *a, int dst, X64Label *l) {
    rex(a, 1, dst, -1, 0);
    x64_byte(a, 0x8D);
    x64_byte(a, (uint8_t)(((dst & 7) << 3) | 5));   /* mod 00, rm 101: rip + disp32 */
    rel32(a, l);
}
void x64_movsxd_rmi(X64 *a, int dst, int base, int index, int scale, int32_t disp) { op_rm(a, 1, 0x63, -1, dst, base, index, scale, disp); }
void x64_movups_xm(X64 *a, int xmm, int base, int32_t disp) { op_rm(a, 0, 0x0F, 0x10, xmm, base, -1, 1, disp); }
void x64_movups_mx(X64 *a, int base, int32_t disp, int xmm) { op_rm(a, 0, 0x0F, 0x11, xmm, base, -1, 1, disp); }
void x64_movups_xmi(X64 *a, int xmm, int base, int index, int scale, int32_t disp) { op_rm(a, 0, 0x0F, 0x10, xmm, base, index, scale, disp); }
void x64_movups_mix(X64 *a, int base, int index, int scale, int32_t disp, int xmm) { op_rm(a, 0, 0x0F, 0x11, xmm, base, index, scale, disp); }

/* ---- arithmetic ---- */
void x64_add_rr(X64 *a, int dst, int src) { op_rr(a, 1, 0x01, -1, src, dst); }
void x64_sub_rr(X64 *a, int dst, int src) { op_rr(a, 1, 0x29, -1, src, dst); }
void x64_and_rr(X64 *a, int dst, int src) { op_rr(a, 1, 0x21, -1, src, dst); }
void x64_or_rr(X64 *a, int dst, int src) { op_rr(a, 1, 0x09, -1, src, dst); }
void x64_xor_rr(X64 *a, int dst, int src) { op_rr(a, 1, 0x31, -1, src, dst); }
void x64_cmp_rr(X64 *a, int a_, int b) { op_rr(a, 1, 0x39, -1, b, a_); }
void x64_test_rr(X64 *a, int a_, int b) { op_rr(a, 1, 0x85, -1, b, a_); }
static void alu_ri(X64 *a, int ext, int r, int32_t imm) {
    if (imm >= -128 && imm <= 127) { op_rr(a, 1, 0x83, -1, ext, r); x64_byte(a, (uint8_t)(int8_t)imm); }
    else { op_rr(a, 1, 0x81, -1, ext, r); x64_u32(a, (uint32_t)imm); }
}
void x64_add_ri(X64 *a, int dst, int32_t imm) { alu_ri(a, 0, dst, imm); }
void x64_sub_ri(X64 *a, int dst, int32_t imm) { alu_ri(a, 5, dst, imm); }
void x64_and_ri(X64 *a, int dst, int32_t imm) { alu_ri(a, 4, dst, imm); }
void x64_cmp_ri(X64 *a, int r, int32_t imm) { alu_ri(a, 7, r, imm); }
void x64_imul_rr(X64 *a, int dst, int src) { op_rr(a, 1, 0x0F, 0xAF, dst, src); }
void x64_neg_r(X64 *a, int r) { op_rr(a, 1, 0xF7, -1, 3, r); }
void x64_not_r(X64 *a, int r) { op_rr(a, 1, 0xF7, -1, 2, r); }
void x64_shl_ri(X64 *a, int r, int imm) { op_rr(a, 1, 0xC1, -1, 4, r); x64_byte(a, (uint8_t)imm); }
void x64_shr_ri(X64 *a, int r, int imm) { op_rr(a, 1, 0xC1, -1, 5, r); x64_byte(a, (uint8_t)imm); }
void x64_sar_ri(X64 *a, int r, int imm) { op_rr(a, 1, 0xC1, -1, 7, r); x64_byte(a, (uint8_t)imm); }
void x64_shl_rcl(X64 *a, int r) { op_rr(a, 1, 0xD3, -1, 4, r); }
void x64_shr_rcl(X64 *a, int r) { op_rr(a, 1, 0xD3, -1, 5, r); }
void x64_cqo(X64 *a) { x64_byte(a, 0x48); x64_byte(a, 0x99); }
void x64_idiv_r(X64 *a, int r) { op_rr(a, 1, 0xF7, -1, 7, r); }
void x64_div_r(X64 *a, int r) { op_rr(a, 1, 0xF7, -1, 6, r); }
void x64_add_mi(X64 *a, int base, int32_t disp, int32_t imm) {
    if (imm >= -128 && imm <= 127) { op_rm(a, 1, 0x83, -1, 0, base, -1, 1, disp); x64_byte(a, (uint8_t)(int8_t)imm); }
    else { op_rm(a, 1, 0x81, -1, 0, base, -1, 1, disp); x64_u32(a, (uint32_t)imm); }
}
void x64_add_mr(X64 *a, int base, int32_t disp, int src) { op_rm(a, 1, 0x01, -1, src, base, -1, 1, disp); }
void x64_add_rm(X64 *a, int dst, int base, int32_t disp) { op_rm(a, 1, 0x03, -1, dst, base, -1, 1, disp); }
void x64_sub_mr(X64 *a, int base, int32_t disp, int src) { op_rm(a, 1, 0x29, -1, src, base, -1, 1, disp); }
void x64_cmp_mr(X64 *a, int base, int32_t disp, int src) { op_rm(a, 1, 0x39, -1, src, base, -1, 1, disp); }
void x64_cmp_rm(X64 *a, int r, int base, int32_t disp) { op_rm(a, 1, 0x3B, -1, r, base, -1, 1, disp); }
void x64_cmp_mi(X64 *a, int base, int32_t disp, int32_t imm) {
    if (imm >= -128 && imm <= 127) { op_rm(a, 1, 0x83, -1, 7, base, -1, 1, disp); x64_byte(a, (uint8_t)(int8_t)imm); }
    else { op_rm(a, 1, 0x81, -1, 7, base, -1, 1, disp); x64_u32(a, (uint32_t)imm); }
}
void x64_cmp8_mi(X64 *a, int base, int32_t disp, int imm8) { op_rm(a, 0, 0x80, -1, 7, base, -1, 1, disp); x64_byte(a, (uint8_t)imm8); }
void x64_cmp32_mi(X64 *a, int base, int32_t disp, int32_t imm) { op_rm(a, 0, 0x81, -1, 7, base, -1, 1, disp); x64_u32(a, (uint32_t)imm); }
void x64_setcc_r8(X64 *a, int cc, int r) {
    rex8(a, 0, 0, -1, r, r);
    x64_byte(a, 0x0F); x64_byte(a, (uint8_t)(0x90 + cc));
    modrm_rr(a, 0, r);
}

/* ---- SSE2 ---- */
static void sse_rm(X64 *a, int prefix, int op, int xmm, int base, int32_t disp) {
    x64_byte(a, (uint8_t)prefix);
    rex(a, 0, xmm, -1, base);
    x64_byte(a, 0x0F); x64_byte(a, (uint8_t)op);
    modrm_mem(a, xmm, base, -1, 1, disp);
}
static void sse_rr(X64 *a, int prefix, int op, int dst, int src) {
    x64_byte(a, (uint8_t)prefix);
    rex(a, 0, dst, -1, src);
    x64_byte(a, 0x0F); x64_byte(a, (uint8_t)op);
    modrm_rr(a, dst, src);
}
void x64_movsd_xm(X64 *a, int xmm, int base, int32_t disp) { sse_rm(a, 0xF2, 0x10, xmm, base, disp); }
void x64_movsd_mx(X64 *a, int base, int32_t disp, int xmm) { sse_rm(a, 0xF2, 0x11, xmm, base, disp); }
void x64_addsd(X64 *a, int dst, int src) { sse_rr(a, 0xF2, 0x58, dst, src); }
void x64_subsd(X64 *a, int dst, int src) { sse_rr(a, 0xF2, 0x5C, dst, src); }
void x64_mulsd(X64 *a, int dst, int src) { sse_rr(a, 0xF2, 0x59, dst, src); }
void x64_divsd(X64 *a, int dst, int src) { sse_rr(a, 0xF2, 0x5E, dst, src); }
void x64_ucomisd(X64 *a, int a_, int b) { sse_rr(a, 0x66, 0x2E, a_, b); }
void x64_xorpd(X64 *a, int dst, int src) { sse_rr(a, 0x66, 0x57, dst, src); }
void x64_movq_rx(X64 *a, int r, int xmm) { x64_byte(a, 0x66); rex(a, 1, xmm, -1, r); x64_byte(a, 0x0F); x64_byte(a, 0x7E); modrm_rr(a, xmm, r); }
void x64_movq_xr(X64 *a, int xmm, int r) { x64_byte(a, 0x66); rex(a, 1, xmm, -1, r); x64_byte(a, 0x0F); x64_byte(a, 0x6E); modrm_rr(a, xmm, r); }

/* ---- control ---- */
void x64_jmp(X64 *a, X64Label *l) { x64_byte(a, 0xE9); rel32(a, l); }
void x64_jcc(X64 *a, int cc, X64Label *l) { x64_byte(a, 0x0F); x64_byte(a, (uint8_t)(0x80 + cc)); rel32(a, l); }
void x64_jmp_r(X64 *a, int r) { rex(a, 0, 0, -1, r); x64_byte(a, 0xFF); modrm_rr(a, 4, r); }
void x64_jmp_m(X64 *a, int base, int index, int scale, int32_t disp) { op_rm(a, 0, 0xFF, -1, 4, base, index, scale, disp); }
void x64_call_r(X64 *a, int r) { rex(a, 0, 0, -1, r); x64_byte(a, 0xFF); modrm_rr(a, 2, r); }
void x64_ret(X64 *a) { x64_byte(a, 0xC3); }
void x64_push_r(X64 *a, int r) { rex(a, 0, 0, -1, r); x64_byte(a, (uint8_t)(0x50 + (r & 7))); }
void x64_pop_r(X64 *a, int r) { rex(a, 0, 0, -1, r); x64_byte(a, (uint8_t)(0x58 + (r & 7))); }
void x64_int3(X64 *a) { x64_byte(a, 0xCC); }
