# Roadmap: the middle-end

Rune translates the syntax tree almost straight into bytecode, with no
intermediate representation worth the name and no optimisation pass. This
roadmap plans what goes in between: the intermediate representations, the
passes on them, how the bytecode is described and generated, and the two
bytecodes the owner has decided on. It was written on 2026-09-24, on
branch `middle-end` from `b5ec8c8`.

What it rests on:
* a reading of the compiler and the VM;
* counts taken for it from the bootstrap and the programs of `tests/perf`,
  with a copy of the interpreter that counts (*Measuring*);
* the literature (*References*).

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done |
| M1 | The instruction set as one description | |
| M2 | Pass infrastructure | |
| M3 | Types, and Mid launched dark | |
| M4 | The new back end: Low and the stack target | |
| M5 | The register target and the first loop of `vm/new` | |
| M6 | `vm/portable`: frames and dispatch | |
| M7 | The simplifier and tree shaking | |
| M8 | Known calls and the calling convention | |
| M9 | Decision trees and `SWITCH` | |
| M10 | The inliner, contification and inline frames | |
| M11 | Representation | |
| M12 | Whole-program analyses | |

The order follows the owner's decisions of 2026-09-24 (*Decisions*): M5
comes right after M4 (D5). The owner decides what starts first.

## The request

The owner's brief, as written:

> - one of rune's weakest points is the lack of a middle-end in the compilers. the ast is translated almost directly to bytecode
> - we need a roadmap to introduce a series of intermediate representations, transformations and optimization to make rune emit best-in-class code. highest priority items on the roadmap are those that improve rune's overall architectures followed by middle-end stages that give the biggest bang for the buck, while keeping in mind the end goal
> - rune will be supporting both an incremental compiltion mode (not currently supported and not part of this roadmap, but keep it in mind) that will be focussed on quick compile times and a whole-program mode for generation production executables focussed on generating maximally performance production code.
> - part of this roadmap may include a (full) redesign of the bytecode. as rune is a research compiler no backwards compatibility is required
>   - you may consider both stack based and register based bytes code. research the trade-offs
>   - modifying the bytecode is currently one of the most fragile places as it touches many places. research is this can be engineered in a better way
> - in the future we may want to experiment with various combinations of intermediate representations, optimizations and even bytecode (e.g. to support lazy languages) and garbage collectors. ensure we are ready for this.

The owner's decisions while it was planned (2026-09-24):
* **Design around the split** of the owner's notes on a new VM:
  * `vm/portable` is today's VM, kept simple, for bootstrapping and unusual
    platforms;
  * `vm/new` is a state-of-the-art VM, with its own roadmap;
  * each has its own back end.
* **Rune will support both a stack and a register bytecode:**
  * the stack bytecode is `vm/portable`'s, and `runeopt` translates it;
  * the register bytecode is `vm/new`'s only.
* **After reading this roadmap**, the owner decided D1, D2, D3, D5, D6,
  D7, D9, D13 and D14. D8, D10, D11 and D12 are open. See *Decisions*.

| The brief asks | Answered in |
|---|---|
| a series of IRs, transformations and optimisations | *The architecture*, milestones M2-M4 and M7-M12 |
| architecture first, then the largest gains | *The milestones*, and why they are in that order |
| incremental and whole-program modes | *Constraints*, *Ready for, not built*, M12 |
| a redesign of the bytecode, stack or register | *Two bytecodes*, M5 |
| changing the bytecode made less fragile | *The instruction set as one description*, M1 |
| ready for other IRs, bytecodes (laziness) and collectors | *The architecture*, *Ready for, not built* |

## Where we are

### The compiler's middle

About 1,170 lines separate the elaborated syntax tree from the bytes of the
`.rbc`. None of them optimises anything.

```
AST ──Translate──► Lambda ──Codegen──► instruction lists ──Emit──► .rbc
      MatchComp     (untyped)           (untyped)
```

* **`Lambda`** (`src/core/lambda.sml:12`, 99 lines) is untyped:
  * variables are integer stamps from one counter
    (`src/elab/elaborate.sml:7`), split into locals (`Var`) and globals
    (`Global`);
  * functions are unary (`Fn`);
  * primitives are called by name (`Prim of string * lexp list`);
  * `Try`/`Fail` is how a match backtracks to its next rule
    (`lambda.sml:30`), which in effect is a join point with no parameters;
  * `Mark` carries positions.

  Nothing of the elaborator's types survives into it.
