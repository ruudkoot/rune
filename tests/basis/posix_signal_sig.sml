(* requires: Posix *)
(* uses: spec-sigs/POSIX_SIGNAL.sml *)
(* Posix.Signal matches POSIX_SIGNAL. *)
structure TestPosixSignalSig =
struct
  structure C : SPEC_POSIX_SIGNAL = Posix.Signal
  val () = T.check ("Posix.Signal:POSIX_SIGNAL/matches", fn () => true)
  val () = T.check ("Posix.Signal:POSIX_SIGNAL/same-signals",
                    fn () => (C.term : Posix.Signal.signal) = Posix.Signal.term
                             andalso C.toWord Posix.Signal.kill = Posix.Signal.toWord C.kill)
end
