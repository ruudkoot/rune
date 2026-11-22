(* Code points (docs/plans/language/haskell98.md, D21): the general
   category by a string below 0x100 and above it by a binary search over
   the ranges of lib/unicode/code_point_data.sml, whose values are the
   positions of the categories in `categories`; the case mappings by
   ASCII's rule, and above it by a binary search over the runs of the
   same file. *)

(* Implements: CODE_POINT *)
structure CodePoint :> CODE_POINT =
struct
  structure D = UnicodeCodePointData

  val version = D.version

  datatype category =
      UppercaseLetter | LowercaseLetter | TitlecaseLetter | ModifierLetter | OtherLetter
    | NonspacingMark | SpacingMark | EnclosingMark
    | DecimalNumber | LetterNumber | OtherNumber
    | ConnectorPunctuation | DashPunctuation | OpenPunctuation | ClosePunctuation
    | InitialPunctuation | FinalPunctuation | OtherPunctuation
    | MathSymbol | CurrencySymbol | ModifierSymbol | OtherSymbol
    | SpaceSeparator | LineSeparator | ParagraphSeparator
    | Control | Format | Surrogate | PrivateUse | Unassigned

  datatype major = Letter | Mark | Number | Punctuation | Symbol | Separator | Other

  (* the categories in the order of the table's values, built at the first
     use, so that a program that never asks for one, as runedoc, which
     links every file of the library, keeps no code of them *)
  val categories =
    D.once (fn () =>
      Vector.fromList
        [UppercaseLetter, LowercaseLetter, TitlecaseLetter, ModifierLetter, OtherLetter,
         NonspacingMark, SpacingMark, EnclosingMark,
         DecimalNumber, LetterNumber, OtherNumber,
         ConnectorPunctuation, DashPunctuation, OpenPunctuation, ClosePunctuation,
         InitialPunctuation, FinalPunctuation, OtherPunctuation,
         MathSymbol, CurrencySymbol, ModifierSymbol, OtherSymbol,
         SpaceSeparator, LineSeparator, ParagraphSeparator,
         Control, Format, Surrogate, PrivateUse, Unassigned])

  (* Unassigned's value, the last *)
  val unassigned = 29

  (* the value of the range of v (triples lo, hi, value) that holds c, or
     unassigned's *)
  fun lookup (v : int vector) c =
    let
      fun go (lo, hi) =
        if lo >= hi then unassigned
        else
          let val m = (lo + hi) div 2
          in
            if c < Vector.sub (v, 3 * m) then go (lo, m)
            else if c > Vector.sub (v, 3 * m + 1) then go (m + 1, hi)
            else Vector.sub (v, 3 * m + 2)
          end
    in
      go (0, Vector.length v div 3)
    end

  fun category c =
    Vector.sub (categories (),
                if c < 0 then unassigned
                else if c < 0x100 then Char.ord (String.sub (D.latin1, c)) - 48
                else lookup (D.category ()) c)

  fun abbreviation g =
    case g of
      UppercaseLetter => "Lu"
    | LowercaseLetter => "Ll"
    | TitlecaseLetter => "Lt"
    | ModifierLetter => "Lm"
    | OtherLetter => "Lo"
    | NonspacingMark => "Mn"
    | SpacingMark => "Mc"
    | EnclosingMark => "Me"
    | DecimalNumber => "Nd"
    | LetterNumber => "Nl"
    | OtherNumber => "No"
    | ConnectorPunctuation => "Pc"
    | DashPunctuation => "Pd"
    | OpenPunctuation => "Ps"
    | ClosePunctuation => "Pe"
    | InitialPunctuation => "Pi"
    | FinalPunctuation => "Pf"
    | OtherPunctuation => "Po"
    | MathSymbol => "Sm"
    | CurrencySymbol => "Sc"
    | ModifierSymbol => "Sk"
    | OtherSymbol => "So"
    | SpaceSeparator => "Zs"
    | LineSeparator => "Zl"
    | ParagraphSeparator => "Zp"
    | Control => "Cc"
    | Format => "Cf"
    | Surrogate => "Cs"
    | PrivateUse => "Co"
    | Unassigned => "Cn"

  fun major g =
    case String.sub (abbreviation g, 0) of
      #"L" => Letter
    | #"M" => Mark
    | #"N" => Number
    | #"P" => Punctuation
    | #"S" => Symbol
    | #"Z" => Separator
    | _ => Other

  fun fromAbbreviation s =
    let
      fun go i =
        if i > unassigned then NONE
        else
          let val g = Vector.sub (categories (), i)
          in if abbreviation g = s then SOME g else go (i + 1) end
    in
      go 0
    end

  (* the mapping of c by the run of v (quadruples lo, hi, step, d) that
     holds it, c + d, or c itself *)
  fun mapping (v : int vector) c =
    let
      fun go (lo, hi) =
        if lo >= hi then c
        else
          let val m = (lo + hi) div 2
          in
            if c < Vector.sub (v, 4 * m) then go (lo, m)
            else if c > Vector.sub (v, 4 * m + 1) then go (m + 1, hi)
            else if (c - Vector.sub (v, 4 * m)) mod Vector.sub (v, 4 * m + 2) = 0 then c + Vector.sub (v, 4 * m + 3)
            else c
          end
    in
      go (0, Vector.length v div 4)
    end

  fun toUpper c =
    if c < 0x80 then (if c >= 0x61 andalso c <= 0x7A then c - 32 else c)
    else mapping (D.upper ()) c

  fun toLower c =
    if c < 0x80 then (if c >= 0x41 andalso c <= 0x5A then c + 32 else c)
    else mapping (D.lower ()) c

  fun toTitle c =
    if c < 0x80 then (if c >= 0x61 andalso c <= 0x7A then c - 32 else c)
    else mapping (D.title ()) c
end
