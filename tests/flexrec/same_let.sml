(* determined later in the same let *)
val x = let fun f r = #a r in f {a = 1, b = 2} end
val () = print (Int.toString x ^ "\n")
