/* What of a VM is the stack bytecode's (src/isa/stack.sml): the check of a
   program's code, its disassembly, and the fingerprint that .rbc files and
   images carry. Each VM links its own: runevm this one, from build/librune.a,
   and vm/new the register bytecode's (vm/new/isa_regs.c), whose definitions
   are taken before the archive's. */
#include "vm.h"

const uint32_t isa_fingerprint = ISA_FINGERPRINT;
const char isa_image_magic[ISA_IMAGE_MAGIC_SIZE] = "runevm image 4 isa " ISA_FINGERPRINT_HEX;

static int fail(char *err, size_t errlen, const char *msg) {
    snprintf(err, errlen, "%s", msg);
    return 0;
}

/* Where every instruction of a program begins, or NULL and a message: the
   opcodes, the ranges of the operands, and the jump targets and function
   entries, which must be instruction boundaries. The caller frees it.

   A .rbc is untrusted input and so, since Runtime.restore, is an image: both
   carry code, and both come through here (vm/image.c). */
uint8_t *validate_program(Program *p, char *err, size_t errlen) {
    for (uint32_t i = 0; i < p->nfuncs; i++) {
        if (p->funcs[i].code_offset >= p->code_len) { fail(err, errlen, "function offset out of range"); return NULL; }
        if (i > 0 && p->funcs[i].code_offset < p->funcs[i - 1].code_offset) { fail(err, errlen, "functions out of order"); return NULL; }
        if (p->funcs[i].nlocals < 1 || p->funcs[i].nlocals > 1000000) { fail(err, errlen, "bad frame size"); return NULL; }
        uint32_t end = (i + 1 < p->nfuncs) ? p->funcs[i + 1].code_offset : p->code_len;
        if (p->funcs[i].code_end != end) { fail(err, errlen, "function does not end where the next begins"); return NULL; }
    }
    uint8_t *starts = calloc(p->code_len + 1, 1);
    uint32_t fi = 0;
    uint32_t pc = 0;
    while (pc < p->code_len) {
        while (fi + 1 < p->nfuncs && pc >= p->funcs[fi + 1].code_offset) fi++;
        uint8_t op = p->code[pc];
        int len = instr_length(op);
        if (len == 0) { free(starts); snprintf(err, errlen, "invalid opcode %u at %u", op, pc); return NULL; }
        if (pc + len > p->code_len) { free(starts); fail(err, errlen, "truncated instruction"); return NULL; }
        starts[pc] = 1;
        int32_t a = len > 1 ? read_i32(p->code + pc + 1) : 0;
        int32_t b = len > 5 ? read_i32(p->code + pc + 5) : 0;
        /* each operand by its kind (src/isa/isa.sml); a label is checked
           below, once every instruction's start is known */
        int bad = 0;
        for (int k = 0; k < op_nargs[op] && !bad; k++) {
            int32_t v = k == 0 ? a : b;
            switch ((enum OperandKind)op_kinds[op][k]) {
            case OPND_CONSTANT: bad = v < 0 || (uint32_t)v >= p->nconsts; break;
            case OPND_STRING_CONSTANT: bad = v < 0 || (uint32_t)v >= p->nconsts || p->consts[v].tag != T_PTR; break;
            case OPND_IMMEDIATE: break;
            case OPND_TAG: bad = v < 0 || v > 65535; break;
            case OPND_LOCAL: bad = v < 0 || (uint32_t)v >= p->funcs[fi].nlocals; break;
            case OPND_ENV_SLOT: bad = v < 0; break;
            case OPND_GLOBAL: bad = v < 0 || (uint32_t)v >= p->nglobals; break;
            case OPND_FUNCTION: bad = v < 0 || (uint32_t)v >= p->nfuncs; break;
            case OPND_LABEL: case OPND_HANDLER_LABEL: break;
            case OPND_PRIMITIVE: bad = v < 0 || v >= PRIM__COUNT; break;
            case OPND_COUNT: bad = v < 0 || v > 1000000; break;
            case OPND_FIELD: bad = v < 0; break;
            case OPND_BUILTIN_EXN: bad = v < 0 || v >= NUM_BUILTIN_EXNS; break;
            }
        }
        if (bad) { free(starts); snprintf(err, errlen, "bad operand for %s at %u", op_names[op], pc); return NULL; }
        pc += len;
    }
    /* jump targets and function entries must be instruction boundaries */
    pc = 0;
    while (pc < p->code_len) {
        uint8_t op = p->code[pc];
        int len = instr_length(op);
        for (int k = 0; k < op_nargs[op]; k++)
            if (op_kinds[op][k] == OPND_LABEL || op_kinds[op][k] == OPND_HANDLER_LABEL) {
                int32_t t = read_i32(p->code + pc + 1 + 4 * k);
                if (t < 0 || (uint32_t)t >= p->code_len || !starts[t]) {
                    free(starts); snprintf(err, errlen, "bad jump target at %u", pc); return NULL;
                }
            }
        pc += len;
    }
    for (uint32_t i = 0; i < p->nfuncs; i++)
        if (!starts[p->funcs[i].code_offset]) { free(starts); fail(err, errlen, "function entry is not an instruction"); return NULL; }
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
            fprintf(out, "function %u %s (locals %u)\n", fi, p->funcs[fi].name, p->funcs[fi].nlocals);
            fi++;
        }
        uint8_t op = p->code[pc];
        int len = instr_length(op);
        fprintf(out, "  %6u  %s", pc, op_names[op]);
        for (int k = 0; k < op_nargs[op]; k++) fprintf(out, " %d", read_i32(p->code + pc + 1 + 4 * k));
        {
            const LineEntry *e = line_at(p, pc);
            if (e && e->file < p->nfiles) fprintf(out, "\t; %s:%u:%u", p->files[e->file], e->line, e->col);
        }
        fprintf(out, "\n");
        pc += len;
    }
}
