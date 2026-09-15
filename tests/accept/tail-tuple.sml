fun loop (n,acc) = if n = 0 then acc else loop (n - 1, acc + 1)
val _ = print (Int.toString (loop (100000,0)) ^ "\n")
