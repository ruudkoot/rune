# signature CODE_POINT

[Unicode](../README.md) &rsaquo; Unicode &rsaquo; **CODE_POINT**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | not listed |
| Source | [lib/unicode/code\_point\_sig.sml](../../../../lib/unicode/code_point_sig.sml) |

## Synopsis

```sml
signature CODE_POINT
structure CodePoint :> CODE_POINT
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CodePoint`](../str/CodePoint.md) |  | [lib/unicode/code\_point.sml](../../../../lib/unicode/code_point.sml) |

Code points: the general category of each, and its simple case
mappings, by the Unicode Character Database.

The general category sorts every code point into one of 30 categories,
each in one of seven classes: letters, marks, numbers, punctuation,
symbols, separators, and the rest (controls, formats, surrogates,
private use, and the code points unassigned). A letter is uppercase,
lowercase or titlecase where it has case, and a modifier or other
letter where it has none, as those of CJK, Hebrew and Arabic.

A simple case mapping maps a code point to one code point, its
uppercase, lowercase or titlecase, or to itself where it has none. The
full mappings of SpecialCasing.txt, which map one code point to
several, as ß to SS, and depend on the language or the letters around,
are not here; nor is case folding. The simple mappings are not
inverses of each other: `toLower 0x130` is `0x69`, i, whose uppercase
is I and not İ.

