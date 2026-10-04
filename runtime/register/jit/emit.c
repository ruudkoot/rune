/* The emitters of tier 1 (docs/plans/jit.md, M4): one per instruction of
   the register bytecode, doing what the instruction's case in runtime/register's
   loop does (src/isa/regs.sml), in the loop's frame, with every value in
   its slot, over the macro-assembler (masm.h). The generated jit_cases.h
   reads each instruction's operands and calls its emitter, and jit_emit.h
   has the prototypes, so an instruction without an emitter does not
   build. `next` is the pc after the instruction, which the VM's pc is made
   before any call into C; a run is counted where it begins (compile.c). */
#include "compile.h"
#include "register/jit_emit.h"

#define M (&j->m)
#define A (&j->m.a)
#define OFF(field) ((int32_t)offsetof(VM, field))

void emit_HALT(Jit *j, uint32_t pc) {
    (void)pc;
    ms_sync(M, j->next, 0);
    ms_handback(M, RUN_HALT);
}
void emit_MOVE(Jit *j, uint32_t pc, int32_t a, int32_t b) { (void)pc; ms_move(M, a, b); }
void emit_INT(Jit *j, uint32_t pc, int32_t a, int32_t b) { (void)pc; ms_set(M, a, T_INT, b); }
void emit_CONST(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
#if !RUNE_VALUE_HDR
    /* a real constant into a home that holds the double: decoded here, once */
    if (ms_real_home(M, a) && j->vm && (uint32_t)b < j->vm->prog.nconsts) {
        ms_set_real_known(M, a, real_bits(val_real(j->vm->prog.consts[b])));
        return;
    }
#endif
    as_ld64(A, R_S0, VMR, OFF(prog.consts));
    ms_load_nth(M, a, R_S0, (uint32_t)b);
}
void emit_UNIT(Jit *j, uint32_t pc, int32_t a) { (void)pc; ms_set(M, a, T_UNIT, 0); }
void emit_CON0(Jit *j, uint32_t pc, int32_t a, int32_t b) { (void)pc; ms_set(M, a, T_CON0, b); }
void emit_GLOBAL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    as_ld64(A, R_S0, VMR, OFF(global_set));
    as_cmp8_mi(A, R_S0, b, 0);
    as_jcc(A, CC_E, jit_fatal(j, FATAL_GLOBAL_UNSET, b, 0, 0));
    as_ld64(A, R_S0, VMR, OFF(globals));
    ms_load_nth(M, a, R_S0, (uint32_t)b);
}
void emit_SETGLOBAL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    ms_need_word(M, b);
    as_ld64(A, R_S0, VMR, OFF(globals));
    ms_store_nth(M, R_S0, (uint32_t)a, b);
    as_ld64(A, R_S0, VMR, OFF(global_set));
    as_st8i(A, R_S0, a, 1);
}
/* rax := the frame's closure, or the fatal error */
static void closure(Jit *j, int what) {
    ms_frame(M, R_S1);
    as_ld64(A, R_S0, R_S1, (int32_t)offsetof(Frame, closure));
    as_test_rr(A, R_S0, R_S0);
    as_jcc(A, CC_E, jit_fatal(j, what, 0, 0, 0));
}
void emit_ENV(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    closure(j, FATAL_ENV_RANGE);
    ms_need_len(M, R_S0, (uint32_t)b + 1, jit_fatal(j, FATAL_ENV_RANGE, b, 0, 0));
    ms_load_field(M, a, R_S0, (uint32_t)b + 1);
}
void emit_SELF(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    closure(j, FATAL_SELF);
    ms_set_reg(M, a, T_PTR, R_S0);
}
/* ---- primitives in line (M7) ---- */

/* The common case of the primitives the loop does in line (fastprim.h),
   as code: exactly what prim_fast gives, and to the slow path -- the
   helper, which does the primitive as the loop would, and may raise --
   wherever prim_fast would answer 0: a tag that is not the one, an
   overflow, a divisor of 0 or -1, an index out of bounds, a real or a
   pointer under `=`. Every argument is read before the result is written,
   since the result's register may be one of them. */

/* the bool of the flags into d */
static void set_bool(Jit *j, int32_t d, int cc) {
    as_setcc(A, R_S0, cc);
    ms_set_reg(M, d, T_CON0, R_S0);
    ms_bool_flags(M, R_S0);   /* and back into the flags (ZF: false), for a branch fused onto it */
}
/* LESS, EQUAL or GREATER (0, 1, 2) of the flags into d: ge + g */
static void set_order(Jit *j, int32_t d, int cc_ge, int cc_g) {
    as_setcc(A, R_S0, cc_ge);
    as_setcc(A, R_S1, cc_g);
    as_add_rr(A, R_S0, R_S1);
    ms_set_reg(M, d, T_CON0, R_S0);
}
/* the two arguments, immediates of one tag, as their words in rax and rcx:
   what a comparison compares, and what the arithmetic of masm.h takes */
static void two(Jit *j, int32_t x, int32_t y, int tag, AsmLabel *slow) { ms_two_imm(M, x, y, tag, slow); }
/* the same as their payloads: what a division divides */
static void two_payloads(Jit *j, int32_t x, int32_t y, int tag, AsmLabel *slow) {
    ms_two_imm(M, x, y, tag, slow);
    ms_untag(M, R_S0, tag);
    ms_untag(M, R_S1, tag);
}
/* the two real arguments into xmm0 and xmm1 (or the other way round) */
static void two_real(Jit *j, int32_t x, int32_t y, AsmLabel *slow) {
    ms_load_real(M, F_S0, x, slow);
    ms_load_real(M, F_S1, y, slow);
}
static void set_real(Jit *j, int32_t d, AsmLabel *slow) { ms_set_real(M, d, F_S0, slow); }
/* rcx := the index in y, checked against the length of the object in rax */
static void index_of(Jit *j, int32_t y, AsmLabel *slow) {
    ms_check_tag(M, y, T_INT, slow);
    ms_load_payload(M, R_S1, y);
    ms_load_len(M, R_S3, R_S0);
    as_cmp_rr(A, R_S1, R_S3);
    as_jcc(A, CC_AE, slow);   /* unsigned: a negative index is out too */
}
/* the length of the object of kind k in x, as an int, into d */
static void length_of(Jit *j, int32_t d, int32_t x, int k, AsmLabel *slow) {
    ms_load_obj(M, R_S0, x, k, slow);
    ms_load_len(M, R_S1, R_S0);
    ms_set_payload(M, d, T_INT, R_S1, slow);
}
/* rax := the address of element rcx of the object in rax (16 bytes each) */
static void element(Jit *j) {
    ms_scale_index(M, R_S1);
    as_add_rr(A, R_S0, R_S1);
}
/* int_div and int_mod after cqo; idiv: the quotient in rax, the
   remainder in rdx, the divisor in rcx; floor where the signs differ */
static void floor_div(Jit *j, int mod) {
    AsmLabel done; as_label_init(&done);
    as_test_rr(A, R_S2, R_S2);
    as_jcc(A, CC_E, &done);
    as_mov_rr(A, R_S3, R_S2);
    as_xor_rr(A, R_S3, R_S1);
    as_test_rr(A, R_S3, R_S3);   /* the sign of the xor: the flags */
    as_jcc(A, CC_NS, &done);
    if (mod) as_add_rr(A, R_S2, R_S1); else as_sub_ri(A, R_S0, 1);
    as_bind(A, &done);
    as_label_free(&done);
}
/* `=` on two immediates: their words the same. A value in the heap is the
   helper's for poly_eq, which walks it, and the primitive's own C for
   imm_eq, which the compiler gives only what is never there (under
   RUNE_INT64 the box of an int past 63 bits). */
