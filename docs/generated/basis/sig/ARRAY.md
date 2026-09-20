# signature ARRAY

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **ARRAY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 25 of 25 entries documented |
| Tests | 235 checks of 25 entries |
| Source | [lib/basis/sig\_array.sml](../../../../lib/basis/sig_array.sml) |

## Synopsis

```sml
signature ARRAY
structure Array : ARRAY
```

| Implementation |  | Source |
| --- | --- | --- |
| `Array` | Array: mutable arrays with identity equality. | [lib/basis/array.sml](../../../../lib/basis/array.sml) |

Arrays: mutable sequences of a fixed length, of any element type.

An array is indexed from 0; [`update`](#val-update) changes an element in place, and two
arrays are equal only when they are the same array, whatever they hold. An
array of length 0 is still an array of its own, so `array (0, x) = array (0, x)` is `false`.

[`VECTOR`](../sig/VECTOR.md) is the immutable counterpart, and [`vector`](#val-vector) and [`copyVec`](#val-copyvec) convert
between the two. [`ARRAY_SLICE`](../sig/ARRAY_SLICE.md) describes a stretch of an array without
copying it, and [`ARRAY2`](../sig/ARRAY2.md) is the two-dimensional version.

> **Erratum** `ARRAY/array-spec`. The specification writes `eqtype 'a array = 'a array`, which the Definition does not allow as a specification; it is
> written here as an abbreviation of the top-level [`array`](#val-array), which admits
> equality whatever its element type is.

## Contents

[Making an array](#making-an-array) &middot;
[Elements](#elements) &middot;
[Copying](#copying) &middot;
[Traversing](#traversing) &middot;
[Searching](#searching)

## Interface

<pre>
signature ARRAY =
sig
  type 'a <a href="#type-array">array</a> = 'a array

  type 'a <a href="#type-vector">vector</a> = 'a Vector.vector

  val <a href="#val-maxlen">maxLen</a> : int

  val <a href="#val-array">array</a> : int * 'a -&gt; 'a array

  val <a href="#val-fromlist">fromList</a> : 'a list -&gt; 'a array

  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; 'a) -&gt; 'a array

  val <a href="#val-length">length</a> : 'a array -&gt; int

  val <a href="#val-sub">sub</a> : 'a array * int -&gt; 'a

  val <a href="#val-update">update</a> : 'a array * int * 'a -&gt; unit

  val <a href="#val-vector">vector</a> : 'a array -&gt; 'a vector

  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : 'a array, <a href="#fld-copy.dst">dst</a> : 'a array, <a href="#fld-copy.di">di</a> : int} -&gt; unit

  val <a href="#val-copyvec">copyVec</a> : {<a href="#fld-copyvec.src">src</a> : 'a vector, <a href="#fld-copyvec.dst">dst</a> : 'a array, <a href="#fld-copyvec.di">di</a> : int} -&gt; unit

  val <a href="#val-appi">appi</a> : (int * 'a -&gt; unit) -&gt; 'a array -&gt; unit

  val <a href="#val-app">app</a> : ('a -&gt; unit) -&gt; 'a array -&gt; unit

  val <a href="#val-modifyi">modifyi</a> : (int * 'a -&gt; 'a) -&gt; 'a array -&gt; unit

  val <a href="#val-modify">modify</a> : ('a -&gt; 'a) -&gt; 'a array -&gt; unit

  val <a href="#val-foldli">foldli</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a array -&gt; 'b

  val <a href="#val-foldri">foldri</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a array -&gt; 'b

  val <a href="#val-foldl">foldl</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a array -&gt; 'b

  val <a href="#val-foldr">foldr</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a array -&gt; 'b

  val <a href="#val-findi">findi</a> : (int * 'a -&gt; bool) -&gt; 'a array -&gt; (int * 'a) option

  val <a href="#val-find">find</a> : ('a -&gt; bool) -&gt; 'a array -&gt; 'a option

  val <a href="#val-exists">exists</a> : ('a -&gt; bool) -&gt; 'a array -&gt; bool

  val <a href="#val-all">all</a> : ('a -&gt; bool) -&gt; 'a array -&gt; bool

  val <a href="#val-collate">collate</a> : ('a * 'a -&gt; order) -&gt; 'a array * 'a array -&gt; order
end
</pre>

### <a name="type-array"></a>`array`

```sml
type 'a array = 'a array
```

The type of arrays, the one of the top-level environment.

Two arrays are equal when they are the same array: equality is identity,
not a comparison of the elements.

<details><summary>Tests (23)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `zero` &middot; `one` &middot; `length` &middot; `Size-negative` (raises Size) &middot; `elements-are-separate` &middot; `every-element-is-init` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `unequal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `of-reals-same` &middot; `of-reals-not-equal` &middot; `of-functions-same` &middot; `in-a-list` &middot; `is-toplevel` &middot; `model-*` &middot; `identity-*` &middot; `long` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="type-vector"></a>`vector`

```sml
type 'a vector = 'a Vector.vector
```

The type of the vectors that [`vector`](#val-vector) and [`copyVec`](#val-copyvec) work with.

<details><summary>Tests (10)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `empty` &middot; `equals-tabulate` &middot; `after-update` &middot; `is-a-snapshot` &middot; `is-Vector.vector` &middot; `structural-equality` &middot; `model-*` &middot; `fromList-*` &middot; `long`

</details>

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

The greatest length an array may have.

> **Implementation** `Array.maxLen/value`. 100000000, the same as
> [`Vector.maxLen`](../sig/VECTOR.md#val-maxlen).

<details><summary>Tests (1)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `covers-created-arrays`

</details>

## Making an array

### <a name="val-array"></a>`array`

```sml
val array : int * 'a -> 'a array
```

`array (n, x)` is a new array of `n` elements, each of them `x`.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0` or `n > maxLen`.

<details><summary>Tests (23)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `zero` &middot; `one` &middot; `length` &middot; `Size-negative` (raises Size) &middot; `elements-are-separate` &middot; `every-element-is-init` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `unequal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `of-reals-same` &middot; `of-reals-not-equal` &middot; `of-functions-same` &middot; `in-a-list` &middot; `is-toplevel` &middot; `model-*` &middot; `identity-*` &middot; `long` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : 'a list -> 'a array
```

`fromList l` is a new array of the elements of `l`, in order.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `l` is longer than [`maxLen`](#val-maxlen).

<details><summary>Tests (9)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `nil` &middot; `singleton` &middot; `length` &middot; `strings` &middot; `same-elements-not-equal` &middot; `zero-length-not-equal` &middot; `round-trip-*` &middot; `long`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> 'a) -> 'a array
```

`tabulate (n, f)` is a new array of `f 0`, `f 1`, ..., `f (n - 1)`.

`f` is applied in order of increasing index.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0` or `n > maxLen`, before `f` is applied at all.

<details><summary>Tests (10)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `zero` &middot; `one` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f` &middot; `same-elements-not-equal` &middot; `zero-length-not-equal` &middot; `model-*` &middot; `Size-above-maxLen` (raises Size)

</details>

## Elements

### <a name="val-length"></a>`length`

```sml
val length : 'a array -> int
```

`length arr` is the number of elements of `arr`.

<details><summary>Tests (5)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `empty` &middot; `five` &middot; `tabulate` &middot; `model-*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a array * int -> 'a
```

`sub (arr, i)` is the element of `arr` at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length arr`.

<details><summary>Tests (9)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `first` &middot; `middle` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

### <a name="val-update"></a>`update`

```sml
val update : 'a array * int * 'a -> unit
```

`update (arr, i, x)` puts `x` at position `i` of `arr`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length arr`.

<details><summary>Tests (12)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `first` &middot; `middle` &middot; `last` &middot; `twice-same-index` &middot; `seen-by-sub` &middot; `seen-through-alias` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model-*` &middot; `model-*` (raises Subscript)

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a array -> 'a vector
```

`vector arr` is an immutable vector of the elements of `arr`.

It is a copy: a later [`update`](#val-update) of `arr` does not touch it.

<details><summary>Tests (10)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `empty` &middot; `equals-tabulate` &middot; `after-update` &middot; `is-a-snapshot` &middot; `is-Vector.vector` &middot; `structural-equality` &middot; `model-*` &middot; `fromList-*` &middot; `long`

</details>

## Copying

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : 'a array, dst : 'a array, di : int} -> unit
```

`copy {src, dst, di}` copies the elements of `src` into `dst`, starting at position `di`.

`src` and `dst` may be the same array and the stretches may overlap:
every element arrives as it was before the copy began.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `di < 0` or `di + length src > length dst`, and
then nothing has been copied.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `'a array` |  |
| <a name="fld-copy.dst"></a>`dst` | `'a array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

<details><summary>Tests (21)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `field-order` &middot; `src-unchanged` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `copies-elements-not-the-array` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `onto-itself` &middot; `Subscript-onto-itself-shifted` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : 'a vector, dst : 'a array, di : int} -> unit
```

`copyVec {src, dst, di}` copies the elements of the vector `src` into `dst`, starting at position `di`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `di < 0` or `di + Vector.length src > length dst`,
and then nothing has been copied.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `'a vector` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `'a array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

<details><summary>Tests (19)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `field-order` &middot; `src-unchanged` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `from-Array.vector` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

## Traversing

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * 'a -> unit) -> 'a array -> unit
```

`appi f arr` applies `f` to the index and the element of each position, from 0 up, for its effect.

<details><summary>Tests (3)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `order` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a array -> unit
```

`app f arr` applies `f` to every element, from 0 up, for its effect.

<details><summary>Tests (4)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `order` &middot; `empty` &middot; `array-unchanged` &middot; `model-*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * 'a -> 'a) -> 'a array -> unit
```

`modifyi f arr` replaces the element at each position by `f` of the index and that element.

The array is changed in place, from 0 up.

<details><summary>Tests (6)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `index-and-element` &middot; `empty` &middot; `order` &middot; `model-*` &middot; `long`

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : ('a -> 'a) -> 'a array -> unit
```

`modify f arr` replaces every element by `f` of it, in place, from 0 up.

<details><summary>Tests (7)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `empty` &middot; `order` &middot; `twice` &middot; `is-modifyi-of-second` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

`foldli f init arr` combines the elements from the left, giving `f` the index as well.

<details><summary>Tests (4)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

`foldri f init arr` combines the elements from the right, giving `f` the index as well.

<details><summary>Tests (4)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

`foldl f init arr` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

<details><summary>Tests (6)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `array-unchanged` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

`foldr f init arr` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

<details><summary>Tests (6)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long` &middot; `long-list`

</details>

## Searching

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a array -> (int * 'a) option
```

`findi p arr` is `SOME (i, x)` for the first position whose index and element satisfy `p`, or `NONE`.

<details><summary>Tests (8)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a array -> 'a option
```

`find p arr` is `SOME x` for the first element that satisfies `p`, or `NONE`.

<details><summary>Tests (7)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `first-match` &middot; `last-element` &middot; `none` &middot; `empty` &middot; `stops` &middot; `model-*` &middot; `long`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a array -> bool
```

`exists p arr` is `true` when some element satisfies `p`; it stops at the first that does.

<details><summary>Tests (6)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a array -> bool
```

`all p arr` is `true` when every element satisfies `p`; it stops at the first that does not.

<details><summary>Tests (8)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `de-morgan-*` &middot; `long`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a array * 'a array -> order
```

`collate cmp (a, b)` compares the elements of two arrays lexicographically with `cmp`.

This compares what the arrays hold, where `=` compares which array it
is.

<details><summary>Tests (14)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `equal` &middot; `same-array` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model-*` &middot; `reflexive-*` &middot; `long`

</details>

## See also

[`VECTOR`](../sig/VECTOR.md), [`ARRAY_SLICE`](../sig/ARRAY_SLICE.md), [`ARRAY2`](../sig/ARRAY2.md), [`MONO_ARRAY`](../sig/MONO_ARRAY.md), [`LIST`](../sig/LIST.md)

---

<sub>Generated by runedoc from lib/basis/sig\_array.sml; do not edit.</sub>
