fun sum n acc = if n = 0 then acc else sum (n - 1) (acc + n)
val first = sum 10
val _ = print (Int.toString (first 0) ^ " " ^ Int.toString (sum 5 10) ^ "\n")
