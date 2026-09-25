# Performance plan: the compiler, `runevm` and native code

This plan covers the speed of what Rune runs:

* the compiler Rune ships, `bin/rune` (`bin/rune.rbc` on `runevm`), which
  `make check` spends most of its time in;
* the programs it compiles, run by `runevm` or translated to x86-64 by
  `runeopt` ([native.md](../native.md), [codegen.md](codegen.md)).

It says where the time goes and ranks the work that remains, from what is
cheap and safe to what is large. Numbers are from 2026-09-24, on the
`codegen` branch after its M15 (`913e9f0`), on a 16-CPU Xeon E5-1680 v3
(Haswell) under WSL2. Every measurement can be repeated with the recipes in
*Measuring*.

## Where we are

The largest workload is the compiler compiling itself (the bootstrap), with
MLton's build of the same compiler as the yardstick. CPU time, user and
system:

| The compiler compiling itself | CPU time | Against MLton |
|---|---:|---:|
| MLton's build of the compiler | 0.30 s | 1x |
| Native code (`runeopt`) | 2.5 s | 8x |
| `runevm` | 7.3 s | 24x |

All three write the same bytecode. The programs of `tests/perf`, in cycles,
against the same source compiled by MLton:

| Program | Native | `runevm` |
|---|---:|---:|
| `real_nbody` | 3.2x | 17x |
| `string_ops` | 6.9x | 21x |
| `fib` | 7.4x | 27x |
| `list_ops` | 10.5x | 36x |
| `tak` | 14.4x | 80x |
| `array_sieve` | 23x | 94x |
| `word_bits` | 31x | 157x |
| `intinf_fact` | (MLton hoists the repeated pure computation out of the loop) | |

So native code is about 8 to 11 times slower than MLton, and `runevm`
about 3 to 5 times slower again. The gap is not one thing. It has four
parts:

* **What the compiler emits:** half of all instructions are moves between
  slots, every call passes one boxed argument, and there is no optimisation
  pass at all.
* **The compiler's own algorithms and the library:** these are slow in
  every build, MLton's included.
* **The collector**, which re-copies long-lived data.
* **The value representation:** 16-byte tagged values, and constructors
  that box their argument.

## Where the time goes

**The bootstrap's bytecode** (850.7 million instructions, counted by a copy
of the interpreter with counters; see *Measuring*):

| Opcode | Share | Opcode | Share |
|---|---:|---|---:|
| `LOCAL` | 33.9% | `JUMPIFNOT` | 2.7% |
| `SETLOCAL` | 19.4% | `GLOBAL` | 2.7% |
| `SELECT` | 7.7% | `TUPLE` | 2.0% |
| `JUMP` | 5.1% | `DECON` | 1.6% |
| `JUMPIFNOTTAG` | 4.5% | `TAILCALL` | 1.5% |
| `PRIM` | 4.4% | `INT` | 1.3% |
| `ENV` | 3.2% | `CON0` | 0.9% |
| `CALL`, `RET` | 3.1% each | `CLOSURE` | 0.8% |

* **Moves** (a pair counts two instructions):
  * `SETLOCAL a; LOCAL a` (store, then load the same slot at once) happens
    99.7 million times, 23% of all instructions.
  * `LOCAL x; SETLOCAL y` (a copy between slots) happens 68.2 million
    times, 16%.
  * The two patterns overlap where a value is copied on at once.
  * `LOCAL; SELECT` and `SELECT; SETLOCAL` happen 65 and 64 million
    times.
* **Jumps:** 9.5 million jumps land on a `JUMP` and 12.1 million on a
  `RET`.
* **Calls:** 39.1 million. Setting every new frame's locals to unit is 291
  million stores, 7.5 per call and 34% on top of the instruction count. The
  9% of calls that enter a function of 20 or more locals make half of those
  stores.
* **Argument tuples:** of 17.2 million tuples, 12.5 million (72%) go
  straight into a `CALL` or `TAILCALL`, so a third of all calls pass a fresh
  tuple.

