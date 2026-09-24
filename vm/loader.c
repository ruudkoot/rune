/* Bytecode loader with validation: the .rbc file is untrusted input. */
#include "vm.h"
#include "sys.h"

typedef struct Reader {
    const uint8_t *data;
    size_t len, pos;
    int error;
} Reader;

/* pos never exceeds len, so this cannot wrap even where size_t is 32 bits
   and n is a length read from the file */
static int need(Reader *r, size_t n) {
    if (n > r->len - r->pos) { r->error = 1; return 0; }
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

/* The line table's numbers, seven bits at a time, least significant first,
   the top bit saying that another byte follows; a signed one is folded so
   that a small negative difference stays one byte. Both refuse a number that
   does not end before the table does, or that does not fit. */
static int rd_uvar(const uint8_t **q, const uint8_t *end, uint64_t *out) {
    uint64_t v = 0;
    int shift = 0;
    while (*q < end) {
        uint8_t b = *(*q)++;
        if (shift > 63 || (shift == 63 && (b & 0x7f) > 1)) return 0;
        v |= (uint64_t)(b & 0x7f) << shift;
        if (!(b & 0x80)) { *out = v; return 1; }
        shift += 7;
    }
    return 0;
}

static int rd_svar(const uint8_t **q, const uint8_t *end, int64_t *out) {
    uint64_t v;
    if (!rd_uvar(q, end, &v)) return 0;
    *out = (v & 1) ? -(int64_t)(v >> 1) - 1 : (int64_t)(v >> 1);
    return 1;
}

static int fail(char *err, size_t errlen, const char *msg) {
    snprintf(err, errlen, "%s", msg);
    return 0;
}

/* The whole file, read to its end: its size is never asked, since ftell
   gives a long, which is 32 bits on Windows. */
static uint8_t *read_file(FILE *f, size_t *size) {
    size_t cap = 1 << 16, n = 0;
    uint8_t *data = malloc(cap);
    while (data) {
        n += fread(data + n, 1, cap - n, f);
        if (n < cap) break;
        if (cap > SIZE_MAX / 2) { free(data); return NULL; }
        uint8_t *bigger = realloc(data, cap * 2);
        if (!bigger) { free(data); return NULL; }
        data = bigger;
        cap *= 2;
    }
    if (data && ferror(f)) { free(data); return NULL; }
    *size = n;
    return data;
}

int load_program(VM *vm, const char *path, char *err, size_t errlen) {
    FILE *f = sys_fopen(path, "rb");
    if (!f) return fail(err, errlen, "cannot open file");
    size_t size = 0;
    uint8_t *data = read_file(f, &size);
    fclose(f);
    if (!data) return fail(err, errlen, "cannot read file");
    int ok = load_program_mem(vm, data, size, err, errlen);
    free(data);
    return ok;
}

/* A program from the bytes of a .rbc, which stay the caller's: what
   load_program does with a file, and a program of runeopt's with the .rbc
   it carries (docs/native.md). */
int load_program_mem(VM *vm, const uint8_t *data, size_t size, char *err, size_t errlen) {
    Reader r = { data, size, 0, 0 };
    Program *p = &vm->prog;
    memset(p, 0, sizeof *p);

    if (!need(&r, 8) || memcmp(data, "RUNE", 4) != 0) return fail(err, errlen, "not a Rune bytecode file");
    r.pos = 4;
    uint32_t version = rd_u32(&r);
    if (version != RBC_VERSION) return fail(err, errlen, "unsupported bytecode version");
    /* the instruction set it was made for (src/isa): a file of another means
       something else by its opcodes and primitives */
    if (rd_u32(&r) != ISA_FINGERPRINT) return fail(err, errlen, "bytecode of another instruction set");

    /* constants */
    p->nconsts = rd_u32(&r);
    if (r.error || p->nconsts > 10000000) return fail(err, errlen, "bad constant table");
    p->consts = calloc(p->nconsts ? p->nconsts : 1, sizeof(Value));
    for (uint32_t i = 0; i < p->nconsts; i++) {
        uint8_t kind = rd_u8(&r);
        switch (kind) {
        case 0: p->consts[i] = mk_int(rd_i64(&r)); break;
        case 1: p->consts[i] = mk_word((uint64_t)rd_i64(&r)); break;
        case 2: {
            uint32_t n = rd_u32(&r);
            if (!need(&r, n) || n > 64) return fail(err, errlen, "bad real constant");
            char buf[65];
            memcpy(buf, data + r.pos, n); buf[n] = 0; r.pos += n;
            p->consts[i] = mk_real(strtod(buf, NULL));
            break;
        }
        case 3: {
            uint32_t n = rd_u32(&r);
            if (!need(&r, n)) return fail(err, errlen, "bad string constant");
            p->consts[i] = mk_ptr(vm_string_from(vm, (const char *)data + r.pos, n));
            r.pos += n;
            break;
        }
        case 4: p->consts[i] = mk_char(rd_u8(&r)); break;
        default: return fail(err, errlen, "bad constant kind");
        }
        if (r.error) return fail(err, errlen, "truncated constant table");
    }

    /* globals */
    p->nglobals = rd_u32(&r);
    if (r.error || p->nglobals > 10000000) return fail(err, errlen, "bad global count");
    vm->globals = calloc(p->nglobals ? p->nglobals : 1, sizeof(Value));
    vm->global_set = calloc(p->nglobals ? p->nglobals : 1, 1);
    for (uint32_t i = 0; i < p->nglobals; i++) vm->globals[i] = mk_unit();

    /* functions */
    p->nfuncs = rd_u32(&r);
    if (r.error || p->nfuncs == 0 || p->nfuncs > 10000000) return fail(err, errlen, "bad function table");
    p->funcs = calloc(p->nfuncs, sizeof(Function));
    for (uint32_t i = 0; i < p->nfuncs; i++) {
        p->funcs[i].code_offset = rd_u32(&r);
        p->funcs[i].nlocals = rd_u32(&r);
        uint32_t n = rd_u32(&r);
        if (!need(&r, n)) return fail(err, errlen, "bad function name");
        p->funcs[i].name = malloc(n + 1);
        memcpy(p->funcs[i].name, data + r.pos, n); p->funcs[i].name[n] = 0; r.pos += n;
        if (p->funcs[i].nlocals < 1 || p->funcs[i].nlocals > 1000000) return fail(err, errlen, "bad frame size");
        if (i > 0 && p->funcs[i].code_offset < p->funcs[i - 1].code_offset) return fail(err, errlen, "functions out of order");
    }

    /* code */
    p->code_len = rd_u32(&r);
    if (r.error || !need(&r, p->code_len)) return fail(err, errlen, "truncated code");
    p->code = malloc(p->code_len ? p->code_len : 1);
    memcpy(p->code, data + r.pos, p->code_len);
    r.pos += p->code_len;

    /* debug information: the files, then the position of every instruction */
    p->nfiles = rd_u32(&r);
    if (r.error || p->nfiles > 1000000) return fail(err, errlen, "bad file table");
    p->files = calloc(p->nfiles ? p->nfiles : 1, sizeof(char *));
    if (!p->files) return fail(err, errlen, "out of memory");
    for (uint32_t i = 0; i < p->nfiles; i++) {
        uint32_t n = rd_u32(&r);
        if (!need(&r, n)) return fail(err, errlen, "bad file name");
        p->files[i] = malloc(n + 1);
        if (!p->files[i]) return fail(err, errlen, "out of memory");
        memcpy(p->files[i], data + r.pos, n); p->files[i][n] = 0; r.pos += n;
    }
    p->nlines = rd_u32(&r);
    uint32_t table_len = rd_u32(&r);
    if (r.error || p->nlines > 100000000 || !need(&r, table_len))
        return fail(err, errlen, "bad line table");
    p->lines = calloc(p->nlines ? p->nlines : 1, sizeof(LineEntry));
    if (!p->lines) return fail(err, errlen, "out of memory");
    {
        const uint8_t *q = data + r.pos, *end = q + table_len;
        int64_t pc = 0, file = 0, line = 0, col = 0;
        for (uint32_t i = 0; i < p->nlines; i++) {
            uint64_t dpc;
            int64_t dfile, dline, dcol;
            if (!rd_uvar(&q, end, &dpc) || !rd_svar(&q, end, &dfile) ||
                !rd_svar(&q, end, &dline) || !rd_svar(&q, end, &dcol))
                return fail(err, errlen, "bad line table");
            if (dpc > (uint64_t)p->code_len) return fail(err, errlen, "line table out of range");
            pc += (int64_t)dpc; file += dfile; line += dline; col += dcol;
            if (pc >= (int64_t)p->code_len || file < 0 || (uint32_t)file >= p->nfiles ||
                line < 1 || col < 1 || line > INT32_MAX || col > INT32_MAX)
                return fail(err, errlen, "line table out of range");
            p->lines[i].pc = (uint32_t)pc;
            p->lines[i].file = (uint32_t)file;
            p->lines[i].line = (uint32_t)line;
            p->lines[i].col = (uint32_t)col;
        }
        if (q != end) return fail(err, errlen, "bad line table");
    }
    r.pos += table_len;

    for (uint32_t i = 0; i < p->nfuncs; i++)
        p->funcs[i].code_end = (i + 1 < p->nfuncs) ? p->funcs[i + 1].code_offset : p->code_len;

    uint8_t *starts = validate_program(p, err, errlen);
    if (!starts) return 0;
    free(starts);
    return 1;
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

/* The entry covering pc: the last one that begins at or before it, found by
   halving the table, which is in order of pc. */
const LineEntry *line_at(const Program *p, uint32_t pc) {
    uint32_t lo = 0, hi = p->nlines;
    if (hi == 0 || p->lines[0].pc > pc) return NULL;
    while (hi - lo > 1) {
        uint32_t mid = lo + (hi - lo) / 2;
        if (p->lines[mid].pc <= pc) lo = mid; else hi = mid;
    }
    return &p->lines[lo];
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
