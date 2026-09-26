/* The emitters of tier 1 (docs/plans/jit.md, M4): one per instruction of
   the register bytecode, doing what the instruction's case in vm/new's
   loop does (src/isa/regs.sml), in the loop's frame, with every value in
   its slot, over the macro-assembler (masm.h). The generated jit_cases.h
   reads each instruction's operands and calls its emitter, and jit_emit.h
   has the prototypes, so an instruction without an emitter does not
   build. `next` is the pc after the instruction, which the VM's pc is made
   before any call into C; a run is counted where it begins (compile.c). */
#include "compile.h"
#include "jit_emit.h"

#define M (&j->m)
#define A (&j->m.a)
#define OFF(field) ((int32_t)offsetof(VM, field))
#define SLOT(k) ((int32_t)(16 * (k)))

void emit_HALT(Jit *j, uint32_t pc) {
    (void)pc;
    ms_sync(M, j->next, 0);
    ms_handback(M, RUN_HALT);
}
void emit_MOVE(Jit *j, uint32_t pc, int32_t a, int32_t b) { (void)pc; ms_copy(M, a, b); }
void emit_INT(Jit *j, uint32_t pc, int32_t a, int32_t b) { (void)pc; ms_set(M, a, T_INT, b); }
void emit_CONST(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    x64_mov_rm(A, RAX, VMR, OFF(prog.consts));
    ms_load_value(M, a, RAX, 16 * b);
}
void emit_UNIT(Jit *j, uint32_t pc, int32_t a) { (void)pc; ms_set(M, a, T_UNIT, 0); }
void emit_CON0(Jit *j, uint32_t pc, int32_t a, int32_t b) { (void)pc; ms_set(M, a, T_CON0, b); }
void emit_GLOBAL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    x64_mov_rm(A, RAX, VMR, OFF(global_set));
    x64_cmp8_mi(A, RAX, b, 0);
    x64_jcc(A, CC_E, jit_fatal(j, FATAL_GLOBAL_UNSET, b, 0, 0));
    x64_mov_rm(A, RAX, VMR, OFF(globals));
    ms_load_value(M, a, RAX, 16 * b);
}
void emit_SETGLOBAL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    x64_mov_rm(A, RAX, VMR, OFF(globals));
    ms_store_value(M, RAX, 16 * a, b);
    x64_mov_rm(A, RAX, VMR, OFF(global_set));
    x64_mov8_mi(A, RAX, a, 1);
}
/* rax := the frame's closure, or the fatal error */
static void closure(Jit *j, int what) {
    ms_frame(M, RCX);
    x64_mov_rm(A, RAX, RCX, (int32_t)offsetof(Frame, closure));
    x64_test_rr(A, RAX, RAX);
    x64_jcc(A, CC_E, jit_fatal(j, what, 0, 0, 0));
}
void emit_ENV(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    closure(j, FATAL_ENV_RANGE);
    x64_cmp32_mi(A, RAX, (int32_t)offsetof(Obj, len), b + 1);
    x64_jcc(A, CC_BE, jit_fatal(j, FATAL_ENV_RANGE, b, 0, 0));
    ms_load_value(M, a, RAX, (int32_t)sizeof(Obj) + 16 * (b + 1));
}
void emit_SELF(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    closure(j, FATAL_SELF);
    ms_set_reg(M, a, T_PTR, RAX);
}
void emit_PRIM(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) {
    (void)pc; (void)n;
    X64Label done; x64_label_init(&done);
    ms_sync(M, j->next, 0);
    x64_mov_ri(A, ms_arg(M, 1), a);
    x64_mov_ri(A, ms_arg(M, 2), b);
    x64_mov_ri(A, ms_arg(M, 3), (int64_t)(intptr_t)L);
    ms_call(M, (MsHelper)jit_h_prim);
    ms_reload(M);
    x64_test_rr(A, RAX, RAX);
    x64_jcc(A, CC_E, &done);
    ms_handback_rax(M);
    x64_bind(A, &done);
    x64_label_free(&done);
}

/* an object of n fields, fast in line or through the helper, then filled
   and stored into d */
