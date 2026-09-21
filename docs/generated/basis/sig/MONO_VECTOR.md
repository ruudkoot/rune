# signature MONO_VECTOR

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **MONO_VECTOR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 19 |
| Documentation | 22 of 22 entries documented |
| Tests | 285 checks of 22 entries |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_VECTOR
structure BoolVector :> MONO_VECTOR where type elem = bool  (* optional *)
structure CharVector : MONO_VECTOR where type vector = String.string where type elem = char
structure Int16Vector :> MONO_VECTOR where type elem = Int16.int  (* optional *)
structure Int32Vector :> MONO_VECTOR where type elem = Int32.int  (* optional *)
structure Int64Vector :> MONO_VECTOR where type elem = Int64.int  (* optional *)
structure Int8Vector :> MONO_VECTOR where type elem = Int8.int  (* optional *)
structure IntVector :> MONO_VECTOR where type elem = int  (* optional *)
structure LargeIntVector :> MONO_VECTOR where type elem = LargeInt.int  (* optional *)
structure LargeRealVector : MONO_VECTOR where type elem = LargeReal.real  (* optional *)
structure LargeWordVector : MONO_VECTOR where type elem = LargeWord.word  (* optional *)
structure Real32Vector :> MONO_VECTOR where type elem = Real32.real  (* optional *)
structure Real64Vector : MONO_VECTOR where type elem = Real64.real  (* optional *)
structure RealVector :> MONO_VECTOR where type elem = real  (* optional *)
structure WideCharVector :> MONO_VECTOR where type elem = WideChar.char  (* optional *)
structure Word16Vector :> MONO_VECTOR where type elem = Word16.word  (* optional *)
structure Word32Vector :> MONO_VECTOR where type elem = Word32.word  (* optional *)
structure Word64Vector :> MONO_VECTOR where type elem = Word64.word  (* optional *)
structure Word8Vector : MONO_VECTOR where type elem = Word8.word
structure WordVector :> MONO_VECTOR where type elem = word  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `BoolVector` | The monomorphic vectors and arrays of booleans and their slices, and the two-dimensional arrays (all optional in the specification), in one file: a program that names one of them loads the five. The vector is a polymorphic vector (RuneMonoVectorFn), the array a polymorphic array. | [lib/basis/mono\_bool.sml](../../../../lib/basis/mono_bool.sml) |
| `CharVector` | CharVector: CharVector.vector is string. | [lib/basis/charvector.sml](../../../../lib/basis/charvector.sml) |
| `Int16Vector` | The monomorphic vectors and arrays of Int16.int, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_int16.sml](../../../../lib/basis/mono_int16.sml) |
| `Int32Vector` | The monomorphic vectors and arrays of Int32.int, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_int32.sml](../../../../lib/basis/mono_int32.sml) |
| `Int64Vector` | The vectors, arrays, slices and two-dimensional arrays of Int64 (optional in the specification). Int64.int is a type of its own, so these are their own structures and not those of Int. | [lib/basis/mono\_int64.sml](../../../../lib/basis/mono_int64.sml) |
| `Int8Vector` | The monomorphic vectors and arrays of Int8.int, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_int8.sml](../../../../lib/basis/mono_int8.sml) |
| `IntVector` | The monomorphic vectors and arrays of int, their slices and the two-dimensional arrays (optional in the specification). Int64Vector and the rest of that family are these (mono\_int64.sml). | [lib/basis/mono\_int.sml](../../../../lib/basis/mono_int.sml) |
| `LargeIntVector` | The monomorphic vectors and arrays of LargeInt.int (IntInf.int), their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_largeint.sml](../../../../lib/basis/mono_largeint.sml) |
| `LargeRealVector` | LargeReal is Real, so its vectors, arrays, slices and two-dimensional arrays (optional in the specification) are those of Real. | [lib/basis/mono\_largereal.sml](../../../../lib/basis/mono_largereal.sml) |
| `LargeWordVector` | LargeWord is Word, so its vectors, arrays, slices and two-dimensional arrays (optional in the specification) are those of Word. | [lib/basis/mono\_largeword.sml](../../../../lib/basis/mono_largeword.sml) |
| `Real32Vector` | The monomorphic vectors and arrays of Real32.real, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_real32.sml](../../../../lib/basis/mono_real32.sml) |
| `Real64Vector` | Real64 is Real, so its vectors, arrays, slices and two-dimensional arrays (optional in the specification) are those of Real. | [lib/basis/mono\_real64.sml](../../../../lib/basis/mono_real64.sml) |
| `RealVector` | The monomorphic vectors and arrays of real, their slices and the two-dimensional arrays (optional in the specification). The elements do not admit equality, which MONO\_VECTOR and MONO\_ARRAY do not ask of them. LargeRealVector, Real64Vector and the rest of those families are these (mono\_largereal.sml, mono\_real64.sml). | [lib/basis/mono\_real.sml](../../../../lib/basis/mono_real.sml) |
| `WideCharVector` | Sealed with a vector of its own (MONO\_VECTOR\_EQ), so that WideString.string is a type name: the constants of a type are overloaded at a name. | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |
| `Word16Vector` | The monomorphic vectors and arrays of Word16.word, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_word16.sml](../../../../lib/basis/mono_word16.sml) |
| `Word32Vector` | The monomorphic vectors and arrays of Word32.word, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_word32.sml](../../../../lib/basis/mono_word32.sml) |
| `Word64Vector` | The vectors, arrays, slices and two-dimensional arrays of Word64 (optional in the specification). Word64.word is a type of its own, so these are their own structures and not those of Word. | [lib/basis/mono\_word64.sml](../../../../lib/basis/mono_word64.sml) |
| `Word8Vector` |  | [lib/basis/word8vector.sml](../../../../lib/basis/word8vector.sml) |
| `WordVector` | The monomorphic vectors and arrays of word, their slices and the two-dimensional arrays (optional in the specification). LargeWordVector, Word64Vector and the rest of those families are these (mono\_largeword.sml, mono\_word64.sml). | [lib/basis/mono\_word.sml](../../../../lib/basis/mono_word.sml) |

