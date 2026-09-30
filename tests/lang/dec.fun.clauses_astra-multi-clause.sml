fun map f [] = []
  | map f (x :: xs) = f x :: map f xs
fun sum [] = 0
  | sum (x :: xs) = x + sum xs
val _ = print (Int.toString (sum (map (fn x => x * 2) [5,7,9])) ^ "\n")
