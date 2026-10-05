# structure IntInf

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; [Structures](../structures.md) &rsaquo; **IntInf**

|  |  |
| --- | --- |
| Signatures | [`INT_INF`](../sig/INT_INF.md), [`INTEGER`](../sig/INTEGER.md) |
| Status | optional |
| Members | 40 |
| Tests | 494 checks |
| Source | [lib/basis/intinf.sml](../../../../lib/basis/intinf.sml) |

## Synopsis

```sml
structure IntInf : INT_INF
structure IntInf : INTEGER
```

IntInf: arbitrary precision integers implemented in SML on top of the
VM's int (63 bits). A value is a sign and a little-endian list of base-2^30 limbs
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
| val | [`*`](../sig/INTEGER.md#val-op-star) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`+`](../sig/INTEGER.md#val-op-plus) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`-`](../sig/INTEGER.md#val-op-minus) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`<`](../sig/INTEGER.md#val-op-lt) | `IntInf.int * IntInf.int -> bool` |
| val | [`<<`](../sig/INT_INF.md#val-op-lt-lt) | `IntInf.int * word -> IntInf.int` |
| val | [`<=`](../sig/INTEGER.md#val-op-lt-eq) | `IntInf.int * IntInf.int -> bool` |
| val | [`>`](../sig/INTEGER.md#val-op-gt) | `IntInf.int * IntInf.int -> bool` |
| val | [`>=`](../sig/INTEGER.md#val-op-gt-eq) | `IntInf.int * IntInf.int -> bool` |
| val | [`abs`](../sig/INTEGER.md#val-abs) | `IntInf.int -> IntInf.int` |
| val | [`andb`](../sig/INT_INF.md#val-andb) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`compare`](../sig/INTEGER.md#val-compare) | `IntInf.int * IntInf.int -> order` |
| val | [`div`](../sig/INTEGER.md#val-div) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`divMod`](../sig/INT_INF.md#val-divmod) | `IntInf.int * IntInf.int -> IntInf.int * IntInf.int` |
| val | [`fmt`](../sig/INTEGER.md#val-fmt) | `StringCvt.radix -> IntInf.int -> string` |
| val | [`fromInt`](../sig/INTEGER.md#val-fromint) | `int -> IntInf.int` |
| val | [`fromLarge`](../sig/INTEGER.md#val-fromlarge) | `IntInf.int -> IntInf.int` |
| val | [`fromString`](../sig/INTEGER.md#val-fromstring) | `string -> IntInf.int option` |
| val | [`log2`](../sig/INT_INF.md#val-log2) | `IntInf.int -> int` |
| val | [`max`](../sig/INTEGER.md#val-max) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`maxInt`](../sig/INTEGER.md#val-maxint) | `IntInf.int option` |
| val | [`min`](../sig/INTEGER.md#val-min) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`minInt`](../sig/INTEGER.md#val-minint) | `IntInf.int option` |
| val | [`mod`](../sig/INTEGER.md#val-mod) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`notb`](../sig/INT_INF.md#val-notb) | `IntInf.int -> IntInf.int` |
| val | [`orb`](../sig/INT_INF.md#val-orb) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`pow`](../sig/INT_INF.md#val-pow) | `IntInf.int * int -> IntInf.int` |
| val | [`precision`](../sig/INTEGER.md#val-precision) | `int option` |
| val | [`quot`](../sig/INTEGER.md#val-quot) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`quotRem`](../sig/INT_INF.md#val-quotrem) | `IntInf.int * IntInf.int -> IntInf.int * IntInf.int` |
| val | [`rem`](../sig/INTEGER.md#val-rem) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`sameSign`](../sig/INTEGER.md#val-samesign) | `IntInf.int * IntInf.int -> bool` |
| val | [`scan`](../sig/INTEGER.md#val-scan) | `StringCvt.radix -> ('a -> (char * 'a) option) -> 'a -> (IntInf.int * 'a) option` |
| val | [`sign`](../sig/INTEGER.md#val-sign) | `IntInf.int -> int` |
| val | [`toInt`](../sig/INTEGER.md#val-toint) | `IntInf.int -> int` |
| val | [`toLarge`](../sig/INTEGER.md#val-tolarge) | `IntInf.int -> IntInf.int` |
| val | [`toString`](../sig/INTEGER.md#val-tostring) | `IntInf.int -> string` |
| val | [`xorb`](../sig/INT_INF.md#val-xorb) | `IntInf.int * IntInf.int -> IntInf.int` |
| val | [`~`](../sig/INTEGER.md#val-op-tilde) | `IntInf.int -> IntInf.int` |
| val | [`~>>`](../sig/INT_INF.md#val-op-tilde-gt-gt) | `IntInf.int * word -> IntInf.int` |

## Notes

### 

> **Implementation** `IntInf.int/limbs`. A sign and a list of digits in base
> 2^30, written in SML on top of [`int`](../sig/INTEGER.md#type-int); equal numbers are equal
> values, so `=` compares them. [`LargeInt`](IntInf.md) is [`IntInf`](IntInf.md).

<details><summary>Other implementations (11)</summary>

- **SML/NJ** &mdash; IntInf.fmt StringCvt.HEX produces the digits a to f, not A to F
- **SML/NJ** &mdash; IntInf.fromString and Word.fromString do not skip vertical tab, form feed and carriage return
- **MLKit** &mdash; scan and fromString of IntInf skip space, tab and newline only, not vertical tab, form feed and carriage return
- **MLKit** &mdash; a sign after the digits is read as the sign of a further group of digits: "1\~2" is 98 and "1+2" is 102, not 1 (IntInf.sml reads every group of digits with NumScan.scanInt, which takes a sign)
- **SML/NJ** &mdash; IntInf.pow (i, j) is 0 for \| i \| = 1 and j \< 0
- **SML/NJ** &mdash; pow (1, j) and pow (\~1, j) for a negative j are 0, where the page has "\|i\| = 1: i^j"
- **SML/NJ** &mdash; scan does not skip vertical tab, form feed and carriage return
- **SML/NJ** &mdash; IntInf.scan StringCvt.BIN accepts characters that are not binary digits ("2" is 2, "0b101" and "0x1" are numbers)
- **SML/NJ** &mdash; IntInf.scan StringCvt.OCT accepts the digits 8 and 9 and the letter x ("0x17" is 15)
- **MLKit** &mdash; a sign after the digits is read as the sign of a further group of digits: "1\~2" is SOME (98, ""), not SOME (1, "\~2")
- **Poly/ML 5.9.2** &mdash; IntInf.\~\>\> of a negative number that does not fit a machine word rounds towards zero, not down (\~2^100 \~\>\> 0w101 is 0, not \~1); 5.7.1 rounds down

</details>

---

<sub>Generated by runedoc from lib/basis/intinf.sml; do not edit.</sub>
