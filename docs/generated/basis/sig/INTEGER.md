# signature INTEGER

[The Standard ML Basis Library](../README.md) &rsaquo; **INTEGER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 7 |
| Documentation | 0 of 30 entries documented |
| Tests | 430 checks of 30 entries |
| Source | [lib/basis/int\_sig.sml](../../../../lib/basis/int_sig.sml) |

## Synopsis

```sml
signature INTEGER
structure Int : INTEGER
structure Int16 : INTEGER  (* optional *)
structure Int32 : INTEGER  (* optional *)
structure Int64 : INTEGER  (* optional *)
structure Int8 : INTEGER  (* optional *)
structure IntInf : INTEGER  (* optional *)
structure LargeInt : INTEGER
```

| Implementation |  | Source |
| --- | --- | --- |
| `Int` | Int: fixed precision integers with Overflow checking: 64 bits on the VM. The bounds are found with the arithmetic itself (2n + 1 until it overflows), so that this file means the same to a system whose int is narrower; see tests/basis/README.md on the xc1 configurations. | [lib/basis/int.sml](../../../../lib/basis/int.sml) |
| `Int16` | Int16: integers of 16 bits. | [lib/basis/int16.sml](../../../../lib/basis/int16.sml) |
| `Int32` | Int32: integers of 32 bits. | [lib/basis/int32.sml](../../../../lib/basis/int32.sml) |
| `Int64` | Int64 is Int, which has 64 bits, and so is FixedInt, the largest of the fixed-precision integers. | [lib/basis/int64.sml](../../../../lib/basis/int64.sml) |
| `Int8` | Int8: integers of 8 bits. | [lib/basis/int8.sml](../../../../lib/basis/int8.sml) |
| `IntInf` | IntInf: arbitrary precision integers implemented in SML on top of the 64-bit int. A value is a sign and a little-endian list of base-2^30 limbs without high zero limbs; zero is never negative. The representation is therefore canonical and structural equality is value equality. | [lib/basis/intinf.sml](../../../../lib/basis/intinf.sml) |
| `LargeInt` | The largest integers are the arbitrary precision ones. | [lib/basis/intinf.sml](../../../../lib/basis/intinf.sml) |

signature INTEGER, which the IntN structures are sealed with.

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

### <a name="type-int"></a>`int`

```sml
eqtype int
```

<details><summary>Tests (3)</summary>

For `LargeInt`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `is-IntInf.int`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `is-toplevel-int` &middot; `toplevel-is-Int.int`

</details>

### <a name="val-tolarge"></a>`toLarge`

```sml
val toLarge : int -> LargeInt.int
```

<details><summary>Tests (9)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `identity`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `zero` &middot; `positive` &middot; `negative` &middot; `maxInt` &middot; `minInt` &middot; `2^200` &middot; `~2^200` &middot; `model*`

</details>

### <a name="val-fromlarge"></a>`fromLarge`

```sml
val fromLarge : LargeInt.int -> int
```

<details><summary>Tests (14)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `identity`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `zero` &middot; `positive` &middot; `negative` &middot; `round-trip` &middot; `maxInt` &middot; `minInt` &middot; `Overflow-maxInt-plus-one` &middot; `Overflow-minInt-minus-one` &middot; `Overflow-twice-maxInt` &middot; `Overflow-twice-minInt` &middot; `2^200` &middot; `~2^200` &middot; `model*`

</details>

### <a name="val-toint"></a>`toInt`

```sml
val toInt : int -> Int.int
```

<details><summary>Tests (16)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `identity` &middot; `identity-on-bounds`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `zero` &middot; `positive` &middot; `negative` &middot; `sum` &middot; `maxInt` &middot; `minInt` &middot; `Overflow-2^200` &middot; `Overflow-~2^200` &middot; `Int.maxInt` &middot; `Int.minInt` &middot; `Overflow-Int.maxInt-plus-one` &middot; `Overflow-Int.minInt-minus-one` &middot; `model*`

</details>

### <a name="val-fromint"></a>`fromInt`

```sml
val fromInt : Int.int -> int
```

