val () = case Budgets.command (CommandLine.arguments ()) of
  SOME run => run ()
| NONE => (Budgets.main (CommandLine.arguments ()) handle Budgets.Failed message =>
    (TextIO.output (TextIO.stdErr, message ^ "\n"); TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w2))
