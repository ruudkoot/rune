/* What of vm/new is the register bytecode's (src/isa/regs.sml): the check of
   a program's code, its disassembly, and the fingerprint its .rbc files and
   images carry. It takes the place of vm/isa_stack.c, which build/librune.a
   holds for runevm: a definition here is taken before the archive's. */
#include "regvm.h"

const uint32_t isa_fingerprint = REG_ISA_FINGERPRINT;
const char isa_image_magic[ISA_IMAGE_MAGIC_SIZE] = "runevm image 4 isa " REG_ISA_FINGERPRINT_HEX;

static int fail(char *err, size_t errlen, const char *msg) {
    snprintf(err, errlen, "%s", msg);
    return 0;
}

/* Is v, an operand of this kind, one the program allows? A register is
   one of the frame's; the rest are as in the stack bytecode. */
static int operand_ok(const Program *p, uint32_t fi, int kind, int32_t v) {
    switch ((enum RegOperandKind)kind) {
    case RK_REGISTER: return v >= 0 && (uint32_t)v < p->funcs[fi].nlocals;
    case RK_CONSTANT: return v >= 0 && (uint32_t)v < p->nconsts;
    case RK_STRING_CONSTANT: return v >= 0 && (uint32_t)v < p->nconsts && p->consts[v].tag == T_PTR;
    case RK_IMMEDIATE: return 1;
    case RK_TAG: return v >= 0 && v <= 65535;
    case RK_ENV_SLOT: return v >= 0;
    case RK_GLOBAL: return v >= 0 && (uint32_t)v < p->nglobals;
    case RK_FUNCTION: return v >= 0 && (uint32_t)v < p->nfuncs;
    case RK_LABEL: case RK_HANDLER_LABEL: return 1;     /* checked below, once every start is known */
    case RK_PRIMITIVE: return v >= 0 && v < PRIM__COUNT;
    case RK_COUNT: return v >= 0 && v <= 1000000;
    case RK_FIELD: return v >= 0;
    case RK_BUILTIN_EXN: return v >= 0 && v < NUM_BUILTIN_EXNS;
    default: return 0;
    }
}

/* Where every instruction of a program begins, or NULL and a message: the
   opcodes, the operands by their kinds (a register below the frame's
   number, every register of a list among them), the jump targets and the
   function entries. A .rbc and an image are untrusted input alike. */
