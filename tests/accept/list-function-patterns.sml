fun first (x :: xs) y = x
val waiting = first []
val _ = print (Int.toString (first [42] true) ^ "\n")
fun empty nil y = y
val _ = print (Int.toString (empty [] 7) ^ "\n")
val take = fn (x :: _) => x
val _ = print (Int.toString (take [9]) ^ "\n")
