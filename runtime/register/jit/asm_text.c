/* The portable assembler (asm.h) as text (asm_text.h). */
#include "asm.h"
#include "native/native_offsets.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *const reg64[16] = { "%rax", "%rcx", "%rdx", "%rbx", "%rsp", "%rbp", "%rsi", "%rdi",
                                       "%r8", "%r9", "%r10", "%r11", "%r12", "%r13", "%r14", "%r15" };
static const char *const reg32[16] = { "%eax", "%ecx", "%edx", "%ebx", "%esp", "%ebp", "%esi", "%edi",
                                       "%r8d", "%r9d", "%r10d", "%r11d", "%r12d", "%r13d", "%r14d", "%r15d" };
static const char *const ccname[16] = { "o", "no", "b", "ae", "e", "ne", "be", "a", "s", "ns", "p", "np", "l", "ge", "le", "g" };

static void emit(Asm *a, const char *fmt, ...);

static void fail(Asm *a, const char *what) { a->failed = 1; emit(a, "# cannot say: %s", what); }

/* a register's name, 64 or 32 bits, or its hole */
static const char *r64(const Asm *a, int r) {
    for (int i = 0; i < a->nregs; i++) if (a->regs[i].reg == r) return a->regs[i].name;
    return r >= 0 && r < 16 ? reg64[r] : "?";
}
static char r32buf[4][40];
static int r32n;
static const char *r32(const Asm *a, int r) {
    for (int i = 0; i < a->nregs; i++) if (a->regs[i].reg == r) {
        char *b = r32buf[r32n++ & 3];
        size_t n = strlen(a->regs[i].name);
        /* {name} -> {name32} */
        snprintf(b, sizeof r32buf[0], "%.*s32}", (int)(n - 1), a->regs[i].name);
        return b;
    }
    return r >= 0 && r < 16 ? reg32[r] : "?";
}
static char xbuf[4][8];
static int xn;
static const char *xmm(int f) { char *b = xbuf[xn++ & 3]; snprintf(b, sizeof xbuf[0], "%%xmm%d", f); return b; }

/* a memory operand [base + disp], by name where the layout has one */
static char membuf[4][96];
static int memn;
static const char *mem(Asm *a, int base, int32_t disp) {
    char *b = membuf[memn++ & 3];
    if (base == R_BASER) {
        for (int i = 0; i < a->nslots; i++) {
            int32_t at = (int32_t)sizeof(Value) * a->slots[i].index;
            if (disp >= at && disp < at + (int32_t)sizeof(Value)) {
                if (a->slots[i].name[0] == '*') {   /* the whole operand is the hole */
                    if (disp != at) fail(a, "a part of an operand that is a whole hole");
                    snprintf(b, 96, "%s", a->slots[i].name + 1);
                    return b;
                }
                if (disp == at) snprintf(b, 96, "%s(%%r13,%%rbp)", a->slots[i].name);
                else snprintf(b, 96, "%s+%d(%%r13,%%rbp)", a->slots[i].name, (int)(disp - at));
                return b;
            }
        }
        fail(a, "a frame slot the generator did not mark");
        snprintf(b, 96, "%d(%%r13,%%rbp)", (int)disp);
        return b;
    }
    if (base == R_VM) {
#define VMNAME(name, value) if (strncmp(name, "VM_", 3) == 0 && (int32_t)(value) == disp) { snprintf(b, 96, "%s(%%r12)", name); return b; }
        NATIVE_OFFSETS(VMNAME)
#undef VMNAME
        fail(a, "a field of the VM that runtime/native/native_offsets.h does not name");
        snprintf(b, 96, "%d(%%r12)", (int)disp);
        return b;
    }
    if (disp == 0) snprintf(b, 96, "(%s)", r64(a, base));
    else if (disp == (int32_t)offsetof(Obj, contag)) snprintf(b, 96, "OBJ_CONTAG(%s)", r64(a, base));
    else if (disp == (int32_t)offsetof(Obj, len)) snprintf(b, 96, "OBJ_LEN(%s)", r64(a, base));
    else if (disp == (int32_t)sizeof(Obj)) snprintf(b, 96, "OBJ_FIELDS(%s)", r64(a, base));
    else if (disp > (int32_t)sizeof(Obj)) snprintf(b, 96, "OBJ_FIELDS+%d(%s)", (int)(disp - (int32_t)sizeof(Obj)), r64(a, base));
    else snprintf(b, 96, "%d(%s)", (int)disp, r64(a, base));
    return b;
}
/* an immediate in a kind context (an object's first byte). A value is one
   word (docs/plans/heap-layout.md, M4), so a slot has no tag byte and what
   is written to one is a number. */
