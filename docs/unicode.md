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

