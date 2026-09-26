# structure String

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; [Structures](../structures.md) &rsaquo; **String**

|  |  |
| --- | --- |
| Signature | [`STRING`](../sig/STRING.md) |
| Status | required |
| Members | 31 |
| Tests | 214 checks |
| Source | [lib/basis/string.sml](../../../../lib/basis/string.sml) |

## Synopsis

```sml
structure String : STRING where type string = string where type char = Char.char
```

String: 8-bit byte strings.

## Members

What each means is on [`STRING`](../sig/STRING.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`char`](../sig/STRING.md#type-char) | *a type of its own* |
| type | [`string`](../sig/STRING.md#type-string) | *a type of its own* |
| val | [`<`](../sig/STRING.md#val-op-lt) | `string * string -> bool` |
| val | [`<=`](../sig/STRING.md#val-op-lt-eq) | `string * string -> bool` |
| val | [`>`](../sig/STRING.md#val-op-gt) | `string * string -> bool` |
| val | [`>=`](../sig/STRING.md#val-op-gt-eq) | `string * string -> bool` |
| val | [`^`](../sig/STRING.md#val-op-caret) | `string * string -> string` |
| val | [`collate`](../sig/STRING.md#val-collate) | `(char * char -> order) -> string * string -> order` |
| val | [`compare`](../sig/STRING.md#val-compare) | `string * string -> order` |
| val | [`concat`](../sig/STRING.md#val-concat) | `string list -> string` |
| val | [`concatWith`](../sig/STRING.md#val-concatwith) | `string -> string list -> string` |
| val | [`explode`](../sig/STRING.md#val-explode) | `string -> char list` |
| val | [`extract`](../sig/STRING.md#val-extract) | `string * int * int option -> string` |
| val | [`fields`](../sig/STRING.md#val-fields) | `(char -> bool) -> string -> string list` |
| val | [`fromCString`](../sig/STRING.md#val-fromcstring) | `string -> string option` |
| val | [`fromString`](../sig/STRING.md#val-fromstring) | `string -> string option` |
| val | [`implode`](../sig/STRING.md#val-implode) | `char list -> string` |
| val | [`isPrefix`](../sig/STRING.md#val-isprefix) | `string -> string -> bool` |
| val | [`isSubstring`](../sig/STRING.md#val-issubstring) | `string -> string -> bool` |
| val | [`isSuffix`](../sig/STRING.md#val-issuffix) | `string -> string -> bool` |
| val | [`map`](../sig/STRING.md#val-map) | `(char -> char) -> string -> string` |
| val | [`maxSize`](../sig/STRING.md#val-maxsize) | `int` |
| val | [`scan`](../sig/STRING.md#val-scan) | `('a -> (char * 'a) option) -> 'a -> (string * 'a) option` |
| val | [`size`](../sig/STRING.md#val-size) | `string -> int` |
| val | [`str`](../sig/STRING.md#val-str) | `char -> string` |
| val | [`sub`](../sig/STRING.md#val-sub) | `string * int -> char` |
| val | [`substring`](../sig/STRING.md#val-substring) | `string * int * int -> string` |
| val | [`toCString`](../sig/STRING.md#val-tocstring) | `string -> string` |
| val | [`toString`](../sig/STRING.md#val-tostring) | `string -> string` |
| val | [`tokens`](../sig/STRING.md#val-tokens) | `(char -> bool) -> string -> string list` |
| val | [`translate`](../sig/STRING.md#val-translate) | `(char -> string) -> string -> string` |

## Notes

### extract

> **Reading** `String.extract/SOME-Subscript-not-Overflow-size`. The bound is
> tested so that it cannot overflow: an `i` and an `n` whose sum is no
> `int` raise [`Subscript`](../sig/GENERAL.md#exn-subscript), not [`Overflow`](../sig/GENERAL.md#exn-overflow).

### fromCString

> **Reading** `String.fromCString/stops-at-hex-longest-sequence`. A `\x`
> escape takes "the longest sequence" of hexadecimal digits: `"\x42C"` is
> one escape of the value 1068, which is no character, and not `\x42`
> followed by `C`.

### fromString

> **Reading** `String.fromString/format-first`. A formatting sequence counts
> as read although it stands for no character, so a text of nothing but
> such a sequence gives `SOME ""`, and so does one that a bad escape
> follows.

### maxSize

> **Implementation** `String.maxSize/value`. 1073741823, which is 2^30 - 1.

> **Implementation** `String.maxSize/Size-is-not-pinned`. With a bound of 2^30
> \- 1 no check of the suite makes a string that is too long: [`Size`](../sig/GENERAL.md#exn-size) from
> [`^`](../sig/STRING.md#val-op-caret), [`concat`](../sig/STRING.md#val-concat), [`implode`](../sig/STRING.md#val-implode) and [`translate`](../sig/STRING.md#val-translate) is raised by the VM when the
> bound is passed, and the suite checks it only on a system whose [`maxSize`](../sig/STRING.md#val-maxsize)
> is at most 2^26. The same holds for [`StringCvt.padLeft`](../sig/STRING_CVT.md#val-padleft) and `padRight`,
> for [`Substring.concat`](../sig/SUBSTRING.md#val-concat) and [`concatWith`](../sig/STRING.md#val-concatwith), and with [`Vector.maxLen`](../sig/VECTOR.md#val-maxlen) for
> [`Vector.concat`](../sig/VECTOR.md#val-concat) and [`VectorSlice.concat`](../sig/VECTOR_SLICE.md#val-concat).

### scan

> **Reading** `String.scan/as-much-as-possible`. "The longest prefix" is
> taken to mean that a character that cannot be read ends the scan rather
> than failing it, and that an escape that is not one (`"a\\q"`) leaves
> what came before it.

> **Reading** `String.fromString/unescaped-double-quote`. A double quote
> without a backslash converts to itself, as in SML/NJ and Poly/ML; MLton
> stops at it. [`Char.scan`](../sig/CHAR.md#val-scan) gives `NONE` for it, for the page of [`CHAR`](../sig/CHAR.md) has
> the text read "as allowed in an SML program" and this one does not.

> **Reading** `String.scan/empty-input-is-SOME-empty`. Nothing to read is no
> failure: `fromString ""` is `SOME ""`. `NONE` is for a first character
> that cannot be read, as in `fromString "\\q"`.

### string

> **Implementation** `String.string/bytes`. [`String.string`](../sig/STRING.md#type-string) is the top-level
> [`string`](../sig/STRING.md#type-string), a sequence of 8-bit characters; [`WideString.string`](../sig/STRING.md#type-string) is one of
> [`WideChar.char`](../sig/CHAR.md#type-char).

> **Implementation** `String.string/u-escape-above-255-rejected`. An escape
> `\uXXXX` above 255 in a constant of type [`string`](../sig/STRING.md#type-string) or [`char`](../sig/STRING.md#type-char) is an error
> when the program is compiled, for the characters have eight bits; at
> [`WideString.string`](../sig/STRING.md#type-string) it is a character.

<details><summary>Other implementations (8)</summary>

- **MLton, SML/NJ, Poly/ML** &mdash; converts an unescaped double quote, which the specification says fromCString does not accept
- **SML/NJ** &mdash; fromCString does not accept \\^c
- **MLton** &mdash; SOME "" instead of NONE when no character can be converted
- **SML/NJ** &mdash; fromCString returns NONE unless the whole string converts
- **MLton** &mdash; another reading of the specification: stops at an unescaped double quote; the test takes the reading of SML/NJ and Poly/ML (it converts to itself)
- **SML/NJ** &mdash; NONE instead of SOME "" when only an escaped formatting sequence can be scanned
- **SML/NJ** &mdash; isSubstring "" "" is false
- **SML/NJ** &mdash; isSubstring "" "" is false (the law draws two empty strings)

</details>

---

<sub>Generated by runedoc from lib/basis/string.sml; do not edit.</sub>
