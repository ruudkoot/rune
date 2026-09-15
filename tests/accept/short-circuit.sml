val _ = if false andalso (1 div 0 = 0) then print "bad" else print "a"
val _ = if true orelse (1 div 0 = 0) then print "b" else print "bad"
val _ = if true then print "c" else print (Int.toString (1 div 0))
val _ = if false then print (Int.toString (1 div 0)) else print "d\n"
