# MLKit 4.7.23: `copy` of `IntArray2`, `RealArray2`, ... checks the destination against the source array

## Status: not reported upstream

It has not been reported upstream from here, and a search of the issues of
[melsman/mlkit](https://github.com/melsman/mlkit/issues) (`Array2`,
`Array2 copy`, `Subscript exception`) found no report of it. MLKit's
`master` at `c49fbea` (2026-09-25) has the same
`basis/wordtable-functors.sml` as 4.7.23, byte for byte, so the bug is not
fixed there either.

## Summary

This is the `copy` of every MONO_ARRAY2 structure of MLKit: `IntArray2`,
`Int8Array2` ... `Int64Array2`, `WordArray2`, `Word16Array2` ...
`Word64Array2`, `LargeWordArray2`, `RealArray2`, `Real64Array2`,
`LargeRealArray2`, `BoolArray2` (all made by the functor `WordArray2` of
`basis/wordtable-functors.sml`), and `LargeIntArray2`, which is
`Word64Array2`.

* **The trigger:** `copy {src, dst, dst_row, dst_col}` where `dst` does not
  have the dimensions of `#base src`, or where `src` is not a valid region.
* **What goes wrong:**
  * `copy` checks the destination region against the number of rows and
    columns of `#base src` instead of `dst`'s. A valid destination region
    in a larger `dst` raises `Subscript`; an invalid one in a smaller
    `dst` raises nothing, and the elements are written past the end of
    `dst`, into whatever is next in memory (in the program below, another
    array). `dst_row` or `dst_col` near `Int.maxInt` raises `Overflow`.
  * `copy` accepts a source region whose `row` is beyond the last row with
    `nrows = NONE`, or whose `nrows` is negative (and the same for
    columns), and then raises `Size`; when `row + nrows` or `col + ncols`
    is beyond `Int.maxInt` it raises `Overflow`.
