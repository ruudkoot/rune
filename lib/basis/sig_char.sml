(* Characters: their codes and order, the classes they belong to, and their
   conversion to and from the text of SML and C character constants.

   A character is a small non-negative integer, its code, and the characters
   are ordered as their codes are. The signature is that of `Char`, whose
   characters are the elements of `string`, and of the optional `WideChar`,
   which is why it specifies a type `string` of its own.

   The classes (`isAlpha`, `isSpace` and the rest) are those of the ASCII
   character set and do not depend on a locale.

   Area: Text and characters

   See also: `STRING`, `SUBSTRING`, `STRING_CVT`

   Erratum: `CHAR/string-types`. The specification writes the types of
   `toString`, `scan`, `fromString`, `toCString` and `fromCString` with
   `String.string` and `Char.char` rather than with the `string` and `char`
   of the signature, because the text is always one of 8-bit characters, also
   for `WideChar`. They are kept as written; that `Char.char` is `char` and
   `Char.string` is `String.string` is a constraint on the structure `Char`.

   Erratum: `CHAR/fromString-sample`. The third example of the page's table
   for `fromString` is not the text of an SML string; the page of `STRING`
   has the table as it was meant.

   Pinned by: `Char.fromString/sample-*` *)
signature CHAR =
sig
  (* ---- Types and bounds ---- *)

  (* The type of characters.

     Implementation: `Char.char/eight-bits`. `Char.char` is the top-level
     `char`, a character of 8 bits: its codes run from 0 to 255. *)
  eqtype char

  (* The type of strings of these characters: `String.string` for `Char`. *)
  eqtype string

  (* The character with the smallest code, 0. *)
  val minChar : char

  (* The character with the largest code, `maxOrd`. *)
  val maxChar : char

  (* The largest code of a character.

     Implementation: `Char.maxOrd/value`. 255 for `Char`, and 1114111, the
     last code point of Unicode, for `WideChar`.

     Pinned by: `WideChar:CHAR/maxOrd-is-Unicode` *)
  val maxOrd : int

  (* ---- Codes and order ---- *)

  (* `ord c` is the code of `c`, between 0 and `maxOrd`.

     Example: `ord #"A" = 65` *)
  val ord : char -> int

  (* `chr i` is the character whose code is `i`.

     Raises: `Chr` if `i < 0` or `i > maxOrd`.

     Example: `chr 97 = #"a"` *)
  val chr : int -> char

  (* `succ c` is the character after `c`, the one with the code `ord c + 1`.

     Raises: `Chr` if `c` is `maxChar`.

     Example: `succ #"a" = #"b"` *)
  val succ : char -> char

  (* `pred c` is the character before `c`, the one with the code `ord c - 1`.

     Raises: `Chr` if `c` is `minChar`. *)
  val pred : char -> char

  (* `compare (c, d)` orders two characters by their codes.

     Reading: `Char.compare/127-128`. The codes are not negative, so 127 comes
     before 128 and 255 after 0: a character is not a signed byte.

     Pinned by: `Char.compare/127-128`, `Char.compare/255-0`,
     `Char.compare/all-pairs` *)
  val compare : char * char -> order

  (* `c < d`, `c <= d`, `c > d` and `c >= d` compare the codes of two
     characters. *)
  val < : char * char -> bool
  val <= : char * char -> bool
  val > : char * char -> bool
  val >= : char * char -> bool

  (* ---- Membership ---- *)

  (* `contains s c` is `true` when `c` occurs in the string `s`.

     Applied to `s` alone it gives a predicate, which suits the functions that
     take one: `String.tokens (contains " ,;")`.

     Example: `contains "abc" #"b" = true` *)
  val contains : string -> char -> bool

  (* `notContains s c` is `true` when `c` does not occur in `s`. *)
  val notContains : string -> char -> bool

  (* ---- Classes and case ---- *)

  (* `isAscii c` is `true` when the code of `c` is at most 127.

     Reading: `Char.isAlpha/latin1`. The classes below are the sets that the
     specification's discussion lists, whatever the locale: no character
     above 127 is in any of them, and `toLower` and `toUpper` change the 52
     letters of ASCII only.

     Pinned by: `Char.is*/latin1`, `Char.toLower/all`, `Char.toUpper/a-grave`
     *)
  val isAscii : char -> bool

  (* `toLower c` is the lower case letter for an upper case letter `c`, and `c`
     otherwise. *)
  val toLower : char -> char

  (* `toUpper c` is the upper case letter for a lower case letter `c`, and `c`
     otherwise.

     Example: `toUpper #"a" = #"A"`

     Example: `toUpper #"1" = #"1"` *)
  val toUpper : char -> char

  (* `isAlpha c` is `true` for a letter, `A` to `Z` and `a` to `z`.

     Example: `isAlpha #"_" = false` *)
  val isAlpha : char -> bool

  (* `isAlphaNum c` is `true` for a letter or a decimal digit. *)
  val isAlphaNum : char -> bool

  (* `isCntrl c` is `true` for a control character: a code below 32, or 127. *)
  val isCntrl : char -> bool

  (* `isDigit c` is `true` for a decimal digit, `0` to `9`. *)
  val isDigit : char -> bool

  (* `isGraph c` is `true` for a character that leaves a mark when printed:
     codes 33 to 126. *)
  val isGraph : char -> bool

  (* `isHexDigit c` is `true` for a hexadecimal digit: `0` to `9`, `a` to `f`
     and `A` to `F`. *)
  val isHexDigit : char -> bool

  (* `isLower c` is `true` for a lower case letter, `a` to `z`. *)
  val isLower : char -> bool

  (* `isPrint c` is `true` for a printable character, the space included: codes
     32 to 126. *)
  val isPrint : char -> bool

  (* `isSpace c` is `true` for white space: the space and the characters `\t`,
     `\n`, `\v`, `\f` and `\r`. *)
  val isSpace : char -> bool

  (* `isPunct c` is `true` for a graphical character that is neither a letter
     nor a digit.

     Example: `isPunct #"_" = true` *)
  val isPunct : char -> bool

  (* `isUpper c` is `true` for an upper case letter, `A` to `Z`. *)
  val isUpper : char -> bool

  (* ---- The text of character constants ---- *)

  (* `toString c` is the text that stands for `c` inside an SML string
     constant.

     A printable character is itself, except that the backslash and the double
     quote get a backslash in front. The control characters with a name are
     `\a`, `\b`, `\t`, `\n`, `\v`, `\f` and `\r`; the other codes below 32
     are written `\^@` to `\^_`, and codes from 127 up as a backslash and three
     decimal digits.

     Example: `toString #"\n" = "\\n"` and `toString #"\255" = "\\255"` *)
  val toString : char -> String.string

  (* `scan getc strm` reads one character from `strm` in the notation of SML
     string constants.

     A printable character other than the backslash stands for itself; a
     backslash begins an escape sequence: the named ones, `\^c` for a control
     character, `\ddd` with three decimal digits, `\uxxxx` with four
     hexadecimal ones, `\\` and `\"`. The answer is `NONE` when the stream
     begins with a character that is not printable or with an escape that
     is malformed or names no character.

     Reading: `Char.scan/formatting`. A formatting sequence, a backslash, white
     space and another backslash, stands for nothing. Such sequences are
     passed over before the character, and after it as well, so that what is
     left of the stream never begins with one. *)
  val scan : (Char.char, 'a) StringCvt.reader -> (char, 'a) StringCvt.reader

  (* `fromString s` is the character that the text `s` begins with, read as
     `scan` reads it, or `NONE`.

     Law: `fromString s = StringCvt.scanString scan s`

     Reading: `Char.fromString/printable-only-all-rejected`. A first character
     outside the printable range, codes 32 to 126, gives `NONE`, and so does
     a backslash by itself; every other printable character but the double
     quote, of which below, is converted to itself.

     Pinned by: `Char.fromString/printable-only-*`

     Reading: `Char.fromString/unescaped-double-quote`. The specification
     has the text read "as allowed in an SML program", where a double quote
     that no backslash precedes ends a constant and is no character, and
     names only characters that do not print and bad escapes as what gives
     `NONE`. The first is followed: a double quote by itself gives `NONE`, as
     in MLton and SML/NJ, where Poly/ML converts it. The page of `STRING` has
     no such words and lists what stops a scan, so `String.scan` converts the
     same double quote; the two pages differ, and each is followed.

     Example: `fromString "\\n" = SOME #"\n"`

     Example: `fromString "\"" = NONE`, where `fromString "\\\"" = SOME #"\""`. *)
  val fromString : String.string -> char option

  (* `toCString c` is the text that stands for `c` inside a C string constant.

     A printable character is itself, except that the backslash, the double
     quote, the single quote and the question mark get a backslash in front.
     The control characters with a name in C are `\a`, `\b`, `\t`, `\n`, `\v`,
     `\f` and `\r`; every other character is a backslash and three octal
     digits.

     Example: `toCString #"\000" = "\\000"` *)
  val toCString : char -> String.string

  (* `fromCString s` is the character that the text `s` begins with in the
     notation of C, or `NONE`.

     The escapes are those of C: the named ones, `\ooo` with one to three
     octal digits and `\x` with any number of hexadecimal ones. There are no
     formatting sequences, and a double quote without a backslash is
     rejected.

     Reading: `Char.fromCString/hex-huge-does-not-fit`. A `\x` escape whose
     value is no character gives `NONE` however many digits it has:
     `Overflow` is not raised.

     Reading: `Char.fromCString/printable-only-all-converted`. Every printable
     character but the double quote and the backslash is converted to itself,
     the single quote included; what does not print is rejected.

     Pinned by: `Char.fromCString/printable-only-*`

     Example: `fromCString "\\x41" = SOME #"A"` *)
  val fromCString : String.string -> char option
end
