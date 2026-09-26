# structure WideSubstring

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; [Structures](../structures.md) &rsaquo; **WideSubstring**

|  |  |
| --- | --- |
| Signature | [`SUBSTRING`](../sig/SUBSTRING.md) |
| Status | optional |
| Members | 39 |
| Tests | 44 checks |
| Source | [lib/basis/widestring.sml](../../../../lib/basis/widestring.sml) |

## Synopsis

```sml
structure WideSubstring :> SUBSTRING where type substring = WideCharVectorSlice.slice where type string = WideCharVector.vector where type char = WideChar.char
```

## Members

What each means is on [`SUBSTRING`](../sig/SUBSTRING.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`char`](../sig/SUBSTRING.md#type-char) | *a type of its own* |
| type | [`string`](../sig/SUBSTRING.md#val-string) | `WideTextIO.vector` |
| type | [`substring`](../sig/SUBSTRING.md#val-substring) | `WideCharVectorSlice.slice` |
| val | [`app`](../sig/SUBSTRING.md#val-app) | `(char -> unit) -> WideCharVectorSlice.slice -> unit` |
| val | [`base`](../sig/SUBSTRING.md#val-base) | `WideCharVectorSlice.slice -> WideTextIO.vector * int * int` |
| val | [`collate`](../sig/SUBSTRING.md#val-collate) | `(char * char -> order) -> WideCharVectorSlice.slice * WideCharVectorSlice.slice -> order` |
| val | [`compare`](../sig/SUBSTRING.md#val-compare) | `WideCharVectorSlice.slice * WideCharVectorSlice.slice -> order` |
| val | [`concat`](../sig/SUBSTRING.md#val-concat) | `WideCharVectorSlice.slice list -> WideTextIO.vector` |
| val | [`concatWith`](../sig/SUBSTRING.md#val-concatwith) | `WideTextIO.vector -> WideCharVectorSlice.slice list -> WideTextIO.vector` |
| val | [`dropl`](../sig/SUBSTRING.md#val-dropl) | `(char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`dropr`](../sig/SUBSTRING.md#val-dropr) | `(char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`explode`](../sig/SUBSTRING.md#val-explode) | `WideCharVectorSlice.slice -> char list` |
| val | [`extract`](../sig/SUBSTRING.md#val-extract) | `WideTextIO.vector * int * int option -> WideCharVectorSlice.slice` |
| val | [`fields`](../sig/SUBSTRING.md#val-fields) | `(char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice list` |
| val | [`first`](../sig/SUBSTRING.md#val-first) | `WideCharVectorSlice.slice -> char option` |
| val | [`foldl`](../sig/SUBSTRING.md#val-foldl) | `(char * 'a -> 'a) -> 'a -> WideCharVectorSlice.slice -> 'a` |
| val | [`foldr`](../sig/SUBSTRING.md#val-foldr) | `(char * 'b -> 'b) -> 'b -> WideCharVectorSlice.slice -> 'b` |
| val | [`full`](../sig/SUBSTRING.md#val-full) | `WideTextIO.vector -> WideCharVectorSlice.slice` |
| val | [`getc`](../sig/SUBSTRING.md#val-getc) | `WideCharVectorSlice.slice -> (char * WideCharVectorSlice.slice) option` |
| val | [`isEmpty`](../sig/SUBSTRING.md#val-isempty) | `WideCharVectorSlice.slice -> bool` |
| val | [`isPrefix`](../sig/SUBSTRING.md#val-isprefix) | `WideTextIO.vector -> WideCharVectorSlice.slice -> bool` |
| val | [`isSubstring`](../sig/SUBSTRING.md#val-issubstring) | `WideTextIO.vector -> WideCharVectorSlice.slice -> bool` |
| val | [`isSuffix`](../sig/SUBSTRING.md#val-issuffix) | `WideTextIO.vector -> WideCharVectorSlice.slice -> bool` |
| val | [`position`](../sig/SUBSTRING.md#val-position) | `WideTextIO.vector -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice * WideCharVectorSlice.slice` |
| val | [`size`](../sig/SUBSTRING.md#val-size) | `WideCharVectorSlice.slice -> int` |
| val | [`slice`](../sig/SUBSTRING.md#val-slice) | `WideCharVectorSlice.slice * int * int option -> WideCharVectorSlice.slice` |
| val | [`span`](../sig/SUBSTRING.md#val-span) | `WideCharVectorSlice.slice * WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`splitAt`](../sig/SUBSTRING.md#val-splitat) | `WideCharVectorSlice.slice * int -> WideCharVectorSlice.slice * WideCharVectorSlice.slice` |
| val | [`splitl`](../sig/SUBSTRING.md#val-splitl) | `(char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice * WideCharVectorSlice.slice` |
| val | [`splitr`](../sig/SUBSTRING.md#val-splitr) | `(char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice * WideCharVectorSlice.slice` |
| val | [`string`](../sig/SUBSTRING.md#val-string) | `WideCharVectorSlice.slice -> WideTextIO.vector` |
| val | [`sub`](../sig/SUBSTRING.md#val-sub) | `WideCharVectorSlice.slice * int -> char` |
| val | [`substring`](../sig/SUBSTRING.md#val-substring) | `WideTextIO.vector * int * int -> WideCharVectorSlice.slice` |
| val | [`takel`](../sig/SUBSTRING.md#val-takel) | `(char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`taker`](../sig/SUBSTRING.md#val-taker) | `(char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`tokens`](../sig/SUBSTRING.md#val-tokens) | `(char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice list` |
| val | [`translate`](../sig/SUBSTRING.md#val-translate) | `(char -> WideTextIO.vector) -> WideCharVectorSlice.slice -> WideTextIO.vector` |
| val | [`triml`](../sig/SUBSTRING.md#val-triml) | `int -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`trimr`](../sig/SUBSTRING.md#val-trimr) | `int -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |

---

<sub>Generated by runedoc from lib/basis/widestring.sml; do not edit.</sub>
