<!-- A hand-written mock of what docgen is to generate for docs/generated/basis/sig/LIST.md.
     It belongs to docs/plans/docgen.md. Names of pages that do not exist yet are not linked here;
     links into lib/ and tests/ are real. -->

# signature LIST

[Basis Library](docgen.md) › Lists › **LIST**

| | |
|---|---|
| Status | required by the specification · all 27 entries implemented (25 values, 1 exception, 1 type) |
| Documentation | 27 of 27 entries documented |
| Tests | 99 checks in [tests/basis/list.sml](../../tests/basis/list.sml), 3 in [list_sig.sml](../../tests/basis/list_sig.sml) · 0 known deviations |
| Source | lib/basis/sig_list.sml |

## Synopsis

```sml
signature LIST
structure List : LIST
```

| Implementation | Ascription | Realisations | Source |
|---|---|---|---|
| `List` | matches `LIST` (checked) | `'a list` is the top-level `list` | [lib/basis/list.sml](../../lib/basis/list.sml) |

Polymorphic, immutable, singly linked lists. A list is either `nil` (written
`[]`) or an element consed onto a list with `::`; the notation `[a, b, c]`
abbreviates `a :: b :: c :: nil`. Everything that needs the *n*-th element or
the length walks the list from the front, so those operations take time
proportional to the position they reach. Positions are counted from 0.

Functions that take a function argument apply it to the elements from left to
right unless the entry says otherwise, which matters when the function has an
effect. Ten of the values below, the datatype and the exception `Empty` are
also available without qualification; they are marked *top level*.

Lists of pairs have their own signature, `LIST_PAIR`; for sequences with
constant-time indexing see `VECTOR` and `ARRAY`.

## Contents

