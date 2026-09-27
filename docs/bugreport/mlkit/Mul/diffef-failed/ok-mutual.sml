exception E of int
fun f (n : int) : unit = if n = 0 then raise E 1 else app []
and app [] = () | app (x :: xs) = (f x; app xs)
val () = f 0 handle E k => print (Int.toString k ^ "\n")
