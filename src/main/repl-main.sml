(* Entry point of rune-repl (docs/repl.md): the last unit of the REPL
   program, run once the units before it are loaded. *)
val () = Repl.main (CommandLine.arguments ())
