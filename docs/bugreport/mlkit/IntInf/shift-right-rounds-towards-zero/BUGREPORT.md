# MLKit 4.7.23: `IntInf.~>>` rounds a negative number towards zero: `~>> (~1, 0w1)` is `0`, not `~1`

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** Poly/ML rounds a negative number of more than 62 bits towards zero as well (`~>> (~2^62 - 1, 0w1)`), though it floors the smaller ones, `~>> (~1, 0w1)` among them; MLton and SML/NJ (110.99.9 and 2026.2) floor them all.

## Status

Not reported upstream from here. MLKit `master` at `5bffdc3` (2026-10-09)
has the same `rshift` and `~>>`: its `basis/IntInf.sml` differs from
4.7.23's only in `toInt` and `fromInt` (PR #234), and `fix.patch` applies
to it (72 lines earlier). A search of MLKit's issues and pull requests
(`shift`, `IntInf`, `rshift`, 2026-10-11) found no report of it.

## Summary

* **The trigger:** `IntInf.~>> (i, n)` with `i` negative and `n > 0`,
  where `i` is not a multiple of `2^n`: `~>> (~1, 0w1)`, `~>> (~5, 0w1)`,
  `~>> (~1000000, 0w10)`, `~>> (~2^62 - 1, 0w1)`.
* **What goes wrong:** the result is `|i| div 2^n` with the sign of `i`,
  that is `i quot 2^n`, rounded towards zero: `0`, `~2`, `~976`,
  `~2^61`. A negative number shifted far enough gives `0`, not `~1`.
* **Required behaviour:** the
  [`INT_INF` specification](https://smlfamily.github.io/Basis/int-inf.html):
  "`~>> (i, n)` shifts i to the right by n bit positions. When i and n are
  interpreted as integers, the latter non-negative, this returns
  floor(i / 2^n)." So `~1`, `~3`, `~977` and `~2^61 - 1`; and "The
  bit-wise operations (andb, orb, notb, <<, etc.) treat the integer
  arguments as having 2's complement representation", in which a right
  shift of `~1` is `~1`.

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
   floor(i / 2^n)": ~>> (~1, 0w1) is ~1 and ~>> (~5, 0w1) is ~3.
   IntInf.div, which floors, gives the expected value. *)
fun show (i : IntInf.int, n : word) =
    print ("IntInf.~>> (" ^ IntInf.toString i ^ ", 0w" ^ Word.fmt StringCvt.DEC n ^ ") = "
           ^ IntInf.toString (IntInf.~>> (i, n))
           ^ "   (floor: " ^ IntInf.toString (IntInf.div (i, IntInf.pow (2, Word.toInt n))) ^ ")\n")
val () = show (~1, 0w1)
val () = show (~5, 0w1)
val () = show (~4, 0w1)
val () = show (5, 0w1)
val () = show (~1, 0w20)
val () = show (~1000000, 0w10)
(* -2^62 - 1, beyond a 63-bit int *)
val () = show (IntInf.- (IntInf.~ (IntInf.pow (2, 62)), 1), 0w1)
```

```
$ mlkit -o bug bug.mlb && ./bug
IntInf.~>> (~1, 0w1) = 0   (floor: ~1)
IntInf.~>> (~5, 0w1) = ~2   (floor: ~3)
IntInf.~>> (~4, 0w1) = ~2   (floor: ~2)
IntInf.~>> (5, 0w1) = 2   (floor: 2)
IntInf.~>> (~1, 0w20) = 0   (floor: ~1)
IntInf.~>> (~1000000, 0w10) = ~976   (floor: ~977)
IntInf.~>> (~4611686018427387905, 0w1) = ~2305843009213693952   (floor: ~2305843009213693953)
```

MLton and SML/NJ print the floor on every line; Poly/ML on every line but
the last.

## The cause

`basis/IntInf.sml` (lines 999 to 1032) keeps a number as a sign and the
digits of its magnitude, and `rshift` shifts the digits and keeps the
sign:

```sml
	(* Right shift. *)
	fun rshift (i, w:word) =
	case i of
	    _IntInf { digits = [], negative } => i (* i = 0 *)
	  | _IntInf { digits, negative } => let
		val { bytes, bits } = shiftAmount w
	...
		case digits of
		    [] => _IntInf { negative=false, digits = [] }
		  | _ => _IntInf { negative=negative, digits = digits }
	    end
    end

    val << = lshift
    val ~>> = rshift
```

Shifting the magnitude is `|i| div 2^n`, so the result is
`sign(i) * (|i| div 2^n)`, the quotient rounded towards zero. That is the
floor the specification asks for when `i >= 0`, and one more than it when
`i < 0` and bits that are not zero are shifted out. (`lshift` can work on
the magnitude: `i * 2^n` has no rounding.)

## The fix

Shift a negative `i` as `notb i = ~1 - i`, which is not negative: for
`i < 0`, `floor(i / 2^n) = ~1 - floor((~1 - i) / 2^n)`, that is
`notb (rshift (notb i, n))` (`fix.patch`):

```diff
--- a/basis/IntInf.sml
+++ b/basis/IntInf.sml
@@ -1029,7 +1029,13 @@
     end
 
     val << = lshift
-    val ~>> = rshift
+
+    (* rshift shifts the magnitude, which rounds a negative number towards
+     * zero; ~>> rounds towards negative infinity.  A negative i is shifted
+     * as notb i = ~1 - i, which is not negative:
+     * i div 2^n = notb ((notb i) div 2^n). *)
+    fun ~>> (i as _IntInf { negative = true, ... }, w) = notb (rshift (notb i, w))
+      | ~>> (i, w) = rshift (i, w)
   end
 
 (** SigDoc *)
```

(`notb`, `~(i + 1)`, is defined above `rshift` in the same structure.)

**Tested, not as a build of MLKit:** `INT_INF.sml` and the patched
`IntInf.sml` compiled at the front of a program with MLKit 4.7.23, so that
the patched `IntInf` shadows the library's. `bug.sml` then prints the
floor on every line. A check of `~>> (i, n) = i div 2^n` for 309 numbers
(300 drawn, of up to 300 bits and either sign, and 0, ±1, ±2 and the
numbers around ±2^30) and every `n` from 0 to 400 finds 35,832 wrong of
123,909 with this patch alone, all of them shifts of 30 bits or more,
which are the subject of the report `IntInf/shift-right-by-30-or-more`,
and none with both patches; `<<` is unchanged (0 wrong of 20,000). The
patch of the library itself was not built.

## How it was found

By the laws of Rune's Basis Library documentation: each `Law:` of
`lib/basis/*.sml` is tested on generated values, and
`tests/basis/run-laws-hosts.py` runs them against MLKit's own Basis
Library (`docs/plans/quickcheck-hunt.md`, the sections on the other
compilers). The law of `~>>` in `lib/basis/sig_int_inf.sml`,

```
Law: `~>> (i, n) = i div pow (2, Word.toInt n)`, run for `n` from
`Arb.wordRange (0w0, 0w4095)`
```

fails at `IntInf` on MLKit with the counterexample `~>> (~1, 0w1)`. The
line of `tests/basis/law-deviations.txt`:

```
native:mlkit | INT_INF.~>>/law-1@IntInf | HOST-BUG | IntInf.~>> rounds towards zero: ~>> (~1, 0w1) is 0, not ~1, and so for the negative numbers of more than 62 bits
```

Poly/ML's line for the same law is its own fault beyond 62 bits.
