# signature MONO_ARRAY_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **MONO_ARRAY_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 19 |
| Documentation | 30 of 30 entries documented |
| Tests | 383 checks of 28 entries |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_ARRAY_SLICE
structure BoolArraySlice :> MONO_ARRAY_SLICE where type vector = BoolVector.vector where type vector_slice = BoolVectorSlice.slice where type array = BoolArray.array where type elem = bool  (* optional *)
structure CharArraySlice :> MONO_ARRAY_SLICE where type vector = CharVector.vector where type vector_slice = CharVectorSlice.slice where type array = CharArray.array where type elem = char
structure Int16ArraySlice :> MONO_ARRAY_SLICE where type vector = Int16Vector.vector where type vector_slice = Int16VectorSlice.slice where type array = Int16Array.array where type elem = Int16.int  (* optional *)
structure Int32ArraySlice :> MONO_ARRAY_SLICE where type vector = Int32Vector.vector where type vector_slice = Int32VectorSlice.slice where type array = Int32Array.array where type elem = Int32.int  (* optional *)
structure Int64ArraySlice :> MONO_ARRAY_SLICE where type vector = Int64Vector.vector where type vector_slice = Int64VectorSlice.slice where type array = Int64Array.array where type elem = Int64.int  (* optional *)
structure Int8ArraySlice :> MONO_ARRAY_SLICE where type vector = Int8Vector.vector where type vector_slice = Int8VectorSlice.slice where type array = Int8Array.array where type elem = Int8.int  (* optional *)
structure IntArraySlice :> MONO_ARRAY_SLICE where type vector = IntVector.vector where type vector_slice = IntVectorSlice.slice where type array = IntArray.array where type elem = int  (* optional *)
structure LargeIntArraySlice :> MONO_ARRAY_SLICE where type vector = LargeIntVector.vector where type vector_slice = LargeIntVectorSlice.slice where type array = LargeIntArray.array where type elem = LargeInt.int  (* optional *)
structure LargeRealArraySlice : MONO_ARRAY_SLICE where type vector = LargeRealVector.vector where type vector_slice = LargeRealVectorSlice.slice where type array = LargeRealArray.array where type elem = LargeReal.real  (* optional *)
structure LargeWordArraySlice : MONO_ARRAY_SLICE where type vector = LargeWordVector.vector where type vector_slice = LargeWordVectorSlice.slice where type array = LargeWordArray.array where type elem = LargeWord.word  (* optional *)
structure Real32ArraySlice :> MONO_ARRAY_SLICE where type vector = Real32Vector.vector where type vector_slice = Real32VectorSlice.slice where type array = Real32Array.array where type elem = Real32.real  (* optional *)
structure Real64ArraySlice : MONO_ARRAY_SLICE where type vector = Real64Vector.vector where type vector_slice = Real64VectorSlice.slice where type array = Real64Array.array where type elem = Real64.real  (* optional *)
structure RealArraySlice :> MONO_ARRAY_SLICE where type vector = RealVector.vector where type vector_slice = RealVectorSlice.slice where type array = RealArray.array where type elem = real  (* optional *)
structure WideCharArraySlice :> MONO_ARRAY_SLICE where type vector = WideCharVector.vector where type vector_slice = WideCharVectorSlice.slice where type array = WideCharArray.array where type elem = WideChar.char  (* optional *)
structure Word16ArraySlice :> MONO_ARRAY_SLICE where type vector = Word16Vector.vector where type vector_slice = Word16VectorSlice.slice where type array = Word16Array.array where type elem = Word16.word  (* optional *)
structure Word32ArraySlice :> MONO_ARRAY_SLICE where type vector = Word32Vector.vector where type vector_slice = Word32VectorSlice.slice where type array = Word32Array.array where type elem = Word32.word  (* optional *)
structure Word64ArraySlice :> MONO_ARRAY_SLICE where type vector = Word64Vector.vector where type vector_slice = Word64VectorSlice.slice where type array = Word64Array.array where type elem = Word64.word  (* optional *)
structure Word8ArraySlice :> MONO_ARRAY_SLICE where type vector = Word8Vector.vector where type vector_slice = Word8VectorSlice.slice where type array = Word8Array.array where type elem = Word8.word
structure WordArraySlice :> MONO_ARRAY_SLICE where type vector = WordVector.vector where type vector_slice = WordVectorSlice.slice where type array = WordArray.array where type elem = word  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `BoolArraySlice` |  | [lib/basis/mono\_bool.sml](../../../../lib/basis/mono_bool.sml) |
| `CharArraySlice` |  | [lib/basis/chararrayslice.sml](../../../../lib/basis/chararrayslice.sml) |
| `Int16ArraySlice` |  | [lib/basis/mono\_int16.sml](../../../../lib/basis/mono_int16.sml) |
| `Int32ArraySlice` |  | [lib/basis/mono\_int32.sml](../../../../lib/basis/mono_int32.sml) |
| `Int64ArraySlice` |  | [lib/basis/mono\_int64.sml](../../../../lib/basis/mono_int64.sml) |
| `Int8ArraySlice` |  | [lib/basis/mono\_int8.sml](../../../../lib/basis/mono_int8.sml) |
| `IntArraySlice` |  | [lib/basis/mono\_int.sml](../../../../lib/basis/mono_int.sml) |
| `LargeIntArraySlice` |  | [lib/basis/mono\_largeint.sml](../../../../lib/basis/mono_largeint.sml) |
| `LargeRealArraySlice` |  | [lib/basis/mono\_largereal.sml](../../../../lib/basis/mono_largereal.sml) |
| `LargeWordArraySlice` |  | [lib/basis/mono\_largeword.sml](../../../../lib/basis/mono_largeword.sml) |
| `Real32ArraySlice` |  | [lib/basis/mono\_real32.sml](../../../../lib/basis/mono_real32.sml) |
| `Real64ArraySlice` |  | [lib/basis/mono\_real64.sml](../../../../lib/basis/mono_real64.sml) |
| `RealArraySlice` |  | [lib/basis/mono\_real.sml](../../../../lib/basis/mono_real.sml) |
| `WideCharArraySlice` |  | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |
| `Word16ArraySlice` |  | [lib/basis/mono\_word16.sml](../../../../lib/basis/mono_word16.sml) |
| `Word32ArraySlice` |  | [lib/basis/mono\_word32.sml](../../../../lib/basis/mono_word32.sml) |
| `Word64ArraySlice` |  | [lib/basis/mono\_word64.sml](../../../../lib/basis/mono_word64.sml) |
| `Word8ArraySlice` |  | [lib/basis/word8arrayslice.sml](../../../../lib/basis/word8arrayslice.sml) |
| `WordArraySlice` |  | [lib/basis/mono\_word.sml](../../../../lib/basis/mono_word.sml) |

