# structure WideSubstring

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; [Structures](../structures.md) &rsaquo; **WideSubstring**

|  |  |
| --- | --- |
| Signature | [`SUBSTRING`](../sig/SUBSTRING.md) |
| Status | optional |
| Members | 39 |
| Tests | 54 checks |
| Source | [lib/basis/widestring.sml](../../../../lib/basis/widestring.sml) |

## Synopsis

```sml
structure WideSubstring :> SUBSTRING where type substring = WideCharVectorSlice.slice where type string = WideCharVector.vector where type char = WideChar.char
```

WideSubstring: pieces of wide strings, taken apart and searched without a
copy.

## Members

What each means is on [`SUBSTRING`](../sig/SUBSTRING.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`char`](../sig/SUBSTRING.md#type-char) | `WideChar.char` |
| type | [`string`](../sig/SUBSTRING.md#type-string) | `WideCharVector.vector` |
| type | [`substring`](../sig/SUBSTRING.md#type-substring) | `WideCharVectorSlice.slice` |
| val | [`app`](../sig/SUBSTRING.md#val-app) | `(WideChar.char -> unit) -> WideCharVectorSlice.slice -> unit` |
| val | [`base`](../sig/SUBSTRING.md#val-base) | `WideCharVectorSlice.slice -> WideCharVector.vector * int * int` |
| val | [`collate`](../sig/SUBSTRING.md#val-collate) | `(WideChar.char * WideChar.char -> order) -> WideCharVectorSlice.slice * WideCharVectorSlice.slice -> order` |
| val | [`compare`](../sig/SUBSTRING.md#val-compare) | `WideCharVectorSlice.slice * WideCharVectorSlice.slice -> order` |
| val | [`concat`](../sig/SUBSTRING.md#val-concat) | `WideCharVectorSlice.slice list -> WideCharVector.vector` |
| val | [`concatWith`](../sig/SUBSTRING.md#val-concatwith) | `WideCharVector.vector -> WideCharVectorSlice.slice list -> WideCharVector.vector` |
| val | [`dropl`](../sig/SUBSTRING.md#val-dropl) | `(WideChar.char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`dropr`](../sig/SUBSTRING.md#val-dropr) | `(WideChar.char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`explode`](../sig/SUBSTRING.md#val-explode) | `WideCharVectorSlice.slice -> WideChar.char list` |
| val | [`extract`](../sig/SUBSTRING.md#val-extract) | `WideCharVector.vector * int * int option -> WideCharVectorSlice.slice` |
| val | [`fields`](../sig/SUBSTRING.md#val-fields) | `(WideChar.char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice list` |
| val | [`first`](../sig/SUBSTRING.md#val-first) | `WideCharVectorSlice.slice -> WideChar.char option` |
| val | [`foldl`](../sig/SUBSTRING.md#val-foldl) | `(WideChar.char * 'a -> 'a) -> 'a -> WideCharVectorSlice.slice -> 'a` |
| val | [`foldr`](../sig/SUBSTRING.md#val-foldr) | `(WideChar.char * 'a -> 'a) -> 'a -> WideCharVectorSlice.slice -> 'a` |
| val | [`full`](../sig/SUBSTRING.md#val-full) | `WideCharVector.vector -> WideCharVectorSlice.slice` |
| val | [`getc`](../sig/SUBSTRING.md#val-getc) | `WideCharVectorSlice.slice -> (WideChar.char * WideCharVectorSlice.slice) option` |
| val | [`isEmpty`](../sig/SUBSTRING.md#val-isempty) | `WideCharVectorSlice.slice -> bool` |
| val | [`isPrefix`](../sig/SUBSTRING.md#val-isprefix) | `WideCharVector.vector -> WideCharVectorSlice.slice -> bool` |
| val | [`isSubstring`](../sig/SUBSTRING.md#val-issubstring) | `WideCharVector.vector -> WideCharVectorSlice.slice -> bool` |
| val | [`isSuffix`](../sig/SUBSTRING.md#val-issuffix) | `WideCharVector.vector -> WideCharVectorSlice.slice -> bool` |
| val | [`position`](../sig/SUBSTRING.md#val-position) | `WideCharVector.vector -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice * WideCharVectorSlice.slice` |
| val | [`size`](../sig/SUBSTRING.md#val-size) | `WideCharVectorSlice.slice -> int` |
| val | [`slice`](../sig/SUBSTRING.md#val-slice) | `WideCharVectorSlice.slice * int * int option -> WideCharVectorSlice.slice` |
| val | [`span`](../sig/SUBSTRING.md#val-span) | `WideCharVectorSlice.slice * WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`splitAt`](../sig/SUBSTRING.md#val-splitat) | `WideCharVectorSlice.slice * int -> WideCharVectorSlice.slice * WideCharVectorSlice.slice` |
| val | [`splitl`](../sig/SUBSTRING.md#val-splitl) | `(WideChar.char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice * WideCharVectorSlice.slice` |
| val | [`splitr`](../sig/SUBSTRING.md#val-splitr) | `(WideChar.char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice * WideCharVectorSlice.slice` |
| val | [`string`](../sig/SUBSTRING.md#val-string) | `WideCharVectorSlice.slice -> WideCharVector.vector` |
| val | [`sub`](../sig/SUBSTRING.md#val-sub) | `WideCharVectorSlice.slice * int -> WideChar.char` |
| val | [`substring`](../sig/SUBSTRING.md#val-substring) | `WideCharVector.vector * int * int -> WideCharVectorSlice.slice` |
| val | [`takel`](../sig/SUBSTRING.md#val-takel) | `(WideChar.char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`taker`](../sig/SUBSTRING.md#val-taker) | `(WideChar.char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`tokens`](../sig/SUBSTRING.md#val-tokens) | `(WideChar.char -> bool) -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice list` |
| val | [`translate`](../sig/SUBSTRING.md#val-translate) | `(WideChar.char -> WideCharVector.vector) -> WideCharVectorSlice.slice -> WideCharVector.vector` |
| val | [`triml`](../sig/SUBSTRING.md#val-triml) | `int -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |
| val | [`trimr`](../sig/SUBSTRING.md#val-trimr) | `int -> WideCharVectorSlice.slice -> WideCharVectorSlice.slice` |

---

<sub>Generated by runedoc from lib/basis/widestring.sml; do not edit.</sub>
