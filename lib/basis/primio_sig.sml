(* The layer under the streams: a reader is a source of elements, a writer a
   sink for them, and both are records of the operations they happen to have.

   A reader or a writer is a plain value that a program can make itself, out
   of a file descriptor, a vector, a network connection or nothing at all.
   Every operation is an `option`, because a source need not offer all of
   them: a pipe cannot be positioned, a file cannot promise not to wait. What
   is `NONE` is what the source cannot do; `augmentReader` and
   `augmentWriter` fill in what can be built from the rest.

   `readVec`, `readArr`, `writeVec` and `writeArr` are the operations that
   may wait; the ones whose names end in `NB` never wait and answer `NONE`
   instead. `block` waits until a read or a write would not; `canInput` and
   `canOutput` say whether it would. A read returns fewer elements than asked
   for when fewer are there, and the empty vector, or 0, at the end of the
   stream.

   `STREAM_IO` is the layer above: it buffers, keeps what was read, and turns
   what these raise into the `cause` of an `IO.Io`.

   Area: Input and output

   See also: `IO`, `STREAM_IO`, `TEXT_IO`, `BIN_IO`, `POSIX_IO`

   Erratum: `PRIM_IO/pos-of-the-instances`. The specification
   leaves `vector_slice` and `array_slice` abstract; in `TextPrimIO` and
   `BinPrimIO` they are the slice types of the corresponding structures,
   which is what every implementation does and what the suite relies on. *)
