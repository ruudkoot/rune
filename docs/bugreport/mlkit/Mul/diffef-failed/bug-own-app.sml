exception E of int
fun app g [] = () | app g (x :: xs) = (g x; app g xs)
fun f (n : int) : unit = if n = 0 then raise E 1 else app f []
val () = f 0 handle E k => print (Int.toString k ^ "\n")
