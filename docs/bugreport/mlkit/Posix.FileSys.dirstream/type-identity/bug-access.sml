(* Posix.FileSys.access_mode is identical to OS.FileSys.access_mode. *)
val modes : OS.FileSys.access_mode list = [Posix.FileSys.A_READ, Posix.FileSys.A_WRITE]
val () = print ("access_mode: the same type; access \".\": "
                ^ Bool.toString (OS.FileSys.access (".", modes)) ^ "\n")
