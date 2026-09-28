# SML/NJ 110.99.9 for 64 bits: a garbage collection corrupts a value that a function holds, so that a pure computation gives different results in different runs

## Status: not reported as such; probably related to open #299 and #381

* **[#299](https://github.com/smlnj/legacy/issues/299)** (open, 64-bit):
  `PackWord64Big.update` "is nondeterministic". John Reppy found there that
  the value "is not being correctly preserved across the garbage
  collection".
* **[#381](https://github.com/smlnj/legacy/issues/381)** (open; smlnj/smlnj
  #394, "fixed in 2026.3"): an `Int64.int` is corrupted because arity
  lowering in `CPSTrans` builds a record that mixes raw 64-bit numbers and
  pointers, which the collector cannot handle. The 2026.3 fix is a new
  `CPSTransFn`, which the legacy branch does not have.

The program below is a single file with no functors, no `Pack` structures
and no records of mixed kinds in its source. Whether it is #299's or #381's
bug, or a third one, was not established. **No fix is offered here.**

**What is worth sending SML/NJ:** a new issue that names #299 and #381,
with `bug.sml` (`upstream.md` is the text). It would also be worth trying
`bug.sml` on 2026.3, which could not be built here.

## Summary

* **The trigger:** a function that computes the bits of a real with
  `Real.isNan`, `Real.isFinite`, `Real.toManExp`, `Real.fromManExp`,
  `Real.toLargeInt` and `Word64` operations. It is run 300,000 times on
  powers of two while garbage collections happen, in a 64-bit build.
* **What goes wrong:** now and then (82 times in 300,000 at the default
  settings, 588 with `@SMLalloc=128k`) the function returns a wrong word. The
  wrong words seen are:
  - `0wxFFF0000000000000`, which is what the function returns if the
    mantissa `man` of `Real.toManExp` reads as 0.0 instead of 0.5;
  - a heap address such as `0wx7B162AD00000`.

  The same call on the same number gives the right result a moment later. In
  the longer program `tests/lib/property/core.sml` of Rune, the process also
  stops with "Fatal error -- bogus fault" or "bogus overflow fault" in 3 runs
  of 5. The 32-bit build gave no wrong result in these runs.
* **Required behaviour:** the result of a pure function does not depend on
  when the collector runs.

## Where it happens

`bug.sml` counts the wrong results of 300,000 calls:

| Build | `@SMLalloc=128k` | default |
|---|---|---|
| 64-bit 110.96, 110.98, 110.99, 110.99.3, 110.99.5, 110.99.7, 110.99.8 | 515 - 953 | not run |
| 64-bit 110.99.9 release | 588 | 82 |
| 64-bit 110.99.9 with the fixes of this directory | 946 | not run |
| 32-bit 110.99.9 release | 0 | not run |

```
$ sml @SMLalloc=128k bug.sml            # 110.99.9, 64-bit
bits 4300000000000000 -> 7B162AD00000
bits 3160000000000000 -> FFF0000000000000
bits DC0000000000000 -> 7B162AD00000
...
588 of 300000 wrong
```

The runs vary: which calls go wrong, and how many, change from run to run.

## What is known

* **The collector triggers it.** An allocation area of 128 KB, which makes
  collections frequent, gives about seven times as many wrong results as the
  default; with the program of an earlier version of `bug.sml`, 512 KB or
  more gave none.
* **It depends on the shape of the compiled code, not the optimizations.**
  - Binding the intermediate values of the function to names, or leaving
    out the `isNan` or `isFinite` test, or either branch, makes it go away.
  - None of `Control.CG.flattenargs`, `extraflatten`, `etasplit`,
    `uncurry`, `betaexpand`, `dropargs`, `rounds := 0`, `spillGen := 0`,
    `ifidiom`, `lambdaprop` or `invariant` changes it.
  - `closureStrategy := 1` changes the count, 952 instead of 588.
  - `Control.CG.checkCPS := true` reports nothing.
* **What is live across the calls.** In the CPS of the function after
  closure conversion, continuations carry the mantissa as an unboxed `R64`
  and the shifted exponent as an unboxed `I64` across the calls to
  `Real.toLargeInt` and `Real.fromManExp`, which allocate. They are kept in
  `RK_FCONT` and `RK_RAWBLOCK` records of the closures, or in float
  registers that `CodeGen/cpscompile/invokegc.sml` must pack into a raw
  record before a collection and unpack after it. A root that is not
  preserved there would give exactly these symptoms. The fault was not
  located.

## How Rune met it

Rune's `tests/lib/property/core.sml` round-trips reals through their bits
and fails, or stops with a "bogus fault", on SML/NJ's 64-bit build now and
then. `tests/basis/deviations.txt` has a `HOST-FLAKY` line that is probably
the same thing (`Real.*/law-*`, "fromManExp (toManExp x) differs from x ...
never seen alone"). `bug.sml` is `realOf`/`bitsOf` of `lib/test/property`
cut down to what still fails.