* **Match compilation** (`src/core/matchcomp.sml`, 179 lines) tries the
  rules one at a time (`compileMatch`, line 161):
  * a failed test jumps to the next rule, and nothing is shared between
    rules;
  * every rule tests the scrutinee's tag again;
  * the last rule is tested even where the match is exhaustive, which the
    elaborator knows (`src/elab/exhaust.sml:1-6`: "the match compiler still
    emits the Match/Bind tests").
* **Translation** (`src/core/translate.sml`, 428 lines):
  * structures are flattened into globals, and every functor application
    is a copy of its body, elaborated again;
  * a curried `fun` becomes nested `Fn`s, and a tupled one takes one tuple
    (`DFun`, line 345);
  * a primitive bound with `val` is applied directly (`applyPrim`,
    line 92);
  * records become tuples;
  * `andalso` and `orelse` build a bool, which is then tested (lines
    219-220);
  * the whole program, Basis Library included, becomes one term nested
    once per declaration (`transProgram`, line 426).
* **Code generation** (`src/backend/codegen.sml`, 340 lines):
  * **Closures:** flat closure conversion. `freeVars` (line 19) walks each
    function's whole body again for every function around it (line 263).
  * **Slots:** every `Let` gets a new slot (lines 136, 164), none is reused,
    and every slot is written at most once per activation.
  * **Tail calls** are found syntactically.
  * **One `RET` per function** (line 253), reached by jumps.
  * **One fused test**, `JUMPIFNOTTAG` (line 190), for a tag compared with a
    constant.
  * **The instructions** are untyped: `Op of int * int list` (line 6).
* **The pipeline is fixed** (`src/driver/main.sml:126-152`): no registry of
  passes, no optimisation levels, and the only dumps are `--dump-lambda`
  and `--dump-code`.
* **What `runeopt` sees:** it translates the `.rbc` an instruction at a
  time ([native.md](../native.md)). The `.rbc` is the only interface
  between the compiler and native code.

### What the bootstrap executes

The bootstrap is the compiler compiling itself, on `runevm`: 849.6 million
instructions, 1,265 MB allocated in 29.7 million objects. The shares below
come from the counts of *Measuring*, and the opcode mix is
[performance.md](performance.md)'s, taken again on this tree.

**Moves:**
* `LOCAL` is 33.9% of all instructions and `SETLOCAL` 19.4%.
* `SETLOCAL a; LOCAL a`, where `a` is read nowhere else, happens 74.0
  million times: 17.4% of all instructions. Another 25.5 million are
  followed by more reads, where a `TEE` would save one instruction each
  (3.0%).
* `LOCAL x; SETLOCAL y`, an alias copy, happens 68.1 million times (16.0%).
* Counted without overlap, **28.0% of all instructions are moves that a back
  end with liveness removes**. The programs of `tests/perf` have 15 to 33%
  of their own:

  | Program | Removable moves |
  |---|---:|
  | `fib` | 14.8% |
  | `real_nbody` | 21.9% |
  | `string_ops` | 21.9% |
  | `list_ops` | 23.2% |
  | `word_bits` | 26.7% |
  | `array_sieve` | 27.9% |
  | `intinf_fact` | 32.4% |
  | `tak` | 33.0% |
* **Unit stores:** setting every new frame's locals to unit costs 291.2
  million stores, 7.5 per call, 34.3% on top of the instruction count.
* **Jumps:** 21.6 million jumps (2.5%) land on a `JUMP` or a `RET`.
* **Results:** 24.9% of `CALL`s are followed by a `SETLOCAL` of their
  result.

**Calls:**
* There are 39.1 million calls: 26.4 million `CALL` and 12.7 million
  `TAILCALL`.
* **Most are known.** 90.2% come from call sites that only ever call one
  function. 66.4% take their closure from a `GLOBAL` or `SELF`. Of the 22.6
  million `GLOBAL` reads, 21.6 million are the function of a call.
* **A third pass a fresh tuple.** 31.9% of calls pass a tuple made just
  before by `TUPLE`, of 2 fields (70.5%), 3 (15.0%) or 4 (14.4%). These
  tuples are 41.9% of all objects allocated, about 580 MB.
* **Tupled callees:** 38.1% of calls enter one of 749 functions that begin
  by taking local 0 apart with `SELECT`s.
* **Curried calls:** 12.8% of calls call the result of a call (`f a b`).
  Another 12.8% enter one of 259 functions whose whole body is `CLOSURE;
  RET`, the partial applications of curried functions.
* **Loops:** 21.3% of all calls, 65% of the tail calls, are a function
  calling itself in tail position: loops written as recursion. Another 5.0%
  are self calls that are not tail calls.
* **Small callees:** 33.9% of calls enter a function of at most 16
  instructions, 61.8% one of at most 32, and 47.5% a function that calls
  nothing.

**Allocation:**
* By kind: tuples 58.1% of objects (66.5% of bytes), closures 22.9%
  (22.5%), constructors with an argument 16.5% (9.3%), strings 2.1%, refs
  0.5%.
* **Closures:** `CLOSURE` runs 6.8 million times. 11.5% of those closures
  have no free variable and could be made once.
* **Argument tuples in the numeric programs** are almost everything
  allocated:

  | Program | Fresh argument tuples, of all objects |
  |---|---:|
  | `tak` | 99.7% |
  | `word_bits` | 99.5% |
  | `real_nbody` | 98.6% |
  | `array_sieve` | 91.3% |
  | `intinf_fact` | 38.7% |
  | `list_ops` | 23.3% |
  | `string_ops` | 11.7% |

**Matching:**
* 38.3 million tag tests (`JUMPIFNOTTAG`), of which 52.7% fail.
* A scrutinee is tested once in 56.7% of matches, twice in 38.4%, and three
  or more times in 4.9%: 1.66 tests on average.
* 15.2 million tests (1.8% of all instructions) are the second or a later
  test of the same value.
* 10.5 million tests (27.4%) belong to a last rule and fail only into
  `Match` or `Bind`. With the `LOCAL` before each, they are about 2.5% of
  all instructions, and half the tag tests of `list_ops` and `string_ops`.
* The hottest is `List.find`'s. It tests its list for `nil`, fails, jumps
  to a jump, and tests the list again for `::`, a test that never fails.

**Other counts:**
* **Exceptions:** the bootstrap installs 34,991 handlers and raises
  nothing.
* **Equality:** 68.3% of the 8.2 million polymorphic equalities (`poly_eq`)
  compare two values that are not pointers.

**Dead code:**
* **In the programs:** 89% of the code of `tak` is in functions that are
  never called, 79% of `list_ops`', and 82% of `examples/hello.sml`'s. Most
  of it is the Basis Library, which is compiled whole into every program
  that names it. In the compiler itself the share is 35%.
* **In the compile time:** that dead code is paid for at every compile.

**The compiler's own time**, in instructions on `runevm`:

| Phase | Bootstrap | Share | `compile-sigs` | Share |
|---|---:|---:|---:|---:|
| Lexing | 192.6M | 22.7% | 68.6M | 26.0% |
| Parsing | 67.4M | 7.9% | 20.8M | 7.9% |
| Elaboration | 240.2M | 28.3% | 95.2M | 36.1% |
| Translation | 31.6M | 3.7% | 9.4M | 3.6% |
| Code generation | 156.0M | 18.4% | 38.6M | 14.6% |
| Emission | 99.8M | 11.7% | 23.5M | 8.9% |

* **The back end today** (translation, code generation, emission) is a
  third of a compile. A middle-end that costs as much again would make
  compiles about a third slower before its own gains are counted.
* **Lexing** is item 1 of [performance.md](performance.md): the linear
  search of the reserved words.
* **`compile-hello`** takes 7.3 million instructions. About 3.3 million of
  them fall outside the phases: start-up, reading the Basis Library's
  `MANIFEST` and choosing its files.

### The instruction set

`vm/opcodes.def` (35 opcodes) and `vm/prims.def` (292 primitives) call
themselves the single source of truth. They hold much less than that:
* **What they give:** each opcode's name, its number (its place in the
  file) and how many operands it takes. The operand letters are thrown
  away. Each primitive gives its name and arity.
* **What is generated:** `scripts/gen-opcodes.sh`, two awk programs, writes
  `vm/opcodes.h`, `vm/prims_table.h`, `src/backend/opcodes.sml` and
  `src/backend/prims.sml`.

Everything else about an instruction is written by hand, about 1,150
lines of per-opcode code in some 15 files:

| Where | What it knows about each opcode |
|---|---|
| `vm/interp.c` | what it does, and 12 fatal messages |
| `vm/loader.c:237-265` | the range of each operand, and which operands are jump targets |
| `src/opt/rbc.sml` | the same validation again, with the same messages |
| `src/opt/rbccheck.sml:60-83` | the stack effect of each opcode (the only place one is written down), the ends of blocks, the jumps |
| `vm/native.c` | about 100 lines copied from `interp.c` |
| `src/opt/x64.sml` | a template for each; `endsRun` (line 38), `reads`, the fatal codes, `imagePrim` by name (line 299), 56 primitives inline (`fastPrim`) |
| `src/backend/codegen.sml`, `emit.sml` | about 46 places that emit instructions; `instrSize` |
| `docs/bytecode.md` | the prose; `make check-docs` checks only that each name is mentioned |
| `tests/opt/rbcasm.awk` | a third reader of the `.def` files and a third writer of `.rbc` |
| `tests/opt/run-opt-tests.sh`, `tests/vm/run-vm-tests.sh` | opcode numbers written as octal bytes |

What makes that fragile:
* **Six parsers.** Six ad-hoc awk and grep programs read the `.def` files.
* **Nine version numbers.** The `.rbc` version, `2`, is written by hand in
  nine places, among them `src/backend/emit.sml:10`, `vm/loader.c:99`, and
  `src/opt/rbc.sml` twice.
* **Silent defaults.** A new opcode without a stack effect is (0, 0) to
  `RbcCheck`. Without a validation case, it gets the loader's default.
  Nothing fails until something runs.
* **No instruction-set version.** An `.rbc` or an image records none, so a
  stale file runs with the wrong meaning. That is why opcodes and
  primitives may only be appended.
* **Primitives own the stack.** They read their arguments off the VM stack
  and pop them themselves (`vm/prims.c:13`), which is also how they stay
  safe across a collection. Their arity is written again by hand in 274
  places in `prims.c`.

### The collector's boundary

A different copying collector with the same object layout could replace
`vm/heap.c`: allocation goes through `vm_alloc` and its friends. Anything
more ambitious meets these:
* **Roots** are listed inline twice (`vm/heap.c:107-115`, and again in
  `heap_relocate`).
* **No write barrier.** Stores into the heap sit in `interp.c` (`SETENV`),
  `native.c`, seven places in `prims.c` (`ref_set`, `array_update`, ...) and
  two templates of `x64.sml`.
* **The templates bake in the layout:** the 16-byte `Value`, the object
  header and the bump allocator.
* **No stack maps.** Every value carries its tag, so the collector needs
  none; a collector for untagged or unboxed values would.

## What the optimiser must preserve

* **The order of evaluation:** left to right, and so which exception a
  program raises first.
* **The exceptions of arithmetic:** an unused `x + y` can still raise
  `Overflow` and `Div`, so it is not dead code.
* **Equality:** `poly_eq` compares refs and arrays by identity, and
  structurally otherwise.
* **Where `Match` and `Bind` are raised.**
* **The positions a program can see.** Only the positions of `CALL`,
  `TAILCALL`, `PRIM`, `RAISE` and a fatal error's pc are observable, in
  traces and messages. `make check-positions` checks that every other
  position names a real line.
* **The frames of a trace.** An uncaught exception and `Runtime.trace` show
  every frame that is not a tail call (`tests/lang/rt.trace_frames.sml`).
  Inlining, contification and new tail calls change that; D7 decides what
  a trace promises.

