(* requires: OS Time *)
(* uses: spec-sigs/OS_PROCESS.sml *)
(* OS.Process matches OS_PROCESS. *)
structure TestOSProcessSig =
struct
  structure C : SPEC_OS_PROCESS = OS.Process
  val () = T.check ("OS.Process:OS_PROCESS/matches", fn () => true)
  val () = T.check ("OS.Process:OS_PROCESS/status-is-OS.Process.status",
                    fn () => OS.Process.isSuccess C.success andalso C.isSuccess OS.Process.success)
end
