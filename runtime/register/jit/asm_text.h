/* runtime/register/jit/asm_text.h -- the portable assembler (asm.h) rendered as text:
   AT&T x86-64 lines in the conventions of runeopt's code (docs/native.md:
   r12 the VM, r13 the stack, rbp the frame's base in bytes, so that the
   frame's registers, r14 in the JIT, are (%r13,%rbp)). Built with
   -DRUNE_ASM_TEXT, which makes asm.h use this backend, into
   bin/runeopt-templates (templates.c): the macro-assembler's operations on
   values and objects, run once each against this backend, become the
   templates of src/opt/x64_layout.sml, so that runeopt follows the layout
   the JIT has without a copy by hand (docs/plans/heap-layout.md, D11, M3).

   What the text says by name rather than number: a field of the VM
   (VM_HEAP_USED and the rest of runtime/native/native_offsets.h), a field of an object
   (OBJ_KIND, OBJ_CONTAG, OBJ_LEN, OBJ_FIELDS+k), a kind the generator has
   named (tx_kind_name), and the holes: a frame slot the generator marked
   (tx_slot: the slot's word at [r14 + sizeof(Value) k] prints as {name}), a
   register it marked (tx_reg: prints as {name}), a label it named. The
   generator turns a hole into a parameter of the template. A value is one
   word, so what is written to a slot is a number, which the generator fits
   to the template's parameters. */
#ifndef RUNE_JIT_ASM_TEXT_H
#define RUNE_JIT_ASM_TEXT_H

#include <stddef.h>
#include <stdint.h>

typedef struct AsmTextLabel {
    const char *name;   /* the generator's name for it, or NULL: made up when first used ({l}_a, {l}_b ...) */
    char made[16];
    int bound;
} AsmTextLabel;

typedef struct AsmText {
    char **lines;
    int n, cap;
    int failed;         /* something the text cannot say: the template is not to be used */
    int nlabels;
    struct { int32_t index; const char *name; } slots[8];
    int nslots;
    struct { int reg; const char *name; } regs[8];
    int nregs;
    struct { int value; const char *name; } kinds[16];
    int nkinds;
} AsmText;

void tx_slot(AsmText *a, int32_t index, const char *name);   /* frame slot index renders as {name}; a name beginning with * is the whole operand */
void tx_reg(AsmText *a, int reg, const char *name);          /* the general register renders as {name} ({name32} in a 32-bit use) */
void tx_kind_name(AsmText *a, int value, const char *name);  /* an immediate in a kind context */
void tx_clear(AsmText *a);                                   /* the lines dropped; the holes and names kept */
void tx_label_name(AsmTextLabel *l, const char *name);

#endif
