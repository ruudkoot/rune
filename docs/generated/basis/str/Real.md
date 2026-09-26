# structure Real

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; [Structures](../structures.md) &rsaquo; **Real**

|  |  |
| --- | --- |
| Signature | [`REAL`](../sig/REAL.md) |
| Status | required |
| Members | 64 |
| Tests | 553 checks |
| Source | [lib/basis/real.sml](../../../../lib/basis/real.sml) |

## Synopsis

```sml
structure Real : REAL where type real = real
```

Real: IEEE double precision.

## Members

What each means is on [`REAL`](../sig/REAL.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`real`](../sig/REAL.md#type-real) | *a type of its own* |
| val | [`!=`](../sig/REAL.md#val-op-bang-eq) | `real * real -> bool` |
| val | [`*`](../sig/REAL.md#val-op-star) | `real * real -> real` |
| val | [`*+`](../sig/REAL.md#val-op-star-plus) | `real * real * real -> real` |
| val | [`*-`](../sig/REAL.md#val-op-star-minus) | `real * real * real -> real` |
| val | [`+`](../sig/REAL.md#val-op-plus) | `real * real -> real` |
| val | [`-`](../sig/REAL.md#val-op-minus) | `real * real -> real` |
| val | [`/`](../sig/REAL.md#val-op-slash) | `real * real -> real` |
| val | [`<`](../sig/REAL.md#val-op-lt) | `real * real -> bool` |
| val | [`<=`](../sig/REAL.md#val-op-lt-eq) | `real * real -> bool` |
| val | [`==`](../sig/REAL.md#val-op-eq-eq) | `real * real -> bool` |
| val | [`>`](../sig/REAL.md#val-op-gt) | `real * real -> bool` |
| val | [`>=`](../sig/REAL.md#val-op-gt-eq) | `real * real -> bool` |
| val | [`?=`](../sig/REAL.md#val-op-question-eq) | `real * real -> bool` |
| val | [`abs`](../sig/REAL.md#val-abs) | `real -> real` |
| val | [`ceil`](../sig/REAL.md#val-ceil) | `real -> int` |
| val | [`checkFloat`](../sig/REAL.md#val-checkfloat) | `real -> real` |
| val | [`class`](../sig/REAL.md#val-class) | `real -> IEEEReal.float_class` |
| val | [`compare`](../sig/REAL.md#val-compare) | `real * real -> order` |
| val | [`compareReal`](../sig/REAL.md#val-comparereal) | `real * real -> IEEEReal.real_order` |
| val | [`copySign`](../sig/REAL.md#val-copysign) | `real * real -> real` |
| val | [`floor`](../sig/REAL.md#val-floor) | `real -> int` |
| val | [`fmt`](../sig/REAL.md#val-fmt) | `StringCvt.realfmt -> real -> string` |
| val | [`fromDecimal`](../sig/REAL.md#val-fromdecimal) | `{class : IEEEReal.float_class, digits : int list, exp : int, sign : bool} -> real option` |
| val | [`fromInt`](../sig/REAL.md#val-fromint) | `int -> real` |
| val | [`fromLarge`](../sig/REAL.md#val-fromlarge) | `IEEEReal.rounding_mode -> real -> real` |
| val | [`fromLargeInt`](../sig/REAL.md#val-fromlargeint) | `IntInf.int -> real` |
| val | [`fromManExp`](../sig/REAL.md#val-frommanexp) | `{exp : int, man : real} -> real` |
| val | [`fromString`](../sig/REAL.md#val-fromstring) | `string -> real option` |
| val | [`isFinite`](../sig/REAL.md#val-isfinite) | `real -> bool` |
| val | [`isNan`](../sig/REAL.md#val-isnan) | `real -> bool` |
| val | [`isNormal`](../sig/REAL.md#val-isnormal) | `real -> bool` |
| val | [`max`](../sig/REAL.md#val-max) | `real * real -> real` |
| val | [`maxFinite`](../sig/REAL.md#val-maxfinite) | `real` |
| val | [`min`](../sig/REAL.md#val-min) | `real * real -> real` |
| val | [`minNormalPos`](../sig/REAL.md#val-minnormalpos) | `real` |
| val | [`minPos`](../sig/REAL.md#val-minpos) | `real` |
| val | [`negInf`](../sig/REAL.md#val-neginf) | `real` |
| val | [`nextAfter`](../sig/REAL.md#val-nextafter) | `real * real -> real` |
| val | [`posInf`](../sig/REAL.md#val-posinf) | `real` |
| val | [`precision`](../sig/REAL.md#val-precision) | `int` |
| val | [`radix`](../sig/REAL.md#val-radix) | `int` |
| val | [`realCeil`](../sig/REAL.md#val-realceil) | `real -> real` |
| val | [`realFloor`](../sig/REAL.md#val-realfloor) | `real -> real` |
| val | [`realMod`](../sig/REAL.md#val-realmod) | `real -> real` |
| val | [`realRound`](../sig/REAL.md#val-realround) | `real -> real` |
| val | [`realTrunc`](../sig/REAL.md#val-realtrunc) | `real -> real` |
| val | [`rem`](../sig/REAL.md#val-rem) | `real * real -> real` |
| val | [`round`](../sig/REAL.md#val-round) | `real -> int` |
| val | [`sameSign`](../sig/REAL.md#val-samesign) | `real * real -> bool` |
| val | [`scan`](../sig/REAL.md#val-scan) | `('a -> (char * 'a) option) -> 'a -> (real * 'a) option` |
| val | [`sign`](../sig/REAL.md#val-sign) | `real -> int` |
| val | [`signBit`](../sig/REAL.md#val-signbit) | `real -> bool` |
| val | [`split`](../sig/REAL.md#val-split) | `real -> {frac : real, whole : real}` |
| val | [`toDecimal`](../sig/REAL.md#val-todecimal) | `real -> {class : IEEEReal.float_class, digits : int list, exp : int, sign : bool}` |
| val | [`toInt`](../sig/REAL.md#val-toint) | `IEEEReal.rounding_mode -> real -> int` |
| val | [`toLarge`](../sig/REAL.md#val-tolarge) | `real -> real` |
| val | [`toLargeInt`](../sig/REAL.md#val-tolargeint) | `IEEEReal.rounding_mode -> real -> IntInf.int` |
| val | [`toManExp`](../sig/REAL.md#val-tomanexp) | `real -> {exp : int, man : real}` |
| val | [`toString`](../sig/REAL.md#val-tostring) | `real -> string` |
| val | [`trunc`](../sig/REAL.md#val-trunc) | `real -> int` |
| val | [`unordered`](../sig/REAL.md#val-unordered) | `real * real -> bool` |
| val | [`~`](../sig/REAL.md#val-op-tilde) | `real -> real` |
| structure | [`Math`](../str/Real.Math.md) | [`MATH`](../sig/MATH.md) |

## Notes

### 

> **Implementation** `Real.real/binary64`. [`Real.real`](../sig/REAL.md#type-real) is the top-level [`real`](../sig/REAL.md#type-real),
> the 64-bit IEEE double ([`radix`](../sig/REAL.md#val-radix) 2, [`precision`](../sig/REAL.md#val-precision) 53\), and so are [`LargeReal`](Real.md)
> and [`Real64`](Real.md); the optional [`Real32`](../str/Real32.md) is binary32. The conversions to and
> from text are correctly rounded, through the C library.

### \*+

> **Implementation** `Real.*+/fused`. Whether the multiplication and the
> addition are rounded once or twice is left to the implementation.

### floor

> **Implementation** `Real.floor/at-the-ends-of-int`. An `int` has 64 bits and
> a real 53, so near the ends of `int` not every integer is a real. `fromInt maxInt` is 2^63, which is one more than `maxInt`, and [`floor`](../sig/REAL.md#val-floor) of it raises
> [`Overflow`](../sig/GENERAL.md#exn-overflow); the largest real that [`floor`](../sig/REAL.md#val-floor), [`ceil`](../sig/REAL.md#val-ceil), [`trunc`](../sig/REAL.md#val-trunc) and [`round`](../sig/REAL.md#val-round)
> take is 2^63 - 1024. `minInt` is a real, and `minInt - 0.5` is `minInt`
> itself, so all four give `minInt` for it.

### fmt

> **Reading** `Real.fmt/SCI-negzero`. A negative zero is written with its
> sign, because the formats are described as `[~]?` and [`signBit`](../sig/REAL.md#val-signbit) is set;
> MLton leaves the sign out.

> **Reading** `Real.fmt/GEN-integral-one`. In `GEN`, a number with no
> fractional part is written without a point, as C's `gcvt` does, and the
> shorter of the scientific and the fixed form is taken, a tie going to
> the fixed one: `fmt (GEN NONE) 1.0` is `"1"` and `fmt (GEN NONE) 1000.0`
> is `"1E3"`.

### fromLargeInt

> **Reading** `Real.fromLargeInt/tie-rounds-to-even-down`. The current
> rounding mode is used; under the default one a value exactly between two
> reals goes to the one whose last digit is even, and the digits that are
> dropped decide the rest.

### fromString

> **Reading** `Real.fromString/TO_NEGINF-negative`. The numeral is rounded in
> the rounding mode that is in force, as in MLton and in C's `strtod`;
> SML/NJ and Poly/ML always round to nearest. [`Real32.fromString`](../sig/REAL.md#val-fromstring) rounds
> once, straight to binary32, and not first to binary64.

### nextAfter

> **Reading** `Real.nextAfter/equal-zeros-returns-r`. "If `r = t` then it
> returns `r`": the two zeros are equal, so `nextAfter (~0.0, 0.0)` is
> `~0.0`. C's `nextafter` returns `t` there, and MLton and Poly/ML follow
> C.

### precision

> **Implementation** `Real.precision/double`. 53 for binary64, which is 52
> stored bits and the leading one that is not stored. The arithmetic must
> show that precision and no more: `1.0 + 2^~52` is greater than `1.0`,
> and `1.0 + 2^~53` rounds back to `1.0`.

### realFloor

> **Reading** `Real.realFloor/negzero-sign`. The specification is silent
> about the sign of a zero result; IEEE 754 keeps the sign of the operand,
> so `realFloor ~0.5` is `~0.0`. The same holds for [`realCeil`](../sig/REAL.md#val-realceil),
> [`realTrunc`](../sig/REAL.md#val-realtrunc) and [`realRound`](../sig/REAL.md#val-realround).

### realRound

> **Reading** `Real.realRound/tie-half`. A value exactly between two whole
> numbers goes to the even one, as it does for [`round`](../sig/REAL.md#val-round): the specification
> states the rule under [`round`](../sig/REAL.md#val-round) alone, and IEEE 754's rounding to an
> integral value agrees.

### rem

> **Reading** `Real.rem/exact-multiple-negative-x`. The sign of a zero
> remainder is left open: the specification asks for the sign of `x`, and
> the definition `x - n * y` gives a positive zero.

### scan

> **Reading** `Real.scan/what-is-left-in-the-stream`. A point needs a digit
> after it, and so does the `E` of an exponent with its sign: what does not
> complete is left in the stream. `"1."` gives 1.0 and leaves the point,
> `"1E~"` gives 1.0 and leaves `E~`, and `"."`, `"~."` and `".E1"` give
> `NONE`. Of the words the longest is tried first, so that `"infinit"` gives
> infinity and leaves `init`.

### signBit

> **Reading** `Real.signBit/zeros`. It looks at the bit and not at the value,
> so it tells the two zeros apart and answers for a NaN as well.

### toDecimal

> **Reading** `Real.toDecimal/shortest-digits`. The digits are the fewest
> that [`fromDecimal`](../sig/REAL.md#val-fromdecimal) reads back as the same real, not the exact expansion,
> which every real has and which is long: `toDecimal 0.1` has the one
> digit 1, where the real nearest to a tenth has 55.

### toManExp

> **Reading** `Real.toManExp/one`. The specification writes the range of the
> significand as "1.0 \<= man \* radix \< radix", which for radix 2 means
> `0.5 <= |man| < 1.0`: the convention of C's `frexp`, and not the one
> that puts the point after the first digit. For a zero, an infinity or a
> NaN the significand is `x` itself.

<details><summary>Other implementations (40)</summary>

- **SML/NJ** &mdash; Real.ceil minPos is 0
- **SML/NJ 110.99.9 (64-bit)** &mdash; floor, ceil, trunc and round do not raise Overflow for a real above maxInt; the result wraps around
- **SML/NJ 110.99.9 (64-bit)** &mdash; ceil and trunc of minInt (and of minInt - 0.5) give maxInt
- **SML/NJ 110.99.9 (64-bit)** &mdash; ceil of the largest real below 2^62, an integer, is one less than it
- **MLton** &mdash; another reading of the specification: SCI, FIX and GEN print \~0.0 without its sign; the test takes the reading of SML/NJ and Poly/ML, "\~0.0"
- **Poly/ML** &mdash; GEN prints integral values with ".0" ("1.0")
- **Poly/ML** &mdash; GEN does not choose the shorter of the two notations ("0.001", "10000000000.0", "1.235E5")
- **SML/NJ** &mdash; GEN (SOME 17) 0.1 is "0.1": at most 15 significant digits are produced
- **SML/NJ** &mdash; GEN does not choose the shorter notation and pads the exponent to two digits ("0.001", "\~1.5E\~07")
- **SML/NJ (32-bit)** &mdash; not there: Real.fmt StringCvt.EXACT raises Fail "RealFormat: fmtReal: EXACT not supported"
- **SML/NJ 110.99.9** &mdash; fmt of minPos prints the digits of the shortest representation, 5E\~324, padded with zeros instead of the digits asked for
- **Poly/ML 5.9.2** &mdash; fmt StringCvt.EXACT of a zero is "0.0E1", not "0.0"
- **SML/NJ (32-bit)** &mdash; Real.fromLargeInt (2^100 + 2^47 + 1) rounds down to 2^100
- **SML/NJ** &mdash; fromManExp {man = 0.5, exp = \~1073} is 0.0, not minPos
- **Poly/ML 5.9.2** &mdash; fromManExp {man = minPos, exp = 2074} is inf, not 2^1000
- **SML/NJ** &mdash; scan skips only space, tab and newline, not the other Char.isSpace characters (\\r, \\v, \\f)
- **SML/NJ** &mdash; scan is not correctly rounded (long digit strings, minNormalPos, 2^53 + 1 + epsilon), and no format gives the 17 digits of a round trip
- **Poly/ML 5.9.2** &mdash; fromString of 2^53 + 1 + 10^-21 gives 2^53, not 2^53 + 2, as if the digits stopped at the tie 2^53 + 1
- **SML/NJ, Poly/ML 5.9.2** &mdash; another reading of the specification: fromString rounds to nearest in every rounding mode; the test takes MLton's reading (and C's), that a numeral is rounded in the current mode
- **SML/NJ (32-bit)** &mdash; fromString "1.5e\~2" is not the real nearest 0.015 (under xc1 through the shim's real\_from\_string, which is the host's Real.fromString)
- **MLton, Poly/ML** &mdash; another reading of the specification: nextAfter (r, t) with r = t returns t, as C's nextafter does; the test takes the reading of SML/NJ, r ("If r = t then it returns r", and 0.0 = \~0.0)
- **Poly/ML** &mdash; Real.nextAfter (posInf, 0.0) is maxFinite, not posInf
- **SML/NJ** &mdash; realFloor, realCeil and realTrunc are inexact beyond 2^52 (realFloor 1E300 \<\> 1E300, realCeil maxFinite = inf)
- **SML/NJ** &mdash; realCeil, realTrunc and realRound lose the sign of a zero result
- **SML/NJ** &mdash; Real.realFloor 0.0 is \~0.0
- **Poly/ML** &mdash; round and realRound of 0.49999999999999994 give 1 (they add 0.5 and floor)
- **Poly/ML** &mdash; Real.realRound (2^52 + 1) is 2^52 + 2
- **Poly/ML** &mdash; Real.realRound (\~0.25) is 0.0, not \~0.0
- **SML/NJ** &mdash; Real.realRound (2^52 + 1) is 2^52
- **MLton** &mdash; Real.rem (0.0, 0.0) is 0.0, not NaN
- **MLton** &mdash; Real.rem computes x - n\*y in floating point: rem (1.5E12, 3.1E\~10) = 2.44140625E\~4, larger than y
- **SML/NJ** &mdash; Real.rem (x, inf) is NaN, not x
- **SML/NJ** &mdash; Real.rem is inexact: rem (210.25, 176.25) = 34.000000000000007
- **SML/NJ 110.99.9** &mdash; rem (±inf, y) is a zero, not NaN
- **SML/NJ 110.99.9** &mdash; rem (x, ±0.0) is a zero, not NaN
- **SML/NJ (32-bit)** &mdash; Real.round (minInt - 0.5) raises Overflow although the tie rounds to the even minInt
- **SML/NJ 110.99.9** &mdash; scan consumes a decimal point that no digit follows ("1." leaves "", "1.E5" is 1E5)
- **Poly/ML 5.9.2** &mdash; toDecimal gives exp = 1, not 0, for zeros, infinities and NaNs
- **Poly/ML** &mdash; toString prints integral values with ".0" ("1.0")
- **Poly/ML** &mdash; toString does not choose the shorter of the two notations ("10000000000.0", "0.000125")

</details>

---

<sub>Generated by runedoc from lib/basis/real.sml; do not edit.</sub>
