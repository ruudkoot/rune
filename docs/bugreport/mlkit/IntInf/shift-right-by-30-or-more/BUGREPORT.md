# MLKit 4.7.23: `IntInf.~>>` by 30 bits or more gives 0: `~>> (2^40, 0w30)` is `0`, not `1024`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton, SML/NJ (110.99.9 and 2026.2) and Poly/ML give `1024`, and `0` for a shift by 2^31 + 5.

## Status

Not reported upstream from here. MLKit `master` at `5bffdc3` (2026-10-09)
has the same `rshift`: its `basis/IntInf.sml` differs from 4.7.23's only
in `toInt` and `fromInt` (PR #234), and `fix.patch` applies to it (72
lines earlier). A search of MLKit's issues and pull requests (`shift`,
`IntInf`, `rshift`, 2026-10-11) found no report of it.

## Summary

* **The trigger:** `IntInf.~>> (i, n)` with `n >= 0w30` and `|i| >= 2^n`,
  such as `~>> (2^40, 0w30)`, `~>> (2^100, 0w60)` or `~>> (2^62, 0w32)`;
  and `~>> (i, n)` with `n >= 2^31`.
* **What goes wrong:** every shift by 30 bits or more gives `0`, whatever
  the number: `~>> (2^40, 0w30)` is `0`, not `1024`. A shift by `n >= 2^31`
  is a shift by `n mod 2^31` (read as a signed 31-bit number):
  `~>> (1024, 0wx80000005)` is `32`, not `0`.
