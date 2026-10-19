(* requires: WideStringCvt WideString WideChar WideSubstring *)
(* The WideStringCvt structure: StringCvt over wide text (an extension, the
   deviation `STRING_CVT/generic`). Expected values follow the text of
   https://smlfamily.github.io/Basis/string-cvt.html read at WideChar.char
   and WideString.string, worked out by hand. The readers are written here,
   over a list of wide characters, so that what the functions are checked
   against does not come from the library. *)
structure TestWideStringCvt =
struct
  val w = WideChar.chr
  val wide = WideString.implode o List.map w
  fun ords s = List.map WideChar.ord (WideString.explode s)
  val eqL = T.eq (T.list T.int)
  val eqLP = T.eq (T.pair (T.list T.int, T.list T.int))
  val eqB = T.eq T.bool
  fun listRd [] = NONE
    | listRd (c :: cs) = SOME (c, cs)
  val lambda = 0x3BB
  val smile = 0x1F600
  fun isLambda c = WideChar.ord c = lambda

  val () = eqL ("WideStringCvt.padLeft/pads-on-the-left", [lambda, lambda, 65],
                fn () => ords (WideStringCvt.padLeft (w lambda) 3 (wide [65])))
  val () = eqL ("WideStringCvt.padLeft/long-enough", [65, 66],
                fn () => ords (WideStringCvt.padLeft (w lambda) 1 (wide [65, 66])))
  val () = eqL ("WideStringCvt.padLeft/negative-width", [65],
                fn () => ords (WideStringCvt.padLeft (w lambda) ~1 (wide [65])))
  val () = T.raises ("WideStringCvt.padLeft/Size", T.isSize,
                     fn () => WideStringCvt.padLeft (w 65) (valOf Int.maxInt) (wide []))
  val () = eqL ("WideStringCvt.padRight/pads-on-the-right", [smile, 46, 46],
                fn () => ords (WideStringCvt.padRight (w 46) 3 (wide [smile])))
  val () = eqL ("WideStringCvt.padRight/long-enough", [65, 66],
                fn () => ords (WideStringCvt.padRight (w 46) 2 (wide [65, 66])))
  val () = T.raises ("WideStringCvt.padRight/Size", T.isSize,
                     fn () => WideStringCvt.padRight (w 65) (valOf Int.maxInt) (wide []))
  val () = eqLP ("WideStringCvt.splitl/a-prefix-and-the-rest", ([lambda, lambda], [65, lambda]),
                 fn () => let val (s, rest) = WideStringCvt.splitl isLambda listRd (List.map w [lambda, lambda, 65, lambda])
                          in (ords s, List.map WideChar.ord rest) end)
  val () = eqLP ("WideStringCvt.splitl/nothing", ([], [65]),
                 fn () => let val (s, rest) = WideStringCvt.splitl isLambda listRd [w 65]
                          in (ords s, List.map WideChar.ord rest) end)
  val () = eqL ("WideStringCvt.takel/a-prefix", [lambda],
                fn () => ords (WideStringCvt.takel isLambda listRd (List.map w [lambda, 66])))
  val () = eqL ("WideStringCvt.dropl/the-rest", [66, lambda],
                fn () => List.map WideChar.ord (WideStringCvt.dropl isLambda listRd (List.map w [lambda, 66, lambda])))
  val () = eqL ("WideStringCvt.skipWS/ascii-white-space", [smile, 32],
                fn () => List.map WideChar.ord (WideStringCvt.skipWS listRd (List.map w [32, 9, 10, 13, 11, 12, smile, 32])))
  (* WideChar.isSpace is ASCII's (the reading WideChar.isAlpha/ascii-classes):
     U+00A0 and U+3000 are not white space to it *)
  val () = eqL ("WideStringCvt.skipWS/no-space-above-127", [0xA0, 32],
                fn () => List.map WideChar.ord (WideStringCvt.skipWS listRd (List.map w [32, 0xA0, 32])))
  val () = eqB ("WideStringCvt.scanString/reads-the-characters", true,
                fn () => WideStringCvt.scanString (fn getc => fn s =>
                                                     case getc s of
                                                       SOME (c, s') => (case getc s' of SOME (d, s'') => SOME ((c, d), s'') | NONE => NONE)
                                                     | NONE => NONE)
                                                  (wide [smile, lambda, 65])
                         = SOME (w smile, w lambda))
  val () = eqB ("WideStringCvt.scanString/a-scan-that-fails", true,
                fn () => WideStringCvt.scanString (fn getc => fn s => NONE : (int * WideStringCvt.cs) option) (wide [65]) = NONE)
  val () = eqB ("WideStringCvt.scanString/WideString.scan", true,
                fn () => WideStringCvt.scanString WideString.scan (wide [65, lambda]) = SOME (wide [65, lambda]))
  val () = eqB ("WideStringCvt.takel/a-substring-reader", true,
                fn () => WideStringCvt.takel isLambda WideSubstring.getc (WideSubstring.full (wide [lambda, 66])) = wide [lambda])
end
