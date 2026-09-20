# signature GENERAL

[The Standard ML Basis Library](../README.md) &rsaquo; **GENERAL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 20 entries documented |
| Tests | 133 checks of 20 entries |
| Source | [lib/basis/sig\_general.sml](../../../../lib/basis/sig_general.sml) |

## Synopsis

```sml
signature GENERAL
structure General : GENERAL
```

| Implementation |  | Source |
| --- | --- | --- |
| `General` | General: the exceptions and combinators of the initial basis as a structure. | [lib/basis/general.sml](../../../../lib/basis/general.sml) |

signature GENERAL, transcribed from <https://smlfamily.github.io/Basis/general.html>

The page specifies `type exn = exn`; here that equates General.exn with the
top-level exn, which is what the page means ("All of the types and values
defined in General are available unqualified at the top-level").

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

### <a name="type-unit"></a>`unit`

```sml
eqtype unit
```

<details><summary>Tests (2)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `eqtype` &middot; `same-as-toplevel`

</details>

### <a name="type-exn"></a>`exn`

```sml
type exn = exn
```

<details><summary>Tests (2)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `extensible` &middot; `same-as-toplevel`

</details>

### <a name="exn-bind"></a>`Bind`

```sml
exception Bind
```

Also in the [top-level environment](../top-level.md): `Bind`.

<details><summary>Tests (2)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `General-handles-toplevel` (raises)

</details>

### <a name="exn-match"></a>`Match`

```sml
exception Match
```

Also in the [top-level environment](../top-level.md): `Match`.

<details><summary>Tests (2)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `General-handles-toplevel` (raises)

</details>

### <a name="exn-chr"></a>`Chr`

```sml
exception Chr
```

Also in the [top-level environment](../top-level.md): `Chr`.

<details><summary>Tests (4)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `chr-negative` (raises) &middot; `chr-above-maxOrd` (raises Chr) &middot; `succ-maxChar` (raises Chr)

</details>

### <a name="exn-div"></a>`Div`

```sml
exception Div
```

Also in the [top-level environment](../top-level.md): `Div`.

<details><summary>Tests (7)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `div` (raises) &middot; `mod` (raises Div) &middot; `quot` (raises Div) &middot; `rem` (raises Div) &middot; `zero-by-zero` (raises Div) &middot; `as-value`

</details>

### <a name="exn-domain"></a>`Domain`

```sml
exception Domain
```

Also in the [top-level environment](../top-level.md): `Domain`.

<details><summary>Tests (9)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `General-handles-toplevel` (raises) &middot; `Real.floor-nan` (raises) &middot; `Real.ceil-nan` (raises Domain) &middot; `Real.trunc-nan` (raises Domain) &middot; `Real.round-nan` (raises Domain) &middot; `Real.sign-nan` (raises Domain) &middot; `IntInf.log2-zero` (raises Domain) &middot; `IntInf.log2-negative` (raises Domain)

</details>

### <a name="exn-fail"></a>`Fail`

```sml
exception Fail of string
```

Also in the [top-level environment](../top-level.md): `Fail`.

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `carries-string` &middot; `empty-string` &middot; `General-handles-toplevel` &middot; `as-value` &middot; `law-*`

</details>

### <a name="exn-overflow"></a>`Overflow`

```sml
exception Overflow
```

Also in the [top-level environment](../top-level.md): `Overflow`.

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `maxInt-plus-one` (raises) &middot; `minInt-minus-one` (raises Overflow) &middot; `maxInt-times-two` (raises Overflow) &middot; `maxInt-minus-minInt` (raises Overflow) &middot; `maxInt-itself-is-fine`

</details>

### <a name="exn-size"></a>`Size`

```sml
exception Size
```

Also in the [top-level environment](../top-level.md): `Size`.

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `List.tabulate-negative` (raises) &middot; `Array.array-negative` (raises Size) &middot; `Array.tabulate-negative` (raises Size) &middot; `Vector.tabulate-negative` (raises Size) &middot; `Array.array-above-maxLen` (raises Size)

</details>

### <a name="exn-span"></a>`Span`

```sml
exception Span
```

Also in the [top-level environment](../top-level.md): `Span`.

<details><summary>Tests (4)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `General-handles-toplevel` (raises) &middot; `Substring.span-different-strings` (raises) &middot; `Substring.span-start-right-of-end` (raises Span)

</details>

### <a name="exn-subscript"></a>`Subscript`

```sml
exception Subscript
```

Also in the [top-level environment](../top-level.md): `Subscript`.

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `List.nth` (raises) &middot; `String.sub` (raises Subscript) &middot; `String.sub-negative` (raises Subscript) &middot; `Array.sub` (raises Subscript) &middot; `Vector.sub` (raises Subscript)

</details>

### <a name="val-exnname"></a>`exnName`

```sml
val exnName : exn -> string
```

Also in the [top-level environment](../top-level.md): `exnName`.

<details><summary>Tests (13)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `*` &middot; `toplevel` &middot; `Fail-ignores-argument` &middot; `raised-Div` &middot; `raised-Chr` &middot; `raised-Subscript` &middot; `raised-Size` &middot; `raised-Overflow` &middot; `raised-Domain` &middot; `user` &middot; `user-with-argument` &middot; `alias-either-name` &middot; `alias-of-standard`

</details>

### <a name="val-exnmessage"></a>`exnMessage`

```sml
val exnMessage : exn -> string
```

Also in the [top-level environment](../top-level.md): `exnMessage`.

<details><summary>Tests (8)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `returns-*` &middot; `toplevel` &middot; `user` &middot; `raised-Div` &middot; `contains-exnName-*` &middot; `contains-exnName-user` &middot; `contains-exnName-raised-Div` &middot; `contains-exnName-raised-Subscript`

</details>

### <a name="type-order"></a>`order`

```sml
datatype order = LESS | EQUAL | GREATER
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-less"></a>`LESS` |  |  |
| <a name="con-equal"></a>`EQUAL` |  |  |
| <a name="con-greater"></a>`GREATER` |  |  |

Also in the [top-level environment](../top-level.md): `order`.

<details><summary>Tests (3)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `case` &middot; `distinct` &middot; `equality`

</details>

### <a name="val-op-bang"></a>`!`

```sml
val ! : 'a ref -> 'a
```

Also in the [top-level environment](../top-level.md): `!`.

<details><summary>Tests (6)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `initial` &middot; `toplevel` &middot; `string` &middot; `list` &middot; `ref-of-ref` &middot; `does-not-change`

</details>

### <a name="val-op-colon-eq"></a>`:=`

```sml
val := : 'a ref * 'a -> unit
```

Also in the [top-level environment](../top-level.md): `:=`.

<details><summary>Tests (13)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `basic` &middot; `toplevel-infix` &middot; `returns-unit` &middot; `last-assignment-wins` &middot; `same-ref-two-names` &middot; `distinct-refs` &middot; `self-reference` &middot; `function` &middot; `ref-of-ref` &middot; `closure-shares-ref` &middot; `infix-below-plus` &middot; `then-deref-*` &middot; `series-*`

</details>

### <a name="val-o"></a>`o`

```sml
val o : ('b -> 'c) * ('a -> 'b) -> 'a -> 'c
```

Also in the [top-level environment](../top-level.md): `o`.

<details><summary>Tests (16)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `basic` &middot; `toplevel-infix` &middot; `three-types` &middot; `three-types-int-string-int` &middot; `chain` &middot; `g-then-f` &middot; `composing-applies-nothing` &middot; `each-application-applies-both` &middot; `exception-of-g` (raises Fail) &middot; `f-not-applied-when-g-raises` &middot; `exception-of-f` (raises Subscript) &middot; `definition-*` &middot; `associative-left-*` &middot; `associative-right-*` &middot; `identity-right-*` &middot; `identity-left-*`

</details>

### <a name="val-before"></a>`before`

```sml
val before : 'a * unit -> 'a
```

Also in the [top-level environment](../top-level.md): `before`.

<details><summary>Tests (11)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `returns-first` &middot; `toplevel-infix` &middot; `string` &middot; `a-then-b` &middot; `value-of-a-before-b-runs` &middot; `b-has-run` &middot; `exception-of-b` (raises Fail) &middot; `b-not-evaluated-when-a-raises` &middot; `infix-below-assign` &middot; `chain` &middot; `law-*`

</details>

### <a name="val-ignore"></a>`ignore`

```sml
val ignore : 'a -> unit
```

Also in the [top-level environment](../top-level.md): `ignore`.

<details><summary>Tests (7)</summary>

For `General`, in [tests/basis/general.sml](../../../../tests/basis/general.sml): `int` &middot; `toplevel` &middot; `function` &middot; `argument-is-evaluated` &middot; `exception-of-argument` (raises Div) &middot; `with-List.app` &middot; `law-*`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_general.sml; do not edit.</sub>
