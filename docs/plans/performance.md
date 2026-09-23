# Performance plan: the compiler on runevm

This document covers the compiler Rune ships, `bin/rune` (i.e. `bin/rune.rbc`
on `runevm`; `check-cross` knows it as `bin/rune-boot`). `make test`,
`make test-basis`, `make bootstrap` and the boot leg of `make check-cross` all
spend their time in it. It records where the time goes and the remaining work,
ordered by expected gain per effort. Numbers are from 2026-09-18 on a 16-CPU
Linux machine.

## Measuring

`runevm --count` prints the instructions executed and the bytes and objects
allocated; `make perf-check` holds benchmark programs, the hello compile and
the bootstrap to budgets on those numbers (`tests/perf`). After a change
that is meant to move them, `sh tests/perf/run-perf.sh --update` and quote the
old and new numbers in the commit.

## Where we are

| Workload | MLton build | `bin/rune` |
|---|---|---|
| Compile the compiler (`BOOT_SRCS` in the Makefile) | 0.08 s | 3.1 s |
| Compile a one-line program (almost all of it is the basis) | 0.05 s | 0.5 s |
| `make test` at `-j16` (176 programs) | 3 s | 15 s |

The self-hosted compiler is about 35–40× slower than the native build.
Two fixes have already landed; together they took the first row from 41 s to 3.1 s:

* **`OrdMap.unionWith`** used to fold the large map `m1` into the small map `m2`.
  That made every `Env.plus` cost time proportional to the whole environment.
  It was about 90% of the run time, in the MLton build as well.
* **Interpreter helpers:** `vm_push` and `instr_length` are now inline.
  Previously each was a real function call on nearly every instruction.

## Profile of the current bootstrap

The compiler compiling itself executes **371 M instructions** and allocates
**15.7 M objects (652 MB)**.

| Opcode | Share | Opcode | Share |
|---|---|---|---|
| `LOCAL` | 29.5% | `CALL` | 3.8% |
| `SETLOCAL` | 15.4% | `RET` | 3.8% |
| `SELECT` | 8.5% | `JUMP` | 3.5% |
| `PRIM` (of which `poly_eq` 4.2%) | 6.8% | `ENV` | 3.5% |
| `JUMPIFNOT` | 5.6% | `CONTAG` | 3.4% |
| `INT` | 4.3% | `GLOBAL` | 3.1% |

Share of VM time (gprof):

| Function | Share |
|---|---|
| `vm_run` (its own code, not its callees) | 75% |
| `vm_alloc_fields` | 16% |
| `push_frame` | 3% |
| primitives | about 4% |

Garbage collection is under 2%.

Hottest source functions, by share of executed instructions:

| Function | Share | Called from |
|---|---|---|
| `List.find` | 11% | `Lexer.lookupReserved` |
| `OrdMap.find`, `height`, `insert`, `bal`, `mk` | about 26% together | elaborator environments, codegen `IntMap`s |
| basis `Char.contains` loop | 4% | lexer |

## Constraints for all items

* Compiler sources must stay inside the language Rune supports
  (`docs/building.md`, rule 6).
* All four compiler builds must emit identical bytecode.
  `make check` enforces this, and `make bootstrap` checks the fixed point.
* **Changing the instruction set** means all of the following:
  * edit `vm/opcodes.def` or `vm/prims.def`, then run `make gen`;
  * describe the change in `docs/bytecode.md`;
  * bump the `.rbc` version in `src/backend/emit.sml` and `vm/loader.c` if the layout changes.
* **VM changes** must also pass `make vm-asan && sh tests/run-tests.sh --vm bin/runevm-asan`.
* VM code stays C99. Compiler extensions such as computed goto need a portable fallback.

## Remaining work

### 1. Source-level fixes in the compiler and basis

These change no instruction or bytecode format. Each is small.

* **Lexer reserved words.** `Lexer.lookupReserved` does a linear `List.find`
  with polymorphic string equality for every identifier. That is 1.1 M
  iterations, and each one also allocates a closure. Use a `StringMap` built once, or
  dispatch on `String.size` first.
* **`OrdMap` inner loops.** `insert cmp`, `find cmp` and the other curried
  functions rebuild the `insert cmp` closure at every recursion level. Instead, bind
  `cmp` once and recurse in a local function. Also, `mk` calls `Int.max` as
  a closure with a tuple argument; an inline `if` is cheaper.
