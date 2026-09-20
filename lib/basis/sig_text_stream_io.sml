(* The functional streams of `STREAM_IO` where the elements are characters,
   with the two operations that only text has: reading a line and writing a
   substring.

   Everything of `STREAM_IO` holds here unchanged; the `include` fixes the
   elements to `char` and the vectors to `string`.

   Area: Input and output

   See also: `STREAM_IO`, `TEXT_IO`, `SUBSTRING` *)
signature TEXT_STREAM_IO =
sig
  include STREAM_IO
    where type vector = CharVector.vector
    where type elem = Char.char

  (* `inputLine f` is `SOME` of the next line, with its newline, and the stream after it, or `NONE` at an end of stream.

     Reading: `TextIO.StreamIO.inputLine/last-line-without-a-newline`. A last
     line that runs into an end of stream gets a newline appended, so that
     every line returned ends in one, and the stream returned is past that
     end of stream. At an end of stream itself it is `NONE`.

     Raises: `IO.Io` if the reader fails. *)
  val inputLine : instream -> (string * instream) option

  (* `outputSubstr (f, ss)` writes the characters of the substring `ss`.

     It is `output (f, Substring.string ss)`, and so raises what that raises,
     with `"output"` as the `function` of the `IO.Io`.

     Raises: `IO.Io` if the writer fails, or if the stream is closed or
     terminated. *)
  val outputSubstr : outstream * substring -> unit
end
