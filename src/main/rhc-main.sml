(* Entry point of rhc, the haskell98 roadmap's compiler: compiled by rune
   after the sources of rhc.build. Rune alone builds it (D42). *)
val () = Pass.instructions := (fn () => #instructions (Runtime.stats ()))
val _ = OS.Process.exit (RhcMain.main (CommandLine.name (), CommandLine.arguments ()))
