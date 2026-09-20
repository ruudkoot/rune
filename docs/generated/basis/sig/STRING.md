# signature STRING

[The Standard ML Basis Library](../README.md) &rsaquo; **STRING**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 0 of 31 entries documented |
| Tests | 382 checks of 29 entries |
| Source | [lib/basis/sig\_string.sml](../../../../lib/basis/sig_string.sml) |

## Synopsis

```sml
signature STRING
structure String : STRING where type string = string where type char = Char.char
structure WideString :> STRING where type string = WideCharVector.vector where type char = WideChar.char  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `String` | String: 8-bit byte strings. | [lib/basis/string.sml](../../../../lib/basis/string.sml) |
| `WideString` |  | [lib/basis/widestring.sml](../../../../lib/basis/widestring.sml) |

signature STRING, transcribed from <https://smlfamily.github.io/Basis/string.html>

The page writes the types of toString, scan, fromString, toCString and
fromCString with [`String.string`](#type-string), because the signature is also that of
WideString; they are kept as written. The constraints of `structure String :> STRING where type string = string where type string = CharVector.vector where type char = Char.char` are in tests/basis/string\_sig.sml.

## Interface

<pre>
signature STRING =
sig
  eqtype <a href="#type-string">string</a>
  eqtype <a href="#type-char">char</a>

  val <a href="#val-maxsize">maxSize</a> : int
  val <a href="#val-size">size</a> : string -&gt; int
  val <a href="#val-sub">sub</a> : string * int -&gt; char
  val <a href="#val-extract">extract</a> : string * int * int option -&gt; string
  val <a href="#val-substring">substring</a> : string * int * int -&gt; string
  val <a href="#val-op-caret">^</a> : string * string -&gt; string
  val <a href="#val-concat">concat</a> : string list -&gt; string
  val <a href="#val-concatwith">concatWith</a> : string -&gt; string list -&gt; string
  val <a href="#val-str">str</a> : char -&gt; string
  val <a href="#val-implode">implode</a> : char list -&gt; string
  val <a href="#val-explode">explode</a> : string -&gt; char list
  val <a href="#val-map">map</a> : (char -&gt; char) -&gt; string -&gt; string
  val <a href="#val-translate">translate</a> : (char -&gt; string) -&gt; string -&gt; string
  val <a href="#val-tokens">tokens</a> : (char -&gt; bool) -&gt; string -&gt; string list
  val <a href="#val-fields">fields</a> : (char -&gt; bool) -&gt; string -&gt; string list
  val <a href="#val-isprefix">isPrefix</a> : string -&gt; string -&gt; bool
  val <a href="#val-issubstring">isSubstring</a> : string -&gt; string -&gt; bool
  val <a href="#val-issuffix">isSuffix</a> : string -&gt; string -&gt; bool

  val <a href="#val-compare">compare</a> : string * string -&gt; order
  val <a href="#val-collate">collate</a> : (char * char -&gt; order) -&gt; string * string -&gt; order
  val <a href="#val-op-lt">&lt;</a> : string * string -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : string * string -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : string * string -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : string * string -&gt; bool

  val <a href="#val-tostring">toString</a> : string -&gt; String.string
  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (string, 'a) StringCvt.reader
  val <a href="#val-fromstring">fromString</a> : String.string -&gt; string option
  val <a href="#val-tocstring">toCString</a> : string -&gt; String.string
  val <a href="#val-fromcstring">fromCString</a> : String.string -&gt; string option
end
</pre>

### <a name="type-string"></a>`string`

```sml
eqtype string
```

### <a name="type-char"></a>`char`

```sml
eqtype char
```

### <a name="val-maxsize"></a>`maxSize`

```sml
val maxSize : int
```

<details><summary>Tests (3)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `positive` &middot; `holds-a-long-string`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `positive`

</details>

### <a name="val-size"></a>`size`

```sml
val size : string -> int
```

Also in the [top-level environment](../top-level.md): `size`.

<details><summary>Tests (9)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `three` &middot; `nul-inside` &middot; `255` &middot; `escapes` &middot; `long` &middot; `length-explode-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `code-points` &middot; `empty`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : string * int -> char
```

<details><summary>Tests (15)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `first` &middot; `middle` &middot; `last` &middot; `255` &middot; `nul` &middot; `Subscript-size` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-maxInt` (raises Subscript) &middot; `Subscript-minInt` (raises Subscript) &middot; `explode-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `first` &middot; `beyond-the-basic-plane` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-extract"></a>`extract`

```sml
val extract : string * int * int option -> string
```

<details><summary>Tests (30)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `NONE-whole` &middot; `NONE-tail` &middot; `NONE-last` &middot; `NONE-at-size` &middot; `NONE-empty-string` &middot; `NONE-Subscript-beyond-size` (raises Subscript) &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-empty-string` (raises Subscript) &middot; `NONE-Subscript-maxInt` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-zero` &middot; `SOME-zero-at-size` &middot; `SOME-empty-string` &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-end-beyond-size` (raises Subscript) &middot; `SOME-Subscript-start-beyond-size` (raises Subscript) &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-start-zero` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-start` (raises Subscript) &middot; `SOME-law-*` &middot; `NONE-law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `to-the-end` &middot; `a-length` &middot; `empty-at-the-end` &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-substring"></a>`substring`

```sml
val substring : string * int * int -> string
```

Also in the [top-level environment](../top-level.md): `substring`.

<details><summary>Tests (16)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `middle` &middot; `whole` &middot; `to-the-end` &middot; `zero` &middot; `zero-at-size` &middot; `empty-string` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-end-beyond-size` (raises Subscript) &middot; `Subscript-start-beyond-size` (raises Subscript) &middot; `Subscript-negative-start` (raises Subscript) &middot; `Subscript-negative-size` (raises Subscript) &middot; `Subscript-not-Overflow-size` (raises Subscript) &middot; `Subscript-not-Overflow-both` (raises Subscript) &middot; `take-drop-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `middle` &middot; `Subscript-too-long` (raises)

</details>

### <a name="val-op-caret"></a>`^`

```sml
val ^ : string * string -> string
```

Also in the [top-level environment](../top-level.md): `^`.

<details><summary>Tests (9)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `empty-left` &middot; `empty-right` &middot; `empty-both` &middot; `infix` &middot; `nul` &middot; `size-*` &middot; `explode-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `concatenates`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : string list -> string
```

Also in the [top-level environment](../top-level.md): `concat`.

<details><summary>Tests (8)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `nil` &middot; `singleton` &middot; `basic` &middot; `empties` &middot; `long` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `three` &middot; `empty-list`

</details>

### <a name="val-concatwith"></a>`concatWith`

```sml
val concatWith : string -> string list -> string
```

<details><summary>Tests (10)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `nil` &middot; `singleton` &middot; `empty-separator` &middot; `empty-strings` &middot; `singleton-empty` &middot; `long-separator` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `separator` &middot; `one-piece`

</details>

### <a name="val-str"></a>`str`

```sml
val str : char -> string
```

Also in the [top-level environment](../top-level.md): `str`.

<details><summary>Tests (4)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `letter` &middot; `nul` &middot; `size`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `one-character`

</details>

### <a name="val-implode"></a>`implode`

```sml
val implode : char list -> string
```

Also in the [top-level environment](../top-level.md): `implode`.

<details><summary>Tests (6)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `nil` &middot; `bytes` &middot; `explode-*` &middot; `concat-map-str-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `list`

