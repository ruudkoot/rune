val x = (print "a"; 123; print "b"; 7)
val _ = let val y = 8 in print "c"; print (Int.toString (x + y)); print "\n" end
