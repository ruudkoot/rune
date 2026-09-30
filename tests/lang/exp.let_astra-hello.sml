val answer = let val x = 6 in x * 7 end
val _ = if answer = 42
        then print (Int.toString answer ^ "\n")
        else print "unexpected\n"
