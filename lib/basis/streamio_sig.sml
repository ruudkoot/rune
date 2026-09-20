(* Streams as values: reading gives the elements and the stream that is left,
   so a stream can be kept, read twice, and read from again where it was.

   An instream is a position in a chain of segments that the reader fills in
   as they are wanted, and reading never changes what a stream in hand holds:
   `input f` twice gives the same elements twice, because the second call
   works on the same `f`. That is what makes lookahead and backtracking
   possible without a buffer of one's own, and what `TEXT_IO.scanStream`
   uses.

   The chain goes on after an end of stream, because a file may grow: a
   stream past an end of stream reads what was appended since. So an end of
   stream is a place in the chain, not a state of the stream, and a stream
   may pass several of them. `input`, `input1` and `inputN` move past the one
   they meet; `endOfStream` only looks.

   An outstream, in contrast, is imperative: `output` writes, and holds what
   the buffer mode says to hold. `getReader` and `getWriter` take the reader
   or the writer back out and leave the stream truncated or terminated; after
   that the stream is done with.

   Whatever a reader or a writer raises is caught and raised again as the
   `cause` of an `IO.Io`, with the name of that reader or writer.

   Area: Input and output

   See also: `IO`, `PRIM_IO`, `TEXT_STREAM_IO`, `IMPERATIVE_IO`, `TEXT_IO` *)
