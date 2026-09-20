(* requires: TextIO StringCvt Substring *)
(* uses: spec-sigs/TEXT_IO_IMP.sml *)
(* TextIO matches the imperative part of TEXT_IO, and its element and vector
   types are char and string. *)
structure TestTextIOSig =
struct
  structure C : SPEC_TEXT_IO_IMP = TextIO
  val () = T.check ("TextIO:TEXT_IO/matches", fn () => true)
  val () = T.check ("TextIO:TEXT_IO/vector-is-string", fn () => ("" : C.vector) = ("" : TextIO.vector))
  val () = T.check ("TextIO:TEXT_IO/elem-is-char", fn () => (#"a" : C.elem) = (#"a" : TextIO.elem))
  val () = T.check ("TextIO:TEXT_IO/streams-are-TextIO-streams",
                    fn () => (C.closeIn (TextIO.openString ""); C.flushOut TextIO.stdOut; true))
end
