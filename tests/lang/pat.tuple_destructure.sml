fun f (a, (b, c), d) = a + b + c + d
val () = print (Int.toString (f (1, (2, 3), 4)) ^ "\n")
val ((x, y), z) = ((1, 2), 3)
val () = print (Int.toString (x + y + z) ^ "\n")
fun unit () = "unit"
val () = print (unit () ^ "\n")