<details><summary>Tests (13)</summary>

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `identity` &middot; `identity-on-bounds`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `distinct` &middot; `equal` &middot; `round-trip` &middot; `maxInt` &middot; `minInt` &middot; `Overflow-maxInt-plus-one` &middot; `Overflow-minInt-minus-one` &middot; `Int.maxInt-plus-one` &middot; `Int.minInt` &middot; `samples-built`

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `scan-samples-built`

</details>

### <a name="val-precision"></a>`precision`

```sml
val precision : Int.int option
```

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

<details><summary>Tests (5)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `no-least-number`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `two-complement` &middot; `maxInt-plus-one-negated` &middot; `toString` &middot; `NONE`

</details>

### <a name="val-maxint"></a>`maxInt`

```sml
val maxInt : int option
```

<details><summary>Tests (7)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `no-greatest-number`

For `Int8`, in [tests/basis/intn\_int8.sml](../../../../tests/basis/intn_int8.sml): `constant`

For `Int16`, in [tests/basis/intn\_int16.sml](../../../../tests/basis/intn_int16.sml): `constant`

For `Int32`, in [tests/basis/intn\_int32.sml](../../../../tests/basis/intn_int32.sml): `constant`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `two-complement` &middot; `toString` &middot; `NONE`

</details>

### <a name="val-op-plus"></a>`+`

```sml
val + : int * int -> int
```

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

<details><summary>Tests (20)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `10^30-minus-one` &middot; `one-minus-10^30` &middot; `as-Int*` &middot; `inverse-of-plus*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-Overflow` (raises Overflow)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Overflow-maxInt-minus-minus-one` &middot; `Overflow-minInt-minus-one` &middot; `Overflow-zero-minus-minInt` &middot; `Overflow-maxInt-minus-minInt` &middot; `Overflow-minInt-minus-maxInt` &middot; `minus-one-minus-minInt` &middot; `zero-minus-maxInt` &middot; `minInt-minus-minInt` &middot; `maxInt-minus-maxInt` &middot; `zero-minus-2^200` &middot; `2^201-minus-2^200` &middot; `model*` &middot; `plus-negation*`

</details>

### <a name="val-op-star"></a>`*`

```sml
val * : int * int -> int
```

<details><summary>Tests (40)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `2^64-squared` &middot; `2^50-squared` &middot; `factorial-20` &middot; `factorial-25` &middot; `factorial-30` &middot; `negative-factorial` &middot; `10^15+1-times-10^15-1` &middot; `as-Int*` &middot; `difference-of-squares*` &middot; `distributive*` &middot; `commutative*` &middot; `associative*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-Overflow` (raises Overflow)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Overflow-maxInt-times-two` &middot; `Overflow-minInt-times-minus-one` &middot; `Overflow-minus-one-times-minInt` &middot; `Overflow-minInt-times-two` &middot; `Overflow-half-range-times-two` &middot; `Overflow-minInt-squared` &middot; `Overflow-maxInt-squared` &middot; `Overflow-maxInt-times-minInt` &middot; `Overflow-square-of-power` &middot; `square-of-power` &middot; `minInt-times-one` &middot; `one-times-minInt` &middot; `maxInt-times-minus-one` &middot; `half-range-times-minus-two` &middot; `minInt-times-zero` &middot; `zero-times-minInt` &middot; `zero-times-maxInt` &middot; `2^200-squared` &middot; `2^200-times-minus-two` &middot; `2^200-times-zero` &middot; `zero-times-2^200` &middot; `zero-times-~2^200` &middot; `model*` &middot; `by-two*` &middot; `by-minus-one*`

</details>

### <a name="val-div"></a>`div`

```sml
val div : int * int -> int
```

