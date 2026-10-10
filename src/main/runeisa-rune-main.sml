(* Entry point of runeisa for the self-hosted build: compiled by rune after the sources of runeisa.build. *)
val _ = OS.Process.exit (IsaMain.main (CommandLine.name (), CommandLine.arguments ()))
