# signature LIST

[The Standard ML Basis Library](../README.md) &rsaquo; **LIST**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 27 entries documented |
| Source | [lib/basis/sig\_list.sml](../../../../lib/basis/sig_list.sml) |

## Synopsis

```sml
signature LIST
structure List : LIST
```

| Implementation |  | Source |
| --- | --- | --- |
| `List` | List | [lib/basis/list.sml](../../../../lib/basis/list.sml) |

signature LIST, transcribed from <https://smlfamily.github.io/Basis/list.html>

The page specifies `datatype 'a list = nil | :: of 'a * 'a list`, which the
Definition does not allow (Section 2.9: nil and :: may not be specified);
the replication below is the legal way to say the same.

## Interface

<pre>
signature LIST =
sig
  datatype <a href="#type-list">list</a> = datatype list
  exception <a href="#exn-empty">Empty</a>

  val <a href="#val-null">null</a> : 'a list -&gt; bool
  val <a href="#val-length">length</a> : 'a list -&gt; int
  val <a href="#val-op-at">@</a> : 'a list * 'a list -&gt; 'a list
  val <a href="#val-hd">hd</a> : 'a list -&gt; 'a
  val <a href="#val-tl">tl</a> : 'a list -&gt; 'a list
  val <a href="#val-last">last</a> : 'a list -&gt; 'a
  val <a href="#val-getitem">getItem</a> : 'a list -&gt; ('a * 'a list) option
  val <a href="#val-nth">nth</a> : 'a list * int -&gt; 'a
  val <a href="#val-take">take</a> : 'a list * int -&gt; 'a list
  val <a href="#val-drop">drop</a> : 'a list * int -&gt; 'a list
  val <a href="#val-rev">rev</a> : 'a list -&gt; 'a list
  val <a href="#val-concat">concat</a> : 'a list list -&gt; 'a list
  val <a href="#val-revappend">revAppend</a> : 'a list * 'a list -&gt; 'a list
  val <a href="#val-app">app</a> : ('a -&gt; unit) -&gt; 'a list -&gt; unit
  val <a href="#val-map">map</a> : ('a -&gt; 'b) -&gt; 'a list -&gt; 'b list
  val <a href="#val-mappartial">mapPartial</a> : ('a -&gt; 'b option) -&gt; 'a list -&gt; 'b list
  val <a href="#val-find">find</a> : ('a -&gt; bool) -&gt; 'a list -&gt; 'a option
  val <a href="#val-filter">filter</a> : ('a -&gt; bool) -&gt; 'a list -&gt; 'a list
  val <a href="#val-partition">partition</a> : ('a -&gt; bool) -&gt; 'a list -&gt; 'a list * 'a list
  val <a href="#val-foldl">foldl</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a list -&gt; 'b
  val <a href="#val-foldr">foldr</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a list -&gt; 'b
  val <a href="#val-exists">exists</a> : ('a -&gt; bool) -&gt; 'a list -&gt; bool
  val <a href="#val-all">all</a> : ('a -&gt; bool) -&gt; 'a list -&gt; bool
  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; 'a) -&gt; 'a list
  val <a href="#val-collate">collate</a> : ('a * 'a -&gt; order) -&gt; 'a list * 'a list -&gt; order
end
</pre>

### <a name="type-list"></a>`list`

```sml
datatype list = datatype list
```

### <a name="exn-empty"></a>`Empty`

```sml
exception Empty
```

### <a name="val-null"></a>`null`

```sml
val null : 'a list -> bool
```

### <a name="val-length"></a>`length`

```sml
val length : 'a list -> int
```

### <a name="val-op-at"></a>`@`

```sml
val @ : 'a list * 'a list -> 'a list
```

### <a name="val-hd"></a>`hd`

```sml
val hd : 'a list -> 'a
```

### <a name="val-tl"></a>`tl`

```sml
val tl : 'a list -> 'a list
```

### <a name="val-last"></a>`last`

```sml
val last : 'a list -> 'a
```

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : 'a list -> ('a * 'a list) option
```

### <a name="val-nth"></a>`nth`

```sml
val nth : 'a list * int -> 'a
```

### <a name="val-take"></a>`take`

```sml
val take : 'a list * int -> 'a list
```

### <a name="val-drop"></a>`drop`

```sml
val drop : 'a list * int -> 'a list
```

### <a name="val-rev"></a>`rev`

```sml
val rev : 'a list -> 'a list
```

### <a name="val-concat"></a>`concat`

```sml
val concat : 'a list list -> 'a list
```

### <a name="val-revappend"></a>`revAppend`

```sml
val revAppend : 'a list * 'a list -> 'a list
```

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a list -> unit
```

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a list -> 'b list
```

### <a name="val-mappartial"></a>`mapPartial`

```sml
val mapPartial : ('a -> 'b option) -> 'a list -> 'b list
```

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a list -> 'a option
```

### <a name="val-filter"></a>`filter`

```sml
val filter : ('a -> bool) -> 'a list -> 'a list
```

### <a name="val-partition"></a>`partition`

```sml
val partition : ('a -> bool) -> 'a list -> 'a list * 'a list
```

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b
```

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b
```

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a list -> bool
```

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a list -> bool
```

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> 'a) -> 'a list
```

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a list * 'a list -> order
```

---

<sub>Generated by runedoc from lib/basis/sig\_list.sml; do not edit.</sub>
