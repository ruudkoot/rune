(* signature TEXT_IO as the change request of docs/unicode.md writes it (the
   deviation `TEXT_IO/generic` of lib/basis): the transcription of TEXT_IO.sml and
   scr/TEXT_STREAM_IO.sml,
   with the types of the text the signature's own. Not the page: a test that
   matches a structure against this checks the change request, and so does
   scripts/gen-basis-sigs.sh, which holds the library's TEXT_IO to this
   instead of to the page's. *)
signature SCR_TEXT_IO =
sig
  structure StreamIO : SCR_TEXT_STREAM_IO

  (* IMPERATIVE_IO *)
  type vector = StreamIO.vector
  type elem = StreamIO.elem
  type substring = StreamIO.substring

  type instream
  type outstream

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

  val mkInstream : StreamIO.instream -> instream
  val getInstream : instream -> StreamIO.instream
  val setInstream : instream * StreamIO.instream -> unit

  val mkOutstream : StreamIO.outstream -> outstream
  val getOutstream : outstream -> StreamIO.outstream
  val setOutstream : outstream * StreamIO.outstream -> unit
  val getPosOut : outstream -> StreamIO.out_pos
  val setPosOut : outstream * StreamIO.out_pos -> unit

  (* TEXT_IO *)
  val inputLine : instream -> vector option
  val outputSubstr : outstream * substring -> unit
  val openIn : string -> instream
  val openOut : string -> outstream
  val openAppend : string -> outstream
  val openString : vector -> instream

  val stdIn : instream
  val stdOut : outstream
  val stdErr : outstream

  val print : vector -> unit
  val scanStream : ((elem, StreamIO.instream) StringCvt.reader
                    -> ('a, StreamIO.instream) StringCvt.reader)
                   -> instream -> 'a option
end
