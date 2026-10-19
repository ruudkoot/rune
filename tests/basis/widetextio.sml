(* requires: WideTextIO WideString WideChar WideCharVector OS *)
(* WideTextIO (optional in the specification, signature TEXT_IO): the
   imperative streams of the wide character. The specification does not say
   how a wide character reaches a file; here a file holds UTF-8, so the
   checks count both the characters a stream gives and the bytes the file
   holds. The files are made in the current directory, which the runner makes
   a new scratch directory. *)
structure TestWideTextIO =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val C = WideChar.chr
  fun ws l = WideString.implode (List.map C l)
  val show = WideString.toString
  val eqW = T.eq show
  val eqWO = T.eq (T.option show)
  val sample = ws [104, 233, 0x1F600, 10]          (* h, e-acute, face, newline: 1 + 2 + 4 + 1 bytes *)
  val file = "widetextio.txt"
  fun write (name, s) =
    let val out = WideTextIO.openOut name in WideTextIO.output (out, s); WideTextIO.closeOut out end
  fun bytes name = let val ins = TextIO.openIn name in TextIO.inputAll ins before TextIO.closeIn ins end

  (*<< files *)
  (* the reader of a file of wide characters has no positions, no ioDesc and
     nothing that does not block: a position in the file is one of bytes and
     not of characters (WideTextIO/file-streams-have-no-positions) *)
  val () = eqB ("WideTextIO.openIn/the-reader-has-no-positions", true,
                fn () => (write (file, sample);
                          let
                            val ins = WideTextIO.openIn file
                            val (rd, _) = WideTextIO.StreamIO.getReader (WideTextIO.getInstream ins)
                            val WideTextPrimIO.RD {getPos, setPos, endPos, ioDesc, readVecNB, ...} = rd
                          in
                            not (isSome getPos) andalso not (isSome setPos) andalso not (isSome endPos)
                            andalso not (isSome ioDesc) andalso not (isSome readVecNB)
                          end))
  val () = eqI ("WideTextIO.output/writes-utf-8", 8, fn () => (write (file, sample); size (bytes file)))
  val () = eqW ("WideTextIO.inputAll/reads-utf-8", sample,
                fn () => (write (file, sample);
                          let val ins = WideTextIO.openIn file in WideTextIO.inputAll ins before WideTextIO.closeIn ins end))
  val () = eqWO ("WideTextIO.input1/first-character", SOME (ws [104]),
                 fn () => (write (file, sample);
                           let val ins = WideTextIO.openIn file
                           in Option.map (fn c => ws [WideChar.ord c]) (WideTextIO.input1 ins) before WideTextIO.closeIn ins end))
  val () = eqW ("WideTextIO.inputN/counts-characters-not-bytes", ws [104, 233],
                fn () => (write (file, sample);
                          let val ins = WideTextIO.openIn file in WideTextIO.inputN (ins, 2) before WideTextIO.closeIn ins end))
  val () = eqWO ("WideTextIO.inputLine/to-the-newline", SOME sample,
                 fn () => (write (file, sample);
                           let val ins = WideTextIO.openIn file in WideTextIO.inputLine ins before WideTextIO.closeIn ins end))
  val () = eqB ("WideTextIO.endOfStream/after-everything", true,
                fn () => (write (file, sample);
                          let val ins = WideTextIO.openIn file
                          in (WideTextIO.inputAll ins; WideTextIO.endOfStream ins) before WideTextIO.closeIn ins end))
  val () = eqW ("WideTextIO.openAppend/adds-to-the-file", WideString.^ (sample, ws [65]),
                fn () => (write (file, sample);
                          let val out = WideTextIO.openAppend file
                          in WideTextIO.output (out, ws [65]); WideTextIO.closeOut out end;
                          let val ins = WideTextIO.openIn file in WideTextIO.inputAll ins before WideTextIO.closeIn ins end))
  val () = eqB ("WideTextIO.openIn/Io-missing-file", true,
                fn () => (WideTextIO.openIn "no-such-directory/f"; false) handle IO.Io _ => true)
  val () = T.check ("WideTextIO.output1/one-character-at-a-time",
                    fn () => (let val out = WideTextIO.openOut file
                              in WideTextIO.output1 (out, C 0x1F600); WideTextIO.output1 (out, C 65);
                                 WideTextIO.closeOut out end;
                              size (bytes file) = 5))
  val () = T.check ("WideTextIO.flushOut/reaches-the-file",
                    fn () => let val out = WideTextIO.openOut file
                             in WideTextIO.output (out, ws [65]); WideTextIO.flushOut out;
                                size (bytes file) = 1 before WideTextIO.closeOut out end)
  val () = T.check ("WideTextIO.lookahead/does-not-consume",
                    fn () => (write (file, sample);
                              let val ins = WideTextIO.openIn file
                                  val a = WideTextIO.lookahead ins
                                  val b = WideTextIO.input1 ins
                              in WideTextIO.closeIn ins; a = b andalso a = SOME (C 104) end))
  val () = T.check ("WideTextIO.inputAll/Io-on-bytes-that-are-not-utf-8",
                    fn () => (let val out = TextIO.openOut file in TextIO.output (out, "\255\255"); TextIO.closeOut out end;
                              let val ins = WideTextIO.openIn file
                              in (WideTextIO.inputAll ins; false) handle IO.Io _ => true end))
  val () = List.app (fn f => OS.FileSys.remove f handle _ => ()) [file]
  (*>> files *)

  (*<< strings *)
  val () = eqW ("WideTextIO.openString/reads-the-characters", sample,
                fn () => let val ins = WideTextIO.openString sample in WideTextIO.inputAll ins end)
  val () = eqI ("WideTextIO.canInput/of-a-string", 2,
                fn () => let val ins = WideTextIO.openString (ws [104, 233])
                         in valOf (WideTextIO.canInput (ins, 5)) end)
  val () = T.check ("WideTextIO.getInstream/and-setInstream",
                    fn () => let val ins = WideTextIO.openString sample
                                 val s = WideTextIO.getInstream ins
                                 val (v, s') = WideTextIO.StreamIO.inputN (s, 2)
                             in WideTextIO.setInstream (ins, s');
                                WideString.compare (v, ws [104, 233]) = EQUAL
                                andalso WideString.compare (WideTextIO.inputAll ins, ws [0x1F600, 10]) = EQUAL end)
  val () = T.check ("WideTextIO.scanStream/scans-a-wide-string",
                    fn () => let val ins = WideTextIO.openString (ws [104, 105])
                             in WideTextIO.scanStream WideString.scan ins = SOME (ws [104, 105]) end)
  val () = T.check ("WideTextIO.StreamIO.inputLine/of-a-string",
                    fn () => case WideTextIO.StreamIO.inputLine (WideTextIO.getInstream (WideTextIO.openString sample)) of
                               SOME (l, _) => WideString.compare (l, sample) = EQUAL
                             | NONE => false)
  val () = T.check ("WideTextIO.StreamIO.outputSubstr/writes-a-substring",
                    fn () => let val out = WideTextIO.mkOutstream (WideTextIO.StreamIO.mkOutstream
                                             (#1 (WideTextIO.StreamIO.getWriter (WideTextIO.getOutstream (WideTextIO.openOut file))), IO.NO_BUF))
                             in WideTextIO.outputSubstr (out, WideSubstring.full (ws [65])); WideTextIO.closeOut out;
                                (OS.FileSys.remove file handle _ => ()); true end)
  (*>> strings *)

  (*<< text-io *)
  (* The members of TEXT_IO that WideTextIO has as TextIO has them, since
     both match one TEXT_IO (the deviation TEXT_IO/generic of lib/basis).
     The runner gives the program an empty standard input. *)
  val () = eqW ("WideTextIO.input/what-is-there", ws [0x3BB, 65],
                fn () => WideTextIO.input (WideTextIO.openString (ws [0x3BB, 65])))
  val () = eqW ("WideTextIO.input/empty-at-end-of-stream", ws [],
                fn () => let val ins = WideTextIO.openString (ws [65]) in ignore (WideTextIO.input ins); WideTextIO.input ins end)
  val () = eqW ("WideTextIO.openOut/empties-the-file", ws [0x1F600],
                fn () => (write (file, sample); write (file, ws [0x1F600]);
                          let val ins = WideTextIO.openIn file in WideTextIO.inputAll ins before WideTextIO.closeIn ins end))
  val () = eqW ("WideTextIO.outputSubstr/writes-the-substring", ws [233, 0x1F600],
                fn () => let val out = WideTextIO.openOut file
                         in WideTextIO.outputSubstr (out, WideSubstring.extract (sample, 1, SOME 2)); WideTextIO.closeOut out;
                            let val ins = WideTextIO.openIn file in WideTextIO.inputAll ins before WideTextIO.closeIn ins end
                         end)
  (* a file of wide characters has no positions
     (WideTextIO/file-streams-have-no-positions) *)
  val () = eqB ("WideTextIO.setPosOut/file-has-no-positions", true,
                fn () => let val out = WideTextIO.openOut file
                         in (WideTextIO.setPosOut (out, WideTextIO.getPosOut out); false) handle IO.Io _ => true
                         end before (OS.FileSys.remove file handle _ => ()))
  val () = eqB ("WideTextIO.StreamIO.setPosOut/file-has-no-positions", true,
                fn () => let val out = WideTextIO.getOutstream (WideTextIO.openOut file)
                         in (ignore (WideTextIO.StreamIO.setPosOut (WideTextIO.StreamIO.getPosOut out)); false) handle IO.Io _ => true
                         end before (OS.FileSys.remove file handle _ => ()))
  val () = eqB ("WideTextIO.StreamIO.filePosOut/file-has-no-positions", true,
                fn () => let val out = WideTextIO.getOutstream (WideTextIO.openOut file)
                         in (ignore (WideTextIO.StreamIO.filePosOut (WideTextIO.StreamIO.getPosOut out)); false) handle IO.Io _ => true
                         end before (OS.FileSys.remove file handle _ => ()))
  val () = eqW ("WideTextIO.stdIn/inputAll-at-end-of-stream", ws [], fn () => WideTextIO.inputAll WideTextIO.stdIn)
  val () = eqB ("WideTextIO.stdOut/output-and-flushOut", true,
                fn () => (WideTextIO.output (WideTextIO.stdOut, ws []); WideTextIO.flushOut WideTextIO.stdOut; true))
  val () = eqB ("WideTextIO.stdErr/output-and-flushOut", true,
                fn () => (WideTextIO.output (WideTextIO.stdErr, ws [35, 32, 0x3BB, 10]); WideTextIO.flushOut WideTextIO.stdErr; true))
  val () = eqB ("WideTextIO.print/empty-string", true, fn () => (WideTextIO.print (ws []); true))
  (*>> text-io *)
end
