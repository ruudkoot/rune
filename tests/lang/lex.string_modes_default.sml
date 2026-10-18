(* lex.string by default: a literal holds ASCII, and the escapes say the
   rest: \ddd and \u up to 255 at char and string, any code point at the wide
   types; \U needs --unicode *)
val c8 = #"\233"
val s8 = "caf\u00E9"
val cw : WideChar.char = #"\u03BB"
val sw : WideString.string = "\999\u00E9\u20AC"
val () = print (Int.toString (Char.ord c8) ^ " " ^ Int.toString (size s8) ^ " "
                ^ String.concatWith "," (List.map (Int.toString o Char.ord) (String.explode s8)) ^ "\n")
val () = print (Int.toString (WideChar.ord cw) ^ " " ^ Int.toString (WideString.size sw) ^ " "
                ^ String.concatWith "," (List.map (Int.toString o WideChar.ord) (WideString.explode sw)) ^ "\n")
