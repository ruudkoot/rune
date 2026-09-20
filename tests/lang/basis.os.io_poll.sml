(* OS.IO: the kind of a descriptor, and waiting for a file that is ready. *)
val f = OS.FileSys.tmpName ()
val out = TextIO.openOut f
val () = (TextIO.output (out, "data"); TextIO.closeOut out)
val ins = TextIO.openIn f
val desc = case TextIO.StreamIO.getReader (TextIO.getInstream ins) of
             (TextPrimIO.RD {ioDesc = SOME d, ...}, _) => d
           | _ => raise Fail "no descriptor"
val () = print ("kind is file: " ^ Bool.toString (OS.IO.kind desc = OS.IO.Kind.file) ^ "\n")
val d = valOf (OS.IO.pollDesc desc)
val ready = OS.IO.poll ([OS.IO.pollIn d], SOME (Time.fromMilliseconds 10))
val () = print ("ready: " ^ Int.toString (List.length ready) ^ " in: "
                ^ Bool.toString (List.all OS.IO.isIn ready) ^ "\n")
val () = (TextIO.closeIn ins; OS.FileSys.remove f)
