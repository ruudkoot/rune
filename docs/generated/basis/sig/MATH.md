# signature MATH

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **MATH**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 5 |
| Documentation | 18 of 18 entries documented |
| Tests | 562 checks of 17 entries |
| Source | [lib/basis/sig\_math.sml](../../../../lib/basis/sig_math.sml) |

## Synopsis

```sml
signature MATH
structure LargeReal.Math : MATH
structure Math : MATH where type real = Real.real
structure Real.Math : MATH
structure Real32.Math : MATH
structure Real64.Math : MATH
```

| Implementation |  | Source |
| --- | --- | --- |
| [`LargeReal.Math`](../str/Real.Math.md) | Real.Math: the elementary functions at [`real`](#type-real), from the C library, with [`asin`](#val-asin), [`acos`](#val-acos) and [`log10`](#val-log10) made from its [`atan2`](#val-atan2) and [`ln`](#val-ln). | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| [`Math`](../str/Real.Math.md) | Math: the elementary functions of the top-level [`real`](#type-real), which are [`Real.Math`](../str/Real.Math.md). | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| [`Real.Math`](../str/Real.Math.md) | Real.Math: the elementary functions at [`real`](#type-real), from the C library, with [`asin`](#val-asin), [`acos`](#val-acos) and [`log10`](#val-log10) made from its [`atan2`](#val-atan2) and [`ln`](#val-ln). | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| [`Real32.Math`](../str/Real32.Math.md) | Real32.Math: the elementary functions at binary32, computed in binary64 and rounded to binary32. | [lib/basis/real32.sml](../../../../lib/basis/real32.sml) |
| [`Real64.Math`](../str/Real.Math.md) | Real.Math: the elementary functions at [`real`](#type-real), from the C library, with [`asin`](#val-asin), [`acos`](#val-acos) and [`log10`](#val-log10) made from its [`atan2`](#val-atan2) and [`ln`](#val-ln). | [lib/basis/real.sml](../../../../lib/basis/real.sml) |

The elementary functions of a real type: roots, the trigonometric and
hyperbolic functions, exponentials and logarithms.

A structure of this signature belongs to a [`REAL`](../sig/REAL.md) structure and computes
with its type, so [`Math`](../str/Real.Math.md) is [`Real.Math`](../str/Real.Math.md). Angles are in radians. None of
these functions raises: where the mathematical function has no value the
answer is a NaN, and where it grows without bound it is an infinity, as
IEEE 754 prescribes. A NaN as an argument gives a NaN, except where a
function says otherwise (`pow (x, 0.0)` is 1 for every `x`).

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

The type of the reals these functions compute with: [`Real.real`](../sig/REAL.md#type-real) for [`Real.Math`](../str/Real.Math.md).

### <a name="val-pi"></a>`pi`

```sml
val pi : real
```

The ratio of a circle's circumference to its diameter, as near as the type can say.

> **Implementation** `Math.pi/nearest-double`. The [`real`](#type-real) nearest to pi,
> which differs from it by about 1.2E\~16.

**Example** `Real.fmt (StringCvt.FIX (SOME 4)) pi = "3.1416"`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (9)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `value` &middot; `nearest-double` &middot; `digits` &middot; `same-as-Real.Math`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `value` &middot; `nearest-double` &middot; `digits` &middot; `same-as-Real.Math`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `binary32`

</details>

### <a name="val-e"></a>`e`

```sml
val e : real
```

The base of the natural logarithm, as near as the type can say.

**Example** `Real.fmt (StringCvt.FIX (SOME 4)) e = "2.7183"`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (7)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `value` &middot; `nearest-double` &middot; `digits`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `value` &middot; `nearest-double` &middot; `digits`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `binary32`

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

**Example** `Real.isNan (sqrt ~1.0) = true`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (34)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `four` &middot; `quarter` &middot; `one` &middot; `two` &middot; `large` &middot; `zero` &middot; `negzero` &middot; `negative` &middot; `small-negative` &middot; `negInf` &middot; `posInf` &middot; `nan` &middot; `law-exact-squares` &middot; `law-squares-back` &middot; `same-as-Real.Math`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `four` &middot; `quarter` &middot; `one` &middot; `two` &middot; `large` &middot; `zero` &middot; `negzero` &middot; `negative` &middot; `small-negative` &middot; `negInf` &middot; `posInf` &middot; `nan` &middot; `law-exact-squares` &middot; `law-squares-back` &middot; `same-as-Real.Math`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `two` &middot; `negzero` &middot; `negative` &middot; `exact`

</details>

### <a name="val-sin"></a>`sin`

```sml
val sin : real -> real
```

`sin x` is the sine of `x` radians.

It is a NaN for an infinite `x`.

**Example** `Real.signBit (sin ~0.0) = true`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (26)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-six` &middot; `pi-over-two` &middot; `pi` &middot; `negative` &middot; `three-half-pi` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-pythagoras` &middot; `law-odd`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-six` &middot; `pi-over-two` &middot; `pi` &middot; `negative` &middot; `three-half-pi` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-pythagoras` &middot; `law-odd`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `zero` &middot; `posInf`

</details>

### <a name="val-cos"></a>`cos`

```sml
val cos : real -> real
```

`cos x` is the cosine of `x` radians.

It is a NaN for an infinite `x`.

**Example** `Real.== (cos 0.0, 1.0) = true`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (24)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-three` &middot; `pi-over-two` &middot; `pi` &middot; `negative` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-even` &middot; `law-bounded`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-three` &middot; `pi-over-two` &middot; `pi` &middot; `negative` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-even` &middot; `law-bounded`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `zero` &middot; `negInf`

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

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (22)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-four` &middot; `negative` &middot; `pi` &middot; `near-singularity` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-is-sin-over-cos`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-four` &middot; `negative` &middot; `pi` &middot; `near-singularity` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-is-sin-over-cos`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negzero` &middot; `nan`

</details>

### <a name="val-asin"></a>`asin`

```sml
val asin : real -> real
```

`asin x` is the arc sine of `x`, in radians, between `~pi/2` and `pi/2`.

It is a NaN for an `x` outside `[~1, 1]`.

> **Reading** `Math.asin/accurate-near-one`. The specification asks for no
> particular accuracy, only "roughly the same semantics" as C. Rune's
> [`asin`](#val-asin) and [`acos`](#val-acos) are within an ulp or two of the true value everywhere,
> near 1 and \~1 too, where a computation through `1 - x * x` loses most of
> the digits; SML/NJ's [`asin`](#val-asin) is off by more there.

**Example** `Real.isNan (asin 2.0) = true`

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; another reading of the specification: asin near 1 and \~1 is off by more than two ulps; the test takes the reading of Rune, a result within two ulps everywhere
- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (30)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `half` &middot; `one` &middot; `minus-one` &middot; `negative` &middot; `above-one` &middot; `just-above-one` &middot; `below-minus-one` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `near-one-accurate` &middot; `near-minus-one-accurate` &middot; `law-range-and-inverse`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `half` &middot; `one` &middot; `minus-one` &middot; `negative` &middot; `above-one` &middot; `just-above-one` &middot; `below-minus-one` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `near-one-accurate` &middot; `near-minus-one-accurate` &middot; `law-range-and-inverse`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `one` &middot; `above-one`

</details>

### <a name="val-acos"></a>`acos`

```sml
val acos : real -> real
```

`acos x` is the arc cosine of `x`, in radians, between 0 and [`pi`](#val-pi).

It is a NaN for an `x` outside `[~1, 1]`.

**Example** `Real.== (acos 1.0, 0.0) = true`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (32)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `half` &middot; `zero` &middot; `negative` &middot; `minus-one` &middot; `above-one` &middot; `just-above-one` &middot; `below-minus-one` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `near-one-accurate` &middot; `near-minus-one-accurate` &middot; `law-range-and-inverse` &middot; `law-complements-asin`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `half` &middot; `zero` &middot; `negative` &middot; `minus-one` &middot; `above-one` &middot; `just-above-one` &middot; `below-minus-one` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `near-one-accurate` &middot; `near-minus-one-accurate` &middot; `law-range-and-inverse` &middot; `law-complements-asin`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `one` &middot; `below-minus-one`

</details>

### <a name="val-atan"></a>`atan`

```sml
val atan : real -> real
```

`atan x` is the arc tangent of `x`, in radians, between `~pi/2` and `pi/2`.

At an infinity it is `~pi/2` or `pi/2`.

**Example** `Real.== (atan Real.negInf, ~ (pi / 2.0)) = true`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (20)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `minus-one` &middot; `sqrt-three` &middot; `huge` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-range-and-inverse`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `minus-one` &middot; `sqrt-three` &middot; `huge` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-range-and-inverse`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `posInf` &middot; `nan`

</details>

### <a name="val-atan2"></a>`atan2`

```sml
val atan2 : real * real -> real
```

`atan2 (y, x)` is the angle in radians from the positive x axis to the point `(x, y)`, between `~pi` and [`pi`](#val-pi).

Unlike `atan (y / x)` it knows which quadrant the point is in, because
it has the signs of both coordinates; the sign of a zero counts, so that
the answer is continuous as the point crosses an axis. The special cases
follow the table of the specification: on the y axis the angle is
`pi/2` or `~pi/2`, `atan2 (0.0, ~0.0)` is [`pi`](#val-pi), and two infinities give
an odd multiple of `pi/4`.

**Law** `atan2 (y, x) = atan (y / x)` for `x > 0.0` (for every `y : real`, `x : real`)

**Example** `Real.== (atan2 (0.0, ~1.0), pi) = true`

<details><summary>Other implementations (3)</summary>

- **SML/NJ** &mdash; Math.atan2 ignores the sign of a zero: atan2 (\~0.0, 1.0) = 0.0, atan2 (0.0, \~0.0) = 0.0
- **SML/NJ** &mdash; Math.atan2 of two infinities is NaN
- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (70)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `first-quadrant` &middot; `second-quadrant` &middot; `third-quadrant` &middot; `fourth-quadrant` &middot; `ratio` &middot; `zero-y-positive-x` &middot; `negzero-y-positive-x` &middot; `zero-y-zero-x` &middot; `negzero-y-zero-x` &middot; `zero-y-negative-x` &middot; `negzero-y-negative-x` &middot; `zero-y-negzero-x` &middot; `negzero-y-negzero-x` &middot; `positive-y-zero-x` &middot; `positive-y-negzero-x` &middot; `negative-y-zero-x` &middot; `negative-y-negzero-x` &middot; `positive-y-posInf-x` &middot; `negative-y-posInf-x` &middot; `positive-y-negInf-x` &middot; `negative-y-negInf-x` &middot; `posInf-y-finite-x` &middot; `posInf-y-negative-x` &middot; `posInf-y-zero-x` &middot; `negInf-y-finite-x` &middot; `negInf-y-negative-x` &middot; `posInf-y-posInf-x` &middot; `negInf-y-posInf-x` &middot; `posInf-y-negInf-x` &middot; `negInf-y-negInf-x` &middot; `nan-y` &middot; `nan-x` &middot; `nan-both` &middot; `law-quadrant`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `first-quadrant` &middot; `second-quadrant` &middot; `third-quadrant` &middot; `fourth-quadrant` &middot; `ratio` &middot; `zero-y-positive-x` &middot; `negzero-y-positive-x` &middot; `zero-y-zero-x` &middot; `negzero-y-zero-x` &middot; `zero-y-negative-x` &middot; `negzero-y-negative-x` &middot; `zero-y-negzero-x` &middot; `negzero-y-negzero-x` &middot; `positive-y-zero-x` &middot; `positive-y-negzero-x` &middot; `negative-y-zero-x` &middot; `negative-y-negzero-x` &middot; `positive-y-posInf-x` &middot; `negative-y-posInf-x` &middot; `positive-y-negInf-x` &middot; `negative-y-negInf-x` &middot; `posInf-y-finite-x` &middot; `posInf-y-negative-x` &middot; `posInf-y-zero-x` &middot; `negInf-y-finite-x` &middot; `negInf-y-negative-x` &middot; `posInf-y-posInf-x` &middot; `negInf-y-posInf-x` &middot; `posInf-y-negInf-x` &middot; `negInf-y-negInf-x` &middot; `nan-y` &middot; `nan-x` &middot; `nan-both` &middot; `law-quadrant`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative-x-axis` &middot; `nan`

</details>

### <a name="val-exp"></a>`exp`

```sml
val exp : real -> real
```

`exp x` is [`e`](#val-e) to the power `x`.

It is 0 at negative infinity and an infinity at positive infinity, and
it overflows to an infinity for a large enough finite `x`.

**Example** `Real.== (exp 0.0, 1.0) = true`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (28)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `two` &middot; `minus-one` &middot; `large` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `underflow` &middot; `law-sum-is-product` &middot; `law-positive-and-inverse-of-ln`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `two` &middot; `minus-one` &middot; `large` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `underflow` &middot; `law-sum-is-product` &middot; `law-positive-and-inverse-of-ln`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `zero` &middot; `negInf` &middot; `posInf` &middot; `overflow`

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

**Example** `Real.round (pow (2.0, 10.0)) = 1024`

**Example** `Real.toString (pow (0.0, 0.0)) = "1"`

<details><summary>Other implementations (3)</summary>

- **Poly/ML** &mdash; Math.pow (+-1.0, +-inf) is 1.0 (C pow), not NaN
- **SML/NJ** &mdash; Math.pow (\~0.0, \~3.0) is posInf, not negInf
- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (135)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `integer-power` &middot; `square-root` &middot; `negative-exponent` &middot; `fractional` &middot; `negative-base-odd` &middot; `negative-base-even` &middot; `negative-base-negative-odd` &middot; `one-base` &middot; `zero-exponent` &middot; `zero-exponent-negative-base` &middot; `zero-exponent-zero-base` &middot; `zero-exponent-posInf-base` &middot; `zero-exponent-negInf-base` &middot; `zero-exponent-nan-base` &middot; `negzero-exponent` &middot; `negzero-exponent-nan-base` &middot; `large-base-posInf` &middot; `large-negative-base-posInf` &middot; `posInf-base-posInf` &middot; `negInf-base-posInf` &middot; `small-base-posInf` &middot; `small-negative-base-posInf` &middot; `zero-base-posInf` &middot; `negzero-base-posInf` &middot; `large-base-negInf` &middot; `large-negative-base-negInf` &middot; `negInf-base-negInf` &middot; `small-base-negInf` &middot; `small-negative-base-negInf` &middot; `zero-base-negInf` &middot; `negzero-base-negInf` &middot; `posInf-base-positive` &middot; `posInf-base-small-positive` &middot; `posInf-base-negative` &middot; `posInf-base-small-negative` &middot; `negInf-base-positive-odd` &middot; `negInf-base-positive-even` &middot; `negInf-base-positive-fraction` &middot; `negInf-base-negative-odd` &middot; `negInf-base-negative-even` &middot; `negInf-base-negative-fraction` &middot; `nan-exponent` &middot; `nan-exponent-zero-base` &middot; `nan-exponent-posInf-base` &middot; `nan-both` &middot; `nan-base` &middot; `nan-base-posInf` &middot; `one-base-nan-exponent` &middot; `one-base-posInf` &middot; `one-base-negInf` &middot; `minus-one-base-posInf` &middot; `minus-one-base-negInf` &middot; `negative-base-fraction` &middot; `negative-base-negative-fraction` &middot; `zero-base-negative-odd` &middot; `negzero-base-negative-odd` &middot; `zero-base-negative-even` &middot; `negzero-base-negative-even` &middot; `negzero-base-negative-fraction` &middot; `zero-base-positive-odd` &middot; `negzero-base-positive-odd` &middot; `zero-base-positive-even` &middot; `negzero-base-positive-even` &middot; `negzero-base-positive-fraction` &middot; `law-exponent-one-and-two` &middot; `law-is-exp-of-ln`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `integer-power` &middot; `square-root` &middot; `negative-exponent` &middot; `fractional` &middot; `negative-base-odd` &middot; `negative-base-even` &middot; `negative-base-negative-odd` &middot; `one-base` &middot; `zero-exponent` &middot; `zero-exponent-negative-base` &middot; `zero-exponent-zero-base` &middot; `zero-exponent-posInf-base` &middot; `zero-exponent-negInf-base` &middot; `zero-exponent-nan-base` &middot; `negzero-exponent` &middot; `negzero-exponent-nan-base` &middot; `large-base-posInf` &middot; `large-negative-base-posInf` &middot; `posInf-base-posInf` &middot; `negInf-base-posInf` &middot; `small-base-posInf` &middot; `small-negative-base-posInf` &middot; `zero-base-posInf` &middot; `negzero-base-posInf` &middot; `large-base-negInf` &middot; `large-negative-base-negInf` &middot; `negInf-base-negInf` &middot; `small-base-negInf` &middot; `small-negative-base-negInf` &middot; `zero-base-negInf` &middot; `negzero-base-negInf` &middot; `posInf-base-positive` &middot; `posInf-base-small-positive` &middot; `posInf-base-negative` &middot; `posInf-base-small-negative` &middot; `negInf-base-positive-odd` &middot; `negInf-base-positive-even` &middot; `negInf-base-positive-fraction` &middot; `negInf-base-negative-odd` &middot; `negInf-base-negative-even` &middot; `negInf-base-negative-fraction` &middot; `nan-exponent` &middot; `nan-exponent-zero-base` &middot; `nan-exponent-posInf-base` &middot; `nan-both` &middot; `nan-base` &middot; `nan-base-posInf` &middot; `one-base-nan-exponent` &middot; `one-base-posInf` &middot; `one-base-negInf` &middot; `minus-one-base-posInf` &middot; `minus-one-base-negInf` &middot; `negative-base-fraction` &middot; `negative-base-negative-fraction` &middot; `zero-base-negative-odd` &middot; `negzero-base-negative-odd` &middot; `zero-base-negative-even` &middot; `negzero-base-negative-even` &middot; `negzero-base-negative-fraction` &middot; `zero-base-positive-odd` &middot; `negzero-base-positive-odd` &middot; `zero-base-positive-even` &middot; `negzero-base-positive-even` &middot; `negzero-base-positive-fraction` &middot; `law-exponent-one-and-two` &middot; `law-is-exp-of-ln`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `exact` &middot; `nan-to-zero` &middot; `nan`

</details>

### <a name="val-ln"></a>`ln`

```sml
val ln : real -> real
```

`ln x` is the natural logarithm of `x`.

It is negative infinity at zero, a NaN for a negative `x`, and positive
infinity at positive infinity.

**Example** `Real.toString (ln 0.0) = "~inf"`

<details><summary>Other implementations (2)</summary>

- **MLKit** &mdash; ln and log10 of a NaN are \~inf: ln tests r == 0.0 first, with an == that holds when neither \< nor \> does
- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (29)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `e` &middot; `two` &middot; `ten` &middot; `half` &middot; `minPos` &middot; `negative` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `nan` &middot; `law-product-is-sum`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `e` &middot; `two` &middot; `ten` &middot; `half` &middot; `minPos` &middot; `negative` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `nan` &middot; `law-product-is-sum`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `zero` &middot; `one` &middot; `negative`

</details>

### <a name="val-log10"></a>`log10`

```sml
val log10 : real -> real
```

`log10 x` is the logarithm of `x` to base 10.

It is negative infinity at zero, a NaN for a negative `x`, and positive
infinity at positive infinity.

> **Reading** `Math.log10/powers-of-ten-exact`. The specification asks for no
> particular accuracy, only "roughly the same semantics" as C's [`log10`](#val-log10).
> Rune gives the exact logarithm where a real holds it, at the powers of
> ten up to 10^22, as C does, so that `floor (log10 1000.0)` is 3. SML/NJ
> and MLKit compute `ln x / ln 10`, which misses some of them by an ulp.

**Example** `Real.== (log10 1000.0, 3.0) = true`

<details><summary>Other implementations (3)</summary>

- **SML/NJ, MLKit** &mdash; another reading of the specification: log10 is ln x / ln 10, which misses some powers of ten by an ulp (log10 1000.0 is 2.9999999999999996); the test takes the reading of Rune, the exact logarithm where a real holds it
- **MLKit** &mdash; ln and log10 of a NaN are \~inf: ln tests r == 0.0 first, with an == that holds when neither \< nor \> does
- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (33)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `ten` &middot; `thousand` &middot; `hundredth` &middot; `two` &middot; `large` &middot; `negative` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `nan` &middot; `powers-of-ten-exact` &middot; `floor-of-a-thousand` &middot; `law-is-ln-over-ln-ten`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `ten` &middot; `thousand` &middot; `hundredth` &middot; `two` &middot; `large` &middot; `negative` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `nan` &middot; `powers-of-ten-exact` &middot; `floor-of-a-thousand` &middot; `law-is-ln-over-ln-ten`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `zero` &middot; `posInf` &middot; `negative`

</details>

### <a name="val-sinh"></a>`sinh`

```sml
val sinh : real -> real
```

`sinh x` is the hyperbolic sine of `x`, `(e^x - e^~x) / 2`.

It keeps the sign of a zero, and overflows to an infinity of the sign of
`x` for a large enough `x`.

**Example** `Real.signBit (sinh ~0.0) = true`

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; Math.sinh (\~0.0) and Math.tanh (\~0.0) are 0.0, not \~0.0
- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (22)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `negative-overflow` &middot; `law-definition`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `negative-overflow` &middot; `law-definition`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negzero` &middot; `negInf`

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

**Example** `Real.== (cosh 0.0, 1.0) = true`

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; another reading of the specification: Math.cosh negInf is negInf, following "cosh +-infinity = +-infinity" to the letter; the test follows the definition (e^x + e^-x)/2, posInf
- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (19)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `law-definition`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `law-definition`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `zero`

</details>

### <a name="val-tanh"></a>`tanh`

```sml
val tanh : real -> real
```

`tanh x` is the hyperbolic tangent of `x`, `sinh x / cosh x`, between `~1` and 1.

It is `~1.0` and `1.0` at the infinities, and for a large enough finite
`x` it is those values too, although [`sinh`](#val-sinh) and [`cosh`](#val-cosh) both overflow
there.

**Example** `Real.== (tanh 1000.0, 1.0) = true`

<details><summary>Other implementations (4)</summary>

- **SML/NJ** &mdash; Math.sinh (\~0.0) and Math.tanh (\~0.0) are 0.0, not \~0.0
- **SML/NJ** &mdash; Math.tanh posInf is NaN
- **SML/NJ** &mdash; Math.tanh 1000.0 is NaN
- **Poly/ML** &mdash; where the result of a function of Real32.Math is a NaN it gives 0.0: asin 2.0, acos \~2.0, ln \~1.0, log10 \~1.0, pow (nan, 1.0)

</details>

<details><summary>Tests (22)</summary>

For `Real.Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `large` &middot; `large-negative` &middot; `law-definition`

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `large` &middot; `large-negative` &middot; `law-definition`

For `Real32.Math`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `posInf` &middot; `negzero`

</details>

## See also

[`REAL`](../sig/REAL.md), [`IEEE_REAL`](../sig/IEEE_REAL.md)

---

<sub>Generated by runedoc from lib/basis/sig\_math.sml; do not edit.</sub>
