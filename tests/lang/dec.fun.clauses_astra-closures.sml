fun makeAdder x = fn y => x + y
val addTwo = makeAdder 2
val _ = print (Int.toString (addTwo 40) ^ "\n")
