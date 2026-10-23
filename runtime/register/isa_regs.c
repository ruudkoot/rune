/* What of runtime/register is the register bytecode's (src/isa/regs.sml): the check of
   a program's code, its disassembly, and the fingerprint its .rbc files and
   images carry. It takes the place of runtime/stack/isa_stack.c, which build/librune.a
   holds for runevm-stack: a definition here is taken before the archive's. */
#include "regvm.h"
#include "jit.h"

const uint32_t isa_fingerprint = REG_ISA_FINGERPRINT;
const char isa_image_magic[ISA_IMAGE_MAGIC_SIZE] = "runevm image 15 isa " REG_ISA_FINGERPRINT_HEX;

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
   which this is what makes safe.

   validate_program_from checks the functions from first on, and the code
   from where the first of them begins, which is what a unit appended to
   the program brings (runtime/loader.c, load_unit_mem): what is before it
   was checked when it came. Its result is indexed from that place. */
uint8_t *validate_program(Program *p, char *err, size_t errlen) {
    return validate_program_from(p, 0, err, errlen);
}

uint8_t *validate_program_from(Program *p, uint32_t first, char *err, size_t errlen) {
    if (first >= p->nfuncs) { fail(err, errlen, "no function to check"); return NULL; }
    /* what a frame's info word holds (regvm.h, reg_info) */
    if (p->nfuncs >= (UINT32_C(1) << 30) || p->code_len >= (UINT32_C(1) << 31)) { fail(err, errlen, "a program too large"); return NULL; }
    const uint32_t base = p->funcs[first].code_offset;
    for (uint32_t i = first; i < p->nfuncs; i++) {
        if (p->funcs[i].code_offset >= p->code_len) { fail(err, errlen, "function offset out of range"); return NULL; }
        if (i > 0 && p->funcs[i].code_offset < p->funcs[i - 1].code_offset) { fail(err, errlen, "functions out of order"); return NULL; }
        if (p->funcs[i].nlocals < 1 || p->funcs[i].nlocals > 1000000) { fail(err, errlen, "bad frame size"); return NULL; }
        uint32_t end = (i + 1 < p->nfuncs) ? p->funcs[i + 1].code_offset : p->code_len;
        if (p->funcs[i].code_end != end) { fail(err, errlen, "function does not end where the next begins"); return NULL; }
    }
    if (first > 0 && p->funcs[first - 1].code_end != base) { fail(err, errlen, "function does not end where the next begins"); return NULL; }
    uint8_t *starts = calloc(p->code_len - base + 1, 1);
    if (!starts) { fail(err, errlen, "out of memory"); return NULL; }
    for (uint32_t i = first; i < p->nfuncs; i++) { p->funcs[i].maxstack = 1; p->funcs[i].reads_closure = 0; }
    uint32_t fi = first;
    uint32_t pc = base;
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
        if (op == ROP_ENV || op == ROP_SELF) p->funcs[fi].reads_closure = 1;
        starts[pc - base] = 1;
        pc += len;
    }
    /* jump targets and function entries must be instruction boundaries,
       and a jump stays in its function; a SWITCH's table is JUMPs of its
       own function, which the code goes on after */
    pc = base;
    fi = first;
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
                bad = !starts[e - base] || p->code[e] != ROP_JUMP;
            }
            if (bad || !starts[end - base]) { free(starts); snprintf(err, errlen, "bad SWITCH table at %u", pc); return NULL; }
        }
        for (int k = 0; k < rop_nfixed[op]; k++)
            if (rop_kinds[op][k] == RK_LABEL || rop_kinds[op][k] == RK_HANDLER_LABEL) {
                int32_t t = read_i32(at + 1 + 4 * k);
                if (t < 0 || (uint32_t)t < from || (uint32_t)t >= to || !starts[(uint32_t)t - base]) {
                    free(starts); snprintf(err, errlen, "bad jump target at %u", pc); return NULL;
                }
            }
        pc += rop_length(at);
    }
    for (uint32_t i = first; i < p->nfuncs; i++)
        if (!starts[p->funcs[i].code_offset - base]) { free(starts); fail(err, errlen, "function entry is not an instruction"); return NULL; }
    /* the representations section, where the file has one: its blocks
       and loop heads begin at instructions of their functions, and each
       register's representation agrees with what the code writes into it,
       where the instruction says (docs/bytecode.md, The representations) */
    for (uint32_t fi = first; fi < p->nfuncs; fi++) {
        const Function *fn = &p->funcs[fi];
        if (!fn->has_meta) continue;
        for (uint32_t b = 0; b < fn->nblocks; b++)
            if (fn->blocks[b].pc < fn->code_offset || fn->blocks[b].pc >= fn->code_end || !starts[fn->blocks[b].pc - base]) {
                free(starts); snprintf(err, errlen, "a block of %s begins at %u, which is no instruction of it", fn->name, fn->blocks[b].pc); return NULL;
            }
        for (uint32_t k = 0; k < fn->nloops; k++)
            if (fn->loops[k] < fn->code_offset || fn->loops[k] >= fn->code_end || !starts[fn->loops[k] - base]) {
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

/* A unit's code, its own numbers made the program's (vm.h, Relocation):
   every operand by the kind the instruction set gives it, the lists of
   registers left as they are. A number past what the unit has is refused
   here; the check of the code (validate_program_from) refuses the rest. */
int relocate_code(uint8_t *code, const Relocation *r, char *err, size_t errlen) {
    uint32_t pc = 0;
    while (pc < r->code_len) {
        uint8_t *at = code + pc;
        uint8_t op = at[0];
        if (op >= ROP__COUNT) { snprintf(err, errlen, "invalid opcode %u at %u", op, pc); return 0; }
        if ((uint64_t)pc + 1 + 4 * (uint64_t)rop_nfixed[op] > r->code_len) return fail(err, errlen, "truncated instruction");
        uint64_t len = 1 + 4 * ((uint64_t)rop_nfixed[op] + rop_list_length(at));
        if ((uint64_t)pc + len > r->code_len) return fail(err, errlen, "truncated instruction");
        for (int k = 0; k < rop_nfixed[op]; k++) {
            uint8_t *o = at + 1 + 4 * k;
            int32_t v = read_i32(o);
            uint32_t to;
            switch ((enum RegOperandKind)rop_kinds[op][k]) {
            case RK_FUNCTION:
                if (v >= 0 && (uint32_t)v < r->nfuncs) to = r->func_base + (uint32_t)v;
                else if (v >= 0 && (uint32_t)v - r->nfuncs < r->nimports && r->imports[(uint32_t)v - r->nfuncs] != UINT32_MAX)
                    to = r->imports[(uint32_t)v - r->nfuncs];
                else { snprintf(err, errlen, "a function of no unit for %s at %u", rop_names[op], pc); return 0; }
                break;
            case RK_GLOBAL:
                if (v < 0 || (uint32_t)v >= r->nglobals) { snprintf(err, errlen, "bad global for %s at %u", rop_names[op], pc); return 0; }
                to = r->globals[v];
                break;
            case RK_CONSTANT: case RK_STRING_CONSTANT:
                if (v < 0 || (uint32_t)v >= r->nconsts) { snprintf(err, errlen, "bad constant for %s at %u", rop_names[op], pc); return 0; }
                to = r->const_base + (uint32_t)v;
                break;
            case RK_LABEL: case RK_HANDLER_LABEL:
                if (v < 0 || (uint32_t)v >= r->code_len) { snprintf(err, errlen, "bad jump target at %u", pc); return 0; }
                to = r->code_base + (uint32_t)v;
                break;
            default:
                continue;
            }
            write_u32(o, to);
        }
        pc += (uint32_t)len;
    }
    return 1;
}

/* RET of register 0, the argument, in a frame of one register */
uint32_t return_function_code(uint8_t *out, uint32_t *nlocals) {
    out[0] = ROP_RET;
    write_u32(out + 1, 0);
    *nlocals = 1;
    return 5;
}

/* <debug> (runtime/debug.c): register 0 the hook, 1 the event, 2 what
   nothing reads, 3 the exception it stopped for or unit. The hook called,
   then rt_debug_return, which takes the frame off; the RET is never
   reached, but makes the code end as a function's does. */
uint32_t debug_function_code(uint8_t *out, uint32_t *nlocals) {
    uint32_t n = 0;
    out[n++] = ROP_CALL; write_u32(out + n, 0); n += 4; write_u32(out + n, 1); n += 4;
    out[n++] = ROP_RESULT; write_u32(out + n, 2); n += 4;
    out[n++] = ROP_PRIM; write_u32(out + n, PRIM_rt_debug_return); n += 4; write_u32(out + n, 2); n += 4;
    write_u32(out + n, 3); n += 4;
    out[n++] = ROP_RET; write_u32(out + n, 2); n += 4;
    *nlocals = 4;
    return n;
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

/* ---- The frames (vm.h, *The frames, as the runtime reads them*;
   docs/plans/native-frames.md, M4) ----
   A frame lives in the value stack: its registers from its base b, and
   below them its header of three words (regvm.h), which its caller writes --
     b-3  the info word: the caller's function and the pc of the RESULT the
          call returns to, and what it says of the caller's base; written by
          the interpreter and the runtime, and where a frame is made to
          return to the interpreter
     b-2  the closure the frame runs in, where it reads one
          (Function.reads_closure); else what the slot held, which the
          collector makes unit
     b-1  the return word: where compiled code's RET goes, an odd number --
          the interpreter's (VM.ret_word, or 1 before the region's return
          stub exists), or a landing in a caller's compiled code, which
          says the caller's function and pc (jit_landing_info) --
   and, below them, for a frame the runtime pushed above values of its own
   (vm_frame_push), the caller's base. A frame's caller's registers end
   where its header begins, but for those; the top level's frame has no
   caller. A frame's id is its base, which grows with the depth; vm->fp is
   the running frame's, vm->func its function. */
const uint32_t isa_frame_header = REG_HEADER;

static Value ret_word(VM *vm) {
    if (!vm->ret_word) vm->ret_word = 1;
    return vm->ret_word;
}

/* the frame's return word, seen through the return barrier where the
   frame is the barrier's (below, M5) */
static inline int barrier_at(const VM *vm, size_t b) {
    return vm->barrier_at && b == vm->barrier_at && vm->stack[b - 1] == vm->barrier_stub;
}
static inline Value ret_word_at(const VM *vm, size_t b) { return barrier_at(vm, b) ? vm->barrier_word : vm->stack[b - 1]; }
static void set_ret_word_at(VM *vm, size_t b, Value w) {
    if (barrier_at(vm, b)) vm->barrier_word = w;
    else vm->stack[b - 1] = w;
}
/* what the header of the frame at base b says of its caller -- its base,
   function and pc in f's caller_*, f's ret_pc; bottom where it has none --
   and where the header begins. A caller whose registers would not end
   below the header is a fault of the VM's (or of an image's, which
   vm_frames_install checks). */
static void broken_below(VM *vm, size_t b) { vm_fatal(vm, "the frames are broken below the frame at %zu", b); }
static void read_header(VM *vm, size_t b, FrameRef *f) {
    Value w = ret_word_at(vm, b);
    f->bottom = 0;
    f->head = b - 3;
    f->stale_slot = NULL;
    if (reg_interp_word(vm, w)) {
        Value info = vm->stack[b - 3];
        f->caller_func = reg_info_func(info);
        f->ret_pc = reg_info_pc(info);
        int kind = reg_info_kind(info);
        if (kind == REG_INFO_BOTTOM) { f->caller_base = 0; f->bottom = 1; return; }
        if (f->caller_func >= vm->prog.nfuncs) broken_below(vm, b);
        if (kind == REG_INFO_EXPLICIT) {
            f->head = b - 4;
            f->caller_base = (size_t)val_imm(vm->stack[b - 4]);
        } else f->caller_base = b - 3 - vm->prog.funcs[f->caller_func].nlocals;
    } else {
        if (!jit_landing_info(vm, w, &f->caller_func, &f->ret_pc))
            vm_fatal(vm, "a frame returns to no code (its return word %#llx)", (unsigned long long)w);
        if (f->caller_func >= vm->prog.nfuncs) broken_below(vm, b);
        f->caller_base = b - 3 - vm->prog.funcs[f->caller_func].nlocals;
        f->stale_slot = &vm->stack[b - 3];   /* compiled code called: the info word is not written */
    }
    if (f->caller_base < 3 || f->caller_base >= b || f->caller_base + vm->prog.funcs[f->caller_func].nlocals > f->head)
        broken_below(vm, b);
}
/* The caller of the frame at b, as a walk steps down to it (the
   collections' walk, vm_frames_from; the barrier's pass): one of the two
   landings it met last -- a deep recursion's frames return to one or two,
   a recursive call or two -- or one the region was asked of lately
   (jit_landing_seen) read in line, the caller's base by how far below
   the frame it is; else the header read as above (*f filled, the step
   given 0). */
typedef struct { Value word; uint32_t func, pc; size_t below; } LastLanding;
typedef struct { size_t base; uint32_t func, pc; } Caller;
static inline void met(LastLanding *last, Value w, uint32_t func, uint32_t pc, size_t below) {
    last[1] = last[0];
    last[0] = (LastLanding){w, func, pc, below};
}
static inline int step_down(VM *vm, size_t b, LastLanding *last, Caller *c, FrameRef *f) {
    Value w = ret_word_at(vm, b);
    size_t below;
    if (w != last[0].word && w == last[1].word) {   /* the other of two, first now */
        LastLanding t = last[1];
        last[1] = last[0];
        last[0] = t;
    }
    if (w == last[0].word) {
        c->func = last[0].func;
        c->pc = last[0].pc;
        below = last[0].below;
    } else {
        const struct LandingSeen *seen = jit_landing_seen ? &jit_landing_seen[jit_seen_slot(w)] : NULL;
        if (seen && seen->word == w) {
            c->func = seen->func;
            c->pc = seen->pc;
            below = seen->below;
        } else {
            read_header(vm, b, f);
            c->base = f->caller_base;
            c->func = f->caller_func;
            c->pc = f->ret_pc;
            if (!f->bottom && !reg_interp_word(vm, w)) met(last, w, c->func, c->pc, b - c->base);
            return 0;
        }
        met(last, w, c->func, c->pc, below);
    }
    c->base = b - below;   /* (below b, else it wraps above it) */
    if (c->base < 3 || c->base >= b) broken_below(vm, b);
    return 1;
}
/* frame b, of function func, waiting at pc (the running one: at vm->pc) */
static void frame_at(VM *vm, size_t b, uint32_t func, uint32_t pc, FrameRef *f) {
    f->func = func;
    f->pc = pc;
    f->base = b;
    f->id = b;
    f->closure_root = NULL;
    read_header(vm, b, f);
    Value c = vm->stack[b - 2];
    f->closure = vm->prog.funcs[func].reads_closure && val_is_ptr(c) ? val_ptr(c) : NULL;
    f->closure_slot = &vm->stack[b - 2];
}

size_t vm_frame_id(const VM *vm) { return vm->fp; }

int vm_frame_top(VM *vm, FrameRef *f) {
    if (!vm->frames_active || vm->fp < 3 || vm->fp > vm->stack_cap) return 0;   /* (a fatal error may come before the frame is pushed) */
    frame_at(vm, vm->fp, vm->func, vm->pc, f);
    return 1;
}

int vm_frame_down(VM *vm, FrameRef *f) {
    if (f->bottom) return 0;
    uint32_t pc = f->ret_pc;
    frame_at(vm, f->caller_base, f->caller_func, pc, f);
    return 1;
}

int vm_frame_find(VM *vm, size_t id, FrameRef *f) {
    int more = vm_frame_top(vm, f);
    while (more && f->id > id) more = vm_frame_down(vm, f);
    return more && f->id == id;
}

size_t vm_frames_from(VM *vm, size_t low, FrameRef **out) {
    *out = NULL;
    if (!vm->frames_active || vm->fp < 3 || vm->fp > vm->stack_cap || low > vm->fp) return 0;
    /* filled from the end, the walk being from the top: a frame is four
       slots at least (a register and its header), which bounds how many */
    size_t most = (vm->fp - low) / 4 + 2;
    if (most > vm->frame_buf_cap) {
        size_t cap = vm->frame_buf_cap ? vm->frame_buf_cap : 64;
        while (cap < most) cap *= 2;
        FrameRef *b = realloc(vm->frame_buf, cap * sizeof *b);
        if (!b) vm_fatal(vm, "out of memory (the frames walked)");
        vm->frame_buf = b;
        vm->frame_buf_cap = cap;
    }
    /* each frame made in its place, as frame_at makes it, from the top
       down: the walk of a collection, which goes as far as the watermark */
    FrameRef *end = vm->frame_buf + most, *at = end;
    const Function *funcs = vm->prog.funcs;
    LastLanding last[2] = {{0, 0, 0, 0}, {0, 0, 0, 0}};
    size_t b = vm->fp;
    uint32_t func = vm->func, pc = vm->pc;
    for (;;) {
        if (at == vm->frame_buf) vm_fatal(vm, "the frames are broken (more than their slots hold)");
        FrameRef *f = --at;
        Caller c;
        int bottom = 0;
        size_t head = b - 3;
        Value *stale = &vm->stack[b - 3];   /* a landing's: compiled code called */
        if (!step_down(vm, b, last, &c, f)) { bottom = f->bottom; head = f->head; stale = f->stale_slot; }
        Value k = vm->stack[b - 2];
        f->func = func;
        f->pc = pc;
        f->ret_pc = c.pc;
        f->base = b;
        f->id = b;
        f->head = head;
        f->closure = funcs[func].reads_closure && val_is_ptr(k) ? val_ptr(k) : NULL;
        f->closure_root = NULL;
        f->closure_slot = &vm->stack[b - 2];
        f->stale_slot = stale;
        f->caller_base = c.base;
        f->caller_func = c.func;
        f->bottom = bottom;
        if (bottom || c.base < low) break;
        b = c.base;
        func = c.func;
        pc = c.pc;
    }
    *out = at;
    return (size_t)(end - at);
}

int vm_frame_top_live(const VM *vm, const FrameRef *top) { return vm->top_frame == (const void *)(vm->stack + top->base); }

/* ---- The watermark (runtime/gc/minor.c) by a return barrier
   (docs/plans/native-frames.md, M5) ----
   Where the JIT's region has the barrier's stub (VM.barrier_stub, an odd
   word), the frame at the watermark has it for its return word, its own
   kept in VM.barrier_word: a return from that frame -- the only one that
   goes below the watermark -- goes through the stub, which lowers the
   watermark to the caller and moves the barrier there
   (reg_barrier_pass), so that compiled code's returns compare nothing.
   Every reader of a return word sees through it (ret_word_at). A
   collection sets the watermark at the frame that runs, the barrier
   leaving the frame it was at; a pop below it -- a raise, the debugger's
   frame dropped -- lowers it, the frame that had the barrier gone. */
/* the barrier at the frame based at b, where there is a stub */
static void barrier_arm(VM *vm, size_t b) {
    vm->barrier_at = 0;
    if (!vm->barrier_stub || !vm->frames_active || b < 3 || b > vm->fp) return;
    vm->barrier_word = vm->stack[b - 1];
    vm->stack[b - 1] = vm->barrier_stub;
    vm->barrier_at = b;
}
/* the watermark lowered to the frame based at id, below it popped (the
   barrier's frame with them) */
static void frames_lower(VM *vm, size_t id) {
    if (id >= vm->fp_low) return;
    vm->fp_low = id;
    barrier_arm(vm, id);
}
/* the watermark at id, the frames as they are: the barrier's frame given
   its return word back, and the barrier at id where a frame is based there */
void vm_frames_mark_low(VM *vm, size_t id) {
    if (barrier_at(vm, vm->barrier_at)) vm->stack[vm->barrier_at - 1] = vm->barrier_word;
    vm->barrier_at = 0;
    vm->barrier_step = 1;
    vm->fp_low = id;
    FrameRef f;
    if (vm->barrier_stub && id >= 3 && vm_frame_find(vm, id, &f)) barrier_arm(vm, id);
}
size_t vm_frames_low(const VM *vm) { return vm->fp_low; }
/* a return through the barrier, the frame at the watermark returning: its
   return word, given back; the watermark lowered to its caller -- or
   further, by as many frames as the returns through the barrier since the
   last collection, doubling to 1024, so that a deep recursion that
   unwinds goes through it not at every return but at every 2^k-th, the
   collection after scanning at most twice the frames that ran (none of
   them is young but where it ran) -- and the barrier there (the top
   level's frame has none below it) */
Value reg_barrier_pass(VM *vm) {
    size_t b = vm->barrier_at;
    Value w = vm->barrier_word;
    vm->stack[b - 1] = w;
    vm->barrier_at = 0;
    vm->barrier_runs++;
    FrameRef f;
    LastLanding last[2] = {{0, 0, 0, 0}, {0, 0, 0, 0}};
    Caller c;
    int bottom = !step_down(vm, b, last, &c, &f) && f.bottom;   /* the top level's frame returns */
    for (uint32_t k = 1; !bottom && k < vm->barrier_step; k++) {
        size_t at = c.base;
        if (!step_down(vm, at, last, &c, &f) && f.bottom) { c.base = at; break; }   /* the watermark at the top level's frame */
    }
    if (vm->barrier_step < 1024) vm->barrier_step = vm->barrier_step ? 2 * vm->barrier_step : 1;
    if (!bottom) {
        vm->fp_low = c.base;
        if (vm->barrier_stub) {
            vm->barrier_word = vm->stack[c.base - 1];
            vm->stack[c.base - 1] = vm->barrier_stub;
            vm->barrier_at = c.base;
        }
    }
    return w;
}
/* the barrier where the watermark is, the stub made (jit_region_init) */
void reg_barrier_arm(VM *vm) { vm_frames_mark_low(vm, vm->fp_low); }
/* runtime/gc/check.c: the barrier at the watermark's frame where there is
   a stub and a frame there, and nowhere else */
const char *vm_frames_check(VM *vm) {
    FrameRef f;
    int there = vm->barrier_stub && vm->fp_low >= 3 && vm_frame_find(vm, vm->fp_low, &f);
    if (there && (vm->barrier_at != vm->fp_low || vm->stack[vm->fp_low - 1] != vm->barrier_stub))
        return "the return barrier not at the stack's watermark";
    if (!there && vm->barrier_at) return "a return barrier where the stack's watermark has no frame";
    return NULL;
}

/* a frame the runtime pushes above values of its own keeps its caller's
   base below its header */
size_t vm_frame_push(VM *vm, uint32_t func, Obj *closure, uint32_t ret_pc, size_t top) {
    const Function *fn = &vm->prog.funcs[func];
    int below = vm->frames_active && top == vm->fp + vm->prog.funcs[vm->func].nlocals;
    size_t b = top + 3 + (below ? 0 : 1);
    if (b + fn->nlocals + fn->maxstack + 1 > vm->stack_cap) vm_grow_stack(vm, b + fn->nlocals + fn->maxstack + 1);
    if (!below) vm->stack[b - 4] = mk_int((int64_t)vm->fp);
    vm->stack[b - 3] = reg_info(vm->func, ret_pc, below ? REG_INFO_CALLER : REG_INFO_EXPLICIT);
    vm->stack[b - 2] = closure ? mk_ptr(closure) : mk_unit();
    vm->stack[b - 1] = ret_word(vm);
    vm->fp = b;
    vm->func = func;
    return b;
}

void vm_frame_drop(VM *vm) {
    FrameRef f;
    if (!vm_frame_top(vm, &f) || f.bottom) vm_fatal(vm, "no frame to drop");
    vm->fp = f.caller_base;
    vm->func = f.caller_func;
    frames_lower(vm, vm->fp);
}

void vm_frame_top_level(VM *vm) {
    vm->sp = 0;
    vm_push(vm, reg_info(0, 0, REG_INFO_BOTTOM));
    vm_push(vm, mk_unit());
    vm_push(vm, ret_word(vm));
    for (uint32_t i = 0; i < vm->prog.funcs[0].nlocals; i++) vm_push(vm, mk_unit());
    vm->fp = 3;
    vm->func = 0;
    vm->frames_active = 1;
    vm->barrier_at = 0;
}

void vm_frame_unwind(VM *vm, size_t id, uint32_t func) {
    vm->fp = id;
    vm->func = func;
    frames_lower(vm, vm->fp);
}
void reg_frames_lower(VM *vm, size_t id) { frames_lower(vm, id); }

/* An image's frames (runtime/image.c), its stack and handlers as the image
   has them, without the headers: the stack made over with a header below
   each frame's registers -- each frame returning to the interpreter, which
   its info word tells, and one whose registers do not begin where its
   caller's end given its caller's base -- and the handlers' places moved
   with it. The frames are checked to lie in order, each above the
   registers of the one below. (A closure is not yet an object here, but
   its distance into the heap: runtime/image.c places it, in the stack,
   and checks it.) */
int vm_frames_install(VM *vm, const FrameRecord *frames, size_t n, const char **err) {
    *err = "the frames of the image are not sound";
    vm->frames_active = n > 0;
    if (!n) return 1;
    const Program *p = &vm->prog;
    size_t sp = vm->sp;
    for (size_t k = 0; k < n; k++) {
        if (frames[k].func >= p->nfuncs || frames[k].base > sp) return 0;
        if (k > 0 && frames[k].base < frames[k - 1].base + p->funcs[frames[k - 1].func].nlocals) return 0;
    }
    for (size_t i = 0; i < vm->hp; i++) {
        size_t k = vm->handlers[i].fp;
        if (k >= n || vm->handlers[i].sp < frames[k].base || (k + 1 < n && vm->handlers[i].sp > frames[k + 1].base)) return 0;
    }
    /* the words of the headers below each frame's base, each frame's own and those below */
    size_t *words = malloc(n * sizeof *words);
    *err = "out of memory";
    if (!words) return 0;
    for (size_t k = 0, sum = 0; k < n; k++) {
        sum += k > 0 && frames[k].base != frames[k - 1].base + p->funcs[frames[k - 1].func].nlocals ? 4 : 3;
        words[k] = sum;
    }
    size_t top = sp + words[n - 1];
    vm_grow_stack(vm, top + 1);
    for (size_t k = n; k-- > 0;) {
        size_t from = frames[k].base, to = k + 1 < n ? frames[k + 1].base : sp, at = from + words[k];
        memmove(vm->stack + at, vm->stack + from, (to - from) * sizeof(Value));
        int kind = k == 0 ? REG_INFO_BOTTOM : words[k] - words[k - 1] == 4 ? REG_INFO_EXPLICIT : REG_INFO_CALLER;
        if (kind == REG_INFO_EXPLICIT) vm->stack[at - 4] = mk_int((int64_t)(frames[k - 1].base + words[k - 1]));
        vm->stack[at - 3] = reg_info(k > 0 ? frames[k - 1].func : 0, frames[k].ret_pc, kind);
        vm->stack[at - 2] = frames[k].closure ? mk_ptr(frames[k].closure) : mk_unit();
        vm->stack[at - 1] = ret_word(vm);
    }
    for (size_t i = 0; i < vm->hp; i++) {
        size_t k = vm->handlers[i].fp;
        vm->handlers[i].fp = frames[k].base + words[k];
        vm->handlers[i].sp += words[k];
        vm->handlers[i].func = frames[k].func;
    }
    vm->sp = top;
    vm->fp = frames[n - 1].base + words[n - 1];
    vm->func = frames[n - 1].func;
    free(words);
    vm->stack_clean = vm->sp;   /* nothing above it claimed (vm.h, M6) */
    vm->stack_room = vm_room(vm, vm->sp);
    vm->barrier_at = 0;
    vm_frames_mark_low(vm, 0);
    return 1;
}

/* the frames whose return word is a landing in [lo, hi) given the
   interpreter's, their info words told their callers */
void reg_frames_to_interpreter(VM *vm, uintptr_t lo, uintptr_t hi) {
    FrameRef f;
    for (int more = vm_frame_top(vm, &f); more; more = vm_frame_down(vm, &f)) {
        Value w = ret_word_at(vm, f.base);
        if (reg_interp_word(vm, w) || (uintptr_t)w - JIT_RET_BIAS < lo || (uintptr_t)w - JIT_RET_BIAS >= hi) continue;
        vm->stack[f.base - 3] = reg_info(f.caller_func, f.ret_pc, REG_INFO_CALLER);
        set_ret_word_at(vm, f.base, ret_word(vm));
    }
}
void vm_frames_to_interpreter(VM *vm) {
    reg_frames_to_interpreter(vm, 0, UINTPTR_MAX);
    reg_frames_ret_word(vm);
}
void reg_frames_ret_word(VM *vm) {
    FrameRef f;
    for (int more = vm_frame_top(vm, &f); more; more = vm_frame_down(vm, &f))
        if (reg_interp_word(vm, ret_word_at(vm, f.base))) set_ret_word_at(vm, f.base, ret_word(vm));
}

/* Register-native safepoints name frame bases in the moving value stack. */
void vm_safepoints_save(const VM *vm, NativeSafepoints *saved) {
    saved->has_top = vm->top_frame != NULL;
    saved->has_verify = vm->verify_frame != NULL;
    saved->top = saved->has_top ? (const Value *)vm->top_frame - vm->stack : 0;
    saved->verify = saved->has_verify ? (const Value *)vm->verify_frame - vm->stack : 0;
}
void vm_safepoints_restore(VM *vm, const NativeSafepoints *saved) {
    vm->top_frame = saved->has_top ? (const void *)(vm->stack + saved->top) : NULL;
    vm->verify_frame = saved->has_verify ? (const void *)(vm->stack + saved->verify) : NULL;
}
