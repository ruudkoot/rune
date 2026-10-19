/* Tier 1 of runtime/register's JIT (compile.h). */
#include "compile.h"
#include "register/fastprim.h"
#include "sys/sys.h"
#include "register/jit_emit.h"
#include "register/live.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
    "a primitive that changes the world in PRIM",
    "--gc-verify/--gc-stress: the home of register %d is not what its slot holds"
};

void jit_h_fatal(VM *vm, int what, int32_t a, int32_t b) {
    vm_fatal(vm, fatal_text[what], (int)a, (int)b);
}
/* the fatal error numbered k (jit_fatal), from the stub, with the value
   rcx held: its message and its trace read the pc and the frames -- the
   stub told the VM the frame's base, and the record its function -- and
   the frames below are exact in the stack */
void jit_h_fatal_at(VM *vm, uint32_t k, int64_t value) {
    const JitFatalSite *f = &jit_program(vm)->fatals[k];
    vm->pc = f->pc;
    vm->func = f->func;   /* the stub told the VM the frame (native-frames.md, M4) */
    vm_fatal(vm, fatal_text[f->what], f->value ? (int)value : (int)f->a, (int)f->b);
}
/* a fatal error's record, its number; UINT32_MAX where there is no memory */
static uint32_t fatal_record(JitProgram *jit, uint32_t func, uint32_t pc, int32_t what, int32_t a, int32_t b, int value) {
    if (jit->nfatals == jit->fatals_cap) {
        uint32_t cap = jit->fatals_cap ? jit->fatals_cap * 2 : 1024;
        JitFatalSite *all = realloc(jit->fatals, (size_t)cap * sizeof *all);
        if (!all) return UINT32_MAX;
        jit->fatals = all;
        jit->fatals_cap = cap;
    }
    JitFatalSite *f = &jit->fatals[jit->nfatals];
    f->pc = pc; f->func = func; f->what = what; f->a = a; f->b = b; f->value = value;
    return jit->nfatals++;
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

void jit_landing_here(Jit *j, uint32_t pc) {
    if (j->nlands == j->lands_cap) {
        uint32_t cap = j->lands_cap ? 2 * j->lands_cap : 16;
        uint32_t *o = realloc(j->land_offs, cap * sizeof *o);
        if (!o) { j->m.a.failed = 1; return; }
        j->land_offs = o;
        uint32_t *q = realloc(j->land_pcs, cap * sizeof *q);
        if (!q) { j->m.a.failed = 1; return; }
        j->land_pcs = q;
        j->lands_cap = cap;
    }
    j->land_offs[j->nlands] = (uint32_t)j->m.a.n;
    j->land_pcs[j->nlands] = pc;
    j->nlands++;
}

void jit_pending(Jit *j, size_t off, uint32_t f, int call) {
    if (j->npending == j->pending_cap) {
        uint32_t cap = j->pending_cap ? 2 * j->pending_cap : 16;
        void *p = realloc(j->pending, cap * sizeof *j->pending);
        if (!p) { j->m.a.failed = 1; return; }
        j->pending = p;
        j->pending_cap = cap;
    }
    j->pending[j->npending].off = (uint32_t)off;
    j->pending[j->npending].f = f;
    j->pending[j->npending].call = call;
    j->npending++;
}
#if JIT_TARGET
/* function f has code: the known calls compiled while it had none made
   jumps into it -- or calls, under --jit-returns=call, into the entry of
   calls, where a jump pushed the return address first (M7) -- where their
   callers' code is the same (M6) */
static void patch_pending(JitProgram *jit, uint32_t f, int callret) {
    CodeObject *co = &jit->codes[f];
    const void *entry = callret ? (const void *)co->code : co->entry;
    size_t page = sys_code_page();
    for (uint32_t i = 0; i < co->npending; i++) {
        struct PendingCall *pc = &co->pending[i];
        if (jit->codes[pc->caller].code != pc->caller_entry) continue;   /* compiled again, or gone */
        uint8_t *lo = (uint8_t *)((uintptr_t)pc->site & ~(uintptr_t)(page - 1));
        size_t len = (uintptr_t)pc->site + 4 > (uintptr_t)lo + page ? 2 * page : page;
        if (!sys_code_protect(lo, len, 0)) continue;
        if (pc->call) as_patch_call(pc->site, entry);
        else as_patch_jmp(pc->site, entry);
        sys_code_protect(lo, len, 1);
        sys_code_flush(pc->site, 4);
        jit_depend(jit, f, pc->caller);
    }
    free(co->pending);
    co->pending = NULL;
    co->npending = co->pending_cap = 0;
}
#endif
Site *jit_site(Jit *j, int kind, uint32_t pc) {
    if (!j->sites || j->nsites >= j->sites_cap) return NULL;
    Site *s = &j->sites[j->nsites++];
    s->kind = (uint32_t)kind;
    s->pc = pc;
    s->f0 = s->f1 = UINT32_MAX;
    s->n0 = s->n1 = s->other = 0;
    return s;
}

int jit_h_prim(VM *vm, int prim, int32_t d, uint32_t at) {
    const uint8_t *L = vm->prog.code + at;
    JitProgram *jit = jit_program(vm);
    if (jit->prim_calls) jit->prim_calls[prim]++;
    Value *base = vm->stack + vm->fp;
    uint32_t n = prim_arity[prim];
    if (prim_fast(vm, prim, n, base, L, &base[d])) return 0;
    for (uint32_t i = 0; i < n; i++) {
        Value v = vm->stack[vm->fp + (size_t)read_i32(L + 4 * i)];
        vm_push(vm, v);
    }
    const void *native = vm->hp ? vm->handlers[vm->hp - 1].native : NULL;
    int r = prim_table[prim](vm);
    if (r == 1) { if (native) { jit_program(vm)->at = native; return RUN_NATIVE; } return RUN_INTERP; }
    if (r == PRIM_NEW_WORLD) vm_fatal(vm, "a primitive that changes the world in PRIM");
    Value v = vm_pop(vm);
    vm->stack[vm->fp + (size_t)d] = v;
    return 0;
}

/* SETENV c e v while the low-pause collector's cycle marks: the store,
   through the barrier (emit.c, emit_SETENV) */
void jit_h_setenv(VM *vm, int32_t c, int32_t e, int32_t v) {
    Value *base = vm->stack + vm->fp;
    obj_set_field(vm, val_ptr(base[c]), (uint32_t)e + 1, base[v]);
}

Obj *jit_h_alloc(VM *vm, int kind, int contag, uint32_t n) {
    return vm_alloc_fields(vm, (uint8_t)kind, (uint16_t)contag, n);
}

/* compiled code's RET into a caller that is not compiled code, through
   the return trampoline (VM.ret_tramp, M6), with the value and the frame
   that returns (VM.fp, the stub's): the frame popped as its header says
   -- the top level's too, which has no caller (native-frames.md, M4) --
   and on as the loop's RET goes on (src/isa/regs.sml): the watermark
   lowered to the caller, the value into the register of the caller's
   RESULT, or onto the stack; what the driver is to do next (the
   interpreter, which goes on in the caller's code where it has some,
   vm_loop) */
int jit_h_return(VM *vm, uint64_t value) {
    Value v = (Value)value;
    size_t b = vm->fp, head = b - REG_HEADER, cb;
    Value info = vm->stack[b - 3];   /* the return word is the interpreter's: the stub is where it goes */
    uint32_t back = reg_info_pc(info), cf = reg_info_func(info);
    switch (reg_info_kind(info)) {
    case REG_INFO_BOTTOM: vm->sp = b; vm->pc = back; vm_push(vm, v); return RUN_HALT;   /* the header stays whole, as the loop's RET leaves it */
    case REG_INFO_EXPLICIT: head--; cb = (size_t)val_imm(vm->stack[head]); break;
    default: cb = head - vm->prog.funcs[cf].nlocals; break;
    }
    vm->sp = head;
    vm->fp = cb;
    vm->func = cf;
    reg_frames_lower(vm, vm->fp);
    const uint8_t *code = vm->prog.code;
    if (code[back] == ROP_RESULT) {
        vm->stack[vm->fp + (size_t)read_i32(code + back + 1)] = v;
        vm->pc = back + 5;
    } else {
        vm_push(vm, v);
        vm->pc = back;
    }
    return RUN_INTERP;
}

/* a RET of the frame at the stack's watermark, through its barrier's
   stub (masm.h, ms_emit_barrier; native-frames.md, M5): the watermark
   lowered and the barrier moved to the caller, and where the frame's own
   return word goes */
const void *jit_h_barrier(VM *vm, const Value *regs) {
    if ((size_t)(regs - vm->stack) != vm->barrier_at) vm_fatal(vm, "a return through the barrier of another frame");
    Value w = reg_barrier_pass(vm);
    return (const void *)(uintptr_t)(w - JIT_RET_BIAS);
}

/* ---- the helpers of the calls, the handlers and PRIMPUSH (M5) ---- */

/* compiled code's call into a function that has no code, through the
   table of calls (JitProgram.call_interp, M6): the frame made, its header
   and registers (the stub told the VM its base and function); the
   interpreter to run it from its first instruction */
int jit_h_enter_interp(VM *vm) {
    const Function *fn = &vm->prog.funcs[vm->func];
    vm->pc = fn->code_offset;
    vm->sp = vm->fp + fn->nlocals;
    return RUN_INTERP;
}

/* room claimed in the stack's clean part to ROOM_SLACK values past at,
   the address in the stack as it is that a room check compared with
   VM.stack_room (M6; native-frames.md, M4) */
void jit_h_grow(VM *vm, const Value *at) {
    /* (at may be below the stack's start, by less than the slack: as numbers) */
    intptr_t k = (intptr_t)((uintptr_t)at - (uintptr_t)vm->stack) / (intptr_t)sizeof(Value) + ROOM_SLACK;
    vm_claim_stack(vm, k > 0 ? (size_t)k : 0);
}

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

/* PUSHHANDLER o, the handler's native code at native */
void jit_h_push_handler(VM *vm, int32_t pc, const void *native) {
    JitProgram *jit = jit_program(vm);
    if (jit->prim_calls) jit->pushes_c++;   /* --jit-stats */
    vm_push_handler(vm, (uint32_t)pc);
    vm->handlers[vm->hp - 1].native = native;
}
/* RAISE s: the handler's native code to go on at, or NULL for the
   interpreter; an uncaught exception ends the program in vm_raise */
const void *jit_h_raise(VM *vm, int32_t s) {
    JitProgram *jit = jit_program(vm);
    if (jit->prim_calls) jit->raises_c++;   /* --jit-stats */
    Value v = vm->stack[vm->fp + (size_t)s];
    const void *native = handler_native(vm);
    vm_raise(vm, v);
    return native;
}
/* what a poll found in the interrupt's flag (SLOW_INTERRUPT): JIT_LEAVE
   where the debugger wants the debug loop (runtime/debug.c), JIT_BACK
   where the mask holds the user's interrupt, else the interrupt raised as
   jit_h_raise raises */
const void *jit_h_interrupt(VM *vm) {
    if (vm_debug_leaves(vm)) return JIT_LEAVE;
    if (!vm_interrupted(vm)) return JIT_BACK;
    const void *native = handler_native(vm);
    vm_interrupt(vm);
    return native;
}
/* PRIMPUSH p args: the result left on the stack for RESULT; 0 when done,
   else what the driver is to do -- after a raise, or where the primitive
   has made the program another (Runtime.restore), which the interpreter
   takes up at its RESULT */
int64_t jit_h_string_order(VM *vm, const Obj *a, const Obj *b) {
    (void)vm;
    uint32_t n = obj_len(a) < obj_len(b) ? obj_len(a) : obj_len(b);
    int c = n ? memcmp(obj_bytes_c(a), obj_bytes_c(b), n) : 0;
    if (c != 0) return c < 0 ? 0 : 2;
    if (obj_len(a) == obj_len(b)) return 1;
    return obj_len(a) < obj_len(b) ? 0 : 2;
}
int64_t jit_h_values_equal(VM *vm, const Value *x, const Value *y) { return values_equal(vm, *x, *y); }
/* a real of tier 2 that has no immediate, boxed into its register's slot
   (masm.c, ms_emit_box_real): the allocation may collect, and the VM's
   stack pointer says what of the frame is there */
void jit_h_box_real(VM *vm, int32_t slot, uint64_t bits) {
    double d;
    memcpy(&d, &bits, sizeof d);
    size_t base = vm->fp;
    /* the box of the last write-back, where the register has not changed:
       a real that stays in its home across many safepoints is boxed once */
    Value old = vm->stack[base + (size_t)slot];
    if (val_is_ptr(old) && obj_kind(val_ptr(old)) == K_REAL && box_bits(old) == bits) return;
    Value v = mk_real(vm, d);
    vm->stack[base + (size_t)slot] = v;
}

/* the same for a number past 63 bits -- an Int64.int, a Word64.word, or
   under RUNE_INT64 an int or a word: its home holds the bits, its slot the
   box */
void jit_h_box_num(VM *vm, int32_t slot, uint64_t bits) {
    size_t base = vm->fp;
    Value old = vm->stack[base + (size_t)slot];
    if (val_is_ptr(old) && obj_kind(val_ptr(old)) == K_BOX && box_bits(old) == bits) return;
    Value v = mk_box_vm(vm, bits);
    vm->stack[base + (size_t)slot] = v;
}

int jit_h_primpush(VM *vm, int prim, uint32_t at) {
    const uint8_t *L = vm->prog.code + at;
    uint32_t n = prim_arity[prim];
    for (uint32_t i = 0; i < n; i++) {
        Value v = vm->stack[vm->fp + (size_t)read_i32(L + 4 * i)];
        vm_push(vm, v);
    }
    const void *native = handler_native(vm);
    int r = prim_table[prim](vm);
    if (r == 1) return after_raise(vm, native);
    if (r == PRIM_NEW_WORLD) return RUN_INTERP;
    return 0;
}

/* Whether tier 2's code takes its arguments in registers (native-frames.md,
   M6), and where: at its first instruction's label, past the entry's
   landing, the parameters live there in their homes -- each a home of
   words, its value's word as the slot would hold it -- or in their slots
   where they have none; a parameter it never reads is passed nowhere. Not
   where a parameter's home is raw (a real's, a number's 64 bits: its
   slot holds a word or a box the caller does not make), nor where the
   function reads at its entry a register no argument gives. */
static void param_homes(Jit *j) {
    j->nparams = 0;
    const Function *fn = &j->vm->prog.funcs[j->f];
    if (j->tier != 2 || !j->landings || !j->live_in || !fn->has_meta || fn->arity > 64 || fn->arity > fn->nlocals) return;
    uint64_t live = j->live_in[0];
    for (uint32_t r = fn->arity; r < fn->nlocals && r < 64; r++) if ((live >> r) & 1) return;
    for (uint32_t i = 0; i < fn->arity; i++) {
        if (!((live >> i) & 1)) { j->param_home[i] = REG_ARG_DEAD; continue; }
        const Home *h = ms_home(&j->m, (int32_t)i);
        if (!h) { j->param_home[i] = REG_ARG_SLOT; continue; }
        if (h->kind != HOME_GPR || !ms_word_home(&j->m, (int32_t)i)) return;
        j->param_home[i] = (int8_t)h->reg;
    }
    j->nparams = fn->arity;   /* (0 where it has none: no argument to give) */
}

/* ---- the context ---- */

/* the scan of a function (below): what the analysis of tier 2 walks */
typedef struct Scan {
    uint8_t *start;     /* 1 where an instruction begins */
    uint8_t *target;    /* 1 where a jump lands, or a call returns */
    uint8_t *ends;      /* 1 where the instruction ends a run */
    uint8_t *phantom;   /* 1 at a RESULT after a call: the callee's RET does it, and it is passed over (M5) */
} Scan;

AsmLabel *jit_label(Jit *j, uint32_t pc) { return &j->labels[pc - j->from]; }
AsmLabel *jit_landing(Jit *j, uint32_t pc) { return j->landings ? &j->landings[pc - j->from] : &j->labels[pc - j->from]; }

#if JIT_TARGET
/* ---- tier 2: what is live where, and the homes (M9) ---- */

/* What is live where is runtime/register/live.c's, which the collector asks
   too: live_in[at] is the registers live at the entry of the instruction at
   from + at. */
static int liveness(Jit *j, const Scan *sc) {
    j->live_in = reg_liveness(&j->vm->prog, j->from, j->to, sc->start, NULL);
    return j->live_in != NULL;
}

/* The homes: the registers of a representation a machine register can hold
   -- an int, a word, a char, a nullary constructor in one of the target's
   general homes (asm.h: registers the emitters never use as scratch while
   a home is live), a real in one of its homes for reals -- the most used
   first, a use inside a loop counting for eight, and one that is raw in
   its home (a number of 64 bits, which a slot holds encoded or boxed) for
   four more.

   A home is not free: where its register is live across a call of a
   function it is written to its slot before and loaded again after, a
   store and a load where each use saved one or the other -- and for a
   raw home an encoding and a decoding, some fifteen instructions where a
   use saved six or seven. So a register has a home only where its uses
   outweigh the calls it is live across, twice over for a word and six
   times for a raw one (HOME_CALL, HOME_CALL_RAW, in tenths of a use;
   measured: docs/plans/performance-64bit.md), a call in a loop counting
   for eight as a use does.

   Two registers have one home where they are never live together: each
   register is given the first home that none of those it interferes with
   has. They interfere where both are live at the entry of an instruction,
   and where one is defined by an instruction at whose entry the other is
   live (what is live at its exit and not at its entry is what it
   defines). So the register an instruction defines never has the home of
   one it reads, though that one may die there: an emitter may write the
   one before it has read the other, and the homes to load after a call
   into C in the middle of an instruction, those live at its entry and
   the one it defines, are all different (masm.c, ms_reload). */
enum { HOME_CALL = 20, HOME_CALL_RAW = 60 };
static int choose_homes(Jit *j) {
    const Program *p = &j->vm->prog;
    const Function *fn = &p->funcs[j->f];
    const uint8_t *code = p->code;
    uint32_t n = fn->nlocals;
    if (fn->has_meta && n > 64) j->jit->homes_too_large++;
    if (!fn->has_meta || n > 64) return 0;
    uint32_t *weight = calloc(n, sizeof *weight);
    uint32_t *calls = calloc(n, sizeof *calls);   /* the calls each is live across, weighted as the uses are */
    Home *homes = calloc(n, sizeof *homes);
    uint64_t *meets = calloc(n, sizeof *meets);   /* the registers each interferes with */
    /* each loop: from its head to the last jump back to it */
    uint32_t *last = calloc(fn->nloops ? fn->nloops : 1, sizeof *last);
    if (!weight || !calls || !homes || !meets || !last) { free(weight); free(calls); free(homes); free(meets); free(last); return 0; }
    for (uint32_t k = 0; k < fn->nloops; k++) last[k] = fn->loops[k];
    for (uint32_t q = j->from; q < j->to; ) {
        uint32_t l = rop_length(code + q);
        if (code[q] == ROP_JUMP)
            for (uint32_t k = 0; k < fn->nloops; k++)
                if ((uint32_t)read_i32(code + q + 1) == fn->loops[k]) last[k] = q;
        if (code[q] == ROP_SWITCH) l += 5 * (uint32_t)read_i32(code + q + 5);
        q += l;
    }
    for (uint32_t pc = j->from; pc < j->to; ) {
        uint8_t op = code[pc];
        uint32_t l = rop_length(code + pc);
        int in_loop = 0;
        for (uint32_t k = 0; k < fn->nloops; k++)
            if (pc >= fn->loops[k] && pc <= last[k]) in_loop = 1;
        uint64_t uses, def;
        reg_uses_defs(p, pc, &uses, &def);
        for (uint32_t r = 0; r < n; r++)
            if (((uses | def) >> r) & 1) weight[r] += in_loop ? 8 : 1;
        uint64_t in = j->live_in[pc - j->from];
        for (uint32_t r = 0; r < n; r++) {
            if ((in >> r) & 1) meets[r] |= in | def;
            if ((def >> r) & 1) meets[r] |= in;
        }
        if (rop_flow[op] == FLOW_CALL && pc + l < j->to) {
            uint64_t after = j->live_in[pc + l - j->from];   /* at the RESULT the call returns to */
            for (uint32_t r = 0; r < n; r++)
                if ((after >> r) & 1) calls[r] += in_loop ? 8 : 1;
        }
        if (op == ROP_SWITCH) l += 5 * (uint32_t)read_i32(code + pc + 5);
        pc += l;
    }
    free(last);
    int given = 0;
    uint64_t seen = 0;   /* the registers decided: a home, or none */
    uint8_t wants[64] = { 0 }, number[64] = { 0 };   /* the kind of home each decided register wants (HOME_SLOT: none), and its number */
    for (;;) {
        uint32_t best = UINT32_MAX;
        uint64_t best_weight = 0;
        for (uint32_t r = 0; r < n; r++) {
            if (((seen >> r) & 1) || weight[r] == 0) continue;
            int rep = fn->reps[r];
            int raw = rep == REP_INT64 || rep == REP_WORD64;   /* the 64-bit types: the 64 bits, raw (masm.c) */
            int gpr = raw || rep == REP_INT || rep == REP_WORD || rep == REP_CHAR || rep == REP_CON0
                      || rep == REP_PTR || rep == REP_CON || rep == REP_ANY;   /* a word of any kind (M7) */
            int xmm = MS_REAL_HOMES && rep == REP_REAL;   /* a real is a word in its slot until masm.h gives it a home */
            if (!gpr && !xmm) { seen |= (uint64_t)1 << r; continue; }
            if ((uint64_t)weight[r] * 10 <= (uint64_t)calls[r] * (raw || xmm ? HOME_CALL_RAW : HOME_CALL)) { seen |= (uint64_t)1 << r; continue; }
            uint64_t w = (uint64_t)weight[r] * (raw ? 4 : 1);
            if (best == UINT32_MAX || w > best_weight) { best = r; best_weight = w; }
        }
        if (best == UINT32_MAX) break;
        seen |= (uint64_t)1 << best;
        int rep = fn->reps[best];
        int kind = rep == REP_REAL ? HOME_XMM : HOME_GPR;
        int nhomes = kind == HOME_XMM ? AS_NHOMES_F : AS_NHOMES_G;
        /* The numbers of the homes of its kind that those it interferes
           with have. A register that gets none is numbered on all the
           same, past the homes there are (wants): the numbers below are
           given as they would be without it, and --jit-stats can say
           what any number of homes would hold. */
        uint64_t taken = 0;
        for (uint32_t r = 0; r < n; r++)
            if (r != best && ((meets[best] >> r) & 1) && wants[r] == kind) taken |= (uint64_t)1 << number[r];
        int k = 0;
        while (k < 63 && ((taken >> k) & 1)) k++;
        wants[best] = (uint8_t)kind;
        number[best] = (uint8_t)k;
        j->jit->homes_wanted[kind == HOME_XMM]++;
        j->jit->homes_weight[kind == HOME_XMM][k < 31 ? k : 31] += weight[best];
        if (k >= nhomes) continue;   /* none left where it is live: its slot */
        j->jit->homes_given[kind == HOME_XMM]++;
        homes[best].kind = (uint8_t)kind;
        homes[best].tag = (uint8_t)k;   /* the home's number, until every register has its own */
        given++;
    }
    for (uint32_t r = 0; r < n; r++) {
        if (homes[r].kind == HOME_SLOT) continue;
        int rep = fn->reps[r], k = homes[r].tag;
        if (homes[r].kind == HOME_XMM) { homes[r].reg = (uint8_t)as_home_f(JIT_WIN, k); homes[r].tag = T_REAL; }
        else {
            homes[r].reg = (uint8_t)as_home_g(JIT_WIN, k);
            homes[r].tag = (uint8_t)(rep == REP_INT ? T_INT : rep == REP_WORD ? T_WORD : rep == REP_CHAR ? T_CHAR
                                     : rep == REP_INT64 ? T_INT64 : rep == REP_WORD64 ? T_WORD64
                                     : rep == REP_CON0 ? T_CON0 : T_PTR);   /* T_PTR: any word, a pointer's too (masm.h) */
        }
    }
    free(weight); free(calls); free(meets);
    if (!given) { free(homes); return 0; }
    j->homes = homes;
    return 1;
}
/* the homes live at the entry of pc loaded from their slots */
static void land(Jit *j, uint32_t pc) {
    ms_reload_homes(&j->m, pc);
}
#endif

AsmLabel *jit_fatal(Jit *j, int what, int32_t a, int32_t b, int rcx_arg) {
    Slow *s = ms_slow(&j->m, SLOW_FATAL, j->next);
    if (!s) return NULL;
    s->a = what; s->b = a; s->c = b; s->d = rcx_arg;
    return &s->here;
}
#if JIT_TARGET
/* the masm's check of the homes under --gc-verify (ms_reload, M7) */
static AsmLabel *home_fails(Masm *m, uint32_t r) { return jit_fatal((Jit *)m, FATAL_HOME_SLOT, (int32_t)r, 0, 0); }
#endif

AsmLabel *jit_alloc_slow(Jit *j, int kind, int contag, uint32_t n, int fill, int32_t d, int32_t a, int32_t b, const uint8_t *L) {
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
        for (uint32_t i = 0; i < n; i++) ms_store_field(m, R_S0, i, read_i32(L + 4 * i));
        break;
    case FILL_ONE:
        ms_store_field(m, R_S0, 0, a);
        break;
    case FILL_CLOSURE:
        /* field 0 is the function's index, then the n - 1 it captures */
        ms_store_field_imm(m, R_S0, 0, T_INT, a);
        for (uint32_t i = 0; i + 1 < n; i++) ms_store_field(m, R_S0, i + 1, read_i32(L + 4 * i));
        break;
    case FILL_NEWEXN:
        /* field 0 is the constant a, the name */
        as_ld64(&m->a, R_S1, VMR, (int32_t)offsetof(VM, prog.consts));
        ms_field_from_nth(m, R_S0, 0, R_S1, (uint32_t)a);
        break;
    case FILL_MKEXN: {
        /* the constructor in a, which must be one, and the payload in b: the
           test after the allocation, as the interpreter's */
        AsmLabel *bad = jit_fatal(j, FATAL_MKEXN, 0, 0, 0);
        uint32_t nfields = m->nfields;
        ms_load_obj_tested(m, R_S1, a, K_EXNCON, bad);
        m->nfields = nfields;   /* the fresh object in rax is still the one being filled */
        ms_store_field(m, R_S0, 0, a);
        ms_store_field(m, R_S0, 1, b);
        break;
    }
    }
    ms_set_reg(m, d, T_PTR, R_S0);
}

