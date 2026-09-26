# signature TIME

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **TIME**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 25 of 25 entries documented |
| Tests | 180 checks of 24 entries |
| Source | [lib/basis/sig\_time.sml](../../../../lib/basis/sig_time.sml) |

## Synopsis

```sml
signature TIME
structure Time :> TIME
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Time`](../str/Time.md) | Time: a length of time, held as microseconds. | [lib/basis/time.sml](../../../../lib/basis/time.sml) |

A length of time, and a point in time counted from a fixed reference.

A [`time`](#type-time) is a duration. It is also how a moment is named: `now ()` is the
time since [`zeroTime`](#val-zerotime), and a moment and a duration have one type, so
`now () + fromSeconds 10` is ten seconds hence and a difference of two
moments is a duration. Times may be negative.

The conversions take and give [`LargeInt.int`](../sig/INTEGER.md#type-int), so that the range of a time
is not tied to [`Int.int`](../sig/INTEGER.md#type-int); going the other way they truncate towards zero.
How fine a time is and how far it reaches is left to the implementation,
and a conversion or an addition whose result does not fit raises [`Time`](#exn-time)
rather than [`Overflow`](../sig/GENERAL.md#exn-overflow).

> **Implementation** `TIME.time/is-microseconds`. A time is a number of
> microseconds held in an `int`, which reaches about 292,000 years either
> way. Anything finer than a microsecond is lost, and [`zeroTime`](#val-zerotime) is the
> epoch of the system's clock, 1 January 1970 UTC.

## Interface

<pre>
signature TIME =
sig
  eqtype <a href="#type-time">time</a>
  exception <a href="#exn-time">Time</a>
  val <a href="#val-zerotime">zeroTime</a> : time
  val <a href="#val-fromreal">fromReal</a> : LargeReal.real -&gt; time
  val <a href="#val-toreal">toReal</a> : time -&gt; LargeReal.real
  val <a href="#val-toseconds">toSeconds</a> : time -&gt; LargeInt.int
  val <a href="#val-tomilliseconds">toMilliseconds</a> : time -&gt; LargeInt.int
  val <a href="#val-tomicroseconds">toMicroseconds</a> : time -&gt; LargeInt.int
  val <a href="#val-tonanoseconds">toNanoseconds</a> : time -&gt; LargeInt.int
  val <a href="#val-fromseconds">fromSeconds</a> : LargeInt.int -&gt; time
  val <a href="#val-frommilliseconds">fromMilliseconds</a> : LargeInt.int -&gt; time
  val <a href="#val-frommicroseconds">fromMicroseconds</a> : LargeInt.int -&gt; time
  val <a href="#val-fromnanoseconds">fromNanoseconds</a> : LargeInt.int -&gt; time
  val <a href="#val-op-plus">+</a> : time * time -&gt; time
  val <a href="#val-op-minus">-</a> : time * time -&gt; time
  val <a href="#val-compare">compare</a> : time * time -&gt; order
  val <a href="#val-op-lt">&lt;</a> : time * time -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : time * time -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : time * time -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : time * time -&gt; bool
  val <a href="#val-now">now</a> : unit -&gt; time
  val <a href="#val-fmt">fmt</a> : int -&gt; time -&gt; string
  val <a href="#val-tostring">toString</a> : time -&gt; string
  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (time, 'a) StringCvt.reader
  val <a href="#val-fromstring">fromString</a> : string -&gt; time option
end
</pre>

### <a name="type-time"></a>`time`

```sml
eqtype time
```

The type of a length of time.

Two times are equal when they are the same length.

### <a name="exn-time"></a>`Time`

```sml
exception Time
```

Raised when a time cannot be made or converted: the value does not fit.

<details><summary>Other implementations (1)</summary>

- **SML/NJ, Poly/ML** &mdash; fromReal of an infinite real raises Overflow, not Time

</details>

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `raise-and-handle` &middot; `is-its-own-exception` &middot; `fromReal-posInf` (raises)

</details>

### <a name="val-zerotime"></a>`zeroTime`

```sml
val zeroTime : time
```

The zero of the arithmetic, and the reference point that [`now`](#val-now) counts from.

> **Reading** `Time.zeroTime/lies-in-the-past`. It is "a common reference
> point for all time values"; the suite takes it to lie in the past, so
> `now ()` is greater.

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `is-fromReal-0.0` &middot; `is-zero-seconds` &middot; `toNanoseconds` &middot; `identity-of-+`

</details>

### <a name="val-fromreal"></a>`fromReal`

```sml
val fromReal : LargeReal.real -> time
```

`fromReal r` is `r` seconds, its fraction truncated towards zero.

**Raises** [`Time`](#exn-time) if `r` is not a number, is infinite, or does not fit.

**Example** `toMilliseconds (fromReal 1.5) = 1500`

<details><summary>Other implementations (2)</summary>

- **MLton, SML/NJ, Poly/ML** &mdash; fromReal of a NaN raises Domain, not Time ("It raises Time when the result is not representable")
- **SML/NJ, Poly/ML** &mdash; fromReal of an infinite real raises Overflow, not Time

</details>

<details><summary>Tests (15)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `one-and-a-half` &middot; `binary-fraction` &middot; `negative` &middot; `negative-zero` &middot; `whole-seconds` &middot; `spec-example-1.8` &middot; `fraction-of-a-microsecond-lost` &middot; `milliseconds` &middot; `posInf` (raises) &middot; `negInf` (raises) &middot; `nan` (raises) &middot; `huge-approximately-or-Time` &middot; `huge-negative-approximately-or-Time` &middot; `binary-fractions-exactly` &middot; `toReal-round-trip-within-a-microsecond`

</details>

### <a name="val-toreal"></a>`toReal`

```sml
val toReal : time -> LargeReal.real
```

`toReal t` is `t` as a number of seconds, which may lose precision.

<details><summary>Tests (8)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `milliseconds` &middot; `negative` &middot; `zeroTime` &middot; `whole-seconds` &middot; `microsecond` &middot; `binary-fractions-exactly` &middot; `random-approximately` &middot; `fromReal-round-trip-within-a-microsecond`

</details>

### <a name="val-toseconds"></a>`toSeconds`

```sml
val toSeconds : time -> LargeInt.int
```

`toSeconds t` is the whole seconds of `t`, truncated towards zero.

<details><summary>Other implementations (3)</summary>

- **Poly/ML** &mdash; toSeconds rounds a negative time towards minus infinity (\~2.01 s gives \~3), not "towards 0"
- **Poly/ML** &mdash; toSeconds rounds a negative time towards minus infinity (\~0.999 s gives \~1), not "towards 0"
- **Poly/ML** &mdash; toSeconds and toMilliseconds round a negative time towards minus infinity, not "towards 0"

</details>

<details><summary>Tests (7)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-2.01` &middot; `negative-towards-zero` &middot; `rounds-towards-zero` &middot; `rounds-negative-towards-zero` &middot; `less-than-a-second` &middot; `large` &middot; `is-toMicroseconds-quot`

</details>

### <a name="val-tomilliseconds"></a>`toMilliseconds`

```sml
val toMilliseconds : time -> LargeInt.int
```

`toMilliseconds t` is the whole milliseconds of `t`, truncated towards zero.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; toMilliseconds rounds a negative time towards minus infinity (\~1500 us gives \~2), not "towards 0"

</details>

<details><summary>Tests (5)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-2.01` &middot; `negative` &middot; `rounds-towards-zero` &middot; `rounds-negative-towards-zero` &middot; `large`

</details>

### <a name="val-tomicroseconds"></a>`toMicroseconds`

```sml
val toMicroseconds : time -> LargeInt.int
```

`toMicroseconds t` is the whole microseconds of `t`, truncated towards zero.

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-2.01` &middot; `negative` &middot; `exact` &middot; `large`

</details>

### <a name="val-tonanoseconds"></a>`toNanoseconds`

```sml
val toNanoseconds : time -> LargeInt.int
```

`toNanoseconds t` is the whole nanoseconds of `t`, truncated towards zero.

> **Implementation** `Time.toNanoseconds/beyond-64-bits`. The result is a
> [`LargeInt.int`](../sig/INTEGER.md#type-int) and is exact however large it is; a [`LargeInt`](../str/IntInf.md) of bounded
> precision would raise [`Overflow`](../sig/GENERAL.md#exn-overflow) instead.

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-2.01` &middot; `negative` &middot; `microsecond` &middot; `beyond-64-bits`

</details>

### <a name="val-fromseconds"></a>`fromSeconds`

```sml
val fromSeconds : LargeInt.int -> time
```

`fromSeconds n` is `n` seconds.

**Raises** [`Time`](#exn-time) if the time does not fit.

> **Implementation** `Time.fromSeconds/range-is-open`. Where the range ends
> is not fixed; the suite asks only that a value either come out exact or
> raise [`Time`](#exn-time), never something else and never a wrong number.

<details><summary>Tests (6)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `agrees-with-finer-units` &middot; `huge-exact-or-Time` &middot; `huge-negative-exact-or-Time` &middot; `beyond-64-bit-microseconds-exact-or-Time`

</details>

### <a name="val-frommilliseconds"></a>`fromMilliseconds`

```sml
val fromMilliseconds : LargeInt.int -> time
```

`fromMilliseconds n` is `n` milliseconds.

**Raises** [`Time`](#exn-time) if the time does not fit.

**Example** `toSeconds (fromMilliseconds 1500) = 1`

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `toMilliseconds-inverts` &middot; `huge-exact-or-Time`

</details>

### <a name="val-frommicroseconds"></a>`fromMicroseconds`

```sml
val fromMicroseconds : LargeInt.int -> time
```

`fromMicroseconds n` is `n` microseconds.

**Raises** [`Time`](#exn-time) if the time does not fit.

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `toMicroseconds-inverts` &middot; `huge-exact-or-Time`

</details>

### <a name="val-fromnanoseconds"></a>`fromNanoseconds`

```sml
val fromNanoseconds : LargeInt.int -> time
```

`fromNanoseconds n` is `n` nanoseconds, truncated to what a time can hold.

**Raises** [`Time`](#exn-time) if the time does not fit.

<details><summary>Tests (6)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `less-than-a-microsecond` &middot; `toNanoseconds-inverts` &middot; `huge-exact-or-Time` &middot; `huge-negative-exact-or-Time`

</details>

### <a name="val-op-plus"></a>`+`

```sml
val + : time * time -> time
```

`t + u` is the sum of two times.

**Raises** [`Time`](#exn-time) if the sum does not fit.

> **Implementation** `Time.+/exact-until-it-raises`. Wherever the range ends,
> doubling a time over and over stays exact until one step raises [`Time`](#exn-time);
> no step gives a wrong value or another exception.

**Example** `fromSeconds 1 + fromMilliseconds 500 = fromMilliseconds 1500`

<details><summary>Tests (8)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `microseconds` &middot; `commutative` &middot; `adds-microseconds` &middot; `associative` &middot; `Time-when-not-representable` &middot; `Time-when-not-representable-negative`

</details>

### <a name="val-op-minus"></a>`-`

```sml
val - : time * time -> time
```

`t - u` is `t` less `u`, which may be negative.

**Raises** [`Time`](#exn-time) if the difference does not fit.

> **Implementation** `Time.-/exact-until-it-raises`. As for [`+`](#val-op-plus): exact until
> a step raises [`Time`](#exn-time).

<details><summary>Tests (7)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative-interval` &middot; `self-is-zeroTime` &middot; `inverts-+` &middot; `subtracts-microseconds` &middot; `Time-when-not-representable` &middot; `Time-when-not-representable-positive`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : time * time -> order
```

`compare (t, u)` orders two times, the shorter first.

<details><summary>Tests (6)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `less` &middot; `equal` &middot; `greater` &middot; `negative` &middot; `negative-and-zero` &middot; `agrees-with-microseconds`

</details>

### <a name="val-op-lt"></a>`<`

```sml
val < : time * time -> bool
```

`t < u` is `true` when `t` is the shorter time.

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `true` &middot; `equal` &middot; `false` &middot; `agrees-with-compare`

</details>

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : time * time -> bool
```

`t <= u` is `true` when `t` is no longer than `u`.

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `true` &middot; `equal` &middot; `false`

</details>

### <a name="val-op-gt"></a>`>`

```sml
val > : time * time -> bool
```

`t > u` is `true` when `t` is the longer time.

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `true` &middot; `equal` &middot; `false`

</details>

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : time * time -> bool
```

`t >= u` is `true` when `t` is no shorter than `u`.

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `true` &middot; `equal` &middot; `false`

</details>

### <a name="val-now"></a>`now`

```sml
val now : unit -> time
```

`now ()` is the time since [`zeroTime`](#val-zerotime), by the clock of the system.

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `after-zeroTime` &middot; `does-not-go-back` &middot; `advances`

</details>

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : int -> time -> string
```

`fmt n t` is `t` in seconds, with `n` digits after the decimal point and none when `n` is 0.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0`.

> **Reading** `Time.fmt/fixed-point`. The text has "fixed-point semantics":
> the digit last kept is rounded to nearest, and since a time holds
> microseconds every digit past the sixth is a zero.

**Example** `fmt 2 (fromMilliseconds 1500) = "1.50"`

**Example** `fmt 0 (fromMilliseconds 1500) = "2"`

**Example** `fmt 0 (fromMilliseconds 2500) = "3"`

<details><summary>Other implementations (3)</summary>

- **Poly/ML** &mdash; fmt with a negative number of digits does not raise Size
- **Poly/ML** &mdash; fmt goes through a real: fmt 6 of 12345678901.234567 s gives 12345678901.234568 ("Time values are required to have fixed-point semantics")
- **MLton** &mdash; fmt is Real.fmt of toReal: fmt 6 of 12345678901.234567 s gives 12345678901.234568 ("Time values are required to have fixed-point semantics")

</details>

<details><summary>Tests (24)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-3` &middot; `spec-example-0` &middot; `spec-example-zeroTime` &middot; `zeroTime-3` &middot; `rounds-down` &middot; `rounds-up` &middot; `carries-into-seconds` &middot; `0-rounds-up` &middot; `0-rounds-down` &middot; `whole-seconds` &middot; `microsecond` &middot; `more-digits-than-microseconds` &middot; `20-digits` &middot; `20-digits-microsecond` &middot; `40-digits` &middot; `negative` &middot; `negative-carries` &middot; `negative-0-digits` &middot; `fixed-point-semantics` &middot; `fixed-point-semantics-rounded` &middot; `large` &middot; `Size` (raises Size) &middot; `Size-zeroTime` (raises Size) &middot; `6-digits-of-microseconds`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : time -> string
```

`toString t` is `fmt 3 t`: seconds with three digits of the fraction.

**Example** `toString (fromMilliseconds ~1500) = "~1.500"`

<details><summary>Tests (7)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example` &middot; `rounds` &middot; `rounds-down` &middot; `negative` &middot; `zeroTime` &middot; `whole` &middot; `is-fmt-3`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (time, 'a) StringCvt.reader
```

`scan getc src` reads a number of seconds, after leading whitespace, and is the time and what is left.

What it reads is an optional sign, then digits, then optionally a point
and digits, or a point and digits alone.

**Raises** [`Time`](#exn-time) if the number does not fit.

> **Reading** `Time.scan/digits-past-the-sixth`. Any number of digits may be
> written; those of the fraction after the sixth are dropped rather than
> rounded, and a number too large for a time raises [`Time`](#exn-time).

<details><summary>Tests (10)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `rest` &middot; `rest-after-whole` &middot; `rest-after-fraction` &middot; `skips-whitespace` &middot; `rest-after-sign` &middot; `NONE` &middot; `NONE-point` &middot; `list-reader` &middot; `list-reader-NONE` &middot; `huge-exact-or-Time`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> time option
```

`fromString s` is `SOME` of the time that `s` begins with, after whitespace, or `NONE`.

**Law** `fromString s = StringCvt.scanString scan s`

**Raises** [`Time`](#exn-time) if the number does not fit.

**Example** `fromString " ~.25x" = SOME (fromMilliseconds ~250)`

<details><summary>Other implementations (1)</summary>

- **MLton, SML/NJ** &mdash; fromString "1." is NONE, although its prefix "1" denotes a time ("SOME(t) where t is the time value denoted by a prefix of s")

</details>

<details><summary>Tests (32)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `fraction` &middot; `whole` &middot; `leading-point` &middot; `leading-point-zero` &middot; `zero` &middot; `zero-point-zero` &middot; `tilde` &middot; `minus` &middot; `plus` &middot; `minus-leading-point` &middot; `negative-zero` &middot; `whitespace` &middot; `prefix` &middot; `trailing-point` &middot; `leading-zeros` &middot; `microsecond` &middot; `many-zero-digits` &middot; `many-fraction-digits` &middot; `tiny-fraction` &middot; `nanoseconds-lost-or-kept` &middot; `empty` &middot; `blank` &middot; `letters` &middot; `point-only` &middot; `sign-only` &middot; `sign-and-point` &middot; `space-after-sign` &middot; `two-signs` &middot; `huge-exact-or-Time` &middot; `huge-negative-exact-or-Time` &middot; `inverts-fmt-6` &middot; `inverts-toString-for-milliseconds`

</details>

## See also

[`DATE`](../sig/DATE.md), [`TIMER`](../sig/TIMER.md), [`OS_PROCESS`](../sig/OS_PROCESS.md)

---

<sub>Generated by runedoc from lib/basis/sig\_time.sml; do not edit.</sub>
