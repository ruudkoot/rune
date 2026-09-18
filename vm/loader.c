/* Bytecode loader with validation: the .rbc file is untrusted input. */
#include "vm.h"

typedef struct Reader {
    const uint8_t *data;
    size_t len, pos;
    int error;
} Reader;

static int need(Reader *r, size_t n) {
    if (r->pos + n > r->len) { r->error = 1; return 0; }
    return 1;
}

static uint8_t rd_u8(Reader *r) { if (!need(r, 1)) return 0; return r->data[r->pos++]; }
static uint32_t rd_u32(Reader *r) { if (!need(r, 4)) return 0; uint32_t v = read_u32(r->data + r->pos); r->pos += 4; return v; }
static int64_t rd_i64(Reader *r) {
    if (!need(r, 8)) return 0;
    uint64_t v = 0;
    for (int i = 7; i >= 0; i--) v = (v << 8) | r->data[r->pos + i];
    r->pos += 8;
    return (int64_t)v;
}

static int fail(char *err, size_t errlen, const char *msg) {
    snprintf(err, errlen, "%s", msg);
    return 0;
}

int load_program(VM *vm, const char *path, char *err, size_t errlen) {
    FILE *f = fopen(path, "rb");
    if (!f) return fail(err, errlen, "cannot open file");
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return fail(err, errlen, "cannot read file"); }
    long size = ftell(f);
    if (size < 0) { fclose(f); return fail(err, errlen, "cannot read file"); }
    rewind(f);
    uint8_t *data = malloc((size_t)size + 1);
    if (!data) { fclose(f); return fail(err, errlen, "out of memory"); }
    if (fread(data, 1, (size_t)size, f) != (size_t)size) { fclose(f); free(data); return fail(err, errlen, "cannot read file"); }
    fclose(f);

    Reader r = { data, (size_t)size, 0, 0 };
    Program *p = &vm->prog;
    memset(p, 0, sizeof *p);

    if (!need(&r, 8) || memcmp(data, "RUNE", 4) != 0) { free(data); return fail(err, errlen, "not a Rune bytecode file"); }
    r.pos = 4;
    uint32_t version = rd_u32(&r);
    if (version != 1) { free(data); return fail(err, errlen, "unsupported bytecode version"); }

    /* constants */
    p->nconsts = rd_u32(&r);
    if (r.error || p->nconsts > 10000000) { free(data); return fail(err, errlen, "bad constant table"); }
    p->consts = calloc(p->nconsts ? p->nconsts : 1, sizeof(Value));
    for (uint32_t i = 0; i < p->nconsts; i++) {
        uint8_t kind = rd_u8(&r);
        switch (kind) {
        case 0: p->consts[i] = mk_int(rd_i64(&r)); break;
        case 1: p->consts[i] = mk_word((uint64_t)rd_i64(&r)); break;
        case 2: {
            uint32_t n = rd_u32(&r);
            if (!need(&r, n) || n > 64) { free(data); return fail(err, errlen, "bad real constant"); }
            char buf[65];
            memcpy(buf, data + r.pos, n); buf[n] = 0; r.pos += n;
            p->consts[i] = mk_real(strtod(buf, NULL));
            break;
        }
        case 3: {
            uint32_t n = rd_u32(&r);
            if (!need(&r, n)) { free(data); return fail(err, errlen, "bad string constant"); }
            p->consts[i] = mk_ptr(vm_string_from(vm, (const char *)data + r.pos, n));
            r.pos += n;
            break;
        }
        case 4: p->consts[i] = mk_char(rd_u8(&r)); break;
        default: free(data); return fail(err, errlen, "bad constant kind");
        }
        if (r.error) { free(data); return fail(err, errlen, "truncated constant table"); }
    }

    /* globals */
    p->nglobals = rd_u32(&r);
    if (r.error || p->nglobals > 10000000) { free(data); return fail(err, errlen, "bad global count"); }
    vm->globals = calloc(p->nglobals ? p->nglobals : 1, sizeof(Value));
    vm->global_set = calloc(p->nglobals ? p->nglobals : 1, 1);
    for (uint32_t i = 0; i < p->nglobals; i++) vm->globals[i] = mk_unit();

    /* functions */
    p->nfuncs = rd_u32(&r);
    if (r.error || p->nfuncs == 0 || p->nfuncs > 10000000) { free(data); return fail(err, errlen, "bad function table"); }
    p->funcs = calloc(p->nfuncs, sizeof(Function));
    for (uint32_t i = 0; i < p->nfuncs; i++) {
        p->funcs[i].code_offset = rd_u32(&r);
        p->funcs[i].nlocals = rd_u32(&r);
        uint32_t n = rd_u32(&r);
        if (!need(&r, n)) { free(data); return fail(err, errlen, "bad function name"); }
        p->funcs[i].name = malloc(n + 1);
        memcpy(p->funcs[i].name, data + r.pos, n); p->funcs[i].name[n] = 0; r.pos += n;
        if (p->funcs[i].nlocals < 1 || p->funcs[i].nlocals > 1000000) { free(data); return fail(err, errlen, "bad frame size"); }
        if (i > 0 && p->funcs[i].code_offset < p->funcs[i - 1].code_offset) { free(data); return fail(err, errlen, "functions out of order"); }
    }

    /* code */
    p->code_len = rd_u32(&r);
    if (r.error || !need(&r, p->code_len)) { free(data); return fail(err, errlen, "truncated code"); }
    p->code = malloc(p->code_len ? p->code_len : 1);
    memcpy(p->code, data + r.pos, p->code_len);
    r.pos += p->code_len;
    free(data);

    for (uint32_t i = 0; i < p->nfuncs; i++) {
        p->funcs[i].code_end = (i + 1 < p->nfuncs) ? p->funcs[i + 1].code_offset : p->code_len;
        if (p->funcs[i].code_offset >= p->code_len) return fail(err, errlen, "function offset out of range");
    }

    /* validate instructions: boundaries and operand ranges */
    uint8_t *starts = calloc(p->code_len + 1, 1);
    uint32_t fi = 0;
    uint32_t pc = 0;
    while (pc < p->code_len) {
        while (fi + 1 < p->nfuncs && pc >= p->funcs[fi + 1].code_offset) fi++;
        uint8_t op = p->code[pc];
        int len = instr_length(op);
        if (len == 0) { free(starts); snprintf(err, errlen, "invalid opcode %u at %u", op, pc); return 0; }
        if (pc + len > p->code_len) { free(starts); return fail(err, errlen, "truncated instruction"); }
        starts[pc] = 1;
        int32_t a = len > 1 ? read_i32(p->code + pc + 1) : 0;
        int32_t b = len > 5 ? read_i32(p->code + pc + 5) : 0;
        int bad = 0;
        switch (op) {
        case OP_CONST: bad = a < 0 || (uint32_t)a >= p->nconsts; break;
        case OP_CON0: case OP_CON: bad = a < 0 || a > 65535; break;
        case OP_LOCAL: case OP_SETLOCAL: bad = a < 0 || (uint32_t)a >= p->funcs[fi].nlocals; break;
        case OP_ENV: case OP_SETENV: bad = a < 0; break;
        case OP_GLOBAL: case OP_SETGLOBAL: bad = a < 0 || (uint32_t)a >= p->nglobals; break;
        case OP_TUPLE: bad = a < 0 || a > 1000000; break;
        case OP_SELECT: bad = a < 0; break;
        case OP_CLOSURE: bad = a < 0 || (uint32_t)a >= p->nfuncs || b < 0 || b > 1000000; break;
        case OP_NEWEXN: bad = a < 0 || (uint32_t)a >= p->nconsts || p->consts[a].tag != T_PTR; break;
        case OP_BUILTINEXN: bad = a < 0 || a >= NUM_BUILTIN_EXNS; break;
        case OP_PRIM: bad = a < 0 || a >= PRIM__COUNT; break;
        default: break;
        }
        if (bad) { free(starts); snprintf(err, errlen, "bad operand for %s at %u", op_names[op], pc); return 0; }
        pc += len;
    }
    /* jump targets and function entries must be instruction boundaries */
    pc = 0;
    while (pc < p->code_len) {
        uint8_t op = p->code[pc];
        int len = instr_length(op);
        if (op == OP_JUMP || op == OP_JUMPIF || op == OP_JUMPIFNOT || op == OP_PUSHHANDLER) {
            int32_t t = read_i32(p->code + pc + 1);
            if (t < 0 || (uint32_t)t >= p->code_len || !starts[t]) {
                free(starts); snprintf(err, errlen, "bad jump target at %u", pc); return 0;
            }
        }
        pc += len;
    }
    for (uint32_t i = 0; i < p->nfuncs; i++)
        if (!starts[p->funcs[i].code_offset]) { free(starts); return fail(err, errlen, "function entry is not an instruction"); }
    free(starts);
    return 1;
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
        fprintf(out, "\n");
        pc += len;
    }
}
