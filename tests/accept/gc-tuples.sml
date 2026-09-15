fun loop (n, pair) =
  if n = 0 then pair
  else let val (a, b) = pair in loop (n - 1, (a + 1, b + 2)) end
val (a, b) = loop (20000, (0, 0))
val _ = print (Int.toString a ^ " " ^ Int.toString b ^ "\n")
