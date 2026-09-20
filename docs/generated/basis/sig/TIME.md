# signature TIME

[The Standard ML Basis Library](../README.md) &rsaquo; **TIME**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 25 entries documented |
| Tests | 180 checks of 24 entries |
| Source | [lib/basis/sig\_time.sml](../../../../lib/basis/sig_time.sml) |

## Synopsis

```sml
signature TIME
structure Time : TIME
```

| Implementation |  | Source |
| --- | --- | --- |
| `Time` | Time: a length of time, held as microseconds. | [lib/basis/time.sml](../../../../lib/basis/time.sml) |

signature TIME, transcribed from <https://smlfamily.github.io/Basis/time.html>

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

### <a name="exn-time"></a>`Time`

```sml
exception Time
```

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `raise-and-handle` &middot; `is-its-own-exception` &middot; `fromReal-posInf` (raises)

</details>

### <a name="val-zerotime"></a>`zeroTime`

```sml
val zeroTime : time
```

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `is-fromReal-0.0` &middot; `is-zero-seconds` &middot; `toNanoseconds` &middot; `identity-of-+`

</details>

### <a name="val-fromreal"></a>`fromReal`

```sml
val fromReal : LargeReal.real -> time
```

<details><summary>Tests (15)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `one-and-a-half` &middot; `binary-fraction` &middot; `negative` &middot; `negative-zero` &middot; `whole-seconds` &middot; `spec-example-1.8` &middot; `fraction-of-a-microsecond-lost` &middot; `milliseconds` &middot; `posInf` (raises) &middot; `negInf` (raises) &middot; `nan` (raises) &middot; `huge-approximately-or-Time` &middot; `huge-negative-approximately-or-Time` &middot; `binary-fractions-exactly` &middot; `toReal-round-trip-within-a-microsecond`

</details>

### <a name="val-toreal"></a>`toReal`

```sml
val toReal : time -> LargeReal.real
```

<details><summary>Tests (8)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `milliseconds` &middot; `negative` &middot; `zeroTime` &middot; `whole-seconds` &middot; `microsecond` &middot; `binary-fractions-exactly` &middot; `random-approximately` &middot; `fromReal-round-trip-within-a-microsecond`

</details>

### <a name="val-toseconds"></a>`toSeconds`

```sml
val toSeconds : time -> LargeInt.int
```

<details><summary>Tests (7)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-2.01` &middot; `negative-towards-zero` &middot; `rounds-towards-zero` &middot; `rounds-negative-towards-zero` &middot; `less-than-a-second` &middot; `large` &middot; `is-toMicroseconds-quot`

</details>

### <a name="val-tomilliseconds"></a>`toMilliseconds`

```sml
val toMilliseconds : time -> LargeInt.int
```

<details><summary>Tests (5)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-2.01` &middot; `negative` &middot; `rounds-towards-zero` &middot; `rounds-negative-towards-zero` &middot; `large`

</details>

### <a name="val-tomicroseconds"></a>`toMicroseconds`

```sml
val toMicroseconds : time -> LargeInt.int
```

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-2.01` &middot; `negative` &middot; `exact` &middot; `large`

</details>

### <a name="val-tonanoseconds"></a>`toNanoseconds`

```sml
val toNanoseconds : time -> LargeInt.int
```

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-2.01` &middot; `negative` &middot; `microsecond` &middot; `beyond-64-bits`

</details>

### <a name="val-fromseconds"></a>`fromSeconds`

```sml
val fromSeconds : LargeInt.int -> time
```

<details><summary>Tests (6)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `agrees-with-finer-units` &middot; `huge-exact-or-Time` &middot; `huge-negative-exact-or-Time` &middot; `beyond-64-bit-microseconds-exact-or-Time`

</details>

### <a name="val-frommilliseconds"></a>`fromMilliseconds`

```sml
val fromMilliseconds : LargeInt.int -> time
```

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `toMilliseconds-inverts` &middot; `huge-exact-or-Time`

</details>

### <a name="val-frommicroseconds"></a>`fromMicroseconds`

```sml
val fromMicroseconds : LargeInt.int -> time
```

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `toMicroseconds-inverts` &middot; `huge-exact-or-Time`

</details>

### <a name="val-fromnanoseconds"></a>`fromNanoseconds`

```sml
val fromNanoseconds : LargeInt.int -> time
```

