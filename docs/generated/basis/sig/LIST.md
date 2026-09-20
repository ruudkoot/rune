# signature LIST

[The Standard ML Basis Library](../README.md) &rsaquo; Lists and options &rsaquo; **LIST**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 27 of 27 entries documented |
| Tests | 99 checks of 27 entries |
| Source | [lib/basis/sig\_list.sml](../../../../lib/basis/sig_list.sml) |

## Synopsis

```sml
signature LIST
structure List : LIST
```

| Implementation |  | Source |
| --- | --- | --- |
| `List` | List | [lib/basis/list.sml](../../../../lib/basis/list.sml) |

Polymorphic, immutable, singly linked lists.

A list is either `nil` (written `[]`) or an element consed onto a list with
`::`; the notation `[a, b, c]` abbreviates `a :: b :: c :: nil`. Everything
that needs the n-th element or the length walks the list from the front, so
those operations take time proportional to the position they reach.
Positions are counted from 0.

Functions that take a function argument apply it to the elements from left
to right unless the entry says otherwise, which matters when the function
has an effect. The datatype, the exception [`Empty`](#exn-empty) and the values [`null`](#val-null),
[`length`](#val-length), [`@`](#val-op-at), [`hd`](#val-hd), [`tl`](#val-tl), [`rev`](#val-rev), [`app`](#val-app), [`map`](#val-map), [`foldl`](#val-foldl) and [`foldr`](#val-foldr) are
also in the top-level environment.

## Contents

[Types and exceptions](#types-and-exceptions) &middot;
[Taking lists apart](#taking-lists-apart) &middot;
[Building lists](#building-lists) &middot;
[Transforming](#transforming) &middot;
[Searching](#searching) &middot;
[Folding and testing the elements](#folding-and-testing-the-elements) &middot;
[Making and comparing](#making-and-comparing)

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

## Types and exceptions

### <a name="type-list"></a>`list`

```sml
datatype list = datatype list
```

The type of lists, the one of the top-level environment.

It admits equality when its element type does. The constructors are
`nil`, the empty list, and the infix `::` (right associative, precedence
5\), which puts an element in front of a list.

> **Erratum** `LIST/list-spec`. The specification writes the datatype out in
> the signature. The Definition (Section 2.9) does not allow `nil` and `::`
> to be specified, so the signature replicates the top-level datatype
> instead; the meaning is the same.

Also in the [top-level environment](../top-level.md): `list`.

<details><summary>Tests (1)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `constructors`

</details>

### <a name="exn-empty"></a>`Empty`

```sml
exception Empty
```

Raised by [`hd`](#val-hd), [`tl`](#val-tl) and [`last`](#val-last) when they are given the empty list. It is
the same exception as the top-level [`Empty`](#exn-empty).

Also in the [top-level environment](../top-level.md): `Empty`.

<details><summary>Tests (1)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `same-as-toplevel` (raises)

</details>

## Taking lists apart

### <a name="val-null"></a>`null`

```sml
val null : 'a list -> bool
```

`null l` is `true` exactly when `l` is empty.

Unlike `l = []` it does not need an equality type.

Also in the [top-level environment](../top-level.md): `null`.

<details><summary>Tests (2)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `nil` &middot; `cons`

</details>

### <a name="val-length"></a>`length`

```sml
val length : 'a list -> int
```

`length l` is the number of elements of `l`.

**Law** `length (l @ m) = length l + length m`

**Complexity** linear in the length; constant stack.

Also in the [top-level environment](../top-level.md): `length`.

<details><summary>Tests (4)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `nil` &middot; `five` &middot; `append-*` &middot; `long`

</details>

### <a name="val-op-at"></a>`@`

```sml
val @ : 'a list * 'a list -> 'a list
```

`l @ m` is the list of the elements of `l` followed by those of `m`.

It is infix and right associative with precedence 5, the same as `::`, so
`1 :: [2] @ [3]` needs no parentheses.

**Complexity** linear in `length l`; `m` is shared, not copied. Appending to
the right in a loop is therefore quadratic: cons onto the front and
reverse at the end, or use [`revAppend`](#val-revappend).

Also in the [top-level environment](../top-level.md): `@`.

<details><summary>Tests (6)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `nil-left` &middot; `nil-right` &middot; `infix` &middot; `right-assoc` &middot; `long`

</details>

### <a name="val-hd"></a>`hd`

```sml
val hd : 'a list -> 'a
```

`hd l` is the first element of `l`.

**Raises** [`Empty`](#exn-empty) if `l` is empty.

Also in the [top-level environment](../top-level.md): `hd`.

<details><summary>Tests (2)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `Empty` (raises Empty)

</details>

### <a name="val-tl"></a>`tl`

```sml
val tl : 'a list -> 'a list
```

`tl l` is `l` without its first element.

**Raises** [`Empty`](#exn-empty) if `l` is empty.

Also in the [top-level environment](../top-level.md): `tl`.

<details><summary>Tests (3)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `singleton` &middot; `Empty` (raises Empty)

</details>

### <a name="val-last"></a>`last`

```sml
val last : 'a list -> 'a
```

`last l` is the final element of `l`.

**Raises** [`Empty`](#exn-empty) if `l` is empty.

**Complexity** linear in the length; constant stack.

<details><summary>Tests (4)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `singleton` &middot; `Empty` (raises Empty) &middot; `long`

</details>

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : 'a list -> ('a * 'a list) option
```

`getItem l` is `NONE` for the empty list and `SOME (hd l, tl l)`
otherwise.

It has the shape of a [`StringCvt.reader`](../sig/STRING_CVT.md#type-reader), so a list can be the stream
that a `scan` function reads from.

**Example** `Int.scan StringCvt.DEC List.getItem (explode "42 rest")` is
`SOME (42, [#" ", #"r", #"e", #"s", #"t"])`.

<details><summary>Tests (2)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `cons` &middot; `nil`

</details>

### <a name="val-nth"></a>`nth`

```sml
val nth : 'a list * int -> 'a
```

`nth (l, i)` is the element of `l` at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= length l`.

**Complexity** linear in `i`.

<details><summary>Tests (5)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `first` &middot; `last` &middot; `Subscript-length` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-nil` (raises Subscript)

</details>

### <a name="val-take"></a>`take`

```sml
val take : 'a list * int -> 'a list
```

`take (l, i)` is the list of the first `i` elements of `l`; `take (l, length l)` is `l`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i > length l`.

**Law** `take (l, i) @ drop (l, i) = l` for `0 <= i <= length l`

<details><summary>Tests (6)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `zero` &middot; `some` &middot; `all` &middot; `Subscript-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `take-drop-*`

</details>

### <a name="val-drop"></a>`drop`

```sml
val drop : 'a list * int -> 'a list
```

`drop (l, i)` is what is left of `l` after its first `i` elements.

The result shares its cells with `l`: nothing is copied.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i > length l`.

<details><summary>Tests (5)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `zero` &middot; `some` &middot; `all` &middot; `Subscript-long` (raises Subscript) &middot; `Subscript-negative` (raises Subscript)

</details>

## Building lists

### <a name="val-rev"></a>`rev`

```sml
val rev : 'a list -> 'a list
```

`rev l` is the list of the elements of `l` in the opposite order.

**Law** `rev (rev l) = l`

Also in the [top-level environment](../top-level.md): `rev`.

<details><summary>Tests (4)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `nil` &middot; `involution-*` &middot; `long`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : 'a list list -> 'a list
```

`concat ls` appends all the lists of `ls`, in order.

**Law** `concat [l, m, n] = l @ m @ n`

<details><summary>Tests (3)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `nil` &middot; `append-*`

</details>

### <a name="val-revappend"></a>`revAppend`

```sml
val revAppend : 'a list * 'a list -> 'a list
```

`revAppend (l, m)` is `rev l @ m`, built in one pass over `l` and without
the intermediate list.

It is the usual way to finish a loop that accumulated its results back to
front.

**Law** `revAppend (l, m) = rev l @ m`

<details><summary>Tests (4)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `nil-left` &middot; `nil-right` &middot; `law-*`

</details>

## Transforming

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a list -> unit
```

`app f l` applies `f` to every element of `l`, from left to right, for its
effect.

Also in the [top-level environment](../top-level.md): `app`.

<details><summary>Tests (1)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `order`

</details>

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a list -> 'b list
```

`map f l` is the list of the results of applying `f` to each element of
`l`, from left to right.

**Law** `map f (map g l) = map (f o g) l` when `f` and `g` have no effects

Also in the [top-level environment](../top-level.md): `map`.

<details><summary>Tests (4)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `nil` &middot; `order` &middot; `long`

</details>

### <a name="val-mappartial"></a>`mapPartial`

```sml
val mapPartial : ('a -> 'b option) -> 'a list -> 'b list
```

`mapPartial f l` applies `f` to each element of `l` and keeps the `v` of
every result `SOME v`, in order.

Elements for which `f` answers `NONE` leave nothing behind: it is a [`map`](#val-map)
and a [`filter`](#val-filter) in one pass.

**Law** `mapPartial f l = map valOf (filter isSome (map f l))`

<details><summary>Tests (3)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `order` &middot; `map-filter-*`

</details>

## Searching

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a list -> 'a option
```

`find p l` is `SOME x` for the first element `x` of `l` that satisfies
`p`, and `NONE` if there is none.

`p` is not applied to the elements after `x`.

<details><summary>Tests (3)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `first-match` &middot; `none` &middot; `stops`

</details>

### <a name="val-filter"></a>`filter`

```sml
val filter : ('a -> bool) -> 'a list -> 'a list
```

`filter p l` is the list of the elements of `l` that satisfy `p`, in their
original order.

`p` is applied to every element, from left to right.

<details><summary>Tests (3)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `order` &middot; `long`

</details>

### <a name="val-partition"></a>`partition`

```sml
val partition : ('a -> bool) -> 'a list -> 'a list * 'a list
```

`partition p l` is the pair of the elements of `l` that satisfy `p` and of
those that do not.

Both lists keep the original order, and `p` is applied once to every
element, from left to right.

**Law** `partition p l = (filter p l, filter (not o p) l)` when `p` has no
effects

<details><summary>Tests (3)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `order` &middot; `filter-*`

</details>

## Folding and testing the elements

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b
```

`foldl f init l` combines the elements of `l` from the left: `f (xn, ... f (x2, f (x1, init)) ...)`.

The accumulator is the second component of the argument of `f`, and
`foldl f init [] = init`.

**Law** `foldl (op ::) [] l = rev l`

**Example** `foldl (op -) 0 [1, 2, 3] = 2`, which is `3 - (2 - (1 - 0))`.

**Complexity** one application of `f` per element; constant stack.

Also in the [top-level environment](../top-level.md): `foldl`.

<details><summary>Tests (5)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `conses-reversed` &middot; `nonassociative` &middot; `nil` &middot; `rev-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b
```

`foldr f init l` combines the elements of `l` from the right: `f (x1, f (x2, ... f (xn, init) ...))`.

`foldr f init [] = init`.

**Law** `foldr (op ::) [] l = l`

**Example** `foldr (op -) 0 [1, 2, 3] = 2`, which is `1 - (2 - (3 - 0))`.

Also in the [top-level environment](../top-level.md): `foldr`.

<details><summary>Tests (4)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `conses-in-order` &middot; `nonassociative` &middot; `nil` &middot; `long`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a list -> bool
```

`exists p l` is `true` when some element of `l` satisfies `p`; it stops at
the first one that does.

`exists p []` is `false`.

**Law** `exists p l = not (all (not o p) l)`

<details><summary>Tests (5)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `true` &middot; `false` &middot; `nil` &middot; `stops` &middot; `de-morgan-*`

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a list -> bool
```

`all p l` is `true` when every element of `l` satisfies `p`; it stops at
the first one that does not.

`all p []` is `true`.

<details><summary>Tests (4)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `true` &middot; `false` &middot; `nil` &middot; `stops`

</details>

## Making and comparing

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> 'a) -> 'a list
```

`tabulate (n, f)` is `[f 0, f 1, ..., f (n - 1)]`; `f` is applied in order
of increasing argument.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0`, before `f` is applied at all.

**Law** `tabulate (length l, fn i => nth (l, i)) = l`

<details><summary>Tests (5)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `basic` &middot; `zero` &middot; `order` &middot; `Size` (raises Size) &middot; `nth-*`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a list * 'a list -> order
```

`collate cmp (l, m)` compares `l` and `m` lexicographically, with `cmp`
for the elements.

The answer is that of `cmp` on the first pair of elements at the same
position that are not `EQUAL`; if there is no such pair the shorter list
is `LESS`, and lists of the same length are `EQUAL`. `cmp` is not applied
beyond the deciding pair.

**Example** `collate Int.compare ([1, 2], [1, 2, 0]) = LESS`

<details><summary>Tests (7)</summary>

For `List`, in [tests/basis/list.sml](../../../../tests/basis/list.sml): `equal` &middot; `nil-nil` &middot; `prefix-less` &middot; `prefix-greater` &middot; `first-difference` &middot; `less` &middot; `reflexive-*`

</details>

## See also

[`LIST_PAIR`](../sig/LIST_PAIR.md), [`OPTION`](../sig/OPTION.md), [`VECTOR`](../sig/VECTOR.md), [`ARRAY`](../sig/ARRAY.md), [`STRING_CVT`](../sig/STRING_CVT.md)

---

<sub>Generated by runedoc from lib/basis/sig\_list.sml; do not edit.</sub>
