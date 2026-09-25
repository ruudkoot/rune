# Roadmap: a JIT for vm/new

`vm/new` runs the register bytecode in a first loop that was handed over
by the middle-end roadmap. This roadmap plans what makes it a
state-of-the-art virtual machine for a strict, statically typed
language: the interpreter finished as tier 0, a baseline JIT that is
correct before it is fast, an optimising tier, and the hooks that the
plans around it -- green threads, another collector, an FFI, incremental
compilation -- will need from it. It was written on 2026-09-25 against
`f0ca8bd`, the commit that finished that roadmap, and committed on branch
`jit` from `89e2678`, the merge of it into master.

What it rests on:
* a reading of `vm/new`, the runtime it shares with `runevm`, the
  compiler's register target and `runeopt`, the native code generator
  whose design a JIT inherits;
* the measurements of the middle-end roadmap, the budgets of
  `tests/perf/new`, and the wall-clock timings of
  [performance.md](../performance.md) of 2026-09-25; the cycle counts M1
  takes are what the milestones are measured against (*Where we are*).
  Below, `performance.md` alone means
  [plans/performance.md](performance.md), the plan.
* the literature and the engines (*What the literature says*,
  *References*).

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done |
| M1 | Measure | |
| M2 | Tier 0: the interpreter finished | |
| M3 | The skeleton: code objects, executable memory, the driver | |
| M4 | Tier 1, straight-line code, x86-64 | |
| M5 | Tier 1 complete, and Windows | |
| M6 | Tiering, OSR entry and the code cache | |
| M7 | Tier 1 made fast | |
| M8 | Preparing tier 2: representations in the image, profiles in tier 1 | |
| M9 | Tier 2: the IR and the back end | |
| M10 | Tier 2: the optimisations | |
| M11 | Deoptimisation, OSR exit and invalidation | |
| M12 | aarch64 | |

The owner decided D1 to D14 on 2026-09-25 (*Decisions*); what starts
first is theirs too. M1 to
M7 are one part: at the end of M7 `vm/new` is meant to be at least as fast
as `runeopt`'s native code, and the owner may stop there. M8 to M12 are
sized now and planned again after M7, with its numbers.

## The request

The owner's brief, as written:

> - this is a draft plan for adding a jit compiler to vm/new
> - the roadmap should lead to a state of the art jit compiler for vm-new in steps up to your choosing
>   - do research on what the state of the art is (literature and implementation in other languages)
>   - keep in mind that rune is a strict functional programming language which may behave differently from imperative or lazy languages
> - we want to retain the interpreted mode in vm/new. you can decide if the jit for vm/new is an option that can be turned on or better implemented as a separate vm/new-jit
> - keep in mind the other future plans (most relevant will be incremental compilation (~/notes/incremental-compilation.md), more advanced garbage colletion, green threading, ffi)
>   - not part of this roadmap unless you think some of that work needs to be done first in which case flag it in the roadmap.

The owner's notes on the new VM (`~/notes/virtual-machine.md`) are the
frame this is designed in: `vm/new` is a research roadmap towards a
production VM, "a number of increasingly complex JIT compilers and
garbage collectors", evaluated empirically; the final target is a
high-core-count NUMA machine with a concurrent collector, millions of
green threads and isolated in-VM processes; delimited continuations are
the control primitive to be ready for; C, not C++; a living
`vm/new/ARCHITECTURE.md`; and "OSR, deopt, code invalidation. Needed as
soon as you speculate or reload modules. Cheap to design in; brutal to
retrofit."

**The owner's decisions after reading this roadmap (2026-09-25):** D1 to
D14, as recorded under *Decisions*; and C17 may be used in `vm/portable`
and `vm/new` where it helps performance, behind `#ifdef`s where that is
not too much trouble (*Constraints*).

| The brief asks | Answered in |
|---|---|
| the state of the art, from the literature and other implementations | *What the literature says*, *References* |
| a strict functional language behaves differently | *What is different for SML* |
| keep the interpreted mode; an option or a separate `vm/new-jit` | D1, D2, M2 |
| steps of my choosing | *The milestones*, *Why this order* |
| the other plans: what must come first, what to keep in mind | *Prerequisites and flags*; nothing must come first |

## Where we are

### vm/new today

`vm/new` is 865 lines: the first loop of middle-end M5 and what the
register instruction set contributes to the runtime.

* **The loop** (`vm/new/interp.c`, 49 lines) is a `switch` inside
  `for (;;)`. Every instruction reads `vm->pc` from memory, decodes four
  32-bit operands whether it has them or not (`vm/new/interp.c:30-33`), computes
  the length of its register list, tests `vm->trace`, adds to
  `vm->instructions` in memory, writes `vm->pc` back and finds its frame
  again (`vm/new/interp.c:41`). A register is found through the frame at every
  access, since a push may move the stack:

  ```c
  #define R(x) (vm->stack[vm->frames[vm->fp].base + (size_t)(x)])
  ```

  Every push checks for room, because the checker sets each function's
  `maxstack` to 0 (`vm/new/isa_regs.c:107`). A call is two dispatches:
  `CALL` or `CALLK`, then `RESULT`, which pops what the callee's `RET`
  pushed. None of the work that made `runevm`'s loop 41% cheaper in
  cycles (middle-end M6: state in the loop's own variables, computed goto,
  each case reading its own operands) has been done here; middle-end M5
  handed exactly that list over (middle-end.md, M5, *Handed over*).
* **The instruction set** (`src/isa/regs.sml`, 318 lines; 41
  instructions, `vm/new/regs.def`) is described in the DSL of middle-end
  M1: three-address, with a list of registers last for `TUPLE`,
  `CLOSURE`, `CONN`, `PRIM`, `CALLK` and `TAILCALLK`. Each instruction has
  its operands by kind, its flow, what it does to the handlers, whether
  it raises, and its body as lines of C. From it `runeisa`
  (`src/isa/reggen.sml`) writes `regs.def`, the tables of
  `vm/new/regops.h`, the cases of the loop (`vm/new/reg_cases.h`) and
  `src/backend/regcodes.sml`; all four are committed and `make check-isa`
  fails when they are stale. The C tables have the operand kinds and
  counts but not the flow, raises or handlers columns that the stack
  instruction set's `vm/opcodes.h` has (`op_flow`); the description has
  them, so the generator can write them. `docs/bytecode.md` still says
  the set has 36 instructions.
* **The checker and the disassembler** (`vm/new/isa_regs.c`, 143 lines)
  validate operands by kind, jump targets, `SWITCH` tables and that a
  known call passes no more arguments than the callee has registers.
  A jump target is not held to the function it is in.
