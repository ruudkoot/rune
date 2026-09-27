# MLKit 4.7.23: `PackWord32Big.subVecX` and `subArrX` do not extend the sign (nor those of `PackWord32Little`)

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton, SML/NJ and Poly/ML extend the sign.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same `basis/Pack32Big.sml` and `basis/Pack32Little.sml` as 4.7.23
(the files are identical), so the bug is not fixed there either.

## Summary

* **The trigger:** `PackWord32Big.subVecX`, `PackWord32Big.subArrX`,
  `PackWord32Little.subVecX` or `PackWord32Little.subArrX` of an element
  whose most significant bit is set.
* **What goes wrong:** the result is the same as that of `subVec` or
  `subArr`: the 32 bits of the element, zero-extended to
  `LargeWord.word`, which has 64 bits in MLKit (`LargeWord` is `Word64`).
* **Required behaviour:** the
  [Basis `PACK_WORD` specification](https://smlfamily.github.io/Basis/pack-word.html):
  "The subVecX version extends the sign bit (most significant bit) when
  converting the subvector to a word" (and `subArrX` likewise). The bytes
  `FF FE FD FC` read big-endian must give `0wxFFFFFFFFFFFEFDFC`, as
  `Word32.toLargeWordX 0wxFFFEFDFC` does.

## Environment

* **MLKit:** v4.7.23 (`MLKit v4.7.23 (v4.7.23 - 2026-09-24T12:26:51+02:00)
  [X64 Backend]`), the official binary release `mlkit-bin-dist-linux.tgz`.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is standalone, built as
  `bug.mlb` (`$(SML_LIB)/basis/basis.mlb` and `bug.sml`) with
  `mlkit -o bug bug.mlb`.

## The program

`bug.sml` (the comments give the values the specification requires):

```sml
(* PackWord32Big.subVecX and subArrX, and those of PackWord32Little, "extend
   the sign bit (most significant bit) when converting the subvector to a
   word".  LargeWord.word has 64 bits, so an element whose bit 31 is set is
   0wxFFFFFFFF........ ; MLKit returns it without the sign extension. *)
val () = print ("LargeWord.wordSize = " ^ Int.toString LargeWord.wordSize ^ "\n")
val bytes = [0wxFF, 0wxFE, 0wxFD, 0wxFC] : Word8.word list
val vec = Word8Vector.fromList bytes
val arr = Word8Array.fromList bytes
fun show name w = print (name ^ " = 0wx" ^ LargeWord.toString w ^ "\n")
val () = show "PackWord32Big.subVec (vec, 0)    " (PackWord32Big.subVec (vec, 0))
val () = show "PackWord32Big.subVecX (vec, 0)   " (PackWord32Big.subVecX (vec, 0))     (* 0wxFFFFFFFFFFFEFDFC *)
val () = show "PackWord32Big.subArrX (arr, 0)   " (PackWord32Big.subArrX (arr, 0))     (* 0wxFFFFFFFFFFFEFDFC *)
val () = show "PackWord32Little.subVecX (vec, 0)" (PackWord32Little.subVecX (vec, 0))  (* 0wxFFFFFFFFFCFDFEFF *)
val () = show "PackWord32Little.subArrX (arr, 0)" (PackWord32Little.subArrX (arr, 0))  (* 0wxFFFFFFFFFCFDFEFF *)
(* for comparison: Word32.toLargeWordX extends the sign of the same 32 bits *)
val () = show "Word32.toLargeWordX 0wxFFFEFDFC  " (Word32.toLargeWordX 0wxFFFEFDFC)
```

```
$ mlkit -o bug bug.mlb
[reading source file:	bug.sml]
[wrote X64 code file:	MLB/RI_GC/bug.sml.s]
[wrote X64 code file:	MLB/RI_GC/base-link_objects.s]
[wrote executable file:	bug]
$ ./bug
LargeWord.wordSize = 64
PackWord32Big.subVec (vec, 0)     = 0wxFFFEFDFC
PackWord32Big.subVecX (vec, 0)    = 0wxFFFEFDFC
PackWord32Big.subArrX (arr, 0)    = 0wxFFFEFDFC
PackWord32Little.subVecX (vec, 0) = 0wxFCFDFEFF
PackWord32Little.subArrX (arr, 0) = 0wxFCFDFEFF
Word32.toLargeWordX 0wxFFFEFDFC   = 0wxFFFFFFFFFFFEFDFC
```

## The cause

`basis/Pack32Big.sml` ("Implementation originates from SML/NJ"), and
`basis/Pack32Little.sml` the same:

```sml
    structure W = LargeWord
    ...
  (* since LargeWord is 32-bits, no sign extension is required *)
    fun subVecX(vec, i) = subVec (vec, i)
    ...
  (* since LargeWord is 32-bits, no sign extension is required *)
    fun subArrX(arr, i) = subArr (arr, i)
```

The code assumes a `LargeWord` of 32 bits, but MLKit's `LargeWord` is
`Word64` (`basis/Word64.sml`: `structure LargeWord : WORD = Word64`), so
bit 31 of the element has to be copied into bits 32 to 63.

## The fix

```diff
--- a/basis/Pack32Big.sml
+++ b/basis/Pack32Big.sml
@@ -40,8 +40,10 @@
 	    mkWord (W8V.sub(vec, k), W8V.sub(vec, k+1),
 	      W8V.sub(vec, k+2), W8V.sub(vec, k+3))
 	  end
-  (* since LargeWord is 32-bits, no sign extension is required *)
-    fun subVecX(vec, i) = subVec (vec, i)
+  (* LargeWord has 64 bits: extend bit 31, the sign of the element *)
+    val extendBy = Word.fromInt (W.wordSize - 32)
+    fun signExtend w = W.~>> (W.<< (w, extendBy), extendBy)
+    fun subVecX(vec, i) = signExtend (subVec (vec, i))
 
     fun subArr (arr, i) = let
 	  val _ = chkIndex (W8A.length arr, i)
@@ -50,8 +52,7 @@
 	    mkWord (W8A.sub(arr, k), W8A.sub(arr, k+1),
 	      W8A.sub(arr, k+2), W8A.sub(arr, k+3))
 	  end
-  (* since LargeWord is 32-bits, no sign extension is required *)
-    fun subArrX(arr, i) = subArr (arr, i)
+    fun subArrX(arr, i) = signExtend (subArr (arr, i))
 
     fun update (arr, i, w) = let
 	  val _ = chkIndex (W8A.length arr, i)
```

and the same lines in `basis/Pack32Little.sml`. The structures are
ascribed `PACK_WORD`, so `extendBy` and `signExtend` stay hidden.

**Tested:** with this change applied to both files of a copy of MLKit
4.7.23's library (`SML_LIB` pointing at the copy), `bug.sml` prints

```
LargeWord.wordSize = 64
PackWord32Big.subVec (vec, 0)     = 0wxFFFEFDFC
PackWord32Big.subVecX (vec, 0)    = 0wxFFFFFFFFFFFEFDFC
PackWord32Big.subArrX (arr, 0)    = 0wxFFFFFFFFFFFEFDFC
PackWord32Little.subVecX (vec, 0) = 0wxFFFFFFFFFCFDFEFF
PackWord32Little.subArrX (arr, 0) = 0wxFFFFFFFFFCFDFEFF
Word32.toLargeWordX 0wxFFFEFDFC   = 0wxFFFFFFFFFFFEFDFC
```

and the Rune test program `pack_word32` (below) passes all its 84 checks.
Not tried against a build of `master`.
The copy of the library had the fixes of the other reports of this
investigation applied as well (`Word.scan/0w-read-as-hex-prefix`,
`Word.fromLargeInt/Overflow-on-negative`, `IntInf.scan/*`,
`PackWord32Big.subVecX/no-sign-extension`, the `LargeIntVector` fix and
the runtime fix of `Int32.mod/SIGFPE-minInt-by-minus-one`); the Rune
programs were those the matrix compiled, `intn_word16` without its
`constants` section (`Int8.int/not-overloaded`).

## Relation to Rune

Rune's Basis Library suite checks `subVecX/sign-extended-K` and
`subArrX/sign-extended-K` (K = 0, 1, 2) in `tests/basis/fn/pack_word_fn.sml`
(lines 59 and 63, Rune at `3d83f11`), run by `tests/basis/pack_word32.sml`
for `PackWord32Big` and `PackWord32Little`; the expected value extends the
sign to `LargeWord.wordSize` bits, whatever that is. All twelve fail on
MLKit. They are explained in `tests/basis/deviations.txt` by

```
native:mlkit@* | PackWord32*.sub[VA]*X/sign-extended-* | HOST-BUG | subVecX and subArrX do not extend the sign: the code, from SML/NJ, assumes a LargeWord of 32 bits ("no sign extension is required"), but MLKit's has 64
```
