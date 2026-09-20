(* requires: Word8 LargeWord LargeInt StringCvt *)
(* uses: spec-sigs/WORD.sml *)
(* Word8 matches WORD, as the other members of the WordN family do
   (intn_word16_sig.sml and the rest). *)
structure TestWord8Sig =
struct
  structure C : SPEC_WORD = Word8
  val () = T.check ("Word8:WORD/matches", fn () => true)
  val () = T.eq T.int ("Word8:WORD/wordSize-is-eight", 8, fn () => C.wordSize)
end
