(* The exit status of a process, as reap and system give it and fromStatus
   shows it. *)
fun show (Unix.W_EXITED) = "W_EXITED"
  | show (Unix.W_EXITSTATUS w) = "W_EXITSTATUS " ^ Word8.fmt StringCvt.DEC w
  | show (Unix.W_SIGNALED s) = "W_SIGNALED " ^ SysWord.fmt StringCvt.DEC (Posix.Signal.toWord s)
  | show (Unix.W_STOPPED s) = "W_STOPPED " ^ SysWord.fmt StringCvt.DEC (Posix.Signal.toWord s)
fun sh s = Unix.execute ("/bin/sh", ["-c", s]) : (TextIO.instream, TextIO.outstream) Unix.proc
val () = print ("fromStatus (reap (sh \"exit 3\"))         = " ^ show (Unix.fromStatus (Unix.reap (sh "exit 3"))) ^ "\n")
val () = print ("fromStatus (reap (sh \"kill -TERM $$\"))  = " ^ show (Unix.fromStatus (Unix.reap (sh "kill -TERM $$"))) ^ "\n")
val () = print ("fromStatus (OS.Process.system \"exit 4\") = " ^ show (Unix.fromStatus (OS.Process.system "exit 4")) ^ "\n")
val () = print ("fromStatus (OS.Process.system \"exit 0\") = " ^ show (Unix.fromStatus (OS.Process.system "exit 0")) ^ "\n")
