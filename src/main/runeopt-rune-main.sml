(* Entry point of runeopt for the self-hosted build: compiled by rune after the sources of runeopt.build. *)
val _ = OS.Process.exit (OptMain.main (CommandLine.name (), CommandLine.arguments ()))
