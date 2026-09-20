(* Entry point of runedoc for the self-hosted build: compiled by rune after the sources in sources-doc.txt. *)
val _ = OS.Process.exit (DocMain.main (CommandLine.name (), CommandLine.arguments ()))
