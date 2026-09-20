# signature VECTOR_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; **VECTOR_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 24 entries documented |
| Source | [lib/basis/sig\_vector\_slice.sml](../../../../lib/basis/sig_vector_slice.sml) |

## Synopsis

```sml
signature VECTOR_SLICE
structure VectorSlice : VECTOR_SLICE
```

| Implementation |  | Source |
| --- | --- | --- |
| `VectorSlice` | VectorSlice: a vector, a start index and a length. The -i functions pass the index in the slice. | [lib/basis/vectorslice.sml](../../../../lib/basis/vectorslice.sml) |

signature VECTOR\_SLICE, transcribed from
<https://smlfamily.github.io/Basis/vector-slice.html>

## Interface

<pre>
signature VECTOR_SLICE =
sig
  type 'a <a href="#type-slice">slice</a>

  val <a href="#val-length">length</a> : 'a slice -&gt; int
  val <a href="#val-sub">sub</a> : 'a slice * int -&gt; 'a
  val <a href="#val-full">full</a> : 'a Vector.vector -&gt; 'a slice
  val <a href="#val-slice">slice</a> : 'a Vector.vector * int * int option -&gt; 'a slice
  val <a href="#val-subslice">subslice</a> : 'a slice * int * int option -&gt; 'a slice
  val <a href="#val-base">base</a> : 'a slice -&gt; 'a Vector.vector * int * int
  val <a href="#val-vector">vector</a> : 'a slice -&gt; 'a Vector.vector
  val <a href="#val-concat">concat</a> : 'a slice list -&gt; 'a Vector.vector
  val <a href="#val-isempty">isEmpty</a> : 'a slice -&gt; bool
  val <a href="#val-getitem">getItem</a> : 'a slice -&gt; ('a * 'a slice) option
  val <a href="#val-appi">appi</a> : (int * 'a -&gt; unit) -&gt; 'a slice -&gt; unit
  val <a href="#val-app">app</a> : ('a -&gt; unit) -&gt; 'a slice -&gt; unit
  val <a href="#val-mapi">mapi</a> : (int * 'a -&gt; 'b) -&gt; 'a slice -&gt; 'b Vector.vector
  val <a href="#val-map">map</a> : ('a -&gt; 'b) -&gt; 'a slice -&gt; 'b Vector.vector
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

### <a name="val-full"></a>`full`

```sml
val full : 'a Vector.vector -> 'a slice
```

### <a name="val-slice"></a>`slice`

```sml
val slice : 'a Vector.vector * int * int option -> 'a slice
```

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : 'a slice * int * int option -> 'a slice
```

### <a name="val-base"></a>`base`

```sml
val base : 'a slice -> 'a Vector.vector * int * int
```

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a slice -> 'a Vector.vector
```

### <a name="val-concat"></a>`concat`

```sml
val concat : 'a slice list -> 'a Vector.vector
```

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

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * 'a -> 'b) -> 'a slice -> 'b Vector.vector
```

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a slice -> 'b Vector.vector
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

<sub>Generated by runedoc from lib/basis/sig\_vector\_slice.sml; do not edit.</sub>
