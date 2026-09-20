# signature IEEE_REAL

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **IEEE_REAL**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | 50 checks of 6 entries |
| Source | [lib/basis/sig\_ieee\_real.sml](../../../../lib/basis/sig_ieee_real.sml) |

## Synopsis

```sml
signature IEEE_REAL
structure IEEEReal : IEEE_REAL  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `IEEEReal` | IEEEReal: the types of IEEE arithmetic that do not depend on a precision. | [lib/basis/ieeereal.sml](../../../../lib/basis/ieeereal.sml) |

The parts of IEEE 754 arithmetic that are not about one real number: the
rounding mode, the classes a number can belong to, and an exact decimal
form to convert through.

[`REAL`](../sig/REAL.md) has everything that computes with reals; what is here is the state
of the floating-point unit, and the type [`decimal_approx`](#type-decimal_approx), which is a
number written out in decimal digits and so can be converted to and from
text without losing anything.

## Interface

<pre>
signature IEEE_REAL =
sig
  exception <a href="#exn-unordered">Unordered</a>

  datatype <a href="#type-real_order">real_order</a> = <a href="#con-less">LESS</a> | <a href="#con-equal">EQUAL</a> | <a href="#con-greater">GREATER</a> | <a href="#con-unordered">UNORDERED</a>

  datatype <a href="#type-float_class">float_class</a>
    = <a href="#con-nan">NAN</a>
    | <a href="#con-inf">INF</a>
    | <a href="#con-zero">ZERO</a>
    | <a href="#con-normal">NORMAL</a>
    | <a href="#con-subnormal">SUBNORMAL</a>

  datatype <a href="#type-rounding_mode">rounding_mode</a>
    = <a href="#con-to_nearest">TO_NEAREST</a>
    | <a href="#con-to_neginf">TO_NEGINF</a>
    | <a href="#con-to_posinf">TO_POSINF</a>
    | <a href="#con-to_zero">TO_ZERO</a>

  val <a href="#val-setroundingmode">setRoundingMode</a> : rounding_mode -&gt; unit

  val <a href="#val-getroundingmode">getRoundingMode</a> : unit -&gt; rounding_mode

  type <a href="#type-decimal_approx">decimal_approx</a> = {<a href="#fld-decimal_approx.class">class</a> : float_class,
                         <a href="#fld-decimal_approx.sign">sign</a> : bool,
                         <a href="#fld-decimal_approx.digits">digits</a> : int list,
                         <a href="#fld-decimal_approx.exp">exp</a> : int}

  val <a href="#val-tostring">toString</a> : decimal_approx -&gt; string

  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (decimal_approx, 'a) StringCvt.reader

  val <a href="#val-fromstring">fromString</a> : string -&gt; decimal_approx option
end
</pre>

### <a name="exn-unordered"></a>`Unordered`

```sml
exception Unordered
```

Raised by [`Real.compare`](../sig/REAL.md#val-compare) when one of its arguments is a NaN, which no
order relates to anything. It is the top-level [`Unordered`](#exn-unordered).

Also in the [top-level environment](../top-level.md): `Unordered`.

<details><summary>Tests (3)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `raised-by-Real.compare` (raises) &middot; `same-as-toplevel` (raises) &middot; `toplevel-handled-by-IEEEReal` (raises)

</details>

### <a name="type-real_order"></a>`real_order`

```sml
datatype real_order = LESS | EQUAL | GREATER | UNORDERED
```

How two reals compare, with a fourth answer for the pairs that no order relates.

[`Real.compareReal`](../sig/REAL.md#val-comparereal) gives it; [`Real.compare`](../sig/REAL.md#val-compare) raises [`Unordered`](#exn-unordered) instead.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-less"></a>`LESS` |  |  |
| <a name="con-equal"></a>`EQUAL` |  |  |
| <a name="con-greater"></a>`GREATER` |  |  |
| <a name="con-unordered"></a>`UNORDERED` |  |  |

### <a name="type-float_class"></a>`float_class`

```sml
datatype float_class
  = NAN
  | INF
  | ZERO
  | NORMAL
  | SUBNORMAL
```

What kind of number a real is.

Every real is of exactly one class, which [`Real.class`](../sig/REAL.md#val-class) gives.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-nan"></a>`NAN` |  | not a number: the result of 0.0/0.0 and its like |
| <a name="con-inf"></a>`INF` |  | an infinity, of either sign |
| <a name="con-zero"></a>`ZERO` |  | a zero, of either sign |
| <a name="con-normal"></a>`NORMAL` |  | an ordinary number |
| <a name="con-subnormal"></a>`SUBNORMAL` |  | a number too small to be normal, with fewer digits of precision |

### <a name="type-rounding_mode"></a>`rounding_mode`

```sml
datatype rounding_mode
  = TO_NEAREST
  | TO_NEGINF
  | TO_POSINF
  | TO_ZERO
