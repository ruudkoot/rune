(* Posix.Process, ProcEnv, Error and Signal: a child that exits with a
   status, and one that a signal ends. *)
structure P = Posix.Process
val () = print ("pid > 0: " ^ Bool.toString (Posix.ProcEnv.getpid () > 0) ^ "\n")
val () = print ("uname: " ^ (case Posix.ProcEnv.uname () of (_, s) :: _ => s | [] => "?") ^ "\n")
val () = print ("groups: " ^ Bool.toString (not (List.null (Posix.ProcEnv.getgroups ()))) ^ "\n")
val () = print ("environ has PATH: " ^ Bool.toString (List.exists (String.isPrefix "PATH=") (Posix.ProcEnv.environ ())) ^ "\n")
val () = print ("isatty of stdin: " ^ Bool.toString (Posix.ProcEnv.isatty 0) ^ "\n")
val () = print ("errorName: " ^ Posix.Error.errorName Posix.Error.noent ^ " "
                ^ Bool.toString (Posix.Error.syserror "noent" = SOME Posix.Error.noent) ^ "\n")
val () = print ("sigkill: " ^ Int.toString Posix.Signal.kill ^ "\n")
val () = case P.fork () of
           NONE => P.exec ("/bin/sh", ["sh", "-c", "exit 7"])
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
