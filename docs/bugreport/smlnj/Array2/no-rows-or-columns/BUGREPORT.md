# SML/NJ 110.99.9 and 2026.2: `Array2` traverses rows and columns that an array or a region does not have

## Status: fixed in part in the development line, not in legacy

smlnj/smlnj fixed most of this in `204968a` (2026-10-05, "fixed various
boundary cases in the `Array2` structure", for 2026.3), after 2026.2. That
commit leaves `fold ColMajor` and `modify ColMajor` of an array with rows
and no columns. smlnj/legacy `main` at `12f1dfe` (2026-10-03) has the file
of 110.99.9 unchanged. No issue on either tracker names `Array2` (searched
2026-10-09).

**What is worth sending SML/NJ:** an issue on smlnj/legacy asking for
`fix.diff`, which is `204968a` backported with the two cases it leaves,
and an issue on smlnj/smlnj for those two cases (`fix-development.diff`).
The texts are in `upstream.md`.

## Summary

* **The trigger:** an `Array2` array with no rows or no columns, or a
  valid region with no rows or no columns.
* **What goes wrong:**
  - `Array2.array (0, 5, x)` and `Array2.array (4, 0, x)` have the
    dimensions (0, 0) (`tabulate` and `fromList` keep them).
  - `Array2.row (a, 0)` of an array without rows is an empty vector, not
    `Subscript` (and `column` likewise).
  - `appi`, `foldi` and `modifyi` of a valid region without rows
    (`RowMajor`) or without columns (`ColMajor`) apply `f` to one row or
    column. Where the region is at the end of the array, that row is past
    the end: it is read with `unsafeSub` and, by `modifyi`, written with
    `unsafeUpdate`.
  - `app`, `fold` and `modify` in `ColMajor` order of an array with rows
    and no columns (as `tabulate (3, 0, f)` makes) apply `f` once a row, to
    elements read past the end of the empty array; `modify` writes them
    back there.
* **Required behaviour:** the
  [Basis `ARRAY2` specification](https://smlfamily.github.io/Basis/array2.html):
  `array (r, c, init)` "creates a new array with r rows and c columns";
  `row (arr, i)`: "If (nRows arr) <= i or i < 0, this raises Subscript"; a
  region with `nrows = SOME 0` or `ncols = SOME 0`, or that starts at the
  last row or column, is valid and has no elements, so `appi`, `foldi` and
  `modifyi` apply `f` to nothing; and an array without elements has none to
  traverse. MLton and MLKit give the expected values below.

## Where it happens

| Build | `bug.sml`, wrong of 10 |
|---|---|
| 110.99.9, 64-bit release | 10 |
| 2026.2 | 10 |
| `array2.sml` of smlnj/smlnj `204968a`, as a program on 110.99.9 | 2 (`fold` and `modify` `ColMajor`) |
| `array2.sml` with `fix.diff`, as a program on 110.99.9 | 0 |

```
$ sml bug.sml                           # 110.99.9 or 2026.2, 64-bit
dimensions (array (0, 5, 0)) = (0, 0), expected (0, 5): WRONG
dimensions (array (4, 0, 0)) = (0, 0), expected (4, 0): WRONG
row (array (0, 3, 0), 0) = 0, expected Subscript: WRONG
elements foldi RowMajor visits in a region without rows = 3, expected 0: WRONG
elements foldi ColMajor visits in a region without columns = 3, expected 0: WRONG
sub (a, 1, 0) after modifyi of a region without rows = 110, expected 10: WRONG
elements foldi RowMajor visits in the empty region at the end = 3, expected 0: WRONG
elements app ColMajor visits in tabulate (3, 0, f) = 3, expected 0: WRONG
elements fold ColMajor visits in tabulate (3, 0, f) = 3, expected 0: WRONG
elements modify ColMajor visits in tabulate (3, 0, f) = 3, expected 0: WRONG
```

## The cause

`system/Basis/Implementation/array2.sml`:

* `array` returns `{data = newArray0(), nrows = 0, ncols = 0}` when the
  array has no elements, whatever the dimensions asked for (`tabulateRM`
  and `tabulateCM` give `nrows = nrows, ncols = ncols`).
* `row` tests `ltu (nrows, i)`, which lets `i = nrows` through; for an
  array with rows, the checked `A.sub` past the end raises `Subscript` by
  chance, and for an array without rows `mkVec` makes an empty vector.
  `column` has the same test with `ncols`.
* `iterateRM` emits an element when `c < cEnd` before it looks at the
  rows, so a region of no rows yields the elements of row `row`;
  `iterateCM` likewise yields column `col` of a region of no columns.
* `appCM`, `foldCM` and `modifyCM` step through the rows of column 0
  before they test the column against `ncols`, so with `ncols = 0` they
  read `data[0]`, `data[0]`, ... of an empty array.
* `204968a` keeps the dimensions in `array`, fixes `row`, `column`,
  `iterateRM` and `iterateCM`, and gives `appCM` a case for no columns, but
  not `foldCM` and `modifyCM`.

## The fix

* `fix.diff` (against smlnj/legacy `12f1dfe`, whose file is 110.99.9's):
  `204968a` backported, with `foldCM` and `modifyCM` returning at once for
  an array without columns.
* `fix-development.diff` (against smlnj/smlnj `main`, which has `204968a`):
  the two cases alone.

**How it was tested:** a rebuild of SML/NJ's Basis was not made. Instead
`array2.sml` was compiled as a program on 110.99.9 with what it takes of
the compiler stood in for (`stand-in.sml`: `InlineT.Int.ltu` as an
unsigned comparison, `Unsafe.Array` for the unchecked array primitives):

* the file of 110.99.9 so gives `bug.sml`'s 10 wrong lines, as the library
  does, and with `fix.diff` none;
* Rune's Basis suite's `tests/basis/array2.sml` (1,255 checks) dies in its
  section `no-elements-writes` with the file of 110.99.9; with `fix.diff`
  it runs to the end, and its only failures are the 20 checks where a
  region whose start plus length passes `Int.maxInt` raises `Overflow`
  instead of `Subscript`, a separate bug that `204968a` leaves too;
* the file of `204968a` gets through the suite with those 20 and 3 of the
  `Array2.fold/model-empty-*` laws failing.

## How Rune met it

Natively, the suite's checks of arrays without rows or columns fail
(`deviations.txt`: `native:smlnj*@* | Array2.*/no-[rc]*`, `nothing-*`,
`row/Subscript-no-rows`), and its section `array2/no-elements-writes` ends
the run with a segmentation fault. In `xc2:smlnj-legacy`, which compiles
SML/NJ's own library with Rune (`tests/basis/xc2`), Rune's machine checks
every array access, so that section ran to the end and its laws showed
which operations go wrong. The `fold` and `modify` cases that `204968a`
leaves turned up while testing the backport against the suite.