**The bootstrap's functions**, as a share of its instructions:

| Function | Share |
|---|---:|
| `StringMap` and `IntMap` (`find`, `insert`, `height`, `bal`, `mk`), with the `String.compare`, `Int.compare` and `Int.max` they call | about 38% |
| `List.find`, from `Lexer.lookupReserved` (a linear search of the reserved words for every identifier) | 9.6% |
| `Char.go`, the loop of `Char.contains`, from `Lexer.isSymbolic` | 2.7% |
| `Source.go`, `Source.search` (the line of a position) | 2.2% |
| `Codegen.fv` (the free variables of every function, again for every enclosing one) | 1.5% |

**Native code** (the bootstrap's user cycles, from `perf record` with every
bytecode instruction as a symbol):

| Where | Share |
|---|---:|
| The collector (`copy_obj` 19.8%, `collect_into` 6.6%) | 27% |
| Calls (CALL 7.0%, RET 6.6%, TAILCALL 4.2%, entries 1.5%) | 19% |
| SELECT | 9.4% |
| SETLOCAL and LOCAL | 9.7% |
| The tag test (JUMPIFNOTTAG 6.2%, JUMPIFNOT 1.6%) | 7.8% |
| Allocation in the templates | 6.1% |
| Primitives, inline and in C | about 6% |

**`runevm`** (the bootstrap):

| Where | Share |
|---|---:|
| The loop (`vm_loop`) | 81% |
| The collector | 10% |
| `vm_alloc` and `vm_alloc_fields` | 3.4% |
| Primitives | 3% |

**MLton's build of the compiler** (its profiler):

| Where | Share |
|---|---:|
| The collector | 22.5% |
| `Lexer.isSymbolic` | 8.7% |
| The maps | about 14% |
| `String.compare`'s `collate` | 4.6% |
| `Emit`'s bytes | 4% |

The compiler's own hot spots are hot in every build.

**The collector:** the bootstrap allocates 1.27 GB and collects 25 times.
Its live data grows steadily, to 205 MB at the end, so the collector copies
846 MB, most of it data that survived before and is copied again.

## Constraints for all items

* **The compiler's sources** stay inside the language Rune supports
  ([building.md](../building.md), rule 6).
* **All compiler builds emit identical bytecode**, and the bootstrap
  reaches its fixed point (`make check`, `make bootstrap`).
* **Changing the instruction set** means:
  * `vm/opcodes.def` or `vm/prims.def`, appended so that nothing is
    renumbered;
  * the interpreter's case;
  * the template in `src/opt/x64.sml` (and `fastPrim` for a primitive
    worth doing inline);
  * the stack effect in `src/opt/rbccheck.sml`;
  * `docs/bytecode.md`;
  * `tests/opt/every-opcode.rasm`.

  The `.rbc` version changes only when the layout does, in
  `src/isa/stack.sml`; the fingerprint of the instruction set, which the
  `.rbc` and images carry, changes by itself.
* **A change that moves `--count`** re-measures the budgets
  (`sh tests/perf/run-perf.sh --update`) and quotes old and new in the
  commit.
* **VM changes** also pass the ASan VM, `make test-stress`,
  `make test-windows` and `make test-portability`. Changes to the templates
  pass `make test-native-stress` and `make test-native-asan`.
* **The VM stays C99.** Compiler extensions need a portable fallback.
* **Traces are observable:** an uncaught exception and `Runtime.trace` show
  every frame that is not a tail call. Inlining and turning `CALL; RET`
  into `TAILCALL` change what programs print, so they need a decision
  first.
* **A code-generator change** is checked with `runeopt --check` over every
  test's bytecode as well: `runevm`'s loader does not check stack heights.

## The work, ranked

Ranked by what the owner asked on 2026-09-24:

* a change with a smaller blast radius or a higher gain goes first;
* each is weighed by the work to do it, the complexity it leaves behind
  (new invariants, new couplings between parts), and whether it will still
  matter once native code is as fast as MLton's.

"At parity" says one of three things:

