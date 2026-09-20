(* requires: Posix OS Time *)
(* uses: spec-sigs/BIT_FLAGS.sml spec-sigs/POSIX_PROCESS.sml *)
(* Posix.Process matches POSIX_PROCESS, its W matches BIT_FLAGS, and its
   signal is Posix.Signal.signal (the constraint of `structure Process` in
   POSIX). *)
structure TestPosixProcessSig =
struct
  structure C : SPEC_POSIX_PROCESS = Posix.Process
  val () = T.check ("Posix.Process:POSIX_PROCESS/matches", fn () => true)
  structure W : SPEC_BIT_FLAGS = Posix.Process.W
  val () = T.check ("Posix.Process.W:BIT_FLAGS/matches", fn () => true)
  val () = T.check ("Posix.Process:POSIX_PROCESS/signal-is-Signal.signal",
                    fn () => C.W_SIGNALED Posix.Signal.term = Posix.Process.W_SIGNALED Posix.Signal.term)
  val () = T.check ("Posix.Process:POSIX_PROCESS/pid-is-ProcEnv.pid",
                    fn () => (Posix.ProcEnv.getpid () : C.pid) = Posix.ProcEnv.getpid ())
  val () = T.check ("Posix.Process:POSIX_PROCESS/W.flags",
                    fn () => (C.W.untraced : Posix.Process.W.flags) = Posix.Process.W.untraced)
end
