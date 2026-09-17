fun dup (l as x :: _) = x :: l | dup [] = []
val () = print (Int.toString (length (dup [1, 2])) ^ "\n")
fun whole (p as (a, b)) = if a > b then p else (b, a)
val (m, n) = whole (1, 2)
val () = print (Int.toString m ^ Int.toString n ^ "\n")
fun typed (x : int as y) = x + y
val () = print (Int.toString (typed 4) ^ "\n")
val r as {a, ...} = {a = 1, b = 2}
val () = print (Int.toString (a + #b r) ^ "\n")