* **stays** -- the change is as useful then;
* **subsumed** -- an optimising back end would do it anyway, so it pays only
  until then;
* **fades** -- the interpreter alone gains.

Gains are for the bootstrap unless stated:

* **measured** -- a trial of the change in a scratch copy, with identical
  output;
* **est.** -- reasoned from the profiles above, to within about half;
* **est. by review** -- a code review's own estimate that I have not checked
  against the profiles.

| # | Item | Gain | Blast radius | Work | Complexity left | At parity |
|---|---|---|---|---|---|---|
| 1 | The lexer's lookups | measured: 9.6% fewer instructions, native 1.07x | the lexer | S, ~15 lines | none | stays |
| 2 | The maps' inner loops | measured: 5.4% fewer instructions, 10% fewer bytes, native 1.09x | `src/util/ordmap.sml` | S, ~60 lines | none | subsumed in part |
| 3 | The file of a position, cached | measured: 2.4% fewer instructions | `source.sml`, `codegen.sml` | S, ~15 lines | none | stays |
| 4 | Aliases share a slot; slots reused | est. 10-15% fewer instructions and most unit stores; native less | `Codegen` | S, ~25 lines | two variables may share a slot | subsumed |
| 5 | Compares that return `order` | est. 4% fewer instructions | `prims.def` (appended), the Basis, `fastPrim` | S-M | one primitive per type | stays |
| 6 | The Basis's higher-order functions as local loops | est. 4-8% fewer instructions, 5-10% fewer bytes, every program | `lib/basis` | S, ~80 lines | none | subsumed |
| 7 | Jumps, returns and branches | est. 3-6% fewer instructions on `runevm`, 1% native | `Codegen` | S, ~75 lines | none | subsumed |
| 8 | No test on the last rule of an exhaustive match | est. 2-4% `runevm`, part of the tag test natively | `MatchComp` | S, ~30 lines | the exhaustiveness check becomes load-bearing | stays |
| 9 | No frame reload after a return | est. by review 2-4% native | `x64.sml` | S, ~20 lines | a return arrives with the callee's base | subsumed |
| 10 | Grow the heap without collecting twice | est. 1-3% | `vm/heap.c` | S, ~20 lines | none | stays |
| 11 | The compiler's other constant factors | est. 3-8% together | `Codegen`, `main.sml`, `Types`, `Emit` | S-M each | none | stays |
| 12 | Loops for self tail calls; closed closures allocated once | est. 3-6%, more on loops | `Codegen` | S-M, ~115 lines | a loop header per function | subsumed |
| 13 | A generational collector | est. native 15-20%, `runevm` 7% | `vm/heap.c`, a write barrier in 4 places and 2 templates | L, ~400 lines of C | a barrier for every future store into the heap | stays |
| 14 | Known calls with n arguments | est. native 15-25% | the compiler, 2 opcodes, the VM, `runeopt` | L, 400-600 lines | a second calling convention in 4 implementations | stays (MLton's own) |
| 15 | `runevm`'s loop | est. `runevm` 1.25-1.5x | `interp.c`, `vm.h` | M, ~200 lines | locals to write back before C | fades |
| 16 | The constructor tag in the tuple's header | est. by review 30% fewer objects, native 8-15% | the compiler, 2 opcodes, the VM, C that walks lists | M-L | two shapes of constructor object | stays |
| 17 | Decision trees and a tag switch | est. `runevm` 5-10%, native 2-5% | `MatchComp`, a variable-length opcode | L | a matching algorithm | stays |
| 18 | Values in registers across a run (M15's rest) | est. 3-5% native | every template | L | every operand in one of three places | subsumed |
| 19 | 8-byte values | est. by review 20-30% on the compiler | everything | XL | the Basis's ints, words and reals change | stays |

Items 1 to 3 together remove 16.5% of the bootstrap's instructions (850.7
to 710.6 million), with the output byte for byte the same. Items 1 and 2
alone make native code 1.17 times as fast. The trials changed about 60
lines. Items 1 to 12 are all S or
S-M, and none changes the bytecode format or the VM's layout. Together they
plausibly take a third to a half off the bootstrap on `runevm` and a
quarter off natively; profile again after them, since they change the
picture. Of the large items, 13 (the collector) touches only the runtime and
helps every program and both engines, so it goes before 14 (the calling
convention), which halves allocation and so also takes part of 13's gain.

### 1. The lexer's lookups

* **Now:**
  * `Lexer.lookupReserved` (`src/frontend/lexer.sml:156`) is
    `List.find (fn (k, _) => k = s)` over the reserved words, for every
    alphanumeric token and every part of a long identifier. That is 9.6% of
    the bootstrap's instructions.
  * `isSymbolic` (`lexer.sml:9`) is `Char.contains` over a string of 20
    characters, whose curried call builds closures. It is 8.7% of MLton's
    build.
  * `Fixity.lookup` (`src/frontend/fixity.sml:17`) scans a list for every
    identifier in an expression.
* **Change:**
  * the reserved words in a `StringMap` built once, or a `case` on the first
    character;
  * `isSymbolic` from a 256-entry vector;
  * the fixities in a map beside the list.
* **Measured** (the first two only): 850.7 to 769.0 million instructions,
  6.3% fewer native cycles, identical output.

### 2. The maps' inner loops

* **Now** (`src/util/ordmap.sml`):
  * `find` and `insert` recurse through the global function, allocating
    their argument tuple at every level;
  * `mk` calls `Int.max` through a closure with a tuple;
  * `bal` computes heights it already has;
  * `foldli`, `foldri` and `mapi` are curried and build a closure at every
    node, and they drive `unionWith`, so every `Env.plus`.
* **Change:** local loops that close over the key and the function, heights
  compared inline.
* **Measured** (`find`, `insert` and `mk` only, on top of item 1): 769.0 to
  727.8 million instructions, 1,202 to 1,084 MB allocated, 8.5% fewer
  native cycles, identical output.
* **At parity:** an optimiser like MLton's does part of this itself, but
  the maps are 14% of MLton's own profile.

### 3. The file of a position, cached

* **Now:** every position mark (`Translate` marks most expressions) looks
  its file up by name twice, in `Source.lineColOf` (defined twice in
  `source.sml`) and `Codegen.fileIdx`, each a `StringMap.find` that compares
  paths sharing their `lib/basis/` prefix.
* **Change:** one cached entry in each, since marks come file by file, and
  drop the duplicate definition.
* **Measured** (on top of items 1 and 2): 727.8 to 710.6 million
  instructions, identical output.

### 4. Aliases share a slot; slots are reused

* **Now:**
  * Every pattern variable is bound as `Let (x, Var v)`, and `Codegen`
    stores every `Let` in a new slot (`codegen.sml:164`). `fun f (a, b) =
    a + b` is ten instructions and five locals where six and three would
    do.
  * `newLocal` only counts up, so a function has a slot for every variable
    it ever binds. Every call sets them all to unit (`interp.c:144`, and a
    store each at a native entry).
* **Change:**
  * a `Let` of a local variable maps the new variable to the old slot and
    emits nothing (about 10 lines);
  * slots are allocated as a stack, the high-water mark being `nlocals`
    (about 15 lines).

  Both stay safe for the collector, since a reused slot always holds a
  valid value.
* **Gain:** `LOCAL x; SETLOCAL y` is 16% of all instructions, and the
  unit stores are 34% on top. The gain is mostly `runevm`'s: M15 already reads many
  of these locals where they are in native code.
* **Done** by the new back end (middle-end M4, the default from `-O1`): a
  variable bound to another is the other, a value used once stays on the
  stack, and locals are shared by linear scan. `fun f (a, b) = a + b` is
  six instructions and one local, where it was ten and five. With the jumps of item 7, `runevm`
  executes 17 to 28% fewer instructions on `tests/perf` (fib 18.5%,
  list_ops 27%, intinf_fact 28%) and the compiler 20 to 26% fewer
  (compiling itself: 806.6M to 595.1M), allocating the same.

### 5. Compares that return `order`

* **Now:** `String.compare` is the primitive and two comparisons, and it
  and `Int.compare` are functions. The maps call them through
  `Key.compare`, a closure call with a tuple each time: 5.7% of all
  instructions.
* **Change:** primitives `string_compare_order`, `int_compare`, and the
  char and word ones, returning `order`, appended to `prims.def`, with
  `int_compare` done inline. The Basis binds `compare` to them with `val`,
  so that `Translate` makes each use one `PRIM`.
* **Check first:** whether the alias survives the functor argument of
  `OrdMapFn`.

### 6. The Basis's higher-order functions as local loops

* **Now:** `map`, `app`, `foldl`, `foldr` (`lib/basis/pervasive.sml:57`),
  `List.find`, `filter`, `exists`, `all` and `ListPair` recurse through
  their curried global, so every element allocates a closure and makes two
  or three calls.
* **Change:** `fun map f l = let fun go [] = [] | go (x :: xs) = f x :: go
  xs in go l end`, keeping the order of evaluation.
* **Gain:** every program gains, not only the compiler. An optimiser that
  uncurries (item 14) subsumes it.
* **Done** (middle-end M8 and M10): the workers of M8 call themselves
  directly, with no closure made per element, and M10 copies such a
  function for a call that gives it a function of the top level, whose
  calls are then known, and inlined where small (`specialise`, docs/ir.md).
  Measured against the same compiler without it (`runevm --count`):
  array_sieve 14.8% fewer instructions, list_ops 7.7%, string_ops 2.5%, the
  compiler 0.4% -- whose calls mostly give closures, which are not
  specialised.

### 7. Jumps, returns and branches

* **Now:**
  * A function has one RET at its end, reached through chains of JUMPs.
  * `If (c, t, Fail)` jumps to a jump.
  * `andalso`, `orelse` and `not` build a bool and then test it
    (`translate.sml:183`).
* **Change:**
  * a RET in tail position;
  * jumps threaded, and a jump to the next instruction dropped;
  * conditions compiled as branches (`JUMPIF` exists and is never
    emitted).
* **At parity:** a CFG back end does all of this.
* **Done in part** by the new back end (middle-end M4): a return where the
  value is, a jump to the next block dropped, jumps to jumps threaded, a
  jump to a block that only returns made a return, and `JUMPIF` where the
  other branch follows. `andalso`, `orelse` and `not` as branches are the
  simplifier's (M7).

### 8. No test on the last rule of an exhaustive match

* **Now:** the last rule is tested like the others, then followed by the
  code of `raise Match` (`matchcomp.sml:161`), even where the match is
  exhaustive, which the elaborator already knows (`Exhaust`).
* **Change:** compile the last rule of an exhaustive match without its
  tests.
* **Complexity left:** DECON does not check a constructor's tag
  (`interp.c:96`), so this makes the soundness of `Exhaust` load-bearing,
  where today it only drives a warning.
* **At parity:** stays, since an untyped back end cannot find this again.
* **Done** (middle-end M9), without relying on `Exhaust`: a decision tree
  leaves the last constructor untested where its rules name every one, and
  `runevm --checked`, which the test suites run, makes `DECON` test the tag
  it now carries.

### 9. No frame reload after a return

* **Now:** the instruction after every CALL reloads the stack, the frames,
  `fp` (just stored by RET) and the frame's base (`x64.sml:318`), a
  dependent chain of about 15 cycles.
* **Change:** the return address `native_ret` points at a stub that
  restores `rbp` by the caller's known height. Image resumes keep a full
  reload.

### 10. Grow the heap without collecting twice

* **Now:** when the heap must grow, `vm_gc` collects into a space of the
  same size and then everything again into the larger one
  (`vm/heap.c:143`). The bootstrap's two growths are its largest
  collections.
* **Change:** decide from the survivors of the last collection, and collect
  once into the larger space.
* **Done:** `vm_gc` guesses the survivors from how they grew between the
  last two collections, and collects into the larger space at once where
  the guess says the heap must grow; a guess too low collects again, as
  before. The bootstrap from a 64 MB heap: 15 to 14 collections, with the
  same bytes and live data and `--count` unchanged; the time is within the
  noise of a run.

### 11. The compiler's other constant factors

Each is S or S-M and changes no output:

* **`Codegen.fv`** (`codegen.sml:19`): computed for every `Fn` over its
  whole body, so each node is walked once per enclosing function. Compute
  it once, bottom up (1.5% of instructions, plus its map work).
* **Dead data kept alive:** the slots of `compileWith` (`main.sml:125`)
  keep the tokens, the AST and the environment alive through code
  generation, and `Source.files` keeps every source text. Every collection
  copies them. Measure the live data by phase first.
* **`Types.prune`** allocates and writes on every call, even for a chain of
  one.
* **`Emit`** builds about 12 objects per bytecode instruction.

### 12. Loops for self tail calls; closed closures allocated once

* **Now:**
  * A function calling itself in tail position goes through GLOBAL or SELF,
    a TAILCALL, the checks and a new frame, and allocates its argument
    tuple, or its partial applications if it is curried, every time.
  * A `fn` with no free variables is allocated again every time it is
    evaluated.
* **Change:**
  * a label at the start of each function, and a self tail call becomes
    stores and a jump, with a tupled or curried parameter kept in locals;
  * a closed closure made once, into a global.
* **At parity:** item 14 subsumes the first.
* **Done** (middle-end M8): a self tail call is a jump back to the head of
  its function, its arguments stored into the head's parameters; a local
  group that captures nothing is lifted to the top level, its closure made
  once. See item 14 for what the two did with it.

### 13. A generational collector

* **Why:** the collector is 27% of native code and 10% of `runevm`, and
  most of what it copies is data it copied before.
* **Design:**
  * a nursery reached through `heap_from`, `heap_used` and `heap_size`, so
    that allocation in the templates (codegen M11) does not change;
  * survivors promoted into today's two spaces, collected as now when full;
  * large objects straight into the old space.
* **The write barrier** goes into `ref_set` and `array_update`
  (`prims.c`), SETENV (`interp.c`, `native_setenv`) and the two templates
  that do `:=` and `Array.update` inline; the spare `pad` byte of an object
  can hold a "remembered" bit.
* **Unchanged:**
  * images, since the heap is collected into one space before it is
    written;
  * `--count`, which counts what is allocated.
* **Needs:** `--gc-stress` then exercises the barrier too; `--stats` and
  `Runtime.stats` learn two kinds of collection.
* **Complexity left:** every future primitive that stores into an object
  must remember the barrier.
* **Before this:** item 10, and item 11's dead data, which cut the live
  data the collector copies.

### 14. Known calls with n arguments

* **Why:** every function takes one argument through a closure. A call to
  a known `fun` is GLOBAL (with its check), a TUPLE, a CALL (tag, kind and
  index checks, an indirect jump) and a prologue that takes the tuple
  apart. A curried call of three arguments is three calls and two closures.
* **Change:**
  * `Translate` makes each `fun` of k curried or n tupled arguments a worker
    of n parameters, and a wrapper for its uses as a value.
  * A full application of a known function becomes `CALLK f, n` or
    `TAILCALLK f, n`: the arguments become locals 0 to n-1, with no checks,
    and natively a direct jump.
  * It can be staged:
    1. closed top-level functions of one argument;
    2. tupled functions;
    3. curried ones;
    4. local functions that do not escape.
* **Blast radius:** `lambda`, `translate`, `codegen`, two opcodes with
  their four implementations, the loader and `Rbc`, the native entry (which
  sets locals from 1 on today), the resume points of images, tests and
  budgets.
* **At parity:** this is what MLton does. It is a step towards parity, not
  work an optimiser would make unnecessary.
* **Done** (middle-end M8), in Mid and the new back end rather than in
  `codegen`: `CALLK` and `TAILCALLK` in both bytecodes; workers and
  wrappers for tupled and curried functions of the top level; local
  functions that do not escape lambda-lifted. Against M7: tak 48% fewer
  instructions and almost no allocation, the other programs of `tests/perf`
  9 to 35% fewer instructions and half the bytes or less, compiles 14%
  fewer (docs/plans/middle-end.md, M8).

### 15. `runevm`'s loop

* **Now, on every instruction** (`vm/interp.c:18`):
  * `vm->pc` is stored and loaded again;
  * the trace flag is tested;
  * the frame is found from `vm->frames` and `vm->fp`;
  * a push loads and stores `vm->sp`;
  * a write of a `Value`'s tag may alias any field of the VM.
* **Change:**
  * pc, sp, the frame's base and the count in locals, written back before
    a primitive, an allocation or a raise;
  * computed goto under `__GNUC__`, with the switch as fallback;
  * tracing in a loop of its own;
  * the fast path of `vm_alloc` inline, without setting fields to unit that
    are written at once.
* **At parity:** fades once programs run natively, but it speeds up `make
  check` and every VM that has no native code (32-bit, PowerPC, Windows).
* **Done** (middle-end M6): the loop keeps the stack pointer, the frame, its
  base, the pc and the count in its own variables and gives them to the VM
  only around what reads them; each case reads its own operands; a push
  does not check, since the loader works out how deep each function's
  stack goes; computed goto under `__GNUC__`; tracing in a copy of its own.
  With `TEELOCAL`: the bootstrap's compile 41% fewer cycles (34.6G to
  20.5G) and 49% fewer machine instructions; fib 30%, tak 45%,
  intinf_fact 41%, string_ops 29%, list_ops 20% fewer cycles.

