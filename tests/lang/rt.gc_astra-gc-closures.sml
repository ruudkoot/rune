fun loop n =
  if n = 20000 then n
  else let val f = fn x => n + x in loop (f 1) end
val _ = print (Int.toString (loop 0) ^ "\n")
