(* closeOut of an output stream that getWriter has terminated *)
fun slurp name = let val ins = TextIO.openIn name in TextIO.inputAll ins before TextIO.closeIn ins end

(* a writer that counts the calls of its close *)
val closes = ref 0
val writer =
  TextPrimIO.WR {name = "counting", chunkSize = 1024,
                 writeVec = SOME CharVectorSlice.length, writeArr = SOME CharArraySlice.length,
                 writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                 getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                 close = fn () => closes := !closes + 1, ioDesc = NONE}
val f = TextIO.StreamIO.mkOutstream (writer, IO.BLOCK_BUF)
val _ = TextIO.StreamIO.getWriter f
val () = TextIO.StreamIO.closeOut f
val () = print ("closeOut after getWriter: the writer was closed " ^ Int.toString (!closes) ^ " times\n")

(* the same on a file: the writer still writes after closeOut *)
val f = TextIO.getOutstream (TextIO.openOut "a.txt")
val (TextPrimIO.WR {writeVec, ...}, _) = TextIO.StreamIO.getWriter f
val () = TextIO.StreamIO.closeOut f
val () = print ("writeVec of the file's writer after closeOut: "
                ^ (Int.toString (valOf writeVec (CharVectorSlice.full "abc")) handle e => exnName e) ^ "\n")
val () = print ("the file holds \"" ^ slurp "a.txt" ^ "\"\n")