The sequences of one element type: vectors, arrays and their slices, as
[`VECTOR`](../sig/VECTOR.md), [`ARRAY`](../sig/ARRAY.md), [`VECTOR_SLICE`](../sig/VECTOR_SLICE.md) and [`ARRAY_SLICE`](../sig/ARRAY_SLICE.md) describe them for any
element type.

Fixing the element type lets an implementation pack the elements, so
[`Word8Vector`](MONO_VECTOR.md) need not hold one machine word per byte, and it gives the
byte- and character-oriented parts of the library ([`BYTE`](../sig/BYTE.md), [`TEXT`](../sig/TEXT.md),
[`BIN_IO`](../sig/BIN_IO.md)) a sequence type to name. The members are those of the
polymorphic signatures, with [`elem`](#type-elem) for the element type; what they mean
is the same, and the pages of [`VECTOR`](../sig/VECTOR.md) and [`ARRAY`](../sig/ARRAY.md) describe it at more
length.

> **Erratum** `MONO_VECTOR/WideCharVector-must-admit-equality`. The page writes
> `type vector`, not `eqtype`, so that a family whose elements do not admit
> equality can have a vector -- [`RealVector`](MONO_VECTOR.md) needs that. Where a vector has
> to admit equality the page says so on the instance instead: [`CharVector`](MONO_VECTOR.md)
> is declared `where type vector = String.string`, and [`STRING`](../sig/STRING.md) writes
> `eqtype string`. \*\*[`WideCharVector`](MONO_VECTOR.md) is declared `where type elem = WideChar.char` and nothing more, and that is not enough.\*\* [`TEXT`](../sig/TEXT.md) shares
> [`String.string`](../sig/STRING.md#type-string) with [`CharVector.vector`](#type-vector), and [`WideText`](../sig/TEXT.md) is declared
> `where type String.string = WideString.string`, so
> [`WideText.CharVector.vector`](#type-vector) is [`WideString.string`](../sig/STRING.md#type-string), which [`STRING`](../sig/STRING.md) makes
> an equality type. Any implementation whose [`WideText.CharVector`](../sig/TEXT.md#str-charvector) is the
> top-level [`WideCharVector`](MONO_VECTOR.md) \-- every one that has both -- must therefore
> give [`WideCharVector.vector`](#type-vector) equality, and the declaration the page gives
> it cannot. \*\*The whole of the defect is one missing constraint\*\*:
> `where type vector = WideString.string`, which [`CharVector`](MONO_VECTOR.md) has and
> [`WideCharVector`](MONO_VECTOR.md) does not. That makes this a milder fault than the one on
> the page of [`ARRAY2`](../sig/ARRAY2.md), where no constraint can help because there is no
> type to pin to; here [`WideString.string`](../sig/STRING.md#type-string) is already there and [`STRING`](../sig/STRING.md)
> already makes it an equality type.

Rune gives the equality the other way, by sealing with [`MONO_VECTOR_EQ`](../sig/MONO_VECTOR_EQ.md).
That is a consequence of \*this\* library's order and not of the fault:
[`WideString`](../sig/STRING.md) is built on [`WideCharVector`](MONO_VECTOR.md) (`type string = V.vector`, and
every operation delegates), so [`WideCharVector`](MONO_VECTOR.md) is where the type name is
born and there is nothing yet to pin it to. Following the page as it
should have been written would mean giving [`WideString`](../sig/STRING.md) a representation
of its own and pinning [`WideCharVector`](MONO_VECTOR.md) to it -- a change to two files,
not a rename -- and [`MONO_VECTOR_EQ`](../sig/MONO_VECTOR_EQ.md) would then be unnecessary.

<details><summary>Other implementations (1)</summary>

- **MLton 20241230** &mdash; BoolVector.length (BoolArray.vector (BoolArray.array (3, true))) is 0 in a program that also uses BoolArraySlice (copyVec, full, sub) or BoolArray2; alone it is 3, and 20210117 gives 3 in the same program

</details>

## Interface

<pre>
signature MONO_VECTOR =
sig
  type <a href="#type-vector">vector</a>

  type <a href="#type-elem">elem</a>

  val <a href="#val-maxlen">maxLen</a> : int

  val <a href="#val-fromlist">fromList</a> : elem list -&gt; vector

  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; elem) -&gt; vector

  val <a href="#val-length">length</a> : vector -&gt; int

  val <a href="#val-sub">sub</a> : vector * int -&gt; elem

  val <a href="#val-update">update</a> : vector * int * elem -&gt; vector

  val <a href="#val-concat">concat</a> : vector list -&gt; vector

  val <a href="#val-appi">appi</a> : (int * elem -&gt; unit) -&gt; vector -&gt; unit

  val <a href="#val-app">app</a> : (elem -&gt; unit) -&gt; vector -&gt; unit

  val <a href="#val-mapi">mapi</a> : (int * elem -&gt; elem) -&gt; vector -&gt; vector

  val <a href="#val-map">map</a> : (elem -&gt; elem) -&gt; vector -&gt; vector

  val <a href="#val-foldli">foldli</a> : (int * elem * 'a -&gt; 'a) -&gt; 'a -&gt; vector -&gt; 'a

  val <a href="#val-foldri">foldri</a> : (int * elem * 'a -&gt; 'a) -&gt; 'a -&gt; vector -&gt; 'a

  val <a href="#val-foldl">foldl</a> : (elem * 'a -&gt; 'a) -&gt; 'a -&gt; vector -&gt; 'a

  val <a href="#val-foldr">foldr</a> : (elem * 'a -&gt; 'a) -&gt; 'a -&gt; vector -&gt; 'a

  val <a href="#val-findi">findi</a> : (int * elem -&gt; bool) -&gt; vector -&gt; (int * elem) option

  val <a href="#val-find">find</a> : (elem -&gt; bool) -&gt; vector -&gt; elem option

  val <a href="#val-exists">exists</a> : (elem -&gt; bool) -&gt; vector -&gt; bool

  val <a href="#val-all">all</a> : (elem -&gt; bool) -&gt; vector -&gt; bool

  val <a href="#val-collate">collate</a> : (elem * elem -&gt; order) -&gt; vector * vector -&gt; order
end
</pre>

### <a name="type-vector"></a>`vector`

```sml
type vector
```

The type of these vectors.

> **Implementation** `MONO_VECTOR.vector/abstract-over-the-polymorphic-one`.
> A monomorphic vector is the polymorphic vector of its elements
> underneath -- the vectors of characters are strings, which the
> specification requires -- but the type is abstract: an [`IntVector.vector`](#type-vector)
> is no `int vector` for a program, as it is none in MLton or SML/NJ. The
> arrays and the two-dimensional arrays are the same. Sealing them costs
> nothing: the instruction counts of `runevm --count` do not change at
> all, because no file of the library goes between the two. No check of
> the suite can pin this -- that a type is abstract is not something a
> program can observe at run time -- and what holds it is the page of the
> types that are one type, which `make check` compares with the library as
> it stands.

<details><summary>Tests (2)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `is-String.string` &middot; `string-equality`

</details>

### <a name="type-elem"></a>`elem`

```sml
type elem
```

The type of the elements: [`Word8.word`](../sig/WORD.md#type-word) for [`Word8Vector`](MONO_VECTOR.md), `char` for [`CharVector`](MONO_VECTOR.md).

<details><summary>Tests (2)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `is-char`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `eight-distinct-samples`

</details>

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

The greatest length such a vector may have.

> **Implementation** `MONO_VECTOR.maxLen/value`. The same bound as
> [`Vector.maxLen`](../sig/VECTOR.md#val-maxlen) for the families built on the polymorphic vectors, and
> [`String.maxSize`](../sig/STRING.md#val-maxsize) for those whose vector is a string.

<details><summary>Tests (2)</summary>

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `covers-created-vectors`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `covers-created-vectors`

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : elem list -> vector
```

`fromList l` is the sequence of the elements of `l`, in order.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `l` is longer than [`maxLen`](#val-maxlen).

<details><summary>Tests (29)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `is-implode` &middot; `nil-is-the-empty-string` &middot; `explode*`

For `Word8Vector`, in [tests/basis/word8vector.sml](../../../../tests/basis/word8vector.sml): `every-byte`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `nil` &middot; `length`

For `IntVector`, in [tests/basis/mono.int.sml](../../../../tests/basis/mono.int.sml): `extremes`

For `Int8Vector`, in [tests/basis/mono.int8.sml](../../../../tests/basis/mono.int8.sml): `extremes`

For `Int16Vector`, in [tests/basis/mono.int16.sml](../../../../tests/basis/mono.int16.sml): `extremes`

For `Int32Vector`, in [tests/basis/mono.int32.sml](../../../../tests/basis/mono.int32.sml): `extremes`

For `LargeIntVector`, in [tests/basis/mono.largeint.sml](../../../../tests/basis/mono.largeint.sml): `extremes`

For `WordVector`, in [tests/basis/mono.word.sml](../../../../tests/basis/mono.word.sml): `extremes`

For `Word16Vector`, in [tests/basis/mono.word16.sml](../../../../tests/basis/mono.word16.sml): `extremes`

For `Word32Vector`, in [tests/basis/mono.word32.sml](../../../../tests/basis/mono.word32.sml): `extremes`

For `RealVector`, in [tests/basis/mono.real.sml](../../../../tests/basis/mono.real.sml): `specials`

For `Int64Vector`, in [tests/basis/mono.int64.sml](../../../../tests/basis/mono.int64.sml): `extremes`

For `LargeWordVector`, in [tests/basis/mono.largeword.sml](../../../../tests/basis/mono.largeword.sml): `extremes`

For `Word64Vector`, in [tests/basis/mono.word64.sml](../../../../tests/basis/mono.word64.sml): `extremes`

For `LargeRealVector`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `specials`

For `Real64Vector`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `specials`

For `Real32Vector`, in [tests/basis/mono.real32.sml](../../../../tests/basis/mono.real32.sml): `specials`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `basic` &middot; `nil` &middot; `singleton` &middot; `every-sample` &middot; `length` &middot; `round-trip*` &middot; `long`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> elem) -> vector
```

`tabulate (n, f)` is the sequence of `f 0`, ..., `f (n - 1)`, applied in order.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0` or `n > maxLen`, before `f` is applied.

<details><summary>Tests (15)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `string`

For `Word8Vector`, in [tests/basis/word8vector.sml](../../../../tests/basis/word8vector.sml): `every-byte`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `zero` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `basic` &middot; `zero` &middot; `one` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f` &middot; `model*` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-length"></a>`length`

```sml
val length : vector -> int
```

`length x` is the number of elements.

<details><summary>Tests (10)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `is-size` &middot; `empty-string` &middot; `size*`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `empty` &middot; `long`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `empty` &middot; `five` &middot; `tabulate` &middot; `model*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : vector * int -> elem
```

`sub (x, i)` is the element at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is outside.

<details><summary>Tests (16)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `string-constant` &middot; `Subscript-at-size` (raises Subscript)

For `Word8Vector`, in [tests/basis/word8vector.sml](../../../../tests/basis/word8vector.sml): `elem-is-Word8.word`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `each` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript)

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `first` &middot; `middle` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-update"></a>`update`

```sml
val update : vector * int * elem -> vector
```

`update (v, i, x)` is a new vector like `v` but with `x` at position `i`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is outside `v`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; Vector.update, Word8Vector.update and CharVector.update return the vector unchanged instead of raising Subscript when the index is out of range

</details>

<details><summary>Tests (20)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `string` &middot; `constant-unchanged`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `first` &middot; `middle` &middot; `last` &middot; `argument-unchanged` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `first` &middot; `middle` &middot; `last` &middot; `singleton` &middot; `argument-unchanged` &middot; `twice` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : vector list -> vector
```

`concat l` is the vectors of `l` one after another.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`maxLen`](#val-maxlen).

<details><summary>Tests (15)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `strings` &middot; `String.concat*`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `nil` &middot; `empties`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `basic` &middot; `nil` &middot; `one` &middot; `empties` &middot; `same-twice` &middot; `order` &middot; `model*` &middot; `long` &middot; `many` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> vector -> unit
```

`appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

<details><summary>Tests (5)</summary>

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `order` &middot; `empty`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> vector -> unit
```

`app f x` applies `f` to every element, from 0 up, for its effect.

<details><summary>Tests (5)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `string`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `order`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * elem -> elem) -> vector -> vector
```

`mapi f v` is the vector of the results of `f` on the index and the element of each position.

<details><summary>Tests (9)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `index`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `order`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `basic` &middot; `index-only` &middot; `empty` &middot; `order` &middot; `model*` &middot; `long`

</details>

### <a name="val-map"></a>`map`

```sml
val map : (elem -> elem) -> vector -> vector
```

`map f v` is the vector of the results of `f` on each element, in order.

<details><summary>Tests (17)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `toUpper` &middot; `String.map*`

For `Word8Vector`, in [tests/basis/word8vector.sml](../../../../tests/basis/word8vector.sml): `Word8-arithmetic`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `not` &middot; `empty` &middot; `order`

For `RealVector`, in [tests/basis/mono.real.sml](../../../../tests/basis/mono.real.sml): `Real-arithmetic`

For `LargeRealVector`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `LargeReal-arithmetic`

For `Real64Vector`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `Real64-arithmetic`

For `Real32Vector`, in [tests/basis/mono.real32.sml](../../../../tests/basis/mono.real32.sml): `Real32-arithmetic`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `basic` &middot; `wraps` &middot; `empty` &middot; `order` &middot; `argument-unchanged` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'a -> 'a) -> 'a -> vector -> 'a
```

`foldli f init x` combines the elements from the left, giving `f` the index as well.

<details><summary>Tests (7)</summary>

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'a -> 'a) -> 'a -> vector -> 'a
```

`foldri f init x` combines the elements from the right, giving `f` the index as well.

<details><summary>Tests (6)</summary>

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `conses-in-order` &middot; `nonassociative`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'a -> 'a) -> 'a -> vector -> 'a
```

`foldl f init x` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

<details><summary>Tests (24)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `reverse`

For `Word8Vector`, in [tests/basis/word8vector.sml](../../../../tests/basis/word8vector.sml): `sum-of-bytes`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative` &middot; `conses-reversed`

For `IntVector`, in [tests/basis/mono.int.sml](../../../../tests/basis/mono.int.sml): `Int-arithmetic`

For `Int8Vector`, in [tests/basis/mono.int8.sml](../../../../tests/basis/mono.int8.sml): `Int8-arithmetic`

For `Int16Vector`, in [tests/basis/mono.int16.sml](../../../../tests/basis/mono.int16.sml): `Int16-arithmetic`

For `Int32Vector`, in [tests/basis/mono.int32.sml](../../../../tests/basis/mono.int32.sml): `Int32-arithmetic`

For `LargeIntVector`, in [tests/basis/mono.largeint.sml](../../../../tests/basis/mono.largeint.sml): `LargeInt-arithmetic`

For `WordVector`, in [tests/basis/mono.word.sml](../../../../tests/basis/mono.word.sml): `Word-arithmetic`

For `Word16Vector`, in [tests/basis/mono.word16.sml](../../../../tests/basis/mono.word16.sml): `Word16-arithmetic`

For `Word32Vector`, in [tests/basis/mono.word32.sml](../../../../tests/basis/mono.word32.sml): `Word32-arithmetic`

For `RealVector`, in [tests/basis/mono.real.sml](../../../../tests/basis/mono.real.sml): `Real-arithmetic`

For `Int64Vector`, in [tests/basis/mono.int64.sml](../../../../tests/basis/mono.int64.sml): `Int64-arithmetic`

For `LargeWordVector`, in [tests/basis/mono.largeword.sml](../../../../tests/basis/mono.largeword.sml): `LargeWord-arithmetic`

For `Word64Vector`, in [tests/basis/mono.word64.sml](../../../../tests/basis/mono.word64.sml): `Word64-arithmetic`

For `LargeRealVector`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `LargeReal-arithmetic`

For `Real64Vector`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `Real64-arithmetic`

For `Real32Vector`, in [tests/basis/mono.real32.sml](../../../../tests/basis/mono.real32.sml): `Real32-arithmetic`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'a -> 'a) -> 'a -> vector -> 'a
```

`foldr f init x` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

<details><summary>Tests (8)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `implode`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `nonassociative` &middot; `conses-in-order`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> vector -> (int * elem) option
```

`findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

<details><summary>Tests (14)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `string`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `first-true` &middot; `by-index` &middot; `none` &middot; `empty` &middot; `stops`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> vector -> elem option
```

`find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

<details><summary>Tests (15)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `string`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `true` &middot; `false` &middot; `none` &middot; `stops`

For `RealVector`, in [tests/basis/mono.real.sml](../../../../tests/basis/mono.real.sml): `nan`

For `LargeRealVector`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `nan`

For `Real64Vector`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `nan`

For `Real32Vector`, in [tests/basis/mono.real32.sml](../../../../tests/basis/mono.real32.sml): `nan`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `first-match` &middot; `last-element` &middot; `none` &middot; `empty` &middot; `stops` &middot; `model*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> vector -> bool
```

`exists p x` is `true` when some element satisfies `p`.

<details><summary>Tests (11)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `string`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `true` &middot; `false` &middot; `empty` &middot; `stops`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> vector -> bool
```

`all p x` is `true` when every element satisfies `p`.

<details><summary>Tests (13)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `string`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `true` &middot; `false` &middot; `empty` &middot; `stops`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*` &middot; `de-morgan*` &middot; `long`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> vector * vector -> order
```

`collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

<details><summary>Tests (40)</summary>

For `CharVector`, in [tests/basis/charvector.sml](../../../../tests/basis/charvector.sml): `strings` &middot; `high-characters` &middot; `String.compare*`

For `Word8Vector`, in [tests/basis/word8vector.sml](../../../../tests/basis/word8vector.sml): `unsigned-bytes`

For `BoolVector`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `equal` &middot; `empty-empty` &middot; `empty-less` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering`

For `IntVector`, in [tests/basis/mono.int.sml](../../../../tests/basis/mono.int.sml): `Int.compare`

For `Int8Vector`, in [tests/basis/mono.int8.sml](../../../../tests/basis/mono.int8.sml): `Int8.compare`

For `Int16Vector`, in [tests/basis/mono.int16.sml](../../../../tests/basis/mono.int16.sml): `Int16.compare`

For `Int32Vector`, in [tests/basis/mono.int32.sml](../../../../tests/basis/mono.int32.sml): `Int32.compare`

For `LargeIntVector`, in [tests/basis/mono.largeint.sml](../../../../tests/basis/mono.largeint.sml): `LargeInt.compare`

For `WordVector`, in [tests/basis/mono.word.sml](../../../../tests/basis/mono.word.sml): `Word.compare-unsigned`

For `Word16Vector`, in [tests/basis/mono.word16.sml](../../../../tests/basis/mono.word16.sml): `Word16.compare-unsigned`

For `Word32Vector`, in [tests/basis/mono.word32.sml](../../../../tests/basis/mono.word32.sml): `Word32.compare-unsigned`

For `RealVector`, in [tests/basis/mono.real.sml](../../../../tests/basis/mono.real.sml): `Real.compare`

For `Int64Vector`, in [tests/basis/mono.int64.sml](../../../../tests/basis/mono.int64.sml): `Int64.compare`

For `LargeWordVector`, in [tests/basis/mono.largeword.sml](../../../../tests/basis/mono.largeword.sml): `LargeWord.compare-unsigned`

For `Word64Vector`, in [tests/basis/mono.word64.sml](../../../../tests/basis/mono.word64.sml): `Word64.compare-unsigned`

For `LargeRealVector`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `LargeReal.compare`

For `Real64Vector`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `Real64.compare`

For `Real32Vector`, in [tests/basis/mono.real32.sml](../../../../tests/basis/mono.real32.sml): `Real32.compare`

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `CharVector`, `Word8Vector`, `IntVector`, `Int8Vector`, `Int16Vector`, `Int32Vector`, `LargeIntVector`, `WordVector`, `Word16Vector`, `Word32Vector`, `RealVector`, `Int64Vector`, `LargeWordVector`, `Word64Vector`, `LargeRealVector`, `Real64Vector`, `Real32Vector`, `WideCharVector`: `equal` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model*` &middot; `reflexive*` &middot; `long`

</details>

## See also

[`VECTOR`](../sig/VECTOR.md), [`ARRAY`](../sig/ARRAY.md), [`VECTOR_SLICE`](../sig/VECTOR_SLICE.md), [`ARRAY_SLICE`](../sig/ARRAY_SLICE.md), [`MONO_ARRAY2`](../sig/MONO_ARRAY2.md),
[`MONO_VECTOR_EQ`](../sig/MONO_VECTOR_EQ.md), [`TEXT`](../sig/TEXT.md), [`BYTE`](../sig/BYTE.md)

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