* **Registers are the frame.** A frame's registers are its slots on the
  VM's value stack from its base; they start as `unit`, and the
  collector sees every one of them because they lie below the stack
  pointer. There are no stack maps, and none are needed: every slot
  carries its tag (middle-end.md, M5: "maps come when `vm/new` keeps
  values in machine registers (its JIT)").

### The runtime the JIT lives with

Everything but the loop is `runevm`'s runtime, `build/librune.a`
([runtime.md](../runtime.md), [architecture.md](../architecture.md)).

* **Values** are 16 bytes: a tag byte, seven bytes of padding and an
  `int64_t`, `uint64_t`, `double` or pointer (`vm/vm.h:29-38`). The size
  is a constraint, not an accident: images and `--count` on every width
  depend on it (`vm.h:20-28`, performance.md item 19). Unit, ints, words,
  reals, chars and nullary constructors are immediate; everything else
  is an object with an 8-byte header and a payload rounded up to 16
  bytes.
* **The collector** is a Cheney two-space copier (`vm/heap.c`, 229
  lines). A collection happens only inside `vm_alloc` (`heap.c:33-48`),
  which is reached by `TUPLE`, `CLOSURE`, `CON`, `CONN`, `NEWEXN`,
  `MKEXN`, by the primitives that allocate, and by a raise of a built-in
  exception, which allocates the exception. `CALL`, `RET` and the moves
  never collect. The roots are the value stack below `sp`, the globals,
  the constants, each frame's closure and the built-in exceptions
  (`heap.c:109-117`): precise by tag, conservative in liveness, since a
  dead register is a root until it is overwritten. There is no write
  barrier (the stores into the heap are `SETENV`, `ref_set`,
  `array_update` and a few more primitives, and two templates of
  `runeopt`), and nothing polls in a loop.
* **Frames, handlers and the stack** are three arrays that double when
  full (`vm.h:145-156`; `runtime.c`): the value stack, from 1,024 values;
  the frames, `{func, ret_pc, base, closure, native_ret}` (`vm.h:127-135`)
  from 256; the handlers, `{pc, sp, fp}`, from 64. Growing the value
  stack moves it (`realloc`), which is why `R(x)` is found again each
  time. `native_ret` is the machine address a frame of `runeopt`'s code
  returns to; an image never carries it (`vm.h:132-134`). The
  interpreter's loop does not call itself: recursion is bounded by
  memory, not by the C stack.
* **Primitives** (297: `src/isa/prims.sml`, 626 lines; `vm/prims.c`,
  2,148) are `int (*)(VM *)`. They read their arguments on the value
  stack and pop them only when the result exists, so that a collection
  during the call keeps them alive (`prims.c:1-19`); they answer 0, 1
  (raised, the machine already unwound) or 2 (`PRIM_NEW_WORLD`:
  `Runtime.restore` made this another program). Their effects are
  declared in the description and used only by the compiler: 60 are
  pure, 172 are given every effect, 62 a precise list. `rt_trace`,
  `rt_instructions`, `rt_save` and `posix_fork` read `vm->frames`,
  `vm->pc`, `vm->sp` and `vm->instructions`: whatever runs the bytecode
  keeps those exact at every `PRIM`.
* **Exceptions** are the handler stack: `PUSHHANDLER` records the code
  position, the stack height and the frame; `vm_raise`
  (`runtime.c:155`) pops to the innermost handler, resets `fp` and `sp`,
  pushes the exception and jumps; the handler's code begins with
  `CATCH`. A raise does no per-frame work.
* **Images** (`vm/image.c`, 714 lines) carry the heap, the program, the
  stack, the frames and the handlers, every value in 9 bytes, so that any
  VM restores what any other saved. The places the register bytecode
  resumes at are the `RESULT` after a `PRIMPUSH` (`vm->pc`) and the
  `RESULT` after a `CALL` or `CALLK` (each frame's `ret_pc`). `runeopt`'s
  `prepare_resume` (`vm/native.c:195`) gives every frame its `native_ret`
  from a table of the code's addresses by pc: an image is in bytecode
  terms, and the machine addresses are found again on restore.
* **The system layer** (`vm/sys.h`, answered by `sys_posix.c`,
  `sys_win.c` and `sys_none.c`) has no `mmap`, `mprotect`, `VirtualAlloc`
  or instruction-cache flush: nothing in `vm/` makes executable memory.
* **Where `vm/new` is built and tested:** for this machine only
  (`Makefile:325-327`); `make windows` and `make portability` build the
  stack VM. `make test-new`, part of `make check` (`Makefile:644-647`),
  runs `tests/lang` on it with `--checked`, holds every program of
  `tests/lang` and `tests/perf` to the bytes and objects it allocates on
  `runevm`, has the compiler as register bytecode compile itself on
  `vm/new` to the bytes `runevm` makes (`scripts/check-new.sh:60-74`), and
  runs the Basis Library suite (137,276 checks) as `rune:new`.
  `make test-stress` runs `tests/lang` on it with a collection every
  101st allocation; `bin/runevm-new-asan` is built by `make vm-asan` and
  run by hand. Its own budgets are `tests/perf/new/*.budget`
  (`tests/perf/run-perf.sh --new`).

### What the compiler gives, and withholds

The register bytecode is made from Low by `Regs` (`src/backend/regs.sml`,
282 lines; [ir.md](../ir.md)): linear scan over the blocks in order,
parameters in registers 0 to n-1, one scratch register, parallel moves
at jumps. What the JIT would like to know, and where it is:

* **Known.** Functions are contiguous ranges of the code, in order, and
  `CALLK f, n`, `TAILCALLK f, n` and `CLOSURE d, f` name their function,
  so the static call graph is in the code. A loop is the target of a
  backward `JUMP`, which the compiler makes of a self tail call and of
  nothing else (`ir.md`, *Low*). Handlers are the operands of
  `PUSHHANDLER`. A function's arity is 1 for one called through a
  closure and `n` at every `CALLK` of it.
* **Withheld.** Low is untyped as built: "the types become
  representations after closure conversion, which Low will carry when a
  target needs them" (`docs/ir.md:388-389`). Low's function record has
  `params`, `ncaptured` and `nvars` (`src/backend/low.sml:75`); the code
  keeps `{id, nlocals, code, name}` (`src/backend/code.sml:22`), and the
  `.rbc` keeps `code_offset`, `nlocals` and the name per function
  (`vm.h:74-80`). No representation, no liveness, no loop mark, no block
  structure reaches the VM. The target record has `barriers` and
  `safepoints`, both false, and nothing reads it: the middle end asks
  `Target.stack` wherever it asks (`src/backend/regs.sml:25`;
  `src/core/workers.sml:127`, `lift.sml:235`, `simplify.sml:118`).
* **What this means:** tier 1 needs nothing from the compiler. Tier 2
  needs the representations, and the middle-end roadmap promised them
  for when a target needs them: that is M8, the one compiler-side
  milestone here. Middle-end M12 left monomorphisation unbuilt "since
  `vm/new` does not unbox"; M9 and M10 are where it would start to.

### What runeopt already proves

`runeopt` ([native.md](../native.md)) is an ahead-of-time translator of
the *stack* bytecode: a program in Standard ML (`src/opt/x64.sml`, 968
lines) that writes GNU assembler text, assembled and linked with the
runtime by `cc`. It cannot be the JIT -- it needs a toolchain when it
runs, and it refuses the register bytecode's fingerprint -- but it is
the proof, on this runtime, of the design a JIT for `vm/new` should
take:

* **Templates over the VM's own frames.** A template per instruction, in
  bytecode order; the value stack, the frames and the handlers are the
  interpreter's, so the collector, traces, `Runtime.stats` and images see
  the machine they see under `runevm` (codegen's D3, option B). `r12`
  holds the VM, `r13` the stack, `rbp` the frame's base, `r15` the count;
  the code never pushes onto the machine stack.
* **The VM is exact where C can look.** `sp` and `fp` before every call
  into C that reads them; `pc` before anything that can raise, collect,
  save an image or end the program; no heap pointer in a register across
  a call into C, and the base of the stack reloaded after one.
* **Counting per run.** The count is added once for each straight run of
  instructions, and a run ends at a call, a return, a `PRIM`, a `RAISE`,
  a jump, before a jump target and before a handler. `--count` is exact
  by construction, and `make test-native` holds it to `runevm`'s on
  every program: the oracle that makes a translation verifiable.
* **Allocation inline** (five templates that copy `vm_alloc`'s fast path,
  with `--gc-stress` sent to the slow path), **59 primitives inline**
  (`fastPrim`, with `tests/opt/prims.sml` on their edge cases), **calls
  through the frame's `native_ret`**, **handlers and resume points by pc
  in tables** (`rune_handlers`, `rune_resume`), and **the layout of the
  VM by name** (`vm/native_offsets.c`), never as a number.
* **Its result:** on 2026-09-25 the compiler compiles itself in 2.82 s
  as native code, 5.03 s on `runevm` and 0.89 s as MLton's build
  ([performance.md](../performance.md), *Compiling*): native code is 1.8
  times `runevm` and MLton 3.2 times native code, after the middle end
  took most of the interpreter's overhead out of the bytecode itself.
  Where the native time went before the middle end (performance.md,
  *Where the time goes*):

  | Where | Share |
  |---|---:|
  | the collector | 27% |
  | calls (CALL, RET, TAILCALL, entries) | 19% |
  | SELECT | 9.4% |
  | SETLOCAL and LOCAL | 9.7% |
  | the tag tests | 7.8% |
  | allocation in the templates | 6.1% |
  | primitives, inline and in C | about 6% |

  A JIT that keeps every value in memory changes the second to sixth
  rows; only values in machine registers and the collector's share, which
  is the GC roadmap's, reach the rest.
* **What was measured and not built** there bounds what a JIT should try
  first: machine-stack frames instead of the VM's (codegen's D3 A) were
  at most 5% of the bootstrap, since the processor predicts the indirect
  returns; values kept in registers across a run (performance.md item
  18) at most about 5% for a change of every template.

### The measurements, and why they are stale

Middle-end M5 measured the same program on the same Low at `-O1`,
`runevm` against `vm/new` (middle-end.md, M5, *Measured*):

| | VM instructions | machine instructions | cycles |
|---|---|---|---|
| the bootstrap | 1,333.1M, 747.2M (−44%) | 73.9G, 62.9G (−15%) | 49.7G, 43.8G (−12%) |
| tak | 1.35M, 0.70M (−48%) | 76.2M, 66.1M | 48.6M, 43.6M (−10%) |
| intinf_fact | 32.3M, 17.8M (−45%) | 1,798M, 1,523M | 1,039M, 853M (−18%) |
| real_nbody | 1.34M, 0.60M (−55%) | 74.7M, 75.6M | 44.5M, 46.4M (+4%) |
| list_ops | 3.62M, 2.47M (−32%) | 233.5M, 234.3M | 145.7M, 158.9M (+9%) |
| string_ops | 4.12M, 2.81M (−32%) | 273.5M, 280.6M | 178.9M, 195.7M (+9%) |
| fib | 1.65M, 1.43M (−14%) | 91.9M, 129.7M | 51.8M, 73.4M (+41%) |

The register code executes far fewer instructions, as Shi et al. found,
and each costs more in the first loop. Then M6 took 41% of the cycles off
`runevm`'s loop and `vm/new` got nothing. The wall-clock table of
[performance.md](../performance.md), taken on 2026-09-25 at `a1a145c`,
shows the result: `vm/new` runs the programs of `tests/perf` 1.5 to 2.6
times slower than `runevm` (`fib` 12.35 ms against 5.50, `tak` 4.42
against 1.72), and the compiler compiles itself in 6.01 s on it against
5.03 s on `runevm`, 2.82 s as native code and 0.89 s as MLton's build.
What is current in instructions are the budgets: the ratio of
`tests/perf/new/NAME.budget` to `tests/perf/NAME.budget` is 0.54 for the
bootstrap, 0.57 for `compile-sigs`, 0.58 for `intinf_fact`, 0.60 for
`real_nbody`, 0.61 for `tak`, 0.62 for `list_ops` and `array_sieve`, 0.64
for `string_ops`, 0.75 for `word_bits` and 0.85 for `fib`. Bytes and
objects are equal on both VMs, as `check-new.sh` requires.

The M5 table predates M6 and M7 to M12, and the wall clock is not what
the milestones are measured in. **M1 takes cycles and instructions for
every configuration** before anything is built, and its table replaces
the M5 table here.

### The gap to MLton

MLton's build of the compiler compiles it 5.7 times faster than `runevm`
and 3.2 times faster than the native code, and on `tests/perf` the hosts'
native code runs 3 to 15 times faster than `runeopt`'s and 10 to 25 times
faster than `runevm` ([performance.md](../performance.md), 2026-09-25).
Three things make up most of it, and only one is this roadmap's:

* **Dispatch and memory traffic:** every value is loaded from and
  stored to a 16-byte slot, tag tested, through an interpreter or through
  templates that keep nothing in registers. This is what a JIT removes.
* **The collector**, 27% of native time, copying data it has copied
  before: performance.md item 13, a parallel track (D14).
* **Boxing:** MLton monomorphises, unboxes and flattens; Rune's values
  are uniform 16-byte cells and its `Value` is a constraint (item 19,
  D10). Tier 2 unboxes within a function and across known calls (M9,
  M10); the heap's representation is not this roadmap's.

So this roadmap's targets (D12) are put against `runeopt` and, on the
programs that compute rather than allocate, against MLton, and the
bootstrap is expected to stay bound by its collector until the GC
roadmap.

## What is different for SML

Most of what a JIT for JavaScript, Python, Lua or Ruby does exists
because those languages do not know their types until they run. Rune
knows them at compile time, and the compiler has already done, whole
program, what such a JIT discovers at run time: which function a call
reaches (middle-end M8, M12), which constructor a value has (M9), what
shape a datatype's values take (M11), what to inline (M10). That changes
what a JIT is for.

**What falls away:**
* **Type feedback and quickening.** No instruction has to learn the
  types of its operands; the compiler chose the instruction.
* **Hidden classes, shapes and inline caches on property access.** A
  `SELECT` reads field `i` of a tuple whose layout is fixed.
* **Deoptimisation for a type that turned out wrong.** There is no such
  event.
* **Global assumptions that can be invalidated.** No class is loaded, no
  method table is mutated, no global is redefined; SML shadows. The one
  thing that will invalidate compiled code is reloading a module, which
  is the incremental roadmap's, and this roadmap keeps its hook (M6,
  M11).

**What remains:**
* **Dispatch and decoding.** The interpreter's loop is 81% of `runevm`'s
  time (performance.md). A baseline JIT removes it and nothing else, and
  the literature says that is worth about two times on code whose
  instructions are small (*What the numbers say*). Rune's instructions
  are small.
* **Values in memory.** The interpreter and `runeopt` keep every value in
  its 16-byte slot: a load, a tag test and a store per use. Machine
  registers across instructions, blocks and calls are tier 2's work.
* **Unknown calls.** A `CALL` through a closure is the one dynamic
  dispatch SML has, and the compiler's counts say most call sites see one
  callee (middle-end.md, *What the bootstrap executes*: 90.2% of calls
  come from sites that only ever call one function). The analogue of an
  inline cache is a cache of the callee at the site, and its use is not
  a faster call -- the processor predicts a monomorphic indirect call --
  but knowing whom to inline: guarded devirtualisation, with the general
  call as the fallback, as .NET does for delegates (Toub 2022, 2023).
  That is speculation without deoptimisation.
* **Profiles.** Which branch of a match is taken, which loop is hot,
  which `Overflow` never happens: hot and cold layout, and checks moved
  to cold paths, need no guard that can fail.
* **Polymorphism.** A polymorphic function runs on uniform 16-byte
  values. A JIT can specialise it to the representation it is called
  with, lazily, as .NET's generics do for value types (Kennedy and Syme
  2001) and Julia does for every method (Bezanson et al. 2018); the
  first candidates are polymorphic equality and comparison and the code
  over `real` and `int` arrays.

**What SML adds:**
* **Tail calls everywhere.** Every loop is a tail call until the compiler
  turns a self tail call into a jump. Machine code must make a tail call
  a jump with the frame replaced, as the interpreter does; a calling
  convention that cannot is unusable (this rules out MIR, D7).
* **Allocation.** The bootstrap allocates about 1.4 GB in 27 million
  objects (`tests/perf/bootstrap.budget`, less its 10%).
  Allocation must be a bump in line, as `runeopt` does it, and the
  collector's cost is not the JIT's to remove.
* **Exceptions as control flow.** The bootstrap installs 34,991 handlers
  and raises nothing (middle-end.md), and other programs raise in loops.
  A handler stack that costs a push and a pop is the right structure;
  zero-cost tables, which make a raise expensive, are not.
* **Immutable data.** A tuple has no identity, so a JIT may keep one in
  registers and make it only where it escapes, always. This roadmap
  still does not do it (D5): the counts of `--count` are the oracle, and
  removing an allocation belongs in the compiler, where the interpreter
  sees it too.
* **Loops are already loops.** Join points (Kennedy 2007; Maurer et al.
  2017) and self tail calls give `vm/new` backward jumps, so hot loops are
  found by counting back-edges, as in an imperative language. Pycket,
  a tracing JIT for Racket, found that "finding and exploiting loops
  requires careful consideration" when calls are the only loop (Bauman
  et al. 2015); Rune has no such problem.

**Why a JIT at all, when the compiler sees the whole program.** Today:
because `runeopt` is a program of its own, for one machine, that needs a
toolchain, and `vm/new` is where native speed is headed (middle-end
D13). Soon: because the incremental roadmap will bring a REPL, units
compiled apart and modules loaded at run time, and then the code that
arrives is bytecode that no whole-program compiler saw; a JIT that
compiles whatever arrives, and that recovers across units the inlining
separate compilation lost, is what keeps that fast. And always: a JIT
has profiles an ahead-of-time compiler lacks, and a `.rbc` runs on every
machine at the speed of the one it is on.

## What the literature says

Each item: what it is, why it was built that way, what was measured, and
what of it transfers to a strict, typed language with a register
bytecode made from a typed IR. Numbers are the sources' own; the
*References* give them.

### Tiers, and why

* **V8** runs Ignition, a register-bytecode interpreter; Sparkplug
  (2021), a non-optimising compiler that translates bytecode one
  instruction at a time with no intermediate representation -- "a switch
  statement inside a for loop" -- into code whose frames are the
  interpreter's; Maglev (2023), an optimiser over a control-flow graph in
  SSA; and TurboFan, whose sea-of-nodes representation has been replaced
  by the CFG-based Turboshaft, which halved compile time (Swirski 2021;
  Verwaest et al. 2023; Mercadier 2025). Why four: an interpreter has
  "inherent overheads" of decoding and dispatch; the top tier cannot
  start before its type feedback is stable and cannot be made much
  cheaper without losing peak code; a middle tier makes "good enough
  code, fast enough". Maglev compiles about 10 times slower than
  Sparkplug and 10 times faster than TurboFan. Hot code is found by a
  budget scaled by bytecode length and spent at returns and back-edges:
  feedback after 8 invocations, Maglev at 400, TurboFan at 3,000, OSR at
  500 (`flag-definitions.h`). Sparkplug's gain was 5 to 15% on whole
  browser workloads, where much of the time is not in bytecode at all.
  *Transfers:* the tier shape, and Sparkplug's frame rule.
* **JavaScriptCore** runs LLInt, Baseline, DFG and FTL. Pizlo (2020)
  gives the cost per bytecode: 3.97 ns, 1.71 ns (2.3 times), 0.349 ns (4.9
  times over Baseline) and 0.225 ns (1.55 times over DFG). Tiers are
  entered at 500, 1,000 and 100,000 points, a call worth 15 and a loop
  iteration 1, scaled by function size and by how often the function
  was compiled before; an OSR exit costs about 2.5 µs from DFG and 10 µs
  from FTL. The DFG deliberately does no global register allocation, no
  escape analysis and no loop optimisation, so that it compiles fast; the
  FTL used LLVM until B3 replaced it in 2016 for compile time (Pizlo
  2016). *Transfers:* the calibration -- a template tier is about two
  times, and most of the DFG's 4.9 is type speculation SML has for free.
* **SpiderMonkey** generates its Baseline Interpreter and its Baseline
  JIT from one code generator, so they share frames and inline caches
  (de Mooij 2019); Warp (2020) replaced whole-program type inference by
  transpiling the baseline tiers' inline caches into the optimiser's IR,
  with "trial inlining" that gives each call site its own cache data,
  and removed 50,000 lines (de Mooij 2020). *Transfers:* one description
  for the interpreter and the compiler's emitters (D3); per-site
  profiles against profile pollution (M8).
* **HotSpot** has levels 0 (interpreter), 1 to 3 (C1, with more or less
  profiling) and 4 (C2). C1 compiles 9 to 16 times faster than C2, and
  its linear-scan register allocator is 29 to 44% of its time, "including
  the metadata for garbage collection and deoptimization" (Kotzmann et
  al. 2008). C2 does class hierarchy analysis with dependency-based
  invalidation, profile-driven inlining, uncommon traps for paths never
  taken, escape analysis (Paleczny, Vick and Click 2001); Graal's partial
  escape analysis removed up to 58.5% of allocation (Stadler, Würthinger
  and Mössenböck 2014). *Transfers:* Java is statically typed and its
  JITs still speculate -- on class hierarchies and profiles, not on
  types. For SML the hierarchy is gone and the profiles remain.
