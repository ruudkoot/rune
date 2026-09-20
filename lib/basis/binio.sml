(* BinIO: the imperative binary streams (signature BIN_IO).

   Implements: BIN_IO

   Implements: IMPERATIVE_IO *)
structure BinIO =
struct
  (* "For binary streams, LINE_BUF mode should be treated as a synonym for
     BLOCK_BUF": no element is a newline.

     Implements: STREAM_IO where type vector = Word8Vector.vector where type
     elem = Word8.word where type reader = BinPrimIO.reader where type writer
     = BinPrimIO.writer where type pos = Position.int *)
  structure StreamIO =
    RuneStreamIOFn (structure PIO = BinPrimIO structure V = Word8Vector structure VS = Word8VectorSlice
                    val isNewline = fn (_ : Word8.word) => false)

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
    fun closedIo (name, function) = raise IO.Io {name = name, function = function, cause = IO.ClosedStream}
    (* The reader and the writer of a file of the VM, as in TextIO: the
       positions of the file when it has them; the writer writes through, the
       stream leaves the VM to buffer. *)
    fun reader (fd, name) =
      let
        val closed = ref false
        val ({getPos, setPos, endPos, verifyPos}, remember) = RuneFile.positions (fd, name, closed)
        fun readVec n = if !closed then closedIo (name, "readVec") else RuneFile.readVec fd n
      in
        BinPrimIO.RD {name = name, chunkSize = RuneFile.chunkSize,
                      readVec = SOME readVec, readArr = NONE,
                      readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                      avail = fn () => if !closed then closedIo (name, "avail") else RuneFile.avail fd (),
                      getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos,
                      close = fn () => if !closed then () else (remember (); closed := true; RuneFile.close fd ()),
                      ioDesc = SOME (RuneIODesc.FD (RuneFile.descriptor fd))}
      end
    fun writer (fd, name) =
      let
        val closed = ref false
        val ({getPos, setPos, endPos, verifyPos}, remember) = RuneFile.positions (fd, name, closed)
        fun put v = if !closed then closedIo (name, "writeVec") else ignore (RuneFile.writeString (fd, name) v)
        fun writeVec sl =
          let val v = Word8VectorSlice.vector sl in put v; RuneFile.flush fd (); Word8Vector.length v end
      in
        (BinPrimIO.WR {name = name, chunkSize = RuneFile.chunkSize,
                       writeVec = SOME writeVec, writeArr = NONE, writeVecNB = NONE, writeArrNB = NONE,
                       block = NONE, canOutput = NONE,
                       getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos,
                       close = fn () => if !closed then () else (remember (); closed := true; RuneFile.close fd ()),
                       ioDesc = SOME (RuneIODesc.FD (RuneFile.descriptor fd))},
         {write = put, flush = RuneFile.flush fd})
      end
    fun outstreamOf (fd, name) =
      let val (w, device) = writer (fd, name)
      in mkOutstream (StreamIO.mkOutstreamOver (w, IO.BLOCK_BUF, device)) end
  in
    fun openIn name =
      mkInstream (StreamIO.mkInstream (reader (RuneFile.open' ("openIn", 0) name, name), Word8Vector.fromList []))
    fun openOut name =
      outstreamOf (RuneFile.open' ("openOut", 1) name, name)
    fun openAppend name =
      outstreamOf (RuneFile.open' ("openAppend", 2) name, name)
  end
end
