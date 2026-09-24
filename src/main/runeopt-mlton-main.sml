(* MLton entry point of runeopt: the .mlb lists this file last. *)
val _ = OS.Process.exit (OptMain.main (CommandLine.name (), CommandLine.arguments ()))
