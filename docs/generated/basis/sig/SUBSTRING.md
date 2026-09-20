# signature SUBSTRING

[The Standard ML Basis Library](../README.md) &rsaquo; **SUBSTRING**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 0 of 39 entries documented |
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

signature SUBSTRING, transcribed from <https://smlfamily.github.io/Basis/substring.html>

The constraints of `structure Substring :> SUBSTRING where type substring = CharVectorSlice.slice where type string = String.string where type char = Char.char` are in tests/basis/substring\_sig.sml. The exception Span that
span raises is that of General; the signature does not specify it.

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

### <a name="type-substring"></a>`substring`

```sml
type substring
```

<details><summary>Tests (30)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `whole` &middot; `to-the-end` &middot; `zero-at-start` &middot; `zero-inside` &middot; `zero-at-size` &middot; `empty-string` &middot; `string-middle` &middot; `string-zero` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-end-beyond-size` (raises Subscript) &middot; `Subscript-start-beyond-size` (raises Subscript) &middot; `Subscript-negative-start` (raises Subscript) &middot; `Subscript-negative-start-zero-size` (raises Subscript) &middot; `Subscript-negative-size` (raises Subscript) &middot; `Subscript-negative-size-at-size` (raises Subscript) &middot; `Subscript-negative-size-end-inside` (raises Subscript) &middot; `Subscript-both-negative` (raises Subscript) &middot; `Subscript-empty-string-size` (raises Subscript) &middot; `Subscript-empty-string-start` (raises Subscript) &middot; `Subscript-on-every-invalid-argument` &middot; `Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `Subscript-not-Overflow-start-zero-size` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-start` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-size` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-both` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-and-largest` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `middle`

</details>

### <a name="type-char"></a>`char`

```sml
eqtype char
```

### <a name="type-string"></a>`string`

```sml
eqtype string
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `empty` &middot; `whole` &middot; `last-character` &middot; `String.substring-of-base` &middot; `characters-0-and-255` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `gives-the-characters`

</details>

### <a name="val-sub"></a>`sub`

```sml
val sub : substring * int -> char
```

<details><summary>Tests (18)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `first` &middot; `inside` &middot; `last` &middot; `whole-string` &middot; `every-index` &middot; `Subscript-at-size` (raises Subscript) &middot; `Subscript-beyond-size` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-negative-before-the-string` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-empty-string` (raises Subscript) &middot; `Subscript-whole-string-at-size` (raises Subscript) &middot; `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-smallest` (raises Subscript) &middot; `law-*` &middot; `law-Subscript-*` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `first` &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-size"></a>`size`

```sml
val size : substring -> int
```

<details><summary>Tests (10)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `empty` &middot; `whole` &middot; `empty-string` &middot; `third-of-base` &middot; `size-of-string` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `whole` &middot; `part`

</details>

### <a name="val-base"></a>`base`

```sml
val base : substring -> string * int * int
```

<details><summary>Tests (5)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `basic` &middot; `empty` &middot; `identity-on-every-valid-argument` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `string-start-length`

</details>

### <a name="val-extract"></a>`extract`

```sml
val extract : string * int * int option -> substring
```

<details><summary>Tests (33)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `NONE-whole` &middot; `NONE-middle` &middot; `NONE-last` &middot; `NONE-at-size` &middot; `NONE-empty-string` &middot; `NONE-string` &middot; `NONE-Subscript-beyond-size` (raises Subscript) &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-empty-string` (raises Subscript) &middot; `SOME-middle` &middot; `SOME-whole` &middot; `SOME-zero-inside` &middot; `SOME-zero-at-size` &middot; `SOME-empty-string` &middot; `SOME-string` &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-end-beyond-size` (raises Subscript) &middot; `SOME-Subscript-start-beyond-size` (raises Subscript) &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-end-inside` (raises Subscript) &middot; `SOME-is-substring` &middot; `NONE-every-argument` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-smallest-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-smallest` (raises Subscript) &middot; `law-SOME-*` &middot; `law-NONE-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `to-the-end` &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-substring"></a>`substring`

```sml
val substring : string * int * int -> substring
```

