val () = print "started\n"
val () = TextIO.flushOut TextIO.stdOut
val () = ignore (Posix.Process.sleep (Time.fromSeconds 1))
val () = print "awake\n"
val () = TextIO.flushOut TextIO.stdOut