void jit_unsupported(Jit *j) { j->unsupported = 1; }

/* the slow paths, after the function's code; a copy of the record, since
   a fill may add a slow path of its own and move the array */
/* an instruction begun: the masm told its pc and the register it defines */
static void begin(Jit *j, uint32_t pc) {
    uint64_t uses;
    ms_begin(&j->m, pc);
    reg_uses_defs(&j->vm->prog, pc, &uses, &j->m.cur_def);
}
/* The interrupt's flag set at a poll (jit_h_interrupt): back where the
   code goes on while the mask holds the user's interrupt; the instruction
   left to the debug loop, the VM exact at its start and its run's
   instructions from it uncounted, where the debugger wants that; else the
   interrupt raised from the instruction, the VM exact, as RAISE raises it,
   and on in the handler's code where it has some, else in the
   interpreter. A jump back polls so (SLOW_INTERRUPT), and a call at its
   room check's slow path (M6). */
static void emit_poll(Masm *m, const Slow *s, uint32_t uncounted) {
    ms_sync(m, s->pc, 0);
    ms_call(m, (MsHelper)jit_h_interrupt);
    AsmLabel other, leave, hand;
    as_label_init(&other); as_label_init(&leave); as_label_init(&hand);
    as_cmp_ri(&m->a, R_S0, (int32_t)(intptr_t)JIT_BACK);
    as_jcc(&m->a, CC_NE, &other);
    ms_reload(m);
    as_jmp(&m->a, (AsmLabel *)&s->back);
    as_bind(&m->a, &other);
    as_cmp_ri(&m->a, R_S0, (int32_t)(intptr_t)JIT_LEAVE);
    as_jcc(&m->a, CC_E, &leave);
    ms_reload(m);
    as_test_rr(&m->a, R_S0, R_S0);
    as_jcc(&m->a, CC_E, &hand);
    as_ld64(&m->a, COUNTR, VMR, (int32_t)offsetof(VM, instructions));   /* the count the sync gave (D9 B) */
    as_jmp_r(&m->a, R_S0);
    as_bind(&m->a, &hand);
    ms_handback(m, RUN_INTERP);
    as_bind(&m->a, &leave);
    as_st32i(&m->a, VMR, (int32_t)offsetof(VM, pc), (int32_t)s->cur);
    as_lea(&m->a, R_S1, COUNTR, -1, 1, -(int32_t)uncounted);
    as_st64(&m->a, VMR, (int32_t)offsetof(VM, instructions), R_S1);
    ms_handback(m, RUN_INTERP);
    as_label_free(&other); as_label_free(&leave); as_label_free(&hand);
}
static void emit_slow(Masm *m, Slow *sp) {
    Jit *j = (Jit *)m;   /* the Masm is the first member */
    Slow s = *sp;
    begin(j, s.cur);
    if (s.kind == SLOW_BOXREAL || s.kind == SLOW_BOXNUM) {
        ms_emit_box(m, sp);
    } else if (s.kind == SLOW_FATAL) {
        /* An error a typed program cannot make, in ten bytes: the number
           of its record in rax, and on to the stub of the region, which
           tells jit_h_fatal_at. Its message and trace read the pc, which
           the record has, and the frames, which are exact: nothing is
           written back. (Each wrote every live home back and called
           C itself: a fifth of the compiler's code compiled, measured in
           docs/plans/performance-64bit.md.) rcx, a value the message may
           want, is where the check left it. */
        uint32_t k = fatal_record(j->jit, j->f, s.pc, s.a, s.b, s.c, s.d);
        if (k == UINT32_MAX) { m->a.failed = 1; return; }
        as_mov_ri(&m->a, R_S0, k);
        as_jmp_to(&m->a, j->jit->fatal_at);
    } else if (s.kind == SLOW_ALLOC) {
        ms_alloc_undo(m, s.a, s.n);   /* the bump the fast path made (M8) */
        ms_sync(m, s.pc, 0);
        as_mov_ri(&m->a, ms_arg(m, 1), s.a);
        as_mov_ri(&m->a, ms_arg(m, 2), s.b);
        as_mov_ri(&m->a, ms_arg(m, 3), (int64_t)s.n);
        ms_call(m, (MsHelper)jit_h_alloc);
        ms_reload(m);
        m->nfields = s.n;   /* the helper made an object of s.n fields, in rax */
        uint32_t saved_next = j->next;
        j->next = s.pc;
        jit_fill(j, s.a, s.c, s.n, s.d, s.e, s.g, s.L);
        j->next = saved_next;
        as_jmp(&m->a, &s.back);
    } else if (s.kind == SLOW_GROW || s.kind == SLOW_GROW_RAX) {
        /* room for n values above the frame's base (in rax: then the
           instruction over again, since the call clobbered what it had
           found), claimed in the stack's clean part (VM.stack_clean, M6),
           and the code's view of the stack taken again; then the poll of
           the call, which the clean part is too (vm.h): the interrupt's
           flag looked at */
        if (s.kind == SLOW_GROW_RAX) as_mov_rr(&m->a, R_S6, R_S0);   /* kept across the sync, which uses rax and writes the homes back (an argument's register may be one) */
        ms_sync(m, s.pc, 0);
        if (s.kind == SLOW_GROW_RAX) as_mov_rr(&m->a, ms_arg(m, 1), R_S6);
        else ms_room_compared(m, ms_arg(m, 1), s.n);
        ms_call(m, (MsHelper)jit_h_grow);
        ms_reload(m);
        as_cmp32_mi(&m->a, VMR, (int32_t)offsetof(VM, interrupt), 0);
        as_jcc(&m->a, CC_E, &s.back);
        emit_poll(m, &s, (uint32_t)s.d);
    } else if (s.kind == SLOW_TAKEN) {
        /* the way taken of a branch counted (--jit-profile), then on to
           its target */
        as_mov_ri(&m->a, R_S6, (int64_t)(intptr_t)((const char *)s.L + offsetof(Site, n0)));
        as_add_mi(&m->a, R_S6, 0, 1);
        as_jmp(&m->a, jit_label(j, (uint32_t)s.a));
    } else if (s.kind == SLOW_SETENV) {
        /* the store in C, through the barrier, while a cycle marks; then on */
        ms_sync(m, s.pc, 0);
        as_mov_ri(&m->a, ms_arg(m, 1), s.a);
        as_mov_ri(&m->a, ms_arg(m, 2), s.b);
        as_mov_ri(&m->a, ms_arg(m, 3), s.c);
        ms_call(m, (MsHelper)jit_h_setenv);
        ms_reload(m);
        as_jmp(&m->a, &s.back);
    } else if (s.kind == SLOW_CALL_TABLE) {
        /* a known call to function s.a, which had no code when this was
           compiled, through the table of calls (M6) -- until it has some,
           when the jump here becomes a jump there (patch_pending) */
        as_ld64(&m->a, R_S0, VMR, (int32_t)offsetof(VM, jit_calls));
        as_ld64(&m->a, R_S0, R_S0, (int32_t)((size_t)s.a * sizeof(CallInfo) + offsetof(CallInfo, entry)));
        as_mov_ri(&m->a, R_S6, 2 * (int64_t)s.a + 1);   /* the callee's word, for the stub of the interpreter (ms_emit_call_interp) */
        as_jmp_r(&m->a, R_S0);

    } else if (s.kind == SLOW_INTERRUPT) {
        emit_poll(m, &s, s.n);
    } else if (s.kind == SLOW_DEOPT) {
        /* --deopt-stress: the Nth boundary reached (r11 is the counter's
           address): the count begun again, the exit counted, and out
           to the interpreter at s.pc, s.n instructions of the run left */
        as_st64i(&m->a, R_S6, 0, 0);
        as_mov_ri(&m->a, R_S6, (int64_t)(intptr_t)&j->jit->deopts);
        as_add_mi(&m->a, R_S6, 0, 1);
        ms_exit(m, s.pc, s.n);
    } else if (s.kind == SLOW_PRIM) {
        /* a primitive done in line, in a case that is the helper's (M7):
           back where the code went on, or, after a raise, the VM handed
           back with what the driver is to do */
        ms_sync(m, s.pc, 0);
        as_mov_ri(&m->a, ms_arg(m, 1), s.a);
        as_mov_ri(&m->a, ms_arg(m, 2), s.b);
        as_mov_ri(&m->a, ms_arg(m, 3), (int64_t)((const uint8_t *)s.L - j->vm->prog.code));
        ms_call(m, (MsHelper)jit_h_prim);
        ms_reload(m);
        as_test_rr(&m->a, R_S0, R_S0);
        AsmLabel hand; as_label_init(&hand);
        as_jcc(&m->a, CC_NE, &hand);
        /* a comparison's bool back into the flags, as the fast path leaves
           it, for the branch fused onto it (s.c) */
        if (s.c) ms_test_false(m, s.b);
        as_jmp(&m->a, &s.back);
        as_bind(&m->a, &hand);
        as_label_free(&hand);
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
        /* a run ends where control goes elsewhere, not where it may (a
           raise): a sync in its middle tells the VM the count less the
           rest of the run (Masm.ahead; performance M6, D9 B) */
        if (rop_flow[op] != FLOW_NEXT) sc->ends[pc - j->from] = 1;
        if ((op == ROP_CALL || op == ROP_CALLK) && pc + l < j->to && code[pc + l] == ROP_RESULT) {
            sc->phantom[pc + l - j->from] = 1;
            if (pc + l + 5 < j->to) sc->target[pc + l + 5 - j->from] = 1;
        }
        /* the RESULT after a PRIMPUSH: where an image resumes (M6) */
        if (op == ROP_PRIMPUSH && pc + l < j->to && code[pc + l] == ROP_RESULT) sc->target[pc + l - j->from] = 1;
        /* the sites of the profile (M8) */
        if (op == ROP_CALL || op == ROP_TAILCALL || op == ROP_JUMPIF || op == ROP_JUMPIFNOT
            || (op == ROP_JUMP && (uint32_t)read_i32(code + pc + 1) <= pc)) j->sites_cap++;
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
    uint32_t run_left = 0;   /* the instructions of the run after this one, for an exit (M11) */
    while (pc < j->to && !j->unsupported && !m->a.failed) {
        uint32_t at = pc - j->from;
        if (!sc->start[at]) { pc++; continue; }
        if (sc->phantom[at]) { pc += rop_length(code + pc); in_run = 0; continue; }
        if (sc->target[at]) { as_bind(&m->a, &j->labels[at]); in_run = 0; }
        ms_mark_pc(m, pc);
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
            run_left = k;
        }
        if (run_left) run_left--;
        uint8_t op = code[pc];
        uint32_t l = rop_length(code + pc);
        j->next = pc + l;
        begin(j, pc);
        /* the flags of a comparison hold to the next instruction, unless
           control can arrive there from elsewhere (M7) */
        j->flags_prev = sc->target[at] ? -1 : j->flags_for;
        j->cc_prev = j->cc_for;
        j->flags_for = -1;
        j->cc_for = -1;
        /* a poll (D11), as the interpreter's POLL: at a jump back, before
           it does anything, a test of the user's interrupt, which a slow
           path raises (SLOW_INTERRUPT); no branch here takes the flags of
           a comparison. A call polls at its room check (M6: the stack's
           clean part, which an interrupt makes 0; emit.c, room) */
        m->ahead = run_left;   /* the run after this instruction, counted already (D9 B) */
        if (op == ROP_JUMP && (uint32_t)read_i32(code + pc + 1) <= pc) {
            Slow *s = ms_slow(m, SLOW_INTERRUPT, j->next);
            if (s) {
                s->n = run_left + 1;   /* this instruction and the rest of its run, for a leave */
                ms_role(m, MR_POLL);
                as_cmp32_mi(&m->a, VMR, (int32_t)offsetof(VM, interrupt), 0);
                as_jcc(&m->a, CC_NE, &s->here);
                as_bind(&m->a, &s->back);
                ms_role(m, MR_BODY);
            }
        }
        switch (op) {
#include "register/jit_cases.h"
        default: j->unsupported = 1;
        }
        if (sc->ends[at]) in_run = 0;
        /* --deopt-stress=N (M11): after an instruction whose effects are
           complete and whose successor is the next (not a branch, a call,
           a return, a raise, nor a PRIMPUSH, whose RESULT is the
           interpreter's to take from the stack), and not between a
           comparison and the branch fused onto it (the flags), the
           Nth boundary leaves for the interpreter */
        if (j->jit->deopt_stress && !j->unsupported && rop_flow[op] == FLOW_NEXT && op != ROP_PRIMPUSH && j->flags_for < 0) {
            Slow *s = ms_slow(m, SLOW_DEOPT, j->next);
            if (s) {
                s->n = run_left;
                as_mov_ri(&m->a, R_S6, (int64_t)(intptr_t)&j->jit->deopt_count);
                as_add_mi(&m->a, R_S6, 0, 1);
                as_cmp_mi(&m->a, R_S6, 0, (int32_t)j->jit->deopt_stress);
                as_jcc(&m->a, CC_AE, &s->here);
            }
        }
        if (op == ROP_SWITCH) {
            uint32_t n = (uint32_t)read_i32(code + pc + 5);
            pc += l + 5 * n;
        } else pc += l;
    }
    return !j->unsupported && !m->a.failed;
}
#endif

