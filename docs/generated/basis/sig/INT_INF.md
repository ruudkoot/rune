# signature INT_INF

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **INT_INF**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | 100 checks of 10 entries |
| Source | [lib/basis/sig\_int\_inf.sml](../../../../lib/basis/sig_int_inf.sml) |

## Synopsis

```sml
signature INT_INF
structure IntInf : INT_INF  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `IntInf` | IntInf: arbitrary precision integers implemented in SML on top of the 64-bit int. A value is a sign and a little-endian list of base-2^30 limbs without high zero limbs; zero is never negative. The representation is therefore canonical and structural equality is value equality. | [lib/basis/intinf.sml](../../../../lib/basis/intinf.sml) |

Integers of arbitrary precision: everything [`INTEGER`](../sig/INTEGER.md) has, and the
operations that make sense only, or mostly, without a bound.

[`IntInf.int`](../sig/INTEGER.md#type-int) has no smallest and no largest value: [`precision`](../sig/INTEGER.md#val-precision), [`minInt`](../sig/INTEGER.md#val-minint)
and [`maxInt`](../sig/INTEGER.md#val-maxint) are `NONE`, and no operation raises [`Overflow`](../sig/GENERAL.md#exn-overflow) except the
conversions to a bounded type. The bit operations treat an integer as an
infinite string of bits in two's complement, so that a negative number has
infinitely many leading ones and `notb i` is `~(i + 1)`.

> **Implementation** `IntInf.int/limbs`. A sign and a list of digits in base
> 2^30, written in SML on top of the 64-bit [`int`](../sig/INTEGER.md#type-int); equal numbers are equal
> values, so `=` compares them. [`LargeInt`](../sig/INTEGER.md) is [`IntInf`](INT_INF.md).

## Contents

[Division](#division) &middot;
[Powers and logarithms](#powers-and-logarithms) &middot;
[Bits](#bits)

## Interface

<pre>
signature INT_INF =
sig
  include INTEGER

  val <a href="#val-divmod">divMod</a> : int * int -&gt; int * int

  val <a href="#val-quotrem">quotRem</a> : int * int -&gt; int * int

  val <a href="#val-pow">pow</a> : int * Int.int -&gt; int

  val <a href="#val-log2">log2</a> : int -&gt; Int.int

  val <a href="#val-orb">orb</a> : int * int -&gt; int

  val <a href="#val-xorb">xorb</a> : int * int -&gt; int

  val <a href="#val-andb">andb</a> : int * int -&gt; int

  val <a href="#val-notb">notb</a> : int -&gt; int

  val <a href="#val-op-lt-lt">&lt;&lt;</a> : int * Word.word -&gt; int

  val <a href="#val-op-tilde-gt-gt">~&gt;&gt;</a> : int * Word.word -&gt; int
end
</pre>

**Included from [`INTEGER`](../sig/INTEGER.md)**: `include INTEGER`

| Member |  |  |
| --- | --- | --- |
| [`int`](../sig/INTEGER.md#type-int) | eqtype | The type of integers of this structure. |
| [`toLarge`](../sig/INTEGER.md#val-tolarge) | val | `toLarge i` is `i` as an integer of `LargeInt`, which loses nothing. |
| [`fromLarge`](../sig/INTEGER.md#val-fromlarge) | val | `fromLarge i` is the integer of this structure with the value `i`. |
| [`toInt`](../sig/INTEGER.md#val-toint) | val | `toInt i` is `i` as an integer of the default structure `Int`. |
| [`fromInt`](../sig/INTEGER.md#val-fromint) | val | `fromInt i` is the integer of this structure with the value `i`. |
| [`precision`](../sig/INTEGER.md#val-precision) | val | `precision` is the number of bits of an integer of this structure, sign included, or `NONE` when there is no bound. |
| [`minInt`](../sig/INTEGER.md#val-minint) | val | `minInt` is the smallest integer of this structure, or `NONE` when there is none. |
| [`maxInt`](../sig/INTEGER.md#val-maxint) | val | `maxInt` is the largest integer of this structure, or `NONE` when there is none. |
| [`+`](../sig/INTEGER.md#val-op-plus) | val | `i + j` is the sum. |
| [`-`](../sig/INTEGER.md#val-op-minus) | val | `i - j` is the difference. |
| [`*`](../sig/INTEGER.md#val-op-star) | val | `i * j` is the product. |
| [`div`](../sig/INTEGER.md#val-div) | val | `i div j` is the quotient, rounded towards negative infinity. |
| [`mod`](../sig/INTEGER.md#val-mod) | val | `i mod j` is what `div` leaves over: it has the sign of `j`. |
| [`quot`](../sig/INTEGER.md#val-quot) | val | `quot (i, j)` is the quotient, rounded towards zero. |
| [`rem`](../sig/INTEGER.md#val-rem) | val | `rem (i, j)` is what `quot` leaves over: it has the sign of `i`. |
| [`compare`](../sig/INTEGER.md#val-compare) | val | `compare (i, j)` orders two integers. |
| [`<`](../sig/INTEGER.md#val-op-lt) | val | `i < j`, `i <= j`, `i > j` and `i >= j` compare two integers. |
| [`<=`](../sig/INTEGER.md#val-op-lt-eq) | val |  |
| [`>`](../sig/INTEGER.md#val-op-gt) | val |  |
| [`>=`](../sig/INTEGER.md#val-op-gt-eq) | val |  |
| [`~`](../sig/INTEGER.md#val-op-tilde) | val | `~i` is the negation of `i`. |
| [`abs`](../sig/INTEGER.md#val-abs) | val | `abs i` is the magnitude of `i`. |
| [`min`](../sig/INTEGER.md#val-min) | val | `min (i, j)` is the smaller of the two. |
| [`max`](../sig/INTEGER.md#val-max) | val | `max (i, j)` is the larger of the two. |
| [`sign`](../sig/INTEGER.md#val-sign) | val | `sign i` is \~1, 0 or 1, as `i` is negative, zero or positive. |
| [`sameSign`](../sig/INTEGER.md#val-samesign) | val | `sameSign (i, j)` is `true` when `i` and `j` have the same sign. |
| [`fmt`](../sig/INTEGER.md#val-fmt) | val | `fmt radix i` is the text of `i` in the given base, with `~` for a negative number. |
| [`toString`](../sig/INTEGER.md#val-tostring) | val | `toString i` is the text of `i` in base 10. |
| [`scan`](../sig/INTEGER.md#val-scan) | val | `scan radix getc strm` reads an integer in the given base from `strm`. |
| [`fromString`](../sig/INTEGER.md#val-fromstring) | val | `fromString s` is the integer that the text `s` begins with in base 10, or `NONE`. |

## Division

### <a name="val-divmod"></a>`divMod`

```sml
val divMod : int * int -> int * int
```

`divMod (i, j)` is the pair `(i div j, i mod j)`, computed in one
division.

The quotient is rounded towards negative infinity and the remainder has
the sign of `j`.

**Raises** [`Div`](../sig/GENERAL.md#exn-div) if `j` is zero.

<details><summary>Tests (12)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `Div` (raises Div) &middot; `Div-zero-by-zero` (raises Div) &middot; `Div-2^100` (raises Div) &middot; `10^30+7-by-10^15` &middot; `~10^30-7-by-10^15` &middot; `2^200+1-by-~2^200` &middot; `small-by-2^200` &middot; `as-Int*` &middot; `law*` &middot; `remainder*` &middot; `div-and-mod*`

</details>

### <a name="val-quotrem"></a>`quotRem`

```sml
val quotRem : int * int -> int * int
```

`quotRem (i, j)` is the pair `(quot (i, j), rem (i, j))`, computed in one
division.

The quotient is rounded towards zero and the remainder has the sign of
`i`.

**Raises** [`Div`](../sig/GENERAL.md#exn-div) if `j` is zero.

<details><summary>Tests (12)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `Div` (raises Div) &middot; `Div-zero-by-zero` (raises Div) &middot; `Div-~2^100` (raises Div) &middot; `10^30+7-by-10^15` &middot; `~10^30-7-by-10^15` &middot; `2^200+1-by-~2^200` &middot; `small-by-2^200` &middot; `as-Int*` &middot; `law*` &middot; `remainder*` &middot; `quot-and-rem*`

</details>

## Powers and logarithms

### <a name="val-pow"></a>`pow`

```sml
val pow : int * Int.int -> int
```

`pow (i, j)` is `i` to the power `j`.

For a negative `j` the result is what is left of `1 / i^~j` as an integer:
1 or \~1 when `i` is 1 or \~1, and 0 for every other `i` but 0.

**Raises** [`Div`](../sig/GENERAL.md#exn-div) if `i` is zero and `j` is negative.

**Example** `pow (2, 100) = 1267650600228229401496703205376`

<details><summary>Tests (18)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `Div-zero-to-minus-one` (raises Div) &middot; `Div-zero-to-minus-five` (raises Div) &middot; `2-to-64` &middot; `2-to-100` &middot; `2-to-200` &middot; `~2-to-201` &middot; `~2-to-200` &middot; `10-to-30` &middot; `2^64-squared` &middot; `2^100-to-one` &middot; `2^100-to-zero` &middot; `2^100-to-minus-one` &middot; `~2^100-to-minus-two` &middot; `as-Int*` &middot; `cube*` &middot; `sum-of-exponents*` &middot; `of-product*`

</details>

### <a name="val-log2"></a>`log2`

```sml
val log2 : int -> Int.int
```

`log2 i` is the largest `k` for which `2^k <= i`: the position of the
highest bit of `i`.

**Raises** [`Domain`](../sig/GENERAL.md#exn-domain) if `i <= 0`.

<details><summary>Tests (11)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `2^100` &middot; `2^100-1` &middot; `2^100+1` &middot; `2^1000` &middot; `10^30` &middot; `Domain-zero` (raises Domain) &middot; `Domain-minus-one` (raises Domain) &middot; `Domain-~2^100` (raises Domain) &middot; `number-of-digits*` &middot; `bounds*`

</details>

## Bits

### <a name="val-orb"></a>`orb`

```sml
val orb : int * int -> int
```

`orb (i, j)` is the bitwise "or" of `i` and `j`.

<details><summary>Tests (7)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `2^200-or-2^100` &middot; `~2^200-or-2^100` &middot; `~2^200-or-2^200-1` &middot; `model*` &middot; `de-morgan*` &middot; `andb-plus-orb*`

</details>

### <a name="val-xorb"></a>`xorb`

```sml
val xorb : int * int -> int
```

`xorb (i, j)` is the bitwise exclusive "or" of `i` and `j`.

<details><summary>Tests (7)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `2^200+2^100-xor-2^100` &middot; `~2^200-xor-2^200-1` &middot; `minus-one-xor-2^200` &middot; `model*` &middot; `orb-minus-andb*` &middot; `self*`

</details>

### <a name="val-andb"></a>`andb`

```sml
val andb : int * int -> int
```

`andb (i, j)` is the bitwise "and" of `i` and `j`.

<details><summary>Tests (7)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `2^200-with-*` &middot; `2^200-1-and-2^100` &middot; `~2^100-and-2^200-1` &middot; `model*` &middot; `de-morgan*` &middot; `commutative*`

</details>

### <a name="val-notb"></a>`notb`

```sml
val notb : int -> int
```

`notb i` is `i` with every bit inverted.

**Law** `notb i = ~(i + 1)`

<details><summary>Tests (6)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `2^200` &middot; `~2^200` &middot; `model*` &middot; `negation-minus-one*` &middot; `involution*`

</details>

### <a name="val-op-lt-lt"></a>`<<`

```sml
val << : int * Word.word -> int
```

`<< (i, n)` is `i` shifted left by `n` bits: `i * 2^n`.

<details><summary>Tests (8)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `one-by-100` &middot; `minus-one-by-100` &middot; `one-by-200` &middot; `2^36-by-64` &middot; `three-by-1000` &middot; `model*` &middot; `times-power*`

</details>

### <a name="val-op-tilde-gt-gt"></a>`~>>`

```sml
val ~>> : int * Word.word -> int
```

`~>> (i, n)` is `i` shifted right by `n` bits with its sign kept: `i div 2^n`, rounded towards negative infinity.

<details><summary>Tests (12)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `*` &middot; `2^100-by-100` &middot; `2^100-by-101` &middot; `~2^100-by-100` &middot; `~2^100-by-101` &middot; `~2^100-by-99` &middot; `~2^100-1-by-100` &middot; `2^200-by-100` &middot; `2^164-by-64` &middot; `model*` &middot; `floor-by-power*` &middot; `after-shift-left*`

</details>

## See also

[`INTEGER`](../sig/INTEGER.md), [`WORD`](../sig/WORD.md)

---

<sub>Generated by runedoc from lib/basis/sig\_int\_inf.sml; do not edit.</sub>
