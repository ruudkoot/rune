# The types of the compiler

Notes of 2026-10-02, on `ir-checks`, for a roadmap to come: what the
compiler does with types after the elaborator, what has gone wrong there,
and what is stopped by a budget for now. Nothing below is a decision yet.

## Where types are

* **The elaborator** (`src/elab/types.sml`) infers with `Types.ty`: type
  variables are mutable cells, and a type bound to a variable is shared by
  everything that names the variable. A type of 2^n nodes as a tree can be
  n nodes in memory.
* **Lambda and Mid** carry `Ty.ty` (`src/core/ty.sml`): immutable trees,
  made from the elaborator's types once elaboration has finished
  (`Ty.fromTypes`), with `Gen` for a variable of a scheme and `Var` for one
  no type was found for. `LambdaLint` and `MidLint` check every node's type
  from its parts (middle-end plan, D3), so every pass that rewrites --
  inlining, specialisation, lifting -- must substitute types as it goes.
* **Low** carries no types, but a representation for each variable
  (`Low.rep`, from Mid's types in `Lower.repOfTy`), which the JIT's tier 2
  trusts. `LowLint` checks them now: a variable agrees with
  the operation that makes it, the primitive that takes it
  (`Prims.repsOf`, generated from the primitive's type in
  `src/isa/prims.sml`), a field of a tuple or a constructor made in its
  function, a block's or a known function's parameter, what a closure's
  function reads of a captured value, and an exception.

## What went wrong, and is fixed

* **A datatype declared in a function** that names the function's type
  variable (`fun 'a f ... = let datatype 'b t = T of 'a * 'b`) kept only
  its own parameters, so `'a` stayed free in its constructors. Inlining or
  specialising `f` at `bool` substituted `'a` in `f`'s body but not in the
  datatype, which every copy shares, and `MidLint` refused MLton's
  regression `datatype-with-free-tyvars` at `-O1` and `-O2` (the code was
  right). Now such a variable is a parameter of the datatype
  after its own, and of every datatype that names it, and every type made
  of the datatype gives it as itself (`Ty.extrasOf`). Bytecode did not
  change for any program of the suites, the benchmarks or the compiler.
* Not yet looked at: an exception declared in a function with an argument
  of the function's type variable (`exception E of 'a`) passes the lint
  today, because neither lint checks `MkExn`'s argument against the
  exception's (`Ty.exnArgs`); were it checked, the same question would
  come up.
* `--passes=` with a list does not reproduce `-O1`: `inline`,
  `specialise` and `trees` must be listed too, or bisecting a pass misleads.

## What is stopped by a budget

MLton's regression `exponential`:

```sml
fun f x = x
fun toy () = let fun g y = f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f y
             in g 3; g 4 end
```

Each `f` is an instance of `'a -> 'a` at the type of the one to its right,
so the type of the leftmost has 2^32 nodes as a tree. The elaborator keeps
it shared and is quick. `Ty.fromTypes` unfolds it: compile time and memory
doubled with each application -- 0.5 GB and 1.6 s at 22, more than 26 GB at
32, when it was killed.

| Compiler, at 32 applications | Result |
|---|---|
| MLton 20241230 (its own regression test) | compiles: 3.2 s, 690 MB |
| SML/NJ 110.99.9 | compiles: under 0.1 s |
| Moscow ML 2.10.1 | compiles: under 0.1 s |
| HaMLet 2.0.1 | runs: 0.9 s |
| Poly/ML 5.9.2 | does not finish in 120 s; time ×4 every two applications (1.9 s at 24), memory flat |
| MLKit 4.7.23 | out of memory at 8 GB after 34 s |
| Rune before the budget | more than 26 GB, killed |
| Rune with the budget of 10000000 | refused at the declaration in 0.25 s, 120 MB |

**The budget.** `--type-work=N` (default 50000000 steps per top-level
declaration; 10000000 until 2026-10-09) limited type inference only. It now also limits the
translation of each top-level declaration's types (`Types.startWorkOn`,
around each declaration in `Translate.transTopDecs`): `Types.prune`,
which the conversion calls on every node, spends a step, and running out is
the compile error `type translation exceeds N steps` at the declaration.
The compiler's own sources need at most about 58000 steps for a
declaration's inference, and no more for its translation. The largest
declaration met so far is the signature `BASIS_EXTRA` of MLton's Basis
Library, which `xc2:mlton` compiles (`tests/basis/xc2`): some 21 million
steps of inference. The default of 50000000 leaves it a margin of about 2.4
times, which is why the default was raised from 10000000. An exponential
program then compiles up to 22 applications (5 s, 350 MB) and is refused
from 23 (in about 9 s, at 690 MB); with 10000000 it was refused from 21
(measured on 2026-10-09 on a loaded machine: 2 to 3 s, 150 MB).
`tests/compiler/run-tests.py` tests both with budgets of its own, and
`tests/external/mlton-skip.txt` skips `exponential` (32 applications) as
`LIMIT`.

## What a fix needs

Measured with MLton's profiler at 22 applications, before the budget: the
translation took 0.9 s, and the time was the collector (32 %),
`Ty.fromTypes` (24 %), `Types.prune` (17 %), map insertions (12 %),
`Lift.gensOfTy` (9 %) and `Ty.equal` (4 %).

A prototype that memoised `Ty.fromTypes` on the elaborator's bound type
variables (cells have identity) made memory flat -- 9 MB from 20 to 24
applications -- but not time, which still doubled with each application:
0.03, 0.10 and 0.38 s at 20, 22 and 24. The profile at 24 is then
`Lift.gensOfTy` (39 %), map insertions (32 %, from it) and `Ty.equal`
(21 %): walks that take a shared type for a tree. So sharing at the
conversion is necessary but not enough; every walk over `Ty.ty` must
share too. They are about 46 places (`grep` of `Ty.subst`, `Ty.equal`,
`Ty.match`, `substTypes`, `gensOfTy`, `tyKey` and functions over
`Ty.ty`), the most in `tomid.sml`, `midtext.sml`, `simplify.sml` and the
two lints.

Directions, for the roadmap to choose from:

1. **Hash-consed types.** Each distinct `Ty.ty` node made once, through a
   table, with an identity a walk can memoise on: equality becomes
   comparing identities, and substitution, the variables a type names
   (`gensOfTy`), and specialisation's keys (`Simplify.tyKey`, a string
   today, which would itself be exponential) are memoised per node. MLton
   hash-conses the types of its intermediate languages this way.
   Portability: the compiler is Basis-only SML on five hosts and itself, so
   an identity has to be a number the table gives, not a pointer.
2. **Sharing kept, walks memoised by hand.** `fromTypes` memoised on the
   elaborator's cells, as in the prototype, and each walk given a memo
   table keyed by those identities; smaller than (1) to start, but every
   new walk has to remember to do it.
3. **Fewer types in the IR.** The instance types on variables
   (`Var (x, ts)`) are what grow; the lints need them, but most passes
   only pass them on. Types could be named once per function (a `let` of
   types) so that a big type is written once. Mid's text (`MidText`, and
   `--mid-roundtrip` in `check-levels`) needs some such abbreviation
   anyway, or printing a big type is exponential too.

Whatever is chosen, the measure of done is `exponential` passing in
`tests/external/run-mlton.sh` at `-O0` to `-O2`, with `--lint` and
`--mid-roundtrip`, its entry gone from `mlton-skip.txt`; a `tests/perf`
budget on a program of some 20 applications to keep it so; and the type
translation's share of `--type-work` dropped, or set by what the compiler
then does.