signature STREAM_IO =
sig
  (* The type of the elements. *)
  type elem

  (* The type of vectors of them, which a read returns and `output` takes. *)
  type vector

  (* The type of the functional input streams.

     Reading: `StreamIO.instream/segments-are-shared`. Two streams that share
     a segment read the same elements from it: the reader is asked for a
     chunk once, and the chunk stays in the chain. The chain continues past
     an end of stream, so a stream that was kept from before an end of stream
     still reads what was there. *)
  type instream

  (* The type of the output streams, which are not functional: `output` changes what they hold. *)
  type outstream

  (* A position in an outstream, together with the stream it is in. *)
  type out_pos

  (* The type of the readers the streams are built on, a `PRIM_IO.reader`. *)
  type reader

  (* The type of the writers the streams are built on, a `PRIM_IO.writer`. *)
  type writer

  (* The type of the positions of that reader and writer, a `PRIM_IO.pos`. *)
  type pos

  (* ---- Reading ---- *)

  (* `input f` is the elements that are left in the current chunk and the stream after them.

     At an end of stream it is the empty vector and the stream immediately
     past that end of stream, so a following `input` reads what the source
     has gained since.

     Raises: `IO.Io` if the reader fails, or if it offers no way to read that
     waits.

     Reading: `StreamIO.input/Io-carries-the-reader`. The page of `IO` says
     what the fields hold: the exception the reader raised is the `cause` and
     the reader's own name is the `name`.

     Pinned by: `*IO.StreamIO.input/Io-when-the-reader-fails`,
     `*IO.StreamIO.input/Io-name-is-the-reader's` *)
  val input : instream -> vector * instream

  (* `input1 f` is `SOME` of the first element and the stream after it, or `NONE` at an end of stream.

     Raises: `IO.Io` if the reader fails.

     Example: `let val s = TextIO.getInstream (TextIO.openString "abc") in
     (Option.map #1 (TextIO.StreamIO.input1 s), Option.map #1
     (TextIO.StreamIO.input1 s)) end = (SOME #"a", SOME #"a")` for a stream is
     a value, and reading from it gives another. *)
  val input1 : instream -> (elem * instream) option

  (* `inputN (f, n)` is `n` elements and the stream after them, or all there are before the next end of stream.

     Raises: `Size` if `n < 0`, or if the vector to be returned would be
     longer than the greatest length of a vector.

     Reading: `StreamIO.inputN/fewer-is-past-the-end-of-stream`. When fewer
     than `n` elements come before an end of stream, the stream returned is
     the one `inputAll` would give: immediately past that end of stream.
     Exactly `n` elements that end at one leave the stream before it.

     Pinned by: `*IO.StreamIO.inputN/fewer-then-past-the-end-of-stream` *)
  val inputN : instream * int -> vector * instream

  (* `inputAll f` is everything up to the next end of stream, and the stream past it. *)
  val inputAll : instream -> vector * instream

  (* `canInput (f, n)` is how many of `n` elements, at most, can be read without waiting, or `NONE`.

     `NONE` means that not even one element can be had without waiting.

     Reading: `StreamIO.canInput/what-is-counted`. Counted are the elements
     already in the chain, then what the reader's `readVecNB` yields, which
     the stream keeps: such a lookahead commits the stream to those elements.
     A reader without `readVecNB` is asked for `avail` instead.

     Raises: `Size` if `n < 0`. *)
  val canInput : instream * int -> int option

  (* `closeIn f` marks the stream closed and closes its reader.

     Closing a truncated or an already closed stream is allowed and does
     nothing more. A closed stream reads as if it ended where what had
     already been read ends. *)
  val closeIn : instream -> unit

  (* `endOfStream f` is `true` when nothing is left before the next end of stream.

     Reading: `StreamIO.endOfStream/does-not-consume`. It does not move past
     the end of stream it finds, so it stays `true` until a read consumes it;
     that read returns the empty vector, and only afterwards are elements
     that the source gained seen.

     Raises: `IO.Io` if the reader fails while it is asked for more. *)
  val endOfStream : instream -> bool

  (* ---- Writing ---- *)

  (* `output (f, v)` writes the elements of `v`, holding back what the buffer mode allows.

     Raises: `IO.Io` if the writer fails, or if the stream is closed or
     terminated.

     Reading: `StreamIO.output/Io-closed-writes-nothing`. The cause on a
     closed or terminated stream is `ClosedStream`, from the list of `IO`,
     and nothing is written.

     Pinned by: `*IO.StreamIO.output/Io-closed`,
     `*IO.StreamIO.output/Io-terminated`,
     `*IO.StreamIO.output/Io-terminated-writes-nothing` *)
  val output : outstream * vector -> unit

  (* `output1 (f, x)` writes the single element `x`.

     Raises: `IO.Io` as `output` does. *)
  val output1 : outstream * elem -> unit

  (* `flushOut f` hands what the stream holds to its writer.

     Raises: `IO.Io` if the writer fails.

     Reading: `StreamIO.flushOut/empties-first`. The buffer is emptied before
     it is passed on, so a writer that fails cannot cause the same elements
     to be written twice. Flushing a terminated or a closed stream does
     nothing.

     Pinned by: `*IO.StreamIO.flushOut/closed-is-a-no-op` *)
  val flushOut : outstream -> unit

  (* `closeOut f` flushes the stream, marks it closed and closes its writer.

     Raises: `IO.Io` if the flush or the writer fails.

     Reading: `StreamIO.closeOut/a-failed-flush-leaves-it-open`. Closing an
     already closed stream does nothing; a terminated one is not flushed; and
     when the flush fails the stream stays open, so that the elements it
     holds are not lost.

     Pinned by: `*IO.StreamIO.closeOut/left-open-when-flushing-fails` *)
  val closeOut : outstream -> unit

  (* ---- Readers and writers ---- *)

  (* `mkInstream (rd, v)` is a stream that reads `v` first and then what `rd` gives.

     `v` is what was taken from the reader already and is being handed back;
     the reader is augmented, so the stream uses whatever reads can be built
     from it. *)
  val mkInstream : reader * vector -> instream

  (* `getReader f` is the reader of `f` and what was read ahead but not consumed, and truncates `f`.

     The reader is the one that was given to `mkInstream`, not the augmented
     one.

     Raises: `IO.Io` if `f` is closed or already truncated.

     Reading: `StreamIO.getReader/Io-cause-is-ClosedStream`. A truncated
     stream is one that has given its reader away; the cause is
     `ClosedStream` for it as for a closed one.

     Pinned by: `*IO.StreamIO.getReader/Io-truncated`,
     `*IO.StreamIO.getReader/Io-closed` *)
  val getReader : instream -> reader * vector

  (* `filePosIn f` is the position of the element that would be read next.

     Raises: `IO.Io` if the stream has no positions, or if it has been
     truncated or closed.

     Reading: `StreamIO.filePosIn/what-is-unsupported`. "Does not support the
     operation" means that the reader has no `getPos`, and the cause of the
     `IO.Io` is then `RandomAccessNotSupported`, from the list of `IO`. A reader
     that has `getPos` may still fail to tell where it is (a pipe), and the
     chunks read then carry no position, which raises as well.

     Pinned by: `*IO.StreamIO.filePosIn/Io-without-positions`,
     `*IO.StreamIO.filePosIn/Io-cause`,
     `*IO.StreamIO.filePosIn/Io-truncated` *)
  val filePosIn : instream -> pos

  (* ---- Buffering ---- *)

  (* `setBufferMode (f, mode)` makes `f` hold back what `mode` says.

     Changing to `NO_BUF` flushes what is held; changing between `LINE_BUF`
     and `BLOCK_BUF` does not.

     Raises: `IO.Io` if that flush fails. *)
  val setBufferMode : outstream * IO.buffer_mode -> unit

  (* `getBufferMode f` is the mode `f` holds back by. *)
  val getBufferMode : outstream -> IO.buffer_mode

  (* `mkOutstream (wr, mode)` is a stream that writes through `wr`, holding back what `mode` says.

     Reading: `StreamIO.mkOutstream/the-writer-is-augmented`. The
     specification does not say whether the writer is augmented here; this
     one augments it, and `getWriter` still gives back the writer that was
     passed in. *)
  val mkOutstream : writer * IO.buffer_mode -> outstream

  (* `getWriter f` flushes `f`, terminates it, and is its writer and its buffer mode.

     Raises: `IO.Io` if `f` is closed, or if the flush fails.

     Reading: `StreamIO.getWriter/terminated-is-not-closed`. A stream that is
     already terminated gives its writer and its mode again without flushing;
     only a closed one raises.

     Pinned by: `*IO.StreamIO.getWriter/Io-closed` *)
  val getWriter : outstream -> writer * IO.buffer_mode

  (* `getPosOut f` flushes `f` and is the position it is now at, together with `f` itself.

     Raises: `IO.Io` if the writer has no positions, if the flush fails, or if
     `f` is terminated or closed.

     Implementation: `StreamIO.getPosOut/is-a-file-offset`. For a stream over
     a file the position is the offset of a byte from the start of it, which
     is what `BinPrimIO.pos` holds.

     Pinned by: `*IO.StreamIO.getPosOut/file-offsets` *)
  val getPosOut : outstream -> out_pos

  (* `setPosOut opos` flushes the stream of `opos`, moves it to that position, and is that stream.

     Raises: `IO.Io` if the writer has no positions, if the flush fails, or if
     the stream is terminated or closed.

     Reading: `StreamIO.setPosOut/writes-over`. What is written after it
     replaces what stood at that position; the stream is not truncated
     there.

     Pinned by: `*IO.StreamIO.setPosOut/file-overwrites` *)
  val setPosOut : out_pos -> outstream

  (* `filePosOut opos` is the position that `opos` records, without its stream. *)
  val filePosOut : out_pos -> pos
end
