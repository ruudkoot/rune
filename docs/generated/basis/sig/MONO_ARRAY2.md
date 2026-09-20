# signature MONO_ARRAY2

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **MONO_ARRAY2**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 18 |
| Documentation | 22 of 22 entries documented |
| Tests | 340 checks of 19 entries |
| Source | [lib/basis/sig\_mono\_array2.sml](../../../../lib/basis/sig_mono_array2.sml) |

## Synopsis

```sml
signature MONO_ARRAY2
structure BoolArray2 : MONO_ARRAY2 where type vector = BoolVector.vector where type elem = bool  (* optional *)
structure CharArray2 : MONO_ARRAY2 where type vector = CharVector.vector where type elem = char  (* optional *)
structure Int16Array2 : MONO_ARRAY2 where type vector = Int16Vector.vector where type elem = Int16.int  (* optional *)
structure Int32Array2 : MONO_ARRAY2 where type vector = Int32Vector.vector where type elem = Int32.int  (* optional *)
structure Int64Array2 : MONO_ARRAY2 where type vector = Int64Vector.vector where type elem = Int64.int  (* optional *)
structure Int8Array2 : MONO_ARRAY2 where type vector = Int8Vector.vector where type elem = Int8.int  (* optional *)
structure IntArray2 : MONO_ARRAY2 where type vector = IntVector.vector where type elem = int  (* optional *)
structure LargeIntArray2 : MONO_ARRAY2 where type vector = LargeIntVector.vector where type elem = LargeInt.int  (* optional *)
structure LargeRealArray2 : MONO_ARRAY2 where type vector = LargeRealVector.vector where type elem = LargeReal.real  (* optional *)
structure LargeWordArray2 : MONO_ARRAY2 where type vector = LargeWordVector.vector where type elem = LargeWord.word  (* optional *)
structure Real32Array2 : MONO_ARRAY2 where type vector = Real32Vector.vector where type elem = Real32.real  (* optional *)
structure Real64Array2 : MONO_ARRAY2 where type vector = Real64Vector.vector where type elem = Real64.real  (* optional *)
structure RealArray2 : MONO_ARRAY2 where type vector = RealVector.vector where type elem = real  (* optional *)
structure Word16Array2 : MONO_ARRAY2 where type vector = Word16Vector.vector where type elem = Word16.word  (* optional *)
structure Word32Array2 : MONO_ARRAY2 where type vector = Word32Vector.vector where type elem = Word32.word  (* optional *)
structure Word64Array2 : MONO_ARRAY2 where type vector = Word64Vector.vector where type elem = Word64.word  (* optional *)
structure Word8Array2 : MONO_ARRAY2 where type vector = Word8Vector.vector where type elem = Word8.word  (* optional *)
structure WordArray2 : MONO_ARRAY2 where type vector = WordVector.vector where type elem = word  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `BoolArray2` |  | [lib/basis/mono\_bool.sml](../../../../lib/basis/mono_bool.sml) |
| `CharArray2` | CharArray2: two-dimensional arrays of characters (optional in the specification), whose rows and columns are strings. | [lib/basis/chararray2.sml](../../../../lib/basis/chararray2.sml) |
| `Int16Array2` |  | [lib/basis/mono\_int16.sml](../../../../lib/basis/mono_int16.sml) |
| `Int32Array2` |  | [lib/basis/mono\_int32.sml](../../../../lib/basis/mono_int32.sml) |
| `Int64Array2` |  | [lib/basis/mono\_int64.sml](../../../../lib/basis/mono_int64.sml) |
| `Int8Array2` |  | [lib/basis/mono\_int8.sml](../../../../lib/basis/mono_int8.sml) |
| `IntArray2` |  | [lib/basis/mono\_int.sml](../../../../lib/basis/mono_int.sml) |
| `LargeIntArray2` |  | [lib/basis/mono\_largeint.sml](../../../../lib/basis/mono_largeint.sml) |
| `LargeRealArray2` |  | [lib/basis/mono\_largereal.sml](../../../../lib/basis/mono_largereal.sml) |
| `LargeWordArray2` |  | [lib/basis/mono\_largeword.sml](../../../../lib/basis/mono_largeword.sml) |
| `Real32Array2` |  | [lib/basis/mono\_real32.sml](../../../../lib/basis/mono_real32.sml) |
| `Real64Array2` |  | [lib/basis/mono\_real64.sml](../../../../lib/basis/mono_real64.sml) |
| `RealArray2` |  | [lib/basis/mono\_real.sml](../../../../lib/basis/mono_real.sml) |
| `Word16Array2` |  | [lib/basis/mono\_word16.sml](../../../../lib/basis/mono_word16.sml) |
| `Word32Array2` |  | [lib/basis/mono\_word32.sml](../../../../lib/basis/mono_word32.sml) |
| `Word64Array2` |  | [lib/basis/mono\_word64.sml](../../../../lib/basis/mono_word64.sml) |
| `Word8Array2` | Word8Array2: two-dimensional arrays of bytes (optional in the specification), whose rows and columns are Word8Vector.vector values. | [lib/basis/word8array2.sml](../../../../lib/basis/word8array2.sml) |
| `WordArray2` |  | [lib/basis/mono\_word.sml](../../../../lib/basis/mono_word.sml) |

Two-dimensional arrays of one element type, as [`ARRAY2`](../sig/ARRAY2.md) describes them for
any element type.

Everything here means what it means in [`ARRAY2`](../sig/ARRAY2.md), whose page describes
regions and traversals at more length; only the element type is fixed, and
[`row`](#val-row) and [`column`](#val-column) give the vector of that element type rather than a
polymorphic one.

> **Erratum** `MONO_ARRAY2/instance-constraints`. The specification writes the
> identity of [`vector`](#type-vector) with the family's vector and of [`elem`](#type-elem) with its
> element as constraints on the structure; they are checked in the suite
> instead, structure by structure.

## Contents

[Making an array](#making-an-array) &middot;
[Elements](#elements) &middot;
[Shape](#shape) &middot;
[Copying](#copying) &middot;
[Traversing](#traversing)

## Interface

<pre>
signature MONO_ARRAY2 =
sig
  eqtype <a href="#type-array">array</a>

  type <a href="#type-elem">elem</a>

  type <a href="#type-vector">vector</a>

  type <a href="#type-region">region</a> = {<a href="#fld-region.base">base</a> : array, <a href="#fld-region.row">row</a> : int, <a href="#fld-region.col">col</a> : int, <a href="#fld-region.nrows">nrows</a> : int option, <a href="#fld-region.ncols">ncols</a> : int option}

  datatype <a href="#type-traversal">traversal</a> = datatype Array2.traversal

  val <a href="#val-array">array</a> : int * int * elem -&gt; array

  val <a href="#val-fromlist">fromList</a> : elem list list -&gt; array

  val <a href="#val-tabulate">tabulate</a> : traversal -&gt; int * int * (int * int -&gt; elem) -&gt; array

  val <a href="#val-sub">sub</a> : array * int * int -&gt; elem

  val <a href="#val-update">update</a> : array * int * int * elem -&gt; unit

  val <a href="#val-dimensions">dimensions</a> : array -&gt; int * int

  val <a href="#val-ncols">nCols</a> : array -&gt; int

  val <a href="#val-nrows">nRows</a> : array -&gt; int

  val <a href="#val-row">row</a> : array * int -&gt; vector

  val <a href="#val-column">column</a> : array * int -&gt; vector

  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : region, <a href="#fld-copy.dst">dst</a> : array, <a href="#fld-copy.dst_row">dst_row</a> : int, <a href="#fld-copy.dst_col">dst_col</a> : int} -&gt; unit

  val <a href="#val-appi">appi</a> : traversal -&gt; (int * int * elem -&gt; unit) -&gt; region -&gt; unit

  val <a href="#val-app">app</a> : traversal -&gt; (elem -&gt; unit) -&gt; array -&gt; unit

  val <a href="#val-foldi">foldi</a> : traversal -&gt; (int * int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; region -&gt; 'b

  val <a href="#val-fold">fold</a> : traversal -&gt; (elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b

  val <a href="#val-modifyi">modifyi</a> : traversal -&gt; (int * int * elem -&gt; elem) -&gt; region -&gt; unit

  val <a href="#val-modify">modify</a> : traversal -&gt; (elem -&gt; elem) -&gt; array -&gt; unit
end
</pre>

### <a name="type-array"></a>`array`

```sml
eqtype array
```

The type of these two-dimensional arrays.

Two are equal when they are the same array.

<details><summary>Tests (28)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `no-rows` &middot; `Size-negative` (raises Size) &middot; `same-elements-not-equal` &middot; `same-array-is-equal`

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `basic` &middot; `one` &middot; `dimensions` &middot; `no-rows` &middot; `no-columns` &middot; `no-rows-no-columns` &middot; `no-columns-rows` &middot; `Size-negative-rows` (raises Size) &middot; `Size-negative-columns` (raises Size) &middot; `Size-negative-both` (raises Size) &middot; `Size-negative-rows-no-columns` (raises Size) &middot; `Size-negative-columns-no-rows` (raises Size) &middot; `elements-are-separate` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `*` &middot; `Size-too-large` (raises Size) &middot; `Size-too-large-rows` (raises Size) &middot; `Size-too-large-columns` (raises Size)

</details>

### <a name="type-elem"></a>`elem`

```sml
type elem
```

The type of the elements.

<details><summary>Tests (1)</summary>

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `sixteen-distinct-samples`

</details>

### <a name="type-vector"></a>`vector`

```sml
type vector
```

The type of the vectors that [`row`](#val-row) and [`column`](#val-column) give: the one of the family.

### <a name="type-region"></a>`region`

```sml
type region = {base : array, row : int, col : int, nrows : int option, ncols : int option}
```

A rectangle inside an array, as in [`ARRAY2`](../sig/ARRAY2.md): where it starts and how far
it reaches, with `NONE` for "to the edge".

> **Reading** `MONO_ARRAY2.region/at-the-end`. A region that starts at the
> edge of the array, and one of no rows or no columns, is valid and
> covers nothing.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-region.base"></a>`base` | `array` |  |
| <a name="fld-region.row"></a>`row` | `int` |  |
| <a name="fld-region.col"></a>`col` | `int` |  |
| <a name="fld-region.nrows"></a>`nrows` | `int option` |  |
| <a name="fld-region.ncols"></a>`ncols` | `int option` |  |

### <a name="type-traversal"></a>`traversal`

```sml
datatype traversal = datatype Array2.traversal
```

Which way a traversal goes: the [`traversal`](#type-traversal) of [`Array2`](../sig/ARRAY2.md), so that the two
structures speak of one type.

## Making an array

### <a name="val-array"></a>`array`

```sml
val array : int * int * elem -> array
```

`array (r, c, x)` is a new array of `r` rows and `c` columns, every element `x`.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `r < 0`, `c < 0`, or the array would be too large.

<details><summary>Tests (28)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `no-rows` &middot; `Size-negative` (raises Size) &middot; `same-elements-not-equal` &middot; `same-array-is-equal`

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `basic` &middot; `one` &middot; `dimensions` &middot; `no-rows` &middot; `no-columns` &middot; `no-rows-no-columns` &middot; `no-columns-rows` &middot; `Size-negative-rows` (raises Size) &middot; `Size-negative-columns` (raises Size) &middot; `Size-negative-both` (raises Size) &middot; `Size-negative-rows-no-columns` (raises Size) &middot; `Size-negative-columns-no-rows` (raises Size) &middot; `elements-are-separate` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `*` &middot; `Size-too-large` (raises Size) &middot; `Size-too-large-rows` (raises Size) &middot; `Size-too-large-columns` (raises Size)

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : elem list list -> array
```