/* The helpers compiled code calls besides the primitives: each has a
   trampoline (jit_region_init). One that is not here is called the long
   way (ms_call). */
static const MsHelper helpers[] = {
    (MsHelper)jit_h_prim, (MsHelper)jit_h_alloc, (MsHelper)jit_h_return, (MsHelper)jit_h_grow,
    (MsHelper)jit_h_push_handler, (MsHelper)jit_h_raise, (MsHelper)jit_h_string_order, (MsHelper)jit_h_values_equal,
    (MsHelper)jit_h_box_real, (MsHelper)jit_h_box_num, (MsHelper)jit_h_primpush, (MsHelper)jit_h_called, (MsHelper)jit_h_enter_interp
};
/* The region: the stubs that enter and leave compiled code, the stub of
   its fatal errors, and a trampoline for every call into C it makes
   (as_trampoline), all at its start, where a function anywhere in its
   64 MB reaches them by a direct jump or call; then the functions. */
int jit_region_init(VM *vm, JitProgram *jit) {
#if JIT_TARGET
    if (jit->code_mem) return 1;
    size_t cap = (size_t)64 << 20;
    uint8_t *mem = sys_code_alloc(cap);
    if (!mem) return 0;
    Asm a; as_init(&a);
    size_t enter_at = 0;
    ms_emit_enter(&a, JIT_WIN);
    size_t leave_at = a.n;
    AsmLabel leave; as_label_init(&leave);
    as_bind(&a, &leave);
    ms_emit_leave(&a, JIT_WIN);
    size_t fatal_at = a.n;
    ms_emit_fatal(&a, JIT_WIN, (MsHelper)jit_h_fatal_at);
    as_ret_align(&a);   /* a return word (native-frames.md, M4) */
    size_t ret_at = a.n;
    ms_emit_ret_tramp(&a, JIT_WIN, (MsHelper)jit_h_return, &leave);
    size_t call_interp_at = a.n;
    ms_emit_call_interp(&a, JIT_WIN, (MsHelper)jit_h_enter_interp, &leave, JIT_CALLS_RET(vm));
    as_label_free(&leave);
    as_ret_align(&a);   /* a return word too (native-frames.md, M5) */
    size_t barrier_at = a.n;
    ms_emit_barrier(&a, JIT_WIN, (MsHelper)jit_h_barrier);
    /* every primitive's C, the helpers, and the C library's functions
       that primitives on reals are (jit_libm_of) */
    uint32_t nhelpers = (uint32_t)(sizeof helpers / sizeof helpers[0]), n = 2 * PRIM__COUNT + nhelpers, size = 16;
    while (size < 2 * n) size *= 2;
    uint64_t *from = calloc(size, sizeof *from);
    const void **to = calloc(size, sizeof *to);
    if (!from || !to) a.failed = 1;
    for (uint32_t k = 0; k < n && !a.failed; k++) {
        MsHelper h = k < PRIM__COUNT ? (MsHelper)prim_table[k]
                   : k < 2 * PRIM__COUNT ? jit_libm_of((int32_t)(k - PRIM__COUNT))
                   : helpers[k - 2 * PRIM__COUNT];
        uint64_t at;
        memcpy(&at, &h, sizeof at);
        if (!at) continue;   /* (0 marks a free entry) */
        uint32_t i = ms_tramp_slot(at, size - 1);
        while (from[i] && from[i] != at) i = (i + 1) & (size - 1);
        if (from[i]) continue;   /* one function for two primitives */
        from[i] = at;
        to[i] = mem + as_trampoline(&a, JIT_WIN, at);
    }
    if (a.failed || a.n > cap) { as_free(&a); free(from); free(to); return 0; }
    memcpy(mem, a.buf, a.n);
    jit->code_mem = mem;
    jit->code_cap = cap;
    jit->code_used = (a.n + 15) & ~(size_t)15;
    jit->enter_at = mem + enter_at;
    jit->leave_at = mem + leave_at;
    jit->fatal_at = mem + fatal_at;
    /* compiled code's RET goes where a frame's return word says, which for
       a frame not pushed by compiled code -- every one there is so far --
       is here (M6; native-frames.md, M4) */
    vm->ret_tramp = jit->ret_tramp = mem + ret_at;
    vm->ret_word = (Value)(uintptr_t)vm->ret_tramp + JIT_RET_BIAS;
    if (vm->frames_active) reg_frames_ret_word(vm);
    /* and the stack's watermark is kept by the barrier from here on (M5) */
    jit->barrier = mem + barrier_at;
    vm->barrier_stub = (Value)(uintptr_t)jit->barrier + JIT_RET_BIAS;
    reg_barrier_arm(vm);
    /* and a call to a function with no code goes here (M6) */
    jit->call_interp = mem + call_interp_at;
    for (uint32_t i = 0; jit->calls && i < jit->nfuncs; i++)
        if (!jit->calls[i].entry) jit->calls[i].entry = jit->call_interp;
    jit->tramp_from = from;
    jit->tramp_to = to;
    jit->tramp_mask = size - 1;
    as_free(&a);
    if (!sys_code_protect(mem, cap, 1)) return 0;
    return 1;
#else
    (void)vm; (void)jit;
    return 0;
#endif
}

