(* requires: OS Time *)
(* uses: spec-sigs/OS_IO.sml *)
(* OS.IO matches OS_IO, and the kinds and the exception seen through the
   signature are those of the structure. *)
structure TestOSIOSig =
struct
  structure C : SPEC_OS_IO = OS.IO
  val () = T.check ("OS.IO:OS_IO/matches", fn () => true)
  val () = T.check ("OS.IO:OS_IO/same-Kind",
                    fn () => C.Kind.file = OS.IO.Kind.file andalso C.Kind.dir = OS.IO.Kind.dir
                             andalso C.Kind.device = OS.IO.Kind.device andalso C.Kind.file <> OS.IO.Kind.pipe)
  val () = T.check ("OS.IO:OS_IO/same-Poll",
                    fn () => (raise C.Poll) handle OS.IO.Poll => true | _ => false)
  val () = T.check ("OS.IO:OS_IO/poll-of-nothing",
                    fn () => List.null (C.poll ([], SOME Time.zeroTime)))
end
