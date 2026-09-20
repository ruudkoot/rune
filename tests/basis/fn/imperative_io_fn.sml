(* Checks of the members of IMPERATIVE_IO that convert to and from the
   streams of its StreamIO substructure, and of the imperative operations
   where a reader or writer of one's own shows more than a file does.
   Expected values follow https://smlfamily.github.io/Basis/imperative-io.html.

     structure Generic = TestImperativeIOFn (structure RW = TextRW structure I = TextIO val name = "TextIO" val elemChar = ... val charElem = ...)

   needs spec-sigs/STREAM_IO.sml, spec-sigs/IMPERATIVE_IO.sml and
   fn/io_script.sml, where TextRW : IO_RW is described. The labels are
   name ^ ".member/case"; elements are written as characters (see
   fn/io_script.sml). getPosOut and setPosOut need positions, which the
   instances check themselves (binio_streamio.sml, textio_streamio.sml); here
   only that a stream without them raises Io. *)
functor TestImperativeIOFn (structure RW : IO_RW
                            structure I : SPEC_IMPERATIVE_IO
                              where type StreamIO.vector = RW.vector
                              where type StreamIO.reader = RW.reader where type StreamIO.writer = RW.writer
                            val name : string
                            val elemChar : I.elem -> char
                            val charElem : char -> I.elem) =
