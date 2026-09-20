# signature OPTION

[The Standard ML Basis Library](../README.md) &rsaquo; Lists and options &rsaquo; **OPTION**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 12 of 12 entries documented |
| Tests | 92 checks of 12 entries |
| Source | [lib/basis/sig\_option.sml](../../../../lib/basis/sig_option.sml) |

## Synopsis

```sml
signature OPTION
structure Option : OPTION
```

| Implementation |  | Source |
| --- | --- | --- |
| `Option` | Option | [lib/basis/option.sml](../../../../lib/basis/option.sml) |

Optional values: a value that may be missing, and what a partial function
returns instead of raising an exception.

[`NONE`](#con-none) says that there is no value and `SOME v` that there is `v`. The
functions here spare a program most case analyses on options: a default for
the missing value ([`getOpt`](#val-getopt)), functions carried over to options ([`map`](#val-map),
[`mapPartial`](#val-mappartial), [`compose`](#val-compose)), a predicate turned into a partial function
([`filter`](#val-filter)). The datatype, the exception and [`getOpt`](#val-getopt), [`isSome`](#val-issome) and [`valOf`](#val-valof)
are also in the top-level environment.

## Interface

<pre>
signature OPTION =
sig
  datatype 'a <a href="#type-option">option</a>
    = <a href="#con-none">NONE</a>
    | <a href="#con-some">SOME</a> of 'a

  exception <a href="#exn-option">Option</a>

  val <a href="#val-getopt">getOpt</a> : 'a option * 'a -&gt; 'a

  val <a href="#val-issome">isSome</a> : 'a option -&gt; bool

  val <a href="#val-valof">valOf</a> : 'a option -&gt; 'a

  val <a href="#val-filter">filter</a> : ('a -&gt; bool) -&gt; 'a -&gt; 'a option

  val <a href="#val-join">join</a> : 'a option option -&gt; 'a option

  val <a href="#val-app">app</a> : ('a -&gt; unit) -&gt; 'a option -&gt; unit

  val <a href="#val-map">map</a> : ('a -&gt; 'b) -&gt; 'a option -&gt; 'b option

  val <a href="#val-mappartial">mapPartial</a> : ('a -&gt; 'b option) -&gt; 'a option -&gt; 'b option

  val <a href="#val-compose">compose</a> : ('a -&gt; 'b) * ('c -&gt; 'a option) -&gt; 'c -&gt; 'b option

  val <a href="#val-composepartial">composePartial</a> : ('a -&gt; 'b option) * ('c -&gt; 'a option) -&gt; 'c -&gt; 'b option
end
</pre>

### <a name="type-option"></a>`option`

```sml
datatype 'a option
  = NONE
  | SOME of 'a
```

The type of optional values, the one of the top-level environment.

It admits equality when `'a` does.

> **Erratum** `OPTION/option-spec`. [`NONE`](#con-none) and [`SOME`](#con-some) may be specified, unlike
> the constructors of [`bool`](../sig/BOOL.md#type-bool) and [`list`](../sig/LIST.md#type-list), so the datatype stands here as the
> specification writes it.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-none"></a>`NONE` |  | no value |
| <a name="con-some"></a>`SOME` | `'a` | the value it carries |

Also in the [top-level environment](../top-level.md): `option`.

<details><summary>Tests (4)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `NONE-is-not-SOME` &middot; `equality-of-SOME` &middot; `inequality-of-SOME` &middot; `nested`

</details>

### <a name="exn-option"></a>`Option`

```sml
exception Option
```

Raised by [`valOf`](#val-valof) when there is no value. It is the top-level [`Option`](#exn-option).

Also in the [top-level environment](../top-level.md): `Option`.

<details><summary>Tests (4)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `handles-toplevel` (raises) &middot; `toplevel-handles` (raises Option) &middot; `raised-by-valOf` (raises) &middot; `differs-from-Empty`

</details>

### <a name="val-getopt"></a>`getOpt`

```sml
val getOpt : 'a option * 'a -> 'a
```

`getOpt (opt, a)` is the value that `opt` carries, or the default `a` if
it carries none.

**Example** `getOpt (NONE, 0) = 0`

Also in the [top-level environment](../top-level.md): `getOpt`.

<details><summary>Tests (7)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `some` &middot; `none` &middot; `string` &middot; `some-equal-to-default` &middot; `toplevel-some` &middot; `toplevel-none` &middot; `law-*`

</details>

### <a name="val-issome"></a>`isSome`

```sml
val isSome : 'a option -> bool
```

`isSome opt` is `true` when `opt` carries a value.

Also in the [top-level environment](../top-level.md): `isSome`.

<details><summary>Tests (6)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `some` &middot; `none` &middot; `some-none` &middot; `toplevel-some` &middot; `toplevel-none` &middot; `law-*`

</details>

### <a name="val-valof"></a>`valOf`

```sml
val valOf : 'a option -> 'a
```

`valOf opt` is the value that `opt` carries.

**Raises** [`Option`](#exn-option) if `opt` is [`NONE`](#con-none).

Also in the [top-level environment](../top-level.md): `valOf`.

<details><summary>Tests (6)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `some` &middot; `Option` (raises Option) &middot; `some-none` &middot; `toplevel-some` &middot; `toplevel-Option` (raises Option) &middot; `SOME-inverse-*`

</details>

### <a name="val-filter"></a>`filter`

```sml
val filter : ('a -> bool) -> 'a -> 'a option
```

`filter p a` is `SOME a` when `a` satisfies `p`, and [`NONE`](#con-none) otherwise.

**Example** `filter (fn x => x > 0) 0 = NONE`

<details><summary>Tests (7)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `true` &middot; `false` &middot; `string` &middot; `applies-f-once-to-a` &middot; `applies-f-once-to-a-false` &middot; `exception-of-f` (raises Fail) &middot; `law-*`

</details>

### <a name="val-join"></a>`join`

```sml
val join : 'a option option -> 'a option
```

`join opt` takes one layer of option away: `SOME (SOME v)` becomes `SOME v`, everything else [`NONE`](#con-none).

**Example** `join (SOME (SOME 1)) = SOME 1`

<details><summary>Tests (8)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `none` &middot; `some-none` &middot; `some-some` &middot; `one-level-only` &middot; `one-level-only-none` &middot; `SOME-*` &middot; `map-SOME-*` &middot; `nested-*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a option -> unit
```

`app f opt` applies `f` to the value that `opt` carries, if there is one,
for its effect.

<details><summary>Tests (7)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `some` &middot; `none` &middot; `returns-unit-some` &middot; `returns-unit-none` &middot; `exception-of-f` (raises Fail) &middot; `none-does-not-apply-f` &middot; `by-cases-*`

</details>

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a option -> 'b option
```

`map f opt` is `SOME (f v)` when `opt` is `SOME v`, and [`NONE`](#con-none) when it is
[`NONE`](#con-none).

**Example** `map (fn x => x + 1) (SOME 1) = SOME 2`

<details><summary>Tests (10)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `some` &middot; `none` &middot; `other-type` &middot; `result-is-wrapped` &middot; `applies-f-once` &middot; `none-does-not-apply-f` &middot; `exception-of-f` (raises Fail) &middot; `identity-*` &middot; `composition-*` &middot; `by-cases-*`

</details>

### <a name="val-mappartial"></a>`mapPartial`

```sml
val mapPartial : ('a -> 'b option) -> 'a option -> 'b option
```

`mapPartial f opt` is `f v` when `opt` is `SOME v`, and [`NONE`](#con-none) when it is
[`NONE`](#con-none).

It chains two computations that may fail: the second runs only if the
first gave a value.

**Law** `mapPartial f opt = join (map f opt)`

**Example** `mapPartial Int.fromString (SOME "x") = NONE`

<details><summary>Tests (10)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `some-to-some` &middot; `some-to-none` &middot; `none` &middot; `other-type` &middot; `applies-f-once` &middot; `none-does-not-apply-f` &middot; `exception-of-f` (raises Fail) &middot; `join-o-map-*` &middot; `by-cases-*` &middot; `SOME-is-identity-*`

</details>

### <a name="val-compose"></a>`compose`

```sml
val compose : ('a -> 'b) * ('c -> 'a option) -> 'c -> 'b option
```

`compose (f, g) a` is `SOME (f v)` when `g a` is `SOME v`, and [`NONE`](#con-none) when
`g a` is [`NONE`](#con-none).

**Law** `compose (f, g) a = map f (g a)`

**Example** `compose (fn x => x + 1, Int.fromString) "41" = SOME 42`

<details><summary>Tests (10)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `some` &middot; `none` &middot; `three-types` &middot; `three-types-none` &middot; `g-then-f` &middot; `f-not-applied-when-g-is-NONE` &middot; `exception-of-g` (raises Fail) &middot; `exception-of-f` (raises Fail) &middot; `map-o-*` &middot; `by-cases-*`

</details>

### <a name="val-composepartial"></a>`composePartial`

```sml
val composePartial : ('a -> 'b option) * ('c -> 'a option) -> 'c -> 'b option
```

`composePartial (f, g) a` is `f v` when `g a` is `SOME v`, and [`NONE`](#con-none) when
`g a` is [`NONE`](#con-none).

**Law** `composePartial (f, g) a = mapPartial f (g a)`

<details><summary>Tests (13)</summary>

For `Option`, in [tests/basis/option.sml](../../../../tests/basis/option.sml): `some-some` &middot; `some-none` &middot; `none` &middot; `three-types` &middot; `three-types-f-none` &middot; `g-then-f` &middot; `f-not-applied-when-g-is-NONE` &middot; `exception-of-g` (raises Fail) &middot; `exception-of-f` (raises Fail) &middot; `mapPartial-o-*` &middot; `by-cases-*` &middot; `SOME-left-*` &middot; `SOME-right-*`

</details>

## See also

[`LIST`](../sig/LIST.md), [`LIST_PAIR`](../sig/LIST_PAIR.md)

---

<sub>Generated by runedoc from lib/basis/sig\_option.sml; do not edit.</sub>