uint8_t *validate_program(Program *p, char *err, size_t errlen) {
    for (uint32_t i = 0; i < p->nfuncs; i++) {
        if (p->funcs[i].code_offset >= p->code_len) { fail(err, errlen, "function offset out of range"); return NULL; }
        if (i > 0 && p->funcs[i].code_offset < p->funcs[i - 1].code_offset) { fail(err, errlen, "functions out of order"); return NULL; }
        if (p->funcs[i].nlocals < 1 || p->funcs[i].nlocals > 1000000) { fail(err, errlen, "bad frame size"); return NULL; }
        uint32_t end = (i + 1 < p->nfuncs) ? p->funcs[i + 1].code_offset : p->code_len;
        if (p->funcs[i].code_end != end) { fail(err, errlen, "function does not end where the next begins"); return NULL; }
    }
    uint8_t *starts = calloc(p->code_len + 1, 1);
    if (!starts) { fail(err, errlen, "out of memory"); return NULL; }
    uint32_t fi = 0;
    uint32_t pc = 0;
    while (pc < p->code_len) {
        while (fi + 1 < p->nfuncs && pc >= p->funcs[fi + 1].code_offset) fi++;
        const uint8_t *at = p->code + pc;
        uint8_t op = at[0];
        if (op >= ROP__COUNT) { free(starts); snprintf(err, errlen, "invalid opcode %u at %u", op, pc); return NULL; }
        if (pc + 1 + 4 * (uint32_t)rop_nfixed[op] > p->code_len) { free(starts); fail(err, errlen, "truncated instruction"); return NULL; }
        int bad = 0;
        for (int k = 0; k < rop_nfixed[op] && !bad; k++)
            bad = !operand_ok(p, fi, rop_kinds[op][k], read_i32(at + 1 + 4 * k));
        if (bad) { free(starts); snprintf(err, errlen, "bad operand for %s at %u", rop_names[op], pc); return NULL; }
        uint32_t len = rop_length(at);
        if (pc + len > p->code_len || (uint64_t)pc + len > p->code_len) { free(starts); fail(err, errlen, "truncated instruction"); return NULL; }
        uint32_t n = rop_list_length(at);
        for (uint32_t i = 0; i < n && !bad; i++)
            bad = !operand_ok(p, fi, RK_REGISTER, read_i32(at + 1 + 4 * (rop_nfixed[op] + i)));
        if (bad) { free(starts); snprintf(err, errlen, "bad register for %s at %u", rop_names[op], pc); return NULL; }
        starts[pc] = 1;
        pc += len;
    }
    /* jump targets and function entries must be instruction boundaries */
    pc = 0;
    while (pc < p->code_len) {
        const uint8_t *at = p->code + pc;
        uint8_t op = at[0];
        for (int k = 0; k < rop_nfixed[op]; k++)
            if (rop_kinds[op][k] == RK_LABEL || rop_kinds[op][k] == RK_HANDLER_LABEL) {
                int32_t t = read_i32(at + 1 + 4 * k);
                if (t < 0 || (uint32_t)t >= p->code_len || !starts[t]) {
                    free(starts); snprintf(err, errlen, "bad jump target at %u", pc); return NULL;
                }
            }
        pc += rop_length(at);
    }
    for (uint32_t i = 0; i < p->nfuncs; i++) {
        if (!starts[p->funcs[i].code_offset]) { free(starts); fail(err, errlen, "function entry is not an instruction"); return NULL; }
        /* the registers are the frame; what is pushed beyond them, a
           primitive's arguments and a call's result, is pushed with a check */
        p->funcs[i].maxstack = 0;
    }
    return starts;
}

void disassemble(const Program *p, FILE *out) {
    for (uint32_t i = 0; i < p->nconsts; i++) {
        Value c = p->consts[i];
        fprintf(out, "const %u = ", i);
        switch (c.tag) {
        case T_INT: fprintf(out, "%lld\n", (long long)c.u.i); break;
        case T_WORD: fprintf(out, "0wx%llX\n", (unsigned long long)c.u.w); break;
        case T_REAL: fprintf(out, "%g\n", c.u.d); break;
        case T_CHAR: fprintf(out, "#%lld\n", (long long)c.u.i); break;
        case T_PTR: fprintf(out, "\"%.*s\"\n", (int)c.u.p->len, OBJ_BYTES(c.u.p)); break;
        default: fprintf(out, "?\n");
        }
    }
    fprintf(out, "globals %u\n", p->nglobals);
    uint32_t fi = 0;
    uint32_t pc = 0;
    while (pc < p->code_len) {
        while (fi < p->nfuncs && pc == p->funcs[fi].code_offset) {
            fprintf(out, "function %u %s (registers %u)\n", fi, p->funcs[fi].name, p->funcs[fi].nlocals);
            fi++;
        }
        const uint8_t *at = p->code + pc;
        uint8_t op = at[0];
        uint32_t len = rop_length(at);
        fprintf(out, "  %6u  %s", pc, rop_names[op]);
        for (uint32_t k = 0; 1 + 4 * k < len; k++) fprintf(out, " %d", read_i32(at + 1 + 4 * k));
        const LineEntry *e = line_at(p, pc);
        if (e && e->file < p->nfiles) fprintf(out, "\t; %s:%u:%u", p->files[e->file], e->line, e->col);
        fprintf(out, "\n");
        pc += len;
    }
}