static void equal(Jit *j, int32_t d, int32_t x, int32_t y, int poly, AsmLabel *slow) {
    if (!(ms_number(M, x) && ms_number(M, x) == ms_number(M, y))) {
        ms_need_word(M, x);
        ms_need_word(M, y);
    }
    /* two values of one representation that is an immediate (tier 2,
       M10): the words alone */
    if (ms_immediate(M, x) && ms_immediate(M, y)) {
        ms_load_bits(M, R_S0, x);
        ms_cmp_bits(M, R_S0, y);
        set_bool(j, d, CC_E);
        return;
    }
    /* two numbers of 64 bits by the section (an Int64.int, a Word64.word;
       an int or a word where the VM keeps 64 bits): the bits, which two
       boxes of one number have and two words of them do not */
    if (ms_number(M, x) && ms_number(M, x) == ms_number(M, y)) {
        int tag = ms_number(M, x);   /* each as what it is: an int's payload is signed */
        if (tag == T_INT64 || tag == T_WORD64) ms_two_num64(M, x, y, tag, slow); else ms_two_imm(M, x, y, tag, slow);
        as_cmp_rr(A, R_S0, R_S1);
        set_bool(j, d, CC_E);
        return;
    }
    AsmLabel done, heap; as_label_init(&done); as_label_init(&heap);
    /* Structural comparison may stop at its work limit, so its helper
       needs the exact VM for the fatal error and its trace. */
    ms_two_words(M, x, y, poly ? &heap : slow);
    as_cmp_rr(A, R_S0, R_S1);
    set_bool(j, d, CC_E);
    if (poly) {
        as_jmp(A, &done);
        as_bind(A, &heap);
        ms_sync(M, j->next, 0);
        ms_slot_addr(M, ms_arg(M, 1), x);
        ms_slot_addr(M, ms_arg(M, 2), y);
        ms_call(M, (MsHelper)jit_h_values_equal);
        ms_reload(M);
        ms_set_reg(M, d, T_CON0, R_S0);
        ms_bool_flags(M, R_S0);
    }
    as_bind(A, &done);
    as_label_free(&done); as_label_free(&heap);
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
    case PRIM_int64_add: case PRIM_int64_sub: case PRIM_int64_mul: case PRIM_int64_div: case PRIM_int64_mod:
    case PRIM_int64_quot: case PRIM_int64_rem: case PRIM_int64_neg: case PRIM_int64_lt: case PRIM_int64_le:
    case PRIM_int64_gt: case PRIM_int64_ge: case PRIM_int64_order:
    case PRIM_word64_add: case PRIM_word64_sub: case PRIM_word64_mul: case PRIM_word64_div: case PRIM_word64_mod:
    case PRIM_word64_lt: case PRIM_word64_le: case PRIM_word64_gt: case PRIM_word64_ge: case PRIM_word64_order:
    case PRIM_word64_andb: case PRIM_word64_orb: case PRIM_word64_xorb: case PRIM_word64_notb:
    case PRIM_word64_lsl: case PRIM_word64_lsr: case PRIM_word64_to_int64: case PRIM_word64_from_int64:
#ifndef RUNE_INT64
    /* between the 64 bits and an int's or a word's 63: where those are 64 too
       (RUNE_INT64) the primitive's C does them */
    case PRIM_int64_to_int: case PRIM_int64_from_int: case PRIM_word64_to_int: case PRIM_word64_to_int_x:
    case PRIM_word64_from_int: case PRIM_word64_to_word: case PRIM_word64_from_word: case PRIM_word64_from_word_x:
#endif
    case PRIM_real_add: case PRIM_real_sub: case PRIM_real_mul: case PRIM_real_div: case PRIM_real_neg: case PRIM_real_sqrt:
    case PRIM_real_lt: case PRIM_real_le: case PRIM_real_gt: case PRIM_real_ge: case PRIM_real_eq:
    case PRIM_char_ord: case PRIM_char_lt: case PRIM_char_le: case PRIM_char_gt: case PRIM_char_ge: case PRIM_char_order:
    case PRIM_string_size: case PRIM_string_sub: case PRIM_ref_get: case PRIM_ref_set:
    case PRIM_array_length: case PRIM_array_sub: case PRIM_array_update: case PRIM_vector_length: case PRIM_vector_sub:
    case PRIM_bytes_length: case PRIM_bytes_sub: case PRIM_bytes_update:
    case PRIM_reals_length: case PRIM_reals_sub: case PRIM_reals_update:
        break;
    default:
        return 0;
    }
    /* the slow path: the helper; its index, since nothing here adds another */
    Slow *s = ms_slow(M, SLOW_PRIM, j->next);
    if (!s) return 1;
    s->a = p; s->b = d; s->L = L;
    int which = M->nslow - 1;
    AsmLabel *slow = &M->slow[which]->here;
    switch (p) {
    case PRIM_poly_eq: equal(j, d, x, y, 1, slow); break;
    case PRIM_imm_eq: equal(j, d, x, y, 0, slow); break;
    case PRIM_string_order:
        /* the two strings to the lean helper, which touches nothing of the
           VM: no sync, no reload */
        ms_writeback(M, M->cur_pc);
        ms_load_obj(M, ms_arg(M, 1), x, K_STRING, slow);
        ms_load_obj(M, ms_arg(M, 2), y, K_STRING, slow);
        ms_call_lean(M, (MsHelper)jit_h_string_order);
        ms_set_reg(M, d, T_CON0, R_S0);
        break;
    case PRIM_ref_new:
        alloc(j, K_REF, 0, 1, FILL_ONE, d, x, 0, NULL);
        break;

    case PRIM_int_add: two(j, x, y, T_INT, slow); ms_int_arith(M, MS_ADD, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_int_sub: two(j, x, y, T_INT, slow); ms_int_arith(M, MS_SUB, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_int_mul: two(j, x, y, T_INT, slow); ms_int_arith(M, MS_MUL, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_int_div: case PRIM_int_mod: case PRIM_int_quot: case PRIM_int_rem:
        two_payloads(j, x, y, T_INT, slow);
        as_test_rr(A, R_S1, R_S1);
        as_jcc(A, CC_E, slow);
        as_cmp_ri(A, R_S1, -1);
        as_jcc(A, CC_E, slow);
        as_divmod(A, R_S1);
        /* the remainder out of R_S2, which giving a slot its word uses */
        if (p == PRIM_int_div) { floor_div(j, 0); ms_set_payload(M, d, T_INT, R_S0, slow); }
        else if (p == PRIM_int_mod) { floor_div(j, 1); as_mov_rr(A, R_S0, R_S2); ms_set_payload(M, d, T_INT, R_S0, slow); }
        else if (p == PRIM_int_quot) ms_set_payload(M, d, T_INT, R_S0, slow);
        else { as_mov_rr(A, R_S0, R_S2); ms_set_payload(M, d, T_INT, R_S0, slow); }
        break;
    case PRIM_int_neg: ms_one_imm(M, x, T_INT, slow); ms_int_neg(M, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_int_lt: two(j, x, y, T_INT, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_L); break;
    case PRIM_int_le: two(j, x, y, T_INT, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_LE); break;
    case PRIM_int_gt: two(j, x, y, T_INT, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_G); break;
    case PRIM_int_ge: two(j, x, y, T_INT, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_GE); break;
    case PRIM_int_order: two(j, x, y, T_INT, slow); as_cmp_rr(A, R_S0, R_S1); set_order(j, d, CC_GE, CC_G); break;
    case PRIM_int_to_char: ms_one_imm(M, x, T_INT, slow); ms_int_to_char(M, slow); ms_set_num(M, d, T_CHAR, R_S0, slow); break;

    case PRIM_word_add: two(j, x, y, T_WORD, slow); ms_word_arith(M, MS_ADD, slow); ms_set_num(M, d, T_WORD, R_S0, slow); break;
    case PRIM_word_sub: two(j, x, y, T_WORD, slow); ms_word_arith(M, MS_SUB, slow); ms_set_num(M, d, T_WORD, R_S0, slow); break;
    case PRIM_word_mul: two(j, x, y, T_WORD, slow); ms_word_arith(M, MS_MUL, slow); ms_set_num(M, d, T_WORD, R_S0, slow); break;
    case PRIM_word_div: case PRIM_word_mod:
        two_payloads(j, x, y, T_WORD, slow);
        as_test_rr(A, R_S1, R_S1);
        as_jcc(A, CC_E, slow);
        as_udivmod(A, R_S1);
        if (p == PRIM_word_mod) as_mov_rr(A, R_S0, R_S2);
        ms_set_payload(M, d, T_WORD, R_S0, slow);
        break;
    case PRIM_word_lt: two(j, x, y, T_WORD, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_B); break;
    case PRIM_word_le: two(j, x, y, T_WORD, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_BE); break;
    case PRIM_word_gt: two(j, x, y, T_WORD, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_A); break;
    case PRIM_word_ge: two(j, x, y, T_WORD, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_AE); break;
    case PRIM_word_order: two(j, x, y, T_WORD, slow); as_cmp_rr(A, R_S0, R_S1); set_order(j, d, CC_AE, CC_A); break;
    case PRIM_word_andb: two(j, x, y, T_WORD, slow); ms_word_arith(M, MS_AND, slow); ms_set_num(M, d, T_WORD, R_S0, slow); break;
    case PRIM_word_orb: two(j, x, y, T_WORD, slow); ms_word_arith(M, MS_OR, slow); ms_set_num(M, d, T_WORD, R_S0, slow); break;
    case PRIM_word_xorb: two(j, x, y, T_WORD, slow); ms_word_arith(M, MS_XOR, slow); ms_set_num(M, d, T_WORD, R_S0, slow); break;
    case PRIM_word_notb: ms_one_imm(M, x, T_WORD, slow); ms_word_not(M, slow); ms_set_num(M, d, T_WORD, R_S0, slow); break;
    case PRIM_word_lsl: case PRIM_word_lsr: {
        /* a count of 64 or more gives 0, where the machine would take it mod 64 */
        AsmLabel ok, done; as_label_init(&ok); as_label_init(&done);
        two_payloads(j, x, y, T_WORD, slow);
        as_cmp_ri(A, R_S1, 64);
        as_jcc(A, CC_B, &ok);
        as_xor_rr(A, R_S0, R_S0);
        as_jmp(A, &done);
        as_bind(A, &ok);
        if (p == PRIM_word_lsl) as_shl_rr(A, R_S0); else as_shr_rr(A, R_S0);
        as_bind(A, &done);
        ms_set_payload(M, d, T_WORD, R_S0, slow);   /* a word of the word size, or the primitive's to box */
        as_label_free(&ok); as_label_free(&done);
        break;
    }
    case PRIM_word_to_int: ms_one_imm(M, x, T_WORD, slow); ms_word_to_int(M, 0, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_word_to_int_x: ms_one_imm(M, x, T_WORD, slow); ms_word_to_int(M, 1, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_word_from_int: ms_one_imm(M, x, T_INT, slow); ms_int_to_word(M, slow); ms_set_num(M, d, T_WORD, R_S0, slow); break;

    /* Int64.int and Word64.word: the arithmetic on the 64 bits themselves */
    case PRIM_int64_add: ms_two_num64(M, x, y, T_INT64, slow); ms_int64_arith(M, MS_ADD, slow); ms_set_num64(M, d, T_INT64, R_S0, slow); break;
    case PRIM_int64_sub: ms_two_num64(M, x, y, T_INT64, slow); ms_int64_arith(M, MS_SUB, slow); ms_set_num64(M, d, T_INT64, R_S0, slow); break;
    case PRIM_int64_mul: ms_two_num64(M, x, y, T_INT64, slow); ms_int64_arith(M, MS_MUL, slow); ms_set_num64(M, d, T_INT64, R_S0, slow); break;
    case PRIM_int64_div: case PRIM_int64_mod: case PRIM_int64_quot: case PRIM_int64_rem:
        ms_two_num64(M, x, y, T_INT64, slow);
        as_test_rr(A, R_S1, R_S1);
        as_jcc(A, CC_E, slow);
        as_cmp_ri(A, R_S1, -1);
        as_jcc(A, CC_E, slow);
        as_divmod(A, R_S1);
        if (p == PRIM_int64_div) floor_div(j, 0);
        else if (p == PRIM_int64_mod) { floor_div(j, 1); as_mov_rr(A, R_S0, R_S2); }
        else if (p == PRIM_int64_rem) as_mov_rr(A, R_S0, R_S2);
        ms_set_num64(M, d, T_INT64, R_S0, slow);
        break;
    case PRIM_int64_neg: ms_one_num64(M, x, T_INT64, slow); ms_int64_neg(M, slow); ms_set_num64(M, d, T_INT64, R_S0, slow); break;
    case PRIM_int64_lt: ms_two_num64(M, x, y, T_INT64, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_L); break;
    case PRIM_int64_le: ms_two_num64(M, x, y, T_INT64, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_LE); break;
    case PRIM_int64_gt: ms_two_num64(M, x, y, T_INT64, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_G); break;
    case PRIM_int64_ge: ms_two_num64(M, x, y, T_INT64, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_GE); break;
    case PRIM_int64_order: ms_two_num64(M, x, y, T_INT64, slow); as_cmp_rr(A, R_S0, R_S1); set_order(j, d, CC_GE, CC_G); break;

    case PRIM_word64_add: ms_two_num64(M, x, y, T_WORD64, slow); ms_word64_arith(M, MS_ADD); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
    case PRIM_word64_sub: ms_two_num64(M, x, y, T_WORD64, slow); ms_word64_arith(M, MS_SUB); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
    case PRIM_word64_mul: ms_two_num64(M, x, y, T_WORD64, slow); ms_word64_arith(M, MS_MUL); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
    case PRIM_word64_div: case PRIM_word64_mod:
        ms_two_num64(M, x, y, T_WORD64, slow);
        as_test_rr(A, R_S1, R_S1);
        as_jcc(A, CC_E, slow);
        as_udivmod(A, R_S1);
        if (p == PRIM_word64_mod) as_mov_rr(A, R_S0, R_S2);
        ms_set_num64(M, d, T_WORD64, R_S0, slow);
        break;
    case PRIM_word64_lt: ms_two_num64(M, x, y, T_WORD64, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_B); break;
    case PRIM_word64_le: ms_two_num64(M, x, y, T_WORD64, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_BE); break;
    case PRIM_word64_gt: ms_two_num64(M, x, y, T_WORD64, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_A); break;
    case PRIM_word64_ge: ms_two_num64(M, x, y, T_WORD64, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_AE); break;
    case PRIM_word64_order: ms_two_num64(M, x, y, T_WORD64, slow); as_cmp_rr(A, R_S0, R_S1); set_order(j, d, CC_AE, CC_A); break;
    case PRIM_word64_andb: ms_two_num64(M, x, y, T_WORD64, slow); ms_word64_arith(M, MS_AND); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
    case PRIM_word64_orb: ms_two_num64(M, x, y, T_WORD64, slow); ms_word64_arith(M, MS_OR); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
    case PRIM_word64_xorb: ms_two_num64(M, x, y, T_WORD64, slow); ms_word64_arith(M, MS_XOR); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
    case PRIM_word64_notb: ms_one_num64(M, x, T_WORD64, slow); ms_word64_not(M); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
    case PRIM_word64_lsl: case PRIM_word64_lsr: {
        /* the count is a word; 64 or more gives 0, where the machine would take it mod 64 */
        AsmLabel ok, done; as_label_init(&ok); as_label_init(&done);
        ms_one_num64(M, x, T_WORD64, slow);
        ms_shift_count(M, y, slow);
        as_cmp_ri(A, R_S1, 64);
        as_jcc(A, CC_B, &ok);
        as_xor_rr(A, R_S0, R_S0);
        as_jmp(A, &done);
        as_bind(A, &ok);
        if (p == PRIM_word64_lsl) as_shl_rr(A, R_S0); else as_shr_rr(A, R_S0);
        as_bind(A, &done);
        ms_set_num64(M, d, T_WORD64, R_S0, slow);
        as_label_free(&ok); as_label_free(&done);
        break;
    }
    /* the same 64 bits, read as the other type */
    case PRIM_word64_to_int64: ms_one_num64(M, x, T_WORD64, slow); ms_set_num64(M, d, T_INT64, R_S0, slow); break;
    case PRIM_word64_from_int64: ms_one_num64(M, x, T_INT64, slow); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
#ifndef RUNE_INT64
    case PRIM_int64_to_int: ms_one_num64(M, x, T_INT64, slow); ms_num64_as_int(M, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_int64_from_int: ms_one_imm(M, x, T_INT, slow); ms_untag(M, R_S0, T_INT); ms_set_num64(M, d, T_INT64, R_S0, slow); break;
    case PRIM_word64_to_int: ms_one_num64(M, x, T_WORD64, slow); ms_word64_as_int(M, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_word64_to_int_x: ms_one_num64(M, x, T_WORD64, slow); ms_num64_as_int(M, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_word64_from_int: ms_one_imm(M, x, T_INT, slow); ms_untag(M, R_S0, T_INT); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
    case PRIM_word64_to_word: ms_one_num64(M, x, T_WORD64, slow); ms_word64_as_word(M); ms_set_num(M, d, T_WORD, R_S0, slow); break;
    case PRIM_word64_from_word: ms_one_imm(M, x, T_WORD, slow); ms_untag(M, R_S0, T_WORD); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
    /* the word's top bit, bit 62 of its 63, is bit 63 of its word: an arithmetic shift extends it */
    case PRIM_word64_from_word_x: ms_one_imm(M, x, T_WORD, slow); ms_untag(M, R_S0, T_INT); ms_set_num64(M, d, T_WORD64, R_S0, slow); break;
#endif

    case PRIM_real_add: two_real(j, x, y, slow); as_fadd(A, F_S0, F_S1); set_real(j, d, slow); break;
    case PRIM_real_sub: two_real(j, x, y, slow); as_fsub(A, F_S0, F_S1); set_real(j, d, slow); break;
    case PRIM_real_mul: two_real(j, x, y, slow); as_fmul(A, F_S0, F_S1); set_real(j, d, slow); break;
    case PRIM_real_div: two_real(j, x, y, slow); as_fdiv(A, F_S0, F_S1); set_real(j, d, slow); break;
    case PRIM_real_neg:
        ms_load_real(M, F_S0, x, slow);
        as_fmov_rf(A, R_S0, F_S0);
        as_mov_ri(A, R_S1, INT64_MIN);   /* the sign bit */
        as_xor_rr(A, R_S0, R_S1);
        as_fmov_fr(A, F_S0, R_S0);
        set_real(j, d, slow);
        break;
    case PRIM_real_sqrt:   /* sqrtsd is what sqrt gives, a NaN for a negative (M10) */
        ms_load_real(M, F_S0, x, slow);
        as_fsqrt(A, F_S0, F_S0);
        set_real(j, d, slow);
        break;
    /* a comparison with a NaN is false: CC_FA and CC_FAE are the target's
       conditions that read an unordered pair as false (asm.h); x < y is
       y > x */
    case PRIM_real_lt: two_real(j, y, x, slow); as_fcmp(A, F_S0, F_S1); set_bool(j, d, CC_FA); break;
    case PRIM_real_le: two_real(j, y, x, slow); as_fcmp(A, F_S0, F_S1); set_bool(j, d, CC_FAE); break;
    case PRIM_real_gt: two_real(j, x, y, slow); as_fcmp(A, F_S0, F_S1); set_bool(j, d, CC_FA); break;
    case PRIM_real_ge: two_real(j, x, y, slow); as_fcmp(A, F_S0, F_S1); set_bool(j, d, CC_FAE); break;
    case PRIM_real_eq:
        two_real(j, x, y, slow);
        as_fcmp(A, F_S0, F_S1);
        set_bool(j, d, CC_FE);   /* equal and ordered */
        break;

    case PRIM_char_ord: ms_one_imm(M, x, T_CHAR, slow); ms_set_num(M, d, T_INT, R_S0, slow); break;
    case PRIM_char_lt: two(j, x, y, T_CHAR, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_L); break;
    case PRIM_char_le: two(j, x, y, T_CHAR, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_LE); break;
    case PRIM_char_gt: two(j, x, y, T_CHAR, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_G); break;
    case PRIM_char_ge: two(j, x, y, T_CHAR, slow); as_cmp_rr(A, R_S0, R_S1); set_bool(j, d, CC_GE); break;
    case PRIM_char_order: two(j, x, y, T_CHAR, slow); as_cmp_rr(A, R_S0, R_S1); set_order(j, d, CC_GE, CC_G); break;

    case PRIM_string_size: length_of(j, d, x, K_STRING, slow); break;
    case PRIM_string_sub:
        ms_load_obj(M, R_S0, x, K_STRING, slow);
        index_of(j, y, slow);
        ms_string_byte(M, R_S1, R_S0, R_S1);
        ms_set_reg(M, d, T_CHAR, R_S1);
        break;
    case PRIM_ref_get: ms_load_obj(M, R_S0, x, K_REF, slow); ms_load_field(M, d, R_S0, 0); break;
    case PRIM_ref_set:
        ms_need_word(M, y);
        ms_load_obj(M, R_S0, x, K_REF, slow);
        ms_store_field(M, R_S0, 0, y);
        ms_barrier(M, R_S0);
        ms_set(M, d, T_UNIT, 0);
        break;
    case PRIM_array_length: length_of(j, d, x, K_ARRAY, slow); break;
    case PRIM_array_sub:
        ms_load_obj(M, R_S0, x, K_ARRAY, slow);
        index_of(j, y, slow);
        element(j);
        ms_load_field(M, d, R_S0, 0);
        break;
    case PRIM_array_update:
        ms_need_word(M, z);
        ms_load_obj(M, R_S0, x, K_ARRAY, slow);
        index_of(j, y, slow);
        element(j);
        ms_store_field(M, R_S0, 0, z);
        ms_barrier(M, R_S0);   /* of the element's address */
        ms_set(M, d, T_UNIT, 0);
        break;
    /* The arrays of bytes and of reals (heap-layout M8): an element is a
       byte, or the double itself, which goes to a home and comes from one
       with no word between. */
    case PRIM_bytes_length: length_of(j, d, x, K_BYTES, slow); break;
    case PRIM_bytes_sub:
        ms_load_obj(M, R_S0, x, K_BYTES, slow);
        index_of(j, y, slow);
        ms_string_byte(M, R_S1, R_S0, R_S1);
        ms_set_reg(M, d, T_CHAR, R_S1);
        break;
    case PRIM_bytes_update:
        ms_load_obj(M, R_S0, x, K_BYTES, slow);
        index_of(j, y, slow);
        ms_check_tag(M, z, T_CHAR, slow);
        ms_load_payload(M, R_S2, z);
        as_add_rr(A, R_S0, R_S1);
        as_st8(A, R_S0, (int32_t)sizeof(Obj), R_S2);
        ms_set(M, d, T_UNIT, 0);
        break;
    case PRIM_reals_length: length_of(j, d, x, K_REALS, slow); break;
    case PRIM_reals_sub:
        ms_load_obj(M, R_S0, x, K_REALS, slow);
        index_of(j, y, slow);
        element(j);
        as_fld(A, F_S0, R_S0, (int32_t)sizeof(Obj));
        set_real(j, d, slow);
        break;
    case PRIM_reals_update:
        ms_load_real(M, F_S0, z, slow);
        ms_load_obj(M, R_S0, x, K_REALS, slow);
        index_of(j, y, slow);
        element(j);
        as_fst(A, R_S0, (int32_t)sizeof(Obj), F_S0);
        ms_set(M, d, T_UNIT, 0);
        break;
    case PRIM_vector_length: length_of(j, d, x, K_TUPLE, slow); break;
    case PRIM_vector_sub:
        ms_load_obj(M, R_S0, x, K_TUPLE, slow);
        index_of(j, y, slow);
        element(j);
        ms_load_field(M, d, R_S0, 0);
        break;
    }
    as_bind(A, &M->slow[which]->back);
    /* a comparison leaves its bool in the flags, for the branch after
       (M7): said to the walk, and to its slow path */
    switch (p) {
    case PRIM_poly_eq: case PRIM_imm_eq:
    case PRIM_int_lt: case PRIM_int_le: case PRIM_int_gt: case PRIM_int_ge:
    case PRIM_word_lt: case PRIM_word_le: case PRIM_word_gt: case PRIM_word_ge:
    case PRIM_real_lt: case PRIM_real_le: case PRIM_real_gt: case PRIM_real_ge: case PRIM_real_eq:
    case PRIM_char_lt: case PRIM_char_le: case PRIM_char_gt: case PRIM_char_ge:
        j->flags_for = d;
        M->slow[which]->c = 1;
        break;
    default: break;
    }
    return 1;
}

/* a primitive not done in line, called as the loop calls it (M7): its
   arguments pushed above the registers, the VM exact, the primitive's own
   C, and the result it left on the stack taken into d; after a raise, on
   in the handler's code where it has some (the handler a raise pops is
   still at hp), else the interpreter, which finds its code if any */
void emit_PRIM(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) {
    (void)pc;
    if (prim_inline(j, a, b, L, n)) return;
    AsmLabel raised, hand, done; as_label_init(&raised); as_label_init(&hand); as_label_init(&done);
    if (j->jit->prim_calls) {   /* --jit-stats: the count of calls of this primitive */
        as_mov_ri(A, R_S0, (int64_t)(intptr_t)&j->jit->prim_calls[a]);
        as_add_mi(A, R_S0, 0, 1);
    }
    for (uint32_t i = 0; i < n; i++) ms_need_word(M, read_i32(L + 4 * i));   /* before anything is pushed */
    for (uint32_t i = 0; i < n; i++) ms_copy(M, (int32_t)(j->m.nlocals + i), read_i32(L + 4 * i));
    ms_sync(M, j->next, (int)n);
    ms_call(M, (MsHelper)prim_table[a]);
    ms_reload(M);
    as_cmp_ri(A, R_S0, 1);
    as_jcc(A, CC_E, &raised);
    as_test_rr(A, R_S0, R_S0);
    as_jcc(A, CC_NE, jit_fatal(j, FATAL_NEW_WORLD, 0, 0, 0));
    ms_copy(M, b, (int32_t)j->m.nlocals);
    as_jmp(A, &done);
    as_bind(A, &raised);
    as_ld64(A, R_S1, VMR, OFF(hp));
    as_mov_ri(A, R_S0, (int64_t)sizeof(Handler));
    as_mul_rr(A, R_S1, R_S0);
    as_add_rm(A, R_S1, VMR, OFF(handlers));
    as_ld64(A, R_S0, R_S1, (int32_t)offsetof(Handler, native));
    as_test_rr(A, R_S0, R_S0);
    as_jcc(A, CC_E, &hand);
    as_jmp_r(A, R_S0);
    as_bind(A, &hand);
    ms_handback(M, RUN_INTERP);
    as_bind(A, &done);
    as_label_free(&raised); as_label_free(&hand); as_label_free(&done);
}

/* an object of n fields, fast in line or through the helper, then filled
   and stored into d */
static void alloc(Jit *j, int kind, int contag, uint32_t n, int fill, int32_t d, int32_t a, int32_t b, const uint8_t *L) {
    /* the words the fill stores, asked for before the object is there: a
       real that must be boxed is boxed by a helper that may collect */
    switch (fill) {
    case FILL_LIST: for (uint32_t i = 0; i < n; i++) ms_need_word(M, read_i32(L + 4 * i)); break;
    case FILL_ONE: ms_need_word(M, a); break;
    case FILL_CLOSURE: for (uint32_t i = 0; i + 1 < n; i++) ms_need_word(M, read_i32(L + 4 * i)); break;
    case FILL_MKEXN: ms_need_word(M, a); ms_need_word(M, b); break;
    default: break;
    }
    AsmLabel *slow = jit_alloc_slow(j, kind, contag, n, fill, d, a, b, L);
    if (!slow) return;
    /* the slow path's index, not its address: the fill may add a slow path
       of its own, and ms_slow moves the array as it grows */
    int which = j->m.nslow - 1;
    ms_alloc(M, kind, contag, n, slow);
    jit_fill(j, kind, fill, n, d, a, b, L);
    as_bind(A, &j->m.slow[which]->back);
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
    ms_load_obj(M, R_S0, c, K_TUPLE, jit_fatal(j, FATAL_EXPECT_TUPLE, 0, 0, 0));
    if (!ms_trusts(M, c, K_TUPLE)) {   /* the tuple has the field, by its type (tier 2, M10) */
        ms_need_len(M, R_S0, (uint32_t)b, jit_fatal(j, FATAL_TUPLE_INDEX, b, 0, 0));
    }
    ms_load_field(M, a, R_S0, (uint32_t)b);
}
void emit_CON(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    alloc(j, K_CON, b, 1, FILL_ONE, a, c, 0, NULL);
}
/* --checked: the tag of the constructor in rax against t */
static void checked_tag(Jit *j, int32_t t, int what) {
    AsmLabel skip; as_label_init(&skip);
    as_cmp32_mi(A, VMR, OFF(checked), 0);
    as_jcc(A, CC_E, &skip);
    ms_load_contag(M, R_S1, R_S0);
    as_cmp_ri(A, R_S1, t);
    /* the message names the tag found, which is in rcx */
    as_jcc(A, CC_NE, jit_fatal(j, what, 0, t, 1));
    as_bind(A, &skip);
    as_label_free(&skip);
}
void emit_DECON(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    ms_load_obj(M, R_S0, b, K_CON, jit_fatal(j, FATAL_EXPECT_CON, 0, 0, 0));
    checked_tag(j, c, FATAL_DECON_TAG);
    ms_load_field(M, a, R_S0, 0);
}
void emit_CONTAG(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    ms_load_tag_of_con(M, R_S0, b, jit_fatal(j, FATAL_CONTAG, 0, 0, 0));
    ms_set_reg(M, a, T_INT, R_S0);
}
void emit_NEWEXN(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    alloc(j, K_EXNCON, 0, 1, FILL_NEWEXN, a, b, 0, NULL);
}
void emit_BUILTINEXN(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    as_ld64(A, R_S0, VMR, OFF(builtin_exns) + 8 * b);
    ms_set_reg(M, a, T_PTR, R_S0);
}
void emit_MKEXN(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    alloc(j, K_EXN, 0, 2, FILL_MKEXN, a, b, c, NULL);
}
void emit_EXNCON(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    ms_load_obj(M, R_S0, b, K_EXN, jit_fatal(j, FATAL_EXPECT_EXN, 0, 0, 0));
    ms_load_field(M, a, R_S0, 0);
}
void emit_EXNARG(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    (void)pc;
    ms_load_obj(M, R_S0, b, K_EXN, jit_fatal(j, FATAL_EXPECT_EXN, 0, 0, 0));
    ms_load_field(M, a, R_S0, 1);
}
void emit_SETENV(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    ms_need_word(M, c);
    ms_load_obj(M, R_S0, a, K_CLOSURE, jit_fatal(j, FATAL_EXPECT_CLOSURE, 0, 0, 0));
    ms_need_len(M, R_S0, (uint32_t)b + 1, jit_fatal(j, FATAL_ENV_RANGE, b, 0, 0));
    ms_store_field(M, R_S0, (uint32_t)b + 1, c);
    ms_barrier(M, R_S0);
}
/* --jit-profile (M8): the count at s's field; add clobbers the flags, so
   after any branch on them */
static void count_site(Jit *j, Site *s, int field) {
    as_mov_ri(A, R_S6, (int64_t)(intptr_t)((char *)s + field));
    as_add_mi(A, R_S6, 0, 1);
}
void emit_JUMP(Jit *j, uint32_t pc, int32_t a) {
    /* a jump back is a loop's: counted under --jit-profile (M8) */
    if ((uint32_t)a <= pc) { Site *s = jit_site(j, SITE_LOOP, pc); if (s) count_site(j, s, (int)offsetof(Site, n0)); }
    as_jmp(A, jit_label(j, (uint32_t)a));
}
/* a branch, its two ways counted under --jit-profile: the way taken
   through a stub after the code (the flags of a fused comparison are
   live, so the count of the way not taken comes after the jump) */
static void branch(Jit *j, uint32_t pc, int32_t a, int32_t b, int cc, int what) {
    Site *s = jit_site(j, SITE_BRANCH, pc);
    if (s) {
        Slow *st = ms_slow(M, SLOW_TAKEN, j->next);
        if (!st) return;
        st->L = (const uint8_t *)s;
        st->a = b;
        int which = M->nslow - 1;
        if (j->flags_prev == a) as_jcc(A, cc, &M->slow[which]->here);
        else {
            ms_check_tag(M, a, T_CON0, jit_fatal(j, what, 0, 0, 0));
            ms_test_false(M, a);
            as_jcc(A, cc, &M->slow[which]->here);
        }
        count_site(j, s, (int)offsetof(Site, n1));
        return;
    }
    if (j->flags_prev == a) { as_jcc(A, cc, jit_label(j, (uint32_t)b)); return; }
    ms_check_tag(M, a, T_CON0, jit_fatal(j, what, 0, 0, 0));
    ms_test_false(M, a);
    as_jcc(A, cc, jit_label(j, (uint32_t)b));
}
/* a branch on the bool a comparison just left in the flags (M7): no tag
   test, since the comparison made it, and no load */
void emit_JUMPIF(Jit *j, uint32_t pc, int32_t a, int32_t b) { branch(j, pc, a, b, CC_NE, FATAL_JUMPIF); }
void emit_JUMPIFNOT(Jit *j, uint32_t pc, int32_t a, int32_t b) { branch(j, pc, a, b, CC_E, FATAL_JUMPIFNOT); }
void emit_JUMPIFNOTTAG(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c) {
    (void)pc;
    ms_load_tag_of_con(M, R_S0, a, jit_fatal(j, FATAL_JUMPIFNOTTAG, 0, 0, 0));
    as_cmp_ri(A, R_S0, c);
    as_jcc(A, CC_NE, jit_label(j, (uint32_t)b));
}
/* the table of n JUMPs after the instruction is a table of offsets here:
   the tag's entry, from the table's start, added to it and jumped to */
void emit_SWITCH(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    const uint8_t *code = j->vm->prog.code;
    uint32_t table = j->next;
    AsmLabel past, tbl; as_label_init(&past); as_label_init(&tbl);
    ms_load_tag_of_con(M, R_S0, a, jit_fatal(j, FATAL_SWITCH, 0, 0, 0));
    as_cmp_ri(A, R_S0, b);
    as_jcc(A, CC_AE, &past);   /* unsigned: a negative tag is past it too */
    as_lea_label(A, R_S1, &tbl);
    as_ld32sx(A, R_S2, R_S1, R_S0);
    as_add_rr(A, R_S1, R_S2);
    as_jmp_r(A, R_S1);
    as_bind(A, &tbl);
    size_t table_at = A->n;
    for (int32_t k = 0; k < b; k++) {
        size_t at = A->n;
        as_u32(A, 0);
        as_offset32_at(A, at, table_at, jit_label(j, (uint32_t)read_i32(code + table + 5 * (uint32_t)k + 1)));
    }
    as_bind(A, &past);
    as_jmp(A, jit_label(j, table + 5 * (uint32_t)b));
    as_label_free(&past); as_label_free(&tbl);
    (void)pc;
}
void emit_CONN(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c, const uint8_t *L, uint32_t n) {
    (void)pc; (void)c;
    alloc(j, K_CON, b, n, FILL_LIST, a, 0, 0, L);
}
void emit_FIELD(Jit *j, uint32_t pc, int32_t a, int32_t b, int32_t c, int32_t d) {
    (void)pc;
    ms_load_obj(M, R_S0, b, K_CON, jit_fatal(j, FATAL_EXPECT_CON_FIELDS, 0, 0, 0));
    checked_tag(j, c, FATAL_FIELD_TAG);
    if (!ms_trusts(M, b, K_CON)) {   /* the constructor has the field, by its type (tier 2, M10) */
        ms_need_len(M, R_S0, (uint32_t)d, jit_fatal(j, FATAL_FIELD_INDEX, d, 0, 0));
    }
    ms_load_field(M, a, R_S0, (uint32_t)d);
}
/* ---- calls, returns, handlers, PRIMPUSH (M5) ---- */

#define FRAME_SIZE ((int32_t)sizeof(Frame))
#define FR(field) ((int32_t)offsetof(Frame, field))

static void fill_unit(Jit *j, int base_reg, uint32_t fill_from, uint32_t nlocals);
/* rax := the entry of function f, read from its code object when the call
   is made, since a function is compiled once and not before every caller */
static void entry_of(Jit *j, uint32_t f) {
    as_mov_ri(A, R_S0, (int64_t)(intptr_t)&j->jit->codes[f].entry);
    as_ld64(A, R_S0, R_S0, 0);
}
/* into the callee whose frame is on top and whose registers rbp and r14
   now name: its code where it has some, else the interpreter, the VM made
   exact for it */
static void to_callee(Jit *j, uint32_t f, const Function *fn) {
    /* straight into the callee's code where it has some (M7): a call to
       this very function to its entry's label, another's by a jump to
       its address, which makes this function go when that one is
       invalidated (jit_depend) */
    if (f == j->f) { as_jmp(A, &j->entry); return; }   /* the entry: the fill, then the homes (M10) */
    const void *entry = j->jit->codes[f].entry;
    if (entry) {
        jit_depend(j->jit, f, j->f);
        as_jmp_to(A, entry);
        return;
    }
    AsmLabel interp; as_label_init(&interp);
    entry_of(j, f);
    as_test_rr(A, R_S0, R_S0);
    as_jcc(A, CC_E, &interp);
    as_jmp_r(A, R_S0);
    as_bind(A, &interp);
    /* the interpreter runs it: the fill its code would have done */
    if (fn->has_meta) {
        uint32_t fill_from = jit_fill_from(j->vm, j->jit, f);
        fill_unit(j, BASER, fill_from < fn->arity ? fn->arity : fill_from, fn->nlocals);
    }
    as_st32i(A, VMR, OFF(pc), (int32_t)fn->code_offset);
    as_lea(A, R_S0, BASEI, -1, 1, (int32_t)fn->nlocals);
    as_st64(A, VMR, OFF(sp), R_S0);
    as_st64(A, VMR, OFF(instructions), COUNTR);
    ms_handback(M, RUN_INTERP);
    as_label_free(&interp);
}
/* room on the stack for need values above the frame's base, or the slow
   path that grows it */
static void room(Jit *j, uint32_t need) {
    Slow *s = ms_slow(M, SLOW_GROW, j->next);
    if (!s) return;
    s->n = need;
    as_lea(A, R_S0, BASEI, -1, 1, (int32_t)need);
    as_cmp_rm(A, R_S0, VMR, OFF(stack_cap));
    as_jcc(A, CC_A, &s->here);
    as_bind(A, &s->back);
}
/* rax := the index of a new frame, the array grown where it must be */
static void frame_room(Jit *j) {
    Slow *s = ms_slow(M, SLOW_FRAMES, j->next);
    if (!s) return;
    as_bind(A, &s->back);
    as_ld64(A, R_S0, VMR, OFF(fp));
    as_add_ri(A, R_S0, 1);
    as_cmp_rm(A, R_S0, VMR, OFF(frames_cap));
    as_jcc(A, CC_AE, &s->here);
}
/* a frame pushed: index rax, function f, base rdx, no closure, returning
   to the code at after, the caller's pc that of the RESULT */
/* the register of the RESULT at pc, if that is one: where a frame pushed
   by a call at that pc returns to (-1: none) */
static int32_t result_at(Jit *j, uint32_t pc) {
    const uint8_t *code = j->vm->prog.code;
    return pc < j->vm->prog.code_len && code[pc] == ROP_RESULT ? read_i32(code + pc + 1) : -1;
}
static void push_frame(Jit *j, uint32_t f, int32_t ret_pc, AsmLabel *after) {
    as_ld64(A, R_S1, VMR, OFF(frames));
    as_mul_ri(A, R_S3, R_S0, FRAME_SIZE);
    as_add_rr(A, R_S1, R_S3);
    as_st32i(A, R_S1, FR(func), (int32_t)f);
    as_st32i(A, R_S1, FR(ret_pc), ret_pc);
    as_st32i(A, R_S1, FR(result), result_at(j, (uint32_t)ret_pc));
    as_st64(A, R_S1, FR(base), R_S2);
    as_st64i(A, R_S1, FR(closure), 0);
    as_lea_label(A, R_S3, after);
    as_st64(A, R_S1, FR(native_ret), R_S3);
    as_st64(A, VMR, OFF(fp), R_S0);
}
/* unit into the registers of the function at base_reg from fill_from
   (M7: the ones the callee does not write before anything could see
   them; M10: the callee's own code does this at its entry where the
   section gives its arity, so a caller does it for a callee without one,
   and for the interpreter) */
static void fill_unit(Jit *j, int base_reg, uint32_t fill_from, uint32_t nlocals) {
    ms_fill_units(M, base_reg, fill_from, nlocals);
}
/* the registers of a callee at r9: its n arguments from the list, the
   rest unit where the callee's code will not do it */
static void make_registers(Jit *j, uint32_t n, const uint8_t *L, uint32_t f, const Function *fn) {
    for (uint32_t i = 0; i < n; i++) ms_store_nth(M, R_S4, i, read_i32(L + 4 * i));
    if (!fn->has_meta) {
        uint32_t fill_from = jit_fill_from(j->vm, j->jit, f);
        fill_unit(j, R_S4, fill_from < n ? n : fill_from, fn->nlocals);
    }
}

void emit_CALLK(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) {
    (void)pc; (void)b;
    const Function *fn = &j->vm->prog.funcs[a];
    AsmLabel *after = jit_landing(j, j->next + 5);   /* past the RESULT */
    ms_writeback(M, pc);   /* the homes to their slots: the callee has the registers, and after loads them again (M9) */
    room(j, j->m.nlocals + fn->nlocals + fn->maxstack);
    frame_room(j);
    ms_slot_addr(M, R_S4, (int32_t)j->m.nlocals);
    make_registers(j, n, L, (uint32_t)a, fn);
    as_lea(A, R_S2, BASEI, -1, 1, (int32_t)j->m.nlocals);
    push_frame(j, (uint32_t)a, (int32_t)j->next, after);
    as_mov_rr(A, BASEI, R_S2);
    as_mov_rr(A, BASER, R_S4);
    to_callee(j, (uint32_t)a, fn);
}
void emit_TAILCALLK(Jit *j, uint32_t pc, int32_t a, int32_t b, const uint8_t *L, uint32_t n) {
    (void)pc; (void)b;
    const Function *fn = &j->vm->prog.funcs[a];
    uint32_t need = j->m.nlocals + n;
    if (fn->nlocals + fn->maxstack > need) need = fn->nlocals + fn->maxstack;
    for (uint32_t i = 0; i < n; i++) ms_need_word(M, read_i32(L + 4 * i));
    room(j, need);
    /* the arguments above the frame first, since they are its registers */
    ms_slot_addr(M, R_S4, (int32_t)j->m.nlocals);
    for (uint32_t i = 0; i < n; i++) ms_store_nth(M, R_S4, i, read_i32(L + 4 * i));
    for (uint32_t i = 0; i < n; i++) ms_slot_from_nth_raw(M, (int32_t)i, R_S4, i);   /* the slots: the callee's registers, not this function's homes */
    if (!fn->has_meta) {
        uint32_t from = jit_fill_from(j->vm, j->jit, (uint32_t)a);
        fill_unit(j, BASER, from < n ? n : from, fn->nlocals);
    }
    ms_frame(M, R_S1);
    as_st32i(A, R_S1, FR(func), a);
    as_st64i(A, R_S1, FR(closure), 0);
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

/* --jit-profile (M8): the function called through a closure at pc (r11)
   told to the site's helper, which touches nothing of the VM */
static void called(Jit *j, uint32_t pc) {
    Site *s = jit_site(j, SITE_CALL, pc);
    if (!s) return;
    /* what closure_function found (rcx, r10, r11) kept across the call:
       three pushes and eight bytes keep the machine stack aligned */
    as_push(A, R_S1); as_push(A, R_S5); as_push(A, R_S6);
    as_sub_ri(A, R_SP, 8);
    as_mov_ri(A, ms_arg(M, 1), (int64_t)(intptr_t)s);
    as_mov_rr(A, ms_arg(M, 2), R_S6);
    ms_call(M, (MsHelper)jit_h_called);
    as_add_ri(A, R_SP, 8);
    as_pop(A, R_S6); as_pop(A, R_S5); as_pop(A, R_S1);
    ms_reload_homes(M, pc);   /* written back at the instruction's start (M9) */
}
/* obj := the closure in register a; r11 := the index of its function,
   checked; rcx := that Function */
static void closure_function(Jit *j, int32_t a, int obj) {
    const Program *p = &j->vm->prog;
    ms_load_obj(M, obj, a, K_CLOSURE, jit_fatal(j, FATAL_CALL, 0, 0, 0));
    ms_load_field_payload(M, R_S6, obj, 0);   /* field 0: the index */
    as_cmp_ri(A, R_S6, (int32_t)p->nfuncs);
    as_jcc(A, CC_AE, jit_fatal(j, FATAL_FUNCTION, 0, 0, 0));   /* unsigned: negative too */
    as_mul_ri(A, R_S1, R_S6, (int32_t)sizeof(Function));
    as_mov_ri(A, R_S3, (int64_t)(intptr_t)p->funcs);
    as_add_rr(A, R_S1, R_S3);
}
/* the slow path that grows the stack and starts the instruction over,
   made first: its back label is the instruction's start (after the run's
   count, which a restart must not add again), and nothing may be live
   across a restart */
static int grow_slow(Jit *j) {
    Slow *s = ms_slow(M, SLOW_GROW_RAX, j->next);
    if (!s) return -1;
    int which = M->nslow - 1;
    as_bind(A, &M->slow[which]->back);
    return which;
}
/* the room a frame of the Function in rcx needs at base (an index in
   base_reg), or the slow path (which) that grows the stack, the need in rax */
static void room_dynamic(Jit *j, int which, int base_reg) {
    as_ld32(A, R_S0, R_S1, (int32_t)offsetof(Function, nlocals));
    as_ld32(A, R_S3, R_S1, (int32_t)offsetof(Function, maxstack));
    as_add_rr(A, R_S0, R_S3);
    as_add_rr(A, R_S0, base_reg);
    as_cmp_rm(A, R_S0, VMR, OFF(stack_cap));
    as_jcc(A, CC_A, &M->slow[which]->here);
}
/* unit into the callee's registers at r9 (its nlocals in r8, its index in
   r11) from the first it does not write before anything could see it
   (jit_fill_from, M7), and at least the second */
static void fill_unit_dynamic(Jit *j) {
    AsmLabel loop, done; as_label_init(&loop); as_label_init(&done);
    /* from the first register the callee does not write before anything
       could see it (jit_fill_from, M7), and at least the second */
    AsmLabel ok; as_label_init(&ok);
    as_mov_ri(A, R_S0, (int64_t)(intptr_t)j->jit->fill_from);
    as_lea(A, R_S0, R_S0, R_S6, 4, 0);
    as_ld32(A, R_S0, R_S0, 0);
    as_cmp_ri(A, R_S0, 1);
    as_jcc(A, CC_AE, &ok);
    as_mov_ri(A, R_S0, 1);
    as_bind(A, &ok);
    as_label_free(&ok);
    ms_scale_index(M, R_S0);
    as_add_rr(A, R_S0, R_S4);                    /* the first to fill */
    as_mov_rr(A, R_H2, R_S3);                    /* (rdx holds the frame's base) */
    ms_scale_index(M, R_H2);
    as_add_rr(A, R_H2, R_S4);                    /* past the last */
    as_bind(A, &loop);
    as_cmp_rr(A, R_S0, R_H2);
    as_jcc(A, CC_AE, &done);
    ms_unit_to(M, R_S0, 0);
    ms_next_value(M, R_S0);
    as_jmp(A, &loop);
    as_bind(A, &done);
    as_label_free(&loop); as_label_free(&done);
}
/* the callee's registers at r9: register 0 from register arg, the rest
   unit where the callee's code will not do it (every function of the
   program has its arity in the section: jit->all_meta) */
static void make_registers_dynamic(Jit *j, int32_t arg) {
    ms_value_to(M, R_S4, 0, arg);
    if (!j->jit->all_meta) fill_unit_dynamic(j);
}
/* into the callee whose Function is in rcx and whose index is in r11, the
   frame's rbp and r14 already its own (r9 too): its code where it has
   some, else the interpreter, the VM made exact for it */
static void to_callee_dynamic(Jit *j) {
    AsmLabel interp; as_label_init(&interp);
    as_mul_ri(A, R_S0, R_S6, (int32_t)sizeof(CodeObject));
    as_mov_ri(A, R_S3, (int64_t)(intptr_t)j->jit->codes);
    as_add_rr(A, R_S0, R_S3);
    as_ld64(A, R_S0, R_S0, (int32_t)offsetof(CodeObject, entry));
    as_test_rr(A, R_S0, R_S0);
    as_jcc(A, CC_E, &interp);
    as_jmp_r(A, R_S0);
    as_bind(A, &interp);
    /* the interpreter runs it: the fill its code would have done (its
       nlocals into r8 again, which the entry's address took) */
    if (j->jit->all_meta) {
        as_ld32(A, R_S3, R_S1, (int32_t)offsetof(Function, nlocals));
        fill_unit_dynamic(j);
    }
    as_ld32(A, R_S0, R_S1, (int32_t)offsetof(Function, code_offset));
    as_st32(A, VMR, OFF(pc), R_S0);
    as_ld32(A, R_S0, R_S1, (int32_t)offsetof(Function, nlocals));
    as_add_rr(A, R_S0, BASEI);
    as_st64(A, VMR, OFF(sp), R_S0);
    as_st64(A, VMR, OFF(instructions), COUNTR);
    ms_handback(M, RUN_INTERP);
    as_label_free(&interp);
}
void emit_CALL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    AsmLabel *after = jit_landing(j, j->next + 5);   /* past the RESULT */
    ms_writeback(M, pc);   /* before the restart label: the slots stay right across a restart (M9) */
    int grow = grow_slow(j);
    if (grow < 0) return;
    /* the frames first: their slow path comes back to its check with the
       registers clobbered, so nothing may be live across it */
    frame_room(j);
    closure_function(j, a, R_S5);
    called(j, pc);
    as_lea(A, R_S2, BASEI, -1, 1, (int32_t)j->m.nlocals);   /* the callee's base */
    room_dynamic(j, grow, R_S2);
    /* the callee's registers above the frame */
    as_ld32(A, R_S3, R_S1, (int32_t)offsetof(Function, nlocals));
    ms_slot_addr(M, R_S4, (int32_t)j->m.nlocals);
    make_registers_dynamic(j, b);
    /* the frame: function r11, closure r10, base rdx, returning to after */
    as_ld64(A, R_S0, VMR, OFF(fp));
    as_add_ri(A, R_S0, 1);
    as_ld64(A, R_H1, VMR, OFF(frames));
    as_mul_ri(A, R_H2, R_S0, FRAME_SIZE);
    as_add_rr(A, R_H1, R_H2);
    as_st32(A, R_H1, (int32_t)offsetof(Frame, func), R_S6);
    as_st32i(A, R_H1, (int32_t)offsetof(Frame, ret_pc), (int32_t)j->next);
    as_st32i(A, R_H1, (int32_t)offsetof(Frame, result), result_at(j, j->next));
    as_st64(A, R_H1, (int32_t)offsetof(Frame, base), R_S2);
    as_st64(A, R_H1, (int32_t)offsetof(Frame, closure), R_S5);
    as_lea_label(A, R_H2, after);
    as_st64(A, R_H1, (int32_t)offsetof(Frame, native_ret), R_H2);
    as_st64(A, VMR, OFF(fp), R_S0);
    as_mov_rr(A, BASEI, R_S2);
    as_mov_rr(A, BASER, R_S4);
    to_callee_dynamic(j);
}
void emit_TAILCALL(Jit *j, uint32_t pc, int32_t a, int32_t b) {
    ms_writeback(M, pc);   /* the profile's helper (called) clobbers the homes; the slots stay right (M9) */
    int grow = grow_slow(j);
    if (grow < 0) return;
    closure_function(j, a, R_S5);
    called(j, pc);
    room_dynamic(j, grow, BASEI);
    /* the callee's registers are this frame's, from its base */
    as_ld32(A, R_S3, R_S1, (int32_t)offsetof(Function, nlocals));
    as_mov_rr(A, R_S4, BASER);
    make_registers_dynamic(j, b);
    /* the frame replaced: its function and closure; its return kept */
    ms_frame(M, R_H1);
    as_st32(A, R_H1, (int32_t)offsetof(Frame, func), R_S6);
    as_st64(A, R_H1, (int32_t)offsetof(Frame, closure), R_S5);
    to_callee_dynamic(j);
}
/* after a CALL or CALLK a RESULT is the callee's RET's to do, and is passed
   over (compile.c, phantom); after a PRIMPUSH it takes what the primitive
   left on the stack, above the registers */
void emit_RESULT(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    ms_copy(M, a, (int32_t)j->m.nlocals);
}
/* RET: the value into the register of the caller's RESULT, then on into
   the caller's code where it has some, else the VM made exact and handed
   back; the frame of the top level through the helper */
void emit_RET(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    AsmLabel no_result, go, interp; as_label_init(&no_result); as_label_init(&go); as_label_init(&interp);
    ms_need_word(M, a);
    Slow *s = ms_slow(M, SLOW_RET, j->next);
    if (!s) return;
    s->a = a;
    as_ld64(A, R_S2, VMR, OFF(fp));
    as_test_rr(A, R_S2, R_S2);
    as_jcc(A, CC_E, &s->here);
    /* the frame: rcx; what it kept: where the caller's code goes on, the
       register of its RESULT (M7), the callee's base (the caller's stack top) */
    as_mul_ri(A, R_S1, R_S2, FRAME_SIZE);
    as_add_rm(A, R_S1, VMR, OFF(frames));
    /* the value, kept across the frame's popping: in xmm0, or in its home
       (tier 2), which the popping leaves alone and which is stored whole
       where it goes, rather than through its slot (a 16-byte load of two
       8-byte stores stalls) */
    /* (a real's home holds the double, not the word: its word is taken
       from its slot, brought up to date above, before the frame goes) */
    /* (so does an int's or a word's that holds its 64 bits: ms_word_home) */
    const Home *h = ms_word_home(M, a);
    if (!h) ms_load_xmm(M, F_S0, a);
    as_ld64(A, R_S4, R_S1, FR(native_ret));
    as_ld32s(A, R_S3, R_S1, FR(result));
    as_ld64(A, R_S5, R_S1, FR(base));
    as_sub_ri(A, R_S2, 1);
    as_st64(A, VMR, OFF(fp), R_S2);   /* the frame popped */
    as_sub_ri(A, R_S1, FRAME_SIZE);      /* the caller's frame: its registers are the code's now */
    as_ld64(A, BASEI, R_S1, FR(base));
    as_mov_rr(A, BASER, BASEI);
    ms_scale_index(M, BASER);
    as_add_rr(A, BASER, STACKR);
    as_test_rr(A, R_S4, R_S4);
    as_jcc(A, CC_E, &interp);
    /* into the caller's code, which has a RESULT (its phantom): the value
       into its register, and on past it */
    ms_scale_index(M, R_S3);
    if (h) { as_lea(A, R_S6, BASER, R_S3, 1, 0); ms_value_to(M, R_S6, 0, a); }
    else { as_lea(A, R_S6, BASER, R_S3, 1, 0); ms_xmm_to(M, R_S6, 0, F_S0); }
    as_jmp_r(A, R_S4);
    as_bind(A, &interp);
    /* the interpreter goes on: at the RESULT's register and past it, or
       with the value on the stack, as an image resumed at RESULT takes it */
    as_ld32(A, R_S0, R_S1, FRAME_SIZE + FR(ret_pc));
    as_cmp_ri(A, R_S3, -1);
    as_jcc(A, CC_E, &no_result);
    ms_scale_index(M, R_S3);
    if (h) { as_lea(A, R_S6, BASER, R_S3, 1, 0); ms_value_to(M, R_S6, 0, a); }
    else { as_lea(A, R_S6, BASER, R_S3, 1, 0); ms_xmm_to(M, R_S6, 0, F_S0); }
    as_add_ri(A, R_S0, 5);
    as_jmp(A, &go);
    as_bind(A, &no_result);
    as_mov_rr(A, R_S2, R_S5);
    ms_scale_index(M, R_S2);
    if (h) { as_lea(A, R_S6, STACKR, R_S2, 1, 0); ms_value_to(M, R_S6, 0, a); }
    else { as_lea(A, R_S6, STACKR, R_S2, 1, 0); ms_xmm_to(M, R_S6, 0, F_S0); }
    as_add_ri(A, R_S5, 1);
    as_bind(A, &go);
    as_st32(A, VMR, OFF(pc), R_S0);
    as_st64(A, VMR, OFF(sp), R_S5);
    as_st64(A, VMR, OFF(instructions), COUNTR);
    ms_handback(M, RUN_INTERP);
    as_label_free(&no_result); as_label_free(&go); as_label_free(&interp);
}
void emit_PRIMPUSH(Jit *j, uint32_t pc, int32_t a, const uint8_t *L, uint32_t n) {
    (void)pc; (void)n;
    AsmLabel done; as_label_init(&done);
    ms_sync(M, j->next, 0);
    as_mov_ri(A, ms_arg(M, 1), a);
    as_mov_ri(A, ms_arg(M, 2), (int64_t)(intptr_t)L);
    ms_call(M, (MsHelper)jit_h_primpush);
    ms_reload(M);
    as_test_rr(A, R_S0, R_S0);
    as_jcc(A, CC_E, &done);
    ms_handback_rax(M);
    as_bind(A, &done);
    as_label_free(&done);
}
void emit_PUSHHANDLER(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    ms_sync(M, j->next, 0);
    as_mov_ri(A, ms_arg(M, 1), a);
    as_lea_label(A, ms_arg(M, 2), jit_landing(j, (uint32_t)a));
    ms_call(M, (MsHelper)jit_h_push_handler);
    ms_reload_homes(M, pc);   /* the stack did not move; the homes the call clobbered (M9) */
}
void emit_POPHANDLER(Jit *j, uint32_t pc) {
    (void)pc;
    as_cmp_mi(A, VMR, OFF(hp), 0);
    as_jcc(A, CC_E, jit_fatal(j, FATAL_POPHANDLER, 0, 0, 0));
    as_add_mi(A, VMR, OFF(hp), -1);
}
void emit_CATCH(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    ms_copy(M, a, (int32_t)j->m.nlocals);
}
void emit_RAISE(Jit *j, uint32_t pc, int32_t a) {
    (void)pc;
    AsmLabel hand; as_label_init(&hand);
    ms_load_obj(M, R_S0, a, K_EXN, jit_fatal(j, FATAL_RAISE, 0, 0, 0));
    ms_sync(M, j->next, 0);
    as_mov_ri(A, ms_arg(M, 1), a);
    ms_call(M, (MsHelper)jit_h_raise);
    ms_reload(M);
    as_test_rr(A, R_S0, R_S0);
    as_jcc(A, CC_E, &hand);
    as_jmp_r(A, R_S0);
    as_bind(A, &hand);
    ms_handback(M, RUN_INTERP);
    as_label_free(&hand);
}
