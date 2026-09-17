fun f true true = 1 | f false false = 2
val _ = f (print "first\n"; true) (print "second\n"; false)
