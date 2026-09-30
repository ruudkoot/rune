val _ = case [1] of [] => print "bad\n" | _ :: _ => print "yes\n" | [x] => print "bad\n"
val _ = let val [] = [] in print "empty\n" end
val singleton = fn [x] => x
val _ = print (Int.toString (singleton [42]) ^ "\n")
