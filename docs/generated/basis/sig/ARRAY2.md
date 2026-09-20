# signature ARRAY2

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **ARRAY2**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 20 of 20 entries documented |
| Tests | 273 checks of 18 entries |
| Source | [lib/basis/sig\_array2.sml](../../../../lib/basis/sig_array2.sml) |

## Synopsis

```sml
signature ARRAY2
structure Array2 : ARRAY2  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Array2` | Array2: two-dimensional arrays, stored row by row in one array. | [lib/basis/array2.sml](../../../../lib/basis/array2.sml) |

Two-dimensional arrays: mutable rectangles of elements, indexed by a row
and a column.

Rows and columns are counted from 0, and the first index is the row: `sub (arr, i, j)` is the element in row `i` and column `j`. An array of no rows
or no columns holds nothing but still has its dimensions.

The traversals take a region, a rectangle inside an array: its `base`,
the [`row`](#val-row) and `col` it starts at, and how many rows and columns it covers,
where `NONE` means "to the edge". They also take a [`traversal`](#type-traversal), which says
whether they go along the rows or down the columns; that decides the order
the elements are visited in, and so what an effect sees.

> **Erratum** `ARRAY2/sub-indices`. The specification's description of [`sub`](#val-sub)
> says that "`i` gives the row index, and gives the column index"; the
> second is `j`.

## Contents

[Making an array](#making-an-array) &middot;
[Elements](#elements) &middot;
[Shape](#shape) &middot;
[Copying](#copying) &middot;
[Traversing](#traversing)

## Interface

<pre>
signature ARRAY2 =
sig
  eqtype 'a <a href="#type-array">array</a>

  type 'a <a href="#type-region">region</a> = {<a href="#fld-region.base">base</a> : 'a array,
                    <a href="#fld-region.row">row</a> : int,
                    <a href="#fld-region.col">col</a> : int,
                    <a href="#fld-region.nrows">nrows</a> : int option,
                    <a href="#fld-region.ncols">ncols</a> : int option}

  datatype <a href="#type-traversal">traversal</a>
    = <a href="#con-rowmajor">RowMajor</a>
    | <a href="#con-colmajor">ColMajor</a>

  val <a href="#val-array">array</a> : int * int * 'a -&gt; 'a array

  val <a href="#val-fromlist">fromList</a> : 'a list list -&gt; 'a array

  val <a href="#val-tabulate">tabulate</a> : traversal -&gt; int * int * (int * int -&gt; 'a) -&gt; 'a array

  val <a href="#val-sub">sub</a> : 'a array * int * int -&gt; 'a

  val <a href="#val-update">update</a> : 'a array * int * int * 'a -&gt; unit

  val <a href="#val-dimensions">dimensions</a> : 'a array -&gt; int * int

  val <a href="#val-ncols">nCols</a> : 'a array -&gt; int

  val <a href="#val-nrows">nRows</a> : 'a array -&gt; int

  val <a href="#val-row">row</a> : 'a array * int -&gt; 'a Vector.vector

  val <a href="#val-column">column</a> : 'a array * int -&gt; 'a Vector.vector

  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : 'a region, <a href="#fld-copy.dst">dst</a> : 'a array, <a href="#fld-copy.dst_row">dst_row</a> : int, <a href="#fld-copy.dst_col">dst_col</a> : int} -&gt; unit

  val <a href="#val-appi">appi</a> : traversal -&gt; (int * int * 'a -&gt; unit) -&gt; 'a region -&gt; unit

  val <a href="#val-app">app</a> : traversal -&gt; ('a -&gt; unit) -&gt; 'a array -&gt; unit

  val <a href="#val-foldi">foldi</a> : traversal -&gt; (int * int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a region -&gt; 'b

  val <a href="#val-fold">fold</a> : traversal -&gt; ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a array -&gt; 'b

  val <a href="#val-modifyi">modifyi</a> : traversal -&gt; (int * int * 'a -&gt; 'a) -&gt; 'a region -&gt; unit

  val <a href="#val-modify">modify</a> : traversal -&gt; ('a -&gt; 'a) -&gt; 'a array -&gt; unit
end
</pre>

### <a name="type-array"></a>`array`

```sml
eqtype 'a array
```

The type of two-dimensional arrays.

Two are equal when they are the same array, as for [`Array.array`](../sig/ARRAY.md#val-array).

<details><summary>Other implementations (4)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)
- **Poly/ML** &mdash; array (0, \~1, x) does not raise Size
- **Poly/ML** &mdash; two arrays without rows are equal

</details>

<details><summary>Tests (27)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `one` &middot; `dimensions` &middot; `no-rows` &middot; `no-columns` &middot; `no-rows-no-columns` &middot; `no-columns-rows` &middot; `Size-negative-rows` (raises Size) &middot; `Size-negative-columns` (raises Size) &middot; `Size-negative-both` (raises Size) &middot; `Size-negative-rows-no-columns` (raises Size) &middot; `Size-negative-columns-no-rows` (raises Size) &middot; `elements-are-separate` &middot; `every-element-is-init` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `of-reals-same` &middot; `of-reals-not-equal` &middot; `of-functions-same` &middot; `*` &middot; `Size-too-large` (raises Size) &middot; `Size-too-large-rows` (raises Size) &middot; `Size-too-large-columns` (raises Size)

</details>

### <a name="type-region"></a>`region`

```sml
type 'a region = {base : 'a array,
                  row : int,
                  col : int,
                  nrows : int option,
                  ncols : int option}
```

A rectangle inside an array: where it starts and how far it reaches.

`NONE` for `nrows` or `ncols` means "as far as the array goes". A region
is valid when it lies inside its base, and an empty one is valid too, so
a region that starts at the edge and covers nothing is allowed and
traverses nothing.

> **Reading** `Array2.region/Subscript-not-Overflow`. Whether a region lies
> inside its array is decided without a sum that could overflow, so a region
> whose `row + nrows` is no `int` raises [`Subscript`](../sig/GENERAL.md#exn-subscript) and never [`Overflow`](../sig/GENERAL.md#exn-overflow).
> [`appi`](#val-appi), [`foldi`](#val-foldi) and [`modifyi`](#val-modifyi) find that out before `f` is applied to
> anything, so a bad region changes nothing.

how many columns, or NONE for all that are left

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-region.base"></a>`base` | `'a array` | the array the rectangle is in |
| <a name="fld-region.row"></a>`row` | `int` | the row it starts at |
| <a name="fld-region.col"></a>`col` | `int` | the column it starts at |
| <a name="fld-region.nrows"></a>`nrows` | `int option` | how many rows, or NONE for all that are left |
| <a name="fld-region.ncols"></a>`ncols` | `int option` |  |

### <a name="type-traversal"></a>`traversal`

```sml
datatype traversal
  = RowMajor
  | ColMajor
```

Which way a traversal goes.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-rowmajor"></a>`RowMajor` |  | along each row in turn: (0,0), (0,1), ..., (1,0), ... |
| <a name="con-colmajor"></a>`ColMajor` |  | down each column in turn: (0,0), (1,0), ..., (0,1), ... |

## Making an array

### <a name="val-array"></a>`array`

```sml
val array : int * int * 'a -> 'a array
```

`array (r, c, x)` is a new array of `r` rows and `c` columns, every element `x`.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `r < 0`, `c < 0`, or the array would be too large.

> **Implementation** `Array2.array/Size`. How large is too large is not
> fixed: an array is too large when the number of its elements is no
> `int`, or when it exceeds what an array can hold.

<details><summary>Other implementations (4)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)
- **Poly/ML** &mdash; array (0, \~1, x) does not raise Size
- **Poly/ML** &mdash; two arrays without rows are equal

</details>

<details><summary>Tests (27)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `one` &middot; `dimensions` &middot; `no-rows` &middot; `no-columns` &middot; `no-rows-no-columns` &middot; `no-columns-rows` &middot; `Size-negative-rows` (raises Size) &middot; `Size-negative-columns` (raises Size) &middot; `Size-negative-both` (raises Size) &middot; `Size-negative-rows-no-columns` (raises Size) &middot; `Size-negative-columns-no-rows` (raises Size) &middot; `elements-are-separate` &middot; `every-element-is-init` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `of-reals-same` &middot; `of-reals-not-equal` &middot; `of-functions-same` &middot; `*` &middot; `Size-too-large` (raises Size) &middot; `Size-too-large-rows` (raises Size) &middot; `Size-too-large-columns` (raises Size)

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : 'a list list -> 'a array
```

`fromList rows` is a new array of the lists of `rows`, one row each.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the lists are not all of one length.

**Example** `let val a = fromList [[1, 2], [3, 4]] in (sub (a, 1, 0), dimensions a) end = (3, (2, 2))`

<details><summary>Other implementations (3)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)
- **Poly/ML** &mdash; two arrays without rows are equal

</details>

<details><summary>Tests (18)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `dimensions` &middot; `second-row-first-column` &middot; `first-row-last-column` &middot; `one-row` &middot; `one-column` &middot; `one-element` &middot; `no-rows` &middot; `empty-rows` &middot; `strings` &middot; `Size-second-shorter` (raises Size) &middot; `Size-second-longer` (raises Size) &middot; `Size-last-shorter` (raises Size) &middot; `Size-first-empty` (raises Size) &middot; `Size-second-empty` (raises Size) &middot; `same-elements-not-equal` &middot; `zero-length-not-equal` &middot; `*`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : traversal -> int * int * (int * int -> 'a) -> 'a array
```

`tabulate trv (r, c, f)` is a new array of `r` rows and `c` columns whose element at `(i, j)` is `f (i, j)`.

`f` is applied in the order that `trv` gives.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `r < 0`, `c < 0` or the array would be too large,
before `f` is applied at all.

> **Reading** `Array2.tabulate/traversal-order`. "Initialized in traversal
> order" is read as: `f (0, 0)` is applied first whichever traversal is
> asked for, and its result fills the array before the rest is
> computed.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)

</details>

<details><summary>Tests (19)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `RowMajor` &middot; `ColMajor` &middot; `dimensions` &middot; `RowMajor-order` &middot; `ColMajor-order` &middot; `RowMajor-counter` &middot; `ColMajor-counter` &middot; `one` &middot; `no-rows` &middot; `no-columns` &middot; `no-elements-no-f` &middot; `Size-negative-rows` (raises Size) &middot; `Size-negative-columns` (raises Size) &middot; `Size-negative-ColMajor` (raises Size) &middot; `Size-before-f` &middot; `same-elements-not-equal` &middot; `*` &middot; `Size-too-large-RowMajor` (raises Size) &middot; `Size-too-large-ColMajor` (raises Size)

</details>

## Elements

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a array * int * int -> 'a
```

`sub (arr, i, j)` is the element of `arr` in row `i` and column `j`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` or `j` is outside the array.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row and dst\_col)
- **Poly/ML** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row + nrows)

</details>

<details><summary>Tests (20)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `first` &middot; `end-of-first-row` &middot; `start-of-last-row` &middot; `middle` &middot; `last` &middot; `Subscript-row-nRows` (raises Subscript) &middot; `Subscript-column-nCols` (raises Subscript) &middot; `Subscript-column-nCols-last-row` (raises Subscript) &middot; `Subscript-negative-row` (raises Subscript) &middot; `Subscript-negative-column` (raises Subscript) &middot; `Subscript-negative-row-column-beyond` (raises Subscript) &middot; `Subscript-column-is-a-row-index` (raises Subscript) &middot; `Subscript-row-is-a-column-index` (raises Subscript) &middot; `Subscript-no-rows` (raises Subscript) &middot; `Subscript-no-columns` (raises Subscript) &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow-row` (raises Subscript) &middot; `Subscript-not-Overflow-column` (raises Subscript) &middot; `Subscript-not-Overflow-both` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-update"></a>`update`

```sml
val update : 'a array * int * int * 'a -> unit
```

`update (arr, i, j, x)` puts `x` in row `i` and column `j` of `arr`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` or `j` is outside the array.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row and dst\_col)
- **Poly/ML** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row + nrows)

</details>

<details><summary>Tests (17)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `first` &middot; `end-of-first-row` &middot; `start-of-last-row` &middot; `last` &middot; `twice-same-element` &middot; `seen-through-alias` &middot; `Subscript-row-nRows` (raises Subscript) &middot; `Subscript-column-nCols` (raises Subscript) &middot; `Subscript-negative-row` (raises Subscript) &middot; `Subscript-negative-column` (raises Subscript) &middot; `Subscript-no-rows` (raises Subscript) &middot; `Subscript-no-columns` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow-row` (raises Subscript) &middot; `Subscript-not-Overflow-column` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

## Shape

### <a name="val-dimensions"></a>`dimensions`

```sml
val dimensions : 'a array -> int * int
```

`dimensions arr` is the pair of the number of rows and the number of columns.

<details><summary>Tests (3)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `rows-then-columns` &middot; `one-row` &middot; `*`

</details>

### <a name="val-ncols"></a>`nCols`

```sml
val nCols : 'a array -> int
```

`nCols arr` is the number of columns.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)

</details>

<details><summary>Tests (5)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `no-rows` &middot; `no-columns` &middot; `is-second-of-dimensions` &middot; `*`

</details>

### <a name="val-nrows"></a>`nRows`

```sml
val nRows : 'a array -> int
```

`nRows arr` is the number of rows.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)

</details>

<details><summary>Tests (5)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `no-rows` &middot; `no-columns` &middot; `is-first-of-dimensions` &middot; `*`

</details>

### <a name="val-row"></a>`row`

```sml
val row : 'a array * int -> 'a Vector.vector
```

`row (arr, i)` is a vector of the elements of row `i`, left to right.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is no row of `arr`.

**Example** `row (fromList [[1, 2], [3, 4]], 1) = Vector.fromList [3, 4]`

<details><summary>Other implementations (3)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **SML/NJ** &mdash; row (a, 0) of an array without rows is an empty vector instead of Subscript
- **SML/NJ** &mdash; row (a, Int.maxInt) raises Overflow instead of Subscript

</details>

<details><summary>Tests (11)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `first` &middot; `middle` &middot; `last` &middot; `no-columns` &middot; `is-a-snapshot` &middot; `Subscript-nRows` (raises Subscript) &middot; `Subscript-is-a-column-index` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-no-rows` (raises Subscript) &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript)

</details>

### <a name="val-column"></a>`column`

```sml
val column : 'a array * int -> 'a Vector.vector
```

`column (arr, j)` is a vector of the elements of column `j`, top to bottom.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `j` is no column of `arr`.

**Example** `column (fromList [[1, 2], [3, 4]], 1) = Vector.fromList [2, 4]`

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)

</details>

<details><summary>Tests (11)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `first` &middot; `middle` &middot; `last` &middot; `no-rows` &middot; `is-a-snapshot` &middot; `Subscript-nCols` (raises Subscript) &middot; `Subscript-is-a-row-index` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-no-columns` (raises Subscript) &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript)

</details>

## Copying

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : 'a region, dst : 'a array, dst_row : int, dst_col : int} -> unit
```

`copy {src, dst, dst_row, dst_col}` copies the region `src` into `dst`, with its top left corner at `(dst_row, dst_col)`.

The source and the destination may be one array and may overlap: every
element arrives as it was before the copy began.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `src` is not a valid region, or if it does not
fit into `dst` at that corner.

> **Reading** `Array2.copy/Subscript-dst-nothing-row-beyond`. The place the
> region is copied to must be inside `dst` even when the region is empty,
> so a corner outside `dst` raises although nothing would be copied.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `'a region` |  |
| <a name="fld-copy.dst"></a>`dst` | `'a array` |  |
| <a name="fld-copy.dst_row"></a>`dst_row` | `int` |  |
| <a name="fld-copy.dst_col"></a>`dst_col` | `int` |  |

<details><summary>Other implementations (5)</summary>

- **MLton** &mdash; copy within one array to the left or the right in the same rows copies elements that it has already overwritten
- **SML/NJ** &mdash; a RowMajor traversal of a valid region without rows, and a ColMajor traversal of one without columns, applies f to one row or column, even beyond the end of the array
- **SML/NJ** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row and dst\_col)
- **Poly/ML** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row + nrows)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript, and column (a, j) does not

</details>

<details><summary>Tests (41)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `region` &middot; `to-the-first-corner` &middot; `to-the-last-corner` &middot; `whole-NONE` &middot; `whole-same-dimensions` &middot; `NONE-rows-SOME-cols` &middot; `SOME-rows-NONE-cols` &middot; `field-order` &middot; `src-unchanged` &middot; `copies-elements-not-the-array` &middot; `Subscript-src-*` (raises Subscript) &middot; `Subscript-dst-negative-row` (raises Subscript) &middot; `Subscript-dst-negative-col` (raises Subscript) &middot; `Subscript-dst-one-row-too-far` (raises Subscript) &middot; `Subscript-dst-one-col-too-far` (raises Subscript) &middot; `Subscript-dst-row-nRows` (raises Subscript) &middot; `Subscript-dst-col-nCols` (raises Subscript) &middot; `Subscript-dst-smaller` (raises Subscript) &middot; `Subscript-dst-no-rows` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `overlap-down-right` &middot; `overlap-up-left` &middot; `overlap-down-left` &middot; `overlap-up-right` &middot; `overlap-right` &middot; `overlap-left` &middot; `overlap-down` &middot; `overlap-up` &middot; `overlap-onto-itself` &middot; `same-array-apart` &middot; `overlap-Subscript` (raises Subscript) &middot; `*` &middot; `within-*` &middot; `nothing-*` &middot; `nothing-to-the-end-of-dst` &middot; `Subscript-dst-nothing-row-beyond` (raises Subscript) &middot; `Subscript-dst-nothing-cols-too-far` (raises Subscript) &middot; `Subscript-not-Overflow-src-*` (raises Subscript) &middot; `Subscript-not-Overflow-dst-sum-row` (raises Subscript) &middot; `Subscript-not-Overflow-dst-sum-col` (raises Subscript) &middot; `Subscript-not-Overflow-dst-least` (raises Subscript)

</details>

## Traversing

### <a name="val-appi"></a>`appi`

```sml
val appi : traversal -> (int * int * 'a -> unit) -> 'a region -> unit
```

`appi trv f reg` applies `f` to the row, the column and the element of each position of the region, in the order `trv` gives.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `reg` is not a valid region.

> **Reading** `Array2.appi/nothing-rows-at-the-end`. "0 \<= \#row reg \<=
> nRows" allows a region to begin at the edge of the array: such a region
> and one of no rows or no columns are valid, and traverse nothing.

<details><summary>Other implementations (4)</summary>

- **SML/NJ** &mdash; a RowMajor traversal of a valid region without rows, and a ColMajor traversal of one without columns, applies f to one row or column, even beyond the end of the array
- **SML/NJ** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row and dst\_col)
- **Poly/ML** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row + nrows)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript, and column (a, j) does not

