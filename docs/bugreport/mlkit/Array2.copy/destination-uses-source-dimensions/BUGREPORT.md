# MLKit 4.7.23: `Array2.copy` treats the destination as if it had the source's dimensions

## Status: not reported upstream

It has not been reported upstream from here, and a search of the issues of
[melsman/mlkit](https://github.com/melsman/mlkit/issues) (`Array2`,
`Array2 copy`, `Subscript exception`) found no report of it. MLKit's
`master` at `c49fbea` (2026-09-25) has the same `basis/Array2.sml` as
4.7.23, byte for byte, so the bug is not fixed there either.

## Summary

* **The trigger:** `Array2.copy {src, dst, dst_row, dst_col}` where `dst`
  does not have the dimensions of `#base src`.
* **What goes wrong:** `copy` checks the destination region against the
  number of rows and columns of `#base src` instead of `dst`'s, and writes
  into `dst` as if its rows were as long as those of `#base src`. So
  * a valid destination region in a larger `dst` raises `Subscript`;
  * an invalid one in a smaller `dst` raises nothing, and the elements are
    written past the end of `dst`, into whatever is next in memory (in the
    program below, another array);
  * when the numbers of columns differ, the elements land in the wrong
    places of `dst`;
  * `dst_row` or `dst_col` near `Int.maxInt` raises `Overflow`.