[Types and exceptions](#types-and-exceptions) ·
[Taking lists apart](#taking-lists-apart) ·
[Building lists](#building-lists) ·
[Transforming](#transforming) ·
[Searching](#searching) ·
[Folding](#folding) ·
[Comparing](#comparing)

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
datatype 'a list = nil | :: of 'a * 'a list
```

The type of lists, the one of the top-level environment. It admits equality
when its element type does. *Top level.*

| Constructor | Argument | Description |
|---|---|---|
| <a name="con-nil"></a>`nil` | | The empty list, also written `[]`. |
| <a name="con-op-colon-colon"></a>`::` | `'a * 'a list` | `x :: l` is the list whose first element is `x` and whose other elements are those of `l`. Infix, right associative, precedence 5. |

> **Erratum** `LIST/list-spec`. The specification writes the datatype out in
> the signature. The Definition (Section 2.9) does not allow `nil` and `::`
> to be specified, so the signature replicates the top-level datatype instead;
> the meaning is the same.

<details><summary>Tests (1)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `List.list/constructors`

</details>

### <a name="exn-empty"></a>`Empty`

```sml
exception Empty
```

Raised by [`hd`](#val-hd), [`tl`](#val-tl) and [`last`](#val-last) when they
are given the empty list. It is the same exception as the top-level `Empty`.
*Top level.*

<details><summary>Tests (1)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `List.Empty/same-as-toplevel`

</details>

## Taking lists apart

### <a name="val-null"></a>`null`

```sml
val null : 'a list -> bool
```

`null l` is `true` exactly when `l` is empty. Unlike `l = []` it does not need
an equality type. *Top level.*

<details><summary>Tests (2)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `nil` · `cons`

</details>

### <a name="val-length"></a>`length`

```sml
val length : 'a list -> int
```

`length l` is the number of elements of `l`. *Top level.*

**Complexity** linear in the length; constant stack.

**Law** `length (l @ m) = length l + length m`

<details><summary>Tests (4)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `nil` · `five` ·
`long` · `append-*` (computed case, repeated)

</details>

### <a name="val-hd"></a>`hd`

```sml
val hd : 'a list -> 'a
```

`hd l` is the first element of `l`. *Top level.*

**Raises** [`Empty`](#exn-empty) if `l` is empty.

<details><summary>Tests (2)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `Empty` (raises)

</details>

### <a name="val-tl"></a>`tl`

```sml
val tl : 'a list -> 'a list
```

`tl l` is `l` without its first element. *Top level.*

**Raises** [`Empty`](#exn-empty) if `l` is empty.

<details><summary>Tests (3)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `singleton` ·
`Empty` (raises)

</details>

### <a name="val-last"></a>`last`

```sml
val last : 'a list -> 'a
```

`last l` is the final element of `l`.

**Raises** [`Empty`](#exn-empty) if `l` is empty.

**Complexity** linear in the length; constant stack.

<details><summary>Tests (4)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `singleton` ·
`Empty` (raises) · `long`

</details>

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : 'a list -> ('a * 'a list) option
```

`getItem l` is `NONE` for the empty list and `SOME (hd l, tl l)` otherwise.
It has the shape of a `StringCvt.reader`, so a list can be the stream that a
`scan` function reads from.

**Example**

```sml
Int.scan StringCvt.DEC List.getItem (explode "42 rest")
  = SOME (42, [#" ", #"r", #"e", #"s", #"t"])
```

<details><summary>Tests (2)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `cons` · `nil`

</details>

### <a name="val-nth"></a>`nth`

```sml
val nth : 'a list * int -> 'a
```

`nth (l, i)` is the element of `l` at position `i`, counting from 0.

**Raises** `Subscript` if `i < 0` or `i >= length l`.

**Complexity** linear in `i`.

<details><summary>Tests (5)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `first` · `last` ·
`Subscript-length` · `Subscript-negative` ·
`Subscript-nil` (raises)

</details>

### <a name="val-take"></a>`take`

```sml
val take : 'a list * int -> 'a list
```

`take (l, i)` is the list of the first `i` elements of `l`; `take (l, length l)`
is `l`.

**Raises** `Subscript` if `i < 0` or `i > length l`.

**Law** `take (l, i) @ drop (l, i) = l` for `0 <= i <= length l`

<details><summary>Tests (6)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `zero` · `some` ·
`all` · `Subscript-long` ·
`Subscript-negative` (raises) ·
`take-drop-*` (computed case, repeated)

</details>

### <a name="val-drop"></a>`drop`

```sml
val drop : 'a list * int -> 'a list
```

`drop (l, i)` is what is left of `l` after its first `i` elements; the result
shares its cells with `l`, so nothing is copied.

**Raises** `Subscript` if `i < 0` or `i > length l`.

<details><summary>Tests (5)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `zero` · `some` ·
`all` · `Subscript-long` ·
`Subscript-negative` (raises)

</details>

## Building lists

### <a name="val-op-at"></a>`@`

```sml
val @ : 'a list * 'a list -> 'a list
```

`l @ m` is the list of the elements of `l` followed by those of `m`. Infix,
right associative, precedence 5, the same as `::`, so `1 :: [2] @ [3]` needs
no parentheses. *Top level.*

**Complexity** linear in `length l`; `m` is shared, not copied. Appending to
the right in a loop is therefore quadratic: cons onto the front and reverse
at the end, or use [`revAppend`](#val-revappend).

<details><summary>Tests (6)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `nil-left` ·
`nil-right` · `infix` ·
`right-assoc` · `long`

</details>

### <a name="val-rev"></a>`rev`

```sml
val rev : 'a list -> 'a list
```

`rev l` is the list of the elements of `l` in the opposite order. *Top level.*

**Law** `rev (rev l) = l`

<details><summary>Tests (4)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `nil` ·
`long` · `involution-*` (computed case, repeated)

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : 'a list list -> 'a list
```

`concat ls` appends all the lists of `ls`, in order.

**Law** `concat [l, m, n] = l @ m @ n`

<details><summary>Tests (3)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `nil` ·
`append-*` (computed case, repeated)

</details>

### <a name="val-revappend"></a>`revAppend`

```sml
val revAppend : 'a list * 'a list -> 'a list
```

`revAppend (l, m)` is `rev l @ m`, built in one pass over `l` and without the
intermediate list. It is the usual way to finish a loop that accumulated its
results back to front.

**Law** `revAppend (l, m) = rev l @ m`

<details><summary>Tests (4)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `nil-left` ·
`nil-right` · `law-*` (computed case, repeated)

</details>

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> 'a) -> 'a list
```

`tabulate (n, f)` is `[f 0, f 1, ..., f (n - 1)]`. `f` is applied in order of
increasing argument.

**Raises** `Size` if `n < 0`, before `f` is applied at all.

**Law** `tabulate (length l, fn i => nth (l, i)) = l`

<details><summary>Tests (5)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `zero` ·
`order` · `Size` (raises) ·
`nth-*` (computed case, repeated)

</details>

## Transforming

### <a name="val-app"></a>`app`

```sml
val app : ('a -> unit) -> 'a list -> unit
```

`app f l` applies `f` to every element of `l`, from left to right, for its
effect. *Top level.*

<details><summary>Tests (1)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `order`

</details>

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a list -> 'b list
```

`map f l` is the list of the results of applying `f` to each element of `l`.
`f` is applied from left to right. *Top level.*

**Law** `map f (map g l) = map (f o g) l` when `f` and `g` have no effects

<details><summary>Tests (4)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `nil` ·
`order` · `long`

</details>

### <a name="val-mappartial"></a>`mapPartial`

```sml
val mapPartial : ('a -> 'b option) -> 'a list -> 'b list
```

`mapPartial f l` applies `f` to each element of `l`, from left to right, and
keeps the `v` of every result `SOME v`, in order; elements for which `f`
answers `NONE` leave nothing behind. It is a `map` and a `filter` in one pass.

**Law** `mapPartial f l = map valOf (filter isSome (map f l))`

<details><summary>Tests (3)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `order` ·
`map-filter-*` (computed case, repeated)

</details>

### <a name="val-filter"></a>`filter`

```sml
val filter : ('a -> bool) -> 'a list -> 'a list
```

`filter p l` is the list of the elements of `l` that satisfy `p`, in their
original order. `p` is applied to every element, from left to right.

<details><summary>Tests (3)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `order` ·
`long`

</details>

### <a name="val-partition"></a>`partition`

```sml
val partition : ('a -> bool) -> 'a list -> 'a list * 'a list
```

`partition p l` is the pair `(yes, no)` of the elements of `l` that satisfy
`p` and of those that do not, each in their original order. `p` is applied
once to every element, from left to right.

**Law** `partition p l = (filter p l, filter (not o p) l)` when `p` has no effects

<details><summary>Tests (3)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `basic` · `order` ·
`filter-*` (computed case, repeated)

</details>

## Searching

### <a name="val-find"></a>`find`

```sml
val find : ('a -> bool) -> 'a list -> 'a option
```

`find p l` is `SOME x` for the first element `x` of `l` that satisfies `p`,
and `NONE` if there is none. `p` is not applied to the elements after `x`.

<details><summary>Tests (3)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `first-match` · `none` ·
`stops`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a -> bool) -> 'a list -> bool
```

`exists p l` is `true` when some element of `l` satisfies `p`; it stops at the
first one that does. `exists p []` is `false`.

**Law** `exists p l = not (all (not o p) l)`

<details><summary>Tests (5)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `true` · `false` ·
`nil` · `stops` ·
`de-morgan-*` (computed case, repeated)

</details>

### <a name="val-all"></a>`all`

```sml
val all : ('a -> bool) -> 'a list -> bool
```

`all p l` is `true` when every element of `l` satisfies `p`; it stops at the
first one that does not. `all p []` is `true`.

<details><summary>Tests (4)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `true` · `false` ·
`nil` · `stops`

</details>

## Folding

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b
```

`foldl f init [x1, x2, ..., xn]` is `f (xn, ... f (x2, f (x1, init)) ...)`:
the elements are combined from the left, and the accumulator is the *second*
component of the argument of `f`. `foldl f init [] = init`. *Top level.*

**Example** `foldl (op ::) [] l = rev l`, and `foldl (op -) 0 [1, 2, 3] = 2`,
which is `3 - (2 - (1 - 0))`.

**Complexity** one application of `f` per element; constant stack.

<details><summary>Tests (5)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `conses-reversed` · `nonassociative` ·
`nil` · `long` ·
`rev-*` (computed case, repeated)

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b
```

`foldr f init [x1, x2, ..., xn]` is `f (x1, f (x2, ... f (xn, init) ...))`:
the elements are combined from the right. `foldr f init [] = init`.
*Top level.*

**Example** `foldr (op ::) [] l = l`, and `foldr (op -) 0 [1, 2, 3] = 2`,
which is `1 - (2 - (3 - 0))`.

<details><summary>Tests (4)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `conses-in-order` · `nonassociative` ·
`nil` · `long`

</details>

## Comparing

### <a name="val-collate"></a>`collate`

```sml
val collate : ('a * 'a -> order) -> 'a list * 'a list -> order
```

`collate cmp (l, m)` compares `l` and `m` lexicographically: the answer is
that of `cmp` on the first pair of elements at the same position that are not
`EQUAL`; if there is no such pair the shorter list is `LESS`, and lists of
the same length are `EQUAL`. `cmp` is not applied beyond the deciding pair.

**Example** `collate Int.compare ([1, 2], [1, 2, 0]) = LESS`

<details><summary>Tests (7)</summary>

In [tests/basis/list.sml](../../tests/basis/list.sml): `equal` · `nil-nil` ·
`prefix-less` · `prefix-greater` ·
`first-difference` · `less` ·
`reflexive-*` (computed case, repeated)

</details>

## See also

`LIST_PAIR` (lists of pairs) · `OPTION` · `VECTOR` · `STRING_CVT` (readers) ·
the top-level environment

---

<sub>Generated by docgen from lib/basis/sig_list.sml, lib/basis/list.sml and
tests/basis; do not edit.</sub>
