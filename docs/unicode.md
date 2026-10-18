# Unicode and Wide Text in Rune

How Rune reads Unicode in source text, how it implements Unicode and wide
characters, how the Standard ML Basis Library specifies them, where the
specification's wide text design breaks down, and how Rune compares with
the specifications and the other implementations.

## The Standard ML text model

Standard ML '97 was defined around 8-bit characters: `char` is an 8-bit code
unit and `string` a sequence of them. In the 2004 Standard ML Basis Library
specification, the Basis committee introduced an optional wide-character
hierarchy (`WideChar`, `WideString`, `WideSubstring`, `WideText`,
`WideTextPrimIO` and `WideTextIO`) intended to accommodate larger character
sets such as Unicode.

In Rune:

* `Char.char` is an 8-bit character (0 to 255), and `String.string` is a
  `CharVector.vector` of 8-bit bytes.
* `WideChar.char` represents a Unicode code point, 0 to `0x10FFFF`, as MLton's
  does. The surrogates `0xD800`–`0xDFFF` are among them: the `CHAR` law
  `ord (chr i) = i` holds for every `i` up to `maxOrd`, so `WideChar.chr`
  takes them. They are refused where text meets the world: `WideTextIO`
  neither reads nor writes one, for UTF-8 holds the scalar values, the code
  points that are not surrogates.
* `WideString.string` is a type of its own, a string of code points, and
  `WideCharVector.vector` is that type, as `CharVector.vector` is
  `String.string`: the wide family is built in the order of the 8-bit one,
  and sealed at once (`RuneWideText` in
  [`lib/basis/widestring.sml`](../lib/basis/widestring.sml)). A wide
  character takes a word of the vector; `^`, `concat` and `substring` copy
  the words in C, as `String`'s copy bytes.
* `WideSubstring.substring` is a `WideCharVectorSlice.slice`.
* `WideText` packages these structures together under `TEXT`.
* `WideTextPrimIO` provides primitive readers and writers of wide characters
  under `PRIM_IO`.
* `WideTextIO` provides imperative and stream I/O for wide characters. Files read
  and written by `WideTextIO` are encoded in UTF-8.

## Source text

