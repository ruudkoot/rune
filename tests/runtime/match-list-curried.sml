fun first (x :: xs) y = x
val f = first []
val _ = print "partial\n"
val _ = f (print "argument\n")
