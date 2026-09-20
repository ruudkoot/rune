# signature BOOL

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; **BOOL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 5 of 5 entries documented |
| Tests | 99 checks of 5 entries |
| Source | [lib/basis/sig\_bool.sml](../../../../lib/basis/sig_bool.sml) |

## Synopsis

```sml
signature BOOL
structure Bool : BOOL
```

| Implementation |  | Source |
| --- | --- | --- |
| `Bool` | Bool | [lib/basis/bool.sml](../../../../lib/basis/bool.sml) |

Booleans: negation, and conversion to and from text.

The conditional `if`, and `andalso` and `orelse`, which evaluate their
second
operand only when they must, are part of the language; [`not`](#val-not) is also in the
top-level environment.

## Interface

<pre>
signature BOOL =
sig
  datatype <a href="#type-bool">bool</a> = datatype bool

  val <a href="#val-not">not</a> : bool -&gt; bool

  val <a href="#val-tostring">toString</a> : bool -&gt; string

  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (bool, 'a) StringCvt.reader

  val <a href="#val-fromstring">fromString</a> : string -&gt; bool option
end
</pre>

### <a name="type-bool"></a>`bool`

```sml
datatype bool = datatype bool
```

The type of truth values, with the constructors `false` and `true`. It
is the top-level [`bool`](#type-bool).

> **Erratum** `BOOL/bool-spec`. The specification writes `datatype bool = false | true`. The Definition (Section 2.9) does not allow `true` and
> `false` to be specified, so the signature replicates the top-level
> datatype instead; the meaning is the same.

Also in the [top-level environment](../top-level.md): `bool`.

<details><summary>Tests (4)</summary>

For `Bool`, in [tests/basis/bool.sml](../../../../tests/basis/bool.sml): `distinct` &middot; `if` &middot; `andalso-short-circuit` &middot; `orelse-short-circuit`

</details>

### <a name="val-not"></a>`not`

```sml
val not : bool -> bool
```

`not b` is the negation of `b`.

Also in the [top-level environment](../top-level.md): `not`.

<details><summary>Tests (6)</summary>

For `Bool`, in [tests/basis/bool.sml](../../../../tests/basis/bool.sml): `true` &middot; `false` &middot; `toplevel-true` &middot; `toplevel-false` &middot; `involution-true` &middot; `involution-false`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : bool -> string
```

`toString b` is `"true"` or `"false"`.

<details><summary>Tests (3)</summary>

For `Bool`, in [tests/basis/bool.sml](../../../../tests/basis/bool.sml): `true` &middot; `false` &middot; `of-not-*`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (bool, 'a) StringCvt.reader
```

`scan getc strm` reads a boolean from the character stream `strm`, which
`getc` reads.

It skips initial white space and then takes the word `true` or `false`,
in any mixture of upper and lower case. The answer is `SOME (b, rest)`,
with `rest` the stream after the word, or `NONE` when neither word is
there, in which case nothing has been consumed. What follows the word
stays in the stream, also when it is a letter: `"truer"` scans as `true`
and leaves `"r"`.

> **Reading** `Bool.scan/wsx-*`. "Initial whitespace" is what [`Char.isSpace`](../sig/CHAR.md#val-isspace)
> accepts, as for [`StringCvt.skipWS`](../sig/STRING_CVT.md#val-skipws): the space, and the characters `\t`,
> `\n`, `\v`, `\f` and `\r`.

<details><summary>Tests (36)</summary>

For `Bool`, in [tests/basis/bool.sml](../../../../tests/basis/bool.sml): `list-true` &middot; `list-false` &middot; `list-rest` &middot; `list-rest-keeps-whitespace` &middot; `list-rest-is-a-prefix-of-true` &middot; `none-empty` &middot; `none-whitespace-only` &middot; `none-tru` &middot; `none-fals` &middot; `none-xtrue` &middot; `none-tr-ue` &middot; `case-list` &middot; `ws-list` &middot; `wsx-list` &middot; `mixed-list` &middot; `List.getItem` &middot; `string-index` &middot; `string-index-from-the-middle` &middot; `none-string-index-middle-of-word` &middot; `none-string-index-at-end` &middot; `ws-string-index` &middot; `index` &middot; `none-index` &middot; `case-index` &middot; `ws-index` &middot; `wsx-index` &middot; `repeatedly` &middot; `ws-repeatedly` &middot; `*` &middot; `agrees-with-fromString-*` &middot; `scanString-true` &middot; `scanString-false` &middot; `scanString-rest` &middot; `none-scanString-tru` &middot; `none-scanString-empty` &middot; `mixed-scanString`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> bool option
```

`fromString s` is the boolean that `s` begins with, read as [`scan`](#val-scan) reads
it, or `NONE`.

**Law** `fromString s = StringCvt.scanString scan s`

> **Reading** `Bool.fromString/none-not-whitespace-*`. The characters whose
> codes are next to those of the white space characters (0, 8, 14, 31, 33,
> 95 and 127) are not white space: a string that begins with one of them
> gives `NONE`.

<details><summary>Tests (50)</summary>

For `Bool`, in [tests/basis/bool.sml](../../../../tests/basis/bool.sml): `true` &middot; `false` &middot; `toString-true` &middot; `toString-false` &middot; `none-empty` &middot; `none-t` &middot; `none-tru` &middot; `none-fals` &middot; `none-FALs` &middot; `none-yes` &middot; `none-one` &middot; `none-zero` &middot; `none-xtrue` &middot; `none-nottrue` &middot; `none-t-rue` &middot; `none-tru-e` &middot; `none-trufalse` &middot; `none-quoted` &middot; `none-whitespace-only` &middot; `none-newline-only` &middot; `none-whitespace-inside` &middot; `none-not-whitespace-*` &middot; `case-TRUE` &middot; `case-FALSE` &middot; `case-True` &middot; `case-False` &middot; `case-tRuE` &middot; `case-fAlSe` &middot; `case-truE` &middot; `ws-space` &middot; `ws-tab` &middot; `ws-newline` &middot; `ws-spaces` &middot; `ws-several` &middot; `wsx-return` &middot; `wsx-vertical-tab` &middot; `wsx-formfeed` &middot; `wsx-all-six` &middot; `prefix-trailing-space` &middot; `prefix-trailing-newline` &middot; `prefix-truely` &middot; `prefix-falsetto` &middot; `prefix-truefalse` &middot; `prefix-falsetrue` &middot; `prefix-two-words` &middot; `mixed-ws-case` &middot; `mixed-ws-case-rest` &middot; `*` &middot; `toString-law-*` &middot; `scanString-scan-*`

</details>

## See also

[`STRING_CVT`](../sig/STRING_CVT.md)

---

<sub>Generated by runedoc from lib/basis/sig\_bool.sml; do not edit.</sub>
