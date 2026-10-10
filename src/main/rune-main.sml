(* Entry point for the self-hosted build: compiled by rune after the sources of rune.build. *)
val _ = OS.Process.exit (Serve.main (CommandLine.name (), CommandLine.arguments ()))
