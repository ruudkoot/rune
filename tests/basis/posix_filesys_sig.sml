(* requires: Posix OS SysWord *)
(* uses: spec-sigs/BIT_FLAGS.sml spec-sigs/POSIX_FILE_SYS.sml *)
(* Posix.FileSys matches POSIX_FILE_SYS, and its types are those the text of
   https://smlfamily.github.io/Basis/posix-file-sys.html and the constraints
   of `structure FileSys : POSIX_FILE_SYS` in signature POSIX
   (https://smlfamily.github.io/Basis/posix.html) make them: uid, gid and
   file_desc are those of Posix.ProcEnv, dirstream is OS.FileSys.dirstream,
   access_mode is OS.FileSys.access_mode, S.flags is S.mode. The match is a
   section of its own, so that the identities are checked where it fails. *)
structure TestPosixFileSysSig =
struct
  (*<< matches *)
  structure C : SPEC_POSIX_FILE_SYS = Posix.FileSys
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/matches", fn () => true)
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/same-types",
                    fn () => C.fdToWord Posix.FileSys.stdout = Posix.FileSys.fdToWord C.stdout
                             andalso C.S.toWord Posix.FileSys.S.irusr = Posix.FileSys.S.toWord C.S.irusr)
  (*>> matches *)

  (*<< ids *)
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/uid-is-ProcEnv.uid",
                    fn () => let val u : Posix.ProcEnv.uid = Posix.ProcEnv.getuid ()
                             in (u : Posix.FileSys.uid) = u end)
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/gid-is-ProcEnv.gid",
                    fn () => let val g : Posix.ProcEnv.gid = Posix.ProcEnv.getgid ()
                             in (g : Posix.FileSys.gid) = g end)
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/file_desc-is-ProcEnv.file_desc",
                    fn () => let val fd : Posix.ProcEnv.file_desc = Posix.FileSys.stdout
                             in Posix.FileSys.fdToWord fd = Posix.FileSys.fdToWord Posix.FileSys.stdout end)
  (*>> ids *)

  (*<< dirstream *)
  (* "This type is identical to OS.FileSys.dirstream." *)
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/dirstream-is-OS.FileSys.dirstream",
                    fn () => let
                               val d : OS.FileSys.dirstream = Posix.FileSys.opendir "."
                               val d' : Posix.FileSys.dirstream = OS.FileSys.openDir "."
                             in
                               Posix.FileSys.closedir d; OS.FileSys.closeDir d'; true
                             end)
  (*>> dirstream *)

  (*<< access_mode *)
  (* "This type is identical to OS.FileSys.access_mode." *)
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/access_mode-is-OS.FileSys.access_mode",
                    fn () => [Posix.FileSys.A_READ, Posix.FileSys.A_WRITE, Posix.FileSys.A_EXEC]
                             = [OS.FileSys.A_READ, OS.FileSys.A_WRITE, OS.FileSys.A_EXEC])
  (*>> access_mode *)

  (*<< iodesc *)
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/iodesc-is-OS.IO.iodesc",
                    fn () => OS.IO.compare (Posix.FileSys.fdToIOD Posix.FileSys.stdout,
                                            Posix.FileSys.fdToIOD Posix.FileSys.stdout) = EQUAL)
  (*>> iodesc *)

  (*<< mode *)
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/S.flags-is-S.mode",
                    fn () => (Posix.FileSys.S.flags [Posix.FileSys.S.irusr] : Posix.FileSys.S.mode)
                             = Posix.FileSys.S.irusr)
  (*>> mode *)
end
