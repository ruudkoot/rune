/* vm/new's first loop (docs/plans/middle-end.md, M5): the register bytecode
   an instruction at a time, from vm->pc. What each instruction does is its
   body in src/isa/regs.sml, from which runeisa writes the cases of the loop
   (reg_cases.h). Everything else -- frames, handlers, primitives, the
   collector, images -- is the runtime vm/portable's runevm has, from
   build/librune.a: a register is a slot of its frame on the VM's stack, so
   the runtime sees it as it sees a local. */
#include "regvm.h"

/* register x of the running frame; the stack may have moved since the
   instruction began (a push grows it), so it is found again each time */
#define R(x) (vm->stack[vm->frames[vm->fp].base + (size_t)(x)])
/* the i-th register of the instruction's list */
#define LIST(i) read_i32(L + 4 * (size_t)(i))

int vm_run(VM *vm) {
    vm_start(vm);
    return vm_loop(vm);
}

/* The loop alone: a VM resumed from an image (vm/image.c) enters it here. */
int vm_loop(VM *vm) {
    Program *p = &vm->prog;
    const uint8_t *code = p->code;
    for (;;) {
        uint32_t pc = vm->pc;
        const uint8_t *at = code + pc;
        uint8_t op = at[0];
        uint32_t nf = rop_nfixed[op];
        int32_t a = nf > 0 ? read_i32(at + 1) : 0;
        int32_t b = nf > 1 ? read_i32(at + 5) : 0;
        int32_t c = nf > 2 ? read_i32(at + 9) : 0;
        int32_t d = nf > 3 ? read_i32(at + 13) : 0;
        const uint8_t *L = at + 1 + 4 * nf;
        uint32_t n = rop_list_length(at);
        (void)c; (void)d; (void)L; (void)n;
        if (vm->trace)
            fprintf(stderr, "[%6u] %-12s %d %d %d  sp=%zu fp=%zu\n", pc, rop_names[op], a, b, c, vm->sp, vm->fp);
        vm->instructions++;
        vm->pc = pc + 1 + 4 * (nf + n);
        Frame *fr = &vm->frames[vm->fp];

        switch (op) {
#include "reg_cases.h"
        default:
            vm_fatal(vm, "invalid opcode %u", op);
        }
    }
}