static void alloc(Jit *j, int kind, int contag, uint32_t n, int fill, int32_t d, int32_t a, int32_t b, const uint8_t *L) {
    X64Label *slow = jit_alloc_slow(j, kind, contag, n, fill, d, a, b, L);
    if (!slow) return;
    /* the slow path's index, not its address: the fill may add a slow path
       of its own, and ms_slow moves the array as it grows */
    int which = j->m.nslow - 1;
    ms_alloc(M, kind, contag, n, slow);
    jit_fill(j, kind, fill, n, d, a, b, L);
    x64_bind(A, &j->m.slow[which].back);
}
void emit_TUPLE(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) {
    (void)pc; (void)b;
    if (n == 0) { ms_set(M, a, T_UNIT, 0); return; }
    alloc(j, K_TUPLE, 0, n, FILL_LIST, a, 0, 0, L);
}
void emit_CLOSURE(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c, const uint8_t *L, uint32_t n) {
    (void)pc; (void)c;
    alloc(j, K_CLOSURE, 0, n + 1, FILL_CLOSURE, a, b, 0, L);
}
void emit_SELECT(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    ms_load_obj(M, RAX, c, K_TUPLE, jit_fatal(j, FATAL_EXPECT_TUPLE, 0, 0, 0));
    x64_cmp32_mi(A, RAX, (int32_t)offsetof(Obj, len), b);
    x64_jcc(A, CC_BE, jit_fatal(j, FATAL_TUPLE_INDEX, b, 0, 0));
    ms_load_value(M, a, RAX, (int32_t)sizeof(Obj) + 16 * b);
}
void emit_CON(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    alloc(j, K_CON, b, 1, FILL_ONE, a, c, 0, NULL);
}
/* --checked: the tag of the constructor in rax against t */
static void checked_tag(Jit *j, int32_t t, int what) {
    X64Label skip; x64_label_init(&skip);
    x64_cmp32_mi(A, VMR, OFF(checked), 0);
    x64_jcc(A, CC_E, &skip);
    x64_movzx16_rm(A, RCX, RAX, (int32_t)offsetof(Obj, contag));
    x64_cmp_ri(A, RCX, t);
    /* the message names the tag found, which is in rcx */
    x64_jcc(A, CC_NE, jit_fatal(j, what, 0, t, 1));
    x64_bind(A, &skip);
    x64_label_free(&skip);
}
void emit_DECON(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    ms_load_obj(M, RAX, b, K_CON, jit_fatal(j, FATAL_EXPECT_CON, 0, 0, 0));
    checked_tag(j, c, FATAL_DECON_TAG);
    ms_load_value(M, a, RAX, (int32_t)sizeof(Obj));
}
void emit_CONTAG(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    ms_load_tag_of_con(M, RAX, b, jit_fatal(j, FATAL_CONTAG, 0, 0, 0));
    ms_set_reg(M, a, T_INT, RAX);
}
void emit_NEWEXN(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    alloc(j, K_EXNCON, 0, 1, FILL_NEWEXN, a, b, 0, NULL);
}
void emit_BUILTINEXN(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    x64_mov_rm(A, RAX, VMR, OFF(builtin_exns) + 8 * b);
    ms_set_reg(M, a, T_PTR, RAX);
}
void emit_MKEXN(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    alloc(j, K_EXN, 0, 2, FILL_MKEXN, a, b, c, NULL);
}
void emit_EXNCON(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    ms_load_obj(M, RAX, b, K_EXN, jit_fatal(j, FATAL_EXPECT_EXN, 0, 0, 0));
    ms_load_value(M, a, RAX, (int32_t)sizeof(Obj));
}
void emit_EXNARG(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    ms_load_obj(M, RAX, b, K_EXN, jit_fatal(j, FATAL_EXPECT_EXN, 0, 0, 0));
    ms_load_value(M, a, RAX, (int32_t)sizeof(Obj) + 16);
}
void emit_SETENV(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    ms_load_obj(M, RAX, a, K_CLOSURE, jit_fatal(j, FATAL_EXPECT_CLOSURE, 0, 0, 0));
    x64_cmp32_mi(A, RAX, (int32_t)offsetof(Obj, len), b + 1);
    x64_jcc(A, CC_BE, jit_fatal(j, FATAL_ENV_RANGE, b, 0, 0));
    ms_store_field(M, RAX, (uint32_t)b + 1, c);
}
void emit_JUMP(Jit *j, uint32_t pc, int32_t a) { (void)pc; x64_jmp(A, jit_label(j, (uint32_t)a)); }
void emit_JUMPIF(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    ms_check_tag(M, a, T_CON0, jit_fatal(j, FATAL_JUMPIF, 0, 0, 0));
    x64_cmp_mi(A, BASER, SLOT(a) + 8, 0);
    x64_jcc(A, CC_NE, jit_label(j, (uint32_t)b));
}
void emit_JUMPIFNOT(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    ms_check_tag(M, a, T_CON0, jit_fatal(j, FATAL_JUMPIFNOT, 0, 0, 0));
    x64_cmp_mi(A, BASER, SLOT(a) + 8, 0);
    x64_jcc(A, CC_E, jit_label(j, (uint32_t)b));
}
void emit_JUMPIFNOTTAG(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    ms_load_tag_of_con(M, RAX, a, jit_fatal(j, FATAL_JUMPIFNOTTAG, 0, 0, 0));
    x64_cmp_ri(A, RAX, c);
    x64_jcc(A, CC_NE, jit_label(j, (uint32_t)b));
}
/* the table of n JUMPs after the instruction is a table of offsets here:
   the tag's entry, from the table's start, added to it and jumped to */
