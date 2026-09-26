/* Tier 1 of vm/new's JIT (compile.h). */
#include "compile.h"
#include "fastprim.h"
#include "sys.h"
#include "jit_emit.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__x86_64__) || defined(_M_X64)
#define JIT_TARGET 1
#else
#define JIT_TARGET 0
#endif
#if defined(_WIN32)
#define JIT_WIN 1
#else
#define JIT_WIN 0
#endif

/* ---- the helpers ---- */

static const char *const fatal_text[] = {
    "expected tuple", "expected constructor with argument", "expected constructor with fields", "expected closure",
    "expected exception",
    "global %d read before initialization", "environment slot %d out of range", "SELF outside a closure",
    "tuple index %d out of range", "DECON of a constructor of tag %d where %d is wanted", "CONTAG on non-constructor",
    "MKEXN on non-constructor", "JUMPIF on non-bool", "JUMPIFNOT on non-bool", "JUMPIFNOTTAG on non-constructor",
    "SWITCH on non-constructor", "FIELD of a constructor of tag %d where %d is wanted", "constructor field %d out of range",
    "POPHANDLER with no handler", "RAISE of non-exception", "expected closure in call", "bad function index",
    "a primitive that changes the world in PRIM"
};

void jit_h_fatal(VM *vm, int what, int32_t a, int32_t b) {
    vm_fatal(vm, fatal_text[what], (int)a, (int)b);
}

/* PRIM p d args: the common case in the loop's way (fastprim.h), or the
   primitive itself with its arguments pushed. 0 when done; else what the
   driver is to do, the machine unwound to a handler. */
/* The registers of a function a call need not fill with unit: those
   written -- and not read -- before the first instruction at which a
   collection could see them or control could arrive from elsewhere. The
   walk is the function's entry prefix in order, stopped at the first
   instruction that may allocate or raise (rop_raises, or one of the
   allocating ones), calls, branches, jumps or is a target; a register
   read there before it is written needs the fill (unit is what the loop
   would read). The answer is the lowest register needing it: the calls
   fill from there up, since the compiler numbers registers by first use
   (src/backend/regs.sml), which keeps the answer tight. */
