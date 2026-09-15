val x = 7
val f = fn y => x + y
val x = 100
val g = let val x = 20 in fn y => x + y end
val _ = print (Int.toString (f 1) ^ " " ^ Int.toString (g 2) ^ " " ^ Int.toString x ^ "\n")