void emit_SWITCH(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    const uint8_t *code = j->vm->prog.code;
    uint32_t table = j->next;
    X64Label past, tbl; x64_label_init(&past); x64_label_init(&tbl);
    ms_load_tag_of_con(M, RAX, a, jit_fatal(j, FATAL_SWITCH, 0, 0, 0));
    x64_cmp_ri(A, RAX, b);
    x64_jcc(A, CC_AE, &past);   /* unsigned: a negative tag is past it too */
    x64_lea_rip(A, RCX, &tbl);
    x64_movsxd_rmi(A, RDX, RCX, RAX, 4, 0);
    x64_add_rr(A, RCX, RDX);
    x64_jmp_r(A, RCX);
    x64_bind(A, &tbl);
    size_t table_at = A->n;
    for (int32_t k = 0; k < b; k++) {
        size_t at = A->n;
        x64_u32(A, 0);
        x64_offset32_at(A, at, table_at, jit_label(j, (uint32_t)read_i32(code + table + 5 * (uint32_t)k + 1)));
    }
    x64_bind(A, &past);
    x64_jmp(A, jit_label(j, table + 5 * (uint32_t)b));
    x64_label_free(&past); x64_label_free(&tbl);
    (void)pc;
}
void emit_CONN(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c, const uint8_t *L, uint32_t n) {
    (void)pc; (void)c;
    alloc(j, K_CON, b, n, FILL_LIST, a, 0, 0, L);
}
void emit_FIELD(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c, int32_t d) {
    (void)pc;
    ms_load_obj(M, RAX, b, K_CON, jit_fatal(j, FATAL_EXPECT_CON_FIELDS, 0, 0, 0));
    checked_tag(j, c, FATAL_FIELD_TAG);
    x64_cmp32_mi(A, RAX, (int32_t)offsetof(Obj, len), d);
    x64_jcc(A, CC_BE, jit_fatal(j, FATAL_FIELD_INDEX, d, 0, 0));
    ms_load_value(M, a, RAX, (int32_t)sizeof(Obj) + 16 * d);
}
/* ---- calls, returns, handlers, PRIMPUSH (M5) ---- */

#define FRAME_SIZE ((int32_t)sizeof(Frame))
#define FR(field) ((int32_t)offsetof(Frame, field))

/* rax := the entry of function f, read from its code object when the call
   is made, since a function is compiled once and not before every caller */
static void entry_of(Jit *j, uint32_t f) {
    x64_mov_ri(A, RAX, (int64_t)(intptr_t)&j->jit->codes[f].entry);
    x64_mov_rm(A, RAX, RAX, 0);
}
/* into the callee whose frame is on top and whose registers rbp and r14
   now name: its code where it has some, else the interpreter, the VM made
   exact for it */
