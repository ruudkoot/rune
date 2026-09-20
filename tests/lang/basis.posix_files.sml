(* Posix.IO, FileSys and SysDB: a pipe, a file by its descriptor, what stat
   reports, and the user database. *)
val {infd, outfd} = Posix.IO.pipe ()
val n = Posix.IO.writeVec (outfd, Word8VectorSlice.full (Byte.stringToBytes "through a pipe"))
val () = Posix.IO.close outfd
val got = Posix.IO.readVec (infd, 100)
val () = print (Int.toString n ^ ": " ^ Byte.bytesToString got ^ "\n")
val () = Posix.IO.close infd
val path = OS.FileSys.tmpName ()
val fd = Posix.FileSys.createf (path, Posix.FileSys.O_RDWR, Posix.FileSys.O.flags [], Posix.FileSys.defaultMode)
val _ = Posix.IO.writeVec (fd, Word8VectorSlice.full (Byte.stringToBytes "0123456789"))
val () = print ("seek: " ^ Int.toString (Posix.IO.lseek (fd, 3, Posix.IO.SEEK_SET)) ^ " read: "
                ^ Byte.bytesToString (Posix.IO.readVec (fd, 4)) ^ "\n")
val st = Posix.FileSys.fstat fd
val () = print ("size " ^ Int.toString (Posix.FileSys.ST.size st) ^ " reg "
                ^ Bool.toString (Posix.FileSys.ST.isReg st) ^ " uid "
                ^ Bool.toString (Posix.FileSys.ST.uid st = Posix.ProcEnv.getuid ()) ^ "\n")
val () = Posix.IO.close fd
val () = Posix.FileSys.chmod (path, Posix.FileSys.S.flags [Posix.FileSys.S.irusr])
val () = print ("mode: " ^ Word.toString (Posix.FileSys.ST.mode (Posix.FileSys.stat path)) ^ "\n")
val () = Posix.FileSys.unlink path
val me = Posix.SysDB.getpwuid (Posix.ProcEnv.getuid ())
val () = print ("user has a home: " ^ Bool.toString (String.isPrefix "/" (Posix.SysDB.Passwd.home me)) ^ "\n")