int jit_compile(VM *vm, JitProgram *jit, uint32_t f) { return jit_compile_tier(vm, jit, f, 1); }

int jit_compile_tier(VM *vm, JitProgram *jit, uint32_t f, int tier) {
#if JIT_TARGET
    if (!jit->code_mem && !jit_region_init(vm, jit)) return 0;
    Program *p = &vm->prog;
    Function *fn = &p->funcs[f];
    Jit j;
    memset(&j, 0, sizeof j);
    ms_init(&j.m, fn->nlocals, fn->maxstack, JIT_WIN, jit->leave_at);
    j.m.func = f;
    j.m.alloc_reg = 1;   /* the allocation pointer in a register (native-frames.md, M8) */
    j.m.verify = vm->gc_verify || vm->gc_stress;   /* the homes checked against their slots (ms_reload, M7) */
    j.m.home_fails = home_fails;
    MsMarks marks = { NULL, 0, 0 };
    if (vm->jit.dump) j.m.marks = &marks;   /* the roles of the code, for --jit-dump (performance M1) */
#ifdef RUNE_JIT_CONV
    j.m.conv_code = vm->prog.code;
    j.m.conv_prim_op = ROP_PRIM;
#endif
    j.m.box_num = (MsHelper)jit_h_box_num;   /* at either tier: a result past 63 bits on its way to a slot */
    j.vm = vm; j.jit = jit; j.f = f;
    j.flags_for = j.flags_prev = -1;
    j.cc_for = j.cc_prev = -1;
    j.tier = tier;
    j.callret = JIT_CALLS_RET(vm);
    as_label_init(&j.call_entry);
    as_label_init(&j.reg_call_entry);
    /* where the code will be placed: a known call jumps to its callee's
       code by a rel32 from there */
    j.m.a.base = (uintptr_t)(jit->code_mem + jit->code_used);
    j.m.placed = 1;
    j.m.tramp_from = jit->tramp_from;
    j.m.tramp_to = jit->tramp_to;
    j.m.tramp_mask = jit->tramp_mask;
    j.from = fn->code_offset; j.to = fn->code_end;
    uint32_t len = j.to - j.from;
    j.labels = malloc(((size_t)len + 1) * sizeof(AsmLabel));
    Scan sc = { NULL, NULL, NULL, NULL };
    int ok = j.labels != NULL;
    if (ok) for (uint32_t i = 0; i <= len; i++) as_label_init(&j.labels[i]);
    ok = ok && scan(&j, &sc);
    j.target = sc.target;
    if (ok && vm->jit.profile && j.sites_cap) {
        j.sites = calloc(j.sites_cap, sizeof(Site));
        if (!j.sites) ok = 0;
    }
    /* the entry: no unit into the registers (M6). A caller claims the
       callee's frame in the stack's clean part (VM.stack_clean), whose
       slots hold unit or values written since the last collection, roots
       as they are; one without an arity in the section has its callers
       fill for it (M10) */
    as_label_init(&j.entry);
    /* Under --jit-returns=call (native-frames.md, M7) the code begins with
       a call's entry: the parameters' homes loaded from their slots, then
       -- where a call with its arguments in registers comes in (M6) -- the
       return address stored as the frame's return word, and on at the
       first instruction; the driver's entry, which has no return address
       to store, loads the homes after the code and jumps there. */
    as_bind(&j.m.a, j.callret ? &j.call_entry : &j.entry);
    /* tier 2: the representations trusted for the shapes of values (M10),
       and the homes, where the function has registers a machine register
       can hold */
    if (ok && tier == 2) {
        if (!fn->has_meta) j.tier = 1;
        else j.m.reps = fn->reps;
        if (fn->has_meta && liveness(&j, &sc) && choose_homes(&j)) {
            j.landings = malloc(((size_t)len + 1) * sizeof(AsmLabel));
            if (!j.landings) ok = 0;
            else {
                for (uint32_t i = 0; i <= len; i++) as_label_init(&j.landings[i]);
                j.m.homes = j.homes;
                for (uint32_t i = 0; i < len; i++)
                    if (sc.start[i] && p->code[j.from + i] == ROP_PUSHHANDLER) j.m.has_handlers = 1;
                j.m.box_real = (MsHelper)jit_h_box_real;
                j.m.live = j.live_in;
                j.m.from = j.from;
                /* the entry: the parameters' homes loaded */
                if (!j.callret) as_bind(&j.m.a, &j.landings[0]);
                ms_role(&j.m, MR_LAND);
                land(&j, j.from);
                ms_role(&j.m, MR_BODY);
                /* the register entry (M6): the first instruction's label, past
                   the loads (under --jit-returns=call, past the store of the
                   return address after them) */
                param_homes(&j);
            }
        } else { free(j.live_in); j.live_in = NULL; }
    }
    if (j.callret) {
        as_bind(&j.m.a, &j.reg_call_entry);
        ms_role(&j.m, MR_FRAME);
        as_pop_ret(&j.m.a, BASER, -(int32_t)sizeof(Value));
        ms_role(&j.m, MR_BODY);
        if (!j.landings) as_bind(&j.m.a, &j.entry);   /* nothing to load: the driver's entry is here */
    }
    /* at both tiers: what is live at each instruction, for a collection
       that comes while the frame runs (VM.top_live, M6) */
    uint64_t *sync_live = j.live_in;
    if (ok && !sync_live) sync_live = reg_liveness(&j.vm->prog, j.from, j.to, sc.start, NULL);
    j.m.sync_live = sync_live;
    j.m.from = j.from;
    ok = ok && emit_function(&j, &sc);
    if (ok) {
        ms_emit_slow_paths(&j.m, emit_slow);
        ok = !j.m.a.failed;
    }
    /* tier 2: the landings of the other targets, after the code: the
       homes live there loaded, then on to the instruction */
    j.m.ahead = 0;
    if (ok && j.landings) {
        for (uint32_t i = 1; i < len; i++)
            if (sc.target[i] && j.labels[i].at >= 0) {
                as_bind(&j.m.a, &j.landings[i]);
                ms_begin(&j.m, j.from + i);
                ms_role(&j.m, MR_LAND);
                ms_mark_pc(&j.m, j.from + i);
                land(&j, j.from + i);
                as_jmp(&j.m.a, &j.labels[i]);
            }
        ok = !j.m.a.failed;
    }
    /* under --jit-returns=call, the driver's entry where there are homes
       to load (M7): the entry's landing, which jit_osr gives for the first
       instruction too */
    if (ok && j.callret && j.landings) {
        as_bind(&j.m.a, &j.entry);
        as_bind(&j.m.a, &j.landings[0]);
        ms_begin(&j.m, j.from);
        ms_role(&j.m, MR_LAND);
        ms_mark_pc(&j.m, j.from);
        land(&j, j.from);
        as_jmp(&j.m.a, &j.labels[0]);
        ok = !j.m.a.failed;
    }
    if (ok) {
        for (uint32_t i = 0; i <= len && ok; i++) if (as_dangling(&j.labels[i])) ok = 0;   /* a jump to nowhere */
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
                /* tier 2 is entered at its landings, which load the homes */
                if (co->osr_pcs && co->osr_offs)
                    for (uint32_t i = 0; i < len; i++)
                        if (sc.target[i] && j.labels[i].at >= 0) {
                            AsmLabel *l = j.landings ? &j.landings[i] : &j.labels[i];
                            co->osr_pcs[co->nosr] = j.from + i; co->osr_offs[co->nosr] = (uint32_t)l->at; co->nosr++;
                        }
                free(co->sites);
                co->sites = j.sites; co->nsites = j.nsites;
                j.sites = NULL;
                free(co->land_offs); free(co->land_pcs);
                co->land_offs = j.land_offs; co->land_pcs = j.land_pcs; co->nlands = j.nlands;
                j.land_offs = j.land_pcs = NULL;
                /* its arguments in registers (M6) */
                free(co->param_home);
                co->param_home = NULL;
                co->nparams = 0;
                co->reg_entry = -1;
                if (j.nparams && j.labels[0].at >= 0 && (co->param_home = malloc(j.nparams))) {
                    memcpy(co->param_home, j.param_home, j.nparams);
                    co->nparams = j.nparams;
                    co->reg_entry = (int32_t)j.labels[0].at;
                    co->reg_call = j.callret ? (int32_t)j.reg_call_entry.at : co->reg_entry;
                }
                jit_code_placed(jit, f, at, j.m.a.n);
                co->tier = (uint32_t)j.tier;
                co->size = (uint32_t)j.m.a.n;
                co->code = at;
                co->entry = at + j.entry.at;   /* published last */
                jit->calls[f].entry = at;   /* where calls go (M6): the code's start, a call's entry under --jit-returns=call (M7) */
                /* this code's known calls to functions with no code, to be
                   patched when each is compiled; and those to this one */
                for (uint32_t i = 0; i < j.npending; i++) {
                    CodeObject *callee = &jit->codes[j.pending[i].f];
                    if (callee->npending == callee->pending_cap) {
                        uint32_t cap = callee->pending_cap ? 2 * callee->pending_cap : 4;
                        struct PendingCall *pcs = realloc(callee->pending, cap * sizeof *pcs);
                        if (!pcs) break;   /* not patched: the call keeps going through the table */
                        callee->pending = pcs;
                        callee->pending_cap = cap;
                    }
                    callee->pending[callee->npending].site = at + j.pending[i].off;
                    callee->pending[callee->npending].caller = f;
                    callee->pending[callee->npending].caller_entry = at;
                    callee->pending[callee->npending].call = j.pending[i].call;
                    callee->npending++;
                }
                if (co->npending) patch_pending(jit, f, j.callret);
                jit->compiled++;
                if (j.tier == 2) jit->compiled_opt++;
                if (j.m.marks) jit_dump_function(&j, at);
            }
        }
    }
    if (j.labels) { for (uint32_t i = 0; i <= len; i++) as_label_free(&j.labels[i]); free(j.labels); }
    if (j.landings) { for (uint32_t i = 0; i <= len; i++) as_label_free(&j.landings[i]); free(j.landings); }
    as_label_free(&j.entry);
    as_label_free(&j.call_entry);
    as_label_free(&j.reg_call_entry);
    if (sync_live != j.live_in) free(sync_live);
    free(j.live_in); free(j.homes);
    free(j.sites);
    free(j.pending);
    free(j.land_offs); free(j.land_pcs);
    free(sc.start); free(sc.target); free(sc.ends); free(sc.phantom);
    free(marks.at);
    ms_free(&j.m);
    return ok;
#else
    (void)vm; (void)jit; (void)f; (void)tier;
    return 0;
#endif
}
