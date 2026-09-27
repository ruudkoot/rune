(* requires: WideTextIO WideTextPrimIO WideString WideChar WideCharVector WideCharVectorSlice WideCharArray WideCharArraySlice IO *)
(* uses: spec-sigs/STREAM_IO.sml spec-sigs/IMPERATIVE_IO.sml spec-sigs/PRIM_IO.sml fn/io_script.sml fn/stream_io_fn.sml fn/imperative_io_fn.sml fn/prim_io_fn.sml *)
(* WideTextIO.StreamIO, WideTextIO and WideTextPrimIO (optional in the
   specification): the checks that hold for every STREAM_IO, IMPERATIVE_IO
   and PRIM_IO structure, from fn/stream_io_fn.sml, fn/imperative_io_fn.sml
   and fn/prim_io_fn.sml, run over readers and writers of wide characters as
   textio_streamio.sml and io_primio.sml run them over those of TextPrimIO.
   The texts of the checks are ASCII; each character is the wide character of
   the same code. What files of wide characters hold is widetextio.sml's. *)
structure TestWideTextIOStreamIO =
struct
  fun widen s = WideString.implode (List.map (fn c => WideChar.chr (Char.ord c)) (String.explode s))
  fun narrow w = String.implode (List.map (fn c => Char.chr (WideChar.ord c)) (WideString.explode w))

  (* The readers and writers of WideTextPrimIO, for fn/io_script.sml. *)
  structure WideRW : IO_RW =
  struct
    type vector = WideString.string
    type vector_slice = WideCharVectorSlice.slice
    type reader = WideTextPrimIO.reader
    type writer = WideTextPrimIO.writer
    val fromString = widen
    val toString = narrow
    val sliceVector = WideCharVectorSlice.vector
    val fullSlice = WideCharVectorSlice.full
    fun mkReader {name, chunkSize, readVec, readVecNB, close} =
      WideTextPrimIO.RD {name = name, chunkSize = chunkSize, readVec = SOME readVec, readArr = NONE,
                         readVecNB = readVecNB, readArrNB = NONE, block = NONE, canInput = NONE,
                         avail = fn () => NONE, getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                         close = close, ioDesc = NONE}
    fun mkWriter {name, chunkSize, writeVec, close} =
      WideTextPrimIO.WR {name = name, chunkSize = chunkSize, writeVec = SOME writeVec,
                         writeArr = SOME (fn sl => writeVec (WideCharVectorSlice.full (WideCharArraySlice.vector sl))),
                         writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                         getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                         close = close, ioDesc = NONE}
    fun readerName (WideTextPrimIO.RD {name, ...}) = name
    fun readerReadVec (WideTextPrimIO.RD {readVec, ...}) = readVec
    fun readerClose (WideTextPrimIO.RD {close, ...}) = close ()
    fun writerName (WideTextPrimIO.WR {name, ...}) = name
    fun writerWriteVec (WideTextPrimIO.WR {writeVec, ...}) = writeVec
    fun writerClose (WideTextPrimIO.WR {close, ...}) = close ()
  end
  fun elemChar c = Char.chr (WideChar.ord c)
  fun charElem c = WideChar.chr (Char.ord c)
  structure Generic = TestStreamIOFn (structure RW = WideRW structure S = WideTextIO.StreamIO val name = "WideTextIO.StreamIO"
                                      val elemChar = elemChar val charElem = charElem val text = true)
  structure Imperative = TestImperativeIOFn (structure RW = WideRW structure I = WideTextIO val name = "WideTextIO"
                                             val elemChar = elemChar val charElem = charElem)
  structure Prim = TestPrimIOFn (structure P = WideTextPrimIO val name = "WideTextPrimIO"
                                 val fromString = widen val toString = narrow
                                 val sliceVector = WideCharVectorSlice.vector val vectorSlice = WideCharVectorSlice.slice
                                 val newArray = fn s => WideCharArray.fromList (WideString.explode (widen s))
                                 val arrayString = fn a => narrow (WideCharArray.vector a)
                                 val arraySlice = WideCharArraySlice.slice val arraySliceLength = WideCharArraySlice.length
                                 val arraySliceVector = WideCharArraySlice.vector
                                 val copyIntoSlice = fn (v, sl) => let val (a, i, _) = WideCharArraySlice.base sl
                                                                   in WideCharArray.copyVec {src = v, dst = a, di = i} end)
end
