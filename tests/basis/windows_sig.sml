(* requires: Windows *)
(* uses: spec-sigs/WINDOWS.sml *)
(* Windows matches WINDOWS. *)
structure TestWindowsSig =
struct
  structure C : SPEC_WINDOWS = Windows
  val () = T.check ("Windows:WINDOWS/matches", fn () => true)
  val () = T.check ("Windows:WINDOWS/status-is-SysWord.word",
                    fn () => (Windows.Status.accessViolation : SysWord.word) = C.Status.accessViolation)
end
