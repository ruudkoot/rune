(* MLton entry point of runeisa: the .mlb lists this file last. *)
val _ = OS.Process.exit (IsaMain.main (CommandLine.name (), CommandLine.arguments ()))
