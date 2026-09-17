val x = 40
fun pick true x = x + 1 | pick false y = x + y
val f = fn (true,x) => x | (false,y) => x + y
fun shadow true shadow = shadow | shadow false shadow = shadow + 1
val _ = print (Int.toString (pick false 2) ^ "\n")
val _ = print (Int.toString (f (false,2)) ^ "\n")
val _ = print (Int.toString (shadow false 41) ^ "\n")
