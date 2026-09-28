# structure Int64

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; [Structures](../structures.md) &rsaquo; **Int64**

|  |  |
| --- | --- |
| Signature | [`INTEGER`](../sig/INTEGER.md) |
| Status | optional |
| Members | 30 |
| Tests | 320 checks |
| Source | [lib/basis/int64.sml](../../../../lib/basis/int64.sml) |

## Synopsis

```sml
structure Int64 :> INTEGER
```

Int64: the 64-bit integers, and FixedInt, the largest of the
fixed-precision ones, which is the same structure.

The implementation is [`Int`](../str/Int.md), whose width the VM decides, but the type is
sealed away from [`Int.int`](../sig/INTEGER.md#type-int) so that no program can take the two for one:
[`Int`](../str/Int.md) is of no fixed width as far as a program can see, which leaves the
VM free to choose it. Every operation is [`Int`](../str/Int.md)'s, so the seal costs
nothing; [`toInt`](../sig/INTEGER.md#val-toint) and [`fromInt`](../sig/INTEGER.md#val-fromint) are the way between them, as the
specification intends.

## Members

What each means is on [`INTEGER`](../sig/INTEGER.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`int`](../sig/INTEGER.md#type-int) | *a type of its own* |
| val | [`*`](../sig/INTEGER.md#val-op-star) | `Int64.int * Int64.int -> Int64.int` |
| val | [`+`](../sig/INTEGER.md#val-op-plus) | `Int64.int * Int64.int -> Int64.int` |
| val | [`-`](../sig/INTEGER.md#val-op-minus) | `Int64.int * Int64.int -> Int64.int` |
| val | [`<`](../sig/INTEGER.md#val-op-lt) | `Int64.int * Int64.int -> bool` |
| val | [`<=`](../sig/INTEGER.md#val-op-lt-eq) | `Int64.int * Int64.int -> bool` |
| val | [`>`](../sig/INTEGER.md#val-op-gt) | `Int64.int * Int64.int -> bool` |
| val | [`>=`](../sig/INTEGER.md#val-op-gt-eq) | `Int64.int * Int64.int -> bool` |
| val | [`abs`](../sig/INTEGER.md#val-abs) | `Int64.int -> Int64.int` |
| val | [`compare`](../sig/INTEGER.md#val-compare) | `Int64.int * Int64.int -> order` |
| val | [`div`](../sig/INTEGER.md#val-div) | `Int64.int * Int64.int -> Int64.int` |
| val | [`fmt`](../sig/INTEGER.md#val-fmt) | `StringCvt.radix -> Int64.int -> string` |
| val | [`fromInt`](../sig/INTEGER.md#val-fromint) | `int -> Int64.int` |
| val | [`fromLarge`](../sig/INTEGER.md#val-fromlarge) | `IntInf.int -> Int64.int` |
| val | [`fromString`](../sig/INTEGER.md#val-fromstring) | `string -> Int64.int option` |
| val | [`max`](../sig/INTEGER.md#val-max) | `Int64.int * Int64.int -> Int64.int` |
| val | [`maxInt`](../sig/INTEGER.md#val-maxint) | `Int64.int option` |
| val | [`min`](../sig/INTEGER.md#val-min) | `Int64.int * Int64.int -> Int64.int` |
| val | [`minInt`](../sig/INTEGER.md#val-minint) | `Int64.int option` |
| val | [`mod`](../sig/INTEGER.md#val-mod) | `Int64.int * Int64.int -> Int64.int` |
| val | [`precision`](../sig/INTEGER.md#val-precision) | `int option` |
| val | [`quot`](../sig/INTEGER.md#val-quot) | `Int64.int * Int64.int -> Int64.int` |
| val | [`rem`](../sig/INTEGER.md#val-rem) | `Int64.int * Int64.int -> Int64.int` |
| val | [`sameSign`](../sig/INTEGER.md#val-samesign) | `Int64.int * Int64.int -> bool` |
| val | [`scan`](../sig/INTEGER.md#val-scan) | `StringCvt.radix -> ('a -> (char * 'a) option) -> 'a -> (Int64.int * 'a) option` |
| val | [`sign`](../sig/INTEGER.md#val-sign) | `Int64.int -> int` |
| val | [`toInt`](../sig/INTEGER.md#val-toint) | `Int64.int -> int` |
| val | [`toLarge`](../sig/INTEGER.md#val-tolarge) | `Int64.int -> IntInf.int` |
| val | [`toString`](../sig/INTEGER.md#val-tostring) | `Int64.int -> string` |
| val | [`~`](../sig/INTEGER.md#val-op-tilde) | `Int64.int -> Int64.int` |

<details><summary>Other implementations (8)</summary>

- **SML/NJ (32-bit)** &mdash; Int64.+ and Int64.- get the carry and the borrow wrong (\~2 + \~3 is \~8589934597 when the numbers are not constants), and the comparisons, div, mod, abs, sign, fmt and the conversions are checked on numbers made with them (docs/bugreport/smlnj/Int64.+/carry-and-borrow)
- **SML/NJ (32-bit)** &mdash; fmt raises an exception for minInt and maxInt and gets other numbers wrong: Int64.+ and Int64.- get the carry and the borrow wrong (docs/bugreport/smlnj/Int64.+/carry-and-borrow)
- **SML/NJ (32-bit)** &mdash; Int64.+ and Int64.- get the carry and the borrow wrong, and fromString and the numbers of the checks are made with them (docs/bugreport/smlnj/Int64.+/carry-and-borrow)
- **SML/NJ (64-bit)** &mdash; mod (minInt, \~1) raises an exception instead of giving 0 (Int32 on 110.79, Int64 on both)
- **SML/NJ (64-bit)** &mdash; rem (minInt, \~1) raises an exception instead of giving 0 (Int32 on 110.79, Int64 on both)
- **SML/NJ (32-bit)** &mdash; Int64.+ and Int64.- get the carry and the borrow wrong, and the numbers of the checks are made with them (docs/bugreport/smlnj/Int64.+/carry-and-borrow)
- **SML/NJ** &mdash; scan does not skip vertical tab, form feed and carriage return
- **SML/NJ (32-bit)** &mdash; Int64.+ and Int64.- get the carry and the borrow wrong, and scan and the numbers of the checks are made with them (docs/bugreport/smlnj/Int64.+/carry-and-borrow)

</details>

---

<sub>Generated by runedoc from lib/basis/int64.sml; do not edit.</sub>
