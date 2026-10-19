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
structure WideString : STRING where type char = WideChar.char
```

WideString: strings of wide characters, and their conversions to and from
the text of SML and C.

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
| type | [`char`](../sig/STRING.md#type-char) | `RuneWideChar.char` |
| type | [`string`](../sig/STRING.md#type-string) | *a type of its own* |
| val | [`<`](../sig/STRING.md#val-op-lt) | `WideString.string * WideString.string -> bool` |
| val | [`<=`](../sig/STRING.md#val-op-lt-eq) | `WideString.string * WideString.string -> bool` |
| val | [`>`](../sig/STRING.md#val-op-gt) | `WideString.string * WideString.string -> bool` |
| val | [`>=`](../sig/STRING.md#val-op-gt-eq) | `WideString.string * WideString.string -> bool` |
| val | [`^`](../sig/STRING.md#val-op-caret) | `WideString.string * WideString.string -> WideString.string` |
| val | [`collate`](../sig/STRING.md#val-collate) | `(RuneWideChar.char * RuneWideChar.char -> order) -> WideString.string * WideString.string -> order` |
| val | [`compare`](../sig/STRING.md#val-compare) | `WideString.string * WideString.string -> order` |
| val | [`concat`](../sig/STRING.md#val-concat) | `WideString.string list -> WideString.string` |
| val | [`concatWith`](../sig/STRING.md#val-concatwith) | `WideString.string -> WideString.string list -> WideString.string` |
| val | [`explode`](../sig/STRING.md#val-explode) | `WideString.string -> RuneWideChar.char list` |
| val | [`extract`](../sig/STRING.md#val-extract) | `WideString.string * int * int option -> WideString.string` |
| val | [`fields`](../sig/STRING.md#val-fields) | `(RuneWideChar.char -> bool) -> WideString.string -> WideString.string list` |
| val | [`fromCString`](../sig/STRING.md#val-fromcstring) | `string -> WideString.string option` |
| val | [`fromString`](../sig/STRING.md#val-fromstring) | `string -> WideString.string option` |
| val | [`implode`](../sig/STRING.md#val-implode) | `RuneWideChar.char list -> WideString.string` |
| val | [`isPrefix`](../sig/STRING.md#val-isprefix) | `WideString.string -> WideString.string -> bool` |
| val | [`isSubstring`](../sig/STRING.md#val-issubstring) | `WideString.string -> WideString.string -> bool` |
| val | [`isSuffix`](../sig/STRING.md#val-issuffix) | `WideString.string -> WideString.string -> bool` |
| val | [`map`](../sig/STRING.md#val-map) | `(RuneWideChar.char -> RuneWideChar.char) -> WideString.string -> WideString.string` |
| val | [`maxSize`](../sig/STRING.md#val-maxsize) | `int` |
| val | [`scan`](../sig/STRING.md#val-scan) | `('a -> (RuneWideChar.char * 'a) option) -> 'a -> (WideString.string * 'a) option` |
| val | [`size`](../sig/STRING.md#val-size) | `WideString.string -> int` |
| val | [`str`](../sig/STRING.md#val-str) | `RuneWideChar.char -> WideString.string` |
| val | [`sub`](../sig/STRING.md#val-sub) | `WideString.string * int -> RuneWideChar.char` |
| val | [`substring`](../sig/STRING.md#val-substring) | `WideString.string * int * int -> WideString.string` |
| val | [`toCString`](../sig/STRING.md#val-tocstring) | `WideString.string -> string` |
| val | [`toString`](../sig/STRING.md#val-tostring) | `WideString.string -> string` |
| val | [`tokens`](../sig/STRING.md#val-tokens) | `(RuneWideChar.char -> bool) -> WideString.string -> WideString.string list` |
| val | [`translate`](../sig/STRING.md#val-translate) | `(RuneWideChar.char -> WideString.string) -> WideString.string -> WideString.string` |

---

<sub>Generated by runedoc from lib/basis/widestring.sml; do not edit.</sub>
