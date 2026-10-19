(* The byte E9 in other places of a literal. The first argument of show
   says what comes before it. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
fun show (what, s) =
  print (what ^ ": size=" ^ Int.toString (size s) ^ " bytes=" ^ bytes s ^ "\n")
val () = show ("ab", "abécd")
val () = show ("an escape", "\néx")
val () = show ("a gap", "\ \éx")
