(* The byte E9 in a character constant. *)
val c = #"é"
val () = print (Int.toString (ord c) ^ "\n")
