fun loop n =
  case TextIO.inputLine TextIO.stdIn of
    NONE => n
  | SOME line => (print (Int.toString (size line) ^ ":" ^ line); loop (n + 1))
val n = loop 0
val () = print ("lines: " ^ Int.toString n ^ "\n")