</details>

<details><summary>Tests (17)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `whole-RowMajor` &middot; `whole-ColMajor` &middot; `region-RowMajor` &middot; `region-ColMajor` &middot; `NONE-to-the-end-RowMajor` &middot; `NONE-to-the-end-ColMajor` &middot; `one-row` &middot; `one-column` &middot; `last-element` &middot; `Subscript-*` (raises Subscript) &middot; `Subscript-ColMajor-too-many-rows` (raises Subscript) &middot; `Subscript-ColMajor-too-many-cols` (raises Subscript) &middot; `Subscript-before-f` &middot; `*` &middot; `nothing-RowMajor-*` &middot; `nothing-ColMajor-*` &middot; `Subscript-not-Overflow-*` (raises Subscript)

</details>

### <a name="val-app"></a>`app`

```sml
val app : traversal -> ('a -> unit) -> 'a array -> unit
```

`app trv f arr` applies `f` to every element of `arr`, in the order `trv` gives, for its effect.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)

</details>

<details><summary>Tests (6)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `RowMajor` &middot; `ColMajor` &middot; `no-rows` &middot; `no-columns` &middot; `array-unchanged` &middot; `*`

</details>

### <a name="val-foldi"></a>`foldi`

```sml
val foldi : traversal -> (int * int * 'a * 'b -> 'b) -> 'b -> 'a region -> 'b
```

