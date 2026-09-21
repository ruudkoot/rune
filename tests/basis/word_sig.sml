(* requires: Word LargeWord SysWord LargeInt StringCvt *)
(* uses: spec-sigs/WORD.sml *)
(* Word matches WORD, and Word.word is the top-level word. LargeWord, which
   the specification requires, and SysWord, which it makes optional, match it
   too; here both are Word. *)
structure TestWordSig =
struct
  structure C : SPEC_WORD = Word
  val () = T.check ("Word:WORD/matches", fn () => true)
  structure L : SPEC_WORD = LargeWord
  val () = T.check ("LargeWord:WORD/matches", fn () => true)
  val () = T.check ("LargeWord:WORD/holds-every-word",
                    fn () => L.toInt (Word.toLarge (Word.fromInt 12345)) = 12345)
  structure S : SPEC_WORD = SysWord
  val () = T.check ("SysWord:WORD/matches", fn () => true)
  val () = T.check ("SysWord:WORD/wordSize-is-at-least-the-word",
                    fn () => S.wordSize >= Word.wordSize)
  val () = T.check ("Word:WORD/word-is-toplevel", fn () => C.+ (0w1 : word, 0w2 : word) = 0w3)
  val () = T.check ("Word:WORD/toplevel-is-word", fn () => (C.fromInt 1 : C.word) + 0w2 = 0w3)
end