A source file is read in one of three *modes*, which say what its bytes are
and how much of Unicode it may hold. [units.md](units.md), *Source modes*,
says where a file's mode comes from: its build file's annotation, else the
command line, else the default. The rows *Source text*, *Strings* and
*Identifiers* of [language.md](language.md#deviations-from-the-definition)
give every rule, and the tests that pin it.

| | the default | `--unicode` (`--unicode=utf8`) | `--unicode=latin1` |
|---|---|---|---|
| the file | UTF-8 | UTF-8 | Latin-1, made UTF-8 as it is read; text that looks like UTF-8 is refused |
| a comment | UTF-8 text | UTF-8 text | Latin-1 text, but no C1 control |
| a raw character above 127 in a literal | refused: it is written as its escape (`\u00E9`) | its code point, which only `WideChar.char` and `WideString.string` take | its byte, at every type |
| the escape `\U` | refused | taken | taken |
| an alphanumeric identifier | ASCII | ASCII, and the letters, marks and digits of the identifier profile, in NFC | as under `--unicode` |

In every mode:

* **The same characters are refused,** in comments, in literals and between
  tokens: the controls but TAB, LF, CR LF and FF, DEL, the C1 controls, the
  line and paragraph separators U+2028 and U+2029, the nine explicit bidi
  controls that Trojan Source uses, a byte order mark past the start of the
  file, and text that is not well formed in the file's encoding. A literal
  refuses TAB too, and writes each of these as its escape (`\t`,
  `\u202E`). A byte order mark at the start of a UTF-8 file is dropped.
  The marks LRM, RLM and ALM and the other default-ignorable characters are
  taken in comments and literals.
* **A raw character means its code point,** as its escape does, wherever a
  mode takes it. So a program that two modes take means the same in both:
  under `--unicode`, `"é"` at `WideString.string` is the one character
  U+00E9, as `"\u00E9"` is in every mode, and not its two bytes of UTF-8.
  At `string`, where the character and its UTF-8 differ, `--unicode` refuses
  the raw character and names both escapes (`\233` for the character,
  `\195\169` for its UTF-8). Under `--unicode=latin1` a byte is its own
  code point, so the rule holds there at every type.
* **Escapes** are the Definition's, at both widths: `\ddd` goes up to 999
  at the wide types, and a character above 255 is an error at `char` and
  `string`. `\UXXXXXXXX`, Rune's extension from Successor ML, needs
  `--unicode`. A surrogate, U+D800 to U+DFFF, is refused in an escape, and
  `\x` is no escape of Standard ML. At run time there is no mode:
  `WideString.toString` and `WideChar.toString` write `\U`, and
  their `fromString` read it.
* **Names.** The identifier profile is `lib/unicode`'s
  [`Identifier`](lib/unicode/str/Identifier.md): UAX #31's XID_Start and
  XID_Continue, with `'` and `_`, less the default-ignorable characters,
  which show nothing, and 239 lookalikes of Standard ML's punctuation and
  digits. The two sets left out are frozen at Unicode 18.0.0, so that no
  later version of Unicode makes a valid name invalid. A name that is not
  in NFC is refused, with its NFC spelling, and not converted: names are
  compared by their bytes. Symbolic identifiers, record labels and numbers
  are ASCII in every mode. The compiler warns of what UTS #39 finds suspect
  in names (restricted characters, mixed scripts, names that look alike, a
  name that looks like a reserved word or like punctuation) and of a
  lookalike of `*)` in a comment, unless `--no-unicode-lints` is given.
  The data behind these warnings change with every version of Unicode,
  which is why they are warnings and not errors.
* **The Basis Library** and the libraries beside it are read in the
  default, so what they export is ASCII, and a program in any mode can
  name it.
* **Positions** are byte offsets inside the compiler. A column that a
  person reads, in a diagnostic or a REPL's trace, counts characters,
  and one that an editor's protocol reads counts UTF-16 units
  ([diagnostics.md](diagnostics.md), *Columns*). The REPL shows a
  `WideString.string` or a `WideChar.char` quoted, in UTF-8, with the
  characters that would not show, or would move the text around them,
  escaped ([repl.md](repl.md)).

## The specification defect in `WideTextIO`

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

### Why `WideTextIO :> TEXT_IO` is impossible

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

## A change request for the specification

What follows is for the maintainers of the Basis Library specification. It
was type-checked on Rune, HaMLet, MLton, Poly/ML and SML/NJ, and built into
Rune's library, where every configuration of the Basis suite passes with it
(rune; Rune's library compiled by MLton, Poly/ML, MLKit and three builds of
SML/NJ; MLton's library compiled by Rune). It needs the wide family built in
the order of the 8-bit one (the next section).

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

## The `WideCharVector` equality defect

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

Rune declares `WideCharVector` as the specification should have, `where type
vector = WideString.string`. The strings are made first and the vectors of
wide characters are a view of them, so plain `MONO_VECTOR` serves and
`STRING` gives the vectors their equality
([basis-compat.md](basis-compat.md#widecharvector-must-admit-equality-and-its-declaration-cannot-say-so)).

## Encodings and stream positions in `WideTextIO`

The Basis specification states that `WideTextIO.openIn : string -> instream`
opens a file by filename, but specifies no character encoding for the file's
contents.

In Rune:

* Files opened with `WideTextIO.openIn`, `openOut`, or `openAppend` are encoded
  in UTF-8. What is not UTF-8 raises `IO.Io` with cause `Fail "UTF-8"`:
  * on input, a byte sequence that is not one of the well-formed sequences of
    the Unicode Standard's Table 3-7: an overlong form, a surrogate, a value
    past `0x10FFFF`, a lead byte `C0`, `C1` or `F5` to `FF`, a continuation
    byte where a sequence begins, or a sequence cut short;
  * on output, a surrogate, which a `WideChar.char` may be and UTF-8 cannot
    encode.
* Streams constructed with `mkInstream` over a custom `WideTextPrimIO.reader`
  carry wide characters in memory without encoding translation, surrogates
  included.

Because UTF-8 is a variable-length encoding (1 to 4 bytes per code point):

* A character count does not equal a byte offset in the file.
* `WideTextIO` file readers and writers cannot provide `pos` seek positions,
  `ioDesc`, non-blocking operations, or `canInput` / `avail`.
* `RuneWideTextPos.pos` is an abstract type of character positions used by
  functional stream backtracking, distinct from `Position.int` byte offsets.

This limitation is recorded as `WideTextIO/file-streams-have-no-positions` in
[`lib/basis/widetextio.sml`](../lib/basis/widetextio.sml).

## Conversion asymmetries

The `STRING` and `CHAR` signatures treat standard 8-bit text as the universal
exchange format, leaving wide text asymmetric:

* `WideString.toString : WideString.string -> String.string` produces an 8-bit
  ASCII string using `\uXXXX` or `\UXXXXXXXX` escape sequences.
* `WideString.fromString : String.string -> WideString.string option` parses an
  8-bit string containing escape sequences into a wide string.
* `WideChar.toString` and `WideChar.fromString` similarly translate through
  8-bit `String.string`, and `WideChar.scan : (Char.char, 'a) StringCvt.reader
  -> (WideChar.char, 'a) StringCvt.reader` reads 8-bit `Char.char` input, as
  `CHAR` writes it.

`WideString.scan` is the exception. `STRING` writes it over the structure's
own `char`, so it is `WideString.scan : (WideChar.char, 'a) StringCvt.reader
-> (WideString.string, 'a) StringCvt.reader` and reads wide characters. In
that stream an escape is written with ASCII characters, and a character that
needs none stands for itself, those above 255 too. MLton's `WideString.scan`
reads 8-bit `Char.char` input instead.

Apart from `WideString.scan`, wide strings and characters are therefore
converted to and from printable representations via 8-bit ASCII escape
conventions rather than native wide-text streams.

`StringCvt`'s functions over text (`padLeft`, `splitl`, `skipWS`,
`scanString` and the rest) take `char` and `string`. Rune adds
`WideStringCvt`, the same functions over `WideChar.char` and
`WideString.string`, with the `radix`, `realfmt` and `reader` of `StringCvt`;
its white space is what `WideChar.isSpace` takes.

## Host support comparison

Among traditional SML implementations:

* **SML/NJ, Poly/ML, and MLKit** do not provide `WideChar`, `WideString`,
  `WideText`, `WideTextPrimIO`, or `WideTextIO`.
* **MLton** provides `WideChar`, `WideString` and `WideText`. Its `WideChar` and
  `WideString` are by default `Char32` and `String32`, whose characters are
  the code points 0 to `0x10FFFF`, surrogates included;
  `-default-type widechar16` makes them the 16-bit `Char16` and `String16`.
  For `WideTextIO` and `WideTextPrimIO`, MLton includes declarations in its
  signature files but comments out the sharing constraints in `basis.sig`
  and provides no implementation.
* **Rune** provides the complete wide text family: the code points 0 to
  `0x10FFFF` in `WideChar`, UTF-8-encoded file streams in `WideTextIO`, and
  full `PRIM_IO` readers and writers in `WideTextPrimIO`.

## Rune, the specifications and the other systems

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

* **Each mode of Rune is Standard ML '97** read from a file in the mode's
  encoding, but stricter in three ways:
  - a comment holds no control but TAB, LF, CR LF and FF, no bidi control,
    no U+2028 or U+2029, and no text that is not well formed, where the
    Definition allows any character: a deviation, pinned by tests
    ([language.md](language.md), *Source text*);
  - a surrogate in `\u` is refused, which the Definition's alphabet
    holds: a deviation, pinned by tests (*Strings*);
  - VT and a lone CR are refused. The Definition asks for no more than
    space, tab, newline and formfeed, so this is no deviation.
* **The default reads nothing that the Definition does not:** `\U` needs
  `--unicode`. Its types go further in one place, in every mode: `^`,
  `size`, `concat` and `substring` are overloaded at `WideString.string`
  as well as `string`, which Appendix E does not list (*Overloading*).
* **`--unicode` and `--unicode=latin1` go beyond the Definition in two
  rows,** non-ASCII identifiers and raw non-ASCII characters at the wide
  types, and each is pinned by tests (`lex.ident_*`, `lex.string_modes_*`).
* **A raw character in a wide literal is one character,** the code point
  that the Definition's rule for an escape would give: a number in the
  type's alphabet. MLton+ext reads one character a byte, so `"é"` at
  `WideString.string` is two characters there and one in Rune.
