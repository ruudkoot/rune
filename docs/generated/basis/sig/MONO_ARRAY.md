# signature MONO_ARRAY

[The Standard ML Basis Library](../README.md) &rsaquo; **MONO_ARRAY**

|  |  |
| --- | --- |
| Status | required |
| Documentation | 0 of 26 entries documented |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_ARRAY
```

## Interface

<pre>
signature MONO_ARRAY =
sig
  eqtype <a href="#type-array">array</a>
  type <a href="#type-elem">elem</a>
  type <a href="#type-vector">vector</a>
  val <a href="#val-maxlen">maxLen</a> : int
  val <a href="#val-array">array</a> : int * elem -&gt; array
  val <a href="#val-fromlist">fromList</a> : elem list -&gt; array
  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; elem) -&gt; array
  val <a href="#val-length">length</a> : array -&gt; int
  val <a href="#val-sub">sub</a> : array * int -&gt; elem
  val <a href="#val-update">update</a> : array * int * elem -&gt; unit
  val <a href="#val-vector">vector</a> : array -&gt; vector
  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : array, <a href="#fld-copy.dst">dst</a> : array, <a href="#fld-copy.di">di</a> : int} -&gt; unit
  val <a href="#val-copyvec">copyVec</a> : {<a href="#fld-copyvec.src">src</a> : vector, <a href="#fld-copyvec.dst">dst</a> : array, <a href="#fld-copyvec.di">di</a> : int} -&gt; unit
  val <a href="#val-appi">appi</a> : (int * elem -&gt; unit) -&gt; array -&gt; unit
  val <a href="#val-app">app</a> : (elem -&gt; unit) -&gt; array -&gt; unit
  val <a href="#val-modifyi">modifyi</a> : (int * elem -&gt; elem) -&gt; array -&gt; unit
  val <a href="#val-modify">modify</a> : (elem -&gt; elem) -&gt; array -&gt; unit
  val <a href="#val-foldli">foldli</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b
  val <a href="#val-foldri">foldri</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b
  val <a href="#val-foldl">foldl</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b
  val <a href="#val-foldr">foldr</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b
  val <a href="#val-findi">findi</a> : (int * elem -&gt; bool) -&gt; array -&gt; (int * elem) option
  val <a href="#val-find">find</a> : (elem -&gt; bool) -&gt; array -&gt; elem option
  val <a href="#val-exists">exists</a> : (elem -&gt; bool) -&gt; array -&gt; bool
  val <a href="#val-all">all</a> : (elem -&gt; bool) -&gt; array -&gt; bool
  val <a href="#val-collate">collate</a> : (elem * elem -&gt; order) -&gt; array * array -&gt; order
end
</pre>

### <a name="type-array"></a>`array`

```sml
eqtype array
```

### <a name="type-elem"></a>`elem`

```sml
type elem
```

### <a name="type-vector"></a>`vector`

```sml
type vector
```

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

### <a name="val-array"></a>`array`

```sml
val array : int * elem -> array
```

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : elem list -> array
```

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> elem) -> array
```

### <a name="val-length"></a>`length`

```sml
val length : array -> int
```

### <a name="val-sub"></a>`sub`

```sml
val sub : array * int -> elem
```

### <a name="val-update"></a>`update`

```sml
val update : array * int * elem -> unit
```

### <a name="val-vector"></a>`vector`

```sml
val vector : array -> vector
```

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : array, dst : array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `array` |  |
| <a name="fld-copy.dst"></a>`dst` | `array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : vector, dst : array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `vector` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> array -> unit
```

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> array -> unit
```

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * elem -> elem) -> array -> unit
```

### <a name="val-modify"></a>`modify`

```sml
val modify : (elem -> elem) -> array -> unit
```

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'b -> 'b) -> 'b -> array -> 'b
```

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'b -> 'b) -> 'b -> array -> 'b
```

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'b -> 'b) -> 'b -> array -> 'b
```

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'b -> 'b) -> 'b -> array -> 'b
```

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> array -> (int * elem) option
```

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> array -> elem option
```

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> array -> bool
```

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> array -> bool
```

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> array * array -> order
```

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
