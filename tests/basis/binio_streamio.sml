(* requires: BinIO BinPrimIO Word8 Word8Vector Word8VectorSlice Word8ArraySlice CharVector Position IO OS *)
(* uses: spec-sigs/STREAM_IO.sml spec-sigs/IMPERATIVE_IO.sml fn/io_script.sml fn/stream_io_fn.sml fn/imperative_io_fn.sml *)
(* BinIO.StreamIO (signature STREAM_IO) and the members of BinIO that convert
   to and from it. Expected values follow
   https://smlfamily.github.io/Basis/stream-io.html, imperative-io.html,
   bin-io.html, prim-io.html and io.html.

   The checks that hold for every STREAM_IO and IMPERATIVE_IO structure are in
   fn/stream_io_fn.sml and fn/imperative_io_fn.sml, on readers and writers of
   their own, which BinRW builds; a writer needs BinPrimIO.vector_slice to be
   Word8VectorSlice.slice (io_primio_sig.sml). Bytes are written there as the
   characters of the same code. This file adds the positions, which are concrete here: "the
   BinIO.StreamIO.pos type, equal to the BinPrimIO.pos type, is concrete,
   being a synonym for Position.int" (bin-io.html). They are checked on a
   reader and a writer of memory whose positions are the offsets of the
   elements, and on files, whose positions are byte offsets.

   The files are made in the current directory and removed at the end. *)
