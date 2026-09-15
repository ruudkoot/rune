fun loop n = let val f = fn x => n+x in loop (f 1) end
val _ = loop 0
