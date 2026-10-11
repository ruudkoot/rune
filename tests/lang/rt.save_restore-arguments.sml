(* rt.save: a world restored with arguments of its own -- those after
   `runevm --restore FILE --` -- sees them as CommandLine.arguments, in place
   of those it was saved with; the world that saved it sees its own (the
   test runner gives the restored world the words of the .restoreargs file) *)
val () =
  case Runtime.save "tests/out/rt.save_restore-arguments.img" of
    Runtime.Saved => print ("saved with [" ^ String.concatWith "," (CommandLine.arguments ()) ^ "]\n")
  | Runtime.Restored => print ("restored with [" ^ String.concatWith "," (CommandLine.arguments ()) ^ "]\n")
