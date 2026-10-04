/* runtime/census/census_static.c -- the static census of a register-bytecode program
   (docs/census.md), a mode of the census VM: `runevm-census --census-static
   FILE.rbc` prints what the loader's tables say of each function's registers
   and of every site that allocates, stores, calls or returns. TSV:
     F  func name nlocals arity has_meta  n_ANY n_INT n_WORD n_REAL n_CHAR n_CON0 n_PTR n_CON n_UNIT
     S  pc func opcode prim n srcreps dstrep file line
        opcode: TUPLE CONN CLOSURE CON SETENV PRIM PRIMPUSH CALL TAILCALL CALLK TAILCALLK RET NEWEXN MKEXN
        prim: the primitive's name under PRIM/PRIMPUSH, else -
        n: the number of source registers listed; srcreps: their reps, comma-separated
           (CALL/TAILCALL: the closure then the argument; SETENV: the closure then the value;
            CLOSURE: the captured registers; MKEXN: the constructor then the payload)
        dstrep: the destination register's rep, or - where the instruction has none
        (a rep is 0..8 as docs/bytecode.md numbers them, 15 where the function has no section) */
#include "vm.h"
#include "register/regvm.h"

static const char *rep_name(int r) {
    static const char *const n[] = { "ANY", "INT", "WORD", "REAL", "CHAR", "CON0", "PTR", "CON", "UNIT" };
    return r >= 0 && r < 9 ? n[r] : "?";
}

void census_static(const Program *p, const char *path, FILE *out) {
    fprintf(out, "# static census of %s: %u functions, %u code bytes, %u consts, %u globals\n", path, p->nfuncs, p->code_len, p->nconsts, p->nglobals);
    for (uint32_t i = 0; i < p->nfuncs; i++) {
        const Function *fn = &p->funcs[i];
        uint64_t by[9] = { 0 };
        if (fn->has_meta) for (uint32_t k = 0; k < fn->nlocals; k++) if (fn->reps[k] < 9) by[fn->reps[k]]++;
        fprintf(out, "F\t%u\t%s\t%u\t%u\t%d", i, fn->name, fn->nlocals, fn->has_meta ? fn->arity : 0, fn->has_meta);
        for (int r = 0; r < 9; r++) fprintf(out, "\t%llu", (unsigned long long)by[r]);
        fprintf(out, "\n");
    }
    uint32_t fi = 0, pc = 0;
    while (pc < p->code_len) {
        while (fi + 1 < p->nfuncs && pc >= p->funcs[fi + 1].code_offset) fi++;
        const Function *fn = &p->funcs[fi];
        const uint8_t *at = p->code + pc;
        uint8_t op = at[0];
        uint32_t len = rop_length(at);
        if (!len) { fprintf(stderr, "runevm-census: bad opcode at %u\n", pc); return; }
#define REPOF(r) ((fn->has_meta && (r) >= 0 && (uint32_t)(r) < fn->nlocals) ? fn->reps[(r)] : 15)
        int32_t srcs[64]; uint32_t n = 0; int dst = -1; const char *prim = "-"; int listed = 0;
        switch (op) {
        case ROP_TUPLE: case ROP_CONN: case ROP_CLOSURE: case ROP_PRIM: case ROP_PRIMPUSH: case ROP_CALLK: case ROP_TAILCALLK: listed = 1; break;
        case ROP_CON: srcs[n++] = read_i32(at + 9); break;
        case ROP_SETENV: srcs[n++] = read_i32(at + 1); srcs[n++] = read_i32(at + 9); break;
        case ROP_CALL: case ROP_TAILCALL: srcs[n++] = read_i32(at + 1); srcs[n++] = read_i32(at + 5); break;
        case ROP_RET: srcs[n++] = read_i32(at + 1); break;
        case ROP_NEWEXN: break;
        case ROP_MKEXN: srcs[n++] = read_i32(at + 5); srcs[n++] = read_i32(at + 9); break;
        default: pc += len; continue;
        }
        uint32_t nl = 0;
        if (listed) {
            nl = rop_list_length(at);
            if (op == ROP_PRIM || op == ROP_PRIMPUSH) { int32_t pr = read_i32(at + 1); prim = pr >= 0 && pr < PRIM__COUNT ? prim_names[pr] : "?"; }
        }
        if (rop_dest[op] >= 0) dst = read_i32(at + 1 + 4 * rop_dest[op]);
        const LineEntry *e = line_at(p, pc);
        fprintf(out, "S\t%u\t%u\t%s\t%s\t%u\t", pc, fi, rop_names[op], prim, listed ? nl : n);
        if (listed) {
            for (uint32_t k = 0; k < nl; k++) fprintf(out, "%s%s", k ? "," : "", rep_name(REPOF(read_i32(at + 1 + 4 * (rop_nfixed[op] + k)))));
        } else {
            for (uint32_t k = 0; k < n; k++) fprintf(out, "%s%s", k ? "," : "", rep_name(REPOF(srcs[k])));
        }
        if (n == 0 && nl == 0) fprintf(out, "-");
        fprintf(out, "\t%s", dst >= 0 ? rep_name(REPOF(dst)) : "-");
        if (e && e->file < p->nfiles) fprintf(out, "\t%s\t%u\n", p->files[e->file], e->line);
        else fprintf(out, "\t-\t0\n");
        pc += len;
    }
}