## Constraints

* **One output from five builds.** The compiler builds with MLton, SML/NJ
  in 64 and 32 bits, Poly/ML and itself, and all five write the same
  bytecode. The bootstrap reaches its fixed point. So:
  * **Integers:** a 32-bit SML/NJ `int` has 31 bits. Constants are folded
    in `IntInf` at the target's precision, and products in heuristics
    (size times count) are capped.
  * **Reals** are never folded, and never used in heuristics. The hosts
    print and round them differently, which is why they are passed through
    as text today.
  * **Iteration:** only ordered maps and ordered worklists.
  * **Names:** stamps come from the one counter. A pass that copies code
    renames what it copies, since `Codegen` assumes every stamp is bound
    once.
* **The compiler's own sources** stay inside the language Rune supports
  ([building.md](../building.md), rule 6).
* **Budgets.**
  * `--count`'s instruction budgets belong to a bytecode: each target has
    its own.
  * Bytes and objects allocated are fixed before the program is split
    into targets, so they are the same on every VM and check one against
    the other.
* **Native code.** `runeopt` keeps its contract ([native.md](../native.md)):
  a template per instruction, and `--count` equal to `runevm`'s.
* **The VM stays C99.**
* **Compile time has budgets per optimisation level** (`compile-hello`,
  `compile-sigs`, the bootstrap). The compiler may grow from 6,500 lines
  to 15,000 or more, and the shipped compiler runs on `runevm`.
* **`DECON` does not check its tag** (`vm/interp.c:96`). Once the
  optimiser relies on exhaustiveness, a VM mode that checks it stays
  available (D14).

## The architecture

```
          front ends (SML today; others later)
                      │
     AST ──Translate, MatchComp──► Lambda   typed
                      │
                      ▼
                     Mid   typed ANF with join points, n-ary functions,
                      │    a top level of definitions, Handle regions
                      │    ◄── simplifier, inliner, contification,
                      │        known calls, decision trees, representation
                      ▼
               closure conversion ──► Mid, closed
                      │
                      ▼
                     Low   SSA with block parameters, exceptional edges,
                      │    explicit Alloc, Store, Safepoint; liveness
             ┌────────┴─────────┐
             ▼                  ▼
      stack target        register target
      out of SSA,         register allocation
      slots, stackify     (linear scan)
             │                  │
             ▼                  ▼
     .rbc for vm/portable   bytecode for vm/new
     (runevm, runeopt)      (and its JIT, later)
```

| IR | Built by | Shape | Why it is there |
|---|---|---|---|
| `Lambda` | Translate, MatchComp | as today, with the elaborator's types on it (M3) | the front ends' target, so a new front end writes only this |
| Mid | from `Lambda` | explicitly typed ANF, join points, n-ary functions, a list of top-level definitions | where the functional optimisations happen |
| Mid, closed | closure conversion | Mid in which no function has a free variable, typed by representations | the boundary between functions and code |
| Low | from closed Mid | SSA with block parameters, per function, typed by representations | liveness, stack maps, both targets |

**Mid** (D1):
* **Atoms.** Every argument of a call, a primitive or a constructor is a
  variable or a constant, and the ML datatype says so, so that breaking
  this rule fails the compiler's build rather than its lint.
* **Join points.** `letjoin j (x1 .. xn) = e in body` binds a local label
  that `body` jumps to, only in tail position, and that no function
  captures.
  * `Try`/`Fail` becomes a join point without parameters.
  * The bodies of a decision tree's rules become join points with them.
* **Functions** take n arguments. A curried or tupled `fun` becomes a
  worker and a wrapper (D9).
* **The top level** is an ordered list of definitions (a global function, a
  global value, an effect), not one term nested once per declaration. That
  gives:
  * known global functions;
  * static closures;
  * tree shaking;
  * a unit for incremental compilation;
  * no recursion as deep as the program is long.
* **Exceptions:** `Handle` stays a structured region, which the VM's
  handler stack implements directly. A raise to a handler of the same
  function becomes a jump in the simplifier.
* **Positions** stay on the nodes that can fail or call. Inlined code keeps
  the position of its source and records where it was inlined (D7).
* **A lint** checks every invariant after every pass (M2), types included
  (M3).

**Low** (D2):
* **Functions of blocks.** A function is blocks with parameters (SSA as in
  Kelsey 1995). Join points become blocks, and a handled region's raises
  become exceptional edges into its handler block.
* **Explicit operations:** `Alloc`, `Store` into the heap, `Safepoint`,
  calls and returns. A collector's barrier is a pass that rewrites
  `Store`, chosen by the target and the collector.
* **Liveness** gives each target what it needs: slots and stackification
  for the stack bytecode, registers for the register bytecode, and stack
  maps at every place a collection can happen.

**Types** (D3, decided: typed IRs). The IRs are typed, and after every pass a
lint checks the types of what it made, as GHC's Core Lint does. The owner's
reason: this is essential for catching the optimiser's bugs.
* **`Lambda`** carries the elaborator's types. The elaborator records:
  * the type scheme of every binder;
  * the instance at every use of a polymorphic variable;
  * every datatype and exception.

  Translate and MatchComp carry them over. Today the elaborator computes
  these and throws them away (`VBuiltin` alone keeps one).
* **Mid** is explicitly typed in the manner of System F, as FLINT and GHC
  Core are:
  * type abstraction and application are written out, so the lint checks
    any pass's output without inferring anything;
  * a pass that substitutes values substitutes types too, which is what
    keeps inlined code well typed.
* **After closure conversion** the types become representations: a value,
  a pointer, an immediate, later an unboxed int or real. Closed Mid and Low
  are checked against those. Typing closures themselves would need
  existential types, and is left out.
* **The snags** to settle in M3:
  * **Mutable types.** The elaborator's types are mutable unification
    variables, final only after `Elaborate.finish`, so they are copied out
    resolved.
  * **Unresolved variables.** A type variable that is never generalised or
    resolved gets a default.
  * **Ascription.** It can give a value a less polymorphic type with no
    coercion (`SigMatch.mergeInfo` keeps the stamp), so Mid needs an
    explicit instance or coercion there.
  * **What is already done:** functors are elaborated anew at every
    application, so modules are monomorphic already and only the core
    language's polymorphism is left; overloading is resolved per top-level
    declaration.
* **Primitives:** each is typed where the Basis Library binds it
  (`_prim "name" : ty`), and again in the DSL (M1), where `prims.def` has
  it only as documentation today. The lint checks that the two agree.

**The target record** is what the middle end asks of a target:
* the precision of `int`, which constant folding needs;
* the most arguments a known call may pass;
* whether `SWITCH` exists;
* the layout of values;
* whether stores need barriers and loops need safepoints;
* whether the target is a stack or a register machine.

## Two bytecodes

The owner has decided: a stack bytecode for `vm/portable` and a register
bytecode for `vm/new`, both made from Low.

**What the literature says.**
* **Shi et al.** translated the JVM's stack code into register code and
  propagated copies (Shi, Gregg, Beatty and Ertl 2005; Shi, Casey, Ertl and
  Gregg 2008).
  * The register code executed about 47% fewer VM instructions and was
    about 25% larger.
  * With a `switch` it ran in about a third less time (a speedup of 1.48 in
    2008).
  * The better the dispatch, the smaller the gain: 26.5% less time with
    threaded code in 2005, and a speedup of 1.15 with inline threading in
    2008.
* **Lua 5.0** moved from a stack machine to registers (Ierusalimschy et
  al. 2005): pushing and popping is expensive where every push copies a
  tagged value, as it does with Rune's 16-byte values. Its simplest loop
  ran more than twice as fast.
* **WebAssembly** chose a structured stack machine for the opposite
  reasons (Haas et al. 2017): smaller code, and validation and translation
  to SSA in one pass.
* **An accumulator** sits between the two. V8's Ignition is a register
  machine with one (McIlroy 2016), and OCaml's bytecode, the ZINC machine
  (Leroy 1990), is a stack machine with one.

The expected gain here is the literature's. M5 measures Rune's own.