* **`String.compare`** makes three calls and allocates three tuples per comparison
  (`compareInt`, `Int.<`, `Int.>`). Compare with the builtin `<`/`>` at type
  `int`, or have the primitive return an `order`.

### 2. Inline primitives bound with `val` (done)

Done as part of [basis.md](basis.md): `Translate` records the variables bound
to a primitive, or to such a variable (`val size = String.size`), and
translates their applications like `applyPrim`. Measured with `runevm --count`
on the compiler compiling itself: 541.7 M to 491.9 M instructions, 916 MB to
650 MB allocated, 22.1 M to 15.5 M objects, 4.3 s to 3.5 s. The description
as it was written:


`lib/basis/int.sml` and others bind `val op < = _prim "int_lt" : ...`. This
makes `Int.<`, `Int.+` and friends global closures. Every qualified use
(`Int.+ (i, 1)`) is then a `GLOBAL`, a `TUPLE` allocation, a `CALL`, two
`SELECT`s and the `PRIM`, instead of just the `PRIM`.

`Translate` only inlines direct `_prim` applications and the builtin overloaded
operators (`transApp`, `applyPrim`). Fix: remember globals whose right-hand side is
an `EPrim`, and translate applications of them like `applyPrim`.

### 3. Codegen peephole and aliases

These are measured over the whole bootstrap:

* **Jump chains.** 45% of executed jumps (15.3 M) land on another `JUMP`, and
  3.0 M land on `RET`. Nested `If`/`Try` each emit a jump to their own end
  label. Fix: thread jumps, and replace a jump to `RET` with `RET`. `andalso`/`orelse`
  (`If (If ...)`) could branch directly instead of building a bool.
* **Alias copies.** A pattern variable is bound through a temporary:
  `bindVar (stamp, g, Var v, k)` in `MatchComp` becomes
  `SELECT i; SETLOCAL w; LOCAL w; SETLOCAL x`. That is 23.5 M
  `LOCAL`→`SETLOCAL` copies. Fix: substitute `Let (x, Var y, e)` away in
  `Translate`/`MatchComp`, or map `x` to `y`'s slot in `Codegen`.
* **Store then reload.** `SETLOCAL a; LOCAL a` runs 31.5 M times. A `Let` whose
  variable is used once, immediately, can stay on the stack.
* **Tag tests.** `MatchComp.testTag` compiles every constructor test to
  `LOCAL v; CONTAG; INT t; PRIM poly_eq; JUMPIFNOT`. It runs 12.5 M times,
  17% of all instructions, and 82% of all `poly_eq` calls are these integer
  tag comparisons. Fix: a fused "jump if tag differs" instruction, which needs a new opcode.

### 4. Match compilation

Rules are tried in order with `Try`/`Fail` backtracking, and each rule
re-selects and re-tests the scrutinee. For example, `OrdMap.height` executes 21 instructions per call.
Replace this with a decision tree (or a tag switch) that:

* tests each subterm once;
* omits the last test when all constructors of the type are covered
  (`#ncons` is in `coninfo`), e.g. the second test for `E | T` or `nil | ::`;
* does not emit the unreachable `raise Match` after an exhaustive match;
* does not re-bind curried parameters for every clause (`ENV k; SETLOCAL j`).

### 5. Frame size

Local slots are never reused: the average function has 7.5 of them and the
largest has 163. `CALL` stores a unit into every slot, 96 M stores per bootstrap
(26% on top of the instruction count). Fix: reuse slots when their scope ends
in `Codegen`. That has to stay GC-safe, because the collector scans the whole stack.

### 6. Calling convention

Every function takes exactly one argument.

* **Tupled calls** allocate an argument tuple that the callee immediately takes
  apart. 8.8 M of the 10.5 M tuples allocated are `TUPLE` followed by `CALL`
  or `TAILCALL`.
* **Curried calls** allocate a closure for every partial application:
  3.2 M closures.
* **Top-level functions** are always called through `GLOBAL` (with a
  `global_set` check) and a generic `CALL`. That path checks the closure's kind and
  the function index, then calls `push_frame`. This applies even to a function's recursive calls to itself.

Options:
* multi-argument functions: arity raising for known tupled/curried functions, with a
  `CALL n`-style instruction;
* direct calls to globals that are bound once to a closure.

This is the largest bytecode change.

### 7. Interpreter loop and allocation

* Dispatch through computed goto where available, keeping the `switch` as the fallback.
* Keep `pc`, `sp` and the frame base in locals and write them back only when
  calling out (primitives, allocation, raise). Today `pc` is written to
  `vm->pc` on every instruction and the `trace` flag is tested on every instruction.
