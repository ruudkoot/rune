fun item n = (print (Int.toString n); n)
val xs = [item 1, item 2, item 3]
val ys = item 4 :: (print "5"; [item 6])
val _ = if xs = [1,2,3] andalso ys = [4,6] then print "\n" else print "bad\n"
