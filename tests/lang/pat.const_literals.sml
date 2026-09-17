fun f 0 = "zero" | f ~1 = "minus one" | f _ = "other"
fun g "a" = 1 | g "bb" = 2 | g _ = 0
fun h #"x" = true | h _ = false
fun w 0w0 = "w0" | w _ = "wn"
val () = print (f 0 ^ f ~1 ^ f 7 ^ Int.toString (g "a" + g "bb" + g "c") ^ Bool.toString (h #"x") ^ Bool.toString (h #"y") ^ w 0w0 ^ w 0w1 ^ "\n")
