(* valbind ::= pat = exp <and valbind> | rec valbind *)
val x = 10 and rec f = fn 0 => 0 | n => n + f (n - 1) and g = fn n => f n * 2
val () = print (Int.toString (x + f 3 + g 3) ^ "\n")
