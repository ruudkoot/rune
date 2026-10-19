/* The JIT's view of a program in runtime/register (docs/plans/jit.md, M3): a code
   object per function -- its entry, its tier, its counters -- the modes of
   --jit, and the protocol between the driver (vm_loop, runtime/register/interp.c) and
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
    JIT_DEFAULT = 0,    /* no --jit= given: JIT_DEFAULT_MODE (runtime/register/jit.c) */
    JIT_OFF,            /* the interpreter alone */
    JIT_BASELINE,       /* tiers 0 and 1, by the counters (M6) */
    JIT_OPT,            /* tiers 0, 1 and 2 (M9) */
    JIT_ALL             /* every function compiled at load, as BEAM does */
};
/* the modes in which the loop tiers a function up by its counters (M6):
   to tier 1 under baseline, to tier 2 under opt (M9) */
#define JIT_TIERS(mode) ((mode) == JIT_BASELINE || (mode) == JIT_OPT)

/* What an engine says when it hands the VM back to the driver, with the
   VM exact (sp, pc, fp, the count) */
enum RunResult {
    RUN_HALT = 0,       /* the program ended: what vm_loop returns */
    RUN_INTERP,         /* the frame on top is the interpreter's, from vm->pc */
    RUN_NATIVE          /* the frame on top has native code: enter it (at its
                           entry for a fresh frame, at the landing its
                           callee's return word names where the callee
                           returns into it, the value in VM.ret_value) */
};

/* How compiled code returns (--jit-returns, native-frames.md, M7): by a
   jump through the frame's return word, which the caller writes
   (JIT_RET_JMP, as M4 built it), or by `call` and `ret`, the callee's
   entry storing the return address as the word and its return pushing it
   again, so that the processor predicts the return (JIT_RET_CALL). */
enum { JIT_RET_DEFAULT = 0, JIT_RET_JMP, JIT_RET_CALL };
#define JIT_RETURNS_DEFAULT JIT_RET_JMP
#define JIT_CALLS_RET(vm) (((vm)->jit.returns ? (vm)->jit.returns : JIT_RETURNS_DEFAULT) == JIT_RET_CALL)
/* A frame's return word (vm.h, isa_frame_header; native-frames.md, M4):
   where compiled code's RET goes, an odd number, which the collector takes
   for an immediate -- the interpreter's return stub (VM.ret_word) or a
   landing in compiled code, at its address plus JIT_RET_BIAS (asm.h,
   as_ret_addr): 0 where the landing is at an odd address (x86-64), 1
   where instructions are words (aarch64). */
#if defined(__aarch64__)
#define JIT_RET_BIAS 1
#else
#define JIT_RET_BIAS 0
#endif

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
    /* where the code begins: the entry of a call under --jit-returns=call,
       which stores the return address as the frame's return word and goes
       on at entry (native-frames.md, M7); entry itself else. The offsets
       of the tables below are from here. */
    const uint8_t *code;
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
    /* the known calls compiled while this function had no code, each a
       jump to the table of calls in its caller's code, patched into a
       jump here when this one is compiled (performance M6): where the
       patch goes, and the caller and its code then (a caller compiled
       again since is not patched) */
    uint32_t npending, pending_cap;
    struct PendingCall { uint8_t *site; uint32_t caller; const void *caller_entry; int call; } *pending;   /* call: the site is a call's (M7), else a jump's */
    /* the profile of the code, under --jit-profile (M8): a site per call
       through a closure, per branch and per jump back, in the order the
       code was emitted; NULL otherwise */
    uint32_t nsites;
    struct Site *sites;
    /* the landings of its calls (native-frames.md, M4): where a callee
       returns to, each the offset of its landing from the entry and the
       pc of the call's RESULT, the offsets rising -- what a frame's return
       word says of its caller, the frame's function and pc
       (jit_landing_info) */
    uint32_t nlands;
    uint32_t *land_offs;
    uint32_t *land_pcs;
    /* its arguments in registers (native-frames.md, M6): where tier 2's
       code may be entered with the parameters already in their homes --
       the first instruction's label, past the entry's landing, which
       loads them from the slots -- as its offset from the entry, or -1
       where there is none; and per parameter (the arity's) the home a
       known call puts it in, or REG_ARG_SLOT (into its slot) or
       REG_ARG_DEAD (nowhere: the callee never reads it) */
    int32_t reg_entry;
    int32_t reg_call;   /* under --jit-returns=call, the same entry for a call: the return address stored first (M7) */
    uint32_t nparams;
    int8_t *param_home;
} CodeObject;
enum { REG_ARG_SLOT = -1, REG_ARG_DEAD = -2 };

