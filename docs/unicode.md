# Unicode in Rune

What Rune supports of Unicode, in its text types, its literals, its source
files and its names; the parts of the Unicode Standard it follows; how it
compares with the Definition of Standard ML, the Basis Library and the
other compilers; and the change to the Basis Library's specification that
its wide text needs.

## At a glance

* **Two widths of text.** `char` and `string` are 8-bit, a byte a
  character. `WideChar.char` and `WideString.string` hold Unicode code
  points, one a character. The whole optional wide family of the Basis
  Library is there, `WideTextIO` reading and writing UTF-8 among it.
* **`^`, `size`, `concat` and `substring` work at both widths,** as the
  comparisons do.
* **Literals** take the Definition's escapes at both widths, `\ddd` and
  `\uXXXX`, and, under `--unicode`, `\UXXXXXXXX`, Rune's extension for the
  characters above U+FFFF. A character above 255 is an error at `char`
  and `string`, and taken at the wide types.
* **Source files are UTF-8.** By default the code is ASCII: comments may
  hold any UTF-8 text, and a character beyond ASCII in a literal is
  written as its escape.
* **`--unicode`** (or `--unicode=utf8`) lets the wide literals hold
  Unicode as it is, takes `\U`, and lets names hold the letters, marks and
  digits of every script, by UAX #31, in NFC: `val λ = 1`.
  **`--unicode=latin1`** does the same for a file in Latin-1.
* **No Unicode operators.** Symbolic identifiers, record labels and numbers
  are ASCII in every mode.
* **Guarded against spoofing.** In every mode Rune refuses the characters
  that make source read otherwise than it runs: the bidi controls of Trojan
  Source, invisible characters in names, lookalikes of Standard ML's
  punctuation. It warns, by UTS #39, of names that look like others
  (*Protection against spoofing and Trojan Source*).

## Flags and annotations

| What it does | Command line | Build file | Program |
|---|---|---|---|
| The default: code in ASCII, comments in UTF-8, other characters as escapes | no flag | `annotate "ascii" in ... end` | `Compiler.compile`, or `Compiler.compileIn "ascii"` |
| UTF-8 source with Unicode in wide literals, `\U`, and Unicode identifiers | `--unicode`, the same as `--unicode=utf8` | `annotate "unicode" in ... end` (or `"unicode=utf8"`) | `Compiler.compileIn "unicode"` |
| The same, from a file in Latin-1 | `--unicode=latin1` | `annotate "unicode=latin1" in ... end` | `Compiler.compileIn "unicode=latin1"` |
| No warnings of UTS #39 on names, or of a lookalike of `*)` | `--no-unicode-lints` | | |
| `lib/unicode` for a program: `Utf8`, `Normalize`, `Identifier`, `Grapheme`, ... | `--library unicode` | | |

`rune-repl` takes `--unicode[=ENC]` and `--no-unicode-lints` too: they say
how the files it uses are read, and under `--unicode` what is typed is
read as UTF-8 ([repl.md](repl.md)). The encoding goes after an `=`:
`--unicode latin1` names an input file `latin1`, and where there is none
the answer is "cannot read latin1 (did you mean --unicode=latin1?)". A
build file's annotation wins over the command line for the files it
holds ([build.md](build.md), *Annotations*).

## Characters and strings

### The text types

| Type | What it holds |
|---|---|
| `Char.char` | an 8-bit character, 0 to 255 |
| `String.string` (= `CharVector.vector`) | bytes, a character each |
| `WideChar.char` | a Unicode code point, 0 to `0x10FFFF` |
| `WideString.string` (= `WideCharVector.vector`) | code points, a word of memory each, so `WideString.sub` takes constant time |
| `WideSubstring.substring` (= `WideCharVectorSlice.slice`) | a part of a wide string |
| `WideCharArray.array` | a mutable array of code points |

`WideText` packages the wide structures under `TEXT`, as `Text` does the
8-bit ones; `WideTextPrimIO` and `WideTextIO` read and write them;
`WideStringCvt` is `StringCvt` at the wide width, an addition of Rune's
(*The Basis Library* below).

The surrogates, `0xD800` to `0xDFFF`, are code points too: `WideChar.chr`
takes them, as the `CHAR` law `ord (chr i) = i` asks for every `i` up to
`maxOrd`. They are refused where text meets the world. UTF-8 holds the
scalar values, the code points that are not surrogates, so `WideTextIO`
neither reads nor writes a surrogate, and a literal holds none.

`WideChar`'s classes and case mappings (`isAlpha`, `isSpace`, `toUpper`, ...)
are ASCII's: `WideChar.isAlpha` is false of every character above 127.

### Strings at both widths

`^`, `size`, `concat` and `substring` are overloaded over `string` and
`WideString.string`, as `<`, `<=`, `>` and `>=` are, and a literal takes
the type its context gives it. They default to `string`, so a program of
Standard ML '97 keeps its types:

```sml
val greek : WideString.string = "\u03BB\u03BC"
val n = size greek                    (* 2 *)
val more = greek ^ "\u00E9"           (* a wide string of 3 *)
val euro : WideChar.char = #"\u20AC"
val bytes = "\195\169"                (* a string: é's two bytes of UTF-8 *)
val () = WideTextIO.print (more ^ "\n")  (* λμé *)
```

A `string` and a wide string do not mix in one `^`. `str`, `implode`,
`explode` and `print` stay 8-bit: at the wide width they are
`WideString.str`, `WideString.implode`, `WideString.explode` and
`WideTextIO.print`. The overloading is an extension of the Definition's
Appendix E ([language.md](language.md), *Overloading*).

