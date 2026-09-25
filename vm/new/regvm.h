/* vm/new: what its loop and its check of a program share about the
   register bytecode (src/isa/regs.sml, vm/new/regops.h). */
#ifndef RUNE_REGVM_H
#define RUNE_REGVM_H

#include "vm.h"
#include "regops.h"

/* How many registers the list of the instruction at code has, the operands
   before it being read as they are: the operand it names, a count, or the
   arity of the primitive it names (0 where that is out of range, which the
   check refuses). */
static inline uint32_t rop_list_length(const uint8_t *code) {
    uint8_t op = code[0];
    if (rop_list_at[op] < 0) return 0;
    int32_t v = read_i32(code + 1 + 4 * rop_list_at[op]);
    if (rop_list_prim[op]) return v >= 0 && v < PRIM__COUNT ? prim_arity[v] : 0;
    return v < 0 ? 0 : (uint32_t)v;
}

/* The byte length of the instruction at code, or 0 for an invalid opcode. */
static inline uint32_t rop_length(const uint8_t *code) {
    uint8_t op = code[0];
    if (op >= ROP__COUNT) return 0;
    return 1 + 4 * ((uint32_t)rop_nfixed[op] + rop_list_length(code));
}

#endif
