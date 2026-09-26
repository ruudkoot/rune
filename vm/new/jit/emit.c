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
/* ---- primitives in line (M7) ---- */

/* The common case of the primitives the loop does in line (fastprim.h),
   as code: exactly what prim_fast gives, and to the slow path -- the
   helper, which does the primitive as the loop would, and may raise --
   wherever prim_fast would answer 0: a tag that is not the one, an
   overflow, a divisor of 0 or -1, an index out of bounds, a real or a
   pointer under `=`. Every argument is read before the result is written,
   since the result's register may be one of them. */
#define PAY(k) ((int32_t)(16 * (k) + 8))
#define TAGOF(k) ((int32_t)(16 * (k)))

/* the bool of the flags into d */
static void set_bool(Jit *j, int32_t d, int cc) {
    x64_setcc_r8(A, cc, RAX);
    x64_movzx8_rr(A, RAX, RAX);
    ms_set_reg(M, d, T_CON0, RAX);
    x64_test_rr(A, RAX, RAX);   /* and back into the flags (ZF: false), for a branch fused onto it */
}
/* LESS, EQUAL or GREATER (0, 1, 2) of the flags into d: ge + g */
static void set_order(Jit *j, int32_t d, int cc_ge, int cc_g) {
    x64_setcc_r8(A, cc_ge, RAX);
    x64_setcc_r8(A, cc_g, RCX);
    x64_movzx8_rr(A, RAX, RAX);
    x64_movzx8_rr(A, RCX, RCX);
    x64_add_rr(A, RAX, RCX);
    ms_set_reg(M, d, T_CON0, RAX);
}
/* the two arguments, of one tag, into rax and rcx */
static void two(Jit *j, int32_t x, int32_t y, int tag, X64Label *slow) {
    ms_check_tag(M, x, tag, slow);
    ms_check_tag(M, y, tag, slow);
    ms_load_payload(M, RAX, x);
    ms_load_payload(M, RCX, y);
}
/* the two real arguments into xmm0 and xmm1 (or the other way round) */
static void two_real(Jit *j, int32_t x, int32_t y, X64Label *slow) {
    ms_check_tag(M, x, T_REAL, slow);
    ms_check_tag(M, y, T_REAL, slow);
    x64_movsd_xm(A, XMM0, BASER, PAY(x));
    x64_movsd_xm(A, XMM1, BASER, PAY(y));
}
static void set_real(Jit *j, int32_t d) {
    x64_mov_mi(A, BASER, TAGOF(d), T_REAL);
    x64_movsd_mx(A, BASER, PAY(d), XMM0);
}
/* rcx := the index in y, checked against the length of the object in rax */
static void index_of(Jit *j, int32_t y, X64Label *slow) {
    ms_check_tag(M, y, T_INT, slow);
    ms_load_payload(M, RCX, y);
    x64_mov32_rm(A, R8, RAX, (int32_t)offsetof(Obj, len));
    x64_cmp_rr(A, RCX, R8);
    x64_jcc(A, CC_AE, slow);   /* unsigned: a negative index is out too */
}
/* the length of the object of kind k in x, as an int, into d */
static void length_of(Jit *j, int32_t d, int32_t x, int k, X64Label *slow) {
    ms_load_obj(M, RAX, x, k, slow);
    x64_mov32_rm(A, RCX, RAX, (int32_t)offsetof(Obj, len));
    ms_set_reg(M, d, T_INT, RCX);
}
/* rax := the address of element rcx of the object in rax (16 bytes each) */
static void element(Jit *j) {
    x64_shl_ri(A, RCX, 4);
    x64_add_rr(A, RAX, RCX);
}
/* int_div and int_mod after cqo; idiv: the quotient in rax, the
   remainder in rdx, the divisor in rcx; floor where the signs differ */
static void floor_div(Jit *j, int mod) {
    X64Label done; x64_label_init(&done);
    x64_test_rr(A, RDX, RDX);
    x64_jcc(A, CC_E, &done);
    x64_mov_rr(A, R8, RDX);
    x64_xor_rr(A, R8, RCX);
    x64_jcc(A, CC_NS, &done);
    if (mod) x64_add_rr(A, RDX, RCX); else x64_sub_ri(A, RAX, 1);
    x64_bind(A, &done);
    x64_label_free(&done);
}
/* `=` on two values that are neither pointers nor (for poly_eq) reals:
   the tags the same and the payloads the same */
