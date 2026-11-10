(* Implements: HS_CHAR *)
structure HsChar :> HS_CHAR =
struct
  datatype class = Small | Large | Digit | Symbol | White | Special | Colon | Quote | Unknown

  (* The class of every ASCII character, by 2.2's productions. *)
  val ascii : class vector =
    Vector.tabulate (128, fn i =>
      let val c = Char.chr i
      in
        if Char.isLower c orelse c = #"_" then Small
        else if Char.isUpper c then Large
        else if Char.isDigit c then Digit
        else if CharVector.exists (fn d => d = c) "!#$%&*+./<=>?@\\^|-~" then Symbol
        else if CharVector.exists (fn d => d = c) "(),;[]`{}" then Special
        else if c = #":" then Colon
        else if c = #"\"" orelse c = #"'" then Quote
        else if c = #" " orelse c = #"\t" orelse c = #"\n" orelse c = #"\r" orelse c = #"\v" orelse c = #"\f"
        then White
        else Unknown
      end)

  (* Above ASCII, by the general category of lib/unicode (D21): uniSmall a
     lowercase letter, uniLarge an uppercase or titlecase one, uniDigit a
     decimal digit, uniSymbol a symbol or a punctuation mark, uniWhite a
     space separator. *)
  fun wide c =
    case CodePoint.category c of
      CodePoint.LowercaseLetter => Small
    | CodePoint.UppercaseLetter => Large
    | CodePoint.TitlecaseLetter => Large
    | CodePoint.DecimalNumber => Digit
    | CodePoint.SpaceSeparator => White
    | g => (case CodePoint.major g of CodePoint.Punctuation => Symbol | CodePoint.Symbol => Symbol | _ => Unknown)

  fun classify c =
    if c < 0 then Unknown
    else if c < 128 then Vector.sub (ascii, c)
    else wide c

  fun isIdent c =
    case classify c of
      Small => true
    | Large => true
    | Digit => true
    | _ => c = 39

  fun isSymbol c =
    case classify c of
      Symbol => true
    | Colon => true
    | _ => false
end
