(* Checks of a structure with signature STREAM_IO, for text and binary
   elements. Expected values follow
   https://smlfamily.github.io/Basis/stream-io.html, and io.html for the
   buffer modes and the Io exception.

     structure Generic = TestStreamIOFn (structure RW = TextRW structure S = TextIO.StreamIO val name = "TextIO.StreamIO" val elemChar = ... val charElem = ... val text = true)

   needs spec-sigs/STREAM_IO.sml and fn/io_script.sml, where TextRW : IO_RW
   is described.
   The labels are name ^ ".member/case". The streams are built with
   S.mkInstream and S.mkOutstream on the readers and writers of
   fn/io_script.sml, whose behaviour the checks fix; elements are written as
   characters (elemChar and charElem convert one element). `text` says
   whether the elements are characters, for which LINE_BUF flushes at a
   newline; "For binary streams, LINE_BUF mode should be treated as a synonym
   for BLOCK_BUF" (io.html).

   Many checks are the predicates of the Discussion of the page ("the
   predicates used to illustrate a point should all evaluate to true"):
   chkInput, chkClose, closeTwice, noBlock, newStr, reads, isEOS, the
   definition of inputAll by input, allAndN and the definition of input1 by
   inputN. Positions are not checked here, only that a stream without them
   raises Io: the pos of TextIO.StreamIO is abstract, so that a reader of
   one's own cannot have them (see binio_streamio.sml and the file checks of
   textio_streamio.sml). *)
functor TestStreamIOFn (structure RW : IO_RW
                        structure S : SPEC_STREAM_IO
                          where type vector = RW.vector where type reader = RW.reader where type writer = RW.writer
                        val name : string
                        val elemChar : S.elem -> char
                        val charElem : char -> S.elem
                        val text : bool) =
