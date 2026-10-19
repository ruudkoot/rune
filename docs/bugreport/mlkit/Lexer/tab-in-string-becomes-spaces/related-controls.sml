(* A raw DEL and a raw ESC, which the Definition does not allow in a
   string constant either. MLKit keeps them as they are. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
val () = print (bytes "abc" ^ "\n")
