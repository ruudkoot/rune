/* The body of vm/new's loop (vm/new/interp.c), which includes it twice: as
   loop_fast and as loop_traced, TRACED saying whether each instruction is
   printed first (runevm-new --trace). Not a header of its own. */

static int LOOP_NAME(VM *vm) {
    Program *p = &vm->prog;
    const uint8_t *code = p->code;
    uint32_t pc = vm->pc;
    uint64_t count = vm->instructions;
    Frame *fr = &vm->frames[vm->fp];
    Value *base = vm->stack + fr->base;
    Value *sp = vm->stack + vm->sp;
#if TRACED
#define TRACE(op, a, b, c) \
    fprintf(stderr, "[%6u] %-12s %d %d %d  sp=%zu fp=%zu\n", pc, rop_names[op], (int)(a), (int)(b), (int)(c), \
            (size_t)(sp - vm->stack), vm->fp)
#else
#define TRACE(op, a, b, c) ((void)0)
#endif
#if THREADED
    static void *const dispatch[] = {
#include "reg_labels.h"
    };
#define CASE(name) L_##name:
#define NEXT goto *dispatch[code[pc]]
    NEXT;
#include "reg_cases.h"
#else
#define CASE(name) case ROP_##name:
#define NEXT continue
    for (;;) {
        switch (code[pc]) {
#include "reg_cases.h"
        default:
            SYNC();
            vm_fatal(vm, "invalid opcode %u", code[pc]);
        }
    }
#endif
#undef CASE
#undef NEXT
#undef TRACE
}
