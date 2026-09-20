# signature IEEE_REAL

[The Standard ML Basis Library](../README.md) &rsaquo; **IEEE_REAL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 10 entries documented |
| Tests | 48 checks of 6 entries |
| Source | [lib/basis/sig\_ieee\_real.sml](../../../../lib/basis/sig_ieee_real.sml) |

## Synopsis

```sml
signature IEEE_REAL
structure IEEEReal : IEEE_REAL
```

| Implementation |  | Source |
| --- | --- | --- |
| `IEEEReal` | IEEEReal: the types of IEEE arithmetic that do not depend on a precision. | [lib/basis/ieeereal.sml](../../../../lib/basis/ieeereal.sml) |

signature IEEE\_REAL, transcribed from <https://smlfamily.github.io/Basis/ieee-float.html>

## Interface

<pre>
signature IEEE_REAL =
sig
  exception <a href="#exn-unordered">Unordered</a>
  datatype <a href="#type-real_order">real_order</a> = <a href="#con-less">LESS</a> | <a href="#con-equal">EQUAL</a> | <a href="#con-greater">GREATER</a> | <a href="#con-unordered">UNORDERED</a>
  datatype <a href="#type-float_class">float_class</a> = <a href="#con-nan">NAN</a> | <a href="#con-inf">INF</a> | <a href="#con-zero">ZERO</a> | <a href="#con-normal">NORMAL</a> | <a href="#con-subnormal">SUBNORMAL</a>
  datatype <a href="#type-rounding_mode">rounding_mode</a> = <a href="#con-to_nearest">TO_NEAREST</a> | <a href="#con-to_neginf">TO_NEGINF</a> | <a href="#con-to_posinf">TO_POSINF</a> | <a href="#con-to_zero">TO_ZERO</a>
  val <a href="#val-setroundingmode">setRoundingMode</a> : rounding_mode -&gt; unit
  val <a href="#val-getroundingmode">getRoundingMode</a> : unit -&gt; rounding_mode
  type <a href="#type-decimal_approx">decimal_approx</a> = {<a href="#fld-decimal_approx.class">class</a> : float_class, <a href="#fld-decimal_approx.sign">sign</a> : bool, <a href="#fld-decimal_approx.digits">digits</a> : int list, <a href="#fld-decimal_approx.exp">exp</a> : int}
  val <a href="#val-tostring">toString</a> : decimal_approx -&gt; string
  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (decimal_approx, 'a) StringCvt.reader
  val <a href="#val-fromstring">fromString</a> : string -&gt; decimal_approx option
end
</pre>

### <a name="exn-unordered"></a>`Unordered`

```sml
exception Unordered
```

<details><summary>Tests (1)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `raised-by-Real.compare` (raises)

</details>

### <a name="type-real_order"></a>`real_order`

```sml
datatype real_order = LESS | EQUAL | GREATER | UNORDERED
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-less"></a>`LESS` |  |  |
| <a name="con-equal"></a>`EQUAL` |  |  |
| <a name="con-greater"></a>`GREATER` |  |  |
| <a name="con-unordered"></a>`UNORDERED` |  |  |

### <a name="type-float_class"></a>`float_class`

```sml
datatype float_class = NAN | INF | ZERO | NORMAL | SUBNORMAL
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-nan"></a>`NAN` |  |  |
| <a name="con-inf"></a>`INF` |  |  |
| <a name="con-zero"></a>`ZERO` |  |  |
| <a name="con-normal"></a>`NORMAL` |  |  |
| <a name="con-subnormal"></a>`SUBNORMAL` |  |  |

### <a name="type-rounding_mode"></a>`rounding_mode`

```sml
datatype rounding_mode = TO_NEAREST | TO_NEGINF | TO_POSINF | TO_ZERO
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-to_nearest"></a>`TO_NEAREST` |  |  |
| <a name="con-to_neginf"></a>`TO_NEGINF` |  |  |
| <a name="con-to_posinf"></a>`TO_POSINF` |  |  |
| <a name="con-to_zero"></a>`TO_ZERO` |  |  |

### <a name="val-setroundingmode"></a>`setRoundingMode`

```sml
val setRoundingMode : rounding_mode -> unit
```

<details><summary>Tests (4)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `then-get-*` &middot; `up-is-above-down` &middot; `zero-is-down-for-positive` &middot; `nearest-is-one-of-them`

</details>

### <a name="val-getroundingmode"></a>`getRoundingMode`

```sml
val getRoundingMode : unit -> rounding_mode
```

<details><summary>Tests (2)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `default` &middot; `restored`

</details>

### <a name="type-decimal_approx"></a>`decimal_approx`

```sml
type decimal_approx = {class : float_class, sign : bool, digits : int list, exp : int}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-decimal_approx.class"></a>`class` | `float_class` |  |
| <a name="fld-decimal_approx.sign"></a>`sign` | `bool` |  |
| <a name="fld-decimal_approx.digits"></a>`digits` | `int list` |  |
| <a name="fld-decimal_approx.exp"></a>`exp` | `int` |  |

### <a name="val-tostring"></a>`toString`

```sml
val toString : decimal_approx -> string
```

<details><summary>Tests (15)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `zero` &middot; `negative-zero` &middot; `zero-ignores-digits-and-exp` &middot; `normal` &middot; `normal-exp` &middot; `normal-negative-exp` &middot; `normal-negative` &middot; `subnormal` &middot; `inf` &middot; `negative-inf` &middot; `inf-ignores-exp` &middot; `nan` &middot; `negative-nan` &middot; `of-toDecimal` &middot; `is-fmt-EXACT`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (decimal_approx, 'a) StringCvt.reader
```

<details><summary>Tests (8)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `rest` &middot; `incomplete-exponent` &middot; `incomplete-exponent-sign` &middot; `point-without-fraction` &middot; `second-point` &middot; `inf-then-letters` &middot; `whitespace` &middot; `NONE`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> decimal_approx option
```

<details><summary>Tests (18)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `integer-and-fraction` &middot; `integer` &middot; `leading-zeros` &middot; `small-fraction` &middot; `point-first` &middot; `trailing-zeros` &middot; `exponent` &middot; `negative-exponent` &middot; `plus-signs` &middot; `zero` &middot; `zero-with-exponent` &middot; `inf` &middot; `infinity-any-case` &middot; `nan` &middot; `NONE-letters` &middot; `NONE-empty` &middot; `NONE-bare-point` &middot; `NONE-sign-only`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_ieee\_real.sml; do not edit.</sub>
