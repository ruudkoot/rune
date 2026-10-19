(* lex.ident under --unicode=latin1: the file is Latin-1, each byte its
   character, so that a name holds the letters of Latin-1: größe *)
val größe = 3
val () = print (Int.toString größe ^ "\n")
