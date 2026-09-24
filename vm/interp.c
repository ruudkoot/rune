/* The interpreter loop: an instruction at a time, from vm->pc. What each
   instruction does is its body in src/isa/stack.sml, from which runeisa
   writes the cases of the loop (interp_cases.h) and the functions of those
   it shares with the code of runeopt (ops.h). */
#include "vm.h"
#include "ops.h"

/* --- main loop --- */
int vm_run(VM *vm) {
    vm_start(vm);
    return vm_loop(vm);
}

/* The loop alone: a VM resumed from an image (vm/image.c) enters it here,
   its built-in exceptions and frames being those of the image. */
int vm_loop(VM *vm) {
    Program *p = &vm->prog;
    const uint8_t *code = p->code;
    for (;;) {
        uint32_t pc = vm->pc;
        uint8_t op = code[pc];
        int32_t a = op_nargs[op] > 0 ? read_i32(code + pc + 1) : 0;
        int32_t b = op_nargs[op] > 1 ? read_i32(code + pc + 5) : 0;
        if (vm->trace) fprintf(stderr, "[%6u] %-12s %d %d  sp=%zu fp=%zu\n", pc, op_names[op], a, b, vm->sp, vm->fp);
        vm->instructions++;
        vm->pc = pc + instr_length(op);
        Frame *fr = &vm->frames[vm->fp];

        switch (op) {
#include "interp_cases.h"
        default:
            vm_fatal(vm, "invalid opcode %u", op);
        }
    }
}
