(* requires: CommandLine *)
(* uses: spec-sigs/COMMAND_LINE.sml *)
(* CommandLine matches COMMAND_LINE. *)
structure TestCommandLineSig =
struct
  structure C : SPEC_COMMAND_LINE = CommandLine
  val () = T.check ("CommandLine:COMMAND_LINE/matches", fn () => true)
  val () = T.check ("CommandLine:COMMAND_LINE/same-values", fn () => C.name () = CommandLine.name ())
end