signature PRIM_IO =
sig
  (* The type of the elements read and written. *)
  type elem

  (* The type of vectors of them: what a read returns and a write takes. *)
  type vector

  (* The type of stretches of such a vector, which `writeVec` writes. *)
  type vector_slice

  (* The type of arrays of them: what `readArr` reads into. *)
  type array

  (* The type of stretches of such an array, which `readArr` and `writeArr` work on. *)
  type array_slice

  (* The type of positions in the source or the sink.

     Implementation: `PRIM_IO.pos/of-the-instances`. `BinPrimIO.pos` is the
     integer type of `Position`, and a position is the offset of a byte from
     the start of the file, so `compare` is the order of those numbers.
     `TextPrimIO.pos` is abstract: a program can compare positions and give
     them back to `setPos`, and nothing more.

     Pinned by: `BinPrimIO.compare/*` `TextPrimIO.compare/*` *)
  eqtype pos

  (* `compare (p, q)` orders two positions: earlier in the stream is less. *)
  val compare : pos * pos -> order

  (* A source of elements: its name, how much it likes to be read at a time, and the operations it has.

     `readVec n` reads at most `n` elements and waits for at least one;
     `readArr sl` reads into a stretch of an array and gives the number of
     elements read; the `NB` pair do the same without waiting, and answer
     `NONE` when they would have to. `block` waits until a read would not.
     `canInput` says whether one would wait. `avail` is how many elements are
     there without waiting, or `NONE` when that cannot be told. `getPos`,
     `setPos`, `endPos` and `verifyPos` are the positions; `close` releases
     the source; `ioDesc` is the descriptor the operating system knows it by,
     for `OS.IO.poll`.

     Reading: `PRIM_IO.reader/after-close`. Once `close` has been called,
     every function of the reader but `close` and `getPos` raises `IO.Io`
     with the cause `IO.ClosedStream`. The specification says both that and
     "raise `IO.ClosedStream`", so the suite accepts either from a reader
     that Rune did not make.

     Implementation: `PRIM_IO.reader/what-a-file-has`. The readers Rune makes
     for a file offer `readVec`, `avail`, `close` and `ioDesc`, and the
     positions only when the file has them; `augmentReader` derives the rest
     that can be derived.

     Pinned by: `*PrimIO.RD/*` `Posix.IO.mkBinReader/*` *)
  datatype reader =
    RD of {name : string,
           chunkSize : int,
           readVec : (int -> vector) option,
           readArr : (array_slice -> int) option,
           readVecNB : (int -> vector option) option,
           readArrNB : (array_slice -> int option) option,
           block : (unit -> unit) option,
           canInput : (unit -> bool) option,
           avail : unit -> int option,
           getPos : (unit -> pos) option,
           setPos : (pos -> unit) option,
           endPos : (unit -> pos) option,
           verifyPos : (unit -> pos) option,
           close : unit -> unit,
           ioDesc : RuneIODesc.iodesc option}

  (* A sink for elements, with the operations of a reader turned around.

     `writeVec sl` and `writeArr sl` write a stretch and give the number of
     elements written, which may be fewer than the stretch holds; the caller
     writes the rest. The `NB` pair never wait. `canOutput` says whether a
     write would wait. The positions and `close` are as for a reader, and
     `ioDesc` is again the descriptor.

     Reading: `PRIM_IO.writer/after-close`. Once `close` has been called,
     every function of the writer but `close` raises `IO.Io` with the cause
     `IO.ClosedStream`.

     Reading: `PRIM_IO.writer/partial-writes`. A write may write only part of
     what it was given; `STREAM_IO` retries until everything is written. *)
  datatype writer =
    WR of {name : string,
           chunkSize : int,
           writeVec : (vector_slice -> int) option,
           writeArr : (array_slice -> int) option,
           writeVecNB : (vector_slice -> int option) option,
           writeArrNB : (array_slice -> int option) option,
           block : (unit -> unit) option,
           canOutput : (unit -> bool) option,
           getPos : (unit -> pos) option,
           setPos : (pos -> unit) option,
           endPos : (unit -> pos) option,
           verifyPos : (unit -> pos) option,
           close : unit -> unit,
           ioDesc : RuneIODesc.iodesc option}

  (* `openVector v` is a reader that delivers the elements of `v` and is then at the end of its stream.

     The data are there already, so the reader has every read operation and
     waits for nothing; its `name` is `"<vector>"`.

     Reading: `PrimIO.openVector/readVecNB-is-there`. Nothing has to be
     waited for, so `readVecNB` is present and always `SOME`, with `SOME` of
     the empty vector once the vector is spent.

     Pinned by: `*PrimIO.openVector/*` *)
  val openVector : vector -> reader

  (* `nullRd ()` is a reader that is at the end of its stream from the start.

     Reading: `PrimIO.nullRd/is-a-closed-source`. It "acts like a reader that
     is always at end-of-stream": every read gives nothing and waits for
     nothing, it has no positions, and once closed it behaves as any other
     closed reader.

     Pinned by: `*PrimIO.nullRd/*` *)
  val nullRd : unit -> reader

  (* `nullWr ()` is a writer that accepts everything and keeps nothing.

     Reading: `PrimIO.nullWr/is-a-sink`. It "serves as a sink": every write
     reports that it wrote all it was given, and once closed it behaves as
     any other closed writer.

     Pinned by: `*PrimIO.nullWr/*` *)
  val nullWr : unit -> writer

  (* `augmentReader rd` is `rd` with the read operations that can be built from the ones it has.

     A vector read becomes an array read by copying and the other way round;
     a blocking read is a non-blocking one done after `block`; a
     non-blocking read is a blocking one that `canInput` says will not wait.
     An operation the reader already has is kept as it is, and the fields
     that are not reads are unchanged.

     Reading: `PrimIO.augmentReader/what-cannot-be-built`. What the table
     does not reach stays `NONE`: there is no non-blocking read without
     `canInput` or an `NB` operation to build it from, and no blocking read
     without `block` or a blocking operation.

     Pinned by: `*PrimIO.augmentReader/*` *)
  val augmentReader : reader -> reader

  (* `augmentWriter wr` is `wr` with the write operations that can be built from the ones it has.

     Implementation: `PrimIO.augmentWriter/the-whole-table`. The same table
     as for a reader, turned around: every row of it is built, an operation
     the writer has is kept as it is, and what cannot be reached stays
     `NONE`.

     Pinned by: `*PrimIO.augmentWriter/*` *)
  val augmentWriter : writer -> writer
end
