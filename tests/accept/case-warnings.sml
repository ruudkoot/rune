val _ = print (Int.toString (case (true,false) of
  (true,_) => 42 | (_,true) => 1 | (false,false) => 0 | (true,true) => 7) ^ "\n")
val _ = let val true = true in print "yes\n" end
