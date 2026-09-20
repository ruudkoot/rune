# signature REAL

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **REAL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 3 |
| Documentation | 64 of 64 entries documented |
| Tests | 1038 checks of 62 entries |
| Source | [lib/basis/sig\_real.sml](../../../../lib/basis/sig_real.sml) |

## Synopsis

```sml
signature REAL
structure LargeReal : REAL
structure Real : REAL where type real = real
structure Real32 :> REAL  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `LargeReal` |  | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| `Real` | Real: IEEE double precision. | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| `Real32` |  | [lib/basis/real32.sml](../../../../lib/basis/real32.sml) |

Floating-point numbers: IEEE 754 arithmetic, the numbers that are not
ordinary (the infinities, the NaNs and the negative zero), and the
conversions to and from integers and text.

[`Real`](REAL.md) is the default structure, [`LargeReal`](REAL.md) the widest, and the sized
ones are [`Real32`](REAL.md) and `Real64`. A NaN, "not a number", is what an
operation answers where there is no value to give: it is equal to nothing,
itself included, so [`==`](#val-op-eq-eq) is `false` for it and [`compare`](#val-compare) raises
[`Unordered`](../sig/IEEE_REAL.md#exn-unordered). Because of that the equality of the language is not available
at [`real`](#type-real); use [`==`](#val-op-eq-eq) where equality is meant and [`Real.compare`](#val-compare) where an
order is.

There are two zeros, which [`==`](#val-op-eq-eq) says are equal and [`signBit`](#val-signbit) tells apart;
a computation that underflows keeps the sign it came from.

The functions that round come in two kinds: [`realFloor`](#val-realfloor) and its like stay
in [`real`](#type-real), [`floor`](#val-floor) and its like give an `int` and raise where the result
would not fit.

> **Implementation** `Real.real/binary64`. [`Real.real`](#type-real) is the top-level [`real`](#type-real),
> the 64-bit IEEE double ([`radix`](#val-radix) 2, [`precision`](#val-precision) 53\), and so are [`LargeReal`](REAL.md)
> and `Real64`; the optional [`Real32`](REAL.md) is binary32. The conversions to and
> from text are correctly rounded, through the C library.

## Contents

[The type](#the-type) &middot;
[The format](#the-format) &middot;
[Arithmetic](#arithmetic) &middot;
[Choosing](#choosing) &middot;
[Signs](#signs) &middot;
[Comparing](#comparing) &middot;
[Classifying](#classifying) &middot;
[Taking a real apart](#taking-a-real-apart) &middot;
[Rounding to a whole number](#rounding-to-a-whole-number) &middot;
[Text](#text)

## Interface

<pre>
signature REAL =
sig

  type <a href="#type-real">real</a>

  structure <a href="#str-math">Math</a> : MATH where type real = real

  val <a href="#val-radix">radix</a> : int

  val <a href="#val-precision">precision</a> : int

  val <a href="#val-maxfinite">maxFinite</a> : real

  val <a href="#val-minpos">minPos</a> : real

  val <a href="#val-minnormalpos">minNormalPos</a> : real

  val <a href="#val-posinf">posInf</a> : real

  val <a href="#val-neginf">negInf</a> : real

  val <a href="#val-op-plus">+</a> : real * real -&gt; real

  val <a href="#val-op-minus">-</a> : real * real -&gt; real

  val <a href="#val-op-star">*</a> : real * real -&gt; real

  val <a href="#val-op-slash">/</a> : real * real -&gt; real

  val <a href="#val-rem">rem</a> : real * real -&gt; real

  val <a href="#val-op-star-plus">*+</a> : real * real * real -&gt; real

  val <a href="#val-op-star-minus">*-</a> : real * real * real -&gt; real

  val <a href="#val-op-tilde">~</a> : real -&gt; real

  val <a href="#val-abs">abs</a> : real -&gt; real

  val <a href="#val-min">min</a> : real * real -&gt; real

  val <a href="#val-max">max</a> : real * real -&gt; real

  val <a href="#val-sign">sign</a> : real -&gt; int

  val <a href="#val-signbit">signBit</a> : real -&gt; bool

  val <a href="#val-samesign">sameSign</a> : real * real -&gt; bool

  val <a href="#val-copysign">copySign</a> : real * real -&gt; real

  val <a href="#val-compare">compare</a> : real * real -&gt; order

  val <a href="#val-comparereal">compareReal</a> : real * real -&gt; IEEEReal.real_order

  val <a href="#val-op-lt">&lt;</a> : real * real -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : real * real -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : real * real -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : real * real -&gt; bool

  val <a href="#val-op-eq-eq">==</a> : real * real -&gt; bool

  val <a href="#val-op-bang-eq">!=</a> : real * real -&gt; bool

  val <a href="#val-op-question-eq">?=</a> : real * real -&gt; bool

  val <a href="#val-unordered">unordered</a> : real * real -&gt; bool

  val <a href="#val-isfinite">isFinite</a> : real -&gt; bool

  val <a href="#val-isnan">isNan</a> : real -&gt; bool

  val <a href="#val-isnormal">isNormal</a> : real -&gt; bool

  val <a href="#val-class">class</a> : real -&gt; IEEEReal.float_class

  val <a href="#val-tomanexp">toManExp</a> : real -&gt; {<a href="#fld-tomanexp.man">man</a> : real, <a href="#fld-tomanexp.exp">exp</a> : int}

  val <a href="#val-frommanexp">fromManExp</a> : {<a href="#fld-frommanexp.man">man</a> : real, <a href="#fld-frommanexp.exp">exp</a> : int} -&gt; real

  val <a href="#val-split">split</a> : real -&gt; {<a href="#fld-split.whole">whole</a> : real, <a href="#fld-split.frac">frac</a> : real}

  val <a href="#val-realmod">realMod</a> : real -&gt; real

  val <a href="#val-nextafter">nextAfter</a> : real * real -&gt; real

  val <a href="#val-checkfloat">checkFloat</a> : real -&gt; real

  val <a href="#val-realfloor">realFloor</a> : real -&gt; real

  val <a href="#val-realceil">realCeil</a> : real -&gt; real

  val <a href="#val-realtrunc">realTrunc</a> : real -&gt; real

  val <a href="#val-realround">realRound</a> : real -&gt; real

  val <a href="#val-floor">floor</a> : real -&gt; int

  val <a href="#val-ceil">ceil</a> : real -&gt; int

  val <a href="#val-trunc">trunc</a> : real -&gt; int

  val <a href="#val-round">round</a> : real -&gt; int

  val <a href="#val-toint">toInt</a> : IEEEReal.rounding_mode -&gt; real -&gt; int

  val <a href="#val-tolargeint">toLargeInt</a> : IEEEReal.rounding_mode -&gt; real -&gt; LargeInt.int

  val <a href="#val-fromint">fromInt</a> : int -&gt; real

  val <a href="#val-fromlargeint">fromLargeInt</a> : LargeInt.int -&gt; real

  val <a href="#val-tolarge">toLarge</a> : real -&gt; LargeReal.real

  val <a href="#val-fromlarge">fromLarge</a> : IEEEReal.rounding_mode -&gt; LargeReal.real -&gt; real

  val <a href="#val-fmt">fmt</a> : StringCvt.realfmt -&gt; real -&gt; string

  val <a href="#val-tostring">toString</a> : real -&gt; string

  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (real, 'a) StringCvt.reader

  val <a href="#val-fromstring">fromString</a> : string -&gt; real option

  val <a href="#val-todecimal">toDecimal</a> : real -&gt; IEEEReal.decimal_approx

  val <a href="#val-fromdecimal">fromDecimal</a> : IEEEReal.decimal_approx -&gt; real option
end
</pre>

## The type

### <a name="type-real"></a>`real`

```sml
type real
```

The type of floating-point numbers of this structure.

It does not admit equality: `=` would say that a NaN is equal to itself
and that the two zeros are different, and neither is what IEEE 754
means.

### <a name="str-math"></a>`Math`

```sml
structure Math : MATH where type real = real
```

A substructure: its members are described on the page of [`MATH`](../sig/MATH.md).

The elementary functions at this type: `sqrt`, `sin`, `ln` and the rest.

## The format

### <a name="val-radix"></a>`radix`

```sml
val radix : int
```

The base in which the significand is written: 2 for every binary format.

<details><summary>Tests (3)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `two`

For `LargeReal`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `same-as-Real`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `2`

</details>

### <a name="val-precision"></a>`precision`

```sml
val precision : int
```

The number of digits of the significand, in base [`radix`](#val-radix).

> **Implementation** `Real.precision/double`. 53 for binary64, which is 52
> stored bits and the leading one that is not stored. The arithmetic must
> show that precision and no more: `1.0 + 2^~52` is greater than `1.0`,
> and `1.0 + 2^~53` rounds back to `1.0`.

<details><summary>Tests (6)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `double` &middot; `one-plus-ulp` &middot; `one-plus-half-ulp` &middot; `no-extended-precision`

For `LargeReal`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `at-least-Real`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `24`

</details>

### <a name="val-maxfinite"></a>`maxFinite`

```sml
val maxFinite : real
```

The largest finite number of this type.

<details><summary>Tests (8)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `value` &middot; `literal` &middot; `is-finite` &middot; `doubling-overflows` &middot; `plus-ulp-overflows` &middot; `plus-small-is-absorbed`

For `LargeReal`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `at-least-Real`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `binary32`

</details>

### <a name="val-minpos"></a>`minPos`

```sml
val minPos : real
```

The smallest positive number of this type, which is subnormal and has few digits of precision.

<details><summary>Tests (6)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `value` &middot; `positive` &middot; `half-is-zero` &middot; `not-normal`

For `LargeReal`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `at-most-Real`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `2^-149`

</details>

### <a name="val-minnormalpos"></a>`minNormalPos`

```sml
val minNormalPos : real
```

The smallest positive normal number: the smallest with the full [`precision`](#val-precision) digits.

<details><summary>Tests (6)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `value` &middot; `literal` &middot; `is-normal` &middot; `below-is-subnormal` &middot; `ratio-to-minPos`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `2^-126`

</details>

### <a name="val-posinf"></a>`posInf`

```sml
val posInf : real
```

Positive infinity, what a computation that grows without bound gives.

<details><summary>Tests (4)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `above-maxFinite` &middot; `one-over-zero` &middot; `not-finite`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `infinite`

</details>

### <a name="val-neginf"></a>`negInf`

```sml
val negInf : real
```

Negative infinity.

<details><summary>Tests (4)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `below-minus-maxFinite` &middot; `minus-one-over-zero` &middot; `negated-posInf`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `infinite`

</details>

## Arithmetic

### <a name="val-op-plus"></a>`+`

```sml
val + : real * real -> real
```

`x + y` is the sum, correctly rounded.

<details><summary>Tests (21)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `negative` &middot; `double-rounding` &middot; `finite-posInf` &middot; `finite-negInf` &middot; `posInf-posInf` &middot; `negInf-negInf` &middot; `posInf-negInf` &middot; `negInf-posInf` &middot; `nan-left` &middot; `nan-right` &middot; `overflow-is-posInf` &middot; `zero-plus-negzero` &middot; `negzero-plus-negzero` &middot; `law-commutative`

For `LargeReal`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `exact` &middot; `tie-to-even` &middot; `rounds-up` &middot; `overflow` &middot; `TO_POSINF`

</details>

### <a name="val-op-minus"></a>`-`

```sml
val - : real * real -> real
```

`x - y` is the difference, correctly rounded.

<details><summary>Tests (13)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `finite-minus-negInf` &middot; `finite-minus-posInf` &middot; `posInf-minus-finite` &middot; `posInf-minus-negInf` &middot; `negInf-minus-posInf` &middot; `posInf-minus-posInf` &middot; `negInf-minus-negInf` &middot; `nan` &middot; `equal-operands-give-plus-zero` &middot; `law-is-plus-negation`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `rounds` &middot; `infinities`

</details>

### <a name="val-op-star"></a>`*`

```sml
val * : real * real -> real
```

`x * y` is the product, correctly rounded.

<details><summary>Tests (17)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `signs` &middot; `zero-posInf` &middot; `negInf-zero` &middot; `negzero-posInf` &middot; `negative-negInf` &middot; `posInf-negInf` &middot; `posInf-posInf` &middot; `positive-negInf` &middot; `nan` &middot; `overflow` &middot; `underflow-to-zero` &middot; `negative-underflow-to-negzero` &middot; `signed-zero` &middot; `law-halving-doubling-exact`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `rounds` &middot; `underflow`

</details>

### <a name="val-op-slash"></a>`/`

```sml
val / : real * real -> real
```

`x / y` is the quotient, correctly rounded.

Division by zero is not an error here: it gives an infinity of the
right sign, and `0.0 / 0.0` gives a NaN.

<details><summary>Tests (22)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `zero-by-zero` &middot; `posInf-by-posInf` &middot; `negInf-by-posInf` &middot; `posInf-by-negInf` &middot; `finite-by-zero` &middot; `negative-by-zero` &middot; `finite-by-negzero` &middot; `negative-by-negzero` &middot; `posInf-by-finite` &middot; `posInf-by-negative` &middot; `negInf-by-zero` &middot; `finite-by-posInf` &middot; `negative-by-posInf` &middot; `finite-by-negInf` &middot; `negative-by-negInf` &middot; `nan` &middot; `correctly-rounded-third`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `one-third` &middot; `by-zero` &middot; `zero-by-zero` &middot; `TO_ZERO`

</details>

### <a name="val-rem"></a>`rem`

```sml
val rem : real * real -> real
```

`rem (x, y)` is what is left of `x` after taking away a whole number of `y`: `x - n * y` with `n` the quotient rounded towards zero.

It is computed exactly, whatever the magnitudes, and is a NaN when `x`
is infinite or `y` is zero; for an infinite `y` it is `x`.

> **Reading** `Real.rem/exact-multiple-negative-x`. The sign of a zero
> remainder is left open: the specification asks for the sign of `x`, and
> the definition `x - n * y` gives a positive zero.

<details><summary>Tests (25)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `negative-x` &middot; `negative-y` &middot; `both-negative` &middot; `x-smaller-than-y` &middot; `exact-multiple` &middot; `exact-multiple-negative-x` &middot; `fractional-y` &middot; `posInf-x` &middot; `negInf-x` &middot; `zero-y` &middot; `negzero-y` &middot; `zero-by-zero` &middot; `posInf-y` &middot; `negInf-y` &middot; `zero-x-posInf-y` &middot; `both-infinite` &middot; `nan-x` &middot; `nan-y` &middot; `large-quotient` &middot; `huge-exact-quotient` &middot; `law-agrees-with-Int-rem` &middot; `law-sign-and-magnitude`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `exact` &middot; `sign-of-dividend`

</details>

### <a name="val-op-star-plus"></a>`*+`

```sml
val *+ : real * real * real -> real
```

`*+ (x, y, z)` is `x * y + z`.

> **Implementation** `Real.*+/fused`. Whether the multiplication and the
> addition are rounded once or twice is left to the implementation.

<details><summary>Tests (9)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `negative` &middot; `posInf-product` &middot; `posInf-times-zero` &middot; `posInf-plus-negInf` &middot; `finite-plus-negInf` &middot; `nan` &middot; `law-small-integers`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `exact`

</details>

### <a name="val-op-star-minus"></a>`*-`

```sml
val *- : real * real * real -> real
```

`*- (x, y, z)` is `x * y - z`.

<details><summary>Tests (7)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `negative` &middot; `posInf-minus-posInf` &middot; `posInf-minus-negInf` &middot; `finite-minus-posInf` &middot; `nan`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `exact`

</details>

### <a name="val-op-tilde"></a>`~`

```sml
val ~ : real -> real
```

`~x` is `x` with its sign bit inverted, the zeros and the NaNs included.

<details><summary>Tests (11)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `negative` &middot; `posInf` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `nan` &middot; `flips-nan-sign` &middot; `zero-literal-has-sign-bit`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negates` &middot; `zero`

