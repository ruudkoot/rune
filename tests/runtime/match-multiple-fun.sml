fun f [] = 0 | f [x] = x
val _ = f (print "argument\n"; [1,2])
