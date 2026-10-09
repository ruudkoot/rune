# signature MONO_ARRAY

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **MONO_ARRAY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 19 |
| Documentation | 26 of 26 entries documented |
| Tests | 318 checks of 24 entries |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_ARRAY
structure BoolArray :> MONO_ARRAY where type vector = BoolVector.vector where type elem = bool  (* optional *)
structure CharArray :> MONO_ARRAY where type vector = CharVector.vector where type elem = char
structure Int16Array :> MONO_ARRAY where type vector = Int16Vector.vector where type elem = Int16.int  (* optional *)
structure Int32Array :> MONO_ARRAY where type vector = Int32Vector.vector where type elem = Int32.int  (* optional *)
structure Int64Array :> MONO_ARRAY where type vector = Int64Vector.vector where type elem = Int64.int  (* optional *)
structure Int8Array :> MONO_ARRAY where type vector = Int8Vector.vector where type elem = Int8.int  (* optional *)
structure IntArray :> MONO_ARRAY where type vector = IntVector.vector where type elem = int  (* optional *)
structure LargeIntArray :> MONO_ARRAY where type vector = LargeIntVector.vector where type elem = LargeInt.int  (* optional *)
structure LargeRealArray : MONO_ARRAY where type vector = LargeRealVector.vector where type elem = LargeReal.real  (* optional *)
structure LargeWordArray : MONO_ARRAY where type vector = LargeWordVector.vector where type elem = LargeWord.word  (* optional *)
structure Real32Array :> MONO_ARRAY where type vector = Real32Vector.vector where type elem = Real32.real  (* optional *)
structure Real64Array : MONO_ARRAY where type vector = Real64Vector.vector where type elem = Real64.real  (* optional *)
structure RealArray : MONO_ARRAY where type vector = RealVector.vector where type elem = real  (* optional *)
structure WideCharArray :> MONO_ARRAY where type vector = WideCharVector.vector where type elem = WideChar.char  (* optional *)
structure Word16Array :> MONO_ARRAY where type vector = Word16Vector.vector where type elem = Word16.word  (* optional *)
structure Word32Array :> MONO_ARRAY where type vector = Word32Vector.vector where type elem = Word32.word  (* optional *)
structure Word64Array :> MONO_ARRAY where type vector = Word64Vector.vector where type elem = Word64.word  (* optional *)
structure Word8Array :> MONO_ARRAY where type vector = Word8Vector.vector where type elem = Word8.word
structure WordArray :> MONO_ARRAY where type vector = WordVector.vector where type elem = word  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`BoolArray`](../str/BoolArray.md) | BoolArray: mutable arrays of booleans, a type of their own with identity equality, whose vectors are those of [`BoolVector`](../str/BoolVector.md). | [lib/basis/mono\_bool.sml](../../../../lib/basis/mono_bool.sml) |
| [`CharArray`](../str/CharArray.md) | CharArray: mutable arrays of characters, a type of their own with identity equality. Their vectors are strings: [`vector`](#val-vector) gives a `string`, and [`copyVec`](#val-copyvec) copies one in. An array takes a byte a character. | [lib/basis/chararray.sml](../../../../lib/basis/chararray.sml) |
| [`Int16Array`](../str/Int16Array.md) | Int16Array: mutable arrays of 16-bit integers, a type of their own with identity equality, whose vectors are those of [`Int16Vector`](../str/Int16Vector.md). | [lib/basis/mono\_int16.sml](../../../../lib/basis/mono_int16.sml) |
| [`Int32Array`](../str/Int32Array.md) | Int32Array: mutable arrays of 32-bit integers, a type of their own with identity equality, whose vectors are those of [`Int32Vector`](../str/Int32Vector.md). | [lib/basis/mono\_int32.sml](../../../../lib/basis/mono_int32.sml) |
| [`Int64Array`](../str/Int64Array.md) | Int64Array: mutable arrays of 64-bit integers, a type of their own with identity equality, whose vectors are those of [`Int64Vector`](../str/Int64Vector.md). | [lib/basis/mono\_int64.sml](../../../../lib/basis/mono_int64.sml) |
| [`Int8Array`](../str/Int8Array.md) | Int8Array: mutable arrays of 8-bit integers, a type of their own with identity equality, whose vectors are those of [`Int8Vector`](../str/Int8Vector.md). | [lib/basis/mono\_int8.sml](../../../../lib/basis/mono_int8.sml) |
| [`IntArray`](../str/IntArray.md) | IntArray: mutable arrays of integers of the default `int`, a type of their own with identity equality, whose vectors are those of [`IntVector`](../str/IntVector.md). | [lib/basis/mono\_int.sml](../../../../lib/basis/mono_int.sml) |
| [`LargeIntArray`](../str/LargeIntArray.md) | LargeIntArray: mutable arrays of integers of any size, a type of their own with identity equality, whose vectors are those of [`LargeIntVector`](../str/LargeIntVector.md). | [lib/basis/mono\_largeint.sml](../../../../lib/basis/mono_largeint.sml) |
| [`LargeRealArray`](../str/RealArray.md) |  | [lib/basis/mono\_largereal.sml](../../../../lib/basis/mono_largereal.sml) |
| [`LargeWordArray`](../str/Word64Array.md) |  | [lib/basis/mono\_largeword.sml](../../../../lib/basis/mono_largeword.sml) |
| [`Real32Array`](../str/Real32Array.md) | Real32Array: mutable arrays of binary32 reals, a type of their own with identity equality, whose vectors are those of [`Real32Vector`](../str/Real32Vector.md). | [lib/basis/mono\_real32.sml](../../../../lib/basis/mono_real32.sml) |
| [`Real64Array`](../str/RealArray.md) |  | [lib/basis/mono\_real64.sml](../../../../lib/basis/mono_real64.sml) |
| [`RealArray`](../str/RealArray.md) | RealArray: mutable arrays of reals, a type of their own with identity equality, whose vectors are those of [`RealVector`](../str/RealVector.md). | [lib/basis/mono\_real.sml](../../../../lib/basis/mono_real.sml) |
| [`WideCharArray`](../str/WideCharArray.md) | WideCharArray: mutable arrays of wide characters, a type of their own with identity equality, whose vectors are those of [`WideCharVector`](../str/WideCharVector.md). | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |
| [`Word16Array`](../str/Word16Array.md) | Word16Array: mutable arrays of 16-bit words, a type of their own with identity equality, whose vectors are those of [`Word16Vector`](../str/Word16Vector.md). | [lib/basis/mono\_word16.sml](../../../../lib/basis/mono_word16.sml) |
| [`Word32Array`](../str/Word32Array.md) | Word32Array: mutable arrays of 32-bit words, a type of their own with identity equality, whose vectors are those of [`Word32Vector`](../str/Word32Vector.md). | [lib/basis/mono\_word32.sml](../../../../lib/basis/mono_word32.sml) |
| [`Word64Array`](../str/Word64Array.md) | Word64Array: mutable arrays of 64-bit words, a type of their own with identity equality, whose vectors are those of [`Word64Vector`](../str/Word64Vector.md). | [lib/basis/mono\_word64.sml](../../../../lib/basis/mono_word64.sml) |
| [`Word8Array`](../str/Word8Array.md) | Word8Array: mutable arrays of bytes, a type of their own with identity equality, whose vectors are those of [`Word8Vector`](../str/Word8Vector.md): the buffers of binary input and output. An array takes a byte an element and is laid out as C has an array of bytes; [`vector`](#val-vector), [`copy`](#val-copy) and [`copyVec`](#val-copyvec) move the bytes in one step. | [lib/basis/word8array.sml](../../../../lib/basis/word8array.sml) |
| [`WordArray`](../str/WordArray.md) | WordArray: mutable arrays of words, a type of their own with identity equality, whose vectors are those of [`WordVector`](../str/WordVector.md). | [lib/basis/mono\_word.sml](../../../../lib/basis/mono_word.sml) |

Mutable sequences of one element type.

> **Implementation** `Word8Array.array/one-value-per-byte`. A [`Word8Array.array`](#val-array)
> is an ordinary array with one value of the machine per byte.

<details><summary>Other implementations (1)</summary>

- **MLton 20241230** &mdash; BoolVector.length (BoolArray.vector (BoolArray.array (3, true))) is 0 in a program that also uses BoolArraySlice (copyVec, full, sub) or BoolArray2; alone it is 3, and 20210117 gives 3 in the same program

</details>

## Interface

<pre>
signature MONO_ARRAY =
sig
  eqtype <a href="#type-array">array</a>
  type <a href="#type-elem">elem</a>
  type <a href="#type-vector">vector</a>
  val <a href="#val-maxlen">maxLen</a> : int
  val <a href="#val-array">array</a> : int * elem -&gt; array
  val <a href="#val-fromlist">fromList</a> : elem list -&gt; array
  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; elem) -&gt; array
  val <a href="#val-length">length</a> : array -&gt; int
  val <a href="#val-sub">sub</a> : array * int -&gt; elem
  val <a href="#val-update">update</a> : array * int * elem -&gt; unit
  val <a href="#val-vector">vector</a> : array -&gt; vector
  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : array, <a href="#fld-copy.dst">dst</a> : array, <a href="#fld-copy.di">di</a> : int} -&gt; unit
  val <a href="#val-copyvec">copyVec</a> : {<a href="#fld-copyvec.src">src</a> : vector, <a href="#fld-copyvec.dst">dst</a> : array, <a href="#fld-copyvec.di">di</a> : int} -&gt; unit
  val <a href="#val-appi">appi</a> : (int * elem -&gt; unit) -&gt; array -&gt; unit
  val <a href="#val-app">app</a> : (elem -&gt; unit) -&gt; array -&gt; unit
  val <a href="#val-modifyi">modifyi</a> : (int * elem -&gt; elem) -&gt; array -&gt; unit
  val <a href="#val-modify">modify</a> : (elem -&gt; elem) -&gt; array -&gt; unit
  val <a href="#val-foldli">foldli</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b
  val <a href="#val-foldri">foldri</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b
  val <a href="#val-foldl">foldl</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b
  val <a href="#val-foldr">foldr</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b
  val <a href="#val-findi">findi</a> : (int * elem -&gt; bool) -&gt; array -&gt; (int * elem) option
  val <a href="#val-find">find</a> : (elem -&gt; bool) -&gt; array -&gt; elem option
  val <a href="#val-exists">exists</a> : (elem -&gt; bool) -&gt; array -&gt; bool
  val <a href="#val-all">all</a> : (elem -&gt; bool) -&gt; array -&gt; bool
  val <a href="#val-collate">collate</a> : (elem * elem -&gt; order) -&gt; array * array -&gt; order
end
</pre>

### <a name="type-array"></a>`array`

```sml
eqtype array
```

The type of these arrays.

Two are equal when they are the same array, whatever they hold.

### <a name="type-elem"></a>`elem`

```sml
type elem
```

The type of the elements: [`Word8.word`](../sig/WORD.md#type-word) for [`Word8Array`](../str/Word8Array.md), `char` for [`CharArray`](../str/CharArray.md).

<details><summary>Tests (2)</summary>

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `is-char`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `eight-distinct-samples`

</details>

### <a name="type-vector"></a>`vector`

```sml
type vector
```

The type of these vectors.

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

The greatest length such an array may have.

> **Implementation** `MONO_ARRAY.maxLen/value`. [`Array.maxLen`](../sig/ARRAY.md#val-maxlen), 100,000,000,
> for every instance, those of characters and of bytes too.

**Example** `maxLen = 100000000`

<details><summary>Tests (2)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `covers-created-arrays`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `covers-created-arrays`

</details>

### <a name="val-array"></a>`array`

```sml
val array : int * elem -> array
```

`array (n, x)` is a new array of `n` elements, each of them `x`.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0` or `n > maxLen`.

**Law** `sub (array (n, x), i) = x` for `0 <= i andalso i < n andalso n <= maxLen`, and it is run for `n` from `Arb.intRange (0, 1048576)`, as the
tester cannot hold a longer one (for every `n : int`, `x : char`, `i : int`)

**Example** `vector (array (3, #"x")) = "xxx"`

**Counterexample** `sub (array (maxLen + 1, #"x"), 0) = #"x"`, for there is
no array so long.

<details><summary>Tests (24)</summary>

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `string-of-init`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `zero` &middot; `Size-negative` (raises Size) &middot; `elements-are-separate` &middot; `same-array-is-equal` &middot; `same-elements-not-equal`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `BoolArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `basic` &middot; `zero` &middot; `one` &middot; `length` &middot; `Size-negative` (raises Size) &middot; `elements-are-separate` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `unequal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `model*` &middot; `identity*` &middot; `long` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : elem list -> array
```

`fromList l` is a new array of the elements of `l`, in order.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `l` is longer than [`maxLen`](#val-maxlen).

**Law** `sub (fromList l, i) = List.nth (l, i)` for `0 <= i andalso i < List.length l` (for every `l : char list`, `i : int`)

**Example** `sub (fromList [#"a", #"b"], 1) = #"b"`

<details><summary>Tests (11)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `nil`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `basic` &middot; `nil` &middot; `singleton` &middot; `every-sample` &middot; `length` &middot; `same-elements-not-equal` &middot; `zero-length-not-equal` &middot; `round-trip*` &middot; `long`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> elem) -> array
```

`tabulate (n, f)` is a new array of `f 0`, ..., `f (n - 1)`, applied in order.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0` or `n > maxLen`.

> **Reading** `MONO_ARRAY.tabulate/Size-before-f`. The specification does not
> say whether the length is checked before `f` is applied. It is, as for
> [`Array.tabulate`](../sig/ARRAY.md#val-tabulate): a length out of range raises [`Size`](../sig/GENERAL.md#exn-size) without applying
> `f` at all.

**Law** `sub (tabulate (n, f), i) = f i` for `0 <= i andalso i < n andalso n <= maxLen`, when `f` has no effects, and it is run for `n` from
`Arb.intRange (0, 65536)`, as a longer one takes the tester too long (for every `n : int`, `f : int -> char`, `i : int`)

**Example** `vector (tabulate (3, fn i => Char.chr (97 + i))) = "abc"`

**Counterexample** `sub (tabulate (maxLen + 1, fn _ => #"x"), 0) = #"x"`, for
there is no array so long.

<details><summary>Tests (16)</summary>

For `Word8Array`, in [tests/basis/word8array.sml](../../../../tests/basis/word8array.sml): `every-byte`

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `string`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `BoolArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `basic` &middot; `zero` &middot; `one` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f` &middot; `same-elements-not-equal` &middot; `zero-length-not-equal` &middot; `model*` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-length"></a>`length`

```sml
val length : array -> int
```

`length x` is the number of elements.

**Law** `length (fromList l) = List.length l` (for every `l : char list`)

**Example** `length (fromList [#"a", #"b"]) = 2`

<details><summary>Tests (7)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `empty`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `empty` &middot; `five` &middot; `tabulate` &middot; `model*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : array * int -> elem
```

`sub (x, i)` is the element at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length x`.

**Example** `sub (fromList [#"a", #"b"], 0) = #"a"`

<details><summary>Tests (13)</summary>

For `Word8Array`, in [tests/basis/word8array.sml](../../../../tests/basis/word8array.sml): `elem-is-Word8.word`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `each` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `first` &middot; `middle` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-update"></a>`update`

```sml
val update : array * int * elem -> unit
```

`update (arr, i, x)` puts `x` at position `i` of `arr`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length arr`.

**Law** `(update (arr, i, x); sub (arr, i)) = x` for `0 <= i andalso i < length arr` (for every `arr : CharArray.array`, `i : int`, `x : char`)

**Example** `let val a = array (3, #"-") in update (a, 1, #"x"); vector a end = "-x-"`

<details><summary>Tests (18)</summary>

For `Word8Array`, in [tests/basis/word8array.sml](../../../../tests/basis/word8array.sml): `every-byte`

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `string`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `twice` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-changes-nothing`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `first` &middot; `middle` &middot; `last` &middot; `twice-same-index` &middot; `seen-through-alias` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model*` &middot; `model*` (raises Subscript)

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : array -> vector
```

`vector arr` is an immutable vector of the elements of `arr`, which is a copy.

**Example** `vector (fromList [#"h", #"i"]) = "hi"`

<details><summary>Tests (32)</summary>

For `Word8Array`, in [tests/basis/word8array.sml](../../../../tests/basis/word8array.sml): `is-Word8Vector.vector`

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `is-a-string` &middot; `empty-string` &middot; `is-CharVector.vector` &middot; `string-is-a-snapshot` &middot; `implode*`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `is-a-snapshot`

For `IntArray`, in [tests/basis/mono.int.sml](../../../../tests/basis/mono.int.sml): `extremes`

For `Int8Array`, in [tests/basis/mono.int8.sml](../../../../tests/basis/mono.int8.sml): `extremes`

For `Int16Array`, in [tests/basis/mono.int16.sml](../../../../tests/basis/mono.int16.sml): `extremes`

For `Int32Array`, in [tests/basis/mono.int32.sml](../../../../tests/basis/mono.int32.sml): `extremes`

For `LargeIntArray`, in [tests/basis/mono.largeint.sml](../../../../tests/basis/mono.largeint.sml): `extremes`

For `WordArray`, in [tests/basis/mono.word.sml](../../../../tests/basis/mono.word.sml): `extremes`

For `Word16Array`, in [tests/basis/mono.word16.sml](../../../../tests/basis/mono.word16.sml): `extremes`

For `Word32Array`, in [tests/basis/mono.word32.sml](../../../../tests/basis/mono.word32.sml): `extremes`

For `RealArray`, in [tests/basis/mono.real.sml](../../../../tests/basis/mono.real.sml): `specials`

For `RealArray`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `specials`

For `RealArray`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `specials`

For `Int64Array`, in [tests/basis/mono.int64.sml](../../../../tests/basis/mono.int64.sml): `extremes`

For `Word64Array`, in [tests/basis/mono.word64.sml](../../../../tests/basis/mono.word64.sml): `extremes`

For `Word64Array`, in [tests/basis/mono.largeword.sml](../../../../tests/basis/mono.largeword.sml): `extremes`

For `LargeWordArray`, in [tests/basis/mono.largeword.sml](../../../../tests/basis/mono.largeword.sml): `extremes`

For `LargeRealArray`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `specials`

For `Real64Array`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `specials`

For `Real32Array`, in [tests/basis/mono.real32.sml](../../../../tests/basis/mono.real32.sml): `specials`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `basic` &middot; `empty` &middot; `after-update` &middot; `is-a-snapshot` &middot; `model*` &middot; `long`

</details>

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : array, dst : array, di : int} -> unit
```

`copy {src, dst, di}` copies `src` into `dst` from position `di` on.

`src` and `dst` may be the same array, and then `di` must be 0: an array
cannot hold itself at any other position, so any other `di` raises
[`Subscript`](../sig/GENERAL.md#exn-subscript), and at 0 the copy changes nothing. Two stretches of one array
that overlap are what [`MONO_ARRAY_SLICE.copy`](../sig/MONO_ARRAY_SLICE.md#val-copy) is for.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `di < 0` or `di + length src > length dst`, and
then nothing has been copied.

**Law** `(copy {src = src, dst = dst, di = di}; sub (dst, di + i)) = sub (src, i)` for `0 <= di andalso di <= length dst - length src andalso 0 <= i andalso i < length src andalso src <> dst` (for every `src : CharArray.array`, `dst : CharArray.array`, `di : int`, `i : int`)

**Example** `let val b = array (4, #".") in copy {src = fromList [#"a", #"b", #"c"], dst = b, di = 1}; vector b end = ".abc"`

**Counterexample** `let val b = array (1, #".") in copy {src = fromList [#"a", #"b"], dst = b, di = 0}; sub (b, 0) end = #"a"`, for the source
does not fit.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `array` |  |
| <a name="fld-copy.dst"></a>`dst` | `array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

<details><summary>Tests (29)</summary>

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `string`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `middle` &middot; `to-the-end` &middot; `empty-at-length` &middot; `onto-itself` &middot; `Subscript-onto-itself-shifted` (raises Subscript) &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-changes-nothing`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `src-unchanged` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `copies-elements-not-the-array` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `onto-itself` &middot; `Subscript-onto-itself-shifted` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : vector, dst : array, di : int} -> unit
```

`copyVec {src, dst, di}` copies the vector `src` into `dst` from position `di` on.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `di < 0` or `di` plus the length of `src` is more
than `length dst`, and then nothing has been copied.

**Example** `let val a = array (4, #".") in copyVec {src = "ab", dst = a, di = 2}; vector a end = "..ab"`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `vector` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

<details><summary>Tests (27)</summary>

For `Word8Array`, in [tests/basis/word8array.sml](../../../../tests/basis/word8array.sml): `from-Word8Vector`

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `string-constant` &middot; `Subscript-string-too-long` (raises Subscript) &middot; `string-unchanged` &middot; `concat*`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `middle` &middot; `whole` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `src-unchanged` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `from-vector-of-array` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> array -> unit
```

`appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

**Example** `let val r = ref [] in appi (fn (i, c) => r := (i, c) :: !r) (fromList [#"a", #"b"]); !r end = [(1, #"b"), (0, #"a")]`

<details><summary>Tests (4)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `order`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> array -> unit
```

`app f x` applies `f` to every element, from 0 up, for its effect.

**Law** `app f x = appi (fn (_, e) => f e) x` (for every `f : char -> unit`, `x : CharArray.array`)

**Example** `let val s = ref 0 in app (fn c => s := !s + Char.ord c) (fromList [#"a", #"b"]); !s end = 195`

<details><summary>Tests (5)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `order`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `order` &middot; `empty` &middot; `array-unchanged` &middot; `model*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * elem -> elem) -> array -> unit
```

`modifyi f x` replaces the element at each position by `f` of the index and that element, in place, from 0 up.

**Example** `let val a = fromList [#"a", #"b", #"c"] in modifyi (fn (i, c) => if i = 1 then Char.toUpper c else c) a; vector a end = "aBc"`

<details><summary>Tests (9)</summary>

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `index`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `order`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `basic` &middot; `index-only` &middot; `empty` &middot; `order` &middot; `model*` &middot; `long`

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : (elem -> elem) -> array -> unit
```

`modify f x` replaces every element by `f` of it, in place, from 0 up.

**Law** `modify f x = modifyi (fn (_, e) => f e) x` (for every `f : char -> char`, `x : CharArray.array`)

**Example** `let val a = fromList [#"a", #"b"] in modify Char.toUpper a; vector a end = "AB"`

<details><summary>Tests (31)</summary>

For `Word8Array`, in [tests/basis/word8array.sml](../../../../tests/basis/word8array.sml): `Word8-arithmetic`

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `toUpper` &middot; `String.map*`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `not` &middot; `order`

For `IntArray`, in [tests/basis/mono.int.sml](../../../../tests/basis/mono.int.sml): `Int-arithmetic`

For `Int8Array`, in [tests/basis/mono.int8.sml](../../../../tests/basis/mono.int8.sml): `Int8-arithmetic`

For `Int16Array`, in [tests/basis/mono.int16.sml](../../../../tests/basis/mono.int16.sml): `Int16-arithmetic`

For `Int32Array`, in [tests/basis/mono.int32.sml](../../../../tests/basis/mono.int32.sml): `Int32-arithmetic`

For `LargeIntArray`, in [tests/basis/mono.largeint.sml](../../../../tests/basis/mono.largeint.sml): `LargeInt-arithmetic`

For `WordArray`, in [tests/basis/mono.word.sml](../../../../tests/basis/mono.word.sml): `Word-arithmetic`

For `Word16Array`, in [tests/basis/mono.word16.sml](../../../../tests/basis/mono.word16.sml): `Word16-arithmetic`

For `Word32Array`, in [tests/basis/mono.word32.sml](../../../../tests/basis/mono.word32.sml): `Word32-arithmetic`

For `RealArray`, in [tests/basis/mono.real.sml](../../../../tests/basis/mono.real.sml): `Real-arithmetic`

For `RealArray`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `LargeReal-arithmetic`

For `RealArray`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `Real64-arithmetic`

For `Int64Array`, in [tests/basis/mono.int64.sml](../../../../tests/basis/mono.int64.sml): `Int64-arithmetic`

For `Word64Array`, in [tests/basis/mono.word64.sml](../../../../tests/basis/mono.word64.sml): `Word64-arithmetic`

For `Word64Array`, in [tests/basis/mono.largeword.sml](../../../../tests/basis/mono.largeword.sml): `LargeWord-arithmetic`

For `LargeWordArray`, in [tests/basis/mono.largeword.sml](../../../../tests/basis/mono.largeword.sml): `LargeWord-arithmetic`

For `LargeRealArray`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `LargeReal-arithmetic`

For `Real64Array`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `Real64-arithmetic`

For `Real32Array`, in [tests/basis/mono.real32.sml](../../../../tests/basis/mono.real32.sml): `Real32-arithmetic`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `basic` &middot; `wraps` &middot; `empty` &middot; `order` &middot; `twice` &middot; `is-modifyi-of-second` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'b -> 'b) -> 'b -> array -> 'b
```

`foldli f init x` combines the elements from the left, giving `f` the index as well.

**Example** `foldli (fn (i, c, acc) => (i, c) :: acc) [] (fromList [#"a", #"b"]) = [(1, #"b"), (0, #"a")]`

<details><summary>Tests (5)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'b -> 'b) -> 'b -> array -> 'b
```

`foldri f init x` combines the elements from the right, giving `f` the index as well.

**Example** `foldri (fn (i, c, acc) => (i, c) :: acc) [] (fromList [#"a", #"b"]) = [(0, #"a"), (1, #"b")]`

<details><summary>Tests (5)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'b -> 'b) -> 'b -> array -> 'b
```

`foldl f init x` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

**Law** `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x` (for every `f : char * 'a -> 'a`, `init : 'a`, `x : CharArray.array`)

**Example** `foldl (op ::) [] (fromList [#"a", #"b", #"c"]) = [#"c", #"b", #"a"]`

<details><summary>Tests (8)</summary>

For `Word8Array`, in [tests/basis/word8array.sml](../../../../tests/basis/word8array.sml): `sum-of-bytes`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative` &middot; `empty`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'b -> 'b) -> 'b -> array -> 'b
```

`foldr f init x` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

**Law** `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x` (for every `f : char * 'a -> 'a`, `init : 'a`, `x : CharArray.array`)

**Example** `foldr (op ::) [] (fromList [#"a", #"b", #"c"]) = [#"a", #"b", #"c"]`

<details><summary>Tests (7)</summary>

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `implode`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> array -> (int * elem) option
```

`findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

`p` is applied from 0 up, and not after the first position that
satisfies it.

**Example** `findi (fn (i, c) => i > 0 andalso c = #"a") (fromList [#"a", #"b", #"a"]) = SOME (2, #"a")`

<details><summary>Tests (11)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `first-true` &middot; `none` &middot; `stops`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> array -> elem option
```

`find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

**Law** `find p x = Option.map #2 (findi (fn (_, e) => p e) x)` (for every `p : char -> bool`, `x : CharArray.array`)

**Example** `find Char.isDigit (fromList [#"a", #"1", #"2"]) = SOME #"1"`

<details><summary>Tests (10)</summary>

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `digit`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `false` &middot; `none` &middot; `stops`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `first-match` &middot; `last-element` &middot; `none` &middot; `empty` &middot; `stops` &middot; `model*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> array -> bool
```

`exists p x` is `true` when some element satisfies `p`; it stops at the first that does.

**Law** `exists p x = isSome (find p x)` (for every `p : char -> bool`, `x : CharArray.array`)

**Example** `exists Char.isDigit (fromList [#"a", #"b"]) = false`

<details><summary>Tests (9)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `true` &middot; `false` &middot; `stops`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> array -> bool
```

`all p x` is `true` when every element satisfies `p`; it stops at the first that does not.

**Law** `all p x = not (exists (not o p) x)` (for every `p : char -> bool`, `x : CharArray.array`)

**Example** `all Char.isLower (fromList [#"a", #"b"]) = true`

<details><summary>Tests (12)</summary>

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `true` &middot; `false` &middot; `empty` &middot; `stops`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*` &middot; `de-morgan*` &middot; `long`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> array * array -> order
```

`collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

This compares what the arrays hold, where `=` compares which array it
is.

**Law** `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)` (for every `cmp : char * char -> order`, `a : CharArray.array`, `b : CharArray.array`)

**Example** `collate Char.compare (fromList [#"a", #"b"], fromList [#"a", #"c"]) = LESS`

<details><summary>Tests (21)</summary>

For `Word8Array`, in [tests/basis/word8array.sml](../../../../tests/basis/word8array.sml): `unsigned-bytes`

For `CharArray`, in [tests/basis/chararray.sml](../../../../tests/basis/chararray.sml): `high-characters` &middot; `String.compare*`

For `BoolArray`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `equal` &middot; `first-difference` &middot; `prefix-less` &middot; `empty-less`

In [tests/basis/fn/mono\_array\_fn.sml](../../../../tests/basis/fn/mono_array_fn.sml), applied to `Word8Array`, `CharArray`, `IntArray`, `Int8Array`, `Int16Array`, `Int32Array`, `LargeIntArray`, `WordArray`, `Word16Array`, `Word32Array`, `RealArray`, `Int64Array`, `Word64Array`, `LargeWordArray`, `LargeRealArray`, `Real64Array`, `Real32Array`, `WideCharArray`: `equal` &middot; `same-array` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model*` &middot; `reflexive*` &middot; `long`

</details>

## See also

[`ARRAY`](../sig/ARRAY.md), [`MONO_VECTOR`](../sig/MONO_VECTOR.md), [`MONO_ARRAY_SLICE`](../sig/MONO_ARRAY_SLICE.md), [`MONO_ARRAY2`](../sig/MONO_ARRAY2.md)

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
