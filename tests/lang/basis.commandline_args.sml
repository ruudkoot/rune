val () = print (String.concatWith "," (CommandLine.arguments ()) ^ "\n")
val () = print (Int.toString (length (CommandLine.arguments ())) ^ "\n")
