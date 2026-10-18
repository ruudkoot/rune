(* libraries: test/unit *)
(* UnicodeSecurity against the data of UTS #39 and the UCD it was made from,
   read from the files that scripts/gen-unicode-tables.py copies to
   tests/lib/unicode, for every code point:
   - types as IdentifierType.txt lists them, and status as
     IdentifierStatus.txt does;
   - scripts as Scripts.txt and ScriptExtensions.txt give them, by the
     short names of PropertyValueAliases.txt, augmented as UTS #39's
     section 5.1 says;
   - the skeleton of each scalar value as confusables.txt makes it.
   Then the restriction levels of strings that mix scripts, among them the
   examples of UTS #39's Table 1a, and confusable names. Run from the top
   of the tree. *)
structure SecurityTest =
struct
  structure S = UnicodeSecurity

  fun hex s = valOf (StringCvt.scanString (Int.scan StringCvt.HEX) s)
  fun u c = "U+" ^ StringCvt.padLeft #"0" 4 (Int.fmt StringCvt.HEX c)

  (* the data lines of a file: the code points from, to, and the fields
     after them *)
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

  (* a value of each code point, from the lines of a file *)
  fun table (file, default, value) =
    let
      val a = Array.array (0x110000, default)
      fun fill (lo, hi, x) = if lo > hi then () else (Array.update (a, lo, x); fill (lo + 1, hi, x))
    in
      List.app (fn (lo, hi, fs) => case value fs of SOME x => fill (lo, hi, x) | NONE => ()) (records file);
      a
    end

  fun sort [] = []
    | sort (x :: xs) =
        let fun insert (y, []) = [y]
              | insert (y, z :: zs) = if String.< (y, z) then y :: z :: zs else z :: insert (y, zs)
        in insert (x, sort xs) end

  (* the code points for which ok fails, the first ten *)
  fun failures (ok, last) =
    let
      fun go (c, bad) =
        if c > last orelse length bad >= 10 then rev bad
        else go (c + 1, if ok c then bad else c :: bad)
    in
      go (0, [])
    end

  fun everyCodePoint (what, ok) () =
    let val bad = failures (ok, 0x10FFFF)
    in
      List.app (fn c => Expect.that (what ^ ": " ^ u c, false)) bad;
      Expect.that (what ^ ", for every code point", null bad)
    end

  (* ---- types and status *)

  val typeNames =
    [("Recommended", S.Recommended), ("Inclusion", S.Inclusion), ("Limited_Use", S.LimitedUse),
     ("Technical", S.Technical), ("Uncommon_Use", S.UncommonUse), ("Obsolete", S.Obsolete),
     ("Exclusion", S.Exclusion), ("Not_XID", S.NotXID), ("Not_NFKC", S.NotNFKC),
     ("Default_Ignorable", S.DefaultIgnorable), ("Deprecated", S.Deprecated), ("Not_Character", S.NotCharacter)]

  (* the types of each code point, in the order of the datatype *)
  val types =
    table ("IdentifierType.txt", [S.NotCharacter],
           fn [ts] =>
                let val names = String.tokens Char.isSpace ts
                in SOME (List.mapPartial (fn (n, t) => if List.exists (fn m => m = n) names then SOME t else NONE)
                                         typeNames) end
            | _ => NONE)

  val status =
    table ("IdentifierStatus.txt", S.Restricted,
           fn ["Allowed"] => SOME S.Allowed | ["Restricted"] => SOME S.Restricted | _ => NONE)

  (* ---- scripts *)

  (* the short name of each script, by its long name *)
  val short =
    let
      val f = TextIO.openIn "tests/lib/unicode/PropertyValueAliases.txt"
      fun field s = String.concatWith " " (String.tokens Char.isSpace s)
      fun loop acc =
        case TextIO.inputLine f of
          NONE => acc
        | SOME l =>
            case map field (String.fields (fn c => c = #";") (hd (String.fields (fn c => c = #"#") l))) of
              "sc" :: s :: long :: _ => loop ((long, s) :: acc)
            | _ => loop acc
    in
      loop [] before TextIO.closeIn f
    end
  fun shortName long =
    case List.find (fn (l, _) => l = long) short of
      SOME (_, s) => s
    | NONE => raise Fail ("no script " ^ long)

  val script = table ("Scripts.txt", "Zzzz", fn [long] => SOME (shortName long) | _ => NONE)
  val extensions = table ("ScriptExtensions.txt", [], fn [ss] => SOME (String.tokens Char.isSpace ss) | _ => NONE)

  (* UTS #39, 5.1 *)
  fun augmented c =
    let
      val s = case Array.sub (extensions, c) of [] => [Array.sub (script, c)] | ss => ss
      fun has x = List.exists (fn y => y = x) s
      val more = (if has "Hani" then ["Hanb", "Hntl", "Jpan", "Kore"] else [])
                 @ (if has "Hira" orelse has "Kana" then ["Jpan"] else [])
                 @ (if has "Hang" then ["Kore"] else [])
                 @ (if has "Bopo" then ["Hanb"] else [])
                 @ (if has "Latn" then ["Hntl"] else [])
      fun distinct [] = []
        | distinct (x :: xs) = x :: distinct (List.filter (fn y => y <> x) xs)
    in
      if has "Zyyy" orelse has "Zinh" then NONE else SOME (sort (distinct (s @ more)))
    end

  (* ---- skeletons *)

  val prototypes =
    table ("confusables.txt", [] : int list,
           fn target :: _ => SOME (map hex (String.tokens Char.isSpace target)) | [] => NONE)
  val ignorable =
    table ("DerivedCoreProperties.txt", false, fn ["Default_Ignorable_Code_Point"] => SOME true | _ => NONE)

  fun skeleton cs =
    let
      val d = List.filter (fn c => not (Array.sub (ignorable, c))) (Normalize.nfdList cs)
    in
      Normalize.nfdList (List.concat (map (fn c => case Array.sub (prototypes, c) of [] => [c] | p => p) d))
    end

  fun sameSkeleton c = not (Utf8.isScalar c) orelse S.skeleton (Utf8.encode c) = Utf8.implode (skeleton [c])

  (* ---- strings *)

  (* UTF-8 of code points *)
  val s = Utf8.implode

  val levels = [
    ("ASCII", s [0x43, 0x69, 0x72, 0x63, 0x6C, 0x65], S.ASCIIOnly),
    ("Table 1a: Latin and Cyrillic", s [0x421, 0x69, 0x72, 0x441, 0x6C, 0x435], S.MinimallyRestrictive),
    ("Cyrillic alone", s [0x421, 0x456, 0x433, 0x441, 0x4CF, 0x435], S.SingleScript),
    ("Table 1a: Han and Common", s [0x3006, 0x5207], S.SingleScript),
    ("Table 1a: Hiragana and Katakana", s [0x306D, 0x30AC], S.SingleScript),
    ("Greek alone", s [0x3BB, 0x3CC, 0x3B3, 0x3BF, 0x3C2], S.SingleScript),
    ("Latin and Greek", s [0x3A9, 0x6D, 0x65, 0x67, 0x61], S.MinimallyRestrictive),
    ("Latin and Han", s [0x61, 0x5909], S.SingleScript),
    ("Latin and Katakana", s [0x61, 0x30AB], S.HighlyRestrictive),
    ("Latin, Han and Katakana", s [0x61, 0x5909, 0x30AB], S.HighlyRestrictive),
    ("Latin and Hangul", s [0x61, 0xAC00], S.HighlyRestrictive),
    ("Latin and Bopomofo, which 18.0 restricts to limited use", s [0x61, 0x3105], S.Unrestricted),
    ("Latin and Arabic", s [0x61, 0x628], S.ModeratelyRestrictive),
    ("Latin and Devanagari", s [0x61, 0x915], S.ModeratelyRestrictive),
    ("Latin, Arabic and Devanagari", s [0x61, 0x628, 0x915], S.MinimallyRestrictive),
    ("Common digits with Greek", s [0x3BB, 0x31], S.SingleScript),
    ("a Restricted character", s [0x61, 0x1D44E], S.Unrestricted),
    ("ill-formed, read as U+FFFD", "a\255", S.Unrestricted)]

  val confusable = [
    ("Latin and Cyrillic a", ("paypal", s [0x70, 0x430, 0x79, 0x70, 0x430, 0x6C]), true),
    ("rn and m", ("rn", "m"), true),
    ("decomposed and composed", (s [0x65, 0x301], s [0xE9]), true),
    ("a joiner left out", (s [0x61, 0x200D, 0x62], "ab"), true),
    ("different names", ("left", "right"), false)]

  fun strings () =
    (List.app (fn (what, x, level) => Expect.that ("restriction: " ^ what, S.restriction x = level)) levels;
     List.app (fn (what, pair, same) => Expect.that ("isConfusable: " ^ what, S.isConfusable pair = same)) confusable;
     Expect.that ("resolvedScripts: Table 1a, Han and Common",
                  S.resolvedScripts (s [0x3006, 0x5207]) = SOME ["Hanb", "Hani", "Hntl", "Jpan", "Kore"]);
     Expect.that ("resolvedScripts of Common", S.resolvedScripts "123" = NONE andalso S.resolvedScripts "" = NONE))

  val tests =
    Test.describe "unicode/security"
      [Test.it "types" (everyCodePoint ("types", fn c => S.types c = Array.sub (types, c))),
       Test.it "status" (everyCodePoint ("status", fn c => S.status c = Array.sub (status, c))),
       Test.it "scripts" (everyCodePoint ("scripts", fn c => S.scripts c = augmented c)),
       Test.it "skeletons" (everyCodePoint ("skeleton", sameSkeleton)),
       Test.it "strings" strings]
end

structure SecurityMain = Main (struct val name = "unicode/security" val tests = SecurityTest.tests end)
val () = SecurityMain.main ()
