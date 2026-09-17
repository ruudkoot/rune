fun f [] 0 = 1 | f [] _ = 2
val partial = f (print "first\n"; [1])
val _ = print "partial\n"
val _ = partial (print "second\n"; 0)