**Rune's numbers change the picture for the stack bytecode.** Half of
today's instructions are `LOCAL` and `SETLOCAL`. The counts above show
that 28% of all instructions are moves a stack back end with liveness
removes by itself. Much of what a register form would save, M4 saves on the
stack. So `vm/portable` keeps a stack machine and gains only what pays
there:
* `TEELOCAL`, a store that keeps its value;
* `CALLK` and `TAILCALLK`, calls to known functions with n arguments;
* `SWITCH`, a jump table on a tag.

**The register bytecode** (for `vm/new`):
* **Frames shaped like Lua's.** Today's `CALL` already starts the callee's
  frame at the slot of the closure it calls, and `RET` leaves the result
  there (`vm/interp.c:127-160`), so a call is a window of registers:
  closure, then arguments.
* **Windows.** Tuples, closures and the arguments of primitives come from
  consecutive registers.
* **Primitives.** `vm/new` needs its own convention for them: arguments by
  pointer or by window, since today's primitives read and pop the stack.
* **Collection.** At every place a collection can happen, either `sp`
  covers exactly the live registers or a per-pc stack map says which are
  live. A register that no longer holds a live value may still hold a
  pointer that a collection did not update. Liveness from Low gives the
  maps.
* **Images:** its own resume points.
* **Counts:** its own `--count` budgets.

The pitfalls a design review found in running register code on today's
runtime:
* stale registers at a collection (above);
* a pointer to the registers kept across a call into C that moves the
  stack;
* the paths of a raise, which change the frame;
* values forwarded across a join, which must not be;
* a `TAILCALL` whose argument is in local 0, which must be read before it
  is overwritten.

**Who owns what:** this roadmap owns the register back end and the first
loop that runs its code (M5). The `vm/new` roadmap owns the VM beyond that.
`runeopt` keeps translating the stack bytecode.

## The instruction set as one description

The brief asks whether changing the bytecode can be engineered better. It
can: describe each instruction once, in full, what it does included, and
generate everything else from that.

**A DSL in Standard ML** (D6, decided):
* **What it is:** an instruction set is an SML program. Each instruction is
  a value giving what is listed below and its body, written in a small
  language of the DSL.
* **The generator** is a program of its own, built from its own list of
  sources as `runedoc` and `runeopt` are. It reads the descriptions and
  writes C and SML.
* **Why SML:**
  * a missing field or an operand of the wrong kind stops the description
    compiling;
  * it is the compiler's own language, checked by the same five builds.
* **`vm/portable` still builds with a C compiler alone,** which is what it
  is for. So the generated C and SML are committed, and `make check`
  fails when they are stale, as it does for `docs/generated`. The
  generator runs on any host, or on Rune itself.

**The description:**
* **Several instruction sets.** One description per bytecode from the
  start: M1 writes the stack one, and M5 adds the register one.
* **Each instruction** gives:
  * **operands** by kind: constant, immediate, tag, local, environment
    slot, global, function, label, primitive, count, built-in exception,
    table;
  * **its stack effect:** a number, an operand, or a primitive's arity;
  * **flags:** branches, ends a counted run, calls C, may collect, may
    raise, reads its operand in place (`reads`), is a place an image
    resumes at;
  * **its body:** what it does, in the DSL's language. That language is
    small and typed, and just enough for these instructions: operands and
    stack slots (or registers) read and written, tags checked, objects
    allocated, runtime helpers called, fatal errors, control transfer. Its
    C is C99.
* **One version**, plus a fingerprint of the whole description,
  written into every `.rbc` and every image. A stale file is refused, and
  the rule that opcodes and primitives are only appended goes away.
* **The primitives** are described in the same DSL, each with its type
  and its effects: pure, reads the heap, writes it, allocates, may raise,
  does I/O, touches images, done inline. The default is the most
  conservative, since a primitive wrongly called pure is a
  miscompilation.

**Generated from it:**
* **The interpreter:** the cases of `interp.c`, and the slow paths
  `native.c` shares with them, from the bodies. The copy between the two
  goes away.
* **Tables:** the C tables and an X-macro list of opcodes.
* **An instruction datatype:** an SML `datatype 'l instr` with encode,
  decode, length, stack effect, flags and `toString`. It replaces
  `Codegen.item`, so that the number and kinds of operands are checked when
  the compiler is built.
* **The validators:** both the loader's and `Rbc`'s, with their messages.
* **What `runeopt` needs:** `RbcCheck`'s effects, block ends and jumps;
  both disassemblers; `Emit.instrSize`; `x64.sml`'s `endsRun` and resume
  points; and `rbcasm.awk`, or its replacement.
* **The documentation:** the table of `docs/bytecode.md`, checked rather
  than grepped, and the check that `every-opcode.rasm` runs every opcode.

**What stays written by hand:**
* **The runtime:** the collector and the primitives' C bodies.
* **`runeopt`'s x86-64 templates.** They are written over the generated
  datatype, and MLton's build treats a non-exhaustive match as an error,
  so an instruction without a template fails the build. Generating them
  from the bodies is a later option.

**Without the DSL:** the octal fixtures in the test scripts become `.rasm`
listings.

**For `vm/new`:** its register instruction set is a second description in
the same DSL. The same bodies can later give the stencils of a
copy-and-patch JIT (Xu and Kjolstad 2021), as CPython already generates
its interpreter from one definition of its instructions.

## Decisions

Each gives the options, what favours each, and the recommendation it was
written with. The owner decided on 2026-09-24:

| Decision | Chosen |
|---|---|
| D1. The shape of Mid | A: ANF with join points |
| D2. The shape of Low | A: SSA with block parameters |
| D3. Types in the IRs | B: typed IRs now |
| D4. The bytecodes | stack for `vm/portable`, register for `vm/new` |
| D5. When the register target comes | A: right after M4 |
| D6. How the instruction set is described | B: a DSL in Standard ML |
| D7. Traces under optimisation | B: inline frames in the line table |
| D8. Optimisation levels | open |
| D9. The calling convention | A for now, B in M12 |
| D10. The old code generator | open |
| D11. The items of performance.md | open |
| D12. The precision of `int` per target | open |
| D13. `runeopt`'s long-term role | A now, perhaps B later |
| D14. Exhaustiveness | B |

### D1. The shape of Mid

**Decided: A**, ANF with join points.

* **A. ANF with join points** (Flanagan et al. 1993; Maurer et al. 2017).
  **Recommended.**
  * Rune already has join points: `Try`/`Fail` is one without parameters,
    and matching needs them with parameters.
  * The VM keeps a handler stack. A structured `Handle` maps onto
    `PUSHHANDLER`/`POPHANDLER` directly.
  * Compile time is paid on `runevm`. CPS names a continuation at every
    call that is not a tail call: more nodes and more allocation, in a
    compiler that already allocates 1.3 GB to compile itself.
  * Traces are defined by calls that are not tail calls, which stay
    syntactic in direct style.
  * A later Haskell front end would find GHC Core's shape: let-bound
    thunks, join points, strictness analysis in direct style.
  * Dumps read like the source.
* **B. CPS with second-class continuations** (Kennedy 2007; Flambda 2).
  * Kennedy's case: inlining is substitution, shrinking runs in linear
    time, while ANF must be normalised again after inlining; and ANF needs
    join points for conditionals anyway, which are continuations under
    another name.
  * Contification, case-of-case and jumps to handlers fall out of the
    representation.
  * Handlers become continuation arguments, which this VM's handler stack
    would have to undo.
  * In ANF these come from explicit passes: contification by dominators
    (Fluet and Weeks 2001), case-of-case with join points (Maurer et al.),
    and a raise to a local handler turned into a jump.
* Maurer et al. added join points to GHC's direct-style Core in answer to
  Kennedy, and know "of no optimizing transformation that is accessible to
  a CPS compiler but not to a direct-style one". Cong et al. (2019) take
  the question up again.

### D2. The shape of Low

**Decided: A**, SSA with block parameters.

* **A. SSA with block parameters.** **Recommended.** Join points become
  blocks, and MLton does its whole-program work on the same shape. It
  serves a register allocator, and out-of-SSA plus stackification serves
  the stack.
* **B. A plain control-flow graph of mutable temporaries.** Simpler to
  build, weaker for analyses.

