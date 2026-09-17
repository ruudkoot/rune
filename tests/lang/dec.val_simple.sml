val x = 1
val y = x + 1
val (a, b) = (y, "s")
val _ = print (Int.toString a ^ b ^ "\n")
val x = "shadowed"
val () = print (x ^ "\n")
val p = 1 and q = 2
val () = print (Int.toString (p + q) ^ "\n")