### 16. The constructor tag in the tuple's header

* **Now:** a constructor with an argument boxes it: a cons cell is a tuple
  of two fields (40 bytes) and a `K_CON` around it (24), and a map node
  112 bytes. A match reads the header, then the tuple.
* **Change:** a constructor whose argument is a tuple or record becomes one
  object of n fields. A binding of the whole argument copies it out, since
  tuples have no identity. A polymorphic argument stays boxed.
* **Blast radius:** the compiler (`coninfo` needs the arity), new opcodes,
  the C that walks lists (`prims.c`, the system layer).

### 17. Decision trees and a tag switch

* **Now:** a `case` over a datatype of many constructors tests them one at
  a time: the last arm of `Codegen.gen`'s `case` over 28 constructors runs
  27 tests.
* **Change:** decision trees in `MatchComp` from each type's constructors,
  and a `SWITCH` jump table.
* **Blast radius:** the table makes a variable-length instruction: a format
  change for the loader, `Rbc`, `RbcCheck`, the disassemblers, `Emit`, the
  interpreter and the templates.
* **Do items 8 and 12 first:** they are most of the gain for narrow types.
* **Done** (middle-end M9): Maranget's decision trees in `MatchComp` from
  `-O1`, and `SWITCH n` followed by a table of `n` `JUMP`s, which kept every
  instruction of fixed size. Against M8: intinf_fact 21.5% fewer
  instructions, list_ops 7.3%, the compiler compiling itself 7.6%.

