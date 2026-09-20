# signature ARRAY2

[The Standard ML Basis Library](../README.md) &rsaquo; **ARRAY2**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 20 entries documented |
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

signature ARRAY2, transcribed from
<https://smlfamily.github.io/Basis/array2.html>

## Interface

<pre>
signature ARRAY2 =
sig
  eqtype 'a <a href="#type-array">array</a>
  type 'a <a href="#type-region">region</a> = {<a href="#fld-region.base">base</a> : 'a array, <a href="#fld-region.row">row</a> : int, <a href="#fld-region.col">col</a> : int, <a href="#fld-region.nrows">nrows</a> : int option, <a href="#fld-region.ncols">ncols</a> : int option}
  datatype <a href="#type-traversal">traversal</a> = <a href="#con-rowmajor">RowMajor</a> | <a href="#con-colmajor">ColMajor</a>

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

<details><summary>Tests (27)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `one` &middot; `dimensions` &middot; `no-rows` &middot; `no-columns` &middot; `no-rows-no-columns` &middot; `no-columns-rows` &middot; `Size-negative-rows` (raises Size) &middot; `Size-negative-columns` (raises Size) &middot; `Size-negative-both` (raises Size) &middot; `Size-negative-rows-no-columns` (raises Size) &middot; `Size-negative-columns-no-rows` (raises Size) &middot; `elements-are-separate` &middot; `every-element-is-init` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `of-reals-same` &middot; `of-reals-not-equal` &middot; `of-functions-same` &middot; `*` &middot; `Size-too-large` (raises Size) &middot; `Size-too-large-rows` (raises Size) &middot; `Size-too-large-columns` (raises Size)

</details>

### <a name="type-region"></a>`region`

```sml
type 'a region = {base : 'a array, row : int, col : int, nrows : int option, ncols : int option}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-region.base"></a>`base` | `'a array` |  |
| <a name="fld-region.row"></a>`row` | `int` |  |
| <a name="fld-region.col"></a>`col` | `int` |  |
| <a name="fld-region.nrows"></a>`nrows` | `int option` |  |
| <a name="fld-region.ncols"></a>`ncols` | `int option` |  |

### <a name="type-traversal"></a>`traversal`

```sml
datatype traversal = RowMajor | ColMajor
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-rowmajor"></a>`RowMajor` |  |  |
| <a name="con-colmajor"></a>`ColMajor` |  |  |

### <a name="val-array"></a>`array`

```sml
val array : int * int * 'a -> 'a array
```

<details><summary>Tests (27)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `one` &middot; `dimensions` &middot; `no-rows` &middot; `no-columns` &middot; `no-rows-no-columns` &middot; `no-columns-rows` &middot; `Size-negative-rows` (raises Size) &middot; `Size-negative-columns` (raises Size) &middot; `Size-negative-both` (raises Size) &middot; `Size-negative-rows-no-columns` (raises Size) &middot; `Size-negative-columns-no-rows` (raises Size) &middot; `elements-are-separate` &middot; `every-element-is-init` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `of-reals-same` &middot; `of-reals-not-equal` &middot; `of-functions-same` &middot; `*` &middot; `Size-too-large` (raises Size) &middot; `Size-too-large-rows` (raises Size) &middot; `Size-too-large-columns` (raises Size)

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : 'a list list -> 'a array
```

