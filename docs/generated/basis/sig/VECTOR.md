# signature VECTOR

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **VECTOR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 21 of 21 entries documented |
| Tests | 148 checks of 21 entries |
| Source | [lib/basis/sig\_vector.sml](../../../../lib/basis/sig_vector.sml) |

## Synopsis

```sml
signature VECTOR
structure Vector : VECTOR
```

| Implementation |  | Source |
| --- | --- | --- |
| `Vector` | Vector: immutable arrays with structural equality. | [lib/basis/vector.sml](../../../../lib/basis/vector.sml) |

Vectors: immutable sequences of a fixed length, of any element type.

A vector is indexed from 0 and is made once: there is no [`update`](#val-update) that
changes one, only one that gives a new vector. [`ARRAY`](../sig/ARRAY.md) is the mutable
counterpart, [`VECTOR_SLICE`](../sig/VECTOR_SLICE.md) describes a stretch of a vector without
copying it, and the [`MONO_VECTOR`](../sig/MONO_VECTOR.md) structures are the same thing for one
element type, which lets an implementation pack the elements.

The traversals come in pairs: [`app`](#val-app), [`map`](#val-map), [`foldl`](#val-foldl), [`foldr`](#val-foldr), [`find`](#val-find) take
a function of an element, and [`appi`](#val-appi), [`mapi`](#val-mapi), [`foldli`](#val-foldli), [`foldri`](#val-foldri), [`findi`](#val-findi)
one of the index and the element. [`foldli`](#val-foldli) and [`foldri`](#val-foldri) differ only in the
order they visit: both pass the index.

> **Erratum** `VECTOR/vector-spec`. The specification writes `eqtype 'a vector = 'a vector`, which the Definition does not allow as a specification; it is
> written here as an abbreviation of the top-level [`vector`](#type-vector), which admits
> equality when its element type does.

## Contents

[Making a vector](#making-a-vector) &middot;
[Elements](#elements) &middot;
[Traversing](#traversing) &middot;
[Searching](#searching)

## Interface

<pre>
signature VECTOR =
sig
  type 'a <a href="#type-vector">vector</a> = 'a vector

  val <a href="#val-maxlen">maxLen</a> : int

  val <a href="#val-fromlist">fromList</a> : 'a list -&gt; 'a vector

  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; 'a) -&gt; 'a vector

  val <a href="#val-length">length</a> : 'a vector -&gt; int

  val <a href="#val-sub">sub</a> : 'a vector * int -&gt; 'a

  val <a href="#val-update">update</a> : 'a vector * int * 'a -&gt; 'a vector

  val <a href="#val-concat">concat</a> : 'a vector list -&gt; 'a vector

  val <a href="#val-appi">appi</a> : (int * 'a -&gt; unit) -&gt; 'a vector -&gt; unit

  val <a href="#val-app">app</a> : ('a -&gt; unit) -&gt; 'a vector -&gt; unit

  val <a href="#val-mapi">mapi</a> : (int * 'a -&gt; 'b) -&gt; 'a vector -&gt; 'b vector

  val <a href="#val-map">map</a> : ('a -&gt; 'b) -&gt; 'a vector -&gt; 'b vector

  val <a href="#val-foldli">foldli</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a vector -&gt; 'b

  val <a href="#val-foldri">foldri</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a vector -&gt; 'b

  val <a href="#val-foldl">foldl</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a vector -&gt; 'b

  val <a href="#val-foldr">foldr</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a vector -&gt; 'b

  val <a href="#val-findi">findi</a> : (int * 'a -&gt; bool) -&gt; 'a vector -&gt; (int * 'a) option

  val <a href="#val-find">find</a> : ('a -&gt; bool) -&gt; 'a vector -&gt; 'a option

  val <a href="#val-exists">exists</a> : ('a -&gt; bool) -&gt; 'a vector -&gt; bool

  val <a href="#val-all">all</a> : ('a -&gt; bool) -&gt; 'a vector -&gt; bool

  val <a href="#val-collate">collate</a> : ('a * 'a -&gt; order) -&gt; 'a vector * 'a vector -&gt; order
end
</pre>

### <a name="type-vector"></a>`vector`

```sml
type 'a vector = 'a vector
```

The type of vectors, the one of the top-level environment.

<details><summary>Tests (16)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `equal` &middot; `equal-tabulate` &middot; `element-differs` &middot; `prefix` &middot; `empty-equal` &middot; `empty-nonempty` &middot; `unequal` &middot; `strings` &middot; `nested` &middot; `nested-differs` &middot; `update-to-same` &middot; `update-differs` &middot; `is-toplevel` &middot; `model-*` &middot; `reflexive-*` &middot; `long`

</details>

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

The greatest length a vector may have.

> **Implementation** `Vector.maxLen/value`. 100000000; an array has the same
> bound.

<details><summary>Tests (1)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `covers-created-vectors`

</details>

## Making a vector

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : 'a list -> 'a vector
```

`fromList l` is the vector of the elements of `l`, in order.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `l` is longer than [`maxLen`](#val-maxlen).

**Example** `fromList [1, 2] = fromList [1, 2]` for vectors with equal
elements are equal.

Also in the [top-level environment](../top-level.md): `vector`.

<details><summary>Tests (7)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `nil` &middot; `singleton` &middot; `length` &middot; `strings` &middot; `round-trip-*` &middot; `long`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> 'a) -> 'a vector
```

`tabulate (n, f)` is the vector of `f 0`, `f 1`, ..., `f (n - 1)`.

`f` is applied in order of increasing index.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0` or `n > maxLen`, before `f` is applied at all.

**Example** `foldr (op ::) [] (tabulate (3, fn i => i * 2)) = [0, 2, 4]`

<details><summary>Tests (8)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `zero` &middot; `one` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f` &middot; `model-*` &middot; `Size-above-maxLen` (raises Size)

</details>

## Elements

### <a name="val-length"></a>`length`

```sml
val length : 'a vector -> int
```

`length v` is the number of elements of `v`.

<details><summary>Tests (5)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `empty` &middot; `five` &middot; `tabulate` &middot; `model-*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a vector * int -> 'a
```

`sub (v, i)` is the element of `v` at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length v`.

**Example** `sub (fromList [1, 2, 3], 1) = 2`

<details><summary>Tests (9)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `first` &middot; `middle` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

### <a name="val-update"></a>`update`

```sml
val update : 'a vector * int * 'a -> 'a vector
```

`update (v, i, x)` is a new vector, like `v` but with `x` at position `i`.

`v` itself does not change: a vector is immutable, so this copies.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length v`.

**Complexity** linear in `length v`.

**Example** `update (fromList [1, 2, 3], 1, 9) = fromList [1, 9, 3]`

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; Vector.update, Word8Vector.update and CharVector.update return the vector unchanged instead of raising Subscript when the index is out of range

</details>

<details><summary>Tests (12)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `first` &middot; `middle` &middot; `last` &middot; `singleton` &middot; `argument-unchanged` &middot; `twice` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : 'a vector list -> 'a vector
```

`concat l` is the vectors of `l` one after another.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`maxLen`](#val-maxlen).

**Example** `concat [fromList [1], fromList [2, 3]] = fromList [1, 2, 3]`

<details><summary>Tests (10)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `nil` &middot; `one` &middot; `empties` &middot; `same-twice` &middot; `order` &middot; `model-*` &middot; `long` &middot; `many` &middot; `Size-above-maxLen` (raises Size)

</details>

## Traversing

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * 'a -> unit) -> 'a vector -> unit
```

`appi f v` applies `f` to the index and the element of each position of `v`, from 0 up, for its effect.

<details><summary>Tests (3)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `order` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a vector -> unit
```

`app f v` applies `f` to every element of `v`, from 0 up, for its effect.

<details><summary>Tests (3)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `order` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * 'a -> 'b) -> 'a vector -> 'b vector
```

`mapi f v` is the vector of the results of `f` on the index and the element of each position.

**Example** `mapi (fn (i, x) => i + x) (fromList [10, 20]) = fromList [10, 21]`

<details><summary>Tests (6)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `index-and-element` &middot; `empty` &middot; `order` &middot; `model-*` &middot; `long`

</details>

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a vector -> 'b vector
```

`map f v` is the vector of the results of `f` on each element, in order.

<details><summary>Tests (7)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `empty` &middot; `order` &middot; `other-type` &middot; `argument-unchanged` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a vector -> 'b
```

`foldli f init v` combines the elements from the left, giving `f` the index as well.

<details><summary>Tests (4)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a vector -> 'b
```

`foldri f init v` combines the elements from the right, giving `f` the index as well.

<details><summary>Tests (4)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a vector -> 'b
```

`foldl f init v` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

<details><summary>Tests (5)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a vector -> 'b
```

`foldr f init v` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

<details><summary>Tests (6)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long` &middot; `long-list`

</details>

## Searching

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a vector -> (int * 'a) option
```

`findi p v` is `SOME (i, x)` for the first position whose index and element satisfy `p`, or `NONE`.

It stops at that position: `p` is not applied to what follows.

**Example** `findi (fn (_, x) => x > 1) (fromList [1, 2, 3]) = SOME (1, 2)`

<details><summary>Tests (8)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a vector -> 'a option
```

`find p v` is `SOME x` for the first element that satisfies `p`, or `NONE`.

<details><summary>Tests (7)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `first-match` &middot; `last-element` &middot; `none` &middot; `empty` &middot; `stops` &middot; `model-*` &middot; `long`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a vector -> bool
```

`exists p v` is `true` when some element satisfies `p`; it stops at the first that does.

<details><summary>Tests (6)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a vector -> bool
```

`all p v` is `true` when every element satisfies `p`; it stops at the first that does not.

<details><summary>Tests (8)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `de-morgan-*` &middot; `long`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a vector * 'a vector -> order
```

`collate cmp (v, w)` compares two vectors lexicographically with `cmp` for the elements.

The answer is that of `cmp` on the first pair of elements at the same
position that are not `EQUAL`; if there is none, the shorter vector is
`LESS`.

**Example** `collate Int.compare (fromList [1], fromList [1, 0]) = LESS`

<details><summary>Tests (13)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `equal` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model-*` &middot; `reflexive-*` &middot; `long`

</details>

## See also

[`ARRAY`](../sig/ARRAY.md), [`VECTOR_SLICE`](../sig/VECTOR_SLICE.md), [`MONO_VECTOR`](../sig/MONO_VECTOR.md), [`LIST`](../sig/LIST.md)

---

<sub>Generated by runedoc from lib/basis/sig\_vector.sml; do not edit.</sub>