* **.NET** starts a method in tier 0 (precompiled or a minimal JIT),
  promotes it after 30 calls, compiles in the background in slices of 10
  ms; on-stack replacement (2022) puts patchpoints at loop back-edges,
  with a counter of 1,000, and the replacement method takes over the
  tier-0 frame rather than rebuilding it, for 2% more code; dynamic
  profile-guided optimisation (default in .NET 8) does guarded
  devirtualisation of virtual calls and, since .NET 7, of delegates:
  test for the callee seen, inline it, fall back to the call (dotnet
  design notes; Toub 2022, 2023). *Transfers:* F# runs on this. Its
  closures are delegates, and guarded devirtualisation of a delegate is
  exactly speculation on an ML closure's target with no deoptimisation
  (D8, M10). Reusing the frame for OSR is what D4 gives for free.
* **Graal and Truffle** partially evaluate an interpreter (Würthinger et
  al. 2017); "splitting" clones a callee per call site to keep its
  profile monomorphic, which is aimed at higher-order code. Not usable
  from a C runtime; the idea of splitting transfers (M8).
* **Android's ART** interprets, JIT-compiles from hotness counters with
  an OSR-capable code cache, writes profiles to files, and compiles ahead
  of time from those profiles; cloud profiles make first launch about
  30% faster. *Transfers:* profiles kept per unit are an option for the
  incremental roadmap.
* **Dart** JIT-compiles for development and hot reload, with inline
  caches and a speculative optimiser that "largely ignores" Dart 2's
  static types, and compiles ahead of time for release with whole-program
  type flow and no speculation (Egorov 2020). *Transfers:* a sound type
  system made speculation-free ahead-of-time code competitive; a JIT is
  kept for the interactive case. That is Rune's split between `runeopt`
  and `vm/new`, in reverse.

**How hot code is found:** counters at function entry and loop
back-edges (JSC, SpiderMonkey, Guile, Deegen, HotSpot; V8 weighted by
size); call counts plus patchpoints (.NET); hashed counters at loop and
call anchors (LuaJIT); or nothing at all, everything compiled at load
(BEAM, Chez Scheme, Julia on first call).

### Baseline compilers

* **Sparkplug** (Swirski 2021): one pass from bytecode, no IR, frames
  identical to the interpreter's so that OSR is "almost zero frame
  translation overhead", most instructions a call to a builtin the
  interpreter shares, "a fast compiler is a simple compiler". The
  debugger, profiler and unwinder needed no change. *Transfers:* the
  whole design (M4, M5).
* **Copy-and-patch** (Xu and Kjolstad 2021): clang compiles a library of
  "stencils" ahead of time, machine code with holes for operands; the
  compiler copies and patches. For WebAssembly it compiled 4.9 to 6.5
  times faster than Liftoff and its code ran 39 to 63% faster than
  Liftoff's; the precursors are Piumarta and Riccardi (1998) and Ertl and
  Gregg (2004). *Transfers:* the only method with no drift between the
  interpreter and the compiler by construction, since both come from the
  same C -- and the one this repository's build rules exclude (D3 C).
* **CPython** (PEP 744; Jin 2025, 2026; PEP 836): a specialising
  interpreter, traces of micro-ops, and copy-and-patch needing clang and
  LLVM at build time. 3.13 and 3.14 ran "slower than the interpreter to
  roughly equivalent"; 3.15 gains 4 to 12%; the 2026 draft of PEP 836
  moves from traces to methods. Its bytecodes are heavy, so dispatch is a
  small share of its time. *Transfers:* a baseline pays in proportion to
  dispatch's share; Rune's fine-grained typed instructions are at the
  favourable end, and the numbers should be taken early (M1, M4).
* **Deegen** (Xu and Kjolstad 2024): a generator that takes the
  semantics of each bytecode and writes the interpreter *and* a
  copy-and-patch baseline compiler, with tiering, OSR entry, hot and cold
  splitting and inline caches. LuaJIT Remake's interpreter is 1.31 times
  LuaJIT's and its baseline compiler 4.60 times PUC Lua -- about 1.65
  times its own interpreter -- compiling 19.1 million bytecodes a second.
  C++ with LLVM at build time, x86-64 only, and the collector is not
  implemented. *Transfers:* the closest precedent to an instruction set
  described once (middle-end D6); Rune's static types make the
  generator's hardest parts -- type guards and quickening -- unnecessary.
* **Guile 3** (Wingo 2018, 2019, 2020): the bytecode was first split into
  small primitive instructions so that the ahead-of-time compiler could
  remove type checks and unbox, which made the interpreter 18% slower on
  its own; then a template JIT on Lightening, a fork of GNU Lightning
  that emits directly, cheap enough to compile at a threshold 50 times
  lower. Every frame holds a virtual return address and a machine one,
  so interpreted and compiled frames mix. About two times on
  microbenchmarks, up to four; the manual's reasons: a template JIT is
  "very predictable", ahead-of-time optimisation "can work well for a
  language like Scheme where there is little polymorphism", and the
  whole thing is "only a few thousand lines". *Transfers:* Rune's
  situation nearly exactly; the two return addresses are `ret_pc` and
  `native_ret`.
