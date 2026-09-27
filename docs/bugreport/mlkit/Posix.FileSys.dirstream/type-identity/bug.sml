(* Posix.FileSys.dirstream is identical to OS.FileSys.dirstream. *)
val d : OS.FileSys.dirstream = Posix.FileSys.opendir "."
val () = OS.FileSys.closeDir d
val () = print "dirstream: the same type\n"
