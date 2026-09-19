(* signature TEXT_STREAM_IO, transcribed from
   https://smlfamily.github.io/Basis/text-stream-io.html

   It includes SPEC_STREAM_IO of tests/basis/spec-sigs/STREAM_IO.sml, so a
   test that uses this file uses that one first. *)
signature SPEC_TEXT_STREAM_IO =
sig
  include SPEC_STREAM_IO
    where type vector = CharVector.vector
    where type elem = Char.char
  val inputLine : instream -> (string * instream) option
  val outputSubstr : outstream * substring -> unit
end
