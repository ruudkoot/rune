# signature CHAR

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; **CHAR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 35 of 35 entries documented |
| Source | [lib/basis/sig\_char.sml](../../../../lib/basis/sig_char.sml) |

## Synopsis

```sml
signature CHAR
structure Char : CHAR where type char = char where type string = String.string
structure WideChar :> CHAR where type char = WideChar.char where type string = WideString.string  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Char` | Char: 8-bit characters. | [lib/basis/char.sml](../../../../lib/basis/char.sml) |
| `WideChar` |  | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |

Characters: their codes and order, the classes they belong to, and their
conversion to and from the text of SML and C character constants.

A character is a small non-negative integer, its code, and the characters
are ordered as their codes are. The signature is that of [`Char`](CHAR.md), whose
characters are the elements of [`string`](#type-string), and of the optional [`WideChar`](CHAR.md),
which is why it specifies a type [`string`](#type-string) of its own.

The classes ([`isAlpha`](#val-isalpha), [`isSpace`](#val-isspace) and the rest) are those of the ASCII
character set and do not depend on a locale.

> **Erratum** `CHAR/string-types`. The specification writes the types of
> [`toString`](#val-tostring), [`scan`](#val-scan), [`fromString`](#val-fromstring), [`toCString`](#val-tocstring) and [`fromCString`](#val-fromcstring) with
> [`String.string`](../sig/STRING.md#type-string) and [`Char.char`](#type-char) rather than with the [`string`](#type-string) and [`char`](#type-char)
> of the signature, because the text is always one of 8-bit characters, also
> for [`WideChar`](CHAR.md). They are kept as written; that [`Char.char`](#type-char) is [`char`](#type-char) and
> [`Char.string`](#type-string) is [`String.string`](../sig/STRING.md#type-string) is a constraint on the structure [`Char`](CHAR.md).

> **Erratum** `CHAR/fromString-sample`. The third example of the page's table
> for [`fromString`](#val-fromstring) is not the text of an SML string; the page of [`STRING`](../sig/STRING.md)
> has the table as it was meant.

## Contents

[Types and bounds](#types-and-bounds) &middot;
[Codes and order](#codes-and-order) &middot;
[Membership](#membership) &middot;
[Classes and case](#classes-and-case) &middot;
[The text of character constants](#the-text-of-character-constants)

## Interface

<pre>
signature CHAR =
sig

  eqtype <a href="#type-char">char</a>

  eqtype <a href="#type-string">string</a>

  val <a href="#val-minchar">minChar</a> : char

  val <a href="#val-maxchar">maxChar</a> : char

  val <a href="#val-maxord">maxOrd</a> : int

  val <a href="#val-ord">ord</a> : char -&gt; int

  val <a href="#val-chr">chr</a> : int -&gt; char

  val <a href="#val-succ">succ</a> : char -&gt; char

  val <a href="#val-pred">pred</a> : char -&gt; char

  val <a href="#val-compare">compare</a> : char * char -&gt; order

  val <a href="#val-op-lt">&lt;</a> : char * char -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : char * char -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : char * char -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : char * char -&gt; bool

  val <a href="#val-contains">contains</a> : string -&gt; char -&gt; bool

  val <a href="#val-notcontains">notContains</a> : string -&gt; char -&gt; bool

  val <a href="#val-isascii">isAscii</a> : char -&gt; bool

  val <a href="#val-tolower">toLower</a> : char -&gt; char

  val <a href="#val-toupper">toUpper</a> : char -&gt; char

  val <a href="#val-isalpha">isAlpha</a> : char -&gt; bool

  val <a href="#val-isalphanum">isAlphaNum</a> : char -&gt; bool

  val <a href="#val-iscntrl">isCntrl</a> : char -&gt; bool

  val <a href="#val-isdigit">isDigit</a> : char -&gt; bool

  val <a href="#val-isgraph">isGraph</a> : char -&gt; bool

  val <a href="#val-ishexdigit">isHexDigit</a> : char -&gt; bool

  val <a href="#val-islower">isLower</a> : char -&gt; bool

  val <a href="#val-isprint">isPrint</a> : char -&gt; bool

  val <a href="#val-isspace">isSpace</a> : char -&gt; bool

  val <a href="#val-ispunct">isPunct</a> : char -&gt; bool

  val <a href="#val-isupper">isUpper</a> : char -&gt; bool

  val <a href="#val-tostring">toString</a> : char -&gt; String.string

  val <a href="#val-scan">scan</a> : (Char.char, 'a) StringCvt.reader -&gt; (char, 'a) StringCvt.reader

  val <a href="#val-fromstring">fromString</a> : String.string -&gt; char option

  val <a href="#val-tocstring">toCString</a> : char -&gt; String.string

  val <a href="#val-fromcstring">fromCString</a> : String.string -&gt; char option
end
</pre>

## Types and bounds

### <a name="type-char"></a>`char`

```sml
eqtype char
```

The type of characters.

> **Implementation** `Char.char/eight-bits`. [`Char.char`](#type-char) is the top-level
> [`char`](#type-char), a character of 8 bits: its codes run from 0 to 255.

### <a name="type-string"></a>`string`

```sml
eqtype string
```

The type of strings of these characters: [`String.string`](../sig/STRING.md#type-string) for [`Char`](CHAR.md).

### <a name="val-minchar"></a>`minChar`

```sml
val minChar : char
```

The character with the smallest code, 0.

### <a name="val-maxchar"></a>`maxChar`

```sml
val maxChar : char
```

The character with the largest code, [`maxOrd`](#val-maxord).

### <a name="val-maxord"></a>`maxOrd`

```sml
val maxOrd : int
```

The largest code of a character.

> **Implementation** `Char.maxOrd/value`. 255 for [`Char`](CHAR.md), and 1114111, the
> last code point of Unicode, for [`WideChar`](CHAR.md).

## Codes and order

### <a name="val-ord"></a>`ord`

```sml
val ord : char -> int
```

`ord c` is the code of `c`, between 0 and [`maxOrd`](#val-maxord).

### <a name="val-chr"></a>`chr`

```sml
val chr : int -> char
```

`chr i` is the character whose code is `i`.

**Raises** `Chr` if `i < 0` or `i > maxOrd`.

### <a name="val-succ"></a>`succ`

```sml
val succ : char -> char
```

`succ c` is the character after `c`, the one with the code `ord c + 1`.

**Raises** `Chr` if `c` is [`maxChar`](#val-maxchar).

### <a name="val-pred"></a>`pred`

```sml
val pred : char -> char
```

`pred c` is the character before `c`, the one with the code `ord c - 1`.

**Raises** `Chr` if `c` is [`minChar`](#val-minchar).

### <a name="val-compare"></a>`compare`

```sml
val compare : char * char -> order
```

`compare (c, d)` orders two characters by their codes.

> **Reading** `Char.compare/127-128`. The codes are not negative, so 127 comes
> before 128 and 255 after 0: a character is not a signed byte.

### <a name="val-op-lt"></a><a name="val-op-lt-eq"></a><a name="val-op-gt"></a><a name="val-op-gt-eq"></a>`<`, `<=`, `>`, `>=`

```sml
val < : char * char -> bool
val <= : char * char -> bool
val > : char * char -> bool
val >= : char * char -> bool
```

`c < d`, `c <= d`, `c > d` and `c >= d` compare the codes of two
characters.

## Membership

### <a name="val-contains"></a>`contains`

```sml
val contains : string -> char -> bool
```

`contains s c` is `true` when `c` occurs in the string `s`.

Applied to `s` alone it gives a predicate, which suits the functions that
take one: `String.tokens (contains " ,;")`.

### <a name="val-notcontains"></a>`notContains`

```sml
val notContains : string -> char -> bool
```

`notContains s c` is `true` when `c` does not occur in `s`.

## Classes and case

### <a name="val-isascii"></a>`isAscii`

```sml
val isAscii : char -> bool
```

`isAscii c` is `true` when the code of `c` is at most 127.

> **Reading** `Char.isAlpha/latin1`. The classes below are the sets that the
> specification's discussion lists, whatever the locale: no character
> above 127 is in any of them, and [`toLower`](#val-tolower) and [`toUpper`](#val-toupper) change the 52
> letters of ASCII only.

### <a name="val-tolower"></a>`toLower`

```sml
val toLower : char -> char
```

`toLower c` is the lower case letter for an upper case letter `c`, and `c`
otherwise.

### <a name="val-toupper"></a>`toUpper`

```sml
val toUpper : char -> char
```

`toUpper c` is the upper case letter for a lower case letter `c`, and `c`
otherwise.

### <a name="val-isalpha"></a>`isAlpha`

```sml
val isAlpha : char -> bool
```

`isAlpha c` is `true` for a letter, `A` to `Z` and `a` to `z`.

### <a name="val-isalphanum"></a>`isAlphaNum`

```sml
val isAlphaNum : char -> bool
```

`isAlphaNum c` is `true` for a letter or a decimal digit.

### <a name="val-iscntrl"></a>`isCntrl`

```sml
val isCntrl : char -> bool
```

`isCntrl c` is `true` for a control character: a code below 32, or 127.

### <a name="val-isdigit"></a>`isDigit`

```sml
val isDigit : char -> bool
```

`isDigit c` is `true` for a decimal digit, `0` to `9`.

### <a name="val-isgraph"></a>`isGraph`

```sml
val isGraph : char -> bool
```

`isGraph c` is `true` for a character that leaves a mark when printed:
codes 33 to 126.

### <a name="val-ishexdigit"></a>`isHexDigit`

```sml
val isHexDigit : char -> bool
```

`isHexDigit c` is `true` for a hexadecimal digit: `0` to `9`, `a` to `f`
and `A` to `F`.

### <a name="val-islower"></a>`isLower`

```sml
val isLower : char -> bool
```

`isLower c` is `true` for a lower case letter, `a` to `z`.

### <a name="val-isprint"></a>`isPrint`

```sml
val isPrint : char -> bool
```

`isPrint c` is `true` for a printable character, the space included: codes
32 to 126.

### <a name="val-isspace"></a>`isSpace`

```sml
val isSpace : char -> bool
```

`isSpace c` is `true` for white space: the space and the characters `\t`,
`\n`, `\v`, `\f` and `\r`.

### <a name="val-ispunct"></a>`isPunct`

```sml
val isPunct : char -> bool
```

`isPunct c` is `true` for a graphical character that is neither a letter
nor a digit.

### <a name="val-isupper"></a>`isUpper`

```sml
val isUpper : char -> bool
```

`isUpper c` is `true` for an upper case letter, `A` to `Z`.

## The text of character constants

### <a name="val-tostring"></a>`toString`

```sml
val toString : char -> String.string
```

`toString c` is the text that stands for `c` inside an SML string
constant.

A printable character is itself, except that the backslash and the double
quote get a backslash in front. The control characters with a name are
`\a`, `\b`, `\t`, `\n`, `\v`, `\f` and `\r`; the other codes below 32
are written `\^@` to `\^_`, and codes from 127 up as a backslash and three
decimal digits.

**Example** `toString #"\n" = "\\n"` and `toString #"\255" = "\\255"`

### <a name="val-scan"></a>`scan`

```sml
val scan : (Char.char, 'a) StringCvt.reader -> (char, 'a) StringCvt.reader
```

`scan getc strm` reads one character from `strm` in the notation of SML
string constants.

A printable character other than the backslash stands for itself; a
backslash begins an escape sequence: the named ones, `\^c` for a control
character, `\ddd` with three decimal digits, `\uxxxx` with four
hexadecimal ones, `\\` and `\"`. The answer is `NONE` when the stream
begins with a character that is not printable or with an escape that
is malformed or names no character.

> **Reading** `Char.scan/formatting`. A formatting sequence, a backslash, white
> space and another backslash, stands for nothing. Such sequences are
> passed over before the character, and after it as well, so that what is
> left of the stream never begins with one.

> **Reading** (the suite differs) `Char.fromString/unescaped-double-quote`.
> The specification says that the text is read "as allowed in an SML
> program" and names only characters that do not print and bad escapes as
> what stops a scan. Rune therefore converts a double quote that has no
> backslash to itself, as Poly/ML does; MLton and SML/NJ answer `NONE`,
> and that is what the suite expects.

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : String.string -> char option
```

`fromString s` is the character that the text `s` begins with, read as
[`scan`](#val-scan) reads it, or `NONE`.

**Law** `fromString s = StringCvt.scanString scan s`

> **Reading** `Char.fromString/printable-only-all-rejected`. A first character
> outside the printable range, codes 32 to 126, gives `NONE`, and so does
> a backslash by itself; every other printable character is converted to
> itself.

### <a name="val-tocstring"></a>`toCString`

```sml
val toCString : char -> String.string
```

`toCString c` is the text that stands for `c` inside a C string constant.

A printable character is itself, except that the backslash, the double
quote, the single quote and the question mark get a backslash in front.
The control characters with a name in C are `\a`, `\b`, `\t`, `\n`, `\v`,
`\f` and `\r`; every other character is a backslash and three octal
digits.

### <a name="val-fromcstring"></a>`fromCString`

```sml
val fromCString : String.string -> char option
```

`fromCString s` is the character that the text `s` begins with in the
notation of C, or `NONE`.

The escapes are those of C: the named ones, `\ooo` with one to three
octal digits and `\x` with any number of hexadecimal ones. There are no
formatting sequences, and a double quote without a backslash is
rejected.

> **Reading** `Char.fromCString/hex-huge-does-not-fit`. A `\x` escape whose
> value is no character gives `NONE` however many digits it has:
> `Overflow` is not raised.

> **Reading** `Char.fromCString/printable-only-all-converted`. Every printable
> character but the double quote and the backslash is converted to itself,
> the single quote included; what does not print is rejected.

## See also

[`STRING`](../sig/STRING.md), [`SUBSTRING`](../sig/SUBSTRING.md), [`STRING_CVT`](../sig/STRING_CVT.md)

---

<sub>Generated by runedoc from lib/basis/sig\_char.sml; do not edit.</sub>
