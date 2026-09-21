# signature INTEGER

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **INTEGER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 9 |
| Documentation | 30 of 30 entries documented |
| Tests | 430 checks of 30 entries |
| Source | [lib/basis/int\_sig.sml](../../../../lib/basis/int_sig.sml) |

## Synopsis

```sml
signature INTEGER
structure FixedInt : INTEGER  (* optional *)
structure Int : INTEGER
structure Int16 : INTEGER  (* optional *)
structure Int32 : INTEGER  (* optional *)
structure Int64 : INTEGER  (* optional *)
structure Int8 : INTEGER  (* optional *)
structure IntInf : INTEGER  (* optional *)
structure LargeInt : INTEGER
structure Position : INTEGER
```

| Implementation |  | Source |
| --- | --- | --- |
| `FixedInt` |  | [lib/basis/int64.sml](../../../../lib/basis/int64.sml) |
| `Int` | Int: fixed precision integers with Overflow checking: 64 bits on the VM. The bounds are found with the arithmetic itself (2n + 1 until it overflows), so that this file means the same to a system whose int is narrower; see tests/basis/README.md on the xc1 configurations. | [lib/basis/int.sml](../../../../lib/basis/int.sml) |
| `Int16` | Int16: integers of 16 bits. | [lib/basis/int16.sml](../../../../lib/basis/int16.sml) |
| `Int32` | Int32: integers of 32 bits. | [lib/basis/int32.sml](../../../../lib/basis/int32.sml) |
| `Int64` | Int64 is Int, which has 64 bits, and so is FixedInt, the largest of the fixed-precision integers. | [lib/basis/int64.sml](../../../../lib/basis/int64.sml) |
| `Int8` | Int8: integers of 8 bits. | [lib/basis/int8.sml](../../../../lib/basis/int8.sml) |
| `IntInf` | IntInf: arbitrary precision integers implemented in SML on top of the 64-bit int. A value is a sign and a little-endian list of base-2^30 limbs without high zero limbs; zero is never negative. The representation is therefore canonical and structural equality is value equality. | [lib/basis/intinf.sml](../../../../lib/basis/intinf.sml) |
| `LargeInt` | The largest integers are the arbitrary precision ones. | [lib/basis/intinf.sml](../../../../lib/basis/intinf.sml) |
| `Position` | Position: the positions in a file. On the VM it is Int. | [lib/basis/position.sml](../../../../lib/basis/position.sml) |

