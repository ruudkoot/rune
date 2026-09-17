datatype t = A | B
fun A true = 1 | A false = 2
val f = fn A => A
val _ = print (Int.toString (f 40 + A false) ^ "\n")
fun names true x = x | names false x = x
val _ = print (Int.toString (names false 42) ^ "\n")
