# signature STRING

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; **STRING**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 31 of 31 entries documented |
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

Strings: immutable sequences of characters, with the operations that take
them apart, put them together, compare them and write them as the text of
a string constant.

A string is indexed from 0 and is of a fixed length, `size s`; there is no
terminating character, so a string may hold any character, the one with
code 0 included. Taking a string apart never copies more than it must, but
every operation that makes one does copy, so building a long string by
repeated [`^`](#val-op-caret) costs time quadratic in the result: collect the pieces in a
list and [`concat`](#val-concat) them once.

The signature is that of [`String`](STRING.md), whose characters are of type [`char`](#type-char), and
of the optional [`WideString`](STRING.md), which is why it specifies a type [`char`](#type-char) of
its own. The strings of the library are compared by their characters'
codes, and that order is what [`<`](#val-op-lt), [`compare`](#val-compare) and [`Substring.compare`](../sig/SUBSTRING.md#val-compare) use.

> **Erratum** `STRING/string-types`. The specification writes the types of
> [`toString`](#val-tostring), [`scan`](#val-scan), [`fromString`](#val-fromstring), [`toCString`](#val-tocstring) and [`fromCString`](#val-fromcstring) with
> [`String.string`](#type-string), because the text of an escape is always of 8-bit
> characters, also for [`WideString`](STRING.md). They are kept as written.

## Contents

[Types and bounds](#types-and-bounds) &middot;
[Taking a string apart](#taking-a-string-apart) &middot;
[Putting strings together](#putting-strings-together) &middot;
[Transforming](#transforming) &middot;
[Splitting](#splitting) &middot;
[Searching](#searching) &middot;
[Comparing](#comparing) &middot;
[The text of string constants](#the-text-of-string-constants)

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

## Types and bounds

### <a name="type-string"></a>`string`

```sml
eqtype string
```

The type of strings of these characters.

> **Implementation** `String.string/bytes`. [`String.string`](#type-string) is the top-level
> [`string`](#type-string), a sequence of 8-bit characters; [`WideString.string`](#type-string) is one of
> [`WideChar.char`](../sig/CHAR.md#type-char).

> **Implementation** `String.string/u-escape-above-255-rejected`. An escape
> `\uXXXX` above 255 in a constant of type [`string`](#type-string) or [`char`](#type-char) is an error
> when the program is compiled, for the characters have eight bits; at
> [`WideString.string`](#type-string) it is a character.

### <a name="type-char"></a>`char`

```sml
eqtype char
```

The type of the characters of such a string: [`Char.char`](../sig/CHAR.md#type-char) for [`String`](STRING.md).

### <a name="val-maxsize"></a>`maxSize`

```sml
val maxSize : int
```

The greatest length a string may have.

> **Implementation** `String.maxSize/value`. 1073741823, which is 2^30 - 1.

> **Implementation** `String.maxSize/Size-is-not-pinned`. With a bound of 2^30
> \- 1 no check of the suite makes a string that is too long: [`Size`](../sig/GENERAL.md#exn-size) from
> [`^`](#val-op-caret), [`concat`](#val-concat), [`implode`](#val-implode) and [`translate`](#val-translate) is raised by the VM when the
> bound is passed, and the suite checks it only on a system whose [`maxSize`](#val-maxsize)
> is at most 2^26. The same holds for [`StringCvt.padLeft`](../sig/STRING_CVT.md#val-padleft) and `padRight`,
> for [`Substring.concat`](../sig/SUBSTRING.md#val-concat) and [`concatWith`](#val-concatwith), and with [`Vector.maxLen`](../sig/VECTOR.md#val-maxlen) for
> [`Vector.concat`](../sig/VECTOR.md#val-concat) and [`VectorSlice.concat`](../sig/VECTOR_SLICE.md#val-concat).

<details><summary>Tests (3)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `positive` &middot; `holds-a-long-string`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `positive`

</details>

## Taking a string apart

### <a name="val-size"></a>`size`

```sml
val size : string -> int
```

`size s` is the number of characters of `s`.

Also in the [top-level environment](../top-level.md): `size`.

<details><summary>Tests (9)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `three` &middot; `nul-inside` &middot; `255` &middot; `escapes` &middot; `long` &middot; `length-explode-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `code-points` &middot; `empty`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : string * int -> char
```

`sub (s, i)` is the character of `s` at position `i`, counting from 0.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= size s`.

<details><summary>Tests (15)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `first` &middot; `middle` &middot; `last` &middot; `255` &middot; `nul` &middot; `Subscript-size` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-maxInt` (raises Subscript) &middot; `Subscript-minInt` (raises Subscript) &middot; `explode-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `first` &middot; `beyond-the-basic-plane` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-extract"></a>`extract`

```sml
val extract : string * int * int option -> string
```

`extract (s, i, NONE)` is the characters of `s` from position `i` on, and `extract (s, i, SOME n)` the `n` characters from `i`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0`, if `i > size s`, or if `n` is given and
`i + n > size s`.

> **Reading** `String.extract/SOME-Subscript-not-Overflow-size`. The bound is
> tested so that it cannot overflow: an `i` and an `n` whose sum is no
> `int` raise [`Subscript`](../sig/GENERAL.md#exn-subscript), not [`Overflow`](../sig/GENERAL.md#exn-overflow).

**Example** `extract ("hello", 2, NONE) = "llo"`

<details><summary>Tests (30)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `NONE-whole` &middot; `NONE-tail` &middot; `NONE-last` &middot; `NONE-at-size` &middot; `NONE-empty-string` &middot; `NONE-Subscript-beyond-size` (raises Subscript) &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-empty-string` (raises Subscript) &middot; `NONE-Subscript-maxInt` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-zero` &middot; `SOME-zero-at-size` &middot; `SOME-empty-string` &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-end-beyond-size` (raises Subscript) &middot; `SOME-Subscript-start-beyond-size` (raises Subscript) &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-start-zero` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-start` (raises Subscript) &middot; `SOME-law-*` &middot; `NONE-law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `to-the-end` &middot; `a-length` &middot; `empty-at-the-end` &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-substring"></a>`substring`

```sml
val substring : string * int * int -> string
```

`substring (s, i, n)` is the `n` characters of `s` from position `i`.

**Law** `substring (s, i, n) = extract (s, i, SOME n)`

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0`, `n < 0` or `i + n > size s`.

**Example** `substring ("hello", 1, 3) = "ell"`

Also in the [top-level environment](../top-level.md): `substring`.

<details><summary>Tests (16)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `middle` &middot; `whole` &middot; `to-the-end` &middot; `zero` &middot; `zero-at-size` &middot; `empty-string` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-end-beyond-size` (raises Subscript) &middot; `Subscript-start-beyond-size` (raises Subscript) &middot; `Subscript-negative-start` (raises Subscript) &middot; `Subscript-negative-size` (raises Subscript) &middot; `Subscript-not-Overflow-size` (raises Subscript) &middot; `Subscript-not-Overflow-both` (raises Subscript) &middot; `take-drop-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `middle` &middot; `Subscript-too-long` (raises)

</details>

## Putting strings together

### <a name="val-op-caret"></a>`^`

```sml
val ^ : string * string -> string
```

`s ^ t` is the characters of `s` followed by those of `t`.

It is infix with precedence 6.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`maxSize`](#val-maxsize).

**Complexity** linear in `size s + size t`; both are copied.

Also in the [top-level environment](../top-level.md): `^`.

<details><summary>Tests (9)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `empty-left` &middot; `empty-right` &middot; `empty-both` &middot; `infix` &middot; `nul` &middot; `size-*` &middot; `explode-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `concatenates`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : string list -> string
```

`concat l` is the strings of `l` one after another.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`maxSize`](#val-maxsize).

**Law** `concat [s, t] = s ^ t`, and `concat [] = ""`

Also in the [top-level environment](../top-level.md): `concat`.

<details><summary>Tests (8)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `nil` &middot; `singleton` &middot; `basic` &middot; `empties` &middot; `long` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `three` &middot; `empty-list`

</details>

### <a name="val-concatwith"></a>`concatWith`

```sml
val concatWith : string -> string list -> string
```

`concatWith sep l` is the strings of `l` one after another with `sep` between them.

There is no separator before the first or after the last, so
`concatWith sep []` is `""` and `concatWith sep [s]` is `s`.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`maxSize`](#val-maxsize).

**Example** `concatWith ", " ["a", "b", "c"] = "a, b, c"`

<details><summary>Tests (10)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `nil` &middot; `singleton` &middot; `empty-separator` &middot; `empty-strings` &middot; `singleton-empty` &middot; `long-separator` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `separator` &middot; `one-piece`

</details>

### <a name="val-str"></a>`str`

```sml
val str : char -> string
```

`str c` is the string of the one character `c`.

Also in the [top-level environment](../top-level.md): `str`.

<details><summary>Tests (4)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `letter` &middot; `nul` &middot; `size`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `one-character`

</details>

### <a name="val-implode"></a>`implode`

```sml
val implode : char list -> string
```

`implode l` is the string of the characters of `l`, in order.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`maxSize`](#val-maxsize).

Also in the [top-level environment](../top-level.md): `implode`.

<details><summary>Tests (6)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `nil` &middot; `bytes` &middot; `explode-*` &middot; `concat-map-str-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `list`

</details>

### <a name="val-explode"></a>`explode`

```sml
val explode : string -> char list
```

`explode s` is the list of the characters of `s`, in order.

**Law** `implode (explode s) = s`

**Example** `explode "ab" = [#"a", #"b"]`

Also in the [top-level environment](../top-level.md): `explode`.

<details><summary>Tests (6)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `empty` &middot; `bytes` &middot; `all-characters`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `length` &middot; `order`

</details>

## Transforming

### <a name="val-map"></a>`map`

```sml
val map : (char -> char) -> string -> string
```

`map f s` is the string of the results of `f` on each character of `s`, from left to right.

<details><summary>Tests (7)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `empty` &middot; `bytes` &middot; `order` &middot; `empty-not-applied` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `to-upper-case`

</details>

### <a name="val-translate"></a>`translate`

```sml
val translate : (char -> string) -> string -> string
```

`translate f s` applies `f` to each character of `s`, from left to right, and appends the strings it gives.

It is [`map`](#val-map) for a function that may give any number of characters for
one, which is how a string is escaped or expanded.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`maxSize`](#val-maxsize).

**Law** `translate f s = concat (List.map f (explode s))`

**Example** `translate (fn #"a" => "4" | c => str c) "banana" = "b4n4n4"`

<details><summary>Tests (7)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `empty` &middot; `all-to-empty` &middot; `double` &middot; `order` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `each-character-to-a-string`

</details>

## Splitting

### <a name="val-tokens"></a>`tokens`

```sml
val tokens : (char -> bool) -> string -> string list
```

`tokens p s` is the non-empty pieces of `s` between the characters that satisfy `p`.

A run of delimiters counts as one, and a delimiter at either end leaves
nothing behind, so this is how a line is split into words.

**Example** `tokens Char.isSpace "  a  b " = ["a", "b"]`

**Law** `tokens p s = List.filter (fn t => size t > 0) (fields p s)`

<details><summary>Tests (15)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `page-example` &middot; `empty-string` &middot; `no-delimiter` &middot; `one-delimiter-only` &middot; `delimiters-only` &middot; `trailing-delimiter` &middot; `leading-delimiter` &middot; `whitespace` &middot; `several-delimiters` &middot; `every-character-delimits` &middot; `nothing-delimits` &middot; `order` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `runs-collapse` &middot; `only-delimiters`

</details>

### <a name="val-fields"></a>`fields`

```sml
val fields : (char -> bool) -> string -> string list
```

`fields p s` is the pieces of `s` that the characters satisfying `p` separate.

Every delimiter ends a field, so `n` delimiters give `n + 1` fields,
empty ones included; this is how a line of a table is read.

**Example** `fields (fn c => c = #",") "a,,b," = ["a", "", "b", ""]`

<details><summary>Tests (17)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `page-example` &middot; `empty-string` &middot; `no-delimiter` &middot; `one-delimiter-only` &middot; `delimiters-only` &middot; `trailing-delimiter` &middot; `leading-delimiter` &middot; `commas` &middot; `several-delimiters` &middot; `every-character-delimits` &middot; `nothing-delimits` &middot; `nothing-delimits-empty-string` &middot; `order` &middot; `law-*` &middot; `concatWith-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `every-delimiter-separates` &middot; `no-delimiter`

</details>

## Searching

### <a name="val-isprefix"></a>`isPrefix`

```sml
val isPrefix : string -> string -> bool
```

`isPrefix p s` is `true` when `s` begins with `p`.

<details><summary>Tests (12)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `not` &middot; `empty` &middot; `empty-empty` &middot; `itself` &middot; `longer` &middot; `of-empty` &middot; `differs-at-end` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `yes` &middot; `no` &middot; `empty`

</details>

### <a name="val-issubstring"></a>`isSubstring`

```sml
val isSubstring : string -> string -> bool
```

`isSubstring p s` is `true` when `p` occurs anywhere in `s`.

The empty string occurs in every string.

**Complexity** the product of the two sizes in the worst case; the search
is the straightforward one.

**Example** `isSubstring "" "abc" = true`

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; isSubstring "" "" is false
- **SML/NJ** &mdash; isSubstring "" "" is false (the law draws two empty strings)

</details>

<details><summary>Tests (18)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `middle` &middot; `prefix` &middot; `suffix` &middot; `not-contiguous` &middot; `empty` &middot; `empty-empty` &middot; `itself` &middot; `longer` &middot; `of-empty` &middot; `after-partial-match` &middot; `after-partial-match-2` &middot; `partial-match-at-end` &middot; `case-matters` &middot; `law-*` &middot; `of-concatenation-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `middle` &middot; `absent` &middot; `empty`

</details>

### <a name="val-issuffix"></a>`isSuffix`

```sml
val isSuffix : string -> string -> bool
```

`isSuffix p s` is `true` when `s` ends with `p`.

<details><summary>Tests (11)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `basic` &middot; `not` &middot; `empty` &middot; `empty-empty` &middot; `itself` &middot; `longer` &middot; `of-empty` &middot; `differs-at-start` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `yes` &middot; `no`

</details>

## Comparing

### <a name="val-compare"></a>`compare`

```sml
val compare : string * string -> order
```

`compare (s, t)` orders two strings by their characters' codes, lexicographically.

A string that is a prefix of another comes before it.

**Law** `compare (s, t) = collate Char.compare (s, t)`

**Example** `compare ("abc", "abd") = LESS`

**Example** `compare ("Z", "a") = LESS` for the capitals come first in ASCII.

<details><summary>Tests (18)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `less` &middot; `equal` &middot; `greater` &middot; `prefix-less` &middot; `prefix-greater` &middot; `empty-empty` &middot; `empty-less` &middot; `upper-before-lower` &middot; `127-128` &middot; `255-letter` &middot; `nul-after-prefix` &middot; `first-difference-decides` &middot; `law-*` &middot; `law-words-*` &middot; `reflexive-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `by-code-point` &middot; `prefix-is-less` &middot; `equal`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (char * char -> order) -> string * string -> order
```

`collate cmp (s, t)` compares two strings lexicographically with `cmp` for the characters.

The answer is that of `cmp` on the first pair of characters at the same
position that are not `EQUAL`; if there is none, the shorter string is
`LESS`.

<details><summary>Tests (11)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `Char.compare` &middot; `reversed-order` &middot; `reversed-order-prefix` &middot; `reversed-order-longer` &middot; `caseless-equal` &middot; `caseless-less` &middot; `empty-empty` &middot; `always-equal-length-decides` &middot; `law-*` &middot; `law-bytes-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `with-a-comparison`

</details>

### <a name="val-op-lt"></a><a name="val-op-lt-eq"></a><a name="val-op-gt"></a><a name="val-op-gt-eq"></a>`<`, `<=`, `>`, `>=`

```sml
val < : string * string -> bool
val <= : string * string -> bool
val > : string * string -> bool
val >= : string * string -> bool
```

`s < t`, `s <= t`, `s > t` and `s >= t` compare two strings as [`compare`](#val-compare) does.

<details><summary>Tests (13)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `less` &middot; `equal` &middot; `greater` &middot; `prefix` &middot; `127-128` &middot; `law-*` &middot; `law-bytes-*` &middot; `empty-empty` &middot; `255-0` &middot; `longer`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `by-code-point` &middot; `equal` &middot; `longer-with-the-same-prefix`

</details>

## The text of string constants

### <a name="val-tostring"></a>`toString`

```sml
val toString : string -> String.string
```

`toString s` is the text that stands for `s` inside an SML string constant.

Every character is written as [`Char.toString`](../sig/CHAR.md#val-tostring) writes it: the printable
ones as themselves, with a backslash before a backslash or a double
quote, and the others as a named escape, `\^c`, or three decimal digits.

**Law** `toString s = translate Char.toString s`

**Example** `toString "a\tb\"" = "a\\tb\\\""`

<details><summary>Tests (13)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `printable` &middot; `newline` &middot; `quote-backslash` &middot; `controls` &middot; `two-character-escapes` &middot; `digit-after-decimal-escape` &middot; `all-characters` &middot; `law-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `escapes-each-character` &middot; `printable` &middot; `quote-and-newline` &middot; `empty`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (string, 'a) StringCvt.reader
```

`scan getc strm` reads the characters that `strm` begins with in the notation of SML string constants.

It reads as many as it can and stops before the first that it cannot,
which makes it total: the answer is `SOME (s, rest)` with the characters
read, and `NONE` only when nothing at all could be read. A formatting
sequence, a backslash, white space and another backslash, stands for
nothing and is passed over, so a stream of one such sequence gives
`SOME ""`.

> **Reading** `String.scan/as-much-as-possible`. "The longest prefix" is
> taken to mean that a character that cannot be read ends the scan rather
> than failing it, and that an escape that is not one (`"a\\q"`) leaves
> what came before it.

> **Reading** `String.fromString/unescaped-double-quote`. A double quote
> without a backslash converts to itself, as in SML/NJ and Poly/ML; MLton
> stops at it. [`Char.scan`](../sig/CHAR.md#val-scan) reads it the same way.

> **Reading** `String.scan/empty-input-is-SOME-empty`. Nothing to read is no
> failure: `fromString ""` is `SOME ""`. `NONE` is for a first character
> that cannot be read, as in `fromString "\\q"`.

**Example** `fromString "" = SOME ""`

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; NONE instead of SOME "" when only an escaped formatting sequence can be scanned

</details>

<details><summary>Tests (18)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `printable` &middot; `empty` &middot; `space-is-not-skipped` &middot; `stops-at-control-D` &middot; `stops-at-newline` &middot; `stops-at-illegal-escape` &middot; `stops-at-decimal-256` &middot; `NONE-illegal-escape` &middot; `NONE-control-D` &middot; `NONE-format-unterminated` &middot; `format-only` &middot; `format-then-control-D` &middot; `format-inside-and-last` &middot; `escapes` &middot; `indexed-reader` &middot; `scanString`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `reads-wide-characters` &middot; `stops-at-a-character-it-cannot-read`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : String.string -> string option
```

`fromString s` is the characters that the text `s` begins with, read as [`scan`](#val-scan) reads them, or `NONE`.

**Law** `fromString s = StringCvt.scanString scan s`

> **Reading** `String.fromString/format-first`. A formatting sequence counts
> as read although it stands for no character, so a text of nothing but
> such a sequence gives `SOME ""`, and so does one that a bad escape
> follows.

**Example** `fromString "a\\nb" = SOME "a\nb"`, where the first text has the
two characters `\` and `n` in it.

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; another reading of the specification: stops at an unescaped double quote; the test takes the reading of SML/NJ and Poly/ML (it converts to itself)
- **SML/NJ** &mdash; NONE instead of SOME "" when only an escaped formatting sequence can be scanned

</details>

<details><summary>Tests (52)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `printable` &middot; `spaces-are-kept` &middot; `single-quote` &middot; `escape-n` &middot; `two-character-escapes` &middot; `control-escapes` &middot; `u-escape-and-decimal` &middot; `decimal-three-digits-only` &middot; `u-escape-four-digits-only` &middot; `not-printable-stops-at-newline` &middot; `not-printable-stops-at-del` &middot; `not-printable-stops-at-200` &middot; `not-printable-first-newline` &middot; `not-printable-first-control-D` &middot; `not-printable-first-200` &middot; `bad-escape-stops-at-q` &middot; `bad-escape-stops-at-decimal-256` &middot; `bad-escape-stops-at-two-digits` &middot; `bad-escape-stops-at-control-96` &middot; `bad-escape-stops-at-u-0100` &middot; `bad-escape-stops-at-lone-backslash` &middot; `bad-escape-stops-at-C-escape` &middot; `bad-escape-first-q` &middot; `bad-escape-first-lone-backslash` &middot; `bad-escape-first-decimal-256` &middot; `format-inside` &middot; `format-first` &middot; `format-last` &middot; `format-twice` &middot; `format-form-feed` &middot; `format-then-escape` &middot; `format-then-illegal-escape` &middot; `format-unterminated` &middot; `sample-1` &middot; `sample-2` &middot; `sample-3` &middot; `sample-4` &middot; `sample-5` &middot; `sample-6` &middot; `sample-7` &middot; `toString-all-characters` &middot; `unescaped-double-quote` &middot; `unescaped-double-quote-first` &middot; `toString-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `plain` &middot; `escapes` &middot; `escape-u` &middot; `formatting-sequence` &middot; `empty` &middot; `stops-at-what-it-cannot-read` &middot; `round-trip`

</details>

### <a name="val-tocstring"></a>`toCString`

```sml
val toCString : string -> String.string
```

`toCString s` is the text that stands for `s` inside a C string constant.

Every character is written as [`Char.toCString`](../sig/CHAR.md#val-tocstring) writes it, so the single
quote and the question mark are escaped as well, and what does not print
becomes a backslash and three octal digits.

**Example** `toCString "a\n?" = "a\\n\\?"`

<details><summary>Tests (7)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `printable` &middot; `escaped-printable` &middot; `nul-and-octal` &middot; `nul-then-digit` &middot; `nul-and-all-characters`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `octal-and-escapes`

</details>

### <a name="val-fromcstring"></a>`fromCString`

```sml
val fromCString : String.string -> string option
```

`fromCString s` is the characters that the text `s` begins with in the notation of C, or `NONE`.

There are no formatting sequences in C, and a double quote without a
backslash is not a character of a constant, so it ends the scan.

> **Reading** `String.fromCString/stops-at-hex-longest-sequence`. A `\x`
> escape takes "the longest sequence" of hexadecimal digits: `"\x42C"` is
> one escape of the value 1068, which is no character, and not `\x42`
> followed by `C`.

**Example** `fromCString "\\x41" = SOME "A"`

<details><summary>Other implementations (4)</summary>

- **MLton, SML/NJ, Poly/ML** &mdash; converts an unescaped double quote, which the specification says fromCString does not accept
- **SML/NJ** &mdash; fromCString does not accept \\^c
- **MLton** &mdash; SOME "" instead of NONE when no character can be converted
- **SML/NJ** &mdash; fromCString returns NONE unless the whole string converts

</details>

<details><summary>Tests (30)</summary>

For `String`, in [tests/basis/string.sml](../../../../tests/basis/string.sml): `empty` &middot; `printable` &middot; `spaces-are-kept` &middot; `escape-t` &middot; `two-character-escapes` &middot; `unescaped-single-quote` &middot; `unescaped-question-mark` &middot; `unescaped-double-quote` &middot; `unescaped-double-quote-first` &middot; `octal` &middot; `octal-short` &middot; `octal-stops-at-8` &middot; `octal-three-digits-only` &middot; `hex` &middot; `hex-stops-at-G` &middot; `stops-at-hex-longest-sequence` &middot; `control` &middot; `stops-at-illegal-escape` &middot; `stops-at-newline` &middot; `stops-at-octal-400` &middot; `stops-at-hex-100` &middot; `stops-at-hex-without-digits` &middot; `NONE-illegal-escape` &middot; `NONE-newline` &middot; `NONE-lone-backslash` &middot; `toCString-all-characters` &middot; `toCString-*`

For `WideString`, in [tests/basis/widestring.sml](../../../../tests/basis/widestring.sml): `octal` &middot; `escape-U` &middot; `empty`

</details>

## See also

[`CHAR`](../sig/CHAR.md), [`SUBSTRING`](../sig/SUBSTRING.md), [`STRING_CVT`](../sig/STRING_CVT.md), [`TEXT`](../sig/TEXT.md), [`MONO_VECTOR`](../sig/MONO_VECTOR.md)

---

<sub>Generated by runedoc from lib/basis/sig\_string.sml; do not edit.</sub>
