# signature ARRAY_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; **ARRAY_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 26 entries documented |
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

signature ARRAY\_SLICE, transcribed from
<https://smlfamily.github.io/Basis/array-slice.html>

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

<details><summary>Tests (39)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-at-length` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-one-at-length` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `empty-array-NONE` &middot; `empty-array-SOME` &middot; `empty-array-NONE-Subscript` (raises Subscript) &middot; `empty-array-SOME-Subscript` (raises Subscript) &middot; `of-the-array-itself` &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-and-most` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-length"></a>`length`

```sml
val length : 'a slice -> int
```

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `full` &middot; `middle` &middot; `NONE` &middot; `empty` &middot; `empty-array` &middot; `is-third-of-base` &middot; `model-*`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a slice * int -> 'a
```

<details><summary>Tests (13)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first` &middot; `middle` &middot; `last` &middot; `sees-Array.update` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-beyond-the-array` (raises Subscript) &middot; `Subscript-before-the-array` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-full` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-update"></a>`update`

```sml
val update : 'a slice * int * 'a -> unit
```

<details><summary>Tests (14)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first` &middot; `last` &middot; `twice-same-index` &middot; `seen-by-sub` &middot; `seen-through-another-slice` &middot; `full` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-beyond-the-array` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-full"></a>`full`

```sml
val full : 'a Array.array -> 'a slice
```

<details><summary>Tests (6)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `basic` &middot; `base` &middot; `empty-array` &middot; `is-slice-0-NONE` &middot; `of-the-array-itself` &middot; `model-*`

</details>

### <a name="val-slice"></a>`slice`

```sml
val slice : 'a Array.array * int * int option -> 'a slice
```

<details><summary>Tests (39)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-at-length` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-one-at-length` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `empty-array-NONE` &middot; `empty-array-SOME` &middot; `empty-array-NONE-Subscript` (raises Subscript) &middot; `empty-array-SOME-Subscript` (raises Subscript) &middot; `of-the-array-itself` &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-and-most` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : 'a slice * int * int option -> 'a slice
```

<details><summary>Tests (31)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `of-subslice` &middot; `of-empty` &middot; `of-empty-Subscript` (raises Subscript) &middot; `of-the-same-array` &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-base"></a>`base`

```sml
val base : 'a slice -> 'a Array.array * int * int
```

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `middle` &middot; `empty` &middot; `the-array-itself` &middot; `model-*`

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a slice -> 'a Vector.vector
```

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `middle` &middot; `full` &middot; `empty` &middot; `equals-tabulate` &middot; `is-a-snapshot` &middot; `model-*` &middot; `long`

</details>

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : 'a slice, dst : 'a Array.array, di : int} -> unit
```

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

<details><summary>Tests (6)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `empty` &middot; `empty-array` &middot; `at-length` &middot; `one` &middot; `middle` &middot; `model-*`

</details>

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : 'a slice -> ('a * 'a slice) option
```

<details><summary>Tests (9)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `middle` &middot; `full` &middot; `one` &middot; `last-of-the-array` &middot; `empty` &middot; `empty-array` &middot; `repeated` &middot; `rest-of-the-same-array` &middot; `model-*`

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * 'a -> unit) -> 'a slice -> unit
```

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `index-in-the-slice` &middot; `full` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a slice -> unit
```

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `order` &middot; `empty` &middot; `array-unchanged` &middot; `model-*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * 'a -> 'a) -> 'a slice -> unit
```

<details><summary>Tests (5)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `index-in-the-slice` &middot; `full` &middot; `empty` &middot; `order` &middot; `model-*`

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : ('a -> 'a) -> 'a slice -> unit
```

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `basic` &middot; `empty` &middot; `order` &middot; `twice` &middot; `seen-by-the-slice` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

<details><summary>Tests (5)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

<details><summary>Tests (5)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long-list`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a slice -> (int * 'a) option
```

<details><summary>Tests (9)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `not-before-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a slice -> 'a option
```

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first-match` &middot; `last-element` &middot; `none` &middot; `not-before-the-slice` &middot; `empty` &middot; `stops` &middot; `model-*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a slice -> bool
```

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `true` &middot; `false` &middot; `not-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a slice -> bool
```

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `de-morgan-*`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a slice * 'a slice -> order
```

<details><summary>Tests (16)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `equal-elements` &middot; `parts-of-one-array` &middot; `same-slice` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `ends-with-the-slice` &middot; `starts-with-the-slice` &middot; `given-ordering` &middot; `argument-order` &middot; `model-*` &middot; `long`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_array\_slice.sml; do not edit.</sub>
