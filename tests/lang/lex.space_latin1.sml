(* lex.space: white space between tokens is space, TAB, LF, CR LF and FF,
   in every mode; a string's gap holds the same *)
val	x=
  1 +	2
val s = "a\ 	

 \b"
val () = print (Int.toString x ^ " " ^ s ^ "\n")
