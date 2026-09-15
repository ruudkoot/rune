fun outer x = fn y => fn z => x + y + z
val f = outer 1
val g = f 2
val h = outer 20 10
val _ = print (Int.toString (g 3) ^ " " ^ Int.toString (h 4) ^ "\n")
