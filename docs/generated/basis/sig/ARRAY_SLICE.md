# signature ARRAY_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **ARRAY_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 26 of 26 entries documented |
| Tests | 270 checks of 25 entries |
| Source | [lib/basis/sig\_array\_slice.sml](../../../../lib/basis/sig_array_slice.sml) |

## Synopsis

```sml
signature ARRAY_SLICE
structure ArraySlice : ARRAY_SLICE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`ArraySlice`](../str/ArraySlice.md) | ArraySlice: an array, a start index and a length. The -i functions pass the index in the slice. | [lib/basis/arrayslice.sml](../../../../lib/basis/arrayslice.sml) |

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

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; slice and subslice (x, i, SOME j) raise Overflow instead of Subscript when i + j overflows

</details>

## Elements

### <a name="val-length"></a>`length`

```sml
val length : 'a slice -> int
```

`length sl` is the number of elements of `sl`.

**Example** `length (slice (Array.fromList [1, 2, 3, 4], 1, SOME 2)) = 2`

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `full` &middot; `middle` &middot; `NONE` &middot; `empty` &middot; `empty-array` &middot; `is-third-of-base` &middot; `model-*`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a slice * int -> 'a
```

`sub (sl, i)` is the element of `sl` at position `i`, counting from the start of the slice.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length sl`.

**Law** `sub (slice (arr, i, NONE), k) = Array.sub (arr, i + k)` for `0 <= i andalso i < Array.length arr andalso 0 <= k andalso k < Array.length arr - i` (for every `arr : 'a array`, `i : int`, `k : int`)

**Example** `sub (slice (Array.fromList [1, 2, 3, 4], 1, NONE), 0) = 2`

**Counterexample** `sub (slice (Array.fromList [1, 2], ~1, NONE), 1) = 1`,
for a slice cannot start before its array.

<details><summary>Tests (13)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first` &middot; `middle` &middot; `last` &middot; `sees-Array.update` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-beyond-the-array` (raises Subscript) &middot; `Subscript-before-the-array` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-full` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-update"></a>`update`

```sml
val update : 'a slice * int * 'a -> unit
```

`update (sl, i, x)` puts `x` at position `i` of `sl`, and so of the array it is a slice of.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length sl`.

**Law** `(update (sl, i, x); sub (sl, i)) = x` for `0 <= i andalso i < length sl` (for every `sl : 'a ArraySlice.slice`, `i : int`, `x : 'a`)

**Example** `let val a = Array.fromList [1, 2, 3] in update (slice (a, 1, NONE), 0, 9); Array.vector a end = Vector.fromList [1, 9, 3]`

<details><summary>Tests (14)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first` &middot; `last` &middot; `twice-same-index` &middot; `seen-by-sub` &middot; `seen-through-another-slice` &middot; `full` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-beyond-the-array` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

## Making a slice

### <a name="val-full"></a>`full`

```sml
val full : 'a Array.array -> 'a slice
```

`full arr` is the whole of `arr` as a slice: `slice (arr, 0, NONE)`.

**Law** `base (full arr) = (arr, 0, Array.length arr)` (for every `arr : 'a array`)

**Example** `length (full (Array.fromList [1, 2, 3])) = 3`

<details><summary>Tests (6)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `basic` &middot; `base` &middot; `empty-array` &middot; `is-slice-0-NONE` &middot; `of-the-array-itself` &middot; `model-*`

</details>

### <a name="val-slice"></a>`slice`

```sml
val slice : 'a Array.array * int * int option -> 'a slice
```

`slice (arr, i, NONE)` is the stretch of `arr` from position `i` to its end, and `slice (arr, i, SOME n)` the `n` elements from `i`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i > Array.length arr`, or, with `SOME n`, if `n < 0` or `i + n > Array.length arr`.

**Law** `base (slice (arr, i, SOME n)) = (arr, i, n)` for `0 <= i andalso i <= Array.length arr andalso 0 <= n andalso n <= Array.length arr - i` (for every `arr : 'a array`, `i : int`, `n : int`)

**Example** `vector (slice (Array.fromList [1, 2, 3, 4], 1, SOME 2)) = Vector.fromList [2, 3]`

