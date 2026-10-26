(* a free type variable of a value no use can determine *)
val x = [] @ []
val () = print (Int.toString (length x) ^ "\n")
