# signature INT_INF

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **INT_INF**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
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
and [`maxInt`](../sig/INTEGER.md#val-maxint) are `NONE`, and no operation raises `Overflow` except the
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
| [`int`](../sig/INTEGER.md#type-int) | eqtype |  |
| [`toLarge`](../sig/INTEGER.md#val-tolarge) | val |  |
| [`fromLarge`](../sig/INTEGER.md#val-fromlarge) | val |  |
| [`toInt`](../sig/INTEGER.md#val-toint) | val |  |
| [`fromInt`](../sig/INTEGER.md#val-fromint) | val |  |
| [`precision`](../sig/INTEGER.md#val-precision) | val |  |
| [`minInt`](../sig/INTEGER.md#val-minint) | val |  |
| [`maxInt`](../sig/INTEGER.md#val-maxint) | val |  |
| [`+`](../sig/INTEGER.md#val-op-plus) | val |  |
| [`-`](../sig/INTEGER.md#val-op-minus) | val |  |
| [`*`](../sig/INTEGER.md#val-op-star) | val |  |
| [`div`](../sig/INTEGER.md#val-div) | val |  |
| [`mod`](../sig/INTEGER.md#val-mod) | val |  |
| [`quot`](../sig/INTEGER.md#val-quot) | val |  |
| [`rem`](../sig/INTEGER.md#val-rem) | val |  |
| [`compare`](../sig/INTEGER.md#val-compare) | val |  |
| [`<`](../sig/INTEGER.md#val-op-lt) | val |  |
| [`<=`](../sig/INTEGER.md#val-op-lt-eq) | val |  |
| [`>`](../sig/INTEGER.md#val-op-gt) | val |  |
| [`>=`](../sig/INTEGER.md#val-op-gt-eq) | val |  |
| [`~`](../sig/INTEGER.md#val-op-tilde) | val |  |
| [`abs`](../sig/INTEGER.md#val-abs) | val |  |
| [`min`](../sig/INTEGER.md#val-min) | val |  |
| [`max`](../sig/INTEGER.md#val-max) | val |  |
| [`sign`](../sig/INTEGER.md#val-sign) | val |  |
| [`sameSign`](../sig/INTEGER.md#val-samesign) | val |  |
| [`fmt`](../sig/INTEGER.md#val-fmt) | val |  |
| [`toString`](../sig/INTEGER.md#val-tostring) | val |  |
| [`scan`](../sig/INTEGER.md#val-scan) | val |  |
| [`fromString`](../sig/INTEGER.md#val-fromstring) | val |  |

## Division

### <a name="val-divmod"></a>`divMod`

```sml
val divMod : int * int -> int * int
```

`divMod (i, j)` is the pair `(i div j, i mod j)`, computed in one
division.

The quotient is rounded towards negative infinity and the remainder has
the sign of `j`.

**Raises** `Div` if `j` is zero.

### <a name="val-quotrem"></a>`quotRem`

```sml
val quotRem : int * int -> int * int
```

`quotRem (i, j)` is the pair `(quot (i, j), rem (i, j))`, computed in one
division.

The quotient is rounded towards zero and the remainder has the sign of
`i`.

**Raises** `Div` if `j` is zero.

## Powers and logarithms

### <a name="val-pow"></a>`pow`

```sml
val pow : int * Int.int -> int
```

`pow (i, j)` is `i` to the power `j`.

For a negative `j` the result is what is left of `1 / i^~j` as an integer:
1 or \~1 when `i` is 1 or \~1, and 0 for every other `i` but 0.

**Raises** `Div` if `i` is zero and `j` is negative.

**Example** `pow (2, 100) = 1267650600228229401496703205376`

### <a name="val-log2"></a>`log2`

```sml
val log2 : int -> Int.int
```

`log2 i` is the largest `k` for which `2^k <= i`: the position of the
highest bit of `i`.

**Raises** `Domain` if `i <= 0`.

## Bits

### <a name="val-orb"></a>`orb`

```sml
val orb : int * int -> int
```

`orb (i, j)` is the bitwise "or" of `i` and `j`.

### <a name="val-xorb"></a>`xorb`

```sml
val xorb : int * int -> int
```

`xorb (i, j)` is the bitwise exclusive "or" of `i` and `j`.

### <a name="val-andb"></a>`andb`

```sml
val andb : int * int -> int
```

`andb (i, j)` is the bitwise "and" of `i` and `j`.

### <a name="val-notb"></a>`notb`

```sml
val notb : int -> int
```

`notb i` is `i` with every bit inverted.

**Law** `notb i = ~(i + 1)`

### <a name="val-op-lt-lt"></a>`<<`

```sml
val << : int * Word.word -> int
```

`<< (i, n)` is `i` shifted left by `n` bits: `i * 2^n`.

### <a name="val-op-tilde-gt-gt"></a>`~>>`

```sml
val ~>> : int * Word.word -> int
```

`~>> (i, n)` is `i` shifted right by `n` bits with its sign kept: `i div 2^n`, rounded towards negative infinity.

## See also

[`INTEGER`](../sig/INTEGER.md), [`WORD`](../sig/WORD.md)

---

<sub>Generated by runedoc from lib/basis/sig\_int\_inf.sml; do not edit.</sub>
