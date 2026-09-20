# signature ARRAY

[The Standard ML Basis Library](../README.md) &rsaquo; **ARRAY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 25 entries documented |
| Tests | 235 checks of 25 entries |
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

<details><summary>Tests (23)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `zero` &middot; `one` &middot; `length` &middot; `Size-negative` (raises Size) &middot; `elements-are-separate` &middot; `every-element-is-init` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `unequal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `of-reals-same` &middot; `of-reals-not-equal` &middot; `of-functions-same` &middot; `in-a-list` &middot; `is-toplevel` &middot; `model-*` &middot; `identity-*` &middot; `long` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="type-vector"></a>`vector`

```sml
type 'a vector = 'a Vector.vector
```

<details><summary>Tests (10)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `empty` &middot; `equals-tabulate` &middot; `after-update` &middot; `is-a-snapshot` &middot; `is-Vector.vector` &middot; `structural-equality` &middot; `model-*` &middot; `fromList-*` &middot; `long`

</details>

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

<details><summary>Tests (1)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `covers-created-arrays`

</details>

### <a name="val-array"></a>`array`

```sml
val array : int * 'a -> 'a array
```

<details><summary>Tests (23)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `zero` &middot; `one` &middot; `length` &middot; `Size-negative` (raises Size) &middot; `elements-are-separate` &middot; `every-element-is-init` &middot; `same-array-is-equal` &middot; `alias-is-equal` &middot; `equal-after-update` &middot; `same-elements-not-equal` &middot; `unequal` &middot; `zero-length-same` &middot; `zero-length-not-equal` &middot; `of-reals-same` &middot; `of-reals-not-equal` &middot; `of-functions-same` &middot; `in-a-list` &middot; `is-toplevel` &middot; `model-*` &middot; `identity-*` &middot; `long` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : 'a list -> 'a array
```

<details><summary>Tests (9)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `nil` &middot; `singleton` &middot; `length` &middot; `strings` &middot; `same-elements-not-equal` &middot; `zero-length-not-equal` &middot; `round-trip-*` &middot; `long`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> 'a) -> 'a array
```

<details><summary>Tests (10)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `zero` &middot; `one` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f` &middot; `same-elements-not-equal` &middot; `zero-length-not-equal` &middot; `model-*` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-length"></a>`length`

```sml
val length : 'a array -> int
```

<details><summary>Tests (5)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `empty` &middot; `five` &middot; `tabulate` &middot; `model-*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : 'a array * int -> 'a
```

<details><summary>Tests (9)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `first` &middot; `middle` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

### <a name="val-update"></a>`update`

```sml
val update : 'a array * int * 'a -> unit
```

<details><summary>Tests (12)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `first` &middot; `middle` &middot; `last` &middot; `twice-same-index` &middot; `seen-by-sub` &middot; `seen-through-alias` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model-*` &middot; `model-*` (raises Subscript)

</details>

### <a name="val-vector"></a>`vector`

```sml
val vector : 'a array -> 'a vector
```

<details><summary>Tests (10)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `empty` &middot; `equals-tabulate` &middot; `after-update` &middot; `is-a-snapshot` &middot; `is-Vector.vector` &middot; `structural-equality` &middot; `model-*` &middot; `fromList-*` &middot; `long`

</details>

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : 'a array, dst : 'a array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `'a array` |  |
| <a name="fld-copy.dst"></a>`dst` | `'a array` |  |
| <a name="fld-copy.di"></a>`di` | `int` |  |

<details><summary>Tests (21)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `field-order` &middot; `src-unchanged` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `copies-elements-not-the-array` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `onto-itself` &middot; `Subscript-onto-itself-shifted` (raises Subscript) &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

### <a name="val-copyvec"></a>`copyVec`

```sml
val copyVec : {src : 'a vector, dst : 'a array, di : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copyvec.src"></a>`src` | `'a vector` |  |
| <a name="fld-copyvec.dst"></a>`dst` | `'a array` |  |
| <a name="fld-copyvec.di"></a>`di` | `int` |  |

<details><summary>Tests (19)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `start` &middot; `middle` &middot; `end` &middot; `whole` &middot; `field-order` &middot; `src-unchanged` &middot; `empty-src` &middot; `empty-src-at-length` &middot; `empty-to-empty` &middot; `from-Array.vector` &middot; `Subscript-too-far` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-src-longer` (raises Subscript) &middot; `Subscript-to-empty` (raises Subscript) &middot; `Subscript-empty-src-beyond` (raises Subscript) &middot; `Subscript-empty-src-negative` (raises Subscript) &middot; `Subscript-changes-nothing` &middot; `model-*` &middot; `model-*` (raises Subscript) &middot; `long`

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * 'a -> unit) -> 'a array -> unit
```

<details><summary>Tests (3)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `order` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a array -> unit
```

<details><summary>Tests (4)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `order` &middot; `empty` &middot; `array-unchanged` &middot; `model-*`

</details>

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : (int * 'a -> 'a) -> 'a array -> unit
```

<details><summary>Tests (6)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `index-and-element` &middot; `empty` &middot; `order` &middot; `model-*` &middot; `long`

</details>

### <a name="val-modify"></a>`modify`

```sml
val modify : ('a -> 'a) -> 'a array -> unit
```

<details><summary>Tests (7)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `basic` &middot; `empty` &middot; `order` &middot; `twice` &middot; `is-modifyi-of-second` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

<details><summary>Tests (4)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

<details><summary>Tests (4)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

<details><summary>Tests (6)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `array-unchanged` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
```

<details><summary>Tests (6)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model-*` &middot; `long` &middot; `long-list`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * 'a -> bool) -> 'a array -> (int * 'a) option
```

<details><summary>Tests (8)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a array -> 'a option
```

<details><summary>Tests (7)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `first-match` &middot; `last-element` &middot; `none` &middot; `empty` &middot; `stops` &middot; `model-*` &middot; `long`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a array -> bool
```

<details><summary>Tests (6)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a array -> bool
```

<details><summary>Tests (8)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `de-morgan-*` &middot; `long`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a array * 'a array -> order
```

<details><summary>Tests (14)</summary>

For `Array`, in [tests/basis/array.sml](../../../../tests/basis/array.sml): `equal` &middot; `same-array` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model-*` &middot; `reflexive-*` &middot; `long`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_array.sml; do not edit.</sub>