A stretch of an array of one element type, without a copy of it.

<details><summary>Other implementations (1)</summary>

- **MLton 20241230** &mdash; BoolVector.length (BoolArray.vector (BoolArray.array (3, true))) is 0 in a program that also uses BoolArraySlice (copyVec, full, sub) or BoolArray2; alone it is 3, and 20210117 gives 3 in the same program

</details>

## Interface

<pre>
signature MONO_ARRAY_SLICE =
sig
  type <a href="#type-elem">elem</a>

  type <a href="#type-array">array</a>

  type <a href="#type-slice">slice</a>

  type <a href="#type-vector">vector</a>

  type <a href="#type-vector_slice">vector_slice</a>

  val <a href="#val-length">length</a> : slice -&gt; int

  val <a href="#val-sub">sub</a> : slice * int -&gt; elem

  val <a href="#val-update">update</a> : slice * int * elem -&gt; unit

  val <a href="#val-full">full</a> : array -&gt; slice

  val <a href="#val-slice">slice</a> : array * int * int option -&gt; slice

  val <a href="#val-subslice">subslice</a> : slice * int * int option -&gt; slice

  val <a href="#val-base">base</a> : slice -&gt; array * int * int

  val <a href="#val-vector">vector</a> : slice -&gt; vector

  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : slice, <a href="#fld-copy.dst">dst</a> : array, <a href="#fld-copy.di">di</a> : int} -&gt; unit

  val <a href="#val-copyvec">copyVec</a> : {<a href="#fld-copyvec.src">src</a> : vector_slice, <a href="#fld-copyvec.dst">dst</a> : array, <a href="#fld-copyvec.di">di</a> : int} -&gt; unit

  val <a href="#val-isempty">isEmpty</a> : slice -&gt; bool

  val <a href="#val-getitem">getItem</a> : slice -&gt; (elem * slice) option

  val <a href="#val-appi">appi</a> : (int * elem -&gt; unit) -&gt; slice -&gt; unit

  val <a href="#val-app">app</a> : (elem -&gt; unit) -&gt; slice -&gt; unit

  val <a href="#val-modifyi">modifyi</a> : (int * elem -&gt; elem) -&gt; slice -&gt; unit

  val <a href="#val-modify">modify</a> : (elem -&gt; elem) -&gt; slice -&gt; unit

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

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `eight-distinct-samples`

