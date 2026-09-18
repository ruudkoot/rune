(* requires: Word LargeWord LargeInt StringCvt *)
(* uses: spec-sigs/WORD.sml *)
(* Word matches WORD, and Word.word is the top-level word. *)
structure TestWordSig =
struct
  structure C : SPEC_WORD = Word
  val () = T.check ("Word:WORD/matches", fn () => true)
  val () = T.check ("Word:WORD/word-is-toplevel", fn () => C.+ (0w1 : word, 0w2 : word) = 0w3)
  val () = T.check ("Word:WORD/toplevel-is-word", fn () => (C.fromInt 1 : C.word) + 0w2 = 0w3)
end
