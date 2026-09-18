(* File streams: write, read back line by line and all at once, append raw
   bytes, and error reporting through IO.Io. *)
val path = "tests/out/basis.textio.files_roundtrip.tmp"

val out = TextIO.openOut path
val () = TextIO.output (out, "alpha\n")
val () = TextIO.output (out, "beta\n")
val () = TextIO.output1 (out, #"g")
val () = TextIO.closeOut out

val ins = TextIO.openIn path
val () = print (case TextIO.inputLine ins of SOME l => "line: " ^ l | NONE => "eof\n")
val () = print ("rest: " ^ TextIO.inputAll ins ^ "|\n")
val () = print ("at eof: " ^ Bool.toString (not (isSome (TextIO.inputLine ins))) ^ "\n")
val () = TextIO.closeIn ins

val ins2 = TextIO.openIn path
fun lines () = case TextIO.inputLine ins2 of NONE => [] | SOME l => l :: lines ()
val ls = lines ()
val () = print (Int.toString (length ls) ^ " lines\n")
val () = List.app (fn l => print ("[" ^ String.toString l ^ "]\n")) ls
val () = TextIO.closeIn ins2

val app = TextIO.openAppend path
val () = TextIO.output (app, "\000\255\n")
val () = TextIO.closeOut app
val ins3 = TextIO.openIn path
val all = TextIO.inputAll ins3
val () = TextIO.closeIn ins3
val () = print ("size " ^ Int.toString (size all) ^ "\n")
val () = print ("bytes " ^ Int.toString (Char.ord (String.sub (all, 12))) ^ " "
                ^ Int.toString (Char.ord (String.sub (all, 13))) ^ "\n")

val () = (ignore (TextIO.openIn "tests/out/no-such-file.tmp"); print "opened?!\n")
         handle IO.Io {name, function, cause = OS.SysErr _} => print ("Io " ^ function ^ " " ^ name ^ "\n")
val () = (TextIO.output (out, "late\n"); print "wrote?!\n")
         handle IO.Io {function, cause = IO.ClosedStream, ...} => print ("closed " ^ function ^ "\n")
val () = (ignore (TextIO.inputLine ins); print "read?!\n")
         handle IO.Io {function, cause = IO.ClosedStream, ...} => print ("closed " ^ function ^ "\n")
