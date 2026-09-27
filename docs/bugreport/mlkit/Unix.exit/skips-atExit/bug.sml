(* Unix.exit after writing to a file and registering an action with
   OS.Process.atExit. After the run, flushed.txt should hold "flushed" and
   atexit.txt "ran". *)
val () = OS.Process.atExit (fn () =>
           let val out = TextIO.openOut "atexit.txt" in TextIO.output (out, "ran"); TextIO.closeOut out end)
val out = TextIO.openOut "flushed.txt"
val () = TextIO.output (out, "flushed")
val () = Unix.exit 0w0
