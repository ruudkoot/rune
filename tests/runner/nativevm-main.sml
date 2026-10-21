val () =
  (case CommandLine.arguments () of
     root :: args => NativeVM.main root args
   | [] => raise Fail "native launcher: missing repository root")
  handle e => (TextIO.output (TextIO.stdErr, "runevm: " ^ General.exnMessage e ^ "\n");
               TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w2)
