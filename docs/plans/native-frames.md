# Roadmap: native frames

This plan is the roadmap that [performance.md](performance.md)'s M9 asks
for: a call at tier 2 that costs what a call costs in native code. On
2026-10-12 a `fib` call at tier 2 was 82.5 machine instructions and 31 to
37 cycles; after performance M6 and M7 (M1, 2026-10-19) it is 39 and 11.
MLton's is 17 and 9 to 10, Poly/ML's 14.5 and 7, OCaml's 10 and 5. The
plan says why, what a frame must become for the gap to close, what else
stands between Rune and OCaml, and in what order to build it.

It was written on 2026-10-12, on branch `perf-m9` from `performance`
(`db6056be`; the runtime is master's `921af2cc`), while performance's M5
to M7 were being built on another branch. What it rests on:

* **Six experiments made for it**, F1 to F6 (*The experiments*):
  * the call by hand: `fib` and `tak` on nine designs of the frame, with
    Rune's semantics, against OCaml, MLton, Poly/ML and tier 2 in one
    session;
  * branch misses, crossings between the tiers, the collector's walks of
    the frames, the body's faults by pattern, and the cost of finding a
    frame's descriptor.
* **The measurements of performance.md** (E9 to E13, the dump of the
  JIT's code by role, the call's prototypes), and its notes on the
  implementations.
* **The sources** of MLton, OCaml 4 and 5, Poly/ML, Chez, GHC, Wasmtime,
  SML/NJ and HotSpot under `/home/ruud/reference`.

Below, `performance.md` alone means [the performance plan](performance.md),
and "performance M6" its milestone; M1 to M9 without a prefix are this
plan's.

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done (2026-10-12); every decision taken as recommended the same day |
| M1 | The gate: the call measured after performance M5 to M7 | done (2026-10-19, on `db0fba57a`): the gate open; *Where we are* and the baselines measured again, the decisions' premises restated, `scripts/hol-kernel.sh` made to run on `$RUNEVM` |
| M2 | The body: tier 2's code for an instruction | done (2026-10-19): a constructor's tag tested by its representation, `SWITCH`'s tag likewise, the `--checked` test compiled in only under `--checked`, `int_mod` by a power of two an `and`; the bootstrap 15.230G to 14.516G instructions (−4.7%), HOL's kernel work 53.016G to 49.953G (−5.8%); cycles, an indication, −7% and −11%; `--count` and every output unchanged; `ENV`'s tests and division by a constant not built (*M2*) |
| M3 | Frames walked, not indexed | done (2026-10-19): the walk of `vm.h`, given by each instruction set over the array, and every reader of frames outside the engines on it; the bootstrap 14.516G to 14.519G instructions (+0.02%), every output and count unchanged (*M3*) |
| M4 | Frames in the value stack | done (2026-10-19): a header of three words below each frame's registers, `vm->frames` gone from `runevm`, returns by `jmp [r14-8]`, the watermark compared at the landing; a `fib` call 39.0 to 29.0 instructions and 11.0 to 8.3 cycles (MLton 8.7), a `tak` call 47.3 to 37.3 and 13.1 to 11.0; HOL's kernel work 49.98G to 43.95G instructions (−12.1%), the bootstrap's compiled code −10.3% and the whole −2.9%; the targets of instructions short (*M4*); `--count`, every output and the images' format unchanged |
| M5 | The watermark by a return barrier | not started; prototype F1 |
| M6 | Arguments in registers | not started; prototype F1 |
| M7 | Returns the processor predicts | not started; prototype F1 |
| M8 | The allocation pointer in a register | not started |
| M9 | Measure again: the owner's goal | not started |

The owner took every decision as recommended on 2026-10-12 (*Decisions*).

## The request

The owner, on 2026-10-12, starting this roadmap:

```
let's see if we can beat MLton and get as fast as OCaml!
```

performance.md's M9, verbatim:

```
After M5 to M7, measure what is left of the call's cost against MLton and
Poly/ML. If the call is still the largest part of HOL's gap, plan native
frames (D5 B): return addresses, a descriptor per return address, and the
interpreter's protocol, deoptimisation, traces and images over them. Plan
maps for pointers in registers (D6 C) with them. This is a change of the
size of the JIT roadmap, and it gets one of its own. Its target to plan
for: a `fib` call at most 25 instructions and 10 cycles.
```

What the plan was asked to answer:

* **Frames:** on the machine stack (OCaml 5, Poly/ML) or on a stack of
  Rune's own (MLton); the return address in the frame; a descriptor per
  return address; one compare for the stack's limit that is also the poll.
* **Arguments and results in registers**, which registers a callee
  saves, and how tier 2's homes map onto that.
* **What must keep working** (*Constraints*).
* **What else stands between Rune and OCaml** beyond the frame, measured
  where it can be, and which of it this plan takes.
* **Experiments** where a question needs numbers.
* **Milestones** to parity, each with targets in instructions per call,
  on the bootstrap, on HOL's kernel work and on MLton's set, the owner's
  goal last.

## Where we are

Measured again on 2026-10-19 for M1, on `performance` `db0fba57a`, which
has performance M1 to M3 and M5 to M8: Rune means that tree's
`bin/runevm` at its default, tier 2 by the counters. The figures of
2026-10-12 (master `921af2cc`), against which the experiments were made,
stand beside them where they changed. *Measuring* says how each was taken;
the raw results are with the drafts (`results/M9/B0/`).

### The call

Machine instructions per call (exact; the difference of two run lengths,
`perf stat -e instructions:u`), and cycles per call (the least of 7 runs,
pinned, in one session with F1's prototypes; F1):

| | Rune, tier 2 | on 2026-10-12 | MLton | Poly/ML | OCaml |
|---|---:|---:|---:|---:|---:|
| `fib`: instructions | 39.0 | 82.5 | 17.0 | 14.5 | 10.0 |
| `fib`: cycles | 11.0 | 31 to 37 | 8.7 | 6.7 | 4.9 |
| `tak`: instructions | 47.3 | 92.0 | 23.3 | 23.0 | 19.7 |
| `tak`: cycles | 13.1 | 38 to 41 | 10.0 | 8.6 | 6.1 |
| a call through a closure and its return: instructions | 29 | 75 | | | |

Performance M6 made the call lean -- the frame's record in `rbp`, no fill,
a return through the record's `native_ret` that tests nothing but the
watermark, a table of calls, known calls patched, the result in `rax`
(performance.md, M6, as built) -- and its code runs at an IPC of 3.5. A
`fib` call is now 1.26 times MLton's cycles, a `tak` call 1.31 times.

Where `fib`'s 39 go, by the role the emitters gave each machine instruction
(callgrind with the JIT's dump at two run lengths, `scripts/jit-dump.py
--diff`):

| Role | Instructions |
|---|---:|
| the body: compare, subtract, add, the branch | 10 |
| the frame: the record's four words written, the record and the registers moved on | 10 |
| the return: the value, `native_ret` loaded, the watermark compared, the jump | 5 |
| the landing: the record and the registers moved back, homes loaded, the result | 5 |
| the count | 3 |
| the room check, which is the poll | 3 |
| arguments, the write-back, the jump | 3 |

Six of them are stores. A call through a closure is 24 instructions
(the frame 10, the room 4, the argument 3, the landing 3, the closure 2,
its pointer's load 1, the jump 1) and its return 5. What is left of the
frame is the record: four words written at every call (the function and
pc in one, the base, the closure, the return address), read back by the
return, and the watermark compared at every return.

### Where the instructions go

Bytecode instructions executed in compiled code, and their machine
instructions (callgrind with the JIT's dump, F5's script):

| Instruction | Bootstrap: executions | machine instructions | each | HOL slice: executions | machine instructions | each |
|---|---:|---:|---:|---:|---:|---:|
| `CALLK` | 61.3M | 1.36G | 22.2 | 27.1M | 0.56G | 20.8 |
| `CALL` (through a closure) | 10.3M | 0.29G | 28.2 | 28.3M | 0.82G | 29.0 |
| `RET` | 72.0M | 0.37G | 5.2 | 54.6M | 0.28G | 5.1 |
| `TAILCALLK` | 12.6M | 0.12G | 9.9 | 13.9M | 0.12G | 8.4 |
| `TAILCALL` | 1.2M | 0.02G | 14.9 | 7.2M | 0.11G | 14.8 |
| `ENV` (a closure's field) | 23.1M | 0.16G | 6.7 | 32.1M | 0.23G | 7.1 |
| `JUMPIFNOTTAG` (a constructor's tag) | 92.5M | 0.92G | 9.9 | 47.7M | 0.44G | 9.2 |
| `SWITCH` | 17.5M | 0.30G | 17.3 | 5.3M | 0.08G | 14.6 |
| `FIELD` | 161.8M | 0.75G | 4.6 | 58.7M | 0.28G | 4.8 |
| `PRIM` | 212.6M | 1.83G | 8.6 | 35.0M | 0.37G | 10.7 |
| all compiled code | | 7.96G of 16.32G | | | 4.66G of 9.54G | |

By role, the call's machinery -- the frame, the landing, the return, the
room, the arguments, the closure, the jump, the write-back, the poll -- is
2.33G of the bootstrap's compiled code (29%) and 1.88G of HOL's (40%;
60% on 2026-10-12). The body is 50% and 36%, allocation 8% and 14%.
The bytecode's six instructions of calls and closures are 29% and 45%.

### The whole programs

* **The bootstrap** -- the compiler of `db0fba57a` compiling its own
  sources, a workload of its own frozen with the drafts (`results/M9/bootwl`,
  1.217G bytecode instructions) -- takes 15.23G instructions and 10.2G to
  10.5G cycles, against 4.85G and 5.9G to 6.2G for MLton's build of the
  same compiler doing the same compile: 1.72 times the cycles and 3.1
  times the instructions (2.46 and 4.6 on 2026-10-12, with that day's
  compiler). Tier 2's code is 60% of its cycles and the collector 30%
  (`perf record` over `--jit-perf-map`, `scripts/perf-groups.awk`).
* **HOL's kernel work** (`scripts/hol-kernel.sh` on HOL4 built by M8's
  compiler, the drafts' `hol/HOL-midM8`) takes 53.0G instructions and 25.2G to
  25.9G cycles, against 11.3G to 11.5G and 8.5G to 8.6G on Poly/ML: 2.98
  times the cycles and 4.6 times the instructions (5.9 and 7.7 on
  2026-10-12). Tier 2's code is 84% of its cycles, the collector 7%. Its
  bytecode executes 15.8G instructions, still more than Poly/ML's whole
  run executes machine instructions.
* **MLton's set** (`scripts/perf-cycles.sh --mlton-bench`, the least of
  three runs): on the 37 programs both ran, the geometric mean of Rune's
  cycles over MLton's is 4.58 and the median 3.40 (10.3 and 8.0 on
  2026-10-12). The seven programs of calls and closures run at 1.32 to
  3.16 times MLton (2.8 to 4.2): `fib` 1.32, `tak` 1.76, `tyan` 1.83,
  `logic` 2.12, `nucleic` 2.35, `model-elimination` 2.41, `barnes-hut`
  3.16. The outliers are IntInf (`pidigits` 681; `smith-normal-form`
  stopped) and the Basis's own code (`output1` 21, `checksum` 18,
  `vector32-concat` 13); `tensor` wants MLton's `Unsafe`. tests/perf's
  `fib` and `tak`, whole, take 1.36 and 1.35 times MLton's cycles (3.9 and
  3.5 on 2026-10-12).

### The gate: the call is still the largest part

performance.md's M9 asked for native frames only if, after its M5 to M7,
the call were still the largest part of HOL's gap to Poly/ML. It is:

* HOL's compiled code is 84% of its cycles, and in it the call's machinery
  is the largest part (40% of its instructions), before the body (36%)
  and allocation (14%);
* a call costs 1.26 to 1.31 times MLton's cycles, and F1's prototypes in
  the same session do it in 6.2 to 7.6 cycles against tier 2's 11.0 (*F1*).

So the plan goes ahead (M1), with the restatements of *Decisions* where
what M6 and M7 built changed a premise.

## What the implementations do

From the sources (`/home/ruud/reference`; the notes with every file and
line are with the drafts, `lit/impl-calls-A.md` and `impl-calls-B.md`,
and were spot-checked for this plan). Instructions per `fib` call are
measured where the system is in the table of *Where we are*, and estimated
from the emitters otherwise.

| | Where frames live | Call and return | Pointers in registers at a collection | How the collector finds a frame's roots | `fib` call |
|---|---|---|---|---|---|
| MLton | its own stack, a heap object; `rbp` its top | `rbp` bumped, the return label stored at `-8(%rbp)`, `jmp`; return `jmp *-8(%rbp)` | never | the frame's layout, by an index in the 4 bytes before the return label | 17.0 measured |
| OCaml 4 | the C stack | `call`, `ret` | yes: a descriptor entry `2r+1` names a register, which `caml_call_gc` saves | a hash of the return address | 10.0 measured |
| OCaml 5 | stacks of its own (fibers), `rsp` pointed into them | `call`, `ret`; a switch to the C stack for C | as OCaml 4 | as OCaml 4, per fiber | OCaml 4's and a stack check of 3 |
| Poly/ML | a stack of its own, `rsp` pointed into it | `call`, `ret` | yes: a mask of registers in the bytes after the trap's call | every word of the stack scanned by its tag | 14.5 measured |
| Chez | its own stack, `r13` | the return label stored in the frame's slot 0, `jmp`; return `jmp [r13]` | never | a live mask in a header before the return label | about 16 |
| GHC | its own stack, `rbp` | the return info pointer stored, `jmp`; return `jmp *0(%rbp)` | only into canned stubs that push them into a described frame | the bitmap of the return point's info table | about 14 to 15 |
| Cranelift, Wasmtime's GC | the C stack | `call`, `ret` | never across a call: the producer spills them | a bitmap per return address | about 12 to 18 |
| SML/NJ | no stack: continuations on the heap | `jmp`, three callee-save registers | yes, a fixed set of root registers | none: the roots are seven registers | about 20 to 25, and a heap record |

What they share, and what Rune can take:

* **No callee-saved registers for the program's values.** MLton flushes
  everything but its two pinned registers at every non-local transfer
  (`amd64-generate-transfers.fun:283-310`); OCaml's calls destroy every
  register (`proc.ml:312-314`); Chez marks every variable live across a
  call spilled (`cpnanopass.ss:8972-8990`); GHC saves everything live
  across a call to its stack (`LayoutStack.hs:40-56`); Poly/ML pushes it.
  Only SML/NJ keeps values in callee-save registers, and it has no stack.
  So a value live across a call is in the frame, where a collector, a
  debugger or a deoptimisation reads it without a map of registers.
* **A frame described by its return point.** MLton keys a frame's layout
  by an index stored before the return label
  (`amd64-generate-transfers.fun:611-616`, `amd64-main.h:42-44`); Chez by
  the header before it (`cmacros.ss:1757-1789`); GHC by the info table the
  return pointer is; OCaml by a hash of the return address
  (`stack.h:116-120`). The collector walks the frames from the top, one
  descriptor per frame.
* **One compare for the stack's limit, which is also the poll.** MLton
  checks the stack at a function's entry with a slack of two frames
  (`insert-checks.fun:335`, `stack.c:35-37`), and a signal forces the slow
  path of its heap checks by setting their limit to 0
  (`insert-checks.fun:10-61`); Poly/ML's `cmp rsp, stackLimit(%rbp); jnb`
  at every entry is the interrupt's poll too, another thread setting the
  limit (`x86_dep.cpp:889-898`); GHC preempts by zeroing the heap limit.
* **A stack of one's own is the rule for garbage-collected functional
  languages.** MLton, Chez and GHC return by an indirect jump through the
  frame and forgo the processor's prediction of returns; OCaml 5 and
  Poly/ML point `rsp` into a stack the runtime owns and relocates, and keep
  `call` and `ret`. No source the plan read compares the two; F1 does.
* **The watermark of a generational stack scan.** HotSpot marks a frame
  "from which returns (or other forms of unwinding) will take a slow
  path" (`stackWatermark.hpp:63-74`), and tests it with one compare in
  every return against a word of the thread
  (`macroAssembler_x86.cpp:2578-2588`). The alternative, a return address
  patched to a stub at the marked frame, costs nothing on the returns
  that do not cross it (F1, variant 3).

And the literature (*References*):

* **A stack frame is cheap when it is only a frame.** Appel and Shao
  (1996) count 5.4 instructions per frame on a stack, against 7.5 to 12.8
  for frames on the heap, and assume frames safe for space: a dead pointer
  in a frame must not keep its object alive. Rune's liveness per return
  point (`live.c`) is that, and stays.
* **Tables at the points a collection can happen**, keyed by the point:
  Diwan, Moss and Hudson (1992) for a statically typed language with a
  copying collector, Agesen, Detlefs and Moss (1998) for the precision of
  the JVM's slots. Stichnoth, Lueh and Cierniak (1999) went the other way,
  maps at every instruction so that threads need no poll. Rune keeps the
  first: safepoints only at calls and slow paths, every slot exact there.
* **Stack cutting suits a design with no callee-saved registers** (Ramsey
  and Peyton Jones, 2000): a raise sets the stack and the pc and restores
  nothing else. D6 A keeps Rune that design.

What Rune does today, beside them: its frames are records in an array of
the VM (`vm->frames`, 40 bytes each) beside the registers on the value
stack; a return reads the record; the collector finds a waiting frame's
roots by its registers' tags and by what is live at the instruction its
callee returns to (`runtime/register/live.c`, a table per function keyed
by that pc). That table is already a descriptor per return point, in
bytecode terms.

## The experiments

Each is kept with the drafts, with its scripts and raw results
(`results/M9/F<n>/`, *Measuring*). Counts are exact; cycles are the least
of several pinned runs on a machine shared with other work, and only
compared within a session.

### F1: the call by hand

**The question.** What does a call cost under each design of the frame,
with everything Rune must keep: ints tagged as 2n + 1 and checked for
overflow, the count in `r15` added once per extended block (performance
D9 B), every value live across a call in its slot (the collector's roots,
no callee-saved registers), and a compare against a limit that is also the
poll?

**The method.** `fib 25` and `tak 18 12 6`, written by hand in assembler
the way tier 2 would emit them (`calls.S`, a C driver for the VM's state
and a value stack of tagged words), in nine variants of the call sequence.
The body is the same in all of them and as good as the JIT could make it
(a compare fused with its branch, immediates, arithmetic in place):

1. **Lean VM frames: performance M6's end state.** The 40-byte record in
   `vm->frames` (its address a pointer), the frames grown with the stack,
   the room check at the call with the poll folded in, no fill, the
   arguments in the callee's slots, the result in `rax`, a return that
   tests nothing but lowers the watermark and rebuilds `r14` from the
   caller's base index.
2. **Native frames.** A header of three words below the callee's
   registers -- the return address, the bytecode pc it stands for, the
   closure or unit -- written by the caller; arguments in the callee's
   slots; the result in `rax`; `jmp [r14-8]` to return; the landing puts
   `r14` back by its frame's size, and lowers the watermark.
3. As 2, the watermark kept by a return barrier: nothing per return.
4. As 3, the arguments in registers.
5. As 4, a header of one word written: the return address alone.
6. As 5, `call` and `ret` on a stack of return addresses of its own, `rsp`
   moved there.
7. As 5, without the count.
8. As 5, the return address stored as an immediate (the code below 2 GB).
9. As 5, returns the processor predicts: `call`, the callee pops the
   return address into its header word, and returns by `push [r14-8];
   ret`, so that calls and returns pair on the C stack while the return
   address lives in the frame; `rsp` is not moved.

The references in the same session: OCaml 4.14.1, MLton 20241230, Poly/ML
5.9.2 and tier 2 on performance.md E9's programs. Every variant prints the
same result and the same count.

**The results** (instructions exact; cycles the least of 7 runs in the
first session and of 9 in the second):

| | `fib`: instructions | cycles | `tak`: instructions | cycles |
|---|---:|---:|---:|---:|
| Rune, tier 2 | 82.5 | 37.3, 33.1 | 92.0 | 40.7, 37.5 |
| 1 lean VM frames | 39.5 | 17.0, 17.9 | 48.0 | 21.9, 21.2 |
| 2 native, 3 words written | 25.5 | 10.0, 9.1 | 34.0 | 12.6, 13.2 |
| 3 ... with a return barrier | 23.5 | 10.4, 7.6 | 32.0 | 10.4, 10.1 |
| 4 ... arguments in registers | 23.0 | 9.0, 7.6 | 32.0 | 11.5, 9.7 |
| 5 ... one word written | 21.0 | 8.1, 7.0 | 30.0 | 10.7, 10.7 |
| 6 ... `call`/`ret`, `rsp` moved | 19.0 | 6.8, 5.8 | 28.0 | 8.8, 7.9 |
| 7 ... 5 without the count | 18.0 | 6.9, 6.8 | 26.3 | 9.4, 9.2 |
| 8 ... 5, the address an immediate | 20.0 | 7.2, 8.1 | 29.0 | 9.7, 10.3 |
| 9 ... 5, returns predicted | 21.0 | 6.2 | 30.0 | 8.0 |
| MLton | 17.0 | 10.0, 8.9 | 23.3 | 10.6, 11.1 |
| Poly/ML | 14.5 | 7.4, 6.7 | 23.0 | 9.5, 8.7 |
| OCaml | 10.0 | 4.9, 4.9 | 19.7 | 6.5, 6.2 |

What it says:

* **Lean VM frames stop at about twice MLton** in this prototype
  (variant 1: 17 to 18 cycles a `fib` call against 9 to 10). The record
  and its read-back are what remains. *Performance M6 did better than
  variant 1* (M1, 2026-10-19): with the same instructions, its record's
  address in `rbp` where variant 1 kept it in the VM's memory, its `fib`
  call takes 11.0 cycles and its `tak` call 13.1 (*Where we are*), 1.26
  and 1.31 times MLton.
* **Native frames reach MLton at once** (variants 2 to 5: 7 to 10 cycles a
  `fib` call, 10 to 13 a `tak` call). Variants 4 to 9 meet
  performance.md's target for M9, at most 25 instructions and 10 cycles,
  in both sessions; variant 3 in one of the two.
* **The watermark's compare** costs 2 instructions a call (variant 2
  against 3), and 0 to 3 cycles.
* **Arguments in registers** save half an instruction on `fib` and none
  on `tak`: both spill their arguments anyway, being live across calls.
  What they save is in leaves (`fib`'s base case).
* **Writing one word of the header rather than three** saves 2
  instructions (variant 5 against 4).
* **Returns the processor predicts** (variant 9) are as fast as `call`
  and `ret` on a stack of their own (variant 6), with the same instructions
  as variant 5: 11% fewer cycles on `fib` and 25% on `tak` than variant 5.
  They beat Poly/ML on both, MLton by 1.4 times, and come within 1.27 and
  1.29 times OCaml.
* **The count** is 3 instructions a `fib` call and 3.7 a `tak` call
  (variant 5 against 7); in cycles it is within the noise of these runs.
  On whole programs it costs 0.8% (performance.md E13).
* **What Rune keeps that OCaml does not** is about 11 instructions of
  variant 9's 21 on `fib`: the count (3), overflow checks and the copies
  two-operand arithmetic needs (about 2.5), the limit compare (2), the
  return address stored and reloaded where OCaml's `call` and `ret` do it
  (2), a home loaded from the argument register (1), and untagging (0.5).
  That floor is the price of Rune's contract, not of its frames.

**A third session** (2026-10-19, M1), beside performance M6 and M7 as
built (`db0fba57a`), least of 7 runs:

| | `fib`: instructions | cycles | `tak`: instructions | cycles |
|---|---:|---:|---:|---:|
| Rune, tier 2 (`db0fba57a`) | 39.0 | 11.0 | 47.3 | 13.1 |
| 1 lean VM frames | 39.5 | 16.5 | 48.0 | 19.4 |
| 2 native, 3 words written | 25.5 | 10.2 | 34.0 | 12.6 |
| 3 ... with a return barrier | 23.5 | 7.6 | 32.0 | 10.0 |
| 5 ... one word written | 21.0 | 7.0 | 30.0 | 8.9 |
| 6 ... `call`/`ret`, `rsp` moved | 19.0 | 5.8 | 28.0 | 7.8 |
| 9 ... 5, returns predicted | 21.0 | 6.2 | 30.0 | 7.9 |
| MLton | 17.0 | 8.7 | 23.3 | 10.0 |
| Poly/ML | 14.5 | 6.7 | 23.0 | 8.6 |
| OCaml | 10.0 | 4.9 | 19.7 | 6.1 |

So native frames would take a `fib` call from tier 2's 11.0 cycles to 7.0
(variant 5) or 6.2 (variant 9), and a `tak` call from 13.1 to 8.9 or 7.9:
32 to 44% fewer cycles, 17 to 18 fewer instructions -- less than against
the base of 2026-10-12, and still the difference between 1.3 times MLton
and 0.7 to 0.8 times.

### F2: what returns mispredict today

**The question.** Variant 9's gain is the processor's prediction of
returns. How much of a whole program's time can that be? Tier 2's
returns are already indirect jumps (`jmp rdx`), as MLton's and variant 5's
are.

**The method.** `perf stat -e branches:u,branch-misses:u` over the
bootstrap (three runs) and HOL's kernel work, at tier 2.

| | Branches | Mispredicted | Cycles | At 16 cycles a miss |
|---|---:|---:|---:|---:|
| the bootstrap | 3.04G | 44.0M to 45.0M | 12.7G to 13.1G | at most 5.4% to 5.7% |
| HOL's kernel work | 14.26G | 96.4M | 58.5G | at most 2.6% |

Every miss counted, of every kind, in the collector and the runtime too,
is at most 5.7% and 2.6% of the time. Returns are a part of that. So on
whole programs predicted returns gain at most a few percent, less than
F1's micro programs suggest; `codegen.md` measured the same bound for
`runeopt`'s code in 2026-09 (*D3's option A*: at most 0.6% at the labels
calls return to). Variant 5 itself mispredicts 0.05 times a `fib` call,
variant 9 almost never (F1's binaries under the same counters).

### F3: how often a frame crosses between the tiers

**The question.** With native frames, a frame that crosses between the
interpreter and compiled code -- a call from one into the other, a return,
a raise -- costs a conversion or a stub. How often does it happen?

**The method.** `runevm --jit-stats`: the times the interpreter handed a
frame to native code, and back.

| | Handed to native code | Handed back | Calls | Crossings per call |
|---|---:|---:|---:|---:|
| the bootstrap | 170,655 | 173,975 | 91.9M (76.2M not in tail position) | 0.4% |
| HOL's kernel work | 328,786 | 330,834 | about 2.4G (one in 6.5 bytecode instructions, performance.md E12) | 0.03% |

On `db0fba57a` (M1), with the bootstrap of its own compiler: 132,154 and
177,557 crossings in about 85M calls (0.4%), and on HOL 281,822 and
329,487 (0.03%).

So a crossing can cost a hundred instructions and add under half an
instruction a call. Deoptimisation at an instruction boundary happened 0
times in both ("left mid-way 0"): only `--deopt-stress` and the debugger
leave code mid-way.

### F4: how many frames a collection walks

**The question.** A collection walks the frames above the watermark,
asking each waiting frame what is live where its callee returns to. With
native frames that is a descriptor found from a return address. How many?

**The method.** `--gc-log`'s column `frames`, per pass.

| | Collections | Frames walked | Per minor collection |
|---|---:|---:|---:|
| the bootstrap | 396 (391 minor) | 51,000 | 120.7 |
| HOL's kernel work | 4,772 logged (4,769 minor) | 25,258 | 5.3 |

On `db0fba57a` (M1): the bootstrap of its own compiler 73,622 frames in
365 collections (184.6 per minor collection), HOL 25,279 in 4,762 (5.3).

The watermark (garbage-collector-v2.md, D9) keeps the walks short.

### F5: the body's faults, counted

**The question.** performance.md lists faults of tier 2's code for a body
(B1's report): comparisons not fused with their branch, constants in
registers, arithmetic through `rax` and `rcx`, `mod` by `idiv`, `FIELD`'s
test of `vm->checked`, allocation with two read-modify-writes of the
counters. How much is each?

**The method.** A script over performance.md E12's callgrind runs with the
JIT's dump, matching machine instructions by role and pattern, weighted by
how often each ran (`scripts/M9/f5patterns.py`).

| Pattern | Bootstrap: executions | share of compiled code | HOL slice: executions | share |
|---|---:|---:|---:|---:|
| the allocation fast path, all of it | 643.8M | 5.8% | 614.7M | 8.6% |
| ... of which a counter's read-modify-write | 107.3M | 1.0% | 102.4M | 1.4% |
| the count (`lea r15`) | 587.6M | 5.3% | 232.7M | 3.3% |
| `ENV` | 374.7M | 3.4% | 311.1M | 4.4% |
| pointers loaded from their slots | 291.0M | 2.6% | 143.6M | 2.0% |
| the poll | 256.6M | 2.3% | 164.5M | 2.3% |
| a primitive's operand moved into `rax` or `rcx` | 177.0M | 1.6% | 23.0M | 0.3% |
| `FIELD`, `DECON`: the test of `vm->checked` (and its branch) | 138.4M | 1.2% (2.5%) | 61.7M | 0.9% (1.7%) |
| tag tests | 97.7M | 0.9% | 67.8M | 1.0% |
| a comparison's `setcc` before a `JUMPIF` | 50.3M | 0.5% (each with 4 more) | 4.9M | 0.1% |
| `INT`: a constant made in a register | 40.0M | 0.4% | 9.2M | 0.1% |
| `idiv` (20 to 40 cycles each) | 8.1M | 0.1% | 1.5M | 0.0% |

And `JUMPIFNOTTAG`, a constructor's tag tested and branched on, takes 7.3
machine instructions where 2 to 4 would do (a nullary tag is one compare of
the word; a pointer's tag a test, a load and a compare): 99.7M executions
in the bootstrap, 50.1M in HOL's slice.

**Again on `db0fba57a`** (M1; F5's script ported to the dump of
performance M1, `scripts/M9/f5patterns2.py`), over the compiled code (the
bootstrap's 7.96G instructions, HOL's slice's 4.66G):

| Pattern | Bootstrap: executions | share | HOL slice: executions | share |
|---|---:|---:|---:|---:|
| `JUMPIFNOTTAG`'s body (8.1 and 7.6 instructions each, beside its count and the landings at it) | 748.8M | 9.4% | 363.5M | 7.8% |
| the allocation fast path | 631.0M | 7.9% | 634.2M | 13.6% |
| ... of which a counter's read-modify-write | 105.2M | 1.3% | 105.7M | 2.3% |
| the count | 467.1M | 5.9% | 220.3M | 4.7% |
| pointers loaded from their slots | 355.0M | 4.5% | 154.8M | 3.3% |
| `SWITCH`, all of it (17.3 and 14.6 each) | 259.6M | 3.3% | 64.7M | 1.4% |
| the test of `vm->checked` (and its branch) | 170.3M | 2.1% (4.3%) | 66.3M | 1.4% (2.8%) |
| `ENV`, all of it (6.7 and 7.1 each) | 144.0M | 1.8% | 193.2M | 4.1% |
| a `setcc` in a body | 52.8M | 0.7% | 7.5M | 0.2% |
| `INT` | 48.6M | 0.6% | 14.7M | 0.3% |
| `idiv` | 10.5M | 0.1% | 3.8M | 0.1% |

Performance M6 fused comparisons with their branches and does `int_add`
and `int_sub` where the words are. The constructor's tag is now the body's
largest fault: tier 2 makes the tag in a scratch register before it
compares -- the word copied, its low bit tested, the tag shifted out or
loaded from the header -- where a compare of the word, or a test and a
compare in memory, would do.

### F6: what finding a descriptor costs

**The question.** A native frame names its caller by a return address.
Finding what it stands for -- the code object, the landing's bytecode pc,
the function of that pc -- is three binary searches. What does it cost?

**The method.** A micro program at the bootstrap's sizes (1,412 compiled
functions in 5.67 MB of code, 3,585 functions), the lookups in a random
order so that each may miss the cache.

**The result.** 110 to 124 ns a lookup: 5.6 to 6.3 ms for the bootstrap's
51,000 frames walked (0.15% of its time) and 2.8 to 3.1 ms for HOL's.
Writing the bytecode pc into every frame instead would cost a store per
call: 92M stores in the bootstrap. So the descriptor is found when a frame
is walked, not written when it is made (D2).

## What else stands between Rune and OCaml

The frame is the largest part, not all of it. Each item below is weighed
by F5 on `db0fba57a` (M1: shares of the compiled code's instructions, the
bootstrap's 7.96G and HOL's slice's 4.66G; on 2026-10-12 the shares were
of 11.09G and 7.12G), or by the experiment named, against what OCaml and
MLton do.

| Item | Bootstrap | HOL slice | OCaml, MLton | Taken by |
|---|---:|---:|---|---|
| The call's machinery: the frame, the return, the landing, the room, the arguments, the closure | 29% (47% on 2026-10-12) | 40% (60%) | 10 to 17 instructions a call | performance M6 (done), then M4 to M7 |
| A constructor's tag: `JUMPIFNOTTAG`'s body at 8.1 and 7.6 instructions | 9.4% | 7.8% | 2 to 4 | M2 |
| Allocation: 12 instructions in line, two of them read-modify-writes of the counters | 7.9% | 13.6% | OCaml: `sub r15; cmp; jb` and the header, the pointer in `r15` | M8 |
| The count | 5.9% | 4.7% | neither counts | performance M6 (per extended block); kept (performance D9 A) |
| Pointers loaded from their slots | 4.5% | 3.3% | kept in registers between safepoints | performance M7 (done: 743M to 262M loads on its workload) |
| `FIELD`'s and `DECON`'s test of `vm->checked`, with its branch | 4.3% | 2.8% | none | M2 |
| `SWITCH` at 17.3 and 14.6 instructions | 3.3% | 1.4% | a jump through a table, about 5 | M2 |
| `ENV`'s null and length tests | 1.8% (`ENV` whole) | 4.1% | the field's load | M2 (the loader's check), M4 (the closure in the header) |
| Comparisons not fused, operands through `rax` and `rcx`, constants in registers | 0.7%, 0.6% (`setcc`, `INT`) | 0.2%, 0.3% | `cmp; jl`, in place, immediates | performance M6 (done in the main); the rest left |
| `div` and `mod` by a constant by `idiv` | 10.5M of them, 20 to 40 cycles each | 3.8M | a multiply and shifts | M2 |
| Polymorphic equality, strings, exceptions in C | 0.9% of cycles | 1.0% of cycles | identity first, in line | performance M5 (done) |
| Inlining in the JIT | | | OCaml and MLton inline before code generation | not here: the middle end; the JIT inlines nothing (jit.md M10) |
| A register allocator over the function | 6 homes serve 84 to 90% of register uses with pointers in them (performance.md E12) | | linear scan, graph colouring | not here: M4 frees `rbp`, which M8 takes |
| Unboxed reals | `real_nbody` at 0.94 times MLton (performance.md E1) | | | none needed |
| The bytecode itself | 1.217G bytecode instructions; MLton's code 4.85G machine instructions | 15.8G; Poly/ML's whole run 11.4G | | not here: the middle end |
| The collector | 30% of cycles | 7% of cycles | | garbage-collector-v3.md |

What it adds up to:

* **This plan takes the frame (M4 to M7), the body's faults (M2) and the
  allocation's fast path (M8):** what native code does in a few
  instructions and tier 2 in many, with nothing changed of what `--count`
  counts. On `db0fba57a` the body's faults have grown in share as the call
  shrank: what M2 would take is about 6% of the bootstrap's instructions.
* **It leaves the bytecode, the collector and inlining** to the middle end,
  to garbage-collector-v3.md and to a later plan
  ([whole-program-optimization.md](whole-program-optimization.md) is where
  performance.md puts what goes beyond it). On HOL that is not a detail:
  Rune's bytecode executes 15.8G instructions where Poly/ML's machine code
  executes 11.4G, so even a translation of one machine instruction per
  bytecode instruction would leave HOL at 1.4 times Poly/ML's
  instructions. On the bootstrap the collector is 30% of the cycles: 3.1G,
  half of what MLton's build of the compiler takes in all.
* **What Rune keeps on purpose** -- the count, the overflow checks SML
  requires, frames the collector can read -- costs about 11 instructions a
  `fib` call against OCaml, and 1.27 to 1.29 times its cycles at best (F1,
  variant 9).

**Where this plan would leave the whole programs, estimated at M1.** The
call's machinery cut to about a third (F1: variant 5's call against
tier 2's), M2's items removed and the allocation's fast path halved:

* the bootstrap about 2.9G instructions fewer (from 16.3G under callgrind,
  15.2G under `perf stat`), and its cycles from 10.2G to about 8.4G: 1.4 to
  1.5 times MLton's build (1.72 at M1), the rest being the collector and
  the runtime;
* HOL's kernel work with its compiled code's instructions about 45% fewer,
  and its cycles from 25.2G to about 17G to 18G: 2.0 to 2.2 times Poly/ML
  (2.98 at M1), the rest being the bytecode's volume, the collector and
  the runtime;
* `fib` and `tak`, which are calls and little else, under MLton's cycles.

These are estimates from the shares above, not measurements; M9 measures
them.

## Constraints

These hold for every milestone. They are AGENTS.md's, jit.md's and
performance.md's, and the list the brief named.

**The engines and their contract:**

* **`--count` exact on every engine** (performance D9 A, kept), with `r15`
  the count at every tier. A frame's header, a stub or a barrier executes
  no bytecode and counts nothing; a `RESULT` after a call stays the phantom
  that every engine passes over and none counts.
* **Allocation counts exact and the same on every engine** (performance
  D10 A): bytes and objects. M8 changes how they are kept, not what they
  say.
* **The driver never nests** (`runtime/register/jit.h`): the interpreter
  hands the VM back where a frame's code is native (`HANDOVER`,
  `RETURN_NATIVE`, `RAISED`), native code hands it back where a frame is
  interpreted, and a helper native code calls never runs bytecode. `make
  test-register-jit` runs a recursion 200,000 deep under a machine stack
  of 1 MB, and must go on passing: nothing of a program lives on the
  machine stack (jit.md D4).
* **Deoptimisation at any instruction boundary** (jit.md M11, `ms_exit`,
  `--deopt-stress`): every value in its slot, the VM exact, the count
  corrected. `check-jit.sh`'s seventh mode leaves after every
  instruction.
* **Tracebacks show every frame that is not a tail call**, with the frames
  the middle end inlined (`trace_frames`, the line table). `Runtime.trace`,
  an uncaught exception, the REPL's `:bt` (`rt_raise_trace`).
* **The debugger and the DAP adapter**: breakpoints, steps, a frame's
  variables, its closure's fields (`runtime/debug.c`, the `rt_debug_*`
  primitives of `runtime/prims.c`).
* **Images in bytecode terms** (jit.md D11 A): `Runtime.save`, `--restore`,
  `Runtime.restore` and the emulated fork write frames and handlers as
  pcs; no native address goes into an image; an image crosses between
  `runevm`, `runevm-stack`, the 32-bit and the PowerPC VMs in every
  direction (`make test-portability`).
* **The REPL and units**: `Runtime.link` grows the program under running
  frames (`jit_grow`), `rt_raise_mark` records the frames a raise leaves.
* **Invalidation** with frames live in the code (`jit_invalidate`,
  `--jit-stress`).
* **Every target**: x86-64 under the System V and Windows conventions and
  aarch64, through the portable assembler (`runtime/register/jit/asm.h`;
  no encoder's name in the emitters); `make windows && make test-windows`,
  `make portability && make test-portability`. The 32-bit and PowerPC VMs
  run the interpreter alone, and must run it on the same frames.
* **The collector's roots**: a waiting frame's registers as far as they
  are live where its callee returns (`VM.frame_live`), the watermark below
  which a minor collection does not scan (garbage-collector-v2.md D9),
  `--gc-stress`, `--gc-verify`, `make test-heap`, `make test-stress`.

**The code base:**

* `runevm-stack` and `runeopt` share the runtime with `runevm`
  (`build/librune.a`) and keep their frames: `runeopt` is frozen
  (performance D11 B), and the stack bytecode is not this plan's. So the
  shared runtime asks the instruction set how to walk frames, as it asks it
  for the fingerprint, the checker and the disassembler
  (`runtime/stack/isa_stack.c`, `runtime/register/isa_regs.c`).
* The emitters' rules of AGENTS.md: the VM exact before a call into C, no
  heap pointer in a machine register across one, every store into an
  object through `ms_set_field`, a field of the VM by `offsetof`.
* A change to `runtime/register` updates `runtime/register/README.md`, and
  runs `make check`, `make test-register-asan`, `make test-stress`, `make
  test-heap`, `make test-windows` and `make test-portability`. A change to
  the instruction set's bodies goes through `src/isa/regs.sml` and `make
  isa`.

## The architecture

What the recommendations of *Decisions* make, together. The frame stays
the VM's, on the VM's value stack, as jit.md D4 wants; what changes is that
its record moves from an array beside the stack into the stack, below the
callee's registers, and that it holds the address the callee returns to.

### The frame

```
  the value stack (grows upwards; indices, so that it may move)

  │ ...                           │
  ├───────────────────────────────┤
  │ callee's registers 0 .. m-1   │ ◄─ r14: the callee's base b'
  ├───────────────────────────────┤
  │ b'-1  the return word         │  a landing in the caller's code, the
  │                               │  interpreter's return stub, or the
  │                               │  barrier's stub (M5)
  │ b'-2  the closure             │  CALL, TAILCALL: the closure, a root;
  │                               │  CALLK: left as it was
  │ b'-3  the info word           │  the caller's function and the pc of its
  │                               │  RESULT, as an immediate: written by the
  │                               │  interpreter and by a conversion
  ├───────────────────────────────┤
  │ caller's registers 0 .. n-1   │ ◄─ the caller's base b = b' - 3 - n
  ├───────────────────────────────┤
  │ the caller's own header       │
  │ ...                           │
```

* **Three words are reserved, one or two written.** Compiled code writes
  the return word of every call, and the closure of a call through one;
  the interpreter writes all three; a frame converted for the interpreter
  (invalidation, an image restored) gets its info word then.
* **The closure word counts only where it is read.** Only `ENV` and
  `SELF` read a frame's closure, and a known call never enters a function
  that has them (its closure is `NULL` today, which they refuse). So the
  walk reads the closure word, and the collector takes it as a root, for a
  frame whose function reads its closure, and for no other; a `TAILCALL`
  writes it, a `TAILCALLK` leaves it. That keeps alive fewer closures than
  today's record does, as the registers' liveness does for registers.
  Under the stack's clean watermark (performance M6: the stack kept clean
  above the stack pointer) a word left unwritten holds unit or a value an
  earlier frame stored, never garbage, but the walk does not read it.
* **The VM keeps the running frame's base and function** (`vm->base`,
  `vm->func`) where it keeps `vm->fp` today, exact wherever C can look:
  `ms_sync` writes them, `ms_reload` reads `r14` back. The array
  `vm->frames` goes from `runevm`.
* **A frame's size is its function's registers and three words.** Above
  its registers a frame pushes only a primitive's arguments, a returned
  value and a raised exception (`maxstack`), never across a call, so the
  callee's base is the caller's base plus its registers plus three.

### Its descriptor

A frame that waits for a call is described by a pair: its function, and
the pc of the `RESULT` at which it waits. The header its callee's frame
holds names that pair. Everything else follows from the pair and the
bytecode, as it does today:

* **the frame's size**: the function's registers, and three;
* **what is live, and so a root**: `live.c`'s table of the function, keyed
  by that pc, which the collector already asks (`VM.frame_live`);
* **which slots hold pointers**: their tags, as today ("the tags are the
  stack map", jit.md D10);
* **the pc for traces, the debugger and deoptimisation**: the pair's pc;
* **where the returned value goes**: the `RESULT`'s register, from the code
  (`Frame.result` today);
* **the handlers**: the handlers' array, each recording its frame's base
  rather than an index.

The pair is found from the return word. The interpreter's stub says that
the info word holds it. A landing in compiled code is found in its code
object (code objects lie in the region in the order they were compiled, so
a binary search by address), and in the code object's table of pc to
address (`jit_osr`'s, which has an entry for the instruction after every
call; its addresses rise with its pcs), at 110 to 124 ns (F6). The barrier's
stub says that the real return word is in the VM.

### A call, a return, a landing

In compiled code, at tier 1 and tier 2 alike, with what M4 to M7 each add:

```
  CALLK f (n registers here):    args (M6: into registers; before, into the callee's slots)
                                 lea rcx, [rip + landing]; mov [r14 + 8(n+3) - 8], rcx
                                     (M7: call; the callee pops it into the word)
                                 add r14, 8(n+3)
                                 jmp f                    (a rel32 where f has code)
  f's entry:                     (M7: pop [r14-8])
                                 cmp r14, [r13 + limit]; ja slow      the room, and the poll
                                 (M6: arguments into homes, or slots)
  RET s:                         mov rax, s; jmp [r14-8]  (M7: push [r14-8]; ret)
  landing:                       sub r14, 8(n+3)
                                 (before M5: the watermark compared and lowered)
                                 the result from rax into its register; homes live after it loaded
```

A call through a closure finds the function's index in the closure, its
code object's entry in the JIT's table, writes the closure into the header
as well, and jumps through the entry (or hands the VM to the interpreter
where there is none, as today). A tail call moves its arguments down and
keeps the header, so that its callee returns to the caller's caller.
`ENV` reads the closure at `[r14-16]`: one load and the field's.

### The interpreter, and crossing between the tiers

The interpreter uses the same frames: its `CALL`, `CALLK`, `TAILCALL` and
`TAILCALLK` (their bodies in `src/isa/regs.sml`) write the header, its
`RET` reads it. One layout for every engine of `runevm` means one walk, one
image writer, one collector's scan, and no conversion where a frame
crosses between the tiers, which F3 says is rare anyway (0.4% and 0.03% of
calls).

The driver's protocol stays as it is, frames being shared:

* **The interpreter calls a function with code**: it writes the header
  with the return word its stub, hands the VM to the driver, which enters
  the callee's entry (M6: the entry that takes its arguments from the
  slots).
* **Compiled code calls a function without code**: the header's return
  word is its landing; the VM is made exact and handed to the interpreter,
  which runs the callee.
* **Compiled code returns into an interpreted frame**: `jmp [r14-8]`
  lands in the interpreter's stub, a piece of code at the region's start,
  which reads the info word, writes the value into the caller's `RESULT`
  register, makes the VM exact and hands it back with `RUN_INTERP` --
  today's slow half of `RET`, taken out of every return (performance M6's
  trampolines are this stub's first form).
* **The interpreter returns into a compiled frame**: the return word is a
  landing; the driver enters it with the value in `rax` (the enter stub
  takes the value).
* **A raise into a handler of the other tier**: the handlers' `native`, as
  today.

The machine stack holds the call into C in progress, as today, and under
M7 a return address for the two instructions between a `call` and the
callee's `pop`.

### Deoptimisation and invalidation

**Leaving compiled code at an instruction boundary** (`ms_exit`) does what
it does today: the homes live there written back, the VM made exact with
`vm->base` and `vm->func`, the count corrected, `RUN_INTERP`. The frame's
own header belongs to its caller and stays as it is: whoever returns from
the frame later reads it.

**Invalidating a function** (`jit_invalidate`) walks the frames, as today it
walks `vm->frames`: a return word that lands in the function's code is
replaced by the interpreter's stub, and the info word written from the
code object's descriptor, whose code and tables stay in the region as dead
bytes. Handlers whose `native` lies in the code are cleared, as today.

### Handlers and raises

A handler records `{pc, sp, base, native}`: the frame's base instead of
its index. A raise (`vm_raise`, and performance M5's raise that unwinds in
compiled code) sets `vm->base`, `vm->func` (from the handler's pc), the
stack pointer, lowers the watermark to the handler's frame and arms the
barrier there (M5). No return address is consumed; under M7, the
processor's stack of predicted returns is left out of step, which costs
mispredictions and nothing else (*Risks*).

### The collector

**The roots** are what they are today: each waiting frame's registers as
far as `frame_live(func, ret_pc)` says they are live, unit written into a
dead one that holds a pointer; the running frame's registers all; the
closure word of a frame whose function reads its closure. The walk skips
the return and info words.

**The watermark** becomes a base (a stack index): the lowest frame that has
run since the last minor collection, below which a minor collection does
not scan. Until M5 it is kept as today, by a compare in every return
(variant 2 of F1). From M5, by a return barrier: after a collection, the
return word of the frame at the watermark is the barrier's stub and the
real word is kept in the VM. Returning through it lowers the watermark by
one frame, moves the barrier to the next frame down and goes on at the
real word. Returns above the watermark pay nothing. Each return through
the barrier lowers the watermark to a frame that the next minor collection
then walks, so the stub runs no more often than F4's walks: at most 47,176
times in the bootstrap's 391 minor collections, against 76.1M returns.
`--gc-verify` checks that the barrier sits at the watermark, as `check.c`
checks the watermark today.

### The limit, and the poll

`vm->limit` is the address up to which a frame's base may go: the stack's
end less a slack, larger than nearly every function's frame and room. A
function's entry compares `r14` with it; a function whose frame and room
exceed the slack compares its base plus its need. Anything that wants
compiled code to stop -- the user's interrupt, the debugger's bit -- sets
the limit to 0, and the slow path tells a poll from a stack that must grow
by `vm->interrupt`, as today's `poll_slow` tells its cases. A loop's jump back
makes the same compare. That replaces, per call, today's poll, room check
and frames check (9 instructions of `fib`'s 82.5).

### Images, traces, the debugger, the REPL

**An image** keeps its format: the writer walks the frames and writes for
each what it writes today (function, return pc, base, closure, the last
`NULL` where the function does not read it); the reader
makes the headers, each return word the interpreter's stub, so that a
restored frame runs interpreted until compiled code is entered at its
resume point (`jit_osr`), as today. Images still cross between every VM.

**A trace**, `Runtime.trace`, the REPL's frames of a raise and the
debugger's frames are walks: each frame's function and pc, and the
inlined frames the line table gives at that pc. The debugger names a frame
by its base, which is unique among live frames and grows with the depth,
where it uses the frame's index today (its step's frame, its keys per
frame).

### Registers

| x86-64 | aarch64 | Holds |
|---|---|---|
| `r13` | `x19` | the VM |
| `r14` | `x22` | the frame's registers |
| `r15` | `x23` | the count |
| `rbp` | `x21` | today the frame's base as an index; from M4 free, from M8 the allocation pointer |
| `rbx`, `r12`, `rsi`, `rdi`, `r10`, `r9` | `x24` to `x26`, `x20`, `x28`, `x27`, `x15`, `x4` to `x8` | tier 2's general homes (and pointers' from performance M7) |
| `rax` | `x0` | a result |
| `rsp` | `sp` | the C stack; under M7 a return address between `call` and `pop` |
| | `x30` | under M7, the return address between `bl` and the callee's store |

No register is saved by a callee (D6): a value live across a call is in its
slot at the call, so the tags stay the stack map, deoptimisation finds every
value in the frame, and no map of registers is needed (performance D6's C
is not).

## Decisions

Each decision gives the options, the evidence, and a recommendation.
"Measured" means an experiment of this plan or of performance.md;
"estimated" means reasoned from the measurements.

The owner took every recommendation on 2026-10-12. Each decision records
it.

**Restated at M1 (2026-10-19), against what performance M6 and M7
built.** No decision changes; these premises did:

* **D1.** C's evidence was F1's variant 1. Performance M6 as built does
  better with the same instructions -- 39 and 11.0 cycles a `fib` call,
  1.26 times MLton -- since it keeps the record's address in `rbp`. A's
  prototypes, in the same session, take 6.2 to 7.6 cycles: still 31 to
  44% of a call's cycles, and the difference between 1.3 times MLton and
  0.7 to 0.8 times (*F1*, the third session).
* **D2.** M6's record keeps the function and the pc in one word, as D2's
  info word does: the layout carries over.
* **D4.** The watermark's compare is two instructions since M6 (`cmp rbp,
  [frame_low]; jbe` to a stub that lowers it), not three; the barrier
  saves those two in every return. Every reader of a return address must
  then see through the barrier's word, which M3's walk is for.
* **D5.** The result in `rax` is done (M6), and so are a tail call's
  arguments written in place; the arguments of a call stay this plan's.
* **D6.** M7's pointer homes made the write-back before a call and the
  homes' reload at a landing larger: on its bootstrap, landings from 274M
  to 404M instructions and write-backs from 19M to 58M (performance M7).
  Callee-saved registers would keep homes across calls; native frames keep
  A, as decided, and M9 measures what the reloads then cost.
* **D7.** `rbp` holds the frame's record since M6, not the frame's base.
  M4 removes the record, so `rbp` is free from M4 as D7 B wants.
* **D8.** M6 fused comparisons with their branches and does `int_add` and
  `int_sub` in place at tier 2. What is left for M2 is the constructor's
  tag, the test of `vm->checked`, `SWITCH`, `ENV`'s tests and division by
  a constant (F5 on `db0fba57a`).
* **D9 and D10** stand. M6 grew the frames array with the stack's clean
  part (a frame per slot); it goes with the array in M4.

### D1. Where frames live

**Decided (2026-10-12): as recommended.**

* **A. In the value stack.** The frame's record becomes a header below
  the callee's registers, written by the caller, holding the return
  address; a return is an indirect jump through it (MLton, Chez, GHC).
  Measured (F1, variants 2 to 5): 21 to 25.5 instructions and 7 to 10
  cycles a `fib` call, against MLton's 17 and 9 to 10. Frames stay the
  VM's (jit.md D4), the machine stack is untouched, images stay in
  bytecode terms.
* **B. On the machine stack:** `rsp` pointed into a stack the VM owns,
  `call` and `ret` (OCaml 5, Poly/ML).
  * Rune's value stack grows upwards and `call` pushes downwards. Either
    the value stack is turned over -- in every engine, the collector, the
    images' indices -- or the return addresses live on a stack of their
    own beside the registers (F1's variant 6), which every walk keeps in
    step.
  * Every call into C switches `rsp` back (8.6M of them in the
    bootstrap, performance.md E12); a signal lands on the switched stack
    (`sigaltstack`); Windows checks `rsp` against the thread's limits in
    `__chkstk`; ASan and valgrind are to be told (codegen.md, *D3's
    option A*, listed the same).
  * Measured (variant 6): 19 instructions, 5.8 to 6.8 cycles a `fib`
    call. Variant 9 has the same cycles without moving `rsp` (D3).
* **C. The VM's records, made lean** (performance M6's end state).
  Measured (variant 1): 39.5 instructions, 17 to 18 cycles.

**Recommendation: A.** It is the only option that reaches MLton without
moving `rsp`, and B's one advantage, predicted returns, D3 B gets inside
A.

### D2. What the header holds, and who writes it

**Decided (2026-10-12): as recommended.**

* **A. Three words, all written by every call:** the return address, the
  closure or unit, the caller's function and pc. A walk reads the frame
  and searches nothing. Measured: two more instructions a call than C
  (F1, variant 4 against 5).
* **B. Three words reserved, one or two written.** Compiled code writes
  the return word, and the closure for a call through one; the interpreter
  writes all three; a frame converted for the interpreter gets its info
  word then. A walk finds a compiled caller's function and pc from the
  return address: 110 to 124 ns (F6), 6 ms for the bootstrap's 51,000
  frames walked, against the 92M stores of A.
* **C. One word:** the return address alone, the closure saved by the
  callee where it needs it, an interpreted frame with more words that its
  stub describes. 16 bytes less a frame, but the layout varies with the
  call and the engine, and invalidation must convert a frame that has no
  room for its info word.

**Recommendation: B.** The instructions of C on the call's path, the
uniform layout of A.

### D3. How a function returns

**Decided (2026-10-12): as recommended.**

* **A. `jmp [r14-8]`** (MLton, Chez, GHC; F1's variant 5).
* **B. Returns the processor predicts, `rsp` unmoved:** `call`, the
  callee's `pop [r14-8]` at its entry, `push [r14-8]; ret`; on aarch64
  `bl`, the link register stored at the entry, `ldr x30, ...; ret`.
  * Measured (variant 9): the instructions of A, and 11% fewer cycles on
    `fib`, 25% on `tak`; as fast as `call` and `ret` on a stack of their
    own.
  * But all branch misses together are at most 5.7% of the bootstrap's
    cycles and 2.6% of HOL's (F2), so on whole programs it gains a few
    percent at most.
  * It costs a second entry per function (the driver and a tail call
    enter past the `pop`). A raise leaves the processor's stack of returns
    out of step, and HOL raises 4.86M times in its kernel work
    (performance.md E11). A process with a CET shadow stack would fault on
    a return through a rewritten word; `runevm` is not marked for one.
* **C. `call` and `ret` on a stack of return addresses of their own**
  (variant 6): as fast as B, with D1 B's costs.

**Recommendation: A in M4; B built in M7 and kept if it gains** at least
1% of cycles on the bootstrap and on HOL's kernel work (the best of ten,
interleaved), with A behind a flag for a machine that wants it.

### D4. The watermark

**Decided (2026-10-12): as recommended.**

* **A. A compare in every return**, as today (three instructions;
  HotSpot's return poll is two, `macroAssembler_x86.cpp:2578-2588`).
* **B. A return barrier:** after a minor collection, the return word of
  the frame at the watermark is a stub that lowers it.

Measured (F1, variant 2 against 3): 2 instructions a call, 0 to 3 cycles.
The stub would run at most 47,176 times in the bootstrap, against 76.1M
returns (F4).

**Recommendation: B, in M5**, once M4 has made every walk of frames go
through one function that sees through the barrier's word.

### D5. Arguments and results

**Decided (2026-10-12): as recommended.**

The result in `rax`: performance M6 makes it so, and it stays.

* **A. Arguments in the callee's slots**, as today.
* **B. Arguments in registers**: a known call's, as many as the
  convention gives, and a call through a closure's one; a second entry,
  taking them from the slots, for the interpreter and the driver.
  * Measured (F1, variant 3 against 4): half an instruction a `fib` call,
    nothing on `tak`, which spill their arguments anyway, being live across
    calls. Leaves gain the store and the load.
  * It costs the parallel move at a call (the arguments' registers are
    homes) and the second entry. Deoptimisation is untouched: homes are
    written back at a boundary as today.

**Recommendation: B, measured in M6**, kept if it takes at least 0.5% of
the bootstrap's instructions; otherwise dropped, and the result recorded
here.

### D6. Which registers a callee saves

**Decided (2026-10-12): as recommended.**

* **A. None.** Every value live across a call is in its slot at the call
  (OCaml, MLton, Chez, GHC). The tags stay the stack map; deoptimisation,
  images and the debugger read slots; performance M7's pointer homes are
  written back at a call as int homes are.
* **B. Some, for values that are not pointers.** Numeric code would keep
  ints and reals in registers across calls. It needs a map per return
  address of which register holds which value, for deoptimisation, the
  debugger and images (not the collector), and saves and restores in the
  callees.
* **C. Some, for pointers too:** maps for the collector as well
  (performance D6 C). OCaml's descriptor entries for registers are for
  allocation points only; at calls it has none.

F1's sequences reach MLton and Poly/ML with none, and OCaml is the fastest
of the three with none.

**Recommendation: A.** Performance D6's C is not needed.

### D7. The allocation pointer

**Decided (2026-10-12): as recommended.**

* **A. As today:** `alloc.used` in the VM, the two counters of `--count`
  read-modify-written per object, `--gc-stress` tested per object: 12
  instructions before the header and the fields.
* **B. In a register** (`rbp`, freed by M4; `x21` on aarch64): a bump and a
  compare against a limit. The bytes are counted from the pointer's
  progress wherever C can look (a sync, a collection), less the boxes,
  which the helper that makes one subtracts; the objects by a constant
  added once per run that allocates, as instructions are counted, with the
  same corrections where a run is left early; `--gc-stress` by setting the
  limit.

Measured (F5): allocation is 5.8% of the bootstrap's compiled code and
8.6% of HOL's; 107M and 102M read-modify-writes of the counters. OCaml's
fast path is three or four instructions.

**Recommendation: B, in M8.** The counts stay exact and the same on every
engine (performance D10 A).

### D8. The body

**Decided (2026-10-12): as recommended.**

Which of F5's items this plan takes, and when.

* **A. In this plan, first (M2), item by item, each measured:** a
  comparison fused with its branch wherever the bool dies there,
  constants as immediates, arithmetic in place, `JUMPIFNOTTAG` in 2 to 4
  instructions, the test of `vm->checked` compiled in only under
  `--checked`, `div` and `mod` by a constant by multiplication.
* **B. A plan of its own.**
* **C. Not at all.**

**Recommendation: A.** The targets per call need it -- `fib`'s body is 20
machine instructions today, 10 in F1's variants -- and it is the cheapest
step, independent of the frames. Inlining in the JIT, a register allocator
over the function and unboxed reals across calls are not taken (*What
else stands between Rune and OCaml*).

### D9. One layout for every engine of `runevm`

**Decided (2026-10-12): as recommended.**

* **A. The interpreter and both tiers on the same headers**; `vm->frames`
  gone from `runevm`.
* **B. The interpreter keeps `vm->frames`; compiled code has headers;** a
  frame is converted where it crosses between the tiers.

F3 says B's conversions would be rare (0.4% and 0.03% of calls). But B
keeps two layouts for every walk, every image, the collector, the
debugger and deoptimisation, which then converts too.

**Recommendation: A.** The interpreter gains as well: three stores a call
where today's record takes seven.

### D10. The runtime that `runevm-stack` and `runeopt` share

**Decided (2026-10-12): as recommended.**

* **A. A walk of frames per instruction set,** which every reader of frames
  in the shared runtime uses: over the array in `runtime/stack/isa_stack.c`,
  over the headers in `runtime/register/isa_regs.c`.
* **B. `vm->frames` kept in `runevm` as a view,** made from the headers
  wherever C may look.

**Recommendation: A**, made in M3 with no change of behaviour, before M4
changes the register VM's frames. B's view would be remade at every
collection, and would go stale as frames pop.

## The milestones

Each ends with every suite green on every target (*Constraints*), its
targets measured as *Measuring* says and written into *Status*. Targets in
instructions are exact counts; cycles are indications, compared within a
session. "At M1" means the baselines M1 records, after performance M5 to
M7; today's figures are given beside them where the target is absolute.

### M1. The gate (S)

performance.md's M9 gate, once performance M5 to M7 are on `performance`:

* E9 again on the code as it then is: instructions per call of `fib`,
  `tak` and a call through a closure, by role (performance M1's dump of
  the JIT's code, callgrind at two run lengths); F1 again in the same
  session, the real code beside the variants and the three other
  compilers;
* the bootstrap's and HOL's instructions by role (F5's script, over M1's
  dump), and their cycles against MLton's build and Poly/ML;
* those figures recorded here as the baselines of M2 to M9.

**The gate:** native frames go ahead if the call's machinery is still the
largest part of HOL's gap to Poly/ML. Expected, from F1: performance M6's
targets leave a closure call at 25 instructions and a `fib` call at 40 to
50, where variant 5 needs 21.

**Done** (2026-10-19, on `db0fba57a`): *Where we are* measured again, F1's
third session, F3 to F5 again, and the decisions' premises restated
(*Decisions*). The gate is open: the call's machinery is 40% of HOL's
compiled code, which is 84% of its cycles. The baselines of the
milestones below:

| | At M1 |
|---|---:|
| a `fib` call: instructions, cycles | 39.0, 11.0 |
| a `tak` call | 47.3, 13.1 |
| a call through a closure and its return: instructions | 29 |
| the bootstrap (`results/M9/bootwl`): instructions, cycles | 15.23G, 10.2G (MLton's build 4.85G, 5.9G) |
| ... its call machinery, under callgrind | 2.33G of 16.32G (14.3%) |
| HOL's kernel work (HOL-midM8): instructions, cycles | 53.0G, 25.2G (Poly/ML 11.4G, 8.5G) |
| MLton's set against MLton, cycles | geometric mean 4.58 (37 programs); the seven of calls and closures 1.32 to 3.16; tests/perf's `fib` and `tak` 1.36, 1.35 |

Found on the way: `scripts/hol-kernel.sh` ran a HOL built by Rune on the
VM it was built with even where `$RUNEVM` named another, as HOL's
`buildheap` execs its own; it now runs that HOL's state on `$RUNEVM`, with
`$RUNEVM_OPTS`.

### M2. The body (M)

D8 A, item by item, each measured on tests/perf, the bootstrap and HOL's
kernel work and kept where it gains. Performance M6 did the comparison
fused with its branch and `int_add` and `int_sub` in place; what is left
(F5 on `db0fba57a`):

* `JUMPIFNOTTAG` in 2 instructions for a nullary tag (a compare of the
  word) and 4 for a pointer's (its low bit tested, its tag compared in
  memory), from 8.1 (92.5M executions in the bootstrap, 47.7M in HOL's
  slice);
* `SWITCH` by a jump through its table on the tag made in one or two
  instructions, from 17.3;
* the test of `vm->checked` in `FIELD` and `DECON` compiled in only when
  the VM runs under `--checked`: `vm->checked` is the command line's, set
  before any code is made (170M tests in the bootstrap, each with its
  branch);
* `ENV`'s and `SELF`'s tests of a null closure and of its length, which
  stay because nothing checks an `ENV`'s index against the closures made
  of its function: the loader checks it, as it checks the rest of the
  code, and the tests go where it has (performance M6's note: at most
  about 150M of the bootstrap);
* `div` and `mod` by a constant by a multiplication and shifts, with the
  same results and the same raise (10.5M `idiv`s).

**Targets:**

* the bootstrap at least 4% fewer instructions than at M1 (the items are
  about 6%), HOL's kernel work at least 2.5% fewer;
* `JUMPIFNOTTAG`'s body at most 4 instructions on average, `SWITCH`'s at
  most 8;
* no program of tests/perf or MLton's set more instructions;
* `--count` unchanged on every program.

**Done** (2026-10-19; `runtime/register/jit/masm.c`, `emit.c`; two tests
in `tests/lang`):

* **The constructor's tag by its representation** (`ms_jump_unless_tag`,
  and `ms_load_tag_of_con` for `SWITCH`): a datatype of nullary
  constructors alone compares its word with the tag's, in its home or its
  slot (2 instructions); one whose constructors all carry a value loads its
  object's tag with no test of the word, the section vouching for a
  constructor (3); a mixed one tests its low bit and then compares the
  immediate or the object's tag, with no kind tested (4 or 6). A layout
  that gave both of the mixed one's paths 5 measured worse: 14.528G
  instructions on the bootstrap against 14.516G, the immediates being the
  commoner. Tier 1, and a register of no known representation, keep every
  test.
* **The test of `vm->checked`** is compiled in only when the VM runs under
  `--checked`, at either tier: `FIELD` from 4.6 machine instructions an
  execution to 2.6.
* **`int_mod` by a positive power of two** is an `and` with one less than
  it -- the floor's remainder of a negative dividend too -- at either tier,
  where an `idiv` takes tens of cycles: the bootstrap's hash tables
  (`IntTable`, 7.1M of its 10.5M `idiv`s). `Int64.int`'s keeps the
  division, whose `-2^63` would pass the test.
* **Measured** (`perf stat`, exact; the bootstrap of `results/M9/bootwl`,
  HOL's kernel work on HOL-midM8): the bootstrap 15.230G to 14.516G
  instructions (−4.7%), HOL's kernel work 53.016G to 49.953G (−5.8%); by
  callgrind on the bootstrap, `JUMPIFNOTTAG`'s body 8.1 to 5.7 instructions
  an execution and `SWITCH`'s 17.3 to 9.4 -- both short of their targets,
  which the tag's kind would meet if the bytecode said whether a
  constructor is nullary, as it does not. Cycles, an indication: the
  bootstrap 9.87G to 9.15G (−7%), HOL's kernel work 26.6G to 23.7G (−11%)
  (`scripts/M9/ab.sh`, interleaved, the least of three). Every output the
  same, the bootstrap's byte for byte; `--count` unchanged
  (`check-jit.sh` in every mode).
* **Not built:** `ENV`'s and `SELF`'s tests (about 0.6% of the bootstrap's
  instructions, about 1% of HOL's): the loader would have to hold every
  closure of a function to its `ENV`s and keep known calls out of
  functions with them, across units loaded later; M4 makes the closure's
  load one instruction instead. Division by a constant: 2.5M of the
  bootstrap's 10.5M `idiv`s, for constants the JIT does not track.

### M3. Frames walked, not indexed (M)

D10 A: a walk of frames per instruction set, and every reader of frames in
the shared runtime over it, with no change of behaviour.

* `runtime/vm.h` names a frame by a cursor -- its function, its pc, its
  base, its closure -- and the step to its caller; `isa_stack.c` walks the
  array, `isa_regs.c` too until M4.
* Its readers: the collector (`gc/copy.c`, `minor.c`, `mark.c`,
  `check.c`), images (`image.c`), traces and raises (`runtime.c`), the
  debugger (`debug.c`, the `rt_debug_*` primitives), the REPL's frames of a
  raise, the census, invalidation (`jit.c`).
* A handler records its frame's base; the debugger names a frame by its
  base.

**Targets:**

* every output and every count unchanged, the bootstrap's instructions
  within 0.2%;
* `vm->frames` named nowhere but the two instruction sets' files, the
  engines' loops and the push in `vm.h`.

**Done** (2026-10-19; `runtime/vm.h`, `runtime/frames_array.inc`, both
instruction sets' files, `runtime/runtime.c`, `image.c`, `prims.c`,
`debug.c`, `gc/copy.c`, `gc/minor.c`, `gc/mark.c`, `gc/chunk.c`,
`gc/check.c`, `gc/gc.h`, `census/census.c`):

* **The walk** (`vm.h`, *The frames, as the runtime reads them*): a frame
  as the runtime reads it (`FrameRef`: its function, its pc, the pc it
  returns to, its base, its id, the cell of its closure), from the one that
  runs down (`vm_frame_top`, `vm_frame_down`, `vm_frame_find`), or the
  frames from an id up, the top level's first, in a buffer of the VM's
  (`vm_frames_from`, for the collector, whose order of roots stays the
  same); and what an engine's frames must answer for the runtime: the
  running frame's id, the frame compiled code said is live
  (`vm_frame_top_live`), the watermark (`vm_frames_mark_low`,
  `vm_frames_low`), a frame pushed and dropped (`vm_start`'s and the
  debugger's), a raise's unwinding to a handler's frame, the frames an
  image gives (`vm_frames_install`), and every frame sent to the
  interpreter (debug mode, `Runtime.restore`). Each instruction set gives
  them; both include `runtime/frames_array.inc`, the array of records,
  in which a frame's id is its index.
* **The readers on it:** the collector's scans of the stack, its roots,
  its watermark and its check; images' writing, reading and checking;
  traces, a fatal error's frame, a raise's frames for the REPL and its
  unwinding, a handler's frame; `Runtime.trace` (which keeps what it needs
  apart before it allocates, since a collection walks into the VM's
  buffer); the debugger's frames, its primitives (`stop_frame` walks down
  from the frame that stopped) and its keys per frame, by id; the census.
  `vm->frames` is named now only by the engines -- the stack VM's loop,
  `runeopt`'s glue, the register VM's loop, its JIT -- and the array's
  file. AGENTS.md says so.
* **Measured:** the bootstrap 14.516G to 14.519G instructions (+0.02%,
  the walk's calls in the collector), its output byte for byte and
  `--count` the same; the language suite on both VMs, `check-jit.sh` in
  every mode.

### M4. Frames in the value stack (L)

D1 A, D2 B, D6 A, D9 A, with returns by `jmp` (D3 A) and the watermark by a
compare (D4 A, until M5):

* the header; `vm->base` and `vm->func`; `vm->frames` gone from `runevm`;
* the interpreter's `CALL`, `CALLK`, `TAILCALL`, `TAILCALLK` and `RET`
  (`src/isa/regs.sml`, `make isa`); the emitters of the same, of `ENV` and
  of the landing, at both tiers; the interpreter's return stub;
* the limit compare at entry and at a jump back, as the room and the poll;
* the result in `rax`; a closure call's entry read from the JIT's table;
* handlers by base, raises, invalidation, images, the debugger and traces
  over the walk of M3;
* x86-64 under both conventions, and aarch64 (`ldr` and `br` for the
  return; the portable assembler grows by what that needs).

**Targets:**

* a `fib` call at most 26 instructions, a `tak` call at most 34 (39.0 and
  47.3 at M1; variants 2 and 3: 23.5 to 25.5, 32 to 34), and at most 9
  cycles a `fib` call (11.0 at M1, MLton 8.7 to 10);
* a call through a closure and its return at most 15 instructions of call
  machinery (29 at M1, 75 on 2026-10-12);
* the bootstrap's call machinery (the roles return, frame, room, poll,
  arguments, jump, closure, landing, write-back) at most 8% of its
  instructions under callgrind (14.3% at M1; 31% on 2026-10-12); the
  bootstrap at least 6% fewer instructions than at M4's start, HOL's
  kernel work at least 8% fewer;
* the seven programs of calls and closures of MLton's set (*Where we
  are*) each at least 10% fewer instructions;
* `--count` unchanged everywhere; images unchanged in format and crossing
  between every VM.

**Done** (2026-10-19; `runtime/register/isa_regs.c`, `regvm.h`, the
loop's words and bodies (`reg_words.h`, `src/isa/regs.sml`), the JIT's
`jit.c`, `compile.c`, `emit.c`, `masm.c` and its assemblers, `vm.h`,
`runtime.c`, `image.c`, `debug.c`, `prims.c`, `gc/copy.c`, `gc/minor.c`,
`gc/check.c`, `census/census.c`):

* **The frame** is its registers and, below them, three words its caller
  writes (`regvm.h`): the *info word*, an immediate of the caller's
  function, the pc of the `RESULT` it returns to and what it says of the
  caller's base; the closure; and the *return word*, an odd number, the
  interpreter's stub (`VM.ret_word`) or the landing of a compiled call --
  on x86-64 the landing at an odd address, a `nop` before it, on aarch64
  the address and 1, `ldr`, `sub` and `br` to return. The interpreter and
  the runtime write all three; compiled code the return word, and the
  closure for a call through one or to a function that reads its closure
  (`ENV`, `SELF`: `Function.reads_closure`, worked out by the loader), to
  which a known call gives `unit`. `VM.fp` is the running frame's base, its
  id, and `VM.func` its function; `vm->frames` is `runevm-stack`'s and
  runeopt's alone. A frame the runtime pushes above values of its own (the
  debugger's `<debug>` at a stop where the stack holds more than the
  registers) keeps its caller's base in a fourth word, and the top level's
  says it has no caller. That one stays whole when the program ends, its
  `RET` leaving the value above the header, for what walks the frames
  after the end (the census's last collection, which found the header
  overwritten in this milestone's first chain); and a fatal error met in
  telling of one -- frames broken, which the walk that names the function
  finds -- is told alone, without the frames.
* **The walk** (`isa_regs.c`) reads each frame's caller from its header:
  the info word, or, for a landing, its code object's table of landings,
  the code found by address among the region's code objects in the order
  they were compiled (`jit_landing_info`), the last 256 return words kept.
  The collector scans a header as the slots between frames, the closure
  made `unit` first where the frame does not read one -- so a header keeps
  less alive than the record did, which kept every closure called through
  -- and a minor collection scans the watermark's frame's header too,
  which its tail calls write. Invalidation and the debugger's debug mode
  give the frames returning into compiled code the interpreter's return
  word and the info word from the landing.
* **Calls and returns.** A known call: its room checked, the arguments
  above the frame and a header, the return word (`lea`, `mov`), `r14`
  moved and the jump; a call through a closure stores the closure too.
  `RET` is `mov rax, s; jmp [r14-8]`. The landing moves `r14` back,
  compares it with `VM.frame_low` (lowered in a slow path; until M5),
  loads the homes needed and stores the result. The room checks compare
  with the clean part's end less `ROOM_SLACK` values (256), so that a
  known call whose frame wants no more compares its own base, `r14`
  (`cmp`, `ja`). The interpreter's `RET` into a landing hands the VM to the
  driver with the value (`VM.ret_value`, which the enter stub loads into
  `rax`); compiled code's into the interpreter goes through the return stub
  (`jit_h_return`), and its call into a function without code through the
  stub that tells the VM the callee (`ms_emit_call_interp`, the function's
  word in `r11`). `rbp` is unused, kept for M8.
* **Images** keep the layout of every engine: the writer leaves the
  headers out of the stack (a frame's base and a handler's stack pointer
  less the words below them, a handler's frame by its index), the reader
  makes them (`vm_frames_install`), each frame returning to the
  interpreter, and checks that each frame lies above its caller's
  registers and its closure is one. HOL-midM8's `hol.state`, written
  before M4, restores and runs; `Runtime.save` and `restore`, the fork, the
  debugger, traces and the census (its samples count frames by index) read
  the frames through the walk.
* **Measured** (`perf stat`, exact; pinned, the least of five for cycles;
  M3's VM against M4's, built alike):
  * a `fib` call 39.0 to 29.0 instructions and 10.96 to 8.25 cycles, a
    `tak` call 47.33 to 37.33 and 13.1 to 11.0 (MLton 8.7 and 10.0 in
    M1's session): the cycles' target met, the instructions' not (26 and
    34). What `fib` keeps that variant 2 has not: the watermark's compare
    in the landing (2; M5), the room's check at the call (2, where the
    prototype compares at the callee's entry), the homes' reload and the
    result's move at the landing, and a body a little longer;
  * a call through a closure and its return 29 to 20 instructions of call
    machinery (target 15): the room, from the table, 4; the header 3 and
    `r14` 1; the landing 4; the closure's and the entry's loads 3;
  * the bootstrap: under callgrind its compiled code 7.268G to 6.520G
    instructions (−10.3%), its call machinery 14.9% of its instructions to
    10.5% (target 8%), the landings now the largest part of it (0.48G, the
    watermark's compare 0.14G of them); the whole 14.520G to 14.104G
    (−2.9%, target 6%) -- its collector does 0.34G more, the full
    collections falling elsewhere since a minor one promotes less;
  * HOL's kernel work 49.98G to 43.95G instructions (−12.1%; target 8%),
    and 25.4G to 21.7G cycles (−15%, the least of three);
  * MLton's seven programs of calls and closures, as `perf-cycles.sh`
    wraps them: `fib` −23.4%, `tak` −17.2%, `model-elimination` −11.6%,
    `logic` −9.5%, `tyan` −5.4%, `barnes-hut` −3.4%, `nucleic` −3.1%
    (target 10% each): the last four spend most of their time outside
    calls;
  * `--count` the same on every engine and at every tier (`check-jit`'s
    programs), the bootstrap's output the same. (The bootstrap's own count
    is not one to compare between runs: the compiler reads the processor's
    clock, and its count moves by thousands with the time it took.)

### M5. The watermark by a return barrier (S-M)

D4 B: the barrier's stub, armed by every minor collection and by a raise,
seen through by every walk.

**Targets:**

* a `fib` call at most 24 instructions, a `tak` call at most 32;
* the bootstrap and HOL's kernel work each at least 0.8% fewer
  instructions;
* the stub's runs counted by `--jit-stats`, and no more than the frames
  minor collections walk;
* `--gc-verify` holding the barrier to the watermark, `--gc-stress` green.

### M6. Arguments in registers (M, measured)

D5 B: a known call's arguments in the convention's registers, a closure
call's one argument, the entry from slots for the interpreter and the
driver.

**Targets:** a `fib` call at most 23.5 instructions (variant 4: 23.0);
kept if the bootstrap's instructions drop by at least 0.5%, otherwise
dropped and the measurement recorded here.

### M7. Returns the processor predicts (M, measured)

D3 B: `call`, `pop [r14-8]` at the entry and `push [r14-8]; ret` on
x86-64; `bl`, the link register stored at the entry and `ldr x30; ret` on
aarch64; a second entry for the driver and tail calls; `jmp` returns kept
behind a flag.

**Targets:** the instructions per call unchanged within one; a `fib` call
at most 7 cycles and a `tak` call at most 9 (variant 9: 6.2 and 8.0); kept
as the default if the bootstrap's and HOL's cycles drop by at least 1%
(the best of ten runs, interleaved), otherwise the flag's default is `jmp`
and the measurement is recorded here.

### M8. The allocation pointer in a register (M)

D7 B: the pointer in `rbp` (`x21`), the bytes from its progress, the
objects per run, `--gc-stress` through the limit.

**Targets:**

* the fast path at most 5 instructions before the header and the fields
  (12 today), and no counter written per object;
* the bootstrap at least 2% fewer instructions, HOL's kernel work at least
  2.5% fewer;
* the bytes and objects of `--count` unchanged on every engine and every
  program; `--gc-stress`, `--gc-verify` and `make test-heap` green.

### M9. Measure again: the owner's goal (S)

*Where we are* measured again: F1 with the real code beside the variants,
E9, the bootstrap, HOL's kernel work, tests/perf and MLton's set, against
MLton, Poly/ML and OCaml in one session; `runtime/register/README.md`
true; what is left moved to the plan that takes it.

**The targets, the owner's goal last:**

* **Beat MLton on calls:** a `fib` and a `tak` call in fewer cycles than
  MLton's (1.26 and 1.31 times at M1); tests/perf's `fib` and `tak`, which
  are calls and little else, in fewer cycles than MLton's build of them
  (1.36 and 1.35 at M1; 3.9 and 3.5 times on 2026-10-12, performance.md
  E1).
* **MLton's set:** the seven programs of calls and closures within 1.5
  times MLton's cycles (1.32 to 3.16 at M1; 2.8 to 4.2 times on 2026-10-12).
* **The whole programs:** the bootstrap within 1.5 times MLton's build in
  cycles (1.72 at M1, 2.46 on 2026-10-12); HOL's kernel work within 2.2
  times Poly/ML (2.98 at M1, 5.9 on 2026-10-12); what remains of each gap
  measured and named (the collector, the bytecode, inlining).
* **As fast as OCaml:** a `fib` and a `tak` call within 1.3 times OCaml's
  cycles, at most 22 and 31 instructions (variant 9: 21 and 30). That is
  the floor F1 measured under Rune's contract (1.27 and 1.29 times); what
  lies below it -- the count, the overflow checks, frames the collector
  reads -- is the owner's to trade, not this plan's.

### Why this order

* **The gate first**, because performance M6 and M7 change the baseline
  and could, in principle, make native frames unnecessary; F1 says they
  will not.
* **The body before the frames:** it is independent of them, cheap and
  low in risk, and the targets per call cannot be met without it.
* **The walk before the frames:** M3 moves every reader of frames in the
  shared runtime onto one function with nothing changed, so that M4
  changes the register VM's frames alone, in its own files.
* **The barrier, the arguments and predicted returns after M4**, each a
  small change on top of frames that work, each measured on its own; two
  of them are gated, since F1 and F2 cannot say whether they pay on whole
  programs.
* **The allocation pointer last**, because it needs the register M4 frees.

## Relation to the other plans

* **[performance.md](performance.md)**: this plan is its M9, and answers
  its D5 B and D6 C. It takes the faults of Track B's *The bytecode, and the
  JIT's code for a body*, which no milestone there takes (M2 here). Of
  performance M6, the fill's removal, the result in a register, counting
  per extended block and patched known calls carry over; its trampolines
  become the interpreter's return stub; the record made lean, the frames
  array grown with the stack and the room check with the poll are replaced
  by M4. Performance M7's pointer homes carry over unchanged (D6 A).
* **[jit.md](jit.md)**: D4 (the VM's frames, nothing of a program on the
  machine stack) holds -- the frames move within the VM's memory; D10 ("the
  tags are the stack map") holds; D11 (images in bytecode terms) holds;
  M10's item 7, arguments across known calls, is M6 here.
* **[garbage-collector-v2.md](garbage-collector-v2.md)**: its D9, the
  stack's watermark, becomes a base and, in M5, a return barrier.
* **[codegen.md](codegen.md)**: its D3's option A (`call` and `ret` for
  `runeopt`, measured and not built) is D1 B and D3 here, measured again
  (F1, F2). `runeopt` keeps its frames (performance D11 B).
* **[garbage-collector-v3.md](garbage-collector-v3.md)** holds what is left
  of the collector, 23% of the bootstrap's cycles, which this plan does not
  touch.
* **[whole-program-optimization.md](whole-program-optimization.md)** is
  where inlining and the bytecode's volume would go (*What else stands
  between Rune and OCaml*).
* **[hol4.md](hol4.md)**'s *What is left*, "the JIT's code": performance
  M5 to M7, and this plan.

## Risks

1. **The readers of frames in the shared runtime.** `vm->frames` and
   `vm->fp` are named on 135 lines in 24 files of `runtime/`; 90 of those
   lines, in 11 files, are the runtime `runevm-stack` and `runeopt` share
   with `runevm`. M3 moves them onto the walk with
   nothing changed, under the stack VM's and `runeopt`'s suites, before M4
   touches a frame.
2. **Images.** The format is kept on purpose, so that images still cross
   between every VM; the risk is in the conversion at save and restore.
   `make test-portability` carries images between the VMs, and `make
   test-register-jit` holds `--restore`, `Runtime.restore` and the emulated
   fork to the interpreter's output and counts.
3. **The debugger's frames.** It names frames by index today (its step's
   frame, its keys per frame, `stop_frame`); M3 names them by base. `make
   test-repl`, `test-dap` and `test-repl-protocol` cover it.
4. **The return barrier's corners** (M5): a raise past it, a tail call
   under it, a frame converted or written into an image, the debugger, an
   invalidation. Every walk goes through one function that sees through
   the barrier's word; `--gc-verify` checks the barrier at the watermark;
   `--gc-stress 1` arms it at every allocation.
5. **Predicted returns** (M7) leave the processor's stack of returns out
   of step after every raise, and HOL raises often; a process with a CET
   shadow stack would fault on them. Hence a gated milestone and a flag.
6. **The register budget.** M4 frees `rbp`, M8 takes it; arguments in
   registers (M6) use registers that are homes, so a call has a parallel
   move to make. aarch64 has registers to spare.
7. **Whole programs gain less than micro programs.** F1 measures `fib` and
   `tak`; F2 bounds what predicted returns can give a whole program; the
   estimates of *What else stands between Rune and OCaml* are estimates.
   M1 measures again before anything is built, and every milestone has
   targets on the bootstrap and HOL, not only per call.
8. **HOL's gap is partly the bytecode's.** Rune's bytecode executes more
   instructions on HOL than Poly/ML's machine code does (15.8G against
   11.4G), so this plan's target for HOL is 3 times Poly/ML, not parity;
   the rest is the middle end's.
9. **Two layouts of frames in one runtime.** The stack bytecode's array
   and the register bytecode's headers each have a walk, and a mistake in
   one shows on its VM alone. Both are in `make check`.
10. **The stack that moves.** The value stack grows by `realloc`. `r14` is
    reloaded after every call into C, as today; a return word is a code
    address and a header holds no address into the stack, so a move leaves
    every frame right.
11. **The count's price stays.** F1 puts it at 3 instructions a `fib`
    call; on whole programs it is 0.8% of cycles (performance.md E13), and
    performance D9 A keeps it. The owner's goal is met within it.

## Measuring

Where each number of this plan came from, and how to take it again. The
scripts, the prototype and every raw result are with the drafts
(`~/.cache/claude-rune-drafts/performance` on the machine it was written
on: `results/M9/`, `scripts/M9/`).

* **The machine:** a Xeon E5-1680 v3 (Haswell, one store port) under WSL2,
  shared with VS Code and other agents. Timed runs were pinned to a core
  of their own (`scripts/timed.sh`).
* **Per call:** `perf stat -e instructions:u,cycles:u` of a program at two
  run lengths; the difference divided by the calls between. Instructions:
  the median of the differences (they repeat to the instruction); cycles:
  the least at each length, then the difference.
* **By role:** callgrind with `--dump-instr=yes` over a VM that dumps its
  code with a role per machine instruction (performance.md's B1-jit-dump,
  performance M1's `--jit-dump`), the counts matched to the roles and
  patterns by script (`scripts/B1/cgjit.py`, `scripts/M9/f5patterns.py`;
  from M1 on the tree's `scripts/jit-dump.py --callgrind` and `--diff`,
  and `scripts/M9/f5patterns2.py`, `callcost.sh`).
* **The bootstrap:** until M1, `bin/rune.rbc` of `921af2cc` compiling its
  own sources with `--heap-size 67108864` (`scripts/B1/boot.sh`). From M1,
  the compiler of `db0fba57a` compiling its own sources, frozen with them
  and its built library in `results/M9/bootwl` so that it stays the same
  while the tree changes (`scripts/M9/boot.sh VM OUT`; 1.217G bytecode
  instructions); MLton's build is `bin/rune-mlton` on the same sources.
  The compile's output is the same on every VM, byte for byte.
* **HOL's kernel work:** `scripts/hol-kernel.sh` in a restored `hol.state`:
  of HOL-perf (built by `921af2cc`) until M1, of HOL-midM8 (built by
  performance M8's compiler, the instruction set of `db0fba57a`) from M1,
  run on the VM measured (`scripts/M9/hol.sh`, or the tree's script with
  `$RUNEVM` since M1). Poly/ML: HOL-poly.
* **MLton's set:** `scripts/perf-cycles.sh --mlton-bench`, MLton's own
  `benchmark/tests` and `tests/perf/mlton-bench.txt`.
* **Counts are the targets.** Cycles are indications, compared only within
  a session. A milestone that changes `--count` is a mistake: none here
  should.

**The experiments:**

| | What |
|---|---|
| F1 | the call by hand: `fib` and `tak`, nine frame designs with Rune's semantics, against OCaml, MLton, Poly/ML and tier 2, two sessions (`F1/src/calls.S`, `driver.c`, `run.sh`, `percall.py`) |
| F2 | branch misses of the bootstrap and HOL's kernel work at tier 2 |
| F3 | crossings between the interpreter and compiled code (`--jit-stats`) |
| F4 | frames walked per collection (`--gc-log`) |
| F5 | the body's faults by pattern, over performance.md E12's callgrind runs |
| F6 | finding a native frame's descriptor: three binary searches, at the bootstrap's sizes |

## References

Every DOI below was checked against its Crossref record with the drafts of
performance.md (`lit/crossref/`). How far each was read is in brackets; for
a record, what this plan says of it comes from its title and the notes that
cite it (`lit/calls.md`, `lit/exceptions.md`).

**Frames and stack maps**

* A. W. Appel, Z. Shao. Empirical and analytic study of stack versus heap
  cost for languages with closures. *JFP* 6(1), 1996, 47-74.
  10.1017/S095679680000157X [in part]
* A. Diwan, E. Moss, R. Hudson. Compiler support for garbage collection in
  a statically typed language. *PLDI '92*, 273-282. 10.1145/143095.143140
  [record]
* O. Agesen, D. Detlefs, J. E. B. Moss. Garbage collection and local
  variable type-precision and liveness in Java virtual machines. *PLDI
  '98*, 269-279. 10.1145/277650.277738 [record]
* J. M. Stichnoth, G.-Y. Lueh, M. Cierniak. Support for garbage collection
  at every instruction in a Java compiler. *PLDI '99*, 118-127.
  10.1145/301618.301652 [record]

**Exceptions**

* N. Ramsey, S. Peyton Jones. A single intermediate language that supports
  multiple implementations of exceptions. *PLDI '00*, 285-298.
  10.1145/349299.349337 [in part]

**The implementations' sources** (under `/home/ruud/reference`)

* MLton `b15e2d289`:
  `mlton/codegen/amd64-codegen/amd64-generate-transfers.fun`,
  `mlton/backend/insert-checks.fun`, `runtime/gc/stack.c`,
  `include/amd64-main.h`.
* OCaml 4.14.4 `2257629c20` and 5.5.1 `46e1c324fb`: `asmcomp/amd64/proc.ml`,
  `emit.mlp`, `runtime/caml/stack.h`.
* Poly/ML 5.9.2 `45575540`: `libpolyml/x86_dep.cpp`,
  `mlsource/MLCompiler/CodeTree/X86Code/`.
* Chez Scheme `e95a7efb`: `s/cpnanopass.ss`, `s/cmacros.ss`.
* GHC 9.14.1 `902339d332`: `compiler/GHC/Cmm/LayoutStack.hs`.
* Wasmtime `46c23a87da`: `cranelift/codegen/src/ir/user_stack_maps.rs`.
* OpenJDK `2365ecc5fd8`: `src/hotspot/share/runtime/stackWatermark.hpp`,
  `src/hotspot/cpu/x86/macroAssembler_x86.cpp`.
