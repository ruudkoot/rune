# structure Array2

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; [Structures](../structures.md) &rsaquo; **Array2**

|  |  |
| --- | --- |
| Signature | [`ARRAY2`](../sig/ARRAY2.md) |
| Status | optional |
| Members | 20 |
| Tests | 249 checks |
| Source | [lib/basis/array2.sml](../../../../lib/basis/array2.sml) |

## Synopsis

```sml
structure Array2 :> ARRAY2
```

Array2: two-dimensional arrays, stored row by row in one array.

> **Implementation** `Array2.array/abstract-and-not-equal-at-any-element`. The
> type is abstract, as `structure Array2 :> ARRAY2` asks. The sentence of
> the page that would have made `real Array2.array` an equality type cannot
> be honoured by any sealed structure and is read as not applying here
> (`ARRAY2/sealed-and-equal-at-any-element`); MLton and SML/NJ read it the
> same way, Poly/ML does not. `RuneArray2` is the implementation under the
> seal, which `RuneMonoArray2Fn` builds the monomorphic two-dimensional
> arrays on: the type of such an array is monomorphic, so it admits equality
> however it is made, which is what [`MONO_ARRAY2`](../sig/MONO_ARRAY2.md) asks for.

## Members

What each means is on [`ARRAY2`](../sig/ARRAY2.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`array`](../sig/ARRAY2.md#type-array) | *a type of its own* |
| type | [`region`](../sig/ARRAY2.md#type-region) | `{base : 'a Array2.array, col : int, ncols : int option, nrows : int option, row : int}` |
| datatype | [`traversal`](../sig/ARRAY2.md#type-traversal) | `RowMajor` &#124; `ColMajor` |
| val | [`app`](../sig/ARRAY2.md#val-app) | `traversal -> ('a -> unit) -> 'a Array2.array -> unit` |
| val | [`appi`](../sig/ARRAY2.md#val-appi) | `traversal -> (int * int * 'a -> unit) -> 'a region -> unit` |
| val | [`array`](../sig/ARRAY2.md#val-array) | `int * int * 'a -> 'a Array2.array` |
| val | [`column`](../sig/ARRAY2.md#val-column) | `'a Array2.array * int -> 'a vector` |
| val | [`copy`](../sig/ARRAY2.md#val-copy) | `{dst : 'a Array2.array, dst_col : int, dst_row : int, src : 'a region} -> unit` |
| val | [`dimensions`](../sig/ARRAY2.md#val-dimensions) | `'a Array2.array -> int * int` |
| val | [`fold`](../sig/ARRAY2.md#val-fold) | `traversal -> ('a * 'b -> 'b) -> 'b -> 'a Array2.array -> 'b` |
| val | [`foldi`](../sig/ARRAY2.md#val-foldi) | `traversal -> (int * int * 'a * 'b -> 'b) -> 'b -> 'a region -> 'b` |
| val | [`fromList`](../sig/ARRAY2.md#val-fromlist) | `'a list list -> 'a Array2.array` |
| val | [`modify`](../sig/ARRAY2.md#val-modify) | `traversal -> ('a -> 'a) -> 'a Array2.array -> unit` |
| val | [`modifyi`](../sig/ARRAY2.md#val-modifyi) | `traversal -> (int * int * 'a -> 'a) -> 'a region -> unit` |
| val | [`nCols`](../sig/ARRAY2.md#val-ncols) | `'a Array2.array -> int` |
| val | [`nRows`](../sig/ARRAY2.md#val-nrows) | `'a Array2.array -> int` |
| val | [`row`](../sig/ARRAY2.md#val-row) | `'a Array2.array * int -> 'a vector` |
| val | [`sub`](../sig/ARRAY2.md#val-sub) | `'a Array2.array * int * int -> 'a` |
| val | [`tabulate`](../sig/ARRAY2.md#val-tabulate) | `traversal -> int * int * (int * int -> 'a) -> 'a Array2.array` |
| val | [`update`](../sig/ARRAY2.md#val-update) | `'a Array2.array * int * int * 'a -> unit` |

## Notes

### appi

> **Reading** `Array2.appi/nothing-rows-at-the-end`. "0 \<= \#row reg \<=
> nRows" allows a region to begin at the edge of the array: such a region
> and one of no rows or no columns are valid, and traverse nothing.

### array

> **Implementation** `Array2.array/Size`. How large is too large is not
> fixed: an array is too large when the number of its elements is no
> `int`, or when it exceeds what an array can hold.

### copy

> **Reading** `Array2.copy/Subscript-dst-nothing-row-beyond`. The place the
> region is copied to must be inside `dst` even when the region is empty,
> so a corner outside `dst` raises although nothing would be copied.

### region

> **Reading** `Array2.region/Subscript-not-Overflow`. Whether a region lies
> inside its array is decided without a sum that could overflow, so a region
> whose `row + nrows` is no `int` raises [`Subscript`](../sig/GENERAL.md#exn-subscript) and never [`Overflow`](../sig/GENERAL.md#exn-overflow).
> [`appi`](../sig/ARRAY2.md#val-appi), [`foldi`](../sig/ARRAY2.md#val-foldi) and [`modifyi`](../sig/ARRAY2.md#val-modifyi) find that out before `f` is applied to
> anything, so a bad region changes nothing.

### tabulate

> **Reading** `Array2.tabulate/Size-before-f`. The specification does not say
> whether the dimensions are checked before `f` is applied. They are: an
> array that is too large, or has a negative dimension, raises [`Size`](../sig/GENERAL.md#exn-size)
> without applying `f` at all.

> **Reading** `Array2.tabulate/traversal-order`. "Initialized in traversal
> order" is read as: `f (0, 0)` is applied first whichever traversal is
> asked for, and its result fills the array before the rest is
> computed.

<details><summary>Other implementations (14)</summary>

- **SML/NJ** &mdash; Array2.array (r, c, x) with r = 0 or c = 0 makes an array of dimensions (0, 0) (docs/bugreport/smlnj/Array2/no-rows-or-columns)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)
- **Poly/ML** &mdash; array (0, \~1, x) does not raise Size
- **Poly/ML** &mdash; two arrays without rows are equal
- **SML/NJ** &mdash; a RowMajor traversal of a valid region without rows, and a ColMajor traversal of one without columns, applies f to one row or column, even beyond the end of the array (docs/bugreport/smlnj/Array2/no-rows-or-columns)
- **SML/NJ** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row and dst\_col) (docs/bugreport/smlnj/Array2/Overflow-not-Subscript)
- **Poly/ML** &mdash; the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row + nrows)
- **Poly/ML** &mdash; an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript, and column (a, j) does not
- **MLKit** &mdash; appi, foldi and modifyi accept a region whose row is beyond nRows with nrows = NONE or whose nrows is negative (and the same for columns), and traverse nothing, and raise Overflow when row + nrows or col + ncols overflows, instead of raising Subscript
- **MLton** &mdash; copy within one array to the left or the right in the same rows copies elements that it has already overwritten
- **MLKit** &mdash; copy, of Array2 and of the MONO\_ARRAY2 structures, accepts a source region whose row is beyond nRows with nrows = NONE or whose nrows is negative (and the same for columns), and then raises Size, and raises Overflow when row + nrows or col + ncols overflows, instead of raising Subscript
- **MLKit** &mdash; copy checks the destination region against the dimensions of the source's base array instead of those of dst, and writes dst with the source's number of columns as its row length: Subscript for a valid destination, none for an invalid one (the elements are written past the end of dst), the elements in the wrong places when the two arrays have different numbers of columns, and Overflow when dst\_row + nrows or dst\_col + ncols overflows
- **SML/NJ** &mdash; row (a, 0) of an array without rows is an empty vector instead of Subscript (docs/bugreport/smlnj/Array2/no-rows-or-columns)
- **SML/NJ** &mdash; row (a, Int.maxInt) raises Overflow instead of Subscript (docs/bugreport/smlnj/Array2/Overflow-not-Subscript)

</details>

---

<sub>Generated by runedoc from lib/basis/array2.sml; do not edit.</sub>
