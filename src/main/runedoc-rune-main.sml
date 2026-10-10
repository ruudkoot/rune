(* Entry point of runedoc for the self-hosted build: compiled by rune after the sources of runedoc.build. *)
val _ = OS.Process.exit (DocMain.main (CommandLine.name (), CommandLine.arguments ()))