</details>

### <a name="type-array"></a>`array`

```sml
type array
```

The type of these arrays.

### <a name="type-slice"></a>`slice`

```sml
type slice
```

The type of slices of one of these.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; slice and subslice (x, i, SOME j) raise Overflow instead of Subscript when i + j overflows

</details>

<details><summary>Tests (40)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `high-bytes`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `String.extract*`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `SOME` &middot; `NONE` &middot; `NONE-at-length` &middot; `Subscript-NONE-beyond` (raises Subscript) &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-all` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-zero-at-length` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-beyond` (raises Subscript) &middot; `of-empty-array` &middot; `of-empty-array-Subscript` (raises Subscript) &middot; `sees-later-updates-of-the-array` &middot; `base-is-the-same-array` &middot; `every-argument` &middot; `model*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="type-vector"></a>`vector`

```sml
type vector
```

The type of these vectors.

<details><summary>Tests (13)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `every-byte`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `is-a-string` &middot; `empty-string` &middot; `is-CharVector.vector` &middot; `String.substring*`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `is-a-snapshot`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `middle` &middot; `full` &middot; `empty` &middot; `is-a-snapshot` &middot; `model*` &middot; `long`

</details>

### <a name="type-vector_slice"></a>`vector_slice`

```sml
type vector_slice
```

The type of slices of the corresponding vector.

### <a name="val-length"></a>`length`

```sml
val length : slice -> int
```

`length x` is the number of elements.

<details><summary>Tests (6)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `middle` &middot; `full` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : slice * int -> elem
```

`sub (x, i)` is the element at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is outside.

<details><summary>Tests (16)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `elem-is-Word8.word`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `elem-is-char` &middot; `high-character`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `each` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `first` &middot; `last` &middot; `Subscript-length-within-the-array` (raises Subscript) &middot; `Subscript-negative-within-the-array` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long` &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-update"></a>`update`

```sml
val update : slice * int * elem -> unit
```

`update (sl, i, x)` puts `x` at position `i` of `sl`, and so of its array.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is outside `sl`.

<details><summary>Tests (17)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `byte`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `string`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `in-the-base` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `first` &middot; `last` &middot; `seen-by-sub` &middot; `seen-through-an-overlapping-slice` &middot; `Subscript-length-within-the-array` (raises Subscript) &middot; `Subscript-negative-within-the-array` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model*` &middot; `model*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-full"></a>`full`

```sml
val full : array -> slice
```

`full arr` is the whole of `arr` as a slice.

<details><summary>Tests (7)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `basic` &middot; `base` &middot; `empty-array` &middot; `empty-array-base` &middot; `base-is-the-same-array` &middot; `model*`

</details>

### <a name="val-slice"></a>`slice`

```sml
val slice : array * int * int option -> slice
```

`slice (arr, i, sz)` is the stretch of `arr` from `i`, of `sz` elements or to the end.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the positions are outside `arr`.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; slice and subslice (x, i, SOME j) raise Overflow instead of Subscript when i + j overflows

</details>

<details><summary>Tests (40)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `high-bytes`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `String.extract*`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `SOME` &middot; `NONE` &middot; `NONE-at-length` &middot; `Subscript-NONE-beyond` (raises Subscript) &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-all` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-zero-at-length` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-beyond` (raises Subscript) &middot; `of-empty-array` &middot; `of-empty-array-Subscript` (raises Subscript) &middot; `sees-later-updates-of-the-array` &middot; `base-is-the-same-array` &middot; `every-argument` &middot; `model*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : slice * int * int option -> slice
```

`subslice (sl, i, sz)` is the stretch of `sl` from `i`, of `sz` elements or to its end.

The bounds are those of `sl`, not of what it is a slice of.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the positions are outside `sl`.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; slice and subslice (x, i, SOME j) raise Overflow instead of Subscript when i + j overflows

</details>

<details><summary>Tests (31)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `NONE` &middot; `SOME` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript)

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-all` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `of-subslice-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-within-the-array` (raises Subscript) &middot; `SOME-Subscript-beyond` (raises Subscript) &middot; `of-empty` &middot; `of-empty-Subscript` (raises Subscript) &middot; `base-is-the-same-array` &middot; `every-argument` &middot; `model*` &middot; `model*` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-base"></a>`base`