static void to_callee(Jit *j, uint32_t f, const Function *fn) {
    X64Label interp; x64_label_init(&interp);
    entry_of(j, f);
    x64_test_rr(A, RAX, RAX);
    x64_jcc(A, CC_E, &interp);
    x64_jmp_r(A, RAX);
    x64_bind(A, &interp);
    x64_mov32_mi(A, VMR, OFF(pc), (int32_t)fn->code_offset);
    x64_lea(A, RAX, BASEI, -1, 1, (int32_t)fn->nlocals);
    x64_mov_mr(A, VMR, OFF(sp), RAX);
    x64_mov_mr(A, VMR, OFF(instructions), COUNTR);
    ms_handback(M, RUN_INTERP);
    x64_label_free(&interp);
}
/* room on the stack for need values above the frame's base, or the slow
   path that grows it */
static void room(Jit *j, uint32_t need) {
    Slow *s = ms_slow(M, SLOW_GROW, j->next);
    if (!s) return;
    s->n = need;
    x64_lea(A, RAX, BASEI, -1, 1, (int32_t)need);
    x64_cmp_rm(A, RAX, VMR, OFF(stack_cap));
    x64_jcc(A, CC_A, &s->here);
    x64_bind(A, &s->back);
}
/* rax := the index of a new frame, the array grown where it must be */
static void frame_room(Jit *j) {
    Slow *s = ms_slow(M, SLOW_FRAMES, j->next);
    if (!s) return;
    x64_bind(A, &s->back);
    x64_mov_rm(A, RAX, VMR, OFF(fp));
    x64_add_ri(A, RAX, 1);
    x64_cmp_rm(A, RAX, VMR, OFF(frames_cap));
    x64_jcc(A, CC_AE, &s->here);
}
/* a frame pushed: index rax, function f, base rdx, no closure, returning
   to the code at after, the caller's pc that of the RESULT */
static void push_frame(Jit *j, uint32_t f, int32_t ret_pc, X64Label *after) {
    x64_mov_rm(A, RCX, VMR, OFF(frames));
    x64_mov_rr(A, R8, RAX);
    x64_shl_ri(A, R8, 5);   /* FRAME_SIZE */
    x64_add_rr(A, RCX, R8);
    x64_mov32_mi(A, RCX, FR(func), (int32_t)f);
    x64_mov32_mi(A, RCX, FR(ret_pc), ret_pc);
    x64_mov_mr(A, RCX, FR(base), RDX);
    x64_mov_mi(A, RCX, FR(closure), 0);
    x64_lea_rip(A, R8, after);
    x64_mov_mr(A, RCX, FR(native_ret), R8);
    x64_mov_mr(A, VMR, OFF(fp), RAX);
}
/* the registers of a callee at r9: its n arguments from the list, the
   rest unit */
static void make_registers(Jit *j, uint32_t n, const uint8_t *L, uint32_t nlocals) {
    for (uint32_t i = 0; i < n; i++) {
        x64_movups_xm(A, XMM0, BASER, 16 * read_i32(L + 4 * i));
        x64_movups_mx(A, R9, (int32_t)(16 * i), XMM0);
    }
    if (nlocals > n) {
        x64_xorpd(A, XMM1, XMM1);   /* unit: tag 0, payload 0 */
        for (uint32_t i = n; i < nlocals; i++) x64_movups_mx(A, R9, (int32_t)(16 * i), XMM1);
    }
}