### Files of wide text

`WideTextIO` reads and writes UTF-8: its `openIn`, `openOut`,
`openAppend`, `stdIn`, `stdOut` and `stdErr`, and `print`. What is not UTF-8
raises `IO.Io` with the cause `Fail "UTF-8"`:

* on input, a byte sequence that is not one of the well-formed sequences of
  the Unicode Standard's Table 3-7: an overlong form, a surrogate, a value
  past `0x10FFFF`, a lead byte `C0`, `C1` or `F5` to `FF`, a continuation
  byte where a sequence begins, or a sequence cut short;
* on output, a surrogate, which a `WideChar.char` may be and UTF-8 cannot
  encode.

A stream made by `mkInstream` over a `WideTextPrimIO.reader` of one's own
carries wide characters as they are, without an encoding, surrogates
included.

Since UTF-8 takes 1 to 4 bytes a code point, a count of characters is not
an offset in the file. So a file's readers and writers in `WideTextIO`
have no `pos`, no `ioDesc`, no non-blocking operations and no `canInput`
or `avail`. A functional stream still goes back to where it was: its
positions are of characters (`RuneWideTextPos.pos`), not of bytes
(`WideTextIO/file-streams-have-no-positions` in
[`lib/basis/widetextio.sml`](../lib/basis/widetextio.sml)).

### Converting

* **To and from UTF-8 bytes in a `string`:** `lib/unicode`'s `Utf8`
  (`rune --library unicode`) works on code points as `int`s:

  ```sml
  val w : WideString.string = "\u03BB\u00E9"
  val utf8 = Utf8.implode (map WideChar.ord (WideString.explode w))  (* 4 bytes *)
  val back = WideString.implode (map WideChar.chr (Utf8.explode utf8))
  ```

  `Utf8` is strict, as `WideTextIO` is: `Utf8.isValid` says whether a
  string is UTF-8, and `Utf8.decode` reads one character or none.
* **To and from Standard ML's escapes:** `WideString.toString` and
  `WideChar.toString` write an 8-bit `string` of ASCII: a character from
  127 to 255 as `\ddd`, one above it as `\uXXXX`, and one above
  U+FFFF as `\UXXXXXXXX`; `fromString` reads them back. They
  take `\U` whatever the source mode, as a program has no mode when it
  runs. `WideChar.scan` reads 8-bit `Char.char`s, as `CHAR` writes it.
  `WideString.scan` reads wide characters, as `STRING` writes it over the
  structure's own `char`: an escape is written in ASCII, and any other
  character stands for itself, those above 255 too. (MLton's
  `WideString.scan` reads `Char.char`s instead.)
* **`WideStringCvt`** has `StringCvt`'s functions over text (`padLeft`,
  `splitl`, `skipWS`, `scanString` and the rest) at the wide width, with the
  `radix`, `realfmt` and `reader` of `StringCvt`. Its white space is what
  `WideChar.isSpace` takes.

### In the REPL

`rune-repl` shows a `WideString.string` or a `WideChar.char` quoted, in
UTF-8 (`"λx"`, `#"λ"`). What would not show, or would make the line read
otherwise, is escaped: a control (C0, DEL, C1), a bidi control or another
default-ignorable character, and a surrogate (`\n`, `\u202E`). A
`string` is bytes, and shows as `String.toString` writes it
(`"caf\195\169"`). See [repl.md](repl.md).

## Literals

### Escapes