<details><summary>Tests (30)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `whole` &middot; `to-the-end` &middot; `zero-at-start` &middot; `zero-inside` &middot; `zero-at-size` &middot; `empty-string` &middot; `string-middle` &middot; `string-zero` &middot; `Subscript-too-long` (raises Subscript) &middot; `Subscript-end-beyond-size` (raises Subscript) &middot; `Subscript-start-beyond-size` (raises Subscript) &middot; `Subscript-negative-start` (raises Subscript) &middot; `Subscript-negative-start-zero-size` (raises Subscript) &middot; `Subscript-negative-size` (raises Subscript) &middot; `Subscript-negative-size-at-size` (raises Subscript) &middot; `Subscript-negative-size-end-inside` (raises Subscript) &middot; `Subscript-both-negative` (raises Subscript) &middot; `Subscript-empty-string-size` (raises Subscript) &middot; `Subscript-empty-string-start` (raises Subscript) &middot; `Subscript-on-every-invalid-argument` &middot; `Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `Subscript-not-Overflow-start-zero-size` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-start` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-size` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-both` (raises Subscript) &middot; `Subscript-not-Overflow-smallest-and-largest` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `middle`

</details>

### <a name="val-full"></a>`full`

```sml
val full : string -> substring
```

<details><summary>Tests (7)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `basic` &middot; `empty-string` &middot; `one-character` &middot; `string` &middot; `all-256-characters` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `whole-string`

</details>

### <a name="val-string"></a>`string`

```sml
val string : substring -> string
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `empty` &middot; `whole` &middot; `last-character` &middot; `String.substring-of-base` &middot; `characters-0-and-255` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `gives-the-characters`

</details>

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : substring -> bool
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `empty-string` &middot; `empty-inside` &middot; `empty-at-size` &middot; `empty-at-start` &middot; `one-character` &middot; `middle` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `empty` &middot; `not-empty`

</details>

### <a name="val-getc"></a>`getc`

```sml
val getc : substring -> (char * substring) option
```

<details><summary>Tests (14)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `whole` &middot; `one-character` &middot; `last-of-string` &middot; `NONE-empty-inside` &middot; `NONE-empty-string` &middot; `reads-the-substring` &middot; `reader-for-StringCvt.splitl` &middot; `reader-for-StringCvt.skipWS` &middot; `reader-for-Int.scan` &middot; `reader-stops-at-the-end` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `first-and-rest` &middot; `NONE-when-empty`

</details>

### <a name="val-first"></a>`first`

```sml
val first : substring -> char option
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `whole` &middot; `one-character` &middot; `NONE-empty-inside` &middot; `NONE-empty-at-size` &middot; `NONE-empty-string` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `character` &middot; `NONE-when-empty`

</details>

### <a name="val-triml"></a>`triml`

```sml
val triml : int -> substring -> substring
```

<details><summary>Tests (20)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `one` &middot; `zero` &middot; `three` &middot; `size` &middot; `zero-of-empty` &middot; `string` &middot; `beyond-size` &middot; `far-beyond-size` &middot; `beyond-size-of-empty` &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-negative-empty` (raises Subscript) &middot; `Subscript-when-k-is-given` (raises Subscript) &middot; `partial-application` &middot; `largest-k` &middot; `Subscript-smallest-k` (raises Subscript) &middot; `law-*` &middot; `law-beyond-size-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `drops-from-the-left` &middot; `more-than-the-size` &middot; `Subscript-negative` (raises)

</details>

### <a name="val-trimr"></a>`trimr`

```sml
val trimr : int -> substring -> substring
```

<details><summary>Tests (20)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `one` &middot; `zero` &middot; `three` &middot; `size` &middot; `zero-of-empty` &middot; `string` &middot; `beyond-size` &middot; `far-beyond-size` &middot; `beyond-size-of-empty` &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-negative-empty` (raises Subscript) &middot; `Subscript-when-k-is-given` (raises Subscript) &middot; `partial-application` &middot; `largest-k` &middot; `Subscript-smallest-k` (raises Subscript) &middot; `law-*` &middot; `law-beyond-size-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `drops-from-the-right` &middot; `more-than-the-size` &middot; `Subscript-negative` (raises)

</details>

### <a name="val-slice"></a>`slice`

```sml
val slice : substring * int * int option -> substring
```

