# signature OPTION

[The Standard ML Basis Library](../README.md) &rsaquo; Lists and options &rsaquo; **OPTION**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 12 of 12 entries documented |
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
> the constructors of `bool` and `list`, so the datatype stands here as the
> specification writes it.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-none"></a>`NONE` |  | no value |
| <a name="con-some"></a>`SOME` | `'a` | the value it carries |

### <a name="exn-option"></a>`Option`

```sml
exception Option
```

Raised by [`valOf`](#val-valof) when there is no value. It is the top-level [`Option`](#exn-option).

### <a name="val-getopt"></a>`getOpt`

```sml
val getOpt : 'a option * 'a -> 'a
```

`getOpt (opt, a)` is the value that `opt` carries, or the default `a` if
it carries none.

### <a name="val-issome"></a>`isSome`

```sml
val isSome : 'a option -> bool
```

`isSome opt` is `true` when `opt` carries a value.

### <a name="val-valof"></a>`valOf`

```sml
val valOf : 'a option -> 'a
```

`valOf opt` is the value that `opt` carries.

**Raises** [`Option`](#exn-option) if `opt` is [`NONE`](#con-none).

### <a name="val-filter"></a>`filter`

```sml
val filter : ('a -> bool) -> 'a -> 'a option
```

`filter p a` is `SOME a` when `a` satisfies `p`, and [`NONE`](#con-none) otherwise.

### <a name="val-join"></a>`join`

```sml
val join : 'a option option -> 'a option
```

`join opt` takes one layer of option away: `SOME (SOME v)` becomes `SOME v`, everything else [`NONE`](#con-none).

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a option -> unit
```

`app f opt` applies `f` to the value that `opt` carries, if there is one,
for its effect.

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a option -> 'b option
```

`map f opt` is `SOME (f v)` when `opt` is `SOME v`, and [`NONE`](#con-none) when it is
[`NONE`](#con-none).

### <a name="val-mappartial"></a>`mapPartial`

```sml
val mapPartial : ('a -> 'b option) -> 'a option -> 'b option
```

`mapPartial f opt` is `f v` when `opt` is `SOME v`, and [`NONE`](#con-none) when it is
[`NONE`](#con-none).

It chains two computations that may fail: the second runs only if the
first gave a value.

**Law** `mapPartial f opt = join (map f opt)`

### <a name="val-compose"></a>`compose`

```sml
val compose : ('a -> 'b) * ('c -> 'a option) -> 'c -> 'b option
```

`compose (f, g) a` is `SOME (f v)` when `g a` is `SOME v`, and [`NONE`](#con-none) when
`g a` is [`NONE`](#con-none).

**Law** `compose (f, g) a = map f (g a)`

### <a name="val-composepartial"></a>`composePartial`

```sml
val composePartial : ('a -> 'b option) * ('c -> 'a option) -> 'c -> 'b option
```

`composePartial (f, g) a` is `f v` when `g a` is `SOME v`, and [`NONE`](#con-none) when
`g a` is [`NONE`](#con-none).

**Law** `composePartial (f, g) a = mapPartial f (g a)`

## See also

[`LIST`](../sig/LIST.md), [`LIST_PAIR`](../sig/LIST_PAIR.md)

---

<sub>Generated by runedoc from lib/basis/sig\_option.sml; do not edit.</sub>