<details><summary>Tests (18)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `dimensions` &middot; `second-row-first-column` &middot; `first-row-last-column` &middot; `one-row` &middot; `one-column` &middot; `one-element` &middot; `no-rows` &middot; `empty-rows` &middot; `strings` &middot; `Size-second-shorter` (raises Size) &middot; `Size-second-longer` (raises Size) &middot; `Size-last-shorter` (raises Size) &middot; `Size-first-empty` (raises Size) &middot; `Size-second-empty` (raises Size) &middot; `same-elements-not-equal` &middot; `zero-length-not-equal` &middot; `*`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : traversal -> int * int * (int * int -> 'a) -> 'a array
```

<details><summary>Tests (19)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `RowMajor` &middot; `ColMajor` &middot; `dimensions` &middot; `RowMajor-order` &middot; `ColMajor-order` &middot; `RowMajor-counter` &middot; `ColMajor-counter` &middot; `one` &middot; `no-rows` &middot; `no-columns` &middot; `no-elements-no-f` &middot; `Size-negative-rows` (raises Size) &middot; `Size-negative-columns` (raises Size) &middot; `Size-negative-ColMajor` (raises Size) &middot; `Size-before-f` &middot; `same-elements-not-equal` &middot; `*` &middot; `Size-too-large-RowMajor` (raises Size) &middot; `Size-too-large-ColMajor` (raises Size)

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a array * int * int -> 'a
```

<details><summary>Tests (20)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `first` &middot; `end-of-first-row` &middot; `start-of-last-row` &middot; `middle` &middot; `last` &middot; `Subscript-row-nRows` (raises Subscript) &middot; `Subscript-column-nCols` (raises Subscript) &middot; `Subscript-column-nCols-last-row` (raises Subscript) &middot; `Subscript-negative-row` (raises Subscript) &middot; `Subscript-negative-column` (raises Subscript) &middot; `Subscript-negative-row-column-beyond` (raises Subscript) &middot; `Subscript-column-is-a-row-index` (raises Subscript) &middot; `Subscript-row-is-a-column-index` (raises Subscript) &middot; `Subscript-no-rows` (raises Subscript) &middot; `Subscript-no-columns` (raises Subscript) &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow-row` (raises Subscript) &middot; `Subscript-not-Overflow-column` (raises Subscript) &middot; `Subscript-not-Overflow-both` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-update"></a>`update`

```sml
val update : 'a array * int * int * 'a -> unit
```

<details><summary>Tests (17)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `first` &middot; `end-of-first-row` &middot; `start-of-last-row` &middot; `last` &middot; `twice-same-element` &middot; `seen-through-alias` &middot; `Subscript-row-nRows` (raises Subscript) &middot; `Subscript-column-nCols` (raises Subscript) &middot; `Subscript-negative-row` (raises Subscript) &middot; `Subscript-negative-column` (raises Subscript) &middot; `Subscript-no-rows` (raises Subscript) &middot; `Subscript-no-columns` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow-row` (raises Subscript) &middot; `Subscript-not-Overflow-column` (raises Subscript) &middot; `Subscript-not-Overflow-least` (raises Subscript)

</details>

### <a name="val-dimensions"></a>`dimensions`

```sml
val dimensions : 'a array -> int * int
```

<details><summary>Tests (3)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `rows-then-columns` &middot; `one-row` &middot; `*`

</details>

### <a name="val-ncols"></a>`nCols`

```sml
val nCols : 'a array -> int
```

<details><summary>Tests (5)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `no-rows` &middot; `no-columns` &middot; `is-second-of-dimensions` &middot; `*`

</details>

### <a name="val-nrows"></a>`nRows`

```sml
val nRows : 'a array -> int
```

<details><summary>Tests (5)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `basic` &middot; `no-rows` &middot; `no-columns` &middot; `is-first-of-dimensions` &middot; `*`

</details>

### <a name="val-row"></a>`row`

```sml
val row : 'a array * int -> 'a Vector.vector
```

<details><summary>Tests (11)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `first` &middot; `middle` &middot; `last` &middot; `no-columns` &middot; `is-a-snapshot` &middot; `Subscript-nRows` (raises Subscript) &middot; `Subscript-is-a-column-index` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-no-rows` (raises Subscript) &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript)

</details>

### <a name="val-column"></a>`column`

```sml
val column : 'a array * int -> 'a Vector.vector
```

<details><summary>Tests (11)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `first` &middot; `middle` &middot; `last` &middot; `no-rows` &middot; `is-a-snapshot` &middot; `Subscript-nCols` (raises Subscript) &middot; `Subscript-is-a-row-index` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-no-columns` (raises Subscript) &middot; `*` &middot; `*` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript)

</details>

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : 'a region, dst : 'a array, dst_row : int, dst_col : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `'a region` |  |
| <a name="fld-copy.dst"></a>`dst` | `'a array` |  |
| <a name="fld-copy.dst_row"></a>`dst_row` | `int` |  |
| <a name="fld-copy.dst_col"></a>`dst_col` | `int` |  |

