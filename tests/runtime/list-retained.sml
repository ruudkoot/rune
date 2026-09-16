fun loop n xs = loop (n+1) (n :: xs)
val _ = loop 0 []
