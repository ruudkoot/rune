# structure Real32

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; [Structures](../structures.md) &rsaquo; **Real32**

|  |  |
| --- | --- |
| Signature | [`REAL`](../sig/REAL.md) |
| Status | optional |
| Members | 64 |
| Tests | 84 checks |
| Source | [lib/basis/real32.sml](../../../../lib/basis/real32.sml) |

## Synopsis

```sml
structure Real32 :> REAL
```

Real32: IEEE 754 binary32. A value is kept as a real (binary64) that
binary32 represents, and an operation rounds its result to binary32 (the
primitive real\_to\_single, in the current rounding mode). For +, -, \*, / and
sqrt that is the correctly rounded binary32 result: binary64 has more than
twice the precision of binary32, plus two bits. Numerals are read to
binary32 at once (real\_single\_from\_string, C's strtof), and the constants
of type Real32.real are read from their text where they are evaluated
(RuneReal32Lit.fromLit).

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