static char immbuf[4][40];
static int immn;
static const char *imm_kind(Asm *a, int v) {
    char *b = immbuf[immn++ & 3];
    for (int i = 0; i < a->nkinds; i++) if (a->kinds[i].value == v) { snprintf(b, 40, "$%s", a->kinds[i].name); return b; }
    snprintf(b, 40, "$%d", v);
    return b;
}
static const char *label(Asm *a, AsmTextLabel *l) {
    if (l->name) return l->name;
    if (!l->made[0]) snprintf(l->made, sizeof l->made, "{l}_%c", 'a' + (a->nlabels++ % 26));
    return l->made;
}

#include <stdarg.h>
static void emit(Asm *a, const char *fmt, ...) {
    char buf[256];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    if (a->n == a->cap) {
        int cap = a->cap ? 2 * a->cap : 64;
        char **l = realloc(a->lines, (size_t)cap * sizeof *l);
        if (!l) { a->failed = 1; return; }
        a->lines = l;
        a->cap = cap;
    }
    size_t len = strlen(buf) + 1;
    char *copy = malloc(len);
    if (!copy) { a->failed = 1; return; }
    memcpy(copy, buf, len);
    a->lines[a->n++] = copy;
}

void tx_slot(Asm *a, int32_t index, const char *name) { if (a->nslots < 8) { a->slots[a->nslots].index = index; a->slots[a->nslots++].name = name; } }
void tx_reg(Asm *a, int reg, const char *name) { if (a->nregs < 8) { a->regs[a->nregs].reg = reg; a->regs[a->nregs++].name = name; } }
void tx_kind_name(Asm *a, int value, const char *name) { if (a->nkinds < 16) { a->kinds[a->nkinds].value = value; a->kinds[a->nkinds++].name = name; } }
void tx_clear(Asm *a) { for (int i = 0; i < a->n; i++) free(a->lines[i]); a->n = 0; a->failed = 0; a->nlabels = 0; }
void tx_label_name(AsmTextLabel *l, const char *name) { l->name = name; }

/* ---- asm.h ---- */
void as_init(Asm *a) { memset(a, 0, sizeof *a); }
void as_free(Asm *a) { tx_clear(a); free(a->lines); a->lines = NULL; a->cap = 0; }
void as_label_init(AsmLabel *l) { memset(l, 0, sizeof *l); }
void as_label_free(AsmLabel *l) { (void)l; }
void as_bind(Asm *a, AsmLabel *l) { l->bound = 1; emit(a, "%s:", label(a, l)); }
int as_bound(const AsmLabel *l) { return l->bound; }
int as_dangling(const AsmLabel *l) { (void)l; return 0; }
void as_u32(Asm *a, uint32_t v) { emit(a, ".long %u", (unsigned)v); }
void as_u64(Asm *a, uint64_t v) { emit(a, ".quad %llu", (unsigned long long)v); }
void as_offset32_at(Asm *a, size_t at, size_t table_at, AsmLabel *l) { (void)at; (void)table_at; (void)l; fail(a, "a jump table"); }
size_t as_align4(Asm *a) { return (size_t)a->n; }

