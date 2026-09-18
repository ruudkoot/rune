(* requires: Word LargeWord LargeInt *)
(* uses: fn/word_large_fn.sml *)
(* The conversions between Word and LargeWord: toLarge, toLargeX, fromLarge
   and their synonyms. Expected values follow the text of
   https://smlfamily.github.io/Basis/word.html; the checks are those of every
   WORD structure, in fn/word_large_fn.sml. *)
structure TestWordLarge =
struct
  structure Generic = TestWordLargeFn (structure W = Word val name = "Word")

  (* "We require that LargeWord.wordSize <= LargeInt.precision" *)
  val () = T.check ("LargeWord.wordSize/at-most-LargeInt.precision",
                    fn () => case LargeInt.precision of NONE => true | SOME p => LargeWord.wordSize <= p)
  val () = T.check ("LargeWord.wordSize/at-least-Word.wordSize", fn () => Word.wordSize <= LargeWord.wordSize)
end