* Inline bump allocation for `TUPLE`, `CON`, `CLOSURE` (`vm_alloc_fields` is
  16% of VM time). Also stop initialising fields to unit when they are overwritten
  immediately.
* Give hot integer operations (`int_add`, `int_lt`, ...) and tag equality
  a path without the indirect `prim_table` call and the out-of-line `ret`.

### 8. Value representation

`Value` is a 1-byte tag plus an 8-byte union, 16 bytes in total, for stack slots
and heap fields alike. A constructor with an argument boxes its tuple in a
separate `K_CON` object, so a list cell is two objects, 40 + 24 = 64 bytes.

Options:
* 8-byte tagged values;
* the constructor tag stored in the tuple's header, so `CON` of a tuple is one object.

This touches every primitive and the collector. Do it last.

**16 bytes is a constraint, not an accident** (`vm/vm.h`). The padding between
the tag and the union is written out, because the 32-bit System V ABI aligns an
`int64_t` to 4 where x86-64, PowerPC and the Windows compilers align it to 8:
without it a `Value` is 12 bytes on a 32-bit Linux and every object of the heap
a different size there. Three things depend on it -- the counts of `--count`,
which `make perf-check` uses as budgets and `make test-portability` compares
across machines; the heap of an image, which is rebuilt at the offsets it was
written from (`vm/image.c`); and the arithmetic of `Int`, `Word` and `Real`,
which is 64-bit on every VM.

**And 12 bytes would save almost nothing anyway.** `payload_size` rounds a
payload up to a multiple of 16, so the objects that fill a heap do not shrink:
a 1-field object is 24 bytes either way, a 2-field one 40 either way, and only
from 4 fields up is anything saved. Measured on `examples/nqueens.sml`:
6,851,408 bytes against 6,882,848, which is **0.46%**. Anyone tempted by a
narrower `Value` on 32-bit machines should read that number first, and know it
would also mean writing an image by object index rather than by offset, and
giving up the byte-for-byte agreement of `--count` between machines.

**The rounding is not a lever**, which is worth saying because it looks like
one. `payload_size` rounds a payload up to a multiple of 16 and never gives
less than 16 (`vm/heap.c`), but a payload of *fields* is `n` times 16 and so
already a multiple of it: nothing is ever padded. It bites only on a string,
which is padded up to 16 bytes and then to a multiple of 16 -- a string of one
byte costs the same 24 bytes as a string of sixteen. Rounding to 8 instead
would change nothing about a tuple and would halve the floor for a short
string.

So what a list cell costs is not padding but the boxing already named above: a
cons cell is a 2-field tuple (40 bytes) *and* a `K_CON` around it (24). Putting
the constructor tag in the tuple's header makes it one object of 40, which is
38% of every list cell, and is where this item's payoff is.

## Measuring

Time the bootstrap. Take the best of several runs, because timings on a
shared machine vary by ±30%:

```sh
BOOT_SRCS="build/config.sml $(grep -v '^[[:space:]]*#' sources.txt | grep -v '^[[:space:]]*$') src/main/rune-main.sml"
time bin/rune -o /tmp/x.rbc $BOOT_SRCS
time bin/rune --typecheck-only $BOOT_SRCS   # front end only
```

Where VM time goes:

```sh
cc -std=c99 -O2 -pg -o /tmp/runevm-pg vm/*.c -lm
/tmp/runevm-pg --heap-size 268435456 bin/rune.rbc -o /tmp/x.rbc $BOOT_SRCS   # writes ./gmon.out
gprof -b -p /tmp/runevm-pg gmon.out && rm gmon.out
```
Where the compiler spends time natively. This usually points at the same
algorithmic hot spots; some runs crash inside the profiler, so rerun those.

```sh
mlton -profile time -output /tmp/rune-prof build/rune.mlb
/tmp/rune-prof -o /tmp/x.rbc $BOOT_SRCS   # writes ./mlmon.out
mlprof /tmp/rune-prof mlmon.out && rm mlmon.out
```

The counts in this document come from a throwaway copy of `vm/interp.c` with
counters in the dispatch loop. It counted:
* opcode, primitive and opcode-pair frequencies;
* instructions and calls per function;
* allocations by kind;
* the move and jump patterns listed above.

A `runevm --profile` option that reports the same data would make each item
above easy to measure before and after.
