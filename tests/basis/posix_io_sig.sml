(* requires: Posix SysWord *)
(* uses: spec-sigs/BIT_FLAGS.sml spec-sigs/POSIX_IO.sml *)
(* Posix.IO matches POSIX_IO, and its types are those the constraints of
   `structure IO : POSIX_IO` in signature POSIX
   (https://smlfamily.github.io/Basis/posix.html) make them: pid is
   Posix.Process.pid, file_desc is Posix.ProcEnv.file_desc (and so
   Posix.FileSys.file_desc), open_mode is Posix.FileSys.open_mode. The match
   is a section of its own, so that the identities are checked where it
   fails. *)
structure TestPosixIOSig =
struct
  (*<< matches *)
  structure C : SPEC_POSIX_IO = Posix.IO
  val () = T.check ("Posix.IO:POSIX_IO/matches", fn () => true)
  val () = T.check ("Posix.IO:POSIX_IO/same-constructors",
                    fn () => C.SEEK_END = Posix.IO.SEEK_END andalso C.O_RDWR = Posix.IO.O_RDWR
                             andalso C.F_UNLCK = Posix.IO.F_UNLCK)
  (*>> matches *)

  (*<< file_desc *)
  val () = T.check ("Posix.IO:POSIX_IO/file_desc-is-ProcEnv.file_desc",
                    fn () => let val fd : Posix.ProcEnv.file_desc = Posix.FileSys.stdout
                             in (fd : Posix.IO.file_desc) = Posix.FileSys.stdout end)
  (*>> file_desc *)

  (*<< pid *)
  val () = T.check ("Posix.IO:POSIX_IO/pid-is-Process.pid",
                    fn () => let val p : Posix.Process.pid = Posix.ProcEnv.getpid ()
                             in (p : Posix.IO.pid) = p end)
  (*>> pid *)

  (*<< open_mode *)
  val () = T.check ("Posix.IO:POSIX_IO/open_mode-is-FileSys.open_mode",
                    fn () => [Posix.IO.O_RDONLY, Posix.IO.O_WRONLY, Posix.IO.O_RDWR]
                             = [Posix.FileSys.O_RDONLY, Posix.FileSys.O_WRONLY, Posix.FileSys.O_RDWR])
  (*>> open_mode *)
end
