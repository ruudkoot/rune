(* Entry point of runeisa for the self-hosted build: compiled by rune after the sources in sources-isa.txt. *)
val _ = OS.Process.exit (IsaMain.main (CommandLine.name (), CommandLine.arguments ()))
