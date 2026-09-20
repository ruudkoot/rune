(* requires: Word32 LargeWord LargeInt StringCvt *)
(* uses: spec-sigs/WORD.sml *)
(* Word32 matches WORD. *)
structure TestWord32Sig =
struct
  structure C : SPEC_WORD = Word32
  val () = T.check ("Word32:WORD/matches", fn () => true)
end
