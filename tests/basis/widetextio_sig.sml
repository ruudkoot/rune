(* requires: WideTextIO WideTextPrimIO WideString WideChar WideSubstring TextIO Position IO *)
(* uses: spec-sigs/PRIM_IO.sml spec-sigs/STREAM_IO.sml spec-sigs/IMPERATIVE_IO.sml spec-sigs/scr/TEXT_STREAM_IO.sml spec-sigs/scr/TEXT_IO.sml *)
(* WideTextPrimIO matches PRIM_IO over the wide character, and WideTextIO and
   TextIO match one TEXT_IO, the signature of the change request of
   docs/unicode.md (the deviation `TEXT_IO/generic`), where what is read and
   written, its elements and its pieces are types of the signature:
     structure TextIO :> TEXT_IO
       where type StreamIO.vector = CharVector.vector
       where type StreamIO.elem = Char.char
       where type StreamIO.substring = Substring.substring
       where type StreamIO.reader = TextPrimIO.reader ...
     structure WideTextIO :> TEXT_IO
       where type StreamIO.vector = WideCharVector.vector
       where type StreamIO.elem = WideChar.char
       where type StreamIO.substring = WideSubstring.substring
       where type StreamIO.reader = WideTextPrimIO.reader ...
   The transcription of the page's TEXT_IO writes its types as string and
   char, so WideTextIO is not matched against that one. No host has a
   WideTextIO, so only Rune runs these checks. *)
functor TestWideTextIOCountLines (IO : SCR_TEXT_IO) =
struct
  fun count f = case IO.inputLine f of NONE => 0 | SOME _ => 1 + count f
