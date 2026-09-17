fun f (x : int) (y : real) : string = Int.toString x ^ Real.toString y
val () = print (f 1 2.5 ^ "\n")
val (a : int, b : string) = (1, "s")
val () = print (Int.toString a ^ b ^ "\n")
fun g (l : int list) = length l
val () = print (Int.toString (g [1, 2]) ^ "\n")
