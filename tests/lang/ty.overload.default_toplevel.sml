(* --overloading=toplevel (the .cargs), Rune's context before the option and
   Moscow ML's: an overloaded operator is determined by the declaration at
   top level, here the whole structure; under the default, declaration,
   `+` defaults to int where `fun double` ends
   (tests/errors/err.overload_declaration) *)
structure X = struct fun double x = x + x val y = double 2.0 end
val () = print (Real.toString X.y ^ "\n")
