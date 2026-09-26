# signature STRING_CVT

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; **STRING_CVT**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 11 of 11 entries documented |
| Tests | 138 checks of 10 entries |
| Source | [lib/basis/sig\_string\_cvt.sml](../../../../lib/basis/sig_string_cvt.sml) |

## Synopsis

```sml
signature STRING_CVT
structure StringCvt : STRING_CVT
```

| Implementation |  | Source |
| --- | --- | --- |
| [`StringCvt`](../str/StringCvt.md) | StringCvt: the types and helpers of the fmt and scan functions. Written on primitives, without another structure, because most others require it. | [lib/basis/stringcvt.sml](../../../../lib/basis/stringcvt.sml) |

The types and helpers of the conversions between values and text: the
formats of `fmt`, the readers of `scan`.

Every `scan` function of the library reads from a functional character
stream: a value of any type `'b` together with a reader, a function that
gives the next character and the rest of the stream, or `NONE` at the end.
A scanner takes a reader of characters and gives a reader of values, so it
works alike on strings, lists of characters, substrings and input streams,
and a program can build scanners of its own out of those of the library and
the helpers below. Nothing is consumed by a scan that fails: the caller
still has the stream it passed.

## Contents

[Formats](#formats) &middot;
[Readers](#readers) &middot;
[Padding](#padding) &middot;
[Building scanners](#building-scanners) &middot;
[Scanning a string](#scanning-a-string)

## Interface

<pre>
signature STRING_CVT =
sig
  datatype <a href="#type-radix">radix</a>
    = <a href="#con-bin">BIN</a>
    | <a href="#con-oct">OCT</a>
    | <a href="#con-dec">DEC</a>
    | <a href="#con-hex">HEX</a>
  datatype <a href="#type-realfmt">realfmt</a>
    = <a href="#con-sci">SCI</a> of int option
    | <a href="#con-fix">FIX</a> of int option
    | <a href="#con-gen">GEN</a> of int option
    | <a href="#con-exact">EXACT</a>
  type ('a, 'b) <a href="#type-reader">reader</a> = 'b -&gt; ('a * 'b) option
  val <a href="#val-padleft">padLeft</a> : char -&gt; int -&gt; string -&gt; string
  val <a href="#val-padright">padRight</a> : char -&gt; int -&gt; string -&gt; string
  val <a href="#val-splitl">splitl</a> : (char -&gt; bool) -&gt; (char, 'a) reader -&gt; 'a -&gt; string * 'a
  val <a href="#val-takel">takel</a> : (char -&gt; bool) -&gt; (char, 'a) reader -&gt; 'a -&gt; string
  val <a href="#val-dropl">dropl</a> : (char -&gt; bool) -&gt; (char, 'a) reader -&gt; 'a -&gt; 'a
  val <a href="#val-skipws">skipWS</a> : (char, 'a) reader -&gt; 'a -&gt; 'a
  type <a href="#type-cs">cs</a>
  val <a href="#val-scanstring">scanString</a> : ((char, cs) reader -&gt; ('a, cs) reader) -&gt; string -&gt; 'a option
end
</pre>

## Formats

### <a name="type-radix"></a>`radix`

```sml
datatype radix
  = BIN
  | OCT
  | DEC
  | HEX
```

The base in which [`Int.fmt`](../sig/INTEGER.md#val-fmt), [`Word.fmt`](../sig/WORD.md#val-fmt) and their `scan` functions write
and read a number.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-bin"></a>`BIN` |  | base 2 |
| <a name="con-oct"></a>`OCT` |  | base 8 |
| <a name="con-dec"></a>`DEC` |  | base 10 |
| <a name="con-hex"></a>`HEX` |  | base 16; the digits above 9 are written `A` to `F` and read in either case |

<details><summary>Tests (2)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `equal-to-itself` &middot; `four-distinct-values`

</details>

### <a name="type-realfmt"></a>`realfmt`

```sml
datatype realfmt
  = SCI of int option
  | FIX of int option
  | GEN of int option
  | EXACT
```

The notation in which [`Real.fmt`](../sig/REAL.md#val-fmt) writes a real number.

The argument is a number of digits; `NONE` asks for the default.

> **Reading** `StringCvt.SCI/carries-negative`. A constructor carries any
> `int option`, also one that no format accepts, such as `SCI (SOME ~1)`:
> [`Size`](../sig/GENERAL.md#exn-size) is raised by `fmt`, not by the constructor.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-sci"></a>`SCI` | `int option` | scientific notation, `[~]d.dddE[~]dd`, with that many digits after the point; 6 by default |
| <a name="con-fix"></a>`FIX` | `int option` | fixed-point notation, `[~]ddd.ddd`, with that many digits after the point; 6 by default |
| <a name="con-gen"></a>`GEN` | `int option` | the shorter of [`SCI`](#con-sci) and [`FIX`](#con-fix), with at most that many significant digits; 12 by default |
| <a name="con-exact"></a>`EXACT` |  | every digit needed to read the same real back |

<details><summary>Tests (3)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `equality` &middot; `constructors-differ` &middot; `arguments-differ`

</details>

## Readers

### <a name="type-reader"></a>`reader`

```sml
type ('a, 'b) reader = 'b -> ('a * 'b) option
```

A reader of values of type `'a` from a stream of type `'b`: `NONE` at the
end of the stream, otherwise the next value and the rest of the stream.

<details><summary>Tests (2)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `is-the-function-type` &middot; `Bool.scan-List.getItem`

</details>

## Padding

### <a name="val-padleft"></a>`padLeft`

```sml
val padLeft : char -> int -> string -> string
```

`padLeft c i s` is `s` with enough copies of `c` on its left to make it
`i` characters long.

A string that has `i` characters or more is returned as it is, also for a
negative `i`.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `i` is larger than [`String.maxSize`](../sig/STRING.md#val-maxsize) and `s` is shorter
than `i`.

**Example** `padLeft #"0" 5 "42" = "00042"`

> **Reading** `StringCvt.padLeft/width-minInt`. For the smallest `int` the
> difference `i - size s` does not exist as an `int`; `s` is returned all
> the same, and [`Overflow`](../sig/GENERAL.md#exn-overflow) is not raised.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; padLeft and padRight raise Overflow for the smallest int (they compute i - \| s \| ) instead of returning s

</details>

<details><summary>Tests (19)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `basic` &middot; `other-character` &middot; `one-short` &middot; `empty-string` &middot; `nul-character` &middot; `width-equals-size` &middot; `width-below-size` &middot; `width-one` &middot; `width-zero` &middot; `width-zero-empty-string` &middot; `width-negative` &middot; `width-negative-empty-string` &middot; `width-minInt` &middot; `partial-application` &middot; `long` &middot; `Size` (raises Size) &middot; `Size-empty-string` (raises Size) &middot; `law-*` &middot; `law-size-*`

</details>

### <a name="val-padright"></a>`padRight`

```sml
val padRight : char -> int -> string -> string
```

`padRight c i s` is `s` with enough copies of `c` on its right to make it
`i` characters long.

A string that has `i` characters or more is returned as it is.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `i` is larger than [`String.maxSize`](../sig/STRING.md#val-maxsize) and `s` is shorter
than `i`.

**Example** `padRight #"." 5 "ab" = "ab..."`

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; padLeft and padRight raise Overflow for the smallest int (they compute i - \| s \| ) instead of returning s

</details>

<details><summary>Tests (19)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `basic` &middot; `other-character` &middot; `one-short` &middot; `empty-string` &middot; `character-255` &middot; `width-equals-size` &middot; `width-below-size` &middot; `width-one` &middot; `width-zero` &middot; `width-zero-empty-string` &middot; `width-negative` &middot; `width-negative-empty-string` &middot; `width-minInt` &middot; `partial-application` &middot; `long` &middot; `Size` (raises Size) &middot; `Size-empty-string` (raises Size) &middot; `law-*` &middot; `law-size-*`

</details>

## Building scanners

### <a name="val-splitl"></a>`splitl`

```sml
val splitl : (char -> bool) -> (char, 'a) reader -> 'a -> string * 'a
```

`splitl p getc strm` is the string of the characters at the front of
`strm` that satisfy `p`, and the rest of the stream.

The rest begins with the first character that does not satisfy `p`.

> **Reading** `StringCvt.splitl/reads-no-further-than-first-failing`. "Will
> often use lookahead characters" is taken to mean exactly one: the
> character that stops the scan is read from the source, and nothing after
> it.

**Example** `splitl Char.isDigit List.getItem (explode "12ab") = ("12", [#"a", #"b"])`

<details><summary>Tests (24)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `list-basic` &middot; `list-none-satisfy` &middot; `list-all-satisfy` &middot; `list-empty-source` &middot; `list-one-satisfies` &middot; `list-one-fails` &middot; `always-true` &middot; `always-false` &middot; `string-basic` &middot; `string-from-the-middle` &middot; `string-to-the-end` &middot; `string-at-the-end` &middot; `string-empty` &middot; `all-256-characters` &middot; `first-of-remainder-is-leftmost-failing` &middot; `other-source` &middot; `predicate-order` &middot; `reads-no-further-than-first-failing` &middot; `reads-from-the-source-given` &middot; `reader-raises` (raises Fail) &middot; `predicate-raises` (raises Div) &middot; `law-string-*` &middot; `law-list-*` &middot; `law-parts-make-the-whole-*`

</details>

### <a name="val-takel"></a>`takel`

```sml
val takel : (char -> bool) -> (char, 'a) reader -> 'a -> string
```

`takel p getc strm` is the string of the characters at the front of `strm`
that satisfy `p`.

**Law** `takel p getc strm = #1 (splitl p getc strm)`

<details><summary>Tests (10)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `list-basic` &middot; `none-satisfy` &middot; `all-satisfy` &middot; `empty-source` &middot; `string-from-the-middle` &middot; `maximal-prefix-only` &middot; `predicate-order` &middot; `reads-no-further-than-first-failing` &middot; `law-*` &middot; `law-is-first-of-splitl-*`

</details>

### <a name="val-dropl"></a>`dropl`

```sml
val dropl : (char -> bool) -> (char, 'a) reader -> 'a -> 'a
```

`dropl p getc strm` is `strm` without the characters at its front that
satisfy `p`.

**Law** `dropl p getc strm = #2 (splitl p getc strm)`

**Example** `implode (dropl Char.isSpace List.getItem (explode "  x")) = "x"`

<details><summary>Tests (11)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `list-basic` &middot; `none-satisfy` &middot; `all-satisfy` &middot; `empty-source` &middot; `string-basic` &middot; `string-from-the-middle` &middot; `maximal-prefix-only` &middot; `predicate-order` &middot; `reads-no-further-than-first-failing` &middot; `law-*` &middot; `law-is-second-of-splitl-*`

</details>

### <a name="val-skipws"></a>`skipWS`

```sml
val skipWS : (char, 'a) reader -> 'a -> 'a
```

`skipWS getc strm` is `strm` without the white space at its front.

White space is what [`Char.isSpace`](../sig/CHAR.md#val-isspace) accepts.

**Law** `skipWS getc strm = dropl Char.isSpace getc strm`

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; skipWS skips space, tab and newline only, not carriage return, vertical tab and formfeed

</details>

<details><summary>Tests (15)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `spaces` &middot; `space-tab-newline` &middot; `wsx-every-whitespace-character` &middot; `no-whitespace` &middot; `only-whitespace` &middot; `empty-source` &middot; `string-basic` &middot; `string-from-the-middle` &middot; `string-at-non-whitespace` &middot; `string-at-the-end` &middot; `wsx-exactly-the-six-characters` &middot; `other-characters-stay` &middot; `reads-no-further-than-first-non-whitespace` &middot; `law-*` &middot; `law-is-dropl-isSpace-*`

</details>

## Scanning a string

### <a name="type-cs"></a>`cs`

```sml
type cs
```

The stream that [`scanString`](#val-scanstring) makes of a string: a scanner can do nothing
with it but read it.

### <a name="val-scanstring"></a>`scanString`

```sml
val scanString : ((char, cs) reader -> ('a, cs) reader) -> string -> 'a option
```

`scanString scan s` applies the scanner `scan` to the characters of `s`,
from the first.

The answer is `SOME v` when `scan` reads a value `v`, whatever follows it
in `s`, and `NONE` when it reads none. This is how every `fromString` of
the library is made from its `scan`.

**Example** `scanString (Int.scan DEC) "12abc" = SOME 12`

<details><summary>Tests (33)</summary>

For `StringCvt`, in [tests/basis/stringcvt.sml](../../../../tests/basis/stringcvt.sml): `page-example-splitl` &middot; `splitl-nothing-satisfies` &middot; `splitl-empty-string` &middot; `source-is-the-string` &middot; `source-of-empty-string` &middot; `source-of-all-256-characters` &middot; `source-of-long-string` &middot; `first-character` &middot; `first-character-of-empty-string` &middot; `NONE` &middot; `nothing-read` &middot; `nothing-read-empty-string` &middot; `rest-is-ignored` &middot; `too-short-for-the-scanner` &middot; `state-can-be-read-again` &middot; `end-can-be-read-again` &middot; `scanner-applied-once` &middot; `scanner-raises` (raises Fail) &middot; `skipWS-then-takel` &middot; `skipWS-then-takel-NONE` &middot; `dropl-then-whole` &middot; `splitl-reads-one-character-ahead` &middot; `Bool.scan` &middot; `Bool.scan-rest-is-ignored` &middot; `Bool.scan-NONE` &middot; `Int.scan` &middot; `Int.scan-rest-is-ignored` &middot; `Int.scan-NONE` &middot; `Int.scan-empty-string` &middot; `composed-scanner` &middot; `law-whole-*` &middot; `law-splitl-*` &middot; `law-skipWS-*`

</details>

## See also

[`CHAR`](../sig/CHAR.md), [`STRING`](../sig/STRING.md), [`SUBSTRING`](../sig/SUBSTRING.md), [`TEXT_IO`](../sig/TEXT_IO.md)

---

<sub>Generated by runedoc from lib/basis/sig\_string\_cvt.sml; do not edit.</sub>
