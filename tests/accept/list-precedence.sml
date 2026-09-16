datatype t = C of int
val _ = if 1+1::3*2::nil = [2,6] andalso [1] <> [] then print "operators\n" else print "bad\n"
val C x :: C y :: [] = [C 20,C 22]
val _ = print (Int.toString (x+y) ^ "\n")
val _ = case [C 42] of C n :: _ => print (Int.toString n ^ "\n") | [] => print "bad\n"
