# MLKit 4.7.23: `Real.fromDecimal` of a NaN class gives a NaN of the opposite sign

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Real.sml` is identical to 4.7.23's.

## Summary

* **The trigger:** `Real.fromDecimal {class = IEEEReal.NAN, sign = s, ...}`.
* **What goes wrong:** the NaN returned has its sign bit set when `s` is
  `false` and clear when `s` is `true`.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html):
  "For fromDecimal, ... If class is NAN, a signed NaN is generated", with
  the sign of the `sign` field; `signBit` "returns true if and only if the
  sign of r (infinities, zeros, and NaN, included) is negative".

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64 (the processor's default NaN has its sign bit
  set), Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
fun nanOf sign = valOf (Real.fromDecimal {class = IEEEReal.NAN, sign = sign, digits = [], exp = 0})
fun show sign =
    let val r = nanOf sign
    in print ("Real.fromDecimal {class = NAN, sign = " ^ Bool.toString sign ^ ", ...}: isNan "
              ^ Bool.toString (Real.isNan r) ^ ", signBit " ^ Bool.toString (Real.signBit r)
              ^ "   (expected signBit " ^ Bool.toString sign ^ ")\n")
    end
val () = show true
val () = show false
val () = print ("Real.signBit (Real.posInf - Real.posInf) = "
                ^ Bool.toString (Real.signBit (Real.posInf - Real.posInf)) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
Real.fromDecimal {class = NAN, sign = true, ...}: isNan true, signBit false   (expected signBit true)
Real.fromDecimal {class = NAN, sign = false, ...}: isNan true, signBit true   (expected signBit false)
Real.signBit (Real.posInf - Real.posInf) = true
```

## The cause

`basis/Real.sml`, `fromDecimal` (line 317):

```sml
          let open IEEEReal
              fun signed r = if sign then ~r else r
              ...
          in case class of
                 NAN => SOME (signed (posInf - posInf))
```

`posInf - posInf` is the "default NaN" of the x86-64 SSE unit, whose sign
bit is set (the last line of the output). `signed` then negates it for
`sign = true`, which clears the bit, and leaves it set for `sign = false`.

## The fix

Set the sign rather than flip it:

```diff
--- a/basis/Real.sml
+++ b/basis/Real.sml
@@ fun fromDecimal {class, sign, digits, exp} =
-                 NAN => SOME (signed (posInf - posInf))
+                 (* the sign of posInf - posInf is the processor's: set it *)
+                 NAN => SOME (copySign (posInf - posInf, if sign then ~1.0 else 1.0))
```

(`copySign` is defined earlier in `Real.sml`.) Tested as a standalone copy
of `fromDecimal` in a program built with MLKit 4.7.23, with `Real`
shadowed: `sign = true` gives a NaN with `signBit` true, `false` one with
`signBit` false, and all 306 checks of Rune's `tests/basis/real_fmt.sml`
pass with it and the fixes of the other reports on `fmt` and
`toDecimal`. The patch of the library itself was not built.

## Relation to Rune

The checks `Real.fromDecimal/negative-nan` and `Real.fromDecimal/positive-nan`
of `tests/basis/real_fmt.sml` (section `decimal-nan`) fail on MLKit
("false"). MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2 give the sign
asked for. Proposed line of `tests/basis/deviations.txt`:

```
native:mlkit@* | Real.fromDecimal/*-nan | HOST-BUG | fromDecimal of class NAN gives a NaN of the opposite sign: it negates posInf - posInf, whose sign bit the processor sets
```
