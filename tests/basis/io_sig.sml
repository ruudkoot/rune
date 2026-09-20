(* requires: IO *)
(* uses: spec-sigs/IO.sml *)
(* IO matches IO, and the exceptions and constructors seen through the
   signature are those of the structure. *)
structure TestIOSig =
struct
  structure C : SPEC_IO = IO
  val () = T.check ("IO:IO/matches", fn () => true)
  val () = T.check ("IO:IO/same-exceptions",
                    fn () => (raise C.Io {name = "n", function = "f", cause = C.ClosedStream})
                             handle IO.Io {cause = IO.ClosedStream, ...} => true | _ => false)
  val () = T.check ("IO:IO/same-buffer_mode", fn () => C.LINE_BUF = IO.LINE_BUF)
end