static void equal(Jit *j, int32_t d, int32_t x, int32_t y, int poly, X64Label *slow) {
    X64Label no, done, heap; x64_label_init(&no); x64_label_init(&done); x64_label_init(&heap);
    /* a pointer, or a real under poly_eq, is values_equal's: the lean
       helper, which touches nothing of the VM (imm_eq's pointer is the
       primitive's error) */
    X64Label *deep = poly ? &heap : slow;
    ms_load_tag(M, RAX, x);
    x64_cmp_ri(A, RAX, T_PTR);
    x64_jcc(A, CC_E, deep);
    if (poly) { x64_cmp_ri(A, RAX, T_REAL); x64_jcc(A, CC_E, deep); }
    ms_load_tag(M, RCX, y);
    x64_cmp_ri(A, RCX, T_PTR);
    x64_jcc(A, CC_E, deep);
    if (poly) { x64_cmp_ri(A, RCX, T_REAL); x64_jcc(A, CC_E, deep); }
    x64_cmp_rr(A, RAX, RCX);
    x64_jcc(A, CC_NE, &no);
    ms_load_payload(M, RAX, x);
    x64_cmp_rm(A, RAX, BASER, PAY(y));
    set_bool(j, d, CC_E);
    x64_jmp(A, &done);
    x64_bind(A, &no);
    ms_set(M, d, T_CON0, 0);
    x64_xor_rr(A, RAX, RAX);   /* false, in the flags too */
    if (poly) {
        x64_jmp(A, &done);
        x64_bind(A, &heap);
        x64_lea(A, ms_arg(M, 1), BASER, -1, 1, 16 * x);
        x64_lea(A, ms_arg(M, 2), BASER, -1, 1, 16 * y);
        ms_call(M, (MsHelper)jit_h_values_equal);
        ms_set_reg(M, d, T_CON0, RAX);
        x64_test_rr(A, RAX, RAX);
    }
    x64_bind(A, &done);
    x64_label_free(&no); x64_label_free(&done); x64_label_free(&heap);
}

