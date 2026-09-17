val v = let val g = fn {x, y, ...} => x + y : int in g {x = 1, y = 2, z = "z"} end
val () = print (Int.toString v ^ "\n")
val w = let fun sel {a, ...} = a in sel {a = "a", b = 1} end
val () = print (w ^ "\n")
