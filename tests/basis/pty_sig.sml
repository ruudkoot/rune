(* requires: Pty Subprocess *)
(* PTY is Rune's extension, with an abstract owned session. *)
structure TestPtySig =
struct
  structure P : PTY = Pty
  val ()=T.check ("Pty:PTY/descriptor-functions",fn () =>
        let val _:P.session -> int=P.input
            val _:P.session -> int=P.output
            val _:P.session -> Subprocess.pid=P.process
        in true end)
end
