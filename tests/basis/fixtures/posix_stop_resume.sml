(* Manual causal probe: compile after harness.sml, fn/posix_child.sml and
   posix_process.sml, and before finish.sml. The ordinary suite already
   checks the persistent child's stopped and deliberately resumed paths. *)
structure PosixStopResumeProbe =
struct
  structure P = Posix.Process
  structure C = PosixChild
  val () = T.check ("fixture/old-child-exits-after-cont-cleanup-ESRCH", fn () =>
    let
      val pid = C.fork (fn () => P.exec ("/bin/sh", ["sh", "-c", "kill -STOP $$; exit 7"]))
      val stopped = C.stopped pid
      val () = if stopped = SOME (P.W_STOPPED Posix.Signal.stop) then () else raise Fail "old child did not stop"
      val () = P.kill (P.K_PROC pid, Posix.Signal.cont)
      val result = ref NONE
      val ended = C.until (5, fn () => case P.waitpid_nh (P.W_CHILD pid, []) of
          NONE => false
        | SOME (_, status) => (result := SOME status; true))
      val () = if ended andalso !result = SOME (P.W_EXITSTATUS (C.w8 7)) then () else raise Fail "old child did not exit 7"
    in
      (P.kill (P.K_PROC pid, Posix.Signal.kill); ignore (C.status pid); false)
      handle OS.SysErr (message, SOME error) =>
        (print ("CAPTURED old fixture cleanup: SysErr " ^ OS.errorName error ^ ": " ^ message ^ "\n");
         error = Posix.Error.srch)
    end)
  val () = T.check ("fixture/persistent-child-survives-planted-cont", fn () => TestPosixProcess.withoutUntraced true)
end