* **BeamAsm** (Erlang/OTP 24: OTP team 2020; OTP PR 2745; the ERTS
  manual): every module is translated at load time, one instruction at a
  time, through asmjit, with no profiling, no speculation and no mixing
  with an interpreter; it relies on "the register allocation given to us
  by the Erlang compiler", pins the scheduler's state in callee-saved
  registers, and maps its code pages twice to satisfy W^X. Earlier
  attempts had failed: HiPE's switching between interpreted and native
  code, and an LLVM-based JIT that compiled too slowly. Gains: estone
  about 50%, pattern matching 170%, JSON 30 to 130%, code about 10%
  larger. OTP 25 then had the compiler write type information into
  `.beam` files for the JIT to drop checks (Gustavsson 2022).
  *Transfers:* compiling everything at load is viable when the compiler
  is this cheap (D6's `--jit=all`); the compiler's representations go
  into the `.rbc` rather than being rediscovered (M8).
* **WebAssembly baselines:** Liftoff makes code 18 to 54% slower than
  TurboFan's on real workloads, allocating registers on the fly and
  spilling at merges (Backes 2018); Winch compiles 15 to 20 times faster
  than Cranelift for code 1.1 to 1.5 times slower; Titzer (2024) finds
  every baseline compiler abstract-interprets the operand stack and
  snapshots at merges, and Wizard's single-pass compiler 5 to 28 times
  faster than its interpreter. *Transfers:* caching VM registers in
  machine registers within a block, Liftoff's way, is the second step
  after a pure template (M7).
* **Druid** generates Pharo's baseline JIT from its annotated interpreter:
  two times the interpreter, 0.7 of the hand-written JIT (Palumbo et al.
  2025). **Ruby** replaced YJIT, which versioned basic blocks lazily for
  15 to 19%, by ZJIT, a method compiler with an SSA IR, "for a higher
  ceiling" and so that a conventional design can be worked on
  (Chevalier-Boisvert et al. 2021; Shopify 2025).

### Optimising tiers, and what static types buy

* **HotSpot and Graal** show that static types remove the guards, not
  the value of profiles: inlining and layout still follow them. The trap
  is profile pollution, where shared higher-order code sees every
  caller's profile at once; SML's `List.map` and `foldl` are exactly
  that. The answers are to inline the combinator into its caller first,
  where the closure is often known -- which Rune's compiler already does
  statically (middle-end M10, M12) -- and, at run time, splitting or
  per-site caches.
* **.NET's generics** compile a specialisation per value type at run
  time and share code for reference types (Kennedy and Syme 2001).
  **Julia** specialises every method on the concrete types of its
  arguments when it is first called, infers types and generates code
  with LLVM, with no interpreter tier; performance follows type
  stability, and the cost is latency, which 1.9 answered by caching
  native code in package images (Bezanson et al. 2018; Julia 2023).
  *Transfers:* lazy specialisation per representation, and a code cache
  per unit as an option for the incremental roadmap.
* **Chez Scheme and Racket CS** compile everything to machine code at
  load time; the nanopass compiler produced code 15 to 27% faster in
  compile times "within a factor of two" of the old one (Keep and Dybvig
  2013); frames live on a Scheme stack in the heap, calls are jumps, and
  each return point carries the frame's live mask for the collector
  (`IMPLEMENTATION.md`). Racket on Chez ran "slightly faster to 50%
  slower" than Racket's old JIT, with longer load times, and interprets
  the outer layer of very large units (Flatt et al. 2019). *Transfers:*
  compile-at-load is a strong baseline and latency is its cost -- the
  reason for counters (D6).
* **Pycket** (Bauman et al. 2015) is a meta-tracing JIT for Racket over
  a CEK machine: 45% faster than Racket's JIT on average, from 4 times
  slower to 470 times faster; generic code loses 6% where Racket's
  loses 30%; weak on "recursive programs with data-dependent control
  flow", which is what a compiler is; warm-up under 10% mostly, over 50%
  on outliers. **LuaJIT and PyPy** trace; TraceMonkey was abandoned for
  trace explosion and bimodal performance (Gal et al. 2009; Nethercote
  2010). *Transfers:* a method JIT with counters, not a tracing one
  (D7).
* **OCaml** has no production JIT. OCamlJIT2 (Meurer 2010) ran 2 to 6
  times faster than `ocamlrun` on x86-64 and concluded that a stack
  bytecode designed for interpretation limits the gain -- "using a
  register machine would make just-in-time compilation the natural
  implementation choice" -- and that matching `ocamlopt` was of
  "questionable" value given that `ocamlopt` exists. Since 4.14 native
  tail calls pass extra arguments through the domain state, so a tail
  call with up to 70 arguments is guaranteed (Leroy 2021); OCaml 5's
  effects run on separately allocated fibers (Sivaramakrishnan et al.
  2021). *Transfers:* the register bytecode was the right choice; the
  case for a JIT is the interactive and incremental case, which OCaml
  answers with a native toplevel.
* **GHC** has no JIT; GHCi interprets bytecode beside compiled code, and
  a 2024 proposal would compile that bytecode by copy-and-patch (GHC
  issue 24607).
* **Standard ML.** MLton is whole-program, ahead of time: defunctorised,
  monomorphised, defunctionalised, flattened, unboxed (Weeks 2006;
  Cejtin, Jagannathan and Weeks 2000). SML/NJ compiles in
  continuation-passing style with heap-allocated continuations, and its
  MLRISC back end was replaced by LLVM with a "jump with arguments"
  convention patched in; the REPL compiles to native code directly
  (Farvardin and Reppy 2020). Poly/ML compiles to native code on x86 and
  arm64 and interprets elsewhere. Manticore's comparison of stack
  representations found the contiguous stack best for sequential code
  and linked frames worst (Farvardin and Reppy 2020b). *Transfers:*
  every production SML system generates native code; the frame that
  works is contiguous, which the VM's value stack is.

### Back ends a C runtime can use

| Back end | Language, dependency | Licence | Targets | Tail calls | Note |
|---|---|---|---|---|---|
| an emitter of one's own | C | ours | what is written | yes | V8, JSC, Guile and BEAM own theirs |
| copy-and-patch | C at run time; clang and LLVM at build time | -- | clang's | `musttail`, `preserve_none` | CPython on x86-64 and aarch64; Deegen on x86-64 |
| DynASM | C, Lua at build time | MIT | x86, x64, ARM, ARM64, PPC, MIPS | an assembler only | LuaJIT's |
| sljit | C | BSD-2 | x86, ARM, RISC-V, s390x, PPC, LoongArch, MIPS | yes | PCRE2's JIT; a small abstract register machine |
| GNU Lightning, Lightening | C | LGPL-3 | x86, x86-64, ARMv7, AArch64 | at the JIT's level | Guile's |
| asmjit, xbyak | C++ | zlib, BSD-3 | x86-64, AArch64 | assembler, plus a register allocator in asmjit | BEAM's; brings C++ |
| MIR (Makarov 2020) | C, about 23,000 lines | MIT | x86-64, aarch64, ppc64le, s390x, riscv64 | **no general tail call** (`JCALL` only without arguments or results) | SSA, GVN, inlining, linear scan; about 100 times faster than `gcc -O2` for code at 0.91 of its speed |
| libgccjit | C API over GCC | GPL-3 | GCC's | can require them | slow; Emacs uses it ahead of time |
| LLVM ORC | C++ (a C API) | Apache-2.0 | all | `musttail` | PostgreSQL pays 50 to 100 ms per query; JSC replaced it (Pizlo 2016) |
| Cranelift | Rust, no C API | Apache-2.0 | x86-64, aarch64, s390x, riscv64 | since 2023 | only 20 to 35% faster than LLVM tuned for compile time; Umbra's single-pass back end 16 times faster at similar code (Engelke and Schwarz 2024) |
| TPDE | C++ | Apache-2.0 | x86-64, AArch64 | -- | 8 to 24 times faster than LLVM -O0 (Schwarz, Kamm and Engelke 2025) |

For a runtime in C with no C++: an emitter of our own, or sljit,
DynASM or Lightening for the baseline; an SSA back end of our own for
the optimising tier, since MIR cannot make a tail call and knows nothing
of safepoints. D3 and D7 choose.

### Techniques

* **Speculation and deoptimisation.** Hölzle, Chambers and Ungar (1992)
  rebuilt interpreter frames from optimised ones to debug SELF; the
  correctness of doing so under optimisation is Flückiger et al. (2018),
  and "Deoptless" (Flückiger et al. 2022) dispatches to a specialised
  continuation instead of deoptimising. JSC's exit costs above. For SML,
  speculation with a compiled fallback needs none of it (D8);
  deoptimisation is for uncommon traps without a fallback, for
  invalidating code that a module reload made wrong, and for debugging
  optimised frames, whose traces Rune's inline-frame tables already give
  (M11).
* **On-stack replacement.** Entry at a loop head is a jump when the
  frames match (Deegen: "simply a branch"); .NET's patchpoints; the
  general form is D'Elia and Demetrescu (2018). Exit is deoptimisation.
* **Inline caches.** Deutsch and Schiffman (1984) cached the callee at a
  send site; Hölzle, Chambers and Ungar (1991) made the cache
  polymorphic, for a median 11%; Hölzle and Ungar (1994) fed the caches
  to the inliner. The analogue for ML is a cache of the function index
  at a `CALL` site (Deegen's "closure call mode" keys on the function,
  not the closure), whose value is the profile (M8, M10).
* **Counters.** At function entry and at back-edges. BEAM's reduction
  count at every call is also its preemption point, and a yieldpoint
  costs 0.3 to 2.3% (Lin et al. 2015): one counter can serve hotness,
  collection, signals and green threads (M6).
* **The code cache.** Keep code outside the collector's heap with no
  heap pointer embedded (constants come from the program's table, which
  is a root), or carry relocation tables as Chez does. Keep it within
  2 GB of the runtime so that a helper is a `rel32` call: V8 found far
  calls cost branch prediction on x86 and Apple's M1 (V8 2021).
* **The collector.** A baseline tier that keeps every value in its slot
  at every point a collection can happen needs no stack map. An
  optimising tier needs one of: maps (C1 builds them in its allocator),
  every live value written back at a safepoint, or Cranelift's "user
  stack maps", in which the front end spills references itself
  (Fitzgerald 2024). Maglev keeps tagged and untagged values in separate
  parts of the frame so the collector skips the raw ones. For Rune, the
  tags are the map (D10): a raw value written to its slot is tagged as
  it is written. A generational collector adds a barrier at stores into
  the heap, which are rare in SML and all in one place here (D14).
* **Exceptions.** Zero-cost tables make `handle` free and `raise`
  expensive; OCaml's chain of trap frames costs a few cycles to install
  and tens to raise. SML raises to control flow: the handler stack stays
  (M5).
* **Tail calls in machine code.** Chez makes calls jumps on its own
  stack; OCaml spills to the domain state; SML/NJ jumps with arguments;
  Cranelift's `tail` convention has the callee pop. Rune's `TAILCALLK`
  already moves the arguments to its own base and enters; in machine
  code that is a copy and a `jmp` (M5).
* **Unboxing across calls.** Leroy's coercions (1992); MLton's
  monomorphisation; GHC's worker/wrapper, which gives a known call an
  entry with unboxed arguments. `CALLK` is that hook (M10).
* **Platforms.** Linux: `mprotect` toggling or two mappings of the code
  (BEAM). macOS on arm64: `MAP_JIT`, per-thread write protection and an
  entitlement (Apple). Windows: `VirtualAlloc`, `VirtualProtect`,
  `FlushInstructionCache`. aarch64: flush the instruction cache after
  writing, and beware cores with different cache line sizes (Mono 2016);
  patching code another thread runs needs `membarrier`. With green
  threads on one OS thread, patching needs no synchronisation at all,
  and Deegen made the same simplification.
* **Warm-up.** Many benchmarks never reach a steady state (Barrett et
  al. 2017). Rune's measurements are whole runs of whole programs, and
  stay so (*Measuring*).

### Functional languages in particular

* **Closures and known calls:** Shao and Appel's closure conversion
  (2000) cut allocation by a third; Rune's flat closures and known calls
  are M4 and M8 of the middle end. Join points (Kennedy 2007; Maurer et
  al. 2017) become jumps with arguments, and so loops.
* **Defunctionalisation** needs the whole program (Cejtin, Jagannathan
  and Weeks 2000), and middle-end M12 measured that it does not pay on
  the compiler; the JIT's version is a guard on the callee's code with
  a fallback -- defunctionalisation by profile.
* **Allocation sinking** is always legal for immutable data (LuaJIT's
  sinking; Graal's partial escape analysis), and is deliberately not
  done by this JIT (D5).
* **Register allocation:** linear scan (Poletto and Sarkar 1999), on SSA
  without a liveness fixpoint (Wimmer and Franz 2010); SSA interference
  graphs are chordal, so spilling separates from colouring (Hack, Grund
  and Goos 2006; Braun and Hack 2009); Cranelift's regalloc2 backtracks
  like LLVM's greedy allocator; Maglev walks forward with local
  heuristics. M9 takes Wimmer and Franz.
* **Curried application:** eval/apply beats push/enter in compiled code
  (Marlow and Peyton Jones 2004). Rune's closures take one argument, so
  an unknown call checks no arity; a guard on the closure's function
  lets the compiled code call the uncurried worker directly and skip the
  partial application (M10).
* **Polymorphism:** uniform representation (OCaml, SML/NJ, Rune today),
  monomorphisation (MLton), intensional type analysis (TIL: Harper and
  Morrisett 1995; Tarditi et al. 1996), or specialisation at run time
  (.NET, Julia). The last is the JIT's, lazily, for equality, comparison
  and array code first (M10).

### What the numbers say

| Measured | Result | Source |
|---|---|---|
| JSC: interpreter to baseline; to DFG; to FTL, per bytecode | 2.3, 4.9, 1.55 times | Pizlo 2020 |
| Deegen: interpreter to baseline | about 1.65 times; 19.1M bytecodes/s compiled | Xu and Kjolstad 2024 |
| LuaJIT: interpreter to tracing JIT | about 3.2 times, collector off | derived from the same |
| BeamAsm over the interpreter | +50% estone; +30 to 130% JSON; up to 4 times | OTP 2020 |
| Guile 3 over 2.2 | about 2 times; up to 4 | Guile 3.0 news |
| OCamlJIT2 over `ocamlrun` | 2 to 6 times | Meurer 2010 |
| Druid over Pharo's interpreter | 2 times; 0.7 of the hand-written JIT | Palumbo et al. 2025 |
| Sparkplug | +5 to 15% on whole-browser metrics | Swirski 2021 |
| CPython's JIT, 3.13/3.14; 3.15 | about 0; +4 to 12% | Jin 2025, 2026 |
| Wizard: single-pass compiler over its interpreter | 5 to 28 times | Titzer 2024 |
| Liftoff's code against TurboFan's | 18 to 54% slower | Backes 2018 |
| Winch against Cranelift | 15 to 20 times faster to compile; code 1.1 to 1.5 times slower | Wasmtime RFC |
| C1 against C2, compile speed | 9 to 16 times | Kotzmann et al. 2008 |
| Maglev: compile speed | 10 times slower than Sparkplug, 10 times faster than TurboFan | Verwaest et al. 2023 |
| Turboshaft against sea of nodes | compile time halved | Mercadier 2025 |
| copy-and-patch against Liftoff | compiles 4.9 to 6.5 times faster; code 39 to 63% faster | Xu and Kjolstad 2021 |
| MIR against `gcc -O2` | about 100 times faster; code at 0.91 | Makarov 2020 |
| a single-pass back end against Cranelift | 16 times faster, similar code | Engelke and Schwarz 2024 |
| register against stack bytecode | 47% fewer instructions; 26 to 32% less time | Shi et al. 2005 |

Two numbers often repeated about these engines are not in their
sources: Sparkplug's "2 times on bytecode-bound code" (the blog gives
only whole-browser figures) and Cranelift's "10 times faster than LLVM"
(that figure is against LLVM with optimisation, from the copy-and-patch
paper; against LLVM tuned for compile time it is 20 to 35%).

### What transfers to Rune

1. **The first tier is a Sparkplug, a BeamAsm, a Guile:** one instruction
   at a time, the interpreter's frames, every value in its slot, the
   runtime for anything heavy. The compiler has already allocated the
   registers, which is BEAM's argument. Expect about two times over a
   good interpreter on code that is instructions rather than primitives
   and collection.
2. **No type feedback, no shapes, no deoptimisation for types.** What is
   dynamic in SML is the callee of a closure call and the direction of a
   branch. Speculate on those with a compiled fallback.
3. **A method compiler over a control-flow graph in SSA,** not traces,
   not a sea of nodes: where V8, JSC, Ruby and CPython have arrived or
   are heading.
4. **Compile speed buys simplicity.** At tens of megabytes of code a
   second, compiling everything at load is a mode, not a problem.
5. **Carry the compiler's knowledge into the image** rather than
   rediscover it: OTP 25's type information, Sparkplug's and BEAM's
   trust in the compiler's register allocation.
6. **One description for the interpreter and the compiler's emitters,**
   where the repository's rules allow it (Deegen, SpiderMonkey, Druid).
7. **Counters at entry and back-edges,** shaped as the yield points
   green threads and a concurrent collector will want.
8. **Frames on a managed stack, never on the machine stack,** with a
   machine return address beside the virtual one (Guile), so that
   interpreted and compiled frames mix, OSR is a jump, and a
   continuation is a copy.
9. **The platform's rules for executable memory from the first line,**
   and measurements of whole runs.

## Constraints

* **The VM stays C, with no C++.** C99 today; the owner allows C17 in
  `vm/portable` and `vm/new` where it helps performance, behind `#ifdef`s
  where that is not too much trouble, so that a C99 compiler still builds
  both. The first use changes `CFLAGS` in the `Makefile` and the rule in
  `AGENTS.md`; the likely first uses are `<stdatomic.h>` for the store
  that publishes a code object's entry (D13) and `_Static_assert` on the
  layout the emitters take by `offsetof`. The owner leans to C and asked
  to be argued with about Rust. Rust was weighed and set aside: a JIT in Rust
  inside a runtime in C would need a C API for every structure the code
  touches (`VM`, `Frame`, the heap), which is the layout `runeopt` names
  by hand today; it is worth taking up only if the VM is rewritten,
  which the owner's notes leave open. Every C++ back end (asmjit, xbyak,
  LLVM, TPDE) is out for the same reason.
* **The VM builds from a clean checkout with a C compiler alone.** What
  `runeisa` writes is committed and `make check-isa` holds it current
  (middle-end D6). A JIT whose build needs clang, LLVM or Lua is out
  (D3).
* **`--count` is the oracle at every tier.** `runevm --count` reports
  instructions executed and bytes and objects allocated, and they depend
  on the program and its input alone (runtime.md, *The same run twice*).
  `make test-native` holds `runeopt`'s code to `runevm`'s numbers on every
  program; a JIT is held the same way, at every tier, on every suite
  (D5). This is what makes a translation testable without a second
  oracle.
* **Images stay in bytecode terms.** `Runtime.save`, `--restore`,
  `Runtime.restore` and the emulated fork write frames and handlers as
  pcs; machine addresses are found again on restore, as `prepare_resume`
  does. No native code goes into an image (D11).
* **The interpreter stays a complete engine.** It is tier 0, the place
  every function starts, where deoptimised frames land, what `--trace`
  runs, and what a machine without an encoder runs.
* **Nothing of a program lives on the machine stack.** Frames are the
  VM's at every tier; the machine stack holds a call into C and nothing
  else (D4). Recursion stays bounded by memory, not by the C stack.
* **The repository's rules** (`AGENTS.md`): one commit a milestone with
  `make check` green; a change to the VM core or the system layer only
  once `make windows` and `make test-windows` pass, and to the layout of
  a value, the heap or the bytecode format only once `make
  test-portability` does; `make test-stress` and the sanitiser build for
  VM changes; `.expected` files reviewed by hand. Once `vm/new` is built
  for Windows and the portable machines (M2), those rules apply to it.
* **One output from five builds.** Only M8 touches the compiler, and its
  metadata is written by `Emit` like everything else, so `check-cross`
  and the bootstrap's fixed point hold it.
* **The 16-byte `Value` stays** through this roadmap, and is used (D10).
* **Tests are deterministic.** Tiering decides by instruction counts,
  never by time, so that `make check` runs the same code twice.

## The architecture

```
            .rbc (register bytecode; from M8, with a metadata section)
              │
              ▼
   ┌─────── the driver ───────────────────────────────────────────┐
   │  one loop per VM: runs the frame on top, at its tier          │
   │                                                               │
   │   tier 0  the interpreter (M2)     entry: bytecode pc         │
   │   tier 1  the baseline JIT (M4-M7) entry: native address      │
   │   tier 2  the optimising JIT (M9-M11)                          │
   │                                                               │
   │  code objects: entry, tier, counters, pc ──► address (M3)     │
   │  frames, handlers, value stack: the VM's, at every tier (D4)  │
   │  calls into C: one transition, state exact (M4, M5; the FFI)  │
   └───────────────────────────────────────────────────────────────┘
              │                       ▲
              ▼                       │
        the runtime: heap, primitives, images, system layer (unchanged)
```

**Three tiers, one frame.**
* **Tier 0** is the interpreter, finished as `runevm`'s was (M2): state
  in the loop's variables, computed goto, each case reading its own
  operands. It counts calls and back-edges.
* **Tier 1** translates a function one instruction at a time into
  machine code that does what the interpreter's case does, in the same
  frame, with every value in its slot (M4, M5). It is `runeopt`'s
  contract for the register bytecode, at run time, in C. Made fast (M7)
  it keeps slots in machine registers within a block and does the
  common case of the primitives `runeopt` does inline.
* **Tier 2** rebuilds a function as a control-flow graph in SSA from its
  bytecode and the metadata of M8, allocates machine registers across
  the function, unboxes what the representations allow, inlines and
  devirtualises with fallbacks, and lays hot and cold code apart (M9,
  M10). Its frame is still the interpreter's: a value in a machine
  register is written back to its tagged slot at every safepoint.

**Code objects.** A function has an `entry` -- a machine address, or a
stub that enters the interpreter -- a `tier`, its counters, and its
compiled code's table of pc to address for its loop heads, handlers and
the instruction after each call. Calls go through the entry; a
compiled function's `CALLK` is patched to a direct call once the callee
is compiled (M7). An entry is published last, with one store, so that a
compiling thread could come later (D13). Invalidating a function resets
its entry to the stub and marks its code; a frame returning into
invalidated code returns through a stub instead (M6, M11). This is the
hook the incremental roadmap's module reload takes.