</details>

### <a name="val-abs"></a>`abs`

```sml
val abs : real -> real
```

`abs x` is `x` with its sign bit clear.

<details><summary>Tests (11)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `positive` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `negative-nan-sign-cleared` &middot; `toplevel`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative` &middot; `negInf`

</details>

## Choosing

### <a name="val-min"></a>`min`

```sml
val min : real * real -> real
```

`min (x, y)` is the smaller of the two, or the one that is not a NaN when the other is.

<details><summary>Tests (13)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `swapped` &middot; `negative` &middot; `negInf` &middot; `posInf` &middot; `nan-left` &middot; `nan-right` &middot; `nan-and-posInf` &middot; `nan-both` &middot; `zeros` &middot; `law-min-le-max`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `smaller` &middot; `nan`

</details>

### <a name="val-max"></a>`max`

```sml
val max : real * real -> real
```

`max (x, y)` is the larger of the two, or the one that is not a NaN when the other is.

<details><summary>Tests (11)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `swapped` &middot; `negative` &middot; `posInf` &middot; `negInf` &middot; `nan-left` &middot; `nan-right` &middot; `nan-and-negInf` &middot; `nan-both`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `larger` &middot; `nan`

</details>

## Signs

### <a name="val-sign"></a>`sign`

```sml
val sign : real -> int
```

`sign x` is \~1, 0 or 1, as `x` is negative, zero or positive.

**Raises** [`Domain`](../sig/GENERAL.md#exn-domain) if `x` is a NaN.

<details><summary>Tests (13)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `positive` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `minPos` &middot; `minus-minPos` &middot; `Domain-nan` (raises Domain) &middot; `law-matches-comparison`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative` &middot; `zero` &middot; `Domain-nan` (raises Domain)

