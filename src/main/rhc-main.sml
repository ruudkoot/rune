(* Entry point of rhc, the haskell98 roadmap's compiler: compiled by rune
   after the sources of rhc.build. Rune alone builds it (D42). A status
   other than 0 and 1 is a program's own, from `exit`, given as it is. *)
val () = Pass.instructions := (fn () => #instructions (Runtime.stats ()))
val status = RhcMain.main (CommandLine.name (), CommandLine.arguments ())
val _ =
  if status = 0 then OS.Process.exit OS.Process.success
  else if status = 1 then OS.Process.exit OS.Process.failure
  else (TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr; Posix.Process.exit (Word8.fromInt status))
