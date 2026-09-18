(* requires: Word LargeInt *)
(* uses: fn/numstr.sml fn/word_fn.sml *)
(* The Word structure (signature WORD). Expected values follow the text of
   https://smlfamily.github.io/Basis/word.html. The checks that hold for every
   WORD structure are in fn/word_fn.sml, those of the conversions to and from
   LargeWord in word_large.sml, those of fmt and scan in word_scan.sml; here
   are the ones of the default word type. *)
structure TestWord =
struct
  structure Generic = TestWordFn (structure W = Word val name = "Word")

  val eqW = T.eq T.word
  val eqB = T.eq T.bool

  (* "structure Word :> WORD where type word = word" *)
  val () = eqW ("Word.word/is-toplevel-word", 0w5, fn () => (Word.+ (0w2 : word, 0w3 : word) : Word.word))
  val () = eqW ("Word.word/toplevel-is-Word.word", 0w5, fn () => (0w2 : Word.word) + (0w3 : Word.word))
  (* word constants denote the words that fromInt gives *)
  val () = eqW ("Word.fromInt/decimal-constant", 0w255, fn () => Word.fromInt 255)
  val () = eqW ("Word.fromInt/hexadecimal-constant", 0wxFF, fn () => Word.fromInt 255)
  val () = T.eq T.int ("Word.toInt/constant", 171, fn () => Word.toInt 0wxaB)
  (* the shift amounts of every WORD structure are of this type *)
  val () = eqW ("Word.<</amount-is-a-word", 0w40, fn () => Word.<< (0w5, 0w3))
  val () = eqW ("Word.>>/amount-is-a-word", 0w5, fn () => Word.>> (0w40, 0w3))
  val () = eqW ("Word.~>>/amount-is-a-word", 0w5, fn () => Word.~>> (0w40, 0w3))

  (* the top-level operators at type word are those of Word *)
  val () = T.seed 9
  val () = T.repeat (25, fn k =>
    let
      val s = "-" ^ Int.toString k
      val a = Word.fromInt (T.range (0, 1000000000)) * 0w5
      val b = Word.fromInt (T.range (0, 1000000000)) * 0w3
      val d = if b = 0w0 then 0w7 else b
    in
      eqW ("Word.+/toplevel" ^ s, Word.+ (a, b), fn () => a + b);
      eqW ("Word.-/toplevel" ^ s, Word.- (a, b), fn () => a - b);
      eqW ("Word.*/toplevel" ^ s, Word.* (a, b), fn () => a * b);
      eqW ("Word.div/toplevel" ^ s, Word.div (a, d), fn () => a div d);
      eqW ("Word.mod/toplevel" ^ s, Word.mod (a, d), fn () => a mod d);
      eqB ("Word.</toplevel" ^ s, Word.< (a, b), fn () => a < b);
      eqB ("Word.<=/toplevel" ^ s, Word.<= (a, b), fn () => a <= b);
      eqB ("Word.>/toplevel" ^ s, Word.> (a, b), fn () => a > b);
      eqB ("Word.>=/toplevel" ^ s, Word.>= (a, b), fn () => a >= b)
    end)
  val () = eqW ("Word.-/toplevel-wraps", Word.notb 0w0, fn () => 0w0 - 0w1)
  val () = eqW ("Word.+/toplevel-wraps", 0w0, fn () => Word.notb 0w0 + 0w1)
  val () = eqB ("Word.</toplevel-unsigned", true, fn () => 0w1 < Word.notb 0w0)
  val () = T.raises ("Word.div/toplevel-Div", T.isDiv, fn () => 0w1 div 0w0)
  val () = T.raises ("Word.mod/toplevel-Div", T.isDiv, fn () => 0w1 mod 0w0)
end