`fromList rows` is a new array of the lists of `rows`, one row each.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the lists are not all of one length.

<details><summary>Tests (20)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `Size-ragged` (raises Size)

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `basic` &middot; `dimensions` &middot; `second-row-first-column` &middot; `first-row-last-column` &middot; `one-row` &middot; `one-column` &middot; `one-element` &middot; `every-sample` &middot; `no-rows` &middot; `empty-rows` &middot; `Size-second-shorter` (raises Size) &middot; `Size-second-longer` (raises Size) &middot; `Size-last-shorter` (raises Size) &middot; `Size-first-empty` (raises Size) &middot; `Size-second-empty` (raises Size) &middot; `same-elements-not-equal` &middot; `zero-length-not-equal` &middot; `*`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : traversal -> int * int * (int * int -> elem) -> array
```

`tabulate trv (r, c, f)` is a new array whose element at `(i, j)` is `f (i, j)`, applied in the order `trv` gives.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `r < 0`, `c < 0` or the array would be too large.

<details><summary>Tests (24)</summary>

For `CharArray2`, in [tests/basis/chararray2.sml](../../../../tests/basis/chararray2.sml): `high-characters`

For `Word8Array2`, in [tests/basis/word8array2.sml](../../../../tests/basis/word8array2.sml): `every-byte`

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `RowMajor` &middot; `ColMajor-order` &middot; `Size-negative` (raises Size)

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `RowMajor` &middot; `ColMajor` &middot; `dimensions` &middot; `RowMajor-order` &middot; `ColMajor-order` &middot; `RowMajor-counter` &middot; `ColMajor-counter` &middot; `one` &middot; `no-rows` &middot; `no-columns` &middot; `no-elements-no-f` &middot; `Size-negative-rows` (raises Size) &middot; `Size-negative-columns` (raises Size) &middot; `Size-negative-ColMajor` (raises Size) &middot; `Size-before-f` &middot; `same-elements-not-equal` &middot; `*` &middot; `Size-too-large-RowMajor` (raises Size) &middot; `Size-too-large-ColMajor` (raises Size)

</details>

## Elements

### <a name="val-sub"></a>`sub`

```sml
val sub : array * int * int -> elem
```

`sub (arr, i, j)` is the element in row `i` and column `j`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` or `j` is outside the array.

