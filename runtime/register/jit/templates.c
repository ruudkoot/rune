/* runtime/register/jit/templates.c -- bin/runeopt-templates: the macro-assembler's
   operations on values and objects (masm.h), each run once against the
   text backend of the assembler (asm_text.h) and written as a template of
   src/opt/x64_layout.sml, which runeopt's translator (src/opt/x64.sml) is
   written over. So the third engine has the layout the JIT has, without a
   copy by hand (docs/plans/heap-layout.md, D11 and M3): after a change to
   the layout in masm.c, `make templates` remakes the file, and
   check-templates refuses a stale one.

   How a template is made: an operation is run with markers for its
   parameters -- a frame slot at an index the backend prints as a hole
   ({s}), a register printed as one ({r}), a label named ({unless}), a
   kind number named ({kind}) -- and, for a numeric parameter (a field
   index, a count, a payload), run again with the parameter moved, so that
   every number of the text that moves with it is fitted as a linear
   expression of it (8 + 8 * n, or 1 + 2 * v for the word of an immediate,
   written as IntInf arithmetic: a host's int may be 31 bits) and checked at
   a third point. A
   parameter the text does not depend on linearly stops the generator. */
#include "masm.h"
#include "native/native_offsets.h"
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static Masm M;
#define A (&M.a)
enum { SLOT_S = 1000, SLOT_D = 2000, SLOT_X = 3000, SLOT_Y = 3100 };   /* the marker slots */
enum { KIND_MARK = 0x72 };
enum { REG_R = R_S3, REG_B = R_S4 };     /* the marker registers: {r} a result, {b} an object */
static AsmLabel unless_label, slow_label;

typedef struct { const char *name; int64_t at; } Param;
typedef void (*OpFn)(const int64_t *p);
typedef struct { const char *sml;   /* the function's name and parameters, e.g. "checkImm line (s, unless)" */
                 OpFn fn; Param params[4]; int nparams;
                 int fixed;         /* the operation works in registers of its own (rax, rcx, rdx, r8): none is a hole */
               } Op;

static void die(const char *what) { fprintf(stderr, "runeopt-templates: %s\n", what); exit(2); }

/* a captured run of an operation: its lines */
typedef struct { char **lines; int n; } Run;
static Run run_op(const Op *op, const int64_t *p) {
    tx_clear(A);
    M.nfields = UINT32_MAX;
    int nregs = A->nregs;
    if (op->fixed) A->nregs = 0;
    op->fn(p);
    A->nregs = nregs;
    if (A->failed) { for (int i = 0; i < A->n; i++) fprintf(stderr, "  %s\n", A->lines[i]); die("the text backend could not say an operation"); }
    Run r;
    r.n = A->n;
    r.lines = calloc((size_t)r.n + 1, sizeof *r.lines);
    for (int i = 0; i < r.n; i++) { size_t len = strlen(A->lines[i]) + 1; r.lines[i] = malloc(len); memcpy(r.lines[i], A->lines[i], len); }
    return r;
}
static void free_run(Run *r) { for (int i = 0; i < r->n; i++) free(r->lines[i]); free(r->lines); }

/* tokens: text, or a number (a run of digits, with a sign when nothing alphanumeric precedes it) */
typedef struct { int isnum; int64_t num; const char *text; int len; } Tok;
static int tokenize(const char *s, Tok *t, int max) {
    int n = 0;
    const char *p = s;
    while (*p) {
        if (n == max) die("a line with too many tokens");
        int neg = p[0] == '-' && isdigit((unsigned char)p[1]) && (p == s || !isalnum((unsigned char)p[-1]));
        if (neg || isdigit((unsigned char)*p)) {
            const char *q = p + neg;
            int64_t v = 0;
            while (isdigit((unsigned char)*q)) { v = v * 10 + (*q - '0'); q++; }
            t[n].isnum = 1; t[n].num = neg ? -v : v; t[n].text = p; t[n].len = (int)(q - p); n++;
            p = q;
        } else {
            const char *q = p;
            while (*q) {
                if (*q == '{') { while (*q && *q != '}') q++; if (*q) q++; continue; }   /* a hole is text, digits and all */
                if (isdigit((unsigned char)*q) || (q[0] == '-' && isdigit((unsigned char)q[1]) && !isalnum((unsigned char)q[-1]))) break;
                q++;
            }
            t[n].isnum = 0; t[n].num = 0; t[n].text = p; t[n].len = (int)(q - p); n++;
            p = q;
        }
    }
    return n;
}

