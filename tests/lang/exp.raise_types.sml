exception E
fun f x = if x then 1 else raise E
val () = print (Int.toString (f true) ^ "\n")
val () = print ((f false; "no") handle E => "raised\n")
fun g () : string = raise Fail "g"
val () = print (g () handle Fail s => s ^ "\n")
val () = print (((raise Fail "in expression") ^ "x") handle Fail s => s ^ "\n")