uint32_t jit_fill_from(VM *vm, JitProgram *jit, uint32_t f) {
    if (jit->fill_from[f] != UINT32_MAX) return jit->fill_from[f];
    const Program *p = &vm->prog;
    const Function *fn = &p->funcs[f];
    const uint8_t *code = p->code;
    uint32_t nlocals = fn->nlocals;
    /* the targets of jumps within the function: where control arrives */
    uint8_t *target = calloc(fn->code_end - fn->code_offset + 1, 1);
    uint32_t lowest = nlocals;   /* nothing needs the fill, so far */
    if (!target) { jit->fill_from[f] = 0; return 0; }
    for (uint32_t pc = fn->code_offset; pc < fn->code_end; ) {
        uint8_t op = code[pc];
        uint32_t l = rop_length(code + pc);
        for (int k = 0; k < rop_nfixed[op]; k++)
            if (rop_kinds[op][k] == RK_LABEL || rop_kinds[op][k] == RK_HANDLER_LABEL) {
                int32_t t = read_i32(code + pc + 1 + 4 * k);
                if (t >= (int32_t)fn->code_offset && (uint32_t)t < fn->code_end) target[t - fn->code_offset] = 1;
            }
        if (op == ROP_SWITCH) {
            uint32_t n = (uint32_t)read_i32(code + pc + 5);
            for (uint32_t k = 0; k < n; k++) {
                int32_t t = read_i32(code + pc + l + 5 * k + 1);
                if (t >= (int32_t)fn->code_offset && (uint32_t)t < fn->code_end) target[t - fn->code_offset] = 1;
            }
            if (pc + l + 5 * n < fn->code_end) target[pc + l + 5 * n - fn->code_offset] = 1;
            pc += l + 5 * n;
        } else pc += l;
    }
    uint64_t written = 0;   /* registers 0..63; a function with more is filled whole */
    if (nlocals > 64) { free(target); jit->fill_from[f] = 0; return 0; }
    for (uint32_t pc = fn->code_offset; pc < fn->code_end; ) {
        if (pc != fn->code_offset && target[pc - fn->code_offset]) break;
        uint8_t op = code[pc];
        uint32_t l = rop_length(code + pc);
        /* what it reads: every register operand but the destination, and
           the list's registers */
        int dest = rop_dest[op];
        for (int k = 0; k < rop_nfixed[op]; k++)
            if (rop_kinds[op][k] == RK_REGISTER && k != dest) {
                uint32_t r = (uint32_t)read_i32(code + pc + 1 + 4 * k);
                if (r < nlocals && !(written & ((uint64_t)1 << r)) && r < lowest) lowest = r;
            }
        if (rop_list_at[op] >= 0 && !rop_list_prim[op]) {
            uint32_t n = (uint32_t)read_i32(code + pc + 1 + 4 * rop_list_at[op]);
            const uint8_t *L = code + pc + 1 + 4 * rop_nfixed[op];
            for (uint32_t i = 0; i < n; i++) {
                uint32_t r = (uint32_t)read_i32(L + 4 * i);
                if (r < nlocals && !(written & ((uint64_t)1 << r)) && r < lowest) lowest = r;
            }
        } else if (rop_list_at[op] >= 0) {
            /* a primitive's arguments: as many as its arity */
            int prim = read_i32(code + pc + 1 + 4 * rop_list_at[op]);
            uint32_t n = prim_arity[prim];
            const uint8_t *L = code + pc + 1 + 4 * rop_nfixed[op];
            for (uint32_t i = 0; i < n; i++) {
                uint32_t r = (uint32_t)read_i32(L + 4 * i);
                if (r < nlocals && !(written & ((uint64_t)1 << r)) && r < lowest) lowest = r;
            }
        }
        /* a point a collection can happen, a call, a raise, or a branch:
           the rest of the registers must be unit for it */
        int flow = rop_flow[op];
        if (rop_raises[op] || flow != FLOW_NEXT || op == ROP_TUPLE || op == ROP_CLOSURE || op == ROP_CON
            || op == ROP_CONN || op == ROP_NEWEXN || op == ROP_MKEXN || op == ROP_PUSHHANDLER) break;
        if (dest >= 0) {
            uint32_t r = (uint32_t)read_i32(code + pc + 1 + 4 * dest);
            if (r < nlocals) written |= (uint64_t)1 << r;
        }
        pc += l;
    }
    /* the lowest register not written before the stop, or read before */
    for (uint32_t r = 0; r < nlocals && r < lowest; r++)
        if (!(written & ((uint64_t)1 << r))) { lowest = r; break; }
    free(target);
    jit->fill_from[f] = lowest;
    return lowest;
}

int jit_h_prim(VM *vm, int prim, int32_t d, const uint8_t *L) {
    JitProgram *jit = jit_program(vm);
    if (jit->prim_calls) jit->prim_calls[prim]++;
    Value *base = vm->stack + vm->frames[vm->fp].base;
    uint32_t n = prim_arity[prim];
    if (prim_fast(prim, n, base, L, &base[d])) return 0;
    for (uint32_t i = 0; i < n; i++) {
        Value v = vm->stack[vm->frames[vm->fp].base + (size_t)read_i32(L + 4 * i)];
        vm_push(vm, v);
    }
    const void *native = vm->hp ? vm->handlers[vm->hp - 1].native : NULL;
    int r = prim_table[prim](vm);
    if (r == 1) { if (native) { jit_program(vm)->at = native; return RUN_NATIVE; } return RUN_INTERP; }
    if (r == PRIM_NEW_WORLD) vm_fatal(vm, "a primitive that changes the world in PRIM");
    Value v = vm_pop(vm);
    vm->stack[vm->frames[vm->fp].base + (size_t)d] = v;
    return 0;
}

