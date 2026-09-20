# signature MONO_ARRAY_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; **MONO_ARRAY_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Documentation | 0 of 30 entries documented |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_ARRAY_SLICE
```

## Interface

<pre>
signature MONO_ARRAY_SLICE =
sig
  type <a href="#type-elem">elem</a>
  type <a href="#type-array">array</a>
  type <a href="#type-slice">slice</a>
  type <a href="#type-vector">vector</a>
  type <a href="#type-vector_slice">vector_slice</a>
  val <a href="#val-length">length</a> : slice -&gt; int
  val <a href="#val-sub">sub</a> : slice * int -&gt; elem
  val <a href="#val-update">update</a> : slice * int * elem -&gt; unit
  val <a href="#val-full">full</a> : array -&gt; slice
  val <a href="#val-slice">slice</a> : array * int * int option -&gt; slice
  val <a href="#val-subslice">subslice</a> : slice * int * int option -&gt; slice
  val <a href="#val-base">base</a> : slice -&gt; array * int * int
  val <a href="#val-vector">vector</a> : slice -&gt; vector
  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : slice, <a href="#fld-copy.dst">dst</a> : array, <a href="#fld-copy.di">di</a> : int} -&gt; unit
  val <a href="#val-copyvec">copyVec</a> : {<a href="#fld-copyvec.src">src</a> : vector_slice, <a href="#fld-copyvec.dst">dst</a> : array, <a href="#fld-copyvec.di">di</a> : int} -&gt; unit
  val <a href="#val-isempty">isEmpty</a> : slice -&gt; bool
  val <a href="#val-getitem">getItem</a> : slice -&gt; (elem * slice) option
  val <a href="#val-appi">appi</a> : (int * elem -&gt; unit) -&gt; slice -&gt; unit
  val <a href="#val-app">app</a> : (elem -&gt; unit) -&gt; slice -&gt; unit
  val <a href="#val-modifyi">modifyi</a> : (int * elem -&gt; elem) -&gt; slice -&gt; unit
  val <a href="#val-modify">modify</a> : (elem -&gt; elem) -&gt; slice -&gt; unit
  val <a href="#val-foldli">foldli</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b
  val <a href="#val-foldr">foldr</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b
  val <a href="#val-foldl">foldl</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b
  val <a href="#val-foldri">foldri</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b
  val <a href="#val-findi">findi</a> : (int * elem -&gt; bool) -&gt; slice -&gt; (int * elem) option
  val <a href="#val-find">find</a> : (elem -&gt; bool) -&gt; slice -&gt; elem option
  val <a href="#val-exists">exists</a> : (elem -&gt; bool) -&gt; slice -&gt; bool
  val <a href="#val-all">all</a> : (elem -&gt; bool) -&gt; slice -&gt; bool
  val <a href="#val-collate">collate</a> : (elem * elem -&gt; order) -&gt; slice * slice -&gt; order
end
</pre>

### <a name="type-elem"></a>`elem`

```sml
type elem
```

### <a name="type-array"></a>`array`

```sml
type array
```

### <a name="type-slice"></a>`slice`

```sml
type slice
```

### <a name="type-vector"></a>`vector`

```sml
type vector
```

### <a name="type-vector_slice"></a>`vector_slice`

```sml
type vector_slice
```

### <a name="val-length"></a>`length`

```sml
val length : slice -> int
```

### <a name="val-sub"></a>`sub`

```sml
val sub : slice * int -> elem
```

### <a name="val-update"></a>`update`

```sml
val update : slice * int * elem -> unit
```

### <a name="val-full"></a>`full`

```sml
val full : array -> slice
```

### <a name="val-slice"></a>`slice`

```sml
val slice : array * int * int option -> slice
```

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : slice * int * int option -> slice
```

### <a name="val-base"></a>`base`

```sml
val base : slice -> array * int * int
```

### <a name="val-vector"></a>`vector`

```sml
val vector : slice -> vector
```

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : slice, dst : array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `slice` |  |
| <a name="fld-copy.dst"></a>`dst` | `array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : vector_slice, dst : array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `vector_slice` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : slice -> bool
```

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : slice -> (elem * slice) option
```

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> slice -> unit
```

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> slice -> unit
```

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * elem -> elem) -> slice -> unit
```

### <a name="val-modify"></a>`modify`

```sml
val modify : (elem -> elem) -> slice -> unit
```

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> slice -> (int * elem) option
```

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> slice -> elem option
```

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> slice -> bool
```

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> slice -> bool
```

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> slice * slice -> order
```

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
