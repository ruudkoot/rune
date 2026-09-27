(* errorName of the syserror values of POSIX_ERROR that Linux shares with
   another name: EAGAIN = EWOULDBLOCK, ENOTSUP = EOPNOTSUPP. *)
structure E = Posix.Error
fun show (name, e) =
  print ("errorName " ^ name ^ " = \"" ^ E.errorName e ^ "\"; syserror \"" ^ name ^ "\" = "
         ^ (case E.syserror name of SOME e' => if e' = e then "SOME " ^ name else "SOME other" | NONE => "NONE")
         ^ "; OS.errorName = \"" ^ OS.errorName e ^ "\"\n")
val () = List.app show [("again", E.again), ("notsup", E.notsup), ("badmsg", E.badmsg)]
