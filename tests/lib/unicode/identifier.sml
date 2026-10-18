(* libraries: test/unit *)
(* Identifier against the data it was made from, read from the files that
   scripts/gen-unicode-tables.py copies to tests/lib/unicode:
   - for every code point, isXIDStart, isXIDContinue and isDefaultIgnorable
     as DerivedCoreProperties.txt lists XID_Start, XID_Continue and
     Default_Ignorable_Code_Point;
   - the frozen default ignorables: XID_Continue and
     Default_Ignorable_Code_Point both, 269 code points;
   - the frozen lookalikes, none of them Recommended by IdentifierType.txt:
     the identifier characters above ASCII whose skeleton (UTS #39, made
     here from confusables.txt, the default ignorables and
     Normalize.nfdList) is one character of Standard ML's punctuation (76)
     or a digit (116); and as listed below, the decimal digits that look
     like 0 and 1 (21), whose skeletons are O and l, U+00B7, and the
     lookalikes of `|` (25), whose skeleton is `l`;
   - the profile, isStart and isContinue for every code point, as the
     grammar of docs/plans/utf8.md (The architecture, Identifiers) has it;
   - names of several scripts, taken and refused.
   The frozen sets are those of Unicode 18.0.0 and do not change with
   Unicode's data: when the files are of a later version, what fails here
   is what the new data would change, for a person to decide. Run from the
   top of the tree. *)
