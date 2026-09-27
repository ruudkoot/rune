(* MLKit entry point of runedoc: build/runedoc-mlkit.mlb lists it last.
   MLKit's OS.Process.failure is ~1, an exit status of 255, where the other
   builds exit with 1 (docs/building.md); a failure ends here with 1 too.
   MLKit's streams are C's, which exit flushes as OS.Process.exit would, and
   no action is registered with OS.Process.atExit. *)
val _ =
  let val status = DocMain.main (CommandLine.name (), CommandLine.arguments ())
  in if OS.Process.isSuccess status then OS.Process.exit status else Posix.Process.exit 0w1 end
