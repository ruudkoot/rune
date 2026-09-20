(* requires: OS *)
(* uses: spec-sigs/OS_PATH.sml *)
(* OS.Path matches OS_PATH, and the exceptions seen through the signature are
   those of the structure. *)
structure TestOSPathSig =
struct
  structure C : SPEC_OS_PATH = OS.Path
  val () = T.check ("OS.Path:OS_PATH/matches", fn () => true)
  val () = T.check ("OS.Path:OS_PATH/same-Path",
                    fn () => (raise C.Path) handle OS.Path.Path => true | _ => false)
  val () = T.check ("OS.Path:OS_PATH/same-InvalidArc",
                    fn () => (raise OS.Path.InvalidArc) handle C.InvalidArc => true | _ => false)
  val () = T.check ("OS.Path:OS_PATH/same-functions",
                    fn () => C.concat ("a", "b") = OS.Path.concat ("a", "b")
                             andalso C.parentArc = OS.Path.parentArc)
end
