(* determined by the next declaration at top level, no ; between *)
fun double x = x + x
val y = double 2.0
val () = print (Real.toString y ^ "\n")
