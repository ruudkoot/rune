(* Text files and the standard streams: the imperative streams of characters,
   with the ways of opening a file.

   This is the signature a program reaches for first. It is `IMPERATIVE_IO`
   over characters, so everything written there holds; what it adds is
   `openIn`, `openOut`, `openAppend` and `openString`, the three standard
   streams, `inputLine`, `print` and `scanStream`.

   A text file holds characters; on the systems Rune runs on nothing is
   translated, so what `output` writes is what `inputAll` reads back, newline
   for newline. `BIN_IO` is the same for bytes.

   `StreamIO` is the functional stream underneath, reached through
   `getInstream` and `getOutstream`; `TEXT_STREAM_IO` describes it.

   Area: Input and output

   See also: `IMPERATIVE_IO`, `TEXT_STREAM_IO`, `BIN_IO`, `STRING_CVT`,
   `OS_FILE_SYS`

   Erratum: `TEXT_IO/include-rewritten`. The page writes `include
   IMPERATIVE_IO` and then specifies `StreamIO` again as a
   `TEXT_STREAM_IO`, which is not valid SML. What it means is that a
   structure matching `TEXT_IO` also matches `IMPERATIVE_IO` and has a
   `StreamIO` matching `TEXT_STREAM_IO`; that is what stands here, with the
   substructure first, then the members of `IMPERATIVE_IO` in full, then the
   ones of `TEXT_IO`.

   Deviation: `TEXT_IO/WideTextIO-not-matched`. The optional `WideTextIO` is
   not matched against this signature, because the types here are written
   `string` and `char`; the suite checks that its readers and writers match
   `PRIM_IO`, and that its vectors are the strings of `WideString` and its
   elements the characters of `WideChar`, instead.

   Pinned by: `WideTextIO.vector/is-WideString.string`,
   `WideTextIO.elem/is-WideChar.char`, `WideTextPrimIO:PRIM_IO/matches` *)
