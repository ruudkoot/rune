# signature MONO_VECTOR_EQ

[The Standard ML Basis Library](../README.md) &rsaquo; **MONO_VECTOR_EQ**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 22 entries documented |
| Tests | 131 checks of 21 entries |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_VECTOR_EQ
structure WideCharVector :> MONO_VECTOR_EQ where type elem = RuneWideChar.char  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `WideCharVector` | Sealed with a vector of its own (MONO\_VECTOR\_EQ), so that WideString.string is a type name: the constants of a type are overloaded at a name. | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |

The same with a vector that admits equality, for a family whose vector is a
type of its own: WideCharVector, whose vector is the string of WideString,
needs a type name so that wide string constants can be overloaded at it
(`_overload string`), and strings are compared with =.

## Interface

<pre>
signature MONO_VECTOR_EQ =
sig
  eqtype <a href="#type-vector">vector</a>
  type <a href="#type-elem">elem</a>
  val <a href="#val-maxlen">maxLen</a> : int
  val <a href="#val-fromlist">fromList</a> : elem list -&gt; vector
  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; elem) -&gt; vector
  val <a href="#val-length">length</a> : vector -&gt; int
  val <a href="#val-sub">sub</a> : vector * int -&gt; elem
  val <a href="#val-update">update</a> : vector * int * elem -&gt; vector
  val <a href="#val-concat">concat</a> : vector list -&gt; vector
  val <a href="#val-appi">appi</a> : (int * elem -&gt; unit) -&gt; vector -&gt; unit
  val <a href="#val-app">app</a> : (elem -&gt; unit) -&gt; vector -&gt; unit
  val <a href="#val-mapi">mapi</a> : (int * elem -&gt; elem) -&gt; vector -&gt; vector
  val <a href="#val-map">map</a> : (elem -&gt; elem) -&gt; vector -&gt; vector
  val <a href="#val-foldli">foldli</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; vector -&gt; 'b
  val <a href="#val-foldri">foldri</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; vector -&gt; 'b
  val <a href="#val-foldl">foldl</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; vector -&gt; 'b
  val <a href="#val-foldr">foldr</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; vector -&gt; 'b
  val <a href="#val-findi">findi</a> : (int * elem -&gt; bool) -&gt; vector -&gt; (int * elem) option
  val <a href="#val-find">find</a> : (elem -&gt; bool) -&gt; vector -&gt; elem option
  val <a href="#val-exists">exists</a> : (elem -&gt; bool) -&gt; vector -&gt; bool
  val <a href="#val-all">all</a> : (elem -&gt; bool) -&gt; vector -&gt; bool
  val <a href="#val-collate">collate</a> : (elem * elem -&gt; order) -&gt; vector * vector -&gt; order
end
</pre>

### <a name="type-vector"></a>`vector`

```sml
eqtype vector
```

### <a name="type-elem"></a>`elem`

```sml
type elem
```

<details><summary>Tests (1)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `eight-distinct-samples`

</details>

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

<details><summary>Tests (1)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `covers-created-vectors`

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : elem list -> vector
```

<details><summary>Tests (7)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `nil` &middot; `singleton` &middot; `every-sample` &middot; `length` &middot; `round-trip*` &middot; `long`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> elem) -> vector
```

<details><summary>Tests (8)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `zero` &middot; `one` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f` &middot; `model*` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-length"></a>`length`

```sml
val length : vector -> int
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `empty` &middot; `five` &middot; `tabulate` &middot; `model*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : vector * int -> elem
```

<details><summary>Tests (9)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `first` &middot; `middle` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-update"></a>`update`

```sml
val update : vector * int * elem -> vector
```

<details><summary>Tests (12)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `first` &middot; `middle` &middot; `last` &middot; `singleton` &middot; `argument-unchanged` &middot; `twice` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : vector list -> vector
```

<details><summary>Tests (10)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `nil` &middot; `one` &middot; `empties` &middot; `same-twice` &middot; `order` &middot; `model*` &middot; `long` &middot; `many` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> vector -> unit
```

<details><summary>Tests (3)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> vector -> unit
```

<details><summary>Tests (3)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * elem -> elem) -> vector -> vector
```

<details><summary>Tests (6)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `index-only` &middot; `empty` &middot; `order` &middot; `model*` &middot; `long`

</details>

### <a name="val-map"></a>`map`

```sml
val map : (elem -> elem) -> vector -> vector
```

<details><summary>Tests (7)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `wraps` &middot; `empty` &middot; `order` &middot; `argument-unchanged` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'b -> 'b) -> 'b -> vector -> 'b
```

<details><summary>Tests (4)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'b -> 'b) -> 'b -> vector -> 'b
```

<details><summary>Tests (4)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'b -> 'b) -> 'b -> vector -> 'b
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'b -> 'b) -> 'b -> vector -> 'b
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> vector -> (int * elem) option
```

<details><summary>Tests (8)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> vector -> elem option
```

<details><summary>Tests (6)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `first-match` &middot; `last-element` &middot; `none` &middot; `empty` &middot; `stops` &middot; `model*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> vector -> bool
```

<details><summary>Tests (6)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> vector -> bool
```

<details><summary>Tests (8)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*` &middot; `de-morgan*` &middot; `long`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> vector * vector -> order
```

<details><summary>Tests (13)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `equal` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model*` &middot; `reflexive*` &middot; `long`

</details>

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
