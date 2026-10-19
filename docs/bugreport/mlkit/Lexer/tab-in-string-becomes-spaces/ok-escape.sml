(* A TAB written as the escape \t. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
val () = print (bytes "a\tb" ^ "\n")