| Escape | at `char` and `string` | at `WideChar.char` and `WideString.string` |
|---|---|---|
| `\a \b \t \n \v \f \r \" \\` | the ASCII control or character | the same |
| `\^C`, `C` from `@` to `_` | the control character 0 to 31 | the same |
| `\ddd`, three decimal digits | 0 to 255 | 0 to 999 |
| `\uXXXX`, four hexadecimal digits | 0 to `FF` | any but a surrogate |
| `\UXXXXXXXX`, eight hexadecimal digits, under `--unicode` | 0 to `FF` | any up to `10FFFF` but a surrogate |
| `\` white space `\` | nothing: a gap | the same |

A character too large for the type is a compile-time error: "string constant
"\u0100" is out of range for the type string". A surrogate is refused in
every escape and at every type, though the Definition's alphabet holds it
("a surrogate is no character"). `\UXXXXXXXX` is Rune's extension, from
Successor ML, and by default is refused: "the escape \U needs --unicode".
`\x` is no escape of Standard ML, and no escape of Rune's.

### `\U`: Rune's extension for characters above U+FFFF

`\uXXXX` stops at U+FFFF, and `\ddd` at 999, so the Definition has no
way to write a character above U+FFFF in a literal: an emoji, a
mathematical letter, a historic script. Rune takes `\UXXXXXXXX`, eight
hexadecimal digits, from Successor ML (and from MLton's extended text
constants):

```sml
(* rune --unicode *)
val smile : WideString.string = "\U0001F600"
val ok = WideString.size smile = 1
```

It is an extension, and it needs `--unicode` (or `--unicode=latin1`), so
that the default reads nothing the Definition does not: by default it is
"the escape \U needs --unicode". There such a character is made when the
program runs, `WideString.str (WideChar.chr 0x1F600)`. At run time there
is no mode: `WideString.toString` writes `\U` for a character above
U+FFFF, and `WideString.fromString` reads it, whatever mode the program
was compiled in.

### Characters as they are

A literal holds no raw control character, in any mode: TAB, DEL and the C1
controls are written as escapes (`\t`, `\127`), and so are the bidi
controls (`\u202E`). What a raw character above 127 means depends on the
mode the file is read in, but where a mode takes it, it means its code
point, as its escape does:

| Mode | `"é"` at `string` | `"é"` at `WideString.string` |
|---|---|---|
| the default | refused: "non-ASCII character U+00E9 in string literal (write it as `\u00E9`, or read the file with --unicode)" | refused, the same way |
| `--unicode` | refused: "write `\233` for the character, or `\195\169` for its UTF-8" | U+00E9, one character |
| `--unicode=latin1`, the byte E9 | the byte 233 | U+00E9, one character |

So a program that two modes take means the same in both, and a raw
character never stands for its bytes of UTF-8. The default takes the
escapes alone, and `"\u00E9"` means the same in every mode.

## Source files

### The three modes

A source file is read in a *mode*, which says what its bytes are and how
much of Unicode it may hold:

| | the default | `--unicode` (`--unicode=utf8`) | `--unicode=latin1` |
|---|---|---|---|
| the file is | UTF-8 | UTF-8 | Latin-1, made UTF-8 as it is read; a file that looks like UTF-8 is refused |
| a comment holds | any UTF-8 text | any UTF-8 text | any Latin-1 text but the C1 controls |
| a raw character above 127 in a literal | refused | at the wide types, its code point | its byte, at every type |
| `\U` | refused | taken | taken |
| a name holds | ASCII | ASCII, and the letters, marks and digits of the identifier profile | as under `--unicode` |

The mode is a file's, not the compile's:

* **On the command line:** `rune --unicode prog.sml`, `rune
  --unicode=latin1 old.sml`, and `rune-repl --unicode` for what the REPL
  uses (what is typed into the REPL is read as UTF-8). The encoding goes
  after an `=`: `--unicode latin1` names an input file `latin1`.
* **In a build file:** `annotate "unicode" in greek.sml end`, and
  `"unicode=latin1"` and `"ascii"` (the default) the same way, over the
  command line ([build.md](build.md), *Annotations*).
* **From a program:** `Compiler.compileIn "unicode"` is `Compiler.compile`
  in a mode.
* **Libraries** are read in the default, the Basis Library among them, so
  what they export is ASCII and a program in any mode can name it.

The cache keeps a unit's mode, so a file read in one mode is never taken
for one read in another. [units.md](units.md), *Source modes*, says the
rest.

### What every mode refuses

In comments, in literals and between tokens, every mode refuses:

* the controls but TAB, LF, CR before LF, and FF (so VT, NUL and a lone CR
  are refused), DEL, and the C1 controls, NEL among them;
* the line and paragraph separators U+2028 and U+2029;
* the nine explicit bidi controls, U+202A to U+202E and U+2066 to U+2069,
  with which Trojan Source makes code read otherwise than it runs: "bidi
  control U+202E in a comment";
* a byte order mark past the start of the file;
* text that is not well formed in the file's encoding: "invalid UTF-8 (byte
  0xE9) in a comment".

A byte order mark at the start of a UTF-8 file is dropped. Lines end at LF
or CR LF. The marks LRM, RLM and ALM and the other default-ignorable
characters are taken in comments and literals, where they cannot hide
code. A lookalike of `*)` in a comment, such as `∗)`, does not end it,
and the compiler warns of it.

Outside literals and comments, a character above 127 is "unexpected
character U+03BB", but in a name under `--unicode`. The error names the
code point, and says when `--unicode` would take it.

## Identifiers

### Unicode identifiers

By default an alphanumeric identifier is ASCII, as the Definition has it.
Under `--unicode` and `--unicode=latin1` it may also hold the letters,
marks and digits of every script, an extension that Successor ML asks for
(issue #33):

```sml
val λ = 2
fun größe (x : int) = x * λ
val gruß : WideString.string = "Grüß Gott, 東京"
```

What a name may hold is `lib/unicode`'s identifier profile
([`Identifier`](lib/unicode/str/Identifier.md)), a profile of
[UAX #31](https://www.unicode.org/reports/tr31/), *Unicode Identifiers and
Syntax*, the annex that Rust, C23, C++23 and Python follow: its
XID_Start and XID_Continue, with `'` and `_` as in Standard ML, less two sets that are
frozen at Unicode 18.0.0, so that no later version of Unicode makes a valid
name invalid:

* **the default-ignorable characters**, which show nothing: "the character
  U+200D in a name is a default ignorable character, which shows nothing".
  The invisible identifier of Trojan Source, U+3164, is one;
* **239 lookalikes** of Standard ML's punctuation and digits, such as `ǃ`
  for `!`, `ʹ` for `'`, `꞉` for `:` and `ꓸ` for `.`: "the character U+01C3
  in a name is a lookalike of !".

A name is in NFC, the composed form. One that is not, such as `e`
followed by the combining acute accent U+0301, is refused with its NFC
spelling: "the name ... is not in NFC, the form names are written in:
write it as é". Rune does not convert it, so that names are compared
by their bytes, and a name looks the same wherever it is printed.

### No Unicode operators

Symbolic identifiers stay ASCII in every mode: `val x = a ⊕ b` is
"unexpected character U+2295". So do record labels ("a record label is
ASCII") and numbers, so `#1` means what it always has, and no digit of
another script makes a number. Unicode symbols in identifiers are
left for later; their lookalikes of Standard ML's punctuation (`∗` for
`*`, `−` for `-`) would need the same care as the letters'.

