structure M = struct val v = 10 fun f x = x + v datatype d = D of int end
open M
val () = print (Int.toString (f 5) ^ "\n")
val D n = D 7
val () = print (Int.toString n ^ "\n")
