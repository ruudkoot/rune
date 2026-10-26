(* determined later in the same let, after a val *)
val y = let val d = fn x => x + x val z = d 2.0 in z end
val () = print (Real.toString y ^ "\n")
