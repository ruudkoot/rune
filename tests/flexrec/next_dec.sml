(* determined by the next declaration, no ; between *)
fun f r = #a r
val x = f {a = 1, b = 2}
val () = print (Int.toString x ^ "\n")
