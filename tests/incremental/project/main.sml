(* uses them all, and prints *)
val () = print (Int.toString (D.area2 (A.Square 3)) ^ "\n")
val () = (raise A.Bad "a") handle A.Bad s => print ("handled " ^ s ^ "\n")