The data is that of the version [`version`](#val-version), and changes with it: a code
point unassigned today may be a letter in a later version.

## Contents

[The general category](#the-general-category) &middot;
[Simple case mappings](#simple-case-mappings)

## Interface

<pre>
signature CODE_POINT =
sig
  val <a href="#val-version">version</a> : string
  datatype <a href="#type-category">category</a> =
      <a href="#con-uppercaseletter">UppercaseLetter</a>
    | <a href="#con-lowercaseletter">LowercaseLetter</a>
    | <a href="#con-titlecaseletter">TitlecaseLetter</a>
    | <a href="#con-modifierletter">ModifierLetter</a>
    | <a href="#con-otherletter">OtherLetter</a>
    | <a href="#con-nonspacingmark">NonspacingMark</a>
    | <a href="#con-spacingmark">SpacingMark</a>
    | <a href="#con-enclosingmark">EnclosingMark</a>
    | <a href="#con-decimalnumber">DecimalNumber</a>
    | <a href="#con-letternumber">LetterNumber</a>
    | <a href="#con-othernumber">OtherNumber</a>
    | <a href="#con-connectorpunctuation">ConnectorPunctuation</a>
    | <a href="#con-dashpunctuation">DashPunctuation</a>
    | <a href="#con-openpunctuation">OpenPunctuation</a>
    | <a href="#con-closepunctuation">ClosePunctuation</a>
    | <a href="#con-initialpunctuation">InitialPunctuation</a>
    | <a href="#con-finalpunctuation">FinalPunctuation</a>
    | <a href="#con-otherpunctuation">OtherPunctuation</a>
    | <a href="#con-mathsymbol">MathSymbol</a>
    | <a href="#con-currencysymbol">CurrencySymbol</a>
    | <a href="#con-modifiersymbol">ModifierSymbol</a>
    | <a href="#con-othersymbol">OtherSymbol</a>
    | <a href="#con-spaceseparator">SpaceSeparator</a>
    | <a href="#con-lineseparator">LineSeparator</a>
    | <a href="#con-paragraphseparator">ParagraphSeparator</a>
    | <a href="#con-control">Control</a>
    | <a href="#con-format">Format</a>
    | <a href="#con-surrogate">Surrogate</a>
    | <a href="#con-privateuse">PrivateUse</a>
    | <a href="#con-unassigned">Unassigned</a>
  val <a href="#val-category">category</a> : int -&gt; category
  datatype <a href="#type-major">major</a> =
      <a href="#con-letter">Letter</a>
    | <a href="#con-mark">Mark</a>
    | <a href="#con-number">Number</a>
    | <a href="#con-punctuation">Punctuation</a>
    | <a href="#con-symbol">Symbol</a>
    | <a href="#con-separator">Separator</a>
    | <a href="#con-other">Other</a>
  val <a href="#val-major">major</a> : category -&gt; major
  val <a href="#val-abbreviation">abbreviation</a> : category -&gt; string
  val <a href="#val-fromabbreviation">fromAbbreviation</a> : string -&gt; category option
  val <a href="#val-toupper">toUpper</a> : int -&gt; int
  val <a href="#val-tolower">toLower</a> : int -&gt; int
  val <a href="#val-totitle">toTitle</a> : int -&gt; int
end
</pre>

### <a name="val-version"></a>`version`

```sml
val version : string
```

The version of Unicode whose data is followed.

**Example** `version = "18.0.0"`

## The general category

### <a name="type-category"></a>`category`

```sml
datatype category =
    UppercaseLetter
  | LowercaseLetter
  | TitlecaseLetter
  | ModifierLetter
  | OtherLetter
  | NonspacingMark
  | SpacingMark
  | EnclosingMark
  | DecimalNumber
  | LetterNumber
  | OtherNumber
  | ConnectorPunctuation
  | DashPunctuation
  | OpenPunctuation
  | ClosePunctuation
  | InitialPunctuation
  | FinalPunctuation
  | OtherPunctuation
  | MathSymbol
  | CurrencySymbol
  | ModifierSymbol
  | OtherSymbol
  | SpaceSeparator
  | LineSeparator
  | ParagraphSeparator
  | Control
  | Format
  | Surrogate
  | PrivateUse
  | Unassigned
```

The values of the property General\_Category (UAX \#44, 5.7.1), each
with its abbreviation, which [`abbreviation`](#val-abbreviation) gives.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-uppercaseletter"></a>`UppercaseLetter` |  | Lu |
| <a name="con-lowercaseletter"></a>`LowercaseLetter` |  | Ll |
| <a name="con-titlecaseletter"></a>`TitlecaseLetter` |  | Lt: a digraph whose first part is uppercase, as U+01C5 |
| <a name="con-modifierletter"></a>`ModifierLetter` |  | Lm |
| <a name="con-otherletter"></a>`OtherLetter` |  | Lo: a letter with no case |
| <a name="con-nonspacingmark"></a>`NonspacingMark` |  | Mn |
| <a name="con-spacingmark"></a>`SpacingMark` |  | Mc |
| <a name="con-enclosingmark"></a>`EnclosingMark` |  | Me |
| <a name="con-decimalnumber"></a>`DecimalNumber` |  | Nd: a digit of a decimal system |
| <a name="con-letternumber"></a>`LetterNumber` |  | Nl: a numeral that is a letter, as the Roman ones |
| <a name="con-othernumber"></a>`OtherNumber` |  | No: as the superscript digits and the fractions |
| <a name="con-connectorpunctuation"></a>`ConnectorPunctuation` |  | Pc: as `_` |
| <a name="con-dashpunctuation"></a>`DashPunctuation` |  | Pd |
| <a name="con-openpunctuation"></a>`OpenPunctuation` |  | Ps |
| <a name="con-closepunctuation"></a>`ClosePunctuation` |  | Pe |
| <a name="con-initialpunctuation"></a>`InitialPunctuation` |  | Pi: an opening quotation mark |
| <a name="con-finalpunctuation"></a>`FinalPunctuation` |  | Pf: a closing quotation mark |
| <a name="con-otherpunctuation"></a>`OtherPunctuation` |  | Po |
| <a name="con-mathsymbol"></a>`MathSymbol` |  | Sm |
| <a name="con-currencysymbol"></a>`CurrencySymbol` |  | Sc |
| <a name="con-modifiersymbol"></a>`ModifierSymbol` |  | Sk |
| <a name="con-othersymbol"></a>`OtherSymbol` |  | So |
| <a name="con-spaceseparator"></a>`SpaceSeparator` |  | Zs |
| <a name="con-lineseparator"></a>`LineSeparator` |  | Zl: U+2028 alone |
| <a name="con-paragraphseparator"></a>`ParagraphSeparator` |  | Zp: U+2029 alone |
| <a name="con-control"></a>`Control` |  | Cc: C0 and C1 |
| <a name="con-format"></a>`Format` |  | Cf |
| <a name="con-surrogate"></a>`Surrogate` |  | Cs |
| <a name="con-privateuse"></a>`PrivateUse` |  | Co |
| <a name="con-unassigned"></a>`Unassigned` |  | Cn: reserved, or a noncharacter |

### <a name="val-category"></a>`category`

```sml
val category : int -> category
```

`category c` is the general category of the code point `c`, and
[`Unassigned`](#con-unassigned) for an integer that is no code point, below 0 or above
0x10FFFF.

Below 0x100 it costs a character of a string; above, a binary search
over ranges, built at the first use.

**Example** `category 0x41 = UppercaseLetter andalso category 0x3BB = LowercaseLetter`

**Example** `category 0x4E2D = OtherLetter andalso category 0x1C5 = TitlecaseLetter`, 中 and ǅ

**Example** `category 0x2B = MathSymbol andalso category 0x5F = ConnectorPunctuation`

**Example** `category 0xD800 = Surrogate andalso category 0x378 = Unassigned andalso category ~1 = Unassigned`

### <a name="type-major"></a>`major`

```sml
datatype major =
    Letter
  | Mark
  | Number
  | Punctuation
  | Symbol
  | Separator
  | Other
```

The class of a category, the first letter of its abbreviation.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-letter"></a>`Letter` |  | L |
| <a name="con-mark"></a>`Mark` |  | M |
| <a name="con-number"></a>`Number` |  | N |
| <a name="con-punctuation"></a>`Punctuation` |  | P |
| <a name="con-symbol"></a>`Symbol` |  | S |
| <a name="con-separator"></a>`Separator` |  | Z |
| <a name="con-other"></a>`Other` |  | C |

### <a name="val-major"></a>`major`

```sml
val major : category -> major
```

`major g` is the class of the category `g`.

**Example** `major OtherLetter = Letter andalso major (category 0x2B) = Symbol andalso major (category 0x20) = Separator`

### <a name="val-abbreviation"></a>`abbreviation`

```sml
val abbreviation : category -> string
```

`abbreviation g` is the two letters that stand for the category `g`
in the Unicode Character Database.

**Example** `abbreviation UppercaseLetter = "Lu" andalso abbreviation Unassigned = "Cn"`

### <a name="val-fromabbreviation"></a>`fromAbbreviation`

```sml
val fromAbbreviation : string -> category option
```

`fromAbbreviation s` is the category whose abbreviation is `s`, and
`NONE` where there is none: the inverse of [`abbreviation`](#val-abbreviation).

**Example** `fromAbbreviation "Nd" = SOME DecimalNumber andalso fromAbbreviation "L" = NONE`

## Simple case mappings

### <a name="val-toupper"></a>`toUpper`

```sml
val toUpper : int -> int
```

`toUpper c` is the property Simple\_Uppercase\_Mapping of the code point
`c`: its uppercase, or `c` where it has none, as for an integer that
is no code point.

ASCII costs no table; the rest, a binary search over runs of
mappings, built at the first use.

**Law** `toUpper (toUpper c) = toUpper c` (for every `c : int`)

**Example** `toUpper 0x61 = 0x41 andalso toUpper 0xFF = 0x178 andalso toUpper 0x41 = 0x41`

**Example** `toUpper 0xDF = 0xDF`, ß, whose full uppercase is SS

**Example** `toUpper 0x1C6 = 0x1C4 andalso toUpper 0x10D0 = 0x1C90`, ǆ and Georgian ა

**Counterexample** `toUpper (toLower 0x130) = 0x130`, İ, whose lowercase is i

### <a name="val-tolower"></a>`toLower`

```sml
val toLower : int -> int
```

`toLower c` is the property Simple\_Lowercase\_Mapping of the code point
`c`: its lowercase, or `c` where it has none.

**Law** `toLower (toLower c) = toLower c` (for every `c : int`)

**Example** `toLower 0x41 = 0x61 andalso toLower 0x130 = 0x69 andalso toLower 0x1C5 = 0x1C6`

### <a name="val-totitle"></a>`toTitle`

```sml
val toTitle : int -> int
```

`toTitle c` is the property Simple\_Titlecase\_Mapping of the code point
`c`: its titlecase, or `c` where it has none.

It is `toUpper c` but for the digraphs, whose titlecase is a letter
of its own, and the Georgian letters, which are their own titlecase.

**Law** `toUpper (toTitle c) = toUpper c` (for every `c : int`)

**Example** `toTitle 0x1C6 = 0x1C5 andalso toTitle 0x61 = 0x41 andalso toTitle 0x10D0 = 0x10D0`

---

<sub>Generated by runedoc from lib/unicode/code\_point\_sig.sml; do not edit.</sub>
