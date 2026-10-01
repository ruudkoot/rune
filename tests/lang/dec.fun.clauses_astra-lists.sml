fun map f xs = case xs of [] => [] | x :: rest => f x :: map f rest
fun sum xs = case xs of [] => 0 | x :: rest => x + sum rest
val _ = print (Int.toString (sum (map (fn x => x * 2) [5, 7, 9])) ^ "\n")