structure IdentifierTest =
struct
  fun hex s = valOf (StringCvt.scanString (Int.scan StringCvt.HEX) s)
  fun u c = "U+" ^ StringCvt.padLeft #"0" 4 (Int.fmt StringCvt.HEX c)

  (* the data lines of a file of the UCD: the code points from, to, and the
     fields after them *)
  fun records file =
    let
      val f = TextIO.openIn ("tests/lib/unicode/" ^ file)
      fun field s = String.concatWith " " (String.tokens Char.isSpace s)
      fun record l =
        case String.fields (fn c => c = #";") (hd (String.fields (fn c => c = #"#") l)) of
          r :: fs =>
            (case String.tokens (fn c => c = #".") (field r) of
               [lo] => SOME (hex lo, hex lo, map field fs)
             | [lo, hi] => SOME (hex lo, hex hi, map field fs)
             | _ => NONE)
        | [] => NONE
      fun loop acc =
        case TextIO.inputLine f of
          NONE => rev acc
        | SOME l => loop (case record l of SOME r => r :: acc | NONE => acc)
    in
      loop [] before TextIO.closeIn f
    end

  (* what the files say of each code point, bits of a character: 1
     XID_Start, 2 XID_Continue, 4 Default_Ignorable_Code_Point, 8 an
     Identifier_Type of Recommended *)
  val flags = CharArray.array (0x110000, #"\000")
  fun set (lo, hi, bit) =
    if lo > hi then ()
    else
      let val x = Char.ord (CharArray.sub (flags, lo))
      in
        if x div bit mod 2 = 0 then CharArray.update (flags, lo, Char.chr (x + bit)) else ();
        set (lo + 1, hi, bit)
      end
  fun has bit c = Char.ord (CharArray.sub (flags, c)) div bit mod 2 = 1
  val xidStart = has 1 and xidContinue = has 2 and ignorable = has 4 and recommended = has 8

  val () =
    List.app (fn (lo, hi, fs) =>
                case fs of
                  ["XID_Start"] => set (lo, hi, 1)
                | ["XID_Continue"] => set (lo, hi, 2)
                | ["Default_Ignorable_Code_Point"] => set (lo, hi, 4)
                | _ => ())
             (records "DerivedCoreProperties.txt")
  val () =
    List.app (fn (lo, hi, [types]) =>
                if List.exists (fn t => t = "Recommended") (String.tokens Char.isSpace types)
                then set (lo, hi, 8) else ()
               | _ => ())
             (records "IdentifierType.txt")

  (* confusables.txt: the prototype of each source, [] for none *)
  val prototypes = Array.array (0x110000, [] : int list)
  val () =
    List.app (fn (c, _, target :: _) => Array.update (prototypes, c, map hex (String.tokens Char.isSpace target))
               | _ => ())
             (records "confusables.txt")

  (* the skeleton of UTS #39, section 4 *)
  fun skeleton cs =
    let
      val d = List.filter (fn c => not (ignorable c)) (Normalize.nfdList cs)
    in
      Normalize.nfdList (List.concat (map (fn c => case Array.sub (prototypes, c) of [] => [c] | p => p) d))
    end

  val punctuation = "!%&$#+-/:<=>?@\\~`^|*()[]{},;.'\"_"

  (* the lookalikes of `|` taken by hand *)
  val bars = [0x01C0, 0x07CA, 0x16C1, 0x217C, 0x2C92, 0x2D4F, 0xA4F2, 0xA7FE, 0xFE8D, 0x1028A, 0x10309,
              0x1050E, 0x10926, 0x10C3E, 0x10CA5, 0x11DDA, 0x11DE1, 0x16D63, 0x16F28, 0x1D5C5, 0x1D5F9,
              0x1D62D, 0x1D661, 0x1E141, 0x1EE00]

  (* the decimal digits that look like 0 and like 1 *)
  val zeros = [0x07C0, 0xFF10, 0x118E0, 0x11DE0, 0x1CCF0, 0x1D7CE, 0x1D7D8, 0x1D7E2, 0x1D7EC, 0x1D7F6,
               0x1E140, 0x1E2F0, 0x1FBF0]
  val ones = [0xFF11, 0x1CCF1, 0x1D7CF, 0x1D7D9, 0x1D7E3, 0x1D7ED, 0x1D7F7, 0x1FBF1]

  fun among (c, l) = List.exists (fn x => x = c) l

  (* what the frozen lists should hold of c, as confusables.txt seeds them:
     the ASCII character c looks like *)
  fun seeded c =
    if c < 0x80 orelse not (xidContinue c) then NONE
    else if c = 0xB7 then SOME #"."
    else if among (c, bars) then SOME #"|"
    else if among (c, zeros) then SOME #"0"
    else if among (c, ones) then SOME #"1"
    else if recommended c then NONE
    else
      case skeleton [c] of
        [a] =>
          if a >= 0x80 then NONE
          else if CharVector.exists (fn p => p = Char.chr a) punctuation then SOME (Char.chr a)
          else if Char.isDigit (Char.chr a) then SOME (Char.chr a)
          else NONE
      | _ => NONE

  (* the code points for which ok fails, the first ten *)
  fun failures ok =
    let
      fun go (c, bad) =
        if c > 0x10FFFF orelse length bad >= 10 then rev bad
        else go (c + 1, if ok c then bad else c :: bad)
    in
      go (0, [])
    end

  fun everyCodePoint (what, ok) () =
    let val bad = failures ok
    in
      List.app (fn c => Expect.that (what ^ ": " ^ u c, false)) bad;
      Expect.that (what ^ ", for every code point", null bad)
    end

  (* the frozen sets, as the profile leaves them out *)
  fun leftOut c = isSome (Identifier.exclusion c)
  fun expectedExclusion c =
    if c >= 0x80 andalso xidContinue c andalso ignorable c then SOME Identifier.Ignorable
    else Option.map Identifier.Lookalike (seeded c)

  fun asciiLetter c = (c >= 0x41 andalso c <= 0x5A) orelse (c >= 0x61 andalso c <= 0x7A)

  fun count p =
    let fun go (c, n) = if c > 0x10FFFF then n else go (c + 1, if p c then n + 1 else n)
    in go (0, 0) end

  fun sizes () =
    let
      fun lookalike p c = case Identifier.exclusion c of SOME (Identifier.Lookalike a) => p a | _ => false
    in
      Expect.that ("269 default ignorables are left out",
                   count (fn c => Identifier.exclusion c = SOME Identifier.Ignorable) = 269);
      Expect.that ("239 lookalikes", count (lookalike (fn _ => true)) = 239);
      Expect.that ("116 of the digits 2 to 9", count (lookalike (fn a => Char.isDigit a andalso a > #"1")) = 116);
      Expect.that ("13 of 0", count (lookalike (fn a => a = #"0")) = 13);
      Expect.that ("8 of 1", count (lookalike (fn a => a = #"1")) = 8);
      Expect.that ("25 of |", count (lookalike (fn a => a = #"|")) = 25);
      Expect.that ("76 of the rest of the punctuation, and the middle dot",
                   count (lookalike (fn a => not (Char.isDigit a) andalso a <> #"|")) = 77);
      Expect.that ("the bars are not Recommended and their skeleton is l",
                   List.all (fn b => not (recommended b) andalso skeleton [b] = [0x6C]) bars);
      Expect.that ("the zeros and ones are not Recommended and look like O and l",
                   List.all (fn z => not (recommended z) andalso skeleton [z] = [0x4F]) zeros
                   andalso List.all (fn z => not (recommended z) andalso skeleton [z] = [0x6C]) ones);
      Expect.that ("the middle dot is its own skeleton", skeleton [0xB7] = [0xB7])
    end

  (* names, as UTF-8 *)
  val taken = [
    ("Greek", "\206\187\207\140\206\179\206\191\207\130"),
    ("Cyrillic", "\209\128\208\176\208\177\208\190\209\130\208\176"),
    ("Han", "\229\164\137\230\149\176"),
    ("Devanagari", "\224\164\168\224\164\174\224\164\184\224\165\141\224\164\164\224\165\135"),
    ("Hebrew", "\215\169\215\156\215\149\215\157"),
    ("Tamil with a vowel sign", "\224\174\149\224\174\190"),
    ("a mark after a letter", "e\204\129"),
    ("ASCII", "x'_1"),
    ("Cyrillic be, a Recommended lookalike of 6", "\208\177"),
    ("Hebrew yod, a Recommended lookalike of '", "\215\153\215\149\215\157"),
    ("Katakana no, a Recommended lookalike of /", "\227\131\142\227\131\188\227\131\137")]
  val refused = [
    ("a Hangul filler", "\227\133\164"),
    ("a joiner", "a\226\128\141b"),
    ("a variation selector", "a\239\184\143"),
    ("a modifier apostrophe", "\202\188a"),
    ("a click like !", "a\199\131"),
    ("a dental click like |", "\199\128"),
    ("a middle dot", "l\194\183l"),
    ("a fullwidth digit", "x\239\188\146"),
    ("a fullwidth digit zero", "x\239\188\144"),
    ("a slanted stroke like |", "a\240\157\152\173"),
    ("a subscript digit", "x\226\130\129"),
    ("a mark first", "\204\129e"),
    ("a digit first", "1x"),
    ("an underscore first", "_x"),
    ("ill-formed", "a\255"),
    ("empty", "")]

  fun names () =
    (List.app (fn (what, s) => Expect.that ("taken: " ^ what, Identifier.isAlphanumeric s)) taken;
     List.app (fn (what, s) => Expect.that ("refused: " ^ what, not (Identifier.isAlphanumeric s))) refused)

  val tests =
    Test.describe "unicode/identifier"
      [Test.it "XID_Start" (everyCodePoint ("isXIDStart", fn c => Identifier.isXIDStart c = xidStart c)),
       Test.it "XID_Continue" (everyCodePoint ("isXIDContinue", fn c => Identifier.isXIDContinue c = xidContinue c)),
       Test.it "Default_Ignorable" (everyCodePoint ("isDefaultIgnorable", fn c => Identifier.isDefaultIgnorable c = ignorable c)),
       Test.it "frozen" (everyCodePoint ("exclusion", fn c => Identifier.exclusion c = expectedExclusion c)),
       Test.it "frozen-sizes" sizes,
       Test.it "start" (everyCodePoint ("isStart", fn c =>
         Identifier.isStart c = (asciiLetter c orelse (c >= 0x80 andalso xidStart c andalso not (leftOut c))))),
       Test.it "continue" (everyCodePoint ("isContinue", fn c =>
         Identifier.isContinue c
         = (asciiLetter c orelse (c >= 0x30 andalso c <= 0x39) orelse c = 0x5F orelse c = 0x27
            orelse (c >= 0x80 andalso xidContinue c andalso not (leftOut c))))),
       Test.it "names" names]
end

structure IdentifierMain = Main (struct val name = "unicode/identifier" val tests = IdentifierTest.tests end)
val () = IdentifierMain.main ()
