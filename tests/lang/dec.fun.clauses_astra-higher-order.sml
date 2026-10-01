fun compose f g x = f (g x)
val show = compose print Int.toString
val _ = show 42
val _ = print "\n"
val choice = if true then (fn x => x + 1) else (fn x => x - 1)
val _ = print (Int.toString (choice 41) ^ "\n")