<details><summary>Tests (24)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `each` &middot; `Subscript-row` (raises Subscript) &middot; `Subscript-column` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `first` &middot; `end-of-first-row` &middot; `start-of-last-row` &middot; `middle` &middot; `last` &middot; `Subscript-row-nRows` (raises Subscript) &middot; `Subscript-column-nCols` (raises Subscript) &middot; `Subscript-column-nCols-last-row` (raises Subscript) &middot; `Subscript-negative-row` (raises Subscript) &middot; `Subscript-negative-column` (raises Subscript) &middot; `Subscript-negative-row-column-beyond` (raises Subscript) &middot; `Subscript-column-is-a-row-index` (raises Subscript) &middot; `Subscript-row-is-a-column-index` (raises Subscript) &middot; `Subscript-no-rows` (raises Subscript) &middot; `Subscript-no-columns` (raises Subscript) &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow-row` (raises Subscript) &middot; `Subscript-not-Overflow-column` (raises Subscript) &middot; `Subscript-not-Overflow-both` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-update"></a>`update`

```sml
val update : array * int * int * elem -> unit
```

`update (arr, i, j, x)` puts `x` in row `i` and column `j`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` or `j` is outside the array.

<details><summary>Tests (20)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `Subscript` (raises Subscript)

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `first` &middot; `end-of-first-row` &middot; `start-of-last-row` &middot; `last` &middot; `twice-same-element` &middot; `seen-through-alias` &middot; `every-sample` &middot; `Subscript-row-nRows` (raises Subscript) &middot; `Subscript-column-nCols` (raises Subscript) &middot; `Subscript-negative-row` (raises Subscript) &middot; `Subscript-negative-column` (raises Subscript) &middot; `Subscript-no-rows` (raises Subscript) &middot; `Subscript-no-columns` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow-row` (raises Subscript) &middot; `Subscript-not-Overflow-column` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

## Shape

### <a name="val-dimensions"></a>`dimensions`

```sml
val dimensions : array -> int * int
```

`dimensions arr` is the pair of the number of rows and the number of columns.

<details><summary>Tests (4)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic`

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `rows-then-columns` &middot; `one-row` &middot; `*`

