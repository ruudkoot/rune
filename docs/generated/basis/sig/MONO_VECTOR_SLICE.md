# signature MONO_VECTOR_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **MONO_VECTOR_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 19 |
| Documentation | 26 of 26 entries documented |
| Tests | 322 checks of 26 entries |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_VECTOR_SLICE
structure BoolVectorSlice : MONO_VECTOR_SLICE where type vector = BoolVector.vector where type elem = bool  (* optional *)
structure CharVectorSlice : MONO_VECTOR_SLICE where type slice = Substring.substring where type vector = String.string where type elem = char
structure Int16VectorSlice : MONO_VECTOR_SLICE where type vector = Int16Vector.vector where type elem = Int16.int  (* optional *)
structure Int32VectorSlice : MONO_VECTOR_SLICE where type vector = Int32Vector.vector where type elem = Int32.int  (* optional *)
structure Int64VectorSlice : MONO_VECTOR_SLICE where type vector = Int64Vector.vector where type elem = Int64.int  (* optional *)
structure Int8VectorSlice : MONO_VECTOR_SLICE where type vector = Int8Vector.vector where type elem = Int8.int  (* optional *)
structure IntVectorSlice : MONO_VECTOR_SLICE where type vector = IntVector.vector where type elem = int  (* optional *)
structure LargeIntVectorSlice : MONO_VECTOR_SLICE where type vector = LargeIntVector.vector where type elem = LargeInt.int  (* optional *)
structure LargeRealVectorSlice : MONO_VECTOR_SLICE where type vector = LargeRealVector.vector where type elem = LargeReal.real  (* optional *)
structure LargeWordVectorSlice : MONO_VECTOR_SLICE where type vector = LargeWordVector.vector where type elem = LargeWord.word  (* optional *)
structure Real32VectorSlice : MONO_VECTOR_SLICE where type vector = Real32Vector.vector where type elem = Real32.real  (* optional *)
structure Real64VectorSlice : MONO_VECTOR_SLICE where type vector = Real64Vector.vector where type elem = Real64.real  (* optional *)
structure RealVectorSlice : MONO_VECTOR_SLICE where type vector = RealVector.vector where type elem = real  (* optional *)
structure WideCharVectorSlice : MONO_VECTOR_SLICE where type vector = WideCharVector.vector where type elem = WideChar.char  (* optional *)
structure Word16VectorSlice : MONO_VECTOR_SLICE where type vector = Word16Vector.vector where type elem = Word16.word  (* optional *)
structure Word32VectorSlice : MONO_VECTOR_SLICE where type vector = Word32Vector.vector where type elem = Word32.word  (* optional *)
structure Word64VectorSlice : MONO_VECTOR_SLICE where type vector = Word64Vector.vector where type elem = Word64.word  (* optional *)
structure Word8VectorSlice : MONO_VECTOR_SLICE where type vector = Word8Vector.vector where type elem = Word8.word
structure WordVectorSlice : MONO_VECTOR_SLICE where type vector = WordVector.vector where type elem = word  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `BoolVectorSlice` |  | [lib/basis/mono\_bool.sml](../../../../lib/basis/mono_bool.sml) |
| `CharVectorSlice` | CharVectorSlice: its slice is the substring of Substring, so it is written on Substring rather than being an instance of RuneMonoVectorSliceFn. The \-i functions pass the index in the slice. | [lib/basis/charvectorslice.sml](../../../../lib/basis/charvectorslice.sml) |
| `Int16VectorSlice` |  | [lib/basis/mono\_int16.sml](../../../../lib/basis/mono_int16.sml) |
| `Int32VectorSlice` |  | [lib/basis/mono\_int32.sml](../../../../lib/basis/mono_int32.sml) |
| `Int64VectorSlice` |  | [lib/basis/mono\_int64.sml](../../../../lib/basis/mono_int64.sml) |
| `Int8VectorSlice` |  | [lib/basis/mono\_int8.sml](../../../../lib/basis/mono_int8.sml) |
| `IntVectorSlice` |  | [lib/basis/mono\_int.sml](../../../../lib/basis/mono_int.sml) |
| `LargeIntVectorSlice` |  | [lib/basis/mono\_largeint.sml](../../../../lib/basis/mono_largeint.sml) |
| `LargeRealVectorSlice` |  | [lib/basis/mono\_largereal.sml](../../../../lib/basis/mono_largereal.sml) |
| `LargeWordVectorSlice` |  | [lib/basis/mono\_largeword.sml](../../../../lib/basis/mono_largeword.sml) |
| `Real32VectorSlice` |  | [lib/basis/mono\_real32.sml](../../../../lib/basis/mono_real32.sml) |
| `Real64VectorSlice` |  | [lib/basis/mono\_real64.sml](../../../../lib/basis/mono_real64.sml) |
| `RealVectorSlice` |  | [lib/basis/mono\_real.sml](../../../../lib/basis/mono_real.sml) |
| `WideCharVectorSlice` |  | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |
| `Word16VectorSlice` |  | [lib/basis/mono\_word16.sml](../../../../lib/basis/mono_word16.sml) |
| `Word32VectorSlice` |  | [lib/basis/mono\_word32.sml](../../../../lib/basis/mono_word32.sml) |
| `Word64VectorSlice` |  | [lib/basis/mono\_word64.sml](../../../../lib/basis/mono_word64.sml) |
| `Word8VectorSlice` | Word8VectorSlice: a Word8Vector.vector is a string, so a slice of one is a substring, and taking its vector is one primitive rather than a walk over the elements. | [lib/basis/word8vectorslice.sml](../../../../lib/basis/word8vectorslice.sml) |
| `WordVectorSlice` |  | [lib/basis/mono\_word.sml](../../../../lib/basis/mono_word.sml) |

