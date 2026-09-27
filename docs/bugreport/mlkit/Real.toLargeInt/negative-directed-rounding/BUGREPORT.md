# MLKit 4.7.23: `Real.toLargeInt` rounds a negative real the wrong way under `TO_NEGINF` and `TO_POSINF`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton, SML/NJ and Poly/ML round a negative real the right way.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Real.sml` is identical to 4.7.23's.

## Summary

* **The trigger:** `Real.toLargeInt IEEEReal.TO_NEGINF r` or
  `Real.toLargeInt IEEEReal.TO_POSINF r` with `r` negative and not an
  integer.
* **What goes wrong:** `toLargeInt` negates a negative `r`, rounds the
  magnitude in the given mode and negates the result, so that `TO_NEGINF`
  rounds towards zero and `TO_POSINF` away from it: `toLargeInt TO_NEGINF
  ~2.5` is `~2`, `toLargeInt TO_POSINF ~2.5` is `~3`. `Real.toInt` with the
  same modes is right.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html)
  says of `toInt mode x` and `toLargeInt mode x`: "These functions convert
  the argument x to an integral type using the specified rounding mode", and `TO_NEGINF` of
  [`IEEEReal`](https://smlfamily.github.io/Basis/ieee-float.html) rounds
  towards negative infinity.

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
fun show (what, expected, i) =
    print (what ^ " = " ^ IntInf.toString i ^ "   (expected " ^ expected ^ ")\n")
val () = show ("Real.toLargeInt TO_NEGINF ~2.5 ", "~3", Real.toLargeInt IEEEReal.TO_NEGINF ~2.5)
val () = show ("Real.toLargeInt TO_POSINF ~2.5 ", "~2", Real.toLargeInt IEEEReal.TO_POSINF ~2.5)
val () = show ("Real.toLargeInt TO_NEGINF ~0.5 ", "~1", Real.toLargeInt IEEEReal.TO_NEGINF ~0.5)
val () = show ("Real.toLargeInt TO_POSINF ~1E10 - 0.5", "~10000000000",
               Real.toLargeInt IEEEReal.TO_POSINF (~1E10 - 0.5))
val () = print ("for comparison, Real.floor ~2.5 = " ^ Int.toString (Real.floor ~2.5)
                ^ ", Real.ceil ~2.5 = " ^ Int.toString (Real.ceil ~2.5)
                ^ ", Real.toInt TO_NEGINF ~2.5 = " ^ Int.toString (Real.toInt IEEEReal.TO_NEGINF ~2.5) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
Real.toLargeInt TO_NEGINF ~2.5  = ~2   (expected ~3)
Real.toLargeInt TO_POSINF ~2.5  = ~3   (expected ~2)
Real.toLargeInt TO_NEGINF ~0.5  = 0   (expected ~1)
Real.toLargeInt TO_POSINF ~1E10 - 0.5 = ~10000000001   (expected ~10000000000)
for comparison, Real.floor ~2.5 = ~3, Real.ceil ~2.5 = ~2, Real.toInt TO_NEGINF ~2.5 = ~3
```

## The cause

`basis/Real.sml`, line 400:

```sml
    fun toLargeInt rm (r:real) =
        let val N_i = 1073741824  (* pow2 30 *)
            ...
            fun toLargePos r =
                if N_r < r then
                  ...
                else Int.toLarge (toInt rm r)
        in if isNan r then raise Domain
           else if r == negInf orelse r == posInf then raise Overflow
           else if r < 0.0 then IntInf.~ (toLargePos (~r))
           else toLargePos r
        end
```

For `r < 0.0` the magnitude `~r` is rounded with `rm` itself. Rounding
`~r` down is rounding `r` up, so the modes `TO_NEGINF` and `TO_POSINF` have
to be exchanged there (`TO_NEAREST` and `TO_ZERO` are symmetric).

## The fix

```diff
--- a/basis/Real.sml
+++ b/basis/Real.sml
@@ fun toLargeInt rm (r:real) =
             val N_r = real N_i
             fun whole r = #whole(split r)
-            fun toLargePos r =
+            fun toLargePos rm r =
                 if N_r < r then
                   let val factor_r = whole(r / N_r)
                       val rem_r = r - factor_r * N_r
-                      val factor = toLargePos factor_r
-                      val rem = toLargePos rem_r
+                      val factor = toLargePos rm factor_r
+                      val rem = toLargePos rm rem_r
                   in IntInf.+(IntInf.*(N, factor), rem)
                   end
                 else Int.toLarge (toInt rm r)
+            (* rounding ~r up is rounding r down *)
+            fun mirror IEEEReal.TO_NEGINF = IEEEReal.TO_POSINF
+              | mirror IEEEReal.TO_POSINF = IEEEReal.TO_NEGINF
+              | mirror m = m
         in if isNan r then raise Domain
            else if r == negInf orelse r == posInf then raise Overflow
-           else if r < 0.0 then IntInf.~ (toLargePos (~r))
-           else toLargePos r
+           else if r < 0.0 then IntInf.~ (toLargePos (mirror rm) (~r))
+           else toLargePos rm r
         end
```

Tested as a standalone copy of the patched function in a program built with
MLKit 4.7.23 (not as a patch of the library): it gives `~3` and `~2` for the
first two lines above, agrees with `floor`, `ceil`, `trunc` and `round` on
300 random reals of magnitude up to 2^28 of both signs, and with
`realFloor`, `realCeil` and `realTrunc` (converted exactly) on 300 random
reals of magnitude up to 2^80.

## Relation to Rune

The checks `Real.toLargeInt/TO_NEGINF-negative` and
`Real.toLargeInt/TO_POSINF-negative` of `tests/basis/real.sml` fail on MLKit
("false"), and so does `Real.toLargeInt/law-agrees-with-toInt`, which
compares `LargeInt.toInt (Real.toLargeInt mode x)` with `floor`, `ceil`,
`trunc` and `round` on random reals of both signs. Proposed lines of
`tests/basis/deviations.txt`:

```
native:mlkit@* | Real.toLargeInt/TO_*INF-negative | HOST-BUG | toLargeInt rounds the magnitude of a negative real in the mode given, so that TO_NEGINF and TO_POSINF are exchanged for it: toLargeInt TO_NEGINF ~2.5 is ~2
native:mlkit@* | Real.toLargeInt/law-agrees-with-toInt | HOST-BUG | toLargeInt rounds the magnitude of a negative real in the mode given, so that TO_NEGINF and TO_POSINF disagree with floor and ceil on negative reals
```
