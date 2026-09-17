fun first (x, _) = x
fun const _ = 42
val _ = print "side effect\n"
val () = print (Int.toString (first (1, "ignored")) ^ Int.toString (const "anything") ^ "\n")
