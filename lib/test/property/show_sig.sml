(* Printers: how a value of a counterexample is shown, as Standard ML that
   reads back where the type has a literal syntax.

   Area: Property testing *)
signature SHOW =
sig
  (* A printer of values of type `'a`. *)
  type 'a show = 'a -> string

  (* `int` shows an integer.

     Example: `int ~5 = "~5"` *)
  val int : int show

  (* `word` shows a word in hexadecimal.

     Example: `word 0w255 = "0wxFF"` *)
  val word : word show

  (* `word64` shows a 64-bit word in hexadecimal. *)
  val word64 : Word64.word show

  (* `char` shows a character as a character constant.

     Example: `char #"\n" = "#\"\\n\""` *)
  val char : char show

  (* `string` shows a string as a string constant.

     Example: `string "a\tb" = "\"a\\tb\""` *)
  val string : string show

  (* `real` shows a real with the 17 digits that tell it from every other
     real, or as `Real.posInf`, `Real.negInf` or `0.0 / 0.0` where it is no
     number. *)
  val real : real show

  (* `bool` shows a boolean.

     Example: `bool true = "true"` *)
  val bool : bool show

  (* `unit` shows `()`. *)
  val unit : unit show

  (* `order` shows an order. *)
  val order : order show

  (* `option s` shows an option.

     Example: `option int (SOME 3) = "SOME 3"` *)
  val option : 'a show -> 'a option show

  (* `list s` shows a list.

     Example: `list int [1, ~2] = "[1, ~2]"` *)
  val list : 'a show -> 'a list show

  (* `vector s` shows a vector as `Vector.fromList` of a list. *)
  val vector : 'a show -> 'a vector show

  (* `array s` shows an array as `Array.fromList` of a list. *)
  val array : 'a show -> 'a array show

  (* `pair (s, t)` shows a pair.

     Example: `pair (int, bool) (1, false) = "(1, false)"` *)
  val pair : 'a show * 'b show -> ('a * 'b) show

  (* `triple (s, t, u)` shows a triple. *)
  val triple : 'a show * 'b show * 'c show -> ('a * 'b * 'c) show
end