</details>

### <a name="val-ncols"></a>`nCols`

```sml
val nCols : array -> int
```

`nCols arr` is the number of columns.

<details><summary>Tests (6)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic`

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `basic` &middot; `no-rows` &middot; `no-columns` &middot; `is-second-of-dimensions` &middot; `*`

</details>

### <a name="val-nrows"></a>`nRows`

```sml
val nRows : array -> int
```

`nRows arr` is the number of rows.

<details><summary>Tests (6)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic`

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `basic` &middot; `no-rows` &middot; `no-columns` &middot; `is-first-of-dimensions` &middot; `*`

</details>

### <a name="val-row"></a>`row`

```sml
val row : array * int -> vector
```

`row (arr, i)` is a vector of the elements of row `i`, left to right.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is no row of `arr`.

<details><summary>Tests (30)</summary>

For `CharArray2`, in [tests/basis/chararray2.sml](../../../../tests/basis/chararray2.sml): `is-a-string`

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `Subscript` (raises Subscript)

For `IntArray2`, in [tests/basis/mono.int.sml](../../../../tests/basis/mono.int.sml): `extremes`

For `Int8Array2`, in [tests/basis/mono.int8.sml](../../../../tests/basis/mono.int8.sml): `extremes`

For `Int16Array2`, in [tests/basis/mono.int16.sml](../../../../tests/basis/mono.int16.sml): `extremes`