structure TestBinIOStreamIO =
struct
  fun fromString (s : string) : Word8Vector.vector = Word8Vector.tabulate (String.size s, fn i => Word8.fromInt (Char.ord (String.sub (s, i))))
  fun toString (v : Word8Vector.vector) : string = CharVector.tabulate (Word8Vector.length v, fn i => Char.chr (Word8.toInt (Word8Vector.sub (v, i))))
  fun elemChar (w : Word8.word) : char = Char.chr (Word8.toInt w)
  fun charElem (c : char) : Word8.word = Word8.fromInt (Char.ord c)
  (* The readers and writers of BinPrimIO, for fn/io_script.sml. *)
  structure BinRW : IO_RW =
  struct
    type vector = Word8Vector.vector
    type vector_slice = Word8VectorSlice.slice
    type reader = BinPrimIO.reader
    type writer = BinPrimIO.writer
    val fromString = fromString
    val toString = toString
    val sliceVector = Word8VectorSlice.vector
    val fullSlice = Word8VectorSlice.full
    fun mkReader {name, chunkSize, readVec, readVecNB, close} =
      BinPrimIO.RD {name = name, chunkSize = chunkSize, readVec = SOME readVec, readArr = NONE,
                    readVecNB = readVecNB, readArrNB = NONE, block = NONE, canInput = NONE,
                    avail = fn () => NONE, getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                    close = close, ioDesc = NONE}
    fun mkWriter {name, chunkSize, writeVec, close} =
      BinPrimIO.WR {name = name, chunkSize = chunkSize, writeVec = SOME writeVec,
                    writeArr = SOME (fn sl => writeVec (Word8VectorSlice.full (Word8ArraySlice.vector sl))),
                    writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                    getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                    close = close, ioDesc = NONE}
    fun readerName (BinPrimIO.RD {name, ...}) = name
    fun readerReadVec (BinPrimIO.RD {readVec, ...}) = readVec
    fun readerClose (BinPrimIO.RD {close, ...}) = close ()
    fun writerName (BinPrimIO.WR {name, ...}) = name
    fun writerWriteVec (BinPrimIO.WR {writeVec, ...}) = writeVec
    fun writerClose (BinPrimIO.WR {close, ...}) = close ()
  end
  structure Generic = TestStreamIOFn (structure RW = BinRW structure S = BinIO.StreamIO val name = "BinIO.StreamIO" val elemChar = elemChar val charElem = charElem val text = false)
  structure Imperative = TestImperativeIOFn (structure RW = BinRW structure I = BinIO val name = "BinIO" val elemChar = elemChar val charElem = charElem)
  structure S = BinIO.StreamIO

  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val eqSL = T.eq (T.list T.string)
  val eqIL = T.eq (T.list T.int)
  fun isIo (IO.Io _) = true
    | isIo _ = false

  (* ---- a reader and a writer of memory with positions ----
     memReader (content, start): a reader of content from offset start, with
     getPos and setPos (offsets). *)
  fun memReader (content : string, start : int) : BinPrimIO.reader =
    let
      val pos = ref start
      fun readVec n =
        let val k = Int.min (n, String.size content - !pos)
        in fromString (String.substring (content, !pos, k)) before pos := !pos + k end
    in
      BinPrimIO.RD {name = "memory", chunkSize = 4, readVec = SOME readVec, readArr = NONE,
                    readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                    avail = fn () => NONE,
                    getPos = SOME (fn () => Position.fromInt (!pos)),
                    setPos = SOME (fn p => pos := Position.toInt p),
                    endPos = SOME (fn () => Position.fromInt (String.size content)),
                    verifyPos = SOME (fn () => Position.fromInt (!pos)),
                    close = fn () => (), ioDesc = NONE}
    end
  (* memWriter (): a writer into a buffer of memory that writes at its
     position, which getPos and setPos read and move; the contents. *)
  fun memWriter () : BinPrimIO.writer * string ref =
    let
      val contents = ref ""
      val pos = ref 0
      fun writeVec sl =
        let
          val s = toString (Word8VectorSlice.vector sl)
          val c = !contents
          val before' = String.substring (c, 0, Int.min (!pos, String.size c))
          val pad = CharVector.tabulate (Int.max (0, !pos - String.size c), fn _ => #"\000")
          val after = if !pos + String.size s < String.size c then String.extract (c, !pos + String.size s, NONE) else ""
        in
          contents := before' ^ pad ^ s ^ after; pos := !pos + String.size s; String.size s
        end
    in
      (BinPrimIO.WR {name = "memory", chunkSize = 1000, writeVec = SOME writeVec,
                     writeArr = SOME (fn sl => writeVec (Word8VectorSlice.full (Word8ArraySlice.vector sl))),
                     writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                     getPos = SOME (fn () => Position.fromInt (!pos)),
                     setPos = SOME (fn p => pos := Position.toInt p),
                     endPos = SOME (fn () => Position.fromInt (String.size (!contents))),
                     verifyPos = SOME (fn () => Position.fromInt (!pos)),
                     close = fn () => (), ioDesc = NONE},
       contents)
    end
  fun input (f : S.instream) = let val (v, f') = S.input f in (toString v, f') end
  fun inputN (f : S.instream, n) = let val (v, f') = S.inputN (f, n) in (toString v, f') end
  fun output (s : S.outstream, str : string) = S.output (s, fromString str)
  val posInt = Position.toInt

  (* ==== filePosIn ==== *)
  (* "returns the primitive-level reader position that corresponds to the
     next element to be read from the buffered stream f" *)
  val () = eqIL ("BinIO.StreamIO.filePosIn/offsets", [0, 1, 3, 4, 7, 10, 10],
                 fn () => let
                            val f0 = S.mkInstream (memReader ("abcdefghij", 0), fromString "")
                            val (_, f1) = inputN (f0, 1)
                            val (_, f3) = inputN (f1, 2)
                            val (_, f4) = inputN (f3, 1)
                            val (_, f7) = inputN (f4, 3)
                            val (_, f10) = S.inputAll f7
                          in List.map (posInt o S.filePosIn) [f0, f1, f3, f4, f7, f10, f10] end)
  val () = eqIL ("BinIO.StreamIO.filePosIn/reader-not-at-the-start", [5, 6, 8],
                 fn () => let
                            val f5 = S.mkInstream (memReader ("abcdefghij", 5), fromString "")
                            val (_, f6) = inputN (f5, 1)
                            val (_, f8) = inputN (f6, 2)
                          in List.map (posInt o S.filePosIn) [f5, f6, f8] end)
  (* "It should be true that, if #1(inputAll f) returns vector v, then
     (setPos (filePosIn f); readVec (length v)) should also return v" *)
  val () = eqSL ("BinIO.StreamIO.filePosIn/setPos-then-readVec", ["efghij", "efghij"],
                 fn () => let
                            val rd = memReader ("abcdefghij", 0)
                            val f = #2 (inputN (S.mkInstream (rd, fromString ""), 4))
                            val v = toString (#1 (S.inputAll f))
                            val BinPrimIO.RD {setPos, readVec, ...} = rd
                          in
                            (valOf setPos) (S.filePosIn f);
                            [v, toString ((valOf readVec) (String.size v))]
                          end)
  (* "This raises the exception Io if the stream does not support the
     operation, or if f has been truncated." *)
  val () = T.raises ("BinIO.StreamIO.filePosIn/Io-truncated", isIo,
                     fn () => let val f = S.mkInstream (memReader ("abc", 0), fromString "") in ignore (S.getReader f); S.filePosIn f end)

  (* ==== getPosOut, setPosOut, filePosOut ==== *)
  (* getPosOut "returns the current position of the stream f"; filePosOut
     "returns the primitive-level writer position that corresponds to the
     abstract output stream position opos". *)
  val () = eqIL ("BinIO.StreamIO.filePosOut/offsets", [0, 3, 4, 4],
                 fn () => let
                            val (w, _) = memWriter ()
                            val s = S.mkOutstream (w, IO.BLOCK_BUF)
                            val p0 = S.getPosOut s
                            val () = output (s, "abc")
                            val p3 = S.getPosOut s
                            val () = S.output1 (s, charElem #"d")
                            val p4 = S.getPosOut s
                          in List.map (posInt o S.filePosOut) [p0, p3, p4, S.getPosOut s] end)
  (* getPosOut: "flushOut f; getPos ()" *)
  val () = eqS ("BinIO.StreamIO.getPosOut/flushes", "abc",
                fn () => let val (w, contents) = memWriter () val s = S.mkOutstream (w, IO.BLOCK_BUF)
                         in output (s, "abc"); ignore (S.getPosOut s); !contents end)
  (* setPosOut "flushes the output buffer of the stream underlying opos, sets
     the current position of the stream to the position recorded in opos,
     and returns the stream" *)
  val () = eqS ("BinIO.StreamIO.setPosOut/overwrites", "abXYef",
                fn () => let
                           val (w, contents) = memWriter ()
                           val s = S.mkOutstream (w, IO.BLOCK_BUF)
                           val () = output (s, "ab")
                           val p = S.getPosOut s
                           val () = output (s, "cdef")
                           val s' = S.setPosOut p
                           val () = output (s', "XY")
                         in S.flushOut s'; !contents end)
  val () = eqS ("BinIO.StreamIO.setPosOut/flushes", "abcd",
                fn () => let
                           val (w, contents) = memWriter ()
                           val s = S.mkOutstream (w, IO.BLOCK_BUF)
                           val p = S.getPosOut s
                           val () = output (s, "abcd")
                         in ignore (S.setPosOut p); !contents end)
  val () = eqS ("BinIO.StreamIO.setPosOut/returns-the-stream", "Xbc",
                fn () => let
                           val (w, contents) = memWriter ()
                           val s = S.mkOutstream (w, IO.NO_BUF)
                           val p = S.getPosOut s
                           val () = output (s, "abc")
                           val _ = S.setPosOut p
                         in output (s, "X"); !contents end)
  (* filePosOut: "(setPos opos; writeVec{buf=v,i=0,sz=NONE}) should have the
     same effect as the last line of the function fun put (outs,x) =
     (flushOut outs; output(outs,x);flushOut outs)" *)
  val () = eqSL ("BinIO.StreamIO.filePosOut/writes-go-there", ["abcXY", "abcXY"],
                 fn () => let
                            val (w1, c1) = memWriter ()
                            val s1 = S.mkOutstream (w1, IO.BLOCK_BUF)
                            val () = output (s1, "abc")
                            val opos = S.getPosOut s1
                            val () = (S.flushOut s1; output (s1, "XY"); S.flushOut s1)
                            val (w2, c2) = memWriter ()
                            val s2 = S.mkOutstream (w2, IO.BLOCK_BUF)
                            val () = output (s2, "abc")
                            val () = S.flushOut s2
                            val (BinPrimIO.WR {setPos, writeVec, ...}, _) = S.getWriter s2
                          in
                            (valOf setPos) (S.filePosOut opos);
                            ignore ((valOf writeVec) (Word8VectorSlice.full (fromString "XY")));
                            [!c1, !c2]
                          end)
  (* IMPERATIVE_IO: "setPosOut (strm, pos) sets the current position of the
     stream strm to be pos" *)
  val () = eqS ("BinIO.setPosOut/overwrites", "aXc",
                fn () => let
                           val (w, contents) = memWriter ()
                           val out = BinIO.mkOutstream (S.mkOutstream (w, IO.BLOCK_BUF))
                           val () = BinIO.output (out, fromString "a")
                           val p = BinIO.getPosOut out
                           val () = BinIO.output (out, fromString "bc")
                           val () = BinIO.setPosOut (out, p)
                           val () = BinIO.output (out, fromString "X")
                         in BinIO.flushOut out; !contents end)
  val () = eqI ("BinIO.getPosOut/offset", 2,
                fn () => let
                           val (w, _) = memWriter ()
                           val out = BinIO.mkOutstream (S.mkOutstream (w, IO.BLOCK_BUF))
                         in BinIO.output (out, fromString "ab"); posInt (S.filePosOut (BinIO.getPosOut out)) end)

  (* ==== files ==== *)
  val made : string list ref = ref []
  fun file (what : string) : string = let val name = "binio-streamio-" ^ what ^ ".bin" in made := name :: !made; name end
  fun write (name : string, s : string) : unit =
    let val out = BinIO.openOut name in BinIO.output (out, fromString s); BinIO.closeOut out end
  fun slurp (name : string) : string =
    let val ins = BinIO.openIn name val v = BinIO.inputAll ins in BinIO.closeIn ins; toString v end

  (* io.html: "By default, output should be buffered." *)
  val () = eqB ("BinIO.StreamIO.getBufferMode/openOut-is-buffered", true,
                fn () => let val out = BinIO.openOut (file "mode")
                         in S.getBufferMode (BinIO.getOutstream out) <> IO.NO_BUF before BinIO.closeOut out end)
  val () = eqSL ("BinIO.StreamIO.setBufferMode/NO_BUF-file", ["abc", "abcd"],
                 fn () => let
                            val name = file "nobuf"
                            val out = BinIO.openOut name
                            val () = S.setBufferMode (BinIO.getOutstream out, IO.NO_BUF)
                            val () = BinIO.output (out, fromString "abc")
                            val a = slurp name
                            val () = BinIO.output1 (out, charElem #"d")
                            val b = slurp name
                          in BinIO.closeOut out; [a, b] end)
  val () = eqS ("BinIO.StreamIO.flushOut/file", "abc",
                fn () => let
                           val name = file "flush"
                           val s = BinIO.getOutstream (BinIO.openOut name)
                           val () = output (s, "abc")
                           val () = S.flushOut s
                         in slurp name before S.closeOut s end)
  val () = eqSL ("BinIO.StreamIO.getWriter/file", ["ab", "abcd"],
                 fn () => let
                            val name = file "writer"
                            val s = BinIO.getOutstream (BinIO.openOut name)
                            val () = output (s, "ab")
                            val (w, _) = S.getWriter s
                            val a = slurp name
                            val BinPrimIO.WR {writeVec, close, ...} = w
                            val () = case writeVec of SOME f => ignore (f (Word8VectorSlice.full (fromString "cd"))) | NONE => ()
                          in [a, slurp name] before close () end)
  val () = eqSL ("BinIO.StreamIO.getReader/file", ["", "hello\n"],
                 fn () => let
                            val name = file "reader"
                            val () = write (name, "hello\n")
                            val (rd, v) = S.getReader (BinIO.getInstream (BinIO.openIn name))
                            val BinPrimIO.RD {readVec, close, ...} = rd
                            fun all acc = case toString ((valOf readVec) 100) of "" => acc | s => all (acc ^ s)
                          in [toString v, all ""] before close () end)

  (*<< positions *)
  (* Positions in files are byte offsets. *)
  val () = eqIL ("BinIO.StreamIO.filePosIn/file-offsets", [0, 3, 11],
                 fn () => let
                            val name = file "pos"
                            val () = write (name, "hello world")
                            val f0 = BinIO.getInstream (BinIO.openIn name)
                            val (_, f3) = inputN (f0, 3)
                            val (_, f11) = S.inputAll f3
                          in List.map (posInt o S.filePosIn) [f0, f3, f11] before S.closeIn f0 end)
  val () = eqIL ("BinIO.StreamIO.getPosOut/file-offsets", [0, 3, 5],
                 fn () => let
                            val s = BinIO.getOutstream (BinIO.openOut (file "posout"))
                            val p0 = S.getPosOut s
                            val () = output (s, "abc")
                            val p3 = S.getPosOut s
                            val () = output (s, "de")
                          in List.map (posInt o S.filePosOut) [p0, p3, S.getPosOut s] before S.closeOut s end)
  val () = eqS ("BinIO.StreamIO.setPosOut/file-overwrites", "abXYef",
                fn () => let
                           val name = file "setpos"
                           val s = BinIO.getOutstream (BinIO.openOut name)
                           val () = output (s, "ab")
                           val p = S.getPosOut s
                           val () = output (s, "cdef")
                           val s' = S.setPosOut p
                           val () = output (s', "XY")
                         in S.closeOut s'; slurp name end)
  val () = eqS ("BinIO.setPosOut/file-overwrites", "abXd",
                fn () => let
                           val name = file "setpos2"
                           val out = BinIO.openOut name
                           val () = BinIO.output (out, fromString "ab")
                           val p = BinIO.getPosOut out
                           val () = BinIO.output (out, fromString "cd")
                           val () = BinIO.setPosOut (out, p)
                           val () = BinIO.output (out, fromString "X")
                         in BinIO.closeOut out; slurp name end)
  (*>> positions *)

  val () = List.app (fn name => OS.FileSys.remove name handle _ => ()) (!made)
end
