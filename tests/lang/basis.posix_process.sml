(* Posix.Process, ProcEnv, Error and Signal, as far as every system has
   them: the numbers of the process, its groups and its environment, and
   the names of errors and signals. A child made by fork is
   basis.posix_fork, and the name of the system basis.posix_linux. *)
val () = print ("pid > 0: " ^ Bool.toString (SysWord.toInt (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())) > 0) ^ "\n")
val () = print ("uname names the system: "
                ^ Bool.toString (List.exists (fn (k, v) => k = "sysname" andalso v <> "") (Posix.ProcEnv.uname ())) ^ "\n")
val () = print ("groups: " ^ Bool.toString (not (List.null (Posix.ProcEnv.getgroups ()))) ^ "\n")
(* Windows writes it Path *)
val () = print ("environ has PATH: "
                ^ Bool.toString (List.exists (String.isPrefix "PATH=" o String.map Char.toUpper) (Posix.ProcEnv.environ ())) ^ "\n")
val () = print ("isatty of stdin: " ^ Bool.toString (Posix.ProcEnv.isatty Posix.FileSys.stdin) ^ "\n")
val () = print ("errorName: " ^ Posix.Error.errorName Posix.Error.noent ^ " "
                ^ Bool.toString (Posix.Error.syserror "noent" = SOME Posix.Error.noent) ^ "\n")
val () = print ("sigkill: " ^ SysWord.fmt StringCvt.DEC (Posix.Signal.toWord Posix.Signal.kill) ^ "\n")
