(* setuid to the user ID the process already has changes nothing. *)
structure E = Posix.ProcEnv
fun uid () = SysWord.fmt StringCvt.DEC (E.uidToWord (E.getuid ()))
val () = print ("uid before: " ^ uid () ^ "\n")
val () = (E.setuid (E.getuid ()); print "setuid (getuid ()) returned\n")
         handle OS.SysErr (m, _) => print ("SysErr " ^ m ^ "\n")
val () = print ("uid after: " ^ uid () ^ "\n")
