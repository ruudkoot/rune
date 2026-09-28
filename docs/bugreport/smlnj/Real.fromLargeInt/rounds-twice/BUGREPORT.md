# SML/NJ 110.99.9: `Real.fromLargeInt` rounds twice, and rounds a negative number's magnitude

## Status: not reported

The issue trackers have no open report on it (searched 2026-09-28).
Earlier, closed reports on the same function were different bugs:
[#69](https://github.com/smlnj/legacy/issues/69) (large inputs crash) and
[#225](https://github.com/smlnj/legacy/issues/225) (negative results).
smlnj/smlnj at `a5f3fa7` has the same code
(`system/Basis/Implementation/Target64Bit/intinf-to-real64.sml`), so the
2026 series has it too (by reading the code; no 2026 build was run).

**What is worth sending SML/NJ:** a new issue with `bug.sml` and `fix.diff`
(`upstream.md` is the text).

## Summary

* **The trigger:**
  - `Real.fromLargeInt i` for an `i` of more than 62 bits (64-bit build)
    or more than 60 bits (32-bit build), where the conversion rounds more
    than once;
  - in the directed rounding modes, any negative `i` that is not exact.
* **What goes wrong:** the result can differ by one ulp from the correctly
  rounded one.
  - `fromLargeInt (2^115 + 2^62 + 1)` is 2^115, not 2^115 + 2^63.
  - On the 32-bit build, `fromLargeInt (2^100 + 2^47 + 1)` is 2^100, not
    2^100 + 2^48.
  - Under `TO_NEGINF`, `fromLargeInt (~(2^53 + 1))` is -2^53, not
    -(2^53 + 2).
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html):
  "If i cannot be exactly represented as a real value, then the current
  rounding mode is used to determine the resulting value", which is one
  rounding of `i` itself, with its sign.

## Where it happens

`bug.sml` holds 148 known answers, one number in each of the four rounding
modes, with the exact results computed by Python's arbitrary-precision
arithmetic:
* numbers chosen to catch a second rounding: 2^115 + 2^62 + 1,
  2^100 + 2^47 + 1, ties and near-ties;
* random numbers of 54 to 300 bits;
* the negations of all of them.

MLton 20241230 gets all 148 right.

| Build (110.99.9) | wrong of 148 |
|---|---|
| 64-bit release | 34 (7 to nearest, 12 `TO_NEGINF`, 15 `TO_POSINF`) |
| 32-bit release and native fixed point, Linux | 31 |
| 32-bit and 64-bit with `fix.diff` | 0 |

The Windows MSI gets more wrong in the directed modes, because
`IEEEReal.setRoundingMode` has no effect there
([IEEEReal.setRoundingMode/windows-no-op](../../IEEEReal.setRoundingMode/windows-no-op/BUGREPORT.md)).
To nearest, Windows fails the same cases as Linux, and with that report's
fix it fails the same cases in every mode.

```
$ sml bug.sml                           # 110.99.9, 64-bit
TO_NEAREST: fromLargeInt 41538374868278625639929989061148673 = 0x4720000000000000, expected 0x4720000000000001
TO_NEAREST: fromLargeInt ~41538374868278625639929989061148673 = 0xC720000000000000, expected 0xC720000000000001
TO_NEAREST: fromLargeInt 212274721979399028737 = 0x442703CE9DEBD1C4, expected 0x442703CE9DEBD1C5
TO_NEAREST: fromLargeInt 2460397548491222481185404434251777 = 0x46DE53A54FD23C68, expected 0x46DE53A54FD23C69
...
34 of 148 wrong
```

(41538374868278625639929989061148673 is 2^115 + 2^62 + 1.)

## The cause

`system/Basis/Implementation/Target64Bit/intinf-to-real64.sml` converts
the top two 62-bit digits of the number and adds them:

```sml
fun calc (k, d1, d2, []) =
      dosign (Assembly.A.scalb (w2r d1 + rbase * w2r d2, k))
...
| [d1, d2] => dosign (w2r d1 + rbase * w2r d2)
```

The steps that round are these:
* `w2r d2` rounds a digit of up to 62 bits to 53;
* the addition rounds again;
* the digits below the top two are dropped without a sticky bit;
* `dosign` negates after rounding, so `TO_NEGINF` and `TO_POSINF` round a
  negative number the wrong way.

For 2^115 + 2^62 + 1, `d2` is 2^53 + 1, whose conversion is a tie that goes
to 2^53; the `+ 1` below can no longer lift the sum above the midpoint.

The 32-bit version (`Target32Bit/intinf-to-real64.sml`) takes three 30-bit
digits, `w2r d1 + rbase * (w2r d2 + rbase * w2r d3)`, with the same faults.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
rewrites `cvt` for both widths. It takes the 55 bits of the magnitude below
its top, with the lowest set when any bit under them is 1 (a sticky bit). A
55-bit integer with a sticky bit rounds to 53 bits exactly as the whole
number does. The sign goes on before the one rounding: an `Int64` negation
on 64 bits, and on 32 bits two exact parts, `hi * 2^30` and `lo`, each
negated and then added once. `scalb` then scales exactly.

* **64-bit:** a single digit is converted with its sign as an `Int64`,
  which rounds once.
* **32-bit:** one or two digits (up to 60 bits) are added as two exact
  signed parts, which rounds once.

**How it was tested:**
* with the other fixes of this directory, built to a fixed point for 32
  and 64 bits;
* `bug.sml` gives 0 wrong on both;
* Rune's Basis suite has no new failure, and its
  `Real.fromLargeInt/sticky-bit` (32-bit) and
  `Real.fromLargeInt/TO_NEGINF-negative-rounds-down` checks pass.

## How Rune met it

`tests/basis/deviations.txt` lines 159 (`Real.fromLargeInt/sticky-bit`,
32-bit) and 583 (`Real.fromLargeInt/TO_NEGINF-negative-rounds-down`, both
builds). That the 64-bit build also rounds twice turned up while checking
them.
