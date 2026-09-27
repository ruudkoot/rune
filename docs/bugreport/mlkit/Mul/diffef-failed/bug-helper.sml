exception E of int
fun fail k = E k
fun f (n : int) : unit = if n = 0 then raise fail 1 else List.app f []
val () = f 0 handle E k => print (Int.toString k ^ "\n")
