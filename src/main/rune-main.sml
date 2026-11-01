(* Entry point for the self-hosted build: compiled by rune after the sources of rune.build. *)
val () = Pass.liveBytes := (fn () => (Runtime.collect (); #live (Runtime.stats ())))
val () = Pass.instructions := (fn () => #instructions (Runtime.stats ()))
val _ = OS.Process.exit (Serve.main (CommandLine.name (), CommandLine.arguments ()))
