fun outer start =
  let fun go n = if n = 0 then start else go (n - 1)
  in go end
val f = outer 42
val g = outer 7
val _ = print (Int.toString (f 20) ^ " " ^ Int.toString (g 30) ^ "\n")
fun down n = if n = 0 then 42 else (fn k => down k) (n - 1)
val _ = print (Int.toString (down 10) ^ "\n")
