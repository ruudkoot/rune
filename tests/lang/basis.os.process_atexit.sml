(* OS.Process.atExit: the actions run at exit, the last registered first; one
   that raises is ignored, and so is a registration made by an action. *)
val () = OS.Process.atExit (fn () => print "first registered, last run\n")
val () = OS.Process.atExit (fn () => raise Fail "ignored")
val () = OS.Process.atExit (fn () => (print "last registered, first run\n";
                                      OS.Process.atExit (fn () => print "registered by an action: never run\n")))
val () = print "main\n"
val () = OS.Process.exit OS.Process.success
