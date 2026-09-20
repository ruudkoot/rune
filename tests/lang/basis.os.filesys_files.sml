(* OS.FileSys: a directory and a file through their whole life. *)
val dir = OS.FileSys.tmpName ()
val () = OS.FileSys.remove dir
val () = OS.FileSys.mkDir dir
val () = print ("isDir: " ^ Bool.toString (OS.FileSys.isDir dir) ^ "\n")
val f = OS.Path.concat (dir, "a.txt")
val out = TextIO.openOut f
val () = (TextIO.output (out, "hello\n"); TextIO.closeOut out)
val () = print ("size: " ^ Int.toString (OS.FileSys.fileSize f) ^ " access: "
                ^ Bool.toString (OS.FileSys.access (f, [OS.FileSys.A_READ, OS.FileSys.A_WRITE])) ^ "\n")
val d = OS.FileSys.openDir dir
fun names acc = case OS.FileSys.readDir d of NONE => List.rev acc | SOME n => names (n :: acc)
val () = print ("entries: " ^ String.concatWith "," (names []) ^ "\n")
val () = OS.FileSys.closeDir d
val () = print ("modTime in the past: " ^ Bool.toString (Time.<= (OS.FileSys.modTime f, Time.now ())) ^ "\n")
val id = OS.FileSys.fileId f
val () = print ("same file: " ^ Bool.toString (OS.FileSys.compare (id, OS.FileSys.fileId f) = EQUAL) ^ "\n")
val here = OS.FileSys.getDir ()
val () = OS.FileSys.chDir dir
val () = print ("chDir: " ^ Bool.toString (OS.FileSys.getDir () <> here) ^ "\n")
val () = OS.FileSys.chDir here
val () = OS.FileSys.rename {old = f, new = OS.Path.concat (dir, "b.txt")}
val () = print ("renamed: " ^ Bool.toString (OS.FileSys.access (OS.Path.concat (dir, "b.txt"), [])) ^ "\n")
val () = OS.FileSys.remove (OS.Path.concat (dir, "b.txt"))
val () = OS.FileSys.rmDir dir
val () = print ((OS.FileSys.isDir dir; "still there") handle OS.SysErr (m, SOME e) => "gone: " ^ OS.errorName e)
val () = print "\n"
