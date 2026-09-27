(* The kind of /dev/null, a character device that is not a terminal. *)
fun kindName k =
  if k = OS.IO.Kind.file then "file" else if k = OS.IO.Kind.dir then "dir"
  else if k = OS.IO.Kind.symlink then "symlink" else if k = OS.IO.Kind.tty then "tty"
  else if k = OS.IO.Kind.pipe then "pipe" else if k = OS.IO.Kind.socket then "socket"
  else if k = OS.IO.Kind.device then "device" else "other"
val fd = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
val () = print ("OS.IO.kind of /dev/null: " ^ kindName (OS.IO.kind (Posix.FileSys.fdToIOD fd))
                ^ " (Posix.ProcEnv.isatty: " ^ Bool.toString (Posix.ProcEnv.isatty fd) ^ ")\n")
