val r = ref 0
val v = (r := !r + 1; r := !r * 10; !r)
val () = print (Int.toString v ^ "\n")
val () = (print "a"; print "b"; print "c\n")
val w = (1; 2; "last")
val () = print (w ^ "\n")