Obj *jit_h_alloc(VM *vm, int kind, int contag, uint32_t n) {
    return vm_alloc_fields(vm, (uint8_t)kind, (uint16_t)contag, n);
}

/* RET s, as the loop does it (src/isa/regs.sml): the value into the
   register of the caller's RESULT, or onto the stack; what the driver is
   to do next. */
int jit_h_ret(VM *vm, int32_t s) {
    Frame *fr = &vm->frames[vm->fp];
    Value v = vm->stack[fr->base + (size_t)s];
    uint32_t back = fr->ret_pc;
    const void *back_native = fr->native_ret;
    size_t top = fr->base;
    if (vm->fp == 0) { vm->sp = top; vm->pc = back; vm_push(vm, v); return RUN_HALT; }
    vm->fp--;
    fr = &vm->frames[vm->fp];
    vm->sp = top;
    const uint8_t *code = vm->prog.code;
    if (code[back] == ROP_RESULT) {
        vm->stack[fr->base + (size_t)read_i32(code + back + 1)] = v;
        vm->pc = back + 5;
    } else {
        vm_push(vm, v);
        vm->pc = back;
    }
    if (back_native) { jit_program(vm)->at = back_native; return RUN_NATIVE; }
    return RUN_INTERP;
}

/* ---- the helpers of the calls, the handlers and PRIMPUSH (M5) ---- */

void jit_h_grow(VM *vm, size_t need) { vm_grow_stack(vm, need); }
void jit_h_grow_frames(VM *vm) { vm_grow_frames(vm); }

/* the handler a raise would land in, before the raise pops it: its native
   address, or NULL where it is the interpreter's */
static const void *handler_native(VM *vm) {
    return vm->hp ? vm->handlers[vm->hp - 1].native : NULL;
}
/* what the driver is to do after a raise: into the handler's native code,
   or the interpreter */
static int after_raise(VM *vm, const void *native) {
    if (native) { jit_program(vm)->at = native; return RUN_NATIVE; }
    return RUN_INTERP;
}

/* CALL f x from native code, as the loop does it (src/isa/regs.sml): the
   frame pushed, returning to the code at after, and the callee's registers
   made; the callee's entry, or NULL where it is interpreted, the VM exact
   for it either way. */
const void *jit_h_call(VM *vm, int32_t a, int32_t b, const void *after) {
    Program *p = &vm->prog;
    Frame *fr = &vm->frames[vm->fp];
    Value arg = vm->stack[fr->base + (size_t)b];
    Value cv = vm->stack[fr->base + (size_t)a];
    Obj *c = vm_expect_obj(vm, cv, K_CLOSURE, "closure in call");
    int64_t fidx = OBJ_FIELDS(c)[0].u.i;
    if (fidx < 0 || (uint64_t)fidx >= p->nfuncs) vm_fatal(vm, "bad function index");
    Function *fn = &p->funcs[fidx];
    size_t top = vm->sp;
    if (top + fn->nlocals + fn->maxstack > vm->stack_cap) vm_grow_stack(vm, top + fn->nlocals + fn->maxstack);
    vm_push_frame(vm, (uint32_t)fidx, c, vm->pc, top);
    vm->frames[vm->fp].native_ret = after;
    Value *slot = &vm->stack[top];
    slot[0] = arg;
    for (uint32_t i = 1; i < fn->nlocals; i++) slot[i] = mk_unit();
    vm->sp = top + fn->nlocals;
    vm->pc = fn->code_offset;
    return jit_program(vm)->codes[fidx].entry;
}
/* TAILCALL f x: the frame replaced, its return kept */
const void *jit_h_tailcall(VM *vm, int32_t a, int32_t b) {
    Program *p = &vm->prog;
    Frame *fr = &vm->frames[vm->fp];
    Value arg = vm->stack[fr->base + (size_t)b];
    Value cv = vm->stack[fr->base + (size_t)a];
    Obj *c = vm_expect_obj(vm, cv, K_CLOSURE, "closure in call");
    int64_t fidx = OBJ_FIELDS(c)[0].u.i;
    if (fidx < 0 || (uint64_t)fidx >= p->nfuncs) vm_fatal(vm, "bad function index");
    Function *fn = &p->funcs[fidx];
    size_t top = fr->base;
    if (top + fn->nlocals + fn->maxstack > vm->stack_cap) vm_grow_stack(vm, top + fn->nlocals + fn->maxstack);
    fr->func = (uint32_t)fidx;
    fr->closure = c;
    Value *slot = &vm->stack[top];
    slot[0] = arg;
    for (uint32_t i = 1; i < fn->nlocals; i++) slot[i] = mk_unit();
    vm->sp = top + fn->nlocals;
    vm->pc = fn->code_offset;
    return jit_program(vm)->codes[fidx].entry;
}
/* PUSHHANDLER o, the handler's native code at native */
void jit_h_push_handler(VM *vm, int32_t pc, const void *native) {
    vm_push_handler(vm, (uint32_t)pc);
    vm->handlers[vm->hp - 1].native = native;
}
/* RAISE s: the handler's native code to go on at, or NULL for the
   interpreter; an uncaught exception ends the program in vm_raise */
