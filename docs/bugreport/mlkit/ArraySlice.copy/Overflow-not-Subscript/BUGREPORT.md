# MLKit 4.7.23: `ArraySlice.copy`, `copyVec` and the other array copies raise `Overflow` instead of `Subscript`

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** Poly/ML raises `Overflow` in the `copy` of the slices, and SML/NJ in `Array.copy`; MLton raises `Subscript`.

## Status: not reported upstream

It has not been reported upstream from here, and a search of the issues of
[melsman/mlkit](https://github.com/melsman/mlkit/issues) (`Subscript
Overflow slice copy`, `Subscript exception`) found no report of it.
MLKit's `master` at `c49fbea` (2026-09-25) has the same
`basis/TableSlice.sml`, `basis/ByteSlice.sml`,
`basis/wordtable-functors.sml` and `basis/polytable.sml` as 4.7.23, byte
for byte, so the bug is not fixed there either.

## Summary

* **The trigger:** `copy {src, dst, di}` or `copyVec {src, dst, di}` with
  `di` so large that `di + |src|` is beyond `Int.maxInt`, for example
  `di = Int.maxInt` and a non-empty `src`, in
  * `ArraySlice`, `CharArraySlice`, `Word8ArraySlice` and the slices of the
    other monomorphic arrays (`IntArraySlice`, `RealArraySlice`,
    `WordArraySlice`, `Int8ArraySlice`, ...), and
  * `Array` and the monomorphic arrays other than `CharArray` and
    `Word8Array` (`IntArray`, `RealArray`, `WordArray`, ...).
* **What goes wrong:** they raise `Overflow`.
* **Required behaviour:** `Subscript`. The
  [Basis `ARRAY_SLICE` specification](https://smlfamily.github.io/Basis/array-slice.html)
  says of `copy` and `copyVec`: "These functions copy the given slice into
  the array dst, with the i(th) element of src, for 0 <= i < |src|, being
  copied to position di + i in the destination array. If di < 0 or if |dst|
  < di+|src|, then the Subscript exception is raised." The
  [`ARRAY` specification](https://smlfamily.github.io/Basis/array.html)
  gives `Array.copy` and `copyVec` the same condition, and `MONO_ARRAY` and
  `MONO_ARRAY_SLICE` take theirs from these. `|dst| < di+|src|` is a
  condition on the numbers, which holds here, not on their sum as an `int`.
* **`CharArray.copy` and `Word8Array.copy` already do this right**
  (`basis/ByteTable.sml` compares `n > n_dst - di`); `CharArraySlice` and
  `Word8ArraySlice` do not.

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
(* MLKit: copy and copyVec with a destination index di so large that
   di + |src| is beyond Int.maxInt. |dst| < di + |src|, so each call must
   raise Subscript. *)
fun try (what : string) (f : unit -> unit) =
  print (what ^ ": " ^ ((f (); "no exception") handle e => "raised " ^ exnName e) ^ "\n")
val di = valOf Int.maxInt

val () = try "ArraySlice.copy" (fn () =>
  ArraySlice.copy {src = ArraySlice.slice (Array.array (8, 0), 2, SOME 4), dst = Array.array (6, 0), di = di})
val () = try "ArraySlice.copyVec" (fn () =>
  ArraySlice.copyVec {src = VectorSlice.slice (Vector.tabulate (8, fn i => i), 2, SOME 4), dst = Array.array (6, 0), di = di})
val () = try "CharArraySlice.copy" (fn () =>
  CharArraySlice.copy {src = CharArraySlice.slice (CharArray.array (8, #"a"), 2, SOME 4), dst = CharArray.array (8, #"b"), di = di})
val () = try "CharArraySlice.copyVec" (fn () =>
  CharArraySlice.copyVec {src = CharVectorSlice.full "abcd", dst = CharArray.array (8, #"b"), di = di})
val () = try "Word8ArraySlice.copy" (fn () =>
  Word8ArraySlice.copy {src = Word8ArraySlice.slice (Word8Array.array (8, 0w1), 2, SOME 4), dst = Word8Array.array (8, 0w2), di = di})
val () = try "IntArraySlice.copy" (fn () =>
  IntArraySlice.copy {src = IntArraySlice.slice (IntArray.array (8, 1), 2, SOME 4), dst = IntArray.array (8, 2), di = di})
val () = try "IntArraySlice.copyVec" (fn () =>
  IntArraySlice.copyVec {src = IntVectorSlice.full (IntVector.fromList [1, 2, 3, 4]), dst = IntArray.array (8, 2), di = di})
val () = try "RealArraySlice.copy" (fn () =>
  RealArraySlice.copy {src = RealArraySlice.slice (RealArray.array (8, 1.0), 2, SOME 4), dst = RealArray.array (8, 2.0), di = di})
(* the same condition in the array structures *)
val () = try "Array.copy" (fn () =>
  Array.copy {src = Array.array (4, 0), dst = Array.array (6, 0), di = di})
val () = try "Array.copyVec" (fn () =>
  Array.copyVec {src = Vector.tabulate (4, fn i => i), dst = Array.array (6, 0), di = di})
val () = try "IntArray.copy" (fn () =>
  IntArray.copy {src = IntArray.array (4, 0), dst = IntArray.array (6, 0), di = di})
val () = try "RealArray.copyVec" (fn () =>
  RealArray.copyVec {src = RealVector.fromList [1.0, 2.0], dst = RealArray.array (6, 0.0), di = di})
(* for contrast: ByteTable.sml checks n > |dst| - di *)
val () = try "CharArray.copy (for contrast)" (fn () =>
  CharArray.copy {src = CharArray.array (4, #"a"), dst = CharArray.array (6, #"b"), di = di})
val () = try "Word8Array.copyVec (for contrast)" (fn () =>
  Word8Array.copyVec {src = Word8Vector.fromList [0w1, 0w2], dst = Word8Array.array (6, 0w0), di = di})
```

```
$ mlkit -o bug bug.mlb && ./bug
ArraySlice.copy: raised Overflow
ArraySlice.copyVec: raised Overflow
CharArraySlice.copy: raised Overflow
CharArraySlice.copyVec: raised Overflow
Word8ArraySlice.copy: raised Overflow
IntArraySlice.copy: raised Overflow
IntArraySlice.copyVec: raised Overflow
RealArraySlice.copy: raised Overflow
Array.copy: raised Overflow
Array.copyVec: raised Overflow
IntArray.copy: raised Overflow
RealArray.copyVec: raised Overflow
CharArray.copy (for contrast): raised Subscript
Word8Array.copyVec (for contrast): raised Subscript
```

Every line should say `raised Subscript`.

## The cause

The destination check is written `i2+n > length a2` in four files, with
MLKit's `int` addition, which raises `Overflow` when `i2 + n` is beyond
`Int.maxInt`, before the comparison:

* `basis/TableSlice.sml` (the functor of `ArraySlice`), `copy` line 74 and
  `copyVec` line 93:

  ```sml
  fun copy {src=(a1,i1,n) : 'a slice, dst=a2: 'a table, di=i2} =
    if i2<0 orelse i2+n > length0 a2 then raise Subscript
  ```

* `basis/ByteSlice.sml` (`CharArraySlice`, `Word8ArraySlice`), `copy` line
  68 and `copyVec` line 87, the same test;
* `basis/wordtable-functors.sml`, the functor `WordSlice` (the other
  monomorphic array slices), `copy` line 372 and `copyVec` line 390
  (`i2+n > tlen a2`), and the functor `WordTable` (the other monomorphic
  arrays), `copy` line 136 and `copyVec` line 148 (`i2+n > length a2`);
* `basis/polytable.sml` (the functor of `Array`), `copy` line 100 and
  `copyVec` line 114.

`basis/ByteTable.sml` (`CharArray`, `Word8Array`) writes the test as
`di < 0 orelse n > n_dst - di` (lines 195 and 228), which cannot overflow.

## The fix

Write the test as `ByteTable.sml` does, in the ten places; with `0 <= i2`
and `0 <= length a2`, `length a2 - i2` cannot overflow:

```diff
--- basis/TableSlice.sml
+++ basis/TableSlice.sml
@@ -71,7 +71,7 @@
     end
 
   fun copy {src=(a1,i1,n) : 'a slice, dst=a2: 'a table, di=i2} =
-    if i2<0 orelse i2+n > length0 a2 then raise Subscript
+    if i2<0 orelse n > length0 a2 - i2 then raise Subscript
     else if i1 < i2 then            (* copy from high to low *)
 	   let fun hi2lo (a2,j) =
 	         if j >= 0 then
@@ -90,7 +90,7 @@
   fun copyVec {src : 'a vector_slice, dst=a2: 'a table, di=i2} =
     let val (a1, i1, n) = vector_slice_base src
     in
-	if i2<0 orelse i2+n > length0 a2 then raise Subscript
+	if i2<0 orelse n > length0 a2 - i2 then raise Subscript
 	else
 	    let fun lo2hi (a2,j) = if j < n then
 		  (update0(a2,i2+j,sub_vector0(a1,i1+j)); lo2hi (a2,j+1))
--- basis/ByteSlice.sml
+++ basis/ByteSlice.sml
@@ -65,7 +65,7 @@
       end
 
     fun copy {src=(a1,i1,n) : slice, dst=a2: table, di=i2} =
-	if i2<0 orelse i2+n > length0 a2 then raise Subscript
+	if i2<0 orelse n > length0 a2 - i2 then raise Subscript
 	else if i1 < i2 then		(* copy from high to low *)
 	         let fun hi2lo j =
 		     if j >= 0 then
@@ -84,7 +84,7 @@
     fun copyVec {src : vector_slice, dst=a2: table, di=i2} =
       let val (a1, i1, n) = src
       in
-	if i2<0 orelse i2+n > length0 a2 then raise Subscript
+	if i2<0 orelse n > length0 a2 - i2 then raise Subscript
 	else
 	    let fun lo2hi j = if j < n then
 		(update_unsafe(a2,i2+j,sub_vector_unsafe(a1,i1+j)); lo2hi (j+1))
--- basis/wordtable-functors.sml
+++ basis/wordtable-functors.sml
@@ -133,7 +133,7 @@
 
   fun copy {src=a1:table, dst=a2:table, di=i2} =
       let val n = length a1
-      in if i2<0 orelse i2+n > length a2
+      in if i2<0 orelse n > length a2 - i2
          then raise Subscript
 	 else let fun hi2lo j = (* copy from high to low *)
 		      if j >= 0
@@ -145,7 +145,7 @@
 
   fun copyVec {src=v:vector, dst=a:table, di=i2} =
       let val n = length_vector v
-      in if i2<0 orelse i2+n > length a
+      in if i2<0 orelse n > length a - i2
          then raise Subscript
 	 else let fun lo2hi j =
 		      if j < n then
@@ -369,7 +369,7 @@
         end
 
     fun copy {src=(a1,i1,n) : slice, dst=a2: table, di=i2} =
-        if i2<0 orelse i2+n > tlen a2 then raise Subscript
+        if i2<0 orelse n > tlen a2 - i2 then raise Subscript
         else if i1 < i2 then            (* copy from high to low *)
           let fun hi2lo j =
                   if j >= 0 then (tupd(a2,i2+j,tsub(a1,i1+j));
@@ -387,7 +387,7 @@
 
     fun copyVec {src : vector_slice, dst=a2: table, di=i2} =
       let val (a1, i1, n) = src
-      in if i2<0 orelse i2+n > tlen a2 then raise Subscript
+      in if i2<0 orelse n > tlen a2 - i2 then raise Subscript
          else let fun lo2hi j = if j < n then
                                   (tupd(a2,i2+j,vsub(a1,i1+j));
                                    lo2hi (j+1))
--- basis/polytable.sml
+++ basis/polytable.sml
@@ -97,7 +97,7 @@
   fun copy {src=a1: 'a table, dst=a2: 'a table, di=i2} =
     let val n = length a1
     in
-	if i2<0 orelse i2+n > length a2 then
+	if i2<0 orelse n > length a2 - i2 then
 	    raise Subscript
 	else		(* copy from high to low *)
 	    let fun hi2lo j =
@@ -111,7 +111,7 @@
   fun copyVec {src=v: 'a vector, dst=a: 'a table, di=i2} =
     let val n = length_vector v
     in
-	if i2<0 orelse i2+n > length a then
+	if i2<0 orelse n > length a - i2 then
 	    raise Subscript
 	else
 	    let fun lo2hi j =
```

Tested, but not in a build of MLKit: the four files were copied into
programs (with `Initial.wordtable_maxlen` replaced by its value,
`274877906944 : int`), and `Array`, `ArraySlice`, `CharArraySlice`,
`Word8ArraySlice`, and the `Int` and `Real` vectors, arrays and slices
were bound again to the patched functors as the basis library binds them.
With the change `bug.sml` prints `raised Subscript` on every line, and
Rune's `tests/basis/arrayslice.sml` (1323 checks), `chararrayslice.sml`
(1006), `word8arrayslice.sml` (921) and `array.sml` (1476) pass all their
checks; `mono.int.sml` does too, with the changes of the two reports on
`IntArray2`.

## Relation to Rune

Rune's Basis Library suite checks the slices in the section `overflow` of
`tests/basis/arrayslice.sml` (Rune commit `d180cfa`, lines 591 and 593)
and with `TestMonoArraySliceOverflowFn` of
`tests/basis/fn/mono_array_slice_fn.sml` (line 570), applied in
`chararrayslice.sml`, `word8arrayslice.sml` and the `mono.*` tests. On
MLKit 4.7.23 17 checks fail: `ArraySlice.copy/Subscript-not-Overflow-sum`,
`ArraySlice.copyVec/Subscript-not-Overflow-sum`,
`CharArraySlice.copy/Subscript-not-Overflow`,
`Word8ArraySlice.copy/Subscript-not-Overflow`, and
`<Name>ArraySlice.copy/Subscript-not-Overflow` in each of the 13 `mono.*`
tests that run on MLKit. The suite has no such check of `Array.copy` or the
monomorphic arrays' `copy`, so their part of the bug does not show in it.
The line of `tests/basis/deviations.txt` for them:

```
native:mlkit@* | *ArraySlice.copy*/Subscript-not-Overflow* | HOST-BUG | copy and copyVec raise Overflow instead of Subscript when di + |src| overflows: they check di + |src| > |dst| (TableSlice.sml, ByteSlice.sml, wordtable-functors.sml)
```

Rune's own `ArraySlice` and monomorphic slices are not affected.
