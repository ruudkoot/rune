(* determined later in the same let, after a fun *)
val y = let fun double x = x + x in double 2.0 end
val () = print (Real.toString y ^ "\n")
