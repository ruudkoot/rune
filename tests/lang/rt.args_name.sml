(* runevm --name: the name the program has (CommandLine.name) rather than
   its file's, for a script that runs a .rbc as a command of its own; and a
   world restored with --name has that one rather than the one it was saved
   with (.restorevmargs) *)
val () =
  case Runtime.save "tests/out/rt.args_name.img" of
    Runtime.Saved => print (CommandLine.name () ^ "\n" ^ String.concatWith "|" (CommandLine.arguments ()) ^ "\n")
  | Runtime.Restored => print (CommandLine.name () ^ "\n")