<details><summary>Tests (32)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `factorial-30-by-factorial-25` &middot; `2^64-by-10^9` &middot; `~2^64-by-10^9` &middot; `2^64-by-~10^9` &middot; `as-Int*` &middot; `of-product*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-floor` &middot; `toplevel-Div` (raises Div) &middot; `toplevel-Overflow` (raises Overflow)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Div` &middot; `Div-negative` &middot; `Div-zero-by-zero` &middot; `Overflow-minInt-by-minus-one` &middot; `Div-minInt` &middot; `minInt-by-one` &middot; `minInt-by-two` &middot; `maxInt-by-minus-one` &middot; `maxInt-by-two` &middot; `next-to-minInt-by-minus-one` &middot; `minInt-by-maxInt` &middot; `maxInt-by-minInt` &middot; `minInt-by-minInt` &middot; `one-by-minInt` &middot; `minus-one-by-minInt` &middot; `2^400-by-2^200` &middot; `2^200+1-by-~2^200` &middot; `Div-2^200` &middot; `law*` &middot; `versus-quot*` &middot; `by-one*`

</details>

### <a name="val-mod"></a>`mod`

```sml
val mod : int * int -> int
```

<details><summary>Tests (29)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `factorial-30-by-factorial-25` &middot; `2^64-by-10^9` &middot; `~2^64-by-10^9` &middot; `2^64-by-~10^9` &middot; `as-Int*` &middot; `of-product*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-sign-of-divisor` &middot; `toplevel-Div` (raises Div)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Div` &middot; `Div-negative` &middot; `Div-zero-by-zero` &middot; `minInt-by-minus-one` &middot; `Div-minInt` &middot; `minInt-by-two` &middot; `maxInt-by-minus-one` &middot; `maxInt-by-two` &middot; `minInt-by-maxInt` &middot; `maxInt-by-minInt` &middot; `minInt-by-minInt` &middot; `one-by-minInt` &middot; `minus-one-by-minInt` &middot; `2^400-by-2^200` &middot; `2^200+1-by-~2^200` &middot; `Div-2^200` &middot; `sign-of-divisor*` &middot; `magnitude*` &middot; `by-one*`

</details>

### <a name="val-quot"></a>`quot`

```sml
val quot : int * int -> int
```

<details><summary>Tests (22)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `~2^64-by-10^9` &middot; `2^64-by-~10^9` &middot; `as-Int*` &middot; `of-product*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Div` &middot; `Div-negative` &middot; `Div-zero-by-zero` &middot; `Overflow-minInt-by-minus-one` &middot; `Div-minInt` &middot; `minInt-by-two` &middot; `maxInt-by-minus-one` &middot; `next-to-minInt-by-minus-one` &middot; `minInt-by-maxInt` &middot; `maxInt-by-minInt` &middot; `minInt-by-minInt` &middot; `one-by-minInt` &middot; `2^200+1-by-~2^200` &middot; `~2^400-by-2^200` &middot; `Div-2^200` &middot; `law*` &middot; `by-one*`

</details>

### <a name="val-rem"></a>`rem`

```sml
val rem : int * int -> int
```

<details><summary>Tests (20)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `~2^64-by-10^9` &middot; `2^64-by-~10^9` &middot; `as-Int*` &middot; `of-product*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `Div` &middot; `Div-negative` &middot; `Div-zero-by-zero` &middot; `minInt-by-minus-one` &middot; `Div-minInt` &middot; `minInt-by-two` &middot; `minInt-by-maxInt` &middot; `maxInt-by-minInt` &middot; `minInt-by-minInt` &middot; `one-by-minInt` &middot; `2^200+1-by-~2^200` &middot; `Div-2^200` &middot; `sign-of-dividend*` &middot; `magnitude*` &middot; `by-one*`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : int * int -> order
```

<details><summary>Tests (15)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*` &middot; `successor*` &middot; `difference*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `minInt-minInt` &middot; `maxInt-maxInt` &middot; `minInt-zero` &middot; `2^200-and-successor` &middot; `2^200-and-~2^200` &middot; `2^200-equal` &middot; `~2^200-and-~2^201` &middot; `model*` &middot; `reflexive*`

</details>

### <a name="val-op-lt"></a>`<`

```sml
val < : int * int -> bool
```

<details><summary>Tests (8)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `minInt-minInt` &middot; `2^200-2^201` &middot; `model*`

</details>

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : int * int -> bool
```

<details><summary>Tests (8)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `minInt-minInt` &middot; `2^200-2^200` &middot; `model*`

</details>

### <a name="val-op-gt"></a>`>`

```sml
val > : int * int -> bool
```

<details><summary>Tests (8)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `maxInt-maxInt` &middot; `2^200-2^201` &middot; `model*`

</details>

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : int * int -> bool
```

