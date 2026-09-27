(* requires: IntVector IntVectorSlice IntArray IntArraySlice *)
(* uses: spec-sigs/PRIM_IO.sml spec-sigs/STREAM_IO.sml spec-sigs/IMPERATIVE_IO.sml fn/io_script.sml fn/prim_io_fn.sml fn/stream_io_fn.sml fn/imperative_io_fn.sml *)
(* The optional functors PrimIO, StreamIO and ImperativeIO, applied to
   integers: a reader over a vector, streams over it, and imperative streams
   over those, and a writer that collects what it is given. After
   https://smlfamily.github.io/Basis/prim-io-fn.html, stream-io-fn.html and
   imperative-io-fn.html; StreamIO takes VectorSlice and ArraySlice as well,
   as MLton's does (the specification's arguments give no way to make the
   vector slices a writer takes). Each application is a section: a host's
   functors may take other arguments. The last section runs the checks that
   hold for every PRIM_IO, STREAM_IO and IMPERATIVE_IO structure
   (fn/prim_io_fn.sml, fn/stream_io_fn.sml, fn/imperative_io_fn.sml) on the
   three results, whose elements stand for the characters of the same
   code. *)
structure TestIOFunctors =
struct
  val eqL = T.eq (T.list T.int)
  val eqB = T.eq T.bool
  fun ints v = IntVector.foldr (op ::) [] v
  val v = IntVector.fromList [3, 1, 4, 1, 5, 9, 2, 6]

  (*<< primio *)
  structure P = PrimIO (structure Vector = IntVector
                        structure VectorSlice = IntVectorSlice
                        structure Array = IntArray
                        structure ArraySlice = IntArraySlice
                        val someElem = 0
                        type pos = int
                        val compare = Int.compare)
  (* "openVector v: creates a reader whose content is v" *)
  val () = eqL ("PrimIO/openVector-reads-the-vector", [3, 1, 4, 1, 5, 9, 2, 6],
                fn () => let val P.RD {readVec, ...} = P.openVector v
                         in case readVec of SOME f => ints (f 100) | NONE => [] end)
  val () = eqL ("PrimIO/nullRd-is-empty", [],
                fn () => let val P.RD {readVec, ...} = P.nullRd ()
                         in case readVec of SOME f => ints (f 10) | NONE => [~1] end)
  val () = eqB ("PrimIO/compare-is-the-argument", true, fn () => P.compare (1, 2) = LESS)
  (*>> primio *)

  (*<< streamio *)
  structure S = StreamIO (structure PrimIO = P
                          structure Vector = IntVector
                          structure VectorSlice = IntVectorSlice
                          structure Array = IntArray
                          structure ArraySlice = IntArraySlice
                          val someElem = 0)
  fun fresh () = S.mkInstream (P.openVector v, IntVector.fromList [])

  (* filePosIn on a stream of this functor: the positions of a PrimIO given
     here are of any type, so nothing can count in them. The stream puts the
     reader back to the start of the chunk it buffered, reads the elements
     again and asks the reader where it is; a reader without readVec, getPos
     and setPos raises Io, which the page allows. *)
  fun counting () =
    let
      val at = ref 0
      fun readVec n =
        let val take = Int.min (n, IntVector.length v - !at)
            val got = IntVectorSlice.vector (IntVectorSlice.slice (v, !at, SOME take))
        in at := !at + take; got end
    in
      P.RD {name = "counting", chunkSize = 4, readVec = SOME readVec, readArr = NONE,
            readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
            avail = fn () => SOME (IntVector.length v - !at),
            getPos = SOME (fn () => !at), setPos = SOME (fn p => at := p),
            endPos = SOME (fn () => IntVector.length v),
            verifyPos = SOME (fn () => !at), close = fn () => (), ioDesc = NONE}
    end
  val () = T.eq T.int ("StreamIO/filePosIn-at-the-start", 0,
                       fn () => S.filePosIn (S.mkInstream (counting (), IntVector.fromList [])))
  val () = T.eq T.int ("StreamIO/filePosIn-inside-a-chunk", 3,
                       fn () => let val s = S.mkInstream (counting (), IntVector.fromList [])
                                    val (_, s') = S.inputN (s, 3)
                                in S.filePosIn s' end)
  val () = T.eq T.int ("StreamIO/filePosIn-past-a-chunk", 6,
                       fn () => let val s = S.mkInstream (counting (), IntVector.fromList [])
                                    val (_, s') = S.inputN (s, 6)
                                in S.filePosIn s' end)
  val () = T.check ("StreamIO/filePosIn-without-positions",
                    fn () => let val s = S.mkInstream (P.openVector v, IntVector.fromList [])
                                 val (_, s') = S.inputN (s, 3)
                             in (ignore (S.filePosIn s'); false)
                                handle IO.Io {cause = IO.RandomAccessNotSupported, ...} => true
                             end)
  val () = eqL ("StreamIO/inputAll", [3, 1, 4, 1, 5, 9, 2, 6], fn () => ints (#1 (S.inputAll (fresh ()))))
  val () = eqL ("StreamIO/inputN-then-input1", [3, 1, 4],
                fn () => let val (a, s) = S.inputN (fresh (), 2)
                         in case S.input1 s of SOME (x, _) => ints a @ [x] | NONE => [] end)
  val () = eqB ("StreamIO/endOfStream-at-the-end", true,
                fn () => S.endOfStream (#2 (S.inputAll (fresh ()))))
  (* a writer that collects the vectors it is given, augmented: Poly/ML's
     StreamIO writes a block buffer with writeArr, and the specification
     leaves open whether mkOutstream augments its writer *)
  fun collector () =
    let
      val got = ref []
      fun writeVec sl = (got := IntVectorSlice.vector sl :: !got; IntVectorSlice.length sl)
    in
      (P.augmentWriter (P.WR {name = "collector", chunkSize = 4, writeVec = SOME writeVec, writeArr = NONE,
             writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
             getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
             close = fn () => (), ioDesc = NONE}),
       fn () => List.concat (List.map ints (List.rev (!got))))
    end
  val () = eqL ("StreamIO/output-then-flushOut", [2, 7, 1, 8],
                fn () => let val (w, got) = collector ()
                             val out = S.mkOutstream (w, IO.BLOCK_BUF)
                         in S.output (out, IntVector.fromList [2, 7]); S.output1 (out, 1);
                            S.output1 (out, 8); S.flushOut out; got () end)
  (*>> streamio *)

  (*<< imperativeio *)
  structure I = ImperativeIO (structure StreamIO = S
                              structure Vector = IntVector
                              structure Array = IntArray)
  val () = eqL ("ImperativeIO/input1-then-inputAll", [3, 1, 4, 1, 5, 9, 2, 6],
                fn () => let val ins = I.mkInstream (fresh ())
                         in case I.input1 ins of
                              SOME x => x :: ints (I.inputAll ins)
                            | NONE => [] end)
  val () = eqL ("ImperativeIO/output-then-closeOut", [1, 6, 1, 8],
                fn () => let val (w, got) = collector ()
                             val out = I.mkOutstream (S.mkOutstream (w, IO.NO_BUF))
                         in I.output (out, IntVector.fromList [1, 6]); I.output1 (out, 1);
                            I.output1 (out, 8); I.closeOut out; got () end)
  (*>> imperativeio *)

  (*<< generic *)
  fun ofString str = IntVector.fromList (List.map Char.ord (String.explode str))
  fun toText v = String.implode (List.map Char.chr (ints v))
  structure GenericPrim = TestPrimIOFn (structure P = P val name = "PrimIO"
                                        val fromString = ofString val toString = toText
                                        val sliceVector = IntVectorSlice.vector val vectorSlice = IntVectorSlice.slice
                                        val newArray = fn str => IntArray.fromList (List.map Char.ord (String.explode str))
                                        val arrayString = fn a => toText (IntArray.vector a)
                                        val arraySlice = IntArraySlice.slice val arraySliceLength = IntArraySlice.length
                                        val arraySliceVector = IntArraySlice.vector
                                        val copyIntoSlice = fn (w, sl) => let val (a, i, _) = IntArraySlice.base sl
                                                                          in IntArray.copyVec {src = w, dst = a, di = i} end)
  (* The readers and writers of P, for fn/io_script.sml. *)
  structure IntRW : IO_RW =
  struct
    type vector = IntVector.vector
    type vector_slice = IntVectorSlice.slice
    type reader = P.reader
    type writer = P.writer
    val fromString = ofString
    val toString = toText
    val sliceVector = IntVectorSlice.vector
    val fullSlice = IntVectorSlice.full
    fun mkReader {name, chunkSize, readVec, readVecNB, close} =
      P.RD {name = name, chunkSize = chunkSize, readVec = SOME readVec, readArr = NONE,
            readVecNB = readVecNB, readArrNB = NONE, block = NONE, canInput = NONE,
            avail = fn () => NONE, getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
            close = close, ioDesc = NONE}
    fun mkWriter {name, chunkSize, writeVec, close} =
      P.WR {name = name, chunkSize = chunkSize, writeVec = SOME writeVec,
            writeArr = SOME (fn sl => writeVec (IntVectorSlice.full (IntArraySlice.vector sl))),
            writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
            getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
            close = close, ioDesc = NONE}
    fun readerName (P.RD {name, ...}) = name
    fun readerReadVec (P.RD {readVec, ...}) = readVec
    fun readerClose (P.RD {close, ...}) = close ()
    fun writerName (P.WR {name, ...}) = name
    fun writerWriteVec (P.WR {writeVec, ...}) = writeVec
    fun writerClose (P.WR {close, ...}) = close ()
  end
  structure GenericStream = TestStreamIOFn (structure RW = IntRW structure S = S val name = "StreamIO"
                                            val elemChar = Char.chr val charElem = Char.ord val text = false)
  structure GenericImperative = TestImperativeIOFn (structure RW = IntRW structure I = I val name = "ImperativeIO"
                                                    val elemChar = Char.chr val charElem = Char.ord)
  (*>> generic *)
end
