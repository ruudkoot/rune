fun mark s x = (print s; x)
val _ = (mark "f" (fn x => x)) (mark "a" 42)
val _ = (mark "1" 1,mark "2" 2)
fun add x y = x+y
val _ = (mark "F" add) (mark "A" 1) (mark "B" 2)
val _ = print "\n"
