(* Binary files: the imperative streams of bytes, with the ways of opening a
   file.

   It is `IMPERATIVE_IO` over `Word8.word`, with the same three `open`
   functions as `TEXT_IO` and nothing else: there are no lines in a binary
   file, no standard streams of bytes, and no `openString`.

   Area: Input and output

   See also: `TEXT_IO`, `IMPERATIVE_IO`, `STREAM_IO`, `PRIM_IO`, `BYTE` *)
signature BIN_IO =
sig
  include IMPERATIVE_IO
    where type StreamIO.vector = Word8Vector.vector
    where type StreamIO.elem = Word8.word
    where type StreamIO.reader = BinPrimIO.reader
    where type StreamIO.writer = BinPrimIO.writer
    where type StreamIO.pos = BinPrimIO.pos

  (* `openIn name` is a stream reading the bytes of the file `name` from its start.

     Raises: `IO.Io` if the file cannot be opened, with the system's error as
     the cause. *)
  val openIn : string -> instream

  (* `openOut name` is a stream writing the file `name`, which it empties or creates.

     Raises: `IO.Io` if the file cannot be opened.

     Implementation: `BinIO.openOut/bytes-are-characters`. A byte written
     here is the character of the same code read by `TEXT_IO`, and the other
     way round: on POSIX nothing is translated between the two, for all 256
     values.

     Pinned by: `BinIO.output/read-back-as-text`,
     `BinIO.inputAll/written-as-text`

     Example: `let val p = OS.FileSys.tmpName () val out = openOut p in output (out, Byte.stringToBytes "ab"); closeOut out; Word8Vector.length (inputAll (openIn p)) before OS.FileSys.remove p end = 2` *)
  val openOut : string -> outstream

  (* `openAppend name` is a stream writing at the end of the file `name`, which it creates if it is not there.

     Raises: `IO.Io` if the file cannot be opened.

     Example: `let val p = OS.FileSys.tmpName () val a = openAppend p in output (a, Byte.stringToBytes "ab"); closeOut a; let val b = openAppend p in output (b, Byte.stringToBytes "c"); closeOut b end; Byte.bytesToString (inputAll (openIn p)) before OS.FileSys.remove p end = "abc"` *)
  val openAppend : string -> outstream
end