### D3. Types in the IRs

**Decided: B**, typed IRs now, against the recommendation: a type-checking
lint is essential for catching bugs. *The architecture* says how, and M3
does it.

* **A. Untyped, with representations on variables and a side table of
  type schemes.** **Recommended.**
  * Everything up to flattened constructors needs only:
    * a datatype's constructors (`coninfo.siblings`, already there);
    * the shape of a constructor's argument, added where the datatype is
      elaborated;
    * the type at an equality, already in `VBuiltin`.
  * The table keeps monomorphisation and unboxing possible for `vm/new`.
* **B. A typed IR now**, as FLINT or GHC Core. A type-checking lint would
  catch more bugs. But the elaborator's types are mutable unification
  variables, and carrying types through inlining needs substitution
  everywhere.

### D4. The bytecodes (decided)

Decided by the owner on 2026-09-24: stack for `vm/portable`, register for
`vm/new`, both from Low. See *Two bytecodes*.

### D5. When the register target comes

**Decided: A**, right after M4, as M5.

* **A. Right after M4**, as M5. **Recommended.**
  * An interface with one implementation is untested. A second, very
    different target shows what Low and the target record got wrong before
    seven milestones rely on them.
  * `CALLK` and `SWITCH` are then designed for both bytecodes at once.
  * `vm/new`'s roadmap gets its bytecode and a first loop early, and can
    proceed beside this one.
  * The cost: every later milestone that adds an instruction adds it
    twice. M1 makes that cheap.
* **B. After M9 or M11**, when the stack bytecode has everything and the
  register one can start complete.

### D6. How the instruction set is described

**Decided: B**, a DSL in Standard ML, for both bytecodes from M1.
*The instruction set as one description* says what it holds and makes.

* **A. A richer `.def` with generators** (M1), for both bytecodes, with
  the instructions' bodies written by hand. Recommended at first.
* **B. A DSL with the instructions' bodies**, as CPython's `bytecodes.c`.
  Recommended at first for `vm/new` only, when it has a JIT to feed.

### D7. Traces under optimisation

**Decided: B**, inline frames in the line table (M10).

* **A. Exact.** No inlining that removes a frame, and no new tail calls.
* **B. Inline frames in the line table.** **Recommended.**
  * Each pc of inlined code records where it was inlined, so a trace shows
    the frames it would have shown.
  * Contification and new tail calls may still remove frames.
  * Tests of traces run at a fixed level, or are updated.
* **C. Best effort**, with no promise.

### D8. Optimisation levels

* **`-O0`:** the old `Codegen` until M10 (D10), then the new back end with
  no optimisation.
* **`-O1`:** the default, cheap passes only.
* **`-O2`:** whole-program analyses.
* The owner decides what the shipped compiler is built with (recommended:
  `-O2`, since it runs on `runevm`) and what `make check` runs (recommended:
  the default, with `-O0` and `-O2` in the differential tests).

### D9. The calling convention

**Decided: A** for now (M8), **then B** in M12.

* **A. Known calls with n arguments; unknown calls stay unary through a
  closure.** **Recommended.**
  * A curried or tupled `fun` becomes a worker of n parameters and a
    wrapper for its uses as a value.
  * The counts favour it: 90.2% of calls come from sites with one callee.
* **B. eval/apply for unknown calls too** (Marlow and Peyton Jones 2004).
  It helps the 12.8% of calls that call a call's result. Later, in M12.

### D10. The old code generator

Keep `Codegen` as `-O0` and the differential reference from M4 until M10,
then remove it. **Recommended.**

### D11. The items of performance.md

* **Do now,** since they are independent of this roadmap:
  * 1-3: the lexer's lookups, the maps' loops, the cached file of a
    position;
  * 5: comparisons that return `order`;
  * 10: growing the heap without collecting twice;
  * 11: the compiler's other constant factors.

  Items 1 to 3 alone take 16.5% off the bootstrap before any middle-end
  work adds compile time.
* **Skip** in the old `Codegen`: 4, 7, 12, 8 and 17. M4, M8 and M9 deliver
  them, and work on `Codegen` would be thrown away.
* See *Relation to performance.md* for the rest.

### D12. The precision of `int` per target

Today it is 64 bits everywhere. A `vm/new` with 8-byte values might have
63-bit ints. That changes constant folding, `Int.precision`, and what the
Basis Library suite expects. The target record carries it.

### D13. `runeopt`'s long-term role

**Decided: A** now, perhaps B later.

* **A.** Templates over the stack bytecode, as now, for `vm/portable`.
* **B.** An optimising native back end from Low, later.
* **Recommended:** A for this roadmap, since `vm/new` and its JIT are
  where native speed is headed.

### D14. Exhaustiveness

**Decided: B.** The checked VM mode is part of M9.

* **A.** `Exhaust` becomes load-bearing: the last rule of an exhaustive
  match is not tested.
* **B.** Decision trees skip that test by construction (M9), and a checked
  VM mode, `DECON` testing its tag, stays for the test suites.
  **Recommended.**

## The milestones

Every milestone is one commit, or a few, each with `make check` green, as
the repository's rules require. Where it touches the VM, it also passes
`make test-stress`, the ASan build, `make test-windows` and
`make test-portability`. Where it moves `--count`, the budgets are measured
again and the commit quotes the old and the new. Sizes are lines of code,
estimated.

### M1. The instruction set as one description (L, about 1,500)

* **What:** the DSL in Standard ML and its generator (D6), with the stack
  bytecode's 35 instructions and 292 primitives described in it, bodies
  included:
  * the DSL, and the small language of its bodies;
  * the generator, its list of sources, and its build by the hosts and by
    Rune itself;
  * the generated interpreter cases, slow paths of `native.c`, tables,
    validators, SML datatype, `RbcCheck` and `runeopt` metadata, and the
    table of `docs/bytecode.md`;
  * the generated files committed, and a check in `make check` that they
    are up to date.
* **Also:**
  * `vm/opcodes.def`, `vm/prims.def`, `scripts/gen-opcodes.sh` and the
    six parsers go;
  * the version and the fingerprint go into `.rbc` and images;
  * the octal fixtures become `.rasm`.
* **Staged**, each step green:
  1. the DSL with everything but bodies, generating what the `.def` files
     and `gen-opcodes.sh` make today, byte for byte;
  2. the rest of the metadata, and its consumers switched over;
  3. the bodies, and the generated interpreter replacing the hand-written
     cases.
* **Done when:**
  * `bin/rune.rbc` is byte for byte the same, and `--count` gives the same
    numbers for every program;
  * the VM builds from a clean checkout with a C compiler alone;
  * an instruction added without a body, or without a template in
    `x64.sml`, fails the build;
  * the generated interpreter costs `runevm` no more instructions (`perf
    stat -e instructions:u` on the bootstrap);
  * `make check`, `make test-stress`, the ASan build, `make test-windows`
    and `make test-portability` pass.

### M2. Pass infrastructure (M, about 500)

* **Passes:** named passes, a pipeline per optimisation level, `-O0`, `-O1`
  and `-O2`, and `--passes=` to run a list of one's own.
* **Dumps:** `--dump-before=PASS` and `--dump-after=PASS`, printed with
  variables numbered afresh, so that expected files survive changes
  upstream.
* **Checks:** `--lint`, which runs the lint after every pass and is on in
  `make check`. Its first lint is `Lambda`'s, of its structure: every
  variable bound, stamps unique, every `Fail` in tail position of a `Try`,
  every `LetRec` right-hand side a `Fn`. M3 adds types.
* **Finding a bad pass:**
  * `--fuel=N`, which stops rewriting after N rewrites (optimisation
    fuel, as in Hoopl: Ramsey, Dias and Peyton Jones 2010), and a script
    that bisects on it to find the rewrite that breaks a program (Whalley
    1994);
  * `--pass-stats`: the time and the size before and after each pass;
  * `Error.Bug` naming the pass.
* **Tests:**
  * `tests/ir`: an input and its expected dump, reviewed like any
    `.expected`;
  * a differential script that compiles every program of `tests/lang`,
    `tests/perf`, the Basis Library suite and `tests/external` at two
    levels and compares output, error output and exit status.
