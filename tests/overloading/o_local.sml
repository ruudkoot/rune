(* determined by the body of a local *)
local fun double x = x + x in val y = double 2.0 end
val () = print (Real.toString y ^ "\n")
