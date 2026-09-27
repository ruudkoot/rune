(* Calls that fail, each of which must raise OS.SysErr. *)
fun try name f =
  (f (); print (name ^ ": no exception\n"))
  handle OS.SysErr (_, SOME e) => print (name ^ ": SysErr " ^ Posix.Error.errorName e ^ "\n")
       | OS.SysErr (_, NONE) => print (name ^ ": SysErr without a syserror\n")
structure FS = Posix.FileSys
val () = (let val out = TextIO.openOut "file.txt" in TextIO.closeOut out end)
val () = try "unlink of a missing file" (fn () => FS.unlink "no-such-file")
val () = try "rmdir of a missing directory" (fn () => FS.rmdir "no-such-dir")
val () = try "rename of a missing file" (fn () => FS.rename {old = "no-such-file", new = "new-name"})
val () = try "link to a missing file" (fn () => FS.link {old = "no-such-file", new = "new-name"})
val () = try "symlink onto an existing name" (fn () => FS.symlink {old = "x", new = "file.txt"})
val () = try "chown of a missing file" (fn () => FS.chown ("no-such-file", Posix.ProcEnv.getuid (), Posix.ProcEnv.getgid ()))
val () = try "close of a closed descriptor" (fn () => let val {infd, outfd} = Posix.IO.pipe ()
                                                   in Posix.IO.close infd; Posix.IO.close outfd; Posix.IO.close infd end)
val () = FS.unlink "file.txt"