* **Done when:** the output is byte for byte the same, and `make check`
  passes.

### M3. Types, and Mid launched dark (XL, about 2,000)

* **Types first** (D3):
  * the elaborator records binder schemes, instances at uses, and the
    datatypes and exceptions;
  * Translate and MatchComp put them on `Lambda`;
  * `Lambda`'s lint checks them.

  This is its own commit. It already checks the elaborator and the
  translation, before any optimisation exists.
* **Then Mid:**
  * its datatype, explicitly typed;
  * the translation from `Lambda`, with `Try`/`Fail` becoming join points
    and the top level becoming a list of definitions;
  * its lint, types included;
  * a printer, and a parser of the printed form, so that a pass can be
    tested on a small input.
* **The snags** of *The architecture* (*Types*) are settled here, each with
  a test in `tests/ir`: unresolved type variables, ascription without a
  coercion, primitives typed where they are bound.
* **Launched dark:** every compile builds the typed Mid and lints it, and
  the code is still generated from `Lambda`.
* **Done when:**
  * the output is byte for byte the same;
  * both lints are clean on every test, the Basis Library suite and the
    bootstrap;
  * printing and parsing give back the same Mid;
  * the compile-time budgets hold. Types cost memory and time on every
    compile, and are measured.

### M4. The new back end: Low and the stack target (XL, about 2,000)

* **What:**
  * closure conversion on Mid, with free variables computed once, bottom
    up (item 11's `fv`), and the same flat closures, so that allocation
    does not change;
  * Mid to Low, with exceptional edges into handler blocks;
  * liveness;
  * the stack target: out of SSA, slots shared and reused (item 4), a
    local read where it was just stored, stackification;
  * block layout: jumps threaded, a `RET` copied into its predecessors, a
    condition compiled as a branch (item 7);
  * the line table;
  * the target record and interface, designed for two targets.
* **The old `Codegen`** stays as `-O0` (D10).
* **Gain, from the counts:**
  * the moves are 28.0% of the bootstrap's instructions, and 15 to 33% of
    each `tests/perf` program's;
  * jumps to jumps and to returns are 2.5% more;
  * many of the unit stores (34.3% on top) go too, since functions need
    fewer slots; M6 removes the rest;
  * natively the gain is smaller: M15 of the native roadmap already reads
    many locals where they are, and `SETLOCAL` and `LOCAL` were 9.7% of
    native cycles.
* **Done when:**
  * bytes and objects allocated equal `-O0`'s for every program: the cheap
    semantic check of a back end;
  * `--gc-stress` passes;
  * `runeopt --check` accepts all the bytecode;
  * `make check-positions`, `check-cross` and the bootstrap's fixed point
    pass;
  * the budgets are measured again.

### M5. The register target and the first loop of `vm/new` (XL)

* **What:**
  * the register instruction set, as a second description (M1);
  * Low to register code, with linear-scan allocation (Poletto and Sarkar
    1999);
  * stack maps at the places a collection can happen;
  * a first loop that runs it, in `vm/new`, on `librune.a`;
  * the suites run through it, as `make test-native` runs them natively;
  * its own `--count` budgets;
  * the handover to the `vm/new` roadmap.
* **Measured here:** dispatches, code size and time against the stack
  target, on the same Low, the bootstrap and `tests/perf`. That is Rune's
  answer to Shi et al.
* **Where it goes:** right after M4 (D5).
* **Done when:** every suite passes on it, with bytes and objects equal to
  `runevm`'s.

### M6. `vm/portable`: frames and dispatch (M, about 400, a parallel track)

* **What:**
  * each function records which locals need a unit at entry (a format
    change);
  * the loop of performance.md's item 15: pc, sp and the frame's base
    kept in locals, computed goto where the compiler has it, from M1's
    X-macros;
  * `TEELOCAL`.
* **Gain:** est. `runevm` 1.25 to 1.5 times, and most of the 291 million
  unit stores.
* **Done when:** ASan, `make test-stress`, `make test-native-stress`,
  Windows and portability pass.

### M7. The simplifier and tree shaking (L, about 1,200)

* **Shrinking reductions** (Appel and Jim 1997): inlining what is used
  once, dead code removed, beta and eta, using the primitives' effects
  from the DSL (M1).
* **What is known:** a `case` on a known constructor, a `SELECT` of a known
  tuple, a known boolean.
* **Constants:** folded in `IntInf` at the target's precision, raising what
  the VM raises, never for reals.
* **Control:** `andalso`, `orelse` and `not` as branches; a raise to a
  handler of the same function as a jump.
* **Tree shaking:** globals nothing reaches go first, since the Basis
  Library is compiled whole into every program. In `tak`, 89% of the code
  is never called.
* **Gain:** est. 5 to 10% fewer instructions, and later passes (and
  compiles) cheaper.

### M8. Known calls and the calling convention (L-XL, about 1,500)

* **Known functions:** a top-level function bound once is known. A closure
  without free variables is made once, statically (item 12).
* **Workers and wrappers:** a curried or tupled `fun` becomes a worker of n
  parameters and a wrapper for its uses as a value (D9).
* **New opcodes:** `CALLK f, n` and `TAILCALLK f, n`. The arguments become
  locals 0 to n-1 with no checks, and natively the call is a direct jump.
* **Loops:** a self tail call becomes a jump to the top (item 12). These
  are the first backward jumps; `RbcCheck` and `runeopt`'s counting already
  allow them.
* **Staged:**
  1. closed top-level functions of one argument;
  2. tupled functions;
  3. curried functions;
  4. local functions that do not escape.
* **Gain, from the counts:**
  * fresh argument tuples are 41.9% of the bootstrap's objects (about 580
    MB), and 91 to 99.7% of those of `tak`, `word_bits`, `real_nbody` and
    `array_sieve`;
  * 21.3% of calls are self tail calls;
  * performance.md estimates native code 15 to 25% faster.
* **Blast radius:** Mid, the new back end, two opcodes in both
  bytecodes, the loader and `Rbc`, the native entry, the resume points of
  images, and the budgets.

### M9. Decision trees and `SWITCH` (L, about 900)

* **What:**
  * Maranget's decision trees (2008), from each datatype's constructors,
    with the rules' bodies as join points so that nothing is copied;
  * `SWITCH`, a variable-length instruction with a table of targets;
  * the last test of an exhaustive match left out by construction (D14);
  * a checked mode of the VMs, in which `DECON` tests its tag, run by the
    test suites (D14).
* **Gain, from the counts:**
  * the tests of a last rule, with their loads, are about 2.5% of the
    bootstrap's instructions;
  * the second and later tests of the same value are 1.8%, overlapping
    with the first;
  * performance.md estimates `runevm` 7 to 14% for items 8 and 17
    together. The counts point to the lower end for the compiler, whose
    datatypes are mostly narrow. Wide datatypes gain more.

### M10. The inliner, contification and inline frames (L, about 1,100)

* **Inlining:** with a size budget, deterministic. 33.9% of calls enter a
  function of at most 16 instructions.
