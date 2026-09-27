# MLKit 4.7.23: `Word.fromLargeInt` raises `Overflow` for a negative number below ~2^63

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton, SML/NJ and Poly/ML take the low-order bits.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same `basis/IntInfRep.sml` as 4.7.23 (the files are identical), so
the bug is not fixed there either.

Related upstream: [#116](https://github.com/melsman/mlkit/issues/116), fixed
by [#117](https://github.com/melsman/mlkit/pull/117) in 2022, made
`Word64.fromLargeInt` convert large positive numbers. The negative numbers
of this report still raise `Overflow`.

## Summary

* **The trigger:** `Word.fromLargeInt i`, `Word32.fromLargeInt i`,
  `Word64.fromLargeInt i` (`LargeWord` is `Word64`, `SysWord` is `Word`)
  or `Word8.fromLargeInt i`, where `i` is negative and `i < ~2^63`.
* **What goes wrong:** the call raises `Overflow`. Negative numbers from
  `~2^63` up, and positive numbers of any size, are converted correctly.
* **Required behaviour:** the
  [Basis `WORD` specification](https://smlfamily.github.io/Basis/word.html)
  says of `fromLargeInt i`: "converts i of type LargeInt.int to a value of
  type word. This has the effect of taking the low-order wordSize bits of
  the 2's complement representation of i." No exception is specified; the
  conversion is defined for every `LargeInt.int` (MLKit's `LargeInt` is
  `IntInf`, which is unbounded).

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
(* Word.fromLargeInt, Word32.fromLargeInt and Word64.fromLargeInt (= LargeWord)
   raise Overflow for a negative argument below ~2^63.  The specification:
   "converts i of type LargeInt.int to a value of type word. This has the
   effect of taking the low-order wordSize bits of the 2's complement
   representation of i."  Every call below should return a word. *)
fun show name toString f =
  print (name ^ " = " ^ (toString (f ()) handle e => "raises " ^ exnName e) ^ "\n")

val two32 = IntInf.pow (2, 32)
val two63 = IntInf.pow (2, 63)
val two64 = IntInf.pow (2, 64)

val () = print ("Word.wordSize = " ^ Int.toString Word.wordSize ^ "\n")
(* expected results in the comments: the low-order wordSize bits *)
val () = show "Word64.fromLargeInt ~1           " Word64.toString (fn () => Word64.fromLargeInt (~1))          (* FFFFFFFFFFFFFFFF *)
val () = show "Word64.fromLargeInt (~2^63)      " Word64.toString (fn () => Word64.fromLargeInt (~two63))      (* 8000000000000000 *)
val () = show "Word64.fromLargeInt (~2^63 - 1)  " Word64.toString (fn () => Word64.fromLargeInt (~two63 - 1))  (* 7FFFFFFFFFFFFFFF *)
val () = show "Word64.fromLargeInt (~2^64 + 5)  " Word64.toString (fn () => Word64.fromLargeInt (~two64 + 5))  (* 5 *)
val () = show "Word64.fromLargeInt (2^64 + 5)   " Word64.toString (fn () => Word64.fromLargeInt (two64 + 5))   (* 5 *)
val () = show "Word.fromLargeInt (~2^63 - 3)    " Word.toString   (fn () => Word.fromLargeInt (~two63 - 3))    (* 7FFFFFFFFFFFFFFD *)
val () = show "Word.fromLargeInt (2^63 + 5)     " Word.toString   (fn () => Word.fromLargeInt (two63 + 5))     (* 5 *)
val () = show "Word32.fromLargeInt (~2^64 - 1)  " Word32.toString (fn () => Word32.fromLargeInt (~two64 - 1))  (* FFFFFFFF *)
val () = show "Word32.fromLargeInt (~2^32 - 3)  " Word32.toString (fn () => Word32.fromLargeInt (~two32 - 3))  (* FFFFFFFD *)
val () = show "Word8.fromLargeInt (~2^64 - 1)   " Word8.toString  (fn () => Word8.fromLargeInt (~two64 - 1))   (* FF *)
```

```
$ mlkit -o bug bug.mlb
[reading source file:	bug.sml]
[wrote X64 code file:	MLB/RI_GC/bug.sml.s]
[wrote X64 code file:	MLB/RI_GC/base-link_objects.s]
[wrote executable file:	bug]
$ ./bug
Word.wordSize = 63
Word64.fromLargeInt ~1            = FFFFFFFFFFFFFFFF
Word64.fromLargeInt (~2^63)       = 8000000000000000
Word64.fromLargeInt (~2^63 - 1)   = raises Overflow
Word64.fromLargeInt (~2^64 + 5)   = raises Overflow
Word64.fromLargeInt (2^64 + 5)    = 5
Word.fromLargeInt (~2^63 - 3)     = raises Overflow
Word.fromLargeInt (2^63 + 5)      = 5
Word32.fromLargeInt (~2^64 - 1)   = raises Overflow
Word32.fromLargeInt (~2^32 - 3)   = FFFFFFFD
Word8.fromLargeInt (~2^64 - 1)    = raises Overflow
```

`Word.wordSize` is 63, so the low-order `wordSize` bits of `~2^63 - 3` are
`0wx7FFFFFFFFFFFFFFD`.

## The cause

Every `fromLargeInt` goes through `IntInfRep.toWord64`
(`Word.fromLargeInt` is `IntInfRep.toWord i`, which is
`w64_w (toWord64 x)`; `Word32.fromLargeInt` is `IntInfRep.toWord32`,
`w64_w32 (toWord64 x)`; `Word8.fromLargeInt` goes through
`Word.fromLargeInt`). `toWord64` is `intInfToW64`, in
`basis/IntInfRep.sml`:

```sml
	fun intInfToW64 (_IntInf{digits=[], ...}) = 0w0
	  | intInfToW64 (_IntInf{negative=false, digits}) = natInfToW64 digits
	  | intInfToW64 (_IntInf{negative=true, digits}) =
            let val i = natInfToI64 digits
	    in i64_w64 (~i)
            end handle _ =>
                       if digits = bigNatMinNeg64() then i64_w64 (minNeg64())
		       else raise Overflow
```

A non-negative number is converted with `natInfToW64`, which computes in
`word64` and so wraps modulo 2^64. A negative number is instead converted
with `natInfToI64`, in checked `int64` arithmetic, which overflows as soon
as the magnitude is 2^63 or more; the handler lets through exactly
`~2^63` and raises `Overflow` for everything below it.

## The fix

Negate the wrapped magnitude in `word64`, as the positive case already
wraps:

```diff
--- a/basis/IntInfRep.sml
+++ b/basis/IntInfRep.sml
@@ -373,11 +373,9 @@
 	fun intInfToW64 (_IntInf{digits=[], ...}) = 0w0
 	  | intInfToW64 (_IntInf{negative=false, digits}) = natInfToW64 digits
 	  | intInfToW64 (_IntInf{negative=true, digits}) =
-            let val i = natInfToI64 digits
-	    in i64_w64 (~i)
-            end handle _ =>
-                       if digits = bigNatMinNeg64() then i64_w64 (minNeg64())
-		       else raise Overflow
+            (* the low-order 64 bits of the 2's complement: the magnitude
+               modulo 2^64 (natInfToW64 wraps), negated modulo 2^64 *)
+            0w0 - natInfToW64 digits
```

**Tested:** with this change applied to a copy of MLKit 4.7.23's library
(`SML_LIB` pointing at the copy, which MLKit then recompiles), `bug.sml`
prints the values in the comments above for every line, and the Rune test
programs `word`, `word8`, `intn_word16`, `intn_word32` and `intn_word64`
(below) pass all their checks. Not tried against a build of `master`.
The copy of the library had the fixes of the other reports of this
investigation applied as well (`Word.scan/0w-read-as-hex-prefix`,
`Word.fromLargeInt/Overflow-on-negative`, `IntInf.scan/*`,
`PackWord32Big.subVecX/no-sign-extension`, the `LargeIntVector` fix and
the runtime fix of `Int32.mod/SIGFPE-minInt-by-minus-one`); the Rune
programs were those the matrix compiled, `intn_word16` without its
`constants` section (`Int8.int/not-overloaded`).

## Relation to Rune

Rune's Basis Library suite checks `fromLargeInt` with numbers below
`~2^wordSize` in `tests/basis/fn/word_fn.sml` (Rune at `3d83f11`),
run for `Word` by `tests/basis/word.sml` and for `Word32` and `Word64` by
`tests/basis/intn_word32.sml` and `tests/basis/intn_word64.sml`:

* `fromLargeInt/minus-two-to-the-wordSize-minus-three` (line 193),
  `~2^wordSize - 3`: fails for `Word` (63 bits) and `Word64`;
* `fromLargeInt/minus-two-to-twice-the-wordSize-minus-one` (line 197),
  `~2^(2 wordSize) - 1`: fails for `Word`, `Word32` and `Word64`;
* `fromLargeInt/minus-multiple-K` (line 438), a random word minus
  `(K + 1) * 2^wordSize`: fails for `Word` for K = 1..39 and for `Word64`
  for K = 0..39.

The expected values are derived from `Word.wordSize`, so they already
allow for MLKit's 63-bit `word`. The failures are explained in
`tests/basis/deviations.txt` by

```
native:mlkit@* | Word*.fromLargeInt/minus-* | HOST-BUG | fromLargeInt raises Overflow for a number below ~2^63 instead of taking its low-order wordSize bits: IntInfRep.toWord64 converts a negative number through a checked int64 (a positive one wraps modulo 2^64)
```
