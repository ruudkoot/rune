(* Checks of fmt and scan (and of toString and fromString in terms of them)
   of a structure with signature INTEGER, for any precision. Expected values
   follow https://smlfamily.github.io/Basis/integer.html.

     structure R = TestIntegerScanFn (structure I = Int8 val name = "Int8")

   needs fn/numstr.sml and a StringCvt structure. The labels are
   name ^ ".member/case"; see fn/integer_fn.sml for the conventions. *)
signature TEST_INTEGER_SCAN =
sig
  eqtype int
  val precision : Int.int option
  val fromInt : Int.int -> int
  val + : int * int -> int
  val - : int * int -> int
  val ~ : int -> int
  val fmt : StringCvt.radix -> int -> string
  val toString : int -> string
  val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (int, 'a) StringCvt.reader
  val fromString : string -> int option
end

functor TestIntegerScanFn (structure I : TEST_INTEGER_SCAN val name : string) =
struct
  fun lab s = name ^ "." ^ s
  fun showI x = I.toString x handle _ => "?"

  fun eqv show (label, expected, f) =
    case (SOME (expected ()) handle _ => NONE) of
      SOME e => T.eq show (label, e, f)
    | NONE => T.fail (label, "the expected value raised an exception")

  val eqS = T.eq T.string
  val eqIO = eqv (T.option showI)
  val eqScan = eqv (T.option (T.pair (showI, T.string)))
  fun overflow (label, f) = T.raises (label, T.isOverflow, f)

  val i = I.fromInt
  val zero = i 0
  val one = i 1
  fun pow2 k = if k <= 0 then one else let val h = pow2 (k - 1) in I.+ (h, h) end

  val radixes = [("BIN", StringCvt.BIN, 2), ("OCT", StringCvt.OCT, 8),
                 ("DEC", StringCvt.DEC, 10), ("HEX", StringCvt.HEX, 16)]

  (* scan on a list of characters; the rest of the stream as a string *)
  fun reader [] = NONE
    | reader (c :: cs) = SOME (c, cs)
  fun scanList radix s =
    Option.map (fn (v, rest) => (v, String.implode rest)) (I.scan radix reader (String.explode s))
  fun scanAll radix s = StringCvt.scanString (I.scan radix) s

  (* ---- fmt: "~" for the sign, digits A to F, no prefix ---- *)
  val () = List.app (fn (c, radix, k, s) => eqS (lab ("fmt/" ^ c), s, fn () => I.fmt radix (i k)))
    [("BIN-zero", StringCvt.BIN, 0, "0"), ("BIN-one", StringCvt.BIN, 1, "1"),
     ("BIN-five", StringCvt.BIN, 5, "101"), ("BIN-minus-five", StringCvt.BIN, ~5, "~101"),
     ("BIN-100", StringCvt.BIN, 100, "1100100"), ("BIN-127", StringCvt.BIN, 127, "1111111"),
     ("OCT-zero", StringCvt.OCT, 0, "0"), ("OCT-seven", StringCvt.OCT, 7, "7"),
     ("OCT-eight", StringCvt.OCT, 8, "10"), ("OCT-100", StringCvt.OCT, 100, "144"),
     ("OCT-minus-100", StringCvt.OCT, ~100, "~144"), ("OCT-127", StringCvt.OCT, 127, "177"),
     ("DEC-zero", StringCvt.DEC, 0, "0"), ("DEC-100", StringCvt.DEC, 100, "100"),
     ("DEC-minus-100", StringCvt.DEC, ~100, "~100"), ("DEC-minus-one", StringCvt.DEC, ~1, "~1"),
     ("HEX-zero", StringCvt.HEX, 0, "0"), ("HEX-nine", StringCvt.HEX, 9, "9"),
     ("HEX-ten", StringCvt.HEX, 10, "A"), ("HEX-eleven", StringCvt.HEX, 11, "B"),
     ("HEX-twelve", StringCvt.HEX, 12, "C"), ("HEX-thirteen", StringCvt.HEX, 13, "D"),
     ("HEX-fourteen", StringCvt.HEX, 14, "E"), ("HEX-fifteen", StringCvt.HEX, 15, "F"),
     ("HEX-sixteen", StringCvt.HEX, 16, "10"), ("HEX-90", StringCvt.HEX, 90, "5A"),
     ("HEX-100", StringCvt.HEX, 100, "64"), ("HEX-minus-100", StringCvt.HEX, ~100, "~64"),
     ("HEX-127", StringCvt.HEX, 127, "7F"), ("HEX-minus-127", StringCvt.HEX, ~127, "~7F"),
     ("HEX-minus-one", StringCvt.HEX, ~1, "~1")]

  (* ---- scan: [+~-]?digits, HEX [+~-]?(0x|0X)?digits, after whitespace ---- *)
  fun scanTable (radixName, radix) cases =
    List.app (fn (c, s, r) =>
      eqScan (lab ("scan/" ^ radixName ^ "-" ^ c),
              fn () => Option.map (fn (k, rest) => (i k, rest)) r,
              fn () => scanList radix s)) cases

  val () = scanTable ("DEC", StringCvt.DEC)
    [("plain", "42", SOME (42, "")), ("rest", "42abc", SOME (42, "abc")),
     ("whitespace-sign-rest", "  ~42 7", SOME (~42, " 7")),
     ("minus", "-42", SOME (~42, "")), ("plus", "+42", SOME (42, "")),
     ("zero", "0", SOME (0, "")), ("tilde-zero", "~0", SOME (0, "")),
     ("leading-zeros", "00012", SOME (12, "")),
     ("whitespace-all-six", " \t\n\v\f\r7", SOME (7, "")),
     ("whitespace-tab", "\t7", SOME (7, "")), ("whitespace-newline", "\n7", SOME (7, "")),
     ("whitespace-vertical-tab", "\v7", SOME (7, "")), ("whitespace-form-feed", "\f7", SOME (7, "")),
     ("whitespace-return", "\r7", SOME (7, "")),
     ("0x-is-no-prefix", "0x1F", SOME (0, "x1F")), ("no-hex-digits", "1F", SOME (1, "F")),
     ("stops-at-second-sign", "1~2", SOME (1, "~2")), ("stops-at-point", "12.5", SOME (12, ".5")),
     ("empty", "", NONE), ("only-whitespace", "  ", NONE), ("letters", "abc", NONE),
     ("only-tilde", "~", NONE), ("only-plus", "+", NONE), ("only-minus", "-", NONE),
     ("space-after-sign", "~ 1", NONE), ("two-signs", "~-1", NONE), ("sign-letter", "-a", NONE)]
  val () = scanTable ("BIN", StringCvt.BIN)
    [("plain", "101", SOME (5, "")), ("tilde", "~101", SOME (~5, "")), ("minus", "-101", SOME (~5, "")),
     ("plus", "+101", SOME (5, "")), ("stops-at-two", "102", SOME (2, "2")),
     ("zero", "0", SOME (0, "")), ("zeros", "000", SOME (0, "")),
     ("seven-ones", "1111111", SOME (127, "")), ("whitespace", "  11", SOME (3, "")),
     ("0b-is-no-prefix", "0b101", SOME (0, "b101")), ("0x-is-no-prefix", "0x1", SOME (0, "x1")),
     ("two", "2", NONE), ("empty", "", NONE), ("only-sign", "~", NONE), ("sign-two", "~2", NONE)]
  val () = scanTable ("OCT", StringCvt.OCT)
    [("plain", "17", SOME (15, "")), ("tilde", "~17", SOME (~15, "")), ("minus", "-17", SOME (~15, "")),
     ("plus", "+17", SOME (15, "")), ("stops-at-eight", "18", SOME (1, "8")),
     ("177", "177", SOME (127, "")), ("whitespace-rest", "\t17 ", SOME (15, " ")),
     ("0o-is-no-prefix", "0o17", SOME (0, "o17")), ("0x-is-no-prefix", "0x17", SOME (0, "x17")),
     ("eight", "8", NONE), ("empty", "", NONE), ("only-sign", "-", NONE), ("sign-nine", "+9", NONE)]
  val () = scanTable ("HEX", StringCvt.HEX)
    [("upper", "1F", SOME (31, "")), ("lower", "1f", SOME (31, "")),
     ("digit-a", "a", SOME (10, "")), ("digit-F", "F", SOME (15, "")),
     ("mixed-case", "4d", SOME (77, "")), ("decimal-digits", "42", SOME (66, "")),
     ("prefix-0x", "0x1F", SOME (31, "")), ("prefix-0X", "0X1f", SOME (31, "")),
     ("tilde-prefix", "~0x1F", SOME (~31, "")), ("minus-prefix", "-0x1F", SOME (~31, "")),
     ("plus-prefix", "+0X1F", SOME (31, "")), ("tilde", "~1F", SOME (~31, "")),
     ("minus", "-1f", SOME (~31, "")), ("plus", "+1f", SOME (31, "")),
     ("whitespace-prefix-rest", "  0x7f rest", SOME (127, " rest")),
     ("stops-at-g", "7Fg", SOME (127, "g")), ("zero-prefix-zero", "0x0", SOME (0, "")),
     (* "strings such as "0xg" and "0x 123" are scanned as SOME(0)": the
        number is the 0, and the stream continues with the x *)
     ("bare-prefix-0x-then-non-digit", "0xg", SOME (0, "xg")), ("bare-prefix-0x-then-space", "0x 123", SOME (0, "x 123")),
     ("bare-prefix-0x", "0x", SOME (0, "x")), ("bare-prefix-0X", "0X", SOME (0, "X")),
     ("bare-prefix-after-tilde", "~0xg", SOME (0, "xg")),
     ("prefix-twice", "0x0x1", SOME (0, "x1")), ("zero-zero-x", "00x1F", SOME (0, "x1F")),
     ("sign-after-prefix", "0x~1", SOME (0, "x~1")),
     ("x-first", "x1F", NONE), ("g", "g", NONE), ("empty", "", NONE), ("only-sign", "~", NONE),
     ("sign-x", "~x1", NONE), ("space-after-sign", "- 1F", NONE)]
  val () = eqIO (lab "scan/HEX-0xg-is-zero", fn () => SOME zero, fn () => scanAll StringCvt.HEX "0xg")
  val () = eqIO (lab "scan/HEX-0x-123-is-zero", fn () => SOME zero, fn () => scanAll StringCvt.HEX "0x 123")

  (* scan with another kind of stream: a position in a string *)
  val () = T.eq (T.option (T.pair (showI, T.int)))
             (lab "scan/string-position", SOME (i 42, 5),
              fn () => let val s = "  +42, 17"
                           fun rd p = if p < String.size s then SOME (String.sub (s, p), p + 1) else NONE
                       in I.scan StringCvt.DEC rd 0 end)
  val () = T.eq (T.option (T.pair (showI, T.int)))
             (lab "scan/string-position-second", SOME (i 17, 9),
              fn () => let val s = "  +42, 17"
                           fun rd p = if p < String.size s then SOME (String.sub (s, p), p + 1) else NONE
                       in I.scan StringCvt.DEC rd 6 end)

  (* ---- toString is fmt DEC; fromString is scanString (scan DEC) ---- *)
  val () = List.app (fn k => eqS (lab ("toString/fmt-DEC-" ^ Int.toString (k + 127)), I.fmt StringCvt.DEC (i k) handle _ => "?",
                                  fn () => I.toString (i k)))
             [~127, ~100, ~10, ~1, 0, 1, 9, 10, 99, 127]
  val () = List.app (fn (c, s) =>
             eqIO (lab ("fromString/scanString-" ^ c), fn () => scanAll StringCvt.DEC s, fn () => I.fromString s))
    [("plain", "42"), ("tilde", "~42"), ("minus", "-42"), ("plus", "+42"), ("whitespace", " \t\n42"),
     ("rest", "42abc"), ("hex-prefix", "0x1F"), ("empty", ""), ("sign-only", "~"), ("letters", "abc"),
     ("space-after-sign", "~ 1"), ("leading-zeros", "007")]

  (* ---- the bounds, in every radix ---- *)
  val () = List.app (fn (rn, radix, r) =>
    case I.precision of
      SOME n =>
        let
          val magLo = NumStr.pow2String r (n - 1)             (* 2^(n-1) = -minInt = maxInt + 1 *)
          val hiText = NumStr.pow2Minus1String r (n - 1)
          val belowLo = NumStr.toString (NumStr.succ r (NumStr.pow2 r (n - 1)))
          fun lo () = let val h = I.~ (pow2 (n - 2)) in I.+ (h, h) end
          fun hi () = let val h = pow2 (n - 2) in I.+ (h, I.- (h, one)) end
        in
          eqS (lab ("fmt/" ^ rn ^ "-minInt"), "~" ^ magLo, fn () => I.fmt radix (lo ()));
          eqS (lab ("fmt/" ^ rn ^ "-maxInt"), hiText, fn () => I.fmt radix (hi ()));
          eqScan (lab ("scan/" ^ rn ^ "-minInt"), fn () => SOME (lo (), ""), fn () => scanList radix ("~" ^ magLo));
          eqScan (lab ("scan/" ^ rn ^ "-minInt-with-minus"), fn () => SOME (lo (), "!"),
                  fn () => scanList radix ("-" ^ magLo ^ "!"));
          eqScan (lab ("scan/" ^ rn ^ "-maxInt"), fn () => SOME (hi (), ""), fn () => scanList radix hiText);
          eqScan (lab ("scan/" ^ rn ^ "-maxInt-with-leading-zeros"), fn () => SOME (hi (), ""),
                  fn () => scanList radix ("+0000000000000000000000000000000000000000" ^ hiText));
          (* "raises Overflow when an integer can be parsed, but is too large" *)
          overflow (lab ("scan/" ^ rn ^ "-Overflow-maxInt-plus-one"), fn () => scanList radix magLo);
          overflow (lab ("scan/" ^ rn ^ "-Overflow-minInt-minus-one"), fn () => scanList radix ("~" ^ belowLo));
          overflow (lab ("scan/" ^ rn ^ "-Overflow-one-more-digit"), fn () => scanList radix (hiText ^ "0"));
          overflow (lab ("scan/" ^ rn ^ "-Overflow-after-whitespace"), fn () => scanList radix (" \n-" ^ hiText ^ "00 "));
          if r = 16 then
            (eqScan (lab "scan/HEX-minInt-with-prefix", fn () => SOME (lo (), ""),
                     fn () => scanList radix ("~0x" ^ magLo));
             eqScan (lab "scan/HEX-maxInt-lower-case", fn () => SOME (hi (), ""),
                     fn () => scanList radix ("0X" ^ NumStr.lower hiText));
             overflow (lab "scan/HEX-Overflow-with-prefix", fn () => scanList radix ("0x" ^ magLo)))
          else ()
        end
    | NONE =>
        let
          val text = NumStr.pow2String r 200
          val less = NumStr.pow2Minus1String r 300
        in
          eqS (lab ("fmt/" ^ rn ^ "-2^200"), text, fn () => I.fmt radix (pow2 200));
          eqS (lab ("fmt/" ^ rn ^ "-~2^200"), "~" ^ text, fn () => I.fmt radix (I.~ (pow2 200)));
          eqS (lab ("fmt/" ^ rn ^ "-2^300-1"), less, fn () => I.fmt radix (I.- (pow2 300, one)));
          eqScan (lab ("scan/" ^ rn ^ "-2^200"), fn () => SOME (pow2 200, ""), fn () => scanList radix text);
          eqScan (lab ("scan/" ^ rn ^ "-~2^200"), fn () => SOME (I.~ (pow2 200), "!"),
                  fn () => scanList radix ("~" ^ text ^ "!"));
          eqScan (lab ("scan/" ^ rn ^ "-2^300-1"), fn () => SOME (I.- (pow2 300, one), ""),
                  fn () => scanList radix less);
          if r = 16 then
            eqScan (lab "scan/HEX-2^300-1-lower-case-with-prefix", fn () => SOME (I.- (pow2 300, one), ""),
                    fn () => scanList radix ("0x" ^ NumStr.lower less))
          else ()
        end) radixes

  (* ---- pseudo-random numbers, built from binary digits (fn/integer_fn.sml) ---- *)
  val samplesBuilt = ref true
  val fullBits = case I.precision of SOME n => n - 1 | NONE => 200

  val () = T.seed 4
  val () = T.repeat (25, fn k =>
    let
      val bits = List.tabulate (T.range (0, fullBits), fn _ => T.range (0, 1) = 1)
      val neg = T.range (0, 1) = 1
      val v = (let val m = List.foldl (fn (b, v) => I.+ (I.+ (v, v), if b then one else zero)) zero bits
               in if neg then I.- (I.~ m, one) else m end)
              handle _ => (samplesBuilt := false; zero)
    in
      List.app (fn (rn, radix, r) =>
        let
          val s = "-" ^ rn ^ "-" ^ Int.toString k
          val ds = NumStr.fromBits r bits
          val digits = NumStr.toString (if neg then NumStr.succ r ds else ds)
          val text = (if neg then "~" else "") ^ digits
        in
          eqS (lab "fmt/model" ^ s, text, fn () => I.fmt radix v);
          eqScan (lab "scan/model" ^ s, fn () => SOME (v, ""), fn () => scanList radix text);
          eqScan (lab "scan/model-lower-case-rest" ^ s, fn () => SOME (v, "!"),
                  fn () => scanList radix ("  " ^ (if neg then "-" else "+") ^ NumStr.lower digits ^ "!"));
          eqIO (lab "scan/fmt-round-trip" ^ s, fn () => SOME v, fn () => scanAll radix (I.fmt radix v))
        end) radixes
    end)
  val () = T.check (lab "fromInt/scan-samples-built", fn () => !samplesBuilt)
end
