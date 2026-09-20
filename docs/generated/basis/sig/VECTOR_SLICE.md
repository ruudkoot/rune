# signature VECTOR_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; **VECTOR_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 24 entries documented |
| Tests | 243 checks of 24 entries |
| Source | [lib/basis/sig\_vector\_slice.sml](../../../../lib/basis/sig_vector_slice.sml) |

## Synopsis

```sml
signature VECTOR_SLICE
structure VectorSlice : VECTOR_SLICE
```

| Implementation |  | Source |
| --- | --- | --- |
| `VectorSlice` | VectorSlice: a vector, a start index and a length. The -i functions pass the index in the slice. | [lib/basis/vectorslice.sml](../../../../lib/basis/vectorslice.sml) |

signature VECTOR\_SLICE, transcribed from
<https://smlfamily.github.io/Basis/vector-slice.html>

## Interface

<pre>
signature VECTOR_SLICE =
sig
  type 'a <a href="#type-slice">slice</a>

  val <a href="#val-length">length</a> : 'a slice -&gt; int
  val <a href="#val-sub">sub</a> : 'a slice * int -&gt; 'a
  val <a href="#val-full">full</a> : 'a Vector.vector -&gt; 'a slice
  val <a href="#val-slice">slice</a> : 'a Vector.vector * int * int option -&gt; 'a slice
  val <a href="#val-subslice">subslice</a> : 'a slice * int * int option -&gt; 'a slice
  val <a href="#val-base">base</a> : 'a slice -&gt; 'a Vector.vector * int * int
  val <a href="#val-vector">vector</a> : 'a slice -&gt; 'a Vector.vector
  val <a href="#val-concat">concat</a> : 'a slice list -&gt; 'a Vector.vector
  val <a href="#val-isempty">isEmpty</a> : 'a slice -&gt; bool
  val <a href="#val-getitem">getItem</a> : 'a slice -&gt; ('a * 'a slice) option
  val <a href="#val-appi">appi</a> : (int * 'a -&gt; unit) -&gt; 'a slice -&gt; unit
  val <a href="#val-app">app</a> : ('a -&gt; unit) -&gt; 'a slice -&gt; unit
  val <a href="#val-mapi">mapi</a> : (int * 'a -&gt; 'b) -&gt; 'a slice -&gt; 'b Vector.vector
  val <a href="#val-map">map</a> : ('a -&gt; 'b) -&gt; 'a slice -&gt; 'b Vector.vector
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

<details><summary>Tests (38)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-at-length` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-one-at-length` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `empty-vector-NONE` &middot; `empty-vector-SOME` &middot; `empty-vector-NONE-Subscript` (raises Subscript) &middot; `empty-vector-SOME-Subscript` (raises Subscript) &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-and-most` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-length"></a>`length`

```sml
val length : 'a slice -> int
```

<details><summary>Tests (6)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `full` &middot; `middle` &middot; `NONE` &middot; `empty` &middot; `empty-vector` &middot; `model-*`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a slice * int -> 'a
```

<details><summary>Tests (12)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `first` &middot; `middle` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-beyond-the-vector` (raises Subscript) &middot; `Subscript-before-the-vector` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-full` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-full"></a>`full`

```sml
val full : 'a Vector.vector -> 'a slice
```

<details><summary>Tests (5)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `basic` &middot; `base` &middot; `empty-vector` &middot; `is-slice-0-NONE` &middot; `model-*`

</details>

### <a name="val-slice"></a>`slice`

```sml
val slice : 'a Vector.vector * int * int option -> 'a slice
```

<details><summary>Tests (38)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-at-length` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-one-at-length` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `empty-vector-NONE` &middot; `empty-vector-SOME` &middot; `empty-vector-NONE-Subscript` (raises Subscript) &middot; `empty-vector-SOME-Subscript` (raises Subscript) &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-and-most` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : 'a slice * int * int option -> 'a slice
```

<details><summary>Tests (30)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `of-subslice` &middot; `of-empty` &middot; `of-empty-Subscript` (raises Subscript) &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-base"></a>`base`

```sml
val base : 'a slice -> 'a Vector.vector * int * int
```

<details><summary>Tests (4)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `middle` &middot; `empty` &middot; `round-trip` &middot; `model-*`

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a slice -> 'a Vector.vector
```

<details><summary>Tests (6)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `middle` &middot; `full` &middot; `empty` &middot; `equals-tabulate` &middot; `model-*` &middot; `long`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : 'a slice list -> 'a Vector.vector
```

<details><summary>Tests (9)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `nil` &middot; `one` &middot; `empty-slices` &middot; `order` &middot; `same-slice-twice` &middot; `overlapping` &middot; `model-*` &middot; `many` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : 'a slice -> bool
```

<details><summary>Tests (6)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `empty` &middot; `empty-vector` &middot; `at-length` &middot; `one` &middot; `middle` &middot; `model-*`

</details>

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : 'a slice -> ('a * 'a slice) option
```

<details><summary>Tests (8)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `middle` &middot; `full` &middot; `one` &middot; `last-of-the-vector` &middot; `empty` &middot; `empty-vector` &middot; `repeated` &middot; `model-*`

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * 'a -> unit) -> 'a slice -> unit
```

<details><summary>Tests (4)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `index-in-the-slice` &middot; `full` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a slice -> unit
```

<details><summary>Tests (3)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `order` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * 'a -> 'b) -> 'a slice -> 'b Vector.vector
```

<details><summary>Tests (4)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `index-in-the-slice` &middot; `empty` &middot; `order` &middot; `model-*`

</details>

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a slice -> 'b Vector.vector
```

<details><summary>Tests (7)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `basic` &middot; `empty` &middot; `order` &middot; `other-type` &middot; `vector-unchanged` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

<details><summary>Tests (4)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

<details><summary>Tests (4)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

<details><summary>Tests (5)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

<details><summary>Tests (5)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long-list`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a slice -> (int * 'a) option
```

<details><summary>Tests (9)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `not-before-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a slice -> 'a option
```

<details><summary>Tests (7)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `first-match` &middot; `last-element` &middot; `none` &middot; `not-before-the-slice` &middot; `empty` &middot; `stops` &middot; `model-*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a slice -> bool
```

<details><summary>Tests (7)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `true` &middot; `false` &middot; `not-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a slice -> bool
```

<details><summary>Tests (7)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `de-morgan-*`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a slice * 'a slice -> order
```

<details><summary>Tests (15)</summary>

For `VectorSlice`, in [tests/basis/vectorslice.sml](../../../../tests/basis/vectorslice.sml): `equal-parts-of-one-vector` &middot; `same-slice` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `ends-with-the-slice` &middot; `starts-with-the-slice` &middot; `given-ordering` &middot; `argument-order` &middot; `model-*` &middot; `long`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_vector\_slice.sml; do not edit.</sub>
