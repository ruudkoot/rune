(* libraries: test/unit *)
(* CodePoint against the data, read from the files that
   bin/rune-generate unicode copies to tests/lib/unicode:
   - the categories: the 30 values of General_Category that
     PropertyValueAliases.txt lists, each by its abbreviation, its long
     name the constructor's, and in the class its groups give it;
   - for every code point, category as UnicodeData.txt gives it, a range
     of <..., First> and <..., Last> included and a code point it does not
     list Cn. The tables are made from DerivedGeneralCategory.txt, so the
     two files check each other;
   - for every code point, toUpper, toLower and toTitle as the fields 12,
     13 and 14 of UnicodeData.txt give them, an empty titlecase being the
     uppercase (UAX #44, 5.3) and an empty field the code point itself;
   - the laws of the signature, for every code point;
   - integers that are no code points.
   Run from the top of the tree. *)
structure CodePointTest =
struct
  structure C = CodePoint

  fun hex s = valOf (StringCvt.scanString (Int.scan StringCvt.HEX) s)
  fun u c = "U+" ^ StringCvt.padLeft #"0" 4 (Int.fmt StringCvt.HEX c)
  val top = 0x110000

  (* the lines of a file of tests/lib/unicode that are not comments, each
     its fields, the blanks around them trimmed *)
  fun lines file =
    let
      val f = TextIO.openIn ("tests/lib/unicode/" ^ file)
      fun trim s = String.concatWith " " (String.tokens Char.isSpace s)
      fun loop acc =
        case TextIO.inputLine f of
          NONE => rev acc
        | SOME l =>
            let val l = String.substring (l, 0, size l - (if String.isSuffix "\n" l then 1 else 0))
            in
              if l = "" orelse String.sub (l, 0) = #"#" then loop acc
              else loop (map trim (String.fields (fn c => c = #";") l) :: acc)
            end
    in
      loop [] before TextIO.closeIn f
    end

  (* the categories with their long names, as PropertyValueAliases.txt
     gives them *)
  val named =
    [(C.UppercaseLetter, "Uppercase_Letter"), (C.LowercaseLetter, "Lowercase_Letter"),
     (C.TitlecaseLetter, "Titlecase_Letter"), (C.ModifierLetter, "Modifier_Letter"),
     (C.OtherLetter, "Other_Letter"), (C.NonspacingMark, "Nonspacing_Mark"),
     (C.SpacingMark, "Spacing_Mark"), (C.EnclosingMark, "Enclosing_Mark"),
     (C.DecimalNumber, "Decimal_Number"), (C.LetterNumber, "Letter_Number"),
     (C.OtherNumber, "Other_Number"), (C.ConnectorPunctuation, "Connector_Punctuation"),
     (C.DashPunctuation, "Dash_Punctuation"), (C.OpenPunctuation, "Open_Punctuation"),
     (C.ClosePunctuation, "Close_Punctuation"), (C.InitialPunctuation, "Initial_Punctuation"),
     (C.FinalPunctuation, "Final_Punctuation"), (C.OtherPunctuation, "Other_Punctuation"),
     (C.MathSymbol, "Math_Symbol"), (C.CurrencySymbol, "Currency_Symbol"),
     (C.ModifierSymbol, "Modifier_Symbol"), (C.OtherSymbol, "Other_Symbol"),
     (C.SpaceSeparator, "Space_Separator"), (C.LineSeparator, "Line_Separator"),
     (C.ParagraphSeparator, "Paragraph_Separator"), (C.Control, "Control"),
     (C.Format, "Format"), (C.Surrogate, "Surrogate"), (C.PrivateUse, "Private_Use"),
     (C.Unassigned, "Unassigned")]
  val all = map #1 named

  (* the classes, by their names in PropertyValueAliases.txt *)
  val classes =
    [("Letter", C.Letter), ("Mark", C.Mark), ("Number", C.Number), ("Punctuation", C.Punctuation),
     ("Symbol", C.Symbol), ("Separator", C.Separator), ("Other", C.Other)]

  (* the lines gc of PropertyValueAliases.txt: the abbreviation, the long
     name, and the members of a group (after "#"), [] for a category *)
  val aliases =
    List.mapPartial
      (fn "gc" :: short :: rest =>
            let
              val last = List.last rest
              val (long, members) =
                case String.fields (fn c => c = #"#") (hd rest) of
                  [long, ms] => (String.concatWith "" (String.tokens Char.isSpace long),
                                 String.tokens (fn c => c = #"|" orelse Char.isSpace c) ms)
                | _ => (hd rest, [])
              val members =
                if null members then
                  case String.fields (fn c => c = #"#") last of
                    [_, ms] => String.tokens (fn c => c = #"|" orelse Char.isSpace c) ms
                  | _ => []
                else members
            in
              SOME (short, long, members)
            end
        | _ => NONE)
      (lines "PropertyValueAliases.txt")

  fun categories () =
    let
      val values = List.filter (fn (_, _, ms) => null ms) aliases
      val groups = List.filter (fn (_, _, ms) => not (null ms)) aliases
    in
      Expect.that ("30 categories in PropertyValueAliases.txt", length values = 30);
      Expect.that ("30 categories in the datatype", length all = 30);
      List.app
        (fn (short, long, _) =>
           case C.fromAbbreviation short of
             NONE => Expect.that ("a category for " ^ short, false)
           | SOME g =>
               (Expect.that ("abbreviation of " ^ short, C.abbreviation g = short);
                Expect.that ("long name of " ^ short,
                             List.exists (fn (h, n) => h = g andalso n = long) named)))
        values;
      List.app
        (fn (short, long, members) =>
           case List.find (fn (n, _) => n = long) classes of
             NONE => Expect.that ("the group " ^ short ^ " is Cased_Letter", short = "LC")
           | SOME (_, m) =>
               (Expect.that ("the group " ^ short ^ " is named by its letter", size short = 1);
                Expect.that ("the members of " ^ short,
                             List.all (fn g => (C.major g = m) = List.exists (fn x => x = C.abbreviation g) members) all)))
        groups;
      Expect.that ("abbreviations are two letters, the first the class's",
                   List.all (fn g => size (C.abbreviation g) = 2) all);
      Expect.that ("no category for L, LC or the empty string",
                   List.all (fn s => not (isSome (C.fromAbbreviation s))) ["L", "LC", "", "lu", "Lux"])
    end

  (* UnicodeData.txt: the category of each code point as an index of all,
     and the simple mappings, each sorted by code point *)
  val index = CharArray.array (top, Char.chr 29)
  val upper = ref [] : (int * int) list ref
  val lower = ref [] : (int * int) list ref
  val title = ref [] : (int * int) list ref
  fun indexOf short =
    let
      fun go (i, []) = raise Fail ("an unknown category " ^ short)
        | go (i, g :: gs) = if C.abbreviation g = short then i else go (i + 1, gs)
    in
      go (0, all)
    end
  fun fill (lo, hi, i) = if lo > hi then () else (CharArray.update (index, lo, Char.chr i); fill (lo + 1, hi, i))
  val () =
    let
      fun add (r, c, s) = if s = "" then () else r := (c, hex s) :: !r
      fun loop (first, []) = ()
        | loop (first, (code :: name :: gc :: f) :: rest) =
            let val c = hex code val i = indexOf gc
            in
              if String.isSuffix "First>" name then loop (SOME c, rest)
              else
                ((case first of SOME a => fill (a, c, i) | NONE => fill (c, c, i));
                 add (upper, c, List.nth (f, 9));
                 add (lower, c, List.nth (f, 10));
                 add (title, c, if List.nth (f, 11) = "" then List.nth (f, 9) else List.nth (f, 11));
                 loop (NONE, rest))
            end
        | loop (_, _ :: rest) = raise Fail "a record of UnicodeData.txt with too few fields"
    in
      loop (NONE, lines "UnicodeData.txt");
      upper := rev (!upper); lower := rev (!lower); title := rev (!title)
    end
  val byIndex = Vector.fromList all
  fun categoryOf c = Vector.sub (byIndex, Char.ord (CharArray.sub (index, c)))

  (* the code points for which ok fails, the first ten *)
  fun failures ok =
    let
      fun go (c, bad) =
        if c >= top orelse length bad >= 10 then rev bad
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

  (* f against the mappings ms, sorted, a code point not among them mapping
     to itself *)
  fun mapsAs (what, f, ms) () =
    let
      fun go (c, ms, bad) =
        if c >= top orelse length bad >= 10 then rev bad
        else
          case ms of
            (d, m) :: rest =>
              if c = d then go (c + 1, rest, if f c = m then bad else c :: bad)
              else go (c + 1, ms, if f c = c then bad else c :: bad)
          | [] => go (c + 1, ms, if f c = c then bad else c :: bad)
      val bad = go (0, ms, [])
    in
      List.app (fn c => Expect.that (what ^ ": " ^ u c, false)) bad;
      Expect.that (what ^ ", for every code point", null bad)
    end

  (* integers that are no code points *)
  fun beyond () =
    let
      val big = case Int.maxInt of SOME m => [m] | NONE => []
      val small = case Int.minInt of SOME m => [m] | NONE => []
      val ns = [~1, ~0x41, top, top + 0x41] @ big @ small
    in
      Expect.that ("Unassigned", List.all (fn n => C.category n = C.Unassigned) ns);
      Expect.that ("toUpper of itself", List.all (fn n => C.toUpper n = n) ns);
      Expect.that ("toLower of itself", List.all (fn n => C.toLower n = n) ns);
      Expect.that ("toTitle of itself", List.all (fn n => C.toTitle n = n) ns)
    end

  val tests =
    Test.describe "unicode/code-point"
      [Test.it "version" (fn () => Expect.that ("18.0.0", C.version = "18.0.0")),
       Test.it "categories" categories,
       Test.it "category" (everyCodePoint ("category", fn c => C.category c = categoryOf c)),
       Test.it "upper" (mapsAs ("toUpper", C.toUpper, !upper)),
       Test.it "lower" (mapsAs ("toLower", C.toLower, !lower)),
       Test.it "title" (mapsAs ("toTitle", C.toTitle, !title)),
       Test.it "laws" (everyCodePoint ("the laws", fn c =>
         C.fromAbbreviation (C.abbreviation (C.category c)) = SOME (C.category c)
         andalso C.toUpper (C.toUpper c) = C.toUpper c
         andalso C.toLower (C.toLower c) = C.toLower c
         andalso C.toUpper (C.toTitle c) = C.toUpper c)),
       Test.it "beyond" beyond]
end

structure CodePointMain = Main (struct val name = "unicode/code-point" val tests = CodePointTest.tests end)
val () = CodePointMain.main ()
