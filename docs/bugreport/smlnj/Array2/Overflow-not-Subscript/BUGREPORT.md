# SML/NJ 110.99.9 and 2026.2: `Array2` raises `Overflow` instead of `Subscript` for an index or a region near `Int.maxInt`

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on it
(searched 2026-10-09). The code is the same in smlnj/legacy `main` at
`12f1dfe` (2026-10-03) and in smlnj/smlnj `main` at `033dd76`
(2026-10-09), after `204968a`, which fixed other boundary cases of
`Array2` ([no-rows-or-columns](../no-rows-or-columns/BUGREPORT.md)).

**What is worth sending SML/NJ:** an issue on smlnj/legacy, which also
asks for smlnj/smlnj, with `bug.sml`, `fix.diff` and
`fix-development.diff` (`upstream.md`).

## Summary

* **The trigger:** `Array2.row (a, i)` with `i` near `Int.maxInt`; `appi`,
  `foldi`, `modifyi` or `copy` of a region whose `row + nrows` or
  `col + ncols` passes `Int.maxInt`; `copy` with a `dst_row` or `dst_col`
  near `Int.maxInt` or `Int.minInt`.
* **What goes wrong:** `Overflow`, not `Subscript`.
* **Required behaviour:** the
  [Basis `ARRAY2` specification](https://smlfamily.github.io/Basis/array2.html):
  `row (arr, i)`: "If (nRows arr) <= i or i < 0, this raises Subscript";
  `appi`, `foldi` and `modifyi`: "If reg is not valid, then the exception
  Subscript is raised"; `copy`: "if the derived destination region (the
  source region src translated to (dst_row,dst_col)) is not valid in dst,
  then the Subscript exception is raised." MLton raises `Subscript` in all
  six cases of `bug.sml`.

## Where it happens

| Build | `bug.sml`, wrong of 6 |
|---|---|
| 110.99.9, 64-bit release | 6 |
| 2026.2 | 6 |
| `array2.sml` of smlnj/smlnj `main` (`204968a`), as a program on 110.99.9 | 6 |
| that file with `fix-development.diff`, or legacy's with `../no-rows-or-columns/fix.diff` and `fix.diff`, as a program on 110.99.9 | 0 |

```
$ sml bug.sml                           # 110.99.9 or 2026.2, 64-bit
row (a, maxInt): Overflow (WRONG: expected Subscript)
foldi of {row = 1, nrows = SOME maxInt}: Overflow (WRONG: expected Subscript)
appi of {col = 1, ncols = SOME maxInt}: Overflow (WRONG: expected Subscript)
modifyi of {row = maxInt, nrows = SOME maxInt}: Overflow (WRONG: expected Subscript)
copy of a 2 x 2 region to dst_row = maxInt: Overflow (WRONG: expected Subscript)
copy of a 2 x 2 region to dst_row = dst_col = minInt: Overflow (WRONG: expected Subscript)
```

## The cause

`system/Basis/Implementation/array2.sml` computes with the checked `int`
arithmetic before it compares:

* `row` binds `val stop = i*ncols` before it tests `i`, so `i = maxInt`
  overflows in the multiplication;
* `chkRegion`, which `appi`, `foldi`, `modifyi` and `copy` use for their
  regions, tests a length with `n < start+len`;
* `copy` tests its destination with `src_nrows + dst_row > dnrows` and
  `src_ncols + dst_col > dncols`, and then computes
  `dst_row * dncols + dst_col`, which overflows for a `dst_row` near
  `minInt` that the first test lets through.

## The fix

The tests compare without adding or multiplying: `row` tests `i` first and
multiplies only a valid index; `chk` tests `n < start orelse n - start <
len`; `copy` tests `dst_row < 0 orelse dst_col < 0 orelse dnrows -
src_nrows < dst_row orelse dncols - src_ncols < dst_col`. None of those
can overflow: every operand is already known to be between 0 and the size
of the array.

* `fix.diff`: against smlnj/legacy `12f1dfe` after
  [`../no-rows-or-columns/fix.diff`](../no-rows-or-columns/fix.diff),
  since both change `row`.
* `fix-development.diff`: against smlnj/smlnj `main`, alone or with
  `../no-rows-or-columns/fix-development.diff` (they touch different
  functions). Either way the two fixes give the same file.

**How it was tested:** a rebuild of SML/NJ's Basis was not made. Instead
`array2.sml` was compiled as a program on 110.99.9 with what it takes of
the compiler stood in for (`../no-rows-or-columns/stand-in.sml`):

* with both fixes `bug.sml` gives `Subscript` six times;
* Rune's Basis suite's `tests/basis/array2.sml` passes all of its 1,255
  checks, where the file of 110.99.9 dies in the section
  `no-elements-writes` and, with the other report's fix alone, fails the 20
  checks `Array2.*/Subscript-not-Overflow*`;
* the file of smlnj/smlnj `main` with `fix-development.diff` alone fails
  only the 3 checks of `fold ColMajor` that the other report fixes.

## How Rune met it

Rune's Basis suite checks each bound near `Int.maxInt` and `Int.minInt`
(`deviations.txt`: `native:smlnj*@* | Array2.*/Subscript-not-Overflow-*`
and `Array2.row/Subscript-not-Overflow`). Poly/ML and MLKit have faults of
the same kind in `Array2` and the slices, which the suite records for them.