static void alloc(Jit *j, int kind, int contag, uint32_t n, int fill, int32_t d, int32_t a, int32_t b, const uint8_t *L);
/* PRIM p d args in line, or 0 where p is not one done in line */
static int prim_inline(Jit *j, int32_t p, int32_t d, const uint8_t *L, uint32_t n) {
    if (n == 0 || n > 3) return 0;
    int32_t x = read_i32(L), y = n > 1 ? read_i32(L + 4) : x, z = n > 2 ? read_i32(L + 8) : x;
    switch (p) {
    case PRIM_poly_eq: case PRIM_imm_eq: case PRIM_string_order: case PRIM_ref_new:
    case PRIM_int_add: case PRIM_int_sub: case PRIM_int_mul: case PRIM_int_div: case PRIM_int_mod:
    case PRIM_int_quot: case PRIM_int_rem: case PRIM_int_neg: case PRIM_int_lt: case PRIM_int_le:
    case PRIM_int_gt: case PRIM_int_ge: case PRIM_int_order: case PRIM_int_to_char:
    case PRIM_word_add: case PRIM_word_sub: case PRIM_word_mul: case PRIM_word_div: case PRIM_word_mod:
    case PRIM_word_lt: case PRIM_word_le: case PRIM_word_gt: case PRIM_word_ge: case PRIM_word_order:
    case PRIM_word_andb: case PRIM_word_orb: case PRIM_word_xorb: case PRIM_word_notb:
    case PRIM_word_lsl: case PRIM_word_lsr: case PRIM_word_to_int: case PRIM_word_to_int_x: case PRIM_word_from_int:
    case PRIM_real_add: case PRIM_real_sub: case PRIM_real_mul: case PRIM_real_div: case PRIM_real_neg:
    case PRIM_real_lt: case PRIM_real_le: case PRIM_real_gt: case PRIM_real_ge: case PRIM_real_eq:
    case PRIM_char_ord: case PRIM_char_lt: case PRIM_char_le: case PRIM_char_gt: case PRIM_char_ge: case PRIM_char_order:
    case PRIM_string_size: case PRIM_string_sub: case PRIM_ref_get: case PRIM_ref_set:
    case PRIM_array_length: case PRIM_array_sub: case PRIM_array_update: case PRIM_vector_length: case PRIM_vector_sub:
        break;
    default:
        return 0;
    }
    /* the slow path: the helper; its index, since nothing here adds another */
    Slow *s = ms_slow(M, SLOW_PRIM, j->next);
    if (!s) return 1;
    s->a = p; s->b = d; s->L = L;
    int which = M->nslow - 1;
    X64Label *slow = &M->slow[which].here;
    switch (p) {
    case PRIM_poly_eq: equal(j, d, x, y, 1, slow); break;
    case PRIM_imm_eq: equal(j, d, x, y, 0, slow); break;
    case PRIM_string_order:
        /* the two strings to the lean helper, which touches nothing of the
           VM: no sync, no reload */
        ms_load_obj(M, ms_arg(M, 1), x, K_STRING, slow);
        ms_load_obj(M, ms_arg(M, 2), y, K_STRING, slow);
        ms_call(M, (MsHelper)jit_h_string_order);
        ms_set_reg(M, d, T_CON0, RAX);
        break;
    case PRIM_ref_new:
        alloc(j, K_REF, 0, 1, FILL_ONE, d, x, 0, NULL);
        break;

    case PRIM_int_add: two(j, x, y, T_INT, slow); x64_add_rr(A, RAX, RCX); x64_jcc(A, CC_O, slow); ms_set_reg(M, d, T_INT, RAX); break;
    case PRIM_int_sub: two(j, x, y, T_INT, slow); x64_sub_rr(A, RAX, RCX); x64_jcc(A, CC_O, slow); ms_set_reg(M, d, T_INT, RAX); break;
    case PRIM_int_mul: two(j, x, y, T_INT, slow); x64_imul_rr(A, RAX, RCX); x64_jcc(A, CC_O, slow); ms_set_reg(M, d, T_INT, RAX); break;
    case PRIM_int_div: case PRIM_int_mod: case PRIM_int_quot: case PRIM_int_rem:
        two(j, x, y, T_INT, slow);
        x64_test_rr(A, RCX, RCX);
        x64_jcc(A, CC_E, slow);
        x64_cmp_ri(A, RCX, -1);
        x64_jcc(A, CC_E, slow);
        x64_cqo(A);
        x64_idiv_r(A, RCX);
        if (p == PRIM_int_div) { floor_div(j, 0); ms_set_reg(M, d, T_INT, RAX); }
        else if (p == PRIM_int_mod) { floor_div(j, 1); ms_set_reg(M, d, T_INT, RDX); }
        else if (p == PRIM_int_quot) ms_set_reg(M, d, T_INT, RAX);
        else ms_set_reg(M, d, T_INT, RDX);
        break;
    case PRIM_int_neg:
        ms_check_tag(M, x, T_INT, slow);
        ms_load_payload(M, RAX, x);
        x64_mov_ri(A, RCX, INT64_MIN);
        x64_cmp_rr(A, RAX, RCX);
        x64_jcc(A, CC_E, slow);
        x64_neg_r(A, RAX);
        ms_set_reg(M, d, T_INT, RAX);
        break;
    case PRIM_int_lt: two(j, x, y, T_INT, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_L); break;
    case PRIM_int_le: two(j, x, y, T_INT, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_LE); break;
    case PRIM_int_gt: two(j, x, y, T_INT, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_G); break;
    case PRIM_int_ge: two(j, x, y, T_INT, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_GE); break;
    case PRIM_int_order: two(j, x, y, T_INT, slow); x64_cmp_rr(A, RAX, RCX); set_order(j, d, CC_GE, CC_G); break;
    case PRIM_int_to_char:
        ms_check_tag(M, x, T_INT, slow);
        ms_load_payload(M, RAX, x);
        x64_cmp_ri(A, RAX, 255);
        x64_jcc(A, CC_A, slow);   /* unsigned: negative is out too */
        ms_set_reg(M, d, T_CHAR, RAX);
        break;

    case PRIM_word_add: two(j, x, y, T_WORD, slow); x64_add_rr(A, RAX, RCX); ms_set_reg(M, d, T_WORD, RAX); break;
    case PRIM_word_sub: two(j, x, y, T_WORD, slow); x64_sub_rr(A, RAX, RCX); ms_set_reg(M, d, T_WORD, RAX); break;
    case PRIM_word_mul: two(j, x, y, T_WORD, slow); x64_imul_rr(A, RAX, RCX); ms_set_reg(M, d, T_WORD, RAX); break;
    case PRIM_word_div: case PRIM_word_mod:
        two(j, x, y, T_WORD, slow);
        x64_test_rr(A, RCX, RCX);
        x64_jcc(A, CC_E, slow);
        x64_xor_rr(A, RDX, RDX);
        x64_div_r(A, RCX);
        ms_set_reg(M, d, T_WORD, p == PRIM_word_div ? RAX : RDX);
        break;
    case PRIM_word_lt: two(j, x, y, T_WORD, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_B); break;
    case PRIM_word_le: two(j, x, y, T_WORD, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_BE); break;
    case PRIM_word_gt: two(j, x, y, T_WORD, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_A); break;
    case PRIM_word_ge: two(j, x, y, T_WORD, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_AE); break;
    case PRIM_word_order: two(j, x, y, T_WORD, slow); x64_cmp_rr(A, RAX, RCX); set_order(j, d, CC_AE, CC_A); break;
    case PRIM_word_andb: two(j, x, y, T_WORD, slow); x64_and_rr(A, RAX, RCX); ms_set_reg(M, d, T_WORD, RAX); break;
    case PRIM_word_orb: two(j, x, y, T_WORD, slow); x64_or_rr(A, RAX, RCX); ms_set_reg(M, d, T_WORD, RAX); break;
    case PRIM_word_xorb: two(j, x, y, T_WORD, slow); x64_xor_rr(A, RAX, RCX); ms_set_reg(M, d, T_WORD, RAX); break;
    case PRIM_word_notb:
        ms_check_tag(M, x, T_WORD, slow);
        ms_load_payload(M, RAX, x);
        x64_not_r(A, RAX);
        ms_set_reg(M, d, T_WORD, RAX);
        break;
    case PRIM_word_lsl: case PRIM_word_lsr: {
        /* a count of 64 or more gives 0, where the machine would take it mod 64 */
        X64Label ok, done; x64_label_init(&ok); x64_label_init(&done);
        two(j, x, y, T_WORD, slow);
        x64_cmp_ri(A, RCX, 64);
        x64_jcc(A, CC_B, &ok);
        x64_xor_rr(A, RAX, RAX);
        x64_jmp(A, &done);
        x64_bind(A, &ok);
        if (p == PRIM_word_lsl) x64_shl_rcl(A, RAX); else x64_shr_rcl(A, RAX);
        x64_bind(A, &done);
        ms_set_reg(M, d, T_WORD, RAX);
        x64_label_free(&ok); x64_label_free(&done);
        break;
    }
    case PRIM_word_to_int:
        ms_check_tag(M, x, T_WORD, slow);
        ms_load_payload(M, RAX, x);
        x64_test_rr(A, RAX, RAX);
        x64_jcc(A, CC_S, slow);   /* above INT64_MAX */
        ms_set_reg(M, d, T_INT, RAX);
        break;
    case PRIM_word_to_int_x: ms_check_tag(M, x, T_WORD, slow); ms_load_payload(M, RAX, x); ms_set_reg(M, d, T_INT, RAX); break;
    case PRIM_word_from_int: ms_check_tag(M, x, T_INT, slow); ms_load_payload(M, RAX, x); ms_set_reg(M, d, T_WORD, RAX); break;

    case PRIM_real_add: two_real(j, x, y, slow); x64_addsd(A, XMM0, XMM1); set_real(j, d); break;
    case PRIM_real_sub: two_real(j, x, y, slow); x64_subsd(A, XMM0, XMM1); set_real(j, d); break;
    case PRIM_real_mul: two_real(j, x, y, slow); x64_mulsd(A, XMM0, XMM1); set_real(j, d); break;
    case PRIM_real_div: two_real(j, x, y, slow); x64_divsd(A, XMM0, XMM1); set_real(j, d); break;
    case PRIM_real_neg:
        ms_check_tag(M, x, T_REAL, slow);
        ms_load_payload(M, RAX, x);
        x64_mov_ri(A, RCX, INT64_MIN);   /* the sign bit */
        x64_xor_rr(A, RAX, RCX);
        ms_set_reg(M, d, T_REAL, RAX);
        break;
    /* a comparison with a NaN is false: ucomisd sets CF, ZF and PF on an
       unordered pair, which `above` reads as false; x < y is y > x */
    case PRIM_real_lt: two_real(j, y, x, slow); x64_ucomisd(A, XMM0, XMM1); set_bool(j, d, CC_A); break;
    case PRIM_real_le: two_real(j, y, x, slow); x64_ucomisd(A, XMM0, XMM1); set_bool(j, d, CC_AE); break;
    case PRIM_real_gt: two_real(j, x, y, slow); x64_ucomisd(A, XMM0, XMM1); set_bool(j, d, CC_A); break;
    case PRIM_real_ge: two_real(j, x, y, slow); x64_ucomisd(A, XMM0, XMM1); set_bool(j, d, CC_AE); break;
    case PRIM_real_eq:
        two_real(j, x, y, slow);
        x64_ucomisd(A, XMM0, XMM1);
        x64_setcc_r8(A, CC_E, RAX);
        x64_setcc_r8(A, CC_NP, RCX);
        x64_movzx8_rr(A, RAX, RAX);
        x64_movzx8_rr(A, RCX, RCX);
        x64_and_rr(A, RAX, RCX);   /* and leaves ZF: false */
        ms_set_reg(M, d, T_CON0, RAX);
        break;

    case PRIM_char_ord: ms_check_tag(M, x, T_CHAR, slow); ms_load_payload(M, RAX, x); ms_set_reg(M, d, T_INT, RAX); break;
    case PRIM_char_lt: two(j, x, y, T_CHAR, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_L); break;
    case PRIM_char_le: two(j, x, y, T_CHAR, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_LE); break;
    case PRIM_char_gt: two(j, x, y, T_CHAR, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_G); break;
    case PRIM_char_ge: two(j, x, y, T_CHAR, slow); x64_cmp_rr(A, RAX, RCX); set_bool(j, d, CC_GE); break;
    case PRIM_char_order: two(j, x, y, T_CHAR, slow); x64_cmp_rr(A, RAX, RCX); set_order(j, d, CC_GE, CC_G); break;

    case PRIM_string_size: length_of(j, d, x, K_STRING, slow); break;
    case PRIM_string_sub:
        ms_load_obj(M, RAX, x, K_STRING, slow);
        index_of(j, y, slow);
        x64_add_rr(A, RAX, RCX);
        x64_movzx8_rm(A, RCX, RAX, (int32_t)sizeof(Obj));
        ms_set_reg(M, d, T_CHAR, RCX);
        break;
    case PRIM_ref_get: ms_load_obj(M, RAX, x, K_REF, slow); ms_load_value(M, d, RAX, (int32_t)sizeof(Obj)); break;
    case PRIM_ref_set:
        ms_load_obj(M, RAX, x, K_REF, slow);
        ms_store_field(M, RAX, 0, y);
        ms_set(M, d, T_UNIT, 0);
        break;
    case PRIM_array_length: length_of(j, d, x, K_ARRAY, slow); break;
    case PRIM_array_sub:
        ms_load_obj(M, RAX, x, K_ARRAY, slow);
        index_of(j, y, slow);
        element(j);
        ms_load_value(M, d, RAX, (int32_t)sizeof(Obj));
        break;
    case PRIM_array_update:
        ms_load_obj(M, RAX, x, K_ARRAY, slow);
        index_of(j, y, slow);
        element(j);
        ms_store_value(M, RAX, (int32_t)sizeof(Obj), z);   /* where a barrier goes, for an element */
        ms_set(M, d, T_UNIT, 0);
        break;
    case PRIM_vector_length: length_of(j, d, x, K_TUPLE, slow); break;
    case PRIM_vector_sub:
        ms_load_obj(M, RAX, x, K_TUPLE, slow);
        index_of(j, y, slow);
        element(j);
        ms_load_value(M, d, RAX, (int32_t)sizeof(Obj));
        break;
    }
    x64_bind(A, &M->slow[which].back);
    /* a comparison leaves its bool in the flags, for the branch after
       (M7): said to the walk, and to its slow path */
    switch (p) {
    case PRIM_poly_eq: case PRIM_imm_eq:
    case PRIM_int_lt: case PRIM_int_le: case PRIM_int_gt: case PRIM_int_ge:
    case PRIM_word_lt: case PRIM_word_le: case PRIM_word_gt: case PRIM_word_ge:
    case PRIM_real_lt: case PRIM_real_le: case PRIM_real_gt: case PRIM_real_ge: case PRIM_real_eq:
    case PRIM_char_lt: case PRIM_char_le: case PRIM_char_gt: case PRIM_char_ge:
        j->flags_for = d;
        M->slow[which].c = 1;
        break;
    default: break;
    }
    return 1;
}
#undef PAY
#undef TAGOF

