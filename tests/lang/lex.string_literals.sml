val () = print "plain\n"
val () = print "esc: \\ \" \t| \065\066 \u0043 \^D\n"
val () = print "gap: abc\
              \def\n"
val () = print (Int.toString (size "") ^ " " ^ Int.toString (size "\000\001") ^ "\n")
