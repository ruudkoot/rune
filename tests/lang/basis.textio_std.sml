val () = TextIO.output (TextIO.stdOut, "to stdout\n")
val () = TextIO.output (TextIO.stdErr, "to stderr\n")
val () = TextIO.output1 (TextIO.stdOut, #"c")
val () = TextIO.print "\n"
val () = TextIO.flushOut TextIO.stdOut
val all = TextIO.inputAll TextIO.stdIn
val () = print (Int.toString (size all) ^ ":" ^ all)
val () = print (Bool.toString (isSome (TextIO.inputLine TextIO.stdIn)) ^ "\n")
