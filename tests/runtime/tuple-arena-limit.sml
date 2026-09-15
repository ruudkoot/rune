fun loop n = let val _ = (n,n) in loop (n+1) end
val _ = loop 0