</details>

### <a name="val-explode"></a>`explode`

```sml
val explode : string -> char list
```

Also in the [top-level environment](../top-level.md): `explode`.

<details><summary>Tests (6)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `empty` &middot; `bytes` &middot; `all-characters`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `length` &middot; `order`

</details>

### <a name="val-map"></a>`map`

```sml
val map : (char -> char) -> string -> string
```

<details><summary>Tests (7)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `empty` &middot; `bytes` &middot; `order` &middot; `empty-not-applied` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `to-upper-case`

</details>

### <a name="val-translate"></a>`translate`

```sml
val translate : (char -> string) -> string -> string
```

<details><summary>Tests (7)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `empty` &middot; `all-to-empty` &middot; `double` &middot; `order` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `each-character-to-a-string`

</details>

### <a name="val-tokens"></a>`tokens`

```sml
val tokens : (char -> bool) -> string -> string list
```

<details><summary>Tests (15)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `page-example` &middot; `empty-string` &middot; `no-delimiter` &middot; `one-delimiter-only` &middot; `delimiters-only` &middot; `trailing-delimiter` &middot; `leading-delimiter` &middot; `whitespace` &middot; `several-delimiters` &middot; `every-character-delimits` &middot; `nothing-delimits` &middot; `order` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `runs-collapse` &middot; `only-delimiters`

