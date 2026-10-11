/* Bytecode loader with validation: the .rbc file is untrusted input. */
#include "vm.h"
#include "sys/sys.h"

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

/* What follows the constants and the count of globals in a .rbc, and in a
   unit's file (load_unit_mem): the functions, the code, the files, the line
   table, the inlined frames and the representations, into p. None of it is
   in the heap, so the collector need not know of p while it is read. */
static int read_code_and_tables(Reader *r, Program *p, const uint8_t *data, char *err, size_t errlen) {
    /* functions */
    p->nfuncs = rd_u32(r);
    if (r->error || p->nfuncs == 0 || p->nfuncs > 10000000) return fail(err, errlen, "bad function table");
    p->funcs = calloc(p->nfuncs, sizeof(Function));
    for (uint32_t i = 0; i < p->nfuncs; i++) {
        p->funcs[i].code_offset = rd_u32(r);
        p->funcs[i].nlocals = rd_u32(r);
        uint32_t n = rd_u32(r);
        if (!need(r, n)) return fail(err, errlen, "bad function name");
        p->funcs[i].name = malloc(n + 1);
        memcpy(p->funcs[i].name, data + r->pos, n); p->funcs[i].name[n] = 0; r->pos += n;
        if (p->funcs[i].nlocals < 1 || p->funcs[i].nlocals > 1000000) return fail(err, errlen, "bad frame size");
        if (i > 0 && p->funcs[i].code_offset < p->funcs[i - 1].code_offset) return fail(err, errlen, "functions out of order");
    }

    /* code */
    p->code_len = rd_u32(r);
    if (r->error || !need(r, p->code_len)) return fail(err, errlen, "truncated code");
    p->code = malloc(p->code_len ? p->code_len : 1);
    memcpy(p->code, data + r->pos, p->code_len);
    r->pos += p->code_len;

    /* debug information: the files, then the position of every instruction */
    p->nfiles = rd_u32(r);
    if (r->error || p->nfiles > 1000000) return fail(err, errlen, "bad file table");
    p->files = calloc(p->nfiles ? p->nfiles : 1, sizeof(char *));
    if (!p->files) return fail(err, errlen, "out of memory");
    for (uint32_t i = 0; i < p->nfiles; i++) {
        uint32_t n = rd_u32(r);
        if (!need(r, n)) return fail(err, errlen, "bad file name");
        p->files[i] = malloc(n + 1);
        if (!p->files[i]) return fail(err, errlen, "out of memory");
        memcpy(p->files[i], data + r->pos, n); p->files[i][n] = 0; r->pos += n;
    }
    p->nlines = rd_u32(r);
    uint32_t table_len = rd_u32(r);
    if (r->error || p->nlines > 100000000 || !need(r, table_len))
        return fail(err, errlen, "bad line table");
    p->lines = calloc(p->nlines ? p->nlines : 1, sizeof(LineEntry));
    if (!p->lines) return fail(err, errlen, "out of memory");
    {
        const uint8_t *q = data + r->pos, *end = q + table_len;
        int64_t pc = 0, file = 0, line = 0, col = 0, inl = 0;
        for (uint32_t i = 0; i < p->nlines; i++) {
            uint64_t dpc;
            int64_t dfile, dline, dcol, dinl;
            if (!rd_uvar(&q, end, &dpc) || !rd_svar(&q, end, &dfile) ||
                !rd_svar(&q, end, &dline) || !rd_svar(&q, end, &dcol) || !rd_svar(&q, end, &dinl))
                return fail(err, errlen, "bad line table");
            if (dpc > (uint64_t)p->code_len) return fail(err, errlen, "line table out of range");
            pc += (int64_t)dpc; file += dfile; line += dline; col += dcol; inl += dinl;
            if (pc >= (int64_t)p->code_len || file < 0 || (uint32_t)file >= p->nfiles ||
                line < 1 || col < 1 || line > INT32_MAX || col > INT32_MAX || inl < 0 || inl > INT32_MAX)
                return fail(err, errlen, "line table out of range");
            p->lines[i].pc = (uint32_t)pc;
            p->lines[i].file = (uint32_t)file;
            p->lines[i].line = (uint32_t)line;
            p->lines[i].col = (uint32_t)col;
            p->lines[i].inl = (uint32_t)inl;
        }
        if (q != end) return fail(err, errlen, "bad line table");
    }
    r->pos += table_len;

    /* the functions inlined on the way to the positions: their names, each
       once, then each frame's name, the place it was called from, and the
       frame that call is in, five natural numbers */
    uint32_t nnames = rd_u32(r);
    if (r->error || nnames > 100000000) return fail(err, errlen, "bad table of inlined functions");
    size_t *name_at = calloc(nnames ? nnames : 1, sizeof(size_t));
    uint32_t *name_len = calloc(nnames ? nnames : 1, sizeof(uint32_t));
    if (!name_at || !name_len) { free(name_at); free(name_len); return fail(err, errlen, "out of memory"); }
    for (uint32_t i = 0; i < nnames; i++) {
        uint32_t n = rd_u32(r);
        if (!need(r, n)) { free(name_at); free(name_len); return fail(err, errlen, "bad table of inlined functions"); }
        name_at[i] = r->pos; name_len[i] = n; r->pos += n;
    }
    p->ninlines = rd_u32(r);
    uint32_t frames_len = rd_u32(r);
    if (r->error || p->ninlines > 100000000 || !need(r, frames_len)) {
        free(name_at); free(name_len);
        return fail(err, errlen, "bad table of inlined functions");
    }
    p->inlines = calloc(p->ninlines ? p->ninlines : 1, sizeof(Inlined));
    if (!p->inlines) { free(name_at); free(name_len); return fail(err, errlen, "out of memory"); }
    {
        const uint8_t *q = data + r->pos, *end = q + frames_len;
        const char *bad = NULL;
        for (uint32_t i = 0; i < p->ninlines && !bad; i++) {
            uint64_t name, file, line, col, parent;
            if (!rd_uvar(&q, end, &name) || !rd_uvar(&q, end, &file) || !rd_uvar(&q, end, &line) ||
                !rd_uvar(&q, end, &col) || !rd_uvar(&q, end, &parent) || name >= nnames ||
                /* a frame called in tail position has no place (0, 0, 0) */
                (line == 0 && (file != 0 || col != 0)) || (line != 0 && (file >= p->nfiles || col < 1)) ||
                line > INT32_MAX || col > INT32_MAX || parent > i) {
                bad = "bad table of inlined functions";
                break;
            }
            p->inlines[i].name = malloc(name_len[name] + 1);
            if (!p->inlines[i].name) { bad = "out of memory"; break; }
            memcpy(p->inlines[i].name, data + name_at[name], name_len[name]);
            p->inlines[i].name[name_len[name]] = 0;
            p->inlines[i].file = (uint32_t)file;
            p->inlines[i].line = (uint32_t)line;
            p->inlines[i].col = (uint32_t)col;
            p->inlines[i].parent = (uint32_t)parent;
        }
        if (!bad && q != end) bad = "bad table of inlined functions";
        free(name_at); free(name_len);
        if (bad) return fail(err, errlen, bad);
    }
    r->pos += frames_len;
    for (uint32_t i = 0; i < p->nlines; i++)
        if (p->lines[i].inl > p->ninlines) return fail(err, errlen, "line table out of range");

    /* the representations section: what the compiler says of each function
       beside its code, or nothing (docs/bytecode.md) */
    {
        uint32_t nmeta = rd_u32(r);
        if (r->error || (nmeta != 0 && nmeta != p->nfuncs)) return fail(err, errlen, "bad representations section");
        for (uint32_t i = 0; i < nmeta; i++) {
            Function *fn = &p->funcs[i];
            fn->has_meta = 1;
            fn->arity = rd_u32(r);
            uint32_t nregs = rd_u32(r);
            if (r->error || nregs != fn->nlocals || !need(r, nregs)) return fail(err, errlen, "bad representations section");
            fn->reps = malloc(nregs ? nregs : 1);
            if (!fn->reps) return fail(err, errlen, "out of memory");
            memcpy(fn->reps, data + r->pos, nregs);
            r->pos += nregs;
            for (uint32_t k = 0; k < nregs; k++) if (fn->reps[k] >= REP__COUNT) return fail(err, errlen, "bad representations section");
            fn->nblocks = rd_u32(r);
            if (r->error || fn->nblocks > 10000000) return fail(err, errlen, "bad representations section");
            fn->blocks = calloc(fn->nblocks ? fn->nblocks : 1, sizeof(MetaBlock));
            if (!fn->blocks) return fail(err, errlen, "out of memory");
            for (uint32_t b = 0; b < fn->nblocks; b++) {
                fn->blocks[b].pc = rd_u32(r);
                fn->blocks[b].nparams = rd_u32(r);
                if (r->error || fn->blocks[b].nparams > nregs) return fail(err, errlen, "bad representations section");
                fn->blocks[b].params = calloc(fn->blocks[b].nparams ? fn->blocks[b].nparams : 1, sizeof(uint32_t));
                if (!fn->blocks[b].params) return fail(err, errlen, "out of memory");
                for (uint32_t k = 0; k < fn->blocks[b].nparams; k++) {
                    fn->blocks[b].params[k] = rd_u32(r);
                    if (fn->blocks[b].params[k] >= nregs) return fail(err, errlen, "bad representations section");
                }
            }
            fn->nloops = rd_u32(r);
            if (r->error || fn->nloops > 10000000) return fail(err, errlen, "bad representations section");
            fn->loops = calloc(fn->nloops ? fn->nloops : 1, sizeof(uint32_t));
            if (!fn->loops) return fail(err, errlen, "out of memory");
            for (uint32_t k = 0; k < fn->nloops; k++) fn->loops[k] = rd_u32(r);
            if (r->error) return fail(err, errlen, "bad representations section");
        }
    }

    for (uint32_t i = 0; i < p->nfuncs; i++)
        p->funcs[i].code_end = (i + 1 < p->nfuncs) ? p->funcs[i + 1].code_offset : p->code_len;

    return 1;
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
static int unit_export(VM *vm, uint32_t session, int32_t stamp, uint32_t kind, uint32_t index);
static int unit_session(VM *vm, const uint8_t *s, uint32_t n, uint32_t *out);

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
    if (rd_u32(&r) != isa_fingerprint) return fail(err, errlen, "bytecode of another instruction set");

    /* constants, counted in as each is made: a minor collection takes those
       above what it took before, so none is counted before it is there
       (runtime/gc/gc.h, MINOR_ROOTS) */
    uint32_t nconsts = rd_u32(&r);
    if (r.error || nconsts > 10000000) return fail(err, errlen, "bad constant table");
    p->consts = calloc(nconsts ? nconsts : 1, sizeof(Value));
    p->const_kinds = calloc(nconsts ? nconsts : 1, 1);
    p->nconsts = 0;
    vm->consts_minor = 0;
    for (uint32_t i = 0; i < nconsts; i++, p->nconsts = i) {
        uint8_t kind = rd_u8(&r);
        p->const_kinds[i] = kind;
        switch (kind) {
        case CONST_INT: {
            int64_t n = rd_i64(&r);
#ifndef RUNE_INT64
            if (!int_fits(n)) return fail(err, errlen, "an int constant beyond 63 bits (bytecode compiled with --int-bits=64)");
#endif
            p->consts[i] = mk_int_vm(vm, n);
            break;
        }
        case CONST_WORD: {
            uint64_t w = (uint64_t)rd_i64(&r);
#ifndef RUNE_INT64
            if (!word_fits(w)) return fail(err, errlen, "a word constant beyond 63 bits (bytecode compiled with --int-bits=64)");
#endif
            p->consts[i] = mk_word_vm(vm, w);
            break;
        }
        case CONST_INT64: p->consts[i] = mk_int64_vm(vm, rd_i64(&r)); break;
        case CONST_WORD64: p->consts[i] = mk_word64_vm(vm, (uint64_t)rd_i64(&r)); break;
        case CONST_REAL: {
            uint32_t n = rd_u32(&r);
            if (!need(&r, n) || n > 64) return fail(err, errlen, "bad real constant");
            char buf[65];
            memcpy(buf, data + r.pos, n); buf[n] = 0; r.pos += n;
            p->consts[i] = mk_real(vm, strtod(buf, NULL));
            break;
        }
        case CONST_STRING: {
            uint32_t n = rd_u32(&r);
            if (!need(&r, n)) return fail(err, errlen, "bad string constant");
            p->consts[i] = mk_ptr(vm_string_from(vm, (const char *)data + r.pos, n));
            r.pos += n;
            break;
        }
        case CONST_CHAR: p->consts[i] = mk_char(rd_u8(&r)); break;
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

    if (!read_code_and_tables(&r, p, data, err, errlen)) return 0;

    /* the units it was linked from, where it was (rune --units): each one's
       identity and what it exports, by its number there -- a function or a
       global -- which a unit loaded into it later names (Runtime.load; a
       dynamic module, docs/units.md) */
    if (r.pos < size) {
        uint32_t nunits = rd_u32(&r);
        if (r.error || nunits > 100000) return fail(err, errlen, "bad table of units");
        for (uint32_t i = 0; i < nunits; i++) {
            uint32_t n = rd_u32(&r);
            if (r.error || n > 4096 || !need(&r, n)) return fail(err, errlen, "bad table of units");
            uint32_t session;
            if (!unit_session(vm, data + r.pos, n, &session)) return fail(err, errlen, "out of memory");
            r.pos += n;
            uint32_t nexports = rd_u32(&r);
            if (r.error || nexports > 10000000) return fail(err, errlen, "bad table of units");
            for (uint32_t j = 0; j < nexports; j++) {
                uint32_t kind = rd_u32(&r), number = rd_u32(&r), index = rd_u32(&r);
                if (r.error || kind > 1 || index >= (kind == 0 ? p->nfuncs : p->nglobals))
                    return fail(err, errlen, "bad table of units");
                if (!unit_export(vm, session, (int32_t)number, kind, index)) return fail(err, errlen, "out of memory");
            }
        }
        if (r.pos != size) return fail(err, errlen, "bad table of units");
    }
    program_epoch(vm);

    uint8_t *starts = validate_program(p, err, errlen);
    if (!starts) return 0;
    free(starts);
    return 1;
}

/* The entry covering pc: the last one that begins at or before it, found by
   halving the table, which is in order of pc. */
uint32_t trace_frames(const Program *p, const LineEntry *e, const char *name, TraceFrame *out, uint32_t max) {
    uint32_t k = 0;
    const char *cur = name;
    uint32_t file = e->file, line = e->line, col = e->col, n = e->inl;
    if (n != 0 && n <= p->ninlines) cur = p->inlines[n - 1].name;
    while (n != 0 && n <= p->ninlines) {
        const Inlined *in = &p->inlines[n - 1];
        const char *next = in->parent != 0 ? p->inlines[in->parent - 1].name : name;
        /* one inlined in tail position took the place of the next: cur
           stays, at the place it is at */
        if (in->line != 0) {
            if (k < max) { out[k].name = cur; out[k].file = file; out[k].line = line; out[k].col = col; }
            k++;
            cur = next; file = in->file; line = in->line; col = in->col;
        }
        n = in->parent;
    }
    if (k < max) { out[k].name = cur; out[k].file = file; out[k].line = line; out[k].col = col; }
    k++;
    return k < max ? k : max;
}

const LineEntry *line_at(const Program *p, uint32_t pc) {
    uint32_t lo = 0, hi = p->nlines;
    if (hi == 0 || p->lines[0].pc > pc) return NULL;
    while (hi - lo > 1) {
        uint32_t mid = lo + (hi - lo) / 2;
        if (p->lines[mid].pc <= pc) lo = mid; else hi = mid;
    }
    return &p->lines[lo];
}

void program_free_meta(Program *p) {
    for (uint32_t i = 0; p->funcs && i < p->nfuncs; i++) {
        Function *fn = &p->funcs[i];
        free(fn->reps);
        for (uint32_t b = 0; fn->blocks && b < fn->nblocks; b++) free(fn->blocks[b].params);
        free(fn->blocks);
        free(fn->loops);
        free(fn->live_pc);
        free(fn->live_at);
        fn->reps = NULL; fn->blocks = NULL; fn->loops = NULL;
        fn->live_pc = NULL; fn->live_at = NULL;
        fn->nblocks = fn->nloops = fn->nlive = 0;
        fn->has_meta = fn->live_made = 0;
    }
}

/* ---------------------------------------------------------------- units */

/* The exports of the units loaded, found by the compile they came from,
   their stamp and their kind: a table of their indexes plus one, by hash,
   with the next slot taken where one is (VM.unit_table). */
static uint32_t unit_hash(uint32_t session, int32_t stamp, uint32_t kind) {
    uint32_t h = session * 2654435761u ^ (uint32_t)stamp * 2246822519u ^ kind * 3266489917u;
    h ^= h >> 15; h *= 2246822519u; h ^= h >> 13;
    return h;
}

static UnitExport *unit_find(VM *vm, uint32_t session, int32_t stamp, uint32_t kind) {
    if (!vm->unit_slots) return NULL;
    uint32_t mask = vm->unit_slots - 1;
    for (uint32_t i = unit_hash(session, stamp, kind) & mask;; i = (i + 1) & mask) {
        uint32_t e = vm->unit_table[i];
        if (e == 0) return NULL;
        UnitExport *x = &vm->unit_exports[e - 1];
        if (x->session == session && x->stamp == stamp && x->kind == kind) return x;
    }
}

static void unit_put(VM *vm, uint32_t e) {
    const UnitExport *x = &vm->unit_exports[e];
    uint32_t mask = vm->unit_slots - 1;
    uint32_t i = unit_hash(x->session, x->stamp, x->kind) & mask;
    while (vm->unit_table[i] != 0) i = (i + 1) & mask;
    vm->unit_table[i] = e + 1;
}

void program_epoch(VM *vm) {
    static uint64_t epochs;
    vm->prog_epoch = ++epochs;
}

int unit_exports_rehash(VM *vm) {
    uint32_t slots = 64;
    while (slots < 2 * (uint64_t)vm->nunit_exports + 2) slots *= 2;
    uint32_t *table = calloc(slots, sizeof *table);
    if (!table) return 0;
    free(vm->unit_table);
    vm->unit_table = table;
    vm->unit_slots = slots;
    for (uint32_t e = 0; e < vm->nunit_exports; e++) unit_put(vm, e);
    return 1;
}

/* A function or global another unit may name: the latest unit to export
   one by that name is the one found, as a later declaration shadows an
   earlier one (a unit loaded twice is two units, the second found) */
static int unit_export(VM *vm, uint32_t session, int32_t stamp, uint32_t kind, uint32_t index) {
    UnitExport *x = unit_find(vm, session, stamp, kind);
    if (x) { x->index = index; return 1; }
    if (vm->nunit_exports == vm->unit_exports_cap) {
        uint32_t cap = vm->unit_exports_cap ? 2 * vm->unit_exports_cap : 256;
        UnitExport *grown = realloc(vm->unit_exports, cap * sizeof *grown);
        if (!grown) return 0;
        vm->unit_exports = grown;
        vm->unit_exports_cap = cap;
    }
    vm->unit_exports[vm->nunit_exports++] = (UnitExport){session, stamp, kind, index};
    if (2 * (uint64_t)vm->nunit_exports + 2 > vm->unit_slots) return unit_exports_rehash(vm);
    unit_put(vm, vm->nunit_exports - 1);
    return 1;
}

static int unit_session(VM *vm, const uint8_t *s, uint32_t n, uint32_t *out) {
    for (uint32_t i = 0; i < vm->nunit_sessions; i++)
        if (strlen(vm->unit_sessions[i]) == n && memcmp(vm->unit_sessions[i], s, n) == 0) { *out = i; return 1; }
    char **grown = realloc(vm->unit_sessions, (vm->nunit_sessions + 1) * sizeof *grown);
    if (!grown) return 0;
    vm->unit_sessions = grown;
    char *copy = malloc(n + 1);
    if (!copy) return 0;
    memcpy(copy, s, n); copy[n] = 0;
    vm->unit_sessions[vm->nunit_sessions] = copy;
    *out = vm->nunit_sessions++;
    return 1;
}

/* The program's arrays grown to hold n more of their elements, or 0 */
static int grow(void **a, size_t elem, size_t have, size_t more) {
    void *g = realloc(*a, (have + more ? have + more : 1) * elem);
    if (!g) return 0;
    *a = g;
    return 1;
}

/* What a unit brought that the program keeps, put back as it was when the
   unit's code fails its check: the program as before, its tables no
   longer counting what came after (the constants made are garbage). */
typedef struct Mark { uint32_t nfuncs, code_len, nconsts, nglobals, nfiles, nlines, ninlines; } Mark;

static Mark mark_of(const VM *vm) {
    const Program *p = &vm->prog;
    return (Mark){p->nfuncs, p->code_len, p->nconsts, p->nglobals, p->nfiles, p->nlines, p->ninlines};
}

static void undo(VM *vm, Mark m) {
    Program *p = &vm->prog;
    for (uint32_t i = m.nfuncs; i < p->nfuncs; i++) {
        Function *fn = &p->funcs[i];
        free(fn->name); free(fn->reps); free(fn->loops); free(fn->live_pc); free(fn->live_at);
        for (uint32_t b = 0; fn->blocks && b < fn->nblocks; b++) free(fn->blocks[b].params);
        free(fn->blocks);
    }
    for (uint32_t i = m.nfiles; i < p->nfiles; i++) free(p->files[i]);
    for (uint32_t i = m.ninlines; i < p->ninlines; i++) free(p->inlines[i].name);
    p->nfuncs = m.nfuncs; p->code_len = m.code_len; p->nconsts = m.nconsts; p->nglobals = m.nglobals;
    /* constants a minor collection took while the unit's were made go too:
       the next unit's, in their places, are new (runtime/gc/gc.h, MINOR_ROOTS) */
    if (vm->consts_minor > p->nconsts) vm->consts_minor = p->nconsts;
    p->nfiles = m.nfiles; p->nlines = m.nlines; p->ninlines = m.ninlines;
    if (p->nfuncs) p->funcs[p->nfuncs - 1].code_end = p->code_len;
}

/* A function added to the program by the VM itself: its code, its
   registers, and the representations every function of the program has,
   if they have them (every register `anything`, and one block),
   checked as a unit's code is. Its number, or UINT32_MAX and why. */
uint32_t program_add_function(VM *vm, const char *name, const uint8_t *code, uint32_t len, uint32_t nlocals,
                              uint32_t arity, char *err, size_t errlen) {
    Program *p = &vm->prog;
    Mark m = mark_of(vm);
    if (!grow((void **)&p->funcs, sizeof(Function), p->nfuncs, 1) || !grow((void **)&p->code, 1, p->code_len, len)) {
        fail(err, errlen, "out of memory");
        return UINT32_MAX;
    }
    Function *fn = &p->funcs[p->nfuncs];
    memset(fn, 0, sizeof *fn);
    fn->code_offset = p->code_len;
    fn->code_end = p->code_len + len;
    fn->nlocals = nlocals;
    size_t nlen = strlen(name) + 1;
    fn->name = malloc(nlen);
    if (!fn->name) { fail(err, errlen, "out of memory"); return UINT32_MAX; }
    memcpy(fn->name, name, nlen);
    if (p->nfuncs && p->funcs[0].has_meta) {
        fn->has_meta = 1;
        fn->arity = arity;
        fn->reps = calloc(nlocals, 1);
        fn->nblocks = 1;
        fn->blocks = calloc(1, sizeof(MetaBlock));
        if (!fn->reps || !fn->blocks) { fail(err, errlen, "out of memory"); return UINT32_MAX; }
        fn->blocks[0].pc = p->code_len;
        fn->blocks[0].params = calloc(1, sizeof(uint32_t));
        if (!fn->blocks[0].params) { fail(err, errlen, "out of memory"); return UINT32_MAX; }
    }
    memcpy(p->code + p->code_len, code, len);
    p->code_len += len;
    p->nfuncs++;
    uint8_t *starts = validate_program_from(p, m.nfuncs, err, errlen);
    if (!starts) { undo(vm, m); return UINT32_MAX; }
    free(starts);
    return m.nfuncs;
}

/* The function a unit's top level goes to last, when no unit follows it:
   it returns its argument. Made the first time a unit names it. */
static int unit_return_function(VM *vm, char *err, size_t errlen) {
    if (vm->unit_return != UINT32_MAX) return 1;
    uint8_t code[16];
    uint32_t nlocals;
    uint32_t len = return_function_code(code, &nlocals);
    uint32_t f = program_add_function(vm, "<return>", code, len, nlocals, 1, err, errlen);
    if (f == UINT32_MAX) return 0;
    vm->unit_return = f;
    return 1;
}

int64_t load_unit_mem(VM *vm, const uint8_t *data, size_t size, char *err, size_t errlen) {
    if (vm->native) { fail(err, errlen, "a program of native code loads no units"); return -1; }
    Reader r = { data, size, 0, 0 };
    Program *p = &vm->prog;
    if (!need(&r, 8) || memcmp(data, "RUNU", 4) != 0) { fail(err, errlen, "not a unit of Rune bytecode"); return -1; }
    r.pos = 4;
    if (rd_u32(&r) != 2) { fail(err, errlen, "unsupported unit version"); return -1; }
    if (rd_u32(&r) != isa_fingerprint) { fail(err, errlen, "a unit of another instruction set"); return -1; }
    if (rd_u32(&r) != 0) { fail(err, errlen, "a unit of another kind of code"); return -1; }
    /* its identity, then those of the units it names, each key's unit being
       its place among them, 0 the unit's own (docs/bytecode.md, Units) */
    uint32_t slen = rd_u32(&r);
    if (r.error || slen > 4096 || !need(&r, slen)) { fail(err, errlen, "bad identity"); return -1; }
    const uint8_t *identity_bytes = data + r.pos;
    r.pos += slen;
    uint32_t nnamed = rd_u32(&r);
    if (r.error || nnamed > 100000) { fail(err, errlen, "bad table of units"); return -1; }
    size_t named_at = r.pos;
    for (uint32_t i = 0; i < nnamed; i++) {
        uint32_t n = rd_u32(&r);
        if (r.error || n > 4096 || !need(&r, n)) { fail(err, errlen, "bad table of units"); return -1; }
        r.pos += n;
    }

    /* its constants, found and checked now and made once the program has
       room for them, where the collector sees them */
    uint32_t nconsts = rd_u32(&r);
    if (r.error || nconsts > 10000000) { fail(err, errlen, "bad constant table"); return -1; }
    size_t *const_at = malloc((nconsts ? nconsts : 1) * sizeof *const_at);
    if (!const_at) { fail(err, errlen, "out of memory"); return -1; }
    const char *bad = NULL;
    for (uint32_t i = 0; i < nconsts && !bad; i++) {
        const_at[i] = r.pos;
        uint8_t kind = rd_u8(&r);
        switch (kind) {
        case CONST_INT: {
            int64_t n = rd_i64(&r);
#ifndef RUNE_INT64
            if (!int_fits(n)) bad = "an int constant beyond 63 bits (bytecode compiled with --int-bits=64)";
#endif
            (void)n;
            break;
        }
        case CONST_WORD: {
            uint64_t w = (uint64_t)rd_i64(&r);
#ifndef RUNE_INT64
            if (!word_fits(w)) bad = "a word constant beyond 63 bits (bytecode compiled with --int-bits=64)";
#endif
            (void)w;
            break;
        }
        case CONST_INT64: case CONST_WORD64: (void)rd_i64(&r); break;
        case CONST_REAL: { uint32_t n = rd_u32(&r); if (!need(&r, n) || n > 64) bad = "bad real constant"; else r.pos += n; break; }
        case CONST_STRING: { uint32_t n = rd_u32(&r); if (!need(&r, n)) bad = "bad string constant"; else r.pos += n; break; }
        case CONST_CHAR: (void)rd_u8(&r); break;
        default: bad = "bad constant kind";
        }
        if (!bad && r.error) bad = "truncated constant table";
    }
    if (bad) { free(const_at); fail(err, errlen, bad); return -1; }
    uint32_t nglobals = rd_u32(&r);
    if (r.error || nglobals > 10000000) { free(const_at); fail(err, errlen, "bad global count"); return -1; }

    /* its functions, code and tables, as a program's file has them */
    Program u;
    memset(&u, 0, sizeof u);
    uint32_t *places = NULL, *stamps = NULL, *imports = NULL, *global_map = NULL, *import_ix = NULL,
             *import_place = NULL, *sessions = NULL;
    int32_t *import_stamp = NULL;
    uint32_t nimports = 0, nexports = 0;
    size_t exports_at = 0;
    int64_t result = -1;
    Mark m = mark_of(vm);
#define FAIL(msg) do { fail(err, errlen, (msg)); goto done; } while (0)
    if (!read_code_and_tables(&r, &u, data, err, errlen)) goto done;

    /* the linker's tables: each global's key (a unit's place, its number
       there), the functions it names past its own, what it exports */
    places = malloc((nglobals ? nglobals : 1) * sizeof *places);
    stamps = malloc((nglobals ? nglobals : 1) * sizeof *stamps);
    if (!places || !stamps) FAIL("out of memory");
    for (uint32_t i = 0; i < nglobals; i++) {
        places[i] = rd_u32(&r);
        stamps[i] = rd_u32(&r);
        if (places[i] > nnamed) FAIL("bad table of the unit's globals");
    }
    nimports = rd_u32(&r);
    if (r.error || nimports > 10000000) FAIL("bad table of imports");
    import_ix = malloc((nimports ? nimports : 1) * sizeof *import_ix);
    import_place = malloc((nimports ? nimports : 1) * sizeof *import_place);
    import_stamp = malloc((nimports ? nimports : 1) * sizeof *import_stamp);
    if (!import_ix || !import_place || !import_stamp) FAIL("out of memory");
    uint32_t nslots = 0;
    for (uint32_t i = 0; i < nimports; i++) {
        import_ix[i] = rd_u32(&r);
        import_place[i] = rd_u32(&r);
        import_stamp[i] = (int32_t)rd_u32(&r);
        if (import_ix[i] < u.nfuncs || import_ix[i] - u.nfuncs >= 10000000 || import_place[i] > nnamed
            || (import_place[i] == 0 && import_stamp[i] != -1))
            FAIL("bad table of imports");
        if (import_ix[i] - u.nfuncs + 1 > nslots) nslots = import_ix[i] - u.nfuncs + 1;
    }
    nexports = rd_u32(&r);
    if (r.error || nexports > u.nfuncs) FAIL("bad table of exports");
    exports_at = r.pos;
    for (uint32_t i = 0; i < nexports; i++) {
        (void)rd_u32(&r);
        if (rd_u32(&r) >= u.nfuncs) FAIL("bad table of exports");
    }
    if (r.error || r.pos != size) FAIL("bad tables of the unit");

    /* the units by their places: the unit's own first */
    sessions = malloc((nnamed + 1) * sizeof *sessions);
    if (!sessions) FAIL("out of memory");
    if (!unit_session(vm, identity_bytes, slen, &sessions[0])) FAIL("out of memory");
    {
        Reader n = { data, size, named_at, 0 };
        for (uint32_t i = 0; i < nnamed; i++) {
            uint32_t len = rd_u32(&n);
            if (!unit_session(vm, data + n.pos, len, &sessions[i + 1])) FAIL("out of memory");
            n.pos += len;
        }
    }
    uint32_t session = sessions[0];
    /* each function it names past its own: another unit's export, or the
       next unit's top level (its own place, number -1), which here is the
       function that returns */
    imports = malloc((nslots ? nslots : 1) * sizeof *imports);
    if (!imports) FAIL("out of memory");
    for (uint32_t i = 0; i < nslots; i++) imports[i] = UINT32_MAX;
    for (uint32_t i = 0; i < nimports; i++) {
        uint32_t to;
        if (import_stamp[i] == -1) {
            if (!unit_return_function(vm, err, errlen)) goto done;
            m = mark_of(vm);
            to = vm->unit_return;
        } else {
            UnitExport *x = unit_find(vm, sessions[import_place[i]], import_stamp[i], 0);
            if (!x) {
                snprintf(err, errlen, "the unit names function %d of unit %s, which no unit loaded has",
                         import_stamp[i], vm->unit_sessions[sessions[import_place[i]]]);
                goto done;
            }
            to = x->index;
        }
        imports[import_ix[i] - u.nfuncs] = to;
    }
    /* its globals: those it sets new ones, after the program's in the order
       of its own numbers; the rest another unit's */
    global_map = malloc((nglobals ? nglobals : 1) * sizeof *global_map);
    if (!global_map) FAIL("out of memory");
    uint32_t nown = 0;
    for (uint32_t i = 0; i < nglobals; i++) {
        if (places[i] == 0) global_map[i] = p->nglobals + nown++;
        else {
            UnitExport *x = unit_find(vm, sessions[places[i]], (int32_t)stamps[i], 1);
            if (!x) {
                snprintf(err, errlen, "the unit names global %d of unit %s, which no unit loaded has",
                         (int32_t)stamps[i], vm->unit_sessions[sessions[places[i]]]);
                goto done;
            }
            global_map[i] = x->index;
        }
    }

    /* its code renumbered for where it goes */
    Relocation rel = { u.nfuncs, p->nfuncs, nslots, imports, nglobals, global_map,
                       nconsts, p->nconsts, u.code_len, p->code_len };
    if (!relocate_code(u.code, &rel, err, errlen)) goto done;

    /* appended: the arrays grown first, so that what fails leaves the
       program as it was */
    if (!grow((void **)&p->funcs, sizeof(Function), p->nfuncs, u.nfuncs)
        || !grow((void **)&p->code, 1, p->code_len, u.code_len)
        || !grow((void **)&p->files, sizeof(char *), p->nfiles, u.nfiles)
        || !grow((void **)&p->lines, sizeof(LineEntry), p->nlines, u.nlines)
        || !grow((void **)&p->inlines, sizeof(Inlined), p->ninlines, u.ninlines)
        || !grow((void **)&p->consts, sizeof(Value), p->nconsts, nconsts)
        || !grow((void **)&p->const_kinds, 1, p->nconsts, nconsts)
        || !grow((void **)&vm->globals, sizeof(Value), p->nglobals, nown)
        || !grow((void **)&vm->global_set, 1, p->nglobals, nown))
        FAIL("out of memory");
    uint32_t func_base = p->nfuncs, code_base = p->code_len, file_base = p->nfiles, inline_base = p->ninlines;
    for (uint32_t i = 0; i < u.nfuncs; i++) {
        Function *fn = &p->funcs[func_base + i];
        *fn = u.funcs[i];
        fn->code_offset += code_base;
        fn->code_end += code_base;
        for (uint32_t b = 0; b < fn->nblocks; b++) fn->blocks[b].pc += code_base;
        for (uint32_t k = 0; k < fn->nloops; k++) fn->loops[k] += code_base;
    }
    p->nfuncs += u.nfuncs;
    u.nfuncs = 0;   /* the program's now */
    memcpy(p->code + code_base, u.code, u.code_len);
    p->code_len += u.code_len;
    for (uint32_t i = 0; i < u.nfiles; i++) p->files[file_base + i] = u.files[i];
    p->nfiles += u.nfiles;
    u.nfiles = 0;
    for (uint32_t i = 0; i < u.nlines; i++) {
        LineEntry e = u.lines[i];
        e.pc += code_base;
        e.file += file_base;
        if (e.inl != 0) e.inl += inline_base;
        p->lines[p->nlines + i] = e;
    }
    p->nlines += u.nlines;
    for (uint32_t i = 0; i < u.ninlines; i++) {
        Inlined in = u.inlines[i];
        if (in.line != 0) in.file += file_base;
        if (in.parent != 0) in.parent += inline_base;
        p->inlines[inline_base + i] = in;
    }
    p->ninlines += u.ninlines;
    u.ninlines = 0;
    for (uint32_t i = 0; i < nown; i++) { vm->globals[p->nglobals + i] = mk_unit(); vm->global_set[p->nglobals + i] = 0; }
    p->nglobals += nown;
    /* the constants, each counted in once it is made, where the collector
       finds it: a minor collection takes those above what it took before
       (runtime/gc/gc.h, MINOR_ROOTS), so none is counted before it is there */
    uint32_t const_base = p->nconsts;
    for (uint32_t i = 0; i < nconsts; i++) {
        Reader c = { data, size, const_at[i], 0 };
        uint8_t kind = rd_u8(&c);
        Value v;
        switch (kind) {
        case CONST_INT: v = mk_int_vm(vm, rd_i64(&c)); break;
        case CONST_WORD: v = mk_word_vm(vm, (uint64_t)rd_i64(&c)); break;
        case CONST_INT64: v = mk_int64_vm(vm, rd_i64(&c)); break;
        case CONST_WORD64: v = mk_word64_vm(vm, (uint64_t)rd_i64(&c)); break;
        case CONST_REAL: {
            uint32_t n = rd_u32(&c);
            char buf[65];
            memcpy(buf, data + c.pos, n); buf[n] = 0;
            v = mk_real(vm, strtod(buf, NULL));
            break;
        }
        case CONST_STRING: { uint32_t n = rd_u32(&c); v = mk_ptr(vm_string_from(vm, (const char *)data + c.pos, n)); break; }
        default: v = mk_char(rd_u8(&c)); break;
        }
        p->consts[const_base + i] = v;
        p->const_kinds[const_base + i] = kind;
        p->nconsts = const_base + i + 1;
    }
    if (func_base > 0) p->funcs[func_base - 1].code_end = code_base;

    /* its code checked, as a file's is, with the rest of the program */
    {
        uint8_t *starts = validate_program_from(p, func_base, err, errlen);
        if (!starts) { undo(vm, m); goto done; }
        free(starts);
    }

    /* what it exports: the functions its file names, and every global it sets */
    {
        Reader e = { data, size, exports_at, 0 };
        for (uint32_t i = 0; i < nexports; i++) {
            int32_t stamp = (int32_t)rd_u32(&e);
            uint32_t ix = rd_u32(&e);
            if (!unit_export(vm, session, stamp, 0, func_base + ix)) { undo(vm, m); FAIL("out of memory"); }
        }
        for (uint32_t i = 0; i < nglobals; i++)
            if (places[i] == 0 && !unit_export(vm, session, (int32_t)stamps[i], 1, global_map[i])) {
                undo(vm, m); FAIL("out of memory");
            }
    }
    result = func_base;
done:
#undef FAIL
    for (uint32_t i = 0; i < u.nfuncs; i++) {
        Function *fn = &u.funcs[i];
        free(fn->name); free(fn->reps); free(fn->loops);
        for (uint32_t b = 0; fn->blocks && b < fn->nblocks; b++) free(fn->blocks[b].params);
        free(fn->blocks);
    }
    free(u.funcs);
    free(u.code);
    for (uint32_t i = 0; i < u.nfiles; i++) free(u.files[i]);
    free(u.files);
    free(u.lines);
    for (uint32_t i = 0; i < u.ninlines; i++) free(u.inlines[i].name);
    free(u.inlines);
    free(const_at); free(places); free(stamps); free(imports); free(import_ix); free(import_place); free(import_stamp);
    free(global_map); free(sessions);
    return result;
}
