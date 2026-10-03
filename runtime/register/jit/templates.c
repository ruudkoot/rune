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
   ({s}), a register printed as one ({r}), a label named ({unless}), a tag
   or kind number named ({tag}) -- and, for a numeric parameter (a field
   index, a count, a payload), run again with the parameter moved, so that
   every number of the text that moves with it is fitted as a linear
   expression of it (`num (8 + 16 * n)`) and checked at a third point. A
   parameter the text does not depend on linearly stops the generator. */
#include "masm.h"
#include "native/native_offsets.h"
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static Masm M;
#define A (&M.a)
enum { SLOT_S = 1000, SLOT_D = 2000 };   /* the marker slots */
enum { TAG_MARK = 0x71, KIND_MARK = 0x72 };
enum { REG_R = R_S3, REG_B = R_S4 };     /* the marker registers: {r} a result, {b} an object */
static AsmLabel unless_label, slow_label;

typedef struct { const char *name; int64_t at; } Param;
typedef void (*OpFn)(const int64_t *p);
typedef struct { const char *sml;   /* the function's name and parameters, e.g. "checkTag line (s, tag, unless)" */
                 OpFn fn; Param params[4]; int nparams; } Op;

static void die(const char *what) { fprintf(stderr, "runeopt-templates: %s\n", what); exit(2); }

