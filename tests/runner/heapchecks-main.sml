val () = case Heap.command (CommandLine.arguments ()) of
  SOME run => run ()
| NONE => (TextIO.output (TextIO.stdErr, "heap check: unknown command\n");
           TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w2)
