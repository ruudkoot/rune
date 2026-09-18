(* Checks of the conversions between a structure with signature WORD and
   LargeWord: toLarge, toLargeX, fromLarge and their deprecated synonyms.
   Expected values follow https://smlfamily.github.io/Basis/word.html.

     structure R = TestWordLargeFn (structure W = Word8 val name = "Word8")

   needs a LargeWord structure. The labels are name ^ ".member/case"; see
   fn/word_fn.sml for the conventions. *)
signature TEST_WORD_LARGE =
sig
  eqtype word
  val wordSize : int
  val toLarge : word -> LargeWord.word
  val toLargeX : word -> LargeWord.word
  val toLargeWord : word -> LargeWord.word
  val toLargeWordX : word -> LargeWord.word
  val fromLarge : LargeWord.word -> word
  val fromLargeWord : LargeWord.word -> word
  val toInt : word -> int
  val toIntX : word -> int
  val fromInt : int -> word
  val + : word * word -> word
  val toString : word -> string
end

functor TestWordLargeFn (structure W : TEST_WORD_LARGE val name : string) =
struct
  structure LW = LargeWord

  val ws = W.wordSize
  val lws = LW.wordSize
  fun lab s = name ^ "." ^ s
  fun showW x = "0wx" ^ W.toString x handle _ => "?"
  fun showLW x = "0wx" ^ LW.toString x handle _ => "?"

  fun eqv show (label, expected, f) =
    case (SOME (expected ()) handle _ => NONE) of
      SOME e => T.eq show (label, e, f)
    | NONE => T.fail (label, "the expected value raised an exception")
  val eqW = eqv showW
  val eqLW = eqv showLW

  val zero = W.fromInt 0
  val one = W.fromInt 1
  val lwzero = LW.fromInt 0
  val lwone = LW.fromInt 1

  (* words from their binary digits, most significant first *)
  fun wordOfBits bits = List.foldl (fn (b, v) => W.+ (W.+ (v, v), if b then one else zero)) zero bits
  fun largeWordOfBits bits = List.foldl (fn (b, v) => LW.+ (LW.+ (v, v), if b then lwone else lwzero)) lwzero bits
  fun copies (n, b : bool) = List.tabulate (if n < 0 then 0 else n, fn _ => b)

  (* "The type LargeWord.word represents the largest word supported." *)
  val () = T.check (lab "wordSize/at-most-LargeWord.wordSize", fn () => ws <= lws)

  (* toLarge: the same number; toLargeX: "the remaining bits of toLargeX w
     are all equal to the most significant bit of w" *)
  val () = eqLW (lab "toLarge/zero", fn () => lwzero, fn () => W.toLarge zero)
  val () = eqLW (lab "toLarge/200", fn () => LW.fromInt 200, fn () => W.toLarge (W.fromInt 200))
  val () = eqLW (lab "toLarge/all-ones", fn () => largeWordOfBits (copies (ws, true)),
                 fn () => W.toLarge (wordOfBits (copies (ws, true))))
  val () = eqLW (lab "toLarge/top-bit", fn () => largeWordOfBits (true :: copies (ws - 1, false)),
                 fn () => W.toLarge (wordOfBits (true :: copies (ws - 1, false))))
  val () = eqLW (lab "toLargeX/zero", fn () => lwzero, fn () => W.toLargeX zero)
  val () = eqLW (lab "toLargeX/100", fn () => LW.fromInt 100, fn () => W.toLargeX (W.fromInt 100))
  val () = eqLW (lab "toLargeX/all-ones", fn () => largeWordOfBits (copies (lws, true)),
                 fn () => W.toLargeX (wordOfBits (copies (ws, true))))
  val () = eqLW (lab "toLargeX/top-bit", fn () => largeWordOfBits (copies (lws - ws + 1, true) @ copies (ws - 1, false)),
                 fn () => W.toLargeX (wordOfBits (true :: copies (ws - 1, false))))
  val () = eqLW (lab "toLargeX/below-top-bit", fn () => largeWordOfBits (copies (ws - 1, true)),
                 fn () => W.toLargeX (wordOfBits (copies (ws - 1, true))))
  val () = eqLW (lab "toLargeWord/200", fn () => LW.fromInt 200, fn () => W.toLargeWord (W.fromInt 200))
  val () = eqLW (lab "toLargeWordX/all-ones", fn () => largeWordOfBits (copies (lws, true)),
                 fn () => W.toLargeWordX (wordOfBits (copies (ws, true))))

  (* fromLarge: "the low-order wordSize bits" *)
  val () = eqW (lab "fromLarge/zero", fn () => zero, fn () => W.fromLarge lwzero)
  val () = eqW (lab "fromLarge/200", fn () => W.fromInt 200, fn () => W.fromLarge (LW.fromInt 200))
  val () = eqW (lab "fromLarge/all-ones", fn () => wordOfBits (copies (ws, true)),
                fn () => W.fromLarge (largeWordOfBits (copies (lws, true))))
  val () = eqW (lab "fromLarge/low-ones", fn () => wordOfBits (copies (ws, true)),
                fn () => W.fromLarge (largeWordOfBits (copies (ws, true))))
  val () = eqW (lab "fromLargeWord/200", fn () => W.fromInt 200, fn () => W.fromLargeWord (LW.fromInt 200))
  val () =
    if lws > ws then
      (eqW (lab "fromLarge/two-to-the-wordSize", fn () => zero,
            fn () => W.fromLarge (largeWordOfBits (true :: copies (ws, false))));
       eqW (lab "fromLarge/two-to-the-wordSize-plus-five", fn () => W.fromInt 5,
            fn () => W.fromLarge (LW.+ (largeWordOfBits (true :: copies (ws, false)), LW.fromInt 5)));
       eqW (lab "fromLarge/high-ones", fn () => zero,
            fn () => W.fromLarge (largeWordOfBits (copies (lws - ws, true) @ copies (ws, false)))))
    else ()

  (* an Int.int result, or Overflow *)
  fun outcome f = SOME (f ()) handle Overflow => NONE
  val eqOutcome = eqv (T.option T.int)

  val () = T.seed 8
  val () = T.repeat (40, fn k =>
    let
      val s = "-" ^ Int.toString k
      fun randomBits n = List.tabulate (n, fn _ => T.range (0, 1) = 1)
      val abits =
        let val m = if T.range (0, 2) = 0 then ws else T.range (0, ws)
        in copies (ws - m, false) @ randomBits m end
      val lbits = randomBits lws
      val a = wordOfBits abits handle _ => zero
      val la = largeWordOfBits lbits handle _ => lwzero
      val j = (if T.range (0, 1) = 0 then 1 else ~1) * T.range (0, 1000000000)
    in
      eqLW (lab "toLarge/model" ^ s, fn () => largeWordOfBits (copies (lws - ws, false) @ abits),
            fn () => W.toLarge a);
      eqLW (lab "toLargeX/model" ^ s, fn () => largeWordOfBits (copies (lws - ws, List.hd abits) @ abits),
            fn () => W.toLargeX a);
      eqW (lab "fromLarge/model" ^ s, fn () => wordOfBits (List.drop (lbits, lws - ws)),
           fn () => W.fromLarge la);
      eqW (lab "fromLarge/toLarge" ^ s, fn () => a, fn () => W.fromLarge (W.toLarge a));
      eqW (lab "fromLarge/toLargeX" ^ s, fn () => a, fn () => W.fromLarge (W.toLargeX a));
      (* "toLargeWord and toLargeWordX are respective synonyms of the first
         two", "fromLargeWord is a deprecated synonym for fromLarge" *)
      eqLW (lab "toLargeWord/synonym" ^ s, fn () => W.toLarge a, fn () => W.toLargeWord a);
      eqLW (lab "toLargeWordX/synonym" ^ s, fn () => W.toLargeX a, fn () => W.toLargeWordX a);
      eqW (lab "fromLargeWord/synonym" ^ s, fn () => W.fromLarge la, fn () => W.fromLargeWord la);
      (* "the functions fromInt, toInt and toIntX are respectively equivalent to ..." *)
      eqW (lab "fromInt/through-LargeWord" ^ s,
           fn () => W.fromLargeWord (LW.fromLargeInt (Int.toLarge j)), fn () => W.fromInt j);
      eqOutcome (lab "toInt/through-LargeWord" ^ s,
                 fn () => outcome (fn () => Int.fromLarge (LW.toLargeInt (W.toLargeWord a))),
                 fn () => outcome (fn () => W.toInt a));
      eqOutcome (lab "toIntX/through-LargeWord" ^ s,
                 fn () => outcome (fn () => Int.fromLarge (LW.toLargeIntX (W.toLargeWordX a))),
                 fn () => outcome (fn () => W.toIntX a))
    end)
end
