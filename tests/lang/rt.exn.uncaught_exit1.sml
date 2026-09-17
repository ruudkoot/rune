val () = print "before\n"
exception Boom of string
val () = raise Boom "kaboom"
val () = print "never\n"
