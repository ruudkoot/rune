# structure Time

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Time**

|  |  |
| --- | --- |
| Signature | [`TIME`](../sig/TIME.md) |
| Status | required |
| Members | 25 |
| Tests | 126 checks |
| Source | [lib/basis/time.sml](../../../../lib/basis/time.sml) |

## Synopsis

```sml
structure Time :> TIME
```

Time: a length of time, held as microseconds.

## Members

What each means is on [`TIME`](../sig/TIME.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`time`](../sig/TIME.md#type-time) | *a type of its own* |
| val | [`+`](../sig/TIME.md#val-op-plus) | `time * time -> time` |
| val | [`-`](../sig/TIME.md#val-op-minus) | `time * time -> time` |
| val | [`<`](../sig/TIME.md#val-op-lt) | `time * time -> bool` |
| val | [`<=`](../sig/TIME.md#val-op-lt-eq) | `time * time -> bool` |
| val | [`>`](../sig/TIME.md#val-op-gt) | `time * time -> bool` |
| val | [`>=`](../sig/TIME.md#val-op-gt-eq) | `time * time -> bool` |
| exception | [`Time`](../sig/TIME.md#exn-time) |  |
| val | [`compare`](../sig/TIME.md#val-compare) | `time * time -> order` |
| val | [`fmt`](../sig/TIME.md#val-fmt) | `int -> time -> string` |
| val | [`fromMicroseconds`](../sig/TIME.md#val-frommicroseconds) | `IntInf.int -> time` |
| val | [`fromMilliseconds`](../sig/TIME.md#val-frommilliseconds) | `IntInf.int -> time` |
| val | [`fromNanoseconds`](../sig/TIME.md#val-fromnanoseconds) | `IntInf.int -> time` |
| val | [`fromReal`](../sig/TIME.md#val-fromreal) | `real -> time` |
| val | [`fromSeconds`](../sig/TIME.md#val-fromseconds) | `IntInf.int -> time` |
| val | [`fromString`](../sig/TIME.md#val-fromstring) | `string -> time option` |
| val | [`now`](../sig/TIME.md#val-now) | `unit -> time` |
| val | [`scan`](../sig/TIME.md#val-scan) | `('a -> (char * 'a) option) -> 'a -> (time * 'a) option` |
| val | [`toMicroseconds`](../sig/TIME.md#val-tomicroseconds) | `time -> IntInf.int` |
| val | [`toMilliseconds`](../sig/TIME.md#val-tomilliseconds) | `time -> IntInf.int` |
| val | [`toNanoseconds`](../sig/TIME.md#val-tonanoseconds) | `time -> IntInf.int` |
| val | [`toReal`](../sig/TIME.md#val-toreal) | `time -> real` |
| val | [`toSeconds`](../sig/TIME.md#val-toseconds) | `time -> IntInf.int` |
| val | [`toString`](../sig/TIME.md#val-tostring) | `time -> string` |
| val | [`zeroTime`](../sig/TIME.md#val-zerotime) | `time` |

## Notes

### \+

> **Implementation** `Time.+/exact-until-it-raises`. Wherever the range ends,
> doubling a time over and over stays exact until one step raises [`Time`](../sig/TIME.md#exn-time);
> no step gives a wrong value or another exception.

### \-

> **Implementation** `Time.-/exact-until-it-raises`. As for [`+`](../sig/TIME.md#val-op-plus): exact until
> a step raises [`Time`](../sig/TIME.md#exn-time).

### fmt

> **Reading** `Time.fmt/fixed-point`. The text has "fixed-point semantics":
> the digit last kept is rounded to nearest, and since a time holds
> microseconds every digit past the sixth is a zero.

### fromSeconds

> **Implementation** `Time.fromSeconds/range-is-open`. Where the range ends
> is not fixed; the suite asks only that a value either come out exact or
> raise [`Time`](../sig/TIME.md#exn-time), never something else and never a wrong number.

### scan

> **Reading** `Time.scan/digits-past-the-sixth`. Any number of digits may be
> written; those of the fraction after the sixth are dropped rather than
> rounded, and a number too large for a time raises [`Time`](../sig/TIME.md#exn-time).

### toNanoseconds

> **Implementation** `Time.toNanoseconds/beyond-64-bits`. The result is a
> [`LargeInt.int`](../sig/INTEGER.md#type-int) and is exact however large it is; a [`LargeInt`](../str/IntInf.md) of bounded
> precision would raise [`Overflow`](../sig/GENERAL.md#exn-overflow) instead.

### zeroTime

> **Reading** `Time.zeroTime/lies-in-the-past`. It is "a common reference
> point for all time values"; the suite takes it to lie in the past, so
> `now ()` is greater.

<details><summary>Other implementations (10)</summary>

- **SML/NJ, Poly/ML** &mdash; fromReal of an infinite real raises Overflow, not Time
- **Poly/ML** &mdash; fmt with a negative number of digits does not raise Size
- **Poly/ML** &mdash; fmt goes through a real: fmt 6 of 12345678901.234567 s gives 12345678901.234568 ("Time values are required to have fixed-point semantics")
- **MLton** &mdash; fmt is Real.fmt of toReal: fmt 6 of 12345678901.234567 s gives 12345678901.234568 ("Time values are required to have fixed-point semantics")
- **MLton, SML/NJ, Poly/ML** &mdash; fromReal of a NaN raises Domain, not Time ("It raises Time when the result is not representable")
- **MLton, SML/NJ** &mdash; fromString "1." is NONE, although its prefix "1" denotes a time ("SOME(t) where t is the time value denoted by a prefix of s")
- **Poly/ML** &mdash; toMilliseconds rounds a negative time towards minus infinity (\~1500 us gives \~2), not "towards 0"
- **Poly/ML** &mdash; toSeconds rounds a negative time towards minus infinity (\~2.01 s gives \~3), not "towards 0"
- **Poly/ML** &mdash; toSeconds rounds a negative time towards minus infinity (\~0.999 s gives \~1), not "towards 0"
- **Poly/ML** &mdash; toSeconds and toMilliseconds round a negative time towards minus infinity, not "towards 0"

</details>

---

<sub>Generated by runedoc from lib/basis/time.sml; do not edit.</sub>
