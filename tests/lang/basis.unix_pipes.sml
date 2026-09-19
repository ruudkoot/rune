(* Unix: a program started with pipes to it, written to, read from, reaped. *)
val p : (TextIO.instream, TextIO.outstream) Unix.proc = Unix.execute ("/bin/sh", ["-c", "read line; echo \"got [$line]\"; exit 4"])
val out = Unix.textOutstreamOf p
val () = (TextIO.output (out, "hello unix\n"); TextIO.flushOut out)
val ins = Unix.textInstreamOf p
val () = print ("child said: " ^ valOf (TextIO.inputLine ins))
val () = print (case Unix.reap p of
                  Unix.W_EXITSTATUS w => "exited " ^ Word8.toString w ^ "\n"
                | _ => "other\n")
