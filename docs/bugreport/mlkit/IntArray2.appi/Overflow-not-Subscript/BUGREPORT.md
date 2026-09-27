# MLKit 4.7.23: `appi`, `foldi` and `modifyi` of `IntArray2`, `RealArray2`, ... raise `Overflow` instead of `Subscript`

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** Poly/ML raises `Overflow` too; MLton raises `Subscript`, and SML/NJ has no `IntArray2`.

## Status: not reported upstream

It has not been reported upstream from here, and a search of the issues of
[melsman/mlkit](https://github.com/melsman/mlkit/issues) (`Array2`,
`Subscript exception`) found no report of it. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/wordtable-functors.sml` as 4.7.23, byte
for byte, so the bug is not fixed there either.

## Summary

This is `appi`, `foldi` and `modifyi` of every MONO_ARRAY2 structure of
MLKit: `IntArray2`, `Int8Array2` ... `Int64Array2`, `WordArray2`,
`Word16Array2` ... `Word64Array2`, `LargeWordArray2`, `RealArray2`,
`Real64Array2`, `LargeRealArray2`, `BoolArray2` (all made by the functor
`WordArray2` of `basis/wordtable-functors.sml`), and `LargeIntArray2`,
which is `Word64Array2`.

* **The trigger:** a region `{base, row, col, nrows = SOME nr, ncols}` in
  which `row` and `nr` are each in range but `row + nr` is beyond
  `Int.maxInt` (or the same for `col` and `ncols`), for example `row = 1`
  and `nr = Int.maxInt`.
* **What goes wrong:** `appi`, `foldi` and `modifyi` raise `Overflow`.
* **Required behaviour:** the region is not valid, and the functions must
  raise `Subscript`. The
  [Basis `MONO_ARRAY2` specification](https://smlfamily.github.io/Basis/mono-array2.html)
  takes their description from
  [`ARRAY2`](https://smlfamily.github.io/Basis/array2.html): "If reg is not
  valid, then the exception Subscript is raised", where "reg is valid if 0
  <= #row reg <= nRows (#base reg) when #nrows reg = NONE, or 0 <= #row reg
  <= (#row reg)+nr <= nRows (#base reg) when #nrows reg = SOME(nr), and the
  analogous conditions hold for columns." The condition is on the numbers,
  not on their sum as an `int`.
* The other invalid regions, `row = Int.maxInt` among them, raise
  `Subscript` as they should.

## Environment

* **MLKit:** v4.7.23 (`mlkit --version`: "MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]"), the official binary release
  `mlkit-bin-dist-linux.tgz`, X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is standalone: `bug.mlb`
  lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, built with
  `mlkit -o bug bug.mlb`; nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* MLKit: IntArray2.appi, foldi and modifyi (and those of every MONO_ARRAY2
   structure, all made by the functor WordArray2) on a region whose end
   row + nrows or col + ncols is beyond Int.maxInt. Every region below is
   invalid, so each call must raise Subscript. *)
fun try (what : string) (f : unit -> unit) =
  print (what ^ ": " ^ ((f (); "no exception") handle e => "raised " ^ exnName e) ^ "\n")
val maxInt = valOf Int.maxInt

(* 3 rows and 4 columns *)
val a = IntArray2.fromList [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]]
fun reg (row, col, nrows, ncols) : IntArray2.region =
  {base = a, row = row, col = col, nrows = nrows, ncols = ncols}

val () = try "IntArray2.appi    row 1, nrows SOME maxInt"
             (fn () => IntArray2.appi IntArray2.RowMajor (fn _ => ()) (reg (1, 0, SOME maxInt, NONE)))
val () = try "IntArray2.foldi   col 1, ncols SOME maxInt"
             (fn () => ignore (IntArray2.foldi IntArray2.ColMajor (fn (_, _, _, n) => n + 1) 0 (reg (0, 1, NONE, SOME maxInt))))
val () = try "IntArray2.modifyi row 1, nrows SOME maxInt"
             (fn () => IntArray2.modifyi IntArray2.RowMajor (fn (_, _, x) => x) (reg (1, 0, SOME maxInt, NONE)))
val () = try "RealArray2.appi   row 1, nrows SOME maxInt"
             (fn () => RealArray2.appi RealArray2.RowMajor (fn _ => ())
                         {base = RealArray2.array (3, 4, 0.0), row = 1, col = 0, nrows = SOME maxInt, ncols = NONE})
val () = try "WordArray2.foldi  col 1, ncols SOME maxInt"
             (fn () => ignore (WordArray2.foldi WordArray2.RowMajor (fn (_, _, _, n) => n + 1) 0
                         {base = WordArray2.array (3, 4, 0w0), row = 0, col = 1, nrows = NONE, ncols = SOME maxInt}))
(* for contrast: row = maxInt, too large by itself *)
val () = try "IntArray2.appi    row maxInt, nrows SOME 1 (for contrast)"
             (fn () => IntArray2.appi IntArray2.RowMajor (fn _ => ()) (reg (maxInt, 0, SOME 1, NONE)))
```

