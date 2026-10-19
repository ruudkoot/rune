(* lex.encoding: under --unicode=latin1 each byte is the character of its
   number; in a string it is that byte, as by default (Latin-1: é) *)
val s = "café"
val () = print (Int.toString (size s) ^ " " ^ Int.toString (Char.ord (String.sub (s, 3))) ^ "\n")
