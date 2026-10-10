(* requires: Terminal OS Time CharVector *)
(* Terminal (signature TERMINAL, Rune's own): the terminal of a program that
   edits what is typed at it. The suite's programs run with the standard
   input on /dev/null and the standard output and error on files, so what is
   checked is what Terminal says where nothing is a terminal; what it does on
   one is tests/terminal's (term-keys, term-resize, term-restore), on Linux
   and on Windows. *)
structure TestTerminal =
struct
  (* refused as a terminal is: ENOTTY *)
  val isNotty = fn OS.SysErr (_, SOME e) => OS.errorName e = "notty" | _ => false

  val () = T.check ("Terminal.size/none-without-a-terminal", fn () => Terminal.size () = NONE)
  val () = T.check ("Terminal.resizes/counted-from-zero", fn () => Terminal.resizes () = 0)
  val () = T.raises ("Terminal.enter/refused-without-a-terminal", isNotty,
                     fn () => Terminal.enter {undo = ""})
  val () = T.raises ("Terminal.enter/refused-without-a-terminal-whatever-the-undo", isNotty,
                     fn () => Terminal.enter {undo = CharVector.tabulate (257, fn _ => #"x")})
  val () = T.raises ("Terminal.read/refused-without-a-terminal", isNotty,
                     fn () => Terminal.read (SOME Time.zeroTime))
  val () = T.check ("Terminal.leave/nothing-when-not-raw", fn () => (Terminal.leave (); true))
end