### 18. Values in registers across a run

The rest of codegen's M15: an instruction's result stays in a register for
the next one. It takes part of LOCAL, SETLOCAL and SELECT (19% of native
code between them), for a change of every template. The part that was
built, a pushed local read where it is, is in [native.md](../native.md).

### 19. 8-byte values

Half the heap and half the collector's work.

* **Cost:**
  * `Int` and `Word` become 63 bits or overflow into boxes, and `Real` is
    boxed, which the language and the Basis suite see;
  * every primitive, the images, every budget and every template change.
* **Do item 16 first.**

What was established about the 16-byte `Value`, and holds meanwhile:

* **It is a constraint, not an accident** (`vm/vm.h`). The padding after
  the tag is written out, since the 32-bit System V ABI aligns an `int64_t`
  to 4. `--count`'s agreement across machines, the heap of an image, and
  64-bit arithmetic on every VM depend on it.
* **A 12-byte value would save 0.46%** of the heap (measured on
  `examples/nqueens.sml`), since a payload of fields is already a multiple
  of 16.
* **What a list cell costs is the boxing of item 16, not padding.**

## Measuring

* **Instructions and allocation:** `runevm --count` prints the instructions
  executed and the bytes and objects allocated. They depend on the program
  and its input alone, and `make perf-check` holds budgets on them
  (`tests/perf`).
