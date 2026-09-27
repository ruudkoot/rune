# structure Real32

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; [Structures](../structures.md) &rsaquo; **Real32**

|  |  |
| --- | --- |
| Signature | [`REAL`](../sig/REAL.md) |
| Status | optional |
| Members | 64 |
| Tests | 147 checks |
| Source | [lib/basis/real32.sml](../../../../lib/basis/real32.sml) |

## Synopsis

```sml
structure Real32 :> REAL
```

> **Implementation** `Real32.real/binary32-in-a-double`. A [`Real32.real`](../sig/REAL.md#type-real) is
> kept as a binary64 whose value is one of binary32: an operation computes
> in binary64 and rounds what it gets to binary32, in the rounding mode that
> is set. That is the correctly rounded result for [`+`](../sig/REAL.md#val-op-plus), [`-`](../sig/REAL.md#val-op-minus), [`*`](../sig/REAL.md#val-op-star), [`/`](../sig/REAL.md#val-op-slash) and
> `sqrt`; [`*+`](../sig/REAL.md#val-op-star-plus) and [`*-`](../sig/REAL.md#val-op-star-minus) round twice. The type is abstract and is not [`real`](../sig/REAL.md#type-real),
> and a real constant at this type is rounded once, as C's `strtof` reads
> it.

## Members

What each means is on [`REAL`](../sig/REAL.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`real`](../sig/REAL.md#type-real) | *a type of its own* |
| val | [`!=`](../sig/REAL.md#val-op-bang-eq) | `Real32.real * Real32.real -> bool` |
| val | [`*`](../sig/REAL.md#val-op-star) | `Real32.real * Real32.real -> Real32.real` |
| val | [`*+`](../sig/REAL.md#val-op-star-plus) | `Real32.real * Real32.real * Real32.real -> Real32.real` |
| val | [`*-`](../sig/REAL.md#val-op-star-minus) | `Real32.real * Real32.real * Real32.real -> Real32.real` |
| val | [`+`](../sig/REAL.md#val-op-plus) | `Real32.real * Real32.real -> Real32.real` |
| val | [`-`](../sig/REAL.md#val-op-minus) | `Real32.real * Real32.real -> Real32.real` |
| val | [`/`](../sig/REAL.md#val-op-slash) | `Real32.real * Real32.real -> Real32.real` |
| val | [`<`](../sig/REAL.md#val-op-lt) | `Real32.real * Real32.real -> bool` |
| val | [`<=`](../sig/REAL.md#val-op-lt-eq) | `Real32.real * Real32.real -> bool` |
| val | [`==`](../sig/REAL.md#val-op-eq-eq) | `Real32.real * Real32.real -> bool` |
| val | [`>`](../sig/REAL.md#val-op-gt) | `Real32.real * Real32.real -> bool` |
| val | [`>=`](../sig/REAL.md#val-op-gt-eq) | `Real32.real * Real32.real -> bool` |
| val | [`?=`](../sig/REAL.md#val-op-question-eq) | `Real32.real * Real32.real -> bool` |
| val | [`abs`](../sig/REAL.md#val-abs) | `Real32.real -> Real32.real` |
| val | [`ceil`](../sig/REAL.md#val-ceil) | `Real32.real -> int` |
| val | [`checkFloat`](../sig/REAL.md#val-checkfloat) | `Real32.real -> Real32.real` |
| val | [`class`](../sig/REAL.md#val-class) | `Real32.real -> IEEEReal.float_class` |
| val | [`compare`](../sig/REAL.md#val-compare) | `Real32.real * Real32.real -> order` |
| val | [`compareReal`](../sig/REAL.md#val-comparereal) | `Real32.real * Real32.real -> IEEEReal.real_order` |
| val | [`copySign`](../sig/REAL.md#val-copysign) | `Real32.real * Real32.real -> Real32.real` |
| val | [`floor`](../sig/REAL.md#val-floor) | `Real32.real -> int` |
| val | [`fmt`](../sig/REAL.md#val-fmt) | `StringCvt.realfmt -> Real32.real -> string` |
| val | [`fromDecimal`](../sig/REAL.md#val-fromdecimal) | `{class : IEEEReal.float_class, digits : int list, exp : int, sign : bool} -> Real32.real option` |
| val | [`fromInt`](../sig/REAL.md#val-fromint) | `int -> Real32.real` |
| val | [`fromLarge`](../sig/REAL.md#val-fromlarge) | `IEEEReal.rounding_mode -> real -> Real32.real` |
| val | [`fromLargeInt`](../sig/REAL.md#val-fromlargeint) | `IntInf.int -> Real32.real` |
| val | [`fromManExp`](../sig/REAL.md#val-frommanexp) | `{exp : int, man : Real32.real} -> Real32.real` |
| val | [`fromString`](../sig/REAL.md#val-fromstring) | `string -> Real32.real option` |
| val | [`isFinite`](../sig/REAL.md#val-isfinite) | `Real32.real -> bool` |
| val | [`isNan`](../sig/REAL.md#val-isnan) | `Real32.real -> bool` |
| val | [`isNormal`](../sig/REAL.md#val-isnormal) | `Real32.real -> bool` |
| val | [`max`](../sig/REAL.md#val-max) | `Real32.real * Real32.real -> Real32.real` |
| val | [`maxFinite`](../sig/REAL.md#val-maxfinite) | `Real32.real` |
| val | [`min`](../sig/REAL.md#val-min) | `Real32.real * Real32.real -> Real32.real` |
| val | [`minNormalPos`](../sig/REAL.md#val-minnormalpos) | `Real32.real` |
| val | [`minPos`](../sig/REAL.md#val-minpos) | `Real32.real` |
| val | [`negInf`](../sig/REAL.md#val-neginf) | `Real32.real` |
| val | [`nextAfter`](../sig/REAL.md#val-nextafter) | `Real32.real * Real32.real -> Real32.real` |
| val | [`posInf`](../sig/REAL.md#val-posinf) | `Real32.real` |
| val | [`precision`](../sig/REAL.md#val-precision) | `int` |
| val | [`radix`](../sig/REAL.md#val-radix) | `int` |
| val | [`realCeil`](../sig/REAL.md#val-realceil) | `Real32.real -> Real32.real` |
| val | [`realFloor`](../sig/REAL.md#val-realfloor) | `Real32.real -> Real32.real` |
| val | [`realMod`](../sig/REAL.md#val-realmod) | `Real32.real -> Real32.real` |
| val | [`realRound`](../sig/REAL.md#val-realround) | `Real32.real -> Real32.real` |
| val | [`realTrunc`](../sig/REAL.md#val-realtrunc) | `Real32.real -> Real32.real` |
| val | [`rem`](../sig/REAL.md#val-rem) | `Real32.real * Real32.real -> Real32.real` |
| val | [`round`](../sig/REAL.md#val-round) | `Real32.real -> int` |
| val | [`sameSign`](../sig/REAL.md#val-samesign) | `Real32.real * Real32.real -> bool` |
| val | [`scan`](../sig/REAL.md#val-scan) | `('a -> (char * 'a) option) -> 'a -> (Real32.real * 'a) option` |
| val | [`sign`](../sig/REAL.md#val-sign) | `Real32.real -> int` |
| val | [`signBit`](../sig/REAL.md#val-signbit) | `Real32.real -> bool` |
| val | [`split`](../sig/REAL.md#val-split) | `Real32.real -> {frac : Real32.real, whole : Real32.real}` |
| val | [`toDecimal`](../sig/REAL.md#val-todecimal) | `Real32.real -> {class : IEEEReal.float_class, digits : int list, exp : int, sign : bool}` |
| val | [`toInt`](../sig/REAL.md#val-toint) | `IEEEReal.rounding_mode -> Real32.real -> int` |
| val | [`toLarge`](../sig/REAL.md#val-tolarge) | `Real32.real -> real` |
| val | [`toLargeInt`](../sig/REAL.md#val-tolargeint) | `IEEEReal.rounding_mode -> Real32.real -> IntInf.int` |
| val | [`toManExp`](../sig/REAL.md#val-tomanexp) | `Real32.real -> {exp : int, man : Real32.real}` |
| val | [`toString`](../sig/REAL.md#val-tostring) | `Real32.real -> string` |
| val | [`trunc`](../sig/REAL.md#val-trunc) | `Real32.real -> int` |
| val | [`unordered`](../sig/REAL.md#val-unordered) | `Real32.real * Real32.real -> bool` |
| val | [`~`](../sig/REAL.md#val-op-tilde) | `Real32.real -> Real32.real` |
| structure | [`Math`](../str/Real32.Math.md) |  |

<details><summary>Other implementations (6)</summary>

- **Poly/ML 5.9.2** &mdash; fromLargeInt rounds to binary64 and then to binary32: 2^60 + 2^36 + 1 becomes 2^60, not 2^60 + 2^37
- **Poly/ML 5.9.2** &mdash; fromString "3.4028236e38", beyond maxFinite by more than half a spacing, is 2^127 instead of an infinity
- **Poly/ML 5.9.2** &mdash; fromString rounds a number just above half of minPos to zero
- **Poly/ML 5.9.2** &mdash; another reading of the specification: fromString rounds to nearest in every rounding mode; the test takes MLton's reading, that a numeral is rounded in the current mode
- **MLton, Poly/ML 5.9.2** &mdash; another reading of the specification: as Real.nextAfter/equal-zeros-returns-r\*: returns t
- **Poly/ML 5.9.2** &mdash; toDecimal of a zero has exp 1, not 0

</details>

---

<sub>Generated by runedoc from lib/basis/real32.sml; do not edit.</sub>
