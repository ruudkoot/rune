# SML/NJ 110.99.9: `Real.nextAfter` flushes subnormal results to zero and gives NaN from a zero towards an infinity of the other sign

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on
`nextAfter` (searched 2026-09-28). It was implemented in `bf1665b`
(2024-03-01); 110.79 raises `Fail "Real.nextAfter unimplemented"`.
smlnj/smlnj at `a5f3fa7` has the same code, so the 2026 series has it too
(by reading the code; no 2026 build was run).

**What is worth sending SML/NJ:** a new issue on smlnj/legacy and
smlnj/smlnj with `bug.sml` and `fix.diff`.

## Summary

* **The trigger:** `Real.nextAfter (r, t)` where the result is subnormal,
  or where `r` is a zero and `t` an infinity of the other sign.
* **What goes wrong:**
  - A step towards zero that should give a subnormal number gives a zero:
    `nextAfter (minNormalPos, 0.0)` is `0.0`, not the largest subnormal
    number.
  - `nextAfter (2.0 * minPos, 0.0)` is `0.0`, not `minPos`.
  - `nextAfter (0.0, negInf)` and `nextAfter (~0.0, posInf)` are NaN, not
    `~minPos` and `minPos`.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html):
  `nextAfter (r, t)` is the next representable number after `r` in the
  direction of `t`; subnormal numbers are representable. MLton and Poly/ML
  give the expected values below.

## Where it happens

| Build (110.99.9) | wrong of 5 |
|---|---|
| 32-bit: Linux and Windows releases, Windows source build (MSVC), native fixed point on Linux, cross-compiled on amd64 | 5 |
| 64-bit release | 5 |
| 32-bit and 64-bit with `fix.diff` | 0 |

```
$ sml bug.sml                           # 110.99.9, 32 or 64 bits
nextAfter (minNormalPos, 0.0) = 0.0000000000000000E0, expected 2.2250738585072010E~308: WRONG
nextAfter (~minNormalPos, 1.0) = ~0.0000000000000000E0, expected ~2.2250738585072010E~308: WRONG
nextAfter (2.0 * minPos, 0.0) = 0.0000000000000000E0, expected 5.0000000000000000E~324: WRONG
nextAfter (0.0, negInf) = nan, expected ~5.0000000000000000E~324: WRONG
nextAfter (~0.0, posInf) = nan, expected 5.0000000000000000E~324: WRONG
```

## The cause

`base/system/Basis/Implementation/Real/real64.sml`, `nextAfter`:

```sml
fun stepDn () = let
      val ef = W64.andb(rBits, expAndFracMask) - 0w1
      in
        if (ef < 0wx0010000000000000)
          (* underflow, so return ±zero *)
          then fromBits rSign
          else fromBits(W64.orb(rSign, ef))
      end
```

* **Subnormals flushed.** `0wx0010000000000000` is the bit pattern of the
  least normal number, so every step down to a subnormal number is taken for
  an underflow. A step down from a nonzero number cannot underflow: the
  step down from `minPos` is 0 by itself.
* **NaN from a zero.** The case of an infinite `t` comes before the case of
  a zero `r`. For `r = 0.0` and `t = negInf` the signs differ, so `stepDn`
  subtracts 1 from the bits of 0.0; the result wraps around to all ones,
  and all ones is a NaN.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9):

* `stepDn` subtracts one from the magnitude's bits and keeps the sign, with
  no underflow test;
* the zero case comes before the infinite `t`, after the NaN `t`, so a zero
  steps to `±minPos` towards any `t`.

**How it was tested:**
* with the other fixes of this directory, built to a fixed point for 32
  and 64 bits and cross-compiled for x86-unix and x86-win32;
* `bug.sml` is right on all of them;
* on the 32-bit build Rune's `lib/test/property`, which draws
  `nextAfter (minNormalPos, 0.0)` among its real edge cases, gives the same
  fingerprint as on Rune, MLton and Poly/ML;
* Rune's Basis suite's `Real.nextAfter` checks still pass.

## How Rune met it

Rune's Basis suite does not check the step into the subnormal range, so no
deviation records it. It was found as the last difference between the
fingerprint of `tests/lib/property/core.sml` on SML/NJ, with the other
fixes of this directory, and on Rune: `Gen.real`'s edge case
`Real.nextAfter (Real.minNormalPos, 0.0)` came out as 0.0.
