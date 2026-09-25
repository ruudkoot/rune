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
    "SWITCH on non-constructor", "FIELD of a constructor of tag %d where %d is wanted", "constructor field %d out of range"
};

void jit_h_fatal(VM *vm, int what, int32_t a, int32_t b) {
    vm_fatal(vm, fatal_text[what], (int)a, (int)b);
}

/* PRIM p d args: the common case in the loop's way (fastprim.h), or the
   primitive itself with its arguments pushed. 0 when done; else what the
   driver is to do, the machine unwound to a handler. */
int jit_h_prim(VM *vm, int prim, int32_t d, const uint8_t *L) {
    Value *base = vm->stack + vm->frames[vm->fp].base;
    uint32_t n = prim_arity[prim];
    if (prim_fast(prim, n, base, L, &base[d])) return 0;
    for (uint32_t i = 0; i < n; i++) {
        Value v = vm->stack[vm->frames[vm->fp].base + (size_t)read_i32(L + 4 * i)];
        vm_push(vm, v);
    }
    int r = prim_table[prim](vm);
    if (r == 1) return RUN_INTERP;
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
    } else {
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
    }
}

/* ---- the scan ---- */

/* the instructions tier 1 compiles (M4: those that neither call, return
   through the interpreter's frame, raise, nor touch a handler) */
static int supported(uint8_t op) {
    switch (op) {
    case ROP_CALL: case ROP_TAILCALL: case ROP_CALLK: case ROP_TAILCALLK: case ROP_RESULT:
    case ROP_PRIMPUSH: case ROP_PUSHHANDLER: case ROP_POPHANDLER: case ROP_CATCH: case ROP_RAISE:
        return 0;
    default:
        return 1;
    }
}

/* the code of a function: each instruction's start, whether it begins a
   run (is a target, or follows an instruction that ends one) and how long
   its run is; 0 where an instruction is not supported. A SWITCH's table
   of JUMPs is data, never run, and not instructions here. */
typedef struct Scan {
    uint8_t *start;     /* 1 where an instruction begins */
    uint8_t *target;    /* 1 where a jump lands */
    uint8_t *ends;      /* 1 where the instruction ends a run */
} Scan;

static int scan(Jit *j, Scan *sc) {
    const uint8_t *code = j->vm->prog.code;
    uint32_t len = j->to - j->from;
    sc->start = calloc(len + 1, 1); sc->target = calloc(len + 1, 1); sc->ends = calloc(len + 1, 1);
    if (!sc->start || !sc->target || !sc->ends) return 0;
    sc->target[0] = 1;
    uint32_t pc = j->from;
    while (pc < j->to) {
        uint8_t op = code[pc];
        if (!supported(op)) return 0;
        sc->start[pc - j->from] = 1;
        uint32_t l = rop_length(code + pc);
        if (rop_flow[op] != FLOW_NEXT || rop_raises[op]) sc->ends[pc - j->from] = 1;
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
        if (sc->target[at]) { x64_bind(&m->a, &j->labels[at]); in_run = 0; }
        if (!in_run) {
            /* the run's length: to the next end, or the next target */
            uint32_t k = 0, q = pc;
            while (q < j->to) {
                uint32_t qa = q - j->from;
                if (sc->start[qa]) {
                    if (q != pc && sc->target[qa]) break;
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
    j.from = fn->code_offset; j.to = fn->code_end;
    uint32_t len = j.to - j.from;
    j.labels = malloc(((size_t)len + 1) * sizeof(X64Label));
    Scan sc = { NULL, NULL, NULL };
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
            if (!sys_code_protect(jit->code_mem, jit->code_cap, 0)) ok = 0;
            else {
                memcpy(at, j.m.a.buf, j.m.a.n);
                sys_code_protect(jit->code_mem, jit->code_cap, 1);
                sys_code_flush(at, j.m.a.n);
                jit->code_used += size;
                jit->codes[f].tier = 1;
                jit->codes[f].size = (uint32_t)j.m.a.n;
                jit->codes[f].entry = at;   /* published last */
                jit->compiled++;
            }
        }
    }
    if (j.labels) { for (uint32_t i = 0; i <= len; i++) x64_label_free(&j.labels[i]); free(j.labels); }
    free(sc.start); free(sc.target); free(sc.ends);
    ms_free(&j.m);
    return ok;
#else
    (void)vm; (void)jit; (void)f;
    return 0;
#endif
}
