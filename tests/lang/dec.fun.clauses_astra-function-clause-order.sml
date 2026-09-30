fun select 0 x = (print "zero\n"; x)
  | select n 0 = (print "second\n"; n)
  | select _ x = (print "rest\n"; x)
val f = fn "first" => (print "first\n"; 10)
         | "second" => 20 | _ => 30
val _ = print (Int.toString (select 0 0 + select 2 0 + select 3 4 + f "first") ^ "\n")