</details>

### <a name="val-fields"></a>`fields`

```sml
val fields : (char -> bool) -> string -> string list
```

<details><summary>Tests (17)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `page-example` &middot; `empty-string` &middot; `no-delimiter` &middot; `one-delimiter-only` &middot; `delimiters-only` &middot; `trailing-delimiter` &middot; `leading-delimiter` &middot; `commas` &middot; `several-delimiters` &middot; `every-character-delimits` &middot; `nothing-delimits` &middot; `nothing-delimits-empty-string` &middot; `order` &middot; `law-*` &middot; `concatWith-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `every-delimiter-separates` &middot; `no-delimiter`

</details>

### <a name="val-isprefix"></a>`isPrefix`

```sml
val isPrefix : string -> string -> bool
```

<details><summary>Tests (12)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `not` &middot; `empty` &middot; `empty-empty` &middot; `itself` &middot; `longer` &middot; `of-empty` &middot; `differs-at-end` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `yes` &middot; `no` &middot; `empty`

</details>

### <a name="val-issubstring"></a>`isSubstring`

```sml
val isSubstring : string -> string -> bool
```

<details><summary>Tests (18)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `middle` &middot; `prefix` &middot; `suffix` &middot; `not-contiguous` &middot; `empty` &middot; `empty-empty` &middot; `itself` &middot; `longer` &middot; `of-empty` &middot; `after-partial-match` &middot; `after-partial-match-2` &middot; `partial-match-at-end` &middot; `case-matters` &middot; `law-*` &middot; `of-concatenation-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `middle` &middot; `absent` &middot; `empty`

</details>

### <a name="val-issuffix"></a>`isSuffix`

```sml
val isSuffix : string -> string -> bool
```

<details><summary>Tests (11)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `not` &middot; `empty` &middot; `empty-empty` &middot; `itself` &middot; `longer` &middot; `of-empty` &middot; `differs-at-start` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `yes` &middot; `no`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : string * string -> order
```

<details><summary>Tests (18)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `less` &middot; `equal` &middot; `greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `empty-empty` &middot; `empty-less` &middot; `upper-before-lower` &middot; `127-128` &middot; `255-letter` &middot; `nul-after-prefix` &middot; `first-difference-decides` &middot; `law-*` &middot; `law-words-*` &middot; `reflexive-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `by-code-point` &middot; `prefix-is-less` &middot; `equal`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (char * char -> order) -> string * string -> order
```

<details><summary>Tests (11)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `Char.compare` &middot; `reversed-order` &middot; `reversed-order-prefix` &middot; `reversed-order-longer` &middot; `caseless-equal` &middot; `caseless-less` &middot; `empty-empty` &middot; `always-equal-length-decides` &middot; `law-*` &middot; `law-bytes-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `with-a-comparison`

</details>

### <a name="val-op-lt"></a>`<`

```sml
val < : string * string -> bool
```

<details><summary>Tests (8)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `less` &middot; `equal` &middot; `greater` &middot; `prefix` &middot; `127-128` &middot; `law-*` &middot; `law-bytes-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `by-code-point`

</details>

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : string * string -> bool
```

<details><summary>Tests (7)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `less` &middot; `equal` &middot; `greater` &middot; `empty-empty` &middot; `255-0` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `equal`

</details>

### <a name="val-op-gt"></a>`>`

```sml
val > : string * string -> bool
```

<details><summary>Tests (7)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `less` &middot; `equal` &middot; `greater` &middot; `longer` &middot; `255-0` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `longer-with-the-same-prefix`

</details>

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : string * string -> bool
```

<details><summary>Tests (8)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `less` &middot; `equal` &middot; `greater` &middot; `empty-empty` &middot; `127-128` &middot; `law-*` &middot; `law-bytes-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `equal`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : string -> String.string
```

