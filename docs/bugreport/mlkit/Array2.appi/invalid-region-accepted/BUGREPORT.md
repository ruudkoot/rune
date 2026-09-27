# MLKit 4.7.23: `Array2.appi`, `foldi`, `modifyi` and `copy` accept invalid regions

## Status: not reported upstream

It has not been reported upstream from here, and a search of the issues of
[melsman/mlkit](https://github.com/melsman/mlkit/issues) (`Array2`,
`Array2 copy`, `Subscript exception`) found no report of it. MLKit's
`master` at `c49fbea` (2026-09-25) has the same `basis/Array2.sml` as
4.7.23, byte for byte, so the bug is not fixed there either.

## Summary

* **The trigger:** a region `{base, row, col, nrows, ncols}` given to
  `Array2.appi`, `foldi` or `modifyi`, or as the `src` of `Array2.copy`,
  in which
  * `nrows = NONE` and `row > nRows base` (or `ncols = NONE` and
    `col > nCols base`), or
  * `nrows = SOME nr` with `nr < 0` (or `ncols = SOME nc` with `nc < 0`),
    or
  * `row + nr` (or `col + nc`) is beyond `Int.maxInt`.
* **What goes wrong:** for the first two, `appi`, `foldi` and `modifyi`
  return normally without applying `f` to anything, and `copy` raises
  `Size`. For the third, all four raise `Overflow`.
* **Required behaviour:** none of these regions is valid. The
  [Basis `ARRAY2` specification](https://smlfamily.github.io/Basis/array2.html)
  says: "reg is valid if 0 <= #row reg <= nRows (#base reg) when #nrows reg
  = NONE, or 0 <= #row reg <= (#row reg)+nr <= nRows (#base reg) when #nrows
  reg = SOME(nr), and the analogous conditions hold for columns." Of `appi`,
  `foldi` and `modifyi` it says "If reg is not valid, then the exception
  Subscript is raised", and of `copy` "If the source region is not valid,
  then the Subscript exception is raised."
* A region that runs past the end of the array, such as `row = 2, nrows =
  SOME 2` in an array of 3 rows, is rejected correctly.

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
(* MLKit: Array2.appi, foldi, modifyi and copy on regions that are not valid.
   Every region below is invalid, so each call must raise Subscript. *)
fun try (what : string) (f : unit -> string) =
  print (what ^ ": " ^ (f () handle e => "raised " ^ exnName e) ^ "\n")

(* 3 rows and 4 columns *)
val a = Array2.fromList [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]]
val maxInt = valOf Int.maxInt
fun reg (row, col, nrows, ncols) : int Array2.region =
  {base = a, row = row, col = col, nrows = nrows, ncols = ncols}

fun appi r = (Array2.appi Array2.RowMajor (fn _ => ()) r; "no exception")
fun foldi r =
  Int.toString (Array2.foldi Array2.RowMajor (fn (_, _, _, n) => n + 1) 0 r)
  ^ " elements, no exception"
fun modifyi r = (Array2.modifyi Array2.ColMajor (fn (_, _, x) => x) r; "no exception")
fun copy r =
  (Array2.copy {src = r, dst = Array2.array (8, 8, 0), dst_row = 0, dst_col = 0};
   "no exception")