<details><summary>Tests (36)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `SOME-inside` &middot; `SOME-whole` &middot; `SOME-to-the-end` &middot; `SOME-zero-at-start` &middot; `SOME-zero-at-size` &middot; `SOME-of-empty` &middot; `NONE-whole` &middot; `NONE-inside` &middot; `NONE-at-size` &middot; `NONE-of-empty` &middot; `SOME-string` &middot; `NONE-string` &middot; `of-a-slice` &middot; `SOME-Subscript-end-beyond-size` (raises Subscript) &middot; `SOME-Subscript-too-long` (raises Subscript) &middot; `SOME-Subscript-start-beyond-size` (raises Subscript) &middot; `SOME-Subscript-negative-start` (raises Subscript) &middot; `SOME-Subscript-negative-size` (raises Subscript) &middot; `SOME-Subscript-negative-size-end-inside` (raises Subscript) &middot; `SOME-Subscript-of-empty` (raises Subscript) &middot; `NONE-Subscript-beyond-size` (raises Subscript) &middot; `NONE-Subscript-negative` (raises Subscript) &middot; `NONE-Subscript-of-empty` (raises Subscript) &middot; `SOME-every-argument` &middot; `NONE-every-argument` &middot; `SOME-Subscript-not-Overflow-sum-size` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-start` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-sum-both` (raises Subscript) &middot; `SOME-Subscript-not-Overflow-smallest-size` (raises Subscript) &middot; `NONE-Subscript-not-Overflow` (raises Subscript) &middot; `NONE-Subscript-not-Overflow-smallest` (raises Subscript) &middot; `law-SOME-*` &middot; `law-NONE-*` &middot; `law-Subscript-*` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `part-of-a-part` &middot; `Subscript-too-long` (raises)

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : substring list -> string
```

<details><summary>Tests (12)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `nil` &middot; `one` &middot; `several-strings` &middot; `with-empty-substrings` &middot; `only-empty-substrings` &middot; `overlapping` &middot; `many` &middot; `Size` (raises Size) &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `two` &middot; `empty-list`

</details>

### <a name="val-concatwith"></a>`concatWith`

```sml
val concatWith : string -> substring list -> string
```

<details><summary>Tests (12)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `nil` &middot; `one` &middot; `two` &middot; `several-strings` &middot; `empty-separator` &middot; `empty-substrings-are-separated` &middot; `empty-substring-first-and-last` &middot; `one-empty` &middot; `Size` (raises Size) &middot; `Size-by-the-separators` (raises Size) &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `separator`

</details>

### <a name="val-explode"></a>`explode`

```sml
val explode : substring -> char list
```

<details><summary>Tests (8)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `middle` &middot; `empty` &middot; `empty-string` &middot; `whole` &middot; `one-character` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `characters`

</details>

### <a name="val-isprefix"></a>`isPrefix`

```sml
val isPrefix : string -> substring -> bool
```

<details><summary>Tests (14)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `true` &middot; `one-character` &middot; `whole` &middot; `empty-string` &middot; `empty-of-empty` &middot; `nonempty-of-empty` &middot; `goes-on-in-the-underlying-string` &middot; `prefix-of-the-underlying-string` &middot; `starts-before` &middot; `inside-only` &middot; `differs-at-the-end` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `yes` &middot; `no`

</details>

### <a name="val-issubstring"></a>`isSubstring`

```sml
val isSubstring : string -> substring -> bool
```

<details><summary>Tests (17)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `inside` &middot; `prefix` &middot; `suffix` &middot; `whole` &middot; `empty-string` &middot; `empty-of-empty` &middot; `nonempty-of-empty` &middot; `ends-after` &middot; `starts-before` &middot; `contains-the-substring` &middot; `elsewhere-in-the-underlying-string` &middot; `not-contiguous` &middot; `after-a-partial-match` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `middle` &middot; `absent`

</details>

### <a name="val-issuffix"></a>`isSuffix`

```sml
val isSuffix : string -> substring -> bool
```

<details><summary>Tests (15)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `true` &middot; `one-character` &middot; `whole` &middot; `empty-string` &middot; `empty-of-empty` &middot; `nonempty-of-empty` &middot; `starts-in-the-underlying-string` &middot; `suffix-of-the-underlying-string` &middot; `ends-after` &middot; `inside-only` &middot; `differs-at-the-start` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `yes` &middot; `no`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : substring * substring -> order
```