<details><summary>Tests (13)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `printable` &middot; `newline` &middot; `quote-backslash` &middot; `controls` &middot; `two-character-escapes` &middot; `digit-after-decimal-escape` &middot; `all-characters` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `escapes-each-character` &middot; `printable` &middot; `quote-and-newline` &middot; `empty`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (string, 'a) StringCvt.reader
```

<details><summary>Tests (18)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `printable` &middot; `empty` &middot; `space-is-not-skipped` &middot; `stops-at-control-D` &middot; `stops-at-newline` &middot; `stops-at-illegal-escape` &middot; `stops-at-decimal-256` &middot; `NONE-illegal-escape` &middot; `NONE-control-D` &middot; `NONE-format-unterminated` &middot; `format-only` &middot; `format-then-control-D` &middot; `format-inside-and-last` &middot; `escapes` &middot; `indexed-reader` &middot; `scanString`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `reads-wide-characters` &middot; `stops-at-a-character-it-cannot-read`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : String.string -> string option
```

<details><summary>Tests (52)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `printable` &middot; `spaces-are-kept` &middot; `single-quote` &middot; `escape-n` &middot; `two-character-escapes` &middot; `control-escapes` &middot; `u-escape-and-decimal` &middot; `decimal-three-digits-only` &middot; `u-escape-four-digits-only` &middot; `not-printable-stops-at-newline` &middot; `not-printable-stops-at-del` &middot; `not-printable-stops-at-200` &middot; `not-printable-first-newline` &middot; `not-printable-first-control-D` &middot; `not-printable-first-200` &middot; `bad-escape-stops-at-q` &middot; `bad-escape-stops-at-decimal-256` &middot; `bad-escape-stops-at-two-digits` &middot; `bad-escape-stops-at-control-96` &middot; `bad-escape-stops-at-u-0100` &middot; `bad-escape-stops-at-lone-backslash` &middot; `bad-escape-stops-at-C-escape` &middot; `bad-escape-first-q` &middot; `bad-escape-first-lone-backslash` &middot; `bad-escape-first-decimal-256` &middot; `format-inside` &middot; `format-first` &middot; `format-last` &middot; `format-twice` &middot; `format-form-feed` &middot; `format-then-escape` &middot; `format-then-illegal-escape` &middot; `format-unterminated` &middot; `sample-1` &middot; `sample-2` &middot; `sample-3` &middot; `sample-4` &middot; `sample-5` &middot; `sample-6` &middot; `sample-7` &middot; `toString-all-characters` &middot; `unescaped-double-quote` &middot; `unescaped-double-quote-first` &middot; `toString-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `plain` &middot; `escapes` &middot; `escape-u` &middot; `formatting-sequence` &middot; `empty` &middot; `stops-at-what-it-cannot-read` &middot; `round-trip`

</details>

### <a name="val-tocstring"></a>`toCString`

```sml
val toCString : string -> String.string
```

<details><summary>Tests (7)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `printable` &middot; `escaped-printable` &middot; `nul-and-octal` &middot; `nul-then-digit` &middot; `nul-and-all-characters`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `octal-and-escapes`

</details>

### <a name="val-fromcstring"></a>`fromCString`

```sml
val fromCString : String.string -> string option
```

<details><summary>Tests (30)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `printable` &middot; `spaces-are-kept` &middot; `escape-t` &middot; `two-character-escapes` &middot; `unescaped-single-quote` &middot; `unescaped-question-mark` &middot; `unescaped-double-quote` &middot; `unescaped-double-quote-first` &middot; `octal` &middot; `octal-short` &middot; `octal-stops-at-8` &middot; `octal-three-digits-only` &middot; `hex` &middot; `hex-stops-at-G` &middot; `stops-at-hex-longest-sequence` &middot; `control` &middot; `stops-at-illegal-escape` &middot; `stops-at-newline` &middot; `stops-at-octal-400` &middot; `stops-at-hex-100` &middot; `stops-at-hex-without-digits` &middot; `NONE-illegal-escape` &middot; `NONE-newline` &middot; `NONE-lone-backslash` &middot; `toCString-all-characters` &middot; `toCString-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `octal` &middot; `escape-U` &middot; `empty`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_string.sml; do not edit.</sub>
