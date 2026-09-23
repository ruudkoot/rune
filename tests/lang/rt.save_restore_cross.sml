(* rt.save: a world written to a file and taken up again, with an answer that
   depends on the heap, on a string, on a real and on the stack -- so that a
   restore which gets a width, an alignment or the order of the bytes wrong
   cannot agree by accident. Both worlds print the same line, which is what
   `make test-windows` and `make test-portability` compare when one machine
   saves and another restores (tests/run-windows.sh, tests/run-portability.sh). *)
fun count (0, acc) = acc | count (n, acc) = count (n - 1, n :: acc)
val live = count (2000, [])
val text = String.concat (List.map Int.toString (List.take (live, 40)))
val r = 2.718281828459045
fun answer () =
  Int.toString (List.foldl (op +) 0 live) ^ " " ^ Int.toString (String.size text)
  ^ " " ^ Real.fmt (StringCvt.FIX (SOME 9)) r
  ^ " " ^ Int.toString (List.length (Runtime.trace ()))
val () =
  case Runtime.save "tests/out/rt.save_restore_cross.img" of
    Runtime.Saved => print (answer () ^ "\n")
  | Runtime.Restored => print (answer () ^ "\n")
