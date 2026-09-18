(* requires: CommandLine *)
(* The CommandLine structure (signature COMMAND_LINE). Expected values follow
   the text of https://smlfamily.github.io/Basis/command-line.html. The runner
   (tests/basis/run-matrix.sh) starts a test program without arguments. *)
structure TestCommandLine =
struct
  (* "The name used to invoke the current program": some name, and the same
     one every time. *)
  val () = T.check ("CommandLine.name/nonempty", fn () => String.size (CommandLine.name ()) > 0)
  val () = T.check ("CommandLine.name/stable", fn () => CommandLine.name () = CommandLine.name ())

  (* "The argument list used to invoke the current program." *)
  val () = T.eq (T.list T.string) ("CommandLine.arguments/none-under-the-runner", [],
                                   fn () => CommandLine.arguments ())
  val () = T.check ("CommandLine.arguments/stable", fn () => CommandLine.arguments () = CommandLine.arguments ())
end
