(* An exception that no rule of a handler matches is raised again from the
   handler, and the trace puts that raise at the `handle`
   (docs/bugreport/rune/handler-reraise-position). The rule here, which never
   runs, calls `last`, which calls TextIO.flushOut. The raise again once took
   the position of the end of that rule; inlined, at -O1 and -O2, that was the
   end of flushOut's body, and the trace named flushOut, which never ran. The
   same program at -O0 is rt.trace_reraise_O0, at -O2 rt.trace_reraise_O2. *)
exception Failed of string
fun last () = TextIO.flushOut TextIO.stdOut
fun protect f () = f () handle Failed why => last ()
fun job () = (print "working\n"; raise Fail "not Failed")
val () = protect job ()