/* Where compiled code's calls go (performance M6): per function, the
   entry of its code, or the region's stub that hands the frame, pushed
   and its registers made, to the interpreter (JitProgram.call_interp);
   and the room its frame wants, its registers and its deepest stack above
   them. A call through a closure finds both by the word of the closure's
   function (2f + 1: the entry at 8 times it less 8, the room at 8 times
   it), a known call to a function that had no code when the call was
   compiled its entry; compiling a function puts its entry here,
   invalidating it the stub. VM.jit_calls is the table, which a unit
   loaded grows (jit_grow). */
typedef struct CallInfo {
    const void *entry;
    uint64_t need;
} CallInfo;

/* A site of a profile: what a call through a closure called (the first
   two functions, and how often each, and how often anything else), which
   way a branch went, how often a loop went round. */
enum SiteKind { SITE_CALL, SITE_BRANCH, SITE_LOOP };
typedef struct Site {
    uint32_t kind, pc;
    uint32_t f0, f1;        /* SITE_CALL: the callees seen first and second (UINT32_MAX: none yet) */
    uint64_t n0, n1, other; /* SITE_CALL: their counts, and the others'; SITE_BRANCH: taken, not; SITE_LOOP: n0 */
} Site;
/* a call through a closure at site s called function f (a lean helper of
   the code under --jit-profile: touches nothing of the VM) */
void jit_h_called(VM *vm, Site *s, uint32_t f);

/* The code objects of the program a VM runs, made when the driver first
   sees it, and again when the program changes (Runtime.restore). */
/* a fatal error of compiled code (compile.c, jit_fatal): what its message
   says, the pc it is told at, and whether the message's first number is
   the value the code has in rcx */
typedef struct JitFatalSite {
    uint32_t pc;
    uint32_t func;      /* the function whose code it is in (VM.func: native-frames.md, M4) */
    int32_t what, a, b;
    int value;
} JitFatalSite;