/* a captured run of an operation: its lines */
typedef struct { char **lines; int n; } Run;
static Run run_op(const Op *op, const int64_t *p) {
    tx_clear(A);
    M.nfields = UINT32_MAX;
    op->fn(p);
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
            char e[128] = "num (";
            int first = 1;
            if (c) { char part[40]; snprintf(part, sizeof part, "%s%lld", c < 0 ? "~" : "", (long long)(c < 0 ? -c : c)); strcat(e, part); first = 0; }
            for (int j = 0; j < op->nparams; j++) if (coeff[j]) {
                char part[48];
                if (!first) strcat(e, " + ");
                if (coeff[j] == 1) snprintf(part, sizeof part, "%s", op->params[j].name);
                else snprintf(part, sizeof part, "%s%lld * %s", coeff[j] < 0 ? "~" : "", (long long)(coeff[j] < 0 ? -coeff[j] : coeff[j]), op->params[j].name);
                strcat(e, part);
                first = 0;
            }
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
static void op_check_tag(const int64_t *p) { (void)p; ms_check_tag(&M, SLOT_S, TAG_MARK, &unless_label); }
static void op_set(const int64_t *p) { ms_set(&M, SLOT_D, TAG_MARK, p[0]); }
static void op_set_reg(const int64_t *p) { (void)p; ms_set_reg(&M, SLOT_D, TAG_MARK, REG_R); }
static void op_load_tag(const int64_t *p) { (void)p; ms_load_tag(&M, REG_R, SLOT_S); }
static void op_load_payload(const int64_t *p) { (void)p; ms_load_payload(&M, REG_R, SLOT_S); }
static void op_copy(const int64_t *p) { (void)p; ms_copy(&M, SLOT_D, SLOT_S); }
static void op_load_real(const int64_t *p) { (void)p; ms_load_real(&M, F_S0, SLOT_S); }
static void op_load_real1(const int64_t *p) { (void)p; ms_load_real(&M, F_S1, SLOT_S); }
static void op_set_real(const int64_t *p) { (void)p; ms_set_real(&M, SLOT_D, F_S0); }
static void op_cmp_payload(const int64_t *p) { (void)p; ms_cmp_payload(&M, REG_R, SLOT_S); }
static void op_test_false(const int64_t *p) { (void)p; ms_test_false(&M, SLOT_S); }
static void op_load_obj(const int64_t *p) { (void)p; ms_load_obj(&M, REG_R, SLOT_S, KIND_MARK, &unless_label); }
static void op_load_tag_of_con(const int64_t *p) { (void)p; ms_load_tag_of_con(&M, REG_R, SLOT_S, &unless_label); }
static void op_alloc(const int64_t *p) { ms_alloc(&M, (int)p[0], (int)p[1], (uint32_t)p[2], &slow_label); }
static void op_store_field(const int64_t *p) { ms_store_field(&M, REG_B, (uint32_t)p[0], SLOT_S); }
static void op_load_field(const int64_t *p) { ms_load_field(&M, SLOT_D, REG_B, (uint32_t)p[0]); }
static void op_load_len(const int64_t *p) { (void)p; ms_load_len(&M, REG_R, REG_B); }
static void op_check_len(const int64_t *p) { ms_check_len(&M, REG_B, (uint32_t)p[0], &unless_label); }
static void op_load_contag(const int64_t *p) { (void)p; ms_load_contag(&M, REG_R, REG_B); }
static void op_need_len(const int64_t *p) { ms_need_len(&M, REG_B, (uint32_t)p[0], &unless_label); }
static void op_store_field_imm(const int64_t *p) { ms_store_field_imm(&M, REG_B, (uint32_t)p[0], TAG_MARK, (int32_t)p[1]); }
static void op_load_field_payload(const int64_t *p) { ms_load_field_payload(&M, REG_R, REG_B, (uint32_t)p[0]); }
static void op_element(const int64_t *p) { (void)p; ms_element(&M, R_S0, R_S1); }
static void op_string_byte(const int64_t *p) { (void)p; ms_string_byte(&M, R_S1, R_S0, R_S1); }
enum { SLOT_FROM = 2500, SLOT_TO = 2600 };
static void op_copy_mem(const int64_t *p) { (void)p; ms_copy(&M, SLOT_TO, SLOT_FROM); }

static const Op ops[] = {
    { "checkTag line (s, tag, unless)", op_check_tag, {{0,0}}, 0 },
    { "set line (d, tag, v)", op_set, {{"v", 5}}, 1 },
    { "setReg line (d, tag, r)", op_set_reg, {{0,0}}, 0 },
    { "loadTag line (r, s)", op_load_tag, {{0,0}}, 0 },
    { "loadPayload line (r, s)", op_load_payload, {{0,0}}, 0 },
    { "copy line (d, s)", op_copy, {{0,0}}, 0 },
    { "loadReal line s", op_load_real, {{0,0}}, 0 },
    { "loadReal1 line s", op_load_real1, {{0,0}}, 0 },
    { "setReal line d", op_set_real, {{0,0}}, 0 },
    { "cmpPayload line (r, s)", op_cmp_payload, {{0,0}}, 0 },
    { "testFalse line s", op_test_false, {{0,0}}, 0 },
    { "loadObj line (r, s, kind, unless)", op_load_obj, {{0,0}}, 0 },
    { "loadTagOfCon line (r, s, unless, l)", op_load_tag_of_con, {{0,0}}, 0 },
    { "alloc line (kind, contag, n, slow)", op_alloc, {{"kind", 1}, {"contag", 3}, {"n", 2}}, 3 },
    { "storeField line (b, i, s)", op_store_field, {{"i", 2}}, 1 },
    { "loadField line (d, b, i)", op_load_field, {{"i", 2}}, 1 },
    { "loadLen line (r, b)", op_load_len, {{0,0}}, 0 },
    { "checkLen line (b, n, unless)", op_check_len, {{"n", 3}}, 1 },
    { "loadContag line (r, b)", op_load_contag, {{0,0}}, 0 },
    { "needLen line (b, n, unless)", op_need_len, {{"n", 3}}, 1 },
    { "storeFieldImm line (b, i, tag, v)", op_store_field_imm, {{"i", 2}, {"v", 5}}, 2 },
    { "loadFieldPayload line (r, b, i)", op_load_field_payload, {{"i", 2}}, 1 },
    { "element line ()", op_element, {{0,0}}, 0 },
    { "stringByte line ()", op_string_byte, {{0,0}}, 0 },
    { "copyMem line (from, to)", op_copy_mem, {{0,0}}, 0 },
};

int main(void) {
    ms_init(&M, 4096, 0, 0, NULL);
    tx_slot(A, SLOT_S, "{s}");
    tx_slot(A, SLOT_D, "{d}");
    tx_slot(A, SLOT_FROM, "*{from}");
    tx_slot(A, SLOT_TO, "*{to}");
    tx_reg(A, REG_R, "{r}");
    tx_reg(A, REG_B, "{b}");
    tx_tag_name(A, TAG_MARK, "{tag}");
    tx_kind_name(A, KIND_MARK, "{kind}");
#define NAME(name, value) if (name[0] == 'T' && name[1] == '_') tx_tag_name(A, (int)(value), name); if (name[0] == 'K' && name[1] == '_') tx_kind_name(A, (int)(value), name);
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
           "   tag and kind the names of rune-offsets.s, unless and slow labels, l a prefix\n"
           "   for the labels an operation makes for itself (printed through line too). *)\n"
           "structure X64Layout =\n"
           "struct\n"
           "  fun num (n : int) : string = if n < 0 then \"-\" ^ Int.toString (~n) else Int.toString n\n"
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
    printf("  (* the displacement of frame slot i from (%%r13,%%rbp), and of field i from an object *)\n"
           "  fun slotDisp i = num (valueSize * i)\n"
           "  fun fieldDisp i = \"OBJ_FIELDS+\" ^ num (valueSize * i)\n");
    printf("  (* the kinds, by number, for alloc *)\n");
#define KIND(name, value) if (name[0] == 'K' && name[1] == '_') printf("  val %s = %d\n", name, (int)(value));
    NATIVE_OFFSETS(KIND)
#undef KIND
    for (size_t i = 0; i < sizeof ops / sizeof ops[0]; i++) template(&ops[i]);
    printf("end\n");
    return 0;
}
