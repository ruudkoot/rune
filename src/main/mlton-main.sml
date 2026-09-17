(* MLton entry point: the .mlb lists this file last. *)
val _ = OS.Process.exit (Main.main (CommandLine.name (), CommandLine.arguments ()))