signature TEXT_IO =
sig
  (* The functional text streams underneath, with the readers and writers of `TextPrimIO`. *)
  structure StreamIO : TEXT_STREAM_IO
    where type reader = TextPrimIO.reader
    where type writer = TextPrimIO.writer
    where type pos = TextPrimIO.pos

  (* ---- The members of IMPERATIVE_IO ---- *)

  (* The type of what is read and written: `string`. *)
  type vector = StreamIO.vector

  (* The type of the elements: `char`. *)
  type elem = StreamIO.elem

  (* The type of the input streams. *)
  type instream

  (* The type of the output streams. *)
  type outstream

  (* `input f` is the characters that are there without waiting, and moves `f` past them.

     Raises: `IO.Io` if the reader fails. *)
  val input : instream -> vector

  (* `input1 f` is `SOME` of the next character, or `NONE` at an end of stream.

     Raises: `IO.Io` if the reader fails. *)
  val input1 : instream -> elem option

  (* `inputN (f, n)` is `n` characters, or all there are before the next end of stream.

     Raises: `Size` if `n < 0`, or if the string to be returned would be
     longer than `String.maxSize`. *)
  val inputN : instream * int -> vector

  (* `inputAll f` is everything up to the next end of stream.

     Raises: `IO.Io` if the reader fails; `Size` if the result would be longer
     than `String.maxSize`. *)
  val inputAll : instream -> vector

  (* `canInput (f, n)` is how many of `n` characters, at most, can be read without waiting, or `NONE`.

     Raises: `Size` if `n < 0`. *)
  val canInput : instream * int -> int option

  (* `lookahead f` is `SOME` of the next character without removing it, or `NONE` at an end of stream.

     Raises: `IO.Io` if the reader fails. *)
  val lookahead : instream -> elem option

  (* `closeIn f` closes the stream and the file underneath.

     Raises: `IO.Io` if the file cannot be closed. *)
  val closeIn : instream -> unit

  (* `endOfStream f` is `true` when nothing is left before the next end of stream.

     Raises: `IO.Io` if the reader fails. *)
  val endOfStream : instream -> bool

  (* `output (f, s)` writes the characters of `s`.

     Raises: `IO.Io` if the stream is closed, with the cause `ClosedStream` and
     nothing written, or if the file cannot be written to.

     Implementation: `TextIO.output/no-translation`. On the POSIX systems the
     suite runs on, a text file holds exactly the characters written to it:
     no newline is translated and no character is dropped, for all 256
     of them.

     Pinned by: `TextIO.output/every-character`,
     `TextIO.output1/every-character`, `TextIO.inputAll/every-character` *)
  val output : outstream * vector -> unit

  (* `output1 (f, c)` writes the single character `c`.

     Raises: `IO.Io` as `output` does. *)
  val output1 : outstream * elem -> unit

  (* `flushOut f` hands what the stream holds to the file.

     Reading: `TextIO.flushOut/closed-is-a-no-op`. Through `STREAM_IO` ("a
     no-op on terminated streams", and a closed stream is terminated too),
     flushing a closed outstream does nothing rather than raising.

     Pinned by: `TextIO.flushOut/closed-stream-is-a-no-op` *)
  val flushOut : outstream -> unit

  (* `closeOut f` flushes the stream and closes it and the file.

     Raises: `IO.Io` if the flush or the close fails. *)
  val closeOut : outstream -> unit

  (* `mkInstream s` is an imperative stream holding the functional stream `s`. *)
  val mkInstream : StreamIO.instream -> instream

  (* `getInstream f` is the functional stream that `f` is at. *)
  val getInstream : instream -> StreamIO.instream

  (* `setInstream (f, s)` makes `f` continue at `s`. *)
  val setInstream : instream * StreamIO.instream -> unit

  (* `mkOutstream s` is an imperative stream holding the functional stream `s`. *)
  val mkOutstream : StreamIO.outstream -> outstream

  (* `getOutstream f` flushes `f` and is the functional stream underneath. *)
  val getOutstream : outstream -> StreamIO.outstream

  (* `setOutstream (f, s)` flushes what `f` holds and then makes it write to `s`. *)
  val setOutstream : outstream * StreamIO.outstream -> unit

  (* `getPosOut f` flushes `f` and is the position it is now at.

     Raises: `IO.Io` if the file has no positions, or the flush fails. *)
  val getPosOut : outstream -> StreamIO.out_pos

  (* `setPosOut (f, opos)` flushes `f` and moves it to the position `opos`.

     What is written afterwards replaces what stood there.

     Raises: `IO.Io` if the file has no positions, or the flush fails. *)
  val setPosOut : outstream * StreamIO.out_pos -> unit

  (* ---- The members of TEXT_IO ---- *)

  (* `inputLine f` is `SOME` of the next line, with its newline, or `NONE` at an end of stream.

     A last line that runs into an end of stream gets a newline appended, so
     every line ends in one.

     Raises: `IO.Io` if the reader fails.

     Reading: `TextIO.inputLine/does-not-pass-the-end-of-stream`. An
     `inputLine` that gives `NONE` does not consume the end of stream it
     found -- `TEXT_STREAM_IO.inputLine` returns no stream in that case, so
     there is none to move on to -- and it keeps giving `NONE` even after the
     file has grown. Poly/ML reads on there.

     Pinned by: `TextIO.inputLine/file-grows-after-end-of-stream` *)
  val inputLine : instream -> string option

  (* `outputSubstr (f, ss)` writes the characters of the substring `ss`.

     Raises: `IO.Io` if the stream is closed or the file cannot be written to.

     Reading: `TextIO.outputSubstr/Io-function-is-output`. It is "equivalent
     to `output`", so the `function` of an `IO.Io` it raises is `"output"`, as
     MLton and Poly/ML report it. SML/NJ reports `"outputSubstr"`.

     Pinned by: `TextIO.outputSubstr/Io-closed-stream-function` *)
  val outputSubstr : outstream * substring -> unit

  (* `openIn name` is a stream reading the file `name` from its start.

     Raises: `IO.Io` if the file cannot be opened, with the system's error as
     the cause and `"openIn"` as the `function`. *)
  val openIn : string -> instream

  (* `openOut name` is a stream writing the file `name`, which it empties or creates.

     Implementation: `TextIO.openOut/buffer-mode`. The mode is `LINE_BUF`
     when the file is a terminal and `BLOCK_BUF` otherwise, as the
     specification asks; but the stream itself holds nothing back. The VM
     keeps the block and flushes every file at exit, so what a program writes
     with `print` and what it writes through a stream reach the file in the
     order it wrote them.

     Raises: `IO.Io` if the file cannot be opened. *)
  val openOut : string -> outstream

  (* `openAppend name` is a stream writing at the end of the file `name`, which it creates if it is not there.

     Raises: `IO.Io` if the file cannot be opened. *)
  val openAppend : string -> outstream

  (* `openString s` is a stream reading the characters of `s`, and no file. *)
  val openString : string -> instream

  (* The standard input of the program. *)
  val stdIn : instream

  (* The standard output of the program. *)
  val stdOut : outstream

  (* The standard error of the program, which holds nothing back: its mode is `NO_BUF`. *)
  val stdErr : outstream

  (* `print s` writes `s` to `stdOut` and flushes it.

     It is the `print` of the top-level environment. *)
  val print : string -> unit

  (* `scanStream scan f` runs a scanner over `f` and moves `f` to where it stopped.

     `scan` is a function of the shape that `StringCvt` describes: it takes a
     reader and reads from a source, here the functional stream underneath.

     Reading: `TextIO.scanStream/moves-only-on-success`. By the
     implementation the page gives, the stream is moved to where the scanner
     stopped when it returns `SOME`, and not at all when it returns `NONE`,
     whatever the scanner read while trying.

     Pinned by: `TextIO.scanStream/*` *)
  val scanStream : ((Char.char, StreamIO.instream) StringCvt.reader
                    -> ('a, StreamIO.instream) StringCvt.reader)
                   -> instream -> 'a option
end
