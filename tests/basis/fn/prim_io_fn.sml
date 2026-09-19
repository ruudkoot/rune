(* Checks of a structure with signature PRIM_IO, for text and binary
   elements. Expected values follow
   https://smlfamily.github.io/Basis/prim-io.html.

     structure Generic = TestPrimIOFn (structure P = TextPrimIO val name = "TextPrimIO" val fromString = ... val toString = ... val sliceVector = ... val vectorSlice = ... val newArray = ... val arrayString = ... val arraySlice = ... val arraySliceLength = ... val arraySliceVector = ... val copyIntoSlice = ...)

   needs spec-sigs/PRIM_IO.sml. The labels are name ^ ".member/case".
   Elements are written as characters: fromString and toString convert
   between strings and vectors, newArray and arrayString between strings and
   arrays. The slices are those of the instance (VectorSlice.slice and
   ArraySlice.slice): vectorSlice and arraySlice make one, sliceVector,
   arraySliceLength and arraySliceVector read one, and copyIntoSlice (v, sl)
   writes v at the start of sl.

   The readers and writers built here offer a chosen set of operations, so
   that the checks of augmentReader and augmentWriter can see which ones the
   result uses: every operation records a letter in a log. compare has checks
   in the tests of the instances, which have positions to compare. *)
functor TestPrimIOFn (structure P : SPEC_PRIM_IO
                      val name : string
                      val fromString : string -> P.vector
                      val toString : P.vector -> string
                      val sliceVector : P.vector_slice -> P.vector
                      val vectorSlice : P.vector * int * int option -> P.vector_slice
                      val newArray : string -> P.array
                      val arrayString : P.array -> string
                      val arraySlice : P.array * int * int option -> P.array_slice
                      val arraySliceLength : P.array_slice -> int
                      val arraySliceVector : P.array_slice -> P.vector
                      val copyIntoSlice : P.vector * P.array_slice -> unit) =
