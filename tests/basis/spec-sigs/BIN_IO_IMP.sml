(* The imperative part of signature BIN_IO, transcribed from
   https://smlfamily.github.io/Basis/bin-io.html and, for the members that
   BIN_IO includes from IMPERATIVE_IO, from
   https://smlfamily.github.io/Basis/imperative-io.html.

   Left out, and specified in a later file together with STREAM_IO: the
   substructure StreamIO and the members that convert to and from it
   (mkInstream, getInstream, setInstream, mkOutstream, getOutstream,
   setOutstream, getPosOut, setPosOut).

   The pages say `type vector = StreamIO.vector` and `type elem =
   StreamIO.elem` `where type StreamIO.vector = Word8Vector.vector` and `where
   type StreamIO.elem = Word8.word`; the types are written out here. *)
signature SPEC_BIN_IO_IMP =
sig
  type vector = Word8Vector.vector
  type elem = Word8.word
  type instream
  type outstream

  (* IMPERATIVE_IO *)
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

  (* BIN_IO *)
  val openIn : string -> instream
  val openOut : string -> outstream
  val openAppend : string -> outstream
end
