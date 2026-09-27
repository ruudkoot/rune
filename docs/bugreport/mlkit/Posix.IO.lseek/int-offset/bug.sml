(* lseek on a pipe must raise OS.SysErr (ESPIPE); on a file it returns
   the offset it moved to. *)
structure FS = Posix.FileSys
structure IO = Posix.IO
fun show f = (Position.toString (f ())) handle OS.SysErr (m, _) => "raised SysErr \"" ^ m ^ "\""
val {infd, outfd} = IO.pipe ()
val () = print ("lseek of a pipe: " ^ show (fn () => IO.lseek (infd, 0, IO.SEEK_SET)) ^ "\n")
val fd = FS.createf ("file.bin", FS.O_RDWR, FS.O.flags [], FS.S.flags [FS.S.irusr, FS.S.iwusr])
val () = List.app (fn p => print ("lseek of a file to " ^ Position.toString p ^ ": "
                                   ^ show (fn () => IO.lseek (fd, p, IO.SEEK_SET)) ^ "\n"))
                  [1000, 1073741823, 1073741824, 3000000000]
val () = (IO.close fd; FS.unlink "file.bin")
