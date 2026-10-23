(* The standalone language server's entry point. *)
val _ = OS.Process.exit (RuneLsp.main (CommandLine.arguments ()))
