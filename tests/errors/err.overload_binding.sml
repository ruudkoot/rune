(* --overloading=binding (the .cargs): `+` defaults to int where the
   innermost value declaration around it ends, the `fun` of the let, as
   HaMLet has it *)
val y = let fun double x = x + x in double 2.0 end
val () = print (Real.toString y ^ "\n")
