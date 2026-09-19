(* requires: Word16 LargeWord LargeInt StringCvt *)
(* uses: spec-sigs/WORD.sml *)
(* Word16 matches WORD. *)
structure TestWord16Sig =
struct
  structure C : SPEC_WORD = Word16
  val () = T.check ("Word16:WORD/matches", fn () => true)
end
