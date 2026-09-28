# SML/NJ 110.99.9: `Real.fromManExp` is 0.0 for every result below 2^-1021

## Status: reported and closed as fixed, but still there

* **The report:** [smlnj/legacy#254](https://github.com/smlnj/legacy/issues/254),
  "Real.fromManExp returns zero for small non-zero values" (2022-07-18):
  `Real.fromManExp {man = 1.0, exp = ~1021}` is `0.0`.
* **Closed** the same day as "related to #72 and is already fixed for
  110.99.3 and 2022.1". #72 was about `man = 0.0`.
* **Still there:** 110.99.9 gives #254's own example `0.0`, on every build
  checked, 32-bit and 64-bit, Linux and Windows. smlnj/smlnj at `a5f3fa7`
  has the same code, so the 2026 series has it too (by reading the code; no
  2026 build was run).

**What is worth sending SML/NJ:** a comment on #254, or a new issue that
names it, with `bug.sml` and `fix.diff`, on smlnj/legacy and smlnj/smlnj.

## Summary

* **The trigger:** `Real.fromManExp {man, exp}` whose value is below
  2^-1021 in magnitude: every subnormal number and the numbers from the
  least normal one, 2^-1022, up to 2^-1021. 2^-1021 itself is wrong when
  given as `{man = 1.0, exp = ~1021}` (#254's example), and right as
  `{man = 0.5, exp = ~1020}`.
* **What goes wrong:**
  - The result is `0.0` (or `~0.0`).
  - `fromManExp {man = 0.5, exp = ~1073}` should be `Real.minPos`.
  - `fromManExp (toManExp x)` is not `x` for any `x` below 2^-1021 in
    magnitude.
  - Below 2^-1200 the result is `0.0` even for a negative `man`, where it
    should be `~0.0`.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html):
  `fromManExp {man, exp}` is `man * radix^exp`, rounded; subnormal results
  are values of `real`.

## Where it happens

| Build (110.99.9 unless noted) | wrong of 6 |
|---|---|
| 32-bit: Linux and Windows releases, Windows source build (MSVC), native fixed point on Linux, cross-compiled on amd64 | 6 |
| 64-bit release | 6 |
| Ubuntu's 110.79 (32-bit) | 6 |
| 32-bit and 64-bit with `fix.diff` | 0 |

`bug.sml` makes each expected value by halving a normal number, which is
exact:

```
$ sml bug.sml                           # 110.99.9, 32 or 64 bits
fromManExp {man = 1, exp = ~1021} = 0.0000000000000000E0, expected 4.4501477170144030E~308: WRONG
fromManExp {man = 0.5, exp = ~1021} = 0.0000000000000000E0, expected 2.2250738585072014E~308: WRONG
fromManExp {man = 0.5, exp = ~1073} = 0.0000000000000000E0, expected 5.0000000000000000E~324: WRONG
fromManExp {man = ~0.75, exp = ~1030} = ~0.0000000000000000E0, expected ~6.5187710698453000E~311: WRONG
fromManExp {man = 0.6875, exp = ~1073} = 0.0000000000000000E0, expected 5.0000000000000000E~324: WRONG
fromManExp {man = ~1, exp = ~1300} = 0.0000000000000000E0, expected ~0.0000000000000000E0: WRONG
```

## The cause

`base/system/Basis/Implementation/Real/real64.sml`, `fromManExp'`, for `man`
in [0.5, 1] and `exp < ~1020`:

```sml
else if e < ~1020
     then if e < ~1200 then 0.0
       else let fun f(i,x) = if i=0 then x else f(i-1, x*0.5)
             in f(1020-e, Assembly.A.scalb(m, ~1020))
            end
```

After scaling by 2^-1020, the loop should halve `~1020 - e` times; it
halves `1020 - e` times, 2,040 times too many, which always ends at zero.
Two smaller faults would remain with only that corrected:
* repeated halving rounds at every step once the number is subnormal,
  so a result can be off by one unit: 1.375 * `minPos` becomes 2 * `minPos`,
  not `minPos`;
* `0.0` below 2^-1200 drops the sign.

The loop is there because `scalb` cannot make a subnormal number on every
target. On amd64 (`base/runtime/mach-dep/AMD64.prim.asm`) it builds the
exponent field directly: it returns +0.0 when the result would be
subnormal, and its argument unchanged when that is subnormal. On x86 it is
`FSCALE`, which is exact.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
scales within the normal range, where `scalb` is right on every target, and
multiplies once by 2^-1022 (`minNormalPos`). The multiplication rounds
once, in the current rounding mode, and keeps the sign of a zero:

```sml
else if e < ~1020
     then Assembly.A.scalb(m, if e < ~1222 then ~200 else e + 1022)
            * minNormalPos
```

For `e` in [~1222, ~1021], `m * 2^(e + 1022)` lies in [2^-201, 2], a
normal number. Below that, `m * 2^-1222` is far enough below `minPos` to
round as the exact value would.

On x86 the product is exact in the FPU's extended exponent range and is
rounded once when it is stored as a double.

**How it was tested:**
* with the other fixes of this directory, built to a fixed point for 32
  and 64 bits and cross-compiled for x86-unix and x86-win32;
* `bug.sml` is right on all of them;
* on the 32-bit build, Rune's Basis suite no longer fails
  `Real.fromManExp/minPos`, and Rune's `lib/test/property`, which decodes a
  real's bits with `fromManExp`, gives the same fingerprint as on Rune,
  MLton and Poly/ML;
* on the 64-bit build its core test does the same in the runs that end, but
  some do not, for a bug of that build that the fixes do not touch
  ([README](../../README.md)).

## How Rune met it

`tests/basis/deviations.txt` line 149 (`Real.fromManExp/minPos`, all
SML/NJ builds) and the `property.core` line of `tests/lib/deviations.txt`.
