(* chmod and fchmod a file, and show its mode as stat(1) prints it. *)
structure FS = Posix.FileSys
structure S = FS.S
fun show what = (print (what ^ ": "); ignore (OS.Process.system "stat -c '%A (%a)' f.txt"))
val () = (let val out = TextIO.openOut "f.txt" in TextIO.closeOut out end)
val () = FS.chmod ("f.txt", S.flags [S.irusr, S.iwusr, S.irgrp])
val () = show "after chmod rw-r-----"
val () = FS.chmod ("f.txt", S.irwxu)
val () = show "after chmod rwx------"
val fd = FS.openf ("f.txt", FS.O_RDONLY, FS.O.flags [])
val () = FS.fchmod (fd, S.flags [S.irusr, S.iroth])
val () = Posix.IO.close fd
val () = show "after fchmod r-----r--"
val () = FS.unlink "f.txt"
