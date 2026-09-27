# structure WideCharArray2

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; [Structures](../structures.md) &rsaquo; **WideCharArray2**

|  |  |
| --- | --- |
| Signature | [`MONO_ARRAY2`](../sig/MONO_ARRAY2.md) |
| Status | optional |
| Members | 22 |
| Tests | 251 checks |
| Source | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |

## Synopsis

```sml
structure WideCharArray2 :> MONO_ARRAY2 where type vector = WideCharVector.vector where type elem = WideChar.char
```

WideCharArray2: two-dimensional arrays of wide characters, whose rows and
columns are [`WideCharVector`](../str/WideCharVector.md) vectors.

## Members

What each means is on [`MONO_ARRAY2`](../sig/MONO_ARRAY2.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`array`](../sig/MONO_ARRAY2.md#type-array) | *a type of its own* |
| type | [`elem`](../sig/MONO_ARRAY2.md#type-elem) | `WideChar.char` |
| type | [`region`](../sig/MONO_ARRAY2.md#type-region) | `{base : WideCharArray2.array, col : int, ncols : int option, nrows : int option, row : int}` |
| datatype | [`traversal`](../sig/MONO_ARRAY2.md#type-traversal) | `RowMajor` &#124; `ColMajor` |
| type | [`vector`](../sig/MONO_ARRAY2.md#type-vector) | `WideCharVector.vector` |
| val | [`app`](../sig/MONO_ARRAY2.md#val-app) | `Array2.traversal -> (WideChar.char -> unit) -> WideCharArray2.array -> unit` |
| val | [`appi`](../sig/MONO_ARRAY2.md#val-appi) | `Array2.traversal -> (int * int * WideChar.char -> unit) -> region -> unit` |
| val | [`array`](../sig/MONO_ARRAY2.md#val-array) | `int * int * WideChar.char -> WideCharArray2.array` |
| val | [`column`](../sig/MONO_ARRAY2.md#val-column) | `WideCharArray2.array * int -> WideCharVector.vector` |
| val | [`copy`](../sig/MONO_ARRAY2.md#val-copy) | `{dst : WideCharArray2.array, dst_col : int, dst_row : int, src : region} -> unit` |
| val | [`dimensions`](../sig/MONO_ARRAY2.md#val-dimensions) | `WideCharArray2.array -> int * int` |
| val | [`fold`](../sig/MONO_ARRAY2.md#val-fold) | `Array2.traversal -> (WideChar.char * 'a -> 'a) -> 'a -> WideCharArray2.array -> 'a` |
| val | [`foldi`](../sig/MONO_ARRAY2.md#val-foldi) | `Array2.traversal -> (int * int * WideChar.char * 'a -> 'a) -> 'a -> region -> 'a` |
| val | [`fromList`](../sig/MONO_ARRAY2.md#val-fromlist) | `WideChar.char list list -> WideCharArray2.array` |
| val | [`modify`](../sig/MONO_ARRAY2.md#val-modify) | `Array2.traversal -> (WideChar.char -> WideChar.char) -> WideCharArray2.array -> unit` |
| val | [`modifyi`](../sig/MONO_ARRAY2.md#val-modifyi) | `Array2.traversal -> (int * int * WideChar.char -> WideChar.char) -> region -> unit` |
| val | [`nCols`](../sig/MONO_ARRAY2.md#val-ncols) | `WideCharArray2.array -> int` |
| val | [`nRows`](../sig/MONO_ARRAY2.md#val-nrows) | `WideCharArray2.array -> int` |
| val | [`row`](../sig/MONO_ARRAY2.md#val-row) | `WideCharArray2.array * int -> WideCharVector.vector` |
| val | [`sub`](../sig/MONO_ARRAY2.md#val-sub) | `WideCharArray2.array * int * int -> WideChar.char` |
| val | [`tabulate`](../sig/MONO_ARRAY2.md#val-tabulate) | `Array2.traversal -> int * int * (int * int -> WideChar.char) -> WideCharArray2.array` |
| val | [`update`](../sig/MONO_ARRAY2.md#val-update) | `WideCharArray2.array * int * int * WideChar.char -> unit` |

<details><summary>Other implementations (9)</summary>

- **Poly/ML** &mdash; as in Array2: an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript on array (0, c, x), fromList \[\] and tabulate tr (0, c, f)
- **Poly/ML** &mdash; as Array2.array: array (0, \~1, x) does not raise Size
- **Poly/ML** &mdash; as in Array2: two arrays without rows are equal
- **Poly/ML** &mdash; as in Array2: the region checks of appi, foldi, modifyi and copy raise Overflow instead of Subscript when row + nrows or col + ncols overflows (copy also for dst\_row + nrows)
- **Poly/ML** &mdash; as in Array2: an array without rows has no number of columns: dimensions, nCols, the traversals and copy raise Subscript, and column (a, j) does not
- **MLKit** &mdash; appi, foldi and modifyi of the MONO\_ARRAY2 structures raise Overflow instead of Subscript when row + nrows or col + ncols overflows
- **MLKit** &mdash; copy, of Array2 and of the MONO\_ARRAY2 structures, accepts a source region whose row is beyond nRows with nrows = NONE or whose nrows is negative (and the same for columns), and then raises Size, and raises Overflow when row + nrows or col + ncols overflows, instead of raising Subscript
- **MLton** &mdash; as Array2.copy: copy within one array to the left or the right in the same rows copies elements that it has already overwritten
- **MLKit** &mdash; copy of the MONO\_ARRAY2 structures checks the destination region against the dimensions of the source's base array instead of those of dst: Subscript for a valid destination, none for an invalid one (the elements are written past the end of dst), and Overflow when dst\_row + nrows or dst\_col + ncols overflows

</details>

---

<sub>Generated by runedoc from lib/basis/widechar.sml; do not edit.</sub>
