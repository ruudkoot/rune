(* requires: Repl *)
(* Repl (signature REPL, Rune's own): the REPL's commands as functions. The
   suite's programs are compiled by rune, with no REPL around them, so what
   is checked is that each raises Fail; the REPL itself is checked by
   tests/repl (commands.in). *)
structure TestRepl =
struct
  val isFail = fn Fail _ => true | _ => false
  val () = T.raises ("Repl.command/no-repl-around-the-program", isFail, fn () => Repl.command ":show")
  val () = T.raises ("Repl.typeOf/no-repl-around-the-program", isFail, fn () => Repl.typeOf "1")
  val () = T.raises ("Repl.info/no-repl-around-the-program", isFail, fn () => Repl.info "map")
  val () = T.raises ("Repl.doc/no-repl-around-the-program", isFail, fn () => Repl.doc "List.map")
  val () = T.raises ("Repl.search/no-repl-around-the-program", isFail, fn () => Repl.search "map")
  val () = T.raises ("Repl.set/no-repl-around-the-program", isFail, fn () => Repl.set ("depth", "5"))
  val () = T.raises ("Repl.settings/no-repl-around-the-program", isFail, fn () => Repl.settings ())
end
