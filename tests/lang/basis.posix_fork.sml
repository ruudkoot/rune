(* Posix.Process.fork: a child that execs the shell of the system (sh on
   POSIX, cmd.exe on Windows) and exits with a status, and one that a
   signal ends. *)
structure P = Posix.Process
val windows = List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ())
val () = case P.fork () of
           NONE =>
             if windows then let val cmd = valOf (OS.Process.getEnv "COMSPEC") in P.exec (cmd, [cmd, "/d", "/c", "exit 7"]) end
             else P.exec ("/bin/sh", ["sh", "-c", "exit 7"])
         | SOME pid =>
             (case P.waitpid (P.W_CHILD pid, []) of
                (p, P.W_EXITSTATUS w) => print ("child " ^ Bool.toString (p = pid) ^ " exited " ^ Word8.toString w ^ "\n")
              | _ => print "other\n")
val () = case P.fork () of
           NONE => (P.pause (); P.exit 0w0)
         | SOME pid =>
             (P.kill (P.K_PROC pid, Posix.Signal.term);
              case P.waitpid (P.W_CHILD pid, []) of
                (_, P.W_SIGNALED s) => print ("signalled with term: " ^ Bool.toString (s = Posix.Signal.term) ^ "\n")
              | _ => print "other\n")
