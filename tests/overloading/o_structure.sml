(* the overloading determined by the next declaration inside one structure *)
structure X = struct fun double x = x + x val y = double 2.0 end
val () = print (Real.toString X.y ^ "\n")
