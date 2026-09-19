(* A stream over a writer of the program's own, block buffered, keeps its
   output until it is flushed; at the end of the program it is ("exit ...
   flushes and closes all I/O streams opened using the Library"). *)
val w = TextPrimIO.WR {name = "own", chunkSize = 1024,
                       writeVec = SOME (fn sl => (print (CharVectorSlice.vector sl); CharVectorSlice.length sl)),
                       writeArr = NONE, writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                       getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                       close = fn () => (), ioDesc = NONE}
val s = TextIO.mkOutstream (TextIO.StreamIO.mkOutstream (w, IO.BLOCK_BUF))
val () = TextIO.output (s, "held until the end\n")
val () = print "printed first\n"
