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

/* --jit=MODE (vm->jit.mode): which tiers run. No option gives
   JIT_DEFAULT, which jit_program makes the mode of the sweep's choosing
   (M6) the first time it is asked. */
enum JitMode {
    JIT_DEFAULT = 0,    /* no --jit= given: JIT_DEFAULT_MODE (vm/new/jit.c) */
    JIT_OFF,            /* the interpreter alone */
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
   the tiering policy (M6: calls of the function, and its work -- the
   iterations of its loops and the calls it makes -- against the thresholds
   of JitProgram); and the code's table of pc to
   address, one entry for each place a run of instructions begins (a jump's
   target, a loop's head, a handler, the instruction after a call, the
   RESULT after a PRIMPUSH), where the interpreter may enter the code with
   the frame as it is (M6: jit_osr). An entry is published last, with one
   store, so that a compiling thread could publish it too (D13). */
typedef struct CodeObject {
    const void *entry;
    uint32_t tier;
    uint32_t size;          /* bytes of code */
    uint32_t calls;
    uint32_t work;
    uint32_t nosr;          /* the table: pcs in order, and each one's offset from the entry */
    uint32_t *osr_pcs;
    uint32_t *osr_offs;
    /* the functions whose code jumps straight into this one's (M7): they
       go with it when it is invalidated */
    uint32_t ncallers, callers_cap;
    uint32_t *callers;
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
    /* the policy (M6): --jit=baseline compiles a function at its
       calls_threshold-th call, or when its work -- the iterations of its
       loops and the calls it makes, so that a function called once that
       runs long is compiled too, and entered when its callee returns --
       reaches work_threshold; --jit-stress=N invalidates the callee's code
       at every Nth call into compiled code */
    uint32_t calls_threshold, work_threshold;
    uint32_t stress;
    uint64_t stress_count;
    int full;                   /* the region is full: nothing more is compiled */
    /* --jit-stats */
    uint64_t handed_native;     /* times the interpreter handed a frame to native code */
    uint64_t handed_interp;     /* times native code handed one back */
    uint64_t compiled;          /* functions given an entry */
    uint64_t osr_entries;       /* times the interpreter went on in a function's code mid-way */
    uint64_t invalidated;       /* code objects invalidated */
    uint64_t dead_bytes;        /* their code, left in the region */
    double compile_seconds;     /* CPU time compiling (clock) */
    uint64_t *prim_calls;       /* per primitive: calls of jit_h_prim from code (--jit-stats, M7) */
    /* per function, the lowest register a call must fill with unit, the
       ones below it being written before anything can collect or read
       them (M7, jit_fill_from); UINT32_MAX while not yet worked out */
    uint32_t *fill_from;
} JitProgram;
/* the lowest register of function f a call must fill with unit */
uint32_t jit_fill_from(VM *vm, JitProgram *jit, uint32_t f);

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
/* The policy's compile: f compiled and timed, unless the region is full. */
void jit_tier_up(VM *vm, JitProgram *jit, uint32_t f);
/* Where the code of co goes on at pc, or NULL where no run begins there. */
const void *jit_osr(const CodeObject *co, uint32_t pc);
/* Function f interpreted again: its entry reset, and every frame and
   handler that would return into its code made to return to the
   interpreter instead. Never called while native code runs: the driver's
   protocol has none on the machine stack when the interpreter does. */
void jit_invalidate(VM *vm, JitProgram *jit, uint32_t f);
/* caller's code jumps straight into callee's: said, for invalidation */
void jit_depend(JitProgram *jit, uint32_t callee, uint32_t caller);

#endif
