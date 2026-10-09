# MLton 20241230: with `-default-type int64`, `Array2` accepts a region whose start plus length passes `Int.maxInt`

## Status: not reported

No issue on MLton/mlton matches (searched 2026-10-09 for `Array2
overflow`, `Array2 region`, `Subscript Overflow`). `master` at `5fe9433`
(2026-10-03) has the same `checkSliceMax'` in
`basis-library/arrays-and-vectors/array2.sml` (read, and `fix.diff`
applies to it).

## Summary

* **The trigger:** a program compiled with `-default-type int64` (so that
  `Int.int` is `Int64.int`), and an `Array2` region with `nrows = SOME n`
  or `ncols = SOME n` where `row + n` or `col + n` passes `Int.maxInt`; or
  `Array2.copy` with `dst_row` or `dst_col` near `Int.maxInt`.
* **What goes wrong:** no `Subscript`. `appi`, `foldi` and `modifyi` of
  such a region return without applying `f`; `copy` returns without
  copying.
* **Required behaviour:** the
  [Basis `ARRAY2` specification](https://smlfamily.github.io/Basis/array2.html)
  of `appi`, `foldi` and `modifyi`: "If reg is not valid, then the
  exception Subscript is raised", and such a region is not valid. With the
  default 32-bit `int` MLton raises `Subscript` for the same program.

## Environment

* **MLton:** 20241230, the official binary release for amd64-linux.
* **System:** Linux x86-64 (Ubuntu 24.04 on WSL2).
* **Basis Library: MLton's own.** `mlton -default-type int64 bug.sml`,
  nothing of Rune involved.

## Where it happens

```
$ mlton -default-type int64 bug.sml && ./bug
Int.precision = 64
foldi of {row = 1, nrows = SOME maxInt}: no exception (WRONG: expected Subscript)
foldi of {col = 1, ncols = SOME maxInt}: no exception (WRONG: expected Subscript)
appi of {row = 1, nrows = SOME maxInt}: no exception (WRONG: expected Subscript)
modifyi of {col = 1, ncols = SOME maxInt}: no exception (WRONG: expected Subscript)
copy of a 2 x 2 region to dst_row = maxInt - 1: no exception (WRONG: expected Subscript)
```

| Build | wrong of 5 |
|---|---|
| `mlton bug.sml` (32-bit `int`) | 0 |
| `mlton -default-type int64 bug.sml` | 5 |
| the same with `fix.diff` applied to a copy of the library (`-mlb-path-var 'SML_LIB ...'`) | 0 |

## The cause

`basis-library/arrays-and-vectors/array2.sml`, `checkSliceMax'`, which
`checkRegion` (for `appi`, `foldi`, `modifyi` and the source of `copy`)
and `checkRegion'` (for the destination of `copy`) use:

```sml
             | SOME num => if Primitive.Controls.safe
                              then let
                                      val start =
                                         (SeqIndex.fromInt start)
                                         handle Overflow => raise Subscript
                                   in
                                      if (start < 0 orelse num < 0
                                          orelse start +! num > max)
                                         then raise Subscript
                                         else (start, start +! num)
                                   end
```

`+!` is `SeqIndex.+!`, the addition without the test of `Overflow`. On a
64-bit target `SeqIndex.int` is `Int64.int`. With the default 32-bit
`int`, `start` and `num` come from 32-bit values and their sum fits in 64
bits; with `-default-type int64` they are 64-bit and the sum wraps round to
a negative number, which is not greater than `max`, so the region passes
with an end below its start.

By reading the code, a 32-bit target, where `SeqIndex.int` and the default
`int` are both 32 bits, should do the same with the default `int`; that was
not run.

## The fix

`fix.diff` (against `master` `5fe9433`; it applies to the library of
20241230 under `lib/mlton/sml/basis` with the path changed) tests without
adding: `start > max orelse num > max -! start`, where `max -! start`
cannot overflow once `0 <= start <= max`.

**How it was tested:** the library of the 20241230 release was copied,
`fix.diff` applied, and programs compiled against the copy with
`-mlb-path-var 'SML_LIB <copy>'` and `-default-type int64 -default-type
word64`:

* `bug.sml` gives `Subscript` five times;
* Rune's Basis suite's `tests/basis/array2.sml` (1,255 checks) fails 18
  checks without the fix, the 16 `Subscript-not-Overflow-sum-*` checks of
  `appi`, `foldi`, `modifyi` and `copy` among them, and 2 with it: the
  checks of `copy` within one array, a separate bug of MLton's that the
  suite records for the default `int` too
  (`native:mlton@* | Array2.copy/overlap-[lr]*`).

## How Rune met it

The suite runs MLton natively with the default 32-bit `int`, where this
does not show. `xc2:mlton` compiles MLton's own library with Rune, and
builds it for a 64-bit `int`, since Rune's `int` has more than 32 bits
(`tests/basis/xc2`); there the 16 checks failed
(`deviations.txt`: `xc2:mlton@* | *Array2.*/Subscript-not-Overflow-sum-*`).
