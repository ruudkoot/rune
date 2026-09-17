val args = CommandLine.arguments ()
val () = print (Int.toString (length args) ^ ":" ^ String.concatWith "|" args ^ "\n")
val () = print (Bool.toString (String.isSuffix ".rbc" (CommandLine.name ())) ^ "\n")
