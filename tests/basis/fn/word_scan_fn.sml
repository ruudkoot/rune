(* Checks of fmt and scan (and of toString and fromString in terms of them)
   of a structure with signature WORD, for any word size. Expected values
   follow https://smlfamily.github.io/Basis/word.html.

     structure R = TestWordScanFn (structure W = Word8 val name = "Word8")

   needs fn/numstr.sml and a StringCvt structure. The labels are
   name ^ ".member/case"; see fn/word_fn.sml for the conventions. *)
signature TEST_WORD_SCAN =
sig
  eqtype word
  val wordSize : int
  val fromInt : int -> word
  val + : word * word -> word
  val fmt : StringCvt.radix -> word -> string
  val toString : word -> string
  val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (word, 'a) StringCvt.reader
  val fromString : string -> word option
end

functor TestWordScanFn (structure W : TEST_WORD_SCAN val name : string) =
struct
  val ws = W.wordSize
  fun lab s = name ^ "." ^ s
  fun showW x = "0wx" ^ W.toString x handle _ => "?"

  fun eqv show (label, expected, f) =
    case (SOME (expected ()) handle _ => NONE) of
      SOME e => T.eq show (label, e, f)
    | NONE => T.fail (label, "the expected value raised an exception")

  val eqS = T.eq T.string
  val eqWO = eqv (T.option showW)
  val eqScan = eqv (T.option (T.pair (showW, T.string)))
  fun overflow (label, f) = T.raises (label, T.isOverflow, f)

  val w = W.fromInt
  val zero = w 0
  val one = w 1
  fun wordOfBits bits = List.foldl (fn (b, v) => W.+ (W.+ (v, v), if b then one else zero)) zero bits
  fun copies (n, b : bool) = List.tabulate (if n < 0 then 0 else n, fn _ => b)
  fun allOnes () = wordOfBits (copies (ws, true))
  fun top () = wordOfBits (true :: copies (ws - 1, false))

  (* radix, its number, and the prefix that scan accepts for it *)
  val radixes = [("BIN", StringCvt.BIN, 2, "0w"), ("OCT", StringCvt.OCT, 8, "0w"),
                 ("DEC", StringCvt.DEC, 10, "0w"), ("HEX", StringCvt.HEX, 16, "0wx")]

  fun reader [] = NONE
    | reader (c :: cs) = SOME (c, cs)
  fun scanList radix s =
    Option.map (fn (v, rest) => (v, String.implode rest)) (W.scan radix reader (String.explode s))
  fun scanAll radix s = StringCvt.scanString (W.scan radix) s

  (* ---- fmt: digits A to F, no prefix ---- *)
  val () = List.app (fn (c, radix, k, s) => eqS (lab ("fmt/" ^ c), s, fn () => W.fmt radix (w k)))
    [("BIN-zero", StringCvt.BIN, 0, "0"), ("BIN-one", StringCvt.BIN, 1, "1"),
     ("BIN-five", StringCvt.BIN, 5, "101"), ("BIN-100", StringCvt.BIN, 100, "1100100"),
     ("BIN-255", StringCvt.BIN, 255, "11111111"),
     ("OCT-zero", StringCvt.OCT, 0, "0"), ("OCT-seven", StringCvt.OCT, 7, "7"),
     ("OCT-eight", StringCvt.OCT, 8, "10"), ("OCT-100", StringCvt.OCT, 100, "144"),
     ("OCT-255", StringCvt.OCT, 255, "377"),
     ("DEC-zero", StringCvt.DEC, 0, "0"), ("DEC-nine", StringCvt.DEC, 9, "9"),
     ("DEC-ten", StringCvt.DEC, 10, "10"), ("DEC-100", StringCvt.DEC, 100, "100"),
     ("DEC-255", StringCvt.DEC, 255, "255"),
     ("HEX-zero", StringCvt.HEX, 0, "0"), ("HEX-ten", StringCvt.HEX, 10, "A"),
     ("HEX-fifteen", StringCvt.HEX, 15, "F"), ("HEX-sixteen", StringCvt.HEX, 16, "10"),
     ("HEX-171", StringCvt.HEX, 171, "AB"), ("HEX-205", StringCvt.HEX, 205, "CD"),
     ("HEX-239", StringCvt.HEX, 239, "EF"), ("HEX-255", StringCvt.HEX, 255, "FF")]

  (* ---- scan: (0w)?digits, HEX (0wx | 0wX | 0x | 0X)?digits, after whitespace ---- *)
  fun scanTable (radixName, radix) cases =
    List.app (fn (c, s, r) =>
      eqScan (lab ("scan/" ^ radixName ^ "-" ^ c),
              fn () => Option.map (fn (k, rest) => (w k, rest)) r,
              fn () => scanList radix s)) cases

  val () = scanTable ("DEC", StringCvt.DEC)
    [("plain", "42", SOME (42, "")), ("prefix", "0w42", SOME (42, "")), ("rest", "42abc", SOME (42, "abc")),
     ("whitespace-rest", "  42 ", SOME (42, " ")), ("whitespace-prefix", "\n0w42", SOME (42, "")),
     ("leading-zeros", "0042", SOME (42, "")), ("255", "255", SOME (255, "")), ("zero", "0", SOME (0, "")),
     ("prefix-zero", "0w0", SOME (0, "")),
     ("whitespace-all-six", " \t\n\v\f\r7", SOME (7, "")),
     ("whitespace-tab", "\t7", SOME (7, "")), ("whitespace-newline", "\n7", SOME (7, "")),
     ("whitespace-vertical-tab", "\v7", SOME (7, "")), ("whitespace-form-feed", "\f7", SOME (7, "")),
     ("whitespace-return", "\r7", SOME (7, "")),
     (* a prefix without a digit after it is not part of the number, but its 0 is one *)
     ("bare-prefix-0w-then-x", "0wx42", SOME (0, "wx42")), ("bare-prefix-0w", "0w", SOME (0, "w")),
     ("bare-prefix-0w-then-space", "0w 1", SOME (0, "w 1")), ("prefix-twice", "0w0w1", SOME (0, "w1")),
     ("0x-is-no-prefix", "0x42", SOME (0, "x42")), ("no-hex-digits", "1F", SOME (1, "F")),
     ("upper-case-prefix", "0W42", SOME (0, "W42")),
     ("empty", "", NONE), ("only-whitespace", "  ", NONE), ("letters", "abc", NONE),
     ("tilde", "~1", NONE), ("minus", "-1", NONE), ("plus", "+1", NONE), ("w-first", "w42", NONE)]
  val () = scanTable ("BIN", StringCvt.BIN)
    [("plain", "101", SOME (5, "")), ("prefix", "0w101", SOME (5, "")), ("stops-at-two", "102", SOME (2, "2")),
     ("eight-ones", "11111111", SOME (255, "")), ("whitespace", "\t 11", SOME (3, "")),
     ("bare-prefix-0w-then-two", "0w2", SOME (0, "w2")), ("bare-prefix-0w-then-x", "0wx1", SOME (0, "wx1")),
     ("0x-is-no-prefix", "0x1", SOME (0, "x1")),
     ("two", "2", NONE), ("empty", "", NONE), ("tilde", "~1", NONE)]
  val () = scanTable ("OCT", StringCvt.OCT)
    [("plain", "17", SOME (15, "")), ("prefix", "0w17", SOME (15, "")), ("stops-at-eight", "18", SOME (1, "8")),
     ("377", "377", SOME (255, "")), ("whitespace-rest", " 17 ", SOME (15, " ")),
     ("bare-prefix-0w-then-eight", "0w8", SOME (0, "w8")), ("0x-is-no-prefix", "0x17", SOME (0, "x17")),
     ("eight", "8", NONE), ("empty", "", NONE), ("minus", "-1", NONE)]
  val () = scanTable ("HEX", StringCvt.HEX)
    [("lower", "ff", SOME (255, "")), ("upper", "FF", SOME (255, "")), ("mixed", "aB", SOME (171, "")),
     ("decimal-digits", "42", SOME (66, "")),
     ("prefix-0wx", "0wxff", SOME (255, "")), ("prefix-0wX", "0wXFF", SOME (255, "")),
     ("prefix-0x", "0xff", SOME (255, "")), ("prefix-0X", "0XfF", SOME (255, "")),
     ("whitespace-prefix-rest", "  0wxff rest", SOME (255, " rest")), ("stops-at-g", "ffg", SOME (255, "g")),
     ("prefix-zero", "0wx0", SOME (0, "")),
     (* 0w is a prefix of the other radices only. (SML/NJ 110.79 and
        Poly/ML 5.7.1 read 0w12 as 0wx12; the format of the specification,
        (0wx | 0wX | 0x | 0X)?[0-9a-fA-F]+, does not.) *)
     ("0w-is-no-prefix", "0w12", SOME (0, "w12")),
     ("bare-prefix-0wx-then-non-digit", "0wxg", SOME (0, "wxg")), ("bare-prefix-0wx", "0wx", SOME (0, "wx")),
     ("bare-prefix-0x", "0x", SOME (0, "x")), ("bare-prefix-0x-then-space", "0x 12", SOME (0, "x 12")),
     ("upper-case-w", "0Wxff", SOME (0, "Wxff")), ("prefix-twice", "0x0wx1", SOME (0, "wx1")),
     ("empty", "", NONE), ("letter", "g", NONE), ("tilde", "~ff", NONE), ("minus", "-ff", NONE),
     ("plus", "+ff", NONE), ("x-first", "x1", NONE), ("w-first", "wx1", NONE)]

  (* scan with another kind of stream: a position in a string *)
  val () = T.eq (T.option (T.pair (showW, T.int)))
             (lab "scan/string-position", SOME (w 42, 6),
              fn () => let val s = "  0w42, 17"
                           fun rd p = if p < String.size s then SOME (String.sub (s, p), p + 1) else NONE
                       in W.scan StringCvt.DEC rd 0 end)

  (* ---- toString is fmt HEX; fromString is scanString (scan HEX) ---- *)
  val () = List.app (fn k => eqS (lab ("toString/fmt-HEX-" ^ Int.toString k), W.fmt StringCvt.HEX (w k) handle _ => "?",
                                  fn () => W.toString (w k)))
             [0, 1, 9, 10, 15, 16, 100, 171, 255]
  val () = List.app (fn (c, s) =>
             eqWO (lab ("fromString/scanString-" ^ c), fn () => scanAll StringCvt.HEX s, fn () => W.fromString s))
    [("plain", "ff"), ("upper", "FF"), ("prefix-0wx", "0wxff"), ("prefix-0X", "0Xff"), ("whitespace", " \t\nff"),
     ("rest", "ffg"), ("only-prefix", "0wx"), ("0w", "0w12"), ("empty", ""), ("sign", "~1"), ("letters", "xyz"),
     ("leading-zeros", "00ff")]

  (* ---- 2^wordSize - 1 and its neighbours, in every radix ---- *)
  val () = List.app (fn (rn, radix, r, prefix) =>
    let
      val onesText = NumStr.pow2Minus1String r ws
      val above = NumStr.pow2String r ws                  (* 2^wordSize *)
      val topText = NumStr.pow2String r (ws - 1)
    in
      eqS (lab ("fmt/" ^ rn ^ "-all-ones"), onesText, fn () => W.fmt radix (allOnes ()));
      eqS (lab ("fmt/" ^ rn ^ "-top-bit"), topText, fn () => W.fmt radix (top ()));
      eqScan (lab ("scan/" ^ rn ^ "-all-ones"), fn () => SOME (allOnes (), ""), fn () => scanList radix onesText);
      eqScan (lab ("scan/" ^ rn ^ "-all-ones-with-prefix"), fn () => SOME (allOnes (), "!"),
              fn () => scanList radix (prefix ^ onesText ^ "!"));
      eqScan (lab ("scan/" ^ rn ^ "-all-ones-with-leading-zeros"), fn () => SOME (allOnes (), ""),
              fn () => scanList radix ("0000000000000000000000000000000000000000" ^ onesText));
      eqScan (lab ("scan/" ^ rn ^ "-top-bit"), fn () => SOME (top (), ""), fn () => scanList radix topText);
      (* "It raises Overflow when a number can be parsed, but is too large to fit in type word." *)
      overflow (lab ("scan/" ^ rn ^ "-Overflow-two-to-the-wordSize"), fn () => scanList radix above);
      overflow (lab ("scan/" ^ rn ^ "-Overflow-with-prefix"), fn () => scanList radix (prefix ^ above));
      overflow (lab ("scan/" ^ rn ^ "-Overflow-one-more-digit"), fn () => scanList radix (onesText ^ "0"));
      overflow (lab ("scan/" ^ rn ^ "-Overflow-after-whitespace"), fn () => scanList radix (" \n" ^ onesText ^ "11 "))
    end) radixes

  (* ---- pseudo-random words, built from binary digits (fn/word_fn.sml) ---- *)
  val () = T.seed 10
  val () = T.repeat (25, fn k =>
    let
      val m = if T.range (0, 2) = 0 then ws else T.range (0, ws)
      val bits = copies (ws - m, false) @ List.tabulate (m, fn _ => T.range (0, 1) = 1)
      val a = wordOfBits bits handle _ => zero
    in
      List.app (fn (rn, radix, r, prefix) =>
        let
          val s = "-" ^ rn ^ "-" ^ Int.toString k
          val text = NumStr.toString (NumStr.fromBits r bits)
        in
          eqS (lab "fmt/model" ^ s, text, fn () => W.fmt radix a);
          eqScan (lab "scan/model" ^ s, fn () => SOME (a, ""), fn () => scanList radix text);
          eqScan (lab "scan/model-prefix-lower-case-rest" ^ s, fn () => SOME (a, "!"),
                  fn () => scanList radix ("  " ^ prefix ^ NumStr.lower text ^ "!"));
          eqWO (lab "scan/fmt-round-trip" ^ s, fn () => SOME a, fn () => scanAll radix (W.fmt radix a))
        end) radixes
    end)
end
