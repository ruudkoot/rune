# MLKit 4.7.23: `Real.toDecimal` of a NaN always has `sign = false`

**Class 4 of 4: the specification can be read more than one way here:** the introduction of the `REAL` page says that the Library ignores the sign of a NaN, while `signBit` and `toDecimal` speak of it. MLton, SML/NJ and Poly/ML report the sign.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Real.sml` is identical to 4.7.23's. The behaviour
is deliberate (a comment says "a NaN has no sign to report"); this report
argues that the specification asks otherwise.

## Summary

* **The trigger:** `Real.toDecimal r` for a NaN `r` whose sign bit is set,
  such as `Real.copySign (nan, ~1.0)` (`Real.signBit` of it is `true`).
* **What goes wrong:** the result has `sign = false`.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html)
  of `toDecimal`: "For toDecimal, when the r is not normal or subnormal,
  then the exp field is set to 0 and the digits field is the empty list. In
  all cases, the sign and class field capture the sign and class of r."
  The sign of a NaN is observable: `signBit r` "returns true if and only if
  the sign of r (infinities, zeros, and NaN, included) is negative", and
  `fromDecimal` of a `NAN` class "generates a signed NaN". (The page's
  introduction says the Library models NaNs "as a single value ... ignoring
  the sign bit"; the sentences above, which name NaNs and "all cases", are
  the ones that speak of `toDecimal` and `signBit`.)

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
val nan = Real.posInf - Real.posInf
val negNan = Real.copySign (nan, ~1.0)
val posNan = Real.copySign (nan, 1.0)
fun sign r = Bool.toString (#sign (Real.toDecimal r))
val () = print ("Real.signBit negNan = " ^ Bool.toString (Real.signBit negNan)
                ^ ", #sign (Real.toDecimal negNan) = " ^ sign negNan ^ "   (expected true)\n")
val () = print ("Real.signBit posNan = " ^ Bool.toString (Real.signBit posNan)
                ^ ", #sign (Real.toDecimal posNan) = " ^ sign posNan ^ "\n")
val () = print ("for comparison, #sign (Real.toDecimal Real.negInf) = " ^ sign Real.negInf ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
Real.signBit negNan = true, #sign (Real.toDecimal negNan) = false   (expected true)
Real.signBit posNan = false, #sign (Real.toDecimal posNan) = false
for comparison, #sign (Real.toDecimal Real.negInf) = true
```

## The cause

`basis/Real.sml`, `toDecimal` (line 307):

```sml
          in case class r of
                 (* a NaN has no sign to report: fmt writes every NaN as "nan" *)
                 NAN => {class = NAN, sign = false, digits = [], exp = 0}
               | INF => {class = INF, sign = signBit r, digits = [], exp = 0}
               | ZERO => {class = ZERO, sign = signBit r, digits = [], exp = 0}
```

`fmt` writing every NaN as `"nan"` is required ("NaN values are converted
to the string "nan""), but `IEEEReal.toString`, not `toDecimal`, is where
that happens: `IEEEReal.toString` of a `NAN` class is `"nan"` whatever the
sign, so `fmt EXACT` would still print `"nan"` with the sign kept.

## The fix

```diff
--- a/basis/Real.sml
+++ b/basis/Real.sml
@@ fun toDecimal r =
-                 (* a NaN has no sign to report: fmt writes every NaN as "nan" *)
-                 NAN => {class = NAN, sign = false, digits = [], exp = 0}
+                 (* "In all cases, the sign and class field capture the sign
+                    and class of r"; fmt EXACT still writes "nan", as
+                    IEEEReal.toString does for every NaN *)
+                 NAN => {class = NAN, sign = signBit r, digits = [], exp = 0}
```

Tested as a standalone copy (a wrapper that sets `sign` to `signBit r`) in
a program built with MLKit 4.7.23, with `Real` shadowed: all 306 checks of
Rune's `tests/basis/real_fmt.sml` pass with it and the fixes of the other
reports on `fmt` and `fromDecimal`, among them `Real.fmt/EXACT-negative-nan`
(`"nan"`), which MLKit passes today. The patch of the library itself was
not built.

## Relation to Rune

The check `Real.toDecimal/negative-nan` of `tests/basis/real_fmt.sml`
(section `decimal-nan`) fails on MLKit ("false"). MLton 20241230, SML/NJ
110.99.9 and Poly/ML 5.9.2 all give `sign = true` for this NaN (Poly/ML
fails the check for another reason, `exp = 1`, which has its own line). Proposed line of `tests/basis/deviations.txt`:

```
native:mlkit@* | Real.toDecimal/negative-nan | HOST-BUG | toDecimal gives sign = false for every NaN ("In all cases, the sign and class field capture the sign and class of r")
```