* **Time:** `perf stat -e cycles:u,instructions:u`, the least of five runs,
  is steady where wall time is not.
  * Same-binary runs differ by up to 3%. A rebuild that changes nothing a
    program executes moves its cycles by up to 13%, from where the code
    lands, so only a change of instructions is real for `runevm`.
  * `:u` counts no kernel time. For anything that touches memory, also
    measure `perf stat -e task-clock` or `/usr/bin/time -f "%U %S %R"`:
    codegen's M12 was 5% in user cycles and 21% in CPU time.
* **Hardware events** have no names under WSL: `r0203:u` is
  `LD_BLOCKS.STORE_FORWARD`, `r0e08:u` completed DTLB walks.
* **Opcodes, pairs, primitives and instructions per function:** a
  throwaway copy of `vm/` whose `interp.c` includes a header of counters,
  called at the top of the loop and at each CALL, and dumped at exit (keep
  copies of the function names: `vm_exit` frees the program first).
* **Native code by bytecode instruction:**
  * `runeopt -S`, rename the labels `.Lp` and `.Le` to `Lp_` and `Le_`,
    assemble and link as `runeopt` does, and aggregate `perf record` over
    several runs (it is throttled to about 1,000 samples a second here).
  * perf sometimes gives a sample the function's symbol instead of the
    label's; count those as unattributed.
