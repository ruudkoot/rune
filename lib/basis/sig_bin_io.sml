(* signature BIN_IO, transcribed from
   https://smlfamily.github.io/Basis/bin-io.html

   It includes IMPERATIVE_IO of tests/basis/spec-sigs/IMPERATIVE_IO.sml,
   whose substructure has STREAM_IO of STREAM_IO.sml; a test that uses
   this file uses those first. *)
signature BIN_IO =
sig
  include IMPERATIVE_IO
    where type StreamIO.vector = Word8Vector.vector
    where type StreamIO.elem = Word8.word
    where type StreamIO.reader = BinPrimIO.reader
    where type StreamIO.writer = BinPrimIO.writer
    where type StreamIO.pos = BinPrimIO.pos

  val openIn : string -> instream
  val openOut : string -> outstream
  val openAppend : string -> outstream
end
