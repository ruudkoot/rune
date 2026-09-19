(* requires: TextIO TextPrimIO CharVector CharVectorSlice CharArraySlice IO OS Substring StringCvt Int *)
(* uses: spec-sigs/STREAM_IO.sml spec-sigs/IMPERATIVE_IO.sml fn/io_script.sml fn/stream_io_fn.sml fn/imperative_io_fn.sml *)
(* TextIO.StreamIO (signature TEXT_STREAM_IO, which includes STREAM_IO) and
   the members of TextIO that convert to and from it. Expected values follow
   https://smlfamily.github.io/Basis/stream-io.html, text-stream-io.html,
   imperative-io.html, text-io.html and io.html.

   The checks that hold for every STREAM_IO and IMPERATIVE_IO structure are in
   fn/stream_io_fn.sml and fn/imperative_io_fn.sml; they run the streams over
   readers and writers of their own, which TextRW builds; a writer needs
   TextPrimIO.vector_slice to be CharVectorSlice.slice (io_primio_sig.sml). This file adds the members of
   TEXT_STREAM_IO and what files show: the buffer modes of the streams that
   TextIO opens, when output reaches the file under each mode, and the
   positions of the readers and writers of files.

   The files are made in the current directory and removed at the end. *)
structure TestTextIOStreamIO =
struct
  (* The readers and writers of TextPrimIO, for fn/io_script.sml. *)
  structure TextRW : IO_RW =
  struct
    type vector = string
    type vector_slice = CharVectorSlice.slice
    type reader = TextPrimIO.reader
    type writer = TextPrimIO.writer
    fun fromString (s : string) = s
    fun toString (s : string) = s
    val sliceVector = CharVectorSlice.vector
    val fullSlice = CharVectorSlice.full
    fun mkReader {name, chunkSize, readVec, readVecNB, close} =
      TextPrimIO.RD {name = name, chunkSize = chunkSize, readVec = SOME readVec, readArr = NONE,
                     readVecNB = readVecNB, readArrNB = NONE, block = NONE, canInput = NONE,
                     avail = fn () => NONE, getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                     close = close, ioDesc = NONE}
    fun mkWriter {name, chunkSize, writeVec, close} =
      TextPrimIO.WR {name = name, chunkSize = chunkSize, writeVec = SOME writeVec,
                     writeArr = SOME (fn sl => writeVec (CharVectorSlice.full (CharArraySlice.vector sl))),
                     writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                     getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                     close = close, ioDesc = NONE}
    fun readerName (TextPrimIO.RD {name, ...}) = name
    fun readerReadVec (TextPrimIO.RD {readVec, ...}) = readVec
    fun readerClose (TextPrimIO.RD {close, ...}) = close ()
    fun writerName (TextPrimIO.WR {name, ...}) = name
    fun writerWriteVec (TextPrimIO.WR {writeVec, ...}) = writeVec
    fun writerClose (TextPrimIO.WR {close, ...}) = close ()
  end
  fun idc (c : char) = c
  structure Generic = TestStreamIOFn (structure RW = TextRW structure S = TextIO.StreamIO val name = "TextIO.StreamIO" val elemChar = idc val charElem = idc val text = true)
  structure Imperative = TestImperativeIOFn (structure RW = TextRW structure I = TextIO val name = "TextIO" val elemChar = idc val charElem = idc)
  structure R = IOScriptFn (TextRW)
  structure S = TextIO.StreamIO

  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqSL = T.eq (T.list T.string)
  val eqSOL = T.eq (T.list (T.option T.string))

  fun instream (pieces : string list) : S.instream = S.mkInstream (#1 (R.reader ("script", pieces)), "")
  fun line (f : S.instream) : string option = Option.map #1 (S.inputLine f)
  (* lines (f, k): the lines inputLine returns along the stream, up to NONE. *)
  fun lines (f : S.instream, k : int) : string option list =
    if k = 0 then []
    else case S.inputLine f of NONE => [NONE] | SOME (l, f') => SOME l :: lines (f', k - 1)
  fun outstream (mode : IO.buffer_mode) : S.outstream * R.log =
    let val (w, log) = R.writer "memory" in (S.mkOutstream (w, mode), log) end

  (* ==== inputLine ==== *)
  (* "ln returns all characters from the current position up to and
     including the next newline (#"\n") character. If it detects an
     end-of-stream before the next newline, it returns the characters read
     appended with a newline. [...] If the current stream position is the
     end-of-stream, then it returns NONE." *)
  val () = eqSOL ("TextIO.StreamIO.inputLine/lines-then-NONE", [SOME "abc\n", SOME "de\n", NONE],
                  fn () => lines (instream ["ab", "c\nd", "e\n"], 10))
  val () = eqSOL ("TextIO.StreamIO.inputLine/last-line-gets-a-newline", [SOME "ab\n", NONE],
                  fn () => lines (instream ["a", "b"], 10))
  val () = eqSOL ("TextIO.StreamIO.inputLine/empty-stream", [NONE], fn () => lines (instream [], 10))
  val () = eqSOL ("TextIO.StreamIO.inputLine/at-end-of-stream", [NONE], fn () => lines (instream ["", "x\n"], 10))
  val () = eqSOL ("TextIO.StreamIO.inputLine/line-ends-at-end-of-stream", [SOME "ab\n"],
                  fn () => [line (instream ["ab", "", "cd\n"])])
  val () = eqSOL ("TextIO.StreamIO.inputLine/empty-lines", [SOME "\n", SOME "\n", SOME "x\n", NONE],
                  fn () => lines (instream ["\n\nx"], 10))
  val () = eqSOL ("TextIO.StreamIO.inputLine/same-result-twice", [SOME "ab\n", SOME "ab\n"],
                  fn () => let val f = instream ["a", "b\nc"] in [line f, line f] end)
  (* "strm' is the residual stream" *)
  val () = eqS ("TextIO.StreamIO.inputLine/residual-stream", "cd\ne",
                fn () => case S.inputLine (instream ["ab\nc", "d\ne"]) of
                           SOME (_, f') => #1 (S.inputAll f')
                         | NONE => "NONE")
  val () = eqB ("TextIO.StreamIO.inputLine/does-not-change-the-stream", true,
                fn () => let val f = instream ["ab\ncd"] in ignore (S.inputLine f); #1 (S.inputAll f) = "ab\ncd" end)
  val () = eqB ("TextIO.StreamIO.inputLine/long-line", true,
                fn () => let
                           val piece = CharVector.tabulate (97, fn i => Char.chr (97 + i mod 26))
                           val f = instream (List.tabulate (200, fn _ => piece) @ ["\nnext"])
                         in line f = SOME (String.concat (List.tabulate (200, fn _ => piece)) ^ "\n") end)
  val () = eqSOL ("TextIO.StreamIO.inputLine/carriage-return-is-kept", [SOME "a\r\n", SOME "b\r\n"],
                  fn () => let val f = instream ["a\r\nb\r"] in lines (f, 2) end)

  (* ==== outputSubstr ==== *)
  (* "This is equivalent to: output (strm, Substring.string ss)" *)
  val () = eqS ("TextIO.StreamIO.outputSubstr/is-output-of-the-string", "ell",
                fn () => let val (s, log) = outstream IO.NO_BUF in S.outputSubstr (s, Substring.substring ("hello", 1, 3)); R.written log end)
  val () = eqS ("TextIO.StreamIO.outputSubstr/empty", "ab",
                fn () => let val (s, log) = outstream IO.NO_BUF
                         in S.output (s, "a"); S.outputSubstr (s, Substring.substring ("xyz", 3, 0)); S.output (s, "b"); R.written log end)
  val () = eqSL ("TextIO.StreamIO.outputSubstr/buffered", ["", "", "a\nb\nc"],
                 fn () => let
                            val (s, log) = outstream IO.BLOCK_BUF
                            val () = S.outputSubstr (s, Substring.full "a\nb")
                            val a = R.written log
                            val () = S.outputSubstr (s, Substring.extract ("x\nc", 1, NONE))
                            val b = R.written log
                          in S.flushOut s; [a, b, R.written log] end)
  val () = eqSL ("TextIO.StreamIO.outputSubstr/LINE_BUF", ["", "ab\n"],
                 fn () => let
                            val (s, log) = outstream IO.LINE_BUF
                            val () = S.outputSubstr (s, Substring.substring ("xab", 1, 2))
                            val a = R.written log
                            val () = S.outputSubstr (s, Substring.full "\n")
                          in [a, R.written log] end)
  val () = eqS ("TextIO.StreamIO.outputSubstr/Io-closed", "ClosedStream",
                fn () => let val (s, _) = outstream IO.NO_BUF
                         in S.closeOut s; R.ioCause (fn () => S.outputSubstr (s, Substring.extract ("yx", 1, NONE))) end)

  (* ==== input1 as a reader of characters ==== *)
  (* "its type makes it a (char,instream) StringCvt.reader and thus a source
     of characters for the various scan functions" *)
  val () = eqSL ("TextIO.StreamIO.input1/is-a-StringCvt.reader", ["42", " x"],
                 fn () => case Int.scan StringCvt.DEC S.input1 (instream [" 4", "2 x"]) of
                            SOME (n, f') => [Int.toString n, #1 (S.inputAll f')]
                          | NONE => ["NONE"])

  (* ==== files ==== *)
  val made : string list ref = ref []
  fun file (what : string) : string = let val name = "textio-streamio-" ^ what ^ ".txt" in made := name :: !made; name end
  fun write (name : string, s : string) : unit =
    let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
  fun slurp (name : string) : string =
    let val ins = TextIO.openIn name val s = TextIO.inputAll ins in TextIO.closeIn ins; s end
  fun showMode IO.NO_BUF = "NO_BUF"
    | showMode IO.LINE_BUF = "LINE_BUF"
    | showMode IO.BLOCK_BUF = "BLOCK_BUF"
  (* readAll rd: what readVec returns up to an empty vector. *)
  fun readAll (TextPrimIO.RD {readVec = SOME f, ...}) =
        let fun go acc = case f 100 of "" => String.concat (List.rev acc) | s => go (s :: acc) in go [] end
    | readAll (TextPrimIO.RD {readVec = NONE, ...}) = "<no readVec>"

  (* "When opening a stream for writing, the stream will be block buffered by
     default, unless the underlying file is associated with an interactive or
     terminal device"; "stdErr is initially unbuffered" (text-io.html). *)
  val () = T.eq showMode ("TextIO.StreamIO.getBufferMode/openOut-is-BLOCK_BUF", IO.BLOCK_BUF,
                          fn () => let val out = TextIO.openOut (file "mode")
                                   in S.getBufferMode (TextIO.getOutstream out) before TextIO.closeOut out end)
  val () = T.eq showMode ("TextIO.StreamIO.getBufferMode/openAppend-is-BLOCK_BUF", IO.BLOCK_BUF,
                          fn () => let val out = TextIO.openAppend (file "mode")
                                   in S.getBufferMode (TextIO.getOutstream out) before TextIO.closeOut out end)
  val () = T.eq showMode ("TextIO.StreamIO.getBufferMode/stdErr-is-NO_BUF", IO.NO_BUF,
                          fn () => S.getBufferMode (TextIO.getOutstream TextIO.stdErr))
  (* io.html: NO_BUF writes "directly to the corresponding device"; LINE_BUF
     flushes at a newline. *)
  val () = eqSL ("TextIO.StreamIO.setBufferMode/NO_BUF-file", ["abc", "abcd"],
                 fn () => let
                            val name = file "nobuf"
                            val out = TextIO.openOut name
                            val () = S.setBufferMode (TextIO.getOutstream out, IO.NO_BUF)
                            val () = TextIO.output (out, "abc")
                            val a = slurp name
                            val () = TextIO.output1 (out, #"d")
                            val b = slurp name
                          in TextIO.closeOut out; [a, b] end)
  val () = eqS ("TextIO.StreamIO.setBufferMode/LINE_BUF-file", "ab\n",
                fn () => let
                           val name = file "linebuf"
                           val out = TextIO.openOut name
                           val () = S.setBufferMode (TextIO.getOutstream out, IO.LINE_BUF)
                           val () = TextIO.output (out, "ab\n")
                         in slurp name before TextIO.closeOut out end)
  val () = eqS ("TextIO.StreamIO.setBufferMode/NO_BUF-flushes-file", "abc",
                fn () => let
                           val name = file "nobuf2"
                           val s = TextIO.getOutstream (TextIO.openOut name)
                           val () = S.output (s, "abc")
                           val () = S.setBufferMode (s, IO.NO_BUF)
                         in slurp name before S.closeOut s end)
  (* STREAM_IO.flushOut "flushes any output in f's buffer to the underlying
     writer", whose writeVec "writes the elements [...] to the output device"
     (prim-io.html). *)
  val () = eqS ("TextIO.StreamIO.flushOut/file", "abc",
                fn () => let
                           val name = file "flush"
                           val s = TextIO.getOutstream (TextIO.openOut name)
                           val () = S.output (s, "abc")
                           val () = S.flushOut s
                         in slurp name before S.closeOut s end)
  val () = eqSL ("TextIO.StreamIO.closeOut/file", ["abc", "Io"],
                 fn () => let
                            val name = file "close"
                            val out = TextIO.openOut name
                            val s = TextIO.getOutstream out
                            val () = S.output (s, "abc")
                            val () = S.closeOut s
                          in [slurp name, (TextIO.output (out, "x"); "no Io") handle IO.Io _ => "Io"] end)
  (* getWriter "flushes the stream f [...] and returns the underlying
     writer" *)
  val () = eqSL ("TextIO.StreamIO.getWriter/file", ["ab", "abcd"],
                 fn () => let
                            val name = file "writer"
                            val s = TextIO.getOutstream (TextIO.openOut name)
                            val () = S.output (s, "ab")
                            val (w, _) = S.getWriter s
                            val a = slurp name
                            val TextPrimIO.WR {writeVec, close, ...} = w
                            val () = case writeVec of SOME f => ignore (f (CharVectorSlice.full "cd")) | NONE => ()
                          in [a, slurp name] before close () end)
  val () = eqS ("TextIO.StreamIO.mkOutstream/file-writer", "abcd",
                fn () => let
                           val name = file "mkout"
                           val s = TextIO.getOutstream (TextIO.openOut name)
                           val () = S.output (s, "ab")
                           val (w, _) = S.getWriter s
                           val s' = S.mkOutstream (w, IO.NO_BUF)
                           val () = S.output (s', "cd")
                         in slurp name before S.closeOut s' end)
  (* "if one opens a stream, then extracts the underlying reader, the reader
     has not yet been advanced in its file" *)
  val () = eqSL ("TextIO.StreamIO.getReader/file", ["", "hello\nworld\n"],
                 fn () => let
                            val name = file "reader"
                            val () = write (name, "hello\nworld\n")
                            val (rd, v) = S.getReader (TextIO.getInstream (TextIO.openIn name))
                            val TextPrimIO.RD {close, ...} = rd
                          in [v, readAll rd] before close () end)
  val () = eqS ("TextIO.StreamIO.mkInstream/file-reader", "hello\nworld\n",
                fn () => let
                           val name = file "reader2"
                           val () = write (name, "hello\nworld\n")
                           val (rd, _) = S.getReader (TextIO.getInstream (TextIO.openIn name))
                           val f = S.mkInstream (rd, "")
                         in #1 (S.inputAll f) before S.closeIn f end)
  val () = eqSL ("TextIO.getInstream/file", ["hel", "lo\n", "lo\n"],
                 fn () => let
                            val name = file "getin"
                            val () = write (name, "hello\n")
                            val ins = TextIO.openIn name
                            val a = TextIO.inputN (ins, 3)
                            val f = TextIO.getInstream ins
                            val b = #1 (S.inputAll f)
                          in [a, b, TextIO.inputAll ins] before TextIO.closeIn ins end)

  (*<< positions *)
  (* The positions of the readers and writers of files. "If the pos type is
     a concrete integer corresponding to a byte offset [...]" is not so for
     TextIO.StreamIO, whose pos is abstract, so only their order and what
     setPos and setPosOut do can be checked. *)
  fun positions (name : string) =
    let
      val () = write (name, "hello world")
      val f0 = TextIO.getInstream (TextIO.openIn name)
      val p0 = S.filePosIn f0
      val (_, f3) = S.inputN (f0, 3)
      val p3 = S.filePosIn f3
    in (f0, p0, f3, p3) end
  (* "returns the primitive-level reader position that corresponds to the
     next element to be read"; getPos "must be non-decreasing". *)
  val () = T.eq (T.list T.order) ("TextPrimIO.compare/file-positions", [LESS, GREATER, EQUAL, EQUAL],
                                  fn () => let val (f0, p0, _, p3) = positions (file "pos")
                                           in [TextPrimIO.compare (p0, p3), TextPrimIO.compare (p3, p0), TextPrimIO.compare (p3, p3),
                                               TextPrimIO.compare (p0, S.filePosIn f0)] before S.closeIn f0 end)
  (* "if #1(inputAll f) returns vector v, then (setPos (filePosIn f); readVec
     (length v)) should also return v" *)
  val () = eqS ("TextIO.StreamIO.filePosIn/setPos-then-readVec", "lo world",
                fn () => let
                           val (_, _, f3, p3) = positions (file "pos2")
                           val v = #1 (S.inputAll f3)
                           val (rd, _) = S.getReader f3
                           val TextPrimIO.RD {setPos, readVec, close, ...} = rd
                         in
                           case (setPos, readVec) of
                             (SOME set, SOME read) =>
                               (set p3;
                                let fun go (k, acc) = if k <= 0 then acc else case read k of "" => acc | s => go (k - size s, acc ^ s)
                                in go (size v, "") end)
                           | _ => "<no setPos or readVec>"
                         end)
  val () = T.raises ("TextIO.StreamIO.filePosIn/Io-truncated", R.isIo,
                     fn () => let val (f0, _, _, _) = positions (file "pos3") in ignore (S.getReader f0); S.filePosIn f0 end)
  (* getPosOut "returns the current position of the stream"; setPosOut
     "flushes the output buffer of the stream underlying opos, sets the
     current position of the stream to the position recorded in opos, and
     returns the stream"; filePosOut "returns the primitive-level writer
     position that corresponds to the abstract output stream position". *)
  val () = eqS ("TextIO.StreamIO.setPosOut/file-overwrites", "abcXYfg",
                fn () => let
                           val name = file "setpos"
                           val s = TextIO.getOutstream (TextIO.openOut name)
                           val () = S.output (s, "abc")
                           val p = S.getPosOut s
                           val () = S.output (s, "defg")
                           val s' = S.setPosOut p
                           val () = S.output (s', "XY")
                         in S.closeOut s'; slurp name end)
  val () = eqB ("TextIO.StreamIO.getPosOut/is-where-the-next-element-goes", true,
                fn () => let
                           val name = file "getpos"
                           val s = TextIO.getOutstream (TextIO.openOut name)
                           val () = S.output (s, "abc")
                           val p = S.getPosOut s
                           val () = S.output (s, "d")
                           val q = S.getPosOut s
                         in TextPrimIO.compare (S.filePosOut p, S.filePosOut q) = LESS before S.closeOut s end)
  val () = eqB ("TextIO.StreamIO.filePosOut/is-the-writer's-position", true,
                fn () => let
                           val name = file "fileposout"
                           val s = TextIO.getOutstream (TextIO.openOut name)
                           val () = S.output (s, "abc")
                           val p = S.filePosOut (S.getPosOut s)
                           val (TextPrimIO.WR {getPos, close, ...}, _) = S.getWriter s
                         in (case getPos of SOME g => g () = p | NONE => false) before close () end)
  val () = eqS ("TextIO.setPosOut/file-overwrites", "abXd",
                fn () => let
                           val name = file "setpos2"
                           val out = TextIO.openOut name
                           val () = TextIO.output (out, "ab")
                           val p = TextIO.getPosOut out
                           val () = TextIO.output (out, "cd")
                           val () = TextIO.setPosOut (out, p)
                           val () = TextIO.output (out, "X")
                         in TextIO.closeOut out; slurp name end)
  val () = eqB ("TextIO.getPosOut/file", true,
                fn () => let
                           val out = TextIO.openOut (file "getpos2")
                           val p0 = TextIO.getPosOut out
                           val () = TextIO.output (out, "ab")
                           val p2 = TextIO.getPosOut out
                         in TextPrimIO.compare (S.filePosOut p0, S.filePosOut p2) = LESS before TextIO.closeOut out end)
  (*>> positions *)

  val () = List.app (fn name => OS.FileSys.remove name handle _ => ()) (!made)
end
