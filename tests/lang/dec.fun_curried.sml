fun add x y = x + y
fun twice f x = f (f x)
val () = print (Int.toString (twice (add 3) 10) ^ "\n")
fun const x _ = x
val () = print (const "c" 99 ^ "\n")
