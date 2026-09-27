structure FS = Posix.FileSys
structure S = FS.S
fun hex m = "0wx" ^ SysWord.toString (S.toWord m)
fun b x = Bool.toString x

(* 1. The values of the modes, which the C binding gives as S_IRWXU 0700,
      S_IRUSR 0400, ..., S_ISGID 02000 (0wx1C0, 0wx100, ..., 0wx400). *)
val () = print ("S.toWord of irwxu, irusr, iwusr, ixusr, isuid: "
                ^ String.concatWith ", " (map hex [S.irwxu, S.irusr, S.iwusr, S.ixusr, S.isuid]) ^ "\n")
(* 2. irwxu is read, write and execute permission for the owner. *)
val () = print ("S.irwxu = S.flags [S.irusr, S.iwusr, S.ixusr]: "
                ^ b (S.irwxu = S.flags [S.irusr, S.iwusr, S.ixusr]) ^ "\n")
(* 3. The mode of a file made with rw-r----- *)
val () = ignore (FS.umask (S.flags []))
val rw_r_____ = S.flags [S.irusr, S.iwusr, S.irgrp]
val () = Posix.IO.close (FS.createf ("f.txt", FS.O_WRONLY, FS.O.flags [], rw_r_____))
val m = FS.ST.mode (FS.stat "f.txt")
val () = print ("ST.mode of a file made rw-r-----: " ^ hex m ^ ", = rw-r-----: " ^ b (m = rw_r_____)
                ^ ", owner's part (intersect with S.irwxu): " ^ hex (S.intersect [m, S.irwxu]) ^ "\n")
val () = FS.unlink "f.txt"
(* 4. umask returns the previous mask. *)
val () = ignore (FS.umask (S.flags [S.iwgrp, S.iwoth]))
val old = FS.umask (S.flags [S.irwxg])
val now = FS.umask old
val () = print ("umask returned " ^ hex old ^ " for the mask S.flags [S.iwgrp, S.iwoth] = "
                ^ hex (S.flags [S.iwgrp, S.iwoth]) ^ ", and " ^ hex now ^ " for S.irwxg = " ^ hex S.irwxg ^ "\n")
val () = print "the mask of the process after putting the old one back, as the shell's umask shows it: "
val _ = OS.Process.system "umask"