/* the SML expression of one line: pieces, literal text or an expression,
   adjacent literals merged; a hole {name} is a parameter ({r} and {b}
   registers through reg64, {r32} and {b32} through reg32) */
static char pieces[64][256];
static int npieces, piece_islit[64];
static void piece_lit(const char *s, int len) {
    if (npieces && piece_islit[npieces - 1]) { strncat(pieces[npieces - 1], s, (size_t)len); return; }
    snprintf(pieces[npieces], 256, "%.*s", len, s);
    piece_islit[npieces++] = 1;
}
static void piece_expr(const char *e) { snprintf(pieces[npieces], 256, "%s", e); piece_islit[npieces++] = 0; }
static void text_pieces(const char *s, int len) {
    for (int i = 0; i < len; i++) {
        if (s[i] == '{') {
            int j = i + 1;
            while (j < len && s[j] != '}') j++;
            if (j == len) die("an unclosed hole");
            char name[32], e[64];
            snprintf(name, sizeof name, "%.*s", j - i - 1, s + i + 1);
            size_t nl = strlen(name);
            if (nl == 3 && (name[0] == 'r' || name[0] == 'b') && strcmp(name + 1, "32") == 0) snprintf(e, sizeof e, "reg32 %c", name[0]);
            else if (nl == 1 && (name[0] == 'r' || name[0] == 'b')) snprintf(e, sizeof e, "reg64 %s", name);
            else snprintf(e, sizeof e, "%s", name);
            piece_expr(e);
            i = j;
        } else piece_lit(s + i, 1);
    }
}
static void print_pieces(void) {
    for (int i = 0; i < npieces; i++) {
        if (i) fputs(" ^ ", stdout);
        if (!piece_islit[i]) { fputs(pieces[i], stdout); continue; }
        putchar('"');
        for (const char *c = pieces[i]; *c; c++) { if (*c == '"' || *c == '\\') putchar('\\'); putchar(*c); }
        putchar('"');
    }
}

/* the template of an operation: its runs at the base point, at each
   parameter moved by one, and at every parameter moved by two, fitted */