const void *jit_h_raise(VM *vm, int32_t s) {
    Value v = vm->stack[vm->frames[vm->fp].base + (size_t)s];
    const void *native = handler_native(vm);
    vm_raise(vm, v);
    return native;
}
/* PRIMPUSH p args: the result left on the stack for RESULT; 0 when done,
   else what the driver is to do -- after a raise, or where the primitive
   has made the program another (Runtime.restore), which the interpreter
   takes up at its RESULT */
int64_t jit_h_string_order(VM *vm, const Obj *a, const Obj *b) {
    (void)vm;
    uint32_t n = a->len < b->len ? a->len : b->len;
    int c = n ? memcmp(OBJ_BYTES(a), OBJ_BYTES(b), n) : 0;
    if (c != 0) return c < 0 ? 0 : 2;
    if (a->len == b->len) return 1;
    return a->len < b->len ? 0 : 2;
}
int64_t jit_h_values_equal(VM *vm, const Value *x, const Value *y) { (void)vm; return values_equal(*x, *y); }

int jit_h_primpush(VM *vm, int prim, const uint8_t *L) {
    uint32_t n = prim_arity[prim];
    for (uint32_t i = 0; i < n; i++) {
        Value v = vm->stack[vm->frames[vm->fp].base + (size_t)read_i32(L + 4 * i)];
        vm_push(vm, v);
    }
    const void *native = handler_native(vm);
    int r = prim_table[prim](vm);
    if (r == 1) return after_raise(vm, native);
    if (r == PRIM_NEW_WORLD) return RUN_INTERP;
    return 0;
}

/* ---- the context ---- */

X64Label *jit_label(Jit *j, uint32_t pc) { return &j->labels[pc - j->from]; }

X64Label *jit_fatal(Jit *j, int what, int32_t a, int32_t b, int rcx_arg) {
    Slow *s = ms_slow(&j->m, SLOW_FATAL, j->next);
    if (!s) return NULL;
    s->a = what; s->b = a; s->c = b; s->d = rcx_arg;
    return &s->here;
}

X64Label *jit_alloc_slow(Jit *j, int kind, int contag, uint32_t n, int fill, int32_t d, int32_t a, int32_t b, const uint8_t *L) {
    Slow *s = ms_slow(&j->m, SLOW_ALLOC, j->next);
    if (!s) return NULL;
    s->a = kind; s->b = contag; s->n = n; s->c = fill; s->d = d; s->e = a; s->g = b; s->L = L;
    return &s->here;
}

