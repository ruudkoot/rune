# signature MONO_VECTOR_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **MONO_VECTOR_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 19 |
| Documentation | 26 of 26 entries documented |
| Tests | 275 checks of 24 entries |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_VECTOR_SLICE
structure BoolVectorSlice :> MONO_VECTOR_SLICE where type vector = BoolVector.vector where type elem = bool  (* optional *)
structure CharVectorSlice : MONO_VECTOR_SLICE where type slice = Substring.substring where type vector = String.string where type elem = char
structure Int16VectorSlice :> MONO_VECTOR_SLICE where type vector = Int16Vector.vector where type elem = Int16.int  (* optional *)
structure Int32VectorSlice :> MONO_VECTOR_SLICE where type vector = Int32Vector.vector where type elem = Int32.int  (* optional *)
structure Int64VectorSlice :> MONO_VECTOR_SLICE where type vector = Int64Vector.vector where type elem = Int64.int  (* optional *)
structure Int8VectorSlice :> MONO_VECTOR_SLICE where type vector = Int8Vector.vector where type elem = Int8.int  (* optional *)
structure IntVectorSlice :> MONO_VECTOR_SLICE where type vector = IntVector.vector where type elem = int  (* optional *)
structure LargeIntVectorSlice :> MONO_VECTOR_SLICE where type vector = LargeIntVector.vector where type elem = LargeInt.int  (* optional *)
structure LargeRealVectorSlice : MONO_VECTOR_SLICE where type vector = LargeRealVector.vector where type elem = LargeReal.real  (* optional *)
structure LargeWordVectorSlice : MONO_VECTOR_SLICE where type vector = LargeWordVector.vector where type elem = LargeWord.word  (* optional *)
structure Real32VectorSlice :> MONO_VECTOR_SLICE where type vector = Real32Vector.vector where type elem = Real32.real  (* optional *)
structure Real64VectorSlice : MONO_VECTOR_SLICE where type vector = Real64Vector.vector where type elem = Real64.real  (* optional *)
structure RealVectorSlice :> MONO_VECTOR_SLICE where type vector = RealVector.vector where type elem = real  (* optional *)
structure WideCharVectorSlice :> MONO_VECTOR_SLICE where type vector = WideCharVector.vector where type elem = WideChar.char  (* optional *)
structure Word16VectorSlice :> MONO_VECTOR_SLICE where type vector = Word16Vector.vector where type elem = Word16.word  (* optional *)
structure Word32VectorSlice :> MONO_VECTOR_SLICE where type vector = Word32Vector.vector where type elem = Word32.word  (* optional *)
structure Word64VectorSlice :> MONO_VECTOR_SLICE where type vector = Word64Vector.vector where type elem = Word64.word  (* optional *)
structure Word8VectorSlice : MONO_VECTOR_SLICE where type vector = Word8Vector.vector where type elem = Word8.word
structure WordVectorSlice :> MONO_VECTOR_SLICE where type vector = WordVector.vector where type elem = word  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`BoolVectorSlice`](../str/BoolVectorSlice.md) | BoolVectorSlice: stretches of [`BoolVector`](../str/BoolVector.md) vectors, without a copy. | [lib/basis/mono\_bool.sml](../../../../lib/basis/mono_bool.sml) |
| [`CharVectorSlice`](../str/CharVectorSlice.md) | CharVectorSlice: the substrings, seen as slices of vectors of characters. Its [`slice`](#val-slice) is [`Substring.substring`](../sig/SUBSTRING.md#val-substring), as the specification requires, so a slice made here is a substring there and the other way round. | [lib/basis/charvectorslice.sml](../../../../lib/basis/charvectorslice.sml) |
| [`Int16VectorSlice`](../str/Int16VectorSlice.md) | Int16VectorSlice: stretches of [`Int16Vector`](../str/Int16Vector.md) vectors, without a copy. | [lib/basis/mono\_int16.sml](../../../../lib/basis/mono_int16.sml) |
| [`Int32VectorSlice`](../str/Int32VectorSlice.md) | Int32VectorSlice: stretches of [`Int32Vector`](../str/Int32Vector.md) vectors, without a copy. | [lib/basis/mono\_int32.sml](../../../../lib/basis/mono_int32.sml) |
| [`Int64VectorSlice`](../str/Int64VectorSlice.md) | Int64VectorSlice: stretches of [`Int64Vector`](../str/Int64Vector.md) vectors, without a copy. | [lib/basis/mono\_int64.sml](../../../../lib/basis/mono_int64.sml) |
| [`Int8VectorSlice`](../str/Int8VectorSlice.md) | Int8VectorSlice: stretches of [`Int8Vector`](../str/Int8Vector.md) vectors, without a copy. | [lib/basis/mono\_int8.sml](../../../../lib/basis/mono_int8.sml) |
| [`IntVectorSlice`](../str/IntVectorSlice.md) | IntVectorSlice: stretches of [`IntVector`](../str/IntVector.md) vectors, without a copy. | [lib/basis/mono\_int.sml](../../../../lib/basis/mono_int.sml) |
| [`LargeIntVectorSlice`](../str/LargeIntVectorSlice.md) | LargeIntVectorSlice: stretches of [`LargeIntVector`](../str/LargeIntVector.md) vectors, without a copy. | [lib/basis/mono\_largeint.sml](../../../../lib/basis/mono_largeint.sml) |
| [`LargeRealVectorSlice`](../str/RealVectorSlice.md) |  | [lib/basis/mono\_largereal.sml](../../../../lib/basis/mono_largereal.sml) |
| [`LargeWordVectorSlice`](../str/Word64VectorSlice.md) |  | [lib/basis/mono\_largeword.sml](../../../../lib/basis/mono_largeword.sml) |
| [`Real32VectorSlice`](../str/Real32VectorSlice.md) | Real32VectorSlice: stretches of [`Real32Vector`](../str/Real32Vector.md) vectors, without a copy. | [lib/basis/mono\_real32.sml](../../../../lib/basis/mono_real32.sml) |
| [`Real64VectorSlice`](../str/RealVectorSlice.md) |  | [lib/basis/mono\_real64.sml](../../../../lib/basis/mono_real64.sml) |
| [`RealVectorSlice`](../str/RealVectorSlice.md) | RealVectorSlice: stretches of [`RealVector`](../str/RealVector.md) vectors, without a copy. | [lib/basis/mono\_real.sml](../../../../lib/basis/mono_real.sml) |
| [`WideCharVectorSlice`](../str/WideCharVectorSlice.md) | WideCharVectorSlice: stretches of [`WideCharVector`](../str/WideCharVector.md) vectors, without a copy, which are the substrings of [`WideSubstring`](../str/WideSubstring.md). | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |
| [`Word16VectorSlice`](../str/Word16VectorSlice.md) | Word16VectorSlice: stretches of [`Word16Vector`](../str/Word16Vector.md) vectors, without a copy. | [lib/basis/mono\_word16.sml](../../../../lib/basis/mono_word16.sml) |
| [`Word32VectorSlice`](../str/Word32VectorSlice.md) | Word32VectorSlice: stretches of [`Word32Vector`](../str/Word32Vector.md) vectors, without a copy. | [lib/basis/mono\_word32.sml](../../../../lib/basis/mono_word32.sml) |
| [`Word64VectorSlice`](../str/Word64VectorSlice.md) | Word64VectorSlice: stretches of [`Word64Vector`](../str/Word64Vector.md) vectors, without a copy. | [lib/basis/mono\_word64.sml](../../../../lib/basis/mono_word64.sml) |
| [`Word8VectorSlice`](../str/Word8VectorSlice.md) | Word8VectorSlice: stretches of [`Word8Vector`](../str/Word8Vector.md) vectors, without a copy. | [lib/basis/word8vector.sml](../../../../lib/basis/word8vector.sml) |
| [`WordVectorSlice`](../str/WordVectorSlice.md) | WordVectorSlice: stretches of [`WordVector`](../str/WordVector.md) vectors, without a copy. | [lib/basis/mono\_word.sml](../../../../lib/basis/mono_word.sml) |

A stretch of a vector of one element type, without a copy of it.

> **Implementation** `CharVectorSlice.slice/substring`. The slice of a vector
> of characters is [`Substring.substring`](../sig/SUBSTRING.md#val-substring), and the slice of one of bytes is a
> substring too.

<details><summary>Other implementations (1)</summary>

- **MLton 20241230** &mdash; BoolVector.length (BoolArray.vector (BoolArray.array (3, true))) is 0 in a program that also uses BoolArraySlice (copyVec, full, sub) or BoolArray2; alone it is 3, and 20210117 gives 3 in the same program

</details>

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

The type of the elements: [`Word8.word`](../sig/WORD.md#type-word) for [`Word8VectorSlice`](../str/Word8VectorSlice.md), `char` for [`CharVectorSlice`](../str/CharVectorSlice.md).

<details><summary>Tests (1)</summary>

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `eight-distinct-samples`

</details>

### <a name="type-vector"></a>`vector`

```sml
type vector
```

The type of these vectors.

### <a name="type-slice"></a>`slice`

```sml
type slice
```

The type of slices of one of these.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; slice and subslice (x, i, SOME j) raise Overflow instead of Subscript when i + j overflows

</details>

### <a name="val-length"></a>`length`

```sml
val length : slice -> int
```

`length x` is the number of elements.

**Law** `length (slice (v, i, SOME n)) = n` for `0 <= i andalso i <= length (full v) andalso 0 <= n andalso n <= length (full v) - i` (for every `v : string`, `i : int`, `n : int`)

**Example** `length (slice ("abc", 1, NONE)) = 2`

<details><summary>Tests (8)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `of-a-substring`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `NONE`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `middle` &middot; `full` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : slice * int -> elem
```

`sub (x, i)` is the element at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length x`.

**Example** `sub (slice ("abc", 1, NONE), 0) = #"b"`

<details><summary>Tests (16)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `elem-is-char` &middot; `high-character`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `elem-is-Word8.word`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `each` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `BoolVectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `first` &middot; `last` &middot; `Subscript-length-within-the-vector` (raises Subscript) &middot; `Subscript-negative-within-the-vector` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long` &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-full"></a>`full`

```sml
val full : vector -> slice
```

`full v` is the whole of `v` as a slice: `slice (v, 0, NONE)`.

**Law** `vector (full v) = v` for a vector type that admits equality (for every `v : string`)

**Example** `vector (full "hi") = "hi"`

<details><summary>Tests (10)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `string-constant` &middot; `is-Substring.full`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `empty` &middot; `is-slice-0-NONE`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `basic` &middot; `base` &middot; `empty-vector` &middot; `empty-vector-base` &middot; `model*`

</details>

### <a name="val-slice"></a>`slice`

```sml
val slice : vector * int * int option -> slice
```

`slice (v, i, sz)` is the stretch of `v` from `i`, of `sz` elements or to the end.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i` is more than the length of `v`, or,
with `SOME n`, if `n < 0` or `i + n` is more than the length of `v`.

**Example** `vector (slice ("abcd", 1, SOME 2)) = "bc"`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; slice and subslice (x, i, SOME j) raise Overflow instead of Subscript when i + j overflows

</details>

<details><summary>Tests (42)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `is-a-substring` &middot; `Substring.base` &middot; `String.extract*`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `high-bytes`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `SOME` &middot; `NONE` &middot; `NONE-at-length` &middot; `SOME-zero` &middot; `Subscript-NONE-beyond` (raises Subscript) &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-negative-size` (raises Subscript)

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `BoolVectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-all` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-zero-at-length` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-beyond` (raises Subscript) &middot; `of-empty-vector` &middot; `of-empty-vector-Subscript` (raises Subscript) &middot; `every-argument` &middot; `model*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : slice * int * int option -> slice
```

`subslice (sl, i, sz)` is the stretch of `sl` from `i`, of `sz` elements or to its end.

The bounds are those of `sl`, not of what it is a slice of.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i > length sl`, or, with `SOME n`, if
`n < 0` or `i + n > length sl`.

**Law** `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= i andalso i < length sl andalso 0 <= k andalso k < length sl - i` (for every `sl : Substring.substring`, `i : int`, `k : int`)

**Example** `vector (subslice (slice ("abcd", 1, NONE), 1, SOME 1)) = "c"`

**Counterexample** `sub (subslice (full "ab", ~1, NONE), 1) = sub (full "ab", 0)`, for a subslice cannot start before its slice.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; slice and subslice (x, i, SOME j) raise Overflow instead of Subscript when i + j overflows

</details>

<details><summary>Tests (34)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `of-Substring.triml` &middot; `then-Substring.trimr`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `NONE` &middot; `SOME` &middot; `at-length` &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `BoolVectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-all` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `of-subslice-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-within-the-vector` (raises Subscript) &middot; `SOME-Subscript-beyond` (raises Subscript) &middot; `of-empty` &middot; `of-empty-Subscript` (raises Subscript) &middot; `every-argument` &middot; `model*` &middot; `model*` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-base"></a>`base`

```sml
val base : slice -> vector * int * int
```

`base sl` is the vector `sl` is a stretch of, where it starts and how long it is.

**Example** `base (slice ("abcd", 1, SOME 2)) = ("abcd", 1, 2)`

<details><summary>Tests (9)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `string` &middot; `of-a-substring` &middot; `Substring.base*`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice` &middot; `subslice`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `middle` &middot; `empty` &middot; `round-trip` &middot; `model*`

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : slice -> vector
```

`vector sl` is a vector of the elements of `sl`, which is a copy of them.

**Example** `vector (slice ("abc", 1, NONE)) = "bc"`

<details><summary>Tests (13)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `is-a-string` &middot; `empty-string` &middot; `of-a-substring` &middot; `of-Substring.extract` &middot; `String.substring*`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `every-byte`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `empty`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `middle` &middot; `full` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : slice list -> vector
```

`concat l` is the vector of the elements of the slices of `l`, one after another.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than a vector can be: the
`maxLen` of the vector structure.

**Law** `length (full (concat l)) = List.foldl (fn (sl, n) => length sl + n) 0 l` (for every `l : Substring.substring list`)

**Example** `concat [slice ("abc", 1, NONE), full "d"] = "bcd"`

<details><summary>Tests (12)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `string` &middot; `of-substrings`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `nil`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `BoolVectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `basic` &middot; `nil` &middot; `one` &middot; `empties` &middot; `same-twice` &middot; `model*` &middot; `many` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : slice -> bool
```

`isEmpty sl` is `true` when `sl` has no elements.

**Law** `isEmpty sl = (length sl = 0)` (for every `sl : Substring.substring`)

**Example** `isEmpty (slice ("a", 1, NONE)) = true`

<details><summary>Tests (9)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `of-a-substring`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `false` &middot; `true`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `empty` &middot; `empty-at-length` &middot; `empty-vector` &middot; `one` &middot; `middle` &middot; `model*`

</details>

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : slice -> (elem * slice) option
```

`getItem sl` is `NONE` when `sl` is empty, and `SOME (x, rest)` otherwise.

It has the shape of a [`StringCvt.reader`](../sig/STRING_CVT.md#type-reader). `rest` is a slice of the same
vector, so it is had for nothing.

**Example** `(case getItem (full "ab") of SOME (c, rest) => (c, vector rest) | NONE => (#" ", "")) = (#"a", "b")`

<details><summary>Tests (12)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `is-Substring.getc`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `first` &middot; `rest-of-the-same-vector` &middot; `empty`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `first` &middot; `rest` &middot; `rest-base` &middot; `last-rest-is-empty` &middot; `empty` &middot; `every-item` &middot; `model*` &middot; `long`

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> slice -> unit
```

`appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

The index is that of the element in the slice, counted from 0.

**Example** `let val r = ref [] in appi (fn (i, c) => r := (i, c) :: !r) (slice ("abc", 1, NONE)); !r end = [(1, #"c"), (0, #"b")]`

<details><summary>Tests (4)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice-indices`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> slice -> unit
```

`app f x` applies `f` to every element, from 0 up, for its effect.

**Law** `app f x = appi (fn (_, e) => f e) x` (for every `f : char -> unit`, `x : Substring.substring`)

<details><summary>Tests (4)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `order`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * elem -> elem) -> slice -> vector
```

`mapi f sl` is the vector of the results of `f` on the index and the element of each position.

The index is that of the element in the slice, and `f` is applied from
0 up.

**Example** `mapi (fn (i, c) => if i = 0 then Char.toUpper c else c) (slice ("abc", 1, NONE)) = "Bc"`

<details><summary>Tests (8)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `string-index`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice-indices` &middot; `order`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `basic` &middot; `index-in-the-slice` &middot; `empty` &middot; `order` &middot; `model*`

</details>

### <a name="val-map"></a>`map`

```sml
val map : (elem -> elem) -> slice -> vector
```

`map f sl` is the vector of the results of `f` on each element, in order.

**Law** `map f sl = mapi (fn (_, e) => f e) sl` (for every `f : char -> char`, `sl : Substring.substring`)

**Example** `map Char.toUpper (slice ("abc", 1, NONE)) = "BC"`

<details><summary>Tests (10)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `toUpper`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `Word8-arithmetic`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `not` &middot; `order`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `basic` &middot; `empty` &middot; `order` &middot; `argument-unchanged` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldli f init x` combines the elements from the left, giving `f` the index as well.

The index is that of the element in the slice, counted from 0.

**Example** `foldli (fn (i, c, acc) => (i, c) :: acc) [] (slice ("abc", 1, NONE)) = [(1, #"c"), (0, #"b")]`

<details><summary>Tests (5)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldr f init x` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

**Law** `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x` (for every `f : char * 'a -> 'a`, `init : 'a`, `x : Substring.substring`)

**Example** `foldr (op ::) [] (full "ab") = [#"a", #"b"]`

<details><summary>Tests (7)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `Substring.explode*`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldl f init x` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

**Law** `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x` (for every `f : char * 'a -> 'a`, `init : 'a`, `x : Substring.substring`)

**Example** `foldl (op ::) [] (full "ab") = [#"b", #"a"]`

<details><summary>Tests (7)</summary>

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `sum-of-bytes`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

`foldri f init x` combines the elements from the right, giving `f` the index as well.

The index is that of the element in the slice, counted from 0.

**Example** `foldri (fn (i, c, acc) => (i, c) :: acc) [] (slice ("abc", 1, NONE)) = [(0, #"b"), (1, #"c")]`

<details><summary>Tests (5)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> slice -> (int * elem) option
```

`findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

The index is that of the element in the slice; `p` is applied from 0 up,
and not after the first position that satisfies it.

**Example** `findi (fn (_, c) => c = #"a") (slice ("aba", 1, NONE)) = SOME (1, #"a")`

<details><summary>Tests (11)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `slice-index` &middot; `none` &middot; `stops`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> slice -> elem option
```

`find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

**Law** `find p x = Option.map #2 (findi (fn (_, e) => p e) x)` (for every `p : char -> bool`, `x : Substring.substring`)

**Example** `find Char.isDigit (full "a1") = SOME #"1"`

<details><summary>Tests (9)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `stops` &middot; `true` &middot; `none-in-the-slice`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `first-match` &middot; `last-element` &middot; `none-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `model*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> slice -> bool
```

`exists p x` is `true` when some element satisfies `p`; it stops at the first that does.

Only the elements of the slice are looked at, not the rest of its vector.

**Law** `exists p x = isSome (find p x)` (for every `p : char -> bool`, `x : Substring.substring`)

**Example** `exists (fn c => c = #"a") (slice ("ab", 1, NONE)) = false`

<details><summary>Tests (9)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `stops` &middot; `only-the-slice` &middot; `true`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `true` &middot; `false-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> slice -> bool
```

`all p x` is `true` when every element satisfies `p`; it stops at the first that does not.

**Law** `all p x = not (exists (not o p) x)` (for every `p : char -> bool`, `x : Substring.substring`)

**Example** `all Char.isLower (slice ("Ab", 1, NONE)) = true`

<details><summary>Tests (10)</summary>

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `stops` &middot; `only-the-slice` &middot; `false`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `true-but-not-outside-the-slice` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*` &middot; `de-morgan*`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> slice * slice -> order
```

`collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

**Law** `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)` (for every `cmp : char * char -> order`, `a : Substring.substring`, `b : Substring.substring`)

**Example** `collate Char.compare (slice ("abc", 1, NONE), full "b") = GREATER`

<details><summary>Tests (20)</summary>

For `CharVectorSlice`, in [tests/basis/charvectorslice.sml](../../../../tests/basis/charvectorslice.sml): `high-characters` &middot; `of-substrings`

For `Word8VectorSlice`, in [tests/basis/word8vectorslice.sml](../../../../tests/basis/word8vectorslice.sml): `unsigned-bytes`

For `BoolVectorSlice`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `equal` &middot; `less` &middot; `prefix-greater`

In [tests/basis/fn/mono\_vector\_slice\_fn.sml](../../../../tests/basis/fn/mono_vector_slice_fn.sml), applied to `CharVectorSlice`, `Word8VectorSlice`, `IntVectorSlice`, `Int8VectorSlice`, `Int16VectorSlice`, `Int32VectorSlice`, `LargeIntVectorSlice`, `WordVectorSlice`, `Word16VectorSlice`, `Word32VectorSlice`, `RealVectorSlice`, `Int64VectorSlice`, `Word64VectorSlice`, `LargeWordVectorSlice`, `LargeRealVectorSlice`, `Real64VectorSlice`, `Real32VectorSlice`, `WideCharVectorSlice`: `equal-in-different-vectors` &middot; `same-slice` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model*` &middot; `reflexive*` &middot; `long`

</details>

## See also

[`VECTOR_SLICE`](../sig/VECTOR_SLICE.md), [`MONO_VECTOR`](../sig/MONO_VECTOR.md), [`SUBSTRING`](../sig/SUBSTRING.md)

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