static void template(const Op *op) {
    int64_t base[4], moved[4][4], check[4];
    for (int j = 0; j < op->nparams; j++) base[j] = op->params[j].at;
    Run r0 = run_op(op, base);
    Run rj[4];
    for (int j = 0; j < op->nparams; j++) {
        for (int k = 0; k < op->nparams; k++) moved[j][k] = base[k] + (j == k ? 1 : 0);
        rj[j] = run_op(op, moved[j]);
        if (rj[j].n != r0.n) die("an operation whose shape depends on a parameter");
    }
    for (int k = 0; k < op->nparams; k++) check[k] = base[k] + 2;
    Run rc = run_op(op, check);
    if (rc.n != r0.n) die("an operation whose shape depends on a parameter");
    printf("  fun %s =\n    (", op->sml);
    for (int i = 0; i < r0.n; i++) {
        Tok t0[64], tj[4][64], tc[64];
        int n0 = tokenize(r0.lines[i], t0, 64);
        for (int j = 0; j < op->nparams; j++) if (tokenize(rj[j].lines[i], tj[j], 64) != n0) die("a line whose tokens depend on a parameter");
        if (tokenize(rc.lines[i], tc, 64) != n0) die("a line whose tokens depend on a parameter");
        int islabel = n0 > 0 && r0.lines[i][strlen(r0.lines[i]) - 1] == ':';
        npieces = 0;
        for (int k = 0; k < n0; k++) {
            if (!t0[k].isnum) {
                if (t0[k].len != tc[k].len || memcmp(t0[k].text, tc[k].text, (size_t)t0[k].len) != 0) die("text that depends on a parameter");
                text_pieces(t0[k].text, t0[k].len);
                continue;
            }
            int64_t coeff[4], c = t0[k].num;
            int varies = 0;
            for (int j = 0; j < op->nparams; j++) { coeff[j] = tj[j][k].num - t0[k].num; c -= coeff[j] * base[j]; if (coeff[j]) varies = 1; }
            int64_t expect = c;
            for (int j = 0; j < op->nparams; j++) expect += coeff[j] * check[j];
            if (expect != tc[k].num) die("a number that is not linear in the parameters");
            if (!varies) { char lit[32]; snprintf(lit, sizeof lit, "%lld", (long long)t0[k].num); piece_lit(lit, (int)strlen(lit)); continue; }
            /* the sum as an IntInf.int, written out: a host's int may be 31
               bits, which the word of a payload near 2^30 is past */
            char e[512] = "num (";
            char sum[400] = "";
            if (c) snprintf(sum, sizeof sum, "IntInf.fromInt %s%lld", c < 0 ? "~" : "", (long long)(c < 0 ? -c : c));
            for (int j = 0; j < op->nparams; j++) if (coeff[j]) {
                char term[96], next[400];
                if (coeff[j] == 1) snprintf(term, sizeof term, "IntInf.fromInt %s", op->params[j].name);
                else snprintf(term, sizeof term, "IntInf.* (IntInf.fromInt %s%lld, IntInf.fromInt %s)", coeff[j] < 0 ? "~" : "",
                              (long long)(coeff[j] < 0 ? -coeff[j] : coeff[j]), op->params[j].name);
                if (sum[0]) snprintf(next, sizeof next, "IntInf.+ (%s, %s)", sum, term); else snprintf(next, sizeof next, "%s", term);
                snprintf(sum, sizeof sum, "%s", next);
            }
            strcat(e, sum);
            strcat(e, ")");
            piece_expr(e);
        }
        /* a label is a line too: runeopt's `line` indents it, which the assembler allows */
        (void)islabel;
        if (i) fputs(";\n     ", stdout);
        fputs("line (", stdout);
        print_pieces();
        fputs(")", stdout);
    }
    fputs(")\n", stdout);
    free_run(&r0);
    for (int j = 0; j < op->nparams; j++) free_run(&rj[j]);
    free_run(&rc);
}

/* ---- the operations ---- */
/* Values are words (docs/plans/heap-layout.md, M4): an immediate is 2n+1,
   so the templates of ints, words, chars and constructor tags work on the
   words, in rax and rcx (R_S0, R_S1) as the JIT's tier 1 does, and a
   template that can meet a box (an int or a word past 63 bits where the VM
   keeps 64, a real with no immediate) takes the label of the slow path,
   where the primitive's own C does it. The real templates use rdx and r8
   (R_S2, R_S3) and make labels of their own, under the prefix l. */
static void op_check_imm(const int64_t *p) { (void)p; ms_check_tag(&M, SLOT_S, T_INT, &unless_label); }
static void op_set(const int64_t *p) { ms_set(&M, SLOT_D, T_INT, p[0]); }
static void op_set_wide(const int64_t *p) { ms_set(&M, SLOT_D, T_INT, p[0]); }
static void op_set_imm(const int64_t *p) { (void)p; ms_set_reg(&M, SLOT_D, T_INT, REG_R); }
static void op_set_bits(const int64_t *p) { (void)p; ms_set_bits(&M, SLOT_D, REG_R); }
static void op_load_bits(const int64_t *p) { (void)p; ms_load_bits(&M, REG_R, SLOT_S); }
static void op_load_payload(const int64_t *p) { (void)p; ms_load_payload(&M, REG_R, SLOT_S); }
static void op_copy(const int64_t *p) { (void)p; ms_copy(&M, SLOT_D, SLOT_S); }
static void op_load_real(const int64_t *p) { (void)p; ms_load_real(&M, F_S0, SLOT_S, &unless_label); }
static void op_load_real1(const int64_t *p) { (void)p; ms_load_real(&M, F_S1, SLOT_S, &unless_label); }
static void op_set_real(const int64_t *p) { (void)p; ms_set_real(&M, SLOT_D, F_S0, &slow_label); }
static void op_test_false(const int64_t *p) { (void)p; ms_test_false(&M, SLOT_S); }
/* The operands of an int's, a word's or a char's arithmetic, in the form it
   is done in (masm.h): their words where an int is 63 bits, their 64 bits
   where the VM keeps 64, an int's payload signed and a word's not. */
