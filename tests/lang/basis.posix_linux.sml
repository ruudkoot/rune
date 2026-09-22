(* What only Linux prints: the name of the system, as uname gives it. The
   language suite of Windows leaves it out (tests/windows-skip.txt). *)
val () = print ("uname: " ^ (case Posix.ProcEnv.uname () of (_, s) :: _ => s | [] => "?") ^ "\n")
