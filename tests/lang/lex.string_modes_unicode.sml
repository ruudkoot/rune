(* lex.string under --unicode: a raw character means its code point at the
   wide types, as its escape does (X1); at char and string the escapes still
   say a byte *)
val c8 = #"\233"
val s8 = "caf\195\169"
val cw : WideChar.char = #"λ"
val sw : WideString.string = "café € 😀"
val () = print (Int.toString (Char.ord c8) ^ " " ^ Int.toString (size s8) ^ " "
                ^ String.concatWith "," (List.map (Int.toString o Char.ord) (String.explode s8)) ^ "\n")
val () = print (Int.toString (WideChar.ord cw) ^ " " ^ Int.toString (WideString.size sw) ^ " "
                ^ String.concatWith "," (List.map (Int.toString o WideChar.ord) (WideString.explode sw)) ^ "\n")
(* raw text and escapes mean the same (X1) *)
val () = print (Bool.toString (sw = "caf\u00E9 \u20AC \U0001F600" andalso cw = #"\u03BB") ^ "\n")
