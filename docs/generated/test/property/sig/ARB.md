# signature ARB

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; **ARB**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 19 of 19 entries documented |
| Tests | not listed |
| Source | [lib/test/property/arb\_sig.sml](../../../../../lib/test/property/arb_sig.sml) |

## Synopsis

```sml
signature ARB
structure Arb :> ARB
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Arb`](../str/Arb.md) |  | [lib/test/property/arb.sml](../../../../../lib/test/property/arb.sml) |

Arbitraries: the generator, the printer, the observer and the equality of
a type, as one record -- what QuickCheck finds by a type class and a
program here passes by name (docs/plans/quickcheck.md, D4).

## Interface

<pre>
signature ARB =
sig
  type 'a <a href="#type-arb">arb</a> = {<a href="#fld-arb.gen">gen</a> : 'a Gen.gen, <a href="#fld-arb.show">show</a> : 'a -&gt; string, <a href="#fld-arb.co">co</a> : 'a -&gt; Word64.word,
                 <a href="#fld-arb.eq">eq</a> : ('a * 'a -&gt; bool) option}
  val <a href="#val-equal">equal</a> : 'a arb -&gt; 'a * 'a -&gt; bool
  val <a href="#val-int">int</a> : int arb
  val <a href="#val-word">word</a> : word arb
  val <a href="#val-word64">word64</a> : Word64.word arb
  val <a href="#val-char">char</a> : char arb
  val <a href="#val-string">string</a> : string arb
  val <a href="#val-real">real</a> : real arb
  val <a href="#val-bool">bool</a> : bool arb
  val <a href="#val-unit">unit</a> : unit arb
  val <a href="#val-order">order</a> : order arb
  val <a href="#val-option">option</a> : 'a arb -&gt; 'a option arb
  val <a href="#val-list">list</a> : 'a arb -&gt; 'a list arb
  val <a href="#val-vector">vector</a> : 'a arb -&gt; 'a vector arb
  val <a href="#val-array">array</a> : 'a arb -&gt; 'a array arb
  val <a href="#val-pair">pair</a> : 'a arb * 'b arb -&gt; ('a * 'b) arb
  val <a href="#val-triple">triple</a> : 'a arb * 'b arb * 'c arb -&gt; ('a * 'b * 'c) arb
  val <a href="#val-function">function</a> : 'a arb * 'b arb -&gt; ('a -&gt; 'b) arb
  val <a href="#val-purefunction">pureFunction</a> : 'a arb * 'b arb -&gt; ('a -&gt; 'b) arb
end
</pre>

### <a name="type-arb"></a>`arb`

```sml
type 'a arb = {gen : 'a Gen.gen, show : 'a -> string, co : 'a -> Word64.word,
               eq : ('a * 'a -> bool) option}
```

The record of a type: `eq` is `NONE` where the type has no equality of
its own and none is given, and is then the equality of what `show`
shows.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-arb.gen"></a>`gen` | `'a Gen.gen` |  |
| <a name="fld-arb.show"></a>`show` | `'a -> string` |  |
| <a name="fld-arb.co"></a>`co` | `'a -> Word64.word` |  |
| <a name="fld-arb.eq"></a>`eq` | `('a * 'a -> bool) option` |  |

### <a name="val-equal"></a>`equal`

```sml
val equal : 'a arb -> 'a * 'a -> bool
```

`equal a (x, y)` is the equality of `a`: its `eq`, or the equality of
what its `show` shows.

### <a name="val-int"></a>`int`

```sml
val int : int arb
```

[`int`](#val-int) is the arbitrary of [`Int.int`](../../../basis/sig/INTEGER.md#type-int).

### <a name="val-word"></a>`word`

```sml
val word : word arb
```

[`word`](#val-word) is the arbitrary of [`Word.word`](../../../basis/sig/WORD.md#type-word).

### <a name="val-word64"></a>`word64`

```sml
val word64 : Word64.word arb
```

[`word64`](#val-word64) is the arbitrary of [`Word64.word`](../../../basis/sig/WORD.md#type-word).

### <a name="val-char"></a>`char`

```sml
val char : char arb
```

[`char`](#val-char) is the arbitrary of [`Char.char`](../../../basis/sig/CHAR.md#type-char).

### <a name="val-string"></a>`string`

```sml
val string : string arb
```

[`string`](#val-string) is the arbitrary of [`String.string`](../../../basis/sig/STRING.md#type-string).

### <a name="val-real"></a>`real`

```sml
val real : real arb
```

[`real`](#val-real) is the arbitrary of [`Real.real`](../../../basis/sig/REAL.md#type-real), whose equality is identity.

Identity is the same number, with the zeros told apart and every NaN
equal to every other (docs/plans/quickcheck.md, D6).

### <a name="val-bool"></a>`bool`

```sml
val bool : bool arb
```

[`bool`](#val-bool) is the arbitrary of [`bool`](#val-bool).

### <a name="val-unit"></a>`unit`

```sml
val unit : unit arb
```

[`unit`](#val-unit) is the arbitrary of [`unit`](#val-unit).

### <a name="val-order"></a>`order`

```sml
val order : order arb
```

[`order`](#val-order) is the arbitrary of [`order`](#val-order).

### <a name="val-option"></a>`option`

```sml
val option : 'a arb -> 'a option arb
```

`option a` is the arbitrary of options of `a`.

### <a name="val-list"></a>`list`

```sml
val list : 'a arb -> 'a list arb
```

`list a` is the arbitrary of lists of `a`.

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a arb -> 'a vector arb
```

`vector a` is the arbitrary of vectors of `a`.

### <a name="val-array"></a>`array`

```sml
val array : 'a arb -> 'a array arb
```

`array a` is the arbitrary of arrays of `a`, compared by their elements:
a fresh array at every draw.

### <a name="val-pair"></a>`pair`

```sml
val pair : 'a arb * 'b arb -> ('a * 'b) arb
```

`pair (a, b)` is the arbitrary of pairs.

### <a name="val-triple"></a>`triple`

```sml
val triple : 'a arb * 'b arb * 'c arb -> ('a * 'b * 'c) arb
```

`triple (a, b, c)` is the arbitrary of triples.

### <a name="val-function"></a>`function`

```sml
val function : 'a arb * 'b arb -> ('a -> 'b) arb
```

`function (a, b)` is the arbitrary of functions from `a` to `b`, of every kind of D5.

A function is pure, raises [`Gen.Generated`](../sig/GEN.md#exn-generated) at some arguments, or
observes its effects, which a law compares (docs/plans/quickcheck.md,
D5 C). A function has no equality and is shown as `fn`; the report
lists the calls of a counterexample's functions.

### <a name="val-purefunction"></a>`pureFunction`

```sml
val pureFunction : 'a arb * 'b arb -> ('a -> 'b) arb
```

`pureFunction (a, b)` is the arbitrary of pure, total functions from `a` to `b`.

It is for a law that says its function has no effects (D5, class A).

---

<sub>Generated by runedoc from lib/test/property/arb\_sig.sml; do not edit.</sub>
