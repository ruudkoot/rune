(* Operating-system strings are UTF-8 on Unicode names, in every source
   mode. Decimal escapes describe the bytes independently of the compiler. *)
val name = "\206\187\195\169\240\159\154\128.txt"
fun say (label, ok) = print (label ^ ": " ^ Bool.toString ok ^ "\n")
val dir = OS.FileSys.tmpName ()
val () = (OS.FileSys.remove dir; OS.FileSys.mkDir dir)
val path = OS.Path.concat (dir, name)
val out = TextIO.openOut path
val () = (TextIO.output (out, "bytes\n"); TextIO.closeOut out)
val input = TextIO.openIn path
val () = say ("unicode file", TextIO.inputAll input = "bytes\n")
val () = TextIO.closeIn input
val stream = OS.FileSys.openDir dir
val () = say ("unicode listing", OS.FileSys.readDir stream = SOME name andalso OS.FileSys.readDir stream = NONE)
val () = (OS.FileSys.rewindDir stream; say ("unicode rewind", OS.FileSys.readDir stream = SOME name); OS.FileSys.closeDir stream)
val full = OS.FileSys.fullPath path
val () = say ("unicode fullPath", OS.FileSys.fileSize full = 6)
val () = (OS.FileSys.remove path; OS.FileSys.rmDir dir)
val () = say ("missing environment", OS.Process.getEnv "RuneWindowsUnicodeNeverSet" = NONE
                                    andalso Posix.ProcEnv.getenv "RuneWindowsUnicodeNeverSet" = NONE)
