(* signature TEXT_STREAM_IO as the change request of docs/unicode.md writes it (the
   deviation `TEXT_STREAM_IO/generic` of lib/basis): the transcription of TEXT_STREAM_IO.sml,
   with the types of the text the signature's own. Not the page: a test that
   matches a structure against this checks the change request, and so does
   scripts/gen-basis-sigs.sh, which holds the library's TEXT_STREAM_IO to this
   instead of to the page's. *)
signature SCR_TEXT_STREAM_IO =
sig
  include SPEC_STREAM_IO
  type substring
  val inputLine : instream -> (vector * instream) option
  val outputSubstr : outstream * substring -> unit
end
