(* requires: WideTextIO WideTextPrimIO WideString WideChar Position IO *)
(* uses: spec-sigs/PRIM_IO.sml *)
(* WideTextPrimIO matches PRIM_IO over the wide character, and the types of
   WideTextIO are those of WideString and WideChar. The transcription of
   TEXT_IO writes its types as string and char (the signature of TextIO), so
   WideTextIO is not matched against it. *)
structure TestWideTextIOSig =
struct
  structure P : SPEC_PRIM_IO = WideTextPrimIO
  val () = T.check ("WideTextPrimIO:PRIM_IO/matches", fn () => true)
  val () = T.check ("WideTextPrimIO:PRIM_IO/elem-is-WideChar.char",
                    fn () => WideChar.ord (WideChar.chr 97 : P.elem) = 97)
  val () = T.check ("WideTextPrimIO:PRIM_IO/vector-is-WideString.string",
                    fn () => WideString.size (WideString.str (WideChar.chr 97) : P.vector) = 1)
  val () = T.check ("WideTextIO.vector/is-WideString.string",
                    fn () => WideString.size (WideString.str (WideChar.chr 97) : WideTextIO.vector) = 1)
  val () = T.check ("WideTextIO.elem/is-WideChar.char",
                    fn () => WideChar.ord (WideChar.chr 97 : WideTextIO.elem) = 97)
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