<details><summary>Tests (6)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `less-than-a-microsecond` &middot; `toNanoseconds-inverts` &middot; `huge-exact-or-Time` &middot; `huge-negative-exact-or-Time`

</details>

### <a name="val-op-plus"></a>`+`

```sml
val + : time * time -> time
```

<details><summary>Tests (8)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative` &middot; `microseconds` &middot; `commutative` &middot; `adds-microseconds` &middot; `associative` &middot; `Time-when-not-representable` &middot; `Time-when-not-representable-negative`

</details>

### <a name="val-op-minus"></a>`-`

```sml
val - : time * time -> time
```

<details><summary>Tests (7)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `basic` &middot; `negative-interval` &middot; `self-is-zeroTime` &middot; `inverts-+` &middot; `subtracts-microseconds` &middot; `Time-when-not-representable` &middot; `Time-when-not-representable-positive`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : time * time -> order
```

<details><summary>Tests (6)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `less` &middot; `equal` &middot; `greater` &middot; `negative` &middot; `negative-and-zero` &middot; `agrees-with-microseconds`

</details>

### <a name="val-op-lt"></a>`<`

```sml
val < : time * time -> bool
```

<details><summary>Tests (4)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `true` &middot; `equal` &middot; `false` &middot; `agrees-with-compare`

</details>

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : time * time -> bool
```

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `true` &middot; `equal` &middot; `false`

</details>

### <a name="val-op-gt"></a>`>`

```sml
val > : time * time -> bool
```

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `true` &middot; `equal` &middot; `false`

</details>

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : time * time -> bool
```

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `true` &middot; `equal` &middot; `false`

</details>

### <a name="val-now"></a>`now`

```sml
val now : unit -> time
```

<details><summary>Tests (3)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `after-zeroTime` &middot; `does-not-go-back` &middot; `advances`

</details>

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : int -> time -> string
```

<details><summary>Tests (24)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example-3` &middot; `spec-example-0` &middot; `spec-example-zeroTime` &middot; `zeroTime-3` &middot; `rounds-down` &middot; `rounds-up` &middot; `carries-into-seconds` &middot; `0-rounds-up` &middot; `0-rounds-down` &middot; `whole-seconds` &middot; `microsecond` &middot; `more-digits-than-microseconds` &middot; `20-digits` &middot; `20-digits-microsecond` &middot; `40-digits` &middot; `negative` &middot; `negative-carries` &middot; `negative-0-digits` &middot; `fixed-point-semantics` &middot; `fixed-point-semantics-rounded` &middot; `large` &middot; `Size` (raises Size) &middot; `Size-zeroTime` (raises Size) &middot; `6-digits-of-microseconds`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : time -> string
```

<details><summary>Tests (7)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `spec-example` &middot; `rounds` &middot; `rounds-down` &middot; `negative` &middot; `zeroTime` &middot; `whole` &middot; `is-fmt-3`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (time, 'a) StringCvt.reader
```

<details><summary>Tests (10)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `rest` &middot; `rest-after-whole` &middot; `rest-after-fraction` &middot; `skips-whitespace` &middot; `rest-after-sign` &middot; `NONE` &middot; `NONE-point` &middot; `list-reader` &middot; `list-reader-NONE` &middot; `huge-exact-or-Time`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> time option
```

<details><summary>Tests (32)</summary>

For `Time`, in [tests/basis/time.sml](../../../../tests/basis/time.sml): `fraction` &middot; `whole` &middot; `leading-point` &middot; `leading-point-zero` &middot; `zero` &middot; `zero-point-zero` &middot; `tilde` &middot; `minus` &middot; `plus` &middot; `minus-leading-point` &middot; `negative-zero` &middot; `whitespace` &middot; `prefix` &middot; `trailing-point` &middot; `leading-zeros` &middot; `microsecond` &middot; `many-zero-digits` &middot; `many-fraction-digits` &middot; `tiny-fraction` &middot; `nanoseconds-lost-or-kept` &middot; `empty` &middot; `blank` &middot; `letters` &middot; `point-only` &middot; `sign-only` &middot; `sign-and-point` &middot; `space-after-sign` &middot; `two-signs` &middot; `huge-exact-or-Time` &middot; `huge-negative-exact-or-Time` &middot; `inverts-fmt-6` &middot; `inverts-toString-for-milliseconds`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_time.sml; do not edit.</sub>
