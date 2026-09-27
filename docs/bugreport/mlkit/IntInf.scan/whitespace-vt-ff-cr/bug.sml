(* IntInf.scan and IntInf.fromString skip only space, tab and newline, not
   the other whitespace characters of Char.isSpace: vertical tab, form feed
   and carriage return.  Int.fromString, for contrast, skips all six. *)
fun opt NONE = "NONE"
  | opt (SOME s) = "SOME " ^ s
fun row (name, s) =
  print (name ^ ": IntInf.fromString = " ^ opt (Option.map IntInf.toString (IntInf.fromString s))
         ^ ", Int.fromString = " ^ opt (Option.map Int.toString (Int.fromString s)) ^ "\n")
val () = List.app row
  [("space          ", " 42"), ("tab            ", "\t42"), ("newline        ", "\n42"),
   ("vertical tab   ", "\v42"), ("form feed      ", "\f42"), ("carriage return", "\r42")]
