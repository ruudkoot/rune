(* LineEdit: the line editor on Rune's terminal.

   Implements: LINE_EDIT *)
structure LineEdit = LineEditFn (structure Device = Terminal)
