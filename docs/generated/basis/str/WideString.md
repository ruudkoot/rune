# structure WideString

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; [Structures](../structures.md) &rsaquo; **WideString**

|  |  |
| --- | --- |
| Signature | [`STRING`](../sig/STRING.md) |
| Status | optional |
| Members | 31 |
| Tests | 64 checks |
| Source | [lib/basis/widestring.sml](../../../../lib/basis/widestring.sml) |

## Synopsis

```sml
structure WideString :> STRING where type string = WideCharVector.vector where type char = WideChar.char
```

> **Reading** `WideString.scan/reads-wide-characters`. As the signature of the
> specification writes it, [`scan`](../sig/STRING.md#val-scan) reads a stream of the structure's own
> characters, where MLton's reads 8-bit ones; [`toString`](../sig/STRING.md#val-tostring), [`fromString`](../sig/STRING.md#val-fromstring),
> [`toCString`](../sig/STRING.md#val-tocstring) and [`fromCString`](../sig/STRING.md#val-fromcstring) take and give text of [`char`](../sig/STRING.md#type-char), the 8-bit one,
> in which a character above 255 appears as the escape `\uXXXX` or
> `\UXXXXXXXX` (widechar.sml).

> **Reading** `WideString.scan/unescaped-double-quote`. In the stream of wide
> characters an escape is written with the characters of ASCII, and a
> character that needs none stands for itself, those above 255 too. A
> double quote that no backslash precedes converts to itself, as it does
> for [`String.scan`](../sig/STRING.md#val-scan) and for [`WideString.fromString`](../sig/STRING.md#val-fromstring) on its text of [`char`](../sig/STRING.md#type-char):
> what ends a scan is the end of the stream, a character that does not
> print and a bad escape, and a double quote is none of these.

## Members

What each means is on [`STRING`](../sig/STRING.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`char`](../sig/STRING.md#type-char) | `WideChar.char` |
| type | [`string`](../sig/STRING.md#type-string) | `WideCharVector.vector` |
| val | [`<`](../sig/STRING.md#val-op-lt) | `WideCharVector.vector * WideCharVector.vector -> bool` |
| val | [`<=`](../sig/STRING.md#val-op-lt-eq) | `WideCharVector.vector * WideCharVector.vector -> bool` |
| val | [`>`](../sig/STRING.md#val-op-gt) | `WideCharVector.vector * WideCharVector.vector -> bool` |
| val | [`>=`](../sig/STRING.md#val-op-gt-eq) | `WideCharVector.vector * WideCharVector.vector -> bool` |
| val | [`^`](../sig/STRING.md#val-op-caret) | `WideCharVector.vector * WideCharVector.vector -> WideCharVector.vector` |
| val | [`collate`](../sig/STRING.md#val-collate) | `(WideChar.char * WideChar.char -> order) -> WideCharVector.vector * WideCharVector.vector -> order` |
| val | [`compare`](../sig/STRING.md#val-compare) | `WideCharVector.vector * WideCharVector.vector -> order` |
| val | [`concat`](../sig/STRING.md#val-concat) | `WideCharVector.vector list -> WideCharVector.vector` |
| val | [`concatWith`](../sig/STRING.md#val-concatwith) | `WideCharVector.vector -> WideCharVector.vector list -> WideCharVector.vector` |
| val | [`explode`](../sig/STRING.md#val-explode) | `WideCharVector.vector -> WideChar.char list` |
| val | [`extract`](../sig/STRING.md#val-extract) | `WideCharVector.vector * int * int option -> WideCharVector.vector` |
| val | [`fields`](../sig/STRING.md#val-fields) | `(WideChar.char -> bool) -> WideCharVector.vector -> WideCharVector.vector list` |
| val | [`fromCString`](../sig/STRING.md#val-fromcstring) | `string -> WideCharVector.vector option` |
| val | [`fromString`](../sig/STRING.md#val-fromstring) | `string -> WideCharVector.vector option` |
| val | [`implode`](../sig/STRING.md#val-implode) | `WideChar.char list -> WideCharVector.vector` |
| val | [`isPrefix`](../sig/STRING.md#val-isprefix) | `WideCharVector.vector -> WideCharVector.vector -> bool` |
| val | [`isSubstring`](../sig/STRING.md#val-issubstring) | `WideCharVector.vector -> WideCharVector.vector -> bool` |
| val | [`isSuffix`](../sig/STRING.md#val-issuffix) | `WideCharVector.vector -> WideCharVector.vector -> bool` |
| val | [`map`](../sig/STRING.md#val-map) | `(WideChar.char -> WideChar.char) -> WideCharVector.vector -> WideCharVector.vector` |
| val | [`maxSize`](../sig/STRING.md#val-maxsize) | `int` |
| val | [`scan`](../sig/STRING.md#val-scan) | `('a -> (WideChar.char * 'a) option) -> 'a -> (WideCharVector.vector * 'a) option` |
| val | [`size`](../sig/STRING.md#val-size) | `WideCharVector.vector -> int` |
| val | [`str`](../sig/STRING.md#val-str) | `WideChar.char -> WideCharVector.vector` |
| val | [`sub`](../sig/STRING.md#val-sub) | `WideCharVector.vector * int -> WideChar.char` |
| val | [`substring`](../sig/STRING.md#val-substring) | `WideCharVector.vector * int * int -> WideCharVector.vector` |
| val | [`toCString`](../sig/STRING.md#val-tocstring) | `WideCharVector.vector -> string` |
| val | [`toString`](../sig/STRING.md#val-tostring) | `WideCharVector.vector -> string` |
| val | [`tokens`](../sig/STRING.md#val-tokens) | `(WideChar.char -> bool) -> WideCharVector.vector -> WideCharVector.vector list` |
| val | [`translate`](../sig/STRING.md#val-translate) | `(WideChar.char -> WideCharVector.vector) -> WideCharVector.vector -> WideCharVector.vector` |

---

<sub>Generated by runedoc from lib/basis/widestring.sml; do not edit.</sub>
