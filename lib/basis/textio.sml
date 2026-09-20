(* TextIO: the imperative text streams (signature TEXT_IO).

   Implements: TEXT_IO

   Implements: IMPERATIVE_IO *)
structure TextIO =
struct
  local
    structure SI =
      RuneStreamIOFn (structure PIO = TextPrimIO structure V = CharVector structure VS = CharVectorSlice
                      val isNewline = fn c => c = #"\n")
  in
    (* TEXT_STREAM_IO: STREAM_IO and the operations on lines and substrings.

       Implements: TEXT_STREAM_IO where type reader = TextPrimIO.reader where
       type writer = TextPrimIO.writer where type pos = TextPrimIO.pos

       Implements: STREAM_IO *)
    structure StreamIO =
    struct
      open SI

      (* "ln returns all characters from the current position up to and
         including the next newline (#"\n") character. If it detects an
         end-of-stream before the next newline, it returns the characters
         read appended with a newline. [...] If the current stream position
         is the end-of-stream, then it returns NONE." The line that ends at
         an end-of-stream leaves the stream after it. *)
      fun inputLine strm =
        let
          fun index (v, i) =
            if i >= size v then NONE else if String.sub (v, i) = #"\n" then SOME i else index (v, i + 1)
          fun go (strm, acc) =
            let val (v, strm') = input strm
            in
              if size v = 0 then
                case acc of
                  [] => NONE
                | _ => SOME (String.concat (List.rev ("\n" :: acc)), strm')
              else
                case index (v, 0) of
                  SOME k => SOME (String.concat (List.rev (String.extract (v, 0, SOME (k + 1)) :: acc)),
                                  #2 (inputN (strm, k + 1)))
                | NONE => go (strm', v :: acc)
            end
        in go (strm, []) end

      (* "This is equivalent to: output (strm, Substring.string ss)" *)
      fun outputSubstr (strm, ss) = output (strm, Substring.string ss)
    end
  end

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
    fun closedIo (name, function) = raise IO.Io {name = name, function = function, cause = IO.ClosedStream}
    (* A file of the VM as a reader, with the positions of the file when it
       has them; "Further operations on the reader (besides close and
       getPos) raise" Io with the cause ClosedStream. *)
    fun reader (fd, name) =
      let
        val closed = ref false
        val ({getPos, setPos, endPos, verifyPos}, remember) = RuneFile.positions (fd, name, closed)
        fun readVec n = if !closed then closedIo (name, "readVec") else RuneFile.readVec fd n
      in
        TextPrimIO.RD {name = name, chunkSize = RuneFile.chunkSize,
                       readVec = SOME readVec, readArr = NONE,
                       readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                       avail = fn () => if !closed then closedIo (name, "avail") else RuneFile.avail fd (),
                       getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos,
                       close = fn () => if !closed then () else (remember (); closed := true; RuneFile.close fd ()),
                       ioDesc = SOME (RuneIODesc.FD (RuneFile.descriptor fd))}
      end
    (* A file of the VM as a writer, which writes through, and the device of
       the stream over it, which leaves the VM to buffer. *)
    fun writer (fd, name) =
      let
        val closed = ref false
        val ({getPos, setPos, endPos, verifyPos}, remember) = RuneFile.positions (fd, name, closed)
        fun put s = if !closed then closedIo (name, "writeVec") else ignore (RuneFile.writeString (fd, name) s)
        fun writeVec sl = let val s = CharVectorSlice.vector sl in put s; RuneFile.flush fd (); size s end
      in
        (TextPrimIO.WR {name = name, chunkSize = RuneFile.chunkSize,
                        writeVec = SOME writeVec, writeArr = NONE, writeVecNB = NONE, writeArrNB = NONE,
                        block = NONE, canOutput = NONE,
                        getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos,
                        close = fn () => if !closed then () else (remember (); closed := true; RuneFile.close fd ()),
                        ioDesc = SOME (RuneIODesc.FD (RuneFile.descriptor fd))},
         {write = put, flush = RuneFile.flush fd})
      end
    fun instreamOf (fd, name) = mkInstream (StreamIO.mkInstream (reader (fd, name), ""))
    (* "When opening a stream for writing, the stream will be block buffered
       by default, unless the underlying file is associated with an
       interactive or terminal device (i.e., the kind of the underlying
       iodesc is OS.IO.Kind.tty), in which case the stream will be line
       buffered." The VM keeps the block; the stream keeps nothing, so that
       what a program writes through print and through a stream reaches the
       file in the order it was written. *)
    fun modeOf fd =
      (if RuneIODesc.kind (RuneIODesc.FD (RuneFile.descriptor fd)) = RuneIODesc.Kind.tty then IO.LINE_BUF
       else IO.BLOCK_BUF)
      handle _ => IO.BLOCK_BUF
    fun outstreamOf (fd, name, mode) =
      let val (w, device) = writer (fd, name)
      in mkOutstream (StreamIO.mkOutstreamOver (w, mode, device)) end
  in
    fun openIn name = instreamOf (RuneFile.open' ("openIn", 0) name, name)
    fun openOut name = let val fd = RuneFile.open' ("openOut", 1) name in outstreamOf (fd, name, modeOf fd) end
    fun openAppend name = let val fd = RuneFile.open' ("openAppend", 2) name in outstreamOf (fd, name, modeOf fd) end
    fun openString s = mkInstream (StreamIO.mkInstream (TextPrimIO.openVector s, ""))

    val stdIn = instreamOf (0, "<stdIn>")
    val stdOut = outstreamOf (1, "<stdOut>", modeOf 1)
    (* "stdErr is initially unbuffered" *)
    val stdErr = outstreamOf (2, "<stdErr>", IO.NO_BUF)
  end

  fun inputLine (InStream r) =
    case StreamIO.inputLine (!r) of
      SOME (l, s) => (r := s; SOME l)
    | NONE => NONE

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