void as_mov_rr(Asm *a, int rd, int rs) { emit(a, "mov %s, %s", r64(a, rs), r64(a, rd)); }
void as_mov_ri(Asm *a, int rd, int64_t v) {
    if (v >= INT32_MIN && v <= INT32_MAX) emit(a, "mov $%lld, %s", (long long)v, r64(a, rd));
    else emit(a, "movabs $%lld, %s", (long long)v, r64(a, rd));
}
void as_ld64(Asm *a, int rd, int base, int32_t disp) { emit(a, "mov %s, %s", mem(a, base, disp), r64(a, rd)); }
void as_ld32(Asm *a, int rd, int base, int32_t disp) { emit(a, "mov %s, %s", mem(a, base, disp), r32(a, rd)); }
void as_ld32s(Asm *a, int rd, int base, int32_t disp) { emit(a, "movslq %s, %s", mem(a, base, disp), r64(a, rd)); }
void as_ld32sx(Asm *a, int rd, int base, int index) { emit(a, "movslq (%s,%s,4), %s", r64(a, base), r64(a, index), r64(a, rd)); }
void as_ld16(Asm *a, int rd, int base, int32_t disp) { emit(a, "movzwl %s, %s", mem(a, base, disp), r32(a, rd)); }
void as_ld8(Asm *a, int rd, int base, int32_t disp) { emit(a, "movzbl %s, %s", mem(a, base, disp), r32(a, rd)); }
void as_st64(Asm *a, int base, int32_t disp, int rs) { emit(a, "mov %s, %s", r64(a, rs), mem(a, base, disp)); }
void as_st32(Asm *a, int base, int32_t disp, int rs) { emit(a, "mov %s, %s", r32(a, rs), mem(a, base, disp)); }
void as_st8(Asm *a, int base, int32_t disp, int rs) { (void)rs; fail(a, "an 8-bit store of a register"); (void)base; (void)disp; }
void as_st64i(Asm *a, int base, int32_t disp, int32_t v) { emit(a, "movq $%d, %s", (int)v, mem(a, base, disp)); }
void as_st32i(Asm *a, int base, int32_t disp, int32_t v) { emit(a, "movl $%d, %s", (int)v, mem(a, base, disp)); }
void as_st8i(Asm *a, int base, int32_t disp, int v) { emit(a, "movb $%d, %s", v, mem(a, base, disp)); }
void as_lea(Asm *a, int rd, int base, int index, int scale, int32_t disp) {
    if (index < 0) emit(a, "lea %d(%s), %s", (int)disp, r64(a, base), r64(a, rd));
    else emit(a, "lea %d(%s,%s,%d), %s", (int)disp, r64(a, base), r64(a, index), scale, r64(a, rd));
}
void as_lea_label(Asm *a, int rd, AsmLabel *l) { emit(a, "lea %s(%%rip), %s", label(a, l), r64(a, rd)); }
void as_ld128(Asm *a, int f, int base, int32_t disp) { emit(a, "movdqu %s, %s", mem(a, base, disp), xmm(f)); }
void as_st128(Asm *a, int base, int32_t disp, int f) { emit(a, "movdqu %s, %s", xmm(f), mem(a, base, disp)); }
void as_ld128x(Asm *a, int f, int base, int index) { emit(a, "movdqu (%s,%s), %s", r64(a, base), r64(a, index), xmm(f)); }
void as_st128x(Asm *a, int base, int index, int f) { emit(a, "movdqu %s, (%s,%s)", xmm(f), r64(a, base), r64(a, index)); }

