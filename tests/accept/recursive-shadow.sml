fun f n = if n = 0 then 7 else f (n - 1)
val g = f
val f = fn n => 99
val _ = print (Int.toString (g 10) ^ " " ^ Int.toString (f 0) ^ "\n")
fun choose choose = choose
val _ = print (choose "ok\n")