struct
  fun lab s = name ^ "." ^ s

  structure R = IOScriptFn (RW)
  val fromString = RW.fromString
  val toString = RW.toString
  structure S = I.StreamIO

  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val eqSL = T.eq (T.list T.string)
  val eqCOL = T.eq (T.list (T.option T.char))

  val empty = fromString ""
  fun functional (pieces : string list) : S.instream * R.log =
    let val (rd, log) = R.reader ("script", pieces) in (S.mkInstream (rd, empty), log) end
  fun imperative (pieces : string list) : I.instream = I.mkInstream (#1 (functional pieces))
  fun inputAll (i : I.instream) : string = toString (I.inputAll i)
  fun input (i : I.instream) : string = toString (I.input i)
  fun inputN (i : I.instream, n : int) : string = toString (I.inputN (i, n))
  fun input1 (i : I.instream) : char option = Option.map elemChar (I.input1 i)
  fun lookahead (i : I.instream) : char option = Option.map elemChar (I.lookahead i)
  fun sInputAll (f : S.instream) : string = toString (#1 (S.inputAll f))
  fun sInput1 (f : S.instream) : (char * S.instream) option =
    case S.input1 f of SOME (e, f') => SOME (elemChar e, f') | NONE => NONE

  fun outstream (mode : IO.buffer_mode) : S.outstream * R.log =
    let val (w, log) = R.writer "memory" in (S.mkOutstream (w, mode), log) end
  fun output (os : I.outstream, s : string) : unit = I.output (os, fromString s)

  (* ==== mkInstream, getInstream, setInstream ==== *)
  (* "constructs a redirectable input stream from a functional one" *)
  val () = eqS (lab "mkInstream/reads-the-functional-stream", "abcde", fn () => inputAll (imperative ["abc", "de"]))
  val () = eqS (lab "mkInstream/from-a-stream-part-read", "cde",
                fn () => let
                           val (f, _) = functional ["abc", "de"]
                           val (_, f') = S.inputN (f, 2)
                         in inputAll (I.mkInstream f') end)
  val () = eqSL (lab "mkInstream/does-not-change-the-functional-stream", ["ab", "ab"],
                 fn () => let val (f, _) = functional ["ab"] in [inputAll (I.mkInstream f), sInputAll f] end)
  (* "returns the current version of the underlying functional input stream
     of strm" *)
  val () = eqS (lab "getInstream/current-version", "bcde",
                fn () => let val i = imperative ["abc", "de"] in ignore (I.input1 i); sInputAll (I.getInstream i) end)
  val () = eqS (lab "getInstream/fresh", "abc", fn () => sInputAll (I.getInstream (imperative ["abc"])))
  (* "After having done so, it may be necessary to reassign the newly
     obtained functional stream to strm using setInstream; otherwise the
     previous input will be read again when reading from strm the next
     time." *)
  val () = eqCOL (lab "getInstream/input-from-it-is-read-again", [SOME #"a", SOME #"a"],
                  fn () => let
                             val i = imperative ["abc"]
                             val direct = case sInput1 (I.getInstream i) of SOME (c, _) => SOME c | NONE => NONE
                           in [direct, input1 i] end)
  (* "assigns a new functional stream strm' to strm. Future input on strm
     will be read from strm'." *)
  val () = eqSL (lab "setInstream/redirects", ["a", "xyz"],
                 fn () => let
                            val i = imperative ["abc"]
                            val a = inputN (i, 1)
                          in I.setInstream (i, #1 (functional ["xyz"])); [a, inputAll i] end)
  val () = eqSL (lab "setInstream/after-getInstream-and-input", ["b", "c"],
                 fn () => let
                            val i = imperative ["abc"]
                            val () = ignore (I.input1 i)
                            val f = I.getInstream i
                          in
                            case S.input1 f of
                              SOME (e, f') => (I.setInstream (i, f'); [str (elemChar e), inputAll i])
                            | NONE => ["NONE"]
                          end)
  (* reread: "Limited random access on input streams [...] can be
     accomplished using getInstream and the underlying Stream I/O layer" *)
  val () = eqSL (lab "setInstream/reread", ["abcd", "abcd", "ef"],
                 fn () => let
                            val f = imperative ["ab", "cd", "ef"]
                            val g = I.getInstream f
                            val s = inputN (f, 4)
                            val () = I.setInstream (f, g)
                            val s' = inputN (f, 4)
                          in [s, s', inputAll f] end)

  (* ==== input1, lookahead, endOfStream with more than one end-of-stream ==== *)
  (* "After a call to input1 returning NONE to indicate an end-of-stream, the
     input stream should be positioned after the end-of-stream." *)
  val () = eqCOL (lab "input1/passes-an-end-of-stream", [SOME #"a", NONE, SOME #"b", NONE],
                  fn () => let val i = imperative ["a", "", "b"]
                               val a = input1 i val b = input1 i val c = input1 i val d = input1 i
                           in [a, b, c, d] end)
  (* lookahead: "e is not removed from strm"; at an end-of-stream it returns
     NONE and removes nothing either: input then consumes the end-of-stream. *)
  val () = eqSL (lab "lookahead/does-not-pass-an-end-of-stream", ["NONE", "NONE", "", "b"],
                 fn () => let
                            val i = imperative ["", "b"]
                            fun show NONE = "NONE" | show (SOME c) = str c
                            val a = show (lookahead i) val b = show (lookahead i) val c = input i
                          in [a, b, c, show (lookahead i)] end)
  (* endOfStream: "After a read from strm to consume the end-of-stream, it is
     possible that the next call to endOfStream strm may return false, and
     input operations will deliver new elements." *)
  val () = eqSL (lab "endOfStream/more-after-an-end-of-stream", ["true", "true", "", "false", "b"],
                 fn () => let
                            val i = imperative ["", "b"]
                            val a = I.endOfStream i
                            val b = I.endOfStream i
                            val c = input i
                            val d = I.endOfStream i
                          in [Bool.toString a, Bool.toString b, c, Bool.toString d, inputAll i] end)
  val () = eqSL (lab "inputAll/up-to-each-end-of-stream", ["abc", "defg", ""],
                 fn () => let val i = imperative ["abc", "", "defg", ""]
                              val a = inputAll i val b = inputAll i val c = inputAll i
                          in [a, b, c] end)

  (* ==== closeIn ==== *)
  (* "Two imperative streams may share an underlying functional stream or
     reader. Closing one of them effectively closes the underlying
     functional stream, which will affect subsequent operations on the
     other." "The function is implemented in terms of StreamIO.closeIn." *)
  val () = eqSL (lab "closeIn/shared-functional-stream", ["", "1"],
                 fn () => let
                            val (f, log) = functional ["abc"]
                            val a = I.mkInstream f
                            val b = I.mkInstream f
                          in I.closeIn a; [inputAll b, Int.toString (R.closes log)] end)
  val () = eqI (lab "closeIn/closes-the-reader", 1,
                fn () => let val (f, log) = functional ["abc"] val i = I.mkInstream f in I.closeIn i; I.closeIn i; R.closes log end)

  (* ==== mkOutstream, getOutstream, setOutstream ==== *)
  (* "constructs a redirectable output stream from a low-level functional
     one. Output to the imperative stream will be redirected to strm." *)
  val () = eqS (lab "mkOutstream/writes-to-the-stream", "abc",
                fn () => let val (s, log) = outstream IO.NO_BUF val os = I.mkOutstream s
                         in output (os, "ab"); I.output1 (os, charElem #"c"); R.written log end)
  val () = eqS (lab "mkOutstream/keeps-the-buffer-mode", "",
                fn () => let val (s, log) = outstream IO.BLOCK_BUF val os = I.mkOutstream s in output (os, "ab"); R.written log end)
  (* "Using getOutstream, it is possible to write output directly to the
     underlying stream" *)
  val () = eqS (lab "getOutstream/the-same-stream", "abc",
                fn () => let
                           val (s, log) = outstream IO.BLOCK_BUF
                           val os = I.mkOutstream s
                         in
                           output (os, "a"); S.output (I.getOutstream os, fromString "b"); output (os, "c");
                           I.flushOut os; R.written log
                         end)
  (* "flushes strm and returns the underlying StreamIO output stream" *)
  val () = eqS (lab "getOutstream/flushes", "ab",
                fn () => let val (s, log) = outstream IO.BLOCK_BUF val os = I.mkOutstream s
                         in output (os, "ab"); ignore (I.getOutstream os); R.written log end)
  (* "flushes the stream underlying strm, and then assigns a new low-level
     stream strm' to it. Future output on strm will be redirected to strm'." *)
  val () = eqSL (lab "setOutstream/redirects", ["ab", "cd"],
                 fn () => let
                            val (s1, log1) = outstream IO.BLOCK_BUF
                            val (s2, log2) = outstream IO.BLOCK_BUF
                            val os = I.mkOutstream s1
                          in
                            output (os, "ab"); I.setOutstream (os, s2); output (os, "cd");
                            S.flushOut s1; I.flushOut os; [R.written log1, R.written log2]
                          end)
  val () = eqS (lab "setOutstream/flushes-the-old-stream", "ab",
                fn () => let
                            val (s1, log1) = outstream IO.BLOCK_BUF
                            val (s2, _) = outstream IO.BLOCK_BUF
                            val os = I.mkOutstream s1
                          in output (os, "ab"); I.setOutstream (os, s2); R.written log1 end)
  (* "to save it and restore it using setOutstream after strm has been
     redirected" *)
  val () = eqSL (lab "setOutstream/save-and-restore", ["ac", "b"],
                 fn () => let
                            val (s1, log1) = outstream IO.NO_BUF
                            val (s2, log2) = outstream IO.NO_BUF
                            val os = I.mkOutstream s1
                            val () = output (os, "a")
                            val saved = I.getOutstream os
                            val () = I.setOutstream (os, s2)
                            val () = output (os, "b")
                            val () = I.setOutstream (os, saved)
                            val () = output (os, "c")
                          in [R.written log1, R.written log2] end)
  (* "Two redirectable streams may share an underlying stream or writer. If
     this is the case, [...] closing it, also affects the other." *)
  val () = T.raises (lab "closeOut/shared-stream", R.isIo,
                     fn () => let val (s, _) = outstream IO.NO_BUF val a = I.mkOutstream s val b = I.mkOutstream s
                              in I.closeOut a; output (b, "x") end)
  val () = eqSL (lab "output/shared-stream", ["abc", "1"],
                 fn () => let val (s, log) = outstream IO.NO_BUF val a = I.mkOutstream s val b = I.mkOutstream s
                          in output (a, "a"); output (b, "b"); output (a, "c"); I.closeOut b; I.closeOut a;
                             [R.written log, Int.toString (R.closes log)] end)
  (* flushOut and closeOut "implemented in terms of" StreamIO.flushOut and
     StreamIO.closeOut *)
  val () = eqSL (lab "flushOut/flushes-the-stream", ["", "abc"],
                 fn () => let val (s, log) = outstream IO.BLOCK_BUF val os = I.mkOutstream s
                          in output (os, "abc"); let val first = R.written log in I.flushOut os; [first, R.written log] end end)
  val () = eqSL (lab "closeOut/flushes-and-closes", ["abc", "1"],
                 fn () => let val (s, log) = outstream IO.BLOCK_BUF val os = I.mkOutstream s
                          in output (os, "abc"); I.closeOut os; [R.written log, Int.toString (R.closes log)] end)

  (* ==== getPosOut, setPosOut ==== *)
  (* "This raises the exception Io if the stream does not support the
     operation" *)
  val () = T.raises (lab "getPosOut/Io-without-positions", R.isIo,
                     fn () => I.getPosOut (I.mkOutstream (#1 (outstream IO.NO_BUF))))
end
