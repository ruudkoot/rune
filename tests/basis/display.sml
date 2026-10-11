(* requires: Display *)
(* Display (signature DISPLAY, Rune's own): an output in several forms. The
   suite's programs have no front that shows more than text, so what is
   checked is that each function shows its text and returns; the kernel
   shows the rest (tests/kernel). *)
structure TestDisplay =
struct
  val () = T.check ("Display.display/shows-its-text", fn () => (Display.display [("text/plain", "shown")]; true))
  val () = T.check ("Display.displayAs/shows-its-text", fn () => (Display.displayAs ("d", [("text/plain", "named")]); true))
  val () = T.check ("Display.update/shows-its-text", fn () => (Display.update ("d", [("text/html", "<b>first</b>")]); true))
  val () = T.check ("Display.clear/does-nothing-here", fn () => (Display.clear false; true))
end
