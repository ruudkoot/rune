# signature MONO_VECTOR_EQ

[The Standard ML Basis Library](../README.md) &rsaquo; Sequences &rsaquo; **MONO_VECTOR_EQ**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 22 of 22 entries documented |
| Tests | 131 checks of 21 entries |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_VECTOR_EQ
structure WideCharVector :> MONO_VECTOR_EQ where type elem = RuneWideChar.char  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`WideCharVector`](../str/WideCharVector.md) | Sealed with a vector of its own (MONO\_VECTOR\_EQ), so that WideString.string is a type name: the constants of a type are overloaded at a name. | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |

The same as [`MONO_VECTOR`](../sig/MONO_VECTOR.md), with a vector type that admits equality.

> **Deviation** `MONO_VECTOR_EQ/not-in-the-specification`. This signature is
> not in the specification, and it is here because the specification asks
> for something it gives no way to say: [`WideCharVector.vector`](../sig/MONO_VECTOR.md#type-vector) has to admit
> equality, and the declaration the page gives [`WideCharVector`](../str/WideCharVector.md) cannot make
> it -- see the erratum `MONO_VECTOR/WideCharVector-must-admit-equality`.
> [`MONO_VECTOR`](../sig/MONO_VECTOR.md) writes `type vector`, not `eqtype`, so that a family whose
> elements do not admit equality can have a vector; a family whose vector is
> a type of its own and does admit it is sealed with this instead. The
> specification's own way out is `where type vector = WideString.string` on
> the instance, which Rune cannot use because [`WideString`](../str/WideString.md) is declared after
> [`WideCharVector`](../str/WideCharVector.md) and is built on it -- [`WideString.string`](../sig/STRING.md#type-string) must be a type
> name of its own for wide string constants to be overloaded at it.

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

The type of these vectors, which admits equality.

### <a name="type-elem"></a>`elem`

```sml
type elem
```

The type of the elements: [`WideChar.char`](../sig/CHAR.md#type-char) for [`WideCharVector`](../str/WideCharVector.md).

<details><summary>Tests (1)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `eight-distinct-samples`

</details>

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

The greatest length such a vector may have.

> **Implementation** `MONO_VECTOR_EQ.maxLen/value`. [`String.maxSize`](../sig/STRING.md#val-maxsize), the
> bound of the families of [`MONO_VECTOR`](../sig/MONO_VECTOR.md) whose vector is a string.

<details><summary>Tests (1)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `covers-created-vectors`

</details>

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : elem list -> vector
```

`fromList l` is the sequence of the elements of `l`, in order.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `l` is longer than [`maxLen`](#val-maxlen).

<details><summary>Tests (7)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `nil` &middot; `singleton` &middot; `every-sample` &middot; `length` &middot; `round-trip*` &middot; `long`

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> elem) -> vector
```

`tabulate (n, f)` is the sequence of `f 0`, ..., `f (n - 1)`, applied in order.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0` or `n > maxLen`, before `f` is applied.

<details><summary>Tests (8)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `zero` &middot; `one` &middot; `order` &middot; `Size-negative` (raises Size) &middot; `Size-before-f` &middot; `model*` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-length"></a>`length`

```sml
val length : vector -> int
```

`length x` is the number of elements.

<details><summary>Tests (5)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `empty` &middot; `five` &middot; `tabulate` &middot; `model*` &middot; `long`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : vector * int -> elem
```

`sub (x, i)` is the element at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is outside.

<details><summary>Tests (9)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `first` &middot; `middle` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-update"></a>`update`

```sml
val update : vector * int * elem -> vector
```

`update (v, i, x)` is a new vector like `v` but with `x` at position `i`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i` is outside `v`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; Vector.update, Word8Vector.update and CharVector.update return the vector unchanged instead of raising Subscript when the index is out of range

</details>

<details><summary>Tests (12)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `first` &middot; `middle` &middot; `last` &middot; `singleton` &middot; `argument-unchanged` &middot; `twice` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-beyond` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `model*` &middot; `model*` (raises Subscript) &middot; `long`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : vector list -> vector
```

`concat l` is the vectors of `l` one after another.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`maxLen`](#val-maxlen).

<details><summary>Tests (10)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `nil` &middot; `one` &middot; `empties` &middot; `same-twice` &middot; `order` &middot; `model*` &middot; `long` &middot; `many` &middot; `Size-above-maxLen` (raises Size)

</details>

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> vector -> unit
```

`appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

<details><summary>Tests (3)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> vector -> unit
```

`app f x` applies `f` to every element, from 0 up, for its effect.

<details><summary>Tests (3)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `order` &middot; `empty` &middot; `model*`

</details>

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * elem -> elem) -> vector -> vector
```

`mapi f v` is the vector of the results of `f` on the index and the element of each position.

<details><summary>Tests (6)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `index-only` &middot; `empty` &middot; `order` &middot; `model*` &middot; `long`

</details>

### <a name="val-map"></a>`map`

```sml
val map : (elem -> elem) -> vector -> vector
```

`map f v` is the vector of the results of `f` on each element, in order.

<details><summary>Tests (7)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `basic` &middot; `wraps` &middot; `empty` &middot; `order` &middot; `argument-unchanged` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'b -> 'b) -> 'b -> vector -> 'b
```

`foldli f init x` combines the elements from the left, giving `f` the index as well.

<details><summary>Tests (4)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'b -> 'b) -> 'b -> vector -> 'b
```

`foldri f init x` combines the elements from the right, giving `f` the index as well.

<details><summary>Tests (4)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'b -> 'b) -> 'b -> vector -> 'b
```

`foldl f init x` combines the elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

<details><summary>Tests (5)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `conses-reversed` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'b -> 'b) -> 'b -> vector -> 'b
```

`foldr f init x` combines the elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

<details><summary>Tests (5)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `conses-in-order` &middot; `nonassociative` &middot; `empty` &middot; `model*` &middot; `long`

</details>

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> vector -> (int * elem) option
```

`findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

<details><summary>Tests (8)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `first-match` &middot; `by-index` &middot; `index-zero` &middot; `none` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> vector -> elem option
```

`find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

<details><summary>Tests (6)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `first-match` &middot; `last-element` &middot; `none` &middot; `empty` &middot; `stops` &middot; `model*`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> vector -> bool
```

`exists p x` is `true` when some element satisfies `p`.

<details><summary>Tests (6)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> vector -> bool
```

`all p x` is `true` when every element satisfies `p`.

<details><summary>Tests (8)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `true` &middot; `false` &middot; `empty` &middot; `stops` &middot; `order` &middot; `model*` &middot; `de-morgan*` &middot; `long`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> vector * vector -> order
```

`collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

<details><summary>Tests (13)</summary>

In [tests/basis/fn/mono\_vector\_fn.sml](../../../../tests/basis/fn/mono_vector_fn.sml), applied to `WideCharVector`: `equal` &middot; `empty-empty` &middot; `empty-less` &middot; `empty-greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `not-by-length` &middot; `given-ordering` &middot; `argument-order` &middot; `model*` &middot; `reflexive*` &middot; `long`

</details>

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
