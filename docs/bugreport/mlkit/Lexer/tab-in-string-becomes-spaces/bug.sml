(* The Definition of Standard ML (Revised), Section 2.2: a string constant
   holds printable characters, spaces and escape sequences; a TAB is
   written \t. The literal below holds a raw TAB, so the program
   must be rejected. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
val s = "a	b"
val () = print ("size=" ^ Int.toString (size s) ^ " bytes=" ^ bytes s ^ "\n")
