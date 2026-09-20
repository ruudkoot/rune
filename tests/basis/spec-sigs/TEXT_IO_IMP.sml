(* The imperative part of signature TEXT_IO, transcribed from
   https://smlfamily.github.io/Basis/text-io.html and, for the members that
   TEXT_IO includes from IMPERATIVE_IO, from
   https://smlfamily.github.io/Basis/imperative-io.html.

   Left out, and specified in a later file together with TEXT_STREAM_IO: the
   substructure StreamIO itself and the members that convert to and from it
   (mkInstream, getInstream, setInstream, mkOutstream, getOutstream,
   setOutstream, getPosOut, setPosOut).

   The pages say `type vector = StreamIO.vector` and `type elem =
   StreamIO.elem`, where TEXT_STREAM_IO fixes them to CharVector.vector (which
   is String.string) and Char.char; they are written out here. The type of
   scanStream mentions StreamIO.instream, so that one type of the substructure
   is specified. *)
signature SPEC_TEXT_IO_IMP =
sig
  structure StreamIO : sig type instream end

  type vector = string
  type elem = char
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

  (* TEXT_IO *)
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
end
