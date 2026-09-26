# structure Char

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; [Structures](../structures.md) &rsaquo; **Char**

|  |  |
| --- | --- |
| Signature | [`CHAR`](../sig/CHAR.md) |
| Status | required |
| Members | 35 |
| Tests | 247 checks |
| Source | [lib/basis/char.sml](../../../../lib/basis/char.sml) |

## Synopsis

```sml
structure Char : CHAR where type char = char where type string = String.string
```

Char: 8-bit characters.

## Members

What each means is on [`CHAR`](../sig/CHAR.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`char`](../sig/CHAR.md#type-char) | *a type of its own* |
| type | [`string`](../sig/CHAR.md#type-string) | *a type of its own* |
| val | [`<`](../sig/CHAR.md#val-op-lt) | `char * char -> bool` |
| val | [`<=`](../sig/CHAR.md#val-op-lt-eq) | `char * char -> bool` |
| val | [`>`](../sig/CHAR.md#val-op-gt) | `char * char -> bool` |
| val | [`>=`](../sig/CHAR.md#val-op-gt-eq) | `char * char -> bool` |
| val | [`chr`](../sig/CHAR.md#val-chr) | `int -> char` |
| val | [`compare`](../sig/CHAR.md#val-compare) | `char * char -> order` |
| val | [`contains`](../sig/CHAR.md#val-contains) | `string -> char -> bool` |
| val | [`fromCString`](../sig/CHAR.md#val-fromcstring) | `string -> char option` |
| val | [`fromString`](../sig/CHAR.md#val-fromstring) | `string -> char option` |
| val | [`isAlpha`](../sig/CHAR.md#val-isalpha) | `char -> bool` |
| val | [`isAlphaNum`](../sig/CHAR.md#val-isalphanum) | `char -> bool` |
| val | [`isAscii`](../sig/CHAR.md#val-isascii) | `char -> bool` |
| val | [`isCntrl`](../sig/CHAR.md#val-iscntrl) | `char -> bool` |
| val | [`isDigit`](../sig/CHAR.md#val-isdigit) | `char -> bool` |
| val | [`isGraph`](../sig/CHAR.md#val-isgraph) | `char -> bool` |
| val | [`isHexDigit`](../sig/CHAR.md#val-ishexdigit) | `char -> bool` |
| val | [`isLower`](../sig/CHAR.md#val-islower) | `char -> bool` |
| val | [`isPrint`](../sig/CHAR.md#val-isprint) | `char -> bool` |
| val | [`isPunct`](../sig/CHAR.md#val-ispunct) | `char -> bool` |
| val | [`isSpace`](../sig/CHAR.md#val-isspace) | `char -> bool` |
| val | [`isUpper`](../sig/CHAR.md#val-isupper) | `char -> bool` |
| val | [`maxChar`](../sig/CHAR.md#val-maxchar) | `char` |
| val | [`maxOrd`](../sig/CHAR.md#val-maxord) | `int` |
| val | [`minChar`](../sig/CHAR.md#val-minchar) | `char` |
| val | [`notContains`](../sig/CHAR.md#val-notcontains) | `string -> char -> bool` |
| val | [`ord`](../sig/CHAR.md#val-ord) | `char -> int` |
| val | [`pred`](../sig/CHAR.md#val-pred) | `char -> char` |
| val | [`scan`](../sig/CHAR.md#val-scan) | `('a -> (char * 'a) option) -> 'a -> (char * 'a) option` |
| val | [`succ`](../sig/CHAR.md#val-succ) | `char -> char` |
| val | [`toCString`](../sig/CHAR.md#val-tocstring) | `char -> string` |
| val | [`toLower`](../sig/CHAR.md#val-tolower) | `char -> char` |
| val | [`toString`](../sig/CHAR.md#val-tostring) | `char -> string` |
| val | [`toUpper`](../sig/CHAR.md#val-toupper) | `char -> char` |

## Notes

### char

> **Implementation** `Char.char/eight-bits`. [`Char.char`](../sig/CHAR.md#type-char) is the top-level
> [`char`](../sig/CHAR.md#type-char), a character of 8 bits: its codes run from 0 to 255.

### compare

> **Reading** `Char.compare/127-128`. The codes are not negative, so 127 comes
> before 128 and 255 after 0: a character is not a signed byte.

### fromCString

> **Reading** `Char.fromCString/hex-huge-does-not-fit`. A `\x` escape whose
> value is no character gives `NONE` however many digits it has:
> [`Overflow`](../sig/GENERAL.md#exn-overflow) is not raised.

> **Reading** `Char.fromCString/printable-only-all-converted`. Every printable
> character but the double quote and the backslash is converted to itself,
> the single quote included; what does not print is rejected.

### fromString

> **Reading** `Char.fromString/printable-only-all-rejected`. A first character
> outside the printable range, codes 32 to 126, gives `NONE`, and so does
> a backslash by itself; every other printable character but the double
> quote, of which below, is converted to itself.

> **Reading** `Char.fromString/unescaped-double-quote`. The specification
> has the text read "as allowed in an SML program", where a double quote
> that no backslash precedes ends a constant and is no character, and
> names only characters that do not print and bad escapes as what gives
> `NONE`. The first is followed: a double quote by itself gives `NONE`, as
> in MLton and SML/NJ, where Poly/ML converts it. The page of [`STRING`](../sig/STRING.md) has
> no such words and lists what stops a scan, so [`String.scan`](../sig/STRING.md#val-scan) converts the
> same double quote; the two pages differ, and each is followed.

### isAscii

> **Reading** `Char.isAlpha/latin1`. The classes below are the sets that the
> specification's discussion lists, whatever the locale: no character
> above 127 is in any of them, and [`toLower`](../sig/CHAR.md#val-tolower) and [`toUpper`](../sig/CHAR.md#val-toupper) change the 52
> letters of ASCII only.

### maxOrd

> **Implementation** `Char.maxOrd/value`. 255 for [`Char`](Char.md), and 1114111, the
> last code point of Unicode, for [`WideChar`](../str/WideChar.md).

### scan

> **Reading** `Char.scan/formatting`. A formatting sequence, a backslash, white
> space and another backslash, stands for nothing. Such sequences are
> passed over before the character, and after it as well, so that what is
> left of the stream never begins with one.

<details><summary>Other implementations (7)</summary>

- **MLton, SML/NJ, Poly/ML** &mdash; converts an unescaped double quote, which the specification says fromCString does not accept
- **MLton, SML/NJ, Poly/ML** &mdash; Overflow instead of NONE for a \\x escape whose value exceeds Int.maxInt
- **MLton** &mdash; fromCString accepts the SML escape \\uxxxx
- **SML/NJ** &mdash; fromCString does not accept \\^c
- **Poly/ML** &mdash; another reading of the specification: converts an unescaped double quote; the test takes the reading of MLton, SML/NJ and Rune (NONE)
- **MLton** &mdash; scan leaves an escaped formatting sequence in the stream after an escape sequence (not after a plain character)
- **SML/NJ, Poly/ML** &mdash; scan leaves an escaped formatting sequence that follows the character in the stream

</details>

---

<sub>Generated by runedoc from lib/basis/char.sml; do not edit.</sub>
