(* requires: Subprocess *)
(* Subprocess matches SUBPROCESS, which is Rune's own signature and has no
   transcription under spec-sigs: `limits` is a record of four options, and
   `unlimited` has none. *)
structure TestSubprocessSig =
struct
  val () = T.check ("Subprocess:SUBPROCESS/unlimited-has-no-limits",
                    fn () =>
                      let val {addressSpace, cpuTime, fileSize, core} : Subprocess.limits = Subprocess.unlimited
                      in not (isSome addressSpace orelse isSome cpuTime orelse isSome fileSize orelse isSome core) end)
end