</details>

### <a name="val-signbit"></a>`signBit`

```sml
val signBit : real -> bool
```

`signBit x` is `true` when the sign bit of `x` is set.

> **Reading** `Real.signBit/zeros`. It looks at the bit and not at the value,
> so it tells the two zeros apart and answers for a NaN as well.

<details><summary>Tests (12)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `positive` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `computed-negzero` &middot; `negative-nan-sign` &middot; `positive-nan` &middot; `law-is-negative`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative-zero` &middot; `positive`

</details>

### <a name="val-samesign"></a>`sameSign`

```sml
val sameSign : real * real -> bool
```

`sameSign (x, y)` is `true` when `x` and `y` have the same sign bit.

**Law** `sameSign (x, y) = (signBit x = signBit y)`

<details><summary>Tests (10)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `both-positive` &middot; `both-negative` &middot; `different` &middot; `zeros-differ` &middot; `negzero-negative` &middot; `zero-posInf` &middot; `differing-nan-sign` &middot; `law-is-signBit-equality`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `zeros` &middot; `negatives`

</details>

### <a name="val-copysign"></a>`copySign`

```sml
val copySign : real * real -> real
```

`copySign (x, y)` is `x` with the sign bit of `y`.

<details><summary>Tests (14)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `to-negative` &middot; `to-positive` &middot; `unchanged` &middot; `sign-of-negzero` &middot; `sign-of-zero` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `sign-of-negInf` &middot; `from-negative-nan-sign` &middot; `sign-of-positive-nan` &middot; `nan` &middot; `law-sign-and-magnitude`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative`

</details>

## Comparing

### <a name="val-compare"></a>`compare`

```sml
val compare : real * real -> order
```

`compare (x, y)` orders two reals.