```

Where a result that is not exact is rounded to.

[`TO_NEAREST`](#con-to_nearest) is what a program gets unless it asks for another, and
under it a result exactly between two reals goes to the one whose last
digit is even.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-to_nearest"></a>`TO_NEAREST` |  | to the nearest, ties to even |
| <a name="con-to_neginf"></a>`TO_NEGINF` |  | down |
| <a name="con-to_posinf"></a>`TO_POSINF` |  | up |
| <a name="con-to_zero"></a>`TO_ZERO` |  | towards zero: the result is truncated |

### <a name="val-setroundingmode"></a>`setRoundingMode`

```sml
val setRoundingMode : rounding_mode -> unit
```

`setRoundingMode m` makes `m` the rounding mode of what follows.

It changes the state of the floating-point unit, so it holds for every
operation until it is set again.

> **Implementation** `IEEEReal.setRoundingMode/fesetround`. The mode of the C
> library, set with `fesetround`.

<details><summary>Tests (4)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `then-get-*` &middot; `up-is-above-down` &middot; `zero-is-down-for-positive` &middot; `nearest-is-one-of-them`

</details>

### <a name="val-getroundingmode"></a>`getRoundingMode`

```sml
val getRoundingMode : unit -> rounding_mode
```

`getRoundingMode ()` is the rounding mode in force.

<details><summary>Tests (2)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `default` &middot; `restored`

</details>

### <a name="type-decimal_approx"></a>`decimal_approx`

```sml
type decimal_approx = {class : float_class,
                       sign : bool,
                       digits : int list,
                       exp : int}
```

A real written out in decimal: the sign, the digits and the exponent.

The number is `0.d1d2...dn` times `10^exp`, negated when `sign` is
`true`, so the point stands before the first digit. For a `class` of
[`ZERO`](#con-zero), [`INF`](#con-inf) or [`NAN`](#con-nan) the digits and the exponent say nothing.

the power of ten to multiply by

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-decimal_approx.class"></a>`class` | `float_class` | which kind of number it is |
| <a name="fld-decimal_approx.sign"></a>`sign` | `bool` | true for a negative number, a negative zero included |
| <a name="fld-decimal_approx.digits"></a>`digits` | `int list` | the digits after the point, each from 0 to 9 |
| <a name="fld-decimal_approx.exp"></a>`exp` | `int` |  |

### <a name="val-tostring"></a>`toString`

```sml
val toString : decimal_approx -> string
```

`toString d` is the text of `d`: `[~]0.d1d2...dnE[~]exp`.

A zero is written `0.0`, an infinity `inf` and a NaN `nan`, each with a
`~` before it when the sign is set, and the exponent is left out when it
is zero.

**Example** `toString {class = NORMAL, sign = false, digits = [1, 5], exp = 1} = "0.15E1"`

<details><summary>Tests (15)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `zero` &middot; `negative-zero` &middot; `zero-ignores-digits-and-exp` &middot; `normal` &middot; `normal-exp` &middot; `normal-negative-exp` &middot; `normal-negative` &middot; `subnormal` &middot; `inf` &middot; `negative-inf` &middot; `inf-ignores-exp` &middot; `nan` &middot; `negative-nan` &middot; `of-toDecimal` &middot; `is-fmt-EXACT`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (decimal_approx, 'a) StringCvt.reader
```

`scan getc strm` reads a decimal number, an infinity or a NaN from `strm`.

It skips initial white space and then takes an optional sign (`~`, `-`
or `+`) and either digits with an optional point and an optional
exponent (`1.5`, `.5`, `15E~1`), or one of the words `inf`, `infinity`
and `nan` in any mixture of upper and lower case. Every digit that is
there is kept, however many.

> **Reading** `IEEEReal.scan/huge-exponent`. An exponent whose digits name a
> number too large for an `int` is taken as the largest `int` rather than
> raising [`Overflow`](../sig/GENERAL.md#exn-overflow): the number it describes is beyond every real
> anyway.

<details><summary>Tests (8)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `rest` &middot; `incomplete-exponent` &middot; `incomplete-exponent-sign` &middot; `point-without-fraction` &middot; `second-point` &middot; `inf-then-letters` &middot; `whitespace` &middot; `NONE`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> decimal_approx option
```

`fromString s` is the decimal number that the text `s` begins with, or `NONE`.

**Law** `fromString s = StringCvt.scanString scan s`

<details><summary>Tests (18)</summary>

For `IEEEReal`, in [tests/basis/ieeereal.sml](../../../../tests/basis/ieeereal.sml): `integer-and-fraction` &middot; `integer` &middot; `leading-zeros` &middot; `small-fraction` &middot; `point-first` &middot; `trailing-zeros` &middot; `exponent` &middot; `negative-exponent` &middot; `plus-signs` &middot; `zero` &middot; `zero-with-exponent` &middot; `inf` &middot; `infinity-any-case` &middot; `nan` &middot; `NONE-letters` &middot; `NONE-empty` &middot; `NONE-bare-point` &middot; `NONE-sign-only`

</details>

## See also

[`REAL`](../sig/REAL.md), [`MATH`](../sig/MATH.md), [`STRING_CVT`](../sig/STRING_CVT.md)

---

<sub>Generated by runedoc from lib/basis/sig\_ieee\_real.sml; do not edit.</sub>
