(* requires: Word64 LargeWord LargeInt StringCvt *)
(* uses: spec-sigs/WORD.sml *)
(* Word64 matches WORD. *)
structure TestWord64Sig =
struct
  structure C : SPEC_WORD = Word64
  val () = T.check ("Word64:WORD/matches", fn () => true)
end
