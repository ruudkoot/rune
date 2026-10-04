/* What of runtime/register is the register bytecode's (src/isa/regs.sml): the check of
   a program's code, its disassembly, and the fingerprint its .rbc files and
   images carry. It takes the place of runtime/stack/isa_stack.c, which build/librune.a
   holds for runevm-stack: a definition here is taken before the archive's. */
#include "regvm.h"

const uint32_t isa_fingerprint = REG_ISA_FINGERPRINT;
const char isa_image_magic[ISA_IMAGE_MAGIC_SIZE] = "runevm image 9 isa " REG_ISA_FINGERPRINT_HEX;

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
    case RK_STRING_CONSTANT: return v >= 0 && (uint32_t)v < p->nconsts && val_is(p->consts[v], T_PTR);
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
   number, every register of a list among them), the jump targets, which
   stay in their function, and the function entries. A .rbc and an image
   are untrusted input alike. On the way it works out how deep each
   function's stack goes above its registers (Function.maxstack): the
   arguments of a primitive, or the one value a call returns and a raise
   leaves for CATCH. The loop's pushes do not check (runtime/register/interp.c),
   which this is what makes safe. */
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
    for (uint32_t i = 0; i < p->nfuncs; i++) p->funcs[i].maxstack = 1;
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
        /* a known call gives no more arguments than its function has registers */
        if ((op == ROP_CALLK || op == ROP_TAILCALLK) && !bad)
            bad = read_i32(at + 5) > (int32_t)p->funcs[read_i32(at + 1)].nlocals;
        if (bad) { free(starts); snprintf(err, errlen, "bad operand for %s at %u", rop_names[op], pc); return NULL; }
        uint32_t len = rop_length(at);
        if (pc + len > p->code_len || (uint64_t)pc + len > p->code_len) { free(starts); fail(err, errlen, "truncated instruction"); return NULL; }
        uint32_t n = rop_list_length(at);
        for (uint32_t i = 0; i < n && !bad; i++)
            bad = !operand_ok(p, fi, RK_REGISTER, read_i32(at + 1 + 4 * (rop_nfixed[op] + i)));
        if (bad) { free(starts); snprintf(err, errlen, "bad register for %s at %u", rop_names[op], pc); return NULL; }
        if ((op == ROP_PRIM || op == ROP_PRIMPUSH) && n > p->funcs[fi].maxstack) p->funcs[fi].maxstack = n;
        starts[pc] = 1;
        pc += len;
    }
    /* jump targets and function entries must be instruction boundaries,
       and a jump stays in its function; a SWITCH's table is JUMPs of its
       own function, which the code goes on after */
    pc = 0;
    fi = 0;
    while (pc < p->code_len) {
        while (fi + 1 < p->nfuncs && pc >= p->funcs[fi + 1].code_offset) fi++;
        const uint8_t *at = p->code + pc;
        uint8_t op = at[0];
        uint32_t from = p->funcs[fi].code_offset, to = p->funcs[fi].code_end;
        if (op == ROP_SWITCH) {
            uint32_t n = (uint32_t)read_i32(at + 5);
            uint64_t table = (uint64_t)pc + rop_length(at);
            uint64_t end = table + 5 * (uint64_t)n;
            int bad = end >= p->funcs[fi].code_end;
            for (uint32_t k = 0; k < n && !bad; k++) {
                uint64_t e = table + 5 * (uint64_t)k;
                bad = !starts[e] || p->code[e] != ROP_JUMP;
            }
            if (bad || !starts[end]) { free(starts); snprintf(err, errlen, "bad SWITCH table at %u", pc); return NULL; }
        }
        for (int k = 0; k < rop_nfixed[op]; k++)
            if (rop_kinds[op][k] == RK_LABEL || rop_kinds[op][k] == RK_HANDLER_LABEL) {
                int32_t t = read_i32(at + 1 + 4 * k);
                if (t < 0 || (uint32_t)t < from || (uint32_t)t >= to || !starts[t]) {
                    free(starts); snprintf(err, errlen, "bad jump target at %u", pc); return NULL;
                }
            }
        pc += rop_length(at);
    }
    for (uint32_t i = 0; i < p->nfuncs; i++)
        if (!starts[p->funcs[i].code_offset]) { free(starts); fail(err, errlen, "function entry is not an instruction"); return NULL; }
    /* the representations section, where the file has one: its blocks
       and loop heads begin at instructions of their functions, and each
       register's representation agrees with what the code writes into it,
       where the instruction says (docs/bytecode.md, The representations) */
    for (uint32_t fi = 0; fi < p->nfuncs; fi++) {
        const Function *fn = &p->funcs[fi];
        if (!fn->has_meta) continue;
        for (uint32_t b = 0; b < fn->nblocks; b++)
            if (fn->blocks[b].pc < fn->code_offset || fn->blocks[b].pc >= fn->code_end || !starts[fn->blocks[b].pc]) {
                free(starts); snprintf(err, errlen, "a block of %s begins at %u, which is no instruction of it", fn->name, fn->blocks[b].pc); return NULL;
            }
        for (uint32_t k = 0; k < fn->nloops; k++)
            if (fn->loops[k] < fn->code_offset || fn->loops[k] >= fn->code_end || !starts[fn->loops[k]]) {
                free(starts); snprintf(err, errlen, "a loop of %s begins at %u, which is no instruction of it", fn->name, fn->loops[k]); return NULL;
            }
        for (uint32_t at = fn->code_offset; at < fn->code_end; ) {
            uint8_t op = p->code[at];
            uint32_t l = rop_length(p->code + at);
            int made = -1;   /* what the instruction writes, where it says */
            switch (op) {
            case ROP_INT: case ROP_CONTAG: made = REP_INT; break;
            case ROP_UNIT: made = REP_UNIT; break;
            case ROP_CON0: made = REP_CON0; break;
            case ROP_TUPLE: case ROP_CLOSURE: case ROP_NEWEXN: case ROP_BUILTINEXN: case ROP_MKEXN:
            case ROP_SELF: case ROP_EXNCON: case ROP_CON: case ROP_CONN: made = REP_PTR; break;
            case ROP_CONST: {
                int32_t c = read_i32(p->code + at + 5);
                if (c >= 0 && (uint32_t)c < p->nconsts)
                    /* by the kind the bytecode gave it: an immediate's is not in its bits */
                    switch (p->const_kinds[c]) {
                    case CONST_INT: made = REP_INT; break;
                    case CONST_WORD: made = REP_WORD; break;
                    case CONST_INT64: made = REP_INT64; break;
                    case CONST_WORD64: made = REP_WORD64; break;
                    case CONST_REAL: made = REP_REAL; break;
                    case CONST_CHAR: made = REP_CHAR; break;
                    case CONST_STRING: made = REP_PTR; break;
                    default: break;
                    }
                break;
            }
            case ROP_PRIM: {
                int32_t prim = read_i32(p->code + at + 1);
                if (prim >= 0 && prim < PRIM__COUNT && prim_result[prim] != REP_ANY) made = prim_result[prim];
                break;
            }
            default: break;
            }
            if (made >= 0 && rop_dest[op] >= 0) {
                int32_t d = read_i32(p->code + at + 1 + 4 * rop_dest[op]);
                int have = d >= 0 && (uint32_t)d < fn->nlocals ? fn->reps[d] : REP_ANY;
                int ok = have == REP_ANY || have == made
                      || (have == REP_CON && (made == REP_CON0 || made == REP_PTR));
                if (!ok) {
                    free(starts);
                    snprintf(err, errlen, "the representation of register %d of %s disagrees with the code at %u", d, fn->name, at);
                    return NULL;
                }
            }
            if (op == ROP_SWITCH) at += l + 5 * (uint32_t)read_i32(p->code + at + 5);
            else at += l;
        }
    }
    return starts;
}

void disassemble(const Program *p, FILE *out) {
    for (uint32_t i = 0; i < p->nconsts; i++) {
        Value c = p->consts[i];
        fprintf(out, "const %u = ", i);
        switch (p->const_kinds[i]) {   /* what the bytecode said: the value does not */
        case CONST_INT: fprintf(out, "%lld\n", (long long)val_int(c)); break;
        case CONST_WORD: fprintf(out, "0wx%llX\n", (unsigned long long)val_word(c)); break;
        case CONST_INT64: fprintf(out, "%lld\n", (long long)val_int64(c)); break;
        case CONST_WORD64: fprintf(out, "0wx%llX\n", (unsigned long long)val_word64(c)); break;
        case CONST_REAL: fprintf(out, "%g\n", val_real(c)); break;
        case CONST_CHAR: fprintf(out, "#%lld\n", (long long)val_char(c)); break;
        case CONST_STRING: fprintf(out, "\"%.*s\"\n", (int)obj_len(val_ptr(c)), obj_bytes(val_ptr(c))); break;
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