* **The compiler under MLton:** `mlton -profile time -output rune-prof
  build/rune.mlb` in a copy of the tree, then `mlprof`.
* **Time the bootstrap:**

  ```sh
  BOOT_SRCS="build/config.sml $(grep -v '^[[:space:]]*#' sources.txt | grep -v '^[[:space:]]*$') src/main/rune-main.sml"
  time bin/rune -o /tmp/x.rbc $BOOT_SRCS
  ```

## Done, dropped, or no longer relevant

* **Done before this plan's refresh:**
  * `OrdMap.unionWith` folds the small map into the large (41 s to 3.1 s).
  * `vm_push` and `instr_length` are inline, and codegen's `e656ead` put
    `vm_pop`, `vm_top` and the frame push back inline after M1 took them
    out.
  * Primitives bound with `val` are inlined by `Translate`
    ([basis.md](basis.md): 541.7 to 491.9 million instructions).
* **Done by codegen**, in native code:
  * the fused tag test (M13, `JUMPIFNOTTAG`, for `runevm` too: 967.9 to
    849.6 million instructions);
  * allocation inline (M11);
  * arithmetic and comparisons without `prim_table` (M5);
  * calls and returns (M10).

  For `runevm` the last three are what item 15 is for.
* **Stale:**
  * "`OrdMap` rebuilds `insert cmp` at every level": `find` and `insert`
    are tupled now, and what they cost is in item 2.
  * "`String.compare` makes three calls and three tuples": it is one
    primitive and two inline comparisons now; what is left is item 5.
  * The profile of 2026-09-18 (371 million instructions): the compiler has
    grown with the Basis since.
* **Measured and dropped** (2026-09-24):
  * **Huge pages for the heap** (`madvise`): page faults 132,000 to 3,300,
    time within noise, since zeroing the memory is the cost, not the
    faults.
  * **A default heap fill of 25%:** 4% less user time, but more system
    time than that.
  * **Removing store-forwarding stalls in the templates** (tags as 8-byte
    stores, values copied in two halves): 58 to 14 million blocked loads,
    no gain, since the processor was hiding them and the copies cost
    instructions.
  * **D3's native `call`/`ret`** (codegen M14): at most 0.6% of the
    bootstrap.
