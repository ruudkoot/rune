(* rt.trace: the call stack, as data and as the VM prints it when nothing
   handles an exception. A tail call leaves no frame behind, which is why
   neither `inner` nor `mid` is in the trace and `outer` is. *)
fun show ({function, file, line, ...} : Runtime.frame) =
  print (function ^ " " ^ file ^ ":" ^ Int.toString line ^ "\n")

fun inner () = Runtime.trace ()
fun mid () = inner ()                       (* a tail call: no frame of its own *)
fun outer () = let val t = mid () in t end  (* not a tail call: a frame *)
val () = List.app show (outer ())
val () = print "--\n"
val () = Runtime.printTrace TextIO.stdOut
val () = print "--\n"
fun boom () = raise Fail "boom"
fun caller () = boom () + 1
val () = print (Int.toString (caller ()) ^ "\n")
