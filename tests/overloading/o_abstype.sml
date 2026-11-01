(* determined later in the body of an abstype at top level, which is one
   declaration at structure level (SML/NJ and MLKit accept it, HaMLet does
   not) *)
abstype t = T with fun double x = x + x val y = double 2.0 end
val () = print (Real.toString y ^ "\n")
