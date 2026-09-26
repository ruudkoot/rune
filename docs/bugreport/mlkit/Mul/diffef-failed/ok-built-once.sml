exception E of int
val e = E 1
fun f (n : int) : unit = if n = 0 then raise e else List.app f []
val () = f 0 handle E k => print (Int.toString k ^ "\n")