void as_add_rr(Asm *a, int rd, int rs) { emit(a, "add %s, %s", r64(a, rs), r64(a, rd)); }
void as_sub_rr(Asm *a, int rd, int rs) { emit(a, "sub %s, %s", r64(a, rs), r64(a, rd)); }
void as_and_rr(Asm *a, int rd, int rs) { emit(a, "and %s, %s", r64(a, rs), r64(a, rd)); }
void as_or_rr(Asm *a, int rd, int rs) { emit(a, "or %s, %s", r64(a, rs), r64(a, rd)); }
void as_xor_rr(Asm *a, int rd, int rs) { emit(a, "xor %s, %s", r64(a, rs), r64(a, rd)); }
void as_cmp_rr(Asm *a, int ra, int rb) { emit(a, "cmp %s, %s", r64(a, rb), r64(a, ra)); }
void as_test_rr(Asm *a, int ra, int rb) { emit(a, "test %s, %s", r64(a, rb), r64(a, ra)); }
void as_add_ri(Asm *a, int rd, int32_t v) { emit(a, "add $%d, %s", (int)v, r64(a, rd)); }
void as_sub_ri(Asm *a, int rd, int32_t v) { emit(a, "sub $%d, %s", (int)v, r64(a, rd)); }
void as_cmp_ri(Asm *a, int r, int32_t v) { emit(a, "cmp $%d, %s", (int)v, r64(a, r)); }
void as_and_ri(Asm *a, int rd, int32_t v) { emit(a, "and $%d, %s", (int)v, r64(a, rd)); }
void as_or_ri(Asm *a, int rd, int32_t v) { emit(a, "or $%d, %s", (int)v, r64(a, rd)); }
void as_test_ri(Asm *a, int r, int32_t v) { emit(a, "test $%d, %s", (int)v, r64(a, r)); }
void as_test8_mi(Asm *a, int base, int32_t disp, int v) { emit(a, "testb $%d, %s", v, mem(a, base, disp)); }
void as_ror_ri(Asm *a, int r, int n) { emit(a, "ror $%d, %s", n, r64(a, r)); }
void as_add_jc(Asm *a, int rd, int rs, AsmLabel *carry) { as_add_rr(a, rd, rs); as_jcc(a, CC_B, carry); }
void as_sub_jb(Asm *a, int rd, int rs, AsmLabel *borrow) { as_sub_rr(a, rd, rs); as_jcc(a, CC_B, borrow); }
void as_mul_rr(Asm *a, int rd, int rs) { emit(a, "imul %s, %s", r64(a, rs), r64(a, rd)); }
void as_mul_ri(Asm *a, int rd, int rs, int32_t v) { emit(a, "imul $%d, %s, %s", (int)v, r64(a, rs), r64(a, rd)); }
void as_mul_jo(Asm *a, int rd, int rs, AsmLabel *overflow) { as_mul_rr(a, rd, rs); as_jcc(a, CC_O, overflow); }
void as_neg(Asm *a, int r) { emit(a, "neg %s", r64(a, r)); }
void as_not(Asm *a, int r) { emit(a, "not %s", r64(a, r)); }
void as_shl_ri(Asm *a, int r, int n) { emit(a, "shl $%d, %s", n, r64(a, r)); }
void as_shr_ri(Asm *a, int r, int n) { emit(a, "shr $%d, %s", n, r64(a, r)); }
void as_sar_ri(Asm *a, int r, int n) { emit(a, "sar $%d, %s", n, r64(a, r)); }
void as_shl_rr(Asm *a, int r) { emit(a, "shl %%cl, %s", r64(a, r)); }
void as_shr_rr(Asm *a, int r) { emit(a, "shr %%cl, %s", r64(a, r)); }
void as_divmod(Asm *a, int divisor) { emit(a, "cqo"); emit(a, "idiv %s", r64(a, divisor)); }
void as_udivmod(Asm *a, int divisor) { emit(a, "xor %%edx, %%edx"); emit(a, "div %s", r64(a, divisor)); }
void as_add_mi(Asm *a, int base, int32_t disp, int32_t v) { emit(a, "addq $%d, %s", (int)v, mem(a, base, disp)); }
void as_add_rm(Asm *a, int rd, int base, int32_t disp) { emit(a, "add %s, %s", mem(a, base, disp), r64(a, rd)); }
void as_cmp_rm(Asm *a, int r, int base, int32_t disp) { emit(a, "cmp %s, %s", mem(a, base, disp), r64(a, r)); }
void as_cmp_mi(Asm *a, int base, int32_t disp, int32_t v) { emit(a, "cmpq $%d, %s", (int)v, mem(a, base, disp)); }
void as_cmp8_mi(Asm *a, int base, int32_t disp, int v) {
    if (base != R_BASER && base != R_VM && disp == (int32_t)offsetof(Obj, kind)) emit(a, "cmpb %s, OBJ_KIND(%s)", imm_kind(a, v), r64(a, base));
    else emit(a, "cmpb $%d, %s", v, mem(a, base, disp));
}
void as_cmp32_mi(Asm *a, int base, int32_t disp, int32_t v) { emit(a, "cmpl $%d, %s", (int)v, mem(a, base, disp)); }

