# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Real.nextAfter` flushes subnormal results to zero, and gives NaN from a zero towards an infinity of the other sign

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2); Windows 11 (10.0.22000) |
| Processor | Any |
| System Component | Basis Library |
| Severity | Minor |
| Also present in the "development" version? | Yes: `system/Basis/Implementation/Real/real64.sml` of smlnj/smlnj `a5f3fa7` has the same code (read, not run) |

### Description

* A step of `Real.nextAfter` that should end on a subnormal number ends on
  zero: `nextAfter (minNormalPos, 0.0)` is `0.0` instead of the largest
  subnormal number.
* A step from a zero towards an infinity of the other sign gives NaN:
  `nextAfter (0.0, negInf)` and `nextAfter (~0.0, posInf)`.

This happens on 32 and 64 bits, Linux and Windows. MLton and Poly/ML give
the expected values.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
nextAfter (minNormalPos, 0.0) = 0.0000000000000000E0, expected 2.2250738585072010E~308: WRONG
nextAfter (~minNormalPos, 1.0) = ~0.0000000000000000E0, expected ~2.2250738585072010E~308: WRONG
nextAfter (2.0 * minPos, 0.0) = 0.0000000000000000E0, expected 5.0000000000000000E~324: WRONG
nextAfter (0.0, negInf) = nan, expected ~5.0000000000000000E~324: WRONG
nextAfter (~0.0, posInf) = nan, expected 5.0000000000000000E~324: WRONG
```

### Expected Behavior

The next representable number after `r` in the direction of `t`; subnormal
numbers are representable. The expected values are in each line.

### Steps to Reproduce

```sml
(* Real.nextAfter at the bottom of the range: the step down from the least
   normal real, a step down between subnormal reals, and the step from a zero
   towards an infinity of the other sign. Run: sml bug.sml *)
fun s r = Real.fmt (StringCvt.SCI (SOME 16)) r
fun show (name, r, e) =
      print (concat [name, " = ", s r, ", expected ", s e, ": ",
                     if Real.== (r, e) andalso Real.signBit r = Real.signBit e then "ok" else "WRONG", "\n"])
val () = show ("nextAfter (minNormalPos, 0.0)", Real.nextAfter (Real.minNormalPos, 0.0), Real.minNormalPos - Real.minPos)
val () = show ("nextAfter (~minNormalPos, 1.0)", Real.nextAfter (~Real.minNormalPos, 1.0), ~(Real.minNormalPos - Real.minPos))
val () = show ("nextAfter (2.0 * minPos, 0.0)", Real.nextAfter (2.0 * Real.minPos, 0.0), Real.minPos)
val () = show ("nextAfter (0.0, negInf)", Real.nextAfter (0.0, Real.negInf), ~Real.minPos)
val () = show ("nextAfter (~0.0, posInf)", Real.nextAfter (~0.0, Real.posInf), Real.minPos)
val () = OS.Process.exit OS.Process.success
```

### Additional Information

In `Real/real64.sml`, `stepDn` returns a zero when the decremented bits are
below `0wx0010000000000000`, the bits of `minNormalPos`, so every step down
into the subnormal range is taken for an underflow. A step down from a
nonzero number cannot underflow; from `minPos` it gives 0 by itself.

Also, the case of an infinite `t` comes before the case of a zero `r`. For
`r = 0.0` and `t = negInf` the signs differ, so `stepDn` subtracts 1 from
the bits of 0.0, which wraps to all ones, a NaN.

The patch drops the underflow test and puts the zero case before the
infinite one (after the NaN one). It is against legacy `main` (`6ed5a0a`)
and also applies to 110.99.9:

```diff
diff --git a/base/system/Basis/Implementation/Real/real64.sml b/base/system/Basis/Implementation/Real/real64.sml
index 8646062..22ea1b1 100644
--- a/base/system/Basis/Implementation/Real/real64.sml
+++ b/base/system/Basis/Implementation/Real/real64.sml
@@ -283,30 +283,25 @@ structure Real64Imp : REAL =
                       then fromBits(W64.orb(rSign, infBits))
                       else fromBits(W64.orb(rSign, ef))
                   end
-            (* decrement the magnitude of r by one ulp *)
-            fun stepDn () = let
-                  val ef = W64.andb(rBits, expAndFracMask) - 0w1
-                  in
-                    if (ef < 0wx0010000000000000)
-                      (* underflow, so return ±zero *)
-                      then fromBits rSign
-                      else fromBits(W64.orb(rSign, ef))
-                  end
+            (* decrement the magnitude of r by one ulp; r is not ±0.0 here, and the
+             * step down from the least normal number is the largest subnormal one
+             *)
+            fun stepDn () =
+                  fromBits(W64.orb(rSign, W64.andb(rBits, expAndFracMask) - 0w1))
             in
               if (rExp = expMask)
                 then r  (* r is either a NaN or infinity so return it *)
-              else if (tExp = expMask)
-                then if (tFrac <> 0w0)
-                  then t (* t is a NaN, so return it *)
-                  else if (rSign = tSign)
-                    (* t is infinity with the same sign as r, so make r bigger *)
-                    then stepUp ()
-                    (* t is infinity with the opposite sign as r, so make r smaller *)
-                    else stepDn ()
-              (* both r and t are normal/subnormal numbers *)
+              else if (tExp = expMask) andalso (tFrac <> 0w0)
+                then t (* t is a NaN, so return it *)
               else if (W64.orb(rExp, rFrac) = 0w0)
                 (* rExp = 0 && rFrac = 0 ==> r = ±0.0 *)
                 then fromBits(W64.orb(tSign, 0w1)) (* ± minimum subnormal *)
+              else if (tExp = expMask)
+                then if (rSign = tSign)
+                  (* t is infinity with the same sign as r, so make r bigger *)
+                  then stepUp ()
+                  (* t is infinity with the opposite sign as r, so make r smaller *)
+                  else stepDn ()
               (* bit r and t are non-zero normal/subnormal numbers *)
               else if (rSign <> tSign)
                 (* when different signs, move `r` toward 0 *)
```

Tested with a fixed point for 32 and 64 bits and with cross-compiled x86-unix
and x86-win32 boot files.