**The driver: no nesting.** One driver loop per VM runs whatever frame
is on top at that frame's tier. The interpreter returns to the driver
when the next frame to run has a native entry; native code returns to
the driver, through a trampoline, when it must run an interpreted frame
or when a `RET` pops into a frame whose `native_ret` is null. Neither
calls the other; the machine stack is one C frame deep whatever the
program does, plus the call into C in progress. Everything else --
green threads as a value stack, frames and handlers per thread that the
driver switches between; delimited continuations as a copy of a segment
of the VM's stack; OSR in and out as a jump; the deoptimisation of a
tier-1 frame, which is the interpreter's frame already -- rests on this
one rule, and it is the rule that cannot be retrofitted.

**Into C, once.** Every call from compiled code into the runtime -- a
helper, a primitive, the collector, and later a foreign function --
goes through one sequence: `sp`, `fp`, `pc` and the count written to the
VM, the call, the base of the stack reloaded after (the stack may have
moved), no heap pointer kept in a machine register across it, a `Value`
passed by pointer and never by value (the System V ABI passes 16 bytes
in two registers and Win64 by a hidden pointer). The FFI's call
sequence is this one with a different callee (*Prerequisites and
flags*).

**The tags are the stack map.** Every slot of a frame carries its tag,
and the collector reads the tags. Tier 2 keeps unboxed ints, words and
reals in machine registers and pointers too, and at a safepoint --
a call, an allocation, a call into C -- writes each live value to its
slot with its tag, and reloads its pointers after. So no tier changes
the collector, and no tier needs a map beside the frame. This is what
the 16-byte `Value` buys, and why replacing it (performance.md item 19)
is a decision for before tier 2 (D10).

**Counters and tiering.** Tier 0 counts a function's calls and its
backward jumps; at a threshold the function is compiled and its entry
replaced; at a loop head the interpreter asks the code object for the
address of that pc and jumps (OSR entry). The thresholds are counts of
instructions, so a run tiers the same way twice. `--jit=off` is tier 0
alone; `--jit=baseline` tiers 0 and 1; `--jit=opt` all three;
`--jit=all` compiles every function at load, as BEAM does, for
measurement and for programs whose whole run is short. `--trace` implies
`--jit=off`. The same counters are where a collector, a signal or a
scheduler will poll later.

**What tier 2 optimises,** from the profile of the native code
(*What runeopt already proves*): machine registers across blocks and
unboxing (the 9.7% of moves and 7.8% of tag tests); inlining of small
known callees and guarded devirtualisation of `CALL` sites with one
observed callee (19% in calls); `SELECT`, `FIELD` and `DECON` without
their kind and length checks where the representation says what the
value is (9.4%); compare-and-branch in one instruction and `SWITCH` as
a jump table; bounds checks hoisted from array loops; several
allocations of one block as one bump; unboxed arguments across known
calls last. Nothing that changes what `--count` counts.

**Where the other plans plug in:** the collector at the allocation fast
path and the one store operation of the macro-assembler; green threads
and continuations at the driver and the counters; the FFI at the
transition into C and at tier 2's calling convention; incremental
compilation at the code objects, the invalidation and the metadata per
unit; a lazy front end at the instruction set, as any instruction.
*Prerequisites and flags* says when.

**`vm/new/ARCHITECTURE.md`** starts in M2 with the runtime as it is --
values, the heap, frames, the instruction set, the loop -- and every
milestone from then on adds its part, so that the file describes the VM
as built and would suffice to build it again, as the owner's notes ask.

## Decisions

Each gives the options, what favours each, and the recommendation it
was written with. The owner decided all of them on 2026-09-25:

| Decision | Chosen |
|---|---|
| D1. One VM or two | A: the JIT inside `vm/new`, `--jit=` at run time, a build option |
| D2. Tier 0 in this roadmap | A: yes, as M2 |
| D3. How tier 1's code is produced | A: C emitters over an encoder and a macro-assembler, the skeleton generated |
| D4. Frames | A: the VM's, at every tier; nothing on the machine stack |
| D5. `--count` per tier | A: exact at every tier; B to be considered after this roadmap |
| D6. Tiering | A: counters at entry and back-edges; `--jit=all` as a mode |
| D7. Tier 2's IR and language | A: an SSA IR of our own, in C; C to be considered after this roadmap |
| D8. Speculation and deoptimisation | A: with a compiled fallback first; deoptimisation in M11 |
| D9. Targets and their order | A: x86-64 Linux, Windows at M5, aarch64 last |
| D10. The 16-byte `Value` | A: keep it and use it; item 19 is decided before M9 |
| D11. `runeopt` and images | A: `runeopt` unchanged, no native code in images; B to be considered after this roadmap |
| D12. What "state of the art" means, measurably | A: tier 1 at `runeopt` or better; tier 2 1.5 times that and within 2 times MLton where it computes |
| D13. A compiling thread | as recommended: none now, designed for |
| D14. When the collector changes | as recommended: after M7 |

### D1. One VM or two

**Decided: A**, the JIT inside `vm/new`.

* **A. The JIT inside `vm/new`**, `--jit=off|baseline|opt|all` at run
  time and `RUNE_JIT=0` at build time. **Recommended.**
  * The interpreter is tier 0 and the target of every deoptimisation:
    both engines are in the binary anyway.
  * The driver, the code objects and the frames are shared, not copied.
  * A machine without an encoder (the i386 and PowerPC builds of `make
    portability`, `SYS=none`) builds the interpreter alone from the same
    sources.
* **B. A separate `bin/runevm-new-jit`.** A second binary with its own
  driver and a copy of the interpreter for the frames it cannot compile.
  Cleaner only until the first function has to move between tiers.

### D2. Tier 0 in this roadmap

**Decided: A**, tier 0 as M2.

* **A. Yes, as M2.** **Recommended.**
  * The brief keeps the interpreted mode, and the loop that was handed
    over is the first one.
  * Every number a JIT is measured against is the interpreter's. Two
    times a loop that finds its frame at every access says nothing.
  * The work is `runevm`'s M6 again, about 400 lines, and the
    generator writes half of it.
* **B. An interpreter track of its own first,** then this roadmap. Two
  roadmaps for one VM.

### D3. How tier 1's code is produced

**Decided: A**, C emitters over an encoder and a macro-assembler, the
skeleton generated.

* **A. C emitters, in two layers, with the skeleton generated.**
  **Recommended.**
  * A per-target encoder (`vm/new/jit/x64.c`, est. 600 lines: moves,
    arithmetic, compares, branches, calls, addressing modes, SSE2 for
    reals later) and a target-independent macro-assembler of about
    thirty operations -- load and store a slot, test a tag, the
    allocation fast path, a store into the heap (the one place a barrier
    goes), a call into C (the one place the ABI goes), the count of a
    run, a branch -- in which the 41 emitters are written (est. 800
    lines). Sparkplug's and BeamAsm's structure.
  * The description contributes what it is good at: `runeisa` writes
    `jit_cases.h`, the switch that decodes each instruction's operands and
    calls `emit_NAME(j, a, b, c, d, L, n)`, so an instruction without an
    emitter does not compile; and the flow, raises and handlers tables
    the C side lacks, for the ends of runs and the call sites.
  * Drift between the interpreter and the emitters is caught as
    `runeopt`'s is: `--count` equal on every suite, a program that runs
    every instruction, `--gc-stress`, the sanitiser build.
  * aarch64 is a second encoder and per-target versions of the call into
    C and the allocation (M12).
* **B. A second, structured description per instruction in the DSL,**
  from which the generator writes the emitters (Deegen's idea, on Rune's
  description).
  * A template language rich enough for tag tests with fatal paths,
    allocation, calls into C with the state made exact, and counting is
    a low-level IR -- tier 2's, written twice.
  * It promises no more than A: two descriptions per instruction either
    way. The DSL was adopted to kill mechanical drift (numbers, operands,
    tables), which A keeps killed; semantic drift is caught by `--count`
    in both.
  * The generator, in Standard ML, cannot see `vm.h`; `runeopt` needed
    `rune-offsets.s` for that. C emitters use `offsetof`.
* **C. Copy-and-patch** (Xu and Kjolstad 2021), stencils compiled by
  clang from the description's C bodies.
  * The only method with no semantic drift at all, since interpreter
    and compiler come from one C, and the one middle-end D6 had in mind.
  * Ruled out by the build: clang and LLVM at build time, or committed
    stencils that are binary, per ABI, and change with every clang
    version, so that no `check-isa`-style test can say whether they are
    stale; mingw needs Win64 stencils; the continuation-passing between
    stencils is clang's `musttail`; the bodies use `break`, `vm->pc` and
    `vm_fatal` and would be rewritten. CPython's small gains are for its
    own reasons and say nothing about Rune's. Keep it as an experiment
    to run beside A once the emitters exist, if the build rules change.
* **D. A library:** sljit or Lightening (C), DynASM (needs Lua at build
  time), MIR (no tail calls). Each brings a calling model of its own and
  no knowledge of frames, safepoints or counting; A's encoder is smaller
  than the glue would be.

### D4. Frames

**Decided: A**, the VM's frames at every tier.

