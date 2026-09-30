fun f [] 0 = 1 | f [] _ = 2
val _ = f [1] (print "second\n"; 1 div 0)