**Raises** [`IEEEReal.Unordered`](../sig/IEEE_REAL.md#exn-unordered) if either is a NaN, which is the top-level
[`Unordered`](../sig/IEEE_REAL.md#exn-unordered).

<details><summary>Tests (17)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `less` &middot; `equal` &middot; `greater` &middot; `zeros-equal` &middot; `infinities` &middot; `posInf-equal` &middot; `maxFinite-posInf` &middot; `subnormals` &middot; `nan-left-raises` (raises any) &middot; `nan-right-raises` (raises any) &middot; `nan-both-raises` (raises any) &middot; `Unordered-nan-left` (raises) &middot; `Unordered-nan-right` (raises) &middot; `Unordered-nan-both` (raises)

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `less` &middot; `zeros` &middot; `Unordered-nan` (raises)

</details>

### <a name="val-comparereal"></a>`compareReal`

```sml
val compareReal : real * real -> IEEEReal.real_order
```

`compareReal (x, y)` orders two reals, and answers `UNORDERED` where a NaN makes the question meaningless.

<details><summary>Tests (11)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `less` &middot; `equal` &middot; `greater` &middot; `zeros-equal` &middot; `infinities` &middot; `nan-left` &middot; `nan-right` &middot; `nan-both` &middot; `law-agrees-with-compare`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `unordered` &middot; `greater`

</details>

### <a name="val-op-lt"></a><a name="val-op-lt-eq"></a><a name="val-op-gt"></a><a name="val-op-gt-eq"></a>`<`, `<=`, `>`, `>=`

```sml
val < : real * real -> bool
val <= : real * real -> bool
val > : real * real -> bool
val >= : real * real -> bool
```

`x < y`, `x <= y`, `x > y` and `x >= y` compare two reals.

Every one of them is `false` when either side is a NaN, so `x <= y` is
not the negation of `x > y`.

<details><summary>Tests (19)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `less` &middot; `equal` &middot; `greater` &middot; `zeros` &middot; `negInf-posInf` &middot; `maxFinite-posInf` &middot; `nan-left` &middot; `nan-right` &middot; `nan-posInf` &middot; `no-reversal-with-nan` &middot; `toplevel-overloaded` &middot; `law-trichotomy` &middot; `posInf-posInf` &middot; `nan-both` &middot; `posInf-maxFinite`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `less` &middot; `nan` &middot; `equal` &middot; `greater`

</details>

### <a name="val-op-eq-eq"></a>`==`

```sml
val == : real * real -> bool
```

`== (x, y)` is `true` when `x` and `y` are the same number.

The two zeros are the same number; a NaN is not even equal to itself.
This is the equality of IEEE 754 and what a program should use at
[`real`](#type-real). The specification writes it infix, which a program must declare
(`infix 4 ==`) before it can do the same.

<details><summary>Tests (10)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `equal` &middot; `different` &middot; `zeros` &middot; `posInf` &middot; `infinities` &middot; `nan-nan` &middot; `nan-left` &middot; `nan-right`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `zeros` &middot; `nan`

</details>

### <a name="val-op-bang-eq"></a>`!=`

```sml
val != : real * real -> bool
```

`!= (x, y)` is the negation of `== (x, y)`, so it is `true` when either is a NaN.

<details><summary>Tests (9)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `equal` &middot; `different` &middot; `zeros` &middot; `nan-nan` &middot; `nan-left` &middot; `nan-right` &middot; `law-is-not-equal`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `nan` &middot; `equal`

</details>

### <a name="val-op-question-eq"></a>`?=`

```sml
val ?= : real * real -> bool
```

`?= (x, y)` is `true` when `x` and `y` are equal or either is a NaN: "unordered or equal".

**Law** `?= (x, y) = (unordered (x, y) orelse == (x, y))`

<details><summary>Tests (10)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `equal` &middot; `different` &middot; `zeros` &middot; `nan-left` &middot; `nan-right` &middot; `nan-both` &middot; `infinities` &middot; `posInf`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `nan` &middot; `different`

</details>

### <a name="val-unordered"></a>`unordered`

```sml
val unordered : real * real -> bool
```

`unordered (x, y)` is `true` when either is a NaN, so that no order relates them.

<details><summary>Tests (7)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `ordered` &middot; `infinities` &middot; `nan-left` &middot; `nan-right` &middot; `nan-both`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `nan` &middot; `numbers`

</details>

## Classifying

### <a name="val-isfinite"></a>`isFinite`

```sml
val isFinite : real -> bool
```

`isFinite x` is `true` when `x` is neither an infinity nor a NaN.

<details><summary>Tests (9)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `ordinary` &middot; `zero` &middot; `maxFinite` &middot; `minPos` &middot; `posInf` &middot; `negInf` &middot; `nan`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `maxFinite` &middot; `posInf`

</details>

### <a name="val-isnan"></a>`isNan`

```sml
val isNan : real -> bool
```

`isNan x` is `true` when `x` is a NaN.

<details><summary>Tests (9)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `nan` &middot; `zero-by-zero` &middot; `negative-nan` &middot; `ordinary` &middot; `posInf` &middot; `negInf` &middot; `zero`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `nan` &middot; `infinity`

</details>

### <a name="val-isnormal"></a>`isNormal`

```sml
val isNormal : real -> bool
```

`isNormal x` is `true` when `x` is an ordinary number: finite, not zero and not subnormal.

<details><summary>Tests (14)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `ordinary` &middot; `maxFinite` &middot; `minNormalPos` &middot; `negative-minNormalPos` &middot; `zero` &middot; `negzero` &middot; `largest-subnormal` &middot; `minPos` &middot; `negative-subnormal` &middot; `posInf` &middot; `negInf` &middot; `nan`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `minNormalPos` &middot; `minPos`

</details>

### <a name="val-class"></a>`class`

```sml
val class : real -> IEEEReal.float_class
```

`class x` is which of the five kinds of number `x` is.

<details><summary>Tests (19)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `nan` &middot; `negative-nan` &middot; `posInf` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `normal` &middot; `negative-normal` &middot; `maxFinite` &middot; `minNormalPos` &middot; `largest-subnormal` &middot; `minPos` &middot; `negative-subnormal` &middot; `law-agrees-with-predicates`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `subnormal` &middot; `normal` &middot; `zero` &middot; `inf` &middot; `nan`

</details>

## Taking a real apart

### <a name="val-tomanexp"></a>`toManExp`

```sml
val toManExp : real -> {man : real, exp : int}
```

`toManExp x` is the significand and the exponent of `x`: the `man` and `exp` for which `x` is `man * radix^exp`.

> **Reading** `Real.toManExp/one`. The specification writes the range of the
> significand as "1.0 \<= man \* radix \< radix", which for radix 2 means
> `0.5 <= |man| < 1.0`: the convention of C's `frexp`, and not the one
> that puts the point after the first digit. For a zero, an infinity or a
> NaN the significand is `x` itself.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-tomanexp.man"></a>`man` | `real` |  |
| <a name="fld-tomanexp.exp"></a>`exp` | `int` |  |

<details><summary>Tests (19)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `one` &middot; `eight` &middot; `three-quarters` &middot; `negative` &middot; `small` &middot; `zero` &middot; `negzero` &middot; `maxFinite` &middot; `minNormalPos` &middot; `minPos` &middot; `subnormal` &middot; `posInf-man` &middot; `negInf-man` &middot; `nan-man` &middot; `law-man-in-range` &middot; `law-exp-is-scale` &middot; `huge-two-to-the-1023rd`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `six` &middot; `minPos`

</details>

### <a name="val-frommanexp"></a>`fromManExp`

```sml
val fromManExp : {man : real, exp : int} -> real
```

`fromManExp {man, exp}` is `man * radix^exp`.

**Law** `fromManExp (toManExp x) == x` for a finite `x`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-frommanexp.man"></a>`man` | `real` |  |
| <a name="fld-frommanexp.exp"></a>`exp` | `int` |  |

<details><summary>Tests (25)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `one` &middot; `unnormalized-man` &middot; `negative-man` &middot; `zero-exp` &middot; `maxFinite` &middot; `minPos` &middot; `overflow` &middot; `negative-overflow` &middot; `underflow` &middot; `far-underflow` &middot; `negative-underflow` &middot; `wide-exp-up` &middot; `wide-exp-subnormal-to-large` &middot; `zero-man` &middot; `negzero-man` &middot; `posInf-man` &middot; `negInf-man` &middot; `nan-man` &middot; `law-inverts-toManExp` &middot; `huge-man-wide-exp-down` &middot; `huge-man-zero-exp` &middot; `huge-man-overflow`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `exact` &middot; `overflow` &middot; `rounds-to-minPos`

</details>

### <a name="val-split"></a>`split`

```sml
val split : real -> {whole : real, frac : real}
```

`split x` is the whole part and the fractional part of `x`, each with the sign of `x`.

The whole part is `x` rounded towards zero. For an infinity the
fractional part is a zero, and for a NaN both are NaNs.

**Law** `#whole (split x) + #frac (split x) == x`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-split.whole"></a>`whole` | `real` |  |
| <a name="fld-split.frac"></a>`frac` | `real` |  |

<details><summary>Tests (16)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `negative` &middot; `fraction-only` &middot; `negative-fraction-only` &middot; `integral` &middot; `negative-integral` &middot; `zero` &middot; `negzero` &middot; `huge` &middot; `largest-fraction` &middot; `minPos` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-parts`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative`

</details>

### <a name="val-realmod"></a>`realMod`

```sml
val realMod : real -> real
```

`realMod x` is the fractional part of `x`, with its sign.

**Law** `realMod x = #frac (split x)`

<details><summary>Tests (10)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `negative` &middot; `integral` &middot; `negative-integral` &middot; `huge` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-is-frac-of-split`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `fraction`

</details>

### <a name="val-nextafter"></a>`nextAfter`

```sml
val nextAfter : real * real -> real
```

`nextAfter (x, y)` is the number of this type next to `x` in the direction of `y`.

> **Reading** `Real.nextAfter/equal-zeros-returns-r`. "If `r = t` then it
> returns `r`": the two zeros are equal, so `nextAfter (~0.0, 0.0)` is
> `~0.0`. C's `nextafter` returns `t` there, and MLton and Poly/ML follow
> C.

<details><summary>Tests (34)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `up-from-one` &middot; `down-from-one` &middot; `towards-posInf` &middot; `towards-negInf` &middot; `negative-up` &middot; `negative-down` &middot; `equal` &middot; `equal-zeros` &middot; `equal-zeros-returns-r` &middot; `equal-zeros-returns-r-positive` &middot; `zero-up` &middot; `zero-down` &middot; `negzero-up` &middot; `minPos-down` &middot; `subnormal-to-normal` &middot; `maxFinite-up` &middot; `maxFinite-down` &middot; `nan-first` &middot; `nan-second` &middot; `posInf-equal` &middot; `negInf-equal` &middot; `posInf-towards-zero` &middot; `negInf-towards-zero` &middot; `law-monotone` &middot; `law-adjacent`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `up` &middot; `down` &middot; `maxFinite-up` &middot; `zero-down` &middot; `minNormalPos-down` &middot; `negative-away` &middot; `nan` &middot; `equal-zeros-returns-r` &middot; `equal-zeros-returns-r-positive`

</details>

### <a name="val-checkfloat"></a>`checkFloat`

```sml
val checkFloat : real -> real
```

`checkFloat x` is `x` when it is finite, and raises otherwise.

It is how a program turns the silent results of IEEE arithmetic into
exceptions at the point it chooses.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if `x` is an infinity; [`Div`](../sig/GENERAL.md#exn-div) if `x` is a NaN.

<details><summary>Tests (10)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `ordinary` &middot; `negzero` &middot; `maxFinite` &middot; `minPos` &middot; `Overflow-posInf` (raises Overflow) &middot; `Overflow-negInf` (raises Overflow) &middot; `Div-nan` (raises Div)

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `finite` &middot; `Overflow-inf` (raises Overflow) &middot; `Div-nan` (raises Div)

</details>

## Rounding to a whole number

### <a name="val-realfloor"></a>`realFloor`

```sml
val realFloor : real -> real
```

`realFloor x` is the largest whole number that is not greater than `x`, as a [`real`](#type-real).

> **Reading** `Real.realFloor/negzero-sign`. The specification is silent
> about the sign of a zero result; IEEE 754 keeps the sign of the operand,
> so `realFloor ~0.5` is `~0.0`. The same holds for [`realCeil`](#val-realceil),
> [`realTrunc`](#val-realtrunc) and [`realRound`](#val-realround).

<details><summary>Tests (13)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `positive` &middot; `negative` &middot; `integral` &middot; `small-negative` &middot; `zero` &middot; `huge` &middot; `negative-huge` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `negzero-sign` &middot; `law-bounds`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative`

</details>

### <a name="val-realceil"></a>`realCeil`

```sml
val realCeil : real -> real
```

`realCeil x` is the smallest whole number that is not less than `x`, as a [`real`](#type-real).

<details><summary>Tests (11)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `positive` &middot; `negative` &middot; `integral` &middot; `small-positive` &middot; `huge` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `negzero-sign` &middot; `law-bounds`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `positive`

</details>

### <a name="val-realtrunc"></a>`realTrunc`

```sml
val realTrunc : real -> real
```

`realTrunc x` is `x` rounded towards zero, as a [`real`](#type-real).

<details><summary>Tests (10)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `positive` &middot; `negative` &middot; `fraction` &middot; `huge` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `negzero-sign` &middot; `law-towards-zero`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative`

</details>

### <a name="val-realround"></a>`realRound`

```sml
val realRound : real -> real
```

`realRound x` is `x` rounded to the nearest whole number, as a [`real`](#type-real).

> **Reading** `Real.realRound/tie-half`. A value exactly between two whole
> numbers goes to the even one, as it does for [`round`](#val-round): the specification
> states the rule under [`round`](#val-round) alone, and IEEE 754's rounding to an
> integral value agrees.

<details><summary>Tests (20)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `down` &middot; `up` &middot; `negative-down` &middot; `negative-up` &middot; `tie-half` &middot; `tie-one-and-half` &middot; `tie-two-and-half` &middot; `tie-three-and-half` &middot; `tie-negative` &middot; `tie-negative-odd` &middot; `just-below-half` &middot; `large-odd` &middot; `huge` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `negzero-sign` &middot; `law-nearest`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `tie-to-even` &middot; `tie-up`

</details>

### <a name="val-floor"></a>`floor`

```sml
val floor : real -> int
```

`floor x` is the largest whole number that is not greater than `x`, as an `int`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if that number is outside the range of [`Int.int`](../sig/INTEGER.md#type-int);
[`Domain`](../sig/GENERAL.md#exn-domain) if `x` is a NaN.

Also in the [top-level environment](../top-level.md): `floor`.

<details><summary>Tests (20)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `positive` &middot; `negative` &middot; `integral` &middot; `negzero` &middot; `small-negative` &middot; `toplevel` &middot; `large-negative` &middot; `Overflow-posInf` (raises Overflow) &middot; `Overflow-negInf` (raises Overflow) &middot; `Domain-nan` (raises Domain) &middot; `Overflow-above-maxInt` &middot; `Overflow-below-minInt` &middot; `Overflow-huge` &middot; `minInt` &middot; `near-maxInt` &middot; `maxInt-plus-half` &middot; `Overflow-minInt-minus-half` &middot; `law-agrees-with-realFloor`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative` &middot; `Overflow-inf` (raises Overflow)

</details>

### <a name="val-ceil"></a>`ceil`

```sml
val ceil : real -> int
```

`ceil x` is the smallest whole number that is not less than `x`, as an `int`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if it does not fit; [`Domain`](../sig/GENERAL.md#exn-domain) if `x` is a NaN.

Also in the [top-level environment](../top-level.md): `ceil`.

<details><summary>Tests (16)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `positive` &middot; `negative` &middot; `integral` &middot; `small-positive` &middot; `negative-fraction` &middot; `toplevel` &middot; `Overflow-posInf` (raises Overflow) &middot; `Overflow-negInf` (raises Overflow) &middot; `Domain-nan` (raises Domain) &middot; `Overflow-above-maxInt` &middot; `Overflow-below-minInt` &middot; `minInt` &middot; `minInt-minus-half` &middot; `near-maxInt` &middot; `Overflow-maxInt-plus-half`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative`

</details>

### <a name="val-trunc"></a>`trunc`

```sml
val trunc : real -> int
```

`trunc x` is `x` rounded towards zero, as an `int`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if it does not fit; [`Domain`](../sig/GENERAL.md#exn-domain) if `x` is a NaN.

Also in the [top-level environment](../top-level.md): `trunc`.

<details><summary>Tests (14)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `positive` &middot; `negative` &middot; `fraction` &middot; `toplevel` &middot; `Overflow-posInf` (raises Overflow) &middot; `Overflow-negInf` (raises Overflow) &middot; `Domain-nan` (raises Domain) &middot; `Overflow-above-maxInt` &middot; `Overflow-below-minInt` &middot; `minInt` &middot; `minInt-minus-half` &middot; `near-maxInt` &middot; `maxInt-plus-half`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `negative`

</details>

### <a name="val-round"></a>`round`

```sml
val round : real -> int
```

`round x` is `x` rounded to the nearest whole number, ties to even, as an `int`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if it does not fit; [`Domain`](../sig/GENERAL.md#exn-domain) if `x` is a NaN.

Also in the [top-level environment](../top-level.md): `round`.

<details><summary>Tests (27)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `down` &middot; `up` &middot; `negative` &middot; `tie-half` &middot; `tie-one-and-half` &middot; `tie-two-and-half` &middot; `tie-three-and-half` &middot; `tie-negative-half` &middot; `tie-negative` &middot; `tie-negative-odd` &middot; `just-below-half` &middot; `toplevel` &middot; `large` &middot; `Overflow-posInf` (raises Overflow) &middot; `Overflow-negInf` (raises Overflow) &middot; `Domain-nan` (raises Domain) &middot; `Overflow-above-maxInt` &middot; `Overflow-below-minInt` &middot; `Overflow-negative-huge` &middot; `minInt` &middot; `minInt-minus-half-tie-to-even` &middot; `near-maxInt` &middot; `Overflow-maxInt-plus-half-tie-to-even` &middot; `law-halves-to-even`

For `LargeReal`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `tie-to-even`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `tie-to-even` &middot; `Domain-nan` (raises Domain)

</details>

### <a name="val-toint"></a>`toInt`

```sml
val toInt : IEEEReal.rounding_mode -> real -> int
```

`toInt mode x` is `x` rounded to an `int` in the given rounding mode.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if it does not fit; [`Domain`](../sig/GENERAL.md#exn-domain) if `x` is a NaN.

<details><summary>Tests (17)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `TO_NEGINF-positive` &middot; `TO_NEGINF-negative` &middot; `TO_POSINF-positive` &middot; `TO_POSINF-negative` &middot; `TO_ZERO-positive` &middot; `TO_ZERO-negative` &middot; `TO_NEAREST-down` &middot; `TO_NEAREST-up` &middot; `TO_NEAREST-tie-even` &middot; `TO_NEAREST-tie-odd` &middot; `TO_NEAREST-tie-negative` &middot; `*` &middot; `Overflow-*` (raises Overflow) &middot; `Domain-*` (raises Domain) &middot; `Overflow-*` &middot; `law-equivalences`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `TO_NEGINF` &middot; `TO_NEAREST`

</details>

### <a name="val-tolargeint"></a>`toLargeInt`

```sml
val toLargeInt : IEEEReal.rounding_mode -> real -> LargeInt.int
```

`toLargeInt mode x` is `x` rounded to a [`LargeInt.int`](../sig/INTEGER.md#type-int) in the given rounding mode.

Where [`LargeInt`](../sig/INTEGER.md) has no bounds this loses nothing, however large `x` is.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if `x` is an infinity, or if the result does not fit
a bounded [`LargeInt.int`](../sig/INTEGER.md#type-int); [`Domain`](../sig/GENERAL.md#exn-domain) if `x` is a NaN.

<details><summary>Tests (22)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `TO_NEGINF-positive` &middot; `TO_NEGINF-negative` &middot; `TO_POSINF-positive` &middot; `TO_POSINF-negative` &middot; `TO_ZERO-positive` &middot; `TO_ZERO-negative` &middot; `TO_NEAREST-tie-even` &middot; `TO_NEAREST-tie-odd` &middot; `TO_NEAREST-tie-negative` &middot; `TO_NEAREST-up` &middot; `ten-to-the-20th` &middot; `two-to-the-100th` &middot; `negative-two-to-the-200th` &middot; `two-to-the-1000th` &middot; `large-with-fraction` &middot; `Overflow-*` (raises Overflow) &middot; `Domain-*` (raises Domain) &middot; `law-agrees-with-toInt` &middot; `huge-maxFinite` &middot; `huge-negative-two-to-the-1023rd`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `maxFinite` &middot; `Overflow-inf` (raises Overflow)

</details>

### <a name="val-fromint"></a>`fromInt`

```sml
val fromInt : int -> real
```

`fromInt i` is `i` as a real, correctly rounded when the type cannot hold it exactly.

Also in the [top-level environment](../top-level.md): `real`.

<details><summary>Tests (12)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `zero` &middot; `positive` &middot; `negative` &middot; `large` &middot; `large-negative` &middot; `toplevel-real` &middot; `maxInt` &middot; `minInt` &middot; `law-round-trip`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `exact` &middot; `tie-to-even-down` &middot; `tie-to-even-up`

</details>

### <a name="val-fromlargeint"></a>`fromLargeInt`

```sml
val fromLargeInt : LargeInt.int -> real
```

`fromLargeInt i` is `i` as a real, correctly rounded.

> **Reading** `Real.fromLargeInt/tie-rounds-to-even-down`. The current
> rounding mode is used; under the default one a value exactly between two
> reals goes to the one whose last digit is even, and the digits that are
> dropped decide the rest.

<details><summary>Tests (17)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `zero` &middot; `positive` &middot; `negative` &middot; `ten-to-the-20th` &middot; `two-to-the-100th` &middot; `negative-two-to-the-1000th` &middot; `tie-rounds-to-even-down` &middot; `tie-rounds-to-even-up` &middot; `sticky-bit` &middot; `tie-without-sticky-bit` &middot; `maxFinite` &middot; `too-large-is-posInf` &middot; `too-small-is-negInf` &middot; `two-to-the-1024th-is-posInf`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `rounds-once` &middot; `negative` &middot; `overflow`

</details>

### <a name="val-tolarge"></a>`toLarge`

```sml
val toLarge : real -> LargeReal.real
```

`toLarge x` is `x` as a [`LargeReal.real`](#type-real), which loses nothing.

<details><summary>Tests (7)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `basic` &middot; `negative` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `tenth`

</details>

### <a name="val-fromlarge"></a>`fromLarge`

```sml
val fromLarge : IEEEReal.rounding_mode -> LargeReal.real -> real
```

`fromLarge mode x` is the number of this type nearest to `x`, rounded in the given mode.

> **Reading** `LargeReal/at-least-Real`. [`LargeReal`](REAL.md) is at least as wide as
> [`Real`](REAL.md), so this rounds only where it is wider.

<details><summary>Tests (10)</summary>

For `Real`, in [tests/basis/real.sml](../../../../tests/basis/real.sml): `*` &middot; `law-inverts-toLarge`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `TO_NEAREST` &middot; `TO_ZERO` &middot; `TO_POSINF` &middot; `TO_NEGINF-negative` &middot; `overflow-TO_ZERO` &middot; `overflow-TO_NEAREST` &middot; `underflow` &middot; `subnormal`

</details>

## Text

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : StringCvt.realfmt -> real -> string
```

`fmt spec x` is the text of `x` in the given notation.

[`StringCvt.SCI`](../sig/STRING_CVT.md#con-sci), `FIX` and `GEN` take a number of digits, and `EXACT`
writes as many as are needed to read the same number back. An infinity
is `"inf"` or `"~inf"` and a NaN is `"nan"`.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the number of digits is negative. The specification
says this happens "when `fmt spec` is evaluated", before a real is
given, so a partial application already raises.

> **Reading** `Real.fmt/SCI-negzero`. A negative zero is written with its
> sign, because the formats are described as `[~]?` and [`signBit`](#val-signbit) is set;
> MLton leaves the sign out.

> **Reading** `Real.fmt/GEN-integral-one`. In `GEN`, a number with no
> fractional part is written without a point, as C's `gcvt` does, and the
> shorter of the scientific and the fixed form is taken, a tie going to
> the fixed one: `fmt (GEN NONE) 1.0` is `"1"` and `fmt (GEN NONE) 1000.0`
> is `"1E3"`.

<details><summary>Tests (119)</summary>

For `Real`, in [tests/basis/real\_fmt.sml](../../../../tests/basis/real_fmt.sml): `SCI-default-one` &middot; `SCI-default-zero` &middot; `SCI-default-rounds` &middot; `SCI-default-negative` &middot; `SCI-two-digits` &middot; `SCI-zero-digits` &middot; `SCI-zero-digits-one` &middot; `SCI-zero-digits-zero` &middot; `SCI-zero-digits-rounds` &middot; `SCI-negative-exponent` &middot; `SCI-negative-both` &middot; `SCI-pads-with-zeros` &middot; `SCI-ten-digits` &middot; `SCI-twenty-digits` &middot; `SCI-carry` &middot; `SCI-carry-zero-digits` &middot; `SCI-power-of-ten` &middot; `SCI-small-power-of-ten` &middot; `SCI-large-exponent` &middot; `SCI-maxFinite` &middot; `SCI-minPos` &middot; `SCI-minNormalPos` &middot; `FIX-default-one` &middot; `FIX-default-zero` &middot; `FIX-default-rounds` &middot; `FIX-default-negative` &middot; `FIX-zero-digits` &middot; `FIX-zero-digits-rounds-up` &middot; `FIX-zero-digits-rounds-down` &middot; `FIX-zero-digits-negative` &middot; `FIX-zero-digits-fraction-up` &middot; `FIX-zero-digits-fraction-down` &middot; `FIX-zero-digits-zero` &middot; `FIX-one-digit` &middot; `FIX-pads-with-zeros` &middot; `FIX-integral` &middot; `FIX-exact-fraction` &middot; `FIX-power-of-ten` &middot; `FIX-ten-to-the-20th` &middot; `FIX-rounds-to-zero` &middot; `FIX-small` &middot; `FIX-carry` &middot; `FIX-carry-adds-digit` &middot; `FIX-carry-zero-digits` &middot; `FIX-twenty-digits` &middot; `FIX-exact-binary-fraction` &middot; `FIX-exact-binary-fraction-rounded` &middot; `FIX-minPos` &middot; `GEN-half` &middot; `GEN-eighth` &middot; `GEN-negative` &middot; `GEN-nine-digits` &middot; `GEN-tenth` &middot; `GEN-third` &middot; `GEN-two-thirds` &middot; `GEN-pi` &middot; `GEN-notation-hundredth` &middot; `GEN-notation-thousandth` &middot; `GEN-notation-small-tie` &middot; `GEN-notation-small-scientific` &middot; `GEN-notation-large` &middot; `GEN-notation-large-fraction` &middot; `GEN-notation-large-mantissa` &middot; `GEN-notation-huge` &middot; `GEN-notation-tiny` &middot; `GEN-notation-negative` &middot; `GEN-maxFinite` &middot; `GEN-minPos` &middot; `GEN-five-digits` &middot; `GEN-two-digits` &middot; `GEN-no-trailing-zeros` &middot; `GEN-notation-one-digit` &middot; `GEN-seventeen-digits` &middot; `GEN-sixteen-digits` &middot; `GEN-integral-one` &middot; `GEN-integral-zero` &middot; `GEN-integral-negative` &middot; `GEN-integral-hundred` &middot; `GEN-integral-five-digits` &middot; `GEN-integral-rounded` &middot; `GEN-integral-carry` &middot; `GEN-notation-thousand` &middot; `GEN-notation-tie-is-fixed` &middot; `GEN-notation-padded` &middot; `GEN-notation-padded-integer` &middot; `EXACT-half` &middot; `EXACT-quarter` &middot; `EXACT-one` &middot; `EXACT-tenth` &middot; `EXACT-negative` &middot; `EXACT-six-digits` &middot; `EXACT-negative-exponent` &middot; `EXACT-sixteenth` &middot; `EXACT-power-of-ten` &middot; `EXACT-maxFinite` &middot; `EXACT-zero` &middot; `EXACT-negzero` &middot; `*` &middot; `SCI-negzero` &middot; `FIX-negzero` &middot; `GEN-integral-negzero` &middot; `Size-SCI-negative` (raises Size) &middot; `Size-FIX-negative` (raises Size) &middot; `Size-GEN-zero` (raises Size) &middot; `Size-GEN-negative` (raises Size) &middot; `Size-SCI-infinite-argument` (raises Size) &middot; `Size-SCI-when-spec-is-evaluated` (raises Size) &middot; `Size-FIX-when-spec-is-evaluated` (raises Size) &middot; `Size-GEN-when-spec-is-evaluated` (raises Size) &middot; `GEN-one-is-valid` &middot; `EXACT-law-fromString-inverts` &middot; `law-FIX-of-integers` &middot; `law-EXACT-is-IEEEReal.toString-of-toDecimal`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `SCI` &middot; `FIX` &middot; `GEN-20` &middot; `EXACT-shortest` &middot; `EXACT-maxFinite` &middot; `Size-GEN-0` (raises Size)

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : real -> string
```

`toString x` is the text of `x` in the general notation with the default number of digits.

**Law** `toString x = fmt (StringCvt.GEN NONE) x`

<details><summary>Tests (17)</summary>

For `Real`, in [tests/basis/real\_fmt.sml](../../../../tests/basis/real_fmt.sml): `half` &middot; `negative` &middot; `twelve-digits` &middot; `nine-digits` &middot; `notation-large` &middot; `notation-small` &middot; `maxFinite` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `integral-one` &middot; `integral-zero` &middot; `integral-negative` &middot; `law-is-fmt-GEN-NONE`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `tenth` &middot; `third` &middot; `negInf`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (real, 'a) StringCvt.reader
```

`scan getc strm` reads a real from `strm`.

It skips initial white space and then takes an optional sign and either
a decimal numeral with an optional point and exponent, or one of the
words `inf`, `infinity` and `nan` in any case. The answer is
`SOME (x, rest)`, or `NONE` when no numeral is there.

A numeral whose value is too large becomes an infinity and one too small
a zero; nothing is raised. A numeral that no real holds exactly is
rounded as [`fromString`](#val-fromstring) rounds it.

<details><summary>Tests (25)</summary>

For `Real`, in [tests/basis/real\_fmt.sml](../../../../tests/basis/real_fmt.sml): `all` &middot; `rest` &middot; `rest-space` &middot; `none` &middot; `empty` &middot; `point-without-digits` &middot; `point-then-exponent` &middot; `second-point` &middot; `exponent-without-digits` &middot; `exponent-sign-without-digits` &middot; `exponent-letter` &middot; `after-exponent-point` &middot; `after-exponent-letter` &middot; `hexadecimal-is-zero` &middot; `sign-after-number` &middot; `nonfinite-infinity-all` &middot; `nonfinite-infinity-rest` &middot; `nonfinite-inf-rest` &middot; `nonfinite-infinit` &middot; `nonfinite-nan-rest` &middot; `no-number` &middot; `bare-point` &middot; `TO_NEGINF-negative`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `rest` &middot; `inf`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> real option
```

`fromString s` is the real that the text `s` begins with, or `NONE`.

**Law** `fromString s = StringCvt.scanString scan s`

> **Reading** `Real.fromString/TO_NEGINF-negative`. The numeral is rounded in
> the rounding mode that is in force, as in MLton and in C's `strtod`;
> SML/NJ and Poly/ML always round to nearest. [`Real32.fromString`](#val-fromstring) rounds
> once, straight to binary32, and not first to binary64.

<details><summary>Tests (80)</summary>

For `Real`, in [tests/basis/real\_fmt.sml](../../../../tests/basis/real_fmt.sml): `basic` &middot; `integer` &middot; `zero` &middot; `leading-zeros` &middot; `exact-many-digits` &middot; `tilde` &middot; `minus` &middot; `plus` &middot; `negative-zero` &middot; `minus-zero` &middot; `no-integer-part` &middot; `negative-no-integer-part` &middot; `exponent` &middot; `lowercase-exponent` &middot; `tilde-exponent` &middot; `minus-exponent` &middot; `plus-exponent` &middot; `fraction-and-exponent` &middot; `exponent-leading-zeros` &middot; `zero-exponent` &middot; `small` &middot; `leading-space` &middot; `leading-whitespace` &middot; `trailing-text` &middot; `trailing-space` &middot; `empty` &middot; `only-whitespace` &middot; `letters` &middot; `bare-point` &middot; `only-sign` &middot; `only-exponent` &middot; `bare-point-exponent` &middot; `two-signs` &middot; `sign-then-space` &middot; `nonfinite-inf` &middot; `nonfinite-infinity` &middot; `nonfinite-inf-uppercase` &middot; `nonfinite-infinity-mixed-case` &middot; `nonfinite-tilde-inf` &middot; `nonfinite-minus-infinity` &middot; `nonfinite-plus-inf` &middot; `nonfinite-whitespace-inf` &middot; `nonfinite-nan` &middot; `nonfinite-nan-mixed-case` &middot; `nonfinite-tilde-nan` &middot; `nonfinite-plus-nan` &middot; `in` &middot; `na` &middot; `too-large` &middot; `too-large-negative` &middot; `too-large-digits` &middot; `too-small` &middot; `too-small-negative` &middot; `huge-exponent` &middot; `huge-negative-exponent` &middot; `huge-exponent-of-zero` &middot; `exact-maxFinite` &middot; `exact-minPos` &middot; `exact-minNormalPos` &middot; `exact-subnormal-long-form` &middot; `exact-round-half-even` &middot; `exact-round-above-half` &middot; `law-is-scanString-scan` &middot; `law-inverts-toString-to-12-digits` &middot; `exact-law-inverts-fmt-SCI-16` &middot; `exact-law-inverts-fmt-GEN-17` &middot; `TO_NEGINF-negative` &middot; `TO_POSINF-negative` &middot; `TO_ZERO-negative` &middot; `TO_NEGINF-positive`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `tenth` &middot; `rounded-once` &middot; `overflow` &middot; `largest` &middot; `above-half-minPos` &middot; `underflow` &middot; `negative` &middot; `NONE` &middot; `TO_NEGINF` &middot; `TO_POSINF-negative`

</details>

### <a name="val-todecimal"></a>`toDecimal`

```sml
val toDecimal : real -> IEEEReal.decimal_approx
```

`toDecimal x` is `x` written out in decimal digits, exactly.

Every real has an exact decimal form, so nothing is lost; [`IEEEReal.toString`](../sig/IEEE_REAL.md#val-tostring)
turns the result into text.

<details><summary>Tests (26)</summary>

For `Real`, in [tests/basis/real\_fmt.sml](../../../../tests/basis/real_fmt.sml): `half` &middot; `one` &middot; `tenth` &middot; `three-tenths` &middot; `negative` &middot; `six-digits` &middot; `negative-exponent` &middot; `power-of-ten` &middot; `no-trailing-zeros` &middot; `third` &middot; `seventeen-digits` &middot; `maxFinite` &middot; `minNormalPos` &middot; `minPos` &middot; `subnormal-class` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `law-digits-are-minimal-form` &middot; `nan` &middot; `negative-nan`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `tenth` &middot; `maxFinite` &middot; `minPos` &middot; `negative-zero`

</details>

### <a name="val-fromdecimal"></a>`fromDecimal`

```sml
val fromDecimal : IEEEReal.decimal_approx -> real option
```

`fromDecimal d` is the real nearest to the decimal number `d`, or `NONE` when `d` is not a number a real can describe.

The current rounding mode is used. A `d` whose value is too large gives
an infinity and one too small a zero.

<details><summary>Tests (41)</summary>

For `Real`, in [tests/basis/real\_fmt.sml](../../../../tests/basis/real_fmt.sml): `half` &middot; `quarter` &middot; `positive-exponent` &middot; `large-exponent` &middot; `negative-exponent` &middot; `negative` &middot; `leading-zero-digits` &middot; `trailing-zero-digits` &middot; `seventeen-digits` &middot; `maxFinite` &middot; `minPos` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `zero-class-decides` &middot; `inf-class-decides` &middot; `no-digits-is-zero` &middot; `no-digits-is-negzero` &middot; `zero-digits-is-zero` &middot; `zero-digits-is-negzero` &middot; `subnormal-class-ignored` &middot; `normal-class-ignored` &middot; `too-large` &middot; `too-large-negative` &middot; `too-small` &middot; `too-small-negative` &middot; `digit-ten` &middot; `digit-negative` &middot; `digit-large` &middot; `law-inverts-toDecimal` &middot; `law-inverts-toDecimal-subnormal` &middot; `nan` &middot; `nan-class-decides` &middot; `negative-nan` &middot; `positive-nan` &middot; `TO_NEGINF-negative`

For `Real32`, in [tests/basis/real32.sml](../../../../tests/basis/real32.sml): `tenth` &middot; `negative` &middot; `NONE-bad-digit` &middot; `TO_NEGINF-negative`

</details>

## See also

[`MATH`](../sig/MATH.md), [`IEEE_REAL`](../sig/IEEE_REAL.md), [`INTEGER`](../sig/INTEGER.md), [`STRING_CVT`](../sig/STRING_CVT.md), [`PACK_REAL`](../sig/PACK_REAL.md)

---

<sub>Generated by runedoc from lib/basis/sig\_real.sml; do not edit.</sub>