For `Int32Array2`, in [tests/basis/mono.int32.sml](../../../../tests/basis/mono.int32.sml): `extremes`

For `LargeIntArray2`, in [tests/basis/mono.largeint.sml](../../../../tests/basis/mono.largeint.sml): `extremes`

For `WordArray2`, in [tests/basis/mono.word.sml](../../../../tests/basis/mono.word.sml): `extremes`

For `Word16Array2`, in [tests/basis/mono.word16.sml](../../../../tests/basis/mono.word16.sml): `extremes`

For `Word32Array2`, in [tests/basis/mono.word32.sml](../../../../tests/basis/mono.word32.sml): `extremes`

For `RealArray2`, in [tests/basis/mono.real.sml](../../../../tests/basis/mono.real.sml): `specials`

For `Int64Array2`, in [tests/basis/mono.int64.sml](../../../../tests/basis/mono.int64.sml): `extremes`

For `LargeWordArray2`, in [tests/basis/mono.largeword.sml](../../../../tests/basis/mono.largeword.sml): `extremes`

For `Word64Array2`, in [tests/basis/mono.word64.sml](../../../../tests/basis/mono.word64.sml): `extremes`

For `LargeRealArray2`, in [tests/basis/mono.largereal.sml](../../../../tests/basis/mono.largereal.sml): `specials`

For `Real64Array2`, in [tests/basis/mono.real64.sml](../../../../tests/basis/mono.real64.sml): `specials`

For `Real32Array2`, in [tests/basis/mono.real32.sml](../../../../tests/basis/mono.real32.sml): `specials`

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `first` &middot; `middle` &middot; `last` &middot; `no-columns` &middot; `is-a-snapshot` &middot; `every-sample` &middot; `Subscript-nRows` (raises Subscript) &middot; `Subscript-is-a-column-index` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-no-rows` (raises Subscript) &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript)

</details>

### <a name="val-column"></a>`column`

```sml
val column : array * int -> vector
```

`column (arr, j)` is a vector of the elements of column `j`, top to bottom.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `j` is no column of `arr`.

<details><summary>Tests (17)</summary>

For `CharArray2`, in [tests/basis/chararray2.sml](../../../../tests/basis/chararray2.sml): `is-a-string` &middot; `is-CharVector.vector`

For `Word8Array2`, in [tests/basis/word8array2.sml](../../../../tests/basis/word8array2.sml): `Word8Vector`

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `basic` &middot; `Subscript` (raises Subscript)

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `first` &middot; `middle` &middot; `last` &middot; `no-rows` &middot; `is-a-snapshot` &middot; `every-sample` &middot; `Subscript-nCols` (raises Subscript) &middot; `Subscript-is-a-row-index` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-no-columns` (raises Subscript) &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript)

</details>

