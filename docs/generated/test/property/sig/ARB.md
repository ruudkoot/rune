# signature ARB

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; **ARB**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 28 of 28 entries documented |
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
  val <a href="#val-intinf">intInf</a> : IntInf.int arb
  val <a href="#val-intrange">intRange</a> : int * int -&gt; int arb
  val <a href="#val-wordrange">wordRange</a> : word * word -&gt; word arb
  val <a href="#val-reference">reference</a> : 'a arb -&gt; 'a ref arb
  val <a href="#val-enum">enum</a> : (''a * string) list -&gt; ''a arb
  val <a href="#val-vectorslice">vectorSlice</a> : 'a arb -&gt; 'a VectorSlice.slice arb
  val <a href="#val-arrayslice">arraySlice</a> : 'a arb -&gt; 'a ArraySlice.slice arb
  val <a href="#val-array2">array2</a> : 'a arb -&gt; 'a Array2.array arb
  val <a href="#val-exn">exn</a> : exn arb
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

### <a name="val-intinf"></a>`intInf`

```sml
val intInf : IntInf.int arb
```

[`intInf`](#val-intinf) is the arbitrary of [`IntInf.int`](../../../basis/sig/INTEGER.md#type-int), drawn by [`Gen.intInf`](../sig/GEN.md#val-intinf).

### <a name="val-intrange"></a>`intRange`

```sml
val intRange : int * int -> int arb
```

`intRange (lo, hi)` is the arbitrary of the integers of `[lo, hi]`, drawn by [`Gen.intRange`](../sig/GEN.md#val-intrange): a domain a law can name (D7).

**Raises** [`Domain`](../../../basis/sig/GENERAL.md#exn-domain) if `hi < lo`.

### <a name="val-wordrange"></a>`wordRange`

```sml
val wordRange : word * word -> word arb
```

`wordRange (lo, hi)` is the arbitrary of the words of `[lo, hi]`, drawn as [`Gen.intRange`](../sig/GEN.md#val-intrange) draws integers.

**Raises** [`Domain`](../../../basis/sig/GENERAL.md#exn-domain) if `hi < lo`.

### <a name="val-reference"></a>`reference`

```sml
val reference : 'a arb -> 'a ref arb
```

`reference a` is the arbitrary of references to `a`: a new one at every
draw, and equal only to itself, as `=` on references is.

### <a name="val-enum"></a>`enum`

```sml
val enum : (''a * string) list -> ''a arb
```

`enum xs` is the arbitrary of the values of `xs`, each shown as its name:
the arbitrary of a datatype with no values in its constructors. The first
is the simplest.

**Raises** [`Empty`](../../../basis/sig/LIST.md#exn-empty) if `xs` is empty.

**Example** `#show (enum [(LESS, "LESS"), (GREATER, "GREATER")]) GREATER = "GREATER"`

### <a name="val-vectorslice"></a>`vectorSlice`

```sml
val vectorSlice : 'a arb -> 'a VectorSlice.slice arb
```

`vectorSlice a` is the arbitrary of slices of vectors of `a`: a vector,
and a start and a length within it.

Two slices are equal when their vectors have equal elements and their
starts and lengths are the same.

### <a name="val-arrayslice"></a>`arraySlice`

```sml
val arraySlice : 'a arb -> 'a ArraySlice.slice arb
```

`arraySlice a` is the arbitrary of slices of arrays of `a`, as
[`vectorSlice`](#val-vectorslice) draws them, over a fresh array at every draw.

### <a name="val-array2"></a>`array2`

```sml
val array2 : 'a arb -> 'a Array2.array arb
```

`array2 a` is the arbitrary of two-dimensional arrays of `a`.

The numbers of rows and of columns are each drawn as a length is, at the
square root of the size; an array with no rows has no columns. Two
arrays are equal when they have the same dimensions and equal elements.

### <a name="val-exn"></a>`exn`

```sml
val exn : exn arb
```

[`exn`](#val-exn) is the arbitrary of exceptions: those of the Basis Library that
carry no value, [`Gen.Generated`](../sig/GEN.md#exn-generated), and [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) with any message.

Two exceptions are equal when they have the same name, and, for [`Fail`](../../../basis/sig/GENERAL.md#exn-fail),
the same message.

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
