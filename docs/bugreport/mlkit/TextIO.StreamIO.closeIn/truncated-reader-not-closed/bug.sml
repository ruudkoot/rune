(* closeIn of an input stream that getReader has truncated *)
fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end

(* a reader of "abc" that counts the calls of its close *)
val closes = ref 0
val reader =
  TextPrimIO.RD {name = "counting", chunkSize = 1024, readVec = SOME (fn _ => "abc"),
                 readArr = NONE, readVecNB = NONE, readArrNB = NONE, block = NONE,
                 canInput = NONE, avail = fn () => NONE, getPos = NONE, setPos = NONE,
                 endPos = NONE, verifyPos = NONE, close = fn () => closes := !closes + 1,
                 ioDesc = NONE}
val f = TextIO.StreamIO.mkInstream (reader, "")
val _ = TextIO.StreamIO.getReader f
val () = TextIO.StreamIO.closeIn f
val () = print ("closeIn after getReader: the reader was closed " ^ Int.toString (!closes) ^ " times\n")

(* the same on a file: the reader is still usable after closeIn *)
val () = write ("a.txt", "abc")
val f = TextIO.getInstream (TextIO.openIn "a.txt")
val (TextPrimIO.RD {readVec, ...}, _) = TextIO.StreamIO.getReader f
val () = TextIO.StreamIO.closeIn f
val () = print ("readVec of the file's reader after closeIn: "
                ^ ("\"" ^ valOf readVec 10 ^ "\"" handle e => exnName e) ^ "\n")