val () = try "appi    row 4, nrows NONE       (row > nRows)" (fn () => appi (reg (4, 0, NONE, NONE)))
val () = try "foldi   col 5, ncols NONE       (col > nCols)" (fn () => foldi (reg (0, 5, NONE, NONE)))
val () = try "modifyi row maxInt, nrows NONE" (fn () => modifyi (reg (maxInt, 0, NONE, NONE)))
val () = try "appi    row 1, nrows SOME ~1" (fn () => appi (reg (1, 0, SOME ~1, NONE)))
val () = try "foldi   col 1, ncols SOME ~1" (fn () => foldi (reg (0, 1, NONE, SOME ~1)))
val () = try "foldi   col 1, ncols SOME minInt" (fn () => foldi (reg (0, 1, NONE, SOME (valOf Int.minInt))))
val () = try "appi    row 1, nrows SOME maxInt" (fn () => appi (reg (1, 0, SOME maxInt, NONE)))
val () = try "modifyi row maxInt, nrows SOME 1" (fn () => modifyi (reg (maxInt, 0, SOME 1, NONE)))
val () = try "copy    row 4, nrows NONE" (fn () => copy (reg (4, 0, NONE, NONE)))
val () = try "copy    row 1, nrows SOME ~1" (fn () => copy (reg (1, 0, SOME ~1, NONE)))
val () = try "copy    row 1, nrows SOME maxInt" (fn () => copy (reg (1, 0, SOME maxInt, NONE)))
(* for contrast: a region that runs one row past the end *)
val () = try "appi    row 2, nrows SOME 2     (for contrast)" (fn () => appi (reg (2, 0, SOME 2, NONE)))
```

```
$ mlkit -o bug bug.mlb && ./bug
appi    row 4, nrows NONE       (row > nRows): no exception
foldi   col 5, ncols NONE       (col > nCols): 0 elements, no exception
modifyi row maxInt, nrows NONE: no exception
appi    row 1, nrows SOME ~1: no exception
foldi   col 1, ncols SOME ~1: 0 elements, no exception
foldi   col 1, ncols SOME minInt: 0 elements, no exception
appi    row 1, nrows SOME maxInt: raised Overflow
modifyi row maxInt, nrows SOME 1: raised Overflow
copy    row 4, nrows NONE: raised Size
copy    row 1, nrows SOME ~1: raised Size
copy    row 1, nrows SOME maxInt: raised Overflow
appi    row 2, nrows SOME 2     (for contrast): raised Subscript
```

Every line but the last should say `raised Subscript`.

## The cause

`appi`, `foldi` and `modifyi` go through `traverse`, and `copy` starts with
the same check of its source region, `traverseInit` in `basis/Array2.sml`
(lines 108-128):

```sml
fun traverseInit ({base,row,col,nrows,ncols}: 'a region)
    : {nR:int,nC:int,rstop:int,cstop:int} =
    let val () = if row < 0 orelse col < 0 then raise Subscript
                 else ()
        val (nR,nC) = dimensions base
        val rstop = case nrows of
                        SOME nr =>
                        let val rstop = row+nr
                        in if rstop > nR then raise Subscript
                           else rstop
                        end
                      | NONE => nR
        ...
```

It checks `0 <= row` and `row + nr <= nRows`, but not the two other
conditions of a valid region:

* with `nrows = NONE` it does not compare `row` with `nR` at all, so a
  `row` beyond the last row passes, with `rstop = nR < row`;
* with `nrows = SOME nr` it does not check `row <= row + nr`, so a negative
  `nr` passes, with `rstop < row`;
* it computes `row+nr` with MLKit's `int` addition, which raises `Overflow`
  when the sum is beyond `Int.maxInt`, before any comparison.

The loops of `traverseRM` and `traverseCM` then run from `row` up to
`rstop`, that is not at all. `copy` (lines 191-207) makes a temporary array
of `rstop - #row src` rows with `tabulate`, which raises `Size` for the
negative number.

The copy of the monomorphic two-dimensional arrays (`IntArray2`,
`RealArray2`, ..., the functor `WordArray2` of
`basis/wordtable-functors.sml`) has a copy of this function (lines 707-727)
and the same bug; their `appi`, `foldi` and `modifyi` use another check,
`check_region`, which is right but for the overflow. Both are in separate
reports (`IntArray2.copy/destination-checked-against-source`,
`IntArray2.appi/Overflow-not-Subscript`).

## The fix

Check the whole condition, comparing `row` with `nR - nr` rather than
`row + nr` with `nR` (with `0 <= nr` and `0 <= nR`, `nR - nr` cannot
overflow):

```diff
--- basis/Array2.sml
+++ basis/Array2.sml
@@ -107,23 +107,17 @@
 
 fun traverseInit ({base,row,col,nrows,ncols}: 'a region)
     : {nR:int,nC:int,rstop:int,cstop:int} =
-    let val () = if row < 0 orelse col < 0 then raise Subscript
-                 else ()
-        val (nR,nC) = dimensions base
-        val rstop = case nrows of
-                        SOME nr =>
-                        let val rstop = row+nr
-                        in if rstop > nR then raise Subscript
-                           else rstop
-                        end
-                      | NONE => nR
-        val cstop = case ncols of
-                        SOME nc =>
-                        let val cstop = col+nc
-                        in if cstop > nC then raise Subscript
-                           else cstop
-                        end
-                      | NONE => nC
+    let val (nR,nC) = dimensions base
+        (* 0 <= start <= start+n <= size, without computing start+n
+           before it is known to be at most size *)
+        fun stop (start, NONE, size) =
+            if start < 0 orelse start > size then raise Subscript
+            else size
+          | stop (start, SOME n, size) =
+            if start < 0 orelse n < 0 orelse start > size - n then raise Subscript
+            else start + n
+        val rstop = stop (row, nrows, nR)
+        val cstop = stop (col, ncols, nC)
     in {nR=nR,nC=nC,rstop=rstop,cstop=cstop}
     end
```

Tested, but not in a build of MLKit: `basis/Array2.sml` was copied into a
program as a structure of another name (with `Initial.wordtable_maxlen`
replaced by its value, `274877906944 : int`) and bound to `Array2` in front
of the program. With this change `bug.sml` prints `raised Subscript` on
every line, and Rune's `tests/basis/array2.sml` passes the 52 checks this
bug fails; the 31 it still fails are those of the destination of `copy`
(report `Array2.copy/destination-uses-source-dimensions`). With both
changes it passes all 1255 of its checks.

## Relation to Rune

Rune's Basis Library suite checks this in `tests/basis/array2.sml` (Rune
commit `d180cfa`): the invalid regions of the list `invalid` (line 235)
given to `copy` (line 282), `appi` (348), `foldi` (387) and `modifyi`
(423), and the regions whose end is beyond `Int.maxInt` of the section
`overflow` (lines 644-681). On MLKit 4.7.23 52 checks fail:
`Array2.{appi,foldi,modifyi}/Subscript-{row-beyond,col-beyond,row-beyond-no-cols,col-beyond-no-rows,negative-nrows,negative-ncols}`
and `Array2.copy/Subscript-src-*` (no exception, or `Size` for `copy`), and
`Array2.{appi,foldi,modifyi}/Subscript-not-Overflow-{sum-nrows,sum-ncols,sum-row,sum-col,row,col,least-ncols}`
and `Array2.copy/Subscript-not-Overflow-src-*`. The copy of the MONO_ARRAY2
structures fails `<Name>Array2.copy/Subscript-src-*` and
`<Name>Array2.copy/Subscript-not-Overflow-src-*` of
`tests/basis/fn/mono_array2_fn.sml` the same way, in each of the 13
`mono.*` tests with a two-dimensional array. The lines of
`tests/basis/deviations.txt` for them:

```
native:mlkit@* | Array2.*i/Subscript-* | HOST-BUG | appi, foldi and modifyi accept a region whose row is beyond nRows with nrows = NONE or whose nrows is negative (and the same for columns), and traverse nothing, and raise Overflow when row + nrows or col + ncols overflows, instead of raising Subscript
native:mlkit@* | *Array2.copy/Subscript-*src-* | HOST-BUG | copy, of Array2 and of the MONO_ARRAY2 structures, accepts a source region whose row is beyond nRows with nrows = NONE or whose nrows is negative (and the same for columns), and then raises Size, and raises Overflow when row + nrows or col + ncols overflows, instead of raising Subscript
```

Rune's own `Array2` (`lib/basis/array2.sml`) is not affected.
