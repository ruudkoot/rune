# signature ARRAY_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **ARRAY_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 26 of 26 entries documented |
| Tests | 309 checks of 26 entries |
| Source | [lib/basis/sig\_array\_slice.sml](../../../../lib/basis/sig_array_slice.sml) |

## Synopsis

```sml
signature ARRAY_SLICE
structure ArraySlice : ARRAY_SLICE
```

| Implementation |  | Source |
| --- | --- | --- |
| `ArraySlice` | ArraySlice: an array, a start index and a length. The -i functions pass the index in the slice. | [lib/basis/arrayslice.sml](../../../../lib/basis/arrayslice.sml) |

A stretch of an array, without a copy of it: a base array and a start and
a length inside it.

What [`VECTOR_SLICE`](../sig/VECTOR_SLICE.md) is to a vector, this is to an array: a way to hand
part of a sequence to a function for nothing. A slice is a window on the
array, not a copy of it, so [`update`](#val-update) through the slice changes the array,
and a change to the array is seen through the slice.

Positions inside a slice are counted from its own start.

## Contents

[Elements](#elements) &middot;
[Making a slice](#making-a-slice) &middot;
[Copying](#copying) &middot;
[Traversing](#traversing) &middot;
[Searching](#searching)

## Interface

<pre>
signature ARRAY_SLICE =
sig
  type 'a <a href="#type-slice">slice</a>

  val <a href="#val-length">length</a> : 'a slice -&gt; int

  val <a href="#val-sub">sub</a> : 'a slice * int -&gt; 'a

  val <a href="#val-update">update</a> : 'a slice * int * 'a -&gt; unit

  val <a href="#val-full">full</a> : 'a Array.array -&gt; 'a slice

  val <a href="#val-slice">slice</a> : 'a Array.array * int * int option -&gt; 'a slice

  val <a href="#val-subslice">subslice</a> : 'a slice * int * int option -&gt; 'a slice

  val <a href="#val-base">base</a> : 'a slice -&gt; 'a Array.array * int * int

  val <a href="#val-vector">vector</a> : 'a slice -&gt; 'a Vector.vector

  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : 'a slice, <a href="#fld-copy.dst">dst</a> : 'a Array.array, <a href="#fld-copy.di">di</a> : int} -&gt; unit

  val <a href="#val-copyvec">copyVec</a> : {<a href="#fld-copyvec.src">src</a> : 'a VectorSlice.slice, <a href="#fld-copyvec.dst">dst</a> : 'a Array.array, <a href="#fld-copyvec.di">di</a> : int} -&gt; unit

  val <a href="#val-isempty">isEmpty</a> : 'a slice -&gt; bool

  val <a href="#val-getitem">getItem</a> : 'a slice -&gt; ('a * 'a slice) option

  val <a href="#val-appi">appi</a> : (int * 'a -&gt; unit) -&gt; 'a slice -&gt; unit

  val <a href="#val-app">app</a> : ('a -&gt; unit) -&gt; 'a slice -&gt; unit

  val <a href="#val-modifyi">modifyi</a> : (int * 'a -&gt; 'a) -&gt; 'a slice -&gt; unit

  val <a href="#val-modify">modify</a> : ('a -&gt; 'a) -&gt; 'a slice -&gt; unit

  val <a href="#val-foldli">foldli</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a slice -&gt; 'b

  val <a href="#val-foldri">foldri</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a slice -&gt; 'b

  val <a href="#val-foldl">foldl</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a slice -&gt; 'b

  val <a href="#val-foldr">foldr</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a slice -&gt; 'b

  val <a href="#val-findi">findi</a> : (int * 'a -&gt; bool) -&gt; 'a slice -&gt; (int * 'a) option

  val <a href="#val-find">find</a> : ('a -&gt; bool) -&gt; 'a slice -&gt; 'a option

  val <a href="#val-exists">exists</a> : ('a -&gt; bool) -&gt; 'a slice -&gt; bool

  val <a href="#val-all">all</a> : ('a -&gt; bool) -&gt; 'a slice -&gt; bool

  val <a href="#val-collate">collate</a> : ('a * 'a -&gt; order) -&gt; 'a slice * 'a slice -&gt; order
end
</pre>

### <a name="type-slice"></a>`slice`

```sml
type 'a slice
```

The type of slices of an array.

<details><summary>Tests (39)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-at-length` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-one-at-length` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `empty-array-NONE` &middot; `empty-array-SOME` &middot; `empty-array-NONE-Subscript` (raises Subscript) &middot; `empty-array-SOME-Subscript` (raises Subscript) &middot; `of-the-array-itself` &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-and-most` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

## Elements

### <a name="val-length"></a>`length`

```sml
val length : 'a slice -> int
```

`length sl` is the number of elements of `sl`.

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `full` &middot; `middle` &middot; `NONE` &middot; `empty` &middot; `empty-array` &middot; `is-third-of-base` &middot; `model-*`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a slice * int -> 'a
```

`sub (sl, i)` is the element of `sl` at position `i`, counting from the start of the slice.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length sl`.

<details><summary>Tests (13)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first` &middot; `middle` &middot; `last` &middot; `sees-Array.update` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-beyond-the-array` (raises Subscript) &middot; `Subscript-before-the-array` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-full` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-update"></a>`update`

```sml
val update : 'a slice * int * 'a -> unit
```

`update (sl, i, x)` puts `x` at position `i` of `sl`, and so of the array it is a slice of.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length sl`.

<details><summary>Tests (14)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first` &middot; `last` &middot; `twice-same-index` &middot; `seen-by-sub` &middot; `seen-through-another-slice` &middot; `full` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-beyond-the-array` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

## Making a slice

### <a name="val-full"></a>`full`

```sml
val full : 'a Array.array -> 'a slice
```

`full arr` is the whole of `arr` as a slice.

<details><summary>Tests (6)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `basic` &middot; `base` &middot; `empty-array` &middot; `is-slice-0-NONE` &middot; `of-the-array-itself` &middot; `model-*`

</details>

### <a name="val-slice"></a>`slice`

```sml
val slice : 'a Array.array * int * int option -> 'a slice
```

`slice (arr, i, NONE)` is the stretch of `arr` from position `i` to its end, and `slice (arr, i, SOME n)` the `n` elements from `i`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the positions are outside `arr`.

<details><summary>Tests (39)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-at-length` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-one-at-length` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `empty-array-NONE` &middot; `empty-array-SOME` &middot; `empty-array-NONE-Subscript` (raises Subscript) &middot; `empty-array-SOME-Subscript` (raises Subscript) &middot; `of-the-array-itself` &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-and-most` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : 'a slice * int * int option -> 'a slice
```

`subslice (sl, i, NONE)` is the stretch of `sl` from position `i` on, and `subslice (sl, i, SOME n)` the `n` elements from `i`.

The bounds are those of `sl`, not of the array it is a slice of.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the positions are outside `sl`.

<details><summary>Tests (31)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `of-subslice` &middot; `of-empty` &middot; `of-empty-Subscript` (raises Subscript) &middot; `of-the-same-array` &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-base"></a>`base`

```sml
val base : 'a slice -> 'a Array.array * int * int
```

`base sl` is the triple of the array that `sl` is a stretch of, where it starts in that array, and how long it is.

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `middle` &middot; `empty` &middot; `the-array-itself` &middot; `model-*`

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a slice -> 'a Vector.vector
```

`vector sl` is an immutable vector of the elements of `sl`, which is a copy.

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `middle` &middot; `full` &middot; `empty` &middot; `equals-tabulate` &middot; `is-a-snapshot` &middot; `model-*` &middot; `long`

</details>

## Copying

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : 'a slice, dst : 'a Array.array, di : int} -> unit
```

`copy {src, dst, di}` copies the elements of the slice `src` into the array `dst`, starting at position `di`.

The slice may be a stretch of `dst` itself and the two may overlap:
every element arrives as it was before the copy began.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `di < 0` or `di + length src > Array.length dst`,
and then nothing has been copied.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `'a slice` |  |
| <a name="fld-copy.dst"></a>`dst` | `'a Array.array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

<details><summary>Tests (31)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `field-order` &middot; `src-unchanged` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `overlap-to-the-right` &middot; `overlap-one-to-the-right` &middot; `overlap-onto-itself` &middot; `overlap-one-to-the-left` &middot; `overlap-to-the-left` &middot; `overlap-to-the-end` &middot; `overlap-Subscript` (raises Subscript) &middot; `same-array-apart` &middot; `full-onto-itself` &middot; `full-onto-itself-shifted-Subscript` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `within-model-*` &middot; `within-model-*` (raises Subscript) &middot; `long-overlap` &middot; `Subscript-not-Overflow-sum` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : 'a VectorSlice.slice, dst : 'a Array.array, di : int} -> unit
```

`copyVec {src, dst, di}` copies the elements of the vector slice `src` into `dst`, starting at position `di`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if they do not fit, and then nothing has been
copied.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `'a VectorSlice.slice` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `'a Array.array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

<details><summary>Tests (19)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `full-vector` &middot; `field-order` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `Subscript-not-Overflow-sum` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : 'a slice -> bool
```

`isEmpty sl` is `true` when `sl` has no elements.

<details><summary>Tests (6)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `empty` &middot; `empty-array` &middot; `at-length` &middot; `one` &middot; `middle` &middot; `model-*`

</details>

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : 'a slice -> ('a * 'a slice) option
```

`getItem sl` is `NONE` for an empty slice and `SOME (x, rest)` for the first element and what follows it.

<details><summary>Tests (9)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `middle` &middot; `full` &middot; `one` &middot; `last-of-the-array` &middot; `empty` &middot; `empty-array` &middot; `repeated` &middot; `rest-of-the-same-array` &middot; `model-*`

</details>

## Traversing

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * 'a -> unit) -> 'a slice -> unit
```

`appi f sl` applies `f` to the index and the element of each position, from 0 up, for its effect.

The index is that of the element in the slice, counted from 0.

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `index-in-the-slice` &middot; `full` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a slice -> unit
```

`app f sl` applies `f` to every element, from 0 up, for its effect.

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `order` &middot; `empty` &middot; `array-unchanged` &middot; `model-*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * 'a -> 'a) -> 'a slice -> unit
```

`modifyi f sl` replaces the element at each position by `f` of the index and that element, in place.

<details><summary>Tests (5)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `index-in-the-slice` &middot; `full` &middot; `empty` &middot; `order` &middot; `model-*`

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : ('a -> 'a) -> 'a slice -> unit
```

`modify f sl` replaces every element by `f` of it, in place, from 0 up.

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `basic` &middot; `empty` &middot; `order` &middot; `twice` &middot; `seen-by-the-slice` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

`foldli f init sl` combines the elements from the left, giving `f` the index as well.

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

`foldri f init sl` combines the elements from the right, giving `f` the index as well.

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

`foldl f init sl` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

<details><summary>Tests (5)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

`foldr f init sl` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

<details><summary>Tests (5)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long-list`

</details>

## Searching

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a slice -> (int * 'a) option
```

`findi p sl` is `SOME (i, x)` for the first position whose index and element satisfy `p`, or `NONE`.

<details><summary>Tests (9)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `not-before-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a slice -> 'a option
```

`find p sl` is `SOME x` for the first element that satisfies `p`, or `NONE`.

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first-match` &middot; `last-element` &middot; `none` &middot; `not-before-the-slice` &middot; `empty` &middot; `stops` &middot; `model-*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a slice -> bool
```

`exists p sl` is `true` when some element satisfies `p`.

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `true` &middot; `false` &middot; `not-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a slice -> bool
```

`all p sl` is `true` when every element satisfies `p`.

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `de-morgan-*`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a slice * 'a slice -> order
```

`collate cmp (sl, tl)` compares the elements of two slices lexicographically with `cmp`.

<details><summary>Tests (16)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `equal-elements` &middot; `parts-of-one-array` &middot; `same-slice` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `ends-with-the-slice` &middot; `starts-with-the-slice` &middot; `given-ordering` &middot; `argument-order` &middot; `model-*` &middot; `long`

</details>

## See also

[`ARRAY`](../sig/ARRAY.md), [`VECTOR_SLICE`](../sig/VECTOR_SLICE.md), [`MONO_ARRAY_SLICE`](../sig/MONO_ARRAY_SLICE.md)

---

<sub>Generated by runedoc from lib/basis/sig\_array\_slice.sml; do not edit.</sub>
