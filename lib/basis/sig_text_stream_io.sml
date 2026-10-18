(* The functional streams of `STREAM_IO` where the elements are characters,
   with the two operations that only text has: reading a line and writing a
   substring.

   Everything of `STREAM_IO` holds here unchanged. The elements are the
   characters of one kind of text and the vectors its strings: `char` and
   `string` for `TextIO.StreamIO`, `WideChar.char` and `WideString.string`
   for `WideTextIO.StreamIO`.

   Area: Input and output

   Deviation: `TEXT_STREAM_IO/generic`. The page writes `include STREAM_IO
   where type vector = CharVector.vector where type elem = Char.char`, and
   `substring` for `Substring.substring`, so no stream of wide characters
   can match it, and the optional `WideTextIO.StreamIO` the page declares
   has no signature. Here the three types are the signature's own --
   `substring` is a type of it, as `vector_slice` is of `PRIM_IO` -- and
   `TextIO` is declared `where type StreamIO.vector = CharVector.vector
   where type StreamIO.elem = Char.char where type StreamIO.substring =
   Substring.substring`, which gives `TextIO.StreamIO` the very types of the
   page. A structure that matches the page's signature matches this one
   once it has the type `substring`. The change of the specification it
   proposes is in docs/unicode.md.

   Pinned by: `TextIO.StreamIO:TEXT_STREAM_IO/generic`,
   `WideTextIO.StreamIO:TEXT_STREAM_IO/generic`,
   `TextIO.StreamIO:TEXT_STREAM_IO/signature-TEXT_STREAM_IO`

   See also: `STREAM_IO`, `TEXT_IO`, `SUBSTRING` *)
signature TEXT_STREAM_IO =
sig
  include STREAM_IO

  (* The type of the substrings of the vectors: `Substring.substring` for
     `TextIO.StreamIO`, `WideSubstring.substring` for `WideTextIO.StreamIO`. *)
  type substring

  (* `inputLine f` is `SOME` of the next line, with its newline, and the stream after it, or `NONE` at an end of stream.

     Reading: `TextIO.StreamIO.inputLine/last-line-without-a-newline`. A last
     line that runs into an end of stream gets a newline appended, so that
     every line returned ends in one, and the stream returned is past that
     end of stream. At an end of stream itself it is `NONE`.

     Raises: `IO.Io` if the reader fails.

     Example: `Option.map #1 (inputLine (TextIO.getInstream (TextIO.openString
     "a\nb"))) = SOME "a\n"` *)
  val inputLine : instream -> (vector * instream) option

  (* `outputSubstr (f, ss)` writes the characters of the substring `ss`.

     It is `output (f, Substring.string ss)` (of the substrings of its own
     kind of text), and so raises what that raises,
     with `"output"` as the `function` of the `IO.Io`.

     Raises: `IO.Io` if the writer fails, or if the stream is closed or
     terminated. *)
  val outputSubstr : outstream * substring -> unit
end
