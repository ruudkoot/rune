val nil = []
val [] = nil
val values = [[], [1], 2 :: 3 :: nil]
val [a, [b], c :: d :: []] = values
val _ = if a = [] then print (Int.toString (b+c+d) ^ "\n") else print "bad\n"
val pair :: [] = [(20,22)]
val (x,y) = pair
val _ = print (Int.toString (x+y) ^ "\n")