A stretch of a vector of one element type, without a copy of it.

> **Implementation** `CharVectorSlice.slice/substring`. The slice of a vector
> of characters is [`Substring.substring`](../sig/SUBSTRING.md#val-substring), and the slice of one of bytes is a
> substring too.

## Interface

<pre>
signature MONO_VECTOR_SLICE =
sig
  type <a href="#type-elem">elem</a>

  type <a href="#type-vector">vector</a>

  type <a href="#type-slice">slice</a>

  val <a href="#val-length">length</a> : slice -&gt; int

  val <a href="#val-sub">sub</a> : slice * int -&gt; elem

  val <a href="#val-full">full</a> : vector -&gt; slice

  val <a href="#val-slice">slice</a> : vector * int * int option -&gt; slice

  val <a href="#val-subslice">subslice</a> : slice * int * int option -&gt; slice

  val <a href="#val-base">base</a> : slice -&gt; vector * int * int

  val <a href="#val-vector">vector</a> : slice -&gt; vector

  val <a href="#val-concat">concat</a> : slice list -&gt; vector

  val <a href="#val-isempty">isEmpty</a> : slice -&gt; bool

  val <a href="#val-getitem">getItem</a> : slice -&gt; (elem * slice) option

  val <a href="#val-appi">appi</a> : (int * elem -&gt; unit) -&gt; slice -&gt; unit

  val <a href="#val-app">app</a> : (elem -&gt; unit) -&gt; slice -&gt; unit

  val <a href="#val-mapi">mapi</a> : (int * elem -&gt; elem) -&gt; slice -&gt; vector

  val <a href="#val-map">map</a> : (elem -&gt; elem) -&gt; slice -&gt; vector

  val <a href="#val-foldli">foldli</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b

  val <a href="#val-foldr">foldr</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b

  val <a href="#val-foldl">foldl</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b

  val <a href="#val-foldri">foldri</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b

  val <a href="#val-findi">findi</a> : (int * elem -&gt; bool) -&gt; slice -&gt; (int * elem) option

  val <a href="#val-find">find</a> : (elem -&gt; bool) -&gt; slice -&gt; elem option

  val <a href="#val-exists">exists</a> : (elem -&gt; bool) -&gt; slice -&gt; bool

  val <a href="#val-all">all</a> : (elem -&gt; bool) -&gt; slice -&gt; bool

  val <a href="#val-collate">collate</a> : (elem * elem -&gt; order) -&gt; slice * slice -&gt; order
end
</pre>

### <a name="type-elem"></a>`elem`

```sml
type elem
```

The type of the elements: [`Word8.word`](../sig/WORD.md#type-word) for [`Word8Vector`](../sig/MONO_VECTOR.md), `char` for [`CharVector`](../sig/MONO_VECTOR.md).

<details><summary>Tests (1)</summary>

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `eight-distinct-samples`

</details>

### <a name="type-vector"></a>`vector`

```sml
type vector
```

The type of these vectors.

<details><summary>Tests (13)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `is-a-string` &middot; `empty-string` &middot; `of-a-substring` &middot; `of-Substring.extract` &middot; `String.substring*`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `every-byte`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `empty`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `middle` &middot; `full` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="type-slice"></a>`slice`

```sml
type slice
```

The type of slices of one of these.

<details><summary>Tests (42)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `is-a-substring` &middot; `Substring.base` &middot; `String.extract*`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `high-bytes`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `SOME` &middot; `NONE` &middot; `NONE-at-length` &middot; `SOME-zero` &middot; `Subscript-NONE-beyond` (raises Subscript) &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-negative-size` (raises Subscript)

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-all` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-zero-at-length` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-beyond` (raises Subscript) &middot; `of-empty-vector` &middot; `of-empty-vector-Subscript` (raises Subscript) &middot; `every-argument` &middot; `model*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-length"></a>`length`

```sml
val length : slice -> int
```

`length x` is the number of elements.

<details><summary>Tests (8)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `of-a-substring`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `NONE`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `middle` &middot; `full` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : slice * int -> elem
```

`sub (x, i)` is the element at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is outside.

<details><summary>Tests (16)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `elem-is-char` &middot; `high-character`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `elem-is-Word8.word`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `each` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `first` &middot; `last` &middot; `Subscript-length-within-the-vector` (raises Subscript) &middot; `Subscript-negative-within-the-vector` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long` &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-full"></a>`full`

```sml
val full : vector -> slice
```

`full v` is the whole of `v` as a slice.

<details><summary>Tests (9)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `string-constant` &middot; `is-Substring.full`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `empty`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `basic` &middot; `base` &middot; `empty-vector` &middot; `empty-vector-base` &middot; `model*`

</details>

### <a name="val-slice"></a>`slice`

```sml
val slice : vector * int * int option -> slice
```

`slice (v, i, sz)` is the stretch of `v` from `i`, of `sz` elements or to the end.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the positions are outside `v`.

<details><summary>Tests (42)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `is-a-substring` &middot; `Substring.base` &middot; `String.extract*`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `high-bytes`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `SOME` &middot; `NONE` &middot; `NONE-at-length` &middot; `SOME-zero` &middot; `Subscript-NONE-beyond` (raises Subscript) &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-negative-size` (raises Subscript)

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-all` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-zero-at-length` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-beyond` (raises Subscript) &middot; `of-empty-vector` &middot; `of-empty-vector-Subscript` (raises Subscript) &middot; `every-argument` &middot; `model*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : slice * int * int option -> slice
```

`subslice (sl, i, sz)` is the stretch of `sl` from `i`, of `sz` elements or to its end.

The bounds are those of `sl`, not of what it is a slice of.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the positions are outside `sl`.

<details><summary>Tests (34)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `of-Substring.triml` &middot; `then-Substring.trimr`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `NONE` &middot; `SOME` &middot; `at-length` &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-all` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `of-subslice-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-within-the-vector` (raises Subscript) &middot; `SOME-Subscript-beyond` (raises Subscript) &middot; `of-empty` &middot; `of-empty-Subscript` (raises Subscript) &middot; `every-argument` &middot; `model*` &middot; `model*` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-base"></a>`base`

```sml
val base : slice -> vector * int * int
```

`base sl` is the vector `sl` is a stretch of, where it starts and how long it is.

<details><summary>Tests (9)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `string` &middot; `of-a-substring` &middot; `Substring.base*`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice` &middot; `subslice`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `middle` &middot; `empty` &middot; `round-trip` &middot; `model*`

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : slice -> vector
```

`vector sl` is a vector of the elements of `sl`, which is where the copy happens.

<details><summary>Tests (13)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `is-a-string` &middot; `empty-string` &middot; `of-a-substring` &middot; `of-Substring.extract` &middot; `String.substring*`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `every-byte`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `empty`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `middle` &middot; `full` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : slice list -> vector
```

`concat l` is the vector of the elements of the slices of `l`, one after another.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than `maxLen`.

<details><summary>Tests (12)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `string` &middot; `of-substrings`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `nil`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `basic` &middot; `nil` &middot; `one` &middot; `empties` &middot; `same-twice` &middot; `model*` &middot; `many` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : slice -> bool
```

`isEmpty sl` is `true` when `sl` has no elements.

<details><summary>Tests (9)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `of-a-substring`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `false` &middot; `true`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `empty` &middot; `empty-at-length` &middot; `empty-vector` &middot; `one` &middot; `middle` &middot; `model*`

</details>

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : slice -> (elem * slice) option
```

`getItem sl` is `NONE` when `sl` is empty, and `SOME (x, rest)` otherwise.

It has the shape of a [`StringCvt.reader`](../sig/STRING_CVT.md#type-reader).

<details><summary>Tests (11)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `is-Substring.getc`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `first` &middot; `empty`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `first` &middot; `rest` &middot; `rest-base` &middot; `last-rest-is-empty` &middot; `empty` &middot; `every-item` &middot; `model*` &middot; `long`

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> slice -> unit
```

`appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

<details><summary>Tests (4)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice-indices`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> slice -> unit
```

`app f x` applies `f` to every element, from 0 up, for its effect.

<details><summary>Tests (4)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `order`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * elem -> elem) -> slice -> vector
```

`mapi f sl` is the vector of the results of `f` on the index and the element of each position.

<details><summary>Tests (7)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `string-index`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice-indices`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `basic` &middot; `index-in-the-slice` &middot; `empty` &middot; `order` &middot; `model*`

</details>

### <a name="val-map"></a>`map`

```sml
val map : (elem -> elem) -> slice -> vector
```

`map f sl` is the vector of the results of `f` on each element, in order.

<details><summary>Tests (9)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `toUpper`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `Word8-arithmetic`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `not`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `basic` &middot; `empty` &middot; `order` &middot; `argument-unchanged` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldli f init x` combines the elements from the left, giving `f` the index as well.

<details><summary>Tests (5)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldr f init x` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

<details><summary>Tests (7)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `Substring.explode*`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldl f init x` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

<details><summary>Tests (7)</summary>

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `sum-of-bytes`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldri f init x` combines the elements from the right, giving `f` the index as well.

<details><summary>Tests (5)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> slice -> (int * elem) option
```

`findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

<details><summary>Tests (10)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice-index` &middot; `none`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> slice -> elem option
```

`find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

<details><summary>Tests (8)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `true` &middot; `none-in-the-slice`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `first-match` &middot; `last-element` &middot; `none-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `model*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> slice -> bool
```

`exists p x` is `true` when some element satisfies `p`.

<details><summary>Tests (8)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `only-the-slice` &middot; `true`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `true` &middot; `false-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> slice -> bool
```

`all p x` is `true` when every element satisfies `p`.

<details><summary>Tests (9)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `only-the-slice` &middot; `false`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `true-but-not-outside-the-slice` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*` &middot; `de-morgan*`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> slice * slice -> order
```

`collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

<details><summary>Tests (20)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `high-characters` &middot; `of-substrings`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `unsigned-bytes`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `equal` &middot; `less` &middot; `prefix-greater`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `LargeWordVectorSlice`, `Word64VectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `equal-in-different-vectors` &middot; `same-slice` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model*` &middot; `reflexive*` &middot; `long`

</details>

## See also

[`VECTOR_SLICE`](../sig/VECTOR_SLICE.md), [`MONO_VECTOR`](../sig/MONO_VECTOR.md), [`SUBSTRING`](../sig/SUBSTRING.md)

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
