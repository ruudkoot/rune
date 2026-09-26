# signature GENERAL

[The Standard ML Basis Library](../README.md) &rsaquo; The language &rsaquo; **GENERAL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 20 of 20 entries documented |
| Tests | 133 checks of 20 entries |
| Source | [lib/basis/sig\_general.sml](../../../../lib/basis/sig_general.sml) |

## Synopsis

```sml
signature GENERAL
structure General : GENERAL
```

| Implementation |  | Source |
| --- | --- | --- |
| [`General`](../str/General.md) | General: the exceptions and combinators of the initial basis as a structure. | [lib/basis/general.sml](../../../../lib/basis/general.sml) |

The types, exceptions and values of the top-level environment that belong
to no other structure.

Everything [`General`](../str/General.md) specifies is also available without a structure in
front, and [`General`](../str/General.md) is the one structure whose members the language itself
uses: `raise Bind` is what a `val` binding does when its pattern does not
match, [`Div`](#exn-div) is what division by zero raises. The exceptions here are those
the specification calls the standard ones; an implementation may raise them
from anywhere its description says it may.

## Contents

[Types](#types) &middot;
[The standard exceptions](#the-standard-exceptions) &middot;
[Naming an exception](#naming-an-exception) &middot;
[Comparison](#comparison) &middot;
[Operators](#operators)

## Interface

<pre>
signature GENERAL =
sig
  eqtype <a href="#type-unit">unit</a>
  type <a href="#type-exn">exn</a> = exn
  exception <a href="#exn-bind">Bind</a>
  exception <a href="#exn-match">Match</a>
  exception <a href="#exn-chr">Chr</a>
  exception <a href="#exn-div">Div</a>
  exception <a href="#exn-domain">Domain</a>
  exception <a href="#exn-fail">Fail</a> of string
  exception <a href="#exn-overflow">Overflow</a>
  exception <a href="#exn-size">Size</a>
  exception <a href="#exn-span">Span</a>
  exception <a href="#exn-subscript">Subscript</a>
  val <a href="#val-exnname">exnName</a> : exn -&gt; string
  val <a href="#val-exnmessage">exnMessage</a> : exn -&gt; string
  datatype <a href="#type-order">order</a> = <a href="#con-less">LESS</a> | <a href="#con-equal">EQUAL</a> | <a href="#con-greater">GREATER</a>
  val <a href="#val-op-bang">!</a> : 'a ref -&gt; 'a
  val <a href="#val-op-colon-eq">:=</a> : 'a ref * 'a -&gt; unit
  val <a href="#val-o">o</a> : ('b -&gt; 'c) * ('a -&gt; 'b) -&gt; 'a -&gt; 'c
  val <a href="#val-before">before</a> : 'a * unit -&gt; 'a
  val <a href="#val-ignore">ignore</a> : 'a -&gt; unit
end
</pre>

## Types

### <a name="type-unit"></a>`unit`

```sml
eqtype unit
```

The type with one value, the empty tuple `()`, which is what a function
that is called for its effect returns.

<details><summary>Tests (2)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `eqtype` &middot; `same-as-toplevel`

</details>

### <a name="type-exn"></a>`exn`

```sml
type exn = exn
```

The type of exception values, the top-level [`exn`](#type-exn).

An exception declaration adds a constructor to it, so the type is open:
it grows as a program declares exceptions, and a value of it cannot be
taken apart except by a pattern that names a constructor. It does not
admit equality.

> **Erratum** `GENERAL/exn-spec`. The specification writes `type exn = exn`,
> which is read as: the type of this structure is the top-level one.

<details><summary>Tests (2)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `extensible` &middot; `same-as-toplevel`

</details>

## The standard exceptions

### <a name="exn-bind"></a>`Bind`

```sml
exception Bind
```

Raised when the pattern of a `val` binding does not match the value.

Also in the [top-level environment](../top-level.md): `Bind`.

<details><summary>Tests (2)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `General-handles-toplevel` (raises)

</details>

### <a name="exn-match"></a>`Match`

```sml
exception Match
```

Raised when no rule of a `case`, a `fn` or a `handle` matches.

Also in the [top-level environment](../top-level.md): `Match`.

<details><summary>Tests (2)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `General-handles-toplevel` (raises)

</details>

### <a name="exn-chr"></a>`Chr`

```sml
exception Chr
```

Raised by [`Char.chr`](../sig/CHAR.md#val-chr), [`Char.succ`](../sig/CHAR.md#val-succ) and [`Char.pred`](../sig/CHAR.md#val-pred) for a code that is no
character.

Also in the [top-level environment](../top-level.md): `Chr`.

<details><summary>Tests (4)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `chr-negative` (raises) &middot; `chr-above-maxOrd` (raises Chr) &middot; `succ-maxChar` (raises Chr)

</details>

### <a name="exn-div"></a>`Div`

```sml
exception Div
```

Raised by `div`, `mod`, `quot` and `rem` when the divisor is zero.

Also in the [top-level environment](../top-level.md): `Div`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; compiler bug: \`case General.Fail "v" of Fail s =\> s \| \_ =\> ...\` takes the default rule when the value is built and matched in one compilation unit under two names of the same exception

</details>

<details><summary>Tests (7)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `div` (raises) &middot; `mod` (raises Div) &middot; `quot` (raises Div) &middot; `rem` (raises Div) &middot; `zero-by-zero` (raises Div) &middot; `as-value`

</details>

### <a name="exn-domain"></a>`Domain`

```sml
exception Domain
```

Raised by a function that is given an argument outside its domain, such
as [`Real.floor`](../sig/REAL.md#val-floor) of a NaN or [`IntInf.log2`](../sig/INT_INF.md#val-log2) of a number that is not
positive.

> **Erratum** `GENERAL/domain-math`. The specification says that the functions
> of [`MATH`](../sig/MATH.md) raise it. They do not: a mathematical function answers with a
> NaN or an infinity instead, and it is [`REAL`](../sig/REAL.md) and [`INT_INF`](../sig/INT_INF.md) that raise
> [`Domain`](#exn-domain).

Also in the [top-level environment](../top-level.md): `Domain`.

<details><summary>Tests (9)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `General-handles-toplevel` (raises) &middot; `Real.floor-nan` (raises) &middot; `Real.ceil-nan` (raises Domain) &middot; `Real.trunc-nan` (raises Domain) &middot; `Real.round-nan` (raises Domain) &middot; `Real.sign-nan` (raises Domain) &middot; `IntInf.log2-zero` (raises Domain) &middot; `IntInf.log2-negative` (raises Domain)

</details>

### <a name="exn-fail"></a>`Fail`

```sml
exception Fail of string
```

Raised where a program has nothing better to raise; its argument says
what went wrong.

Also in the [top-level environment](../top-level.md): `Fail`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; compiler bug: \`case General.Fail "v" of Fail s =\> s \| \_ =\> ...\` takes the default rule when the value is built and matched in one compilation unit under two names of the same exception

</details>

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `carries-string` &middot; `empty-string` &middot; `General-handles-toplevel` &middot; `as-value` &middot; `law-*`

</details>

### <a name="exn-overflow"></a>`Overflow`

```sml
exception Overflow
```

Raised by an arithmetic operation whose result is not representable, such
as [`Int.+`](../sig/INTEGER.md#val-op-plus) beyond [`Int.maxInt`](../sig/INTEGER.md#val-maxint).

> **Implementation** `General.Overflow/bounded-int`. Whether an operation can
> overflow depends on the precision of the type: nothing overflows at
> [`IntInf.int`](../sig/INTEGER.md#type-int), which has none.

Also in the [top-level environment](../top-level.md): `Overflow`.

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `maxInt-plus-one` (raises) &middot; `minInt-minus-one` (raises Overflow) &middot; `maxInt-times-two` (raises Overflow) &middot; `maxInt-minus-minInt` (raises Overflow) &middot; `maxInt-itself-is-fine`

</details>

### <a name="exn-size"></a>`Size`

```sml
exception Size
```

Raised by an operation that would make a string, a vector or an array
longer than the implementation allows, such as [`Array.array`](../sig/ARRAY.md#val-array) of a length
above [`Array.maxLen`](../sig/ARRAY.md#val-maxlen).

> **Implementation** `General.Size/maxLen`. What is too large depends on the
> type: [`String.maxSize`](../sig/STRING.md#val-maxsize) and [`Array.maxLen`](../sig/ARRAY.md#val-maxlen) say where the bound is.

Where `Array.maxLen + 1` is no `int` nothing can ask for an array that is
too long, and the suite's check raises [`Size`](#exn-size) itself there; here it is an
`int`, and [`Array.array`](../sig/ARRAY.md#val-array) raises it.

Also in the [top-level environment](../top-level.md): `Size`.

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `List.tabulate-negative` (raises) &middot; `Array.array-negative` (raises Size) &middot; `Array.tabulate-negative` (raises Size) &middot; `Vector.tabulate-negative` (raises Size) &middot; `Array.array-above-maxLen` (raises Size)

</details>

### <a name="exn-span"></a>`Span`

```sml
exception Span
```

Raised by [`Substring.span`](../sig/SUBSTRING.md#val-span) when its two arguments are not substrings of
one string, or lie the wrong way round.

Also in the [top-level environment](../top-level.md): `Span`.

<details><summary>Tests (4)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `General-handles-toplevel` (raises) &middot; `Substring.span-different-strings` (raises) &middot; `Substring.span-start-right-of-end` (raises Span)

</details>

### <a name="exn-subscript"></a>`Subscript`

```sml
exception Subscript
```

Raised by an operation that is given an index or a length outside what
the sequence has, such as [`String.sub`](../sig/STRING.md#val-sub) or [`List.nth`](../sig/LIST.md#val-nth).

Also in the [top-level environment](../top-level.md): `Subscript`.

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `List.nth` (raises) &middot; `String.sub` (raises Subscript) &middot; `String.sub-negative` (raises Subscript) &middot; `Array.sub` (raises Subscript) &middot; `Vector.sub` (raises Subscript)

</details>

## Naming an exception

### <a name="val-exnname"></a>`exnName`

```sml
val exnName : exn -> string
```

`exnName ex` is the name of the constructor of `ex`, without a structure
in front and without its argument.

**Example** `exnName (Fail "why") = "Fail"`, and `exnName Subscript = "Subscript"`.

> **Reading** `General.exnName/alias-either-name`. For an exception declared
> to be another one (`exception E2 = E1`) either name is an answer: the two
> constructors are the same exception, and which name the implementation
> kept is its own business.

Also in the [top-level environment](../top-level.md): `exnName`.

<details><summary>Tests (13)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `toplevel` &middot; `Fail-ignores-argument` &middot; `raised-Div` &middot; `raised-Chr` &middot; `raised-Subscript` &middot; `raised-Size` &middot; `raised-Overflow` &middot; `raised-Domain` &middot; `user` &middot; `user-with-argument` &middot; `alias-either-name` &middot; `alias-of-standard`

</details>

### <a name="val-exnmessage"></a>`exnMessage`

```sml
val exnMessage : exn -> string
```

`exnMessage ex` is a message that describes `ex`, for a program that
reports an exception it cannot handle.

> **Reading** `General.exnMessage/returns-*`. "The precise format of the
> message may vary between implementations and locales", so only this is
> required of it: it returns rather than raising, and it contains
> `exnName ex`.

> **Erratum** `GENERAL/exnMessage-example`. The specification's example
> `exnMessage Div = "Div"` contradicts that freedom; it is an example of
> one possible format, not a rule.

> **Implementation** `General.exnMessage/format`. `"Fail: "` and the argument
> for a [`Fail`](#exn-fail), and `exnName ex` for everything else.

**Example** `exnMessage (Fail "why") = "Fail: why"`

Also in the [top-level environment](../top-level.md): `exnMessage`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; exnMessage of Bind, Match, Div, Domain, Overflow, Size and Subscript is a phrase ("divide by zero", "subscript out of bounds", ...) that does not contain exnName ex

</details>

<details><summary>Tests (8)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `returns-*` &middot; `toplevel` &middot; `user` &middot; `raised-Div` &middot; `contains-exnName-*` &middot; `contains-exnName-user` &middot; `contains-exnName-raised-Div` &middot; `contains-exnName-raised-Subscript`

</details>

## Comparison

### <a name="type-order"></a>`order`

```sml
datatype order = LESS | EQUAL | GREATER
```

What a comparison answers: the result of [`Int.compare`](../sig/INTEGER.md#val-compare), [`String.compare`](../sig/STRING.md#val-compare)
and every other `compare` and `collate` of the library. It is the
top-level [`order`](#type-order).

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-less"></a>`LESS` |  |  |
| <a name="con-equal"></a>`EQUAL` |  |  |
| <a name="con-greater"></a>`GREATER` |  |  |

Also in the [top-level environment](../top-level.md): `order`.

<details><summary>Tests (3)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `case` &middot; `distinct` &middot; `equality`

</details>

## Operators

### <a name="val-op-bang"></a>`!`

```sml
val ! : 'a ref -> 'a
```

`!r` is the value that the reference `r` holds.

Also in the [top-level environment](../top-level.md): `!`.

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `initial` &middot; `toplevel` &middot; `string` &middot; `list` &middot; `ref-of-ref` &middot; `does-not-change`

</details>

### <a name="val-op-colon-eq"></a>`:=`

```sml
val := : 'a ref * 'a -> unit
```

`r := v` makes the reference `r` hold `v`.

It is infix with precedence 3.

Also in the [top-level environment](../top-level.md): `:=`.

<details><summary>Tests (13)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `basic` &middot; `toplevel-infix` &middot; `returns-unit` &middot; `last-assignment-wins` &middot; `same-ref-two-names` &middot; `distinct-refs` &middot; `self-reference` &middot; `function` &middot; `ref-of-ref` &middot; `closure-shares-ref` &middot; `infix-below-plus` &middot; `then-deref-*` &middot; `series-*`

</details>

### <a name="val-o"></a>`o`

```sml
val o : ('b -> 'c) * ('a -> 'b) -> 'a -> 'c
```

`(f o g) x` is `f (g x)`: the composition of two functions.

It is infix with precedence 3.

**Example** `(Int.toString o (fn x => x + 1)) 1 = "2"`

Also in the [top-level environment](../top-level.md): `o`.

<details><summary>Tests (16)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `basic` &middot; `toplevel-infix` &middot; `three-types` &middot; `three-types-int-string-int` &middot; `chain` &middot; `g-then-f` &middot; `composing-applies-nothing` &middot; `each-application-applies-both` &middot; `exception-of-g` (raises Fail) &middot; `f-not-applied-when-g-raises` &middot; `exception-of-f` (raises Subscript) &middot; `definition-*` &middot; `associative-left-*` &middot; `associative-right-*` &middot; `identity-right-*` &middot; `identity-left-*`

</details>

### <a name="val-before"></a>`before`

```sml
val before : 'a * unit -> 'a
```

`e before e'` is `e`, after `e'` has been evaluated for its effect.

It is infix with precedence 0, the loosest there is, so that
`x before print "done"` needs no parentheses.

**Law** `e before e' = (fn (a, ()) => a) (e, e')`

**Example** `(1 before ()) = 1`

Also in the [top-level environment](../top-level.md): `before`.

<details><summary>Tests (11)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `returns-first` &middot; `toplevel-infix` &middot; `string` &middot; `a-then-b` &middot; `value-of-a-before-b-runs` &middot; `b-has-run` &middot; `exception-of-b` (raises Fail) &middot; `b-not-evaluated-when-a-raises` &middot; `infix-below-assign` &middot; `chain` &middot; `law-*`

</details>

### <a name="val-ignore"></a>`ignore`

```sml
val ignore : 'a -> unit
```

`ignore e` is `()`: it throws the value of `e` away.

A statement whose value is not [`unit`](#type-unit) is a warning in some compilers and
a mistake in most programs; [`ignore`](#val-ignore) says that this one is meant.

Also in the [top-level environment](../top-level.md): `ignore`.

<details><summary>Tests (7)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `int` &middot; `toplevel` &middot; `function` &middot; `argument-is-evaluated` &middot; `exception-of-argument` (raises Div) &middot; `with-List.app` &middot; `law-*`

</details>

## See also

[`OPTION`](../sig/OPTION.md), [`LIST`](../sig/LIST.md), [`STRING`](../sig/STRING.md)

---

<sub>Generated by runedoc from lib/basis/sig\_general.sml; do not edit.</sub>
