(* TextIO: the imperative text streams (signature TEXT_IO). *)
structure TextIO =
struct
  structure StreamIO =
    RuneStreamIOFn (structure PIO = TextPrimIO structure V = CharVector structure VS = CharVectorSlice)

  structure Imperative = RuneImperativeIOFn (structure SIO = StreamIO structure V = CharVector)

  type vector = string
  type elem = char
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
    (* A file of the VM as a reader and as a writer. *)
    fun reader (fd, name) =
      TextPrimIO.RD {name = name, chunkSize = RuneFile.chunkSize,
                     readVec = SOME (RuneFile.readVec fd), readArr = NONE,
                     readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                     avail = RuneFile.avail fd,
                     getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                     close = RuneFile.close fd, ioDesc = SOME (RuneIODesc.FD (RuneFile.descriptor fd))}
    fun writer (fd, name) =
      TextPrimIO.WR {name = name, chunkSize = RuneFile.chunkSize,
                     writeVec = SOME (fn sl => RuneFile.writeString (fd, name) (CharVectorSlice.vector sl)),
                     writeArr = NONE, writeVecNB = NONE, writeArrNB = NONE,
                     block = NONE, canOutput = NONE,
                     getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                     close = RuneFile.close fd, ioDesc = SOME (RuneIODesc.FD (RuneFile.descriptor fd))}
    fun instreamOf (fd, name) = mkInstream (StreamIO.mkInstream (reader (fd, name), ""))
    (* The VM buffers a file of its own, so the stream layer keeps nothing:
       what a program writes through print and through a stream then reaches
       the file in the order it was written. *)
    fun outstreamOf (fd, name) = Imperative.mkOutstreamOver (StreamIO.mkOutstream (writer (fd, name), IO.NO_BUF), RuneFile.flush fd)
  in
    fun openIn name = instreamOf (RuneFile.open' ("openIn", 0) name, name)
    fun openOut name = outstreamOf (RuneFile.open' ("openOut", 1) name, name)
    fun openAppend name = outstreamOf (RuneFile.open' ("openAppend", 2) name, name)
    fun openString s = mkInstream (StreamIO.mkInstream (TextPrimIO.openVector s, ""))

    val stdIn = instreamOf (0, "<stdIn>")
    val stdOut = outstreamOf (1, "<stdOut>")
    val stdErr = outstreamOf (2, "<stdErr>")
  end

  (* A line includes its newline; a last line without one gets it. NONE at
     the end of the stream, which is not passed: "if endOfStream f returns
     true, then input f returns ("", f')". *)
  fun inputLine (InStream r) =
    let
      fun index (v, i) =
        if i >= size v then NONE else if String.sub (v, i) = #"\n" then SOME i else index (v, i + 1)
      fun go (strm, acc) =
        let val (v, strm') = StreamIO.input strm
        in
          if size v = 0 then
            case acc of
              [] => (r := strm; NONE)
            | _ => (r := strm'; SOME (String.concat (List.rev ("\n" :: acc))))
          else
            case index (v, 0) of
              SOME k =>
                (r := #2 (StreamIO.inputN (strm, k + 1));
                 SOME (String.concat (List.rev (String.extract (v, 0, SOME (k + 1)) :: acc))))
            | NONE => go (strm', v :: acc)
        end
    in go (!r, []) end

  fun outputSubstr (strm, ss) = output (strm, Substring.string ss)

  (* "print s = (output (stdOut, s); flushOut stdOut)" *)
  fun print s = (output (stdOut, s); flushOut stdOut)

  (* The scanner reads from the functional stream and the imperative one is
     left where it stopped. *)
  fun scanStream scan (InStream r) =
    case scan StreamIO.input1 (!r) of
      SOME (v, rest) => (r := rest; SOME v)
    | NONE => NONE
end
