(* requires: Posix Time *)
(* uses: spec-sigs/POSIX_PROC_ENV.sml *)
(* Posix.ProcEnv matches POSIX_PROC_ENV, and its pid is Posix.Process.pid
   (the constraint of `structure ProcEnv` in POSIX). *)
structure TestPosixProcEnvSig =
struct
  structure C : SPEC_POSIX_PROC_ENV = Posix.ProcEnv
  val () = T.check ("Posix.ProcEnv:POSIX_PROC_ENV/matches", fn () => true)
  val () = T.check ("Posix.ProcEnv:POSIX_PROC_ENV/pid-is-Process.pid",
                    fn () => Posix.Process.pidToWord (C.getpid ()) = Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
  val () = T.check ("Posix.ProcEnv:POSIX_PROC_ENV/file_desc-is-FileSys.file_desc",
                    fn () => not (C.isatty (Posix.FileSys.wordToFD 0w1000)))
end