void as_jmp(Asm *a, AsmLabel *l) { emit(a, "jmp %s", label(a, l)); }
void as_jcc(Asm *a, int cc, AsmLabel *l) {
    if (cc >= 0 && cc < 16) emit(a, "j%s %s", ccname[cc], label(a, l));
    else fail(a, "a floating-point condition");
}
void as_jmp_r(Asm *a, int r) { emit(a, "jmp *%s", r64(a, r)); }
void as_jmp_to(Asm *a, const void *at) { (void)at; fail(a, "a jump to an address"); }
void as_call_r(Asm *a, int r) { emit(a, "call *%s", r64(a, r)); }
void as_ret(Asm *a) { emit(a, "ret"); }
void as_trap(Asm *a) { emit(a, "ud2"); }
void as_setcc(Asm *a, int rd, int cc) {
    if (cc >= 0 && cc < 16) { emit(a, "set%s %%al", ccname[cc]); emit(a, "movzbl %%al, %s", r32(a, rd)); }
    else fail(a, "a floating-point condition");
}
void as_push(Asm *a, int r) { emit(a, "push %s", r64(a, r)); emit(a, "sub $8, %%rsp"); }
void as_pop(Asm *a, int r) { emit(a, "add $8, %%rsp"); emit(a, "pop %s", r64(a, r)); }

void as_fld(Asm *a, int f, int base, int32_t disp) { emit(a, "movsd %s, %s", mem(a, base, disp), xmm(f)); }
void as_fst(Asm *a, int base, int32_t disp, int f) { emit(a, "movsd %s, %s", xmm(f), mem(a, base, disp)); }
void as_fmov(Asm *a, int fd, int fs) { emit(a, "movapd %s, %s", xmm(fs), xmm(fd)); }
void as_fadd(Asm *a, int fd, int fs) { emit(a, "addsd %s, %s", xmm(fs), xmm(fd)); }
void as_fsub(Asm *a, int fd, int fs) { emit(a, "subsd %s, %s", xmm(fs), xmm(fd)); }
void as_fmul(Asm *a, int fd, int fs) { emit(a, "mulsd %s, %s", xmm(fs), xmm(fd)); }
void as_fdiv(Asm *a, int fd, int fs) { emit(a, "divsd %s, %s", xmm(fs), xmm(fd)); }
void as_fsqrt(Asm *a, int fd, int fs) { emit(a, "sqrtsd %s, %s", xmm(fs), xmm(fd)); }
void as_fcmp(Asm *a, int fa, int fb) { emit(a, "ucomisd %s, %s", xmm(fb), xmm(fa)); }
void as_fzero(Asm *a, int f) { emit(a, "xorpd %s, %s", xmm(f), xmm(f)); }
void as_fmov_rf(Asm *a, int r, int f) { emit(a, "movq %s, %s", xmm(f), r64(a, r)); }
void as_fmov_fr(Asm *a, int f, int r) { emit(a, "movq %s, %s", r64(a, r), xmm(f)); }

void as_stub_enter(Asm *a, int win) { (void)win; fail(a, "the enter stub"); }
void as_stub_leave(Asm *a, int win) { (void)win; fail(a, "the leave stub"); }
int as_arg(int win, int i) { static const int sysv[4] = { RDI, RSI, RDX, RCX }, w[4] = { RCX, RDX, R8, R9 }; return win ? w[i] : sysv[i]; }
void as_call_c(Asm *a, int win, uint64_t addr) { (void)win; (void)addr; fail(a, "a call into C"); }
