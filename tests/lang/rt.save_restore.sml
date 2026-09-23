(* rt.save: a program writes itself to a file and stops; a second VM is given
   that file and carries on from inside the same call, where it is `Restored`.
   The heap, the stacks and the counters are the ones that were saved, and a
   file the program had open is opened again where it was left. *)
val out = TextIO.openOut "tests/out/rt.save_restore.txt"
val () = TextIO.output (out, "before\n")
fun count (0, acc) = acc | count (n, acc) = count (n - 1, n :: acc)
val live = count (1000, [])
fun sum () = List.foldl (op +) 0 live
val () = print ("saving with sum " ^ Int.toString (sum ()) ^ "\n")
val () =
  case Runtime.save "tests/out/rt.save_restore.img" of
    Runtime.Saved => print "saved\n"
  | Runtime.Restored =>
      (print ("restored with sum " ^ Int.toString (sum ()) ^ "\n");
       TextIO.output (out, "after\n");
       TextIO.closeOut out;
       print ("the file kept: " ^ TextIO.inputAll (TextIO.openIn "tests/out/rt.save_restore.txt")))