void emit_CALLK(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) {
    (void)pc; (void)b;
    const Function *fn = &j->vm->prog.funcs[a];
    X64Label *after = jit_label(j, j->next + 5);   /* past the RESULT */
    room(j, j->m.nlocals + fn->nlocals + fn->maxstack);
    frame_room(j);
    x64_lea(A, R9, BASER, -1, 1, (int32_t)(16 * j->m.nlocals));
    make_registers(j, n, L, fn->nlocals);
    x64_lea(A, RDX, BASEI, -1, 1, (int32_t)j->m.nlocals);
    push_frame(j, (uint32_t)a, (int32_t)j->next, after);
    x64_mov_rr(A, BASEI, RDX);
    x64_mov_rr(A, BASER, R9);
    to_callee(j, (uint32_t)a, fn);
}
void emit_TAILCALLK(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) {
    (void)pc; (void)b;
    const Function *fn = &j->vm->prog.funcs[a];
    uint32_t need = j->m.nlocals + n;
    if (fn->nlocals + fn->maxstack > need) need = fn->nlocals + fn->maxstack;
    room(j, need);
    /* the arguments above the frame first, since they are its registers */
    x64_lea(A, R9, BASER, -1, 1, (int32_t)(16 * j->m.nlocals));
    for (uint32_t i = 0; i < n; i++) {
        x64_movups_xm(A, XMM0, BASER, 16 * read_i32(L + 4 * i));
        x64_movups_mx(A, R9, (int32_t)(16 * i), XMM0);
    }
    for (uint32_t i = 0; i < n; i++) {
        x64_movups_xm(A, XMM0, R9, (int32_t)(16 * i));
        x64_movups_mx(A, BASER, (int32_t)(16 * i), XMM0);
    }
    if (fn->nlocals > n) {
        x64_xorpd(A, XMM1, XMM1);
        for (uint32_t i = n; i < fn->nlocals; i++) x64_movups_mx(A, BASER, (int32_t)(16 * i), XMM1);
    }
    ms_frame(M, RCX);
    x64_mov32_mi(A, RCX, FR(func), a);
    x64_mov_mi(A, RCX, FR(closure), 0);
    to_callee(j, (uint32_t)a, fn);
}
/* a call through a closure: the helper checks it, pushes the frame and
   makes the callee's registers, and answers with the callee's entry, or
   NULL for the interpreter, the VM made exact for it */
static void call_through(Jit *j, MsHelper helper, int32_t a, int32_t b, X64Label *after) {
    X64Label interp; x64_label_init(&interp);
    ms_sync(M, j->next, 0);
    x64_mov_ri(A, ms_arg(M, 1), a);
    x64_mov_ri(A, ms_arg(M, 2), b);
    if (after) x64_lea_rip(A, ms_arg(M, 3), after);
    ms_call(M, helper);
    ms_reload(M);
    x64_test_rr(A, RAX, RAX);
    x64_jcc(A, CC_E, &interp);
    x64_jmp_r(A, RAX);
    x64_bind(A, &interp);
    ms_handback(M, RUN_INTERP);
    x64_label_free(&interp);
}
void emit_CALL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    call_through(j, (MsHelper)jit_h_call, a, b, jit_label(j, j->next + 5));
}
void emit_TAILCALL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    call_through(j, (MsHelper)jit_h_tailcall, a, b, NULL);
}
/* after a CALL or CALLK a RESULT is the callee's RET's to do, and is passed
   over (compile.c, phantom); after a PRIMPUSH it takes what the primitive
   left on the stack, above the registers */
void emit_RESULT(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    x64_movups_xm(A, XMM0, BASER, (int32_t)(16 * j->m.nlocals));
    x64_movups_mx(A, BASER, 16 * a, XMM0);
}
/* RET: the value into the register of the caller's RESULT, then on into
   the caller's code where it has some, else the VM made exact and handed
   back; the frame of the top level through the helper */