end
structure TestWideTextIOSig =
struct
  structure G : SCR_TEXT_IO
    where type StreamIO.vector = WideCharVector.vector
    where type StreamIO.elem = WideChar.char
    where type StreamIO.substring = WideSubstring.substring
    where type StreamIO.reader = WideTextPrimIO.reader
    where type StreamIO.writer = WideTextPrimIO.writer
    where type StreamIO.pos = WideTextPrimIO.pos = WideTextIO
  val () = T.check ("WideTextIO:TEXT_IO/generic", fn () => true)
  val () = T.check ("WideTextIO:TEXT_IO/vector-is-WideString.string",
                    fn () => WideString.size (G.inputAll (G.openString (WideString.str (WideChar.chr 0x3BB)))) = 1)
  val () = T.check ("WideTextIO:TEXT_IO/elem-is-WideChar.char",
                    fn () => G.input1 (G.openString (WideString.str (WideChar.chr 0x1F600))) = SOME (WideChar.chr 0x1F600))
  val () = T.check ("WideTextIO:TEXT_IO/substring-is-WideSubstring.substring",
                    fn () => let val out = G.openOut "widetextio-sig.tmp"
                             in G.outputSubstr (out, WideSubstring.full (WideString.str (WideChar.chr 0x3BB)));
                                G.closeOut out;
                                G.inputAll (G.openIn "widetextio-sig.tmp") = WideString.str (WideChar.chr 0x3BB)
                                before OS.FileSys.remove "widetextio-sig.tmp"
                             end)
  structure GT : SCR_TEXT_IO
    where type StreamIO.vector = CharVector.vector
    where type StreamIO.elem = Char.char
    where type StreamIO.substring = Substring.substring
    where type StreamIO.reader = TextPrimIO.reader
    where type StreamIO.writer = TextPrimIO.writer
    where type StreamIO.pos = TextPrimIO.pos = TextIO
  val () = T.check ("TextIO:TEXT_IO/generic", fn () => GT.inputAll (GT.openString "ab") = "ab")
  structure GS : SCR_TEXT_STREAM_IO
    where type vector = WideCharVector.vector
    where type elem = WideChar.char
    where type substring = WideSubstring.substring
    where type reader = WideTextPrimIO.reader
    where type writer = WideTextPrimIO.writer = WideTextIO.StreamIO
  val () = T.check ("WideTextIO.StreamIO:TEXT_STREAM_IO/generic",
                    fn () => Option.map #1 (GS.inputLine (GS.mkInstream (WideTextPrimIO.openVector (WideString.str (WideChar.chr 0x3BB)),
                                                                         WideString.implode [])))
                             = SOME (WideString.implode [WideChar.chr 0x3BB, WideChar.chr 10]))
  structure GTS : SCR_TEXT_STREAM_IO
    where type vector = CharVector.vector
    where type elem = Char.char
    where type substring = Substring.substring
    where type reader = TextPrimIO.reader
    where type writer = TextPrimIO.writer = TextIO.StreamIO
  val () = T.check ("TextIO.StreamIO:TEXT_STREAM_IO/generic",
                    fn () => Option.map #1 (GTS.inputLine (TextIO.getInstream (TextIO.openString "a"))) = SOME "a\n")
  structure GI : SPEC_IMPERATIVE_IO = WideTextIO
  val () = T.check ("WideTextIO:IMPERATIVE_IO/matches", fn () => true)
  structure GSS : SPEC_STREAM_IO = WideTextIO.StreamIO
  val () = T.check ("WideTextIO.StreamIO:STREAM_IO/matches", fn () => true)
  (* one functor, at either kind of text *)
  structure C8 = TestWideTextIOCountLines (TextIO)
  structure CW = TestWideTextIOCountLines (WideTextIO)
  val () = T.check ("WideTextIO:TEXT_IO/one-functor-for-both",
                    fn () => C8.count (TextIO.openString "a\nb\n") = 2
                             andalso CW.count (WideTextIO.openString (WideString.implode [WideChar.chr 0x3BB, WideChar.chr 10])) = 1)

  structure P : SPEC_PRIM_IO = WideTextPrimIO
  val () = T.check ("WideTextPrimIO:PRIM_IO/matches", fn () => true)
  val () = T.check ("WideTextPrimIO:PRIM_IO/elem-is-WideChar.char",
                    fn () => WideChar.ord (WideChar.chr 97 : P.elem) = 97)
  val () = T.check ("WideTextPrimIO:PRIM_IO/vector-is-WideString.string",
                    fn () => WideString.size (WideString.str (WideChar.chr 97) : P.vector) = 1)
  (* the members of PRIM_IO over the wide character *)
  val () = T.check ("WideTextPrimIO.openVector/reads-a-wide-string",
                    fn () => let val s = WideTextIO.StreamIO.mkInstream
                                           (WideTextPrimIO.openVector (WideString.str (WideChar.chr 0x100)),
                                            WideString.implode [])
                             in WideString.size (#1 (WideTextIO.StreamIO.inputAll s)) = 1 end)
  val () = T.check ("WideTextPrimIO.nullRd/reads-nothing",
                    fn () => let val s = WideTextIO.StreamIO.mkInstream (WideTextPrimIO.nullRd (), WideString.implode [])
                             in WideString.size (#1 (WideTextIO.StreamIO.inputAll s)) = 0 end)
  val () = T.check ("WideTextPrimIO.nullWr/takes-everything",
                    fn () => let val s = WideTextIO.StreamIO.mkOutstream (WideTextPrimIO.nullWr (), IO.NO_BUF)
                             in WideTextIO.StreamIO.output (s, WideString.str (WideChar.chr 97));
                                WideTextIO.StreamIO.closeOut s; true end)
  val () = T.check ("WideTextPrimIO.augmentReader/adds-what-the-reader-lacks",
                    fn () => case WideTextPrimIO.augmentReader (WideTextPrimIO.openVector (WideString.str (WideChar.chr 97))) of
                               WideTextPrimIO.RD {readArr, ...} => isSome readArr)
  val () = T.check ("WideTextPrimIO.augmentWriter/adds-what-the-writer-lacks",
                    fn () => case WideTextPrimIO.augmentWriter (WideTextPrimIO.nullWr ()) of
                               WideTextPrimIO.WR {writeArr, ...} => isSome writeArr)
  (* pos is abstract: the positions come from a reader that has them *)
  val () = T.check ("WideTextPrimIO.compare/of-positions",
                    fn () =>
                      case WideTextPrimIO.openVector (WideString.implode [WideChar.chr 97, WideChar.chr 98]) of
                        WideTextPrimIO.RD {getPos = SOME getPos, readVec = SOME readVec, ...} =>
                          let
                            val first = getPos ()
                            val _ = readVec 1
                            val next = getPos ()
                          in
                            WideTextPrimIO.compare (first, next) = LESS
                            andalso WideTextPrimIO.compare (next, first) = GREATER
                            andalso WideTextPrimIO.compare (first, first) = EQUAL
                          end
                      | _ => false)
  val () = T.check ("WideTextIO.StreamIO.reader/is-that-of-WideTextPrimIO",
                    fn () => let val rd = WideTextPrimIO.openVector (WideString.str (WideChar.chr 97))
                                 val s = WideTextIO.StreamIO.mkInstream (rd, WideString.implode [])
                             in WideString.size (#1 (WideTextIO.StreamIO.inputAll s)) = 1 end)
end
