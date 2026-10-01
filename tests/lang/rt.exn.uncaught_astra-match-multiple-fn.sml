val f = fn [] => 0 | [x] => x
val _ = f (print "argument\n"; [1,2])
