fun trace s x = (print s; x)
val _ = trace "f" (fn a => fn b => a + b) (trace "1" 1) (trace "2" 2)
val () = print "\n"
val _ = (trace "a" 1, trace "b" 2, trace "c" 3)
val () = print "\n"
val _ = [trace "x" 1, trace "y" 2]
val () = print "\n"
val _ = {p = trace "p" 1, q = trace "q" 2}
val () = print "\n"
val _ = {q = trace "q" 1, p = trace "p" 2}
val () = print "\n"
