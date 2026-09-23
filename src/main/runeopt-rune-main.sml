(* Entry point of runeopt for the self-hosted build: compiled by rune after the sources in sources-opt.txt. *)
val _ = OS.Process.exit (OptMain.main (CommandLine.name (), CommandLine.arguments ()))
