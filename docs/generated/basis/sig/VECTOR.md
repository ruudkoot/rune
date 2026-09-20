# signature VECTOR

[The Standard ML Basis Library](../README.md) &rsaquo; **VECTOR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 21 entries documented |
| Tests | 148 checks of 21 entries |
| Source | [lib/basis/sig\_vector.sml](../../../../lib/basis/sig_vector.sml) |

## Synopsis

```sml
signature VECTOR
structure Vector : VECTOR
```

| Implementation |  | Source |
| --- | --- | --- |
| `Vector` | Vector: immutable arrays with structural equality. | [lib/basis/vector.sml](../../../../lib/basis/vector.sml) |

signature VECTOR, transcribed from <https://smlfamily.github.io/Basis/vector.html>

The page specifies `eqtype 'a vector = 'a vector`, which is not a
specification of the Definition (an eqtype specification has no right-hand
side). The type abbreviation below says the same: the type is the top-level
vector type, and it admits equality because that type does.

## Interface

<pre>
signature VECTOR =
sig
  type 'a <a href="#type-vector">vector</a> = 'a vector

  val <a href="#val-maxlen">maxLen</a> : int
  val <a href="#val-fromlist">fromList</a> : 'a list -&gt; 'a vector
  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; 'a) -&gt; 'a vector
  val <a href="#val-length">length</a> : 'a vector -&gt; int
  val <a href="#val-sub">sub</a> : 'a vector * int -&gt; 'a
  val <a href="#val-update">update</a> : 'a vector * int * 'a -&gt; 'a vector
  val <a href="#val-concat">concat</a> : 'a vector list -&gt; 'a vector
  val <a href="#val-appi">appi</a> : (int * 'a -&gt; unit) -&gt; 'a vector -&gt; unit
  val <a href="#val-app">app</a> : ('a -&gt; unit) -&gt; 'a vector -&gt; unit
  val <a href="#val-mapi">mapi</a> : (int * 'a -&gt; 'b) -&gt; 'a vector -&gt; 'b vector
  val <a href="#val-map">map</a> : ('a -&gt; 'b) -&gt; 'a vector -&gt; 'b vector
  val <a href="#val-foldli">foldli</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a vector -&gt; 'b
  val <a href="#val-foldri">foldri</a> : (int * 'a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a vector -&gt; 'b
  val <a href="#val-foldl">foldl</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a vector -&gt; 'b
  val <a href="#val-foldr">foldr</a> : ('a * 'b -&gt; 'b) -&gt; 'b -&gt; 'a vector -&gt; 'b
  val <a href="#val-findi">findi</a> : (int * 'a -&gt; bool) -&gt; 'a vector -&gt; (int * 'a) option
  val <a href="#val-find">find</a> : ('a -&gt; bool) -&gt; 'a vector -&gt; 'a option
  val <a href="#val-exists">exists</a> : ('a -&gt; bool) -&gt; 'a vector -&gt; bool
  val <a href="#val-all">all</a> : ('a -&gt; bool) -&gt; 'a vector -&gt; bool
  val <a href="#val-collate">collate</a> : ('a * 'a -&gt; order) -&gt; 'a vector * 'a vector -&gt; order
end
</pre>

### <a name="type-vector"></a>`vector`

```sml
type 'a vector = 'a vector
```

<details><summary>Tests (16)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `equal` &middot; `equal-tabulate` &middot; `element-differs` &middot; `prefix` &middot; `empty-equal` &middot; `empty-nonempty` &middot; `unequal` &middot; `strings` &middot; `nested` &middot; `nested-differs` &middot; `update-to-same` &middot; `update-differs` &middot; `is-toplevel` &middot; `model-*` &middot; `reflexive-*` &middot; `long`

</details>

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

<details><summary>Tests (1)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `covers-created-vectors`

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : 'a list -> 'a vector
```

Also in the [top-level environment](../top-level.md): `vector`.

<details><summary>Tests (7)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `nil` &middot; `singleton` &middot; `length` &middot; `strings` &middot; `round-trip-*` &middot; `long`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> 'a) -> 'a vector
```

<details><summary>Tests (8)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `zero` &middot; `one` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f` &middot; `model-*` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-length"></a>`length`

```sml
val length : 'a vector -> int
```

<details><summary>Tests (5)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `empty` &middot; `five` &middot; `tabulate` &middot; `model-*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a vector * int -> 'a
```

<details><summary>Tests (9)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `first` &middot; `middle` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

### <a name="val-update"></a>`update`

```sml
val update : 'a vector * int * 'a -> 'a vector
```

<details><summary>Tests (12)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `first` &middot; `middle` &middot; `last` &middot; `singleton` &middot; `argument-unchanged` &middot; `twice` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : 'a vector list -> 'a vector
```

<details><summary>Tests (10)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `nil` &middot; `one` &middot; `empties` &middot; `same-twice` &middot; `order` &middot; `model-*` &middot; `long` &middot; `many` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * 'a -> unit) -> 'a vector -> unit
```

<details><summary>Tests (3)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `order` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a vector -> unit
```

<details><summary>Tests (3)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `order` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * 'a -> 'b) -> 'a vector -> 'b vector
```

<details><summary>Tests (6)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `index-and-element` &middot; `empty` &middot; `order` &middot; `model-*` &middot; `long`

</details>

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a vector -> 'b vector
```

<details><summary>Tests (7)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `basic` &middot; `empty` &middot; `order` &middot; `other-type` &middot; `argument-unchanged` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a vector -> 'b
```

<details><summary>Tests (4)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a vector -> 'b
```

<details><summary>Tests (4)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a vector -> 'b
```

<details><summary>Tests (5)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a vector -> 'b
```

<details><summary>Tests (6)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long` &middot; `long-list`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a vector -> (int * 'a) option
```

<details><summary>Tests (8)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a vector -> 'a option
```

<details><summary>Tests (7)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `first-match` &middot; `last-element` &middot; `none` &middot; `empty` &middot; `stops` &middot; `model-*` &middot; `long`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a vector -> bool
```

<details><summary>Tests (6)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a vector -> bool
```

<details><summary>Tests (8)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `de-morgan-*` &middot; `long`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a vector * 'a vector -> order
```

<details><summary>Tests (13)</summary>

For `Vector`, in [tests/basis/vector.sml](../../../../tests/basis/vector.sml): `equal` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model-*` &middot; `reflexive-*` &middot; `long`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_vector.sml; do not edit.</sub>
