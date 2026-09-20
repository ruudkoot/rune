# signature SUBSTRING

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; **SUBSTRING**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 39 of 39 entries documented |
| Tests | 574 checks of 38 entries |
| Source | [lib/basis/sig\_substring.sml](../../../../lib/basis/sig_substring.sml) |

## Synopsis

```sml
signature SUBSTRING
structure Substring : SUBSTRING where type string = string where type char = Char.char
structure WideSubstring :> SUBSTRING where type substring = WideCharVectorSlice.slice where type string = WideCharVector.vector where type char = WideChar.char
```

| Implementation |  | Source |
| --- | --- | --- |
| `Substring` | Substring: a string, a start index and a length. | [lib/basis/substring.sml](../../../../lib/basis/substring.sml) |
| `WideSubstring` |  | [lib/basis/widestring.sml](../../../../lib/basis/widestring.sml) |

A stretch of a string, without a copy of it: a base string and a start and
a length inside it.

Taking a substring apart is free where taking a string apart is not, so a
program that scans text works on substrings and makes a string only of what
it keeps. The three numbers are what [`base`](#val-base) gives back; `full s` is the
whole of `s`, `string ss` copies the stretch out. The functions that split
come in pairs, one for each end: `l` takes from the left and `r` from the
right.

The signature is that of [`Substring`](SUBSTRING.md), over [`String`](../sig/STRING.md), and of the optional
[`WideSubstring`](SUBSTRING.md).

> **Erratum** `SUBSTRING/span-exception`. The specification does not say in the
> signature that [`span`](#val-span) raises an exception, although its description does;
> the exception is [`General.Span`](../sig/GENERAL.md#exn-span).

## Contents

[Types](#types) &middot;
[Taking a substring apart](#taking-a-substring-apart) &middot;
[Making a substring](#making-a-substring) &middot;
[Trimming and slicing](#trimming-and-slicing) &middot;
[Putting substrings together](#putting-substrings-together) &middot;
[Searching](#searching) &middot;
[Comparing](#comparing) &middot;
[Splitting](#splitting) &middot;
[Transforming](#transforming) &middot;
[Traversing](#traversing)

## Interface

<pre>
signature SUBSTRING =
sig

  type <a href="#type-substring">substring</a>

  eqtype <a href="#type-char">char</a>

  eqtype <a href="#type-string">string</a>

  val <a href="#val-sub">sub</a> : substring * int -&gt; char

  val <a href="#val-size">size</a> : substring -&gt; int

  val <a href="#val-base">base</a> : substring -&gt; string * int * int

  val <a href="#val-extract">extract</a> : string * int * int option -&gt; substring

  val <a href="#val-substring">substring</a> : string * int * int -&gt; substring

  val <a href="#val-full">full</a> : string -&gt; substring

  val <a href="#val-string">string</a> : substring -&gt; string

  val <a href="#val-isempty">isEmpty</a> : substring -&gt; bool

  val <a href="#val-getc">getc</a> : substring -&gt; (char * substring) option

  val <a href="#val-first">first</a> : substring -&gt; char option

  val <a href="#val-triml">triml</a> : int -&gt; substring -&gt; substring

  val <a href="#val-trimr">trimr</a> : int -&gt; substring -&gt; substring

  val <a href="#val-slice">slice</a> : substring * int * int option -&gt; substring

  val <a href="#val-concat">concat</a> : substring list -&gt; string

  val <a href="#val-concatwith">concatWith</a> : string -&gt; substring list -&gt; string

  val <a href="#val-explode">explode</a> : substring -&gt; char list

  val <a href="#val-isprefix">isPrefix</a> : string -&gt; substring -&gt; bool

  val <a href="#val-issubstring">isSubstring</a> : string -&gt; substring -&gt; bool

  val <a href="#val-issuffix">isSuffix</a> : string -&gt; substring -&gt; bool

  val <a href="#val-compare">compare</a> : substring * substring -&gt; order

  val <a href="#val-collate">collate</a> : (char * char -&gt; order) -&gt; substring * substring -&gt; order

  val <a href="#val-splitl">splitl</a> : (char -&gt; bool) -&gt; substring -&gt; substring * substring

  val <a href="#val-splitr">splitr</a> : (char -&gt; bool) -&gt; substring -&gt; substring * substring

  val <a href="#val-splitat">splitAt</a> : substring * int -&gt; substring * substring

  val <a href="#val-dropl">dropl</a> : (char -&gt; bool) -&gt; substring -&gt; substring

  val <a href="#val-dropr">dropr</a> : (char -&gt; bool) -&gt; substring -&gt; substring

  val <a href="#val-takel">takel</a> : (char -&gt; bool) -&gt; substring -&gt; substring

  val <a href="#val-taker">taker</a> : (char -&gt; bool) -&gt; substring -&gt; substring

  val <a href="#val-position">position</a> : string -&gt; substring -&gt; substring * substring

  val <a href="#val-span">span</a> : substring * substring -&gt; substring

  val <a href="#val-translate">translate</a> : (char -&gt; string) -&gt; substring -&gt; string

  val <a href="#val-tokens">tokens</a> : (char -&gt; bool) -&gt; substring -&gt; substring list

  val <a href="#val-fields">fields</a> : (char -&gt; bool) -&gt; substring -&gt; substring list

  val <a href="#val-app">app</a> : (char -&gt; unit) -&gt; substring -&gt; unit

  val <a href="#val-foldl">foldl</a> : (char * 'a -&gt; 'a) -&gt; 'a -&gt; substring -&gt; 'a

  val <a href="#val-foldr">foldr</a> : (char * 'a -&gt; 'a) -&gt; 'a -&gt; substring -&gt; 'a
end
</pre>

## Types

### <a name="type-substring"></a>`substring`

```sml
type substring
```

The type of substrings: a base string, a start in it and a length.

> **Implementation** `Substring.substring/slice`. It is
> [`CharVectorSlice.slice`](../sig/MONO_VECTOR_SLICE.md#val-slice), the slice of a vector of characters, so the two
> structures describe one type.

<details><summary>Tests (30)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `whole` &middot; `to-the-end` &middot; `zero-at-start` &middot; `zero-inside` &middot; `zero-at-size` &middot; `empty-string` &middot; `string-middle` &middot; `string-zero` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-end-beyond-size` (raises Subscript) &middot; `Subscript-start-beyond-size` (raises Subscript) &middot; `Subscript-negative-start` (raises Subscript) &middot; `Subscript-negative-start-zero-size` (raises Subscript) &middot; `Subscript-negative-size` (raises Subscript) &middot; `Subscript-negative-size-at-size` (raises Subscript) &middot; `Subscript-negative-size-end-inside` (raises Subscript) &middot; `Subscript-both-negative` (raises Subscript) &middot; `Subscript-empty-string-size` (raises Subscript) &middot; `Subscript-empty-string-start` (raises Subscript) &middot; `Subscript-on-every-invalid-argument` &middot; `Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `Subscript-not-Overflow-start-zero-size` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-start` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-size` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-both` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-and-largest` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `middle`

</details>

### <a name="type-char"></a>`char`

```sml
eqtype char
```

The type of the characters: [`Char.char`](../sig/CHAR.md#type-char) for [`Substring`](SUBSTRING.md).

### <a name="type-string"></a>`string`

```sml
eqtype string
```

The type of the strings these are substrings of.

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `empty` &middot; `whole` &middot; `last-character` &middot; `String.substring-of-base` &middot; `characters-0-and-255` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `gives-the-characters`

</details>

## Taking a substring apart

### <a name="val-sub"></a>`sub`

```sml
val sub : substring * int -> char
```

`sub (ss, i)` is the character of `ss` at position `i`, counting from the start of the substring.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i >= size ss`.

<details><summary>Tests (18)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `first` &middot; `inside` &middot; `last` &middot; `whole-string` &middot; `every-index` &middot; `Subscript-at-size` (raises Subscript) &middot; `Subscript-beyond-size` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-negative-before-the-string` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-empty-string` (raises Subscript) &middot; `Subscript-whole-string-at-size` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-smallest` (raises Subscript) &middot; `law-*` &middot; `law-Subscript-*` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `first` &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-size"></a>`size`

```sml
val size : substring -> int
```

`size ss` is the number of characters of `ss`.

<details><summary>Tests (10)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `empty` &middot; `whole` &middot; `empty-string` &middot; `third-of-base` &middot; `size-of-string` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `whole` &middot; `part`

</details>

### <a name="val-base"></a>`base`

```sml
val base : substring -> string * int * int
```

`base ss` is the triple of the string that `ss` is a stretch of, where it starts in that string, and how long it is.

**Law** `base (substring (s, i, n)) = (s, i, n)`

<details><summary>Tests (5)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `basic` &middot; `empty` &middot; `identity-on-every-valid-argument` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `string-start-length`

</details>

## Making a substring

### <a name="val-extract"></a>`extract`

```sml
val extract : string * int * int option -> substring
```

`extract (s, i, NONE)` is the stretch of `s` from position `i` to its end, and `extract (s, i, SOME n)` the `n` characters from `i`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0`, if `i > String.size s`, or if `n` is
given and `i + n > String.size s`.

> **Implementation** `Substring.extract/no-overflow`. The bounds are tested
> so that they cannot overflow: an `i` and an `n` whose sum is no `int`
> raise [`Subscript`](../sig/GENERAL.md#exn-subscript), not [`Overflow`](../sig/GENERAL.md#exn-overflow).

<details><summary>Tests (33)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `NONE-whole` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-size` &middot; `NONE-empty-string` &middot; `NONE-string` &middot; `NONE-Subscript-beyond-size` (raises Subscript) &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-empty-string` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-zero-inside` &middot; `SOME-zero-at-size` &middot; `SOME-empty-string` &middot; `SOME-string` &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-end-beyond-size` (raises Subscript) &middot; `SOME-Subscript-start-beyond-size` (raises Subscript) &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-end-inside` (raises Subscript) &middot; `SOME-is-substring` &middot; `NONE-every-argument` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-smallest-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-smallest` (raises Subscript) &middot; `law-SOME-*` &middot; `law-NONE-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `to-the-end` &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-substring"></a>`substring`

```sml
val substring : string * int * int -> substring
```

`substring (s, i, n)` is the `n` characters of `s` from position `i`.

**Law** `substring (s, i, n) = extract (s, i, SOME n)`

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0`, `n < 0` or `i + n > String.size s`.

<details><summary>Tests (30)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `whole` &middot; `to-the-end` &middot; `zero-at-start` &middot; `zero-inside` &middot; `zero-at-size` &middot; `empty-string` &middot; `string-middle` &middot; `string-zero` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-end-beyond-size` (raises Subscript) &middot; `Subscript-start-beyond-size` (raises Subscript) &middot; `Subscript-negative-start` (raises Subscript) &middot; `Subscript-negative-start-zero-size` (raises Subscript) &middot; `Subscript-negative-size` (raises Subscript) &middot; `Subscript-negative-size-at-size` (raises Subscript) &middot; `Subscript-negative-size-end-inside` (raises Subscript) &middot; `Subscript-both-negative` (raises Subscript) &middot; `Subscript-empty-string-size` (raises Subscript) &middot; `Subscript-empty-string-start` (raises Subscript) &middot; `Subscript-on-every-invalid-argument` &middot; `Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `Subscript-not-Overflow-start-zero-size` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-start` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-size` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-both` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-and-largest` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `middle`

</details>

### <a name="val-full"></a>`full`

```sml
val full : string -> substring
```

`full s` is the whole of `s` as a substring.

<details><summary>Tests (7)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `basic` &middot; `empty-string` &middot; `one-character` &middot; `string` &middot; `all-256-characters` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `whole-string`

</details>

### <a name="val-string"></a>`string`

```sml
val string : substring -> string
```

`string ss` is the characters of `ss` as a string of their own.

This is where the copy happens.

**Law** `string (full s) = s`

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `empty` &middot; `whole` &middot; `last-character` &middot; `String.substring-of-base` &middot; `characters-0-and-255` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `gives-the-characters`

</details>

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : substring -> bool
```

`isEmpty ss` is `true` when `ss` has no characters.

**Law** `isEmpty ss = (size ss = 0)`

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `empty-string` &middot; `empty-inside` &middot; `empty-at-size` &middot; `empty-at-start` &middot; `one-character` &middot; `middle` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `empty` &middot; `not-empty`

</details>

### <a name="val-getc"></a>`getc`

```sml
val getc : substring -> (char * substring) option
```

`getc ss` is `NONE` for the empty substring and `SOME (c, rest)` for the first character and what follows it.

It has the shape of a [`StringCvt.reader`](../sig/STRING_CVT.md#type-reader), so a substring is a stream
that a `scan` function can read from.

<details><summary>Tests (14)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `whole` &middot; `one-character` &middot; `last-of-string` &middot; `NONE-empty-inside` &middot; `NONE-empty-string` &middot; `reads-the-substring` &middot; `reader-for-StringCvt.splitl` &middot; `reader-for-StringCvt.skipWS` &middot; `reader-for-Int.scan` &middot; `reader-stops-at-the-end` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `first-and-rest` &middot; `NONE-when-empty`

</details>

### <a name="val-first"></a>`first`

```sml
val first : substring -> char option
```

`first ss` is `SOME` of the first character of `ss`, or `NONE` when it is empty.

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `whole` &middot; `one-character` &middot; `NONE-empty-inside` &middot; `NONE-empty-at-size` &middot; `NONE-empty-string` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `character` &middot; `NONE-when-empty`

</details>

## Trimming and slicing

### <a name="val-triml"></a>`triml`

```sml
val triml : int -> substring -> substring
```

`triml k ss` is `ss` without its first `k` characters, or empty when it has at most `k`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `k < 0`.

> **Reading** `Substring.triml/Subscript-negative-k`. The specification says
> that the exception is raised "when `triml k` is evaluated", before the
> substring is given, so a partial application with a negative `k` raises
> at once.

<details><summary>Tests (20)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `one` &middot; `zero` &middot; `three` &middot; `size` &middot; `zero-of-empty` &middot; `string` &middot; `beyond-size` &middot; `far-beyond-size` &middot; `beyond-size-of-empty` &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-negative-empty` (raises Subscript) &middot; `Subscript-when-k-is-given` (raises Subscript) &middot; `partial-application` &middot; `largest-k` &middot; `Subscript-smallest-k` (raises Subscript) &middot; `law-*` &middot; `law-beyond-size-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `drops-from-the-left` &middot; `more-than-the-size` &middot; `Subscript-negative` (raises)

</details>

### <a name="val-trimr"></a>`trimr`

```sml
val trimr : int -> substring -> substring
```

`trimr k ss` is `ss` without its last `k` characters, or empty when it has at most `k`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `k < 0`, when `trimr k` is evaluated.

<details><summary>Tests (20)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `one` &middot; `zero` &middot; `three` &middot; `size` &middot; `zero-of-empty` &middot; `string` &middot; `beyond-size` &middot; `far-beyond-size` &middot; `beyond-size-of-empty` &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-negative-empty` (raises Subscript) &middot; `Subscript-when-k-is-given` (raises Subscript) &middot; `partial-application` &middot; `largest-k` &middot; `Subscript-smallest-k` (raises Subscript) &middot; `law-*` &middot; `law-beyond-size-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `drops-from-the-right` &middot; `more-than-the-size` &middot; `Subscript-negative` (raises)

</details>

### <a name="val-slice"></a>`slice`

```sml
val slice : substring * int * int option -> substring
```

`slice (ss, i, NONE)` is the stretch of `ss` from position `i` on, and `slice (ss, i, SOME n)` the `n` characters from `i`.

The positions are those of `ss`, not of its base string, and the result
is a substring of the same base.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0`, if `i > size ss`, or if `n` is given and
`i + n > size ss`.

<details><summary>Tests (36)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `SOME-inside` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-zero-at-start` &middot; `SOME-zero-at-size` &middot; `SOME-of-empty` &middot; `NONE-whole` &middot; `NONE-inside` &middot; `NONE-at-size` &middot; `NONE-of-empty` &middot; `SOME-string` &middot; `NONE-string` &middot; `of-a-slice` &middot; `SOME-Subscript-end-beyond-size` (raises Subscript) &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-start-beyond-size` (raises Subscript) &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-end-inside` (raises Subscript) &middot; `SOME-Subscript-of-empty` (raises Subscript) &middot; `NONE-Subscript-beyond-size` (raises Subscript) &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-of-empty` (raises Subscript) &middot; `SOME-every-argument` &middot; `NONE-every-argument` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-smallest-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-smallest` (raises Subscript) &middot; `law-SOME-*` &middot; `law-NONE-*` &middot; `law-Subscript-*` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `part-of-a-part` &middot; `Subscript-too-long` (raises)

</details>

## Putting substrings together

### <a name="val-concat"></a>`concat`

```sml
val concat : substring list -> string
```

`concat l` is the string of the substrings of `l`, one after another.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`String.maxSize`](../sig/STRING.md#val-maxsize).

<details><summary>Tests (12)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `nil` &middot; `one` &middot; `several-strings` &middot; `with-empty-substrings` &middot; `only-empty-substrings` &middot; `overlapping` &middot; `many` &middot; `Size` (raises Size) &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `two` &middot; `empty-list`

</details>

### <a name="val-concatwith"></a>`concatWith`

```sml
val concatWith : string -> substring list -> string
```

`concatWith sep l` is the string of the substrings of `l` with `sep` between them.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer than [`String.maxSize`](../sig/STRING.md#val-maxsize).

<details><summary>Tests (12)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `nil` &middot; `one` &middot; `two` &middot; `several-strings` &middot; `empty-separator` &middot; `empty-substrings-are-separated` &middot; `empty-substring-first-and-last` &middot; `one-empty` &middot; `Size` (raises Size) &middot; `Size-by-the-separators` (raises Size) &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `separator`

</details>

### <a name="val-explode"></a>`explode`

```sml
val explode : substring -> char list
```

`explode ss` is the list of the characters of `ss`, in order.

<details><summary>Tests (8)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `empty` &middot; `empty-string` &middot; `whole` &middot; `one-character` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `characters`

</details>

## Searching

### <a name="val-isprefix"></a>`isPrefix`

```sml
val isPrefix : string -> substring -> bool
```

`isPrefix s ss` is `true` when `ss` begins with the string `s`.

<details><summary>Tests (14)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `true` &middot; `one-character` &middot; `whole` &middot; `empty-string` &middot; `empty-of-empty` &middot; `nonempty-of-empty` &middot; `goes-on-in-the-underlying-string` &middot; `prefix-of-the-underlying-string` &middot; `starts-before` &middot; `inside-only` &middot; `differs-at-the-end` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `yes` &middot; `no`

</details>

### <a name="val-issubstring"></a>`isSubstring`

```sml
val isSubstring : string -> substring -> bool
```

`isSubstring s ss` is `true` when `s` occurs anywhere in `ss`.

<details><summary>Tests (17)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `inside` &middot; `prefix` &middot; `suffix` &middot; `whole` &middot; `empty-string` &middot; `empty-of-empty` &middot; `nonempty-of-empty` &middot; `ends-after` &middot; `starts-before` &middot; `contains-the-substring` &middot; `elsewhere-in-the-underlying-string` &middot; `not-contiguous` &middot; `after-a-partial-match` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `middle` &middot; `absent`

</details>

### <a name="val-issuffix"></a>`isSuffix`

```sml
val isSuffix : string -> substring -> bool
```

`isSuffix s ss` is `true` when `ss` ends with the string `s`.

<details><summary>Tests (15)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `true` &middot; `one-character` &middot; `whole` &middot; `empty-string` &middot; `empty-of-empty` &middot; `nonempty-of-empty` &middot; `starts-in-the-underlying-string` &middot; `suffix-of-the-underlying-string` &middot; `ends-after` &middot; `inside-only` &middot; `differs-at-the-start` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `yes` &middot; `no`

</details>

## Comparing

### <a name="val-compare"></a>`compare`

```sml
val compare : substring * substring -> order
```

`compare (ss, tt)` orders two substrings by their characters, lexicographically.

What they are substrings of does not matter: only the characters they
hold.

**Law** `compare (ss, tt) = String.compare (string ss, string tt)`

<details><summary>Tests (19)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `less` &middot; `greater` &middot; `equal` &middot; `prefix-is-less` &middot; `longer-is-greater` &middot; `first-difference-decides` &middot; `empty-empty` &middot; `empty-less` &middot; `upper-before-lower` &middot; `character-255-last` &middot; `equal-in-different-strings` &middot; `equal-at-different-places` &middot; `same-start-different-size` &middot; `what-follows-does-not-count` &middot; `long` &middot; `law-*` &middot; `law-same-string-*` &middot; `law-antisymmetric-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `by-code-point`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (char * char -> order) -> substring * substring -> order
```

`collate cmp (ss, tt)` compares two substrings lexicographically with `cmp` for the characters.

<details><summary>Tests (13)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `Char.compare` &middot; `reversed-order` &middot; `reversed-order-prefix` &middot; `reversed-order-longer` &middot; `caseless-equal` &middot; `caseless-less` &middot; `empty-empty` &middot; `always-equal-size-decides` &middot; `inside-strings` &middot; `order` &middot; `law-*` &middot; `law-reversed-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `with-a-comparison`

</details>

## Splitting

### <a name="val-splitl"></a>`splitl`

```sml
val splitl : (char -> bool) -> substring -> substring * substring
```

`splitl p ss` is the pair of the longest prefix of `ss` whose characters satisfy `p` and the rest.

**Law** `splitl p ss = (takel p ss, dropl p ss)`

<details><summary>Tests (14)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `page-example-strings` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `first-fails` &middot; `last-fails` &middot; `stops-at-the-end-of-the-substring` &middot; `first-failing-of-several` &middot; `order` &middot; `order-all-satisfy` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `letters-then-the-rest`

</details>

### <a name="val-splitr"></a>`splitr`

```sml
val splitr : (char -> bool) -> substring -> substring * substring
```

`splitr p ss` is the pair of what comes before the longest suffix whose characters satisfy `p`, and that suffix.

<details><summary>Tests (14)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `page-example-strings` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `last-fails` &middot; `first-fails` &middot; `stops-at-the-start-of-the-substring` &middot; `first-failing-of-several` &middot; `order` &middot; `order-all-satisfy` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `digits-at-the-end`

</details>

### <a name="val-splitat"></a>`splitAt`

```sml
val splitAt : substring * int -> substring * substring
```

`splitAt (ss, i)` is the pair of the first `i` characters of `ss` and the rest.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or `i > size ss`.

<details><summary>Tests (15)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-smallest` (raises Subscript) &middot; `inside` &middot; `zero` &middot; `size` &middot; `empty` &middot; `whole-string` &middot; `Subscript-beyond-size` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-empty-negative` (raises Subscript) &middot; `law-*` &middot; `law-Subscript-*` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `at-an-index` &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-dropl"></a>`dropl`

```sml
val dropl : (char -> bool) -> substring -> substring
```

`dropl p ss` is `ss` without the characters at its front that satisfy `p`.

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `within-the-substring` &middot; `whitespace` &middot; `order` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `letters`

</details>

### <a name="val-dropr"></a>`dropr`

```sml
val dropr : (char -> bool) -> substring -> substring
```

`dropr p ss` is `ss` without the characters at its end that satisfy `p`.

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `within-the-substring` &middot; `whitespace` &middot; `order` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `digits`

</details>

### <a name="val-takel"></a>`takel`

```sml
val takel : (char -> bool) -> substring -> substring
```

`takel p ss` is the longest prefix of `ss` whose characters satisfy `p`.

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `within-the-substring` &middot; `digits` &middot; `order` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `letters`

</details>

### <a name="val-taker"></a>`taker`

```sml
val taker : (char -> bool) -> substring -> substring
```

`taker p ss` is the longest suffix of `ss` whose characters satisfy `p`.

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `within-the-substring` &middot; `digits` &middot; `order` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `digits`

</details>

### <a name="val-position"></a>`position`

```sml
val position : string -> substring -> substring * substring
```

`position s ss` is the pair of what comes before the first occurrence of `s` in `ss`, and the rest from that occurrence on.

When `s` does not occur, the first component is all of `ss` and the
second is empty at its end, so the two always fit back together. The
empty string occurs at once, which makes the first component empty.

**Law** `let val (pref, suff) = position s ss in concat [pref, suff] = string ss end`

> **Erratum** `Substring.position/none-ends-after-the-substring`. The
> specification describes the second component as "the longest suffix of
> `ss` that has `s` as a prefix", and then writes the condition on the
> index in a way that forgets that the occurrence has to lie inside `ss`:
> an `s` that begins in `ss` and runs past its end is not an occurrence.

<details><summary>Tests (28)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `first-occurrence` &middot; `at-the-start` &middot; `at-the-end` &middot; `whole` &middot; `one-character` &middot; `overlapping-occurrences` &middot; `after-a-partial-match` &middot; `inside-a-string` &middot; `strings` &middot; `none` &middot; `none-whole-string` &middot; `none-longer-than-the-substring` &middot; `none-only-before-the-substring` &middot; `none-only-after-the-substring` &middot; `none-starts-before-the-substring` &middot; `none-ends-after-the-substring` &middot; `none-in-empty` &middot; `none-in-empty-string` &middot; `empty-string` &middot; `empty-string-in-empty` &middot; `empty-string-in-empty-string` &middot; `empty-string-at-the-end` &middot; `long` &middot; `long-none` &middot; `law-*` &middot; `law-span-restores-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `found` &middot; `not-found`

</details>

### <a name="val-span"></a>`span`

```sml
val span : substring * substring -> substring
```

`span (ss, tt)` is the stretch from the start of `ss` to the end of `tt`.

Both must be substrings of one string, and `tt` must not end before `ss`
begins; this is how the pieces that [`splitl`](#val-splitl) and [`position`](#val-position) gave are put
back together.

**Raises** [`Span`](../sig/GENERAL.md#exn-span) if they are substrings of different strings, or if `tt`
ends before `ss` starts.

> **Reading** `Substring.span/equal-strings-built-separately`. "Unless `s <> s'`" is read as a comparison of the base strings by value: two equal
> strings that were built separately count as one base.

<details><summary>Tests (31)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `apart` &middot; `adjacent` &middot; `overlapping` &middot; `same` &middot; `whole` &middot; `empty-and-empty-same-place` &middot; `empty-to-empty` &middot; `second-inside-first` &middot; `first-ends-to-the-right` &middot; `second-begins-to-the-left` &middot; `second-ends-at-start-of-first` &middot; `empty-second-at-start-of-first` &middot; `Span-second-ends-before-first` (raises Span) &middot; `Span-second-ends-one-before-first` (raises Span) &middot; `Span-empty-ones-in-the-wrong-order` (raises Span) &middot; `Span-whole-string-ends` (raises Span) &middot; `Span-different-strings` (raises Span) &middot; `Span-different-strings-same-substrings` (raises Span) &middot; `Span-string-and-its-prefix` (raises Span) &middot; `Span-empty-string-and-another` (raises Span) &middot; `Span-is-General.Span` (raises) &middot; `equal-strings-built-separately` &middot; `page-example` &middot; `page-example-string` &middot; `law-*` (raises Span) &middot; `law-*` &middot; `law-restores-splitl-*` &middot; `law-restores-splitr-*` &middot; `law-restores-splitAt-*` &middot; `law-first-to-last-field-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `from-the-one-to-the-other` &middot; `Span-in-the-wrong-order` (raises)

</details>

## Transforming

### <a name="val-translate"></a>`translate`

```sml
val translate : (char -> string) -> substring -> string
```

`translate f ss` applies `f` to each character of `ss`, from left to right, and appends the strings it gives.

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `basic` &middot; `empty-results` &middot; `all-empty-results` &middot; `empty` &middot; `longer-results` &middot; `order` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `each-character-to-a-string`

</details>

### <a name="val-tokens"></a>`tokens`

```sml
val tokens : (char -> bool) -> substring -> substring list
```

`tokens p ss` is the non-empty pieces of `ss` between the characters that satisfy `p`.

A run of delimiters counts as one, and the pieces are substrings of the
same base string, so nothing is copied.

**Law** `tokens p ss = List.filter (fn t => not (isEmpty t)) (fields p ss)`

<details><summary>Tests (16)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `page-example-strings` &middot; `empty` &middot; `empty-string` &middot; `no-delimiter` &middot; `delimiters-only` &middot; `trailing-delimiter` &middot; `inside-a-string` &middot; `inside-a-string-with-delimiters` &middot; `every-character-delimits` &middot; `whitespace` &middot; `order` &middot; `long` &middot; `law-*` &middot; `law-other-delimiters-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `runs-collapse`

</details>

### <a name="val-fields"></a>`fields`

```sml
val fields : (char -> bool) -> substring -> substring list
```

`fields p ss` is the pieces of `ss` that the characters satisfying `p` separate.

Every delimiter ends a field, so `n` delimiters give `n + 1` fields,
empty ones included.

<details><summary>Tests (17)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `page-example-strings` &middot; `empty` &middot; `empty-string` &middot; `no-delimiter` &middot; `delimiters-only` &middot; `trailing-delimiter` &middot; `inside-a-string` &middot; `inside-a-string-with-delimiters` &middot; `every-character-delimits` &middot; `commas` &middot; `order` &middot; `long` &middot; `law-*` &middot; `law-other-delimiters-*` &middot; `law-concatWith-restores-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `every-delimiter-separates`

</details>

## Traversing

### <a name="val-app"></a>`app`

```sml
val app : (char -> unit) -> substring -> unit
```

`app f ss` applies `f` to every character of `ss`, from left to right, for its effect.

<details><summary>Tests (7)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `order` &middot; `empty` &middot; `whole` &middot; `returns-unit` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `in-order`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (char * 'a -> 'a) -> 'a -> substring -> 'a
```

`foldl f init ss` combines the characters of `ss` from the left, as [`List.foldl`](../sig/LIST.md#val-foldl) does.

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `conses-reversed` &middot; `appends` &middot; `nonassociative` &middot; `empty` &middot; `counts` &middot; `order` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `sums-the-code-points`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (char * 'a -> 'a) -> 'a -> substring -> 'a
```

`foldr f init ss` combines the characters of `ss` from the right, as [`List.foldr`](../sig/LIST.md#val-foldr) does.

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `conses-in-order` &middot; `appends` &middot; `nonassociative` &middot; `empty` &middot; `counts` &middot; `order` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `from-the-right`

</details>

## See also

[`STRING`](../sig/STRING.md), [`CHAR`](../sig/CHAR.md), [`STRING_CVT`](../sig/STRING_CVT.md), [`TEXT`](../sig/TEXT.md), [`MONO_VECTOR_SLICE`](../sig/MONO_VECTOR_SLICE.md)

---

<sub>Generated by runedoc from lib/basis/sig\_substring.sml; do not edit.</sub>
