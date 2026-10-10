(* generalised, and used at two record types *)
fun getX r = #x r
val a = getX {x = 1, y = "one"}
val b = getX {x = "two", y = 2}
val () = print (Int.toString a ^ b ^ "\n")
