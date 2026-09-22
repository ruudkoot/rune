(* Unix: a program started with pipes to it, written to, read from, reaped.
   The program is the shell of the system: sh on POSIX, and on Windows
   cmd.exe (COMSPEC), which ends its lines with \r\n; uname says which. *)
val windows = List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ())
val (shell, args) =
  if windows then (valOf (OS.Process.getEnv "COMSPEC"), ["/d", "/v:on", "/c", "set /p line=& echo got [!line!]& exit 4"])
  else ("/bin/sh", ["-c", "read line; echo \"got [$line]\"; exit 4"])
val p : (TextIO.instream, TextIO.outstream) Unix.proc = Unix.execute (shell, args)
val out = Unix.textOutstreamOf p
val () = (TextIO.output (out, "hello unix\n"); TextIO.flushOut out)
val ins = Unix.textInstreamOf p
val line = String.translate (fn #"\r" => "" | c => String.str c) (valOf (TextIO.inputLine ins))
val () = print ("child said: " ^ line)
val () = print (case Unix.fromStatus (Unix.reap p) of
                  Unix.W_EXITSTATUS w => "exited " ^ Word8.toString w ^ "\n"
                | _ => "other\n")
