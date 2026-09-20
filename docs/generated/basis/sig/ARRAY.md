# signature ARRAY

[The Standard ML Basis Library](../README.md) &rsaquo; **ARRAY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 25 entries documented |
| Source | [lib/basis/sig\_array.sml](../../../../lib/basis/sig_array.sml) |

## Synopsis

```sml
signature ARRAY
structure Array : ARRAY
```

| Implementation |  | Source |
| --- | --- | --- |
| `Array` | Array: mutable arrays with identity equality. | [lib/basis/array.sml](../../../../lib/basis/array.sml) |

signature ARRAY, transcribed from <https://smlfamily.github.io/Basis/array.html>

The page specifies `eqtype 'a array = 'a array`, which is not a
specification of the Definition (an eqtype specification has no right-hand
side). The type abbreviation below says the same: the type is the top-level
array type, and it admits equality, whatever the element type, because that
type does.

## Interface

<pre>
signature ARRAY =
sig
  type 'a <a href="#type-array">array</a> = 'a array
  type 'a <a href="#type-vector">vector</a> = 'a Vector.vector

  val <a href="#val-maxlen">maxLen</a> : int
  val <a href="#val-array">array</a> : int * 'a -&gt; 'a array
  val <a href="#val-fromlist">fromList</a> : 'a list -&gt; 'a array
  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; 'a) -&gt; 'a array
  val <a href="#val-length">length</a> : 'a array -&gt; int
  val <a href="#val-sub">sub</a> : 'a array * int -&gt; 'a
  val <a href="#val-update">update</a> : 'a array * int * 'a -&gt; unit
  val <a href="#val-vector">vector</a> : 'a array -&gt; 'a vector
  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : 'a array, <a href="#fld-copy.dst">dst</a> : 'a array, <a href="#fld-copy.di">di</a> : int} -&gt; unit
  val <a href="#val-copyvec">copyVec</a> : {<a href="#fld-copyvec.src">src</a> : 'a vector, <a href="#fld-copyvec.dst">dst</a> : 'a array, <a href="#fld-copyvec.di">di</a> : int} -&gt; unit
  val <a href="#val-appi">appi</a> : (int * 'a -&gt; unit) -&gt; 'a array -&gt; unit
  val <a href="#val-app">app</a> : ('a -&gt; unit) -&gt; 'a array -&gt; unit
  val <a href="#val-modifyi">modifyi</a> : (int * 'a -&gt; 'a) -&gt; 'a array -&gt; unit
  val <a href="#val-modify">modify</a> : ('a -&gt; 'a) -&gt; 'a array -&gt; unit
  val <a href="#val-foldli">foldli</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a array -&gt; 'b
  val <a href="#val-foldri">foldri</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a array -&gt; 'b
  val <a href="#val-foldl">foldl</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a array -&gt; 'b
  val <a href="#val-foldr">foldr</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a array -&gt; 'b
  val <a href="#val-findi">findi</a> : (int * 'a -&gt; bool) -&gt; 'a array -&gt; (int * 'a) option
  val <a href="#val-find">find</a> : ('a -&gt; bool) -&gt; 'a array -&gt; 'a option
  val <a href="#val-exists">exists</a> : ('a -&gt; bool) -&gt; 'a array -&gt; bool
  val <a href="#val-all">all</a> : ('a -&gt; bool) -&gt; 'a array -&gt; bool
  val <a href="#val-collate">collate</a> : ('a * 'a -&gt; order) -&gt; 'a array * 'a array -&gt; order
end
</pre>

### <a name="type-array"></a>`array`

```sml
type 'a array = 'a array
```

### <a name="type-vector"></a>`vector`

```sml
type 'a vector = 'a Vector.vector
```

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

### <a name="val-array"></a>`array`

```sml
val array : int * 'a -> 'a array
```

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : 'a list -> 'a array
```

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> 'a) -> 'a array
```

### <a name="val-length"></a>`length`

```sml
val length : 'a array -> int
```

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a array * int -> 'a
```

### <a name="val-update"></a>`update`

```sml
val update : 'a array * int * 'a -> unit
```

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a array -> 'a vector
```

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : 'a array, dst : 'a array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `'a array` |  |
| <a name="fld-copy.dst"></a>`dst` | `'a array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : 'a vector, dst : 'a array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `'a vector` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `'a array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * 'a -> unit) -> 'a array -> unit
```

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a array -> unit
```

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * 'a -> 'a) -> 'a array -> unit
```

### <a name="val-modify"></a>`modify`

```sml
val modify : ('a -> 'a) -> 'a array -> unit
```

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a array -> (int * 'a) option
```

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a array -> 'a option
```

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a array -> bool
```

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a array -> bool
```

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a array * 'a array -> order
```

---

<sub>Generated by runedoc from lib/basis/sig\_array.sml; do not edit.</sub>