static void op_one_int(const int64_t *p) { (void)p; ms_one_imm(&M, SLOT_X, T_INT, &slow_label); }
static void op_one_word(const int64_t *p) { (void)p; ms_one_imm(&M, SLOT_X, T_WORD, &slow_label); }
static void op_one_char(const int64_t *p) { (void)p; ms_one_imm(&M, SLOT_X, T_CHAR, &slow_label); }
static void op_two_int(const int64_t *p) { (void)p; ms_two_imm(&M, SLOT_X, SLOT_Y, T_INT, &slow_label); }
static void op_two_word(const int64_t *p) { (void)p; ms_two_imm(&M, SLOT_X, SLOT_Y, T_WORD, &slow_label); }
static void op_two_char(const int64_t *p) { (void)p; ms_two_imm(&M, SLOT_X, SLOT_Y, T_CHAR, &slow_label); }
/* two values as their words, for `=`: to the label where either is in the heap */
static void op_two_words(const int64_t *p) { (void)p; ms_two_words(&M, SLOT_X, SLOT_Y, &slow_label); }
/* the result of that arithmetic into its slot, and a payload (a quotient, a
   shifted word) into its: to the slow path where a slot wants a word the
   number has none for */
static void op_set_int(const int64_t *p) { (void)p; ms_set_num(&M, SLOT_D, T_INT, REG_R, &slow_label); }
static void op_set_wordnum(const int64_t *p) { (void)p; ms_set_num(&M, SLOT_D, T_WORD, REG_R, &slow_label); }
static void op_set_char(const int64_t *p) { (void)p; ms_set_num(&M, SLOT_D, T_CHAR, REG_R, &slow_label); }
static void op_set_pay_int(const int64_t *p) { (void)p; ms_set_payload(&M, SLOT_D, T_INT, REG_R, &slow_label); }
static void op_set_pay_word(const int64_t *p) { (void)p; ms_set_payload(&M, SLOT_D, T_WORD, REG_R, &slow_label); }
static void op_int_add(const int64_t *p) { (void)p; ms_int_arith(&M, MS_ADD, &slow_label); }
static void op_int_sub(const int64_t *p) { (void)p; ms_int_arith(&M, MS_SUB, &slow_label); }
static void op_int_mul(const int64_t *p) { (void)p; ms_int_arith(&M, MS_MUL, &slow_label); }
static void op_int_neg(const int64_t *p) { (void)p; ms_int_neg(&M, &slow_label); }
static void op_int_to_char(const int64_t *p) { (void)p; ms_int_to_char(&M, &slow_label); }
static void op_word_add(const int64_t *p) { (void)p; ms_word_arith(&M, MS_ADD, &slow_label); }
static void op_word_sub(const int64_t *p) { (void)p; ms_word_arith(&M, MS_SUB, &slow_label); }
static void op_word_mul(const int64_t *p) { (void)p; ms_word_arith(&M, MS_MUL, &slow_label); }
static void op_word_and(const int64_t *p) { (void)p; ms_word_arith(&M, MS_AND, &slow_label); }
static void op_word_or(const int64_t *p) { (void)p; ms_word_arith(&M, MS_OR, &slow_label); }
static void op_word_xor(const int64_t *p) { (void)p; ms_word_arith(&M, MS_XOR, &slow_label); }
static void op_word_not(const int64_t *p) { (void)p; ms_word_not(&M, &slow_label); }
static void op_word_to_int(const int64_t *p) { (void)p; ms_word_to_int(&M, 0, &slow_label); }
static void op_word_to_int_x(const int64_t *p) { (void)p; ms_word_to_int(&M, 1, &slow_label); }
static void op_int_to_word(const int64_t *p) { (void)p; ms_int_to_word(&M, &slow_label); }
static void op_untag_int(const int64_t *p) { (void)p; ms_untag(&M, REG_R, T_INT); }
static void op_untag_word(const int64_t *p) { (void)p; ms_untag(&M, REG_R, T_WORD); }
static void op_load_obj(const int64_t *p) { (void)p; ms_load_obj(&M, REG_R, SLOT_S, KIND_MARK, &unless_label); }
static void op_load_tag_of_con(const int64_t *p) { (void)p; ms_load_tag_of_con(&M, REG_R, SLOT_S, &unless_label); }
static void op_alloc(const int64_t *p) { ms_alloc(&M, (int)p[0], (int)p[1], (uint32_t)p[2], &slow_label); }
static void op_store_field(const int64_t *p) { ms_store_field(&M, REG_B, (uint32_t)p[0], SLOT_S); }
static void op_set_field(const int64_t *p) { ms_set_field(&M, REG_B, (uint32_t)p[0], SLOT_S); }
static void op_load_field(const int64_t *p) { ms_load_field(&M, SLOT_D, REG_B, (uint32_t)p[0]); }
static void op_load_len(const int64_t *p) { (void)p; ms_load_len(&M, REG_R, REG_B); }
static void op_check_len(const int64_t *p) { ms_check_len(&M, REG_B, (uint32_t)p[0], &unless_label); }
static void op_load_contag(const int64_t *p) { (void)p; ms_load_contag(&M, REG_R, REG_B); }
static void op_need_len(const int64_t *p) { ms_need_len(&M, REG_B, (uint32_t)p[0], &unless_label); }
static void op_store_field_imm(const int64_t *p) { ms_store_field_imm(&M, REG_B, (uint32_t)p[0], T_INT, (int32_t)p[1]); }
static void op_load_field_payload(const int64_t *p) { ms_load_field_payload(&M, REG_R, REG_B, (uint32_t)p[0]); }
static void op_element(const int64_t *p) { (void)p; ms_element(&M, R_S0, R_S1); }
static void op_string_byte(const int64_t *p) { (void)p; ms_string_byte(&M, R_S1, R_S0, R_S1); }
enum { SLOT_FROM = 2500, SLOT_TO = 2600 };
static void op_copy_mem(const int64_t *p) { (void)p; ms_copy(&M, SLOT_TO, SLOT_FROM); }

