(* signature CHAR, transcribed from https://smlfamily.github.io/Basis/char.html

   The page writes the types of toString, scan, fromString, toCString and
   fromCString with `String.string` and `Char.char`, because the signature
   is also that of WideChar; they are kept as written. The constraints of
   `structure Char :> CHAR where type char = char where type string =
   String.string` are in tests/basis/char_sig.sml. *)
signature SPEC_CHAR =
sig
  eqtype char
  eqtype string

  val minChar : char
  val maxChar : char
  val maxOrd : int

  val ord : char -> int
  val chr : int -> char
  val succ : char -> char
  val pred : char -> char

  val compare : char * char -> order
  val < : char * char -> bool
  val <= : char * char -> bool
  val > : char * char -> bool
  val >= : char * char -> bool

  val contains : string -> char -> bool
  val notContains : string -> char -> bool

  val isAscii : char -> bool
  val toLower : char -> char
  val toUpper : char -> char
  val isAlpha : char -> bool
  val isAlphaNum : char -> bool
  val isCntrl : char -> bool
  val isDigit : char -> bool
  val isGraph : char -> bool
  val isHexDigit : char -> bool
  val isLower : char -> bool
  val isPrint : char -> bool
  val isSpace : char -> bool
  val isPunct : char -> bool
  val isUpper : char -> bool

  val toString : char -> String.string
  val scan : (Char.char, 'a) StringCvt.reader -> (char, 'a) StringCvt.reader
  val fromString : String.string -> char option
  val toCString : char -> String.string
  val fromCString : String.string -> char option
end
