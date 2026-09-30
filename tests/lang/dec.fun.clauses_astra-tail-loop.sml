fun loop n = if n = 0 then 42 else
  let val next = loop in ((); next (n - 1)) end
val _ = print (Int.toString (loop 1000000) ^ "\n")
