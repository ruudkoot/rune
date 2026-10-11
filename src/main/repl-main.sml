(* Entry point of rune-repl (docs/repl.md): the last unit of the REPL
   program, run once the units before it are loaded. The commands, which
   are compiled after the loop, are given to it and to the session's Repl
   here. *)
val () = ReplLoop.commandHook := ReplCommands.dispatch
val () = ReplCommands.install ()
val () = ReplLoop.main (CommandLine.arguments ())
