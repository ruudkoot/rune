(* The Definition of Standard ML (Revised), Section 2.2: a string constant
   holds printable characters (numbered 33-126), spaces and escape
   sequences. The literal below holds the byte E9 (e acute in Latin-1)
   after "caf", so the program must be rejected. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
val s = "café"
val () = print ("size=" ^ Int.toString (size s) ^ " bytes=" ^ bytes s ^ "\n")
