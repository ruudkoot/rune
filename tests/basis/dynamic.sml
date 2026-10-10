(* requires: Dynamic *)
(* Dynamic: loading what is not a unit. The modules themselves, through
   _dynamic and _export, are tests/dynamic's. *)
structure TestDynamic =
struct
  val () = T.check ("Dynamic.load/raises-io-on-a-missing-file",
                    fn () => (Dynamic.load "no such file of a unit.rbu"; false) handle IO.Io _ => true)
  val () = T.check ("Dynamic.Mismatch/carries-its-message",
                    fn () => (raise Dynamic.Mismatch "m") handle Dynamic.Mismatch s => s = "m")
end
