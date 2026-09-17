fun f {a, b} = a + b
fun g {a = x, b = y} = x * y
fun h {name : string, age} = name ^ Int.toString age
val () = print (Int.toString (f {a = 1, b = 2}) ^ Int.toString (g {b = 3, a = 4}) ^ h {age = 5, name = "n"} ^ "\n")
val {x = {y = {z}}} = {x = {y = {z = "deep"}}}
val () = print (z ^ "\n")