struct
  fun lab s = name ^ "." ^ s

  structure R = IOScriptFn (RW)
  val fromString = RW.fromString
  val toString = RW.toString

  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val eqSL = T.eq (T.list T.string)
  val eqCOL = T.eq (T.list (T.option T.char))

  val empty = fromString ""

  (* instream pieces: a stream on a fresh scripted reader (a piece "" is an
     end-of-stream), and the reader's log. *)
  fun instream (pieces : string list) : S.instream * R.log =
    let val (rd, log) = R.reader ("script", pieces) in (S.mkInstream (rd, empty), log) end
  fun instream' pieces = #1 (instream pieces)
  (* nbInstream pieces: the same on a reader that has readVecNB, and the
     switch that makes it answer that a read would block. *)
  fun nbInstream (pieces : string list) : S.instream * R.log * bool ref =
    let
      val blocked = ref false
      val (rd, log) = R.scripted {name = "nb", chunkSize = 1000, pieces = pieces, broken = ref false,
                                  blocked = blocked, nonBlocking = true}
    in (S.mkInstream (rd, empty), log, blocked) end
  (* brokenInstream pieces: the same on a reader that fails while the switch
     is on. *)
  fun brokenInstream (pieces : string list) : S.instream * bool ref =
    let
      val broken = ref false
      val (rd, _) = R.scripted {name = "broken", chunkSize = 1000, pieces = pieces, broken = broken,
                                blocked = ref false, nonBlocking = false}
    in (S.mkInstream (rd, empty), broken) end
  (* A reader whose close fails. *)
  fun badCloseInstream () : S.instream =
    S.mkInstream (RW.mkReader {name = "badclose", chunkSize = 1000, readVec = fn _ => fromString "",
                               readVecNB = NONE, close = fn () => raise R.Broken},
                  empty)

  fun input (f : S.instream) : string * S.instream = let val (v, f') = S.input f in (toString v, f') end
  fun input1 (f : S.instream) : (char * S.instream) option =
    case S.input1 f of SOME (e, f') => SOME (elemChar e, f') | NONE => NONE
  fun inputN (f : S.instream, n : int) : string * S.instream =
    let val (v, f') = S.inputN (f, n) in (toString v, f') end
  fun inputAll (f : S.instream) : string * S.instream = let val (v, f') = S.inputAll f in (toString v, f') end
  (* inputs (f, k): the vectors that k successive calls of input return. *)
  fun inputs (f : S.instream, k : int) : string list =
    if k = 0 then [] else let val (a, f') = input f in a :: inputs (f', k - 1) end
  (* untilEos f: the elements that input returns up to the next
     end-of-stream, and the stream after it. *)
  fun untilEos (f : S.instream) : string * S.instream =
    let
      fun go (f, acc) =
        case input f of
          ("", f') => (String.concat (List.rev acc), f')
        | (s, f') => go (f', s :: acc)
    in go (f, []) end
  (* segments (f, k): untilEos k times. *)
  fun segments (f : S.instream, k : int) : string list =
    if k = 0 then [] else let val (s, f') = untilEos f in s :: segments (f', k - 1) end
  (* allInputs (f, k): inputAll k times. *)
  fun allInputs (f : S.instream, k : int) : string list =
    if k = 0 then [] else let val (s, f') = inputAll f in s :: allInputs (f', k - 1) end
  (* chars (f, k): what input1 returns along the stream, up to NONE. *)
  fun chars (f : S.instream, k : int) : char option list =
    if k = 0 then []
    else case input1 f of NONE => [NONE] | SOME (c, f') => SOME c :: chars (f', k - 1)
  (* equiv (f, g, k): "the two argument streams behave identically under
     input", for k inputs. *)
  fun equiv (f : S.instream, g : S.instream, k : int) : bool =
    k = 0 orelse
    let val (s, f') = input f val (t, g') = input g in s = t andalso equiv (f', g', k - 1) end

  (* outstream mode: a stream in that mode on a fresh writer, and its log. *)
  fun outstream (mode : IO.buffer_mode) : S.outstream * R.log =
    let val (w, log) = R.writer "memory" in (S.mkOutstream (w, mode), log) end
  fun output (s : S.outstream, str : string) : unit = S.output (s, fromString str)
  (* afterEach (mode, steps): what the writer holds after each step. *)
  fun afterEach (mode : IO.buffer_mode, steps : (S.outstream -> unit) list) : string list =
    let val (s, log) = outstream mode in List.map (fn step => (step s; R.written log)) steps end
  fun out str = fn s => output (s, str)
  fun out1 c = fn s => S.output1 (s, charElem c)
  (* brokenOutstream mode: a stream on a writer that fails while the switch
     is on. *)
  fun brokenOutstream (mode : IO.buffer_mode) : S.outstream * R.log * bool ref =
    let
      val broken = ref false
      val (w, log) = R.memWriter {name = "brokenw", chunkSize = 1000, most = 1000000, broken = broken}
    in (S.mkOutstream (w, mode), log, broken) end

  fun showMode IO.NO_BUF = "NO_BUF"
    | showMode IO.LINE_BUF = "LINE_BUF"
    | showMode IO.BLOCK_BUF = "BLOCK_BUF"
  val modes = [IO.NO_BUF, IO.LINE_BUF, IO.BLOCK_BUF]

  (* ==== input ==== *)
  (* "The sequence of strings returned from a fresh stream by input is
     exactly the sequence returned by the underlying reader. This includes
     end-of-stream conditions". *)
  val () = eqB (lab "input/the-sequence-of-the-reader", true,
                fn () => let
                           val (f, log) = instream ["abc", "de", "", "fgh", "", "i"]
                           val got = inputs (f, 8)
                         in got = List.take (R.returned log, 8) end)
  val () = eqSL (lab "input/up-to-each-end-of-stream", ["abcde", "fgh", "i", "", ""],
                 fn () => segments (instream' ["abc", "de", "", "fgh", "", "i"], 5))
  val () = eqB (lab "input/one-or-more-elements", true,
                fn () => let val (s, _) = input (instream' ["hello"]) in String.size s >= 1 andalso String.isPrefix s "hello" end)
  val () = eqS (lab "input/empty-at-end-of-stream", "", fn () => #1 (input (instream' [])))
  (* chkInput: input "must return the same number of elements on subsequent
     reads from the same point" *)
  val () = eqB (lab "input/same-result-twice", true,
                fn () => let
                           val f = instream' ["abc", "de", "", "f"]
                           val (a, f1) = input f
                           val (b, f1') = input f
                           val (c, _) = input f1
                           val (d, _) = input f1'
                         in a = b andalso c = d end)
  (* reads (rdr, n), for n = 0, ..., 4: "the first time any stream value is
     produced, it is up-to-date with respect to its reader". *)
  val () = eqB (lab "input/up-to-date-with-the-reader", true,
                fn () => List.all (fn n =>
                                     let
                                       fun nreads (f, 0) = f
                                         | nreads (f, k) = nreads (#2 (input f), k - 1)
                                       val f = nreads (instream' ["ab", "cd", "", "e", "fg"], n)
                                     in
                                       S.closeIn f; #1 (input f) = ""
                                     end) [0, 1, 2, 3, 4])
  (* "Input from f again will yield the same elements": every stream of the
     chain reads on from its own point. *)
  val () = eqSL (lab "input/earlier-streams-read-the-same", ["abcdef", "cdef", "ef", "abcdef"],
                 fn () => let
                            val f0 = instream' ["ab", "cd", "ef"]
                            val (_, f1) = input f0
                            val (_, f2) = input f1
                          in [#1 (untilEos f0), #1 (untilEos f1), #1 (untilEos f2), #1 (untilEos f0)] end)
  (* "This function raises the Io exception if there is an error in the
     underlying reader"; its cause is the exception of the reader and its
     name that of the reader (io.html). *)
  val () = eqS (lab "input/Io-when-the-reader-fails", "Broken",
                fn () => let val (f, broken) = brokenInstream ["abc"]
                         in broken := true; R.ioCause (fn () => ignore (S.input f)) end)
  val () = eqS (lab "input/Io-name-is-the-reader's", "broken",
                fn () => let val (f, broken) = brokenInstream ["abc"]
                         in broken := true; R.ioName (fn () => ignore (S.input f)) end)
  (* "if an exception occurs during any Stream I/O operation, then the stream
     must leave itself in a consistent state, without losing or duplicating
     data" *)
  val () = eqS (lab "input/after-a-failure-of-the-reader", "abcde",
                fn () => let
                           val (f, broken) = brokenInstream ["abc", "de"]
                           val () = broken := true
                           val () = (ignore (S.input f)) handle _ => ()
                           val () = broken := false
                         in #1 (untilEos f) end)

  (* ==== input1 ==== *)
  val () = eqCOL (lab "input1/elements-then-NONE", [SOME #"a", SOME #"b", SOME #"c", NONE],
                  fn () => chars (instream' ["ab", "c"], 10))
  val () = eqCOL (lab "input1/empty-stream", [NONE], fn () => chars (instream' [], 10))
  val () = eqCOL (lab "input1/stops-at-end-of-stream", [SOME #"a", NONE], fn () => chars (instream' ["a", "", "b"], 10))
  (* "it cannot be used to read beyond an end-of-stream": NONE again from the
     same stream. *)
  val () = eqCOL (lab "input1/NONE-again", [NONE, NONE],
                  fn () => let val f = instream' ["", "b"] in chars (f, 1) @ chars (f, 1) end)
  (* "fun input1 f = case TS.inputN (f,1) of ("",_) => NONE | (s,f')=>
     SOME(String.sub(s,0),f')" *)
  val () = eqB (lab "input1/is-inputN-1", true,
                fn () => let
                           fun same (f, k) =
                             k = 0 orelse
                             (case (input1 f, inputN (f, 1)) of
                                (NONE, ("", f')) => same (f', k - 1)
                              | (SOME (c, f1), (s, f2)) => str c = s andalso equiv (f1, f2, 4) andalso same (f1, k - 1)
                              | _ => false)
                         in same (instream' ["xy", "", "z", "", "", "uvw"], 9) end)

  (* ==== inputN ==== *)
  (* "inputN(f,0) returns immediately with an empty vector and f" *)
  val () = eqB (lab "inputN/zero", true,
                fn () => let
                           val (f, log) = instream ["abc"]
                           val (s, f') = inputN (f, 0)
                         in s = "" andalso R.reads log = 0 andalso equiv (f, f', 3) end)
  val () = T.raises (lab "inputN/Size-negative", T.isSize, fn () => S.inputN (instream' ["abc"], ~1))
  val () = eqSL (lab "inputN/across-pieces", ["abcde", "f"],
                 fn () => let val (s, f') = inputN (instream' ["ab", "cd", "ef"], 5) in [s, #1 (inputAll f')] end)
  (* "If fewer than n elements are available before the next end-of-stream,
     it returns all of the elements up to that end-of-stream"; the stream it
     returns is then equivalent to the one of inputAll, which "is
     immediately past the next end-of-stream" (allAndN). *)
  val () = eqSL (lab "inputN/fewer-then-past-the-end-of-stream", ["ab", "cd"],
                 fn () => let val (s, f') = inputN (instream' ["ab", "", "cd"], 5) in [s, #1 (untilEos f')] end)
  (* "if input1(f) returns NONE, a call to inputN(f,1) will return
     immediately with (fromList [], f'), and f' can be used to continue
     input" *)
  val () = eqSL (lab "inputN/continues-after-input1-NONE", ["NONE", "", "x"],
                 fn () => let
                            val f = instream' ["", "x"]
                            val a = case input1 f of NONE => "NONE" | SOME _ => "SOME"
                            val (b, f') = inputN (f, 1)
                          in [a, b, #1 (untilEos f')] end)
  (* "If f contained exactly n characters before the end-of-stream, then r
     in allAndN will be the empty string" *)
  val () = eqSL (lab "inputN/exactly-n-before-end-of-stream", ["abc", "", "d"],
                 fn () => let
                            val (s, f1) = inputN (instream' ["abc", "", "d"], 3)
                            val (r, f3) = inputAll f1
                          in [s, r, #1 (inputAll f3)] end)
  val () = eqS (lab "inputN/empty-stream", "", fn () => #1 (inputN (instream' [], 4)))

  (* ==== inputAll ==== *)
  (* "if a stream f contains data "abc" followed by an end-of-stream
     followed by "defg" and another end-of-stream, then inputAll f returns
     ("abc",f'), and inputAll f' returns ("defg",f'')" *)
  val () = eqSL (lab "inputAll/up-to-each-end-of-stream", ["abc", "defg", ""],
                 fn () => allInputs (instream' ["abc", "", "defg", ""], 3))
  val () = eqSL (lab "inputAll/pieces", ["abcdefg", ""], fn () => allInputs (instream' ["ab", "c", "defg"], 2))
  val () = eqSL (lab "inputAll/same-result-twice", ["abc", "abc"],
                 fn () => let val f = instream' ["a", "bc", "", "d"] in [#1 (inputAll f), #1 (inputAll f)] end)
  (* The semantics of inputAll "can be defined in terms of input". *)
  val () = eqB (lab "inputAll/is-input-to-end-of-stream", true,
                fn () => let
                           val f = instream' ["a", "bc", "", "", "def", "g", "", "h"]
                           fun same (f, k) =
                             k = 0 orelse
                             let val (s, f1) = inputAll f val (t, f2) = untilEos f
                             in s = t andalso equiv (f1, f2, 5) andalso same (f1, k - 1) end
                         in same (f, 5) end)
  val () = eqS (lab "inputAll/with-initial-elements", "xyabc",
                fn () => let val (rd, _) = R.reader ("script", ["ab", "c"]) in #1 (inputAll (S.mkInstream (rd, fromString "xy"))) end)

  (* ==== laws on random streams ====
     allAndN: "inputN returns fewer than n characters if and only if those
     elements are followed by an end-of-stream"; inputN against inputAll. *)
  fun randomPieces () =
    List.tabulate (T.range (0, 8),
                   fn _ => if T.range (0, 3) = 0 then ""
                           else String.implode (List.tabulate (T.range (1, 6), fn _ => T.oneOf [#"a", #"b", #"\n", #"z"])))
  val () = T.seed 2026
  val () = T.repeat (20, fn i =>
             eqB (lab ("inputN/allAndN-random-" ^ Int.toString i), true,
                  fn () => let
                             val f = instream' (randomPieces ())
                             val n = T.range (0, 12)
                             val (s, f1) = inputN (f, n)
                             val (t, f2) = inputAll f
                           in
                             (String.size s < n andalso s = t andalso equiv (f1, f2, 6))
                             orelse
                             (let val (r, f3) = inputAll f1
                              in String.size s = n andalso t = s ^ r andalso equiv (f2, f3, 6) end)
                           end))

  (* ==== canInput ==== *)
  val () = T.raises (lab "canInput/Size-negative", T.isSize, fn () => S.canInput (#1 (nbInstream ["abc"]), ~1))
  (* "returns NONE if any attempt at input would block" *)
  val () = eqB (lab "canInput/NONE-when-input-would-block", true,
                fn () => let val (f, _, blocked) = nbInstream ["abc"] in blocked := true; S.canInput (f, 5) = NONE end)
  (* "It returns SOME(k), where 0 <= k <= n, if a call to input would return
     immediately with at least k characters. Note that k = 0 corresponds to
     the stream being at end-of-stream." *)
  val () = eqB (lab "canInput/elements-available", true,
                fn () => case S.canInput (#1 (nbInstream ["abc"]), 2) of SOME k => 1 <= k andalso k <= 2 | NONE => false)
  (* "inputN is guaranteed not to block if a previous call to canInput
     returned SOME(_)", so that inputN and canInput make a non-blocking
     inputN. (input itself may return fewer than k: "a typical
     implementation will simply return the remainder of the current
     buffer".) *)
  val () = eqB (lab "canInput/then-inputN-k", true,
                fn () => let val (f, _, _) = nbInstream ["abc", "de"]
                         in case S.canInput (f, 10) of
                              SOME k => k >= 1 andalso String.size (#1 (inputN (f, k))) = k
                            | NONE => false
                         end)
  val () = eqB (lab "canInput/end-of-stream-is-zero", true,
                fn () => S.canInput (#1 (nbInstream []), 5) = SOME 0)
  (* noBlock: "If a stream has already been at least partly determined, then
     input cannot possibly block", even if the reader would now. *)
  val () = eqB (lab "canInput/determined-stream-does-not-block", true,
                fn () => List.all (fn pieces =>
                                     let
                                       val (f, _, blocked) = nbInstream pieces
                                       val (s, _) = input f
                                       val () = blocked := true
                                     in
                                       case S.canInput (f, 1) of
                                         SOME 0 => String.size s = 0
                                       | SOME _ => String.size s > 0
                                       | NONE => false
                                     end) [["abc"], [], ["", "x"]])
  val () = eqS (lab "canInput/removes-nothing", "abcde",
                fn () => let val (f, _, _) = nbInstream ["abc", "de"] in ignore (S.canInput (f, 4)); #1 (untilEos f) end)

  (* ==== closeIn ==== *)
  (* "marks the stream closed, and closes the underlying reader. Applying
     closeIn on a closed stream has no effect." *)
  val () = eqI (lab "closeIn/closes-the-reader", 1, fn () => let val (f, log) = instream ["abc"] in S.closeIn f; R.closes log end)
  (* closeTwice *)
  val () = eqI (lab "closeIn/twice", 1, fn () => let val (f, log) = instream ["abc"] in S.closeIn f; S.closeIn f; R.closes log end)
  val () = eqI (lab "closeIn/any-stream-of-the-chain", 1,
                fn () => let val (f, log) = instream ["abc", "de"] val (_, f1) = input f
                         in S.closeIn f1; S.closeIn f; R.closes log end)
  (* chkClose: "Closing or truncating a stream just causes the
     not-yet-determined part of the stream to be empty" *)
  val () = eqB (lab "closeIn/not-yet-determined-part-is-empty", true,
                fn () => let
                           val f = instream' ["abc", "de"]
                           val (a, f') = input f
                           val _ = S.closeIn f
                           val (b, _) = input f
                         in a = b andalso S.endOfStream f' end)
  (* newStr: "A freshly opened stream is still undetermined (no ``read'' has
     yet been done on the underlying reader)" *)
  val () = eqB (lab "closeIn/fresh-stream", true,
                fn () => let val (f, log) = instream ["abc"]
                         in S.closeIn f; String.size (#1 (input f)) = 0 andalso R.reads log = 0 end)
  val () = eqSL (lab "closeIn/keeps-what-was-determined", ["abc", "", "abc"],
                 fn () => let
                            val f = instream' ["abc", "de"]
                            val (_, f1) = input f
                            val () = S.closeIn f1
                          in [#1 (untilEos f), #1 (untilEos f1), #1 (inputAll f)] end)
  (* "This function raises the Io exception if there is an error in the
     underlying reader." *)
  val () = eqS (lab "closeIn/Io-when-the-reader-fails", "Broken",
                fn () => R.ioCause (fn () => S.closeIn (badCloseInstream ())))
  (* "one can close a truncated or terminated string [...] with the inactive
     stream providing a handle to the underlying file" *)
  val () = eqI (lab "closeIn/truncated-stream-closes-the-reader", 1,
                fn () => let val (f, log) = instream ["abc"] in ignore (S.getReader f); S.closeIn f; R.closes log end)

  (* ==== endOfStream ==== *)
  (* isEOS: "The endOfStream test is equivalent to input returning an empty
     sequence", at every point of a stream. *)
  val () = eqB (lab "endOfStream/is-input-empty", true,
                fn () => let
                           fun all (f, k) =
                             k = 0 orelse
                             (let val (a, f') = input f in (String.size a = 0) = S.endOfStream f andalso all (f', k - 1) end)
                         in all (instream' ["ab", "", "", "c", "d", ""], 9) end)
  (* "It is always true, however, that endOfStream f = endOfStream f"; "if
     endOfStream f returns true, then input f returns ("",f') and
     endOfStream f' may or may not be true" *)
  val () = eqSL (lab "endOfStream/end-of-stream-then-more", ["true", "true", "", "false", "x"],
                 fn () => let
                            val f = instream' ["", "x"]
                            val a = S.endOfStream f
                            val b = S.endOfStream f
                            val (c, f') = input f
                          in [Bool.toString a, Bool.toString b, c, Bool.toString (S.endOfStream f'), #1 (untilEos f')] end)
  val () = eqB (lab "endOfStream/elements-available", false, fn () => S.endOfStream (instream' ["a"]))
  val () = eqB (lab "endOfStream/empty-stream", true, fn () => S.endOfStream (instream' []))
  val () = eqS (lab "endOfStream/removes-nothing", "ab",
                fn () => let val f = instream' ["ab"] in ignore (S.endOfStream f); #1 (untilEos f) end)
  val () = eqB (lab "endOfStream/closed-stream", true,
                fn () => let val f = instream' ["ab"] in S.closeIn f; S.endOfStream f end)

  (* ==== mkInstream ==== *)
  (* "returns a new instream built on top of the reader rd with the initial
     buffer contents v" *)
  val () = eqS (lab "mkInstream/initial-buffer-comes-first", "xyabc",
                fn () => let val (rd, _) = R.reader ("script", ["abc"]) in #1 (untilEos (S.mkInstream (rd, fromString "xy"))) end)
  val () = eqCOL (lab "mkInstream/initial-buffer-input1", [SOME #"x", SOME #"y", SOME #"a", NONE],
                  fn () => let val (rd, _) = R.reader ("script", ["a"]) in chars (S.mkInstream (rd, fromString "xy"), 10) end)
  val () = eqB (lab "mkInstream/input-of-initial-buffer", true,
                fn () => let val (rd, _) = R.reader ("script", ["abc"]) val (s, _) = input (S.mkInstream (rd, fromString "xy"))
                         in String.size s >= 1 andalso String.isPrefix s "xyabc" end)
  val () = eqI (lab "mkInstream/reads-nothing", 0,
                fn () => let val (f, log) = instream ["abc"] in ignore f; R.reads log end)
  val () = eqSL (lab "mkInstream/empty-reader", ["", ""], fn () => allInputs (instream' [], 2))

  (* ==== getReader ==== *)
  (* "returns the underlying reader along with any unconsumed data from its
     buffer. The data returned will have the value (closeIn f; inputAll f)."
     "if one opens a stream, then extracts the underlying reader, the reader
     has not yet been advanced in its file." *)
  fun readVec (rd, n) = case RW.readerReadVec rd of SOME f => toString (f n) | NONE => "<no readVec>"
  val readerName = RW.readerName
  val () = eqSL (lab "getReader/fresh-stream", ["script", "", "abc"],
                 fn () => let val (rd, v) = S.getReader (instream' ["abc", "de"])
                          in [readerName rd, toString v, readVec (rd, 100)] end)
  val () = eqSL (lab "getReader/unconsumed-data", ["abc", "de"],
                 fn () => let
                            val f = instream' ["abc", "de"]
                            val _ = input f
                            val (rd, v) = S.getReader f
                          in [toString v, readVec (rd, 100)] end)
  val () = eqSL (lab "getReader/after-the-data", ["", "de"],
                 fn () => let
                            val (_, f1) = input (instream' ["abc", "de"])
                            val (rd, v) = S.getReader f1
                          in [toString v, readVec (rd, 100)] end)
  val () = eqS (lab "getReader/initial-buffer", "xy",
                fn () => let val (rd, _) = R.reader ("script", ["abc"]) in toString (#2 (S.getReader (S.mkInstream (rd, fromString "xy")))) end)
  (* "marks the input stream f as truncated"; "Reading from a truncated input
     stream will never block; after all buffered elements are read, input
     operations always return empty vectors." *)
  val () = eqB (lab "getReader/truncates-the-stream", true,
                fn () => let val (f, log) = instream ["abc"]
                         in ignore (S.getReader f); #1 (input f) = "" andalso S.endOfStream f andalso R.reads log = 0 end)
  val () = eqSL (lab "getReader/truncated-stream-keeps-its-buffer", ["abc", ""],
                 fn () => let
                            val f = instream' ["abc", "de"]
                            val (_, f1) = input f
                          in ignore (S.getReader f); [#1 (untilEos f), #1 (untilEos f1)] end)
  val () = eqI (lab "getReader/does-not-close-the-reader", 0,
                fn () => let val (f, log) = instream ["abc"] in ignore (S.getReader f); R.closes log end)
  (* "The function raises the exception Io if f is closed or truncated." *)
  val () = T.raises (lab "getReader/Io-truncated", R.isIo,
                     fn () => let val f = instream' ["abc"] in ignore (S.getReader f); S.getReader f end)
  val () = T.raises (lab "getReader/Io-closed", R.isIo,
                     fn () => let val f = instream' ["abc"] in S.closeIn f; S.getReader f end)

  (* ==== filePosIn ==== *)
  (* "This raises the exception Io if the stream does not support the
     operation": the reader has no positions ("filePosIn [needs] getPos and
     setPos"), which io.html reports with RandomAccessNotSupported. *)
  val () = T.raises (lab "filePosIn/Io-without-positions", R.isIo, fn () => S.filePosIn (instream' ["abc"]))
  val () = eqS (lab "filePosIn/Io-cause", "RandomAccessNotSupported",
                fn () => R.ioCause (fn () => ignore (S.filePosIn (instream' ["abc"]))))

  (* ==== mkOutstream, getBufferMode, setBufferMode ==== *)
  val () = eqB (lab "mkOutstream/buffer-mode", true,
                fn () => List.all (fn m => S.getBufferMode (#1 (outstream m)) = m) modes)
  val () = eqSL (lab "mkOutstream/writes-to-the-writer", ["abc"],
                 fn () => afterEach (IO.NO_BUF, [out "abc"]))
  val () = eqB (lab "getBufferMode/after-setBufferMode", true,
                fn () => let val (s, _) = outstream IO.NO_BUF
                         in List.all (fn m => (S.setBufferMode (s, m); S.getBufferMode s = m)) (modes @ List.rev modes) end)
  (* "Setting the buffer mode to IO.NO_BUF causes any buffered output to be
     flushed." *)
  val () = eqSL (lab "setBufferMode/NO_BUF-flushes", ["", "abc"],
                 fn () => afterEach (IO.BLOCK_BUF, [out "abc", fn s => S.setBufferMode (s, IO.NO_BUF)]))
  (* "Switching the mode between IO.LINE_BUF and IO.BLOCK_BUF should not
     cause flushing." *)
  val () = eqSL (lab "setBufferMode/BLOCK_BUF-to-LINE_BUF-does-not-flush", ["", ""],
                 fn () => afterEach (IO.BLOCK_BUF, [out "a\nb", fn s => S.setBufferMode (s, IO.LINE_BUF)]))
  val () = eqSL (lab "setBufferMode/LINE_BUF-to-BLOCK_BUF-does-not-flush", ["", ""],
                 fn () => afterEach (IO.LINE_BUF, [out "ab", fn s => S.setBufferMode (s, IO.BLOCK_BUF)]))
  val () = eqSL (lab "setBufferMode/then-output", ["", "", "abcd"],
                 fn () => afterEach (IO.BLOCK_BUF, [out "ab", fn s => S.setBufferMode (s, IO.BLOCK_BUF),
                                                    fn s => (S.setBufferMode (s, IO.NO_BUF); output (s, "cd"))]))

  (* ==== output, output1 ==== *)
  (* io.html: "If an output stream has mode NO_BUF, the implementation should
     write the argument bytes of any output function directly to the
     corresponding device." *)
  val () = eqSL (lab "output/NO_BUF-writes-at-once", ["abc", "abcde", "abcde"],
                 fn () => afterEach (IO.NO_BUF, [out "abc", out "de", out ""]))
  val () = eqSL (lab "output1/NO_BUF-writes-at-once", ["a", "ab", "abcd"],
                 fn () => afterEach (IO.NO_BUF, [out1 #"a", out1 #"b", out "cd"]))
  (* "If flushing finds that it can do only a partial write [...], then the
     stream function must adjust the stream's buffer for the items written
     and then try again." *)
  val () = eqS (lab "output/partial-writes-are-completed", "abcdefg",
                fn () => let
                           val (w, log) = R.memWriter {name = "two", chunkSize = 1000, most = 2, broken = ref false}
                           val s = S.mkOutstream (w, IO.NO_BUF)
                         in output (s, "abcdefg"); R.written log end)
  val () = eqS (lab "flushOut/partial-writes-are-completed", "abcdefg",
                fn () => let
                           val (w, log) = R.memWriter {name = "two", chunkSize = 1000, most = 2, broken = ref false}
                           val s = S.mkOutstream (w, IO.BLOCK_BUF)
                         in output (s, "abc"); S.output1 (s, charElem #"d"); output (s, "efg"); S.flushOut s; R.written log end)
  (* "If an output stream has mode BLOCK_BUF, the implementation should
     store output in a buffer, actually writing the buffer's content to the
     device only when the buffer is full"; the writer's chunkSize is 1000. *)
  val () = eqSL (lab "output/BLOCK_BUF-keeps-a-little", ["", "", "", "abc\ndef"],
                 fn () => afterEach (IO.BLOCK_BUF, [out "abc", out "\n", out1 #"d", fn s => (output (s, "ef"); S.flushOut s)]))
  (* "If an output stream has mode LINE_BUF, output bytes should be buffered
     until a newline character (#"\n") is seen, at which point the buffer
     should be flushed, including the newline character. For binary streams,
     LINE_BUF mode should be treated as a synonym for BLOCK_BUF." *)
  val () =
    if text then
      eqSL (lab "output/LINE_BUF-flushes-at-a-newline", ["", "", "ab\n", "ab\n", "ab\ncd\n"],
            fn () => afterEach (IO.LINE_BUF, [out "a", out1 #"b", out1 #"\n", out "c", out "d\n"]))
    else
      eqSL (lab "output/LINE_BUF-is-BLOCK_BUF", ["", "", "", "a\nb\ncd\n"],
            fn () => afterEach (IO.LINE_BUF, [out "a\n", out1 #"b", out "\ncd\n", fn s => S.flushOut s]))
  val () =
    if text then
      eqB (lab "output1/LINE_BUF-flushes-at-a-newline", true,
           fn () => afterEach (IO.LINE_BUF, [out1 #"x", out1 #"\n"]) = ["", "x\n"])
    else
      eqB (lab "output1/LINE_BUF-is-BLOCK_BUF", true,
           fn () => afterEach (IO.LINE_BUF, [out1 #"x", out1 #"\n"]) = ["", ""])
  (* "This raises the exception Io if f is terminated"; ClosedStream "is used
     by the output I/O operations if the underlying object is closed or
     terminated" (io.html). *)
  val () = eqS (lab "output/Io-closed", "ClosedStream",
                fn () => let val (s, _) = outstream IO.NO_BUF in S.closeOut s; R.ioCause (fn () => output (s, "x")) end)
  val () = eqS (lab "output/Io-closed-name", "memory",
                fn () => let val (s, _) = outstream IO.NO_BUF in S.closeOut s; R.ioName (fn () => output (s, "x")) end)
  val () = eqS (lab "output/Io-terminated", "ClosedStream",
                fn () => let val (s, _) = outstream IO.NO_BUF in ignore (S.getWriter s); R.ioCause (fn () => output (s, "x")) end)
  val () = eqS (lab "output/Io-terminated-writes-nothing", "ab",
                fn () => let val (s, log) = outstream IO.NO_BUF
                         in output (s, "ab"); ignore (S.getWriter s); ignore (R.ioOf (fn () => output (s, "x"))); R.written log end)
  val () = eqS (lab "output1/Io-closed", "ClosedStream",
                fn () => let val (s, _) = outstream IO.BLOCK_BUF in S.closeOut s; R.ioCause (fn () => out1 #"x" s) end)
  val () = eqS (lab "output1/Io-terminated", "ClosedStream",
                fn () => let val (s, _) = outstream IO.LINE_BUF in ignore (S.getWriter s); R.ioCause (fn () => out1 #"x" s) end)
  (* "This function also raises the Io exception if there is an error in the
     underlying writer"; "Users who create their own readers or writers may
     raise any exception they like, which will be reported as the cause
     field of the resulting Io exception" (io.html). *)
  val () = eqS (lab "output/Io-when-the-writer-fails", "Broken",
                fn () => let val (s, _, broken) = brokenOutstream IO.NO_BUF in broken := true; R.ioCause (fn () => output (s, "x")) end)
  val () = eqS (lab "output/Io-name-is-the-writer's", "brokenw",
                fn () => let val (s, _, broken) = brokenOutstream IO.NO_BUF in broken := true; R.ioName (fn () => output (s, "x")) end)
  val () = eqS (lab "output1/Io-when-the-writer-fails", "Broken",
                fn () => let val (s, _, broken) = brokenOutstream IO.NO_BUF in broken := true; R.ioCause (fn () => out1 #"x" s) end)

  (* ==== flushOut ==== *)
  (* "flushes any output in f's buffer to the underlying writer; it is a
     no-op on terminated streams" *)
  val () = eqSL (lab "flushOut/writes-the-buffer", ["", "abc", "abc", "abcd"],
                 fn () => afterEach (IO.BLOCK_BUF, [out "abc", S.flushOut, S.flushOut, fn s => (out1 #"d" s; S.flushOut s)]))
  val () = eqSL (lab "flushOut/LINE_BUF", ["", "ab"], fn () => afterEach (IO.LINE_BUF, [out "ab", S.flushOut]))
  val () = eqSL (lab "flushOut/NO_BUF", ["ab", "ab"], fn () => afterEach (IO.NO_BUF, [out "ab", S.flushOut]))
  val () = eqS (lab "flushOut/terminated-is-a-no-op", "ab",
                fn () => let val (s, log) = outstream IO.BLOCK_BUF
                         in output (s, "ab"); ignore (S.getWriter s); S.flushOut s; S.flushOut s; R.written log end)
  val () = eqS (lab "flushOut/closed-is-a-no-op", "ab",
                fn () => let val (s, log) = outstream IO.BLOCK_BUF
                         in output (s, "ab"); S.closeOut s; S.flushOut s; R.written log end)
  val () = eqS (lab "flushOut/Io-when-the-writer-fails", "Broken",
                fn () => let val (s, _, broken) = brokenOutstream IO.BLOCK_BUF
                         in output (s, "abc"); broken := true; R.ioCause (fn () => S.flushOut s) end)

  (* ==== closeOut ==== *)
  (* "flushes f's buffers, marks the stream closed, and closes the underlying
     writer. This operation has no effect if f is already closed. Note that
     if f is terminated, no flushing will occur." *)
  val () = eqS (lab "closeOut/flushes", "abc",
                fn () => let val (s, log) = outstream IO.BLOCK_BUF in output (s, "abc"); S.closeOut s; R.written log end)
  val () = eqI (lab "closeOut/closes-the-writer", 1, fn () => let val (s, log) = outstream IO.NO_BUF in S.closeOut s; R.closes log end)
  val () = eqI (lab "closeOut/twice", 1, fn () => let val (s, log) = outstream IO.NO_BUF in S.closeOut s; S.closeOut s; R.closes log end)
  (* "one can close a truncated or terminated string" *)
  val () = eqI (lab "closeOut/terminated-closes-the-writer", 1,
                fn () => let val (s, log) = outstream IO.BLOCK_BUF in ignore (S.getWriter s); S.closeOut s; R.closes log end)
  (* "This function raises the Io exception if there is an error in the
     underlying writer or if flushing fails. In the latter case, the stream
     is left open." *)
  val () = eqS (lab "closeOut/Io-when-flushing-fails", "Broken",
                fn () => let val (s, _, broken) = brokenOutstream IO.BLOCK_BUF
                         in output (s, "abc"); broken := true; R.ioRootCause (fn () => S.closeOut s) end)
  val () = eqB (lab "closeOut/left-open-when-flushing-fails", true,
                fn () => let
                           val (s, log, broken) = brokenOutstream IO.BLOCK_BUF
                           val () = output (s, "abc")
                           val () = broken := true
                           val () = ignore (R.ioOf (fn () => S.closeOut s))
                           val () = broken := false
                           val openAfterwards = R.closes log = 0
                         in S.closeOut s; openAfterwards andalso R.closes log = 1 end)

  (* ==== getWriter ==== *)
  (* "flushes the stream f, marks it as being terminated and returns the
     underlying writer and the stream's buffer mode. This raises the
     exception Io if f is closed, or if the flushing fails." *)
  val writerName = RW.writerName
  val () = eqSL (lab "getWriter/writer-and-mode", ["memory", "LINE_BUF"],
                 fn () => let val (w, m) = S.getWriter (#1 (outstream IO.LINE_BUF)) in [writerName w, showMode m] end)
  val () = eqS (lab "getWriter/flushes", "abc",
                fn () => let val (s, log) = outstream IO.BLOCK_BUF in output (s, "abc"); ignore (S.getWriter s); R.written log end)
  val () = eqS (lab "getWriter/the-same-writer", "abcxy",
                fn () => let
                           val (s, log) = outstream IO.NO_BUF
                           val () = output (s, "abc")
                           val (w, _) = S.getWriter s
                           val s' = S.mkOutstream (w, IO.NO_BUF)
                         in output (s', "xy"); R.written log end)
  val () = eqI (lab "getWriter/does-not-close-the-writer", 0,
                fn () => let val (s, log) = outstream IO.NO_BUF in ignore (S.getWriter s); R.closes log end)
  val () = T.raises (lab "getWriter/Io-closed", R.isIo, fn () => let val (s, _) = outstream IO.NO_BUF in S.closeOut s; S.getWriter s end)
  val () = eqS (lab "getWriter/Io-when-flushing-fails", "Broken",
                fn () => let val (s, _, broken) = brokenOutstream IO.BLOCK_BUF
                         in output (s, "abc"); broken := true; R.ioCause (fn () => ignore (S.getWriter s)) end)

  (* ==== getPosOut ==== *)
  (* "This raises the exception Io if the stream does not support the
     operation, if any implicit flushing fails, or if f is terminated." *)
  val () = T.raises (lab "getPosOut/Io-without-positions", R.isIo, fn () => S.getPosOut (#1 (outstream IO.NO_BUF)))
  val () = eqS (lab "getPosOut/Io-cause", "RandomAccessNotSupported",
                fn () => R.ioCause (fn () => ignore (S.getPosOut (#1 (outstream IO.NO_BUF)))))
  val () = T.raises (lab "getPosOut/Io-terminated", R.isIo,
                     fn () => let val (s, _) = outstream IO.NO_BUF in ignore (S.getWriter s); S.getPosOut s end)
end