/* a primitive not done in line, called as the loop calls it (M7): its
   arguments pushed above the registers, the VM exact, the primitive's own
   C, and the result it left on the stack taken into d; after a raise, on
   in the handler's code where it has some (the handler a raise pops is
   still at hp), else the interpreter, which finds its code if any */
void emit_PRIM(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) {
    (void)pc;
    if (prim_inline(j, a, b, L, n)) return;
    X64Label raised, hand, done; x64_label_init(&raised); x64_label_init(&hand); x64_label_init(&done);
    if (j->jit->prim_calls) {   /* --jit-stats: the count of calls of this primitive */
        x64_mov_ri(A, RAX, (int64_t)(intptr_t)&j->jit->prim_calls[a]);
        x64_add_mi(A, RAX, 0, 1);
    }
    for (uint32_t i = 0; i < n; i++) {
        x64_movups_xm(A, XMM0, BASER, 16 * read_i32(L + 4 * i));
        x64_movups_mx(A, BASER, (int32_t)(16 * (j->m.nlocals + i)), XMM0);
    }
    ms_sync(M, j->next, (int)n);
    ms_call(M, (MsHelper)prim_table[a]);
    ms_reload(M);
    x64_cmp_ri(A, RAX, 1);
    x64_jcc(A, CC_E, &raised);
    x64_test_rr(A, RAX, RAX);
    x64_jcc(A, CC_NE, jit_fatal(j, FATAL_NEW_WORLD, 0, 0, 0));
    x64_movups_xm(A, XMM0, BASER, (int32_t)(16 * j->m.nlocals));
    x64_movups_mx(A, BASER, 16 * b, XMM0);
    x64_jmp(A, &done);
    x64_bind(A, &raised);
    x64_mov_rm(A, RCX, VMR, OFF(hp));
    x64_mov_ri(A, RAX, (int64_t)sizeof(Handler));
    x64_imul_rr(A, RCX, RAX);
    x64_add_rm(A, RCX, VMR, OFF(handlers));
    x64_mov_rm(A, RAX, RCX, (int32_t)offsetof(Handler, native));
    x64_test_rr(A, RAX, RAX);
    x64_jcc(A, CC_E, &hand);
    x64_jmp_r(A, RAX);
    x64_bind(A, &hand);
    ms_handback(M, RUN_INTERP);
    x64_bind(A, &done);
    x64_label_free(&raised); x64_label_free(&hand); x64_label_free(&done);
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
/* a branch on the bool a comparison just left in the flags (M7): no tag
   test, since the comparison made it, and no load */
void emit_JUMPIF(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    if (j->flags_prev == a) { x64_jcc(A, CC_NE, jit_label(j, (uint32_t)b)); return; }
    ms_check_tag(M, a, T_CON0, jit_fatal(j, FATAL_JUMPIF, 0, 0, 0));
    x64_cmp_mi(A, BASER, SLOT(a) + 8, 0);
    x64_jcc(A, CC_NE, jit_label(j, (uint32_t)b));
}
void emit_JUMPIFNOT(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    if (j->flags_prev == a) { x64_jcc(A, CC_E, jit_label(j, (uint32_t)b)); return; }
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
    /* straight into the callee's code where it has some (M7): a call to
       this very function to its entry's label, another's by a jump to
       its address, which makes this function go when that one is
       invalidated (jit_depend) */
    if (f == j->f) { x64_jmp(A, jit_label(j, fn->code_offset)); return; }
    const void *entry = j->jit->codes[f].entry;
    if (entry) {
        jit_depend(j->jit, f, j->f);
        x64_jmp_to(A, entry);
        return;
    }
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
/* the register of the RESULT at pc, if that is one: where a frame pushed
   by a call at that pc returns to (-1: none) */
static int32_t result_at(Jit *j, uint32_t pc) {
    const uint8_t *code = j->vm->prog.code;
    return pc < j->vm->prog.code_len && code[pc] == ROP_RESULT ? read_i32(code + pc + 1) : -1;
}
static void push_frame(Jit *j, uint32_t f, int32_t ret_pc, X64Label *after) {
    x64_mov_rm(A, RCX, VMR, OFF(frames));
    x64_lea(A, R8, RAX, RAX, 4, 0);   /* FRAME_SIZE, 40: 5 rax, then 8 times */
    x64_shl_ri(A, R8, 3);
    x64_add_rr(A, RCX, R8);
    x64_mov32_mi(A, RCX, FR(func), (int32_t)f);
    x64_mov32_mi(A, RCX, FR(ret_pc), ret_pc);
    x64_mov32_mi(A, RCX, FR(result), result_at(j, (uint32_t)ret_pc));
    x64_mov_mr(A, RCX, FR(base), RDX);
    x64_mov_mi(A, RCX, FR(closure), 0);
    x64_lea_rip(A, R8, after);
    x64_mov_mr(A, RCX, FR(native_ret), R8);
    x64_mov_mr(A, VMR, OFF(fp), RAX);
}
/* the registers of a callee at r9: its n arguments from the list, the
   rest unit */
static void make_registers(Jit *j, uint32_t n, const uint8_t *L, uint32_t nlocals, uint32_t fill_from) {
    for (uint32_t i = 0; i < n; i++) {
        x64_movups_xm(A, XMM0, BASER, 16 * read_i32(L + 4 * i));
        x64_movups_mx(A, R9, (int32_t)(16 * i), XMM0);
    }
    /* unit into the registers the callee does not write before anything
       could see them (jit_fill_from, M7) */
    if (fill_from < n) fill_from = n;
    if (nlocals > fill_from) {
        x64_xorpd(A, XMM1, XMM1);   /* unit: tag 0, payload 0 */
        for (uint32_t i = fill_from; i < nlocals; i++) x64_movups_mx(A, R9, (int32_t)(16 * i), XMM1);
    }
}

void emit_CALLK(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) {
    (void)pc; (void)b;
    const Function *fn = &j->vm->prog.funcs[a];
    X64Label *after = jit_label(j, j->next + 5);   /* past the RESULT */
    room(j, j->m.nlocals + fn->nlocals + fn->maxstack);
    frame_room(j);
    x64_lea(A, R9, BASER, -1, 1, (int32_t)(16 * j->m.nlocals));
    make_registers(j, n, L, fn->nlocals, jit_fill_from(j->vm, j->jit, (uint32_t)a));
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
    {
        uint32_t from = jit_fill_from(j->vm, j->jit, (uint32_t)a);
        if (from < n) from = n;
        if (fn->nlocals > from) {
            x64_xorpd(A, XMM1, XMM1);
            for (uint32_t i = from; i < fn->nlocals; i++) x64_movups_mx(A, BASER, (int32_t)(16 * i), XMM1);
        }
    }
    ms_frame(M, RCX);
    x64_mov32_mi(A, RCX, FR(func), a);
    x64_mov_mi(A, RCX, FR(closure), 0);
    to_callee(j, (uint32_t)a, fn);
}
/* ---- calls through a closure, in line (M7) ---- */

/* A call through a closure, as the loop does it (src/isa/regs.sml, CALL
   and TAILCALL), in line: the closure checked, the function it names
   found, the room made (a slow path grows the stack and comes back to the
   start, since growing clobbers what was found; another grows the
   frames), the callee's registers made and the frame pushed (or, for a
   tail call, replaced), and the callee's entry, read from its code
   object, jumped to -- or, where it has none, the VM made exact for the
   interpreter and handed back. */

/* obj := the closure in register a; r11 := the index of its function,
   checked; rcx := that Function */
static void closure_function(Jit *j, int32_t a, int obj) {
    const Program *p = &j->vm->prog;
    ms_load_obj(M, obj, a, K_CLOSURE, jit_fatal(j, FATAL_CALL, 0, 0, 0));
    x64_mov_rm(A, R11, obj, (int32_t)sizeof(Obj) + 8);   /* field 0: the index */
    x64_cmp_ri(A, R11, (int32_t)p->nfuncs);
    x64_jcc(A, CC_AE, jit_fatal(j, FATAL_FUNCTION, 0, 0, 0));   /* unsigned: negative too */
    x64_lea(A, RCX, R11, R11, 2, 0);                      /* 3 r11 */
    x64_shl_ri(A, RCX, 3);                                /* 24 r11: sizeof(Function) */
    x64_mov_ri(A, R8, (int64_t)(intptr_t)p->funcs);
    x64_add_rr(A, RCX, R8);
}
/* the slow path that grows the stack and starts the instruction over,
   made first: its back label is the instruction's start (after the run's
   count, which a restart must not add again), and nothing may be live
   across a restart */
static int grow_slow(Jit *j) {
    Slow *s = ms_slow(M, SLOW_GROW_RAX, j->next);
    if (!s) return -1;
    int which = M->nslow - 1;
    x64_bind(A, &M->slow[which].back);
    return which;
}
/* the room a frame of the Function in rcx needs at base (an index in
   base_reg), or the slow path (which) that grows the stack, the need in rax */
static void room_dynamic(Jit *j, int which, int base_reg) {
    x64_mov32_rm(A, RAX, RCX, (int32_t)offsetof(Function, nlocals));
    x64_mov32_rm(A, R8, RCX, (int32_t)offsetof(Function, maxstack));
    x64_add_rr(A, RAX, R8);
    x64_add_rr(A, RAX, base_reg);
    x64_cmp_rm(A, RAX, VMR, OFF(stack_cap));
    x64_jcc(A, CC_A, &M->slow[which].here);
}
/* the callee's registers at r9: register 0 from register arg, the rest
   unit; the callee's nlocals in r8 */
static void make_registers_dynamic(Jit *j, int32_t arg) {
    X64Label loop, done; x64_label_init(&loop); x64_label_init(&done);
    x64_movups_xm(A, XMM0, BASER, 16 * arg);
    x64_movups_mx(A, R9, 0, XMM0);
    x64_xorpd(A, XMM1, XMM1);
    /* from the first register the callee does not write before anything
       could see it (jit_fill_from, M7), and at least the second */
    X64Label ok; x64_label_init(&ok);
    x64_mov_ri(A, RAX, (int64_t)(intptr_t)j->jit->fill_from);
    x64_lea(A, RAX, RAX, R11, 4, 0);
    x64_mov32_rm(A, RAX, RAX, 0);
    x64_cmp_ri(A, RAX, 1);
    x64_jcc(A, CC_AE, &ok);
    x64_mov_ri(A, RAX, 1);
    x64_bind(A, &ok);
    x64_label_free(&ok);
    x64_shl_ri(A, RAX, 4);
    x64_add_rr(A, RAX, R9);                    /* the first to fill */
    x64_mov_rr(A, RDI, R8);                    /* (rdx holds the frame's base) */
    x64_shl_ri(A, RDI, 4);
    x64_add_rr(A, RDI, R9);                    /* past the last */
    x64_bind(A, &loop);
    x64_cmp_rr(A, RAX, RDI);
    x64_jcc(A, CC_AE, &done);
    x64_movups_mx(A, RAX, 0, XMM1);
    x64_add_ri(A, RAX, 16);
    x64_jmp(A, &loop);
    x64_bind(A, &done);
    x64_label_free(&loop); x64_label_free(&done);
}
/* into the callee whose Function is in rcx and whose index is in r11, the
   frame's rbp and r14 already its own: its code where it has some, else
   the interpreter, the VM made exact for it */
static void to_callee_dynamic(Jit *j) {
    X64Label interp; x64_label_init(&interp);
    x64_mov_ri(A, RAX, (int64_t)sizeof(CodeObject));
    x64_imul_rr(A, RAX, R11);
    x64_mov_ri(A, R8, (int64_t)(intptr_t)j->jit->codes);
    x64_add_rr(A, RAX, R8);
    x64_mov_rm(A, RAX, RAX, (int32_t)offsetof(CodeObject, entry));
    x64_test_rr(A, RAX, RAX);
    x64_jcc(A, CC_E, &interp);
    x64_jmp_r(A, RAX);
    x64_bind(A, &interp);
    x64_mov32_rm(A, RAX, RCX, (int32_t)offsetof(Function, code_offset));
    x64_mov32_mr(A, VMR, OFF(pc), RAX);
    x64_mov32_rm(A, RAX, RCX, (int32_t)offsetof(Function, nlocals));
    x64_add_rr(A, RAX, BASEI);
    x64_mov_mr(A, VMR, OFF(sp), RAX);
    x64_mov_mr(A, VMR, OFF(instructions), COUNTR);
    ms_handback(M, RUN_INTERP);
    x64_label_free(&interp);
}
void emit_CALL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    X64Label *after = jit_label(j, j->next + 5);   /* past the RESULT */
    int grow = grow_slow(j);
    if (grow < 0) return;
    /* the frames first: their slow path comes back to its check with the
       registers clobbered, so nothing may be live across it */
    frame_room(j);
    closure_function(j, a, R10);
    x64_lea(A, RDX, BASEI, -1, 1, (int32_t)j->m.nlocals);   /* the callee's base */
    room_dynamic(j, grow, RDX);
    /* the callee's registers above the frame */
    x64_mov32_rm(A, R8, RCX, (int32_t)offsetof(Function, nlocals));
    x64_lea(A, R9, BASER, -1, 1, (int32_t)(16 * j->m.nlocals));
    make_registers_dynamic(j, b);
    /* the frame: function r11, closure r10, base rdx, returning to after */
    x64_mov_rm(A, RAX, VMR, OFF(fp));
    x64_add_ri(A, RAX, 1);
    x64_mov_rm(A, RSI, VMR, OFF(frames));
    x64_lea(A, RDI, RAX, RAX, 4, 0);   /* sizeof(Frame), 40 */
    x64_shl_ri(A, RDI, 3);
    x64_add_rr(A, RSI, RDI);
    x64_mov32_mr(A, RSI, (int32_t)offsetof(Frame, func), R11);
    x64_mov32_mi(A, RSI, (int32_t)offsetof(Frame, ret_pc), (int32_t)j->next);
    x64_mov32_mi(A, RSI, (int32_t)offsetof(Frame, result), result_at(j, j->next));
    x64_mov_mr(A, RSI, (int32_t)offsetof(Frame, base), RDX);
    x64_mov_mr(A, RSI, (int32_t)offsetof(Frame, closure), R10);
    x64_lea_rip(A, RDI, after);
    x64_mov_mr(A, RSI, (int32_t)offsetof(Frame, native_ret), RDI);
    x64_mov_mr(A, VMR, OFF(fp), RAX);
    x64_mov_rr(A, BASEI, RDX);
    x64_mov_rr(A, BASER, R9);
    to_callee_dynamic(j);
}
void emit_TAILCALL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    int grow = grow_slow(j);
    if (grow < 0) return;
    closure_function(j, a, R10);
    room_dynamic(j, grow, BASEI);
    /* the callee's registers are this frame's, from its base */
    x64_mov32_rm(A, R8, RCX, (int32_t)offsetof(Function, nlocals));
    x64_mov_rr(A, R9, BASER);
    make_registers_dynamic(j, b);
    /* the frame replaced: its function and closure; its return kept */
    ms_frame(M, RSI);
    x64_mov32_mr(A, RSI, (int32_t)offsetof(Frame, func), R11);
    x64_mov_mr(A, RSI, (int32_t)offsetof(Frame, closure), R10);
    to_callee_dynamic(j);
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
    X64Label no_result, go, interp; x64_label_init(&no_result); x64_label_init(&go); x64_label_init(&interp);
    Slow *s = ms_slow(M, SLOW_RET, j->next);
    if (!s) return;
    s->a = a;
    x64_mov_rm(A, RDX, VMR, OFF(fp));
    x64_test_rr(A, RDX, RDX);
    x64_jcc(A, CC_E, &s->here);
    /* the frame: rcx; what it kept: where the caller's code goes on, the
       register of its RESULT (M7), the callee's base (the caller's stack top) */
    x64_lea(A, RCX, RDX, RDX, 4, 0);
    x64_shl_ri(A, RCX, 3);
    x64_add_rm(A, RCX, VMR, OFF(frames));
    x64_movups_xm(A, XMM0, BASER, 16 * a);
    x64_mov_rm(A, R9, RCX, FR(native_ret));
    x64_movsxd_rmi(A, R8, RCX, -1, 1, FR(result));
    x64_mov_rm(A, R10, RCX, FR(base));
    x64_sub_ri(A, RDX, 1);
    x64_mov_mr(A, VMR, OFF(fp), RDX);   /* the frame popped */
    x64_sub_ri(A, RCX, FRAME_SIZE);      /* the caller's frame: its registers are the code's now */
    x64_mov_rm(A, BASEI, RCX, FR(base));
    x64_mov_rr(A, BASER, BASEI);
    x64_shl_ri(A, BASER, 4);
    x64_add_rr(A, BASER, STACKR);
    x64_test_rr(A, R9, R9);
    x64_jcc(A, CC_E, &interp);
    /* into the caller's code, which has a RESULT (its phantom): the value
       into its register, and on past it */
    x64_shl_ri(A, R8, 4);
    x64_movups_mix(A, BASER, R8, 1, 0, XMM0);
    x64_jmp_r(A, R9);
    x64_bind(A, &interp);
    /* the interpreter goes on: at the RESULT's register and past it, or
       with the value on the stack, as an image resumed at RESULT takes it */
    x64_mov32_rm(A, RAX, RCX, FRAME_SIZE + FR(ret_pc));
    x64_cmp_ri(A, R8, -1);
    x64_jcc(A, CC_E, &no_result);
    x64_shl_ri(A, R8, 4);
    x64_movups_mix(A, BASER, R8, 1, 0, XMM0);
    x64_add_ri(A, RAX, 5);
    x64_jmp(A, &go);
    x64_bind(A, &no_result);
    x64_mov_rr(A, RDX, R10);
    x64_shl_ri(A, RDX, 4);
    x64_movups_mix(A, STACKR, RDX, 1, 0, XMM0);
    x64_add_ri(A, R10, 1);
    x64_bind(A, &go);
    x64_mov32_mr(A, VMR, OFF(pc), RAX);
    x64_mov_mr(A, VMR, OFF(sp), R10);
    x64_mov_mr(A, VMR, OFF(instructions), COUNTR);
    ms_handback(M, RUN_INTERP);
    x64_label_free(&no_result); x64_label_free(&go); x64_label_free(&interp);
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
