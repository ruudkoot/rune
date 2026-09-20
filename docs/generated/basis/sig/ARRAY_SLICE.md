# signature ARRAY_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; **ARRAY_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Documentation | 0 of 26 entries documented |
| Source | [lib/basis/sig\_array\_slice.sml](../../../../lib/basis/sig_array_slice.sml) |

## Synopsis

```sml
signature ARRAY_SLICE
```

signature ARRAY\_SLICE, transcribed from
<https://smlfamily.github.io/Basis/array-slice.html>

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

### <a name="val-length"></a>`length`

```sml
val length : 'a slice -> int
```

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a slice * int -> 'a
```

### <a name="val-update"></a>`update`

```sml
val update : 'a slice * int * 'a -> unit
```

### <a name="val-full"></a>`full`

```sml
val full : 'a Array.array -> 'a slice
```

### <a name="val-slice"></a>`slice`

```sml
val slice : 'a Array.array * int * int option -> 'a slice
```

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : 'a slice * int * int option -> 'a slice
```

### <a name="val-base"></a>`base`

```sml
val base : 'a slice -> 'a Array.array * int * int
```

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a slice -> 'a Vector.vector
```

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : 'a slice, dst : 'a Array.array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `'a slice` |  |
| <a name="fld-copy.dst"></a>`dst` | `'a Array.array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : 'a VectorSlice.slice, dst : 'a Array.array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `'a VectorSlice.slice` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `'a Array.array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : 'a slice -> bool
```

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : 'a slice -> ('a * 'a slice) option
```

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * 'a -> unit) -> 'a slice -> unit
```

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a slice -> unit
```

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * 'a -> 'a) -> 'a slice -> unit
```

### <a name="val-modify"></a>`modify`

```sml
val modify : ('a -> 'a) -> 'a slice -> unit
```

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b
```

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a slice -> (int * 'a) option
```

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a slice -> 'a option
```

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a slice -> bool
```

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a slice -> bool
```

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a slice * 'a slice -> order
```

---

<sub>Generated by runedoc from lib/basis/sig\_array\_slice.sml; do not edit.</sub>
