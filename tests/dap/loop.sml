fun loop (n : int) = if n = 0 then 0 else loop (n - 1)
val _ = loop 100000000000
