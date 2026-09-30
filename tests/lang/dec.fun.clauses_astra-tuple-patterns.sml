val (x,(_,y),()) = (40,(false,2),())
val () = print (Int.toString (x+y) ^ "\n")
val swap = fn (a,b) => (b,a)
val (yes,n) = swap (42,true)
fun result ((),(_,x)) y = if yes then x + y else 0
val _ = print (Int.toString (result ((),(false,n)) 0) ^ "\n")
