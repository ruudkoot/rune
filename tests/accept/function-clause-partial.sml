fun choose [] 0 = (print "body-zero\n"; 0)
  | choose [] n = (print "body-empty\n"; n)
  | choose (_ :: _) n = (print "body-list\n"; n + 1)
val partial = choose (print "first\n"; [])
val _ = print "partial\n"
val _ = print (Int.toString (partial (print "second\n"; 42)) ^ "\n")
val another = choose [1]
val _ = print (Int.toString (another 41) ^ "\n")
