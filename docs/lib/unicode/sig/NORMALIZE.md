# signature NORMALIZE

[Unicode](../README.md) &rsaquo; Unicode &rsaquo; **NORMALIZE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 11 of 11 entries documented |
| Tests | not listed |
| Source | [lib/unicode/normalize\_sig.sml](../../../../lib/unicode/normalize_sig.sml) |

## Synopsis

```sml
signature NORMALIZE
structure Normalize :> NORMALIZE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Normalize`](../str/Normalize.md) |  | [lib/unicode/normalize.sml](../../../../lib/unicode/normalize.sml) |

Normalisation: the canonical forms of Unicode Standard Annex \#15.

Two strings of code points may be the same text: "é" may be U+00E9, or
"e" and U+0301 COMBINING ACUTE ACCENT; a Hangul syllable may be one
code point or its two or three jamo; accents on one letter may come in
either order. Normalisation Form D (NFD) writes every such text one
way, decomposed: each character replaced by its canonical decomposition,
then the marks of each letter sorted by their combining class. Form C
(NFC) composes NFD again wherever a primary composite exists, so that
most text is shorter in it and is often already in it. Two strings are
canonically equivalent exactly when their NFCs, or their NFDs, are
equal. The data is that of the version [`version`](#val-version); the test data of that
version (NormalizationTest.txt) passes, and a string in NFC stays in NFC
in every later version (Unicode's normalisation stability policy).

The functions over strings read UTF-8 by [`Utf8.next`](../sig/UTF8.md#val-next): an ill-formed part
of a string is read as U+FFFD, and such a string is in no form.

## Interface

<pre>
signature NORMALIZE =
sig
  val <a href="#val-version">version</a> : string
  datatype <a href="#type-answer">answer</a> = <a href="#con-yes">Yes</a> | <a href="#con-no">No</a> | <a href="#con-maybe">Maybe</a>
  val <a href="#val-combiningclass">combiningClass</a> : int -&gt; int
  val <a href="#val-nfd">nfd</a> : string -&gt; string
  val <a href="#val-nfc">nfc</a> : string -&gt; string
  val <a href="#val-nfdlist">nfdList</a> : int list -&gt; int list
  val <a href="#val-nfclist">nfcList</a> : int list -&gt; int list
  val <a href="#val-quickcheck">quickCheck</a> : string -&gt; answer
  val <a href="#val-quickchecklist">quickCheckList</a> : int list -&gt; answer
  val <a href="#val-isnfc">isNFC</a> : string -&gt; bool
  val <a href="#val-isnfclist">isNFCList</a> : int list -&gt; bool
end
</pre>

### <a name="val-version"></a>`version`

```sml
val version : string
```

The version of Unicode whose data is followed.

**Example** `version = "18.0.0"`

### <a name="type-answer"></a>`answer`

```sml
datatype answer = Yes | No | Maybe
```

The answer of a quick check: certainly in the form, certainly not, or
only normalising tells.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-yes"></a>`Yes` |  |  |
| <a name="con-no"></a>`No` |  |  |
| <a name="con-maybe"></a>`Maybe` |  |  |

### <a name="val-combiningclass"></a>`combiningClass`

```sml
val combiningClass : int -> int
```

`combiningClass c` is the Canonical\_Combining\_Class of the code point
`c`: 0 for a starter, which is most characters; the marks above a
letter 230, those below 220.

**Example** `combiningClass 0x301 = 230 andalso combiningClass 0x41 = 0`

### <a name="val-nfd"></a>`nfd`

```sml
val nfd : string -> string
```

`nfd s` is the canonical decomposition of the UTF-8 string `s`,
Normalisation Form D.

**Law** `nfd (nfd s) = nfd s` (for every `s : string`)

**Example** `nfd "\195\169" = "e\204\129"`, é decomposed

### <a name="val-nfc"></a>`nfc`

```sml
val nfc : string -> string
```

`nfc s` is the canonical composition of the UTF-8 string `s`,
Normalisation Form C. A string that the quick check finds in NFC is
`s` itself, unchanged.

**Law** `nfc (nfd s) = nfc s` (for every `s : string`)

**Example** `nfc "e\204\129" = "\195\169"`, é composed

### <a name="val-nfdlist"></a>`nfdList`

```sml
val nfdList : int list -> int list
```

`nfdList cs` is the NFD of the code points `cs`.

**Raises** [`Chr`](../../basis/sig/GENERAL.md#exn-chr) if one of `cs` is not a scalar value ([`Utf8.isScalar`](../sig/UTF8.md#val-isscalar)).

**Example** `nfdList [0xAC01] = [0x1100, 0x1161, 0x11A8]`, a Hangul syllable

### <a name="val-nfclist"></a>`nfcList`

```sml
val nfcList : int list -> int list
```

`nfcList cs` is the NFC of the code points `cs`.

**Raises** [`Chr`](../../basis/sig/GENERAL.md#exn-chr) if one of `cs` is not a scalar value.

**Example** `nfcList [0x1100, 0x1161, 0x11A8] = [0xAC01]`

### <a name="val-quickcheck"></a>`quickCheck`

```sml
val quickCheck : string -> answer
```

`quickCheck s` is the NFC quick check of the UTF-8 string `s`: [`Yes`](#con-yes)
where `s` is in NFC, [`No`](#con-no) where it is not, [`Maybe`](#con-maybe) where only [`nfc`](#val-nfc)
tells.

It is the algorithm of UAX \#15's section 9 over the property
NFC\_Quick\_Check. ASCII is always [`Yes`](#con-yes) and costs no table; ill-formed
UTF-8 is [`No`](#con-no).

**Example** `quickCheck "abc" = Yes andalso quickCheck "e\204\129" = Maybe`

### <a name="val-quickchecklist"></a>`quickCheckList`

```sml
val quickCheckList : int list -> answer
```

`quickCheckList cs` is the NFC quick check of the code points `cs`.

**Raises** [`Chr`](../../basis/sig/GENERAL.md#exn-chr) if one of `cs` is not a scalar value.

### <a name="val-isnfc"></a>`isNFC`

```sml
val isNFC : string -> bool
```

`isNFC s` is whether the UTF-8 string `s` is in NFC: the quick check,
and [`nfc`](#val-nfc) where it says [`Maybe`](#con-maybe).

**Law** `isNFC s = (nfc s = s)` (for every `s : string`)

**Example** `isNFC "\195\169" andalso not (isNFC "e\204\129")`

### <a name="val-isnfclist"></a>`isNFCList`

```sml
val isNFCList : int list -> bool
```

`isNFCList cs` is whether the code points `cs` are in NFC.

**Raises** [`Chr`](../../basis/sig/GENERAL.md#exn-chr) if one of `cs` is not a scalar value.

---

<sub>Generated by runedoc from lib/unicode/normalize\_sig.sml; do not edit.</sub>
