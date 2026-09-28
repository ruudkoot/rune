# signature GEN

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; **GEN**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 43 of 43 entries documented |
| Tests | not listed |
| Source | [lib/test/property/gen\_sig.sml](../../../../../lib/test/property/gen_sig.sml) |

## Synopsis

```sml
signature GEN
structure Gen :> GEN
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Gen`](../str/Gen.md) |  | [lib/test/property/gen.sml](../../../../../lib/test/property/gen.sml) |

Generators: values drawn from the source of a case of a property.

A generator reads the nodes of its own part of an implicit tree of random
words, so that the parts of a value never draw from each other: that is
what lets the shrinker change one part and leave the others be
(docs/plans/quickcheck.md, D3). How a word becomes a value follows the
generator principles of that roadmap: integers are small, on an edge, or
anywhere in their range, a third each; a list's length is up to the size,
often 0 or 1. The size grows from 0 over the cases of a run.

## Interface

<pre>
signature GEN =
sig
  type 'a <a href="#type-gen">gen</a>
  val <a href="#val-sample">sample</a> : 'a gen -&gt; Word64.word -&gt; int -&gt; 'a
  val <a href="#val-draw">draw</a> : 'a gen -&gt; PropertySource.source * PropertySource.position -&gt; 'a
  val <a href="#val-return">return</a> : 'a -&gt; 'a gen
  val <a href="#val-map">map</a> : ('a -&gt; 'b) -&gt; 'a gen -&gt; 'b gen
  val <a href="#val-map2">map2</a> : ('a * 'b -&gt; 'c) -&gt; 'a gen * 'b gen -&gt; 'c gen
  val <a href="#val-bind">bind</a> : 'a gen -&gt; ('a -&gt; 'b gen) -&gt; 'b gen
  val <a href="#val-pair">pair</a> : 'a gen * 'b gen -&gt; ('a * 'b) gen
  val <a href="#val-triple">triple</a> : 'a gen * 'b gen * 'c gen -&gt; ('a * 'b * 'c) gen
  val <a href="#val-sized">sized</a> : (int -&gt; 'a gen) -&gt; 'a gen
  val <a href="#val-resize">resize</a> : int -&gt; 'a gen -&gt; 'a gen
  val <a href="#val-oneof">oneOf</a> : 'a gen list -&gt; 'a gen
  val <a href="#val-frequency">frequency</a> : (int * 'a gen) list -&gt; 'a gen
  val <a href="#val-elements">elements</a> : 'a vector -&gt; 'a gen
  val <a href="#val-filter">filter</a> : ('a -&gt; bool) -&gt; 'a gen -&gt; 'a gen
  exception <a href="#exn-discarded">Discarded</a>
  val <a href="#val-fix">fix</a> : ('a gen -&gt; 'a gen) -&gt; 'a gen
  val <a href="#val-intrange">intRange</a> : int * int -&gt; int gen
  val <a href="#val-int">int</a> : int gen
  val <a href="#val-largerange">largeRange</a> : LargeInt.int * LargeInt.int -&gt; LargeInt.int gen
  val <a href="#val-intinf">intInf</a> : IntInf.int gen
  val <a href="#val-intinfrange">intInfRange</a> : IntInf.int * IntInf.int -&gt; IntInf.int gen
  val <a href="#val-word">word</a> : word gen
  val <a href="#val-word64">word64</a> : Word64.word gen
  val <a href="#val-code">code</a> : int -&gt; int gen
  val <a href="#val-char">char</a> : char gen
  val <a href="#val-real">real</a> : real gen
  val <a href="#val-bool">bool</a> : bool gen
  val <a href="#val-unit">unit</a> : unit gen
  val <a href="#val-order">order</a> : order gen
  val <a href="#val-option">option</a> : 'a gen -&gt; 'a option gen
  val <a href="#val-list">list</a> : 'a gen -&gt; 'a list gen
  val <a href="#val-listof">listOf</a> : int gen -&gt; 'a gen -&gt; 'a list gen
  val <a href="#val-string">string</a> : string gen
  val <a href="#val-vector">vector</a> : 'a gen -&gt; 'a vector gen
  val <a href="#val-array">array</a> : 'a gen -&gt; 'a array gen
  val <a href="#val-function">function</a> : ('a -&gt; Word64.word) * 'b gen -&gt; ('a -&gt; 'b) gen
  val <a href="#val-functionof">functionOf</a> : ('a -&gt; Word64.word) * ('a -&gt; string) * ('b -&gt; string) * 'b gen -&gt; ('a -&gt; 'b) gen
  val <a href="#val-pureof">pureOf</a> : ('a -&gt; Word64.word) * ('a -&gt; string) * ('b -&gt; string) * 'b gen -&gt; ('a -&gt; 'b) gen
  exception <a href="#exn-generated">Generated</a>
  val <a href="#val-wordbits">wordBits</a> : int -&gt; Word64.word gen
  val <a href="#val-primitive">primitive</a> : (PropertySource.source * PropertySource.position -&gt; 'a) -&gt; 'a gen
  val <a href="#val-resource">resource</a> : 'a gen * ('a -&gt; unit) -&gt; 'a gen
end
</pre>

### <a name="type-gen"></a>`gen`

```sml
type 'a gen
```

A generator of values of type `'a`.

### <a name="val-sample"></a>`sample`

```sml
val sample : 'a gen -> Word64.word -> int -> 'a
```

`sample g seed size` is the value `g` draws from the source of `seed`
at `size`: the same value every time.

**Example** `sample (list int) 0w1 0 = []`

### <a name="val-draw"></a>`draw`

```sml
val draw : 'a gen -> PropertySource.source * PropertySource.position -> 'a
```

`draw g (source, address)` is the value of `g` read at `address` of
`source`: what the other structures of the library run a generator
with.

### <a name="val-return"></a>`return`

```sml
val return : 'a -> 'a gen
```

`return x` always draws `x`.

**Example** `sample (return 3) 0w0 10 = 3`

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a gen -> 'b gen
```

`map f g` draws `f x` for the `x` that `g` draws.

### <a name="val-map2"></a>`map2`

```sml
val map2 : ('a * 'b -> 'c) -> 'a gen * 'b gen -> 'c gen
```

`map2 f (g, h)` draws `f (x, y)` for the `x` and `y` that `g` and `h`
draw from their own parts.

### <a name="val-bind"></a>`bind`

```sml
val bind : 'a gen -> ('a -> 'b gen) -> 'b gen
```

`bind g f` draws `x` from `g`, and then from `f x` in a part of its own.

### <a name="val-pair"></a>`pair`

```sml
val pair : 'a gen * 'b gen -> ('a * 'b) gen
```

`pair (g, h)` draws a pair, each component from its own part.

### <a name="val-triple"></a>`triple`

```sml
val triple : 'a gen * 'b gen * 'c gen -> ('a * 'b * 'c) gen
```

`triple (g, h, k)` draws a triple, each component from its own part.

### <a name="val-sized"></a>`sized`

```sml
val sized : (int -> 'a gen) -> 'a gen
```

`sized f` is the generator `f n` for the size `n` of the case.

### <a name="val-resize"></a>`resize`

```sml
val resize : int -> 'a gen -> 'a gen
```

`resize n g` is `g` at the size `n`.

### <a name="val-oneof"></a>`oneOf`

```sml
val oneOf : 'a gen list -> 'a gen
```

`oneOf gs` draws from one of `gs`, each as likely; the first is the
simplest.

**Raises** [`Empty`](../../../basis/sig/LIST.md#exn-empty) if `gs` is empty.

### <a name="val-frequency"></a>`frequency`

```sml
val frequency : (int * 'a gen) list -> 'a gen
```

`frequency ws` draws from one of the generators of `ws`, each as likely as
its weight says; the first is the simplest.

**Raises** [`Empty`](../../../basis/sig/LIST.md#exn-empty) if no weight is positive.

### <a name="val-elements"></a>`elements`

```sml
val elements : 'a vector -> 'a gen
```

`elements v` draws an element of `v`, each as likely; the first is the
simplest.

**Raises** [`Empty`](../../../basis/sig/LIST.md#exn-empty) if `v` is empty.

**Example** `sample (elements (Vector.fromList [7])) 0w5 3 = 7`

### <a name="val-filter"></a>`filter`

```sml
val filter : ('a -> bool) -> 'a gen -> 'a gen
```

`filter p g` draws from `g` until `p` holds, a hundred times at most,
and then gives the case up: it is discarded, as a condition that does
not hold discards it.

### <a name="exn-discarded"></a>`Discarded`

```sml
exception Discarded
```

[`Discarded`](#exn-discarded) is raised by a generator that gives its case up.

The runner counts the case as discarded. It is the library's own, raised
only while a case is drawn, never through the code under test.

### <a name="val-fix"></a>`fix`

```sml
val fix : ('a gen -> 'a gen) -> 'a gen
```

`fix f` is the generator `g` for which `g = f g`: a recursive generator.
`f` must make its recursive draws smaller, by [`resize`](#val-resize), so that they
end.

### <a name="val-intrange"></a>`intRange`

```sml
val intRange : int * int -> int gen
```

`intRange (lo, hi)` draws an integer of `[lo, hi]`.

It is a third of the time small (within the size of 0), a third on an
edge, and a third anywhere. Half the edges are the extremes (0, 1, \~1,
the bounds and their neighbours) and half the powers of two in range
and their neighbours.

**Raises** [`Domain`](../../../basis/sig/GENERAL.md#exn-domain) if `hi < lo`.

**Example** `sample (intRange (5, 5)) 0w9 50 = 5`

### <a name="val-int"></a>`int`

```sml
val int : int gen
```

[`int`](#val-int) draws an integer of the whole range of [`Int.int`](../../../basis/sig/INTEGER.md#type-int), as [`intRange`](#val-intrange)
does; where [`Int.int`](../../../basis/sig/INTEGER.md#type-int) has no bounds, of the range of 64 bits.

### <a name="val-largerange"></a>`largeRange`

```sml
val largeRange : LargeInt.int * LargeInt.int -> LargeInt.int gen
```

`largeRange (lo, hi)` draws an integer of `[lo, hi]` as [`intRange`](#val-intrange) does, for a range of at most 2^64 integers.

The integers may be of any size: this is what the arbitraries of [`Int64`](../../../basis/str/Int64.md)
and [`Position`](../../../basis/str/Int.md) are made of where [`Int.int`](../../../basis/sig/INTEGER.md#type-int) is narrower.

**Raises** [`Domain`](../../../basis/sig/GENERAL.md#exn-domain) if `hi < lo`, or if the range has more than 2^64
integers.

### <a name="val-intinf"></a>`intInf`

```sml
val intInf : IntInf.int gen
```

[`intInf`](#val-intinf) draws an [`IntInf.int`](../../../basis/sig/INTEGER.md#type-int): a third of the time small, a third an
edge of a fixed width, a third of any magnitude.

An edge is 2^k, 2^k - 1 or 2^k + 1, or the negation of one, for `k` up
to 130. A magnitude is 1 to [`size`](../../../basis/sig/STRING.md#val-size) limbs of 30 bits (the limbs of Rune's
[`IntInf`](../../../basis/str/IntInf.md)), each uniform, with either sign.

### <a name="val-intinfrange"></a>`intInfRange`

```sml
val intInfRange : IntInf.int * IntInf.int -> IntInf.int gen
```

`intInfRange (lo, hi)` draws an integer of `[lo, hi]`, a range of any width, as [`intRange`](#val-intrange) does.

It is a third of the time small, a third on an edge (0, 1, \~1, the bounds
and their neighbours, powers of two and their neighbours), and a third
anywhere in the range.

**Raises** [`Domain`](../../../basis/sig/GENERAL.md#exn-domain) if `hi < lo`.

### <a name="val-word"></a>`word`

```sml
val word : word gen
```

[`word`](#val-word) draws a word: a third of the time small, a third on an edge, a third anywhere.

Half the edges are the extremes (0, 1, the largest and its neighbour,
the top bit and its neighbours) and half the powers of two and their
neighbours.

### <a name="val-word64"></a>`word64`

```sml
val word64 : Word64.word gen
```

[`word64`](#val-word64) draws a 64-bit word as [`word`](#val-word) draws a word.

### <a name="val-code"></a>`code`

```sml
val code : int -> int gen
```

`code maxOrd` draws the code of a character of a character set of
`maxOrd + 1` characters, as [`char`](#val-char) draws a character.

Where `maxOrd` is above 255, a third of the draws that are any of the
256 are instead any of the whole set.

### <a name="val-char"></a>`char`

```sml
val char : char gen
```

[`char`](#val-char) draws a character: half the time any of the 256.

The other half it is a letter or digit, a space or control, or a
character that the syntax of numbers, characters and strings gives a
meaning to.

### <a name="val-real"></a>`real`

```sml
val real : real gen
```

[`real`](#val-real) draws a real: a special one, a small one, or any, a third of the time each.

The special ones are the zeros, the infinities, a NaN, the smallest and
largest subnormals and normals, 1, \~1, 0.5, 2^53 and the real after it.
The small ones are integers and halves within the size. Any is any bit
pattern.

### <a name="val-bool"></a>`bool`

```sml
val bool : bool gen
```

[`bool`](#val-bool) draws `true` and `false`, each half the time; `false` is the
simpler.

### <a name="val-unit"></a>`unit`

```sml
val unit : unit gen
```

[`unit`](#val-unit) draws `()`.

### <a name="val-order"></a>`order`

```sml
val order : order gen
```

[`order`](#val-order) draws `LESS`, `EQUAL` or `GREATER`, each a third of the time.

### <a name="val-option"></a>`option`

```sml
val option : 'a gen -> 'a option gen
```

`option g` draws `NONE` a quarter of the time, and `SOME` of what `g`
draws otherwise.

### <a name="val-list"></a>`list`

```sml
val list : 'a gen -> 'a list gen
```

`list g` draws a list of elements of `g`, of a length up to the size.

Its length is 0 or 1 an eighth of the time each. Each element has a part
of its own and a mark the shrinker may clear, which removes it.

### <a name="val-listof"></a>`listOf`

```sml
val listOf : int gen -> 'a gen -> 'a list gen
```

`listOf n g` draws a list of the length `n` draws, of elements of `g`
(with no marks: the shrinker shortens it from its end).

### <a name="val-string"></a>`string`

```sml
val string : string gen
```

[`string`](#val-string) draws a string of characters of [`char`](#val-char), of a length as [`list`](#val-list)
draws one.

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a gen -> 'a vector gen
```

`vector g` draws a vector as `list g` draws a list.

### <a name="val-array"></a>`array`

```sml
val array : 'a gen -> 'a array gen
```

`array g` draws an array as `list g` draws a list: a fresh one at every
draw, so that two draws of the same case do not share it.

### <a name="val-function"></a>`function`

```sml
val function : ('a -> Word64.word) * 'b gen -> ('a -> 'b) gen
```

`function (co, g)` draws a function, whose result at `x` is drawn at `co x`.

The result comes from the part of the tree that the observation `co x`
names, so that the function gives the same result for arguments that
`co` does not tell apart.

### <a name="val-functionof"></a>`functionOf`

```sml
val functionOf : ('a -> Word64.word) * ('a -> string) * ('b -> string) * 'b gen -> ('a -> 'b) gen
```

`functionOf (co, showArg, showRes, g)` draws a function of any of the three kinds of D5.

A node chooses the kind: pure, as [`function`](#val-function) draws (the simplest);
raising [`Generated`](#exn-generated) at a quarter of the arguments; or observing its
effects, whose calls a law compares on its two sides. Every call is
logged, and the report shows the calls of a counterexample's function
as a table. The shrinker makes a function a constant of its kind where
it can: a pure one gives the simplest value everywhere, and a raising
one raises everywhere.

### <a name="val-pureof"></a>`pureOf`

```sml
val pureOf : ('a -> Word64.word) * ('a -> string) * ('b -> string) * 'b gen -> ('a -> 'b) gen
```

`pureOf (co, showArg, showRes, g)` draws a pure function, as [`function`](#val-function)
does, whose calls the report shows.

### <a name="exn-generated"></a>`Generated`

```sml
exception Generated
```

[`Generated`](#exn-generated) is what a raising function of [`functionOf`](#val-functionof) raises.

### <a name="val-wordbits"></a>`wordBits`

```sml
val wordBits : int -> Word64.word gen
```

`wordBits n` draws a word of `n` bits (at most 64), as [`word`](#val-word) draws a
word.

### <a name="val-primitive"></a>`primitive`

```sml
val primitive : (PropertySource.source * PropertySource.position -> 'a) -> 'a gen
```

`primitive f` is the generator that runs `f` with the source and the position it is given.

It is a generator that reads its nodes from the source itself, as the
arbitraries of a family of structures do.

### <a name="val-resource"></a>`resource`

```sml
val resource : 'a gen * ('a -> unit) -> 'a gen
```

`resource (g, release)` draws what `g` draws, and calls `release` on it
when the case is over: a generator of things that must be undone, such
as a file or a socket.

---

<sub>Generated by runedoc from lib/test/property/gen\_sig.sml; do not edit.</sub>
