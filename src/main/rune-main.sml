(* Entry point for the self-hosted build: compiled by rune after the sources in sources.txt. *)
val _ = OS.Process.exit (Main.main (CommandLine.name (), CommandLine.arguments ()))
