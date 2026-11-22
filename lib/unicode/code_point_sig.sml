(* Code points: the general category of each, and its simple case
   mappings, by the Unicode Character Database.

   The general category sorts every code point into one of 30 categories,
   each in one of seven classes: letters, marks, numbers, punctuation,
   symbols, separators, and the rest (controls, formats, surrogates,
   private use, and the code points unassigned). A letter is uppercase,
   lowercase or titlecase where it has case, and a modifier or other
   letter where it has none, as those of CJK, Hebrew and Arabic.

   A simple case mapping maps a code point to one code point, its
   uppercase, lowercase or titlecase, or to itself where it has none. The
   full mappings of SpecialCasing.txt, which map one code point to
   several, as ß to SS, and depend on the language or the letters around,
   are not here; nor is case folding. The simple mappings are not
   inverses of each other: `toLower 0x130` is `0x69`, i, whose uppercase
   is I and not İ.

   The data is that of the version `version`, and changes with it: a code
   point unassigned today may be a letter in a later version.

   Area: Unicode *)
signature CODE_POINT =
sig
  (* The version of Unicode whose data is followed.

     Example: `version = "18.0.0"` *)
  val version : string

  (* ---- The general category ---- *)

  (* The values of the property General_Category (UAX #44, 5.7.1), each
     with its abbreviation, which `abbreviation` gives. *)
  datatype category =
      UppercaseLetter       (* Lu *)
    | LowercaseLetter       (* Ll *)
    | TitlecaseLetter       (* Lt: a digraph whose first part is uppercase, as U+01C5 *)
    | ModifierLetter        (* Lm *)
    | OtherLetter           (* Lo: a letter with no case *)
    | NonspacingMark        (* Mn *)
    | SpacingMark           (* Mc *)
    | EnclosingMark         (* Me *)
    | DecimalNumber         (* Nd: a digit of a decimal system *)
    | LetterNumber          (* Nl: a numeral that is a letter, as the Roman ones *)
    | OtherNumber           (* No: as the superscript digits and the fractions *)
    | ConnectorPunctuation  (* Pc: as `_` *)
    | DashPunctuation       (* Pd *)
    | OpenPunctuation       (* Ps *)
    | ClosePunctuation      (* Pe *)
    | InitialPunctuation    (* Pi: an opening quotation mark *)
    | FinalPunctuation      (* Pf: a closing quotation mark *)
    | OtherPunctuation      (* Po *)
    | MathSymbol            (* Sm *)
    | CurrencySymbol        (* Sc *)
    | ModifierSymbol        (* Sk *)
    | OtherSymbol           (* So *)
    | SpaceSeparator        (* Zs *)
    | LineSeparator         (* Zl: U+2028 alone *)
    | ParagraphSeparator    (* Zp: U+2029 alone *)
    | Control               (* Cc: C0 and C1 *)
    | Format                (* Cf *)
    | Surrogate             (* Cs *)
    | PrivateUse            (* Co *)
    | Unassigned            (* Cn: reserved, or a noncharacter *)

  (* `category c` is the general category of the code point `c`, and
     `Unassigned` for an integer that is no code point, below 0 or above
     0x10FFFF.

     Below 0x100 it costs a character of a string; above, a binary search
     over ranges, built at the first use.

     Example: `category 0x41 = UppercaseLetter andalso category 0x3BB = LowercaseLetter`

     Example: `category 0x4E2D = OtherLetter andalso category 0x1C5 = TitlecaseLetter`, 中 and ǅ

     Example: `category 0x2B = MathSymbol andalso category 0x5F = ConnectorPunctuation`

     Example: `category 0xD800 = Surrogate andalso category 0x378 = Unassigned andalso category ~1 = Unassigned` *)
  val category : int -> category

  (* The class of a category, the first letter of its abbreviation. *)
  datatype major =
      Letter       (* L *)
    | Mark         (* M *)
    | Number       (* N *)
    | Punctuation  (* P *)
    | Symbol       (* S *)
    | Separator    (* Z *)
    | Other        (* C *)

  (* `major g` is the class of the category `g`.

     Example: `major OtherLetter = Letter andalso major (category 0x2B) = Symbol andalso major (category 0x20) = Separator` *)
  val major : category -> major

  (* `abbreviation g` is the two letters that stand for the category `g`
     in the Unicode Character Database.

     Example: `abbreviation UppercaseLetter = "Lu" andalso abbreviation Unassigned = "Cn"` *)
  val abbreviation : category -> string

  (* `fromAbbreviation s` is the category whose abbreviation is `s`, and
     `NONE` where there is none: the inverse of `abbreviation`.

     Example: `fromAbbreviation "Nd" = SOME DecimalNumber andalso fromAbbreviation "L" = NONE` *)
  val fromAbbreviation : string -> category option

  (* ---- Simple case mappings ---- *)

  (* `toUpper c` is the property Simple_Uppercase_Mapping of the code point
     `c`: its uppercase, or `c` where it has none, as for an integer that
     is no code point.

     ASCII costs no table; the rest, a binary search over runs of
     mappings, built at the first use.

     Law: `toUpper (toUpper c) = toUpper c`

     Example: `toUpper 0x61 = 0x41 andalso toUpper 0xFF = 0x178 andalso toUpper 0x41 = 0x41`

     Example: `toUpper 0xDF = 0xDF`, ß, whose full uppercase is SS

     Example: `toUpper 0x1C6 = 0x1C4 andalso toUpper 0x10D0 = 0x1C90`, ǆ and Georgian ა

     Counterexample: `toUpper (toLower 0x130) = 0x130`, İ, whose lowercase is i *)
  val toUpper : int -> int

  (* `toLower c` is the property Simple_Lowercase_Mapping of the code point
     `c`: its lowercase, or `c` where it has none.

     Law: `toLower (toLower c) = toLower c`

     Example: `toLower 0x41 = 0x61 andalso toLower 0x130 = 0x69 andalso toLower 0x1C5 = 0x1C6` *)
  val toLower : int -> int

  (* `toTitle c` is the property Simple_Titlecase_Mapping of the code point
     `c`: its titlecase, or `c` where it has none.

     It is `toUpper c` but for the digraphs, whose titlecase is a letter
     of its own, and the Georgian letters, which are their own titlecase.

     Law: `toUpper (toTitle c) = toUpper c`

     Example: `toTitle 0x1C6 = 0x1C5 andalso toTitle 0x61 = 0x41 andalso toTitle 0x10D0 = 0x10D0` *)
  val toTitle : int -> int
end