```sml
val base : slice -> array * int * int
```

`base sl` is the array `sl` is a stretch of, where it starts and how long it is.

<details><summary>Tests (7)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `is-the-Word8Array`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `is-the-CharArray`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `is-the-array`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `middle` &middot; `empty` &middot; `round-trip` &middot; `model*`

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : slice -> vector
```

`vector sl` is a vector of the elements of `sl`, which is where the copy happens.

<details><summary>Tests (13)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `every-byte`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `is-a-string` &middot; `empty-string` &middot; `is-CharVector.vector` &middot; `String.substring*`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `is-a-snapshot`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `middle` &middot; `full` &middot; `empty` &middot; `is-a-snapshot` &middot; `model*` &middot; `long`

</details>

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : slice, dst : array, di : int} -> unit
```

`copy {src, dst, di}` copies the slice `src` into `dst` from position `di` on.

They may overlap: every element arrives as it was before the copy
began.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if it does not fit, and then nothing has been
copied.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `slice` |  |
| <a name="fld-copy.dst"></a>`dst` | `array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; copy with di = Int.maxInt raises Overflow instead of Subscript

</details>

<details><summary>Tests (35)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `to-Word8Array`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `to-CharArray` &middot; `overlapping-string`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `other-array` &middot; `overlap-right` &middot; `overlap-left` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `src-unchanged` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `overlap-to-the-right` &middot; `overlap-to-the-left` &middot; `overlap-by-one` &middot; `onto-itself` &middot; `same-array-no-overlap` &middot; `Subscript-same-array` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `same-array-model*` &middot; `long-overlap-to-the-right` &middot; `long-overlap-to-the-left` &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : vector_slice, dst : array, di : int} -> unit
```

`copyVec {src, dst, di}` copies the vector slice `src` into `dst` from position `di` on.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if it does not fit, and then nothing has been
copied.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `vector_slice` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

<details><summary>Tests (25)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `from-Word8VectorSlice`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `from-CharVectorSlice` &middot; `from-a-substring` &middot; `Subscript-substring-too-long` (raises Subscript) &middot; `String.substring*`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `full-vector` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `from-vector-of-slice` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : slice -> bool
```

`isEmpty sl` is `true` when `sl` has no elements.

<details><summary>Tests (8)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `false` &middot; `true`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `empty` &middot; `empty-at-length` &middot; `empty-array` &middot; `one` &middot; `middle` &middot; `model*`

</details>

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : slice -> (elem * slice) option
```

`getItem sl` is `NONE` when `sl` is empty, and `SOME (x, rest)` otherwise.

It has the shape of a [`StringCvt.reader`](../sig/STRING_CVT.md#type-reader).

<details><summary>Tests (11)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `first` &middot; `empty`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `first` &middot; `rest` &middot; `rest-base` &middot; `last-rest-is-empty` &middot; `empty` &middot; `every-item` &middot; `rest-is-the-same-array` &middot; `model*` &middot; `long`

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> slice -> unit
```

`appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

<details><summary>Tests (4)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice-indices`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> slice -> unit
```

`app f x` applies `f` to every element, from 0 up, for its effect.

<details><summary>Tests (4)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `order`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * elem -> elem) -> slice -> unit
```

`modifyi f x` replaces the element at each position by `f` of the index and that element, in place.

<details><summary>Tests (7)</summary>

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `string-index`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice-indices`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `basic` &middot; `index-in-the-slice` &middot; `empty` &middot; `order` &middot; `model*`

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : (elem -> elem) -> slice -> unit
```

`modify f x` replaces every element by `f` of it, in place, from 0 up.

<details><summary>Tests (11)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `Word8-arithmetic`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `toUpper` &middot; `String.map*`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `not`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `basic` &middot; `full-wraps` &middot; `empty` &middot; `order` &middot; `seen-by-the-slice` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldli f init x` combines the elements from the left, giving `f` the index as well.

<details><summary>Tests (5)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldr f init x` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

<details><summary>Tests (6)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldl f init x` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

<details><summary>Tests (22)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `sum-of-bytes`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