> **Reading** `ArraySlice.slice/Subscript-not-Overflow`. When `i + n` is no
> `int` the slice does not exist, and [`Subscript`](../sig/GENERAL.md#exn-subscript) says so, never [`Overflow`](../sig/GENERAL.md#exn-overflow);
> [`subslice`](#val-subslice), [`copy`](#val-copy) and [`copyVec`](#val-copyvec) are the same with their sums, and so are
> the slices of the monomorphic arrays.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; slice and subslice (x, i, SOME j) raise Overflow instead of Subscript when i + j overflows

</details>

<details><summary>Tests (39)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-one` &middot; `SOME-zero` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-at-length` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-one-at-length` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `empty-array-NONE` &middot; `empty-array-SOME` &middot; `empty-array-NONE-Subscript` (raises Subscript) &middot; `empty-array-SOME-Subscript` (raises Subscript) &middot; `of-the-array-itself` &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-and-most` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : 'a slice * int * int option -> 'a slice
```

`subslice (sl, i, NONE)` is the stretch of `sl` from position `i` on, and `subslice (sl, i, SOME n)` the `n` elements from `i`.

The bounds are those of `sl`, not of the array it is a slice of.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i > length sl`, or, with `SOME n`, if
`n < 0` or `i + n > length sl`.

**Law** `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= i andalso i < length sl andalso 0 <= k andalso k < length sl - i` (for every `sl : 'a ArraySlice.slice`, `i : int`, `k : int`)

**Example** `vector (subslice (slice (Array.fromList [1, 2, 3, 4], 1, NONE), 1, SOME 1)) = Vector.fromList [3]`

**Counterexample** `sub (subslice (full (Array.fromList [1, 2]), ~1, NONE), 1) = 1`, for a subslice cannot start before its slice.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; slice and subslice (x, i, SOME j) raise Overflow instead of Subscript when i + j overflows

</details>

<details><summary>Tests (31)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `NONE-from-zero` &middot; `NONE-middle` &middot; `NONE-at-length` &middot; `NONE-middle-base` &middot; `NONE-at-length-base` &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-beyond` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-middle-base` &middot; `SOME-zero-base` &middot; `SOME-zero-at-length-base` &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-one-too-many` (raises Subscript) &middot; `SOME-Subscript-whole-and-one` (raises Subscript) &middot; `SOME-Subscript-zero-size-beyond` (raises Subscript) &middot; `of-subslice` &middot; `of-empty` &middot; `of-empty-Subscript` (raises Subscript) &middot; `of-the-same-array` &middot; `every-argument` &middot; `model-*` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-start-zero-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-least-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-base"></a>`base`

```sml
val base : 'a slice -> 'a Array.array * int * int
```

`base sl` is the triple of the array that `sl` is a stretch of, where it starts in that array, and how long it is.

**Example** `let val (_, i, n) = base (slice (Array.fromList [1, 2, 3, 4], 1, SOME 2)) in (i, n) end = (1, 2)`

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `middle` &middot; `empty` &middot; `the-array-itself` &middot; `model-*`

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a slice -> 'a Vector.vector
```

`vector sl` is an immutable vector of the elements of `sl`, which is a copy.

**Law** `vector sl = Vector.tabulate (length sl, fn i => sub (sl, i))` (for every `sl : 'a ArraySlice.slice`)

**Example** `vector (slice (Array.fromList [1, 2, 3], 1, NONE)) = Vector.fromList [2, 3]`

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

**Example** `let val a = Array.fromList [1, 2, 3, 4] in copy {src = slice (a, 0, SOME 3), dst = a, di = 1}; Array.vector a end = Vector.fromList [1, 1, 2, 3]`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `'a slice` |  |
| <a name="fld-copy.dst"></a>`dst` | `'a Array.array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

<details><summary>Other implementations (2)</summary>

- **Poly/ML** &mdash; copy and copyVec raise Overflow instead of Subscript when di + \|src\| overflows
- **MLKit** &mdash; copy and copyVec raise Overflow instead of Subscript when di + \|src\| overflows: they check di + \|src\| \> \|dst\| (TableSlice.sml, ByteSlice.sml, wordtable-functors.sml)

</details>

<details><summary>Tests (31)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `field-order` &middot; `src-unchanged` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `overlap-to-the-right` &middot; `overlap-one-to-the-right` &middot; `overlap-onto-itself` &middot; `overlap-one-to-the-left` &middot; `overlap-to-the-left` &middot; `overlap-to-the-end` &middot; `overlap-Subscript` (raises Subscript) &middot; `same-array-apart` &middot; `full-onto-itself` &middot; `full-onto-itself-shifted-Subscript` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `within-model-*` &middot; `within-model-*` (raises Subscript) &middot; `long-overlap` &middot; `Subscript-not-Overflow-sum` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : 'a VectorSlice.slice, dst : 'a Array.array, di : int} -> unit
```

`copyVec {src, dst, di}` copies the elements of the vector slice `src` into `dst`, starting at position `di`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `di < 0` or `di + VectorSlice.length src > Array.length dst`, and then nothing has been copied.

**Example** `let val a = Array.array (3, 0) in copyVec {src = VectorSlice.slice (Vector.fromList [7, 8, 9], 1, NONE), dst = a, di = 0}; Array.vector a end = Vector.fromList [8, 9, 0]`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `'a VectorSlice.slice` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `'a Array.array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

<details><summary>Other implementations (2)</summary>

- **Poly/ML** &mdash; copy and copyVec raise Overflow instead of Subscript when di + \|src\| overflows
- **MLKit** &mdash; copy and copyVec raise Overflow instead of Subscript when di + \|src\| overflows: they check di + \|src\| \> \|dst\| (TableSlice.sml, ByteSlice.sml, wordtable-functors.sml)

</details>

<details><summary>Tests (19)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `full-vector` &middot; `field-order` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `Subscript-not-Overflow-sum` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : 'a slice -> bool
```

`isEmpty sl` is `true` when `sl` has no elements.

**Law** `isEmpty sl = (length sl = 0)` (for every `sl : 'a ArraySlice.slice`)

**Example** `isEmpty (slice (Array.fromList [1], 1, NONE)) = true`

<details><summary>Tests (6)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `empty` &middot; `empty-array` &middot; `at-length` &middot; `one` &middot; `middle` &middot; `model-*`

</details>

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : 'a slice -> ('a * 'a slice) option
```

`getItem sl` is `NONE` for an empty slice and `SOME (x, rest)` for the first element and what follows it.

`rest` is a slice of the same array, so it is had for nothing.

**Example** `(case getItem (full (Array.fromList [1, 2])) of SOME (x, rest) => (x, length rest) | NONE => (0, 0)) = (1, 1)`

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

**Example** `let val r = ref [] in appi (fn (i, x) => r := (i, x) :: !r) (slice (Array.fromList ["a", "b", "c"], 1, NONE)); !r end = [(1, "c"), (0, "b")]`

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `index-in-the-slice` &middot; `full` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a slice -> unit
```

`app f sl` applies `f` to every element, from 0 up, for its effect.

**Law** `app f sl = appi (f o #2) sl` (for every `f : 'a -> unit`, `sl : 'a ArraySlice.slice`)

**Example** `let val s = ref 0 in app (fn x => s := !s + x) (slice (Array.fromList [1, 2, 3], 1, NONE)); !s end = 5`

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `order` &middot; `empty` &middot; `array-unchanged` &middot; `model-*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * 'a -> 'a) -> 'a slice -> unit
```

`modifyi f sl` replaces the element at each position by `f` of the index and that element, in place.

The index is that of the element in the slice, and the elements are
replaced from 0 up.

**Example** `let val a = Array.fromList [10, 20, 30] in modifyi (fn (i, x) => x + i) (slice (a, 1, NONE)); Array.vector a end = Vector.fromList [10, 20, 31]`

<details><summary>Tests (5)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `index-in-the-slice` &middot; `full` &middot; `empty` &middot; `order` &middot; `model-*`

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : ('a -> 'a) -> 'a slice -> unit
```

`modify f sl` replaces every element by `f` of it, in place, from 0 up.

**Law** `modify f sl = modifyi (fn (_, x) => f x) sl` (for every `f : 'a -> 'a`, `sl : 'a ArraySlice.slice`)

**Example** `let val a = Array.fromList [1, 2, 3, 4] in modify (fn _ => 0) (slice (a, 1, SOME 2)); Array.vector a end = Vector.fromList [1, 0, 0, 4]`

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `basic` &middot; `empty` &middot; `order` &middot; `twice` &middot; `seen-by-the-slice` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

`foldli f init sl` combines the elements from the left, giving `f` the index as well.

The index is that of the element in the slice, counted from 0.

**Example** `foldli (fn (i, x, acc) => (i, x) :: acc) [] (slice (Array.fromList ["a", "b", "c"], 1, NONE)) = [(1, "c"), (0, "b")]`

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

`foldri f init sl` combines the elements from the right, giving `f` the index as well.

The index is that of the element in the slice, counted from 0.

**Example** `foldri (fn (i, x, acc) => (i, x) :: acc) [] (slice (Array.fromList ["a", "b", "c"], 1, NONE)) = [(0, "b"), (1, "c")]`

<details><summary>Tests (4)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

`foldl f init sl` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

**Law** `foldl f init sl = foldli (fn (_, a, x) => f (a, x)) init sl` (for every `f : 'b * 'a -> 'a`, `init : 'a`, `sl : 'b ArraySlice.slice`)

**Example** `foldl (op ::) [] (full (Array.fromList [1, 2, 3])) = [3, 2, 1]`

<details><summary>Tests (5)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

`foldr f init sl` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

**Law** `foldr f init sl = foldri (fn (_, a, x) => f (a, x)) init sl` (for every `f : 'b * 'a -> 'a`, `init : 'a`, `sl : 'b ArraySlice.slice`)

**Example** `foldr (op ::) [] (full (Array.fromList [1, 2, 3])) = [1, 2, 3]`

<details><summary>Tests (5)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long-list`

</details>

## Searching

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a slice -> (int * 'a) option
```

`findi p sl` is `SOME (i, x)` for the first position whose index and element satisfy `p`, or `NONE`.

The index is that of the element in the slice; `p` is applied from 0 up,
and not after the first position that satisfies it.

**Example** `findi (fn (_, x) => x = 3) (slice (Array.fromList [3, 1, 3], 1, NONE)) = SOME (1, 3)`

<details><summary>Tests (9)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `not-before-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a slice -> 'a option
```

`find p sl` is `SOME x` for the first element that satisfies `p`, or `NONE`.

**Law** `find p sl = Option.map #2 (findi (fn (_, x) => p x) sl)` (for every `p : 'a -> bool`, `sl : 'a ArraySlice.slice`)

**Example** `find (fn x => x > 1) (full (Array.fromList [1, 2, 3])) = SOME 2`

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `first-match` &middot; `last-element` &middot; `none` &middot; `not-before-the-slice` &middot; `empty` &middot; `stops` &middot; `model-*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a slice -> bool
```

`exists p sl` is `true` when some element satisfies `p`; it stops at the first that does.

Only the elements of the slice are looked at, not the rest of its array.

**Law** `exists p sl = isSome (find p sl)` (for every `p : 'a -> bool`, `sl : 'a ArraySlice.slice`)

**Example** `exists (fn x => x = 1) (slice (Array.fromList [1, 2, 3], 1, NONE)) = false`

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `true` &middot; `false` &middot; `not-outside-the-slice` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a slice -> bool
```

`all p sl` is `true` when every element satisfies `p`; it stops at the first that does not.

**Law** `all p sl = not (exists (not o p) sl)` (for every `p : 'a -> bool`, `sl : 'a ArraySlice.slice`)

**Example** `all (fn x => x > 1) (slice (Array.fromList [1, 2, 3], 1, NONE)) = true`

<details><summary>Tests (7)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `de-morgan-*`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a slice * 'a slice -> order
```

`collate cmp (sl, tl)` compares the elements of two slices lexicographically with `cmp`.

**Law** `collate cmp (sl, sl') = List.collate cmp (foldr (op ::) [] sl, foldr (op ::) [] sl')` (for every `cmp : 'a * 'a -> order`, `sl : 'a ArraySlice.slice`, `sl' : 'a ArraySlice.slice`)

**Example** `collate Int.compare (slice (Array.fromList [1, 2, 3], 1, NONE), full (Array.fromList [2])) = GREATER`

<details><summary>Tests (16)</summary>

For `ArraySlice`, in [tests/basis/arrayslice.sml](../../../../tests/basis/arrayslice.sml): `equal-elements` &middot; `parts-of-one-array` &middot; `same-slice` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `ends-with-the-slice` &middot; `starts-with-the-slice` &middot; `given-ordering` &middot; `argument-order` &middot; `model-*` &middot; `long`

</details>

## See also

[`ARRAY`](../sig/ARRAY.md), [`VECTOR_SLICE`](../sig/VECTOR_SLICE.md), [`MONO_ARRAY_SLICE`](../sig/MONO_ARRAY_SLICE.md)

---

<sub>Generated by runedoc from lib/basis/sig\_array\_slice.sml; do not edit.</sub>
