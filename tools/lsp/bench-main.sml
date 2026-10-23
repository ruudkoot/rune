(* The measurement program's entry point. *)
val _ = OS.Process.exit (LspBench.entry (CommandLine.arguments ()))
