# MLKit 4.7.23: `Real.fromLargeInt` rounds more than once and can miss the nearest real

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Real.sml` is identical to 4.7.23's.

## Summary

* **The trigger:** `Real.fromLargeInt i` for an `i` of more than 53
  significant bits whose low bits decide the rounding, such as
  2^100 + 2^47 + 1.
* **What goes wrong:** `fromLargeInt` splits `i` into parts of 30 bits,
  converts each and combines them with floating-point `*` and `+`, rounding
  at every step. 2^100 + 2^47 + 1 lies just above the midpoint of the reals
  2^100 and 2^100 + 2^48, and should become 2^100 + 2^48; after the first
  rounding has dropped the `+ 1`, the midpoint is rounded to even, and the
  result is 2^100.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html):
  "If i cannot be exactly represented as a real value, then the current
  rounding mode is used to determine the resulting value" -- one rounding
  of `i`, to nearest by default.

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* 2^100 + 2^47 lies half-way between the reals 2^100 and 2^100 + 2^48;
   one more is above the half-way point, so to nearest it is 2^100 + 2^48. *)
fun pow2 n = Real.fromManExp {man = 1.0, exp = n}
val i = IntInf.+ (IntInf.+ (IntInf.pow (2, 100), IntInf.pow (2, 47)), 1)
val r = Real.fromLargeInt i
fun exact r = Real.fmt StringCvt.EXACT r
val () = print ("i                                 = " ^ IntInf.toString i ^ "\n")
val () = print ("Real.fromLargeInt i               = " ^ exact r ^ "\n")
val () = print ("2^100 + 2^48 (expected)           = " ^ exact (pow2 100 + pow2 48) ^ "\n")
val () = print ("2^100                             = " ^ exact (pow2 100) ^ "\n")
val () = print ("Real.fromString (IntInf.toString i) = " ^ exact (valOf (Real.fromString (IntInf.toString i))) ^ "\n")
val () = print ("fromLargeInt i = 2^100 + 2^48: " ^ Bool.toString (Real.== (r, pow2 100 + pow2 48)) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
i                                 = 1267650600228229542234191560705
Real.fromLargeInt i               = 0.12676506002282294E31
2^100 + 2^48 (expected)           = 0.12676506002282297E31
2^100                             = 0.12676506002282294E31
Real.fromString (IntInf.toString i) = 0.12676506002282297E31
fromLargeInt i = 2^100 + 2^48: false
```

`Real.fromString`, which hands the digits to `strtod`, gets it right.

## The cause

`basis/Real.sml`, line 87:

```sml
    fun fromLargeInt i =
        let val N_i = 1073741824  (* pow2 30 *)
            val N = IntInf.fromInt N_i
            val N_r = real N_i
            val op < = IntInf.<
            fun fromLargePos i =
                if N < i then
                  let val factor = IntInf.div(i, N)
                      val rem = IntInf.-(i, IntInf.*(factor, N))
                      val factor_r = fromLargePos factor
                      val rem_r = fromLargePos rem
                  in N_r * factor_r + rem_r
                  end
                else real (Int.fromLarge i)
        in if i < 0 then ~ (fromLargePos (IntInf.~ i))
           else fromLargePos i
        end
```

Here `factor` = 2^70 + 2^17 (54 significant bits) is itself rounded, to
2^70 (a tie, to even); `N_r * factor_r` is then 2^100 and `+ 1.0` cannot
move it. Each `+` rounds, so the information below the 53 bits kept at the
first rounding (the "sticky bit") is lost. Converting the magnitude and
negating also makes the directed rounding modes round the wrong way for a
negative `i`: under `IEEEReal.TO_NEGINF`, `fromLargeInt (~(2^53 + 1))` is
`~0.9007199254740992E16` (-2^53, towards zero) where `Real.fromString` of
the same digits gives `~0.9007199254740994E16` (-(2^53 + 2)).

## The fix

Round once, by giving the decimal digits to the runtime's `strtod`, which
`Real.scan` already uses and which rounds correctly in the current rounding
mode (with its sign) and gives an infinity beyond `maxFinite`:

```diff
--- a/basis/Real.sml
+++ b/basis/Real.sml
@@
-    fun fromLargeInt i =
-        let val N_i = 1073741824  (* pow2 30 *)
-            ...
-        in if i < 0 then ~ (fromLargePos (IntInf.~ i))
-           else fromLargePos i
-        end
+    (* "the current rounding mode is used": strtod rounds the whole
+       number once, in the current mode, and overflows to an infinity *)
+    fun fromLargeInt i =
+        strtod_ (String.translate (fn #"~" => "-" | c => String.str c) (IntInf.toString i))
```

Tested as a standalone function built on `Real.fromString` (which calls the
same `strtod`) in a program built with MLKit 4.7.23, not as a patch of the
library: 2^100 + 2^47 + 1 gives 2^100 + 2^48, 2^100 + 2^47 gives 2^100,
2^53 + 1 gives 2^53, -10^400 gives `negInf`, -7 gives `~7.0`, and
-(2^53 + 1) under `TO_NEGINF` gives -(2^53 + 2). It costs
a decimal conversion of `i`; an exact binary conversion with a sticky bit
would avoid that.

## Relation to Rune

The check `Real.fromLargeInt/sticky-bit` of `tests/basis/real.sml` fails on
MLKit with "got 1.26765060023E30, expected 1.26765060023E30" (the two reals
differ beyond the 12 digits printed); `Real.fromLargeInt/tie-without-sticky-bit`
passes. Proposed line of `tests/basis/deviations.txt`:

```
native:mlkit@* | Real.fromLargeInt/sticky-bit | HOST-BUG | fromLargeInt adds up the reals of 30-bit parts, rounding at each step: 2^100 + 2^47 + 1 becomes 2^100, not 2^100 + 2^48
```
