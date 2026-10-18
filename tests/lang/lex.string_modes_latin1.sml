(* lex.string under --unicode=latin1: the file is Latin-1, and a raw
   character is its own byte at char and string, and its code point, the
   same number, at the wide types; MLKit's regexp tests write "(æ|ø|å)" *)
val c8 = #"æ"
val s8 = "(æ|ø|å)"
val cw : WideChar.char = #"é"
val sw : WideString.string = "café"
val () = print (Int.toString (Char.ord c8) ^ " " ^ Int.toString (size s8) ^ " "
                ^ String.concatWith "," (List.map (Int.toString o Char.ord) (String.explode s8)) ^ "\n")
val () = print (Int.toString (WideChar.ord cw) ^ " " ^ Int.toString (WideString.size sw) ^ " "
                ^ String.concatWith "," (List.map (Int.toString o WideChar.ord) (WideString.explode sw)) ^ "\n")
(* raw text and escapes mean the same (X1) *)
val () = print (Bool.toString (s8 = "(\230|\248|\229)" andalso sw = "caf\u00E9") ^ "\n")
