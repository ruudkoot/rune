(* requires: TextIO *)
(* The imperative part of TextIO (signature TEXT_IO, which includes
   IMPERATIVE_IO). Expected values follow the text of
   https://smlfamily.github.io/Basis/text-io.html and
   https://smlfamily.github.io/Basis/imperative-io.html, and, where those pages
   define an operation by the one of the same name in STREAM_IO, of
   https://smlfamily.github.io/Basis/stream-io.html. TextIO.StreamIO and the
   members that convert to and from it are tested elsewhere.

   The files are made in the current directory, which the runner makes a new
   scratch directory; standard input is /dev/null. On the POSIX systems the
   suite runs on a text file holds exactly the characters written to it. *)
structure TestTextIO =
struct
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val eqSO = T.eq (T.option T.string)
  val eqSL = T.eq (T.list T.string)
  val eqSOL = T.eq (T.list (T.option T.string))
  val eqSS = T.eq (T.pair (T.string, T.string))

  (* write (name, s): the file name is created or truncated, and holds s. *)
  fun write (name : string, s : string) : unit =
    let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end

  (* slurp name: what the file holds. *)
  fun slurp (name : string) : string =
    let val ins = TextIO.openIn name val s = TextIO.inputAll ins in TextIO.closeIn ins; s end

  (* reading (name, s, f): f applied to an instream on a new file that holds s. *)
  fun reading (name : string, s : string, f : TextIO.instream -> 'a) : 'a =
    let
      val () = write (name, s)
      val ins = TextIO.openIn name
      val r = f ins
    in
      TextIO.closeIn ins; r
    end

  (* closed (name, s): an instream on a file that holds s, closed at once. *)
  fun closed (name : string, s : string) : TextIO.instream =
    let val () = write (name, s) val ins = TextIO.openIn name in TextIO.closeIn ins; ins end

  (* The Io exception that f () raises, shown field by field. *)
  fun ioOf (f : unit -> unit) = (f (); NONE) handle IO.Io r => SOME r
  fun ioName f = case ioOf f of SOME {name, ...} => name | NONE => "<no Io>"
  fun ioFunction f = case ioOf f of SOME {function, ...} => function | NONE => "<no Io>"
  fun ioCause f =
    case ioOf f of
      SOME {cause = IO.ClosedStream, ...} => "ClosedStream"
    | SOME {cause = OS.SysErr _, ...} => "SysErr"
    | SOME _ => "<another cause>"
    | NONE => "<no Io>"
  val isIo = fn IO.Io _ => true | _ => false

  (* An outstream on name that has been closed after writing s. *)
  fun closedOut (name : string, s : string) : TextIO.outstream =
    let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out; out end

  (* ---- contents ---- *)
  val allChars = fn () => String.implode (List.tabulate (256, Char.chr))

  (* About 230 KB in 8000 lines of different lengths, none like another, so
     that a buffer that is lost, repeated or out of place shows. *)
  fun lineOf (i : int) : string =
    "line " ^ Int.toString i ^ " "
    ^ String.implode (List.tabulate (i mod 37, fn k => Char.chr (97 + (i + k) mod 26))) ^ "\n"
  val bigMemo : string option ref = ref NONE
  fun big () : string =
    case !bigMemo of
      SOME s => s
    | NONE => let val s = String.concat (List.tabulate (8000, lineOf)) in bigMemo := SOME s; s end

  (* modelLines s: what repeated inputLine returns for a stream that holds s:
     "all characters from the current position up to and including the next
     newline"; "If it detects an end-of-stream before the next newline, it
     returns the characters read appended with a newline". *)
  fun modelLines (s : string) : string list =
    let
      fun go [] = []
        | go [last] = if last = "" then [] else [last ^ "\n"]
        | go (f :: rest) = (f ^ "\n") :: go rest
    in
      go (String.fields (fn c => c = #"\n") s)
    end

  (* readLines ins: the lines inputLine returns until NONE; never more calls
     than fuel. *)
  fun readLines (ins : TextIO.instream, fuel : int) : string list =
    if fuel = 0 then ["<inputLine does not reach the end of the stream>"]
    else case TextIO.inputLine ins of
           NONE => []
         | SOME l => l :: readLines (ins, fuel - 1)

  (* randomText n: n characters, with many line ends. *)
  fun randomText (n : int) : string =
    String.implode (List.tabulate (n, fn _ => T.oneOf [#"a", #"b", #"c", #" ", #"\n", #"\n", #"\t", #"\r", #"z", #"~"]))

  (* writeChunks (name, s): s written with output, output1 and flushOut in
     pieces of random sizes up to maxChunk. *)
  fun writeChunks (name : string, s : string, maxChunk : int) : unit =
    let
      val n = String.size s
      val out = TextIO.openOut name
      fun go pos =
        if pos >= n then ()
        else
          let val k = T.range (0, maxChunk)
          in
            if k = 0 then (TextIO.output1 (out, String.sub (s, pos)); go (pos + 1))
            else
              let val len = Int.min (k, n - pos)
              in
                TextIO.output (out, String.substring (s, pos, len));
                if T.range (0, 9) = 0 then TextIO.flushOut out else ();
                go (pos + len)
              end
          end
    in
      go 0; TextIO.closeOut out
    end

  (* ---- a model of reading ----
     runMix (r, s, steps): steps operations chosen at random on the stream r,
     which holds s, each compared with what the specification says for a
     stream that holds s and has been read up to a position; then inputAll
     (that the stream is at its end after inputAll has checks of their own).
     The result is "ok" or a description of the first difference. The
     operations are passed as functions so that a section can supply the ones
     an implementation has. *)
  type reader = {input1 : unit -> char option, inputN : int -> string, inputLine : unit -> string option,
                 lookahead : unit -> char option, endOfStream : unit -> bool, input : unit -> string,
                 canInput : int -> int option, inputAll : unit -> string}

  fun runMix (r : reader, s : string, steps : int, maxN : int) : string =
    let
      val n = String.size s
      val pos = ref 0
      val showC = T.option T.char
      val showS = T.option T.string
      fun lineAt p =
        if p >= n then NONE
        else
          let
            fun find j =
              if j >= n then (String.extract (s, p, NONE) ^ "\n", n)
              else if String.sub (s, j) = #"\n" then (String.substring (s, p, j - p + 1), j + 1)
              else find (j + 1)
          in
            SOME (find p)
          end
      fun step i =
        let
          val p = !pos
          fun bad (what, got, want) =
            "step " ^ Int.toString i ^ ", position " ^ Int.toString p ^ ": " ^ what ^ " gave " ^ got
            ^ ", expected " ^ want
          fun next () = step (i + 1)
        in
          if i = steps then
            let val got = #inputAll r () val want = String.extract (s, p, NONE)
            in
              if got <> want then bad ("inputAll", Int.toString (String.size got) ^ " characters",
                                       Int.toString (String.size want) ^ " characters")
              else "ok"
            end
          else
            case T.range (0, 6) of
              0 => let val got = #input1 r () val want = if p < n then SOME (String.sub (s, p)) else NONE
                   in if got = want then (pos := Int.min (n, p + 1); next ()) else bad ("input1", showC got, showC want) end
            | 1 => let val k = T.range (0, maxN)
                       val got = #inputN r k
                       val want = String.substring (s, p, Int.min (k, n - p))
                   in
                     if got = want then (pos := p + String.size want; next ())
                     else bad ("inputN " ^ Int.toString k, T.string got, T.string want)
                   end
            | 2 => let val got = #inputLine r ()
                   in
                     case lineAt p of
                       NONE => if got = NONE then next () else bad ("inputLine", showS got, "NONE")
                     | SOME (want, p') => if got = SOME want then (pos := p'; next ())
                                          else bad ("inputLine", showS got, showS (SOME want))
                   end
            | 3 => let val got = #lookahead r () val want = if p < n then SOME (String.sub (s, p)) else NONE
                   in if got = want then next () else bad ("lookahead", showC got, showC want) end
            | 4 => let val got = #endOfStream r ()
                   in if got = (p = n) then next () else bad ("endOfStream", T.bool got, T.bool (p = n)) end
            | 5 => let val got = #input r () val len = String.size got
                   in
                     if p = n then (if got = "" then next () else bad ("input", T.string got, "\"\""))
                     else if len = 0 then bad ("input", "\"\"", "at least one character")
                     else if p + len > n orelse String.substring (s, p, len) <> got
                     then bad ("input", T.string got, "the characters that follow")
                     else (pos := p + len; next ())
                   end
            | _ => let val k = T.range (1, 50) val got = #canInput r k
                   in
                     case got of
                       SOME j => if (p = n andalso j = 0) orelse (p < n andalso 1 <= j andalso j <= k) then next ()
                                 else bad ("canInput " ^ Int.toString k, T.option T.int got,
                                           if p = n then "SOME 0" else "SOME j, 1 <= j <= k")
                     | NONE => bad ("canInput " ^ Int.toString k, "NONE", "SOME _ (a file does not block)")
                   end
        end
    in
      step 0
    end

  (* ==== openOut, output, closeOut, openIn, inputAll, closeIn ==== *)
  val () = eqS ("TextIO.openOut/creates-the-file", "hello\n", fn () => (write ("create.txt", "hello\n"); slurp "create.txt"))
  val () = eqS ("TextIO.openOut/truncates-an-existing-file", "x",
                fn () => (write ("trunc.txt", "some longer contents\n"); write ("trunc.txt", "x"); slurp "trunc.txt"))
  val () = eqS ("TextIO.openOut/truncates-at-open", "",
                fn () => (write ("trunc2.txt", "contents\n");
                          let val out = TextIO.openOut "trunc2.txt" val s = slurp "trunc2.txt"
                          in TextIO.closeOut out; s end))
  val () = eqS ("TextIO.openOut/nothing-written", "", fn () => (write ("empty.txt", ""); slurp "empty.txt"))
  val () = T.raises ("TextIO.openOut/Io-directory-does-not-exist", isIo,
                     fn () => TextIO.openOut "no-such-directory/file.txt")
  val () = eqS ("TextIO.openOut/Io-name", "no-such-directory/file.txt",
                fn () => ioName (fn () => TextIO.closeOut (TextIO.openOut "no-such-directory/file.txt")))
  val () = eqS ("TextIO.openOut/Io-function", "openOut",
                fn () => ioFunction (fn () => TextIO.closeOut (TextIO.openOut "no-such-directory/file.txt")))
  val () = eqS ("TextIO.openOut/Io-cause", "SysErr",
                fn () => ioCause (fn () => TextIO.closeOut (TextIO.openOut "no-such-directory/file.txt")))

  val () = eqS ("TextIO.openIn/reads-the-file", "contents\n", fn () => (write ("in.txt", "contents\n"); slurp "in.txt"))
  val () = T.raises ("TextIO.openIn/Io-file-does-not-exist", isIo, fn () => TextIO.openIn "missing.txt")
  val () = eqS ("TextIO.openIn/Io-name", "missing.txt", fn () => ioName (fn () => TextIO.closeIn (TextIO.openIn "missing.txt")))
  val () = eqS ("TextIO.openIn/Io-function", "openIn",
                fn () => ioFunction (fn () => TextIO.closeIn (TextIO.openIn "missing.txt")))
  val () = eqS ("TextIO.openIn/Io-cause", "SysErr", fn () => ioCause (fn () => TextIO.closeIn (TextIO.openIn "missing.txt")))
  (* the type is abstract in the specification; in Rune it is a datatype
     holding a ref, so two streams compare equal exactly when they are one
     (IMPERATIVE_IO.instream/admits-equality) *)
  val () = eqB ("TextIO.instream/equal-when-the-same-stream", true,
                fn () => let val a = TextIO.openString "x"
                             val b = TextIO.openString "x"
                         in a = a andalso a <> b end)
  val () = eqB ("TextIO.openIn/does-not-create-the-file", true,
                fn () => (ignore (ioOf (fn () => TextIO.closeIn (TextIO.openIn "missing.txt")));
                          isSome (ioOf (fn () => TextIO.closeIn (TextIO.openIn "missing.txt")))))
  val () = T.raises ("TextIO.openIn/Io-empty-name", isIo, fn () => TextIO.openIn "")

  (* instream, outstream: several streams on one file each have their own position. *)
  val () = eqSOL ("TextIO.instream/two-on-one-file", [SOME "one\n", SOME "one\n", SOME "two\n", SOME "two\n"],
                  fn () => (write ("two.txt", "one\ntwo\n");
                            let
                              val a : TextIO.instream = TextIO.openIn "two.txt"
                              val b : TextIO.instream = TextIO.openIn "two.txt"
                              val a1 = TextIO.inputLine a
                              val b1 = TextIO.inputLine b
                              val a2 = TextIO.inputLine a
                              val b2 = TextIO.inputLine b
                            in
                              TextIO.closeIn a; TextIO.closeIn b; [a1, b1, a2, b2]
                            end))
  val () = eqSS ("TextIO.outstream/two-files", ("to a", "to b"),
                 fn () => let
                            val a : TextIO.outstream = TextIO.openOut "out-a.txt"
                            val b : TextIO.outstream = TextIO.openOut "out-b.txt"
                          in
                            TextIO.output (a, "to "); TextIO.output (b, "to "); TextIO.output (b, "b");
                            TextIO.output (a, "a"); TextIO.closeOut b; TextIO.closeOut a;
                            (slurp "out-a.txt", slurp "out-b.txt")
                          end)

  (* ==== output, output1 ==== *)
  val () = eqS ("TextIO.output/in-order", "one two three",
                fn () => let val out = TextIO.openOut "output.txt"
                         in
                           TextIO.output (out, "one "); TextIO.output (out, "two "); TextIO.output (out, "three");
                           TextIO.closeOut out; slurp "output.txt"
                         end)
  val () = eqS ("TextIO.output/empty-string", "ab",
                fn () => let val out = TextIO.openOut "output-empty.txt"
                         in
                           TextIO.output (out, ""); TextIO.output (out, "a"); TextIO.output (out, "");
                           TextIO.output (out, "b"); TextIO.output (out, ""); TextIO.closeOut out;
                           slurp "output-empty.txt"
                         end)
  val () = eqB ("TextIO.output/every-character", true,
                fn () => (write ("chars.txt", allChars ()); slurp "chars.txt" = allChars ()))
  val () = eqS ("TextIO.output/no-line-end-translation", "a\r\nb\rc\n\n",
                fn () => (write ("crlf.txt", "a\r\nb\rc\n\n"); slurp "crlf.txt"))
  val () = eqB ("TextIO.output/large", true, fn () => (write ("big.txt", big ()); slurp "big.txt" = big ()))
  val () = eqI ("TextIO.output/large-size", String.size (big ()), fn () => String.size (slurp "big.txt"))
  val () = T.raises ("TextIO.output/Io-closed-stream", isIo,
                     fn () => TextIO.output (closedOut ("closed-out.txt", "kept"), "lost"))
  val () = eqS ("TextIO.output/Io-closed-stream-cause", "ClosedStream",
                fn () => ioCause (fn () => TextIO.output (closedOut ("closed-out.txt", "kept"), "lost")))
  val () = eqS ("TextIO.output/Io-closed-stream-function", "output",
                fn () => ioFunction (fn () => TextIO.output (closedOut ("closed-out.txt", "kept"), "lost")))
  val () = eqS ("TextIO.output/Io-closed-stream-name", "closed-out.txt",
                fn () => ioName (fn () => TextIO.output (closedOut ("closed-out.txt", "kept"), "lost")))
  val () = eqS ("TextIO.output/closed-stream-writes-nothing", "kept",
                fn () => (ignore (ioOf (fn () => TextIO.output (closedOut ("closed-out.txt", "kept"), "lost")));
                          slurp "closed-out.txt"))

  val () = eqS ("TextIO.output1/in-order", "abc",
                fn () => let val out = TextIO.openOut "output1.txt"
                         in
                           TextIO.output1 (out, #"a"); TextIO.output1 (out, #"b"); TextIO.output1 (out, #"c");
                           TextIO.closeOut out; slurp "output1.txt"
                         end)
  val () = eqS ("TextIO.output1/mixed-with-output", "a-bc-d\n",
                fn () => let val out = TextIO.openOut "output1-mixed.txt"
                         in
                           TextIO.output1 (out, #"a"); TextIO.output (out, "-bc-"); TextIO.output1 (out, #"d");
                           TextIO.output1 (out, #"\n"); TextIO.closeOut out; slurp "output1-mixed.txt"
                         end)
  val () = eqB ("TextIO.output1/every-character", true,
                fn () => let val out = TextIO.openOut "output1-chars.txt"
                         in
                           T.repeat (256, fn i => TextIO.output1 (out, Char.chr i));
                           TextIO.closeOut out; slurp "output1-chars.txt" = allChars ()
                         end)
  val () = T.raises ("TextIO.output1/Io-closed-stream", isIo,
                     fn () => TextIO.output1 (closedOut ("closed-out1.txt", "kept"), #"x"))
  val () = eqS ("TextIO.output1/Io-closed-stream-cause", "ClosedStream",
                fn () => ioCause (fn () => TextIO.output1 (closedOut ("closed-out1.txt", "kept"), #"x")))
  val () = eqS ("TextIO.output1/Io-closed-stream-function", "output1",
                fn () => ioFunction (fn () => TextIO.output1 (closedOut ("closed-out1.txt", "kept"), #"x")))
  val () = eqS ("TextIO.output1/Io-closed-stream-name", "closed-out1.txt",
                fn () => ioName (fn () => TextIO.output1 (closedOut ("closed-out1.txt", "kept"), #"x")))

  (* ==== flushOut, closeOut ==== *)
  (* "causes any buffers associated with strm to be written out" *)
  val () = eqSS ("TextIO.flushOut/makes-output-visible", ("abc", "abcdef"),
                 fn () => let
                            val out = TextIO.openOut "flush.txt"
                            val () = TextIO.output (out, "abc")
                            val () = TextIO.flushOut out
                            val first = slurp "flush.txt"
                            val () = TextIO.output (out, "def")
                            val () = TextIO.closeOut out
                          in
                            (first, slurp "flush.txt")
                          end)
  val () = eqS ("TextIO.flushOut/nothing-to-flush", "",
                fn () => let val out = TextIO.openOut "flush-empty.txt"
                         in TextIO.flushOut out; TextIO.flushOut out; TextIO.closeOut out; slurp "flush-empty.txt" end)
  val () = eqS ("TextIO.flushOut/twice", "abab",
                fn () => let val out = TextIO.openOut "flush-twice.txt"
                         in
                           TextIO.output (out, "ab"); TextIO.flushOut out; TextIO.flushOut out;
                           TextIO.output (out, "ab"); TextIO.flushOut out;
                           let val s = slurp "flush-twice.txt" in TextIO.closeOut out; s end
                         end)
  (* STREAM_IO: flushOut "is a no-op on terminated streams", and "A closed
     stream is also terminated". *)
  val () = eqS ("TextIO.flushOut/closed-stream-is-a-no-op", "kept",
                fn () => (TextIO.flushOut (closedOut ("flush-closed.txt", "kept")); slurp "flush-closed.txt"))
  (* "flushes any buffers associated with strm, then closes strm" *)
  val () = eqS ("TextIO.closeOut/flushes", "x", fn () => (write ("close.txt", "x"); slurp "close.txt"))
  (* STREAM_IO.closeOut: "This operation has no effect if f is already closed." *)
  val () = eqS ("TextIO.closeOut/twice", "kept",
                fn () => let val out = closedOut ("close-twice.txt", "kept")
                         in TextIO.closeOut out; TextIO.closeOut out; slurp "close-twice.txt" end)
  val () = eqS ("TextIO.closeOut/other-streams-stay-open", "second",
                fn () => let
                           val a = TextIO.openOut "close-a.txt"
                           val b = TextIO.openOut "close-b.txt"
                         in
                           TextIO.closeOut a; TextIO.output (b, "second"); TextIO.closeOut b; slurp "close-b.txt"
                         end)

  (* ==== openAppend ==== *)
  val () = eqS ("TextIO.openAppend/creates-the-file", "one\n",
                fn () => let val out = TextIO.openAppend "append.txt"
                         in TextIO.output (out, "one\n"); TextIO.closeOut out; slurp "append.txt" end)
  val () = eqS ("TextIO.openAppend/appends-to-an-existing-file", "one\ntwo\n",
                fn () => (write ("append2.txt", "one\n");
                          let val out = TextIO.openAppend "append2.txt"
                          in TextIO.output (out, "two\n"); TextIO.closeOut out; slurp "append2.txt" end))
  val () = eqS ("TextIO.openAppend/keeps-the-contents", "one\n",
                fn () => (write ("append3.txt", "one\n");
                          let val out = TextIO.openAppend "append3.txt" in TextIO.closeOut out; slurp "append3.txt" end))
  val () = eqS ("TextIO.openAppend/three-times", "abc",
                fn () => (List.app (fn s => let val out = TextIO.openAppend "append4.txt"
                                            in TextIO.output (out, s); TextIO.closeOut out end) ["a", "b", "c"];
                          slurp "append4.txt"))
  val () = eqS ("TextIO.openAppend/output1", "one\n!",
                fn () => (write ("append5.txt", "one\n");
                          let val out = TextIO.openAppend "append5.txt"
                          in TextIO.output1 (out, #"!"); TextIO.closeOut out; slurp "append5.txt" end))
  val () = T.raises ("TextIO.openAppend/Io-directory-does-not-exist", isIo,
                     fn () => TextIO.openAppend "no-such-directory/file.txt")
  val () = eqS ("TextIO.openAppend/Io-name", "no-such-directory/file.txt",
                fn () => ioName (fn () => TextIO.closeOut (TextIO.openAppend "no-such-directory/file.txt")))
  val () = eqS ("TextIO.openAppend/Io-function", "openAppend",
                fn () => ioFunction (fn () => TextIO.closeOut (TextIO.openAppend "no-such-directory/file.txt")))
  val () = eqS ("TextIO.openAppend/Io-cause", "SysErr",
                fn () => ioCause (fn () => TextIO.closeOut (TextIO.openAppend "no-such-directory/file.txt")))
  val () = eqS ("TextIO.openAppend/Io-closed-stream", "ClosedStream",
                fn () => ioCause (fn () => let val out = TextIO.openAppend "append6.txt"
                                           in TextIO.closeOut out; TextIO.output (out, "lost") end))

  (* ==== inputAll ==== *)
  val () = eqS ("TextIO.inputAll/whole-file", "a\nb\n", fn () => reading ("all.txt", "a\nb\n", TextIO.inputAll))
  val () = eqS ("TextIO.inputAll/empty-file", "", fn () => reading ("all-empty.txt", "", TextIO.inputAll))
  val () = eqSL ("TextIO.inputAll/again-at-end-of-stream", ["abc", "", "", ""],
                 fn () => reading ("all-again.txt", "abc",
                                   fn ins => let
                                               val a = TextIO.inputAll ins
                                               val b = TextIO.inputAll ins
                                               val c = TextIO.inputAll ins
                                               val d = TextIO.inputAll ins
                                             in [a, b, c, d] end))
  val () = eqS ("TextIO.inputAll/rest-after-inputLine", "bc\nd",
                fn () => reading ("all-rest.txt", "a\nbc\nd", fn ins => (ignore (TextIO.inputLine ins); TextIO.inputAll ins)))
  val () = eqSL ("TextIO.inputAll/empty-after-inputLine-and-inputAll", ["bc\nd", "", ""],
                 fn () => reading ("all-rest2.txt", "a\nbc\nd",
                                   fn ins => let
                                               val _ = TextIO.inputLine ins
                                               val a = TextIO.inputAll ins
                                               val b = TextIO.inputAll ins
                                               val c = TextIO.inputAll ins
                                             in [a, b, c] end))
  val () = eqSO ("TextIO.inputLine/NONE-after-inputLine-and-inputAll", NONE,
                 fn () => reading ("all-rest3.txt", "a\nbc\nd",
                                   fn ins => (ignore (TextIO.inputLine ins); ignore (TextIO.inputAll ins); TextIO.inputLine ins)))
  val () = eqB ("TextIO.inputAll/every-character", true,
                fn () => reading ("all-chars.txt", allChars (), TextIO.inputAll) = allChars ())
  val () = eqB ("TextIO.inputAll/large", true, fn () => reading ("all-big.txt", big (), TextIO.inputAll) = big ())
  val () = eqS ("TextIO.inputAll/no-final-newline-added", "no newline",
                fn () => reading ("all-nonl.txt", "no newline", TextIO.inputAll))

  (* ==== inputLine ==== *)
  val () = eqSOL ("TextIO.inputLine/lines-then-NONE", [SOME "a\n", SOME "bc\n", NONE],
                  fn () => reading ("line.txt", "a\nbc\n",
                                    fn ins => let
                                                val a = TextIO.inputLine ins
                                                val b = TextIO.inputLine ins
                                                val c = TextIO.inputLine ins
                                              in [a, b, c] end))
  val () = eqSOL ("TextIO.inputLine/final-line-gets-newline", [SOME "a\n", SOME "bc\n", NONE],
                  fn () => reading ("line-nonl.txt", "a\nbc",
                                    fn ins => let
                                                val a = TextIO.inputLine ins
                                                val b = TextIO.inputLine ins
                                                val c = TextIO.inputLine ins
                                              in [a, b, c] end))
  val () = eqSO ("TextIO.inputLine/one-character-without-newline", SOME "x\n",
                 fn () => reading ("line-x.txt", "x", TextIO.inputLine))
  val () = eqSO ("TextIO.inputLine/empty-file", NONE, fn () => reading ("line-empty.txt", "", TextIO.inputLine))
  val () = eqSOL ("TextIO.inputLine/NONE-again-at-end-of-stream", [SOME "a\n", NONE, NONE, NONE],
                  fn () => reading ("line-again.txt", "a\n",
                                    fn ins => let
                                                val a = TextIO.inputLine ins
                                                val b = TextIO.inputLine ins
                                                val c = TextIO.inputLine ins
                                                val d = TextIO.inputLine ins
                                              in [a, b, c, d] end))
  val () = eqSOL ("TextIO.inputLine/empty-lines", [SOME "\n", SOME "\n", SOME "x\n", SOME "\n", NONE],
                  fn () => reading ("line-blank.txt", "\n\nx\n\n",
                                    fn ins => let
                                                val a = TextIO.inputLine ins
                                                val b = TextIO.inputLine ins
                                                val c = TextIO.inputLine ins
                                                val d = TextIO.inputLine ins
                                                val e = TextIO.inputLine ins
                                              in [a, b, c, d, e] end))
  val () = eqSOL ("TextIO.inputLine/carriage-return-is-kept", [SOME "a\r\n", SOME "b\rc\n", NONE],
                  fn () => reading ("line-cr.txt", "a\r\nb\rc\n",
                                    fn ins => let
                                                val a = TextIO.inputLine ins
                                                val b = TextIO.inputLine ins
                                                val c = TextIO.inputLine ins
                                              in [a, b, c] end))
  val () = eqSOL ("TextIO.inputLine/NUL-and-high-characters", [SOME "a\000b\n", SOME "\255\000\n", SOME "\000\n", NONE],
                  fn () => reading ("line-nul.txt", "a\000b\n\255\000\n\000",
                                    fn ins => let
                                                val a = TextIO.inputLine ins
                                                val b = TextIO.inputLine ins
                                                val c = TextIO.inputLine ins
                                                val d = TextIO.inputLine ins
                                              in [a, b, c, d] end))
  val () = eqB ("TextIO.inputLine/long-line-without-newline", true,
                fn () => let val long = String.implode (List.tabulate (100000, fn i => Char.chr (97 + i mod 26)))
                         in reading ("line-long.txt", long, TextIO.inputLine) = SOME (long ^ "\n") end)
  val () = eqB ("TextIO.inputLine/large", true,
                fn () => reading ("line-big.txt", big (), fn ins => readLines (ins, 8002)) = List.tabulate (8000, lineOf))
  val () = eqSO ("TextIO.inputLine/after-inputAll", NONE,
                 fn () => reading ("line-after-all.txt", "a\nb\n", fn ins => (ignore (TextIO.inputAll ins); TextIO.inputLine ins)))

  (* ==== closeIn ====
     "Closing an already closed stream will be ignored. Other operations on a
     closed stream will behave as if the stream is at end-of-stream." and
     "Input on a closed stream behaves as though the stream is permanently at
     end-of-stream. Thus, [...] the closeIn function must also replace the
     functional stream with an empty stream." *)
  val () = eqB ("TextIO.closeIn/twice", true,
                fn () => let val ins = closed ("closein.txt", "abc\n") in TextIO.closeIn ins; TextIO.closeIn ins; true end)
  val () = eqS ("TextIO.closeIn/then-inputAll-is-empty", "", fn () => TextIO.inputAll (closed ("closein.txt", "abc\n")))
  val () = eqSO ("TextIO.closeIn/then-inputLine-is-NONE", NONE, fn () => TextIO.inputLine (closed ("closein.txt", "abc\n")))
  val () = eqSL ("TextIO.closeIn/then-inputAll-again", ["", ""],
                 fn () => let val ins = closed ("closein.txt", "abc\n")
                              val a = TextIO.inputAll ins
                              val b = TextIO.inputAll ins
                          in [a, b] end)
  val () = eqS ("TextIO.closeIn/unread-characters-are-dropped", "",
                fn () => (write ("closein-unread.txt", "abc\ndef\nghi\n");
                          let val ins = TextIO.openIn "closein-unread.txt"
                          in ignore (TextIO.inputLine ins); TextIO.closeIn ins; TextIO.inputAll ins end))
  val () = eqSO ("TextIO.closeIn/unread-lines-are-dropped", NONE,
                 fn () => (write ("closein-unread.txt", "abc\ndef\nghi\n");
                           let val ins = TextIO.openIn "closein-unread.txt"
                           in ignore (TextIO.inputLine ins); TextIO.closeIn ins; TextIO.inputLine ins end))
  val () = eqS ("TextIO.closeIn/other-streams-stay-open", "abc\n",
                fn () => (write ("closein-other.txt", "abc\n");
                          let val a = TextIO.openIn "closein-other.txt" val b = TextIO.openIn "closein-other.txt"
                          in TextIO.closeIn a; let val s = TextIO.inputAll b in TextIO.closeIn b; s end end))
  val () = eqS ("TextIO.closeIn/file-can-be-rewritten", "new",
                fn () => (ignore (closed ("closein-rewrite.txt", "old")); write ("closein-rewrite.txt", "new");
                          slurp "closein-rewrite.txt"))

  (* ==== a file that grows ====
     "After a read from strm to consume the end-of-stream, it is possible that
     the next call to endOfStream strm may return false, and input operations
     will deliver new elements." STREAM_IO: "The sequence of strings returned
     from a fresh stream by input is exactly the sequence returned by the
     underlying reader. This includes end-of-stream conditions", and a POSIX
     read returns what has been appended to a file since it reported the end
     of the file. *)
  fun append (name, s) = let val out = TextIO.openAppend name in TextIO.output (out, s); TextIO.closeOut out end
  val () = eqSL ("TextIO.inputAll/file-grows-after-end-of-stream", ["abc", "defg", ""],
                 fn () => (write ("grow.txt", "abc");
                           let
                             val ins = TextIO.openIn "grow.txt"
                             val a = TextIO.inputAll ins
                             val () = append ("grow.txt", "defg")
                             val b = TextIO.inputAll ins
                             val c = TextIO.inputAll ins
                           in
                             TextIO.closeIn ins; [a, b, c]
                           end))
  (* inputLine that returns NONE does not consume the end-of-stream (in
     TEXT_STREAM_IO it returns no residual stream), so it goes on returning
     NONE; the multiple-end-of-stream section reads on. *)
  val () = eqSOL ("TextIO.inputLine/file-grows-after-end-of-stream", [SOME "a\n", NONE, NONE, NONE],
                  fn () => (write ("grow-line.txt", "a\n");
                            let
                              val ins = TextIO.openIn "grow-line.txt"
                              val a = TextIO.inputLine ins
                              val b = TextIO.inputLine ins
                              val () = append ("grow-line.txt", "b\n")
                              val c = TextIO.inputLine ins
                              val d = TextIO.inputLine ins
                            in
                              TextIO.closeIn ins; [a, b, c, d]
                            end))

  (* ==== stdIn, stdOut, stdErr, print ====
     The runner gives the program an empty standard input. What reaches
     standard output and standard error cannot be seen from inside the
     program; standard output carries the results of the checks. *)
  val () = eqSO ("TextIO.stdIn/inputLine-at-end-of-stream", NONE, fn () => TextIO.inputLine TextIO.stdIn)
  val () = eqS ("TextIO.stdIn/inputAll-at-end-of-stream", "", fn () => TextIO.inputAll TextIO.stdIn)
  val () = eqB ("TextIO.stdOut/output-and-flushOut", true,
                fn () => (TextIO.output (TextIO.stdOut, ""); TextIO.flushOut TextIO.stdOut; true))
  val () = eqB ("TextIO.stdOut/is-the-stream-of-print", true,
                fn () => (TextIO.output (TextIO.stdOut, ""); print ""; TextIO.output (TextIO.stdOut, ""); true))
  val () = eqB ("TextIO.stdErr/output-and-flushOut", true,
                fn () => (TextIO.output (TextIO.stdErr, "# written to stderr by tests/basis/textio.sml\n");
                          TextIO.output1 (TextIO.stdErr, #"#"); TextIO.output1 (TextIO.stdErr, #"\n");
                          TextIO.flushOut TextIO.stdErr; true))
  val () = eqB ("TextIO.print/empty-string", true, fn () => (TextIO.print ""; true))
  val () = eqB ("TextIO.print/returns-unit", true, fn () => TextIO.print "" = ())

  (* ==== laws on random contents, for the members above ==== *)
  val () = T.seed 20260918
  val () = T.repeat (12, fn i =>
             eqB ("TextIO.output/random-chunks-" ^ Int.toString i, true,
                  fn () => let
                             val s = randomText (T.range (0, 3000))
                             val name = "random-" ^ Int.toString i ^ ".txt"
                           in
                             writeChunks (name, s, 40); slurp name = s
                           end))
  val () = T.repeat (12, fn i =>
             eqB ("TextIO.inputLine/random-lines-" ^ Int.toString i, true,
                  fn () => let
                             val s = randomText (T.range (0, 3000))
                             val name = "random-lines-" ^ Int.toString i ^ ".txt"
                             val () = writeChunks (name, s, 40)
                             val ins = TextIO.openIn name
                             val lines = readLines (ins, String.size s + 2)
                           in
                             TextIO.closeIn ins; lines = modelLines s
                           end))
  val () = eqB ("TextIO.output/random-chunks-large", true,
                fn () => (writeChunks ("random-big.txt", big (), 20000); slurp "random-big.txt" = big ()))
  val () = eqB ("TextIO.output1/large", true,
                fn () => let
                           val s = String.substring (big (), 0, 70000)
                           val out = TextIO.openOut "output1-big.txt"
                         in
                           T.repeat (70000, fn i => TextIO.output1 (out, String.sub (s, i)));
                           TextIO.closeOut out; slurp "output1-big.txt" = s
                         end)
  val () = eqB ("TextIO.openAppend/random-pieces", true,
                fn () => let
                           val pieces = List.tabulate (20, fn _ => randomText (T.range (0, 200)))
                         in
                           List.app (fn p => append ("append-random.txt", p)) pieces;
                           slurp "append-random.txt" = String.concat pieces
                         end)

  (*<< vector-elem *)
  (* "For text streams, these are Char.char and String.string" *)
  val () = eqS ("TextIO.vector/is-string", "abc",
                fn () => let val v : TextIO.vector = reading ("vector.txt", "abc", TextIO.inputAll) in v end)
  val () = eqS ("TextIO.elem/is-char", "x",
                fn () => let val c : TextIO.elem = #"x" val out = TextIO.openOut "elem.txt"
                         in TextIO.output1 (out, c); TextIO.closeOut out; slurp "elem.txt" end)
  (*>> vector-elem *)

  (*<< input *)
  (* "When elements are available, it returns a vector of at least one
     element. When strm is at end-of-stream or is closed, it returns an empty
     vector." inputs ins: what input returns until the empty string. *)
  fun inputs (ins : TextIO.instream, fuel : int) : string list =
    if fuel = 0 then ["<input does not reach the end of the stream>"]
    else case TextIO.input ins of "" => [] | s => s :: inputs (ins, fuel - 1)
  val () = eqB ("TextIO.input/at-least-one-character", true,
                fn () => reading ("input.txt", "hello",
                                  fn ins => let val s = TextIO.input ins
                                            in String.size s >= 1 andalso String.isPrefix s "hello" end))
  val () = eqS ("TextIO.input/empty-file", "", fn () => reading ("input-empty.txt", "", TextIO.input))
  val () = eqS ("TextIO.input/pieces-make-the-file", "hello\nworld",
                fn () => reading ("input-pieces.txt", "hello\nworld", fn ins => String.concat (inputs (ins, 20))))
  val () = eqSL ("TextIO.input/empty-again-at-end-of-stream", ["", "", ""],
                 fn () => reading ("input-again.txt", "abc",
                                   fn ins => let
                                               val _ = inputs (ins, 10)
                                               val a = TextIO.input ins
                                               val b = TextIO.input ins
                                               val c = TextIO.input ins
                                             in [a, b, c] end))
  val () = eqB ("TextIO.input/large", true,
                fn () => reading ("input-big.txt", big (),
                                  fn ins => String.concat (inputs (ins, String.size (big ()) + 1)) = big ()))
  val () = eqS ("TextIO.input/after-inputLine", "second\n",
                fn () => reading ("input-line.txt", "first\nsecond\n",
                                  fn ins => (ignore (TextIO.inputLine ins); String.concat (inputs (ins, 20)))))
  val () = eqSL ("TextIO.input/empty-after-input-and-inputAll", ["", ""],
                 fn () => reading ("input-all.txt", "hello\nworld\n",
                                   fn ins => let
                                               val _ = TextIO.input ins
                                               val _ = TextIO.inputAll ins
                                               val a = TextIO.input ins
                                               val b = TextIO.inputAll ins
                                             in [a, b] end))
  val () = eqS ("TextIO.input/closed-stream", "", fn () => TextIO.input (closed ("input-closed.txt", "abc")))
  val () = eqS ("TextIO.stdIn/input-at-end-of-stream", "", fn () => TextIO.input TextIO.stdIn)
  (*>> input *)

  (*<< input1 *)
  val eqCOL = T.eq (T.list (T.option T.char))
  val () = eqCOL ("TextIO.input1/characters-then-NONE", [SOME #"a", SOME #"b", NONE],
                  fn () => reading ("input1.txt", "ab",
                                    fn ins => let
                                                val a = TextIO.input1 ins
                                                val b = TextIO.input1 ins
                                                val c = TextIO.input1 ins
                                              in [a, b, c] end))
  val () = eqCOL ("TextIO.input1/empty-file", [NONE], fn () => reading ("input1-empty.txt", "", fn ins => [TextIO.input1 ins]))
  val () = eqCOL ("TextIO.input1/NONE-again-at-end-of-stream", [SOME #"a", NONE, NONE, NONE],
                  fn () => reading ("input1-again.txt", "a",
                                    fn ins => let
                                                val a = TextIO.input1 ins
                                                val b = TextIO.input1 ins
                                                val c = TextIO.input1 ins
                                                val d = TextIO.input1 ins
                                              in [a, b, c, d] end))
  val () = eqCOL ("TextIO.input1/newline-NUL-and-high-characters", [SOME #"\n", SOME #"\000", SOME #"\255", SOME #"\r", NONE],
                  fn () => reading ("input1-chars.txt", "\n\000\255\r",
                                    fn ins => let
                                                val a = TextIO.input1 ins
                                                val b = TextIO.input1 ins
                                                val c = TextIO.input1 ins
                                                val d = TextIO.input1 ins
                                                val e = TextIO.input1 ins
                                              in [a, b, c, d, e] end))
  val () = eqS ("TextIO.input1/removes-one-character", "bc",
                fn () => reading ("input1-rest.txt", "abc", fn ins => (ignore (TextIO.input1 ins); TextIO.inputAll ins)))
  val () = eqSL ("TextIO.inputAll/empty-after-input1-and-inputAll", ["bc", "", ""],
                 fn () => reading ("input1-all.txt", "abc",
                                   fn ins => let
                                               val _ = TextIO.input1 ins
                                               val a = TextIO.inputAll ins
                                               val b = TextIO.inputAll ins
                                               val c = TextIO.inputAll ins
                                             in [a, b, c] end))
  val () = eqCOL ("TextIO.input1/NONE-after-input1-and-inputAll", [NONE],
                  fn () => reading ("input1-all2.txt", "abc",
                                    fn ins => (ignore (TextIO.input1 ins); ignore (TextIO.inputAll ins); [TextIO.input1 ins])))
  val () = eqSO ("TextIO.input1/then-inputLine", SOME "b\n",
                 fn () => reading ("input1-line.txt", "ab\ncd\n", fn ins => (ignore (TextIO.input1 ins); TextIO.inputLine ins)))
  val () = eqB ("TextIO.input1/every-character", true,
                fn () => reading ("input1-all.txt", allChars (),
                                  fn ins => List.tabulate (257, fn _ => TextIO.input1 ins)
                                            = List.tabulate (256, fn i => SOME (Char.chr i)) @ [NONE]))
  val () = eqB ("TextIO.input1/large", true,
                fn () => let val s = String.substring (big (), 0, 70000)
                         in
                           reading ("input1-big.txt", s,
                                    fn ins => let fun go i = if i = 70000 then TextIO.input1 ins = NONE
                                                             else TextIO.input1 ins = SOME (String.sub (s, i)) andalso go (i + 1)
                                              in go 0 end)
                         end)
  val () = eqCOL ("TextIO.input1/closed-stream", [NONE, NONE],
                  fn () => let val ins = closed ("input1-closed.txt", "abc")
                               val a = TextIO.input1 ins
                               val b = TextIO.input1 ins
                           in [a, b] end)
  val () = eqCOL ("TextIO.stdIn/input1-at-end-of-stream", [NONE], fn () => [TextIO.input1 TextIO.stdIn])
  (*>> input1 *)

  (*<< inputN *)
  (* "It returns a vector containing n elements if at least n elements are
     available before end-of-stream; it returns a shorter (and possibly empty)
     vector of all elements remaining before end-of-stream otherwise. [...] It
     raises Size if n < 0 or if n is greater than the maxLen value for the
     vector type." *)
  val () = eqSL ("TextIO.inputN/pieces-then-empty", ["hel", "lo", "", ""],
                 fn () => reading ("inputn.txt", "hello",
                                   fn ins => let
                                               val a = TextIO.inputN (ins, 3)
                                               val b = TextIO.inputN (ins, 3)
                                               val c = TextIO.inputN (ins, 3)
                                               val d = TextIO.inputN (ins, 3)
                                             in [a, b, c, d] end))
  val () = eqSL ("TextIO.inputN/exactly-the-rest", ["hello", ""],
                 fn () => reading ("inputn-exact.txt", "hello",
                                   fn ins => let val a = TextIO.inputN (ins, 5) val b = TextIO.inputN (ins, 1) in [a, b] end))
  val () = eqS ("TextIO.inputN/more-than-there-is", "hello", fn () => reading ("inputn-more.txt", "hello", fn ins => TextIO.inputN (ins, 100)))
  val () = eqS ("TextIO.inputN/one", "h", fn () => reading ("inputn-one.txt", "hello", fn ins => TextIO.inputN (ins, 1)))
  (* STREAM_IO: "inputN(f,0) returns immediately with an empty vector and f" *)
  val () = eqSL ("TextIO.inputN/zero-reads-nothing", ["", "", "hello", ""],
                 fn () => reading ("inputn-zero.txt", "hello",
                                   fn ins => let
                                               val a = TextIO.inputN (ins, 0)
                                               val b = TextIO.inputN (ins, 0)
                                               val c = TextIO.inputAll ins
                                               val d = TextIO.inputN (ins, 0)
                                             in [a, b, c, d] end))
  val () = eqSL ("TextIO.inputN/empty-after-inputN-and-inputAll", ["lo", "", ""],
                 fn () => reading ("inputn-all.txt", "hello",
                                   fn ins => let
                                               val _ = TextIO.inputN (ins, 3)
                                               val a = TextIO.inputAll ins
                                               val b = TextIO.inputN (ins, 3)
                                               val c = TextIO.inputAll ins
                                             in [a, b, c] end))
  val () = eqS ("TextIO.inputN/empty-file", "", fn () => reading ("inputn-empty.txt", "", fn ins => TextIO.inputN (ins, 10)))
  val () = eqS ("TextIO.inputN/does-not-stop-at-a-newline", "a\nb\nc", fn () => reading ("inputn-nl.txt", "a\nb\nc\n", fn ins => TextIO.inputN (ins, 5)))
  val () = T.raises ("TextIO.inputN/Size-negative", T.isSize, fn () => reading ("inputn-size.txt", "hello", fn ins => TextIO.inputN (ins, ~1)))
  val () = T.raises ("TextIO.inputN/Size-negative-at-end-of-stream", T.isSize,
                     fn () => reading ("inputn-size2.txt", "", fn ins => TextIO.inputN (ins, ~5)))
  val () = eqS ("TextIO.inputN/negative-reads-nothing", "hello",
                fn () => reading ("inputn-size3.txt", "hello",
                                  fn ins => ((ignore (TextIO.inputN (ins, ~1))) handle _ => (); TextIO.inputAll ins)))
  (* IMPERATIVE_IO says "It raises Size [...] if n is greater than the maxLen
     value for the vector type", STREAM_IO, which defines the operation, "if
     [...] the number of elements to be returned is greater than maxLen". The
     hosts in which an int greater than String.maxSize exists take the second
     reading, and so does this check. *)
  val () = eqS ("TextIO.inputN/more-than-maxSize-of-a-short-file", "hello",
                fn () => let
                           val tooLong = case Int.maxInt of
                                           NONE => SOME (String.maxSize + 1)
                                         | SOME m => if String.maxSize < m then SOME (String.maxSize + 1) else NONE
                         in
                           case tooLong of
                             NONE => "hello"
                           | SOME n => reading ("inputn-size4.txt", "hello", fn ins => TextIO.inputN (ins, n))
                         end)
  val () = eqB ("TextIO.inputN/large", true,
                fn () => reading ("inputn-big.txt", big (),
                                  fn ins => let
                                              val s = big ()
                                              val n = String.size s
                                              val a = TextIO.inputN (ins, 70000)
                                              val b = TextIO.inputN (ins, 1)
                                              val c = TextIO.inputN (ins, 100000)
                                              val d = TextIO.inputN (ins, n)
                                            in
                                              a = String.substring (s, 0, 70000) andalso b = String.substring (s, 70000, 1)
                                              andalso c = String.substring (s, 70001, 100000)
                                              andalso d = String.extract (s, 170001, NONE)
                                            end))
  val () = eqSL ("TextIO.inputN/closed-stream", ["", ""],
                 fn () => let val ins = closed ("inputn-closed.txt", "abc")
                              val a = TextIO.inputN (ins, 2)
                              val b = TextIO.inputN (ins, 0)
                          in [a, b] end)
  (*>> inputN *)

  (*<< lookahead *)
  (* "In the former case, e is not removed from strm but stays available for
     further input operations." *)
  val eqCOL' = T.eq (T.list (T.option T.char))
  val () = eqCOL' ("TextIO.lookahead/does-not-remove", [SOME #"x", SOME #"x", SOME #"x"],
                   fn () => reading ("look.txt", "xy",
                                     fn ins => let
                                                 val a = TextIO.lookahead ins
                                                 val b = TextIO.lookahead ins
                                                 val c = TextIO.lookahead ins
                                               in [a, b, c] end))
  val () = eqS ("TextIO.lookahead/then-inputAll", "xy",
                fn () => reading ("look-all.txt", "xy", fn ins => (ignore (TextIO.lookahead ins); TextIO.inputAll ins)))
  val () = eqSL ("TextIO.inputAll/empty-after-lookahead-and-inputAll", ["xy", "", ""],
                 fn () => reading ("look-all2.txt", "xy",
                                   fn ins => let
                                               val _ = TextIO.lookahead ins
                                               val a = TextIO.inputAll ins
                                               val b = TextIO.inputAll ins
                                               val c = TextIO.inputAll ins
                                             in [a, b, c] end))
  val () = eqCOL' ("TextIO.lookahead/NONE-after-lookahead-and-inputAll", [NONE],
                   fn () => reading ("look-all3.txt", "xy",
                                     fn ins => (ignore (TextIO.lookahead ins); ignore (TextIO.inputAll ins); [TextIO.lookahead ins])))
  val () = eqSO ("TextIO.lookahead/then-inputLine", SOME "xy\n",
                 fn () => reading ("look-line.txt", "xy\nz\n", fn ins => (ignore (TextIO.lookahead ins); TextIO.inputLine ins)))
  val () = eqCOL' ("TextIO.lookahead/empty-file", [NONE, NONE],
                   fn () => reading ("look-empty.txt", "",
                                     fn ins => let val a = TextIO.lookahead ins val b = TextIO.lookahead ins in [a, b] end))
  val () = eqCOL' ("TextIO.lookahead/after-each-line", [SOME #"a", SOME #"b", NONE],
                   fn () => reading ("look-lines.txt", "a\nb\n",
                                     fn ins => let
                                                 val a = TextIO.lookahead ins
                                                 val _ = TextIO.inputLine ins
                                                 val b = TextIO.lookahead ins
                                                 val _ = TextIO.inputLine ins
                                                 val c = TextIO.lookahead ins
                                               in [a, b, c] end))
  val () = eqCOL' ("TextIO.lookahead/newline-and-NUL", [SOME #"\n", SOME #"\000"],
                   fn () => let
                              val a = reading ("look-nl.txt", "\nx", TextIO.lookahead)
                              val b = reading ("look-nul.txt", "\000x", TextIO.lookahead)
                            in [a, b] end)
  val () = eqCOL' ("TextIO.lookahead/closed-stream", [NONE], fn () => [TextIO.lookahead (closed ("look-closed.txt", "abc"))])
  (*>> lookahead *)

  (*<< endOfStream *)
  (* "returns true if strm is at end-of-stream, and false if elements are
     still available" *)
  val eqBL = T.eq (T.list T.bool)
  val () = eqB ("TextIO.endOfStream/empty-file", true, fn () => reading ("eos-empty.txt", "", TextIO.endOfStream))
  val () = eqB ("TextIO.endOfStream/characters-available", false, fn () => reading ("eos.txt", "a", TextIO.endOfStream))
  val () = eqS ("TextIO.endOfStream/removes-nothing", "abc",
                fn () => reading ("eos-keep.txt", "abc", fn ins => (ignore (TextIO.endOfStream ins); TextIO.inputAll ins)))
  val () = eqSL ("TextIO.inputAll/empty-after-endOfStream-and-inputAll", ["abc", "", ""],
                 fn () => reading ("eos-all2.txt", "abc",
                                   fn ins => let
                                               val _ = TextIO.endOfStream ins
                                               val a = TextIO.inputAll ins
                                               val b = TextIO.inputAll ins
                                               val c = TextIO.inputAll ins
                                             in [a, b, c] end))
  val () = eqBL ("TextIO.endOfStream/true-after-endOfStream-and-inputAll", [false, true],
                 fn () => reading ("eos-all3.txt", "abc",
                                   fn ins => let
                                               val a = TextIO.endOfStream ins
                                               val _ = TextIO.inputAll ins
                                               val b = TextIO.endOfStream ins
                                             in [a, b] end))
  val () = eqBL ("TextIO.endOfStream/around-each-line", [false, false, true, true],
                 fn () => reading ("eos-lines.txt", "a\nb",
                                   fn ins => let
                                               val a = TextIO.endOfStream ins
                                               val _ = TextIO.inputLine ins
                                               val b = TextIO.endOfStream ins
                                               val _ = TextIO.inputLine ins
                                               val c = TextIO.endOfStream ins
                                               val d = TextIO.endOfStream ins
                                             in [a, b, c, d] end))
  val () = eqBL ("TextIO.endOfStream/after-inputAll", [true, true],
                 fn () => reading ("eos-all.txt", "abc",
                                   fn ins => let
                                               val _ = TextIO.inputAll ins
                                               val a = TextIO.endOfStream ins
                                               val b = TextIO.endOfStream ins
                                             in [a, b] end))
  val () = eqSO ("TextIO.endOfStream/true-then-inputLine-is-NONE", NONE,
                 fn () => reading ("eos-then-line.txt", "",
                                   fn ins => if TextIO.endOfStream ins then TextIO.inputLine ins else SOME "<not at the end>"))
  val () = eqB ("TextIO.endOfStream/closed-stream", true, fn () => TextIO.endOfStream (closed ("eos-closed.txt", "abc")))
  val () = eqB ("TextIO.stdIn/endOfStream", true, fn () => TextIO.endOfStream TextIO.stdIn)
  (*>> endOfStream *)

  (*<< canInput *)
  (* "returns NONE if any attempt at input would block. It returns SOME(k),
     where 0 <= k <= n, if a call to input would return immediately with at
     least k characters. Note that k = 0 corresponds to the stream being at
     end-of-stream. [...] It raises the Size exception if n < 0." Reading a
     file does not block. *)
  val eqIO = T.eq (T.option T.int)
  val () = eqB ("TextIO.canInput/characters-available", true,
                fn () => reading ("can.txt", "hello",
                                  fn ins => case TextIO.canInput (ins, 3) of SOME k => 1 <= k andalso k <= 3 | NONE => false))
  val () = eqIO ("TextIO.canInput/one", SOME 1, fn () => reading ("can-one.txt", "hello", fn ins => TextIO.canInput (ins, 1)))
  val () = eqB ("TextIO.canInput/more-than-there-is", true,
                fn () => reading ("can-more.txt", "hello",
                                  fn ins => case TextIO.canInput (ins, 100) of SOME k => 1 <= k andalso k <= 5 | NONE => false))
  val () = eqIO ("TextIO.canInput/empty-file", SOME 0, fn () => reading ("can-empty.txt", "", fn ins => TextIO.canInput (ins, 10)))
  val () = eqIO ("TextIO.canInput/at-end-of-stream", SOME 0,
                 fn () => reading ("can-eos.txt", "abc", fn ins => (ignore (TextIO.inputAll ins); TextIO.canInput (ins, 10))))
  val () = eqS ("TextIO.canInput/removes-nothing", "hello",
                fn () => reading ("can-keep.txt", "hello", fn ins => (ignore (TextIO.canInput (ins, 3)); TextIO.inputAll ins)))
  val () = eqSL ("TextIO.inputAll/empty-after-canInput-and-inputAll", ["hello", "", ""],
                 fn () => reading ("can-all.txt", "hello",
                                   fn ins => let
                                               val _ = TextIO.canInput (ins, 3)
                                               val a = TextIO.inputAll ins
                                               val b = TextIO.inputAll ins
                                               val c = TextIO.inputAll ins
                                             in [a, b, c] end))
  val () = eqIO ("TextIO.canInput/zero", SOME 0, fn () => reading ("can-zero.txt", "hello", fn ins => TextIO.canInput (ins, 0)))
  val () = T.raises ("TextIO.canInput/Size-negative", T.isSize,
                     fn () => reading ("can-size.txt", "hello", fn ins => TextIO.canInput (ins, ~1)))
  val () = eqIO ("TextIO.canInput/closed-stream", SOME 0, fn () => TextIO.canInput (closed ("can-closed.txt", "abc"), 10))
  (*>> canInput *)

  (*<< openString *)
  (* "creates an input stream whose content is s" *)
  val eqSOL' = T.eq (T.list (T.option T.string))
  val () = eqS ("TextIO.openString/inputAll", "hello\nworld", fn () => TextIO.inputAll (TextIO.openString "hello\nworld"))
  val () = eqS ("TextIO.openString/empty", "", fn () => TextIO.inputAll (TextIO.openString ""))
  val () = eqSOL' ("TextIO.openString/empty-inputLine", [NONE, NONE],
                   fn () => let val ins = TextIO.openString ""
                                val a = TextIO.inputLine ins
                                val b = TextIO.inputLine ins
                            in [a, b] end)
  val () = eqSOL' ("TextIO.openString/inputLine", [SOME "a\n", SOME "b\n", NONE, NONE],
                   fn () => let val ins = TextIO.openString "a\nb"
                                val a = TextIO.inputLine ins
                                val b = TextIO.inputLine ins
                                val c = TextIO.inputLine ins
                                val d = TextIO.inputLine ins
                            in [a, b, c, d] end)
  val () = eqSOL' ("TextIO.openString/streams-are-independent", [SOME "a\n", SOME "a\n", SOME "b\n"],
                   fn () => let val s = "a\nb\n"
                                val ins1 = TextIO.openString s
                                val ins2 = TextIO.openString s
                                val a = TextIO.inputLine ins1
                                val b = TextIO.inputLine ins2
                                val c = TextIO.inputLine ins1
                            in [a, b, c] end)
  val () = eqB ("TextIO.openString/every-character", true, fn () => TextIO.inputAll (TextIO.openString (allChars ())) = allChars ())
  val () = eqB ("TextIO.openString/large", true,
                fn () => readLines (TextIO.openString (big ()), 8002) = List.tabulate (8000, lineOf))
  val () = eqS ("TextIO.openString/inputAll-twice", "",
                fn () => let val ins = TextIO.openString "abc" in ignore (TextIO.inputAll ins); TextIO.inputAll ins end)
  val () = eqS ("TextIO.openString/closeIn", "",
                fn () => let val ins = TextIO.openString "abc" in TextIO.closeIn ins; TextIO.closeIn ins; TextIO.inputAll ins end)
  val () = T.repeat (8, fn i =>
             eqB ("TextIO.openString/random-lines-" ^ Int.toString i, true,
                  fn () => let val s = randomText (T.range (0, 2000))
                           in readLines (TextIO.openString s, String.size s + 2) = modelLines s end))
  (*>> openString *)

  (*<< outputSubstr *)
  (* "This is equivalent to: output (strm, Substring.string ss)" *)
  fun writeSubstrs (name : string, l : substring list) : string =
    let val out = TextIO.openOut name in List.app (fn ss => TextIO.outputSubstr (out, ss)) l; TextIO.closeOut out; slurp name end
  val () = eqS ("TextIO.outputSubstr/part-of-a-string", "world",
                fn () => writeSubstrs ("substr.txt", [Substring.substring ("hello world!", 6, 5)]))
  val () = eqS ("TextIO.outputSubstr/whole-string", "hello", fn () => writeSubstrs ("substr-full.txt", [Substring.full "hello"]))
  val () = eqS ("TextIO.outputSubstr/empty", "", fn () => writeSubstrs ("substr-empty.txt", [Substring.substring ("hello", 2, 0)]))
  val () = eqS ("TextIO.outputSubstr/in-order", "lo, hel\n",
                fn () => writeSubstrs ("substr-order.txt",
                                       [Substring.extract ("hello", 3, NONE), Substring.full ", ",
                                        Substring.substring ("hello", 0, 3), Substring.full "\n"]))
  val () = eqS ("TextIO.outputSubstr/mixed-with-output", "<ell>",
                fn () => let val out = TextIO.openOut "substr-mixed.txt"
                         in
                           TextIO.output (out, "<"); TextIO.outputSubstr (out, Substring.substring ("hello", 1, 3));
                           TextIO.output1 (out, #">"); TextIO.closeOut out; slurp "substr-mixed.txt"
                         end)
  val () = eqB ("TextIO.outputSubstr/large", true,
                fn () => writeSubstrs ("substr-big.txt", [Substring.substring ("x" ^ big () ^ "y", 1, String.size (big ()))]) = big ())
  val () = eqS ("TextIO.outputSubstr/Io-closed-stream-cause", "ClosedStream",
                fn () => ioCause (fn () => TextIO.outputSubstr (closedOut ("substr-closed.txt", "kept"), Substring.full "lost")))
  (* "The name of the function raising the exception" is outputSubstr, but
     outputSubstr "is equivalent to" a call of output, which raises Io with
     the function output. MLton and Poly/ML report output, SML/NJ
     outputSubstr; the check takes the reading of the majority. *)
  val () = eqS ("TextIO.outputSubstr/Io-closed-stream-function", "output",
                fn () => ioFunction (fn () => TextIO.outputSubstr (closedOut ("substr-closed.txt", "kept"), Substring.full "lost")))
  val () = eqS ("TextIO.outputSubstr/Io-closed-stream-name", "substr-closed.txt",
                fn () => ioName (fn () => TextIO.outputSubstr (closedOut ("substr-closed.txt", "kept"), Substring.full "lost")))
  (*>> outputSubstr *)

  (*<< scanStream *)
  (* "converts a stream-based scan function into one that works on Imperative
     I/O streams"; by the implementation given, the stream advances to where
     the scan function stopped when it returns SOME, and not at all when it
     returns NONE ("assures that input is not inadvertently lost due to
     lookahead during scanning"). *)
  val eqIS = T.eq (T.pair (T.option T.int, T.string))
  fun scanInt ins = TextIO.scanStream (Int.scan StringCvt.DEC) ins
  val () = eqIS ("TextIO.scanStream/number-then-rest", (SOME 42, " rest\n"),
                 fn () => reading ("scan.txt", "  42 rest\n", fn ins => let val v = scanInt ins in (v, TextIO.inputAll ins) end))
  val () = eqIS ("TextIO.scanStream/stops-before-the-first-other-character", (SOME 12, "x"),
                 fn () => reading ("scan-stop.txt", "12x", fn ins => let val v = scanInt ins in (v, TextIO.inputAll ins) end))
  val () = eqIS ("TextIO.scanStream/negative-number", (SOME ~7, "\n"),
                 fn () => reading ("scan-neg.txt", "~7\n", fn ins => let val v = scanInt ins in (v, TextIO.inputAll ins) end))
  val () = eqIS ("TextIO.scanStream/NONE-reads-nothing", (NONE, "abc"),
                 fn () => reading ("scan-none.txt", "abc", fn ins => let val v = scanInt ins in (v, TextIO.inputAll ins) end))
  val () = eqIS ("TextIO.scanStream/NONE-keeps-skipped-whitespace", (NONE, "  \n x1"),
                 fn () => reading ("scan-space.txt", "  \n x1", fn ins => let val v = scanInt ins in (v, TextIO.inputAll ins) end))
  val () = eqIS ("TextIO.scanStream/NONE-keeps-a-sign", (NONE, "~x"),
                 fn () => reading ("scan-sign.txt", "~x", fn ins => let val v = scanInt ins in (v, TextIO.inputAll ins) end))
  val () = eqIS ("TextIO.scanStream/empty-file", (NONE, ""),
                 fn () => reading ("scan-empty.txt", "", fn ins => let val v = scanInt ins in (v, TextIO.inputAll ins) end))
  val () = eqIS ("TextIO.scanStream/number-up-to-end-of-stream", (SOME 123, ""),
                 fn () => reading ("scan-eos.txt", "123", fn ins => let val v = scanInt ins in (v, TextIO.inputAll ins) end))
  val () = T.eq (T.list (T.option T.int)) ("TextIO.scanStream/one-after-another", [SOME 1, SOME 22, SOME 333, NONE, NONE],
                 fn () => reading ("scan-seq.txt", "1 22\n333\n",
                                   fn ins => let
                                               val a = scanInt ins
                                               val b = scanInt ins
                                               val c = scanInt ins
                                               val d = scanInt ins
                                               val e = scanInt ins
                                             in [a, b, c, d, e] end))
  val () = T.eq (T.pair (T.option T.int, T.option T.string)) ("TextIO.scanStream/then-inputLine", (SOME 5, SOME " apples\n"),
                 fn () => reading ("scan-line.txt", "5 apples\n6 pears\n",
                                   fn ins => let val v = scanInt ins in (v, TextIO.inputLine ins) end))
  (* Scan functions of our own: two characters or nothing; one character
     after looking at three; nothing read at all. *)
  fun two getc strm =
    case getc strm of
      NONE => NONE
    | SOME (a, strm1) => (case getc strm1 of
                            NONE => NONE
                          | SOME (b, strm2) => SOME (String.implode [a, b], strm2))
  fun firstOfThree getc strm =
    case getc strm of
      NONE => NONE
    | SOME (a, strm1) => (case getc strm1 of
                            NONE => NONE
                          | SOME (_, strm2) => (case getc strm2 of NONE => NONE | SOME _ => SOME (a, strm1)))
  fun nothing (_ : (char, 'strm) StringCvt.reader) (strm : 'strm) = SOME (7, strm)
  val eqSS' = T.eq (T.pair (T.option T.string, T.string))
  val () = eqSS' ("TextIO.scanStream/own-scanner", (SOME "xy", "z"),
                  fn () => reading ("scan-two.txt", "xyz", fn ins => let val v = TextIO.scanStream two ins in (v, TextIO.inputAll ins) end))
  val () = eqSS' ("TextIO.scanStream/own-scanner-fails-at-end-of-stream", (NONE, "x"),
                  fn () => reading ("scan-two-eos.txt", "x", fn ins => let val v = TextIO.scanStream two ins in (v, TextIO.inputAll ins) end))
  val () = T.eq (T.pair (T.option T.char, T.string)) ("TextIO.scanStream/lookahead-is-not-lost", (SOME #"a", "bcdef"),
                  fn () => reading ("scan-ahead.txt", "abcdef",
                                    fn ins => let val v = TextIO.scanStream firstOfThree ins in (v, TextIO.inputAll ins) end))
  val () = eqIS ("TextIO.scanStream/scanner-that-reads-nothing", (SOME 7, "abc"),
                 fn () => reading ("scan-nothing.txt", "abc", fn ins => let val v = TextIO.scanStream nothing ins in (v, TextIO.inputAll ins) end))
  val () = eqIS ("TextIO.scanStream/closed-stream", (NONE, ""),
                 fn () => let val ins = closed ("scan-closed.txt", "42") val v = scanInt ins in (v, TextIO.inputAll ins) end)
  (* 30000 numbers, more than any buffer holds. *)
  val () = T.eq (T.pair (T.int, T.int)) ("TextIO.scanStream/large", (30000, 449985000 mod 1000003),
                 fn () => reading ("scan-big.txt", String.concat (List.tabulate (30000, fn i => Int.toString i ^ (if i mod 7 = 0 then "\n" else " "))),
                                   fn ins => let
                                               fun go (count, sum) =
                                                 if count > 30000 then (count, sum)
                                                 else case scanInt ins of
                                                        NONE => (count, sum)
                                                      | SOME v => if v = count then go (count + 1, (sum + v) mod 1000003)
                                                                  else (~1, v)
                                             in go (0, 0) end))
  (*>> scanStream *)

  (*<< mixed *)
  (* Every input operation, in a random order, on random contents. *)
  fun fileReader (ins : TextIO.instream) : reader =
    {input1 = fn () => TextIO.input1 ins, inputN = fn n => TextIO.inputN (ins, n),
     inputLine = fn () => TextIO.inputLine ins, lookahead = fn () => TextIO.lookahead ins,
     endOfStream = fn () => TextIO.endOfStream ins, input = fn () => TextIO.input ins,
     canInput = fn n => TextIO.canInput (ins, n), inputAll = fn () => TextIO.inputAll ins}
  val () = T.seed 918
  val () = T.repeat (16, fn i =>
             eqS ("TextIO.inputN/random-mix-of-operations-" ^ Int.toString i, "ok",
                  fn () => let
                             val s = randomText (T.range (0, 4000))
                             val name = "mix-" ^ Int.toString i ^ ".txt"
                             val () = writeChunks (name, s, 60)
                             val ins = TextIO.openIn name
                             val r = runMix (fileReader ins, s, T.range (0, 400), 300)
                           in
                             TextIO.closeIn ins; r
                           end))
  val () = T.repeat (3, fn i =>
             eqS ("TextIO.inputN/random-mix-of-operations-large-" ^ Int.toString i, "ok",
                  fn () => let
                             val name = "mix-big-" ^ Int.toString i ^ ".txt"
                             val () = write (name, big ())
                             val ins = TextIO.openIn name
                             val r = runMix (fileReader ins, big (), 150, 9000)
                           in
                             TextIO.closeIn ins; r
                           end))
  (*>> mixed *)

  (*<< mixed-openString *)
  fun stringReader (ins : TextIO.instream) : reader =
    {input1 = fn () => TextIO.input1 ins, inputN = fn n => TextIO.inputN (ins, n),
     inputLine = fn () => TextIO.inputLine ins, lookahead = fn () => TextIO.lookahead ins,
     endOfStream = fn () => TextIO.endOfStream ins, input = fn () => TextIO.input ins,
     canInput = fn n => TextIO.canInput (ins, n), inputAll = fn () => TextIO.inputAll ins}
  val () = T.seed 919
  val () = T.repeat (8, fn i =>
             eqS ("TextIO.openString/random-mix-of-operations-" ^ Int.toString i, "ok",
                  fn () => let val s = randomText (T.range (0, 4000))
                           in runMix (stringReader (TextIO.openString s), s, T.range (0, 400), 300) end))
  val () = eqS ("TextIO.openString/random-mix-of-operations-large", "ok",
                fn () => runMix (stringReader (TextIO.openString (big ())), big (), 150, 9000))
  (*>> mixed-openString *)

  (*<< multiple-end-of-stream *)
  (* A file that grows (see above), read with the other operations.
     "After a call to input1 returning NONE to indicate an end-of-stream, the
     input stream should be positioned after the end-of-stream." *)
  fun append' (name, s) = let val out = TextIO.openAppend name in TextIO.output (out, s); TextIO.closeOut out end
  val () = T.eq (T.list (T.option T.char)) ("TextIO.input1/file-grows-after-end-of-stream", [SOME #"a", NONE, SOME #"z", NONE],
                 fn () => (write ("grow1.txt", "a");
                           let
                             val ins = TextIO.openIn "grow1.txt"
                             val a = TextIO.input1 ins
                             val b = TextIO.input1 ins
                             val () = append' ("grow1.txt", "z")
                             val c = TextIO.input1 ins
                             val d = TextIO.input1 ins
                           in
                             TextIO.closeIn ins; [a, b, c, d]
                           end))
  (* inputLine finds the end-of-stream and leaves it; input consumes it. *)
  val () = eqSL ("TextIO.inputLine/reads-on-after-a-consumed-end-of-stream", ["a\n", "NONE", "NONE", "", "b\n", "NONE"],
                 fn () => (write ("grow3.txt", "a\n");
                           let
                             fun line ins = case TextIO.inputLine ins of SOME l => l | NONE => "NONE"
                             val ins = TextIO.openIn "grow3.txt"
                             val a = line ins
                             val b = line ins
                             val () = append' ("grow3.txt", "b\n")
                             val c = line ins
                             val d = TextIO.input ins
                             val e = line ins
                             val f = line ins
                           in
                             TextIO.closeIn ins; [a, b, c, d, e, f]
                           end))
  (* endOfStream does not consume the end-of-stream it finds ("When
     endOfStream returns true on an untruncated stream, this denotes the
     current situation. After a read from strm to consume the end-of-stream
     [...]"): it stays true until a read has consumed it, and that read
     returns the empty string. *)
  val () = eqSL ("TextIO.endOfStream/file-grows-after-end-of-stream", ["true", "true", "", "false", "new"],
                 fn () => (write ("grow2.txt", "");
                           let
                             val ins = TextIO.openIn "grow2.txt"
                             val a = TextIO.endOfStream ins
                             val () = append' ("grow2.txt", "new")
                             val b = TextIO.endOfStream ins
                             val c = TextIO.input ins
                             val d = TextIO.endOfStream ins
                             val e = TextIO.inputAll ins
                           in
                             TextIO.closeIn ins; [Bool.toString a, Bool.toString b, c, Bool.toString d, e]
                           end))
  (*>> multiple-end-of-stream *)

  (* A stream that is still open when the program ends: "All streams created
     by [...] the open functions in TextIO will be closed (and the output
     streams among them flushed) when the SML program exits." The runner does
     not look at the file, left-open.txt, which must hold "flushed at exit\n"
     afterwards. *)
  val leftOpen : TextIO.outstream option ref = ref NONE
  val () = eqB ("TextIO.openOut/left-open-at-exit", true,
                fn () => let val out = TextIO.openOut "left-open.txt"
                         in leftOpen := SOME out; TextIO.output (out, "flushed at exit\n"); true end)
end
