(* Streams that remember where they are: a cell holding a functional stream,
   which every operation replaces by what it left.

   This is the layer a program normally uses. `input f` gives elements, not
   elements and a stream, because `f` itself has moved on. `TEXT_IO` and
   `BIN_IO` are this signature with the element type fixed and the ways of
   opening a file added.

   `StreamIO` is the functional stream underneath, and the stream in the cell
   can be taken out and put back: `getInstream` gives the position the
   imperative stream is at, and `setInstream` moves it. That is how a program
   backtracks over an imperative stream -- keep what `getInstream` gave, read
   on, and put it back to read the same elements again.

   The end of a stream is not a state: an imperative stream sits at a place
   in the chain of its functional stream, and a file that grows delivers what
   it gained, as `STREAM_IO` describes.

   Area: Input and output

   See also: `STREAM_IO`, `TEXT_IO`, `BIN_IO`, `PRIM_IO`

   Deviation: `IMPERATIVE_IO/functor-not-sealed`. The functor
   `ImperativeIO` is not ascribed this signature, because the library
   declares the signature after the structures that would need it; its result
   matches it, which `tests/basis` checks. *)
signature IMPERATIVE_IO =
sig
  (* The functional streams these are built on. *)
  structure StreamIO : STREAM_IO

  (* The type of vectors of elements, the one of `StreamIO`. *)
  type vector = StreamIO.vector

  (* The type of the elements, the one of `StreamIO`. *)
  type elem = StreamIO.elem

  (* The type of the input streams.

     Deviation: `IMPERATIVE_IO.instream/admits-equality`. The specification
     leaves the type abstract, and a program should not rely on more. In Rune
     it is a datatype holding a `ref`, so `=` may be written between two
     instreams and is true exactly when they are the same stream; the same
     holds for `outstream`. *)
  type instream

  (* The type of the output streams. *)
  type outstream

  (* ---- Reading ---- *)

  (* `input f` is the elements that are there without waiting for more, and moves `f` past them.

     At an end of stream it is the empty vector and `f` moves past that end
     of stream.

     Raises: `IO.Io` if the reader fails. *)
  val input : instream -> vector

  (* `input1 f` is `SOME` of the next element, or `NONE` at an end of stream.

     Raises: `IO.Io` if the reader fails.

     Reading: `IMPERATIVE_IO.input1/passes-the-end-of-stream`. An `input1`
     that returns `NONE` leaves the stream positioned after the end of stream
     it found, as `StreamIO.inputN (f, 1)` does, so a following `input1`
     delivers what the source has gained since.

     Pinned by: `*IO.input1/file-grows-after-end-of-stream` *)
  val input1 : instream -> elem option

  (* `inputN (f, n)` is `n` elements, or all there are before the next end of stream.

     Raises: `Size` if `n < 0`, or if the vector to be returned would be too
     long.

     Reading: `IMPERATIVE_IO.inputN/Size-is-about-the-result`. The
     specification writes the condition two ways; `Size` is raised when the
     number of elements to be returned exceeds the greatest length of a
     vector, as `STREAM_IO` puts it, not when `n` does.

     Pinned by: `*IO.inputN/more-than-maxSize-of-a-short-file` *)
  val inputN : instream * int -> vector

  (* `inputAll f` is everything up to the next end of stream.

     Raises: `IO.Io` if the reader fails.

     Reading: `IMPERATIVE_IO.inputAll/file-grows`. Several ends of stream are
     real for a file: a read after one delivers what was appended since, so a
     second `inputAll` need not be empty.

     Pinned by: `*IO.inputAll/file-grows-after-end-of-stream` *)
  val inputAll : instream -> vector

  (* `canInput (f, n)` is how many of `n` elements, at most, can be read without waiting, or `NONE`.

     Raises: `Size` if `n < 0`. *)
  val canInput : instream * int -> int option

  (* `lookahead f` is `SOME` of the next element without removing it, or `NONE` at an end of stream.

     Raises: `IO.Io` if the reader fails.

     Reading: `IMPERATIVE_IO.lookahead/removes-nothing`. It removes nothing
     at all, an end of stream included: at one it gives `NONE` and leaves the
     stream before that end of stream, which a following `input` then
     consumes.

     Pinned by: `*IO.lookahead/does-not-pass-an-end-of-stream`,
     `*IO.lookahead/does-not-remove` *)
  val lookahead : instream -> elem option

  (* `closeIn f` closes the stream and its reader.

     Reading: `IMPERATIVE_IO.closeIn/drops-what-was-read-ahead`. Closing
     "must also replace the functional stream with an empty stream": what the
     stream had read ahead of the program is dropped, so nothing can be read
     after `closeIn`. Closing twice is allowed.

     Raises: `IO.Io` if the reader fails while closing. *)
  val closeIn : instream -> unit

  (* `endOfStream f` is `true` when nothing is left before the next end of stream.

     Raises: `IO.Io` if the reader fails.

     Reading: `IMPERATIVE_IO.endOfStream/does-not-consume`. It does not
     consume the end of stream it finds: it stays `true` until a read does,
     that read gives nothing, and only afterwards is what the source gained
     seen.

     Pinned by: `*IO.endOfStream/file-grows-after-end-of-stream` *)
  val endOfStream : instream -> bool

  (* ---- Writing ---- *)

  (* `output (f, v)` writes the elements of `v`.

     Raises: `IO.Io` if the writer fails or the stream is closed. *)
  val output : outstream * vector -> unit

  (* `output1 (f, x)` writes the single element `x`.

     Raises: `IO.Io` if the writer fails or the stream is closed. *)
  val output1 : outstream * elem -> unit

  (* `flushOut f` hands what the stream holds to its writer.

     Raises: `IO.Io` if the writer fails. *)
  val flushOut : outstream -> unit

  (* `closeOut f` flushes the stream and closes it and its writer.

     Closing twice is allowed.

     Raises: `IO.Io` if the flush or the writer fails. *)
  val closeOut : outstream -> unit

  (* ---- The stream underneath ---- *)

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

     Raises: `IO.Io` if the writer has no positions, or the flush fails. *)
  val getPosOut : outstream -> StreamIO.out_pos

  (* `setPosOut (f, opos)` flushes `f` and moves it to the position `opos`.

     Raises: `IO.Io` if the writer has no positions, or the flush fails. *)
  val setPosOut : outstream * StreamIO.out_pos -> unit
end
