# signature ARRAY2

[The Standard ML Basis Library](../README.md) &rsaquo; **ARRAY2**

|  |  |
| --- | --- |
| Status | required |
| Documentation | 0 of 20 entries documented |
| Source | [lib/basis/sig\_array2.sml](../../../../lib/basis/sig_array2.sml) |

## Synopsis

```sml
signature ARRAY2
```

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

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : 'a list list -> 'a array
```

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : traversal -> int * int * (int * int -> 'a) -> 'a array
```

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a array * int * int -> 'a
```

### <a name="val-update"></a>`update`

```sml
val update : 'a array * int * int * 'a -> unit
```

### <a name="val-dimensions"></a>`dimensions`

```sml
val dimensions : 'a array -> int * int
```

### <a name="val-ncols"></a>`nCols`

```sml
val nCols : 'a array -> int
```

### <a name="val-nrows"></a>`nRows`

```sml
val nRows : 'a array -> int
```

### <a name="val-row"></a>`row`

```sml
val row : 'a array * int -> 'a Vector.vector
```

### <a name="val-column"></a>`column`

```sml
val column : 'a array * int -> 'a Vector.vector
```

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

### <a name="val-appi"></a>`appi`

```sml
val appi : traversal -> (int * int * 'a -> unit) -> 'a region -> unit
```

### <a name="val-app"></a>`app`

```sml
val app : traversal -> ('a -> unit) -> 'a array -> unit
```

### <a name="val-foldi"></a>`foldi`

```sml
val foldi : traversal -> (int * int * 'a * 'b -> 'b) -> 'b -> 'a region -> 'b
```

### <a name="val-fold"></a>`fold`

```sml
val fold : traversal -> ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : traversal -> (int * int * 'a -> 'a) -> 'a region -> unit
```

### <a name="val-modify"></a>`modify`

```sml
val modify : traversal -> ('a -> 'a) -> 'a array -> unit
```

---

<sub>Generated by runedoc from lib/basis/sig\_array2.sml; do not edit.</sub>
