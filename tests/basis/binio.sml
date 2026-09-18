(* requires: BinIO Word8 Word8Vector TextIO *)
(* The imperative part of BinIO (signature BIN_IO, which includes
   IMPERATIVE_IO). Expected values follow the text of
   https://smlfamily.github.io/Basis/bin-io.html and
   https://smlfamily.github.io/Basis/imperative-io.html, and, where those pages
   define an operation by the one of the same name in STREAM_IO, of
   https://smlfamily.github.io/Basis/stream-io.html. BinIO.StreamIO and the
   members that convert to and from it are tested elsewhere.

   Bytes are written as ints: vec [1, 2] is the vector of the bytes 1 and 2.
   The files are made in the current directory, which the runner makes a new
   scratch directory. *)
structure TestBinIO =
struct
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val eqV = T.eq (T.list T.int)
  val eqVL = T.eq (T.list (T.list T.int))
  val eqEL = T.eq (T.list (T.option T.int))

  fun vec (l : int list) : Word8Vector.vector = Word8Vector.fromList (List.map Word8.fromInt l)
  fun ints (v : Word8Vector.vector) : int list = Word8Vector.foldr (fn (w, l) => Word8.toInt w :: l) [] v
  fun elem (e : Word8.word option) : int option = Option.map Word8.toInt e
  (* piece (v, i, n): the n bytes of v from index i. *)
  fun piece (v : Word8Vector.vector, i : int, n : int) : Word8Vector.vector =
    Word8Vector.tabulate (n, fn k => Word8Vector.sub (v, i + k))

  (* write (name, v): the file name is created or truncated, and holds v. *)
  fun write (name : string, v : Word8Vector.vector) : unit =
    let val out = BinIO.openOut name in BinIO.output (out, v); BinIO.closeOut out end
  fun append (name : string, v : Word8Vector.vector) : unit =
    let val out = BinIO.openAppend name in BinIO.output (out, v); BinIO.closeOut out end

  (* slurp name: what the file holds. *)
  fun slurp (name : string) : Word8Vector.vector =
    let val ins = BinIO.openIn name val v = BinIO.inputAll ins in BinIO.closeIn ins; v end

  (* reading (name, l, f): f applied to an instream on a new file that holds the bytes l. *)
  fun reading (name : string, v : Word8Vector.vector, f : BinIO.instream -> 'a) : 'a =
    let
      val () = write (name, v)
      val ins = BinIO.openIn name
      val r = f ins
    in
      BinIO.closeIn ins; r
    end

  (* closed (name, v): an instream on a file that holds v, closed at once. *)
  fun closed (name : string, v : Word8Vector.vector) : BinIO.instream =
    let val () = write (name, v) val ins = BinIO.openIn name in BinIO.closeIn ins; ins end

  (* An outstream on name that has been closed after writing v. *)
  fun closedOut (name : string, v : Word8Vector.vector) : BinIO.outstream =
    let val out = BinIO.openOut name in BinIO.output (out, v); BinIO.closeOut out; out end

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

  (* ---- contents ---- *)
  (* Every byte, in order; and the bytes that a text mode would change. *)
  fun allBytes () = Word8Vector.tabulate (256, Word8.fromInt)
  val delicate = [0, 13, 10, 13, 10, 10, 13, 26, 4, 0, 0, 255, 128, 127, 10]

  (* About 210 KB whose bytes repeat with period 251 * 256, so that a buffer
     that is lost, repeated or out of place shows. *)
  fun byteAt (i : int) : int = (i mod 251 + i div 251) mod 256
  val bigSize = 210001
  val bigMemo : Word8Vector.vector option ref = ref NONE
  fun big () : Word8Vector.vector =
    case !bigMemo of
      SOME v => v
    | NONE => let val v = Word8Vector.tabulate (bigSize, fn i => Word8.fromInt (byteAt i)) in bigMemo := SOME v; v end

  fun randomBytes (n : int) : Word8Vector.vector =
    Word8Vector.tabulate (n, fn _ => Word8.fromInt (if T.range (0, 3) = 0 then T.oneOf [0, 10, 13, 255] else T.range (0, 255)))

  (* writeChunks (name, v, maxChunk): v written with output and flushOut in
     pieces of random sizes up to maxChunk. *)
  fun writeChunks (name : string, v : Word8Vector.vector, maxChunk : int) : unit =
    let
      val n = Word8Vector.length v
      val out = BinIO.openOut name
      fun go pos =
        if pos >= n then ()
        else
          let val len = Int.min (T.range (0, maxChunk), n - pos)
          in
            BinIO.output (out, piece (v, pos, len));
            if T.range (0, 9) = 0 then BinIO.flushOut out else ();
            go (pos + len)
          end
    in
      go 0; BinIO.closeOut out
    end

  (* ---- a model of reading ----
     runMix (r, v, steps, maxN): steps operations chosen at random on the
     stream r, which holds v, each compared with what the specification says
     for a stream that holds v and has been read up to a position; then
     inputAll. The result is "ok" or a description of the first difference.
     The operations are passed as functions so that a section can supply the
     ones an implementation has. *)
  type reader = {input1 : unit -> Word8.word option, inputN : int -> Word8Vector.vector,
                 lookahead : unit -> Word8.word option, endOfStream : unit -> bool,
                 input : unit -> Word8Vector.vector, canInput : int -> int option,
                 inputAll : unit -> Word8Vector.vector}

  fun runMix (r : reader, v : Word8Vector.vector, steps : int, maxN : int) : string =
    let
      val n = Word8Vector.length v
      val pos = ref 0
      val showE = T.option T.int
      fun showV w = if Word8Vector.length w <= 16 then T.list T.int (ints w)
                    else Int.toString (Word8Vector.length w) ^ " bytes"
      fun step i =
        let
          val p = !pos
          fun bad (what, got, want) =
            "step " ^ Int.toString i ^ ", position " ^ Int.toString p ^ ": " ^ what ^ " gave " ^ got
            ^ ", expected " ^ want
          fun next () = step (i + 1)
          fun here () = if p < n then SOME (Word8.toInt (Word8Vector.sub (v, p))) else NONE
        in
          if i = steps then
            let val got = #inputAll r () val want = piece (v, p, n - p)
            in if got <> want then bad ("inputAll", showV got, showV want) else "ok" end
          else
            case T.range (0, 5) of
              0 => let val got = elem (#input1 r ())
                   in if got = here () then (pos := Int.min (n, p + 1); next ()) else bad ("input1", showE got, showE (here ())) end
            | 1 => let val k = T.range (0, maxN)
                       val got = #inputN r k
                       val want = piece (v, p, Int.min (k, n - p))
                   in
                     if got = want then (pos := p + Word8Vector.length want; next ())
                     else bad ("inputN " ^ Int.toString k, showV got, showV want)
                   end
            | 2 => let val got = elem (#lookahead r ())
                   in if got = here () then next () else bad ("lookahead", showE got, showE (here ())) end
            | 3 => let val got = #endOfStream r ()
                   in if got = (p = n) then next () else bad ("endOfStream", T.bool got, T.bool (p = n)) end
            | 4 => let val got = #input r () val len = Word8Vector.length got
                   in
                     if p = n then (if len = 0 then next () else bad ("input", showV got, "[]"))
                     else if len = 0 then bad ("input", "[]", "at least one byte")
                     else if p + len > n orelse piece (v, p, len) <> got then bad ("input", showV got, "the bytes that follow")
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
  val () = eqV ("BinIO.openOut/creates-the-file", [1, 2, 3], fn () => (write ("create.bin", vec [1, 2, 3]); ints (slurp "create.bin")))
  val () = eqV ("BinIO.openOut/truncates-an-existing-file", [9],
                fn () => (write ("trunc.bin", vec [1, 2, 3, 4, 5]); write ("trunc.bin", vec [9]); ints (slurp "trunc.bin")))
  val () = eqV ("BinIO.openOut/truncates-at-open", [],
                fn () => (write ("trunc2.bin", vec [1, 2, 3]);
                          let val out = BinIO.openOut "trunc2.bin" val v = slurp "trunc2.bin"
                          in BinIO.closeOut out; ints v end))
  val () = eqV ("BinIO.openOut/nothing-written", [], fn () => (write ("empty.bin", vec []); ints (slurp "empty.bin")))
  val () = T.raises ("BinIO.openOut/Io-directory-does-not-exist", isIo, fn () => BinIO.openOut "no-such-directory/file.bin")
  val () = eqS ("BinIO.openOut/Io-name", "no-such-directory/file.bin",
                fn () => ioName (fn () => BinIO.closeOut (BinIO.openOut "no-such-directory/file.bin")))
  val () = eqS ("BinIO.openOut/Io-function", "openOut",
                fn () => ioFunction (fn () => BinIO.closeOut (BinIO.openOut "no-such-directory/file.bin")))
  val () = eqS ("BinIO.openOut/Io-cause", "SysErr",
                fn () => ioCause (fn () => BinIO.closeOut (BinIO.openOut "no-such-directory/file.bin")))

  val () = eqV ("BinIO.openIn/reads-the-file", [7, 8], fn () => (write ("in.bin", vec [7, 8]); ints (slurp "in.bin")))
  val () = T.raises ("BinIO.openIn/Io-file-does-not-exist", isIo, fn () => BinIO.openIn "missing.bin")
  val () = eqS ("BinIO.openIn/Io-name", "missing.bin", fn () => ioName (fn () => BinIO.closeIn (BinIO.openIn "missing.bin")))
  val () = eqS ("BinIO.openIn/Io-function", "openIn", fn () => ioFunction (fn () => BinIO.closeIn (BinIO.openIn "missing.bin")))
  val () = eqS ("BinIO.openIn/Io-cause", "SysErr", fn () => ioCause (fn () => BinIO.closeIn (BinIO.openIn "missing.bin")))
  val () = eqB ("BinIO.openIn/does-not-create-the-file", true,
                fn () => (ignore (ioOf (fn () => BinIO.closeIn (BinIO.openIn "missing.bin")));
                          isSome (ioOf (fn () => BinIO.closeIn (BinIO.openIn "missing.bin")))))

  (* vector, instream, outstream *)
  val () = eqV ("BinIO.vector/is-Word8Vector.vector", [1, 2],
                fn () => let val v : BinIO.vector = vec [1, 2] val w : Word8Vector.vector = v in ints w end)
  val () = eqVL ("BinIO.instream/two-on-one-file", [[1, 2, 3], [1, 2, 3]],
                 fn () => (write ("two.bin", vec [1, 2, 3]);
                           let
                             val a : BinIO.instream = BinIO.openIn "two.bin"
                             val b : BinIO.instream = BinIO.openIn "two.bin"
                             val va = BinIO.inputAll a
                             val vb = BinIO.inputAll b
                           in
                             BinIO.closeIn a; BinIO.closeIn b; [ints va, ints vb]
                           end))
  val () = eqVL ("BinIO.outstream/two-files", [[1, 4], [2, 3]],
                 fn () => let
                            val a : BinIO.outstream = BinIO.openOut "out-a.bin"
                            val b : BinIO.outstream = BinIO.openOut "out-b.bin"
                          in
                            BinIO.output (a, vec [1]); BinIO.output (b, vec [2]); BinIO.output (b, vec [3]);
                            BinIO.output (a, vec [4]); BinIO.closeOut b; BinIO.closeOut a;
                            [ints (slurp "out-a.bin"), ints (slurp "out-b.bin")]
                          end)

  (* ==== output ==== *)
  val () = eqV ("BinIO.output/in-order", [1, 2, 3, 4, 5, 6],
                fn () => let val out = BinIO.openOut "output.bin"
                         in
                           BinIO.output (out, vec [1, 2]); BinIO.output (out, vec [3]); BinIO.output (out, vec [4, 5, 6]);
                           BinIO.closeOut out; ints (slurp "output.bin")
                         end)
  val () = eqV ("BinIO.output/empty-vector", [1, 2],
                fn () => let val out = BinIO.openOut "output-empty.bin"
                         in
                           BinIO.output (out, vec []); BinIO.output (out, vec [1]); BinIO.output (out, vec []);
                           BinIO.output (out, vec [2]); BinIO.output (out, vec []); BinIO.closeOut out;
                           ints (slurp "output-empty.bin")
                         end)
  val () = eqB ("BinIO.output/every-byte", true, fn () => (write ("bytes.bin", allBytes ()); slurp "bytes.bin" = allBytes ()))
  val () = eqI ("BinIO.output/every-byte-size", 256, fn () => Word8Vector.length (slurp "bytes.bin"))
  val () = eqV ("BinIO.output/NUL-line-ends-and-control-Z", delicate,
                fn () => (write ("delicate.bin", vec delicate); ints (slurp "delicate.bin")))
  val () = eqB ("BinIO.output/large", true, fn () => (write ("big.bin", big ()); slurp "big.bin" = big ()))
  val () = eqI ("BinIO.output/large-size", bigSize, fn () => Word8Vector.length (slurp "big.bin"))
  (* The bytes are the characters with those codes (no translation on POSIX). *)
  val () = eqB ("BinIO.output/read-back-as-text", true,
                fn () => (write ("as-text.bin", allBytes ());
                          let val ins = TextIO.openIn "as-text.bin" val s = TextIO.inputAll ins
                          in TextIO.closeIn ins; s = String.implode (List.tabulate (256, Char.chr)) end))
  val () = eqB ("BinIO.inputAll/written-as-text", true,
                fn () => let val out = TextIO.openOut "as-bytes.txt"
                         in
                           TextIO.output (out, String.implode (List.tabulate (256, Char.chr))); TextIO.closeOut out;
                           slurp "as-bytes.txt" = allBytes ()
                         end)
  val () = T.raises ("BinIO.output/Io-closed-stream", isIo, fn () => BinIO.output (closedOut ("closed-out.bin", vec [1]), vec [2]))
  val () = eqS ("BinIO.output/Io-closed-stream-cause", "ClosedStream",
                fn () => ioCause (fn () => BinIO.output (closedOut ("closed-out.bin", vec [1]), vec [2])))
  val () = eqS ("BinIO.output/Io-closed-stream-function", "output",
                fn () => ioFunction (fn () => BinIO.output (closedOut ("closed-out.bin", vec [1]), vec [2])))
  val () = eqS ("BinIO.output/Io-closed-stream-name", "closed-out.bin",
                fn () => ioName (fn () => BinIO.output (closedOut ("closed-out.bin", vec [1]), vec [2])))
  val () = eqV ("BinIO.output/closed-stream-writes-nothing", [1],
                fn () => (ignore (ioOf (fn () => BinIO.output (closedOut ("closed-out.bin", vec [1]), vec [2])));
                          ints (slurp "closed-out.bin")))

  (* ==== flushOut, closeOut ==== *)
  val () = eqVL ("BinIO.flushOut/makes-output-visible", [[1, 2, 3], [1, 2, 3, 4, 5]],
                 fn () => let
                            val out = BinIO.openOut "flush.bin"
                            val () = BinIO.output (out, vec [1, 2, 3])
                            val () = BinIO.flushOut out
                            val first = slurp "flush.bin"
                            val () = BinIO.output (out, vec [4, 5])
                            val () = BinIO.closeOut out
                          in
                            [ints first, ints (slurp "flush.bin")]
                          end)
  val () = eqV ("BinIO.flushOut/nothing-to-flush", [],
                fn () => let val out = BinIO.openOut "flush-empty.bin"
                         in BinIO.flushOut out; BinIO.flushOut out; BinIO.closeOut out; ints (slurp "flush-empty.bin") end)
  (* STREAM_IO: flushOut "is a no-op on terminated streams", and "A closed
     stream is also terminated". *)
  val () = eqV ("BinIO.flushOut/closed-stream-is-a-no-op", [1],
                fn () => (BinIO.flushOut (closedOut ("flush-closed.bin", vec [1])); ints (slurp "flush-closed.bin")))
  val () = eqV ("BinIO.closeOut/flushes", [42], fn () => (write ("close.bin", vec [42]); ints (slurp "close.bin")))
  (* STREAM_IO.closeOut: "This operation has no effect if f is already closed." *)
  val () = eqV ("BinIO.closeOut/twice", [1],
                fn () => let val out = closedOut ("close-twice.bin", vec [1])
                         in BinIO.closeOut out; BinIO.closeOut out; ints (slurp "close-twice.bin") end)

  (* ==== openAppend ==== *)
  val () = eqV ("BinIO.openAppend/creates-the-file", [1, 2], fn () => (append ("append.bin", vec [1, 2]); ints (slurp "append.bin")))
  val () = eqV ("BinIO.openAppend/appends-to-an-existing-file", [1, 2, 3, 4],
                fn () => (write ("append2.bin", vec [1, 2]); append ("append2.bin", vec [3, 4]); ints (slurp "append2.bin")))
  val () = eqV ("BinIO.openAppend/keeps-the-contents", [1, 2],
                fn () => (write ("append3.bin", vec [1, 2]); append ("append3.bin", vec []); ints (slurp "append3.bin")))
  val () = eqV ("BinIO.openAppend/three-times", [1, 0, 2],
                fn () => (List.app (fn b => append ("append4.bin", vec [b])) [1, 0, 2]; ints (slurp "append4.bin")))
  val () = T.raises ("BinIO.openAppend/Io-directory-does-not-exist", isIo, fn () => BinIO.openAppend "no-such-directory/file.bin")
  val () = eqS ("BinIO.openAppend/Io-name", "no-such-directory/file.bin",
                fn () => ioName (fn () => BinIO.closeOut (BinIO.openAppend "no-such-directory/file.bin")))
  val () = eqS ("BinIO.openAppend/Io-function", "openAppend",
                fn () => ioFunction (fn () => BinIO.closeOut (BinIO.openAppend "no-such-directory/file.bin")))
  val () = eqS ("BinIO.openAppend/Io-cause", "SysErr",
                fn () => ioCause (fn () => BinIO.closeOut (BinIO.openAppend "no-such-directory/file.bin")))
  val () = eqS ("BinIO.openAppend/Io-closed-stream", "ClosedStream",
                fn () => ioCause (fn () => let val out = BinIO.openAppend "append5.bin"
                                           in BinIO.closeOut out; BinIO.output (out, vec [1]) end))

  (* ==== inputAll ==== *)
  val () = eqV ("BinIO.inputAll/whole-file", [5, 6, 7], fn () => ints (reading ("all.bin", vec [5, 6, 7], BinIO.inputAll)))
  val () = eqV ("BinIO.inputAll/empty-file", [], fn () => ints (reading ("all-empty.bin", vec [], BinIO.inputAll)))
  val () = eqVL ("BinIO.inputAll/again-at-end-of-stream", [[1, 2], [], [], []],
                 fn () => reading ("all-again.bin", vec [1, 2],
                                   fn ins => let
                                               val a = BinIO.inputAll ins
                                               val b = BinIO.inputAll ins
                                               val c = BinIO.inputAll ins
                                               val d = BinIO.inputAll ins
                                             in List.map ints [a, b, c, d] end))
  val () = eqB ("BinIO.inputAll/every-byte", true, fn () => reading ("all-bytes.bin", allBytes (), BinIO.inputAll) = allBytes ())
  val () = eqB ("BinIO.inputAll/large", true, fn () => reading ("all-big.bin", big (), BinIO.inputAll) = big ())

  (* ==== closeIn ====
     "Closing an already closed stream will be ignored. Other operations on a
     closed stream will behave as if the stream is at end-of-stream." *)
  val () = eqB ("BinIO.closeIn/twice", true,
                fn () => let val ins = closed ("closein.bin", vec [1, 2, 3]) in BinIO.closeIn ins; BinIO.closeIn ins; true end)
  val () = eqV ("BinIO.closeIn/then-inputAll-is-empty", [], fn () => ints (BinIO.inputAll (closed ("closein.bin", vec [1, 2, 3]))))
  val () = eqVL ("BinIO.closeIn/then-inputAll-again", [[], []],
                 fn () => let val ins = closed ("closein.bin", vec [1, 2, 3])
                              val a = BinIO.inputAll ins
                              val b = BinIO.inputAll ins
                          in [ints a, ints b] end)
  val () = eqV ("BinIO.closeIn/other-streams-stay-open", [1, 2, 3],
                fn () => (write ("closein-other.bin", vec [1, 2, 3]);
                          let val a = BinIO.openIn "closein-other.bin" val b = BinIO.openIn "closein-other.bin"
                          in BinIO.closeIn a; let val v = BinIO.inputAll b in BinIO.closeIn b; ints v end end))

  (* ==== a file that grows ====
     "After a read from strm to consume the end-of-stream, it is possible that
     the next call to endOfStream strm may return false, and input operations
     will deliver new elements." STREAM_IO: "The sequence of strings returned
     from a fresh stream by input is exactly the sequence returned by the
     underlying reader. This includes end-of-stream conditions", and a POSIX
     read returns what has been appended to a file since it reported the end
     of the file. *)
  val () = eqVL ("BinIO.inputAll/file-grows-after-end-of-stream", [[1, 2], [3, 4, 5], []],
                 fn () => (write ("grow.bin", vec [1, 2]);
                           let
                             val ins = BinIO.openIn "grow.bin"
                             val a = BinIO.inputAll ins
                             val () = append ("grow.bin", vec [3, 4, 5])
                             val b = BinIO.inputAll ins
                             val c = BinIO.inputAll ins
                           in
                             BinIO.closeIn ins; List.map ints [a, b, c]
                           end))

  (* ==== laws on random contents, for the members above ==== *)
  val () = T.seed 20260919
  val () = T.repeat (12, fn i =>
             eqB ("BinIO.output/random-chunks-" ^ Int.toString i, true,
                  fn () => let
                             val v = randomBytes (T.range (0, 3000))
                             val name = "random-" ^ Int.toString i ^ ".bin"
                           in
                             writeChunks (name, v, 40); slurp name = v
                           end))
  val () = eqB ("BinIO.output/random-chunks-large", true,
                fn () => (writeChunks ("random-big.bin", big (), 20000); slurp "random-big.bin" = big ()))
  val () = eqB ("BinIO.openAppend/random-pieces", true,
                fn () => let val pieces = List.tabulate (20, fn _ => randomBytes (T.range (0, 200)))
                         in
                           List.app (fn p => append ("append-random.bin", p)) pieces;
                           slurp "append-random.bin" = Word8Vector.concat pieces
                         end)

  (*<< elem *)
  (* "for binary streams, they correspond to Word8.word and Word8Vector.vector" *)
  val () = eqI ("BinIO.elem/is-Word8.word", 200,
                fn () => let val e : BinIO.elem = Word8.fromInt 200 val w : Word8.word = e in Word8.toInt w end)
  (*>> elem *)

  (*<< output1 *)
  val () = eqV ("BinIO.output1/in-order", [1, 2, 3],
                fn () => let val out = BinIO.openOut "output1.bin"
                         in
                           BinIO.output1 (out, Word8.fromInt 1); BinIO.output1 (out, Word8.fromInt 2);
                           BinIO.output1 (out, Word8.fromInt 3); BinIO.closeOut out; ints (slurp "output1.bin")
                         end)
  val () = eqV ("BinIO.output1/mixed-with-output", [1, 2, 3, 4],
                fn () => let val out = BinIO.openOut "output1-mixed.bin"
                         in
                           BinIO.output1 (out, Word8.fromInt 1); BinIO.output (out, vec [2, 3]);
                           BinIO.output1 (out, Word8.fromInt 4); BinIO.closeOut out; ints (slurp "output1-mixed.bin")
                         end)
  val () = eqB ("BinIO.output1/every-byte", true,
                fn () => let val out = BinIO.openOut "output1-bytes.bin"
                         in
                           T.repeat (256, fn i => BinIO.output1 (out, Word8.fromInt i));
                           BinIO.closeOut out; slurp "output1-bytes.bin" = allBytes ()
                         end)
  val () = eqB ("BinIO.output1/large", true,
                fn () => let val out = BinIO.openOut "output1-big.bin"
                         in
                           T.repeat (70000, fn i => BinIO.output1 (out, Word8.fromInt (byteAt i)));
                           BinIO.closeOut out; slurp "output1-big.bin" = piece (big (), 0, 70000)
                         end)
  val () = eqV ("BinIO.output1/appends", [1, 2],
                fn () => (write ("output1-append.bin", vec [1]);
                          let val out = BinIO.openAppend "output1-append.bin"
                          in BinIO.output1 (out, Word8.fromInt 2); BinIO.closeOut out; ints (slurp "output1-append.bin") end))
  val () = T.raises ("BinIO.output1/Io-closed-stream", isIo,
                     fn () => BinIO.output1 (closedOut ("closed-out1.bin", vec [1]), Word8.fromInt 2))
  val () = eqS ("BinIO.output1/Io-closed-stream-cause", "ClosedStream",
                fn () => ioCause (fn () => BinIO.output1 (closedOut ("closed-out1.bin", vec [1]), Word8.fromInt 2)))
  val () = eqS ("BinIO.output1/Io-closed-stream-function", "output1",
                fn () => ioFunction (fn () => BinIO.output1 (closedOut ("closed-out1.bin", vec [1]), Word8.fromInt 2)))
  val () = eqS ("BinIO.output1/Io-closed-stream-name", "closed-out1.bin",
                fn () => ioName (fn () => BinIO.output1 (closedOut ("closed-out1.bin", vec [1]), Word8.fromInt 2)))
  (*>> output1 *)

  (*<< input *)
  (* "When elements are available, it returns a vector of at least one
     element. When strm is at end-of-stream or is closed, it returns an empty
     vector." inputs ins: what input returns until the empty vector. *)
  fun inputs (ins : BinIO.instream, fuel : int) : Word8Vector.vector list =
    if fuel = 0 then [Word8Vector.fromList [Word8.fromInt 255, Word8.fromInt 255, Word8.fromInt 255]]
    else let val v = BinIO.input ins in if Word8Vector.length v = 0 then [] else v :: inputs (ins, fuel - 1) end
  val () = eqB ("BinIO.input/at-least-one-byte", true,
                fn () => reading ("input.bin", vec [1, 2, 3, 4, 5],
                                  fn ins => let val v = BinIO.input ins val n = Word8Vector.length v
                                            in n >= 1 andalso n <= 5 andalso ints v = List.take ([1, 2, 3, 4, 5], n) end))
  val () = eqV ("BinIO.input/empty-file", [], fn () => ints (reading ("input-empty.bin", vec [], BinIO.input)))
  val () = eqV ("BinIO.input/pieces-make-the-file", [1, 0, 10, 13, 255],
                fn () => reading ("input-pieces.bin", vec [1, 0, 10, 13, 255], fn ins => ints (Word8Vector.concat (inputs (ins, 20)))))
  val () = eqVL ("BinIO.input/empty-again-at-end-of-stream", [[], [], []],
                 fn () => reading ("input-again.bin", vec [1, 2, 3],
                                   fn ins => let
                                               val _ = inputs (ins, 10)
                                               val a = BinIO.input ins
                                               val b = BinIO.input ins
                                               val c = BinIO.input ins
                                             in List.map ints [a, b, c] end))
  val () = eqB ("BinIO.input/large", true,
                fn () => reading ("input-big.bin", big (), fn ins => Word8Vector.concat (inputs (ins, bigSize + 1)) = big ()))
  val () = eqVL ("BinIO.input/empty-after-input-and-inputAll", [[], []],
                 fn () => reading ("input-all.bin", vec [1, 2, 3],
                                   fn ins => let
                                               val _ = BinIO.input ins
                                               val _ = BinIO.inputAll ins
                                               val a = BinIO.input ins
                                               val b = BinIO.inputAll ins
                                             in [ints a, ints b] end))
  val () = eqV ("BinIO.input/closed-stream", [], fn () => ints (BinIO.input (closed ("input-closed.bin", vec [1, 2, 3]))))
  (*>> input *)

  (*<< input1 *)
  val () = eqEL ("BinIO.input1/bytes-then-NONE", [SOME 7, SOME 8, NONE],
                 fn () => reading ("input1.bin", vec [7, 8],
                                   fn ins => let
                                               val a = BinIO.input1 ins
                                               val b = BinIO.input1 ins
                                               val c = BinIO.input1 ins
                                             in List.map elem [a, b, c] end))
  val () = eqEL ("BinIO.input1/empty-file", [NONE], fn () => reading ("input1-empty.bin", vec [], fn ins => [elem (BinIO.input1 ins)]))
  val () = eqEL ("BinIO.input1/NONE-again-at-end-of-stream", [SOME 7, NONE, NONE, NONE],
                 fn () => reading ("input1-again.bin", vec [7],
                                   fn ins => let
                                               val a = BinIO.input1 ins
                                               val b = BinIO.input1 ins
                                               val c = BinIO.input1 ins
                                               val d = BinIO.input1 ins
                                             in List.map elem [a, b, c, d] end))
  val () = eqEL ("BinIO.input1/NUL-line-ends-and-control-Z", List.map SOME delicate @ [NONE],
                 fn () => reading ("input1-delicate.bin", vec delicate,
                                   fn ins => List.tabulate (List.length delicate + 1, fn _ => elem (BinIO.input1 ins))))
  val () = eqB ("BinIO.input1/every-byte", true,
                fn () => reading ("input1-all.bin", allBytes (),
                                  fn ins => List.tabulate (257, fn _ => elem (BinIO.input1 ins))
                                            = List.tabulate (256, SOME) @ [NONE]))
  val () = eqV ("BinIO.input1/removes-one-byte", [2, 3],
                fn () => reading ("input1-rest.bin", vec [1, 2, 3], fn ins => (ignore (BinIO.input1 ins); ints (BinIO.inputAll ins))))
  val () = eqVL ("BinIO.inputAll/empty-after-input1-and-inputAll", [[2, 3], [], []],
                 fn () => reading ("input1-all2.bin", vec [1, 2, 3],
                                   fn ins => let
                                               val _ = BinIO.input1 ins
                                               val a = BinIO.inputAll ins
                                               val b = BinIO.inputAll ins
                                               val c = BinIO.inputAll ins
                                             in List.map ints [a, b, c] end))
  val () = eqB ("BinIO.input1/large", true,
                fn () => reading ("input1-big.bin", piece (big (), 0, 70000),
                                  fn ins => let fun go i = if i = 70000 then elem (BinIO.input1 ins) = NONE
                                                           else elem (BinIO.input1 ins) = SOME (byteAt i) andalso go (i + 1)
                                            in go 0 end))
  val () = eqEL ("BinIO.input1/closed-stream", [NONE, NONE],
                 fn () => let val ins = closed ("input1-closed.bin", vec [1, 2, 3])
                              val a = BinIO.input1 ins
                              val b = BinIO.input1 ins
                          in [elem a, elem b] end)
  (*>> input1 *)

  (*<< inputN *)
  (* "It returns a vector containing n elements if at least n elements are
     available before end-of-stream; it returns a shorter (and possibly empty)
     vector of all elements remaining before end-of-stream otherwise. [...] It
     raises Size if n < 0 [...]" *)
  val () = eqVL ("BinIO.inputN/pieces-then-empty", [[1, 2, 3], [4, 5], [], []],
                 fn () => reading ("inputn.bin", vec [1, 2, 3, 4, 5],
                                   fn ins => let
                                               val a = BinIO.inputN (ins, 3)
                                               val b = BinIO.inputN (ins, 3)
                                               val c = BinIO.inputN (ins, 3)
                                               val d = BinIO.inputN (ins, 3)
                                             in List.map ints [a, b, c, d] end))
  val () = eqVL ("BinIO.inputN/exactly-the-rest", [[1, 2, 3, 4, 5], []],
                 fn () => reading ("inputn-exact.bin", vec [1, 2, 3, 4, 5],
                                   fn ins => let val a = BinIO.inputN (ins, 5) val b = BinIO.inputN (ins, 1) in [ints a, ints b] end))
  val () = eqV ("BinIO.inputN/more-than-there-is", [1, 2, 3],
                fn () => ints (reading ("inputn-more.bin", vec [1, 2, 3], fn ins => BinIO.inputN (ins, 100))))
  (* STREAM_IO: "inputN(f,0) returns immediately with an empty vector and f" *)
  val () = eqVL ("BinIO.inputN/zero-reads-nothing", [[], [], [1, 2, 3], []],
                 fn () => reading ("inputn-zero.bin", vec [1, 2, 3],
                                   fn ins => let
                                               val a = BinIO.inputN (ins, 0)
                                               val b = BinIO.inputN (ins, 0)
                                               val c = BinIO.inputAll ins
                                               val d = BinIO.inputN (ins, 0)
                                             in List.map ints [a, b, c, d] end))
  val () = eqV ("BinIO.inputN/empty-file", [], fn () => ints (reading ("inputn-empty.bin", vec [], fn ins => BinIO.inputN (ins, 10))))
  val () = eqV ("BinIO.inputN/NUL-line-ends-and-control-Z", delicate,
                fn () => ints (reading ("inputn-delicate.bin", vec delicate, fn ins => BinIO.inputN (ins, List.length delicate))))
  val () = T.raises ("BinIO.inputN/Size-negative", T.isSize,
                     fn () => reading ("inputn-size.bin", vec [1, 2, 3], fn ins => BinIO.inputN (ins, ~1)))
  val () = T.raises ("BinIO.inputN/Size-negative-at-end-of-stream", T.isSize,
                     fn () => reading ("inputn-size2.bin", vec [], fn ins => BinIO.inputN (ins, ~5)))
  val () = eqV ("BinIO.inputN/negative-reads-nothing", [1, 2, 3],
                fn () => reading ("inputn-size3.bin", vec [1, 2, 3],
                                  fn ins => ((ignore (BinIO.inputN (ins, ~1))) handle _ => (); ints (BinIO.inputAll ins))))
  val () = eqVL ("BinIO.inputN/empty-after-inputN-and-inputAll", [[3, 4], [], []],
                 fn () => reading ("inputn-all.bin", vec [1, 2, 3, 4],
                                   fn ins => let
                                               val _ = BinIO.inputN (ins, 2)
                                               val a = BinIO.inputAll ins
                                               val b = BinIO.inputN (ins, 2)
                                               val c = BinIO.inputAll ins
                                             in List.map ints [a, b, c] end))
  val () = eqB ("BinIO.inputN/large", true,
                fn () => reading ("inputn-big.bin", big (),
                                  fn ins => let
                                              val v = big ()
                                              val a = BinIO.inputN (ins, 70000)
                                              val b = BinIO.inputN (ins, 1)
                                              val c = BinIO.inputN (ins, 100000)
                                              val d = BinIO.inputN (ins, bigSize)
                                            in
                                              a = piece (v, 0, 70000) andalso b = piece (v, 70000, 1)
                                              andalso c = piece (v, 70001, 100000)
                                              andalso d = piece (v, 170001, bigSize - 170001)
                                            end))
  val () = eqVL ("BinIO.inputN/closed-stream", [[], []],
                 fn () => let val ins = closed ("inputn-closed.bin", vec [1, 2, 3])
                              val a = BinIO.inputN (ins, 2)
                              val b = BinIO.inputN (ins, 0)
                          in [ints a, ints b] end)
  (*>> inputN *)

  (*<< lookahead *)
  (* "In the former case, e is not removed from strm but stays available for
     further input operations." *)
  val () = eqEL ("BinIO.lookahead/does-not-remove", [SOME 9, SOME 9, SOME 9],
                 fn () => reading ("look.bin", vec [9, 8],
                                   fn ins => let
                                               val a = BinIO.lookahead ins
                                               val b = BinIO.lookahead ins
                                               val c = BinIO.lookahead ins
                                             in List.map elem [a, b, c] end))
  val () = eqV ("BinIO.lookahead/then-inputAll", [9, 8],
                fn () => reading ("look-all.bin", vec [9, 8], fn ins => (ignore (BinIO.lookahead ins); ints (BinIO.inputAll ins))))
  val () = eqVL ("BinIO.inputAll/empty-after-lookahead-and-inputAll", [[9, 8], [], []],
                 fn () => reading ("look-all2.bin", vec [9, 8],
                                   fn ins => let
                                               val _ = BinIO.lookahead ins
                                               val a = BinIO.inputAll ins
                                               val b = BinIO.inputAll ins
                                               val c = BinIO.inputAll ins
                                             in List.map ints [a, b, c] end))
  val () = eqEL ("BinIO.lookahead/empty-file", [NONE, NONE],
                 fn () => reading ("look-empty.bin", vec [],
                                   fn ins => let val a = BinIO.lookahead ins val b = BinIO.lookahead ins in [elem a, elem b] end))
  val () = eqEL ("BinIO.lookahead/NUL-and-255", [SOME 0, SOME 255],
                 fn () => let
                            val a = reading ("look-nul.bin", vec [0, 1], BinIO.lookahead)
                            val b = reading ("look-255.bin", vec [255, 1], BinIO.lookahead)
                          in [elem a, elem b] end)
  val () = eqEL ("BinIO.lookahead/at-end-of-stream", [NONE],
                 fn () => reading ("look-eos.bin", vec [1], fn ins => (ignore (BinIO.inputAll ins); [elem (BinIO.lookahead ins)])))
  val () = eqEL ("BinIO.lookahead/closed-stream", [NONE], fn () => [elem (BinIO.lookahead (closed ("look-closed.bin", vec [1, 2, 3])))])
  (*>> lookahead *)

  (*<< endOfStream *)
  val eqBL = T.eq (T.list T.bool)
  val () = eqB ("BinIO.endOfStream/empty-file", true, fn () => reading ("eos-empty.bin", vec [], BinIO.endOfStream))
  val () = eqB ("BinIO.endOfStream/bytes-available", false, fn () => reading ("eos.bin", vec [0], BinIO.endOfStream))
  val () = eqV ("BinIO.endOfStream/removes-nothing", [1, 2, 3],
                fn () => reading ("eos-keep.bin", vec [1, 2, 3], fn ins => (ignore (BinIO.endOfStream ins); ints (BinIO.inputAll ins))))
  val () = eqBL ("BinIO.endOfStream/true-after-endOfStream-and-inputAll", [false, true, true],
                 fn () => reading ("eos-all.bin", vec [1, 2, 3],
                                   fn ins => let
                                               val a = BinIO.endOfStream ins
                                               val _ = BinIO.inputAll ins
                                               val b = BinIO.endOfStream ins
                                               val c = BinIO.endOfStream ins
                                             in [a, b, c] end))
  val () = eqB ("BinIO.endOfStream/closed-stream", true, fn () => BinIO.endOfStream (closed ("eos-closed.bin", vec [1, 2, 3])))
  (*>> endOfStream *)

  (*<< canInput *)
  (* "returns NONE if any attempt at input would block. It returns SOME(k),
     where 0 <= k <= n, if a call to input would return immediately with at
     least k characters. Note that k = 0 corresponds to the stream being at
     end-of-stream. [...] It raises the Size exception if n < 0." Reading a
     file does not block. *)
  val eqIO = T.eq (T.option T.int)
  val () = eqB ("BinIO.canInput/bytes-available", true,
                fn () => reading ("can.bin", vec [1, 2, 3, 4, 5],
                                  fn ins => case BinIO.canInput (ins, 3) of SOME k => 1 <= k andalso k <= 3 | NONE => false))
  val () = eqIO ("BinIO.canInput/one", SOME 1, fn () => reading ("can-one.bin", vec [1, 2, 3], fn ins => BinIO.canInput (ins, 1)))
  val () = eqB ("BinIO.canInput/more-than-there-is", true,
                fn () => reading ("can-more.bin", vec [1, 2, 3],
                                  fn ins => case BinIO.canInput (ins, 100) of SOME k => 1 <= k andalso k <= 3 | NONE => false))
  val () = eqIO ("BinIO.canInput/empty-file", SOME 0, fn () => reading ("can-empty.bin", vec [], fn ins => BinIO.canInput (ins, 10)))
  val () = eqIO ("BinIO.canInput/at-end-of-stream", SOME 0,
                 fn () => reading ("can-eos.bin", vec [1, 2, 3], fn ins => (ignore (BinIO.inputAll ins); BinIO.canInput (ins, 10))))
  val () = eqV ("BinIO.canInput/removes-nothing", [1, 2, 3],
                fn () => reading ("can-keep.bin", vec [1, 2, 3], fn ins => (ignore (BinIO.canInput (ins, 2)); ints (BinIO.inputAll ins))))
  val () = eqIO ("BinIO.canInput/zero", SOME 0, fn () => reading ("can-zero.bin", vec [1, 2, 3], fn ins => BinIO.canInput (ins, 0)))
  val () = T.raises ("BinIO.canInput/Size-negative", T.isSize,
                     fn () => reading ("can-size.bin", vec [1, 2, 3], fn ins => BinIO.canInput (ins, ~1)))
  val () = eqIO ("BinIO.canInput/closed-stream", SOME 0, fn () => BinIO.canInput (closed ("can-closed.bin", vec [1, 2, 3]), 10))
  (*>> canInput *)

  (*<< mixed *)
  (* Every input operation, in a random order, on random contents. *)
  fun fileReader (ins : BinIO.instream) : reader =
    {input1 = fn () => BinIO.input1 ins, inputN = fn n => BinIO.inputN (ins, n),
     lookahead = fn () => BinIO.lookahead ins, endOfStream = fn () => BinIO.endOfStream ins,
     input = fn () => BinIO.input ins, canInput = fn n => BinIO.canInput (ins, n),
     inputAll = fn () => BinIO.inputAll ins}
  val () = T.seed 1918
  val () = T.repeat (16, fn i =>
             eqS ("BinIO.inputN/random-mix-of-operations-" ^ Int.toString i, "ok",
                  fn () => let
                             val v = randomBytes (T.range (0, 4000))
                             val name = "mix-" ^ Int.toString i ^ ".bin"
                             val () = writeChunks (name, v, 60)
                             val ins = BinIO.openIn name
                             val r = runMix (fileReader ins, v, T.range (0, 400), 300)
                           in
                             BinIO.closeIn ins; r
                           end))
  val () = T.repeat (3, fn i =>
             eqS ("BinIO.inputN/random-mix-of-operations-large-" ^ Int.toString i, "ok",
                  fn () => let
                             val name = "mix-big-" ^ Int.toString i ^ ".bin"
                             val () = write (name, big ())
                             val ins = BinIO.openIn name
                             val r = runMix (fileReader ins, big (), 150, 9000)
                           in
                             BinIO.closeIn ins; r
                           end))
  (*>> mixed *)

  (*<< multiple-end-of-stream *)
  (* A file that grows (see above). "After a call to input1 returning NONE to
     indicate an end-of-stream, the input stream should be positioned after
     the end-of-stream." *)
  val () = eqEL ("BinIO.input1/file-grows-after-end-of-stream", [SOME 1, NONE, SOME 2, NONE],
                 fn () => (write ("grow1.bin", vec [1]);
                           let
                             val ins = BinIO.openIn "grow1.bin"
                             val a = BinIO.input1 ins
                             val b = BinIO.input1 ins
                             val () = append ("grow1.bin", vec [2])
                             val c = BinIO.input1 ins
                             val d = BinIO.input1 ins
                           in
                             BinIO.closeIn ins; List.map elem [a, b, c, d]
                           end))
  (* endOfStream does not consume the end-of-stream it finds: it stays true
     until a read has consumed it, and that read returns the empty vector. *)
  val () = eqS ("BinIO.endOfStream/file-grows-after-end-of-stream", "true true [] false [7, 8]",
                fn () => (write ("grow2.bin", vec []);
                          let
                            val ins = BinIO.openIn "grow2.bin"
                            val a = BinIO.endOfStream ins
                            val () = append ("grow2.bin", vec [7, 8])
                            val b = BinIO.endOfStream ins
                            val c = BinIO.input ins
                            val d = BinIO.endOfStream ins
                            val e = BinIO.inputAll ins
                          in
                            BinIO.closeIn ins;
                            String.concatWith " " [Bool.toString a, Bool.toString b, T.list T.int (ints c), Bool.toString d,
                                                   T.list T.int (ints e)]
                          end))
  (*>> multiple-end-of-stream *)

  (* A stream that is still open when the program ends: "All streams created
     by [...] the open functions in BinIO will be closed (and the output
     streams among them flushed) when the SML program exits." The runner does
     not look at the file, left-open.bin, which must hold the bytes 1 2 3
     afterwards. *)
  val leftOpen : BinIO.outstream option ref = ref NONE
  val () = eqB ("BinIO.openOut/left-open-at-exit", true,
                fn () => let val out = BinIO.openOut "left-open.bin"
                         in leftOpen := SOME out; BinIO.output (out, vec [1, 2, 3]); true end)
end