void jit_fill(Jit *j, int kind, int fill, uint32_t n, int32_t d, int32_t a, int32_t b, const uint8_t *L) {
    Masm *m = &j->m;
    (void)kind;
    switch (fill) {
    case FILL_LIST:
        for (uint32_t i = 0; i < n; i++) ms_store_field(m, RAX, i, read_i32(L + 4 * i));
        break;
    case FILL_ONE:
        ms_store_field(m, RAX, 0, a);
        break;
    case FILL_CLOSURE:
        /* field 0 is the function's index, then the n - 1 it captures */
        x64_mov_mi(&m->a, RAX, (int32_t)sizeof(Obj), T_INT);
        x64_mov_mi(&m->a, RAX, (int32_t)sizeof(Obj) + 8, a);
        for (uint32_t i = 0; i + 1 < n; i++) ms_store_field(m, RAX, i + 1, read_i32(L + 4 * i));
        break;
    case FILL_NEWEXN:
        /* field 0 is the constant a, the name */
        x64_mov_rm(&m->a, RCX, VMR, (int32_t)offsetof(VM, prog.consts));
        x64_movups_xm(&m->a, XMM0, RCX, 16 * a);
        x64_movups_mx(&m->a, RAX, (int32_t)sizeof(Obj), XMM0);
        break;
    case FILL_MKEXN: {
        /* the constructor in a, which must be one, and the payload in b: the
           test after the allocation, as the interpreter's */
        X64Label *bad = jit_fatal(j, FATAL_MKEXN, 0, 0, 0);
        x64_cmp8_mi(&m->a, BASER, 16 * a, T_PTR);
        x64_jcc(&m->a, CC_NE, bad);
        x64_mov_rm(&m->a, RCX, BASER, 16 * a + 8);
        x64_cmp8_mi(&m->a, RCX, (int32_t)offsetof(Obj, kind), K_EXNCON);
        x64_jcc(&m->a, CC_NE, bad);
        ms_store_field(m, RAX, 0, a);
        ms_store_field(m, RAX, 1, b);
        break;
    }
    }
    ms_set_reg(m, d, T_PTR, RAX);
}

void jit_unsupported(Jit *j) { j->unsupported = 1; }

/* the slow paths, after the function's code; a copy of the record, since
   a fill may add a slow path of its own and move the array */
