(* Unix.execute of a program that does not exist. The parent reads what
   the child writes to its standard output. *)
val me = Posix.ProcEnv.getpid ()
fun pid () = SysWord.fmt StringCvt.DEC (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
val p : (TextIO.instream, TextIO.outstream) Unix.proc =
  Unix.execute ("./no-such-program", [])
  handle OS.SysErr (m, _) =>
    (print ("SysErr in process " ^ pid ()
            ^ (if Posix.ProcEnv.getpid () = me then " (the parent)" else " (a child, running this program's handler)")
            ^ ": " ^ m ^ "\n");
     TextIO.flushOut TextIO.stdOut;
     Posix.Process.exit 0w7)
val fromChild = TextIO.inputAll (Unix.textInstreamOf p)
val status = Unix.reap p
val () = print ("parent: the child wrote: \"" ^ String.toString fromChild ^ "\"\n")
val () = print ("parent: the child's status: " ^ (case Unix.fromStatus status of
                                                   Unix.W_EXITED => "W_EXITED"
                                                 | Unix.W_EXITSTATUS w => "W_EXITSTATUS " ^ Word8.fmt StringCvt.DEC w
                                                 | _ => "other") ^ "\n")