<details><summary>Tests (41)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `region` &middot; `to-the-first-corner` &middot; `to-the-last-corner` &middot; `whole-NONE` &middot; `whole-same-dimensions` &middot; `NONE-rows-SOME-cols` &middot; `SOME-rows-NONE-cols` &middot; `field-order` &middot; `src-unchanged` &middot; `copies-elements-not-the-array` &middot; `Subscript-src-*` (raises Subscript) &middot; `Subscript-dst-negative-row` (raises Subscript) &middot; `Subscript-dst-negative-col` (raises Subscript) &middot; `Subscript-dst-one-row-too-far` (raises Subscript) &middot; `Subscript-dst-one-col-too-far` (raises Subscript) &middot; `Subscript-dst-row-nRows` (raises Subscript) &middot; `Subscript-dst-col-nCols` (raises Subscript) &middot; `Subscript-dst-smaller` (raises Subscript) &middot; `Subscript-dst-no-rows` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `overlap-down-right` &middot; `overlap-up-left` &middot; `overlap-down-left` &middot; `overlap-up-right` &middot; `overlap-right` &middot; `overlap-left` &middot; `overlap-down` &middot; `overlap-up` &middot; `overlap-onto-itself` &middot; `same-array-apart` &middot; `overlap-Subscript` (raises Subscript) &middot; `*` &middot; `within-*` &middot; `nothing-*` &middot; `nothing-to-the-end-of-dst` &middot; `Subscript-dst-nothing-row-beyond` (raises Subscript) &middot; `Subscript-dst-nothing-cols-too-far` (raises Subscript) &middot; `Subscript-not-Overflow-src-*` (raises Subscript) &middot; `Subscript-not-Overflow-dst-sum-row` (raises Subscript) &middot; `Subscript-not-Overflow-dst-sum-col` (raises Subscript) &middot; `Subscript-not-Overflow-dst-least` (raises Subscript)

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : traversal -> (int * int * 'a -> unit) -> 'a region -> unit
```

<details><summary>Tests (17)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `whole-RowMajor` &middot; `whole-ColMajor` &middot; `region-RowMajor` &middot; `region-ColMajor` &middot; `NONE-to-the-end-RowMajor` &middot; `NONE-to-the-end-ColMajor` &middot; `one-row` &middot; `one-column` &middot; `last-element` &middot; `Subscript-*` (raises Subscript) &middot; `Subscript-ColMajor-too-many-rows` (raises Subscript) &middot; `Subscript-ColMajor-too-many-cols` (raises Subscript) &middot; `Subscript-before-f` &middot; `*` &middot; `nothing-RowMajor-*` &middot; `nothing-ColMajor-*` &middot; `Subscript-not-Overflow-*` (raises Subscript)

</details>

### <a name="val-app"></a>`app`

```sml
val app : traversal -> ('a -> unit) -> 'a array -> unit
```

<details><summary>Tests (6)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `RowMajor` &middot; `ColMajor` &middot; `no-rows` &middot; `no-columns` &middot; `array-unchanged` &middot; `*`

</details>

### <a name="val-foldi"></a>`foldi`

```sml
val foldi : traversal -> (int * int * 'a * 'b -> 'b) -> 'b -> 'a region -> 'b
```

<details><summary>Tests (15)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `whole-RowMajor-conses-reversed` &middot; `whole-ColMajor-conses-reversed` &middot; `region-RowMajor` &middot; `region-ColMajor` &middot; `nonassociative-RowMajor` &middot; `nonassociative-ColMajor` &middot; `NONE-to-the-end` &middot; `Subscript-*` (raises Subscript) &middot; `Subscript-ColMajor-too-many-rows` (raises Subscript) &middot; `Subscript-ColMajor-too-many-cols` (raises Subscript) &middot; `Subscript-before-f` &middot; `*` &middot; `nothing-RowMajor-*` &middot; `nothing-ColMajor-*` &middot; `Subscript-not-Overflow-*` (raises Subscript)

</details>

### <a name="val-fold"></a>`fold`

```sml
val fold : traversal -> ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

<details><summary>Tests (7)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `RowMajor-conses-reversed` &middot; `ColMajor-conses-reversed` &middot; `nonassociative-RowMajor` &middot; `nonassociative-ColMajor` &middot; `no-rows` &middot; `no-columns` &middot; `*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : traversal -> (int * int * 'a -> 'a) -> 'a region -> unit
```

<details><summary>Tests (16)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `region` &middot; `region-ColMajor` &middot; `whole` &middot; `NONE-to-the-end` &middot; `order-RowMajor` &middot; `order-ColMajor` &middot; `RowMajor-counter` &middot; `ColMajor-counter` &middot; `Subscript-*` (raises Subscript) &middot; `Subscript-ColMajor-too-many-rows` (raises Subscript) &middot; `Subscript-ColMajor-too-many-cols` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `*` &middot; `nothing-RowMajor-*` &middot; `nothing-ColMajor-*` &middot; `Subscript-not-Overflow-*` (raises Subscript)

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : traversal -> ('a -> 'a) -> 'a array -> unit
```

<details><summary>Tests (8)</summary>

For `Array2`, in [tests/basis/array2.sml](../../../../tests/basis/array2.sml): `RowMajor` &middot; `ColMajor` &middot; `order-RowMajor` &middot; `order-ColMajor` &middot; `ColMajor-counter` &middot; `no-rows` &middot; `twice` &middot; `*`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_array2.sml; do not edit.</sub>
