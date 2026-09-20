(* requires: Posix *)
(* uses: spec-sigs/BIT_FLAGS.sml spec-sigs/POSIX_ERROR.sml spec-sigs/POSIX_SIGNAL.sml spec-sigs/POSIX_PROCESS.sml spec-sigs/POSIX_PROC_ENV.sml spec-sigs/POSIX_FILE_SYS.sml spec-sigs/POSIX_IO.sml spec-sigs/POSIX_SYS_DB.sml spec-sigs/POSIX_TTY.sml spec-sigs/POSIX.sml *)
(* Posix matches POSIX (https://smlfamily.github.io/Basis/posix.html), all
   eight substructures at once; posix_error_sig.sml, posix_signal_sig.sml,
   ... match them one by one. Below, one section per type that POSIX
   shares between substructures (its `where type` clauses), so that each is
   reported by itself. *)
structure TestPosixSig =
struct
  (*<< whole *)
  structure C : SPEC_POSIX = Posix
  val () = T.check ("Posix:POSIX/matches", fn () => true)
  val () = T.check ("Posix:POSIX/same-structures",
                    fn () => C.Error.noent = Posix.Error.noent andalso C.Signal.term = Posix.Signal.term)
  (*>> whole *)

  (*<< process-signal *)
  val () = T.check ("Posix:POSIX/Process.signal-is-Signal.signal",
                    fn () => Posix.Process.W_SIGNALED (Posix.Signal.term : Posix.Process.signal)
                             = Posix.Process.W_SIGNALED Posix.Signal.term)
  (*>> process-signal *)

  (*<< procenv-pid *)
  val () = T.check ("Posix:POSIX/ProcEnv.pid-is-Process.pid",
                    fn () => Posix.Process.pidToWord (Posix.ProcEnv.getpid () : Posix.Process.pid) > 0w0)
  (*>> procenv-pid *)

  (*<< filesys-types *)
  val () = T.check ("Posix:POSIX/FileSys.file_desc-is-ProcEnv.file_desc",
                    fn () => not (Posix.ProcEnv.isatty (Posix.FileSys.wordToFD 0w1000 : Posix.ProcEnv.file_desc)))
  (* The scratch directory belongs to the user of the test. *)
  val () = T.check ("Posix:POSIX/FileSys.uid-is-ProcEnv.uid",
                    fn () => Posix.FileSys.ST.uid (Posix.FileSys.stat ".") = (Posix.ProcEnv.geteuid () : Posix.FileSys.uid))
  val () = T.check ("Posix:POSIX/FileSys.gid-is-ProcEnv.gid",
                    fn () => let val _ : Posix.FileSys.gid = Posix.ProcEnv.getegid () in true end)
  (*>> filesys-types *)

  (*<< io-types *)
  val () = T.check ("Posix:POSIX/IO.pid-is-Process.pid",
                    fn () => let val _ : Posix.IO.pid = Posix.ProcEnv.getpid () in true end)
  val () = T.check ("Posix:POSIX/IO.file_desc-is-ProcEnv.file_desc",
                    fn () => let val _ : Posix.IO.file_desc = (Posix.FileSys.wordToFD 0w0 : Posix.ProcEnv.file_desc) in true end)
  val () = T.check ("Posix:POSIX/IO.open_mode-is-FileSys.open_mode",
                    fn () => (Posix.FileSys.O_RDONLY : Posix.IO.open_mode) = Posix.IO.O_RDONLY)
  (*>> io-types *)

  (*<< sysdb-types *)
  val () = T.check ("Posix:POSIX/SysDB.uid-is-ProcEnv.uid",
                    fn () => let val _ : Posix.SysDB.uid = Posix.ProcEnv.getuid () in true end)
  val () = T.check ("Posix:POSIX/SysDB.gid-is-ProcEnv.gid",
                    fn () => let val _ : Posix.SysDB.gid = Posix.ProcEnv.getgid () in true end)
  (*>> sysdb-types *)

  (*<< tty-types *)
  val () = T.check ("Posix:POSIX/TTY.pid-is-Process.pid",
                    fn () => let val _ : Posix.TTY.pid = Posix.ProcEnv.getpid () in true end)
  val () = T.check ("Posix:POSIX/TTY.file_desc-is-ProcEnv.file_desc",
                    fn () => let val _ : Posix.TTY.file_desc = (Posix.FileSys.wordToFD 0w0 : Posix.ProcEnv.file_desc) in true end)
  (*>> tty-types *)
end