* **Specialisation:** higher-order functions specialised to a known
  function argument (item 6's gain, for every program).
* **Contification:** a local function that always returns to the same
  place becomes a join point (Fluet and Weeks 2001).
* **Inline frames:** a line table that records inlined frames, so traces
  keep them (D7).
* **Gain:** est. 10 to 20% on the compiler, whose maps (38% of its
  instructions) call `compare` through a functor argument that expansion
  already makes known.
* **Also:** the old `Codegen` goes (D10).

### M11. Representation (L, about 1,000)

* **What:**
  * representations chosen from the datatypes M3 records;
  * a constructor whose argument is a tuple becomes one object (item 16);
  * `=` compiled by type where the type is known: 68.3% of polymorphic
    equalities compare two non-pointers;
  * the C that walks lists goes through accessors.
* **Gain:** est. about 30% fewer objects, native 8 to 15%. Constructors
  with an argument are 16.5% of objects, and each points to a tuple, one of
  the 58.1%.

### M12. Whole-program analyses (XL)

* **What:**
  * control-flow analysis (0CFA), for known calls through higher-order
    code;
  * defunctionalisation where a function value has few possible targets;
  * removal of useless variables and arguments;
  * eval/apply for the unknown curried calls (D9 B);
  * monomorphisation, only if `vm/new` unboxes.
* **Where it runs:** at `-O2` only, the whole-program mode.
* **Gain:** measured then. MLton, which does all of this, is 8 times faster
  than Rune's native code on the bootstrap.

### Why this order

* **Architecture first.** M1 to M3 change no output, so their checks are
  byte for byte and cheap. M4 finishes the architecture and is also the
  largest single gain. M5 proves the architecture with a second target.
* **Then gain for the work,** M7 to M11, each needing the ones before it:
  * M7 before M8, since workers and wrappers need the simplifier to clean
    up after them;
  * M9 before M10, since the inliner works on what the decision trees
    leave.
* **Parallel tracks:**
  * M6, `vm/portable`'s frames and dispatch;
  * performance.md's item 13, a generational collector. It needs nothing of
    this roadmap: every store into the heap is in `ref_set`,
    `array_update`, `SETENV` and two templates.
* **Revisit the order** after M4: its profile will not be today's.

## Ready for, not built

For each, what the IRs keep so that it stays possible, and the milestone at
which its design has to start.

* **Incremental compilation.**
  * **What the IRs keep:** every pass takes a flag that says whether it
    sees the whole program. Stamps need only be unique within a unit.
    Mid's printed form can serve as a unit's interface, carrying what
    other units may inline.
  * **Precedents:** OCaml's `.cmx` files; separate compilation in SML/NJ
    (Appel and MacQueen 1994).
  * **When:** the top level as a list of definitions (M3) is the unit.
    Start the design before M12, whose analyses must be switchable off.
* **Lazy evaluation, or a Haskell front end.**
  * **What the IRs keep:** thunk, force and update as Mid operations;
    strictness analysis in direct style; representations that tell an
    evaluated value from a thunk.
  * **Precedents:** the STG machine (Peyton Jones 1992) and pointer tagging
    (Marlow et al. 2007).
  * **When:** the representation of M11.
* **Delimited continuations and effect handlers.**
  * **What the IRs keep:** continuations stay second-class in the IR. The
    VM captures stack segments (Hieb, Dybvig and Bruggeman 1990), as OCaml
    5 does with fibers (Sivaramakrishnan et al. 2021).
  * **When:** `Handle` regions in Mid are where they attach.
* **Other collectors.**
  * **What the IRs keep:** `Alloc`, `Store` and `Safepoint` are Low
    operations, a barrier is a pass chosen by the collector, and liveness
    gives stack maps (Diwan, Moss and Hudson 1992).
  * **Loops:** a loop without calls gets a safepoint once M8 makes such
    loops, for collectors, green threads and signals alike.
  * **When:** M4 and M5.
* **Escape analysis and stack allocation, and regions** (Tofte and Talpin
  1997).
  * **What the IRs keep:** Low's explicit `Alloc` is where they act, and the
    counts above say what could move: 41.9% of objects are tuples made
    only to be passed to a call.
  * **When:** research after M8, since known calls remove most of those
    tuples first.
* **The FFI.** The owner asked where this becomes critical, so that the
  tracks can switch in time.
  * **Start its design before M5**, where `vm/new`'s convention for
    primitives is set.
  * **Settle it by M8**, where the calling convention is chosen.
  * **M11** extends it, when unboxed representations appear.
  * A foreign call is a known call with a different convention and a
    safepoint around it.
* **JIT, deoptimisation and on-stack replacement** in `vm/new`.
  * **What the IRs keep:** per-pc liveness and inline frames (M5, M10), so
    that optimised frames can be rebuilt as unoptimised ones (Hölzle,
    Chambers and Ungar 1992; Flückiger et al. 2018). The owner's notes ask
    for this to be designed in early.
* **Other IRs and bytecodes as experiments.**
  * `--passes=` runs any pipeline.
  * An instruction set is a file.
  * A target is a record and a module.
  * A new front end writes `Lambda`.

## Relation to performance.md

| Item of performance.md | Here |
|---|---|
| 1-3, 5, 10, 11 | stay there; do them now (D11) |
| 4 (slots), 7 (branches), 11's `fv` | M4 |
| 15 (`runevm`'s loop) | M6 |
| 12 (loops, closed closures), 14 (known calls) | M8 |
| 8 (last rule), 17 (decision trees) | M9 |
| 6 (the Basis's higher-order functions) | M10 |
| 16 (constructor tags) | M11 |
| 13 (generational collector) | stays there, a parallel track |
| 9, 18 (native templates) | stay there; worth doing only if native speed is needed before `vm/new` |
| 19 (8-byte values) | stays there; with `vm/new` and D12 |

## Testing an optimiser

* **The oracle** is the compiler built by MLton, backed by the bootstrap's
  fixed point and `check-cross`.
* **Differential runs:** every program compiled at `-O0` and `-O2`, and
  later on both targets, must print the same, fail the same and allocate
  the same bytes and objects.
* **Unit tests of passes** use Mid's printed form in `tests/ir`.
* **Lints** run after every pass in `make check`, and check types (D3):
  a pass that makes an ill-typed program is caught where it runs, not
  where the program fails.
* **Bisection by fuel** finds the one rewrite that breaks a program.
* **Stress and outside code:** `--gc-stress`, `runeopt --check`, the corpus
  of `rune-corpus-sml97` and `tests/external`.
* **Random programs,** later: a generator of well-typed SML programs, and
  equivalence modulo inputs (Le, Afshari and Su 2014), as Csmith did for C
  (Yang et al. 2011).
* **Documentation, as passes arrive:**
  * `docs/ir.md`, which says what each lint checks;
  * a rule in `AGENTS.md` for adding a pass: its lint, its dump, its test
    in `tests/ir`, its entry in `--pass-stats`.

## Measuring

The counts were taken on `b5ec8c8`, on the bootstrap (the recipe of
performance.md's *Measuring*) and on the eight programs of `tests/perf` at
their default input. Their tools were throwaway and are not in the tree.
Here is how to make them again.

* **The counting VM:** a copy of `vm/` whose `interp.c` calls a hook
  before every instruction, and whose `vm_alloc` calls another. The hook
  records:
  * executions per pc;
  * for each stack slot, the opcode that last pushed it: this gives where
    a call's closure and argument came from;
  * at every `CALL` and `TAILCALL`, the callee, whether the site has seen
    another callee, and whether the argument is a tuple and of how many
    fields;
  * consecutive pairs `SETLOCAL a; LOCAL a` and `LOCAL x; SETLOCAL y`, by
    pc;
  * the length of each run of `JUMPIFNOTTAG` on the same local of the same
    frame, closed when a test succeeds;
  * raises, and whether the frame changed;
  * `poly_eq` on two values that are not pointers;
  * allocations by kind, length and the opcode or primitive that made
    them.

  The counts are written at exit. A run gives the same instruction count
  as `runevm --count` (849,568,405 for the bootstrap), and the same
  bytecode.
* **The analysis:** a script reads the `.rbc`'s code with the lengths of
  `vm/opcodes.def`, joins the counts to it, and adds what is static:
  * the static reads of each local, for a store read once;
  * function sizes, and which functions are leaves;
  * which functions begin by taking local 0 apart, and which are only
    `CLOSURE; RET`;
  * which globals are bound once to a closure.

  Removable moves are counted per pc, taking the larger count where two
  pairs share an instruction.
* **Compile time by phase:** a copy of `src/driver/main.sml` that reads
  `Runtime.stats ()` around each phase, compiled by `bin/rune` and run on
  `runevm`. Instructions are deterministic, where time is not.

## References

Each was checked against its publisher's record on 2026-09-24.

**The shape of the IRs** (D1, D2):
* Flanagan, Sabry, Duba, Felleisen. "The essence of compiling with
  continuations." PLDI 1993, 237-247. doi:10.1145/155090.155113
* Kennedy. "Compiling with continuations, continued." ICFP 2007, 177-190.
  doi:10.1145/1291151.1291179
* Maurer, Downen, Ariola, Peyton Jones. "Compiling without continuations."
  PLDI 2017, 482-494. doi:10.1145/3062341.3062380
* Cong, Osvald, Essertel, Rompf. "Compiling with continuations, or
  without? Whatever." PACMPL 3 (ICFP 2019), article 79.
  doi:10.1145/3341643
* Kelsey. "A correspondence between continuation passing style and static
  single assignment form." IR '95, SIGPLAN Notices 30(3), 13-22.
  doi:10.1145/202529.202532
* Fluet, Weeks. "Contification using dominators." ICFP 2001, 2-13.
  doi:10.1145/507635.507639
* Tan, Myreen, Kumar, Fox, Owens, Norrish. "The verified CakeML compiler
  backend." JFP 29, e2, 2019. doi:10.1017/S0956796818000229
* Shao. "An overview of the FLINT/ML compiler." TIC 1997.
  http://flint.cs.yale.edu/shao/papers/tic97.html
* MLton's intermediate languages, AST → CoreML → XML → SXML → SSA → SSA2 →
  RSSA → Machine: http://mlton.org/CompilerOverview,
  http://mlton.org/IntermediateLanguage
* Chambart, Laviron, Bury, Courant, Pinto. "Flambda2 Ep. 1: Foundational
  Design Decisions." OCamlPro, 2024: its IR is second-class CPS, after
  Kennedy. https://ocamlpro.com/blog/2024_03_19_the_flambda2_snippets_1/

**Simplifying, inlining, compiling ML to a VM** (M7, M10):
* Appel, Jim. "Shrinking lambda expressions in linear time." JFP 7(5),
  515-540, 1997. doi:10.1017/S0956796897002839
* Peyton Jones, Marlow. "Secrets of the Glasgow Haskell Compiler inliner."
  JFP 12(4-5), 393-434, 2002. doi:10.1017/S0956796802004331
* Benton, Kennedy, Russell. "Compiling Standard ML to Java bytecodes."
  ICFP 1998, 129-140. doi:10.1145/289423.289435
* Benton, Kennedy, Russo. "Adventures in interoperability: the SML.NET
  experience." PPDP 2004, 215-226. doi:10.1145/1013963.1013987

**Calls and closures** (D9, M8):
* Marlow, Peyton Jones. "Making a fast curry: push/enter vs. eval/apply for
  higher-order languages." ICFP 2004, 4-15. doi:10.1145/1016850.1016856
* Bolingbroke, Peyton Jones. "Types are calling conventions." Haskell
  2009, 1-12. doi:10.1145/1596638.1596640
* Shao, Appel. "Efficient and safe-for-space closure conversion." TOPLAS
  22(1), 129-161, 2000. doi:10.1145/345099.345125
* Keep, Hearn, Dybvig. "Optimizing closures in O(0) time." Scheme 2012,
  30-35. doi:10.1145/2661103.2661106

**Matching** (M9):
* Maranget. "Compiling pattern matching to good decision trees." ML 2008,
  35-46. doi:10.1145/1411304.1411311
* Le Fessant, Maranget. "Optimizing pattern matching." ICFP 2001, 26-37.
  doi:10.1145/507635.507641

**Representation and whole programs** (M11, M12):
* Leroy. "Unboxed objects and polymorphic typing." POPL 1992, 177-188.
  doi:10.1145/143165.143205
* MLton's packed representations: http://mlton.org/PackedRepresentation
* Weeks. "Whole-program compilation in MLton." ML 2006 (abstract).
  doi:10.1145/1159876.1159877
* Cejtin, Jagannathan, Weeks. "Flow-directed closure conversion for typed
  languages." ESOP 2000, LNCS 1782, 56-71. doi:10.1007/3-540-46425-5_4

**Bytecode and interpreters** (D4, D6, M1, M5):
* Shi, Gregg, Beatty, Ertl. "Virtual machine showdown: stack versus
  registers." VEE 2005, 153-163. doi:10.1145/1064979.1065001
* Shi, Casey, Ertl, Gregg. "Virtual machine showdown: stack versus
  registers." TACO 4(4), article 21, 2008. doi:10.1145/1328195.1328197
* Ierusalimschy, de Figueiredo, Celes. "The implementation of Lua 5.0."
  J.UCS 11(7), 1159-1176, 2005. doi:10.3217/jucs-011-07-1159
* Ertl, Gregg. "The structure and performance of efficient interpreters."
  JILP 5, 2003. https://jilp.org/vol5/v5paper12.pdf
* McIlroy. "Firing up the Ignition interpreter." V8 blog, 2016.
  https://v8.dev/blog/ignition-interpreter
* Haas et al. "Bringing the web up to speed with WebAssembly." PLDI 2017,
  185-200. doi:10.1145/3062341.3062363; the design's rationale:
  https://github.com/WebAssembly/design/blob/main/Rationale.md; LLVM's
  stackification: `llvm/lib/Target/WebAssembly/WebAssemblyRegStackify.cpp`
* Leroy. "The ZINC experiment: an economical implementation of the ML
  language." INRIA RT-0117, 1990. https://inria.hal.science/inria-00070049
* Poletto, Sarkar. "Linear scan register allocation." TOPLAS 21(5),
  895-913, 1999. doi:10.1145/330249.330250
* CPython's generated interpreter (3.12): `Python/bytecodes.c`,
  `Tools/cases_generator/interpreter_definition.md`;
  https://github.com/python/cpython/issues/98831
* JavaScriptCore's instruction list, `Source/JavaScriptCore/bytecode/BytecodeList.rb`,
  and its portable assembler `offlineasm`; Zagallo, "A new bytecode format
  for JavaScriptCore", WebKit blog, 2019.
  https://webkit.org/blog/9329/a-new-bytecode-format-for-javascriptcore/
* Xu, Kjolstad. "Copy-and-patch compilation: a fast compilation algorithm
  for high-level languages and bytecode." PACMPL 5 (OOPSLA 2021), article
  136. doi:10.1145/3485513

**Ready for, not built:**
* Diwan, Moss, Hudson. "Compiler support for garbage collection in a
  statically typed language." PLDI 1992, 273-282.
  doi:10.1145/143095.143140
* Hieb, Dybvig, Bruggeman. "Representing control in the presence of
  first-class continuations." PLDI 1990, 66-77. doi:10.1145/93542.93554
* Sivaramakrishnan, Dolan, White, Kelly, Jaffer, Madhavapeddy.
  "Retrofitting effect handlers onto OCaml." PLDI 2021, 206-221.
  doi:10.1145/3453483.3454039
* Peyton Jones. "Implementing lazy functional languages on stock hardware:
  the Spineless Tagless G-machine." JFP 2(2), 127-202, 1992.
  doi:10.1017/S0956796800000319
* Marlow, Yakushev, Peyton Jones. "Faster laziness using dynamic pointer
  tagging." ICFP 2007, 277-288. doi:10.1145/1291151.1291194
* Tofte, Talpin. "Region-based memory management." Information and
  Computation 132(2), 109-176, 1997. doi:10.1006/inco.1996.2613
* Hölzle, Chambers, Ungar. "Debugging optimized code with dynamic
  deoptimization." PLDI 1992, 32-43. doi:10.1145/143095.143114
* Flückiger, Scherer, Yee, Goel, Ahmed, Vitek. "Correctness of speculative
  optimizations with dynamic deoptimization." PACMPL 2 (POPL 2018),
  article 49. doi:10.1145/3158137
* Appel, MacQueen. "Separate compilation for Standard ML." PLDI 1994,
  13-23. doi:10.1145/178243.178245

**Testing an optimiser:**
* Whalley. "Automatic isolation of compiler errors." TOPLAS 16(5),
  1648-1659, 1994. doi:10.1145/186025.186103
* Ramsey, Dias, Peyton Jones. "Hoopl: a modular, reusable library for
  dataflow analysis and transformation." Haskell 2010, 121-134:
  optimisation fuel. doi:10.1145/1863523.1863539
* Yang, Chen, Eide, Regehr. "Finding and understanding bugs in C
  compilers." PLDI 2011, 283-294. doi:10.1145/1993498.1993532
* Le, Afshari, Su. "Compiler validation via equivalence modulo inputs."
  PLDI 2014, 216-226. doi:10.1145/2594291.2594334