static void emit_slow(Masm *m, Slow *sp) {
    Jit *j = (Jit *)m;   /* the Masm is the first member */
    Slow s = *sp;
    if (s.kind == SLOW_FATAL) {
        /* rcx, a value the message wants, before anything uses it */
        if (s.d) x64_mov_rr(&m->a, ms_arg(m, 2), RCX);
        ms_sync(m, s.pc, 0);
        x64_mov_ri(&m->a, ms_arg(m, 1), s.a);
        if (!s.d) x64_mov_ri(&m->a, ms_arg(m, 2), s.b);
        x64_mov_ri(&m->a, ms_arg(m, 3), s.c);
        ms_call(m, (MsHelper)jit_h_fatal);
        x64_int3(&m->a);   /* it never returns */
    } else if (s.kind == SLOW_ALLOC) {
        ms_sync(m, s.pc, 0);
        x64_mov_ri(&m->a, ms_arg(m, 1), s.a);
        x64_mov_ri(&m->a, ms_arg(m, 2), s.b);
        x64_mov_ri(&m->a, ms_arg(m, 3), (int64_t)s.n);
        ms_call(m, (MsHelper)jit_h_alloc);
        ms_reload(m);
        m->nfields = s.n;   /* the helper made an object of s.n fields, in rax */
        uint32_t saved_next = j->next;
        j->next = s.pc;
        jit_fill(j, s.a, s.c, s.n, s.d, s.e, s.g, s.L);
        j->next = saved_next;
        x64_jmp(&m->a, &s.back);
    } else if (s.kind == SLOW_GROW) {
        /* room for n values above the frame's base: the stack grown, and
           the code's view of it taken again */
        ms_sync(m, s.pc, 0);
        x64_lea(&m->a, ms_arg(m, 1), BASEI, -1, 1, (int32_t)s.n);
        ms_call(m, (MsHelper)jit_h_grow);
        ms_reload(m);
        x64_jmp(&m->a, &s.back);
    } else if (s.kind == SLOW_GROW_RAX) {
        /* the need in rax; then the instruction (at s.d) over again, since
           the call clobbered what it had found */
        x64_mov_rr(&m->a, ms_arg(m, 1), RAX);   /* before the sync, which uses rax */
        ms_sync(m, s.pc, 0);
        ms_call(m, (MsHelper)jit_h_grow);
        ms_reload(m);
        x64_jmp(&m->a, &s.back);
    } else if (s.kind == SLOW_FRAMES) {
        ms_sync(m, s.pc, 0);
        ms_call(m, (MsHelper)jit_h_grow_frames);
        ms_reload(m);
        x64_jmp(&m->a, &s.back);
    } else if (s.kind == SLOW_PRIM) {
        /* a primitive done in line, in a case that is the helper's (M7):
           back where the code went on, or, after a raise, the VM handed
           back with what the driver is to do */
        ms_sync(m, s.pc, 0);
        x64_mov_ri(&m->a, ms_arg(m, 1), s.a);
        x64_mov_ri(&m->a, ms_arg(m, 2), s.b);
        x64_mov_ri(&m->a, ms_arg(m, 3), (int64_t)(intptr_t)s.L);
        ms_call(m, (MsHelper)jit_h_prim);
        ms_reload(m);
        x64_test_rr(&m->a, RAX, RAX);
        X64Label hand; x64_label_init(&hand);
        x64_jcc(&m->a, CC_NE, &hand);
        /* a comparison's bool back into the flags, as the fast path leaves
           it, for the branch fused onto it (s.c) */
        if (s.c) x64_cmp_mi(&m->a, BASER, 16 * s.b + 8, 0);
        x64_jmp(&m->a, &s.back);
        x64_bind(&m->a, &hand);
        x64_label_free(&hand);
        ms_handback_rax(m);
    } else {
        /* SLOW_RET: the frame of the top level returns through the helper */
        ms_sync(m, s.pc, 0);
        x64_mov_ri(&m->a, ms_arg(m, 1), s.a);
        ms_call(m, (MsHelper)jit_h_ret);
        ms_handback_rax(m);
    }
}

/* ---- the scan ---- */

/* the instructions tier 1 compiles: every one, since M5 */
static int supported(uint8_t op) { (void)op; return 1; }

/* the code of a function: each instruction's start, whether it begins a
   run (is a target, or follows an instruction that ends one) and how long
   its run is; 0 where an instruction is not supported. A SWITCH's table
   of JUMPs is data, never run, and not instructions here. */
typedef struct Scan {
    uint8_t *start;     /* 1 where an instruction begins */
    uint8_t *target;    /* 1 where a jump lands, or a call returns */
    uint8_t *ends;      /* 1 where the instruction ends a run */
    uint8_t *phantom;   /* 1 at a RESULT after a call: the callee's RET does it, and it is passed over (M5) */
} Scan;

