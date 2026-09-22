(* Posix.FileSys.createf and Posix.IO.lseek: a file made, written, and moved
   in from its end, from where it is and from its start. The numbers of
   O_RDWR, O_TRUNC and SEEK_END come from the system: where they were all 0,
   the file was opened for reading only and every seek went to the start. *)
val path = OS.FileSys.tmpName ()
val fd = Posix.FileSys.createf (path, Posix.FileSys.O_RDWR, Posix.FileSys.O.trunc,
                                Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr])
val n = Posix.IO.writeVec (fd, Word8VectorSlice.full (Byte.stringToBytes "0123456789"))
val atEnd = Posix.IO.lseek (fd, 0, Posix.IO.SEEK_END)
val back = Posix.IO.lseek (fd, ~4, Posix.IO.SEEK_CUR)
val two = Byte.bytesToString (Posix.IO.readVec (fd, 2))
val start = Posix.IO.lseek (fd, 1, Posix.IO.SEEK_SET)
val three = Byte.bytesToString (Posix.IO.readVec (fd, 3))
val () = Posix.IO.close fd
val () = print ("wrote " ^ Int.toString n ^ ", end " ^ Int.toString atEnd ^ ", back " ^ Int.toString back
                ^ " reads " ^ two ^ ", start " ^ Int.toString start ^ " reads " ^ three ^ "\n")
val () = print ("size " ^ Int.toString (OS.FileSys.fileSize path) ^ "\n")
val () = Posix.FileSys.unlink path
val () = print ("gone: " ^ Bool.toString (not (OS.FileSys.access (path, []))) ^ "\n")
