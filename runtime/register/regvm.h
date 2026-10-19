/* runtime/register: what its loop and its check of a program share about the
   register bytecode (src/isa/regs.sml, runtime/register/regops.h). */
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

/* A frame's header in the value stack (runtime/register/isa_regs.c;
   docs/plans/native-frames.md, M4): the info word, an immediate of the
   caller's function (below 2^30), the pc of the RESULT the call returns to
   (below 2^31) and what it says of the caller's base -- REG_INFO_CALLER,
   its registers end where the header begins; REG_INFO_EXPLICIT, the word
   below the info word holds it (a frame the runtime pushed above values
   of its own: vm_frame_push); REG_INFO_BOTTOM, there is no caller (the
   top level's frame). A return word is the interpreter's where it is 1
   (before the JIT's region) or VM.ret_word. */
enum { REG_HEADER = 3, REG_INFO_CALLER = 0, REG_INFO_EXPLICIT = 1, REG_INFO_BOTTOM = 2 };
static inline Value reg_info(uint32_t func, uint32_t pc, int kind) {
    return mk_imm((int64_t)(((uint64_t)pc << 32) | ((uint64_t)func << 2) | (uint64_t)kind));
}
static inline uint32_t reg_info_func(Value v) { return (uint32_t)((uint64_t)v >> 3) & 0x3fffffffu; }
static inline uint32_t reg_info_pc(Value v) { return (uint32_t)((uint64_t)v >> 33); }
static inline int reg_info_kind(Value v) { return (int)(((uint64_t)v >> 1) & 3); }
static inline int reg_interp_word(const VM *vm, Value w) { return w == 1 || w == vm->ret_word; }
/* the watermark's return barrier (isa_regs.c; native-frames.md, M5): a
   return through it, its frame's own return word given back; the
   watermark lowered to the frame based at id, the frames above it popped;
   and the barrier armed where the watermark is, the stub made */
Value reg_barrier_pass(VM *vm);
void reg_frames_lower(VM *vm, size_t id);
void reg_barrier_arm(VM *vm);

/* The byte length of the instruction at code, or 0 for an invalid opcode. */
static inline uint32_t rop_length(const uint8_t *code) {
    uint8_t op = code[0];
    if (op >= ROP__COUNT) return 0;
    return 1 + 4 * ((uint32_t)rop_nfixed[op] + rop_list_length(code));
}

#endif
