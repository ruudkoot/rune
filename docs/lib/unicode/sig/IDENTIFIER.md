# signature IDENTIFIER

[Unicode](../README.md) &rsaquo; Unicode &rsaquo; **IDENTIFIER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 9 of 9 entries documented |
| Tests | not listed |
| Source | [lib/unicode/identifier\_sig.sml](../../../../lib/unicode/identifier_sig.sml) |

## Synopsis

```sml
signature IDENTIFIER
structure Identifier :> IDENTIFIER
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Identifier`](../str/Identifier.md) |  | [lib/unicode/identifier.sml](../../../../lib/unicode/identifier.sml) |

Identifiers: which code points may make a name, by Unicode Standard
Annex \#31, and the profile of it that Rune takes for Standard ML.

UAX \#31 gives XID\_Start, the code points that may begin an identifier
(letters), and XID\_Continue, those that may follow them (letters,
digits, combining marks, connector punctuation); a string of them stays
one in every later version of Unicode. The profile of this structure
adds `'` to the code points that may follow, as Standard ML has it, and
leaves out two sets that are written down and frozen at Unicode 18.0.0,
so that a name valid today stays valid:

- the default ignorable code points that XID\_Continue holds, which are
  invisible: the joiners U+200C and U+200D, the variation selectors,
  the Hangul fillers;
- the lookalikes of Standard ML's punctuation and digits, such as U+01C3
  for [`!`](../../basis/sig/GENERAL.md#val-op-bang), U+02BC for `'`, U+00B7 for `.` and U+01C0 for `|`.

Whether a name is in Normalization Form C is for [`Normalize.isNFC`](../sig/NORMALIZE.md#val-isnfc) to
say.

## Interface

<pre>
signature IDENTIFIER =
sig
  val <a href="#val-version">version</a> : string
  val <a href="#val-isxidstart">isXIDStart</a> : int -&gt; bool
  val <a href="#val-isxidcontinue">isXIDContinue</a> : int -&gt; bool
  val <a href="#val-isdefaultignorable">isDefaultIgnorable</a> : int -&gt; bool
  datatype <a href="#type-exclusion">exclusion</a> =
      <a href="#con-ignorable">Ignorable</a>
    | <a href="#con-lookalike">Lookalike</a> of char
  val <a href="#val-exclusion">exclusion</a> : int -&gt; exclusion option
  val <a href="#val-isstart">isStart</a> : int -&gt; bool
  val <a href="#val-iscontinue">isContinue</a> : int -&gt; bool
  val <a href="#val-isalphanumeric">isAlphanumeric</a> : string -&gt; bool
end
</pre>

### <a name="val-version"></a>`version`

```sml
val version : string
```

The version of Unicode whose properties are followed.

**Example** `version = "18.0.0"`

### <a name="val-isxidstart"></a>`isXIDStart`

```sml
val isXIDStart : int -> bool
```

`isXIDStart c` is whether the code point `c` has the property
XID\_Start.

**Example** `isXIDStart 0x3BB andalso not (isXIDStart 0x30)`

### <a name="val-isxidcontinue"></a>`isXIDContinue`

```sml
val isXIDContinue : int -> bool
```

`isXIDContinue c` is whether the code point `c` has the property
XID\_Continue.

**Example** `isXIDContinue 0x30 andalso isXIDContinue 0x200D andalso not (isXIDContinue 0x27)`

### <a name="val-isdefaultignorable"></a>`isDefaultIgnorable`

```sml
val isDefaultIgnorable : int -> bool
```

`isDefaultIgnorable c` is whether the code point `c` has the property
Default\_Ignorable\_Code\_Point.

**Example** `isDefaultIgnorable 0x200D andalso isDefaultIgnorable 0x3164 andalso not (isDefaultIgnorable 0x41)`

### <a name="type-exclusion"></a>`exclusion`

```sml
datatype exclusion =
    Ignorable
  | Lookalike of char
```

Why the profile leaves out a code point of XID\_Continue.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-ignorable"></a>`Ignorable` |  | a default ignorable code point, which shows nothing |
| <a name="con-lookalike"></a>`Lookalike` | `char` | it looks like this character of ASCII |

### <a name="val-exclusion"></a>`exclusion`

```sml
val exclusion : int -> exclusion option
```

`exclusion c` is why the profile leaves out the code point `c`, and
`NONE` where it does not or where `c` is not XID\_Continue.

**Example** `exclusion 0x2BC = SOME (Lookalike #"'") andalso exclusion 0x200D = SOME Ignorable`

**Example** `exclusion 0x1C0 = SOME (Lookalike #"|") andalso exclusion 0x3BB = NONE`

### <a name="val-isstart"></a>`isStart`

```sml
val isStart : int -> bool
```

`isStart c` is whether the code point `c` may begin an alphanumeric
identifier: an ASCII letter, or XID\_Start where the profile does not
leave it out.

**Example** `isStart 0x3BB andalso not (isStart 0x3164) andalso not (isStart 0x5F)`

### <a name="val-iscontinue"></a>`isContinue`

```sml
val isContinue : int -> bool
```

`isContinue c` is whether the code point `c` may follow in an
alphanumeric identifier.

It may where it is an ASCII letter or digit, `_` or `'`, or
XID\_Continue where the profile does not leave it out.

**Example** `isContinue 0x27 andalso isContinue 0x301 andalso not (isContinue 0x200D)`

### <a name="val-isalphanumeric"></a>`isAlphanumeric`

```sml
val isAlphanumeric : string -> bool
```

`isAlphanumeric s` is whether the UTF-8 string `s` is an alphanumeric
identifier of the profile: well-formed, an [`isStart`](#val-isstart) and then
[`isContinue`](#val-iscontinue)s. ASCII costs no table.

**Example** `isAlphanumeric "x\206\187'" andalso not (isAlphanumeric "a\226\128\141b")`, λ and a joiner

---

<sub>Generated by runedoc from lib/unicode/identifier\_sig.sml; do not edit.</sub>
