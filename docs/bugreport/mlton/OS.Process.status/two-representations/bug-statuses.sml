(* MLton: the other functions of OS.Process.status read it in another
   representation than system and exit. Unix.reap returns the exit code
   (through Status.fromPosix), and Unix.fromStatus (Posix.Process.fromStatus)
   reads it as the status of waitpid; so does it OS.Process.failure.
   Run: mlton bug-statuses.sml && ./bug-statuses *)
fun show st =
  case Unix.fromStatus st of
    Unix.W_EXITED => "W_EXITED"
  | Unix.W_EXITSTATUS w => "W_EXITSTATUS " ^ Int.toString (Word8.toInt w)
  | Unix.W_SIGNALED s => "W_SIGNALED " ^ SysWord.fmt StringCvt.DEC (Posix.Signal.toWord s)
  | Unix.W_STOPPED s => "W_STOPPED " ^ SysWord.fmt StringCvt.DEC (Posix.Signal.toWord s)
fun line (name, got, expected) =
  print (concat [name, " = ", got, ", expected ", expected, ": ", if got = expected then "ok" else "WRONG", "\n"])
val () = line ("fromStatus (system \"exit 3\")", show (OS.Process.system "exit 3"), "W_EXITSTATUS 3")
val () = line ("fromStatus (reap of sh -c \"exit 3\")",
               show (Unix.reap (Unix.execute ("/bin/sh", ["-c", "exit 3"]))), "W_EXITSTATUS 3")
val p : (TextIO.instream, TextIO.outstream) Unix.proc = Unix.execute ("/bin/sh", ["-c", "sleep 10"])
val () = Unix.kill (p, Posix.Signal.term)
val () = line ("fromStatus (reap of sh killed by SIGTERM)", show (Unix.reap p), "W_SIGNALED 15")
val () = let val got = show OS.Process.failure
          in print (concat ["fromStatus OS.Process.failure = ", got, ", expected W_EXITSTATUS of a non-zero code: ",
                            if String.isPrefix "W_EXITSTATUS " got then "ok" else "WRONG", "\n"]) end