struct
  fun lab s = name ^ "." ^ s

  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val eqSL = T.eq (T.list T.string)
  val eqIO = T.eq (T.option T.int)

  (* "A reader is required to raise IO.Io if any of its functions, except
     close or getPos, is invoked after a call to close. A writer is required
     to raise IO.Io if any of its functions, except close, is invoked after a
     call to close. In both cases, the cause field of the exception should be
     IO.ClosedStream." The descriptions of close say instead that further
     operations "raise IO.ClosedStream", which io.html says the primitive
     I/O modules never raise bare; the checks accept both. *)
  fun isClosedIo (IO.Io {cause = IO.ClosedStream, ...}) = true
    | isClosedIo IO.ClosedStream = true
    | isClosedIo _ = false

  (* ---- using a reader ---- *)
  fun readVec (P.RD {readVec = SOME f, ...}, n) = toString (f n)
    | readVec (P.RD {readVec = NONE, ...}, _) = "<none>"
  (* readArr (rd, init, i, n): readArr on the slice (i, n) of an array that
     holds init; the count, and what the array holds afterwards. *)
  fun readArr (P.RD {readArr = SOME f, ...}, init, i, n) =
        let val a = newArray init val k = f (arraySlice (a, i, SOME n)) in Int.toString k ^ ":" ^ arrayString a end
    | readArr (P.RD {readArr = NONE, ...}, _, _, _) = "<none>"
  fun readVecNB (P.RD {readVecNB = SOME f, ...}, n) =
        (case f n of SOME v => "SOME " ^ toString v | NONE => "NONE")
    | readVecNB (P.RD {readVecNB = NONE, ...}, _) = "<none>"
  fun readArrNB (P.RD {readArrNB = SOME f, ...}, init, i, n) =
        let val a = newArray init
        in case f (arraySlice (a, i, SOME n)) of
             SOME k => "SOME " ^ Int.toString k ^ ":" ^ arrayString a
           | NONE => "NONE"
        end
    | readArrNB (P.RD {readArrNB = NONE, ...}, _, _, _) = "<none>"
  (* readAll rd: what repeated readVec 3 returns up to an empty vector. *)
  fun readAll rd =
    let
      fun go (k, acc) =
        if k = 0 then "<no end>"
        else case readVec (rd, 3) of "" => String.concat (List.rev acc) | s => go (k - 1, s :: acc)
    in go (1000, []) end
  fun closeRd (P.RD {close, ...}) = close ()
  fun chunkSizeRd (P.RD {chunkSize, ...}) = chunkSize
  fun nameRd (P.RD {name, ...}) = name
  fun availRd (P.RD {avail, ...}) = avail ()

  (* ---- using a writer ---- *)
  fun writeVec (P.WR {writeVec = SOME f, ...}, s, i, n) = Int.toString (f (vectorSlice (fromString s, i, SOME n)))
    | writeVec (P.WR {writeVec = NONE, ...}, _, _, _) = "<none>"
  fun writeArr (P.WR {writeArr = SOME f, ...}, s, i, n) = Int.toString (f (arraySlice (newArray s, i, SOME n)))
    | writeArr (P.WR {writeArr = NONE, ...}, _, _, _) = "<none>"
  fun writeVecNB (P.WR {writeVecNB = SOME f, ...}, s, i, n) =
        (case f (vectorSlice (fromString s, i, SOME n)) of SOME k => "SOME " ^ Int.toString k | NONE => "NONE")
    | writeVecNB (P.WR {writeVecNB = NONE, ...}, _, _, _) = "<none>"
  fun writeArrNB (P.WR {writeArrNB = SOME f, ...}, s, i, n) =
        (case f (arraySlice (newArray s, i, SOME n)) of SOME k => "SOME " ^ Int.toString k | NONE => "NONE")
    | writeArrNB (P.WR {writeArrNB = NONE, ...}, _, _, _) = "<none>"
  fun closeWr (P.WR {close, ...}) = close ()
  fun chunkSizeWr (P.WR {chunkSize, ...}) = chunkSize
  fun nameWr (P.WR {name, ...}) = name

  (* ---- a source and a sink of one's own ----
     A reader of `content` or a writer that keeps what it receives, with the
     operations that `ops` asks for. Each operation records its letter in the
     log: V, A, v, a for the vector, array, vector NB and array NB
     operations, b for block, c for canInput or canOutput. While !ready is
     false the non-blocking operations answer NONE and canInput/canOutput
     false; block sets it. *)
  type ops = {vec : bool, arr : bool, vecNB : bool, arrNB : bool, block : bool, can : bool}
  val no : ops = {vec = false, arr = false, vecNB = false, arrNB = false, block = false, can = false}
  fun opt (b, f) = if b then SOME f else NONE

  fun source (ops : ops, content : string) : P.reader * string ref * bool ref =
    let
      val log = ref ""
      val pos = ref 0
      val ready = ref true
      fun note s = log := !log ^ s
      fun take n =
        let val k = Int.min (n, String.size content - !pos)
        in String.substring (content, !pos, k) before pos := !pos + k end
      fun intoSlice sl = let val v = fromString (take (arraySliceLength sl)) in copyIntoSlice (v, sl); String.size (toString v) end
    in
      (P.RD {name = "source", chunkSize = 7,
             readVec = opt (#vec ops, fn n => (note "V"; fromString (take n))),
             readArr = opt (#arr ops, fn sl => (note "A"; intoSlice sl)),
             readVecNB = opt (#vecNB ops, fn n => (note "v"; if !ready then SOME (fromString (take n)) else NONE)),
             readArrNB = opt (#arrNB ops, fn sl => (note "a"; if !ready then SOME (intoSlice sl) else NONE)),
             block = opt (#block ops, fn () => (note "b"; ready := true)),
             canInput = opt (#can ops, fn () => (note "c"; !ready)),
             avail = fn () => SOME (String.size content - !pos),
             getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
             close = fn () => note "C", ioDesc = NONE},
       log, ready)
    end

  fun sink (ops : ops) : P.writer * string ref * string ref * bool ref =
    let
      val log = ref ""
      val got = ref ""
      val ready = ref true
      fun note s = log := !log ^ s
      fun keep v = let val s = toString v in got := !got ^ s; String.size s end
    in
      (P.WR {name = "sink", chunkSize = 5,
             writeVec = opt (#vec ops, fn sl => (note "V"; keep (sliceVector sl))),
             writeArr = opt (#arr ops, fn sl => (note "A"; keep (arraySliceVector sl))),
             writeVecNB = opt (#vecNB ops, fn sl => (note "v"; if !ready then SOME (keep (sliceVector sl)) else NONE)),
             writeArrNB = opt (#arrNB ops, fn sl => (note "a"; if !ready then SOME (keep (arraySliceVector sl)) else NONE)),
             block = opt (#block ops, fn () => (note "b"; ready := true)),
             canOutput = opt (#can ops, fn () => (note "c"; !ready)),
             getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
             close = fn () => note "C", ioDesc = NONE},
       got, log, ready)
    end

  (* ==== RD, WR ==== *)
  val () = eqSL (lab "RD/fields", ["n", "3", "abc", "SOME 2"],
                 fn () => let
                            val (P.RD r, _, _) = source ({vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = false}, "abcde")
                            val rd = P.RD {name = "n", chunkSize = 3, readVec = #readVec r, readArr = NONE, readVecNB = NONE,
                                           readArrNB = NONE, block = NONE, canInput = NONE, avail = #avail r, getPos = NONE,
                                           setPos = NONE, endPos = NONE, verifyPos = NONE, close = #close r, ioDesc = NONE}
                            val P.RD {name = n, chunkSize = c, avail, ...} = rd
                          in [n, Int.toString c, readVec (rd, 3), T.option T.int (avail ())] end)
  val () = eqSL (lab "WR/fields", ["n", "4", "2", "bc"],
                 fn () => let
                            val (P.WR w, got, _, _) = sink {vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = false}
                            val wr = P.WR {name = "n", chunkSize = 4, writeVec = #writeVec w, writeArr = NONE, writeVecNB = NONE,
                                           writeArrNB = NONE, block = NONE, canOutput = NONE, getPos = NONE, setPos = NONE,
                                           endPos = NONE, verifyPos = NONE, close = #close w, ioDesc = NONE}
                            val P.WR {name = n, chunkSize = c, ...} = wr
                            val k = writeVec (wr, "abcd", 1, 2)
                          in [n, Int.toString c, k, !got] end)

  (* ==== openVector ==== *)
  (* "creates a reader whose content is v"; readVec n "reads upto n elements
     [...] returns the empty vector if end-of-stream is detected (or if n is
     0)". The operations are those of augmentReader (openVector v), which
     "provides the same implementation" of those the reader has. *)
  fun vecReader s = P.augmentReader (P.openVector (fromString s))
  val () = eqS (lab "openVector/content", "hello, world", fn () => readAll (vecReader "hello, world"))
  val () = eqSL (lab "openVector/readVec-pieces", ["ab", "cd", "e", "", ""],
                 fn () => let val rd = vecReader "abcde" in List.map (fn n => readVec (rd, n)) [2, 2, 2, 2, 2] end)
  val () = eqSL (lab "openVector/readVec-zero", ["", "abc"],
                 fn () => let val rd = vecReader "abc" val a = readVec (rd, 0) in [a, readVec (rd, 10)] end)
  val () = eqS (lab "openVector/empty", "", fn () => readVec (vecReader "", 5))
  val () = eqSL (lab "openVector/readArr", ["3:?abc?", "2:de???", "0:?????"],
                 fn () => let val rd = vecReader "abcde"
                              val a = readArr (rd, "?????", 1, 3)
                              val b = readArr (rd, "?????", 0, 5)
                          in [a, b, readArr (rd, "?????", 2, 3)] end)
  val () = eqS (lab "openVector/readArr-empty-slice", "0:??", fn () => readArr (vecReader "abc", "??", 1, 0))
  (* "chunkSize <= 0 is illegal" *)
  val () = eqB (lab "openVector/chunkSize-positive", true,
                fn () => chunkSizeRd (P.openVector (fromString "")) >= 1 andalso chunkSizeRd (P.openVector (fromString "abc")) >= 1)
  (* avail "returns the number of bytes available on the ``device,'' or
     NONE if it cannot be determined. For files or strings, this is the file
     or string size minus the current position" *)
  val () = eqB (lab "openVector/avail", true,
                fn () => let
                           val rd = vecReader "abcde"
                           fun ok k = case availRd rd of NONE => true | SOME n => n = k
                           val a = ok 5
                           val _ = readVec (rd, 2)
                           val b = ok 3
                           val _ = readVec (rd, 10)
                         in a andalso b andalso ok 0 end)
  (* readVecNB "reads i elements without blocking for 1 <= i <= n [...] or if
     end-of-stream is detected without blocking, returns SOME(fromList[])";
     a vector is always there, so the augmented reader has it. *)
  val () = eqSL (lab "openVector/readVecNB", ["SOME ab", "SOME c", "SOME "],
                 fn () => let val rd = vecReader "abc" val a = readVecNB (rd, 2) val b = readVecNB (rd, 2)
                          in [a, b, readVecNB (rd, 2)] end)
  (* "A reader is required to raise IO.Io if any of its functions, except
     close or getPos, is invoked after a call to close. [...] the cause field
     of the exception should be IO.ClosedStream." *)
  val () = T.raises (lab "openVector/readVec-after-close", isClosedIo,
                     fn () => let val rd = P.openVector (fromString "abc")
                              in closeRd rd; case rd of P.RD {readVec = SOME f, ...} => f 1 | _ => raise Fail "no readVec" end)
  val () = T.raises (lab "openVector/readArr-after-close", isClosedIo,
                     fn () => let val rd = vecReader "abc"
                              in closeRd rd; readArr (rd, "???", 0, 3) end)
  val () = T.raises (lab "openVector/avail-after-close", isClosedIo,
                     fn () => let val rd = P.openVector (fromString "abc") in closeRd rd; availRd rd end)
  val () = eqB (lab "openVector/close-twice", true,
                fn () => let val rd = P.openVector (fromString "abc") in closeRd rd; closeRd rd; true end)

  (* ==== nullRd, nullWr ==== *)
  (* "The reader nullRd acts like a reader that is always at end-of-stream.
     The writer nullWr serves as a sink; any data written using it is thrown
     away. Null readers and writers can be closed; if closed, they are
     expected to behave the same as any other closed reader or writer." *)
  val () = eqSL (lab "nullRd/always-at-end-of-stream", ["", "", ""],
                 fn () => let val rd = P.augmentReader (P.nullRd ()) in [readVec (rd, 5), readVec (rd, 1), readVec (rd, 100)] end)
  val () = eqS (lab "nullRd/readArr", "0:???", fn () => readArr (P.augmentReader (P.nullRd ()), "???", 0, 3))
  val () = eqS (lab "nullRd/readVecNB", "SOME ", fn () => readVecNB (P.augmentReader (P.nullRd ()), 4))
  val () = eqB (lab "nullRd/chunkSize-positive", true, fn () => chunkSizeRd (P.nullRd ()) >= 1)
  val () = T.raises (lab "nullRd/readVec-after-close", isClosedIo,
                     fn () => let val rd = P.nullRd () in closeRd rd; case rd of P.RD {readVec = SOME f, ...} => f 1 | _ => raise Fail "no readVec" end)
  val () = eqB (lab "nullRd/close-twice", true, fn () => let val rd = P.nullRd () in closeRd rd; closeRd rd; true end)
  val () = eqB (lab "nullRd/independent", true,
                fn () => let val a = P.nullRd () val b = P.augmentReader (P.nullRd ()) in closeRd a; readVec (b, 1) = "" end)

  val () = eqSL (lab "nullWr/takes-everything", ["3", "4"],
                 fn () => let val wr = P.augmentWriter (P.nullWr ()) in [writeVec (wr, "abcde", 1, 3), writeArr (wr, "abcd", 0, 4)] end)
  val () = eqS (lab "nullWr/writeVecNB", "SOME 2", fn () => writeVecNB (P.augmentWriter (P.nullWr ()), "abc", 1, 2))
  val () = eqB (lab "nullWr/chunkSize-positive", true, fn () => chunkSizeWr (P.nullWr ()) >= 1)
  (* "A writer is required to raise IO.Io if any of its functions, except
     close, is invoked after a call to close." *)
  val () = T.raises (lab "nullWr/writeVec-after-close", isClosedIo,
                     fn () => let val wr = P.nullWr ()
                              in closeWr wr; case wr of P.WR {writeVec = SOME f, ...} => f (vectorSlice (fromString "ab", 0, NONE)) | _ => raise Fail "no writeVec" end)
  val () = eqB (lab "nullWr/close-twice", true, fn () => let val wr = P.nullWr () in closeWr wr; closeWr wr; true end)

  (* ==== augmentReader ==== *)
  (* "if a reader rd supplies some operation (such as readArr), then
     augmentReader(rd) provides the same implementation of that operation,
     not a synthesized one" *)
  val all = {vec = true, arr = true, vecNB = true, arrNB = true, block = true, can = true}
  val () = eqSL (lab "augmentReader/keeps-what-the-reader-has", ["ab", "2:cd???", "SOME e", "SOME 1:f????", "VAva"],
                 fn () => let
                            val (rd, log, _) = source (all, "abcdef")
                            val rd' = P.augmentReader rd
                            val a = readVec (rd', 2)
                            val b = readArr (rd', "?????", 0, 2)
                            val c = readVecNB (rd', 1)
                            val d = readArrNB (rd', "?????", 0, 1)
                          in [a, b, c, d, !log] end)
  val () = eqSL (lab "augmentReader/keeps-the-other-fields", ["source", "7", "SOME 4", "C"],
                 fn () => let
                            val (rd, log, _) = source ({vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = false}, "abcd")
                            val rd' = P.augmentReader rd
                          in closeRd rd'; [nameRd rd', Int.toString (chunkSizeRd rd'), T.option T.int (availRd rd'), !log] end)
  (* The table: readVec from "readVec or readArr or (block and (readVecNB or
     readArrNB))". *)
  val () = eqSL (lab "augmentReader/readVec-from-readArr", ["abcd", "e", ""],
                 fn () => let val (rd, _, _) = source ({vec = false, arr = true, vecNB = false, arrNB = false, block = false, can = false}, "abcde")
                              val rd' = P.augmentReader rd
                              val a = readVec (rd', 4)
                              val b = readVec (rd', 4)
                          in [a, b, readVec (rd', 4)] end)
  val () = eqS (lab "augmentReader/readVec-from-block-and-readVecNB", "abc",
                fn () => let val (rd, _, ready) = source ({vec = false, arr = false, vecNB = true, arrNB = false, block = true, can = false}, "abcde")
                         in ready := false; readVec (P.augmentReader rd, 3) end)
  val () = eqS (lab "augmentReader/readVec-from-block-and-readArrNB", "abc",
                fn () => let val (rd, _, ready) = source ({vec = false, arr = false, vecNB = false, arrNB = true, block = true, can = false}, "abcde")
                         in ready := false; readVec (P.augmentReader rd, 3) end)
  (* readArr from "readArr or readVec or (block and (readArrNB or
     readVecNB))". *)
  val () = eqSL (lab "augmentReader/readArr-from-readVec", ["3:?abc?", "2:de???", "0:?????"],
                 fn () => let val (rd, _, _) = source ({vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = false}, "abcde")
                              val rd' = P.augmentReader rd
                              val a = readArr (rd', "?????", 1, 3)
                              val b = readArr (rd', "?????", 0, 5)
                          in [a, b, readArr (rd', "?????", 0, 5)] end)
  val () = eqS (lab "augmentReader/readArr-from-block-and-readArrNB", "2:ab???",
                fn () => let val (rd, _, ready) = source ({vec = false, arr = false, vecNB = false, arrNB = true, block = true, can = false}, "abcde")
                         in ready := false; readArr (P.augmentReader rd, "?????", 0, 2) end)
  val () = eqS (lab "augmentReader/readArr-from-block-and-readVecNB", "2:?ab??",
                fn () => let val (rd, _, ready) = source ({vec = false, arr = false, vecNB = true, arrNB = false, block = true, can = false}, "abcde")
                         in ready := false; readArr (P.augmentReader rd, "?????", 1, 2) end)
  (* readVecNB from "readVecNB or readArrNB or (canInput and (readVec or
     readArr))" *)
  val () = eqSL (lab "augmentReader/readVecNB-from-readArrNB", ["NONE", "SOME ab"],
                 fn () => let val (rd, _, ready) = source ({vec = false, arr = false, vecNB = false, arrNB = true, block = false, can = false}, "abcde")
                              val rd' = P.augmentReader rd
                              val () = ready := false
                              val a = readVecNB (rd', 2)
                              val () = ready := true
                          in [a, readVecNB (rd', 2)] end)
  val () = eqSL (lab "augmentReader/readVecNB-from-canInput-and-readVec", ["NONE", "SOME ab", ""],
                 fn () => let val (rd, log, ready) = source ({vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = true}, "abcde")
                              val rd' = P.augmentReader rd
                              val () = ready := false
                              val a = readVecNB (rd', 2)
                              val readsWhileBlocked = String.translate (fn #"V" => "V" | _ => "") (!log)
                              val () = ready := true
                          in [a, readVecNB (rd', 2), readsWhileBlocked] end)
  val () = eqSL (lab "augmentReader/readVecNB-from-canInput-and-readArr", ["NONE", "SOME ab"],
                 fn () => let val (rd, _, ready) = source ({vec = false, arr = true, vecNB = false, arrNB = false, block = false, can = true}, "abcde")
                              val rd' = P.augmentReader rd
                              val () = ready := false
                              val a = readVecNB (rd', 2)
                              val () = ready := true
                          in [a, readVecNB (rd', 2)] end)
  (* readArrNB from "readArrNB or readVecNB or (canInput and (readArr or
     readVec))" *)
  val () = eqSL (lab "augmentReader/readArrNB-from-readVecNB", ["NONE", "SOME 2:ab???"],
                 fn () => let val (rd, _, ready) = source ({vec = false, arr = false, vecNB = true, arrNB = false, block = false, can = false}, "abcde")
                              val rd' = P.augmentReader rd
                              val () = ready := false
                              val a = readArrNB (rd', "?????", 0, 2)
                              val () = ready := true
                          in [a, readArrNB (rd', "?????", 0, 2)] end)
  val () = eqSL (lab "augmentReader/readArrNB-from-canInput-and-readVec", ["NONE", "SOME 3:?abc?"],
                 fn () => let val (rd, _, ready) = source ({vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = true}, "abcde")
                              val rd' = P.augmentReader rd
                              val () = ready := false
                              val a = readArrNB (rd', "?????", 1, 3)
                              val () = ready := true
                          in [a, readArrNB (rd', "?????", 1, 3)] end)
  (* What cannot be synthesized stays absent: no non-blocking read without
     canInput or a non-blocking operation, no blocking one without block or
     a blocking operation. *)
  val () = eqSL (lab "augmentReader/no-readVecNB-from-readVec-alone", ["<none>", "<none>"],
                 fn () => let val (rd, _, _) = source ({vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = false}, "abcde")
                              val rd' = P.augmentReader rd
                          in [readVecNB (rd', 2), readArrNB (rd', "??", 0, 2)] end)
  val () = eqSL (lab "augmentReader/no-readVec-from-readVecNB-alone", ["<none>", "<none>"],
                 fn () => let val (rd, _, _) = source ({vec = false, arr = false, vecNB = true, arrNB = false, block = false, can = false}, "abcde")
                              val rd' = P.augmentReader rd
                          in [readVec (rd', 2), readArr (rd', "??", 0, 2)] end)

  (* ==== augmentWriter ==== *)
  (* "if a writer supplies some operation, then the augmented writer provides
     the same implementation of that operation" *)
  val () = eqSL (lab "augmentWriter/keeps-what-the-writer-has", ["2", "1", "SOME 3", "SOME 2", "bcdabccd", "VAva"],
                 fn () => let
                            val (wr, got, log, _) = sink all
                            val wr' = P.augmentWriter wr
                            val a = writeVec (wr', "abcde", 1, 2)
                            val b = writeArr (wr', "abcde", 3, 1)
                            val c = writeVecNB (wr', "abcde", 0, 3)
                            val d = writeArrNB (wr', "abcde", 2, 2)
                          in [a, b, c, d, !got, !log] end)
  val () = eqSL (lab "augmentWriter/keeps-the-other-fields", ["sink", "5", "C"],
                 fn () => let
                            val (wr, _, log, _) = sink {vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = false}
                            val wr' = P.augmentWriter wr
                          in closeWr wr'; [nameWr wr', Int.toString (chunkSizeWr wr'), !log] end)
  (* writeVec from "writeVec or writeArr or (block and (writeVecNB or
     writeArrNB))", and so on as for readers. *)
  val () = eqSL (lab "augmentWriter/writeVec-from-writeArr", ["3", "bcd"],
                 fn () => let val (wr, got, _, _) = sink {vec = false, arr = true, vecNB = false, arrNB = false, block = false, can = false}
                          in [writeVec (P.augmentWriter wr, "abcde", 1, 3), !got] end)
  val () = eqSL (lab "augmentWriter/writeArr-from-writeVec", ["2", "cd"],
                 fn () => let val (wr, got, _, _) = sink {vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = false}
                          in [writeArr (P.augmentWriter wr, "abcde", 2, 2), !got] end)
  val () = eqSL (lab "augmentWriter/writeVec-from-block-and-writeVecNB", ["2", "ab"],
                 fn () => let val (wr, got, _, ready) = sink {vec = false, arr = false, vecNB = true, arrNB = false, block = true, can = false}
                          in ready := false; [writeVec (P.augmentWriter wr, "abcde", 0, 2), !got] end)
  val () = eqSL (lab "augmentWriter/writeVec-from-block-and-writeArrNB", ["2", "ab"],
                 fn () => let val (wr, got, _, ready) = sink {vec = false, arr = false, vecNB = false, arrNB = true, block = true, can = false}
                          in ready := false; [writeVec (P.augmentWriter wr, "abcde", 0, 2), !got] end)
  val () = eqSL (lab "augmentWriter/writeArr-from-block-and-writeVecNB", ["3", "cde"],
                 fn () => let val (wr, got, _, ready) = sink {vec = false, arr = false, vecNB = true, arrNB = false, block = true, can = false}
                          in ready := false; [writeArr (P.augmentWriter wr, "abcde", 2, 3), !got] end)
  val () = eqSL (lab "augmentWriter/writeVecNB-from-writeArrNB", ["NONE", "SOME 2", "bc"],
                 fn () => let val (wr, got, _, ready) = sink {vec = false, arr = false, vecNB = false, arrNB = true, block = false, can = false}
                              val wr' = P.augmentWriter wr
                              val () = ready := false
                              val a = writeVecNB (wr', "abcde", 1, 2)
                              val () = ready := true
                          in [a, writeVecNB (wr', "abcde", 1, 2), !got] end)
  val () = eqSL (lab "augmentWriter/writeVecNB-from-canOutput-and-writeVec", ["NONE", "", "SOME 2", "bc"],
                 fn () => let val (wr, got, _, ready) = sink {vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = true}
                              val wr' = P.augmentWriter wr
                              val () = ready := false
                              val a = writeVecNB (wr', "abcde", 1, 2)
                              val gotWhileBlocked = !got
                              val () = ready := true
                          in [a, gotWhileBlocked, writeVecNB (wr', "abcde", 1, 2), !got] end)
  val () = eqSL (lab "augmentWriter/writeArrNB-from-writeVecNB", ["NONE", "SOME 3", "abc"],
                 fn () => let val (wr, got, _, ready) = sink {vec = false, arr = false, vecNB = true, arrNB = false, block = false, can = false}
                              val wr' = P.augmentWriter wr
                              val () = ready := false
                              val a = writeArrNB (wr', "abcde", 0, 3)
                              val () = ready := true
                          in [a, writeArrNB (wr', "abcde", 0, 3), !got] end)
  val () = eqSL (lab "augmentWriter/writeArrNB-from-canOutput-and-writeArr", ["NONE", "SOME 1", "e"],
                 fn () => let val (wr, got, _, ready) = sink {vec = false, arr = true, vecNB = false, arrNB = false, block = false, can = true}
                              val wr' = P.augmentWriter wr
                              val () = ready := false
                              val a = writeArrNB (wr', "abcde", 4, 1)
                              val () = ready := true
                          in [a, writeArrNB (wr', "abcde", 4, 1), !got] end)
  val () = eqSL (lab "augmentWriter/no-writeVecNB-from-writeVec-alone", ["<none>", "<none>"],
                 fn () => let val (wr, _, _, _) = sink {vec = true, arr = false, vecNB = false, arrNB = false, block = false, can = false}
                              val wr' = P.augmentWriter wr
                          in [writeVecNB (wr', "ab", 0, 2), writeArrNB (wr', "ab", 0, 2)] end)
  val () = eqSL (lab "augmentWriter/no-writeVec-from-writeVecNB-alone", ["<none>", "<none>"],
                 fn () => let val (wr, _, _, _) = sink {vec = false, arr = false, vecNB = true, arrNB = false, block = false, can = false}
                              val wr' = P.augmentWriter wr
                          in [writeVec (wr', "ab", 0, 2), writeArr (wr', "ab", 0, 2)] end)
end
