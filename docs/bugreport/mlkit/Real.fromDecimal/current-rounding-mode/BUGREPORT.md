# MLKit 4.7.23: `Real.fromDecimal` and `Real.toDecimal` convert in the current rounding mode, not to nearest

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Real.sml` is identical to 4.7.23's.

## Summary

* **The trigger:** `Real.fromDecimal` or `Real.toDecimal` called while the
  rounding mode set by `IEEEReal.setRoundingMode` is not `TO_NEAREST`.
* **What goes wrong:** `fromDecimal` hands the digits of the magnitude to
  `strtod`, which rounds in the current mode, and negates afterwards: under
  `TO_NEGINF` both `0.1` and `~0.1` come out as the neighbour of the nearest
  real towards zero (`0.09999999999999999`). `toDecimal` produces its digits
  with `printf` and checks them with `strtod`, both in the current mode:
  under `TO_POSINF` it gives 17 digits for 0.1 (`10000000000000001`)
  instead of the single digit `1`.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html)
  of `toDecimal` and `fromDecimal`: "Decimal approximations are to be
  converted using the IEEEReal.TO_NEAREST rounding mode. toDecimal should
  produce only as many digits as are necessary for fromDecimal to convert
  back to the same number."

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04 (glibc 2.39, whose `printf` and
  `strtod` honour the rounding mode).
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "Decimal approximations are to be converted using the IEEEReal.TO_NEAREST
   rounding mode." *)
fun inMode mode f =
    let val saved = IEEEReal.getRoundingMode ()
    in IEEEReal.setRoundingMode mode; f () before IEEEReal.setRoundingMode saved end
fun dec (sign, digits, exp) =
    valOf (Real.fromDecimal {class = IEEEReal.NORMAL, sign = sign, digits = digits, exp = exp})
fun exact r = Real.fmt StringCvt.EXACT r
fun digits r = String.concat (map Int.toString (#digits (Real.toDecimal r)))
val () = print ("TO_NEAREST: fromDecimal ~0.1 = " ^ exact (dec (true, [1], 0)) ^ "\n")
val () = print ("TO_NEGINF:  fromDecimal ~0.1 = "
                ^ exact (inMode IEEEReal.TO_NEGINF (fn () => dec (true, [1], 0))) ^ "   (expected ~0.1)\n")
val () = print ("TO_NEGINF:  fromDecimal 0.1  = "
                ^ exact (inMode IEEEReal.TO_NEGINF (fn () => dec (false, [1], 0))) ^ "   (expected 0.1)\n")
val () = print ("TO_POSINF:  digits of toDecimal 0.1 = "
                ^ inMode IEEEReal.TO_POSINF (fn () => digits 0.1) ^ "   (expected 1)\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
TO_NEAREST: fromDecimal ~0.1 = ~0.1
TO_NEGINF:  fromDecimal ~0.1 = ~0.9999999999999999E~1   (expected ~0.1)
TO_NEGINF:  fromDecimal 0.1  = 0.9999999999999999E~1   (expected 0.1)
TO_POSINF:  digits of toDecimal 0.1 = 10000000000000001   (expected 1)
```

(`~0.1` is printed by `fmt EXACT` in the default mode; the reals printed
`~0.9999999999999999E~1` are the neighbours of `~0.1` and `0.1` towards
zero.)

## The cause

`basis/Real.sml`, `fromDecimal` (line 317) converts the magnitude and
negates it, in whatever mode is current:

```sml
              fun signed r = if sign then ~r else r
              ...
               | _ => if valid digits then
                        SOME (signed (strtod_ ("0." ^ str digits ^ "e" ^ cstring (Int.toString exp))))
                      else NONE
```

and `toDecimal` (line 279) looks for the shortest digits with the runtime's
`printf` (`to_string_gen ("%." ^ Int.toString p ^ "e")`) and `strtod_`,
again in the current mode. `strtodFloat` and `generalStringOfFloat` in
`src/Runtime/Math.c` call `strtod` and `snprintf` directly.

## The fix

Run both conversions in `TO_NEAREST` and give the sign to `strtod`:

```diff
--- a/basis/Real.sml
+++ b/basis/Real.sml
@@ local
       fun cstring s = String.translate (fn #"~" => "-" | c => String.str c) s
+      (* "Decimal approximations are to be converted using the
+         IEEEReal.TO_NEAREST rounding mode" *)
+      fun nearest f =
+          let val m = IEEEReal.getRoundingMode ()
+          in if m = IEEEReal.TO_NEAREST then f ()
+             else (IEEEReal.setRoundingMode IEEEReal.TO_NEAREST;
+                   (f () before IEEEReal.setRoundingMode m)
+                   handle e => (IEEEReal.setRoundingMode m; raise e))
+          end
@@ fun toDecimal r =
-               | cls => let val (digits, exp) = split (shortest 0)
+               | cls => let val (digits, exp) = split (nearest (fn () => shortest 0))
@@ fun fromDecimal {class, sign, digits, exp} =
                | _ => if valid digits then
-                        SOME (signed (strtod_ ("0." ^ str digits ^ "e" ^ cstring (Int.toString exp))))
+                        SOME (nearest (fn () => strtod_ ((if sign then "-" else "") ^ "0." ^ str digits
+                                                         ^ "e" ^ cstring (Int.toString exp))))
                       else NONE
```

Tested as standalone copies of `fromDecimal` and a wrapper of `toDecimal`
in a program built with MLKit 4.7.23, with `Real` shadowed: under
`TO_NEGINF` `{sign = true, digits = [1], exp = 0}` gives `~0.1`, the mode is
set back afterwards, and all 306 checks of Rune's `tests/basis/real_fmt.sml`
pass with them and the fixes of the other reports on `fmt` and the NaN
signs. The patch of the library itself was not built.

## Relation to Rune

The check `Real.fromDecimal/TO_NEGINF-negative` of
`tests/basis/real_fmt.sml` (section `decimal-rounding-mode`) fails on MLKit
with "got ~0.1, expected ~0.1" (the two reals differ beyond the digits
printed). `Real.fromString/TO_NEGINF-negative`, which reads the sign as
part of the numeral, passes. No check of the suite runs `toDecimal` in
another mode. Proposed line of `tests/basis/deviations.txt`:

```
native:mlkit@* | Real.fromDecimal/TO_NEGINF-negative | HOST-BUG | fromDecimal converts the magnitude in the current rounding mode and negates it, where the specification asks for TO_NEAREST: under TO_NEGINF {sign = true, digits = [1], exp = 0} is ~0.09999999999999999, not ~0.1
```
