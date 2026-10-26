(* determined in the same value declaration *)
val y = (fn x => x + x) 2.0
val () = print (Real.toString y ^ "\n")