<details><summary>Tests (19)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `less` &middot; `greater` &middot; `equal` &middot; `prefix-is-less` &middot; `longer-is-greater` &middot; `first-difference-decides` &middot; `empty-empty` &middot; `empty-less` &middot; `upper-before-lower` &middot; `character-255-last` &middot; `equal-in-different-strings` &middot; `equal-at-different-places` &middot; `same-start-different-size` &middot; `what-follows-does-not-count` &middot; `long` &middot; `law-*` &middot; `law-same-string-*` &middot; `law-antisymmetric-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `by-code-point`

</details>

### <a name="val-collate"></a>`collate`

```sml
val collate : (char * char -> order) -> substring * substring -> order
```

<details><summary>Tests (13)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `Char.compare` &middot; `reversed-order` &middot; `reversed-order-prefix` &middot; `reversed-order-longer` &middot; `caseless-equal` &middot; `caseless-less` &middot; `empty-empty` &middot; `always-equal-size-decides` &middot; `inside-strings` &middot; `order` &middot; `law-*` &middot; `law-reversed-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `with-a-comparison`

</details>

### <a name="val-splitl"></a>`splitl`

```sml
val splitl : (char -> bool) -> substring -> substring * substring
```

<details><summary>Tests (14)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `page-example-strings` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `first-fails` &middot; `last-fails` &middot; `stops-at-the-end-of-the-substring` &middot; `first-failing-of-several` &middot; `order` &middot; `order-all-satisfy` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `letters-then-the-rest`

</details>

### <a name="val-splitr"></a>`splitr`

```sml
val splitr : (char -> bool) -> substring -> substring * substring
```

<details><summary>Tests (14)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `page-example-strings` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `last-fails` &middot; `first-fails` &middot; `stops-at-the-start-of-the-substring` &middot; `first-failing-of-several` &middot; `order` &middot; `order-all-satisfy` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `digits-at-the-end`

</details>

### <a name="val-splitat"></a>`splitAt`

```sml
val splitAt : substring * int -> substring * substring
```

<details><summary>Tests (15)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `Subscript-not-Overflow` (raises Subscript) &middot; `Subscript-not-Overflow-smallest` (raises Subscript) &middot; `inside` &middot; `zero` &middot; `size` &middot; `empty` &middot; `whole-string` &middot; `Subscript-beyond-size` (raises Subscript) &middot; `Subscript-negative` (raises Subscript) &middot; `Subscript-empty` (raises Subscript) &middot; `Subscript-empty-negative` (raises Subscript) &middot; `law-*` &middot; `law-Subscript-*` (raises Subscript)

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `at-an-index` &middot; `Subscript-past-the-end` (raises)

</details>

### <a name="val-dropl"></a>`dropl`

```sml
val dropl : (char -> bool) -> substring -> substring
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `within-the-substring` &middot; `whitespace` &middot; `order` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `letters`

</details>

### <a name="val-dropr"></a>`dropr`

```sml
val dropr : (char -> bool) -> substring -> substring
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `within-the-substring` &middot; `whitespace` &middot; `order` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `digits`

</details>

### <a name="val-takel"></a>`takel`

```sml
val takel : (char -> bool) -> substring -> substring
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `within-the-substring` &middot; `digits` &middot; `order` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `letters`

</details>

### <a name="val-taker"></a>`taker`

```sml
val taker : (char -> bool) -> substring -> substring
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `all-satisfy` &middot; `none-satisfies` &middot; `empty` &middot; `within-the-substring` &middot; `digits` &middot; `order` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `digits`

</details>

### <a name="val-position"></a>`position`

```sml
val position : string -> substring -> substring * substring
```

