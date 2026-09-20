(* requires: Unix OS TextIO BinIO *)
(* uses: spec-sigs/UNIX.sml *)
(* Unix matches UNIX. "If an implementation provides both the Posix and Unix
   structures, then Posix.Process.exit_status and exit_status must be the
   same type"; its signal "would probably" be Posix.Signal.signal. *)
structure TestUnixSig =
struct
  structure C : SPEC_UNIX = Unix
  val () = T.check ("Unix:UNIX/matches", fn () => true)
  val () = T.check ("Unix:UNIX/same-exit_status", fn () => C.fromStatus OS.Process.success = Unix.W_EXITED)
  (*<< posix *)
  val () = T.check ("Unix:UNIX/exit_status-is-Posix.Process.exit_status",
                    fn () => (Unix.fromStatus OS.Process.success : Posix.Process.exit_status) = Posix.Process.W_EXITED)
  val () = T.check ("Unix:UNIX/signal-is-Posix.Signal.signal",
                    fn () => (Posix.Signal.term : Unix.signal) = Posix.Signal.term)
  (*>> posix *)
end