`foldi trv f init reg` combines the elements of the region, giving `f` the row and the column as well.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `reg` is not a valid region.

<details><summary>Other implementations (4)</summary>

- **SML/NJ** &mdash; a RowMajor traversal of a valid region without rows, and a ColMajor traversal of one without columns, applies f to one row or column, even beyond the end of the array
- **SML/NJ** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row and dst\_col)
- **Poly/ML** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row + nrows)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript, and column (a, j) does not

</details>

<details><summary>Tests (15)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `whole-RowMajor-conses-reversed` &middot; `whole-ColMajor-conses-reversed` &middot; `region-RowMajor` &middot; `region-ColMajor` &middot; `nonassociative-RowMajor` &middot; `nonassociative-ColMajor` &middot; `NONE-to-the-end` &middot; `Subscript-*` (raises Subscript) &middot; `Subscript-ColMajor-too-many-rows` (raises Subscript) &middot; `Subscript-ColMajor-too-many-cols` (raises Subscript) &middot; `Subscript-before-f` &middot; `*` &middot; `nothing-RowMajor-*` &middot; `nothing-ColMajor-*` &middot; `Subscript-not-Overflow-*` (raises Subscript)

</details>

### <a name="val-fold"></a>`fold`

```sml
val fold : traversal -> ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

`fold trv f init arr` combines every element of `arr`, in the order `trv` gives.

**Example** `fold RowMajor (op ::) [] (fromList [[1, 2], [3, 4]]) = [4, 3, 2, 1]`

**Example** `fold ColMajor (op ::) [] (fromList [[1, 2], [3, 4]]) = [4, 2, 3, 1]`

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)

</details>

<details><summary>Tests (7)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `RowMajor-conses-reversed` &middot; `ColMajor-conses-reversed` &middot; `nonassociative-RowMajor` &middot; `nonassociative-ColMajor` &middot; `no-rows` &middot; `no-columns` &middot; `*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : traversal -> (int * int * 'a -> 'a) -> 'a region -> unit
```

`modifyi trv f reg` replaces each element of the region by `f` of its row, its column and that element.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `reg` is not a valid region.

<details><summary>Other implementations (4)</summary>

- **SML/NJ** &mdash; a RowMajor traversal of a valid region without rows, and a ColMajor traversal of one without columns, applies f to one row or column, even beyond the end of the array
- **SML/NJ** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row and dst\_col)
- **Poly/ML** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row + nrows)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript, and column (a, j) does not

</details>

<details><summary>Tests (16)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `region` &middot; `region-ColMajor` &middot; `whole` &middot; `NONE-to-the-end` &middot; `order-RowMajor` &middot; `order-ColMajor` &middot; `RowMajor-counter` &middot; `ColMajor-counter` &middot; `Subscript-*` (raises Subscript) &middot; `Subscript-ColMajor-too-many-rows` (raises Subscript) &middot; `Subscript-ColMajor-too-many-cols` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `*` &middot; `nothing-RowMajor-*` &middot; `nothing-ColMajor-*` &middot; `Subscript-not-Overflow-*` (raises Subscript)

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : traversal -> ('a -> 'a) -> 'a array -> unit
```

`modify trv f arr` replaces every element of `arr` by `f` of it, in the order `trv` gives.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)

</details>

<details><summary>Tests (8)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `RowMajor` &middot; `ColMajor` &middot; `order-RowMajor` &middot; `order-ColMajor` &middot; `ColMajor-counter` &middot; `no-rows` &middot; `twice` &middot; `*`

</details>

## See also

[`ARRAY`](../sig/ARRAY.md), [`VECTOR`](../sig/VECTOR.md), [`MONO_ARRAY2`](../sig/MONO_ARRAY2.md)

---

<sub>Generated by runedoc from lib/basis/sig\_array2.sml; do not edit.</sub>
