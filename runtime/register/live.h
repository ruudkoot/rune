/* What is live where in a function of the register bytecode (live.c). */
#ifndef RUNE_REGISTER_LIVE_H
#define RUNE_REGISTER_LIVE_H

#include "vm.h"

void reg_uses_defs(const Program *p, uint32_t pc, uint64_t *uses, uint64_t *def);
uint64_t *reg_liveness(const Program *p, uint32_t from, uint32_t to, const uint8_t *start, uint64_t *handlers);
uint64_t reg_frame_live(VM *vm, uint32_t func, uint32_t ret_pc);

#endif
