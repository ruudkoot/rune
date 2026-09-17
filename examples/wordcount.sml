(* Count lines, words and characters on standard input. *)
fun loop (lines, words, chars) =
  case TextIO.inputLine TextIO.stdIn of
    NONE => (lines, words, chars)
  | SOME line =>
      loop (lines + 1, words + length (String.tokens Char.isSpace line), chars + size line)

val (l, w, c) = loop (0, 0, 0)
val () = print (Int.toString l ^ " " ^ Int.toString w ^ " " ^ Int.toString c ^ "\n")
