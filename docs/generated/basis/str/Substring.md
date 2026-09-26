# structure Substring

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; [Structures](../structures.md) &rsaquo; **Substring**

|  |  |
| --- | --- |
| Signature | [`SUBSTRING`](../sig/SUBSTRING.md) |
| Status | required |
| Members | 39 |
| Tests | 256 checks |
| Source | [lib/basis/substring.sml](../../../../lib/basis/substring.sml) |

## Synopsis

```sml
structure Substring : SUBSTRING where type string = string where type char = Char.char
```

Substring: a string, a start index and a length.

## Members

What each means is on [`SUBSTRING`](../sig/SUBSTRING.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`char`](../sig/SUBSTRING.md#type-char) | *a type of its own* |
| type | [`string`](../sig/SUBSTRING.md#val-string) | *a type of its own* |
| type | [`substring`](../sig/SUBSTRING.md#val-substring) | *a type of its own* |
| val | [`app`](../sig/SUBSTRING.md#val-app) | `(char -> unit) -> substring -> unit` |
| val | [`base`](../sig/SUBSTRING.md#val-base) | `substring -> string * int * int` |
| val | [`collate`](../sig/SUBSTRING.md#val-collate) | `(char * char -> order) -> substring * substring -> order` |
| val | [`compare`](../sig/SUBSTRING.md#val-compare) | `substring * substring -> order` |
| val | [`concat`](../sig/SUBSTRING.md#val-concat) | `substring list -> string` |
| val | [`concatWith`](../sig/SUBSTRING.md#val-concatwith) | `string -> substring list -> string` |
| val | [`dropl`](../sig/SUBSTRING.md#val-dropl) | `(char -> bool) -> substring -> substring` |
| val | [`dropr`](../sig/SUBSTRING.md#val-dropr) | `(char -> bool) -> substring -> substring` |
| val | [`explode`](../sig/SUBSTRING.md#val-explode) | `substring -> char list` |
| val | [`extract`](../sig/SUBSTRING.md#val-extract) | `string * int * int option -> substring` |
| val | [`fields`](../sig/SUBSTRING.md#val-fields) | `(char -> bool) -> substring -> substring list` |
| val | [`first`](../sig/SUBSTRING.md#val-first) | `substring -> char option` |
| val | [`foldl`](../sig/SUBSTRING.md#val-foldl) | `(char * 'a -> 'a) -> 'a -> substring -> 'a` |
| val | [`foldr`](../sig/SUBSTRING.md#val-foldr) | `(char * 'b -> 'b) -> 'b -> substring -> 'b` |
| val | [`full`](../sig/SUBSTRING.md#val-full) | `string -> substring` |
| val | [`getc`](../sig/SUBSTRING.md#val-getc) | `substring -> (char * substring) option` |
| val | [`isEmpty`](../sig/SUBSTRING.md#val-isempty) | `substring -> bool` |
| val | [`isPrefix`](../sig/SUBSTRING.md#val-isprefix) | `string -> substring -> bool` |
| val | [`isSubstring`](../sig/SUBSTRING.md#val-issubstring) | `string -> substring -> bool` |
| val | [`isSuffix`](../sig/SUBSTRING.md#val-issuffix) | `string -> substring -> bool` |
| val | [`position`](../sig/SUBSTRING.md#val-position) | `string -> substring -> substring * substring` |
| val | [`size`](../sig/SUBSTRING.md#val-size) | `substring -> int` |
| val | [`slice`](../sig/SUBSTRING.md#val-slice) | `substring * int * int option -> substring` |
| val | [`span`](../sig/SUBSTRING.md#val-span) | `substring * substring -> substring` |
| val | [`splitAt`](../sig/SUBSTRING.md#val-splitat) | `substring * int -> substring * substring` |
| val | [`splitl`](../sig/SUBSTRING.md#val-splitl) | `(char -> bool) -> substring -> substring * substring` |
| val | [`splitr`](../sig/SUBSTRING.md#val-splitr) | `(char -> bool) -> substring -> substring * substring` |
| val | [`string`](../sig/SUBSTRING.md#val-string) | `substring -> string` |
| val | [`sub`](../sig/SUBSTRING.md#val-sub) | `substring * int -> char` |
| val | [`substring`](../sig/SUBSTRING.md#val-substring) | `string * int * int -> substring` |
| val | [`takel`](../sig/SUBSTRING.md#val-takel) | `(char -> bool) -> substring -> substring` |
| val | [`taker`](../sig/SUBSTRING.md#val-taker) | `(char -> bool) -> substring -> substring` |
| val | [`tokens`](../sig/SUBSTRING.md#val-tokens) | `(char -> bool) -> substring -> substring list` |
| val | [`translate`](../sig/SUBSTRING.md#val-translate) | `(char -> string) -> substring -> string` |
| val | [`triml`](../sig/SUBSTRING.md#val-triml) | `int -> substring -> substring` |
| val | [`trimr`](../sig/SUBSTRING.md#val-trimr) | `int -> substring -> substring` |

## Notes

### extract

> **Implementation** `Substring.extract/no-overflow`. The bounds are tested
> so that they cannot overflow: an `i` and an `n` whose sum is no `int`
> raise [`Subscript`](../sig/GENERAL.md#exn-subscript), not [`Overflow`](../sig/GENERAL.md#exn-overflow).

### position

> **Erratum** `Substring.position/none-ends-after-the-substring`. The
> specification describes the second component as "the longest suffix of
> `ss` that has `s` as a prefix", and then writes the condition on the
> index in a way that forgets that the occurrence has to lie inside `ss`:
> an `s` that begins in `ss` and runs past its end is not an occurrence.

### span

> **Reading** `Substring.span/equal-strings-built-separately`. "Unless `s <> s'`" is read as a comparison of the base strings by value: two equal
> strings that were built separately count as one base.

### substring

> **Implementation** `Substring.substring/slice`. It is
> [`CharVectorSlice.slice`](../sig/MONO_VECTOR_SLICE.md#val-slice), the slice of a vector of characters, so the two
> structures describe one type.

### triml

> **Reading** `Substring.triml/Subscript-negative-k`. The specification says
> that the exception is raised "when `triml k` is evaluated", before the
> substring is given, so a partial application with a negative `k` raises
> at once.

> **Reading** `Substring.triml/position-of-the-empty-result`. When `k` is more
> than the size the result is empty, and the page does not say where in the
> string it lies: here at the end of the substring for [`triml`](../sig/SUBSTRING.md#val-triml) and at its
> start for [`trimr`](../sig/SUBSTRING.md#val-trimr). The suite checks that it is empty and lies inside the
> same string.

<details><summary>Other implementations (5)</summary>

- **Poly/ML** &mdash; substring (s, i, j) raises Overflow instead of Subscript when i + j overflows
- **Poly/ML** &mdash; extract (s, i, SOME j) raises Overflow instead of Subscript when i + j overflows
- **Poly/ML** &mdash; extract (s, i, NONE) raises Overflow instead of Subscript for the smallest int (\|s\| - i overflows)
- **SML/NJ** &mdash; isSubstring "" ss is false when ss is empty
- **MLton, SML/NJ** &mdash; triml k and trimr k with k \< 0 raise Subscript only when applied to a substring

</details>

---

<sub>Generated by runedoc from lib/basis/substring.sml; do not edit.</sub>