### Warnings

The compiler warns of what Unicode Technical Standard #39 finds suspect in
a source's names:

* a character it restricts in identifiers: "the name ʃell holds U+0283,
  which UTS #39 restricts in names (technical)";
* a name that mixes scripts beyond its moderately restrictive profile, each
  part between `_` and `'` judged by itself: "the name сорt mixes
  scripts";
* a name that looks like another of the same source, a reserved word, or
  punctuation: "the name vаl looks like the reserved word val", "the name
  ノ looks like /".

`--no-unicode-lints` turns these warnings off. The data behind them change
with every version of Unicode, which is why they are warnings and not
errors.

### Protection against spoofing and Trojan Source

Unicode lets text look otherwise than it is: characters that show nothing,
letters of one script that look like another's, controls that reorder a
line on the screen. Boucher and Anderson's [Trojan
Source](https://trojansource.codes/) (CVE-2021-42574, CVE-2021-42694)
hides code that way in comments, literals and names. Rune follows
[UTS #55](https://www.unicode.org/reports/tr55/), *Unicode Source Code
Handling*, and [UTS #39](https://www.unicode.org/reports/tr39/), *Unicode
Security Mechanisms*:

* **Errors,** from data that Unicode's [stability
  policy](https://www.unicode.org/policies/stability_policy.html) freezes,
  so that a program that compiles today compiles under every later
  version:
  - the nine explicit bidi controls, in every mode and every context, so
    that Trojan Source's early return, commented-out code and stretched
    string are refused (*What every mode refuses*);
  - the C1 controls, which a terminal may take for commands, and the line
    and paragraph separators;
  - in a name, the default-ignorable characters, which show nothing,
    among them the Hangul filler U+3164 of Trojan Source's invisible
    identifier;
  - in a name, the 239 lookalikes of Standard ML's punctuation and digits
    (`ǃ` for `!`, `ʹ` for `'`, `꞉` for `:`), so that a name cannot pass
    for punctuation, a type variable or a long identifier;
  - a name not in NFC ([UAX #15](https://www.unicode.org/reports/tr15/)),
    so that two names that look the same are the same bytes;
  - Unicode in symbolic identifiers, labels and numbers (*No Unicode
    operators*).
* **Warnings,** from UTS #39's data, which changes with every version of
  Unicode (`--no-unicode-lints` turns them off):
  - a name that looks like another of the same source: Trojan Source's
    homoglyph function, `ѕсоре` beside `scope`;
  - a name that mixes scripts, holds a restricted character, or looks like
    a reserved word or like punctuation;
  - a lookalike of `*)` in a comment, which does not end it.
* **What is shown.** A diagnostic escapes a bidi control or an invisible
  character in its excerpt and its file name, and the REPL escapes them
  in the wide strings it prints, so that the terminal shows what the text
  holds.

## Positions and columns

A position is a byte offset inside the compiler. A column that a person
reads, in a diagnostic's `FILE:LINE:COL` or a REPL's trace, counts
characters; one that an editor's protocol reads, in the REPL's engine and
`rune-dap`, counts UTF-16 units, as editors do. The excerpt under a
diagnostic draws a CJK character two columns wide and a combining mark
none ([diagnostics.md](diagnostics.md), *Columns*).

## The Unicode specifications Rune follows

Rune's tables come from the Unicode Character Database 18.0.0, by
`scripts/gen-unicode-tables.py`, each file pinned by its SHA-256, into
`lib/unicode` ([docs/lib/unicode](lib/unicode/README.md)), which the
compiler is built with.

| Specification | What Rune takes from it | Where |
|---|---|---|
| [The Unicode Standard](https://www.unicode.org/versions/latest/), chapter 3, Table 3-7 | well-formed UTF-8, and nothing else | `Utf8`, `WideTextIO`, the lexer |
| [UAX #31](https://www.unicode.org/reports/tr31/), Unicode Identifiers and Syntax | XID_Start and XID_Continue, the default-ignorable characters | `Identifier`, names under `--unicode` |
| [UAX #15](https://www.unicode.org/reports/tr15/), Unicode Normalization Forms | NFC and NFD, and the quick check; tested on all of `NormalizationTest.txt` | `Normalize`, names in NFC |
| [UTS #39](https://www.unicode.org/reports/tr39/), Unicode Security Mechanisms | identifier status and type, mixed scripts, confusable skeletons | `UnicodeSecurity`, the warnings |
| [UTS #55](https://www.unicode.org/reports/tr55/), Unicode Source Code Handling | bidi controls in source, lookalikes of a comment's end | the lexer |
| [UAX #9](https://www.unicode.org/reports/tr9/), Unicode Bidirectional Algorithm | which characters are the explicit bidi controls | the lexer, the REPL's printer, diagnostics |
| [UAX #29](https://www.unicode.org/reports/tr29/), Unicode Text Segmentation | grapheme clusters; tested on `GraphemeBreakTest.txt` | `Grapheme`, diagnostics' excerpts |
| [UAX #11](https://www.unicode.org/reports/tr11/), East Asian Width | how many columns a character takes | `DisplayWidth`, diagnostics' carets |
| [Unicode Character Encoding Stability Policies](https://www.unicode.org/policies/stability_policy.html) | identifiers and normalisation do not change; the security data may | why names follow XID and NFC as rules, and UTS #39 as warnings |

And for the threats: Nicholas Boucher and Ross Anderson, ["Trojan Source:
Invisible Vulnerabilities"](https://trojansource.codes/) (USENIX Security
2023; CVE-2021-42574 and CVE-2021-42694).

## Rune, the Definition, the Basis Library and the other compilers

### Source text and literals

How each of Rune's modes reads source text, and what its wide text is,
beside the Definition and the Basis Library ("Def.") and the other
implementations of Standard ML. The other systems' columns come from the
same programs run on each (the utf8 roadmap's *Appendix E*,
[plans/utf8.md](plans/utf8.md#appendix-e-the-host-probes)): MLton 20241230, with and without
`-default-ann 'allowExtendedTextConsts true'` ("MLton+ext"), SML/NJ
110.99.9, Poly/ML 5.9.2, MLKit 4.7.25, Moscow ML 2.10.1 and HaMLet 2.0.1. A
"-" is a question the system cannot be asked, for want of the wide types.

| | Def. | Rune, default | Rune, `--unicode=latin1` | Rune, `--unicode` | MLton | MLton+ext | SML/NJ | Poly/ML | MLKit | Moscow ML | HaMLet |
|---|---|---|---|---|---|---|---|---|---|---|---|
| encoding of the file | none | UTF-8 | Latin-1 | UTF-8 | bytes | bytes | bytes | bytes | bytes | bytes | bytes |
| text that is not UTF-8 refused | - | yes | - | yes | in literals (all non-ASCII) | in literals | no | in literals (all non-ASCII) | no | no | no |
| non-ASCII in comments | any | UTF-8 | Latin-1 but C1 controls | UTF-8 | any | any | any | any | any | any | any |
| raw non-ASCII at `string` | no | no | its byte | no | no | bytes | bytes | no | bytes | bytes | no, or cut short |
| raw non-ASCII at `WideString` | (no) | no | its code point | its code point | no | a code point per byte | - | - | - | - | - |
| raw TAB in a literal | no | no | no | no | no | no | no | no | spaces | no | no |
| raw DEL in a literal | no | no | no | no | no | no | yes | no | yes | no | no |
| VT between tokens | allowed | no | no | no | yes | yes | no | yes | no | no | yes |
| FF between tokens | required | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| bare CR | allowed | no | no | no | yes | yes | yes | yes | yes | yes | yes |
| byte order mark at the start | - | dropped | refused (looks like UTF-8) | dropped | error | error | error | error | error | error | error |
| the nine bidi controls, raw | literals no, comments yes | no | no | no | comments only | yes | yes | comments only | yes | yes | comments; literals cut short |
| non-ASCII identifiers | ("letters") | no | the identifier profile | the identifier profile | no | no | no | no | no | no | no |
| identifiers in NFC | - | - | required | required | - | - | - | - | - | - | - |
| Unicode symbols in identifiers | no | no | no | no | no | no | no | no | no | no | no |
| `\uXXXX` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| `\UXXXXXXXX` | no | no (needs `--unicode`) | yes | yes | needs ext | yes | no | no | no | no | no |
| `\x` | no | no | no | no | no | no | no | no | no | no | no |
| `\ddd` above 255 at the wide types | yes | yes | yes | yes | yes | yes | - | - | - | - | - |
| a surrogate in `\u` | in the range | refused | refused | refused | not probed | not probed | - | - | - | - | - |
| wide types | optional | all | all | all | `WideChar` to `WideText` | the same | no | no | no | no | no |
| `WideTextIO` | optional, unmatchable | sealed with the generic `TEXT_IO` | the same | the same | no | no | no | no | no | no | no |
| `WideCharVector.vector` admits equality | must, unwritten | `where type vector = WideString.string` | the same | the same | yes | yes | - | - | - | - | - |
| top-level `^` at `WideString.string` | no | yes, overloaded | the same | the same | no: `WideString.^` | the same | - | - | - | - | - |

* **Each mode of Rune reads Standard ML '97,** in the mode's encoding, but
  for what *Where Rune departs from the specifications* below lists: two
  refusals stricter than the Definition, in every mode, and two rows
  wider, names and raw characters in wide literals, under `--unicode`
  and `--unicode=latin1`.
* **The default reads nothing that the Definition does not:** `\U` needs
  `--unicode`. Its types go further in one place, in every mode: `^`,
  `size`, `concat` and `substring` are overloaded at `WideString.string`
  as well as `string`, which Appendix E does not list (*Overloading*).
* **A raw character in a wide literal is one character,** the code point
  that the Definition's rule for an escape would give: a number in the
  type's alphabet. MLton+ext reads one character a byte, so `"é"` at
  `WideString.string` is two characters there and one in Rune.

### The wide text family

Among traditional SML implementations:

* **SML/NJ, Poly/ML, MLKit, Moscow ML and HaMLet** provide none of
  `WideChar`, `WideString`, `WideText`, `WideTextPrimIO` and `WideTextIO`.
* **MLton** provides `WideChar`, `WideString` and `WideText`. Its `WideChar` and
  `WideString` are by default `Char32` and `String32`, whose characters are
  the code points 0 to `0x10FFFF`, surrogates included;
  `-default-type widechar16` makes them the 16-bit `Char16` and `String16`.
  For `WideTextIO` and `WideTextPrimIO`, MLton includes declarations in its
  signature files but comments out the sharing constraints in `basis.sig`
  and provides no implementation.
* **Rune** provides the complete wide text family: the code points 0 to
  `0x10FFFF` in `WideChar`, UTF-8-encoded file streams in `WideTextIO`,
  full `PRIM_IO` readers and writers in `WideTextPrimIO`, and
  `WideStringCvt`.

### Where Rune departs from the specifications

Each departure is written where it is made, and pinned by tests.

From the Definition ([language.md](language.md#deviations-from-the-definition),
rows *Strings*, *Source text*, *Identifiers* and *Overloading*):

| What | Kind | Pinned by |
|---|---|---|
| A comment holds no control but TAB, LF, CR LF and FF, no bidi control, no U+2028 or U+2029, and only well-formed text | stricter: a deviation | `tests/errors/err.lex_comment_*`, `err.lex_trojan_*` |
| A surrogate in an escape is refused | stricter: a deviation | `tests/errors/err.lex_surrogate*` |
| `\UXXXXXXXX`, under `--unicode` | wider: an extension, from Successor ML | `tests/errors/err.lex_escape_bigu*`, `tests/lang/ty.overload.literal_wide` |
| Names beyond ASCII, under `--unicode` | wider: an extension, which Successor ML asks for (issue #33) | `tests/lang/lex.ident_*`, `tests/errors/err.lex_name_*` |
| A raw character above 127 in a wide literal, under `--unicode` | wider: an extension | `tests/lang/lex.string_modes_*` |
| `^`, `size`, `concat` and `substring` overloaded at `WideString.string` | wider: an extension of Appendix E | `tests/lang/ty.overload.string*`, `tests/errors/err.ty_overload-string-mixed` |

VT, NUL and a lone CR are refused between tokens. The Definition asks for
space, tab, newline and formfeed, and no more, so this is no deviation.

From the Basis Library, each a note where the signature or structure is
declared, pinned by the Basis suite ([basis-compat.md](basis-compat.md)):

* `TEXT_IO/generic` and `TEXT_STREAM_IO/generic`: the text types are the
  signatures' own, and said where `TextIO` and `WideTextIO` are declared;
* `STRING_CVT/generic` and `WideStringCvt/not-in-the-specification`;
* `WideCharVector` is declared `where type vector = WideString.string`, as
  the specification should have declared it;
* `WideTextIO/file-streams-have-no-positions`, a limitation of UTF-8 files
  (*Files of wide text* above).

## The Basis Library's wide text, and where its specification breaks

The Basis Library makes a wide family optional, for character sets larger
than 8 bits: `WideChar`, `WideString`, `WideSubstring`, `WideCharVector`,
`WideCharVectorSlice`, `WideCharArray` and its slices, `WideText`,
`WideTextPrimIO` and `WideTextIO`. Two parts of its specification cannot be
met as they are written, and one leaves the wide width out:

1. no structure of wide characters can match `TEXT_IO`, though the synopsis
   declares `WideTextIO :> TEXT_IO`;
2. `WideCharVector.vector` must admit equality, and its declaration cannot
   say so;
3. `STRING_CVT`'s functions over text exist at the 8-bit width alone.

Rune implements the whole family, departs from the page where it must, and
proposes the change of the next section.

### `WideTextIO :> TEXT_IO` cannot be met

The official SML Basis specification ([`text-io.html`](https://smlfamily.github.io/Basis/text-io.html))
declares in its synopsis:

```sml
signature TEXT_IO
structure TextIO :> TEXT_IO
structure WideTextIO :> TEXT_IO  (* OPTIONAL *)
```

In the interface that follows, `TEXT_IO` specifies:

```sml
include IMPERATIVE_IO
structure StreamIO : TEXT_STREAM_IO
  where type reader = TextPrimIO.reader
  where type writer = TextPrimIO.writer
  where type pos = TextPrimIO.pos

val inputLine : instream -> string option
val outputSubstr : outstream * substring -> unit
val openIn : string -> instream
val openOut : string -> outstream
val openAppend : string -> outstream
val openString : string -> instream
val stdIn : instream
val stdOut : outstream
val stdErr : outstream
val print : string -> unit
val scanStream : ((Char.char, StreamIO.instream) StringCvt.reader
                  -> ('a, StreamIO.instream) StringCvt.reader)
                 -> instream -> 'a option
```

And `TEXT_STREAM_IO` ([`text-stream-io.html`](https://smlfamily.github.io/Basis/text-stream-io.html)) specifies:

```sml
include STREAM_IO
  where type vector = CharVector.vector
  where type elem = Char.char
val inputLine : instream -> (string * instream) option
val outputSubstr : outstream * substring -> unit
```

In Standard ML, `TEXT_IO` and `TEXT_STREAM_IO` explicitly constrain:

* `elem` to `Char.char`
* `vector` to `CharVector.vector` (which is `String.string`)
* `StreamIO.reader` to `TextPrimIO.reader`
* `StreamIO.writer` to `TextPrimIO.writer`
* `outputSubstr` to `Substring.substring`
* `scanStream` to `Char.char` readers

A wide-character I/O structure must operate on `WideChar.char`,
`WideString.string`, `WideSubstring.substring`, and `WideTextPrimIO` readers and
writers. Unless `WideChar.char` is identical to 8-bit `Char.char`, **no
structure providing wide character I/O can match `TEXT_IO`**.

The specification authors needed either:

1. A parameterized `GEN_TEXT_IO` / `GEN_TEXT_STREAM_IO` signature, or
2. Separate `WIDE_TEXT_IO` and `WIDE_TEXT_STREAM_IO` signatures, or
3. Placing I/O inside `TEXT` (such as `Text.IO` and `WideText.IO`).

Because none of these were specified, `WideTextIO` has no signature in the
Standard ML Basis Library.

### `WideCharVector` must admit equality, and its declaration cannot say so

The `MONO_VECTOR` signature specifies `type vector`, not `eqtype vector`, so
that `RealVector` can exist. Where a monomorphic vector admits equality, the
specification adds an equality constraint on the instance declaration:

* `CharVector` is declared `where type vector = String.string`. Because
  `STRING` specifies `eqtype string`, `CharVector.vector` inherits equality.
* `WideCharVector` is declared `where type elem = WideChar.char` and nothing
  more.

Meanwhile, `TEXT` shares `CharVector.vector = String.string`. For `WideText`,
the specification requires `WideText.String.string = WideString.string` and
`WideText.CharVector.vector = WideString.string`. Because `WideString.string`
admits equality, `WideText.CharVector.vector` must admit equality.

Any implementation where `WideText.CharVector` is the top-level
`WideCharVector` must therefore give `WideCharVector.vector` equality. The
specification omitted `where type vector = WideString.string` from
`WideCharVector`.

### What Rune does

Rune makes the text types of `TEXT_IO` and `TEXT_STREAM_IO` the signatures'
own, as `MONO_VECTOR`, `PRIM_IO` and `STREAM_IO` already have theirs, and
says them where each structure is declared:

* `TextIO :> TEXT_IO where type StreamIO.vector = CharVector.vector where
  type StreamIO.elem = Char.char where type StreamIO.substring =
  Substring.substring` and its readers and writers `TextPrimIO`'s, which
  gives `TextIO` the very types of the page;
* `WideTextIO :> TEXT_IO` with `WideCharVector.vector`, `WideChar.char`,
  `WideSubstring.substring` and the readers and writers of
  `WideTextPrimIO`, in
  [`lib/basis/seal_widetextio.sml`](../lib/basis/seal_widetextio.sml).

`STRING_CVT` has the character and the string as types of its own in the
same way, `StringCvt` is declared with `char` and `string`, and
`WideStringCvt` with the wide ones. The deviations are `TEXT_IO/generic`,
`TEXT_STREAM_IO/generic`, `STRING_CVT/generic` and
`WideStringCvt/not-in-the-specification`, each written on the signature or
the structure it is about and pinned by the Basis suite. The change of the
specification that would make them unnecessary is below.

Rune declares `WideCharVector` as the specification should have, `where type
vector = WideString.string`. The strings are made first and the vectors of
wide characters are a view of them, so plain `MONO_VECTOR` serves and
`STRING` gives the vectors their equality
([basis-compat.md](basis-compat.md#widecharvector-must-admit-equality-and-its-declaration-cannot-say-so)).

## A change request for the specification

What follows is for the maintainers of the Basis Library specification. It
was type-checked on Rune, HaMLet, MLton, Poly/ML and SML/NJ, and built into
Rune's library, where every configuration of the Basis suite passes with it
(rune; Rune's library compiled by MLton, Poly/ML, MLKit and three builds of
SML/NJ; MLton's library compiled by Rune). It needs the wide family built in
the order of the 8-bit one (*What Rune does* above).

### What is wrong

1. **`WideTextIO :> TEXT_IO` cannot be met.** `TEXT_STREAM_IO` writes
   `include STREAM_IO where type vector = CharVector.vector where type elem =
   Char.char`. `TEXT_IO` writes its readers and writers as `TextPrimIO`'s.
   No structure of wide characters matches either.
2. **`WideCharVector :> MONO_VECTOR where type elem = WideChar.char` cannot
   admit equality,** but `TEXT` shares its vector type with
   `WideString.string`, which must. `MONO_VECTOR` declares `type vector` so
   that `RealVector` can exist. `CharVector` escapes through `where type
   vector = String.string`; `WideCharVector` was not given the same
   constraint.
3. **`STRING_CVT`'s functions over text exist for 8-bit text only.**

### The change

The text types leave the signatures and go to the declarations, as
`MONO_VECTOR`, `PRIM_IO` and `STREAM_IO` already do it. `TEXT_STREAM_IO` and
`TEXT_IO` gain `type substring`. File names stay `string`, which is
`String.string`. `STRING_CVT` takes its character and string types as its own,
and a `WideStringCvt` joins the optional structures.

```sml
signature TEXT_STREAM_IO =
sig
  include STREAM_IO
  type substring
  val inputLine : instream -> (vector * instream) option
  val outputSubstr : outstream * substring -> unit
end

(* 2. TEXT_IO: the same; file names stay String.string. Written out, since
   `include IMPERATIVE_IO` cannot give StreamIO the larger signature (the
   page's own text is not valid SML here: Rune's erratum
   TEXT_IO/include-rewritten). *)
signature TEXT_IO =
sig
  structure StreamIO : TEXT_STREAM_IO
  type vector = StreamIO.vector
  type elem = StreamIO.elem
  type substring = StreamIO.substring
  type instream
  type outstream
  val input : instream -> vector
  val input1 : instream -> elem option
  val inputN : instream * int -> vector
  val inputAll : instream -> vector
  val canInput : instream * int -> int option
  val lookahead : instream -> elem option
  val closeIn : instream -> unit
  val endOfStream : instream -> bool
  val output : outstream * vector -> unit
  val output1 : outstream * elem -> unit
  val flushOut : outstream -> unit
  val closeOut : outstream -> unit
  val mkInstream : StreamIO.instream -> instream
  val getInstream : instream -> StreamIO.instream
  val setInstream : instream * StreamIO.instream -> unit
  val mkOutstream : StreamIO.outstream -> outstream
  val getOutstream : outstream -> StreamIO.outstream
  val setOutstream : outstream * StreamIO.outstream -> unit
  val getPosOut : outstream -> StreamIO.out_pos
  val setPosOut : outstream * StreamIO.out_pos -> unit
  val inputLine : instream -> vector option
  val outputSubstr : outstream * substring -> unit
  val openIn : string -> instream
  val openOut : string -> outstream
  val openAppend : string -> outstream
  val openString : vector -> instream
  val stdIn : instream
  val stdOut : outstream
  val stdErr : outstream
  val print : vector -> unit
  val scanStream : ((elem, StreamIO.instream) StringCvt.reader
                    -> ('a, StreamIO.instream) StringCvt.reader)
                   -> instream -> 'a option
end

(* 3. STRING_CVT over a character and string pair. *)
signature STRING_CVT =
sig
  eqtype char
  eqtype string
  datatype radix = BIN | OCT | DEC | HEX
  datatype realfmt
    = SCI of int option
    | FIX of int option
    | GEN of int option
    | EXACT
  type ('a, 'b) reader = 'b -> ('a * 'b) option
  val padLeft : char -> int -> string -> string
  val padRight : char -> int -> string -> string
  val splitl : (char -> bool) -> (char, 'a) reader -> 'a -> string * 'a
  val takel : (char -> bool) -> (char, 'a) reader -> 'a -> string
  val dropl : (char -> bool) -> (char, 'a) reader -> 'a -> 'a
  val skipWS : (char, 'a) reader -> 'a -> 'a
  type cs
  val scanString : ((char, cs) reader -> ('a, cs) reader) -> string -> 'a option
end
```

The declarations, with each changed or new line marked:

```sml
structure StringCvt :> STRING_CVT
  where type char = Char.char                                (* new *)
  where type string = String.string                          (* new *)
structure WideStringCvt :> STRING_CVT  (* OPTIONAL *)        (* new *)
  where type char = WideChar.char
  where type string = WideString.string
  where type radix = StringCvt.radix
  where type realfmt = StringCvt.realfmt

structure WideString :> STRING  (* OPTIONAL *)
  where type char = WideChar.char
structure WideChar :> CHAR  (* OPTIONAL *)
  where type string = WideString.string
structure WideCharVector :> MONO_VECTOR  (* OPTIONAL *)
  where type vector = WideString.string                      (* added *)
  where type elem = WideChar.char
structure WideCharVectorSlice :> MONO_VECTOR_SLICE  (* OPTIONAL *)
  where type vector = WideCharVector.vector
  where type elem = WideChar.char
structure WideSubstring :> SUBSTRING  (* OPTIONAL *)
  where type substring = WideCharVectorSlice.slice
  where type string = WideString.string
  where type char = WideChar.char

structure TextIO :> TEXT_IO
  where type StreamIO.vector = CharVector.vector             (* moved from TEXT_STREAM_IO *)
  where type StreamIO.elem = Char.char                       (* moved from TEXT_STREAM_IO *)
  where type StreamIO.substring = Substring.substring        (* new *)
  where type StreamIO.reader = TextPrimIO.reader             (* moved from TEXT_IO *)
  where type StreamIO.writer = TextPrimIO.writer             (* moved from TEXT_IO *)
  where type StreamIO.pos = TextPrimIO.pos                   (* moved from TEXT_IO *)
structure WideTextIO :> TEXT_IO  (* OPTIONAL *)
  where type StreamIO.vector = WideCharVector.vector         (* new: the page has none *)
  where type StreamIO.elem = WideChar.char
  where type StreamIO.substring = WideSubstring.substring
  where type StreamIO.reader = WideTextPrimIO.reader
  where type StreamIO.writer = WideTextPrimIO.writer
  where type StreamIO.pos = WideTextPrimIO.pos
```

Unchanged: `TEXT`, `CHAR`, `STRING`, `SUBSTRING`, `MONO_VECTOR`, `PRIM_IO`,
`STREAM_IO` and `IMPERATIVE_IO`. With `WideCharVector`'s added constraint,
`TEXT`'s sharing holds for `Text` and `WideText` with plain `MONO_VECTOR`.
No other signature is needed.

### What it costs

- **Implementations of 8-bit text** add `type substring` to `TextIO` and
  `TextIO.StreamIO`: two lines. With them, the real `TextIO` of MLton,
  Poly/ML and SML/NJ matches the new `TEXT_IO`, and their real `StringCvt`
  the new `STRING_CVT`.
- **Programs** that name `TEXT_IO`, `TEXT_STREAM_IO` or `STRING_CVT` as a
  functor's parameter lose the knowledge that `vector` is `string`, unless
  they add the `where type`. None was found in HOL4, MLton's libraries
  (smlnj-lib, CML, mlyacc-lib and the others) or the SML '97 corpus. The
  only users are implementations of the Basis.
- **Alternatives considered:**
  - a new signature `GEN_TEXT_IO`, with `TEXT_IO` as its 8-bit instance, as
    `BIN_IO` is an instance of `IMPERATIVE_IO`;
  - `IO` as a substructure of `TEXT`.

  The first adds names and keeps the synopsis line `WideTextIO :> TEXT_IO`
  false. The second needs the generic `TEXT_IO` anyway.