typedef struct JitProgram {
    const uint8_t *code;    /* the program these belong to */
    uint64_t epoch;         /* its VM.prog_epoch, the same while units are loaded into it */
    uint32_t nfuncs;
    CodeObject *codes;
    const void *at;         /* where native code is entered next (RUN_NATIVE) */
    /* the code region: one mapping, executable, made writable to add a
       function's code (M4); its stubs enter native code and leave it */
    uint8_t *code_mem;
    size_t code_cap, code_used;
    const void *enter_at, *leave_at;
    const void *fatal_at;       /* the stub of the fatal errors, beside them */
    JitFatalSite *fatals;           /* the fatal errors of the code, by the number it gives the stub; the process's */
    uint32_t nfatals, fatals_cap;
    uint64_t *tramp_from;       /* the trampolines of the calls into C, beside the stubs: helper to trampoline (masm.h) */
    const void **tramp_to;
    uint32_t tramp_mask;
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
    uint64_t compiled_opt;      /* of them, at tier 2 (M9) */
    uint64_t osr_entries;       /* times the interpreter went on in a function's code mid-way */
    uint64_t invalidated;       /* code objects invalidated */
    uint64_t dead_bytes;        /* their code, left in the region */
    double compile_seconds;     /* CPU time compiling (clock) */
    uint64_t *prim_calls;       /* per primitive: calls of jit_h_prim from code (--jit-stats, M7) */
    uint64_t eq_calls, eq_walked;   /* --jit-stats: poly_eq's calls from code, and those walked by values_equal in C (performance M5) */
    uint64_t pushes, pushes_c;      /* --jit-stats: handlers pushed by code, and of them by the helper (M5) */
    uint64_t raises, raises_c;      /* --jit-stats: RAISEs of code, and of them through the helper (M5) */
    /* tier 2's homes, general ([0]) and of reals ([1]): the registers a
       home could hold and those given one; their weights by the number of
       the home each has, or would have were there that many ([k]: the
       k+1st; the last for all beyond), so that the sum to k says what k
       homes hold (compile.c, choose_homes); and the functions too large to
       have any */
    uint64_t homes_wanted[2], homes_given[2], homes_weight[2][32];
    uint64_t homes_too_large;
    int profile;                /* --jit-profile (M8): the sites counted, and the functions' names kept
                                   (the program is gone when the statistics print at exit) */
    char **names;
    /* per function, the lowest register a call must fill with unit, the
       ones below it being written before anything can collect or read
       them (M7, jit_fill_from); UINT32_MAX while not yet worked out */
    uint32_t *fill_from;
    int all_meta;               /* every function has its arity in the section: a callee's code fills its own registers (M10) */
    struct JitDump *dump;       /* --jit-dump=DIR: where the code goes (jit/dump.c); NULL until the first function */
    CallInfo *calls;            /* per function, where calls go in (M6); VM.jit_calls */
    const void *call_interp;    /* the stub a call goes to where the callee has no code (M6), in the region */
    const void *ret_tramp;      /* the return trampoline (VM.ret_tramp, M6), in the region: a new world's VM is given it again (jit_make) */
    const void *barrier;        /* the stack's return barrier (VM.barrier_stub; native-frames.md, M5), in the region: and the barrier too */
    uint32_t deopt_stress;      /* --deopt-stress=N (M11): the code counts instruction boundaries here and leaves at every Nth */
    uint64_t deopt_count;
    uint64_t deopts;            /* how many times it left so */
    /* the code in the region by address (native-frames.md, M4): a range
       per function's code as it was compiled, in the order of the region
       and so of address, its function UINT32_MAX once it is invalidated;
       and a cache of the return words it was asked of last */
    struct CodeRange { uintptr_t lo, hi; uint32_t func; } *ranges;
    uint32_t nranges, ranges_cap;
    struct LandingSeen { Value word; uint32_t func, pc; } seen[256];
    uint64_t walked_landings;   /* --jit-stats: the return words of compiled code the walks of the frames read */
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
/* tier 1: function f compiled, or not (runtime/register/jit/compile.c) */
int jit_compile(VM *vm, JitProgram *jit, uint32_t f);
int jit_compile_tier(VM *vm, JitProgram *jit, uint32_t f, int tier);   /* at tier 1 or 2 (M9) */
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
/* what the return word w of a frame says of its caller where w is a
   landing in compiled code: the caller's function and the pc of the
   RESULT of the call (the walk of the frames, runtime/register/isa_regs.c);
   0 where it is none */
int jit_landing_info(VM *vm, Value w, uint32_t *func, uint32_t *pc);
/* function f's code is placed at at, size bytes: its range, for jit_landing_info */
void jit_code_placed(JitProgram *jit, uint32_t f, const void *at, size_t size);
/* runtime/register/isa_regs.c: the frames whose return word is a landing
   in the code at [lo, hi) made to return to the interpreter, each told
   its caller's function and pc in its info word; and every frame that
   returns to the interpreter given VM.ret_word, which the region's return
   stub became */
void reg_frames_to_interpreter(VM *vm, uintptr_t lo, uintptr_t hi);
void reg_frames_ret_word(VM *vm);

#endif
