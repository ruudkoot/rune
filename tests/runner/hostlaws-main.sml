val () = case HostLaws.command (CommandLine.arguments ()) of
  SOME run => run ()
| NONE => (HostLaws.main (CommandLine.arguments ()) handle HostLaws.Failed message =>
    (TextIO.output (TextIO.stdErr, "test-laws-hosts: " ^ message ^ "\n");
     TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w1))
