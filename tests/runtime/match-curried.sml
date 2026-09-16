datatype t = A | B
fun f A x = x+0
val partial = f (print "first\n"; B)
val _ = print "partial\n"
val _ = partial (print "second\n"; 1)
