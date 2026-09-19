(* requires: OS Time Position *)
(* uses: spec-sigs/OS_FILE_SYS.sml *)
(* OS.FileSys matches OS_FILE_SYS, and the types and constructors seen through
   the signature are those of the structure. *)
structure TestOSFileSysSig =
struct
  structure C : SPEC_OS_FILE_SYS = OS.FileSys
  val () = T.check ("OS.FileSys:OS_FILE_SYS/matches", fn () => true)
  val () = T.check ("OS.FileSys:OS_FILE_SYS/same-access_mode",
                    fn () => C.A_READ = OS.FileSys.A_READ andalso C.A_WRITE = OS.FileSys.A_WRITE
                             andalso C.A_EXEC = OS.FileSys.A_EXEC andalso C.A_READ <> OS.FileSys.A_EXEC)
  val () = T.check ("OS.FileSys:OS_FILE_SYS/file_id-is-an-eqtype",
                    fn () => C.fileId "." = OS.FileSys.fileId ".")
  val () = T.check ("OS.FileSys:OS_FILE_SYS/dirstream-is-OS.FileSys.dirstream",
                    fn () => let val d = C.openDir "." in OS.FileSys.closeDir d; C.closeDir d; true end)
  val () = T.check ("OS.FileSys:OS_FILE_SYS/Position.int-and-Time.time",
                    fn () => (C.fileSize "." : Position.int) >= Position.fromInt 0
                             andalso Time.<= (C.modTime ".", Time.+ (Time.now (), Time.fromSeconds (LargeInt.fromInt 86400))))
end