static int scan(Jit *j, Scan *sc) {
    const uint8_t *code = j->vm->prog.code;
    uint32_t len = j->to - j->from;
    sc->start = calloc(len + 1, 1); sc->target = calloc(len + 1, 1); sc->ends = calloc(len + 1, 1);
    sc->phantom = calloc(len + 1, 1);
    if (!sc->start || !sc->target || !sc->ends || !sc->phantom) return 0;
    sc->target[0] = 1;
    uint32_t pc = j->from;
    while (pc < j->to) {
        uint8_t op = code[pc];
        if (!supported(op)) return 0;
        sc->start[pc - j->from] = 1;
        uint32_t l = rop_length(code + pc);
        if (rop_flow[op] != FLOW_NEXT || rop_raises[op]) sc->ends[pc - j->from] = 1;
        if ((op == ROP_CALL || op == ROP_CALLK) && pc + l < j->to && code[pc + l] == ROP_RESULT) {
            sc->phantom[pc + l - j->from] = 1;
            if (pc + l + 5 < j->to) sc->target[pc + l + 5 - j->from] = 1;
        }
        /* the RESULT after a PRIMPUSH: where an image resumes (M6) */
        if (op == ROP_PRIMPUSH && pc + l < j->to && code[pc + l] == ROP_RESULT) sc->target[pc + l - j->from] = 1;
        for (int k = 0; k < rop_nfixed[op]; k++)
            if (rop_kinds[op][k] == RK_LABEL || rop_kinds[op][k] == RK_HANDLER_LABEL)
                sc->target[(uint32_t)read_i32(code + pc + 1 + 4 * k) - j->from] = 1;
        if (op == ROP_SWITCH) {
            uint32_t n = (uint32_t)read_i32(code + pc + 5);
            uint32_t table = pc + l;
            for (uint32_t k = 0; k < n; k++) sc->target[(uint32_t)read_i32(code + table + 5 * k + 1) - j->from] = 1;
            sc->target[table + 5 * n - j->from] = 1;
            pc = table + 5 * n;
            continue;
        }
        pc += l;
    }
    return 1;
}

/* ---- the compiler ---- */

#if JIT_TARGET
static int emit_function(Jit *j, Scan *sc) {
    const uint8_t *code = j->vm->prog.code;
    Masm *m = &j->m;
    uint32_t pc = j->from;
    int in_run = 0;
    while (pc < j->to && !j->unsupported && !m->a.failed) {
        uint32_t at = pc - j->from;
        if (!sc->start[at]) { pc++; continue; }
        if (sc->phantom[at]) { pc += rop_length(code + pc); in_run = 0; continue; }
        if (sc->target[at]) { x64_bind(&m->a, &j->labels[at]); in_run = 0; }
        if (!in_run) {
            /* the run's length: to the next end, or the next target */
            uint32_t k = 0, q = pc;
            while (q < j->to) {
                uint32_t qa = q - j->from;
                if (sc->start[qa]) {
                    if (q != pc && (sc->target[qa] || sc->phantom[qa])) break;
                    k++;
                    if (sc->ends[qa]) break;
                }
                q++;
            }
            ms_count(m, k);
            in_run = 1;
        }
        uint8_t op = code[pc];
        uint32_t l = rop_length(code + pc);
        j->next = pc + l;
        /* the flags of a comparison hold to the next instruction, unless
           control can arrive there from elsewhere (M7) */
        j->flags_prev = sc->target[at] ? -1 : j->flags_for;
        j->flags_for = -1;
        switch (op) {
#include "jit_cases.h"
        default: j->unsupported = 1;
        }
        if (sc->ends[at]) in_run = 0;
        if (op == ROP_SWITCH) {
            uint32_t n = (uint32_t)read_i32(code + pc + 5);
            pc += l + 5 * n;
        } else pc += l;
    }
    return !j->unsupported && !m->a.failed;
}
#endif

int jit_region_init(VM *vm, JitProgram *jit) {
#if JIT_TARGET
    (void)vm;
    if (jit->code_mem) return 1;
    size_t cap = (size_t)64 << 20;
    uint8_t *mem = sys_code_alloc(cap);
    if (!mem) return 0;
    X64 a; x64_init(&a);
    size_t enter_at = 0;
    ms_emit_enter(&a, JIT_WIN);
    size_t leave_at = a.n;
    ms_emit_leave(&a, JIT_WIN);
    if (a.failed) { x64_free(&a); return 0; }
    memcpy(mem, a.buf, a.n);
    jit->code_mem = mem;
    jit->code_cap = cap;
    jit->code_used = (a.n + 15) & ~(size_t)15;
    jit->enter_at = mem + enter_at;
    jit->leave_at = mem + leave_at;
    x64_free(&a);
    if (!sys_code_protect(mem, cap, 1)) return 0;
    return 1;
#else
    (void)vm; (void)jit;
    return 0;
#endif
}

