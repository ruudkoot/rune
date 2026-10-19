(* e acute written as the escape \233, which Section 2.2 allows. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
fun show s =
  print ("size=" ^ Int.toString (size s) ^ " bytes=" ^ bytes s ^ "\n")
val () = show "caf\233"
