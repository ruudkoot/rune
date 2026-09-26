# structure IntInf

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; [Structures](../structures.md) &rsaquo; **IntInf**

|  |  |
| --- | --- |
| Signatures | [`INT_INF`](../sig/INT_INF.md), [`INTEGER`](../sig/INTEGER.md) |
| Status | optional |
| Members | 40 |
| Tests | 265 checks |
| Source | [lib/basis/intinf.sml](../../../../lib/basis/intinf.sml) |

## Synopsis

```sml
structure IntInf : INT_INF
structure IntInf : INTEGER
```

IntInf: arbitrary precision integers implemented in SML on top of the
64-bit int. A value is a sign and a little-endian list of base-2^30 limbs
without high zero limbs; zero is never negative. The representation is
therefore canonical and structural equality is value equality.

This file is compiled before int.sml (Int.toLarge/fromLarge use it), so it
relies on the builtin overloaded operators and VM primitives only. Every
helper that uses int arithmetic is defined before the IntInf operators
shadow + - \* div mod \~ \< \<= \> \>= inside the structure.

## Members

What each means is on [`INT_INF`](../sig/INT_INF.md) and [`INTEGER`](../sig/INTEGER.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`int`](../sig/INTEGER.md#type-int) | *a type of its own* |
| val | [`*`](../sig/INTEGER.md#val-op-star) | `int * int -> int` |
| val | [`+`](../sig/INTEGER.md#val-op-plus) | `int * int -> int` |
| val | [`-`](../sig/INTEGER.md#val-op-minus) | `int * int -> int` |
| val | [`<`](../sig/INTEGER.md#val-op-lt) | `int * int -> bool` |
| val | [`<<`](../sig/INT_INF.md#val-op-lt-lt) | `int * word -> int` |
| val | [`<=`](../sig/INTEGER.md#val-op-lt-eq) | `int * int -> bool` |
| val | [`>`](../sig/INTEGER.md#val-op-gt) | `int * int -> bool` |
| val | [`>=`](../sig/INTEGER.md#val-op-gt-eq) | `int * int -> bool` |
| val | [`abs`](../sig/INTEGER.md#val-abs) | `int -> int` |
| val | [`andb`](../sig/INT_INF.md#val-andb) | `int * int -> int` |
| val | [`compare`](../sig/INTEGER.md#val-compare) | `int * int -> order` |
| val | [`div`](../sig/INTEGER.md#val-div) | `int * int -> int` |
| val | [`divMod`](../sig/INT_INF.md#val-divmod) | `int * int -> int * int` |
| val | [`fmt`](../sig/INTEGER.md#val-fmt) | `StringCvt.radix -> int -> string` |
| val | [`fromInt`](../sig/INTEGER.md#val-fromint) | `int -> int` |
| val | [`fromLarge`](../sig/INTEGER.md#val-fromlarge) | `int -> int` |
| val | [`fromString`](../sig/INTEGER.md#val-fromstring) | `string -> int option` |
| val | [`log2`](../sig/INT_INF.md#val-log2) | `int -> int` |
| val | [`max`](../sig/INTEGER.md#val-max) | `int * int -> int` |
| val | [`maxInt`](../sig/INTEGER.md#val-maxint) | `int option` |
| val | [`min`](../sig/INTEGER.md#val-min) | `int * int -> int` |
| val | [`minInt`](../sig/INTEGER.md#val-minint) | `int option` |
| val | [`mod`](../sig/INTEGER.md#val-mod) | `int * int -> int` |
| val | [`notb`](../sig/INT_INF.md#val-notb) | `int -> int` |
| val | [`orb`](../sig/INT_INF.md#val-orb) | `int * int -> int` |
| val | [`pow`](../sig/INT_INF.md#val-pow) | `int * int -> int` |
| val | [`precision`](../sig/INTEGER.md#val-precision) | `int option` |
| val | [`quot`](../sig/INTEGER.md#val-quot) | `int * int -> int` |
| val | [`quotRem`](../sig/INT_INF.md#val-quotrem) | `int * int -> int * int` |
| val | [`rem`](../sig/INTEGER.md#val-rem) | `int * int -> int` |
| val | [`sameSign`](../sig/INTEGER.md#val-samesign) | `int * int -> bool` |
| val | [`scan`](../sig/INTEGER.md#val-scan) | `StringCvt.radix -> ('a -> (char * 'a) option) -> 'a -> (int * 'a) option` |
| val | [`sign`](../sig/INTEGER.md#val-sign) | `int -> int` |
| val | [`toInt`](../sig/INTEGER.md#val-toint) | `int -> int` |
| val | [`toLarge`](../sig/INTEGER.md#val-tolarge) | `int -> int` |
| val | [`toString`](../sig/INTEGER.md#val-tostring) | `int -> string` |
| val | [`xorb`](../sig/INT_INF.md#val-xorb) | `int * int -> int` |
| val | [`~`](../sig/INTEGER.md#val-op-tilde) | `int -> int` |
| val | [`~>>`](../sig/INT_INF.md#val-op-tilde-gt-gt) | `int * word -> int` |

## Notes

### 

> **Implementation** `IntInf.int/limbs`. A sign and a list of digits in base
> 2^30, written in SML on top of the 64-bit [`int`](../sig/INTEGER.md#type-int); equal numbers are equal
> values, so `=` compares them. [`LargeInt`](IntInf.md) is [`IntInf`](IntInf.md).

<details><summary>Other implementations (7)</summary>

- **SML/NJ** &mdash; IntInf.fmt StringCvt.HEX produces the digits a to f, not A to F
- **SML/NJ** &mdash; IntInf.fromString and Word.fromString do not skip vertical tab, form feed and carriage return
- **SML/NJ** &mdash; IntInf.pow (i, j) is 0 for \| i \| = 1 and j \< 0
- **SML/NJ** &mdash; scan does not skip vertical tab, form feed and carriage return
- **SML/NJ 110.99.9** &mdash; IntInf.scan StringCvt.BIN accepts characters that are not binary digits ("2" is 2, "0b101" and "0x1" are numbers)
- **SML/NJ 110.99.9** &mdash; IntInf.scan StringCvt.OCT accepts the digits 8 and 9 and the letter x ("0x17" is 15)
- **Poly/ML 5.9.2** &mdash; IntInf.\~\>\> of a negative number that does not fit a machine word rounds towards zero, not down (\~2^100 \~\>\> 0w101 is 0, not \~1); 5.7.1 rounds down

</details>

---

<sub>Generated by runedoc from lib/basis/intinf.sml; do not edit.</sub>
