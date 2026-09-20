# signature MATH

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **MATH**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 4 |
| Documentation | 18 of 18 entries documented |
| Tests | 256 checks of 17 entries |
| Source | [lib/basis/sig\_math.sml](../../../../lib/basis/sig_math.sml) |

## Synopsis

```sml
signature MATH
structure LargeReal.Math : MATH
structure Math : MATH where type real = Real.real
structure Real.Math : MATH
structure Real64.Math : MATH
```

| Implementation |  | Source |
| --- | --- | --- |
| `LargeReal.Math` |  | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| `Math` |  | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| `Real.Math` |  | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| `Real64.Math` |  | [lib/basis/real.sml](../../../../lib/basis/real.sml) |

The elementary functions of a real type: roots, the trigonometric and
hyperbolic functions, exponentials and logarithms.

A structure of this signature belongs to a [`REAL`](../sig/REAL.md) structure and computes
with its type, so [`Math`](MATH.md) is [`Real.Math`](../sig/REAL.md#str-math). Angles are in radians. None of
these functions raises: where the mathematical function has no value the
answer is a NaN, and where it grows without bound it is an infinity, as
IEEE 754 prescribes.

The results are not exact. The specification asks only that they be
"accurate", and a program that compares them should allow for the rounding
of the last digits; [`Real.==`](../sig/REAL.md#val-op-eq-eq) on two results of different routes is
usually wrong.

## Interface

<pre>
signature MATH =
sig
  type <a href="#type-real">real</a>

  val <a href="#val-pi">pi</a> : real

  val <a href="#val-e">e</a> : real

  val <a href="#val-sqrt">sqrt</a> : real -&gt; real

  val <a href="#val-sin">sin</a> : real -&gt; real

  val <a href="#val-cos">cos</a> : real -&gt; real

  val <a href="#val-tan">tan</a> : real -&gt; real

  val <a href="#val-asin">asin</a> : real -&gt; real

  val <a href="#val-acos">acos</a> : real -&gt; real

  val <a href="#val-atan">atan</a> : real -&gt; real

  val <a href="#val-atan2">atan2</a> : real * real -&gt; real

  val <a href="#val-exp">exp</a> : real -&gt; real

  val <a href="#val-pow">pow</a> : real * real -&gt; real

  val <a href="#val-ln">ln</a> : real -&gt; real

  val <a href="#val-log10">log10</a> : real -&gt; real

  val <a href="#val-sinh">sinh</a> : real -&gt; real

  val <a href="#val-cosh">cosh</a> : real -&gt; real

  val <a href="#val-tanh">tanh</a> : real -&gt; real
end
</pre>

### <a name="type-real"></a>`real`

```sml
type real
```

The type of the reals these functions compute with: [`Real.real`](../sig/REAL.md#type-real) for [`Real.Math`](../sig/REAL.md#str-math).

### <a name="val-pi"></a>`pi`

```sml
val pi : real
```

The ratio of a circle's circumference to its diameter, as near as the type can say.

> **Implementation** `Math.pi/nearest-double`. The [`real`](#type-real) nearest to pi,
> which differs from it by about 1.2E\~16.

<details><summary>Tests (4)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `value` &middot; `nearest-double` &middot; `digits` &middot; `same-as-Real.Math`

</details>

### <a name="val-e"></a>`e`

```sml
val e : real
```

The base of the natural logarithm, as near as the type can say.

<details><summary>Tests (3)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `value` &middot; `nearest-double` &middot; `digits`

</details>

### <a name="val-sqrt"></a>`sqrt`

```sml
val sqrt : real -> real
```

`sqrt x` is the square root of `x`.

It is a NaN for a negative `x`, and `~0.0` for `~0.0`.

> **Implementation** `Math.sqrt/four`. IEEE 754 requires the square root to
> be correctly rounded, so an exact square gives its root exactly:
> `sqrt 4.0` is `2.0`, not something near it.

<details><summary>Tests (15)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `four` &middot; `quarter` &middot; `one` &middot; `two` &middot; `large` &middot; `zero` &middot; `negzero` &middot; `negative` &middot; `small-negative` &middot; `negInf` &middot; `posInf` &middot; `nan` &middot; `law-exact-squares` &middot; `law-squares-back` &middot; `same-as-Real.Math`

</details>

### <a name="val-sin"></a>`sin`

```sml
val sin : real -> real
```

`sin x` is the sine of `x` radians.

It is a NaN for an infinite `x`.

<details><summary>Tests (12)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-six` &middot; `pi-over-two` &middot; `pi` &middot; `negative` &middot; `three-half-pi` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-pythagoras` &middot; `law-odd`

</details>

### <a name="val-cos"></a>`cos`

```sml
val cos : real -> real
```

`cos x` is the cosine of `x` radians.

It is a NaN for an infinite `x`.

<details><summary>Tests (11)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-three` &middot; `pi-over-two` &middot; `pi` &middot; `negative` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-even` &middot; `law-bounded`

</details>

### <a name="val-tan"></a>`tan`

```sml
val tan : real -> real
```

`tan x` is the tangent of `x` radians.

It is a NaN for an infinite `x`.

> **Reading** `Math.tan/near-singularity`. The specification says that [`tan`](#val-tan)
> has "infinities at various finite values"; no [`real`](#type-real) is an odd multiple
> of pi/2, so the function is finite everywhere, and what is asked of it
> is only that its magnitude near the singularity be large.

<details><summary>Tests (10)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-four` &middot; `negative` &middot; `pi` &middot; `near-singularity` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-is-sin-over-cos`

</details>

### <a name="val-asin"></a>`asin`

```sml
val asin : real -> real
```

`asin x` is the arc sine of `x`, in radians, between `~pi/2` and `pi/2`.

It is a NaN for an `x` outside `[~1, 1]`.

<details><summary>Tests (12)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `half` &middot; `one` &middot; `minus-one` &middot; `negative` &middot; `above-one` &middot; `just-above-one` &middot; `below-minus-one` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-range-and-inverse`

</details>

### <a name="val-acos"></a>`acos`

```sml
val acos : real -> real
```

`acos x` is the arc cosine of `x`, in radians, between 0 and [`pi`](#val-pi).

It is a NaN for an `x` outside `[~1, 1]`.

<details><summary>Tests (13)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `half` &middot; `zero` &middot; `negative` &middot; `minus-one` &middot; `above-one` &middot; `just-above-one` &middot; `below-minus-one` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-range-and-inverse` &middot; `law-complements-asin`

</details>

### <a name="val-atan"></a>`atan`

```sml
val atan : real -> real
```

`atan x` is the arc tangent of `x`, in radians, between `~pi/2` and `pi/2`.

At an infinity it is `~pi/2` or `pi/2`.

<details><summary>Tests (9)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `minus-one` &middot; `sqrt-three` &middot; `huge` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-range-and-inverse`

</details>

### <a name="val-atan2"></a>`atan2`

```sml
val atan2 : real * real -> real
```

`atan2 (y, x)` is the angle in radians from the positive x axis to the point `(x, y)`, between `~pi` and [`pi`](#val-pi).

Unlike `atan (y / x)` it knows which quadrant the point is in, because
it has the signs of both coordinates; the sign of a zero counts, so that
the answer is continuous as the point crosses an axis.

**Law** `atan2 (y, x) = atan (y / x)` for `x > 0`

<details><summary>Tests (34)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `first-quadrant` &middot; `second-quadrant` &middot; `third-quadrant` &middot; `fourth-quadrant` &middot; `ratio` &middot; `zero-y-positive-x` &middot; `negzero-y-positive-x` &middot; `zero-y-zero-x` &middot; `negzero-y-zero-x` &middot; `zero-y-negative-x` &middot; `negzero-y-negative-x` &middot; `zero-y-negzero-x` &middot; `negzero-y-negzero-x` &middot; `positive-y-zero-x` &middot; `positive-y-negzero-x` &middot; `negative-y-zero-x` &middot; `negative-y-negzero-x` &middot; `positive-y-posInf-x` &middot; `negative-y-posInf-x` &middot; `positive-y-negInf-x` &middot; `negative-y-negInf-x` &middot; `posInf-y-finite-x` &middot; `posInf-y-negative-x` &middot; `posInf-y-zero-x` &middot; `negInf-y-finite-x` &middot; `negInf-y-negative-x` &middot; `posInf-y-posInf-x` &middot; `negInf-y-posInf-x` &middot; `posInf-y-negInf-x` &middot; `negInf-y-negInf-x` &middot; `nan-y` &middot; `nan-x` &middot; `nan-both` &middot; `law-quadrant`

</details>

### <a name="val-exp"></a>`exp`

```sml
val exp : real -> real
```

`exp x` is [`e`](#val-e) to the power `x`.

It is 0 at negative infinity and an infinity at positive infinity, and
it overflows to an infinity for a large enough finite `x`.

<details><summary>Tests (12)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `two` &middot; `minus-one` &middot; `large` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `underflow` &middot; `law-sum-is-product` &middot; `law-positive-and-inverse-of-ln`

</details>

### <a name="val-pow"></a>`pow`

```sml
val pow : real * real -> real
```

`pow (x, y)` is `x` to the power `y`.

The special cases follow the table of the specification: it is 1 when
`y` is zero, whatever `x` is, and a NaN where the value would not be
determined.

> **Reading** `Math.pow/one-base-posInf`. `pow (1.0, y)` is a NaN for an
> infinite or NaN `y`, as the specification's table says; C99 and IEEE
> 754-2008 make it 1 instead, and Poly/ML follows them.

<details><summary>Tests (66)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `integer-power` &middot; `square-root` &middot; `negative-exponent` &middot; `fractional` &middot; `negative-base-odd` &middot; `negative-base-even` &middot; `negative-base-negative-odd` &middot; `one-base` &middot; `zero-exponent` &middot; `zero-exponent-negative-base` &middot; `zero-exponent-zero-base` &middot; `zero-exponent-posInf-base` &middot; `zero-exponent-negInf-base` &middot; `zero-exponent-nan-base` &middot; `negzero-exponent` &middot; `negzero-exponent-nan-base` &middot; `large-base-posInf` &middot; `large-negative-base-posInf` &middot; `posInf-base-posInf` &middot; `negInf-base-posInf` &middot; `small-base-posInf` &middot; `small-negative-base-posInf` &middot; `zero-base-posInf` &middot; `negzero-base-posInf` &middot; `large-base-negInf` &middot; `large-negative-base-negInf` &middot; `negInf-base-negInf` &middot; `small-base-negInf` &middot; `small-negative-base-negInf` &middot; `zero-base-negInf` &middot; `negzero-base-negInf` &middot; `posInf-base-positive` &middot; `posInf-base-small-positive` &middot; `posInf-base-negative` &middot; `posInf-base-small-negative` &middot; `negInf-base-positive-odd` &middot; `negInf-base-positive-even` &middot; `negInf-base-positive-fraction` &middot; `negInf-base-negative-odd` &middot; `negInf-base-negative-even` &middot; `negInf-base-negative-fraction` &middot; `nan-exponent` &middot; `nan-exponent-zero-base` &middot; `nan-exponent-posInf-base` &middot; `nan-both` &middot; `nan-base` &middot; `nan-base-posInf` &middot; `one-base-nan-exponent` &middot; `one-base-posInf` &middot; `one-base-negInf` &middot; `minus-one-base-posInf` &middot; `minus-one-base-negInf` &middot; `negative-base-fraction` &middot; `negative-base-negative-fraction` &middot; `zero-base-negative-odd` &middot; `negzero-base-negative-odd` &middot; `zero-base-negative-even` &middot; `negzero-base-negative-even` &middot; `negzero-base-negative-fraction` &middot; `zero-base-positive-odd` &middot; `negzero-base-positive-odd` &middot; `zero-base-positive-even` &middot; `negzero-base-positive-even` &middot; `negzero-base-positive-fraction` &middot; `law-exponent-one-and-two` &middot; `law-is-exp-of-ln`

</details>

### <a name="val-ln"></a>`ln`

```sml
val ln : real -> real
```

`ln x` is the natural logarithm of `x`.

It is negative infinity at zero and a NaN for a negative `x`.

<details><summary>Tests (13)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `e` &middot; `two` &middot; `ten` &middot; `half` &middot; `minPos` &middot; `negative` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `nan` &middot; `law-product-is-sum`

</details>

### <a name="val-log10"></a>`log10`

```sml
val log10 : real -> real
```

`log10 x` is the logarithm of `x` to base 10.

It is negative infinity at zero and a NaN for a negative `x`.

<details><summary>Tests (13)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `ten` &middot; `thousand` &middot; `hundredth` &middot; `two` &middot; `large` &middot; `negative` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `nan` &middot; `law-is-ln-over-ln-ten`

</details>

### <a name="val-sinh"></a>`sinh`

```sml
val sinh : real -> real
```

`sinh x` is the hyperbolic sine of `x`, `(e^x - e^~x) / 2`.

It overflows to an infinity of the sign of `x` for a large enough `x`.

<details><summary>Tests (10)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `negative-overflow` &middot; `law-definition`

</details>

### <a name="val-cosh"></a>`cosh`

```sml
val cosh : real -> real
```

`cosh x` is the hyperbolic cosine of `x`, `(e^x + e^~x) / 2`.

> **Reading** `Math.cosh/negInf`. It is positive infinity at either infinity,
> which is what the definition gives; the specification's table writes
> "cosh +-infinity = +-infinity", which cannot be meant, and MLton follows
> it to the letter.

<details><summary>Tests (9)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `law-definition`

</details>

### <a name="val-tanh"></a>`tanh`

```sml
val tanh : real -> real
```

`tanh x` is the hyperbolic tangent of `x`, `sinh x / cosh x`, between `~1` and 1.

It is `~1.0` and `1.0` at the infinities, and for a large enough finite
`x` it is those values too, although [`sinh`](#val-sinh) and [`cosh`](#val-cosh) both overflow
there.

<details><summary>Tests (10)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `large` &middot; `large-negative` &middot; `law-definition`

</details>

## See also

[`REAL`](../sig/REAL.md), [`IEEE_REAL`](../sig/IEEE_REAL.md)

---

<sub>Generated by runedoc from lib/basis/sig\_math.sml; do not edit.</sub>
