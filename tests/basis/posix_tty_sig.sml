(* requires: Posix.TTY Posix *)
(* uses: spec-sigs/BIT_FLAGS.sml spec-sigs/POSIX_TTY.sml *)
(* Posix.TTY matches POSIX_TTY, and its pid and file_desc are those of
   Posix.Process and Posix.ProcEnv (the constraints of `structure TTY` in
   POSIX). *)
structure TestPosixTTYSig =
struct
  (*<< whole *)
  structure C : SPEC_POSIX_TTY = Posix.TTY
  val () = T.check ("Posix.TTY:POSIX_TTY/matches", fn () => true)
  val () = T.check ("Posix.TTY:POSIX_TTY/same-speeds", fn () => C.compareSpeed (Posix.TTY.b0, C.b9600) = LESS)
  (*>> whole *)
  (*<< types *)
  val () = T.check ("Posix.TTY:POSIX_TTY/pid-is-Process.pid",
                    fn () => let val _ : Posix.TTY.pid = Posix.ProcEnv.getpid () in true end)
  val () = T.check ("Posix.TTY:POSIX_TTY/file_desc-is-ProcEnv.file_desc",
                    fn () => let val _ : Posix.TTY.file_desc = (Posix.FileSys.wordToFD 0w0 : Posix.ProcEnv.file_desc) in true end)
  (*>> types *)
end
