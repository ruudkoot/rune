# Unicode and Wide Text in Rune

How Rune implements Unicode and wide characters, how the Standard ML Basis
Library specifies them, and where the specification's wide text design breaks
down.

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

Rune implements `WideTextIO` with the operations of `TEXT_IO` transcribed over
`WideChar.char` and `WideString.string`:

* `WideTextIO.elem` is `WideChar.char`.
* `WideTextIO.vector` is `WideString.string`.
* `WideTextIO.StreamIO` has `reader = WideTextPrimIO.reader` and `writer =
  WideTextPrimIO.writer`.
* `WideTextIO.inputLine` returns `WideString.string option`.
* `WideTextIO.outputSubstr` takes `WideSubstring.substring`.
* `WideTextIO.openString` takes `WideString.string`.

In [`lib/basis/sig_text_io.sml`](../lib/basis/sig_text_io.sml), this is
documented as `Deviation: TEXT_IO/WideTextIO-not-matched`. In
[`lib/basis/seal_widetextio.sml`](../lib/basis/seal_widetextio.sml),
`WideTextPrimIO` is sealed with `PRIM_IO`, while `WideTextIO` is exported
unsealed because the library contains no signature for it. Its documentation is
attached directly to the structure in
[`lib/basis/widetextio.sml`](../lib/basis/widetextio.sml).

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

