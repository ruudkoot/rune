(* A TAB in a gap \f...f\, where the Definition allows it: the gap
   is ignored. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
val () = print (bytes "a\	\b" ^ "\n")