int jit_compile(VM *vm, JitProgram *jit, uint32_t f) {
#if JIT_TARGET
    if (!jit->code_mem && !jit_region_init(vm, jit)) return 0;
    Program *p = &vm->prog;
    Function *fn = &p->funcs[f];
    Jit j;
    memset(&j, 0, sizeof j);
    ms_init(&j.m, fn->nlocals, fn->maxstack, JIT_WIN, jit->leave_at);
    j.vm = vm; j.jit = jit; j.f = f;
    j.flags_for = j.flags_prev = -1;
    /* where the code will be placed: a known call jumps to its callee's
       code by a rel32 from there */
    j.m.a.base = (uintptr_t)(jit->code_mem + jit->code_used);
    j.from = fn->code_offset; j.to = fn->code_end;
    uint32_t len = j.to - j.from;
    j.labels = malloc(((size_t)len + 1) * sizeof(X64Label));
    Scan sc = { NULL, NULL, NULL, NULL };
    int ok = j.labels != NULL;
    if (ok) for (uint32_t i = 0; i <= len; i++) x64_label_init(&j.labels[i]);
    ok = ok && scan(&j, &sc) && emit_function(&j, &sc);
    if (ok) {
        ms_emit_slow_paths(&j.m, emit_slow);
        ok = !j.m.a.failed;
    }
    if (ok) {
        for (uint32_t i = 0; i <= len && ok; i++) if (j.labels[i].nrefs) ok = 0;   /* a jump to nowhere */
    }
    if (ok) {
        size_t size = (j.m.a.n + 15) & ~(size_t)15;
        if (jit->code_used + size > jit->code_cap) ok = 0;
        else {
            uint8_t *at = jit->code_mem + jit->code_used;
            /* the pages the code lands in alone are made writable and
               executable again: protecting the whole region, 64 MB, for
               each function was most of a compile on Windows */
            size_t page = sys_code_page();
            size_t lo = jit->code_used & ~(page - 1);
            size_t hi = (jit->code_used + size + page - 1) & ~(page - 1);
            if (!sys_code_protect(jit->code_mem + lo, hi - lo, 0)) ok = 0;
            else {
                memcpy(at, j.m.a.buf, j.m.a.n);
                sys_code_protect(jit->code_mem + lo, hi - lo, 1);
                sys_code_flush(at, j.m.a.n);
                jit->code_used += size;
                /* the table of pc to address: every target bound (M6) */
                uint32_t nosr = 0;
                for (uint32_t i = 0; i < len; i++) if (sc.target[i] && j.labels[i].at >= 0) nosr++;
                CodeObject *co = &jit->codes[f];
                free(co->osr_pcs); free(co->osr_offs);
                co->osr_pcs = malloc((nosr ? nosr : 1) * sizeof *co->osr_pcs);
                co->osr_offs = malloc((nosr ? nosr : 1) * sizeof *co->osr_offs);
                co->nosr = 0;
                if (co->osr_pcs && co->osr_offs)
                    for (uint32_t i = 0; i < len; i++)
                        if (sc.target[i] && j.labels[i].at >= 0) { co->osr_pcs[co->nosr] = j.from + i; co->osr_offs[co->nosr] = (uint32_t)j.labels[i].at; co->nosr++; }
                co->tier = 1;
                co->size = (uint32_t)j.m.a.n;
                co->entry = at;   /* published last */
                jit->compiled++;
            }
        }
    }
    if (j.labels) { for (uint32_t i = 0; i <= len; i++) x64_label_free(&j.labels[i]); free(j.labels); }
    free(sc.start); free(sc.target); free(sc.ends); free(sc.phantom);
    ms_free(&j.m);
    return ok;
#else
    (void)vm; (void)jit; (void)f;
    return 0;
#endif
}
