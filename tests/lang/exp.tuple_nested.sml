val t = (1, "two", (3.0, true))
val (a, b, (c, d)) = t
val () = print (Int.toString a ^ b ^ Real.toString c ^ Bool.toString d ^ "\n")
val () = print (Int.toString (#1 t) ^ #2 t ^ Real.toString (#1 (#3 t)) ^ "\n")
val u = ()
val () = print (Bool.toString (u = ()) ^ "\n")
