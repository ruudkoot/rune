# MLKit 4.7.23: `Real.fmt (GEN _)` and `Real.toString` are C's `%g` with `".0"` added, not the GEN format

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Real.sml` and `src/Runtime/Math.c` are identical
to 4.7.23's. The `".0"` is added on purpose (`mlify` in `basis/Real.sml`,
`stringOfFloat` in `Math.c`), as Poly/ML also does; the choice of notation
is C's.

## Summary

* **The trigger:** `Real.fmt (StringCvt.GEN n) r` or `Real.toString r`
  (which the specification defines as `fmt (GEN NONE)`) for an integral `r`,
  or for an `r` where C's `%g` rule picks the longer notation: 1000.0, 1E10,
  0.001, 0.000125, `GEN (SOME 1)` of 9.6, `GEN (SOME 4)` of 123456.789.
* **What goes wrong:** integral values get a `".0"` that the format forbids
  (`"1.0"`, `"~42.0"`, `"0.0"`, `"10000000000.0"`); the notation is
  chosen by the exponent, as C's `%g` does (scientific when the exponent is
  below -4 or not below the precision), not by length, so `"0.001"` is
  printed where `"1E~3"` is shorter and `"1E1"` where `"10"` is shorter.
* **Required behaviour:** the
  [Basis `StringCvt` specification](https://smlfamily.github.io/Basis/string-cvt.html)
  of `GEN`: "a formatting function to use either the scientific or
  fixed-point notation, whichever is shorter, breaking ties in favor of
  fixed-point. The optional integer value specifies the maximum number of
  significant digits used, with 12 the default. The string should display
  as many significant digits as possible, subject to this maximum. There
  should not be any trailing zeros after the decimal point. There should
  not be a decimal point unless a fractional part is included." The
  [`REAL` page](https://smlfamily.github.io/Basis/real.html): "The value
  returned by toString is equivalent to: (fmt (StringCvt.GEN NONE) r)".

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04 (glibc 2.39).
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "either the scientific or fixed-point notation, whichever is shorter,
   breaking ties in favor of fixed-point ... There should not be a decimal
   point unless a fractional part is included." *)
fun show (what, got, expected) =
    print (what ^ " = " ^ got ^ (if got = expected then "" else "   (expected " ^ expected ^ ")") ^ "\n")
open StringCvt
val () = show ("Real.fmt (GEN NONE) 1.0         ", Real.fmt (GEN NONE) 1.0, "1")
val () = show ("Real.fmt (GEN NONE) ~42.0       ", Real.fmt (GEN NONE) ~42.0, "~42")
val () = show ("Real.fmt (GEN NONE) 0.0         ", Real.fmt (GEN NONE) 0.0, "0")
val () = show ("Real.fmt (GEN NONE) 1000.0      ", Real.fmt (GEN NONE) 1000.0, "1E3")
val () = show ("Real.fmt (GEN NONE) 1E10        ", Real.fmt (GEN NONE) 1E10, "1E10")
val () = show ("Real.fmt (GEN NONE) 1.2345E7    ", Real.fmt (GEN NONE) 1.2345E7, "12345000")
val () = show ("Real.fmt (GEN NONE) 0.001       ", Real.fmt (GEN NONE) 0.001, "1E~3")
val () = show ("Real.fmt (GEN NONE) 0.000125    ", Real.fmt (GEN NONE) 0.000125, "1.25E~4")
val () = show ("Real.fmt (GEN NONE) 0.01        ", Real.fmt (GEN NONE) 0.01, "0.01")
val () = show ("Real.fmt (GEN (SOME 1)) 9.6     ", Real.fmt (GEN (SOME 1)) 9.6, "10")
val () = show ("Real.fmt (GEN (SOME 4)) 123456.789", Real.fmt (GEN (SOME 4)) 123456.789, "123500")
val () = show ("Real.toString 1.0               ", Real.toString 1.0, "1")
val () = show ("Real.toString 1E10              ", Real.toString 1E10, "1E10")
val () = show ("Real.toString 0.000125          ", Real.toString 0.000125, "1.25E~4")
```

