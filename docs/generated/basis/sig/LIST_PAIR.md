# signature LIST_PAIR

[The Standard ML Basis Library](../README.md) &rsaquo; Lists and options &rsaquo; **LIST_PAIR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 15 of 15 entries documented |
| Tests | 140 checks of 15 entries |
| Source | [lib/basis/sig\_list\_pair.sml](../../../../lib/basis/sig_list_pair.sml) |

## Synopsis

```sml
signature LIST_PAIR
structure ListPair : LIST_PAIR
```

| Implementation |  | Source |
| --- | --- | --- |
| `ListPair` | ListPair | [lib/basis/listpair.sml](../../../../lib/basis/listpair.sml) |

Two lists walked side by side: pairing, and the traversals that take a
function of an element of each.

Every function comes in two forms. The plain one stops at the end of the
shorter list and ignores the rest of the longer, so `zip ([1, 2, 3], [#"a"])` is `[(1, #"a")]`. The one whose name ends in `Eq` insists that
the lists have the same length and raises [`UnequalLengths`](#exn-unequallengths) when they do
not, so that a program can say which it means.

## Contents

[Pairing](#pairing) &middot;
[Traversing](#traversing) &middot;
[Folding](#folding) &middot;
[Testing the pairs](#testing-the-pairs)

## Interface

<pre>
signature LIST_PAIR =
sig
  exception <a href="#exn-unequallengths">UnequalLengths</a>

  val <a href="#val-zip">zip</a> : 'a list * 'b list -&gt; ('a * 'b) list

  val <a href="#val-zipeq">zipEq</a> : 'a list * 'b list -&gt; ('a * 'b) list

  val <a href="#val-unzip">unzip</a> : ('a * 'b) list -&gt; 'a list * 'b list

  val <a href="#val-app">app</a> : ('a * 'b -&gt; unit) -&gt; 'a list * 'b list -&gt; unit

  val <a href="#val-appeq">appEq</a> : ('a * 'b -&gt; unit) -&gt; 'a list * 'b list -&gt; unit

  val <a href="#val-map">map</a> : ('a * 'b -&gt; 'c) -&gt; 'a list * 'b list -&gt; 'c list

  val <a href="#val-mapeq">mapEq</a> : ('a * 'b -&gt; 'c) -&gt; 'a list * 'b list -&gt; 'c list

  val <a href="#val-foldl">foldl</a> : ('a * 'b * 'c -&gt; 'c) -&gt; 'c -&gt; 'a list * 'b list -&gt; 'c

  val <a href="#val-foldr">foldr</a> : ('a * 'b * 'c -&gt; 'c) -&gt; 'c -&gt; 'a list * 'b list -&gt; 'c

  val <a href="#val-foldleq">foldlEq</a> : ('a * 'b * 'c -&gt; 'c) -&gt; 'c -&gt; 'a list * 'b list -&gt; 'c

  val <a href="#val-foldreq">foldrEq</a> : ('a * 'b * 'c -&gt; 'c) -&gt; 'c -&gt; 'a list * 'b list -&gt; 'c

  val <a href="#val-all">all</a> : ('a * 'b -&gt; bool) -&gt; 'a list * 'b list -&gt; bool

  val <a href="#val-exists">exists</a> : ('a * 'b -&gt; bool) -&gt; 'a list * 'b list -&gt; bool

  val <a href="#val-alleq">allEq</a> : ('a * 'b -&gt; bool) -&gt; 'a list * 'b list -&gt; bool
end
</pre>

### <a name="exn-unequallengths"></a>`UnequalLengths`

```sml
exception UnequalLengths
```

Raised by the `Eq` functions when the two lists have different lengths.

<details><summary>Tests (3)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `raised-by-zipEq` (raises) &middot; `can-be-raised-and-handled` &middot; `differs-from-Subscript-and-Size`

</details>

## Pairing

### <a name="val-zip"></a>`zip`

```sml
val zip : 'a list * 'b list -> ('a * 'b) list
```

`zip (l, m)` is the list of the pairs of the elements of `l` and `m` at the same position.

It stops at the end of the shorter list.

**Law** `List.length (zip (l, m)) = Int.min (List.length l, List.length m)`

<details><summary>Tests (10)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `basic` &middot; `nil-nil` &middot; `singleton` &middot; `left-longer` &middot; `right-longer` &middot; `nil-left` &middot; `nil-right` &middot; `two-types` &middot; `model-*` &middot; `long`

</details>

### <a name="val-zipeq"></a>`zipEq`

```sml
val zipEq : 'a list * 'b list -> ('a * 'b) list
```

`zipEq (l, m)` is `zip (l, m)`, and insists that the lists are as long as each other.

**Raises** [`UnequalLengths`](#exn-unequallengths) if `l` and `m` have different lengths.

<details><summary>Tests (10)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `basic` &middot; `nil-nil` &middot; `singleton` &middot; `UnequalLengths-left-longer` (raises) &middot; `UnequalLengths-right-longer` (raises) &middot; `UnequalLengths-nil-left` (raises) &middot; `UnequalLengths-nil-right` (raises) &middot; `model-*` &middot; `long` &middot; `long-UnequalLengths` (raises)

</details>

### <a name="val-unzip"></a>`unzip`

```sml
val unzip : ('a * 'b) list -> 'a list * 'b list
```

`unzip l` is the pair of the lists of the first and of the second components of the pairs of `l`.

**Law** `unzip (zip (l, m)) = (l, m)` when `l` and `m` are as long as each other

<details><summary>Tests (9)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `basic` &middot; `nil` &middot; `singleton` &middot; `two-types` &middot; `inverse-of-zip` &middot; `zip-is-its-inverse` &middot; `zip-*` &middot; `inverse-*` &middot; `long`

</details>

## Traversing

### <a name="val-app"></a>`app`

```sml
val app : ('a * 'b -> unit) -> 'a list * 'b list -> unit
```

`app f (l, m)` applies `f` to the pairs of elements at the same position, from left to right, for its effect.

**Law** `app f (l, m) = List.app f (zip (l, m))`

<details><summary>Tests (7)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `order` &middot; `nil-nil` &middot; `left-longer` &middot; `right-longer` &middot; `nil-right` &middot; `model-*` &middot; `long`

</details>

### <a name="val-appeq"></a>`appEq`

```sml
val appEq : ('a * 'b -> unit) -> 'a list * 'b list -> unit
```

`appEq f (l, m)` is `app f (l, m)`, and insists that the lists are as long as each other.

`f` is applied to the pairs up to the end of the shorter list before the
exception is raised.

**Raises** [`UnequalLengths`](#exn-unequallengths) if `l` and `m` have different lengths.

<details><summary>Tests (8)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `order` &middot; `nil-nil` &middot; `UnequalLengths-left-longer` (raises) &middot; `UnequalLengths-right-longer` (raises) &middot; `UnequalLengths-nil-left` (raises) &middot; `applies-before-raising` &middot; `model-*` &middot; `long`

</details>

### <a name="val-map"></a>`map`

```sml
val map : ('a * 'b -> 'c) -> 'a list * 'b list -> 'c list
```

`map f (l, m)` is the list of the results of `f` on the pairs of elements at the same position.

**Law** `map f (l, m) = List.map f (zip (l, m))`

<details><summary>Tests (10)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `basic` &middot; `argument-order` &middot; `nil-nil` &middot; `left-longer` &middot; `right-longer` &middot; `nil-left` &middot; `order` &middot; `three-types` &middot; `model-*` &middot; `long`

</details>

### <a name="val-mapeq"></a>`mapEq`

```sml
val mapEq : ('a * 'b -> 'c) -> 'a list * 'b list -> 'c list
```

`mapEq f (l, m)` is `map f (l, m)`, and insists that the lists are as long as each other.

**Raises** [`UnequalLengths`](#exn-unequallengths) if `l` and `m` have different lengths.

<details><summary>Tests (9)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `basic` &middot; `nil-nil` &middot; `order` &middot; `UnequalLengths-left-longer` (raises) &middot; `UnequalLengths-right-longer` (raises) &middot; `UnequalLengths-nil-right` (raises) &middot; `applies-before-raising` &middot; `model-*` &middot; `long`

</details>

## Folding

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : ('a * 'b * 'c -> 'c) -> 'c -> 'a list * 'b list -> 'c
```

`foldl f init (l, m)` combines the pairs of elements from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

`f` takes the two elements and the accumulator, and the traversal stops
at the end of the shorter list.

**Law** `foldl f init (l, m) = List.foldl (fn ((x, y), acc) => f (x, y, acc)) init (zip (l, m))`

<details><summary>Tests (9)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `conses-reversed` &middot; `nonassociative` &middot; `nil-nil` &middot; `left-longer` &middot; `right-longer` &middot; `nil-right` &middot; `order` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : ('a * 'b * 'c -> 'c) -> 'c -> 'a list * 'b list -> 'c
```

`foldr f init (l, m)` combines the pairs of elements from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

<details><summary>Tests (10)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `conses-in-order` &middot; `nonassociative` &middot; `nil-nil` &middot; `left-longer` &middot; `right-longer` &middot; `nil-left` &middot; `order` &middot; `order-left-longer` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldleq"></a>`foldlEq`

```sml
val foldlEq : ('a * 'b * 'c -> 'c) -> 'c -> 'a list * 'b list -> 'c
```

`foldlEq f init (l, m)` is `foldl f init (l, m)`, and insists that the lists are as long as each other.

`f` is applied to the pairs up to the end of the shorter list before the
exception is raised.

**Raises** [`UnequalLengths`](#exn-unequallengths) if `l` and `m` have different lengths.

<details><summary>Tests (10)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `conses-reversed` &middot; `nonassociative` &middot; `nil-nil` &middot; `order` &middot; `UnequalLengths-left-longer` (raises) &middot; `UnequalLengths-right-longer` (raises) &middot; `UnequalLengths-nil-left` (raises) &middot; `applies-before-raising` &middot; `model-*` &middot; `long`

</details>

### <a name="val-foldreq"></a>`foldrEq`

```sml
val foldrEq : ('a * 'b * 'c -> 'c) -> 'c -> 'a list * 'b list -> 'c
```

`foldrEq f init (l, m)` is `foldr f init (l, m)`, and insists that the lists are as long as each other.

**Raises** [`UnequalLengths`](#exn-unequallengths) if `l` and `m` have different lengths.

> **Reading** `ListPair.foldrEq/raises-before-applying`. Folding from the
> right needs the last pair first, so the ends of both lists are reached
> before anything is combined: `f` is not applied at all when the lengths
> differ.

<details><summary>Tests (10)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `conses-in-order` &middot; `nonassociative` &middot; `nil-nil` &middot; `order` &middot; `UnequalLengths-left-longer` (raises) &middot; `UnequalLengths-right-longer` (raises) &middot; `UnequalLengths-nil-right` (raises) &middot; `raises-before-applying` &middot; `model-*` &middot; `long`

</details>

## Testing the pairs

### <a name="val-all"></a>`all`

```sml
val all : ('a * 'b -> bool) -> 'a list * 'b list -> bool
```

`all p (l, m)` is `true` when every pair of elements at the same position satisfies `p`.

It stops at the first pair that does not, and at the end of the shorter
list, so `all p (l, [])` is `true`.

<details><summary>Tests (9)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `true` &middot; `false` &middot; `nil-nil` &middot; `nil-right` &middot; `excess-ignored` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `long`

</details>

### <a name="val-exists"></a>`exists`

```sml
val exists : ('a * 'b -> bool) -> 'a list * 'b list -> bool
```

`exists p (l, m)` is `true` when some pair of elements at the same position satisfies `p`.

It stops at the first pair that does, and at the end of the shorter list.

<details><summary>Tests (10)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `true` &middot; `false` &middot; `nil-nil` &middot; `nil-left` &middot; `excess-ignored` &middot; `stops` &middot; `order` &middot; `model-*` &middot; `de-morgan-*` &middot; `long`

</details>

### <a name="val-alleq"></a>`allEq`

```sml
val allEq : ('a * 'b -> bool) -> 'a list * 'b list -> bool
```

`allEq p (l, m)` is `true` when the lists are as long as each other and every pair satisfies `p`.

> **Reading** `ListPair.allEq/left-longer`. It answers `false` for lists of
> different lengths rather than raising [`UnequalLengths`](#exn-unequallengths): it is the one
> `Eq` function that does not raise.

> **Reading** `ListPair.allEq/applies-before-lengths-are-known`. The
> specification gives both an equivalent expression, which would apply `p`
> to nothing when the lengths differ, and an implementation note, which
> walks the lists together and stops at the first pair that fails. The
> note is what is implemented, and all three other systems do the same: `p`
> is applied to the pairs of the common prefix before the lengths are
> known.

<details><summary>Tests (16)</summary>

For `ListPair`, in [tests/basis/listpair.sml](../../../../tests/basis/listpair.sml): `true` &middot; `false` &middot; `nil-nil` &middot; `left-longer` &middot; `right-longer` &middot; `nil-left` &middot; `nil-right` &middot; `list-equality` &middot; `list-inequality` &middot; `stops` &middot; `order` &middot; `applies-before-lengths-are-known` &middot; `model-*` &middot; `list-equality-*` &middot; `long` &middot; `long-unequal`

</details>

## See also

[`LIST`](../sig/LIST.md), [`OPTION`](../sig/OPTION.md)

---

<sub>Generated by runedoc from lib/basis/sig\_list\_pair.sml; do not edit.</sub>
