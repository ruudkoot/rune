(* requires: OS Time Position *)
(* uses: spec-sigs/OS_FILE_SYS.sml spec-sigs/OS_IO.sml spec-sigs/OS_PATH.sml spec-sigs/OS_PROCESS.sml spec-sigs/OS.sml *)
(* OS matches OS, transparently and opaquely (the page declares
   `structure OS :> OS`), and the substructures, the syserror type and the
   exception seen through the signature are those of the structure. *)
structure TestOSSig =
struct
  structure C : SPEC_OS = OS
  val () = T.check ("OS:OS/matches", fn () => true)
  structure O :> SPEC_OS = OS
  val () = T.check ("OS:OS/matches-opaquely", fn () => O.Path.concat ("a", "b") = "a/b")
  val () = T.check ("OS:OS/same-SysErr",
                    fn () => (raise C.SysErr ("m", NONE)) handle OS.SysErr ("m", NONE) => true | _ => false)
  val () = T.check ("OS:OS/syserror-is-OS.syserror",
                    fn () => C.syserror "no such error name in any system" = (NONE : OS.syserror option))
  val () = T.check ("OS:OS/Path-is-OS.Path",
                    fn () => (raise C.Path.Path) handle OS.Path.Path => true | _ => false)
  val () = T.check ("OS:OS/FileSys-is-OS.FileSys", fn () => C.FileSys.A_READ = OS.FileSys.A_READ)
  val () = T.check ("OS:OS/IO-is-OS.IO", fn () => C.IO.Kind.file = OS.IO.Kind.file)
  val () = T.check ("OS:OS/Process-is-OS.Process", fn () => OS.Process.isSuccess C.Process.success)
end
