fun id x = x
val a = id 1
val b = id "s"
val c = id (id true)
val () = print (Int.toString a ^ b ^ Bool.toString c ^ "\n")
val r = let fun pair x = (x, x) in (pair 1, pair "a") end
val () = print (Int.toString (#1 (#1 r)) ^ #2 (#2 r) ^ "\n")
fun map f [] = [] | map f (x :: xs) = f x :: map f xs
val () = print (Int.toString (length (map Int.toString [1, 2])) ^ Int.toString (length (map (fn x => x) ["a"])) ^ "\n")
