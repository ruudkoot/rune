(* BinIO: the imperative binary streams (signature BIN_IO). *)
structure BinIO =
struct
  structure StreamIO =
    RuneStreamIOFn (structure PIO = BinPrimIO structure V = Word8Vector structure VS = Word8VectorSlice)

  structure Imperative = RuneImperativeIOFn (structure SIO = StreamIO structure V = Word8Vector)

  type vector = Word8Vector.vector
  type elem = Word8.word
  datatype instream = datatype Imperative.instream
  datatype outstream = datatype Imperative.outstream

  val input = Imperative.input
  val input1 = Imperative.input1
  val inputN = Imperative.inputN
  val inputAll = Imperative.inputAll
  val canInput = Imperative.canInput
  val lookahead = Imperative.lookahead
  val closeIn = Imperative.closeIn
  val endOfStream = Imperative.endOfStream
  val output = Imperative.output
  val output1 = Imperative.output1
  val flushOut = Imperative.flushOut
  val closeOut = Imperative.closeOut
  val getPosOut = Imperative.getPosOut
  val setPosOut = Imperative.setPosOut
  val mkInstream = Imperative.mkInstream
  val getInstream = Imperative.getInstream
  val setInstream = Imperative.setInstream
  val mkOutstream = Imperative.mkOutstream
  val getOutstream = Imperative.getOutstream
  val setOutstream = Imperative.setOutstream

  local
    fun reader (fd, name) =
      BinPrimIO.RD {name = name, chunkSize = RuneFile.chunkSize,
                    readVec = SOME (RuneFile.readVec fd), readArr = NONE,
                    readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                    avail = RuneFile.avail fd,
                    getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                    close = RuneFile.close fd, ioDesc = SOME (RuneIODesc.FD fd)}
    fun writer (fd, name) =
      BinPrimIO.WR {name = name, chunkSize = RuneFile.chunkSize,
                    writeVec = SOME (fn sl => RuneFile.writeString (fd, name) (Word8VectorSlice.vector sl)),
                    writeArr = NONE, writeVecNB = NONE, writeArrNB = NONE,
                    block = NONE, canOutput = NONE,
                    getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                    close = RuneFile.close fd, ioDesc = SOME (RuneIODesc.FD fd)}
    fun outstreamOf (fd, name) =
      Imperative.mkOutstreamOver (StreamIO.mkOutstream (writer (fd, name), IO.NO_BUF), RuneFile.flush fd)
  in
    fun openIn name =
      mkInstream (StreamIO.mkInstream (reader (RuneFile.open' ("openIn", 0) name, name), ""))
    fun openOut name =
      outstreamOf (RuneFile.open' ("openOut", 1) name, name)
    fun openAppend name =
      outstreamOf (RuneFile.open' ("openAppend", 2) name, name)
  end
end
