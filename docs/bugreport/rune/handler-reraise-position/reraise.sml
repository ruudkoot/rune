(* An exception that a handler does not match goes on, raised again in the
   handler's frame. Compiled at -O1 or -O2 and run, this program ends

     runevm: uncaught exception SysErr <value>
       in RuneStreamIOFn.flushOut at .../lib/basis/streamio_fn.sml:333:104
       in <toplevel> at reraise.sml:15:22

   though nothing here calls flushOut: OS.FileSys.rmDir raised it, in job.
   At -O0 the first line is "in protect at reraise.sml:13:51", the end of the
   handler's rule. *)
exception Failed of string
fun last () = TextIO.flushOut TextIO.stdOut
fun protect f () = f () handle Failed why => last ()
fun job () = (print "working\n"; OS.FileSys.rmDir "/nonexistent/dir/x")
val () = protect job ()