## Copying

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : region, dst : array, dst_row : int, dst_col : int} -> unit
```

`copy {src, dst, dst_row, dst_col}` copies the region `src` into `dst` at that corner.

Source and destination may be one array and may overlap: every element
arrives as it was before the copy began.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `src` is not a valid region, or if it does not
fit into `dst` at that corner, which can happen for an empty region
too.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `region` |  |
| <a name="fld-copy.dst"></a>`dst` | `array` |  |
| <a name="fld-copy.dst_row"></a>`dst_row` | `int` |  |
| <a name="fld-copy.dst_col"></a>`dst_col` | `int` |  |

<details><summary>Tests (45)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `region` &middot; `overlap-down` &middot; `Subscript-dst` (raises Subscript) &middot; `Subscript-src` (raises Subscript)

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `region` &middot; `to-the-first-corner` &middot; `to-the-last-corner` &middot; `whole-NONE` &middot; `whole-same-dimensions` &middot; `NONE-rows-SOME-cols` &middot; `SOME-rows-NONE-cols` &middot; `field-order` &middot; `src-unchanged` &middot; `copies-elements-not-the-array` &middot; `Subscript-src-*` (raises Subscript) &middot; `Subscript-dst-negative-row` (raises Subscript) &middot; `Subscript-dst-negative-col` (raises Subscript) &middot; `Subscript-dst-one-row-too-far` (raises Subscript) &middot; `Subscript-dst-one-col-too-far` (raises Subscript) &middot; `Subscript-dst-row-nRows` (raises Subscript) &middot; `Subscript-dst-col-nCols` (raises Subscript) &middot; `Subscript-dst-smaller` (raises Subscript) &middot; `Subscript-dst-no-rows` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `overlap-down-right` &middot; `overlap-up-left` &middot; `overlap-down-left` &middot; `overlap-up-right` &middot; `overlap-right` &middot; `overlap-left` &middot; `overlap-down` &middot; `overlap-up` &middot; `overlap-onto-itself` &middot; `same-array-apart` &middot; `overlap-Subscript` (raises Subscript) &middot; `*` &middot; `within-*` &middot; `nothing-*` &middot; `nothing-to-the-end-of-dst` &middot; `Subscript-dst-nothing-row-beyond` (raises Subscript) &middot; `Subscript-dst-nothing-cols-too-far` (raises Subscript) &middot; `Subscript-not-Overflow-src-*` (raises Subscript) &middot; `Subscript-not-Overflow-dst-sum-row` (raises Subscript) &middot; `Subscript-not-Overflow-dst-sum-col` (raises Subscript) &middot; `Subscript-not-Overflow-dst-least` (raises Subscript)

</details>

## Traversing

### <a name="val-appi"></a>`appi`

```sml
val appi : traversal -> (int * int * elem -> unit) -> region -> unit
```

`appi trv f reg` applies `f` to the row, the column and the element of each position of the region.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `reg` is not a valid region.

<details><summary>Tests (20)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `region-RowMajor` &middot; `region-ColMajor` &middot; `Subscript` (raises Subscript)

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `whole-RowMajor` &middot; `whole-ColMajor` &middot; `region-RowMajor` &middot; `region-ColMajor` &middot; `NONE-to-the-end-RowMajor` &middot; `NONE-to-the-end-ColMajor` &middot; `one-row` &middot; `one-column` &middot; `last-element` &middot; `Subscript-*` (raises Subscript) &middot; `Subscript-ColMajor-too-many-rows` (raises Subscript) &middot; `Subscript-ColMajor-too-many-cols` (raises Subscript) &middot; `Subscript-before-f` &middot; `*` &middot; `nothing-RowMajor-*` &middot; `nothing-ColMajor-*` &middot; `Subscript-not-Overflow-*` (raises Subscript)

</details>

### <a name="val-app"></a>`app`

```sml
val app : traversal -> (elem -> unit) -> array -> unit
```

`app trv f arr` applies `f` to every element, in the order `trv` gives, for its effect.

<details><summary>Tests (7)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `ColMajor`

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `RowMajor` &middot; `ColMajor` &middot; `no-rows` &middot; `no-columns` &middot; `array-unchanged` &middot; `*`

</details>

### <a name="val-foldi"></a>`foldi`

```sml
val foldi : traversal -> (int * int * elem * 'b -> 'b) -> 'b -> region -> 'b
```

`foldi trv f init reg` combines the elements of the region, giving `f` the row and the column as well.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `reg` is not a valid region.

<details><summary>Tests (19)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `RowMajor` &middot; `ColMajor` &middot; `coordinates` &middot; `Subscript` (raises Subscript)

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `whole-RowMajor-conses-reversed` &middot; `whole-ColMajor-conses-reversed` &middot; `region-RowMajor` &middot; `region-ColMajor` &middot; `nonassociative-RowMajor` &middot; `nonassociative-ColMajor` &middot; `NONE-to-the-end` &middot; `Subscript-*` (raises Subscript) &middot; `Subscript-ColMajor-too-many-rows` (raises Subscript) &middot; `Subscript-ColMajor-too-many-cols` (raises Subscript) &middot; `Subscript-before-f` &middot; `*` &middot; `nothing-RowMajor-*` &middot; `nothing-ColMajor-*` &middot; `Subscript-not-Overflow-*` (raises Subscript)

</details>

### <a name="val-fold"></a>`fold`

```sml
val fold : traversal -> (elem * 'b -> 'b) -> 'b -> array -> 'b
```

`fold trv f init arr` combines every element, in the order `trv` gives.

<details><summary>Tests (11)</summary>

For `CharArray2`, in [tests/basis/chararray2.sml](../../../../tests/basis/chararray2.sml): `implode-ColMajor`

For `Word8Array2`, in [tests/basis/word8array2.sml](../../../../tests/basis/word8array2.sml): `sum-of-bytes`

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `RowMajor` &middot; `ColMajor`

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `RowMajor-conses-reversed` &middot; `ColMajor-conses-reversed` &middot; `nonassociative-RowMajor` &middot; `nonassociative-ColMajor` &middot; `no-rows` &middot; `no-columns` &middot; `*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : traversal -> (int * int * elem -> elem) -> region -> unit
```

`modifyi trv f reg` replaces each element of the region by `f` of its row, its column and that element.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `reg` is not a valid region.

<details><summary>Tests (18)</summary>

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `region` &middot; `Subscript` (raises Subscript)

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `region` &middot; `region-ColMajor` &middot; `whole` &middot; `NONE-to-the-end` &middot; `order-RowMajor` &middot; `order-ColMajor` &middot; `RowMajor-counter` &middot; `ColMajor-counter` &middot; `Subscript-*` (raises Subscript) &middot; `Subscript-ColMajor-too-many-rows` (raises Subscript) &middot; `Subscript-ColMajor-too-many-cols` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `*` &middot; `nothing-RowMajor-*` &middot; `nothing-ColMajor-*` &middot; `Subscript-not-Overflow-*` (raises Subscript)

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : traversal -> (elem -> elem) -> array -> unit
```