* **Required behaviour:** the
  [Basis `MONO_ARRAY2` specification](https://smlfamily.github.io/Basis/mono-array2.html)
  takes its description of `copy` from
  [`ARRAY2`](https://smlfamily.github.io/Basis/array2.html): "Copies the
  region src into the array dst, with the element at position (#row src,
  #col src) copied into the destination array at position
  (dst_row,dst_col). If the source region is not valid, then the Subscript
  exception is raised. Similarly, if the derived destination region (the
  source region src translated to (dst_row,dst_col)) is not valid in dst,
  then the Subscript exception is raised." A region is valid "if 0 <= #row
  reg <= nRows (#base reg) when #nrows reg = NONE, or 0 <= #row reg <=
  (#row reg)+nr <= nRows (#base reg) when #nrows reg = SOME(nr), and the
  analogous conditions hold for columns."

Unlike the polymorphic `Array2.copy` (report
`Array2.copy/destination-uses-source-dimensions`), the elements land in the
right places of `dst` when the copy is allowed: `update_unsafe` takes the
length of a row from `dst`.

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
(* MLKit: IntArray2.copy (and the copy of every MONO_ARRAY2 structure, all
   made by the functor WordArray2) into an array whose dimensions differ from
   those of the source region's base array, and from invalid source regions *)
structure A = IntArray2
fun try (what : string) (f : unit -> string) =
  print (what ^ ":\n    " ^ (f () handle e => "raised " ^ exnName e) ^ "\n")
fun show (a : A.array) : string =
  "[" ^ String.concatWith " / "
    (List.tabulate (A.nRows a, fn i =>
       String.concatWith " " (List.tabulate (A.nCols a, fn j => Int.toString (A.sub (a, i, j)))))) ^ "]"

(* 3 rows and 4 columns; the region inner is its rows 1-2 and columns 1-2,
   11 12 / 21 22 *)
fun src () = A.fromList [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]]
fun reg (row, col, nrows, ncols) : A.region = {base = src (), row = row, col = col, nrows = nrows, ncols = ncols}
fun inner () = reg (1, 1, SOME 2, SOME 2)
fun whole () = reg (0, 0, NONE, NONE)
fun copyTo (r, (m, n), dr, dc) =
  let val d = A.array (m, n, 0)
  in A.copy {src = r, dst = d, dst_row = dr, dst_col = dc}; "no exception, dst = " ^ show d end
val maxInt = valOf Int.maxInt

(* the destination region is valid in dst *)
val () = try "inner to (2, 3) of 4 x 5, expected [0 0 0 0 0 / 0 0 0 0 0 / 0 0 0 11 12 / 0 0 0 21 22]"
             (fn () => copyTo (inner (), (4, 5), 2, 3))
val () = try "whole 3 x 4 to (1, 1) of 4 x 5, expected [0 0 0 0 0 / 0 0 1 2 3 / 0 10 11 12 13 / 0 20 21 22 23]"
             (fn () => copyTo (whole (), (4, 5), 1, 1))
(* the destination region is not valid in dst *)
val () = try "whole 3 x 4 to (0, 0) of 3 x 3, expected Subscript"
             (fn () => copyTo (whole (), (3, 3), 0, 0))
val () = try "inner to (0, 0) of 0 x 5, expected Subscript"
             (fn () => copyTo (inner (), (0, 5), 0, 0))
val () = try "inner to (maxInt, 0) of 4 x 5, expected Subscript"
             (fn () => copyTo (inner (), (4, 5), maxInt, 0))
(* the source region is not valid *)
val () = try "source row 4, nrows NONE (row > nRows), expected Subscript"
             (fn () => copyTo (reg (4, 0, NONE, NONE), (8, 8), 0, 0))
val () = try "source row 1, nrows SOME ~1, expected Subscript"
             (fn () => copyTo (reg (1, 0, SOME ~1, NONE), (8, 8), 0, 0))
val () = try "source row 1, nrows SOME maxInt, expected Subscript"
             (fn () => copyTo (reg (1, 0, SOME maxInt, NONE), (8, 8), 0, 0))
(* the same in RealArray2 *)
val () = try "RealArray2: 1 x 1 to (1, 1) of 2 x 2, expected [0.0 0.0 / 0.0 1.0]"
             (fn () => let val d = RealArray2.array (2, 2, 0.0)
                       in RealArray2.copy {src = {base = RealArray2.array (1, 1, 1.0), row = 0, col = 0, nrows = NONE, ncols = NONE},
                                           dst = d, dst_row = 1, dst_col = 1};
                          "no exception, dst = [" ^ String.concatWith " / "
                            (List.tabulate (2, fn i => String.concatWith " "
                              (List.tabulate (2, fn j => Real.toString (RealArray2.sub (d, i, j)))))) ^ "]"
                       end)

(* The writes of a copy that should have raised Subscript land outside dst:
   here in another array, e. *)
val s = src ()
val d = A.array (1, 1, 0)
val e = A.array (2, 2, 7)
val () = print ("e before a copy into d: " ^ show e ^ "\n")
val () = try "copy of the whole 3 x 4 array into the 1 x 1 array d, expected Subscript"
             (fn () => (A.copy {src = {base = s, row = 0, col = 0, nrows = NONE, ncols = NONE},
                                dst = d, dst_row = 0, dst_col = 0};
                        "no exception"))
val () = print ("e after the copy into d: " ^ show e ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
inner to (2, 3) of 4 x 5, expected [0 0 0 0 0 / 0 0 0 0 0 / 0 0 0 11 12 / 0 0 0 21 22]:
    raised Subscript
whole 3 x 4 to (1, 1) of 4 x 5, expected [0 0 0 0 0 / 0 0 1 2 3 / 0 10 11 12 13 / 0 20 21 22 23]:
    raised Subscript
whole 3 x 4 to (0, 0) of 3 x 3, expected Subscript:
    no exception, dst = [0 1 2 / 10 11 12 / 20 21 22]
inner to (0, 0) of 0 x 5, expected Subscript:
    no exception, dst = []
inner to (maxInt, 0) of 4 x 5, expected Subscript:
    raised Overflow
source row 4, nrows NONE (row > nRows), expected Subscript:
    raised Size
source row 1, nrows SOME ~1, expected Subscript:
    raised Size
source row 1, nrows SOME maxInt, expected Subscript:
    raised Overflow
RealArray2: 1 x 1 to (1, 1) of 2 x 2, expected [0.0 0.0 / 0.0 1.0]:
    raised Subscript
e before a copy into d: [7 7 / 7 7]
copy of the whole 3 x 4 array into the 1 x 1 array d, expected Subscript:
    no exception
e after the copy into d: [21 22 / 23 7]
```

In the copy of a 3 x 4 array into a 3 x 3 one, the last element of each
row is written at the start of the next row of `dst`, where the first
element of that row then overwrites it (3 by 10, 13 by 20), and 23, the
last element, one element past the end of `dst`. The last copy writes twelve
elements into an array of one; in this run three of them ended up as the
elements of `e`, which the program never passed to `copy`.

## The cause

In `basis/wordtable-functors.sml`, the functor `WordArray2` defines `copy`
(lines 729-748) with a local copy of the region check of
`basis/Array2.sml`, `traverseInit` (lines 707-727):

```sml
local
fun traverseInit ({base,row,col,nrows,ncols}: region)
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
in
fun copy {src : region,
          dst : array,
          dst_row : int,
          dst_col : int} : unit =
    let val {nR:int,nC:int,rstop:int,cstop:int} = traverseInit src
        val r_reg = rstop - (#row src)
        val c_reg = cstop - (#col src)
        val () = if dst_row < 0 orelse dst_row + r_reg > nR orelse
                    dst_col < 0 orelse dst_col + c_reg > nC
                 then raise Subscript
                 else ()
        val tmp = tabulate RowMajor
                           (r_reg, c_reg,
                            fn(r,c) => sub_unsafe(#base src,
                                                  r + #row src,
                                                  c + #col src))
    in appi RowMajor (fn (r,c,v) =>
                         update_unsafe(dst,dst_row+r,dst_col+c,v))
            {base=tmp,row=0,col=0,nrows=NONE,ncols=NONE}
    end
```

* `nR` and `nC` are the dimensions of `#base src`, but the destination
  check compares `dst_row + r_reg` and `dst_col + c_reg` with them instead
  of the dimensions of `dst`. `update_unsafe` (lines 678-679) writes the
  element `i*ncols+j` of `dst`'s table with `tupd`, which for `IntArray2`
  is the primitive `__bytetable_update_word` and does not check the index,
  so a position beyond `dst` is written wherever it is in memory.
* `traverseInit` checks `0 <= row` and `row + nr <= nRows` but not
  `row <= nRows` when `nrows = NONE`, nor `0 <= nr` when `nrows = SOME nr`;
  for such a region `r_reg` is negative and `tabulate` raises `Size`.
* `row + nr` and `dst_row + r_reg` are computed with MLKit's `int`
  addition, which raises `Overflow` when the sum is beyond `Int.maxInt`.

The source check is the same code as `Array2`'s (report
`Array2.appi/invalid-region-accepted`). `appi`, `foldi` and `modifyi` of
`WordArray2` do not use it: they check their region with `check_region`
(lines 593-603), which is right but for an overflow (report
`IntArray2.appi/Overflow-not-Subscript`).

## The fix

The same change as in `basis/Array2.sml`: the whole condition of a valid
source region, the dimensions of `dst` for the destination, and no sums
that can overflow:

```diff
--- basis/wordtable-functors.sml
+++ basis/wordtable-functors.sml
@@ -706,23 +706,15 @@
 local
 fun traverseInit ({base,row,col,nrows,ncols}: region)
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
 in
@@ -733,8 +725,9 @@
     let val {nR:int,nC:int,rstop:int,cstop:int} = traverseInit src
         val r_reg = rstop - (#row src)
         val c_reg = cstop - (#col src)
-        val () = if dst_row < 0 orelse dst_row + r_reg > nR orelse
-                    dst_col < 0 orelse dst_col + c_reg > nC
+        val (dR,dC) = dimensions dst
+        val () = if dst_row < 0 orelse dst_row > dR - r_reg orelse
+                    dst_col < 0 orelse dst_col > dC - c_reg
                  then raise Subscript
                  else ()
         val tmp = tabulate RowMajor
```

With the region checked in full, `r_reg` and `c_reg` are not negative, so
`dR - r_reg` and `dC - c_reg` cannot overflow.

Tested, but not in a build of MLKit: `basis/wordtable-functors.sml` was
copied into a program (with `Initial.wordtable_maxlen` replaced by its
value, `274877906944 : int`), and `IntVector`, `IntVectorSlice`,
`IntArray`, `IntArraySlice`, `IntArray2` and `RealArray2` were bound again
to its functors as `basis/inttables.sml` and `basis/wordtables.sml` bind
them. With this change `bug.sml` prints the expected result on every line
(`e` stays `[7 7 / 7 7]`). With it and the changes of the reports
`IntArray2.appi/Overflow-not-Subscript` and
`ArraySlice.copy/Overflow-not-Subscript`, Rune's `tests/basis/mono.int.sml`
passes all 4380 of its checks; with only the `traverseInit` part, or only
the destination part, the checks of the other part still fail.

## Relation to Rune

Rune's Basis Library suite checks the MONO_ARRAY2 structures with the
functors of `tests/basis/fn/mono_array2_fn.sml` (Rune commit `d180cfa`):
`TestMonoArray2Fn` (the section on `copy`, lines 317-381),
`TestMonoArray2LawsFn` (`copy/model-*`, line 688), `TestMonoArray2EmptyFn`
(lines 739-765) and `TestMonoArray2OverflowFn` (lines 796-812), applied in
`tests/basis/mono.<elem>.sml`. On MLKit 4.7.23 36 checks of `copy` fail
in each of the 13 tests `mono.int`, `mono.int8`, `mono.int16`,
`mono.int32`, `mono.int64`, `mono.word`, `mono.word16`, `mono.word32`,
`mono.word64`, `mono.largeword`, `mono.real`, `mono.real64` and
`mono.largereal` (468 in all):

* the destination: `<Name>Array2.copy/to-the-last-corner`, `whole-NONE`,
  `Subscript-dst-smaller`, `Subscript-dst-no-rows`,
  `Subscript-changes-nothing`, `model-43`, `nothing-cols-at-the-end`,
  `Subscript-dst-nothing-row-beyond`, `Subscript-dst-nothing-cols-too-far`,
  12 of the `model-empty-*`, `Subscript-not-Overflow-dst-sum-row` and
  `-sum-col` (23 per test);
* the source: `<Name>Array2.copy/Subscript-src-*` (6) and
  `<Name>Array2.copy/Subscript-not-Overflow-src-*` (7).

(`tests/basis/mono.bool.sml` checks `BoolArray2` with a few checks of its
own, whose copies either have a destination of the source's dimensions or
are invalid in both arrays, and pass; `mono.largeint` does not compile, report
`LargeIntVector/elem-is-Word64`.) The lines of
`tests/basis/deviations.txt` for them:

```
native:mlkit@* | *Array2.copy/Subscript-*src-* | HOST-BUG | copy, of Array2 and of the MONO_ARRAY2 structures, accepts a source region whose row is beyond nRows with nrows = NONE or whose nrows is negative (and the same for columns), and then raises Size, and raises Overflow when row + nrows or col + ncols overflows, instead of raising Subscript
native:mlkit@* | ?*Array2.copy/[!o]* | HOST-BUG | copy of the MONO_ARRAY2 structures checks the destination region against the dimensions of the source's base array instead of those of dst: Subscript for a valid destination, none for an invalid one (the elements are written past the end of dst), and Overflow when dst_row + nrows or dst_col + ncols overflows
```

Rune's own MONO_ARRAY2 structures (`lib/basis/mono_array2_fn.sml`) are not
affected.