/* the point a wide immediate is fitted at: past what a store of 32 bits holds */
#define WIDE ((int64_t)1 << 40)
static const Op ops[] = {
    { "checkImm line (s, unless)", op_check_imm, {{0,0}}, 0, 0 },
    { "set line (d, v)", op_set, {{"v", 5}}, 1, 0 },
    { "setWide line (d, v)", op_set_wide, {{"v", WIDE}}, 1, 0 },
    { "setImm line (d, r)", op_set_imm, {{0,0}}, 0, 0 },
    { "setBits line (d, r)", op_set_bits, {{0,0}}, 0, 0 },
    { "loadBits line (r, s)", op_load_bits, {{0,0}}, 0, 0 },
    { "loadPayload line (r, s)", op_load_payload, {{0,0}}, 0, 0 },
    { "copy line (d, s)", op_copy, {{0,0}}, 0, 0 },
    { "loadReal line (s, unless, l)", op_load_real, {{0,0}}, 0, 1 },
    { "loadReal1 line (s, unless, l)", op_load_real1, {{0,0}}, 0, 1 },
    { "setReal line (d, slow, l)", op_set_real, {{0,0}}, 0, 1 },
    { "testFalse line s", op_test_false, {{0,0}}, 0, 0 },
    { "oneInt line (x, slow, l)", op_one_int, {{0,0}}, 0, 1 },
    { "oneWord line (x, slow, l)", op_one_word, {{0,0}}, 0, 1 },
    { "oneChar line (x, slow, l)", op_one_char, {{0,0}}, 0, 1 },
    { "twoInt line (x, y, slow, l)", op_two_int, {{0,0}}, 0, 1 },
    { "twoWord line (x, y, slow, l)", op_two_word, {{0,0}}, 0, 1 },
    { "twoChar line (x, y, slow, l)", op_two_char, {{0,0}}, 0, 1 },
    { "twoWords line (x, y, slow)", op_two_words, {{0,0}}, 0, 1 },
    { "setInt line (d, r, slow)", op_set_int, {{0,0}}, 0, 0 },
    { "setWord line (d, r, slow)", op_set_wordnum, {{0,0}}, 0, 0 },
    { "setChar line (d, r, slow)", op_set_char, {{0,0}}, 0, 0 },
    { "setPayInt line (d, r, slow)", op_set_pay_int, {{0,0}}, 0, 0 },
    { "setPayWord line (d, r, slow)", op_set_pay_word, {{0,0}}, 0, 0 },
    { "intAdd line slow", op_int_add, {{0,0}}, 0, 1 },
    { "intSub line slow", op_int_sub, {{0,0}}, 0, 1 },
    { "intMul line slow", op_int_mul, {{0,0}}, 0, 1 },
    { "intNeg line slow", op_int_neg, {{0,0}}, 0, 1 },
    { "intToChar line slow", op_int_to_char, {{0,0}}, 0, 1 },
    { "wordAdd line slow", op_word_add, {{0,0}}, 0, 1 },
    { "wordSub line slow", op_word_sub, {{0,0}}, 0, 1 },
    { "wordMul line slow", op_word_mul, {{0,0}}, 0, 1 },
    { "wordAnd line slow", op_word_and, {{0,0}}, 0, 1 },
    { "wordOr line slow", op_word_or, {{0,0}}, 0, 1 },
    { "wordXor line slow", op_word_xor, {{0,0}}, 0, 1 },
    { "wordNot line slow", op_word_not, {{0,0}}, 0, 1 },
    { "wordToInt line slow", op_word_to_int, {{0,0}}, 0, 1 },
    { "wordToIntX line slow", op_word_to_int_x, {{0,0}}, 0, 1 },
    { "intToWord line slow", op_int_to_word, {{0,0}}, 0, 1 },
    { "untagInt line r", op_untag_int, {{0,0}}, 0, 0 },
    { "untagWord line r", op_untag_word, {{0,0}}, 0, 0 },
    { "loadObj line (r, s, kind, unless)", op_load_obj, {{0,0}}, 0, 0 },
    { "loadTagOfCon line (r, s, unless, l)", op_load_tag_of_con, {{0,0}}, 0, 0 },
    { "alloc line (kind, contag, n, slow)", op_alloc, {{"kind", 1}, {"contag", 3}, {"n", 2}}, 3, 1 },
    { "storeField line (b, i, s)", op_store_field, {{"i", 2}}, 1, 0 },
    { "setField line (b, i, s)", op_set_field, {{"i", 2}}, 1, 0 },
    { "loadField line (d, b, i)", op_load_field, {{"i", 2}}, 1, 0 },
    { "loadLen line (r, b)", op_load_len, {{0,0}}, 0, 0 },
    { "checkLen line (b, n, unless)", op_check_len, {{"n", 3}}, 1, 0 },
    { "loadContag line (r, b)", op_load_contag, {{0,0}}, 0, 0 },
    { "needLen line (b, n, unless)", op_need_len, {{"n", 3}}, 1, 0 },
    { "storeFieldImm line (b, i, v)", op_store_field_imm, {{"i", 2}, {"v", 5}}, 2, 0 },
    { "loadFieldPayload line (r, b, i)", op_load_field_payload, {{"i", 2}}, 1, 0 },
    { "element line ()", op_element, {{0,0}}, 0, 1 },
    { "stringByte line ()", op_string_byte, {{0,0}}, 0, 1 },
    { "copyMem line (from, to)", op_copy_mem, {{0,0}}, 0, 0 },
};

