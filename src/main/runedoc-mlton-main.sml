(* MLton entry point of runedoc: the .mlb lists this file last. *)
val _ = OS.Process.exit (DocMain.main (CommandLine.name (), CommandLine.arguments ()))
