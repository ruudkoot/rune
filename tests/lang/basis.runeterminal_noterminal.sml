(* RuneTerminal where nothing is a terminal, as in the suite: no size,
   resizes counted from 0, and raw mode and reading refused, ENOTTY. A
   terminal itself is tests/terminal's (term-keys, term-resize,
   term-restore). *)
fun refused f =
  (f (); "done")
  handle OS.SysErr (_, SOME e) => "SysErr " ^ OS.errorName e
       | OS.SysErr (_, NONE) => "SysErr"
val () = print ("size: " ^ (case RuneTerminal.size () of NONE => "none" | SOME _ => "some") ^ "\n")
val () = print ("resizes: " ^ Int.toString (RuneTerminal.resizes ()) ^ "\n")
val () = print ("enter: " ^ refused (fn () => RuneTerminal.enter {undo = ""}) ^ "\n")
val () = print ("enter, a long undo: " ^ refused (fn () => RuneTerminal.enter {undo = CharVector.tabulate (300, fn _ => #"x")}) ^ "\n")
val () = print ("read: " ^ refused (fn () => ignore (RuneTerminal.read (SOME Time.zeroTime))) ^ "\n")
val () = print ("leave: " ^ refused RuneTerminal.leave ^ "\n")