```
$ mlkit -o bug bug.mlb && ./bug
IntArray2.appi    row 1, nrows SOME maxInt: raised Overflow
IntArray2.foldi   col 1, ncols SOME maxInt: raised Overflow
IntArray2.modifyi row 1, nrows SOME maxInt: raised Overflow
RealArray2.appi   row 1, nrows SOME maxInt: raised Overflow
WordArray2.foldi  col 1, ncols SOME maxInt: raised Overflow
IntArray2.appi    row maxInt, nrows SOME 1 (for contrast): raised Subscript
```

Every line should say `raised Subscript`.

## The cause

`appi`, `foldi` and `modifyi` of the functor `WordArray2` check their
region with `check_region`, `basis/wordtable-functors.sml` lines 593-603:

```sml
fun check_region ({base,row,col,nrows,ncols}:region) : unit =
    if row < 0 orelse col < 0 then raise Subscript
    else if row > nRows base orelse col > nCols base then raise Subscript
    else ((case nrows of
               NONE => ()
             | SOME n => if n < 0 orelse n+row > nRows base then raise Subscript
                         else ())
         ; (case ncols of
                NONE => ()
              | SOME n => if n < 0 orelse n+col > nCols base then raise Subscript
                          else ()))
```

It checks every condition of a valid region, but it computes `n+row` and
`n+col` with MLKit's `int` addition, which raises `Overflow` when the sum
is beyond `Int.maxInt`, before the comparison. `row = Int.maxInt` is caught
by the comparison with `nRows base` before any sum, which is why the last
line of the program is right.

## The fix

Compare `row` with `nRows base - n` instead: with `0 <= n` and
`0 <= nRows base` the difference cannot overflow.

```diff
--- basis/wordtable-functors.sml
+++ basis/wordtable-functors.sml
@@ -595,11 +595,11 @@
     else if row > nRows base orelse col > nCols base then raise Subscript
     else ((case nrows of
                NONE => ()
-             | SOME n => if n < 0 orelse n+row > nRows base then raise Subscript
+             | SOME n => if n < 0 orelse row > nRows base - n then raise Subscript
                          else ())
          ; (case ncols of
                 NONE => ()
-              | SOME n => if n < 0 orelse n+col > nCols base then raise Subscript
+              | SOME n => if n < 0 orelse col > nCols base - n then raise Subscript
                           else ()))
```

`trav` computes `row + h` too, but only after `check_region` has passed,
when the sum is at most `nRows base`.

Tested, but not in a build of MLKit: `basis/wordtable-functors.sml` was
copied into a program (with `Initial.wordtable_maxlen` replaced by its
value, `274877906944 : int`), and `IntArray2`, `RealArray2` and
`WordArray2` were bound again to its functors as `basis/inttables.sml` and
`basis/wordtables.sml` bind them. With this change `bug.sml` prints
`raised Subscript` on every line, and with it and the changes of the
reports `IntArray2.copy/destination-checked-against-source` and
`ArraySlice.copy/Overflow-not-Subscript`, Rune's
`tests/basis/mono.int.sml` passes all 4380 of its checks.

## Relation to Rune

Rune's Basis Library suite checks this with `TestMonoArray2OverflowFn` of
`tests/basis/fn/mono_array2_fn.sml` (Rune commit `d180cfa`, lines
774-812), applied in `tests/basis/mono.<elem>.sml`. On MLKit 4.7.23 6
checks fail in each of the 13 tests `mono.int`, `mono.int8`, `mono.int16`,
`mono.int32`, `mono.int64`, `mono.word`, `mono.word16`, `mono.word32`,
`mono.word64`, `mono.largeword`, `mono.real`, `mono.real64` and
`mono.largereal` (78 in all):
`<Name>Array2.{appi,foldi,modifyi}/Subscript-not-Overflow-sum-nrows` and
`-sum-ncols`. The line of `tests/basis/deviations.txt` for them:

```
native:mlkit@* | ?*Array2.*i/Subscript-not-Overflow-sum-n* | HOST-BUG | appi, foldi and modifyi of the MONO_ARRAY2 structures raise Overflow instead of Subscript when row + nrows or col + ncols overflows
```

Rune's own MONO_ARRAY2 structures (`lib/basis/mono_array2_fn.sml`) are not
affected.