```
$ mlkit -o bug bug.mlb && ./bug
Real.fmt (GEN NONE) 1.0          = 1.0   (expected 1)
Real.fmt (GEN NONE) ~42.0        = ~42.0   (expected ~42)
Real.fmt (GEN NONE) 0.0          = 0.0   (expected 0)
Real.fmt (GEN NONE) 1000.0       = 1000.0   (expected 1E3)
Real.fmt (GEN NONE) 1E10         = 10000000000.0   (expected 1E10)
Real.fmt (GEN NONE) 1.2345E7     = 12345000.0   (expected 12345000)
Real.fmt (GEN NONE) 0.001        = 0.001   (expected 1E~3)
Real.fmt (GEN NONE) 0.000125     = 0.000125   (expected 1.25E~4)
Real.fmt (GEN NONE) 0.01         = 0.01
Real.fmt (GEN (SOME 1)) 9.6      = 1E1   (expected 10)
Real.fmt (GEN (SOME 4)) 123456.789 = 1.235E5   (expected 123500)
Real.toString 1.0                = 1.0   (expected 1)
Real.toString 1E10               = 10000000000.0   (expected 1E10)
Real.toString 0.000125           = 0.000125   (expected 1.25E~4)
```

The expected strings follow the text quoted above: `"1E3"` (3 characters)
is shorter than `"1000"`, `"12345000"` and `"1.2345E7"` tie (fixed-point
wins), `"0.01"` and `"1E~2"` tie, and with 4 significant digits 123456.789
is `"123500"` (6) or `"1.235E5"` (7).

## The cause

`basis/Real.sml`, `fmt` (line 334):

```sml
    fun fmt spec =
      let fun mlify s = (* Add ".0" if not "e" or "." in s  *)
              ...
      in
          fn r =>
          case spec of
              ...
            | GEN NONE     => toString r
            | GEN (SOME n) =>
                  if isFinite r then mlify (to_string_gen ("%." ^ Int.toString n ^ "g") r)
                  else toString r
```

and `toString` is `prim ("stringOfFloat", x)`, which in
`src/Runtime/Math.c` is

```c
  sprintf(buf, "%.12g", get_d(arg));
  mkSMLMinus(buf);
  if( countChar('.', buf) == 0 && countChar('E', buf) == 0 && countChar('n', buf) == 0)  // protect for nan and inf
    {
      strcat(buf, ".0");
    }
```

C's `%.Pg` uses scientific notation when the exponent X satisfies X < -4 or
X >= P, and fixed-point otherwise, whatever the lengths; `mlify` and
`stringOfFloat` then add `".0"` to a result without a point or exponent.

## The fix

Take the digits from `%.(n-1)e`, drop the trailing zeros, write them both
ways and keep the shorter (fixed-point on a tie). Inside `fmt` the
arithmetic operators of `Real.sml` are those of `real`, hence `Int.+` etc.:

