# signature MATH

[The Standard ML Basis Library](../README.md) &rsaquo; **MATH**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 4 |
| Documentation | 0 of 18 entries documented |
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

signature MATH, transcribed from <https://smlfamily.github.io/Basis/math.html>

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

### <a name="val-pi"></a>`pi`

```sml
val pi : real
```

<details><summary>Tests (4)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `value` &middot; `nearest-double` &middot; `digits` &middot; `same-as-Real.Math`

</details>

### <a name="val-e"></a>`e`

```sml
val e : real
```

<details><summary>Tests (3)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `value` &middot; `nearest-double` &middot; `digits`

</details>

### <a name="val-sqrt"></a>`sqrt`

```sml
val sqrt : real -> real
```

<details><summary>Tests (15)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `four` &middot; `quarter` &middot; `one` &middot; `two` &middot; `large` &middot; `zero` &middot; `negzero` &middot; `negative` &middot; `small-negative` &middot; `negInf` &middot; `posInf` &middot; `nan` &middot; `law-exact-squares` &middot; `law-squares-back` &middot; `same-as-Real.Math`

</details>

### <a name="val-sin"></a>`sin`

```sml
val sin : real -> real
```

<details><summary>Tests (12)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-six` &middot; `pi-over-two` &middot; `pi` &middot; `negative` &middot; `three-half-pi` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-pythagoras` &middot; `law-odd`

</details>

### <a name="val-cos"></a>`cos`

```sml
val cos : real -> real
```

<details><summary>Tests (11)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-three` &middot; `pi-over-two` &middot; `pi` &middot; `negative` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-even` &middot; `law-bounded`

</details>

### <a name="val-tan"></a>`tan`

```sml
val tan : real -> real
```

<details><summary>Tests (10)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `pi-over-four` &middot; `negative` &middot; `pi` &middot; `near-singularity` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-is-sin-over-cos`

</details>

### <a name="val-asin"></a>`asin`

```sml
val asin : real -> real
```

<details><summary>Tests (12)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `half` &middot; `one` &middot; `minus-one` &middot; `negative` &middot; `above-one` &middot; `just-above-one` &middot; `below-minus-one` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-range-and-inverse`

</details>

### <a name="val-acos"></a>`acos`

```sml
val acos : real -> real
```

