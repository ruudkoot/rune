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
void emit_CALL(Jit *j, uint32_t pc, int32_t a, int32_t b) { (void)pc; (void)a; (void)b; jit_unsupported(j); }
void emit_RESULT(Jit *j, uint32_t pc, int32_t a) { (void)pc; (void)a; jit_unsupported(j); }
void emit_TAILCALL(Jit *j, uint32_t pc, int32_t a, int32_t b) { (void)pc; (void)a; (void)b; jit_unsupported(j); }
void emit_RET(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    ms_sync(M, j->next, 0);
    x64_mov_ri(A, ms_arg(M, 1), a);
    ms_call(M, (MsHelper)jit_h_ret);
    ms_handback_rax(M);
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
void emit_PRIMPUSH(Jit *j, uint32_t pc, int32_t a, const uint8_t *L, uint32_t n) { (void)pc; (void)a; (void)L; (void)n; jit_unsupported(j); }

/* an object of n fields, fast in line or through the helper, then filled
   and stored into d */
static void alloc(Jit *j, int kind, int contag, uint32_t n, int fill, int32_t d, int32_t a, int32_t b, const uint8_t *L) {
    X64Label *slow = jit_alloc_slow(j, kind, contag, n, fill, d, a, b, L);
    if (!slow) return;
    Slow *s = &j->m.slow[j->m.nslow - 1];
    ms_alloc(M, kind, contag, n, slow);
    jit_fill(j, kind, fill, n, d, a, b, L);
    x64_bind(A, &s->back);
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
void emit_PUSHHANDLER(Jit *j, uint32_t pc, int32_t a) { (void)pc; (void)a; jit_unsupported(j); }
void emit_POPHANDLER(Jit *j, uint32_t pc) { (void)pc; jit_unsupported(j); }
void emit_CATCH(Jit *j, uint32_t pc, int32_t a) { (void)pc; (void)a; jit_unsupported(j); }
void emit_RAISE(Jit *j, uint32_t pc, int32_t a) { (void)pc; (void)a; jit_unsupported(j); }
void emit_CALLK(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) { (void)pc; (void)a; (void)b; (void)L; (void)n; jit_unsupported(j); }
void emit_TAILCALLK(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) { (void)pc; (void)a; (void)b; (void)L; (void)n; jit_unsupported(j); }
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