int main(void) {
    ms_init(&M, 4096, 0, 0, NULL);
    tx_slot(A, SLOT_S, "{s}");
    tx_slot(A, SLOT_D, "{d}");
    tx_slot(A, SLOT_X, "{x}");
    tx_slot(A, SLOT_Y, "{y}");
    tx_slot(A, SLOT_FROM, "*{from}");
    tx_slot(A, SLOT_TO, "*{to}");
    tx_reg(A, REG_R, "{r}");
    tx_reg(A, REG_B, "{b}");
    tx_kind_name(A, KIND_MARK, "{kind}");
#define NAME(name, value) if (name[0] == 'K' && name[1] == '_') tx_kind_name(A, (int)(value), name);
    NATIVE_OFFSETS(NAME)
#undef NAME
    as_label_init(&unless_label); tx_label_name(&unless_label, "{unless}");
    as_label_init(&slow_label); tx_label_name(&slow_label, "{slow}");
    printf("(* src/opt/x64_layout.sml -- runeopt's templates for the layout of values and\n"
           "   objects, generated by bin/runeopt-templates (runtime/register/jit/templates.c) from\n"
           "   the JIT's macro-assembler (runtime/register/jit/masm.c): DO NOT EDIT; `make templates`\n"
           "   after a change to masm.c, and `make check-templates` refuses a stale file.\n"
           "   Each function prints, through `line`, what the macro-assembler emits for the\n"
           "   operation, in runeopt's conventions (docs/native.md): s and d are the texts\n"
           "   of frame-slot displacements (slotDisp), b and r registers by number (RAX ...),\n"
           "   kind a name of rune-offsets.s, unless and slow labels, l a prefix for the\n"
           "   labels an operation makes for itself (printed through line too). A value is\n"
           "   one word and an immediate is its payload doubled and one more: the templates\n"
           "   of ints, words, chars and constructor tags (oneImm ... setWord) work on the\n"
           "   words in %%rax and %%rcx and clobber %%rdx, and those of reals use %%rdx and\n"
           "   %%r8; each takes the label of the slow path, where the primitive's C does\n"
           "   what has no immediate. *)\n"
           "structure X64Layout =\n"
           "struct\n"
           "  fun num (n : IntInf.int) : string =\n"
           "    if IntInf.< (n, IntInf.fromInt 0) then \"-\" ^ IntInf.toString (IntInf.~ n) else IntInf.toString n\n"
           "  val RAX = 0 val RCX = 1 val RDX = 2 val RBX = 3 val RSI = 6 val RDI = 7\n"
           "  val R8 = 8 val R9 = 9 val R10 = 10 val R11 = 11\n"
           "  val regs64 = Vector.fromList [\"%%rax\", \"%%rcx\", \"%%rdx\", \"%%rbx\", \"%%rsp\", \"%%rbp\", \"%%rsi\", \"%%rdi\",\n"
           "                                \"%%r8\", \"%%r9\", \"%%r10\", \"%%r11\", \"%%r12\", \"%%r13\", \"%%r14\", \"%%r15\"]\n"
           "  val regs32 = Vector.fromList [\"%%eax\", \"%%ecx\", \"%%edx\", \"%%ebx\", \"%%esp\", \"%%ebp\", \"%%esi\", \"%%edi\",\n"
           "                                \"%%r8d\", \"%%r9d\", \"%%r10d\", \"%%r11d\", \"%%r12d\", \"%%r13d\", \"%%r14d\", \"%%r15d\"]\n"
           "  fun reg64 r = Vector.sub (regs64, r)\n"
           "  fun reg32 r = Vector.sub (regs32, r)\n");
    int shift = 0;
    while ((1u << shift) < sizeof(Value)) shift++;
    printf("  (* the sizes the frame and an object's fields are cut by, and the\n"
           "     rounding of an object's payload (runtime/value.h) *)\n"
           "  val valueSize = %d\n  val valueShift = %d\n  val headerSize = %d\n"
           "  val payloadAlign = %d\n  val payloadMin = %d\n",
           (int)sizeof(Value), shift, (int)sizeof(Obj), (int)PAYLOAD_ALIGN, (int)PAYLOAD_MIN);
    {
        /* the word of an immediate, from the value interface: its payload scaled, and a constant */
        int64_t zero = (int64_t)val_bits(mk_imm(0)), step = (int64_t)val_bits(mk_imm(1)) - zero;
        printf("  (* the payloads `set` can write: those whose word a store of 32 bits holds;\n"
               "     setWide writes the others through %%rax *)\n"
               "  val setMin = ~%lld\n  val setMax = %lld\n",
               (long long)((zero - (int64_t)INT32_MIN) / step), (long long)(((int64_t)INT32_MAX - zero) / step));
    }
    printf("  (* the displacement of frame slot i from (%%r13,%%rbp), and of field i from an object *)\n"
           "  fun slotDisp i = num (IntInf.fromInt (valueSize * i))\n"
           "  fun fieldDisp i = \"OBJ_FIELDS+\" ^ num (IntInf.fromInt (valueSize * i))\n");
    printf("  (* the kinds, by number, for alloc *)\n");
#define KIND(name, value) if (name[0] == 'K' && name[1] == '_') printf("  val %s = %d\n", name, (int)(value));
    NATIVE_OFFSETS(KIND)
#undef KIND
    for (size_t i = 0; i < sizeof ops / sizeof ops[0]; i++) template(&ops[i]);
    printf("end\n");
    return 0;
}
