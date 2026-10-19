(* The Definition, Appendix E: it is a compile-time error if a constant
   "does not make sense or does not denote a value within the machine
   representation chosen for the type", such as \u0100 or \256 in
   a string of 8-bit characters. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
fun show s =
  print ("size=" ^ Int.toString (size s) ^ " bytes=" ^ bytes s ^ "\n")
val () = show "a\u0100b"
val () = show "a\256b"