```diff
--- a/basis/Real.sml
+++ b/basis/Real.sml
@@ fun fmt spec =
-      let fun mlify s = (* Add ".0" if not "e" or "." in s  *)
-              let val stop = size s
-                  fun loop i =          (* s[0..i-1] contains no "." or "e" *)
-                      if i = stop then s ^ ".0"
-                      else if sub_unsafe(s,i) = #"." orelse sub_unsafe(s,i) = #"E" then s
-                      else loop (Int.+ (i, 1))
-              in loop 0 end
+      let (* GEN: the digits of %.(n-1)e without its trailing zeros, in the
+             notation that is shorter, fixed-point on a tie; no point
+             without a fraction *)
+          fun gen n r =
+              if isNan r then "nan"
+              else if not (isFinite r) then (if r > 0.0 then "inf" else "~inf")
+              else
+                let val s = to_string_gen ("%." ^ Int.toString (Int.- (n, 1)) ^ "e") r
+                    val neg = sub_unsafe (s, 0) = #"~"
+                    val s = if neg then String.extract (s, 1, NONE) else s
+                    val (m, e) = case String.fields (fn c => c = #"E") s of
+                                     [m, e] => (m, valOf (Int.fromString e))
+                                   | _ => raise Fail "Real.fmt: GEN"
+                    fun strip (#"0" :: (ds as _ :: _)) = strip ds
+                      | strip ds = ds
+                    val ds = String.implode (List.rev (strip (List.rev
+                                 (List.filter (fn c => c <> #".") (String.explode m)))))
+                    val k = size ds
+                    fun zeros i = CharVector.tabulate (Int.max (i, 0), fn _ => #"0")
+                    val sci = String.substring (ds, 0, 1)
+                              ^ (if Int.> (k, 1) then "." ^ String.extract (ds, 1, NONE) else "")
+                              ^ "E" ^ (if Int.< (e, 0) then "~" ^ Int.toString (Int.~ e) else Int.toString e)
+                    val fix = if Int.>= (e, Int.- (k, 1)) then ds ^ zeros (Int.- (e, Int.- (k, 1)))
+                              else if Int.>= (e, 0)
+                              then String.substring (ds, 0, Int.+ (e, 1)) ^ "." ^ String.extract (ds, Int.+ (e, 1), NONE)
+                              else "0." ^ zeros (Int.- (Int.~ e, 1)) ^ ds
+                in (if neg then "~" else "") ^ (if Int.<= (size fix, size sci) then fix else sci)
+                end
@@
-            | GEN NONE     => toString r
-            | GEN (SOME n) =>
-                  if isFinite r then mlify (to_string_gen ("%." ^ Int.toString n ^ "g") r)
-                  else toString r
+            | GEN NONE     => gen 12 r
+            | GEN (SOME n) => gen n r
             | EXACT => IEEEReal.toString (toDecimal r)
       end
+
+    fun toString r = fmt (StringCvt.GEN NONE) r
```

together with the removal of the earlier `fun toString (x:real) : string =
prim ("stringOfFloat", x)`. The function `gen` was compiled with MLKit
4.7.23 in a structure that rebinds the operators to `real` as `Real.sml`
does, and gives the expected result on 42 cases: every `GEN` and
`toString` expectation of Rune's `tests/basis/real_fmt.sml` (among them
`GEN (SOME 17) 0.1` = `"0.10000000000000001"`, `maxFinite` =
`"1.79769313486E308"`, `~0.0` = `"~0"`), and on the infinities and NaNs.
With `fmt` and `toString` replaced by it (in a structure that shadows
`Real`), all 306 checks of `real_fmt.sml` pass. The patch of the library
itself was not built.

## Relation to Rune

`tests/basis/real_fmt.sml` checks the GEN format against the text above;
on MLKit 22 of its checks fail: `Real.fmt/GEN-integral-*` (one, zero,
negative, hundred, five-digits, rounded, carry, negzero),
`Real.fmt/GEN-notation-*` (thousandth, small-scientific, large,
large-fraction, large-mantissa, thousand, tie-is-fixed, padded,
padded-integer) and `Real.toString/integral-*` and `Real.toString/notation-*`.
Poly/ML fails the same checks and SML/NJ the `GEN-notation` ones, recorded
as `HOST-BUG` in `tests/basis/deviations.txt`. Proposed lines:

```
native:mlkit@* | Real.fmt/GEN-integral-* | HOST-BUG | fmt (GEN _) is C's %g with ".0" added to an integral result: integral values print with ".0" ("1.0", "~0.0"), and 9.6 at one digit is "1E1", not "10"
native:mlkit@* | Real.fmt/GEN-notation-* | HOST-BUG | fmt (GEN _) is C's %g: it chooses the notation by the exponent, not the shorter one ("0.001", "10000000000.0", "1.235E5"), and adds ".0" to an integral value
native:mlkit@* | Real.toString/integral-* | HOST-BUG | toString is C's %.12g with ".0" added to an integral result ("1.0")
native:mlkit@* | Real.toString/notation-* | HOST-BUG | toString is C's %.12g: it chooses the notation by the exponent, not the shorter one ("10000000000.0", "0.000125")
```