void emit_RET(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    X64Label no_result, go, hand; x64_label_init(&no_result); x64_label_init(&go); x64_label_init(&hand);
    Slow *s = ms_slow(M, SLOW_RET, j->next);
    if (!s) return;
    s->a = a;
    x64_mov_rm(A, RDX, VMR, OFF(fp));
    x64_test_rr(A, RDX, RDX);
    x64_jcc(A, CC_E, &s->here);
    ms_frame(M, RCX);
    x64_movups_xm(A, XMM0, BASER, 16 * a);
    x64_mov32_rm(A, R8, RCX, FR(ret_pc));
    x64_mov_rm(A, R9, RCX, FR(native_ret));
    x64_mov_rm(A, R10, RCX, FR(base));
    x64_sub_ri(A, RDX, 1);
    x64_mov_mr(A, VMR, OFF(fp), RDX);
    x64_sub_ri(A, RCX, FRAME_SIZE);
    x64_mov_rm(A, BASEI, RCX, FR(base));
    x64_mov_rr(A, BASER, BASEI);
    x64_shl_ri(A, BASER, 4);
    x64_add_rr(A, BASER, STACKR);
    x64_mov_rm(A, RAX, VMR, OFF(prog.code));
    x64_add_rr(A, RAX, R8);
    x64_cmp8_mi(A, RAX, 0, ROP_RESULT);
    x64_jcc(A, CC_NE, &no_result);
    x64_movsxd_rmi(A, RDX, RAX, -1, 1, 1);
    x64_shl_ri(A, RDX, 4);
    x64_movups_mix(A, BASER, RDX, 1, 0, XMM0);
    x64_add_ri(A, R8, 5);
    x64_jmp(A, &go);
    x64_bind(A, &no_result);
    /* no RESULT to write into: the value onto the stack for it */
    x64_mov_rr(A, RAX, R10);
    x64_shl_ri(A, RAX, 4);
    x64_movups_mix(A, STACKR, RAX, 1, 0, XMM0);
    x64_add_ri(A, R10, 1);
    x64_bind(A, &go);
    x64_test_rr(A, R9, R9);
    x64_jcc(A, CC_E, &hand);
    x64_jmp_r(A, R9);
    x64_bind(A, &hand);
    x64_mov32_mr(A, VMR, OFF(pc), R8);
    x64_mov_mr(A, VMR, OFF(sp), R10);
    x64_mov_mr(A, VMR, OFF(instructions), COUNTR);
    ms_handback(M, RUN_INTERP);
    x64_label_free(&no_result); x64_label_free(&go); x64_label_free(&hand);
}
void emit_PRIMPUSH(Jit *j, uint32_t pc, int32_t a, const uint8_t *L, uint32_t n) {
    (void)pc; (void)n;
    X64Label done; x64_label_init(&done);
    ms_sync(M, j->next, 0);
    x64_mov_ri(A, ms_arg(M, 1), a);
    x64_mov_ri(A, ms_arg(M, 2), (int64_t)(intptr_t)L);
    ms_call(M, (MsHelper)jit_h_primpush);
    ms_reload(M);
    x64_test_rr(A, RAX, RAX);
    x64_jcc(A, CC_E, &done);
    ms_handback_rax(M);
    x64_bind(A, &done);
    x64_label_free(&done);
}
void emit_PUSHHANDLER(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    ms_sync(M, j->next, 0);
    x64_mov_ri(A, ms_arg(M, 1), a);
    x64_lea_rip(A, ms_arg(M, 2), jit_label(j, (uint32_t)a));
    ms_call(M, (MsHelper)jit_h_push_handler);
}
void emit_POPHANDLER(Jit *j, uint32_t pc) {
    (void)pc;
    x64_cmp_mi(A, VMR, OFF(hp), 0);
    x64_jcc(A, CC_E, jit_fatal(j, FATAL_POPHANDLER, 0, 0, 0));
    x64_add_mi(A, VMR, OFF(hp), -1);
}
void emit_CATCH(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    x64_movups_xm(A, XMM0, BASER, (int32_t)(16 * j->m.nlocals));
    x64_movups_mx(A, BASER, 16 * a, XMM0);
}
void emit_RAISE(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    X64Label hand; x64_label_init(&hand);
    ms_load_obj(M, RAX, a, K_EXN, jit_fatal(j, FATAL_RAISE, 0, 0, 0));
    ms_sync(M, j->next, 0);
    x64_mov_ri(A, ms_arg(M, 1), a);
    ms_call(M, (MsHelper)jit_h_raise);
    ms_reload(M);
    x64_test_rr(A, RAX, RAX);
    x64_jcc(A, CC_E, &hand);
    x64_jmp_r(A, RAX);
    x64_bind(A, &hand);
    ms_handback(M, RUN_INTERP);
    x64_label_free(&hand);
}
