# signature UNICODE_SECURITY

[Unicode](../README.md) &rsaquo; Unicode &rsaquo; **UNICODE_SECURITY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 12 of 12 entries documented |
| Tests | not listed |
| Source | [lib/unicode/security\_sig.sml](../../../../lib/unicode/security_sig.sml) |

## Synopsis

```sml
signature UNICODE_SECURITY
structure UnicodeSecurity :> UNICODE_SECURITY
```

| Implementation |  | Source |
| --- | --- | --- |
| [`UnicodeSecurity`](../str/UnicodeSecurity.md) |  | [lib/unicode/security.sml](../../../../lib/unicode/security.sml) |

The security mechanisms of Unicode Technical Standard \#39 for
identifiers: which code points the standard allows in identifiers and
of what type they are, the scripts of a string and how far they mix,
and the skeletons by which two strings are confusable.

Unlike the properties of UAX \#31 that [`Identifier`](../str/Identifier.md) follows, these data
change between versions of Unicode: a code point may stop being allowed,
and two strings may become confusable or stop being so. They suit
warnings rather than the rules of a language. The data are those of the
version [`version`](#val-version).

## Contents

[Identifier status and type](#identifier-status-and-type) &middot;
[Scripts](#scripts) &middot;
[Confusables](#confusables)

## Interface

<pre>
signature UNICODE_SECURITY =
sig
  val <a href="#val-version">version</a> : string
  datatype <a href="#type-status">status</a> =
      <a href="#con-allowed">Allowed</a>
    | <a href="#con-restricted">Restricted</a>
  val <a href="#val-status">status</a> : int -&gt; status
  datatype <a href="#type-identifiertype">identifierType</a> =
      <a href="#con-recommended">Recommended</a>
    | <a href="#con-inclusion">Inclusion</a>
    | <a href="#con-limiteduse">LimitedUse</a>
    | <a href="#con-technical">Technical</a>
    | <a href="#con-uncommonuse">UncommonUse</a>
    | <a href="#con-obsolete">Obsolete</a>
    | <a href="#con-exclusion">Exclusion</a>
    | <a href="#con-notxid">NotXID</a>
    | <a href="#con-notnfkc">NotNFKC</a>
    | <a href="#con-defaultignorable">DefaultIgnorable</a>
    | <a href="#con-deprecated">Deprecated</a>
    | <a href="#con-notcharacter">NotCharacter</a>
  val <a href="#val-types">types</a> : int -&gt; identifierType list
  val <a href="#val-scripts">scripts</a> : int -&gt; string list option
  val <a href="#val-resolvedscripts">resolvedScripts</a> : string -&gt; string list option
  val <a href="#val-issinglescript">isSingleScript</a> : string -&gt; bool
  datatype <a href="#type-restriction">restriction</a> =
      <a href="#con-asciionly">ASCIIOnly</a>
    | <a href="#con-singlescript">SingleScript</a>
    | <a href="#con-highlyrestrictive">HighlyRestrictive</a>
    | <a href="#con-moderatelyrestrictive">ModeratelyRestrictive</a>
    | <a href="#con-minimallyrestrictive">MinimallyRestrictive</a>
    | <a href="#con-unrestricted">Unrestricted</a>
  val <a href="#val-restriction">restriction</a> : string -&gt; restriction
  val <a href="#val-skeleton">skeleton</a> : string -&gt; string
  val <a href="#val-isconfusable">isConfusable</a> : string * string -&gt; bool
end
</pre>

### <a name="val-version"></a>`version`

```sml
val version : string
```

The version of Unicode and of UTS \#39 whose data are followed.

**Example** `version = "18.0.0"`

## Identifier status and type

### <a name="type-status"></a>`status`

```sml
datatype status =
    Allowed
  | Restricted
```

The Identifier\_Status of a code point.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-allowed"></a>`Allowed` |  | its Identifier\_Type is Recommended or Inclusion: the General Security Profile allows it |
| <a name="con-restricted"></a>`Restricted` |  | any other |

### <a name="val-status"></a>`status`

```sml
val status : int -> status
```

`status c` is the Identifier\_Status of the code point `c`.

**Example** `status 0x61 = Allowed andalso status 0x1D44E = Restricted`, a and a mathematical italic a

### <a name="type-identifiertype"></a>`identifierType`

```sml
datatype identifierType =
    Recommended
  | Inclusion
  | LimitedUse
  | Technical
  | UncommonUse
  | Obsolete
  | Exclusion
  | NotXID
  | NotNFKC
  | DefaultIgnorable
  | Deprecated
  | NotCharacter
```

An Identifier\_Type: why a code point is allowed in identifiers, or why
it is restricted.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-recommended"></a>`Recommended` |  | in widespread modern use |
| <a name="con-inclusion"></a>`Inclusion` |  | not a letter, but used in the words of some languages, as U+00B7 is in Catalan's |
| <a name="con-limiteduse"></a>`LimitedUse` |  | of a script in use by a limited community |
| <a name="con-technical"></a>`Technical` |  | for technical notation, such as phonetics |
| <a name="con-uncommonuse"></a>`UncommonUse` |  | of uncommon use |
| <a name="con-obsolete"></a>`Obsolete` |  | no longer in modern use |
| <a name="con-exclusion"></a>`Exclusion` |  | of a script no longer in use |
| <a name="con-notxid"></a>`NotXID` |  | not XID\_Continue |
| <a name="con-notnfkc"></a>`NotNFKC` |  | changed by NFKC |
| <a name="con-defaultignorable"></a>`DefaultIgnorable` |  | a default ignorable code point |
| <a name="con-deprecated"></a>`Deprecated` |  | deprecated |
| <a name="con-notcharacter"></a>`NotCharacter` |  | not assigned, of private use, a surrogate or a noncharacter |

### <a name="val-types"></a>`types`

```sml
val types : int -> identifierType list
```

`types c` is the Identifier\_Type of the code point `c`, a set of one
or more types, in the order of the datatype.

**Example** `types 0x61 = [Recommended] andalso types 0x1C0 = [Technical]`

## Scripts

### <a name="val-scripts"></a>`scripts`

```sml
val scripts : int -> string list option
```

`scripts c` is the augmented script set of the code point `c` (UTS \#39,
section 5.1), its scripts as ISO 15924 codes in order, or `NONE` for
every script.

The scripts are those of its Script\_Extensions, with the writing
systems that hold them: Hanb, Hntl, Jpan and Kore for Han, Jpan for
Hiragana and Katakana, Kore for Hangul, Hanb for Bopomofo and Hntl for
Latin. A code point of Common or Inherited has every script.

**Example** `scripts 0x3BB = SOME ["Grek"] andalso scripts 0x30 = NONE`

**Example** `scripts 0x61 = SOME ["Hntl", "Latn"]`

### <a name="val-resolvedscripts"></a>`resolvedScripts`

```sml
val resolvedScripts : string -> string list option
```

`resolvedScripts s` is the resolved script set of the UTF-8 string
`s`, the scripts that every code point of `s` has, or `NONE` for every
script.

**Example** `resolvedScripts "x\206\187" = SOME [] andalso resolvedScripts "\206\187" = SOME ["Grek"]`, x and λ

### <a name="val-issinglescript"></a>`isSingleScript`

```sml
val isSingleScript : string -> bool
```

`isSingleScript s` is whether the resolved script set of the UTF-8
string `s` is not empty.

**Example** `isSingleScript "\206\177\206\187" andalso not (isSingleScript "x\206\187")`

### <a name="type-restriction"></a>`restriction`

```sml
datatype restriction =
    ASCIIOnly
  | SingleScript
  | HighlyRestrictive
  | ModeratelyRestrictive
  | MinimallyRestrictive
  | Unrestricted
```

The restriction levels of UTS \#39, section 5.2, the strictest first.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-asciionly"></a>`ASCIIOnly` |  | ASCII alone |
| <a name="con-singlescript"></a>`SingleScript` |  | one script, as [`isSingleScript`](#val-issinglescript) says |
| <a name="con-highlyrestrictive"></a>`HighlyRestrictive` |  | Latin with Japanese, with Han and Bopomofo, or with Korean |
| <a name="con-moderatelyrestrictive"></a>`ModeratelyRestrictive` |  | Latin with one other Recommended script, not Cyrillic or Greek |
| <a name="con-minimallyrestrictive"></a>`MinimallyRestrictive` |  | any mixture of scripts |
| <a name="con-unrestricted"></a>`Unrestricted` |  | a code point that [`status`](#val-status) does not allow |

### <a name="val-restriction"></a>`restriction`

```sml
val restriction : string -> restriction
```

`restriction s` is the strictest restriction level that the UTF-8
string `s` meets, by the algorithm of UTS \#39, section 5.2, with
[`status`](#val-status) as the identifier profile.

**Example** `restriction "abc" = ASCIIOnly andalso restriction "\206\177\206\187" = SingleScript`

**Example** `restriction "x\206\187" = MinimallyRestrictive`, Latin and Greek

## Confusables

### <a name="val-skeleton"></a>`skeleton`

```sml
val skeleton : string -> string
```

`skeleton s` is the skeleton of the UTF-8 string `s` (UTS \#39, section
4\), by which strings that look alike are found.

It is the NFD of `s` without its default ignorable code points, each
code point replaced by its prototype in confusables.txt, and the NFD of
that.

**Example** `skeleton "\208\176" = "a"`, a Cyrillic а

### <a name="val-isconfusable"></a>`isConfusable`

```sml
val isConfusable : string * string -> bool
```

`isConfusable (s, t)` is whether the UTF-8 strings `s` and `t` have the
same skeleton.

**Example** `isConfusable ("paypal", "p\208\176yp\208\176l")`, with two Cyrillic а

---

<sub>Generated by runedoc from lib/unicode/security\_sig.sml; do not edit.</sub>
