val id = (fn f => f) (fn x => x)
val _ = print (Int.toString (id 42) ^ "\n")
val _ = print (Int.toString (id 7) ^ "\n")