<details><summary>Tests (13)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `half` &middot; `zero` &middot; `negative` &middot; `minus-one` &middot; `above-one` &middot; `just-above-one` &middot; `below-minus-one` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-range-and-inverse` &middot; `law-complements-asin`

</details>

### <a name="val-atan"></a>`atan`

```sml
val atan : real -> real
```

<details><summary>Tests (9)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `minus-one` &middot; `sqrt-three` &middot; `huge` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `law-range-and-inverse`

</details>

### <a name="val-atan2"></a>`atan2`

```sml
val atan2 : real * real -> real
```

<details><summary>Tests (34)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `first-quadrant` &middot; `second-quadrant` &middot; `third-quadrant` &middot; `fourth-quadrant` &middot; `ratio` &middot; `zero-y-positive-x` &middot; `negzero-y-positive-x` &middot; `zero-y-zero-x` &middot; `negzero-y-zero-x` &middot; `zero-y-negative-x` &middot; `negzero-y-negative-x` &middot; `zero-y-negzero-x` &middot; `negzero-y-negzero-x` &middot; `positive-y-zero-x` &middot; `positive-y-negzero-x` &middot; `negative-y-zero-x` &middot; `negative-y-negzero-x` &middot; `positive-y-posInf-x` &middot; `negative-y-posInf-x` &middot; `positive-y-negInf-x` &middot; `negative-y-negInf-x` &middot; `posInf-y-finite-x` &middot; `posInf-y-negative-x` &middot; `posInf-y-zero-x` &middot; `negInf-y-finite-x` &middot; `negInf-y-negative-x` &middot; `posInf-y-posInf-x` &middot; `negInf-y-posInf-x` &middot; `posInf-y-negInf-x` &middot; `negInf-y-negInf-x` &middot; `nan-y` &middot; `nan-x` &middot; `nan-both` &middot; `law-quadrant`

</details>

### <a name="val-exp"></a>`exp`

```sml
val exp : real -> real
```

<details><summary>Tests (12)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `zero` &middot; `one` &middot; `two` &middot; `minus-one` &middot; `large` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `underflow` &middot; `law-sum-is-product` &middot; `law-positive-and-inverse-of-ln`

</details>

### <a name="val-pow"></a>`pow`

```sml
val pow : real * real -> real
```

<details><summary>Tests (66)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `integer-power` &middot; `square-root` &middot; `negative-exponent` &middot; `fractional` &middot; `negative-base-odd` &middot; `negative-base-even` &middot; `negative-base-negative-odd` &middot; `one-base` &middot; `zero-exponent` &middot; `zero-exponent-negative-base` &middot; `zero-exponent-zero-base` &middot; `zero-exponent-posInf-base` &middot; `zero-exponent-negInf-base` &middot; `zero-exponent-nan-base` &middot; `negzero-exponent` &middot; `negzero-exponent-nan-base` &middot; `large-base-posInf` &middot; `large-negative-base-posInf` &middot; `posInf-base-posInf` &middot; `negInf-base-posInf` &middot; `small-base-posInf` &middot; `small-negative-base-posInf` &middot; `zero-base-posInf` &middot; `negzero-base-posInf` &middot; `large-base-negInf` &middot; `large-negative-base-negInf` &middot; `negInf-base-negInf` &middot; `small-base-negInf` &middot; `small-negative-base-negInf` &middot; `zero-base-negInf` &middot; `negzero-base-negInf` &middot; `posInf-base-positive` &middot; `posInf-base-small-positive` &middot; `posInf-base-negative` &middot; `posInf-base-small-negative` &middot; `negInf-base-positive-odd` &middot; `negInf-base-positive-even` &middot; `negInf-base-positive-fraction` &middot; `negInf-base-negative-odd` &middot; `negInf-base-negative-even` &middot; `negInf-base-negative-fraction` &middot; `nan-exponent` &middot; `nan-exponent-zero-base` &middot; `nan-exponent-posInf-base` &middot; `nan-both` &middot; `nan-base` &middot; `nan-base-posInf` &middot; `one-base-nan-exponent` &middot; `one-base-posInf` &middot; `one-base-negInf` &middot; `minus-one-base-posInf` &middot; `minus-one-base-negInf` &middot; `negative-base-fraction` &middot; `negative-base-negative-fraction` &middot; `zero-base-negative-odd` &middot; `negzero-base-negative-odd` &middot; `zero-base-negative-even` &middot; `negzero-base-negative-even` &middot; `negzero-base-negative-fraction` &middot; `zero-base-positive-odd` &middot; `negzero-base-positive-odd` &middot; `zero-base-positive-even` &middot; `negzero-base-positive-even` &middot; `negzero-base-positive-fraction` &middot; `law-exponent-one-and-two` &middot; `law-is-exp-of-ln`

</details>

### <a name="val-ln"></a>`ln`

```sml
val ln : real -> real
```

<details><summary>Tests (13)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `e` &middot; `two` &middot; `ten` &middot; `half` &middot; `minPos` &middot; `negative` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `nan` &middot; `law-product-is-sum`

</details>

### <a name="val-log10"></a>`log10`

```sml
val log10 : real -> real
```

<details><summary>Tests (13)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `ten` &middot; `thousand` &middot; `hundredth` &middot; `two` &middot; `large` &middot; `negative` &middot; `negInf` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `nan` &middot; `law-is-ln-over-ln-ten`

</details>

### <a name="val-sinh"></a>`sinh`

```sml
val sinh : real -> real
```

<details><summary>Tests (10)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `negative-overflow` &middot; `law-definition`

</details>

### <a name="val-cosh"></a>`cosh`

```sml
val cosh : real -> real
```

<details><summary>Tests (9)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `overflow` &middot; `law-definition`

</details>

### <a name="val-tanh"></a>`tanh`

```sml
val tanh : real -> real
```

<details><summary>Tests (10)</summary>

For `Math`, in [tests/basis/math.sml](../../../../tests/basis/math.sml): `one` &middot; `negative` &middot; `zero` &middot; `negzero` &middot; `posInf` &middot; `negInf` &middot; `nan` &middot; `large` &middot; `large-negative` &middot; `law-definition`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_math.sml; do not edit.</sub>
