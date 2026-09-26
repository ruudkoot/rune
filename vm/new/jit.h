/* The JIT's view of a program in vm/new (docs/plans/jit.md, M3): a code
   object per function -- its entry, its tier, its counters -- the modes of
   --jit, and the protocol between the driver (vm_loop, vm/new/interp.c) and
   the engines that run a frame: the interpreter, and the code the JIT makes.

   The driver runs whatever frame is on top at that frame's tier, and no
   engine calls another: the interpreter hands the VM back to the driver
   when the function it is about to run has a native entry, and native
   code hands it back when it must run an interpreted frame or returns
   into one. So the machine stack is one C frame deep whatever the program
   does (plus the call into C in progress), which is what lets frames be
   switched (green threads), copied (continuations) and rebuilt
   (deoptimisation) later. */
#ifndef RUNE_JIT_H
#define RUNE_JIT_H

#include "vm.h"

/* --jit=MODE (vm->jit_mode): which tiers run */
enum JitMode {
    JIT_OFF = 0,        /* the interpreter alone */
    JIT_BASELINE,       /* tiers 0 and 1, by the counters (M6) */
    JIT_OPT,            /* tiers 0, 1 and 2 (M9) */
    JIT_ALL             /* every function compiled at load, as BEAM does */
};

/* What an engine says when it hands the VM back to the driver, with the
   VM exact (sp, pc, fp, the count) */
enum RunResult {
    RUN_HALT = 0,       /* the program ended: what vm_loop returns */
    RUN_INTERP,         /* the frame on top is the interpreter's, from vm->pc */
    RUN_NATIVE          /* the frame on top has native code: enter it (at its
                           entry for a fresh frame, at the frame's native_ret
                           where it returns into one) */
};

/* One per function: the tier its code is at and the code's entry, which
   is NULL while the function is interpreted; the counters tier 0 keeps for
   the tiering policy (M6); and the code's table of pc to address (M6). An
   entry is published last, with one store, so that a compiling thread
   could publish it too (D13). */
typedef struct CodeObject {
    const void *entry;
    uint32_t tier;
    uint32_t size;          /* bytes of code */
    uint32_t calls;
    uint32_t loops;
} CodeObject;

/* The code objects of the program a VM runs, made when the driver first
   sees it, and again when the program changes (Runtime.restore). */
typedef struct JitProgram {
    const uint8_t *code;    /* the program these belong to */
    uint32_t nfuncs;
    CodeObject *codes;
    const void *at;         /* where native code is entered next (RUN_NATIVE) */
    /* the code region: one mapping, executable, made writable to add a
       function's code (M4); its stubs enter native code and leave it */
    uint8_t *code_mem;
    size_t code_cap, code_used;
    const void *enter_at, *leave_at;
    /* --jit-stats */
    uint64_t handed_native;     /* times the interpreter handed a frame to native code */
    uint64_t handed_interp;     /* times native code handed one back */
    uint64_t compiled;          /* functions given an entry */
} JitProgram;

/* The state of the VM's JIT, or NULL where the VM is built without one
   (RUNE_JIT=0). */
JitProgram *jit_program(VM *vm);
/* The entry of function f, or NULL while it is interpreted. */
static inline const void *jit_entry(JitProgram *jit, uint32_t f) {
    return jit ? jit->codes[f].entry : NULL;
}
/* Run the frame on top in its native code: what it says on handing back. */
int jit_run(VM *vm, JitProgram *jit, const void *at);
/* --jit-stats at exit */
void jit_print_stats(void);
/* --jit-check: executable memory, and code in it, work on this machine */
int jit_check(void);
/* tier 1: function f compiled, or not (vm/new/jit/compile.c) */
int jit_compile(VM *vm, JitProgram *jit, uint32_t f);

#endif
