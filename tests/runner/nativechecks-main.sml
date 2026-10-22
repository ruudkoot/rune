val () = case NativeChecks.command (CommandLine.arguments ()) of
  SOME run => run ()
| NONE => (TextIO.output (TextIO.stdErr, "native check: unknown command\n");
           TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w2)