`modify trv f arr` replaces every element by `f` of it, in the order `trv` gives.

<details><summary>Tests (12)</summary>

For `CharArray2`, in [tests/basis/chararray2.sml](../../../../tests/basis/chararray2.sml): `toUpper`

For `Word8Array2`, in [tests/basis/word8array2.sml](../../../../tests/basis/word8array2.sml): `Word8-arithmetic`

For `BoolArray2`, in [tests/basis/mono.bool.sml](../../../../tests/basis/mono.bool.sml): `not` &middot; `order-ColMajor`

In [tests/basis/fn/mono\_array2\_fn.sml](../../../../tests/basis/fn/mono_array2_fn.sml), applied to `CharArray2`, `Word8Array2`, `IntArray2`, `Int8Array2`, `Int16Array2`, `Int32Array2`, `LargeIntArray2`, `WordArray2`, `Word16Array2`, `Word32Array2`, `RealArray2`, `Int64Array2`, `LargeWordArray2`, `Word64Array2`, `LargeRealArray2`, `Real64Array2`, `Real32Array2`: `RowMajor` &middot; `ColMajor` &middot; `order-RowMajor` &middot; `order-ColMajor` &middot; `ColMajor-counter` &middot; `no-rows` &middot; `twice` &middot; `*`

</details>

## See also

[`ARRAY2`](../sig/ARRAY2.md), [`MONO_ARRAY`](../sig/MONO_ARRAY.md), [`MONO_VECTOR`](../sig/MONO_VECTOR.md)

---

<sub>Generated by runedoc from lib/basis/sig\_mono\_array2.sml; do not edit.</sub>