* **Required behaviour:** the
  [Basis `ARRAY2` specification](https://smlfamily.github.io/Basis/array2.html)
  says `copy` "Copies the region src into the array dst, with the element
  at position (#row src, #col src) copied into the destination array at
  position (dst_row,dst_col). If the source region is not valid, then the
  Subscript exception is raised. Similarly, if the derived destination
  region (the source region src translated to (dst_row,dst_col)) is not
  valid in dst, then the Subscript exception is raised."

The copy of the monomorphic two-dimensional arrays (`IntArray2`, ...) has
the first two of these, but writes in the right places (report
`IntArray2.copy/destination-checked-against-source`).

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
(* MLKit: Array2.copy into an array whose dimensions differ from those of
   the source region's base array *)
fun try (what : string) (f : unit -> string) =
  print (what ^ ":\n    " ^ (f () handle e => "raised " ^ exnName e) ^ "\n")
fun show (a : int Array2.array) : string =
  "[" ^ String.concatWith " / "
    (List.tabulate (Array2.nRows a, fn i =>
       String.concatWith " " (List.tabulate (Array2.nCols a, fn j => Int.toString (Array2.sub (a, i, j)))))) ^ "]"

(* 3 rows and 4 columns; the source region is its rows 1-2 and columns 1-2,
   11 12 / 21 22 *)
fun src () = Array2.fromList [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]]
fun inner () : int Array2.region = {base = src (), row = 1, col = 1, nrows = SOME 2, ncols = SOME 2}
fun whole () : int Array2.region = {base = src (), row = 0, col = 0, nrows = NONE, ncols = NONE}
(* copyTo (region, (rows, cols), dst_row, dst_col): a zero array of rows x
   cols after the copy of region to (dst_row, dst_col) *)
fun copyTo (reg, (r, c), dr, dc) =
  let val d = Array2.array (r, c, 0)
  in Array2.copy {src = reg, dst = d, dst_row = dr, dst_col = dc}; "no exception, dst = " ^ show d end

val () = try "inner to (1, 2) of 4 x 5, expected [0 0 0 0 0 / 0 0 11 12 0 / 0 0 21 22 0 / 0 0 0 0 0]"
             (fn () => copyTo (inner (), (4, 5), 1, 2))
val () = try "inner to (2, 3) of 4 x 5, expected [0 0 0 0 0 / 0 0 0 0 0 / 0 0 0 11 12 / 0 0 0 21 22]"
             (fn () => copyTo (inner (), (4, 5), 2, 3))
val () = try "whole 3 x 4 to (1, 1) of 4 x 5, expected [0 0 0 0 0 / 0 0 1 2 3 / 0 10 11 12 13 / 0 20 21 22 23]"
             (fn () => copyTo (whole (), (4, 5), 1, 1))
val () = try "whole 3 x 4 to (0, 0) of 3 x 3, expected Subscript"
             (fn () => copyTo (whole (), (3, 3), 0, 0))
val () = try "inner to (0, 0) of 0 x 5, expected Subscript"
             (fn () => copyTo (inner (), (0, 5), 0, 0))
val () = try "inner to (maxInt, 0) of 4 x 5, expected Subscript"
             (fn () => copyTo (inner (), (4, 5), valOf Int.maxInt, 0))

(* The writes of a copy that should have raised Subscript land outside dst:
   here in another array, e. *)
val s = src ()
val d = Array2.array (1, 1, 0)
val e = Array2.array (2, 2, 7)
val () = print ("e before a copy into d: " ^ show e ^ "\n")
val () = try "copy of a 2 x 3 region into the 1 x 1 array d, expected Subscript"
             (fn () => (Array2.copy {src = {base = s, row = 0, col = 0, nrows = SOME 2, ncols = SOME 3},
                                     dst = d, dst_row = 0, dst_col = 0};
                        "no exception"))
val () = print ("e after the copy into d: " ^ show e ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
inner to (1, 2) of 4 x 5, expected [0 0 0 0 0 / 0 0 11 12 0 / 0 0 21 22 0 / 0 0 0 0 0]:
    no exception, dst = [0 0 0 0 0 / 0 11 12 0 0 / 21 22 0 0 0 / 0 0 0 0 0]
inner to (2, 3) of 4 x 5, expected [0 0 0 0 0 / 0 0 0 0 0 / 0 0 0 11 12 / 0 0 0 21 22]:
    raised Subscript
whole 3 x 4 to (1, 1) of 4 x 5, expected [0 0 0 0 0 / 0 0 1 2 3 / 0 10 11 12 13 / 0 20 21 22 23]:
    raised Subscript
whole 3 x 4 to (0, 0) of 3 x 3, expected Subscript:
    no exception, dst = [0 1 2 / 3 10 11 / 12 13 20]
inner to (0, 0) of 0 x 5, expected Subscript:
    no exception, dst = []
inner to (maxInt, 0) of 4 x 5, expected Subscript:
    raised Overflow
e before a copy into d: [7 7 / 7 7]
copy of a 2 x 3 region into the 1 x 1 array d, expected Subscript:
    no exception
e after the copy into d: [10 11 / 12 7]
```

The last copy writes 0 1 2 / 10 11 12 into an array of one element; three
of the words written past its end were, in this run, the elements of `e`,
which the program never passed to `copy`. The same happens, unseen, in the
lines above that print "no exception" where `Subscript` is expected.

## The cause

`copy` in `basis/Array2.sml` (lines 191-207):

```sml
fun copy {src: 'a region, dst: 'a array, dst_row:int, dst_col:int} : unit =
    let val {nR:int,nC:int,rstop:int,cstop:int} = traverseInit src
        val r_reg = rstop - (#row src)
        val c_reg = cstop - (#col src)
        val () = if dst_row < 0 orelse dst_row + r_reg > nR orelse
                    dst_col < 0 orelse dst_col + c_reg > nC
                 then raise Subscript
                 else ()
        val tmp = tabulate RowMajor
                           (r_reg, c_reg,
                            fn(r,c) => sub2(#base src,nC,
                                            r + #row src,
                                            c + #col src))
    in appi RowMajor (fn (r,c,v) =>
                         update2(dst,nC,dst_row+r,dst_col+c,v))
            {base=tmp,row=0,col=0,nrows=NONE,ncols=NONE}
    end
```

`nR` and `nC` are the dimensions of `#base src`, as `traverseInit src`
returns them, and they are used for `dst` twice:

* the destination check compares `dst_row + r_reg` and `dst_col + c_reg`
  with `nR` and `nC` instead of the dimensions of `dst`;
* `update2 (dst, nC, r, c, v)` (lines 27-28) writes the word
  `r*cols+c+2` of the table with `cols = nC`, the length of a row of
  `#base src`, not of `dst`. `update2` is the primitive `word_update0`,
  which does not check the index, so a position beyond `dst` is written
  wherever it is in memory.

`dst_row + r_reg` is also computed with MLKit's `int` addition, which
raises `Overflow` when `dst_row` is near `Int.maxInt`.

## The fix

Use the dimensions of `dst`, and compare `dst_row` with `dR - r_reg`
rather than `dst_row + r_reg` with `dR`:

```diff
--- basis/Array2.sml
+++ basis/Array2.sml
@@ -192,8 +192,9 @@
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
@@ -202,7 +203,7 @@
                                             r + #row src,
                                             c + #col src))
     in appi RowMajor (fn (r,c,v) =>
-                         update2(dst,nC,dst_row+r,dst_col+c,v))
+                         update2(dst,dC,dst_row+r,dst_col+c,v))
             {base=tmp,row=0,col=0,nrows=NONE,ncols=NONE}
     end
```

`dR - r_reg` cannot overflow as long as `r_reg` is not negative. As
4.7.23's `traverseInit` stands, an invalid source region can make it
negative; the fix of `traverseInit` (report
`Array2.appi/invalid-region-accepted`) rejects those regions, and the two
changes belong together.

Tested, but not in a build of MLKit: `basis/Array2.sml` was copied into a
program as a structure of another name (with `Initial.wordtable_maxlen`
replaced by its value, `274877906944 : int`) and bound to `Array2` in front
of the program. With this change alone `bug.sml` prints the expected result
on every line (`e` stays `[7 7 / 7 7]`), and Rune's
`tests/basis/array2.sml` passes the 31 checks this bug fails; with the fix
of `traverseInit` as well it passes all 1255 of its checks.

## Relation to Rune

Rune's Basis Library suite checks `copy` in `tests/basis/array2.sml` (Rune
commit `d180cfa`): the section on `copy` (lines 255-326), the random
samples of the laws (`Array2.copy/model-*` and, for the samples without
elements, `Array2.copy/model-empty-*`, line 590) and the regions without
elements (lines 621-640). On MLKit 4.7.23 31 checks
fail: `Array2.copy/region`, `to-the-first-corner`, `to-the-last-corner`,
`whole-NONE`, `NONE-rows-SOME-cols`, `SOME-rows-NONE-cols`, `field-order`,
`copies-elements-not-the-array`, `Subscript-dst-smaller`,
`Subscript-dst-no-rows`, `Subscript-changes-nothing`, `model-22`,
`model-30`, `model-43`, `nothing-cols-at-the-end`,
`Subscript-dst-nothing-row-beyond`, `Subscript-dst-nothing-cols-too-far`,
12 of the `model-empty-*` and `Subscript-not-Overflow-dst-sum-row` and
`-sum-col`. The line of `tests/basis/deviations.txt` for them (after the
one for `*Array2.copy/Subscript-*src-*`, which explains the other failures
of `copy`):

```
native:mlkit@* | Array2.copy/[!o]* | HOST-BUG | copy checks the destination region against the dimensions of the source's base array instead of those of dst, and writes dst with the source's number of columns as its row length: Subscript for a valid destination, none for an invalid one (the elements are written past the end of dst), the elements in the wrong places when the two arrays have different numbers of columns, and Overflow when dst_row + nrows or dst_col + ncols overflows
```

The checks of copies within one array (`Array2.copy/overlap-*`,
`Array2.copy/within-model-*`) pass: there `dst` is `#base src`. Rune's own
`Array2` (`lib/basis/array2.sml`) is not affected.