For `IntArraySlice`, in [tests/basis/mono.int.sml](../../../../tests/basis/mono.int.sml): `Int-arithmetic`

For `Int8ArraySlice`, in [tests/basis/mono.int8.sml](../../../../tests/basis/mono.int8.sml): `Int8-arithmetic`

For `Int16ArraySlice`, in [tests/basis/mono.int16.sml](../../../../tests/basis/mono.int16.sml): `Int16-arithmetic`

For `Int32ArraySlice`, in [tests/basis/mono.int32.sml](../../../../tests/basis/mono.int32.sml): `Int32-arithmetic`

For `LargeIntArraySlice`, in [tests/basis/mono.largeint.sml](../../../../tests/basis/mono.largeint.sml): `LargeInt-arithmetic`

For `WordArraySlice`, in [tests/basis/mono.word.sml](../../../../tests/basis/mono.word.sml): `Word-arithmetic`

For `Word16ArraySlice`, in [tests/basis/mono.word16.sml](../../../../tests/basis/mono.word16.sml): `Word16-arithmetic`

For `Word32ArraySlice`, in [tests/basis/mono.word32.sml](../../../../tests/basis/mono.word32.sml): `Word32-arithmetic`

For `RealArraySlice`, in [tests/basis/mono.real.sml](../../../../tests/basis/mono.real.sml): `Real-arithmetic`

For `Int64ArraySlice`, in [tests/basis/mono.int64.sml](../../../../tests/basis/mono.int64.sml): `Int64-arithmetic`

For `LargeWordArraySlice`, in [tests/basis/mono.largeword.sml](../../../../tests/basis/mono.largeword.sml): `LargeWord-arithmetic`

For `Word64ArraySlice`, in [tests/basis/mono.word64.sml](../../../../tests/basis/mono.word64.sml): `Word64-arithmetic`

For `LargeRealArraySlice`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `LargeReal-arithmetic`

For `Real64ArraySlice`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `Real64-arithmetic`

For `Real32ArraySlice`, in [tests/basis/mono.real32.sml](../../../../tests/basis/mono.real32.sml): `Real32-arithmetic`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldri f init x` combines the elements from the right, giving `f` the index as well.

<details><summary>Tests (5)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> slice -> (int * elem) option
```

`findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

<details><summary>Tests (9)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice-index`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> slice -> elem option
```

`find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

<details><summary>Tests (7)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `none-in-the-slice`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `first-match` &middot; `last-element` &middot; `none-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `model*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> slice -> bool
```

`exists p x` is `true` when some element satisfies `p`.

<details><summary>Tests (7)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `true`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `true` &middot; `false-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> slice -> bool
```

`all p x` is `true` when every element satisfies `p`.

<details><summary>Tests (8)</summary>

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `only-the-slice`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `true-but-not-outside-the-slice` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*` &middot; `de-morgan*`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> slice * slice -> order
```

`collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

<details><summary>Tests (18)</summary>

For `Word8ArraySlice`, in [tests/basis/word8arrayslice.sml](../../../../tests/basis/word8arrayslice.sml): `unsigned-bytes`

For `CharArraySlice`, in [tests/basis/chararrayslice.sml](../../../../tests/basis/chararrayslice.sml): `high-characters`

For `BoolArraySlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `equal` &middot; `greater`

In [tests/basis/fn/mono\_array\_slice\_fn.sml](../../../../tests/basis/fn/mono_array_slice_fn.sml), applied to `Word8ArraySlice`, `CharArraySlice`, `IntArraySlice`, `Int8ArraySlice`, `Int16ArraySlice`, `Int32ArraySlice`, `LargeIntArraySlice`, `WordArraySlice`, `Word16ArraySlice`, `Word32ArraySlice`, `RealArraySlice`, `Int64ArraySlice`, `LargeWordArraySlice`, `Word64ArraySlice`, `LargeRealArraySlice`, `Real64ArraySlice`, `Real32ArraySlice`, `WideCharArraySlice`: `equal-in-different-arrays` &middot; `same-slice` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model*` &middot; `reflexive*` &middot; `long`

</details>

## See also

[`ARRAY_SLICE`](../sig/ARRAY_SLICE.md), [`MONO_ARRAY`](../sig/MONO_ARRAY.md), [`MONO_VECTOR_SLICE`](../sig/MONO_VECTOR_SLICE.md)

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