Integers of a fixed precision, with arithmetic that raises [`Overflow`](../sig/GENERAL.md#exn-overflow)
rather than wrapping round.

The structures that implement this signature differ only in how many bits
they keep: [`Int`](INTEGER.md) is the default one, [`Int8`](INTEGER.md) to [`Int64`](INTEGER.md) are the sized ones,
[`LargeInt`](INTEGER.md) is the largest there is, and [`Position`](INTEGER.md) is what a file position
is measured in. [`IntInf`](../sig/INT_INF.md) implements it too, through [`INT_INF`](../sig/INT_INF.md), and has no
bounds at all: there [`precision`](#val-precision), [`minInt`](#val-minint) and [`maxInt`](#val-maxint) are `NONE` and
nothing overflows.

Two integers of different structures are of different types, and the
conversions between them go through [`Int.int`](#type-int) or [`LargeInt.int`](#type-int)
([`toInt`](#val-toint), [`fromInt`](#val-fromint), [`toLarge`](#val-tolarge), [`fromLarge`](#val-fromlarge)), each of which raises
[`Overflow`](../sig/GENERAL.md#exn-overflow) when the value does not fit.

[`div`](#val-div) and [`mod`](#val-mod) round towards negative infinity, so the remainder has the
sign of the divisor; [`quot`](#val-quot) and [`rem`](#val-rem) round towards zero, so the remainder
has the sign of the dividend. The first pair is what the language's
infix [`div`](#val-div) and [`mod`](#val-mod) mean.

## Contents

[The type](#the-type) &middot;
[Conversions](#conversions) &middot;
[The range](#the-range) &middot;
[Arithmetic](#arithmetic) &middot;
[Comparing](#comparing) &middot;
[Text](#text)

## Interface

<pre>
signature INTEGER =
sig

  eqtype <a href="#type-int">int</a>

  val <a href="#val-tolarge">toLarge</a> : int -&gt; LargeInt.int

  val <a href="#val-fromlarge">fromLarge</a> : LargeInt.int -&gt; int

  val <a href="#val-toint">toInt</a> : int -&gt; Int.int

  val <a href="#val-fromint">fromInt</a> : Int.int -&gt; int

  val <a href="#val-precision">precision</a> : Int.int option

  val <a href="#val-minint">minInt</a> : int option

  val <a href="#val-maxint">maxInt</a> : int option

  val <a href="#val-op-plus">+</a> : int * int -&gt; int

  val <a href="#val-op-minus">-</a> : int * int -&gt; int

  val <a href="#val-op-star">*</a> : int * int -&gt; int

  val <a href="#val-div">div</a> : int * int -&gt; int

  val <a href="#val-mod">mod</a> : int * int -&gt; int

  val <a href="#val-quot">quot</a> : int * int -&gt; int

  val <a href="#val-rem">rem</a> : int * int -&gt; int

  val <a href="#val-compare">compare</a> : int * int -&gt; order

  val <a href="#val-op-lt">&lt;</a> : int * int -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : int * int -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : int * int -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : int * int -&gt; bool

  val <a href="#val-op-tilde">~</a> : int -&gt; int

  val <a href="#val-abs">abs</a> : int -&gt; int

  val <a href="#val-min">min</a> : int * int -&gt; int

  val <a href="#val-max">max</a> : int * int -&gt; int

  val <a href="#val-sign">sign</a> : int -&gt; Int.int

  val <a href="#val-samesign">sameSign</a> : int * int -&gt; bool

  val <a href="#val-fmt">fmt</a> : StringCvt.radix -&gt; int -&gt; string

  val <a href="#val-tostring">toString</a> : int -&gt; string

  val <a href="#val-scan">scan</a> : StringCvt.radix -&gt; (char, 'a) StringCvt.reader -&gt; (int, 'a) StringCvt.reader

  val <a href="#val-fromstring">fromString</a> : string -&gt; int option
end
</pre>

## The type

### <a name="type-int"></a>`int`

```sml
eqtype int
```

The type of integers of this structure.

> **Implementation** `Int.int/64-bits`. [`Int.int`](#type-int) is the top-level [`int`](#type-int), of
> 64 bits, and so are [`Int64`](INTEGER.md), [`FixedInt`](INTEGER.md) and [`Position`](INTEGER.md); [`Int8`](INTEGER.md), [`Int16`](INTEGER.md)
> and [`Int32`](INTEGER.md) keep a value of their own width, and [`LargeInt`](INTEGER.md) is [`IntInf`](../sig/INT_INF.md),
> which has no width. Constants of each are checked against its range
> where they are written.

<details><summary>Tests (3)</summary>

For `LargeInt`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `is-IntInf.int`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `is-toplevel-int` &middot; `toplevel-is-Int.int`

</details>

## Conversions

### <a name="val-tolarge"></a>`toLarge`

```sml
val toLarge : int -> LargeInt.int
```

`toLarge i` is `i` as an integer of [`LargeInt`](INTEGER.md), which loses nothing.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (9)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `identity`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `zero` &middot; `positive` &middot; `negative` &middot; `maxInt` &middot; `minInt` &middot; `2^200` &middot; `~2^200` &middot; `model*`

</details>

### <a name="val-fromlarge"></a>`fromLarge`

```sml
val fromLarge : LargeInt.int -> int
```

`fromLarge i` is the integer of this structure with the value `i`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if `i` is outside the range of this structure.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (14)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `identity`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `zero` &middot; `positive` &middot; `negative` &middot; `round-trip` &middot; `maxInt` &middot; `minInt` &middot; `Overflow-maxInt-plus-one` &middot; `Overflow-minInt-minus-one` &middot; `Overflow-twice-maxInt` &middot; `Overflow-twice-minInt` &middot; `2^200` &middot; `~2^200` &middot; `model*`

</details>

### <a name="val-toint"></a>`toInt`

```sml
val toInt : int -> Int.int
```

`toInt i` is `i` as an integer of the default structure [`Int`](INTEGER.md).

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if `i` is outside the range of [`Int.int`](#type-int).

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (16)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `identity` &middot; `identity-on-bounds`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `zero` &middot; `positive` &middot; `negative` &middot; `sum` &middot; `maxInt` &middot; `minInt` &middot; `Overflow-2^200` &middot; `Overflow-~2^200` &middot; `Int.maxInt` &middot; `Int.minInt` &middot; `Overflow-Int.maxInt-plus-one` &middot; `Overflow-Int.minInt-minus-one` &middot; `model*`

</details>

### <a name="val-fromint"></a>`fromInt`

```sml
val fromInt : Int.int -> int
```

`fromInt i` is the integer of this structure with the value `i`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if `i` is outside the range of this structure.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (13)</summary>

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `identity` &middot; `identity-on-bounds`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `distinct` &middot; `equal` &middot; `round-trip` &middot; `maxInt` &middot; `minInt` &middot; `Overflow-maxInt-plus-one` &middot; `Overflow-minInt-minus-one` &middot; `Int.maxInt-plus-one` &middot; `Int.minInt` &middot; `samples-built`

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `scan-samples-built`

</details>

## The range

### <a name="val-precision"></a>`precision`

```sml
val precision : Int.int option
```

[`precision`](#val-precision) is the number of bits of an integer of this structure, sign included, or `NONE` when there is no bound.

**Example** `Int.precision = SOME 64` and `IntInf.precision = NONE`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (7)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `NONE`

For `LargeInt`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `is-IntInf.precision`

For `Int64`, in [tests/basis/intn\_int64.sml](../../../../tests/basis/intn_int64.sml): `64`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `bounds-are-representable` &middot; `at-least-8` &middot; `NONE-iff-minInt-NONE` &middot; `NONE-iff-maxInt-NONE`

</details>

### <a name="val-minint"></a>`minInt`

```sml
val minInt : int option
```

[`minInt`](#val-minint) is the smallest integer of this structure, or `NONE` when there is none.

**Law** `minInt = SOME (~(2 ^ (p - 1)))` where `precision = SOME p`

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (5)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `no-least-number`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `two-complement` &middot; `maxInt-plus-one-negated` &middot; `toString` &middot; `NONE`

</details>

### <a name="val-maxint"></a>`maxInt`

```sml
val maxInt : int option
```

[`maxInt`](#val-maxint) is the largest integer of this structure, or `NONE` when there is none.

**Law** `maxInt = SOME (2 ^ (p - 1) - 1)` where `precision = SOME p`. The
range is not symmetric: `~minInt` overflows and `abs minInt` does too.

**Example** `Int.maxInt = SOME 9223372036854775807`

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (7)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `no-greatest-number`

For `Int8`, in [tests/basis/intn\_int8.sml](../../../../tests/basis/intn_int8.sml): `constant`

For `Int16`, in [tests/basis/intn\_int16.sml](../../../../tests/basis/intn_int16.sml): `constant`

For `Int32`, in [tests/basis/intn\_int32.sml](../../../../tests/basis/intn_int32.sml): `constant`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `two-complement` &middot; `toString` &middot; `NONE`

</details>

## Arithmetic

### <a name="val-op-plus"></a>`+`

```sml
val + : int * int -> int
```

`i + j` is the sum.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if the result is outside the range of this structure.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (30)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `2^63-twice` &middot; `carry-chain` &middot; `as-Int*` &middot; `associative*`

For `LargeInt`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `is-IntInf.+`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-Overflow` (raises Overflow)

For `Int8`, in [tests/basis/intn\_int8.sml](../../../../tests/basis/intn_int8.sml): `overloaded` &middot; `overloaded-Overflow` (raises Overflow)

For `Int16`, in [tests/basis/intn\_int16.sml](../../../../tests/basis/intn_int16.sml): `overloaded` &middot; `overloaded-Overflow` (raises Overflow)

For `Int32`, in [tests/basis/intn\_int32.sml](../../../../tests/basis/intn_int32.sml): `overloaded` &middot; `overloaded-Overflow` (raises Overflow)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Overflow-maxInt-plus-one` &middot; `Overflow-one-plus-maxInt` &middot; `Overflow-minInt-plus-minus-one` &middot; `Overflow-maxInt-twice` &middot; `Overflow-minInt-twice` &middot; `Overflow-half-range-twice` &middot; `maxInt-plus-zero` &middot; `up-to-maxInt` &middot; `minInt-plus-maxInt` &middot; `down-to-minInt` &middot; `2^200-twice` &middot; `2^200-inverse` &middot; `zero-times-2^200-plus-minus-six` &middot; `model*` &middot; `commutative*` &middot; `then-minus*`

</details>

### <a name="val-op-minus"></a>`-`

```sml
val - : int * int -> int
```

`i - j` is the difference.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if the result is outside the range.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (20)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `10^30-minus-one` &middot; `one-minus-10^30` &middot; `as-Int*` &middot; `inverse-of-plus*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-Overflow` (raises Overflow)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Overflow-maxInt-minus-minus-one` &middot; `Overflow-minInt-minus-one` &middot; `Overflow-zero-minus-minInt` &middot; `Overflow-maxInt-minus-minInt` &middot; `Overflow-minInt-minus-maxInt` &middot; `minus-one-minus-minInt` &middot; `zero-minus-maxInt` &middot; `minInt-minus-minInt` &middot; `maxInt-minus-maxInt` &middot; `zero-minus-2^200` &middot; `2^201-minus-2^200` &middot; `model*` &middot; `plus-negation*`

</details>

### <a name="val-op-star"></a>`*`

```sml
val * : int * int -> int
```

`i * j` is the product.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if the result is outside the range.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (40)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `2^64-squared` &middot; `2^50-squared` &middot; `factorial-20` &middot; `factorial-25` &middot; `factorial-30` &middot; `negative-factorial` &middot; `10^15+1-times-10^15-1` &middot; `as-Int*` &middot; `difference-of-squares*` &middot; `distributive*` &middot; `commutative*` &middot; `associative*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-Overflow` (raises Overflow)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Overflow-maxInt-times-two` &middot; `Overflow-minInt-times-minus-one` &middot; `Overflow-minus-one-times-minInt` &middot; `Overflow-minInt-times-two` &middot; `Overflow-half-range-times-two` &middot; `Overflow-minInt-squared` &middot; `Overflow-maxInt-squared` &middot; `Overflow-maxInt-times-minInt` &middot; `Overflow-square-of-power` &middot; `square-of-power` &middot; `minInt-times-one` &middot; `one-times-minInt` &middot; `maxInt-times-minus-one` &middot; `half-range-times-minus-two` &middot; `minInt-times-zero` &middot; `zero-times-minInt` &middot; `zero-times-maxInt` &middot; `2^200-squared` &middot; `2^200-times-minus-two` &middot; `2^200-times-zero` &middot; `zero-times-2^200` &middot; `zero-times-~2^200` &middot; `model*` &middot; `by-two*` &middot; `by-minus-one*`

</details>

### <a name="val-div"></a>`div`

```sml
val div : int * int -> int
```

`i div j` is the quotient, rounded towards negative infinity.

**Raises** [`Div`](../sig/GENERAL.md#exn-div) if `j` is zero; [`Overflow`](../sig/GENERAL.md#exn-overflow) if the result is outside the
range, which happens for `minInt div ~1`.

**Example** `~7 div 2 = ~4`, where `~7 quot 2` is `~3`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (32)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `factorial-30-by-factorial-25` &middot; `2^64-by-10^9` &middot; `~2^64-by-10^9` &middot; `2^64-by-~10^9` &middot; `as-Int*` &middot; `of-product*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-floor` &middot; `toplevel-Div` (raises Div) &middot; `toplevel-Overflow` (raises Overflow)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Div` &middot; `Div-negative` &middot; `Div-zero-by-zero` &middot; `Overflow-minInt-by-minus-one` &middot; `Div-minInt` &middot; `minInt-by-one` &middot; `minInt-by-two` &middot; `maxInt-by-minus-one` &middot; `maxInt-by-two` &middot; `next-to-minInt-by-minus-one` &middot; `minInt-by-maxInt` &middot; `maxInt-by-minInt` &middot; `minInt-by-minInt` &middot; `one-by-minInt` &middot; `minus-one-by-minInt` &middot; `2^400-by-2^200` &middot; `2^200+1-by-~2^200` &middot; `Div-2^200` &middot; `law*` &middot; `versus-quot*` &middot; `by-one*`

</details>

### <a name="val-mod"></a>`mod`

```sml
val mod : int * int -> int
```

`i mod j` is what [`div`](#val-div) leaves over: it has the sign of `j`.

**Raises** [`Div`](../sig/GENERAL.md#exn-div) if `j` is zero.

**Law** `(i div j) * j + (i mod j) = i`

> **Reading** `Int.mod/minInt-by-minus-one`. [`mod`](#val-mod) never raises [`Overflow`](../sig/GENERAL.md#exn-overflow),
> although [`div`](#val-div) does at the same arguments: `minInt mod ~1` is 0.

**Example** `~7 mod 2 = 1` where `rem (~7, 2)` is `~1`.

<details><summary>Other implementations (2)</summary>

- **SML/NJ (64-bit)** &mdash; mod (minInt, \~1) raises an exception instead of giving 0 (Int32 on 110.79, Int64 on both)
- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (29)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `factorial-30-by-factorial-25` &middot; `2^64-by-10^9` &middot; `~2^64-by-10^9` &middot; `2^64-by-~10^9` &middot; `as-Int*` &middot; `of-product*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-sign-of-divisor` &middot; `toplevel-Div` (raises Div)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Div` &middot; `Div-negative` &middot; `Div-zero-by-zero` &middot; `minInt-by-minus-one` &middot; `Div-minInt` &middot; `minInt-by-two` &middot; `maxInt-by-minus-one` &middot; `maxInt-by-two` &middot; `minInt-by-maxInt` &middot; `maxInt-by-minInt` &middot; `minInt-by-minInt` &middot; `one-by-minInt` &middot; `minus-one-by-minInt` &middot; `2^400-by-2^200` &middot; `2^200+1-by-~2^200` &middot; `Div-2^200` &middot; `sign-of-divisor*` &middot; `magnitude*` &middot; `by-one*`

</details>

### <a name="val-quot"></a>`quot`

```sml
val quot : int * int -> int
```

`quot (i, j)` is the quotient, rounded towards zero.

**Raises** [`Div`](../sig/GENERAL.md#exn-div) if `j` is zero; [`Overflow`](../sig/GENERAL.md#exn-overflow) for `quot (minInt, ~1)`.

**Example** `quot (~7, 2) = ~3`, where `~7 div 2` is `~4`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (22)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `~2^64-by-10^9` &middot; `2^64-by-~10^9` &middot; `as-Int*` &middot; `of-product*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Div` &middot; `Div-negative` &middot; `Div-zero-by-zero` &middot; `Overflow-minInt-by-minus-one` &middot; `Div-minInt` &middot; `minInt-by-two` &middot; `maxInt-by-minus-one` &middot; `next-to-minInt-by-minus-one` &middot; `minInt-by-maxInt` &middot; `maxInt-by-minInt` &middot; `minInt-by-minInt` &middot; `one-by-minInt` &middot; `2^200+1-by-~2^200` &middot; `~2^400-by-2^200` &middot; `Div-2^200` &middot; `law*` &middot; `by-one*`

</details>

### <a name="val-rem"></a>`rem`

```sml
val rem : int * int -> int
```

`rem (i, j)` is what [`quot`](#val-quot) leaves over: it has the sign of `i`.

**Raises** [`Div`](../sig/GENERAL.md#exn-div) if `j` is zero.

**Law** `quot (i, j) * j + rem (i, j) = i`

> **Reading** `Int.rem/minInt-by-minus-one`. As [`mod`](#val-mod), it never raises
> [`Overflow`](../sig/GENERAL.md#exn-overflow): `rem (minInt, ~1)` is 0.

**Example** `rem (~7, 2) = ~1` where `~7 mod 2` is `1`.

<details><summary>Other implementations (2)</summary>

- **SML/NJ (64-bit)** &mdash; rem (minInt, \~1) raises an exception instead of giving 0 (Int32 on 110.79, Int64 on both)
- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (20)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `~2^64-by-10^9` &middot; `2^64-by-~10^9` &middot; `as-Int*` &middot; `of-product*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Div` &middot; `Div-negative` &middot; `Div-zero-by-zero` &middot; `minInt-by-minus-one` &middot; `Div-minInt` &middot; `minInt-by-two` &middot; `minInt-by-maxInt` &middot; `maxInt-by-minInt` &middot; `minInt-by-minInt` &middot; `one-by-minInt` &middot; `2^200+1-by-~2^200` &middot; `Div-2^200` &middot; `sign-of-dividend*` &middot; `magnitude*` &middot; `by-one*`

</details>

## Comparing

### <a name="val-compare"></a>`compare`

```sml
val compare : int * int -> order
```

`compare (i, j)` orders two integers.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (15)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*` &middot; `successor*` &middot; `difference*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `minInt-minInt` &middot; `maxInt-maxInt` &middot; `minInt-zero` &middot; `2^200-and-successor` &middot; `2^200-and-~2^200` &middot; `2^200-equal` &middot; `~2^200-and-~2^201` &middot; `model*` &middot; `reflexive*`

</details>

### <a name="val-op-lt"></a><a name="val-op-lt-eq"></a><a name="val-op-gt"></a><a name="val-op-gt-eq"></a>`<`, `<=`, `>`, `>=`

```sml
val < : int * int -> bool
val <= : int * int -> bool
val > : int * int -> bool
val >= : int * int -> bool
```

`i < j`, `i <= j`, `i > j` and `i >= j` compare two integers.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (11)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `minInt-minInt` &middot; `2^200-2^201` &middot; `model*` &middot; `2^200-2^200` &middot; `maxInt-maxInt` &middot; `~2^200-~2^201`

</details>

### <a name="val-op-tilde"></a>`~`

```sml
val ~ : int -> int
```

`~i` is the negation of `i`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) for `~minInt`, which is not in the range.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (16)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*` &middot; `minus-from-zero*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-Overflow` (raises Overflow)

For `Int8`, in [tests/basis/intn\_int8.sml](../../../../tests/basis/intn_int8.sml): `overloaded-minInt`

For `Int16`, in [tests/basis/intn\_int16.sml](../../../../tests/basis/intn_int16.sml): `overloaded-minInt`

For `Int32`, in [tests/basis/intn\_int32.sml](../../../../tests/basis/intn_int32.sml): `overloaded-minInt`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `positive` &middot; `negative` &middot; `zero` &middot; `Overflow-minInt` &middot; `maxInt` &middot; `next-to-minInt` &middot; `2^200` &middot; `model*` &middot; `involution*`

</details>

### <a name="val-abs"></a>`abs`

```sml
val abs : int -> int
```

`abs i` is the magnitude of `i`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) for `abs minInt`.

<details><summary>Other implementations (2)</summary>

- **SML/NJ 110.99.9 (64-bit)** &mdash; Int32.abs minInt gives minInt instead of raising Overflow
- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (13)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-Overflow` (raises Overflow)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `positive` &middot; `negative` &middot; `zero` &middot; `Overflow-minInt` &middot; `next-to-minInt` &middot; `maxInt` &middot; `~2^200` &middot; `2^200` &middot; `model*` &middot; `law*`

</details>

### <a name="val-min"></a>`min`

```sml
val min : int * int -> int
```

`min (i, j)` is the smaller of the two.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (6)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `2^200-~2^201` &middot; `model*`

</details>

### <a name="val-max"></a>`max`

```sml
val max : int * int -> int
```

`max (i, j)` is the larger of the two.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (6)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `2^200-~2^201` &middot; `model*`

</details>

### <a name="val-sign"></a>`sign`

```sml
val sign : int -> Int.int
```

`sign i` is \~1, 0 or 1, as `i` is negative, zero or positive.

**Example** `sign ~3 = ~1`

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (12)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `positive` &middot; `negative` &middot; `zero` &middot; `one` &middot; `minus-one` &middot; `minInt` &middot; `maxInt` &middot; `zero-times-2^200` &middot; `2^200` &middot; `~2^200` &middot; `model*`

</details>

### <a name="val-samesign"></a>`sameSign`

```sml
val sameSign : int * int -> bool
```

`sameSign (i, j)` is `true` when `i` and `j` have the same sign.

> **Reading** `Int.sameSign/zero-pos`. It is "equivalent to `sign i = sign j`", so zero has the same sign as zero only, and not as a positive
> number.

**Law** `sameSign (i, j) = (sign i = sign j)`

**Example** `sameSign (0, 1) = false`

<details><summary>Other implementations (2)</summary>

- **SML/NJ (32-bit)** &mdash; sameSign (0, i) is true for positive i
- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (10)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `minInt-minus-one` &middot; `maxInt-one` &middot; `minInt-zero` &middot; `zero-maxInt` &middot; `2^200-one` &middot; `2^200-~2^200` &middot; `model*`

</details>

## Text

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : StringCvt.radix -> int -> string
```

`fmt radix i` is the text of `i` in the given base, with [`~`](#val-op-tilde) for a negative number.

There is no prefix: a hexadecimal number is written with the digits `A`
to `F` and nothing before them.

**Example** `fmt StringCvt.HEX 255 = "FF"` and `fmt StringCvt.BIN ~5 = "~101"`

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; IntInf.fmt StringCvt.HEX produces the digits a to f, not A to F
- **SML/NJ (32-bit)** &mdash; Int64.fmt StringCvt.HEX produces the digits a to f, not A to F

</details>

<details><summary>Tests (2)</summary>

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `model*`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : int -> string
```

`toString i` is the text of `i` in base 10.

**Law** `toString i = fmt StringCvt.DEC i`

**Example** `toString ~5 = "~5"`

<details><summary>Other implementations (1)</summary>

- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (12)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `10^30` &middot; `~10^30` &middot; `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt` &middot; `maxInt` &middot; `next-to-minInt` &middot; `2^200` &middot; `~2^200` &middot; `2^200-1` &middot; `model*`

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `fmt-DEC-*`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (int, 'a) StringCvt.reader
```

`scan radix getc strm` reads an integer in the given base from `strm`.

It skips initial white space, takes an optional sign ([`~`](#val-op-tilde) or [`-`](#val-op-minus) for a
negative number, [`+`](#val-op-plus) for a positive one) and then the digits. In
[`StringCvt.HEX`](../sig/STRING_CVT.md#con-hex) an optional `0x` or `0X` may stand before them. The
answer is `SOME (i, rest)`, or `NONE` when no digit is there, and then
nothing has been consumed.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if the digits name a number outside the range of this
structure.

> **Reading** `Int.scan/HEX-bare-prefix-0x`. A `0x` that no digit follows is
> not a prefix, but its `0` is a digit: `"0xg"` scans as 0 and leaves
> `"xg"` in the stream.

**Example** `StringCvt.scanString (scan StringCvt.HEX) "0x1F" = SOME 31`

<details><summary>Other implementations (5)</summary>

- **SML/NJ** &mdash; scan does not skip vertical tab, form feed and carriage return
- **SML/NJ 110.99.9** &mdash; IntInf.scan StringCvt.BIN accepts characters that are not binary digits ("2" is 2, "0b101" and "0x1" are numbers)
- **SML/NJ 110.99.9** &mdash; IntInf.scan StringCvt.OCT accepts the digits 8 and 9 and the letter x ("0x17" is 15)
- **SML/NJ (32-bit)** &mdash; Int64.scan raises an exception for a value that does not fit 32 bits
- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (12)</summary>

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `HEX-0xg-is-zero` &middot; `HEX-0x-123-is-zero` &middot; `string-position` &middot; `string-position-second` &middot; `HEX-minInt-with-prefix` &middot; `HEX-maxInt-lower-case` &middot; `HEX-Overflow-with-prefix` &middot; `HEX-2^300-1-lower-case-with-prefix` &middot; `model*` &middot; `model-lower-case-rest*` &middot; `fmt-round-trip*`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> int option
```

`fromString s` is the integer that the text `s` begins with in base 10, or `NONE`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if the digits name a number outside the range.

**Law** `fromString s = StringCvt.scanString (scan StringCvt.DEC) s`

**Example** `fromString " +12x" = SOME 12`

**Example** `fromString "0x1F" = SOME 0` for it reads decimal digits only.

<details><summary>Other implementations (3)</summary>

- **SML/NJ** &mdash; IntInf.fromString and Word.fromString do not skip vertical tab, form feed and carriage return
- **SML/NJ (32-bit)** &mdash; Int64.fromString raises an exception for a value that does not fit 32 bits
- **SML/NJ (32-bit)** &mdash; Int64 is emulated with two words and comes out wrong throughout: Int64.+ (\~2, \~3) is 1073741819, and the comparisons, div, mod, abs, sign, fmt and the conversions follow it

</details>

<details><summary>Tests (27)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `2^64` &middot; `factorial-30` &middot; `~2^128` &middot; `as-Int*` &middot; `toString*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt` &middot; `minInt-with-minus` &middot; `maxInt` &middot; `maxInt-with-plus` &middot; `maxInt-then-letters` &middot; `maxInt-with-leading-zeros` &middot; `minInt-with-leading-zeros` &middot; `Overflow-maxInt-plus-one` &middot; `Overflow-minInt-minus-one` &middot; `Overflow-maxInt-times-ten` &middot; `Overflow-minInt-times-ten` &middot; `Overflow-after-whitespace` &middot; `Overflow-many-digits` &middot; `2^200` &middot; `~2^200` &middot; `-2^200` &middot; `2^200-then-letters` &middot; `model*` &middot; `other-sign*` &middot; `round-trip*`

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `scanString-*`

</details>

## See also

[`INT_INF`](../sig/INT_INF.md), [`WORD`](../sig/WORD.md), [`REAL`](../sig/REAL.md), [`STRING_CVT`](../sig/STRING_CVT.md)

---

<sub>Generated by runedoc from lib/basis/int\_sig.sml; do not edit.</sub>