* **A. The VM's frames and value stack at every tier**, the machine
  stack only inside a call into C, and the driver protocol of *The
  architecture*. **Recommended.**
  * OSR in and out is a jump; the collector's roots are unchanged;
    images are unchanged; a frame of tier 1 is an interpreter frame
    already, so deoptimising it is nothing.
  * Green threads are a stack, frames and handlers per thread switched
    in the driver; a delimited continuation is a copy of a segment.
  * Measured on `runeopt`: machine-stack frames would gain at most 5%
    (codegen.md, *D3's option A*), since the processor predicts the
    indirect returns.
* **B. Machine-stack frames** (codegen's D3 A): `call` and `ret`, a
  separate large mapped stack, guard pages, `__chkstk` on Windows, a
  restore that rebuilds the machine stack from an image, and no way to
  switch threads or capture a continuation without switching machine
  stacks.

### D5. `--count` per tier

**Decided: A**, exact at every tier. B is to be considered after this
roadmap.

* **A. Exact at every tier.** **Recommended.**
  * Instructions: counted per run, as `runeopt` does, which is a count
    per path and survives inlining and duplicated blocks (a `CALL` still
    counts one, and the callee's runs count theirs).
  * Bytes and objects: exact because the JIT removes no allocation.
    Allocation sinking and escape analysis belong in the compiler,
    where Low's allocations are explicit and the interpreter agrees
    (middle-end, *Ready for, not built*).
  * This keeps the one oracle that made `runeopt` verifiable and lets
    every suite check every tier without a second expected output.
* **B. Exact at tiers 0 and 1, free at tier 2.** Then tier 2 is checked
  by output alone, and a lost allocation is a lost check.

### D6. Tiering

**Decided: A**, counters, with `--jit=all` as a mode.

* **A. Counters at function entry and backward jumps,** in instructions,
  thresholds swept in M6; `--jit=all` compiles everything at load.
  **Recommended.**
  * Deterministic tests.
  * The same points are where a collector, a signal or a scheduler will
    poll (Lin et al. 2015: 0.3 to 2.3%).
  * Compiling everything at load is BEAM's answer, and a mode here: the
    sweep says whether it is also the default.
* **B. Compile everything at load, nothing else.** Simplest, and a short
  program pays for code it never runs; no poll points for later.

### D7. Tier 2's IR and language

**Decided: A**, an SSA IR of our own, in C. C, the metacircular tier,
is to be considered after this roadmap.

* **A. An SSA IR of our own, in C, inside `vm/new`,** in this roadmap as
  its second part, sized again after M7. **Recommended.**
  * Bytecode plus M8's metadata rebuilds blocks with parameters, so the
    IR is Low's shape in C.
  * The literature's destination (Turboshaft, Maglev, ZJIT, PEP 836).
* **B. MIR** (Makarov 2020). C, small, fast, good code -- and no general
  tail call, which SML cannot do without; no safepoints or maps; frames
  of its own.
* **C. Metacircular:** the compiler's own Low passes at run time, in
  Rune, as Chez Scheme's and Racket's compilers run in themselves and as
  the owner's notes list ("rune (low & high-level)").
  * The right sequel, once the incremental roadmap makes the compiler
    resident and this roadmap has compiled it: then Low, its passes and
    its lints are the optimising tier for free.
  * Not now: the compiler on `runevm` takes 7.3 s of CPU time to compile
    itself and cannot tier a function in time, and a JIT in Rune needs
    the JIT in C to be fast enough to run it.

### D8. Speculation and deoptimisation

**Decided: A**, a compiled fallback first, deoptimisation in M11.

* **A. Speculate with a compiled fallback first; build deoptimisation
  in M11.** **Recommended.**
  * Guarded devirtualisation of closure calls, hot and cold layout, and
    checks moved to cold paths need no frame rebuilt: the guard's other
    branch is code.
  * Deoptimisation is needed for an uncommon trap without a fallback,
    for a module reload that invalidates code with frames in it, and for
    debugging optimised frames; M11 builds it once M10 has measured what
    speculation pays.
  * What M3 designs in is exactly: frames are interpreter frames, every
    function has a patchable entry, and `ret_pc` is always in bytecode
    terms. No metadata goes into the `.rbc` before a tier consumes it.
* **B. Deoptimisation from the first optimising milestone.** Ready
  sooner, measured later, and the maps cost every compile.

### D9. Targets and their order

**Decided: A**, x86-64 Linux first, Windows in M5, aarch64 last.

* **A. x86-64 System V first (M4); Windows x86-64 in M5; aarch64 last
  (M12).** **Recommended.**
  * Windows is not a target of the encoder: it is `VirtualAlloc`,
    `VirtualProtect` and `FlushInstructionCache` in `sys_win.c` and the
    Win64 convention in the one call into C (`rcx`, `rdx`, `r8`, `r9`, 32
    bytes of shadow space, `rsi`, `rdi` and `xmm6` to `xmm15` preserved).
    Doing it in M5, while the transition is being written, costs an S;
    later it costs a rewrite. `make test-windows` then holds it.
  * aarch64 is a second encoder and can be tested here only under
    qemu-user, as PowerPC is (`make doctor`'s scopes). macOS on arm64
    adds `MAP_JIT`, per-thread write protection and an entitlement, noted
    for when there is a Mac.
* **B. x86-64 Linux only.** Cheaper now; `runeopt`'s to-revisit list has
  the same two items waiting.

### D10. The 16-byte `Value`

**Decided: A**, the 16-byte `Value` kept and used; item 19 is decided
before M9.

* **A. Keep it through this roadmap, and use it.** **Recommended.**
  * The tags are the stack map: tier 2's values in machine registers go
    back to tagged slots at safepoints and the collector is untouched at
    every tier (*The architecture*).
  * Item 19 of performance.md, 8-byte values, would replace that with
    real stack maps, per safepoint, per tier: an XL change to tier 2 if
    it comes after it. So **the owner decides item 19 before M9**, not
    after this roadmap, and this roadmap's second part is planned with
    that decision in hand.
* **B. Item 19 first.** An XL change to everything (every primitive,
  the images, every budget, `Int` and `Real` boxing or 63-bit ints)
  before any tier exists; its gain is the collector's and the heap's,
  not the JIT's.

### D11. `runeopt` and images

**Decided: A**, `runeopt` and images unchanged. B is to be considered
after this roadmap.

* **A. `runeopt` unchanged; images unchanged; no native code
  persisted.** **Recommended.**
  * `runeopt` keeps translating the stack bytecode for `vm/portable`
    (middle-end D13). When `vm/new` with its JIT is at least as fast on
    the bootstrap (M7's target), the owner decides what `runeopt` is for.
  * An image restores into the interpreter and the code cache's pc to
    address table gives every frame its `native_ret` back as the
    functions are compiled again: `prepare_resume` with an empty table.
    Codegen's D11 rejected native addresses in an image for the same
    reasons, and they hold.
* **B. Native code in images**, as MLton's `World.save`: an image for
  one machine and one build of the VM, which gives up what images are
  for.

### D12. What "state of the art" means, measurably

**Decided: A**, the four targets.

* **A. Targets.** **Recommended.**
  1. After M7, tier 1 is at least as fast as `runeopt`'s native code on
     the bootstrap and on every program of `tests/perf`, in cycles.
  2. After M10, tier 2 is at least 1.5 times tier 1 on the programs
     that compute rather than allocate (`fib`, `tak`, `word_bits`,
     `real_nbody`), and within 2 times MLton's native code on them.
  3. The bootstrap stays bound by its collector (27%) until the GC
     roadmap and item 19; this roadmap promises no MLton parity there
     and says so.
  4. Architecturally: OSR in and out, deoptimisation and invalidation
     each have a stress mode that `make check` runs; the JIT compiles
     bytecode that arrives at run time, which the incremental roadmap
     needs.
* **B. Parity with `runeopt` alone.** Enough to retire `runeopt` and
  nothing more.

### D13. A compiling thread

**Decided: as recommended.**

Not the owner's to weigh. Compilation is synchronous, on the thread that
runs the program; a code object's entry is published with one store,
last, so that a compiling thread can come with OS threads. With C17
allowed (*Constraints*) that store is an atomic of `<stdatomic.h>` where
the compiler has it. Written down as a rule in `ARCHITECTURE.md`.

### D14. When the collector changes

**Decided: as recommended**, after M7.

Performance.md's item 13, a generational collector, is a parallel track
that needs nothing of this roadmap. Its timing matters: the allocation
fast path and the store into the heap are written once, against
whichever allocator exists, in M4. So: before M4, or after M7 -- never
between. **Recommended: after M7,** so that the JIT's numbers come
first and the barrier is one operation of the macro-assembler when it
comes.

## The milestones

Every milestone is one commit, or a few, each with `make check` green,
as the repository's rules require. Where it touches the VM it also
passes `make test-stress`, the sanitiser build, `make test-windows` and
`make test-portability` (from M2, when `vm/new` is built there). Where
it moves a budget, the budgets are measured again and the commit quotes
the old and the new; a JIT tier never moves one, since `--count` is
exact (D5). Every milestone measures itself against the one before it
in cycles (*Measuring*) and adds its part to `vm/new/ARCHITECTURE.md`.
Sizes are lines of code, estimated. M1 to M7 are about 3,500 lines of C;
M8 to M12 about 6,000, and are planned again after M7.

### M1. Measure (S, about 100)

* **What:** a script, `scripts/perf-cycles.sh`, that runs `perf stat -e
  cycles:u,instructions:u` five times and keeps the least, for `runevm`
  (after M6), `runevm-new`, `runeopt`'s native code and MLton's build, on
  the bootstrap and every program of `tests/perf`; a `perf record` of
  `runevm-new` on the bootstrap, by opcode; the ratios of the budgets.
  The table goes into *Where we are* of this roadmap, replacing the M5
  table.
* **Why now:** every number this roadmap was written with predates
  `runevm`'s M6; nothing is estimated from them again.
* **Done when:** the script is committed and the table is in this file.

### M2. Tier 0: the interpreter finished (M, about 400)

* **What:** `runevm`'s M6, for `vm/new`:
  * `reggen` writes each case with its own operand reads and a table of
    labels, as `isagen` does for the stack loop (`isagen.sml:232-272`);
  * the loop keeps the frame's base, `sp`, `pc` and the count in its own
    variables, with `SYNC` before whatever reads them in the VM and
    `RELOAD` after whatever may change them (the words of `vm/interp.c`
    and `vm/loop.h`), computed goto under `__GNUC__`, a second copy of
    the loop for `--trace`;
  * the checker works out each function's deepest stack above its
    registers (a primitive's arguments, a call's result), so a push does
    not check;
  * a call that writes its result: `RESULT` folded into the return where
    the counts say it pays (measured; it changes the instruction budgets
    of `tests/perf/new` and the commit says by how much);
  * the checker holds a jump target to its own function;
  * `bin/runevm-new-asan` run by `make check`; `make windows`, `make
    portability` and `make test-portability` build and run `runevm-new`;
    `docs/bytecode.md` says 41;
  * `vm/new/ARCHITECTURE.md` begins: values, the heap, frames, handlers,
    the instruction set, the loop.
* **Not here:** no change to the compiler, and no `Safepoint`
  instruction: a backward `JUMP` is where a loop can be interrupted, and
  M6 counts it.
* **Gain:** est. 30 to 40% fewer cycles (`runevm`'s M6 gave 41%).
* **Done when:** `--count` unchanged on every program (but for the
  folded `RESULT`, quoted); cycles at or below `runevm`'s on every
  program of `tests/perf` and the bootstrap; sanitiser, stress, Windows
  and portability green.

### M3. The skeleton: code objects, executable memory, the driver (M, about 500)

* **What:**
  * `vm/sys.h` gains executable memory: allocate, make writable, make
    executable, flush; `sys_posix.c` with `mmap` and `mprotect`,
    `sys_win.c` with `VirtualAlloc`, `VirtualProtect` and
    `FlushInstructionCache`, `sys_none.c` with `ENOSYS`;
  * a code object per function in `vm/new`'s view of the program: the
    entry (a stub into the interpreter, at first), the tier, the counters
    of calls and loops, the table of pc to address (empty);
  * the driver loop and the trampoline: the interpreter returns to the
    driver when the next frame's function has a native entry, native
    code returns to it when it needs an interpreted frame or returns into
    one; a test in which two functions call each other, one per tier,
    ten million deep, and the machine stack does not grow;
  * the image's restore path asking the code cache for each frame's
    `native_ret` (finding none yet);
  * `--jit=off|all` and `--jit-stats`; `RUNE_JIT=0` builds the
    interpreter alone.
* **Measured first:** the cost of dispatching every call through the
  entry, which every tier pays.
* **Why now:** the driver's no-nesting rule is the piece that cannot be
  retrofitted; it is built while nothing depends on it.
* **Done when:** every suite passes under `--jit=all` with the stubs;
  the nesting test passes; Windows and portability build.
* **Touches:** green threads and continuations (the driver), incremental
  compilation (the entries).

### M4. Tier 1, straight-line code, x86-64 (L, about 1,500)

* **What:**
  * the encoder (`vm/new/jit/x64.c`) and the macro-assembler
    (`vm/new/jit/masm.c`, `masm.h`), with the VM's layout by `offsetof`,
    never as a number;
  * `jit_cases.h` from `reggen`, and the flow, raises and handlers
    tables;
  * emitters for every instruction that neither calls nor returns nor
    raises: the moves and constants, `GLOBAL`, `SETGLOBAL`, `ENV`,
    `SELF`, `TUPLE`, `CLOSURE`, `SELECT`, `CON`, `DECON`, `CONTAG`,
    `CONN`, `FIELD`, `NEWEXN`, `BUILTINEXN`, `MKEXN`, `EXNCON`, `EXNARG`,
    `SETENV`, `JUMP`, `JUMPIF`, `JUMPIFNOT`, `JUMPIFNOTTAG`, `SWITCH`
    through a table of addresses, `PRIM` through `prim_table` and
    `HALT`;
  * allocation in line as native.md's five templates do it: the
    `--gc-stress` test, the room, the bump, the counts, the header, the
    slow path in C;
  * the count per run, from the flow tables, exactly as native.md's
    *Counting*;
  * a fatal check calling the interpreter's message;
  * a program that runs every instruction of the register set, as
    `tests/opt/every-opcode.rasm` does for the stack set, run on the
    interpreter and on tier 1 with `--count` compared;
  * a function with a call, a handler or a raise is left to the
    interpreter through the driver, for now.
* **Why now:** correct before fast; the driver of M3 lets half a
  function set be compiled and the rest interpreted.
* **Done when:** `tests/lang` gives the same output and `--count` under
  `--jit=all` as under `--jit=off`; `--gc-stress 1` and the sanitiser
  pass.
* **Touches:** the FFI and the collector (the transition into C and the
  allocation path are written here).

### M5. Tier 1 complete, and Windows (L, about 800)

* **What:**
  * `CALL`, `CALLK`, `TAILCALL`, `TAILCALLK`, `RET` and `RESULT` through
    the frame's `native_ret` and the driver, the entry for calls checking
    the room the frame needs, tail calls as a copy into the frame's own
    base and a jump;
  * `PUSHHANDLER`, `POPHANDLER`, `CATCH` and `RAISE` through `vm_raise`
    and a handler's address by its pc;
  * `PRIMPUSH` and the places an image resumes at: the instruction after
    each call and each image primitive in the code object's table;
    `--restore`, `Runtime.restore`, the emulated fork and `Runtime.save`
    crossing between tiers and VMs;
  * `--checked`; `--trace` implying `--jit=off`;
  * the transition into C written down in `ARCHITECTURE.md` as the
    FFI's future call sequence;
  * Windows: the code memory of `sys_win.c` and the Win64 convention in
    the call into C; `make test-windows` runs `vm/new` with `--jit=all`;
  * `make test-new-jit`, part of `make check`: `tests/lang`, the Basis
    Library suite and the bootstrap's fixed point under `--jit=all`, with
    `--count` held to the interpreter's, as `make test-native` holds
    `runeopt`.
* **Measured** against tier 0 and against `runeopt`.
* **Done when:** the compiler as register bytecode compiles itself under
  `--jit=all` to the same bytes with the same `--count`; the Basis suite
  and Windows are green; stress and sanitiser pass.
* **Touches:** the FFI (the transition is fixed here), incremental
  compilation (images and entries).

### M6. Tiering, OSR entry and the code cache (M, about 500)

* **What:**
  * counters in tier 0's `CALL`, `CALLK` and backward `JUMP`, and the
    thresholds at which a function is compiled;
  * OSR entry: at a loop head the interpreter asks the code object for
    the address of the pc and jumps, the frame being the same;
  * the sweep: compile at N calls or N iterations, for several N, against
    `--jit=all` and `--jit=off`, on the bootstrap and `tests/perf`, in
    cycles and in code compiled; the default chosen from it;
  * `--jit=baseline`; the code cache's accounting in `--jit-stats`
    (functions, bytes, time compiling);
  * invalidation: a code object marked dead has its entry reset to the
    stub, and a frame returning into it returns through a stub that
    re-enters the interpreter at `ret_pc`; a test that invalidates every
    function in turn while it runs;
  * `make check` deterministic under the default: thresholds in
    instructions, `--jit=all` and `--jit=off` in the differential runs.
* **Done when:** the policy table is in this roadmap; every suite
  passes under the default, under `--jit=all` and under `--jit=off`
  with one `--count`.
* **Touches:** green threads and the collector (the poll points),
  incremental compilation (invalidation).

### M7. Tier 1 made fast (L, about 1,000)

* **What:**
  * slots cached in machine registers within a block, written through,
    forgotten at every call into C and every slow path;
  * a compare and its branch as one instruction; `JUMPIFNOTTAG` and
    `SWITCH` without the kind test where the block made the value;
  * the primitives `runeopt` does in line, ported from `fastPrim` with
    their C slow paths, and `tests/opt/prims.sml`'s edge cases run on
    `vm/new` at both tiers;
  * `CALLK` and `TAILCALLK` as a direct `call` or `jmp` once the callee
    is compiled, patched on tier-up: the first patching of code that
    exists, under W^X, and its cost measured;
  * `unit` stored only into the registers not provably written before
    the first point a collection can happen;
  * code within 2 GB of the runtime, so a helper is a `rel32` call;
  * a perf map of compiled functions, so that `perf record` names them.
* **Target:** D12's first: at or above `runeopt`'s native code on the
  bootstrap and every program of `tests/perf`.
* **Done when:** measured; `--count` exact; stress and sanitiser green.
  The owner decides here whether to go on, and what `runeopt` is now
  for (D11).

### M8. Preparing tier 2: representations in the image, profiles in tier 1 (M, about 600)

* **Compiler (about 300 lines of SML):** `Lower` and `Regs` carry a
  representation per Low variable, from the types Mid has, into a
  metadata section of the `.rbc`: per function its arity, its registers'
  representations (int, word, real, char, bool, a pointer of a known
  shape, or any), its loop heads, and its block starts with their
  parameter registers. `rbcVersion` goes up; the section is checked by
  the loader and a lint holds the representations to the code; the five
  builds write the same bytes (`check-cross`). The stack bytecode gets
  no section: `runeopt` reads none.
* **VM (about 300 lines of C):** a cache of the callee's function index
  at every `CALL` site of tier-1 code (one, two, or many), counts per
  branch and per loop, all cheap, all off when nothing will read them,
  all shown by `--jit-stats`.
* **Why here:** metadata gets a consumer, M9, in the next milestone, and
  not before (D8). This section is the compiler-runtime contract the
  owner's notes ask for, and it is per function so that a unit of the
  incremental roadmap carries its own.
* **Done when:** the lint is green on every program; the profiles show
  in `--jit-stats`; `--count` unchanged.
* **Touches:** incremental compilation (the section per unit).

### M9. Tier 2: the IR and the back end (XL, about 3,000)

* **What:**
  * bytecode and metadata to a control-flow graph in SSA, blocks with
    parameters as Low's; liveness and the call graph computed here;
  * linear scan on SSA (Wimmer and Franz 2010) onto the machine
    registers, ints, words and reals unboxed within the function from
    the representations;
  * the tagged slots as the spill area and the map: every live value
    written back with its tag at a safepoint, pointers reloaded after;
  * calls between tiers through the code objects; the same transition
    into C;
  * no speculation, no inlining: the same instructions, in registers.
* **Done when:** every suite passes under `--jit=opt` with `--count`
  exact; `--gc-stress 1` and the sanitiser pass; measured against tier 1.
* **Touches:** the FFI (a typed convention appears), green threads
  (nothing outside the frame at a safepoint).

### M10. Tier 2: the optimisations (XL, about 2,000)

Each built, measured on the bootstrap and `tests/perf`, and kept where it
pays, as middle-end M12 did:

1. registers across blocks, and unboxed values across blocks;
2. inlining of small known callees; guarded devirtualisation of a `CALL`
   site with one observed callee, the general call as the fallback;
   the curried call's guard, calling the worker directly;
3. `SELECT`, `FIELD` and `DECON` without kind and length checks where
   the representation says what the value is;
4. compare-and-branch fused; `SWITCH` as a jump table;
5. bounds checks hoisted out of loops over arrays and vectors;
6. the allocations of one block as one bump, the counts unchanged;
7. unboxed arguments and results across known calls, worker and wrapper
   on `CALLK`, last;
8. polymorphic equality and comparison specialised by the
   representation seen.

Global value numbering and loop-invariant motion only if a count says
they would pay: the simplifier does most of that before the bytecode.
Nothing here changes what `--count` counts (D5).

* **Target:** D12's second.
* **Done when:** each item's measurement is in this file; `--count`
  exact; stress and sanitiser green.

### M11. Deoptimisation, OSR exit and invalidation (L, about 1,000)

* **What:** a map at every safepoint of tier-2 code from machine
  registers to interpreter registers; the frames of inlined calls made
  VM frames again where a deoptimisation lands in one, from the inline
  frames the line table already carries; `--deopt-stress`, which
  deoptimises at every safepoint; invalidation of a code object with
  frames live in it; uncommon traps without a fallback where M10 showed
  one pays.
* **Done when:** `--deopt-stress` runs every suite with the same output
  and `--count`; traces are the same at every tier
  (`tests/lang/rt.trace_*` under each `--jit=`); the invalidation test of
  M6 passes with tier-2 frames.
* **Touches:** incremental compilation (module reload).

### M12. aarch64 (L, about 900)

* **What:** a second encoder, per-target versions of the call into C and
  the allocation, the instruction-cache flush; built and run under
  qemu-user with an aarch64 sysroot, as PowerPC is (`make doctor`'s
  scope); `ARCHITECTURE.md` says what a target must provide.
* **Done when:** the suites pass under qemu at every tier.

### Why this order

* **Measure, then the interpreter.** Tier 0 is what every number is
  against, and the owner keeps interpreted mode.
* **The skeleton before any code.** The driver's no-nesting rule and the
  code objects are the pieces that cannot be retrofitted, and they are
  cheapest while nothing runs on them.
* **Correct before fast.** M4 and M5 make a tier 1 held to `--count`;
  M6 makes the default mode the one that is measured; only then M7
  makes it fast, so that every optimisation is measured on the mode
  that ships.
* **A stopping point at M7.** Tier 1 at `runeopt`'s speed is a whole
  result: `runeopt` can be retired, and the second part planned against
  real numbers, with item 19 decided (D10).
* **Metadata when consumed,** speculation when measured, deoptimisation
  when speculation has paid, a second target when the first is done.

## Prerequisites and flags

The brief asks what of the other plans must be done first. **Nothing
must.** Tier 1 needs nothing from the compiler; the middle-end roadmap is
finished. What this roadmap designs in for each plan, and when each
becomes critical:

* **The collector** (performance.md item 13; the concurrent collector of
  the owner's notes later). Not a prerequisite. Timing per D14: before M4
  or after M7. What this roadmap gives it: every store into the heap
  through one operation of the macro-assembler, where a barrier goes;
  the allocation fast path in one place; poll points at backward jumps
  and calls (M6); no heap pointer in a machine register across a
  safepoint (M9). What it withholds: allocation sinking (D5). A
  collector that moves objects while code runs (the concurrent one) will
  want the maps of M11 and the write-back rule of M9, and nothing else
  new.
* **Green threads.** Design before M9, build after this roadmap. What
  this roadmap gives: the driver (M3), so that a thread is a value
  stack, frames and handlers switched in it; the poll points (M6); a
  value stack that already grows by `realloc`, so a thread's stack can
  start small; code patching that needs no synchronisation while there
  is one OS thread. What a scheduler across OS threads adds later:
  `membarrier` or dual-mapped code, and the compiling thread of D13.
* **Delimited continuations.** The owner's notes want one-shot fibers
  first and the exception as the abort-only case. What this roadmap
  gives: frames on the VM's stack at every tier (D4), captured only at
  safepoints, where every value is in its slot (M9's rule); `ret_pc`
  always in bytecode terms and `native_ret` found again from it, as an
  image does. The handler stack stays (M5).
* **The FFI.** Critical twice, as asked:
  1. **At M4 and M5,** where the transition into C is written: the
     state made exact, the pointers reloaded, which helpers may collect,
     a `Value` by pointer. A foreign call is that transition with
     another callee and its arguments marshalled; design it as such.
  2. **At M9,** where a typed calling convention appears: unboxed
     arguments in machine registers are what a foreign call wants.

  Callbacks from C into SML would break the no-nesting rule: decide
  before M9 whether they exist and, if so, that they run a nested driver
  of bounded depth, and that no continuation is captured across one.
* **Incremental compilation, the REPL, dynamic modules, hot reload.**
  Consumers of M3's entries, M6's and M11's invalidation, and M8's
  metadata per unit. What this roadmap gives beyond that: a JIT that
  compiles whatever bytecode arrives (D12), which is what makes units
  compiled apart fast again; and the metacircular tier as that
  roadmap's sequel (D7 C), once the compiler is resident. Profiles or
  code kept per unit (Julia's package images, ART's profiles) are
  options to weigh then.
* **8-byte values** (performance.md item 19): the owner decides before
  M9 (D10).
* **A lazy front end:** thunk, force and update as instructions of the
  same description; tier 1 compiles them as any instruction; pointer
  tagging of the STG kind (Marlow, Yakushev and Peyton Jones 2007)
  would want item 19.

## Relation to the other plans

| Elsewhere | Here |
|---|---|
| performance.md items 9, 18 (native templates) | superseded by M7 for `vm/new`; `runeopt`'s to do if it stays |
| performance.md item 13 (generational collector) | D14; the barrier is one operation |
| performance.md item 19 (8-byte values) | D10; decided before M9 |
| codegen.md, *D3's option A* (machine-stack frames) | D4, B: not taken |
| codegen.md, *Windows and other processors* | M5, M12 |
| codegen.md, *Debugging* (backtraces, DWARF) | a perf map in M7; a debugger's view of compiled frames out of scope |
| native.md, *Keeping it in step* | the same rules for the emitters, in `AGENTS.md` (M4) |
| middle-end.md, *Ready for, not built*: JIT, deoptimisation, OSR | D8, M6, M11 |
| middle-end.md, *Ready for, not built*: other collectors, safepoints | a backward `JUMP` is the safepoint; `store_field` the barrier |
| middle-end.md, *Ready for, not built*: the FFI | *Prerequisites and flags* |
| middle-end.md, *Two bytecodes*: `vm/new`'s convention for primitives | unchanged: arguments pushed, as now; a window convention is measured in M7 if `PRIM` shows in the profile |
| the owner's notes, S2 of `missing-roadmaps.md` (the compiler-runtime contract) | M8 |

## Risks

1. **Tier 1 gains less than the literature's two times**, because the
   time is in primitives and the collector, not in dispatch (CPython's
   lesson). M1 says how much is dispatch before anything is built; M4
   measures the straight-line subset early; M7's inline primitives are
   the lever if the profile says so.
2. **The interpreter and the emitters drift apart.** `--count` equality
   on every suite at every tier, the generated `jit_cases.h`, the
   every-instruction program, `--gc-stress` and the sanitiser build; a
   rule in `AGENTS.md` that an instruction is a description, an emitter
   and a use in that program.
3. **A pointer kept across a call into C or an allocation.** The
   collector and `realloc` move everything; `--gc-stress 1` and the
   sanitiser find it, as they do for `runeopt`, and both run in `make
   check` for `vm/new`.
4. **Mixed-mode nesting** blows the machine stack in a recursion that
   alternates tiers. The driver protocol of M3, and its test, before any
   code is compiled.
5. **Executable memory** differs by platform: W^X on Linux, `MAP_JIT` on
   macOS, `VirtualProtect` and Control Flow Guard on Windows, the
   instruction cache on aarch64. All behind `sys.h`; the cost of
   toggling measured in M6 and M7, with two mappings as the fallback.
6. **Tier 2 grows without bound** in scope and compile time. A budget
   per function in `--jit-stats`; M10 kept per optimisation only where
   it pays; M9 to M12 planned again after M7.
7. **The 16-byte value caps the bootstrap's gain.** D12 says so; item 19
   is decided before M9.
8. **Tests become non-deterministic** under tiering. Thresholds in
   instructions; `--jit=all` and `--jit=off` in the differential runs;
   the profiles of M8 off when `--count` is read.
9. **Other sessions commit on the branch** while a milestone is in
   progress (M12 of the middle end landed during the writing of this
   roadmap). `git log` before every commit, as the repository's rules
   say.

## Testing a JIT

* **The oracle** is `--count`: instructions, bytes and objects equal to
  the interpreter's at every tier, on `tests/lang`, `tests/perf`, the
  Basis Library suite, `tests/external`, the corpus of
  `rune-corpus-sml97` and the bootstrap's fixed point (`make
  test-new-jit`, M5), as `make test-native` holds `runeopt`.
* **Every instruction,** in a program run at every tier (M4).
* **Stress:** `--gc-stress 1`, the sanitiser build, `--deopt-stress`
  (M11), the invalidation test (M6), the nesting test (M3).
* **Every mode** in the differential runs: `--jit=off`, `baseline`,
  `opt`, `all`, as `make check-levels` runs every optimisation level.
* **Images** crossing between tiers, between `vm/new` and `runevm`, and
  between machines (`make test-portability`).
* **Platforms:** Windows at every tier from M5; the interpreter alone on
  i386 and PowerPC; aarch64 under qemu from M12.
* **Rules for `AGENTS.md`** (M4): an instruction of the register set is
  its description, its emitter and its use in the every-instruction
  program; a field of the VM the emitters touch is `offsetof`, never a
  number; the transition into C is the one of `ARCHITECTURE.md`; a
  primitive done in line changes with its C.

## Measuring

* **Cycles:** `perf stat -e cycles:u,instructions:u`, the least of five
  runs, on the bootstrap, the programs of `tests/perf` at their default
  input and the two `runedoc` measurements; same-binary runs differ by up
  to 3% and a relink by up to 13% (performance.md, *Measuring*), so a
  change under that is not a change. `task-clock` beside it for anything
  that touches memory.
* **Whole runs.** Warm-up is part of the measurement (Barrett et al.
  2017); there is no steady-state figure.
* **`--jit-stats`:** functions compiled per tier, bytes of code, time
  compiling, OSR entries and exits, deoptimisations, invalidations,
  callee-cache hits.
* **Where the time goes:** `perf record` with the perf map of M7, by
  compiled function, and by opcode for the interpreter.
* **The budgets** of `tests/perf/new` stay the deterministic gate: a run
  under `--jit=all` matches them exactly, and `make perf-check` runs it
  so from M5.
* **The script of M1** is how every milestone's table is made.

## References

The sources were read on 2026-09-25, and every DOI was checked against
Crossref's record that day; engines and blogs give their URL.

**Tiers** (*What the literature says*, D6):
* Swirski. "Sparkplug -- a non-optimizing JavaScript compiler." V8
  blog, 2021. https://v8.dev/blog/sparkplug
* Verwaest et al. "Maglev -- V8's fastest optimizing JIT." V8 blog,
  2023. https://v8.dev/blog/maglev
* Mercadier. "Land ahoy: leaving the Sea of Nodes." V8 blog, 2025.
  https://v8.dev/blog/leaving-the-sea-of-nodes
* V8, `src/flags/flag-definitions.h` (the thresholds).
  https://chromium.googlesource.com/v8/v8/+/refs/heads/main/src/flags/flag-definitions.h
* Backes. "Liftoff: a new baseline compiler for WebAssembly in V8." V8
  blog, 2018. https://v8.dev/blog/liftoff
* V8. "Short builtin calls." V8 blog, 2021.
  https://v8.dev/blog/short-builtin-calls
* Pizlo. "Speculation in JavaScriptCore." WebKit blog, 2020.
  https://webkit.org/blog/10308/speculation-in-javascriptcore/
* Pizlo. "Introducing the B3 JIT compiler." WebKit blog, 2016.
  https://webkit.org/blog/5852/introducing-the-b3-jit-compiler/
* de Mooij. "The Baseline Interpreter: a faster JS interpreter in
  Firefox 70." Mozilla Hacks, 2019.
  https://hacks.mozilla.org/2019/08/the-baseline-interpreter-a-faster-js-interpreter-in-firefox-70/
* de Mooij. "Warp: improved JS performance in Firefox 83." Mozilla
  Hacks, 2020.
  https://hacks.mozilla.org/2020/11/warp-improved-js-performance-in-firefox-83/
* Nethercote. JägerMonkey and TraceMonkey posts, 2010-2011.
  https://blog.mozilla.org/nnethercote/category/jagermonkey/
* Gal et al. "Trace-based just-in-time type specialization for dynamic
  languages." PLDI 2009. doi:10.1145/1542476.1542528
* Kotzmann, Wimmer, Mössenböck, Rodriguez, Russell, Cox. "Design of the
  Java HotSpot client compiler for Java 6." TACO 5(1), 2008.
  doi:10.1145/1369396.1370017
* Paleczny, Vick, Click. "The Java HotSpot server compiler." JVM '01,
  2001.
* Stadler, Würthinger, Mössenböck. "Partial escape analysis and scalar
  replacement for Java." CGO 2014. doi:10.1145/2544137.2544157
* dotnet/runtime. "Tiered compilation" and "On stack replacement",
  design documents.
  https://github.com/dotnet/runtime/blob/main/docs/design/features/tiered-compilation.md,
  https://github.com/dotnet/runtime/blob/main/docs/design/features/OnStackReplacement.md
* Toub. "Performance improvements in .NET 7" (2022) and "in .NET 8"
  (2023). .NET blog.
  https://devblogs.microsoft.com/dotnet/performance_improvements_in_net_7/,
  https://devblogs.microsoft.com/dotnet/performance-improvements-in-net-8/
* Würthinger et al. "Practical partial evaluation for high-performance
  dynamic language runtimes." PLDI 2017. doi:10.1145/3062341.3062381
* GraalVM, Truffle "Splitting".
  https://github.com/oracle/graal/blob/master/truffle/docs/splitting/Splitting.md
* Android. "Implement ART just-in-time compiler"; "Baseline Profiles
  overview". https://source.android.com/docs/core/runtime/jit-compiler,
  https://developer.android.com/topic/performance/baselineprofiles/overview
* Egorov. "10 years of Dart." VMIL 2020. https://mrale.ph/talks/vmil2020/

**Baseline compilers** (D3, M4-M7):
* Xu, Kjolstad. "Copy-and-patch compilation: a fast compilation
  algorithm for high-level languages and bytecode." PACMPL 5 (OOPSLA
  2021), article 136. doi:10.1145/3485513
* Xu, Kjolstad. "Deegen: a JIT-capable VM generator for dynamic
  languages." arXiv 2411.11469, 2024; PACMPL (OOPSLA 2026).
  https://arxiv.org/abs/2411.11469
* Xu. "Building a baseline JIT for Lua automatically." 2023.
  https://sillycross.github.io/2023/05/12/2023-05-12/
* Piumarta, Riccardi. "Optimizing direct threaded code by selective
  inlining." PLDI 1998. doi:10.1145/277650.277743
* Ertl, Gregg. "Retargeting JIT compilers by using C-compiler generated
  executable code." PACT 2004. doi:10.1109/PACT.2004.1342540
* Bucher, Ostrowski. "PEP 744 -- JIT compilation." 2024.
  https://peps.python.org/pep-0744/
* Jin. "Reflections on 2 years of CPython's JIT compiler." 2025.
  https://fidget-spinner.github.io/posts/jit-reflections.html
* Jin. "Python 3.15's JIT is now back on track." Python Insider, 2026.
  https://blog.python.org/2026/03/jit-on-track/
* "PEP 836 -- JIT go brrr: the path to a supported JIT compiler for
  CPython." Draft, 2026. https://peps.python.org/pep-0836/
* Elhage. "Performance of the Python 3.14 tail-call interpreter."
  2025. https://blog.nelhage.com/post/cpython-tail-call/
* Wingo. "Instruction explosion in Guile" (2018); "Lightening run-time
  code generation" (2019). wingolog.
  https://wingolog.org/archives/2018/01/17/instruction-explosion-in-guile,
  https://wingolog.org/archives/2019/05/24/lightening-run-time-code-generation
* GNU Guile Reference Manual, "Just-in-time native code" and "Stack
  layout"; Guile 3.0 release notes.
  https://www.gnu.org/software/guile/manual/html_node/Just_002dIn_002dTime-Native-Code.html
* Erlang/OTP. "A first look at the JIT." 2020.
  https://www.erlang.org/blog/a-first-look-at-the-jit/; the pull request
  "Implement BeamAsm". https://github.com/erlang/otp/pull/2745; ERTS
  manual, "BeamAsm, the Erlang JIT".
  https://www.erlang.org/doc/apps/erts/beamasm.html
* Gustavsson. "Type-based optimizations in the JIT." 2022.
  https://www.erlang.org/blog/type-based-optimizations-in-the-jit/
* Titzer. "Whose baseline compiler is it anyway?" CGO 2024.
  https://arxiv.org/abs/2305.13241
* Bytecode Alliance. "Wasmtime baseline compilation" (Winch), RFC.
  https://github.com/bytecodealliance/rfcs/blob/main/accepted/wasmtime-baseline-compilation.md
* Palumbo et al. "Meta-compilation of baseline JIT compilers with
  Druid." The Art, Science, and Engineering of Programming, 2025.
  https://arxiv.org/abs/2502.20543
* Chevalier-Boisvert et al. "YJIT: a basic block versioning JIT compiler
  for CRuby." VMIL 2021. doi:10.1145/3486606.3486781
* Shopify. "ZJIT has been merged into Ruby." 2025.
  https://railsatscale.com/2025-05-14-merge-zjit/

**Optimising tiers and typed languages** (D7, D8, M9, M10):
* Kennedy, Syme. "Design and implementation of generics for the .NET
  Common Language Runtime." PLDI 2001. doi:10.1145/378795.378797
* Bezanson et al. "Julia: dynamism and performance reconciled by
  design." PACMPL 2 (OOPSLA 2018), article 120. doi:10.1145/3276490
* Julia. "Julia 1.9 highlights." 2023.
  https://julialang.org/blog/2023/04/julia-1.9-highlights/
* Keep, Dybvig. "A nanopass framework for commercial compiler
  development." ICFP 2013. doi:10.1145/2500365.2500618
* Chez Scheme, `IMPLEMENTATION.md`.
  https://github.com/cisco/ChezScheme/blob/main/IMPLEMENTATION.md
* Flatt et al. "Rebuilding Racket on Chez Scheme (experience report)."
  PACMPL 3 (ICFP 2019), article 78. doi:10.1145/3341642
* Bauman, Bolz, Hirschfeld, Kirilichev, Pape, Siek, Tobin-Hochstadt.
  "Pycket: a tracing JIT for a functional language." ICFP 2015.
  doi:10.1145/2784731.2784740
* Meurer. "Just-in-time compilation of OCaml byte-code." arXiv
  1011.6223, 2010; "OCamlJIT 2.0 -- faster Objective Caml." arXiv
  1011.1783, 2010.
* Leroy. Tail calls with stack-passed arguments through the domain
  state, ocaml/ocaml pull request 10595, 2021.
* Sivaramakrishnan, Dolan, White, Kelly, Jaffer, Madhavapeddy.
  "Retrofitting effect handlers onto OCaml." PLDI 2021.
  doi:10.1145/3453483.3454039
* GHC issue 24607, "Replace (internal) bytecode interpreter with
  copy-and-patch JIT compilation." 2024.
* Weeks. "Whole-program compilation in MLton." ML 2006.
  doi:10.1145/1159876.1159877
* Cejtin, Jagannathan, Weeks. "Flow-directed closure conversion for
  typed languages." ESOP 2000. doi:10.1007/3-540-46425-5_4
* Farvardin, Reppy. "A new backend for Standard ML of New Jersey." IFL
  2020. doi:10.1145/3462172.3462191
* Farvardin, Reppy. "From folklore to fact: comparing implementations
  of stacks and continuations." PLDI 2020. doi:10.1145/3385412.3385994
* Poly/ML FAQ. https://www.polyml.org/FAQ.html

**Back ends** (D3, D7):
* Makarov. MIR. https://github.com/vnmakarov/mir; "MIR: a lightweight
  JIT compiler project." Red Hat Developer, 2020.
* Herczeg. sljit. https://github.com/zherczeg/sljit
* Pall. DynASM. https://luajit.org/dynasm.html
* Wingo. Lightening. https://gitlab.com/wingo/lightening
* Cranelift: README; Fallin, "Cranelift, part 4: a new register
  allocator" (2022) and "The acyclic e-graph" (2026); Fitzgerald, "New
  stack maps for Wasmtime and Cranelift" (2024).
  https://github.com/bytecodealliance/wasmtime/blob/main/cranelift/README.md
* Engelke, Schwarz. "Compile-time analysis of compiler frameworks for
  query compilation." CGO 2024.
  https://home.cit.tum.de/~engelke/pubs/2403-cgo.pdf
* Schwarz, Kamm, Engelke. "TPDE: a fast adaptable compiler back-end
  framework." arXiv 2505.22610, 2025.
* libgccjit. https://gcc.gnu.org/onlinedocs/jit/
* PostgreSQL, "When to JIT?".
  https://www.postgresql.org/docs/current/jit-decision.html

**Techniques** (D4, D8, M6, M11):
* Hölzle, Chambers, Ungar. "Debugging optimized code with dynamic
  deoptimization." PLDI 1992. doi:10.1145/143095.143114
* Hölzle, Chambers, Ungar. "Optimizing dynamically-typed
  object-oriented languages with polymorphic inline caches." ECOOP 1991.
  doi:10.1007/BFb0057013
* Hölzle, Ungar. "Optimizing dynamically-dispatched calls with run-time
  type feedback." PLDI 1994. doi:10.1145/178243.178478
* Deutsch, Schiffman. "Efficient implementation of the Smalltalk-80
  system." POPL 1984. doi:10.1145/800017.800542
* Flückiger, Scherer, Yee, Goel, Ahmed, Vitek. "Correctness of
  speculative optimizations with dynamic deoptimization." PACMPL 2 (POPL
  2018), article 49. doi:10.1145/3158137
* Flückiger, Ječmen, Krynski, Vitek. "Deoptless: speculation with
  dispatched on-stack replacement and specialized continuations." PLDI
  2022. doi:10.1145/3519939.3523729
* D'Elia, Demetrescu. "On-stack replacement, distilled." PLDI 2018.
  doi:10.1145/3192366.3192396
* Lin, Wang, Blackburn, Hosking, Norrish. "Stop and go: understanding
  yieldpoint behavior." ISMM 2015. doi:10.1145/2754169.2754187
* Barrett, Bolz-Tereick, Killick, Mount, Tratt. "Virtual machine warmup
  blows hot and cold." PACMPL 1 (OOPSLA 2017), article 52.
  doi:10.1145/3133876
* Diwan, Moss, Hudson. "Compiler support for garbage collection in a
  statically typed language." PLDI 1992. doi:10.1145/143095.143140
* Apple. "Porting just-in-time compilers to Apple silicon."
  https://developer.apple.com/documentation/apple-silicon/porting-just-in-time-compilers-to-apple-silicon
* Mono. "A tale of an impossible bug: big.LITTLE and caching." 2016.
  https://www.mono-project.com/news/2016/09/12/arm64-icache/
* Shi, Gregg, Beatty, Ertl. "Virtual machine showdown: stack versus
  registers." VEE 2005. doi:10.1145/1064979.1065001

**Functional languages** (*What is different for SML*, M10):
* Shao, Appel. "Efficient and safe-for-space closure conversion."
  TOPLAS 22(1), 2000. doi:10.1145/345099.345125
* Kennedy. "Compiling with continuations, continued." ICFP 2007.
  doi:10.1145/1291151.1291179
* Maurer, Downen, Ariola, Peyton Jones. "Compiling without
  continuations." PLDI 2017. doi:10.1145/3062341.3062380
* Marlow, Peyton Jones. "Making a fast curry: push/enter vs. eval/apply
  for higher-order languages." ICFP 2004. doi:10.1145/1016850.1016856
* Leroy. "Unboxed objects and polymorphic typing." POPL 1992.
  doi:10.1145/143165.143205
* Harper, Morrisett. "Compiling polymorphism using intensional type
  analysis." POPL 1995. doi:10.1145/199448.199475
* Tarditi, Morrisett, Cheng, Stone, Harper, Lee. "TIL: a type-directed
  optimizing compiler for ML." PLDI 1996. doi:10.1145/231379.231414
* Marlow, Yakushev, Peyton Jones. "Faster laziness using dynamic
  pointer tagging." ICFP 2007. doi:10.1145/1291151.1291194
* Poletto, Sarkar. "Linear scan register allocation." TOPLAS 21(5),
  1999. doi:10.1145/330249.330250
* Wimmer, Franz. "Linear scan register allocation on SSA form." CGO
  2010. doi:10.1145/1772954.1772979
* Hack, Grund, Goos. "Register allocation for programs in SSA-form."
  CC 2006. doi:10.1007/11688839_20
* Braun, Hack. "Register spilling and live-range splitting for SSA-form
  programs." CC 2009. doi:10.1007/978-3-642-00722-4_13
* Pall. "LuaJIT allocation sinking optimization." LuaJIT wiki.
