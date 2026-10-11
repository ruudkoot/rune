(* requires: Terminal *)
(* Terminal matches TERMINAL, which is Rune's own signature and has no
   transcription under spec-sigs: the size is a record of columns and rows,
   and nothing is abstract. *)
structure TestTerminalSig =
struct
  val () = T.check ("Terminal:TERMINAL/size-is-columns-and-rows",
                    fn () =>
                      case Terminal.size () of
                        SOME {columns, rows} => columns + rows >= 0
                      | NONE => true)
end
