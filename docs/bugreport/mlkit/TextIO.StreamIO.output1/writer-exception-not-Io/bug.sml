(* output1 on an unbuffered stream whose writer fails *)
fun describe f =
  (f (); "no exception")
  handle IO.Io {function, name, cause} =>
           "Io {function = \"" ^ function ^ "\", name = \"" ^ name ^ "\", cause = " ^ exnName cause ^ "}"
       | e => exnName e ^ " (not Io)"

(* a writer that always fails *)
exception Broken
val writer =
  TextPrimIO.WR {name = "broken", chunkSize = 1024,
                 writeVec = SOME (fn _ => raise Broken), writeArr = SOME (fn _ => raise Broken),
                 writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                 getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                 close = fn () => (), ioDesc = NONE}
val f = TextIO.StreamIO.mkOutstream (writer, IO.NO_BUF)
val () = print ("TextIO.StreamIO.output1: " ^ describe (fn () => TextIO.StreamIO.output1 (f, #"x")) ^ "\n")
val () = print ("TextIO.StreamIO.output:  " ^ describe (fn () => TextIO.StreamIO.output (f, "x")) ^ "\n")

(* TextIO.stdErr is unbuffered: close its descriptor underneath it *)
val () = Posix.IO.close Posix.FileSys.stderr
val () = print ("TextIO.output1 stdErr:   " ^ describe (fn () => TextIO.output1 (TextIO.stdErr, #"x")) ^ "\n")
val () = print ("TextIO.output stdErr:    " ^ describe (fn () => TextIO.output (TextIO.stdErr, "x")) ^ "\n")