<details><summary>Tests (28)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `first-occurrence` &middot; `at-the-start` &middot; `at-the-end` &middot; `whole` &middot; `one-character` &middot; `overlapping-occurrences` &middot; `after-a-partial-match` &middot; `inside-a-string` &middot; `strings` &middot; `none` &middot; `none-whole-string` &middot; `none-longer-than-the-substring` &middot; `none-only-before-the-substring` &middot; `none-only-after-the-substring` &middot; `none-starts-before-the-substring` &middot; `none-ends-after-the-substring` &middot; `none-in-empty` &middot; `none-in-empty-string` &middot; `empty-string` &middot; `empty-string-in-empty` &middot; `empty-string-in-empty-string` &middot; `empty-string-at-the-end` &middot; `long` &middot; `long-none` &middot; `law-*` &middot; `law-span-restores-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `found` &middot; `not-found`

</details>

### <a name="val-span"></a>`span`

```sml
val span : substring * substring -> substring
```

<details><summary>Tests (31)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `apart` &middot; `adjacent` &middot; `overlapping` &middot; `same` &middot; `whole` &middot; `empty-and-empty-same-place` &middot; `empty-to-empty` &middot; `second-inside-first` &middot; `first-ends-to-the-right` &middot; `second-begins-to-the-left` &middot; `second-ends-at-start-of-first` &middot; `empty-second-at-start-of-first` &middot; `Span-second-ends-before-first` (raises Span) &middot; `Span-second-ends-one-before-first` (raises Span) &middot; `Span-empty-ones-in-the-wrong-order` (raises Span) &middot; `Span-whole-string-ends` (raises Span) &middot; `Span-different-strings` (raises Span) &middot; `Span-different-strings-same-substrings` (raises Span) &middot; `Span-string-and-its-prefix` (raises Span) &middot; `Span-empty-string-and-another` (raises Span) &middot; `Span-is-General.Span` (raises) &middot; `equal-strings-built-separately` &middot; `page-example` &middot; `page-example-string` &middot; `law-*` (raises Span) &middot; `law-*` &middot; `law-restores-splitl-*` &middot; `law-restores-splitr-*` &middot; `law-restores-splitAt-*` &middot; `law-first-to-last-field-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `from-the-one-to-the-other` &middot; `Span-in-the-wrong-order` (raises)

</details>

### <a name="val-translate"></a>`translate`

```sml
val translate : (char -> string) -> substring -> string
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `basic` &middot; `empty-results` &middot; `all-empty-results` &middot; `empty` &middot; `longer-results` &middot; `order` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `each-character-to-a-string`

</details>

### <a name="val-tokens"></a>`tokens`

```sml
val tokens : (char -> bool) -> substring -> substring list
```

<details><summary>Tests (16)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `page-example-strings` &middot; `empty` &middot; `empty-string` &middot; `no-delimiter` &middot; `delimiters-only` &middot; `trailing-delimiter` &middot; `inside-a-string` &middot; `inside-a-string-with-delimiters` &middot; `every-character-delimits` &middot; `whitespace` &middot; `order` &middot; `long` &middot; `law-*` &middot; `law-other-delimiters-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `runs-collapse`

</details>

### <a name="val-fields"></a>`fields`

```sml
val fields : (char -> bool) -> substring -> substring list
```

<details><summary>Tests (17)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `page-example` &middot; `page-example-strings` &middot; `empty` &middot; `empty-string` &middot; `no-delimiter` &middot; `delimiters-only` &middot; `trailing-delimiter` &middot; `inside-a-string` &middot; `inside-a-string-with-delimiters` &middot; `every-character-delimits` &middot; `commas` &middot; `order` &middot; `long` &middot; `law-*` &middot; `law-other-delimiters-*` &middot; `law-concatWith-restores-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `every-delimiter-separates`

</details>

### <a name="val-app"></a>`app`

```sml
val app : (char -> unit) -> substring -> unit
```

<details><summary>Tests (7)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `order` &middot; `empty` &middot; `whole` &middot; `returns-unit` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `in-order`

</details>

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (char * 'a -> 'a) -> 'a -> substring -> 'a
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `conses-reversed` &middot; `appends` &middot; `nonassociative` &middot; `empty` &middot; `counts` &middot; `order` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `sums-the-code-points`

</details>

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (char * 'a -> 'a) -> 'a -> substring -> 'a
```

<details><summary>Tests (9)</summary>

For `Substring`, in [tests/basis/substring.sml](../../../../tests/basis/substring.sml): `conses-in-order` &middot; `appends` &middot; `nonassociative` &middot; `empty` &middot; `counts` &middot; `order` &middot; `long` &middot; `law-*`

For `WideSubstring`, in [tests/basis/widesubstring.sml](../../../../tests/basis/widesubstring.sml): `from-the-right`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_substring.sml; do not edit.</sub>