<details><summary>Tests (8)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `maxInt-maxInt` &middot; `~2^200-~2^201` &middot; `model*`

</details>

### <a name="val-op-tilde"></a>`~`

```sml
val ~ : int -> int
```

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

<details><summary>Tests (13)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

For `Int`, in [tests/basis/int.sml](../../../../tests/basis/int.sml): `toplevel*` &middot; `toplevel-Overflow` (raises Overflow)

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `positive` &middot; `negative` &middot; `zero` &middot; `Overflow-minInt` &middot; `next-to-minInt` &middot; `maxInt` &middot; `~2^200` &middot; `2^200` &middot; `model*` &middot; `law*`

</details>

### <a name="val-min"></a>`min`

```sml
val min : int * int -> int
```

<details><summary>Tests (6)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `2^200-~2^201` &middot; `model*`

</details>

### <a name="val-max"></a>`max`

```sml
val max : int * int -> int
```

<details><summary>Tests (6)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `maxInt-minInt` &middot; `2^200-~2^201` &middot; `model*`

</details>

### <a name="val-sign"></a>`sign`

```sml
val sign : int -> Int.int
```

<details><summary>Tests (12)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `positive` &middot; `negative` &middot; `zero` &middot; `one` &middot; `minus-one` &middot; `minInt` &middot; `maxInt` &middot; `zero-times-2^200` &middot; `2^200` &middot; `~2^200` &middot; `model*`

</details>

### <a name="val-samesign"></a>`sameSign`

```sml
val sameSign : int * int -> bool
```

<details><summary>Tests (10)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt-maxInt` &middot; `minInt-minus-one` &middot; `maxInt-one` &middot; `minInt-zero` &middot; `zero-maxInt` &middot; `2^200-one` &middot; `2^200-~2^200` &middot; `model*`

</details>

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : StringCvt.radix -> int -> string
```

<details><summary>Tests (2)</summary>

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `model*`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : int -> string
```

<details><summary>Tests (12)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `10^30` &middot; `~10^30` &middot; `as-Int*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt` &middot; `maxInt` &middot; `next-to-minInt` &middot; `2^200` &middot; `~2^200` &middot; `2^200-1` &middot; `model*`

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `fmt-DEC-*`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (int, 'a) StringCvt.reader
```

<details><summary>Tests (12)</summary>

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `HEX-0xg-is-zero` &middot; `HEX-0x-123-is-zero` &middot; `string-position` &middot; `string-position-second` &middot; `HEX-minInt-with-prefix` &middot; `HEX-maxInt-lower-case` &middot; `HEX-Overflow-with-prefix` &middot; `HEX-2^300-1-lower-case-with-prefix` &middot; `model*` &middot; `model-lower-case-rest*` &middot; `fmt-round-trip*`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> int option
```

<details><summary>Tests (27)</summary>

For `IntInf`, in [tests/basis/intinf.sml](../../../../tests/basis/intinf.sml): `2^64` &middot; `factorial-30` &middot; `~2^128` &middot; `as-Int*` &middot; `toString*`

In [tests/basis/fn/integer\_fn.sml](../../../../tests/basis/fn/integer_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `*` &middot; `minInt` &middot; `minInt-with-minus` &middot; `maxInt` &middot; `maxInt-with-plus` &middot; `maxInt-then-letters` &middot; `maxInt-with-leading-zeros` &middot; `minInt-with-leading-zeros` &middot; `Overflow-maxInt-plus-one` &middot; `Overflow-minInt-minus-one` &middot; `Overflow-maxInt-times-ten` &middot; `Overflow-minInt-times-ten` &middot; `Overflow-after-whitespace` &middot; `Overflow-many-digits` &middot; `2^200` &middot; `~2^200` &middot; `-2^200` &middot; `2^200-then-letters` &middot; `model*` &middot; `other-sign*` &middot; `round-trip*`

In [tests/basis/fn/integer\_scan\_fn.sml](../../../../tests/basis/fn/integer_scan_fn.sml), applied to `IntInf`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`: `scanString-*`

</details>

---

<sub>Generated by runedoc from lib/basis/int\_sig.sml; do not edit.</sub>