* **Required behaviour:** the
  [`INT_INF` specification](https://smlfamily.github.io/Basis/int-inf.html):
  "`~>> (i, n)` shifts i to the right by n bit positions. When i and n are
  interpreted as integers, the latter non-negative, this returns
  floor(i / 2^n)."

## Environment

* **MLKit:** v4.7.23 ("MLKit v4.7.23 (v4.7.23 - 2026-09-24T12:26:51+02:00)
  [X64 Backend]"), the official binary release `mlkit-bin-dist-linux.tgz`.
* **System:** Linux x86-64, Ubuntu 24.04 under WSL2 (kernel 6.18), glibc
  2.39.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* IntInf.~>> (i, n) "shifts i to the right by n bit positions.  When i and n
   are interpreted as integers, the latter non-negative, this returns
   floor(i / 2^n)".  The numbers here are not negative, so the floor is the
   quotient (see the report IntInf/shift-right-rounds-towards-zero for
   negative ones). *)
fun show (i : IntInf.int, n : word, expected : string) =
    print ("IntInf.~>> (" ^ IntInf.toString i ^ ", 0w" ^ Word.fmt StringCvt.DEC n ^ ") = "
           ^ IntInf.toString (IntInf.~>> (i, n)) ^ "   (expected " ^ expected ^ ")\n")
val two40 = IntInf.pow (2, 40)
val () = show (two40, 0w29, "2048")
val () = show (two40, 0w30, "1024")
val () = show (two40, 0w31, "512")
val () = show (two40, 0w40, "1")
val () = show (IntInf.pow (2, 100), 0w60, "1099511627776")
val () = show (IntInf.pow (2, 62), 0w32, "1073741824")
(* the amount is not taken modulo 2^31: 2^31 + 5 bits leave nothing of 1024 *)
val () = show (1024, 0wx80000005, "0")
```

```
$ mlkit -o bug bug.mlb && ./bug
IntInf.~>> (1099511627776, 0w29) = 2048   (expected 2048)
IntInf.~>> (1099511627776, 0w30) = 0   (expected 1024)
IntInf.~>> (1099511627776, 0w31) = 0   (expected 512)
IntInf.~>> (1099511627776, 0w40) = 0   (expected 1)
IntInf.~>> (1267650600228229401496703205376, 0w60) = 0   (expected 1099511627776)
IntInf.~>> (4611686018427387904, 0w32) = 0   (expected 1073741824)
IntInf.~>> (1024, 0w2147483653) = 32   (expected 0)
```

MLton, SML/NJ and Poly/ML print the expected value on every line.

## The cause

`basis/IntInf.sml` keeps the magnitude of a number as a list of digits of
`baseBits` = 30 bits, the least significant first. `shiftAmount` (line
959) splits the shift into whole digits (`bytes`) and the bits left over:

```sml
    fun shiftAmount w =
	{ bytes = Int31.div (wtoi(Word31.fromLarge(Word.toLarge w)), baseBits),
	  bits = Int31.mod (wtoi(Word31.fromLarge(Word.toLarge w)), baseBits) }
```

and `rshift` (line 1000) drops `bytes` digits with `drop`, which never
counts down:

```sml
	fun rshift (i, w:word) =
	case i of
	    _IntInf { digits = [], negative } => i (* i = 0 *)
	  | _IntInf { digits, negative } => let
		val { bytes, bits } = shiftAmount w
		val bits' = Int31.-(baseBits, bits)
		fun drop (0, i) = i
		  | drop (n, []) = []
		  | drop (n, x :: xs) = drop (Int31.-(n,0), xs)
```

For a shift of 30 bits or more `bytes` is at least 1, and
`drop (n, x :: xs) = drop (n - 0, xs)` drops every digit, so the result
is 0. `shiftAmount` also keeps only the low 31 bits of the amount
(`Word31.fromLarge`), which `wtoi` reads as a signed number: a shift by
2^31 + 5 is a shift by 5.

(`lshift` uses the same `shiftAmount`, so `IntInf.<< (1, 0wx80000005)` is
`32`; its result would have 2^31 + 5 bits, so the patch below leaves it.)

## The fix

Count `drop` down, and give 0 for a shift by all the bits of the digits or
more before `shiftAmount` sees the amount (`fix.patch`):

```diff
--- a/basis/IntInf.sml
+++ b/basis/IntInf.sml
@@ -1000,12 +1000,17 @@
 	fun rshift (i, w:word) =
 	case i of
 	    _IntInf { digits = [], negative } => i (* i = 0 *)
-	  | _IntInf { digits, negative } => let
+	  | _IntInf { digits, negative } =>
+	    (* a shift by the bits of all the digits or more leaves none of
+	     * them (and keeps w within the 31 bits of shiftAmount) *)
+	    if Word.>= (w, Word.fromInt (Int.* (Int31.toInt baseBits, List.length digits)))
+	    then _IntInf { negative=false, digits = [] }
+	    else let
 		val { bytes, bits } = shiftAmount w
 		val bits' = Int31.-(baseBits, bits)
 		fun drop (0, i) = i
 		  | drop (n, []) = []
-		  | drop (n, x :: xs) = drop (Int31.-(n,0), xs)
+		  | drop (n, x :: xs) = drop (Int31.-(n,1), xs)
 		fun shift [] = ([], 0w0)
 		  | shift (x :: xs) =
 		    let val (zs, borrow) = shift xs
```

`rshift` shifts the magnitude, so a negative number shifted that far gives
0 as well; the patch of the report `IntInf/shift-right-rounds-towards-zero`,
which applies independently, makes it `~1`.

**Tested, not as a build of MLKit:** `INT_INF.sml` and the patched
`IntInf.sml` compiled at the front of a program with MLKit 4.7.23, so that
the patched `IntInf` shadows the library's. `bug.sml` then prints the
expected value on every line. A check of `~>> (i, n) = i div 2^n` for 309
numbers (300 drawn, of up to 300 bits and either sign, and 0, ±1, ±2 and
the numbers around ±2^30) and every `n` from 0 to 400 finds 17,118 wrong
for numbers that are not negative without the patch, none with it, and
none at all with this patch and that of
`IntInf/shift-right-rounds-towards-zero`; `<<` is unchanged (0 wrong of
20,000). The patch of the library itself was not built.

## How it was found

While finding the cause of the report
`IntInf/shift-right-rounds-towards-zero`, which the laws of Rune's Basis
Library documentation found: each `Law:` of `lib/basis/*.sml` is tested on
generated values, and `tests/basis/run-laws-hosts.py` runs them against
MLKit's own Basis Library (`docs/plans/quickcheck-hunt.md`, the sections
on the other compilers). The law of `~>>` in `lib/basis/sig_int_inf.sml`,

```
Law: `~>> (i, n) = i div pow (2, Word.toInt n)`, run for `n` from
`Arb.wordRange (0w0, 0w4095)`
```

fails at `IntInf` on MLKit, and the case shown is the smallest,
`~>> (~1, 0w1)`; a shift of 30 bits or more fails it only for a number of
more than 30 bits, so the one line of `tests/basis/law-deviations.txt` for
the law,

```
native:mlkit | INT_INF.~>>/law-1@IntInf | HOST-BUG | IntInf.~>> rounds towards zero: ~>> (~1, 0w1) is 0, not ~1, and so for the negative numbers of more than 62 bits
```

names only the rounding. Reading `rshift` showed `drop`.

## Runeffi byte encoding confirmation (2026-10-23)

MLKit 4.7.25 still reproduces the same fault through `ForeignBytes.integer`:
64/128-bit signed minima/maxima and unsigned maxima fail their byte round
trips in `tests/lib/ffi/marshal/core.sml`. Six endpoint tests fail; the other
61 marshalling/text/cleanup checks pass. The production encoder uses the
specified `IntInf.~>>` operation without a host-specific workaround. The
native library suite records this existing fault as `HOST-BUG`.
