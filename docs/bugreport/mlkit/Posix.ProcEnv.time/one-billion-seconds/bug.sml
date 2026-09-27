(* Posix.ProcEnv.time is the time since the Epoch, as Time.now. *)
val () = print ("Posix.ProcEnv.time () = " ^ LargeInt.toString (Time.toSeconds (Posix.ProcEnv.time ())) ^ " s\n")
val () = print ("Time.now ()           = " ^ LargeInt.toString (Time.toSeconds (Time.now ())) ^ " s\n")
