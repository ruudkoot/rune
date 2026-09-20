(* requires: WideChar WideCharVector *)
(* WideChar (optional in the specification, signature CHAR): characters that
   are Unicode code points. Expected values follow
   https://smlfamily.github.io/Basis/char.html, which leaves the classes and
   the case conversions of a wide character to the implementation ("in
   general, the definition of a letter is locale-dependent"): here they are
   those of ASCII, and a character above 127 is in no class and is its own
   upper and lower case, as MLton reads it too. A character above 255 is
   written \uXXXX, or \UXXXXXXXX above 0xFFFF.

   The text that toString and fromString take and give is of char, the 8-bit
   one, as the signature writes it. *)
structure TestWideChar =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqO = T.eq T.order
  val C = WideChar.chr
  fun ordOf c = WideChar.ord c
  val showC = fn c => "0x" ^ Int.fmt StringCvt.HEX (WideChar.ord c)
  val eqC = T.eq showC
  val eqCO = T.eq (T.option showC)
  val isChr = fn Chr => true | _ => false
  (* a wide string from code points *)
  fun ws l = WideCharVector.fromList (List.map C l)

  (*<< ord-chr *)
  val () = eqI ("WideChar.maxOrd/0x10FFFF", 1114111, fn () => WideChar.maxOrd)
  val () = eqI ("WideChar.ord/ascii", 97, fn () => ordOf (C 97))
  val () = eqI ("WideChar.ord/beyond-the-basic-plane", 128512, fn () => ordOf (C 128512))
  val () = eqC ("WideChar.chr/round-trip", C 233, fn () => C (ordOf (C 233)))
  val () = T.raises ("WideChar.chr/Chr-negative", isChr, fn () => C ~1)
  val () = T.raises ("WideChar.chr/Chr-above-maxOrd", isChr, fn () => C 1114112)
  val () = eqI ("WideChar.minChar/is-zero", 0, fn () => ordOf WideChar.minChar)
  val () = eqI ("WideChar.maxChar/is-maxOrd", 1114111, fn () => ordOf WideChar.maxChar)
  val () = eqC ("WideChar.succ/next-code-point", C 0x1F601, fn () => WideChar.succ (C 0x1F600))
  val () = T.raises ("WideChar.succ/Chr-at-maxChar", isChr, fn () => WideChar.succ WideChar.maxChar)
  val () = eqC ("WideChar.pred/previous-code-point", C 0x1F5FF, fn () => WideChar.pred (C 0x1F600))
  val () = T.raises ("WideChar.pred/Chr-at-minChar", isChr, fn () => WideChar.pred WideChar.minChar)
  (*>> ord-chr *)

  (*<< comparison *)
  val () = eqO ("WideChar.compare/less", LESS, fn () => WideChar.compare (C 97, C 0x100))
  val () = eqO ("WideChar.compare/equal", EQUAL, fn () => WideChar.compare (C 0x1F600, C 0x1F600))
  val () = eqO ("WideChar.compare/greater", GREATER, fn () => WideChar.compare (C 0x10FFFF, C 0x10FFFE))
  val () = eqB ("WideChar.</by-code-point", true, fn () => WideChar.< (C 255, C 256))
  val () = eqB ("WideChar.</not-less", false, fn () => WideChar.< (C 256, C 256))
  val () = eqB ("WideChar.<=/equal", true, fn () => WideChar.<= (C 256, C 256))
  val () = eqB ("WideChar.>/by-code-point", true, fn () => WideChar.> (C 0x1F600, C 97))
  val () = eqB ("WideChar.>=/equal", true, fn () => WideChar.>= (C 0, C 0))
  (*>> comparison *)

  (*<< contains *)
  val () = eqB ("WideChar.contains/present", true, fn () => WideChar.contains (ws [104, 233, 0x1F600]) (C 233))
  val () = eqB ("WideChar.contains/absent", false, fn () => WideChar.contains (ws [104, 233]) (C 0x1F600))
  val () = eqB ("WideChar.contains/empty", false, fn () => WideChar.contains (ws []) (C 97))
  val () = eqB ("WideChar.notContains/absent", true, fn () => WideChar.notContains (ws [104]) (C 233))
  val () = eqB ("WideChar.notContains/present", false, fn () => WideChar.notContains (ws [104]) (C 104))
  (*>> contains *)

  (*<< classes *)
  (* the classes of ASCII; a character above 127 is in none of them *)
  val () = eqB ("WideChar.isAscii/below-128", true, fn () => WideChar.isAscii (C 127))
  val () = eqB ("WideChar.isAscii/above-127", false, fn () => WideChar.isAscii (C 128))
  val () = eqB ("WideChar.isAlpha/letter", true, fn () => WideChar.isAlpha (C 97))
  val () = eqB ("WideChar.isAlpha/e-acute", false, fn () => WideChar.isAlpha (C 233))
  val () = eqB ("WideChar.isAlphaNum/digit", true, fn () => WideChar.isAlphaNum (C 53))
  val () = eqB ("WideChar.isAlphaNum/emoji", false, fn () => WideChar.isAlphaNum (C 0x1F600))
  val () = eqB ("WideChar.isCntrl/newline", true, fn () => WideChar.isCntrl (C 10))
  val () = eqB ("WideChar.isCntrl/next-line-0x85", false, fn () => WideChar.isCntrl (C 0x85))
  val () = eqB ("WideChar.isDigit/five", true, fn () => WideChar.isDigit (C 53))
  val () = eqB ("WideChar.isDigit/arabic-indic", false, fn () => WideChar.isDigit (C 0x0660))
  val () = eqB ("WideChar.isGraph/letter", true, fn () => WideChar.isGraph (C 97))
  val () = eqB ("WideChar.isGraph/e-acute", false, fn () => WideChar.isGraph (C 233))
  val () = eqB ("WideChar.isHexDigit/f", true, fn () => WideChar.isHexDigit (C 102))
  val () = eqB ("WideChar.isHexDigit/fullwidth-f", false, fn () => WideChar.isHexDigit (C 0xFF46))
  val () = eqB ("WideChar.isLower/small-a", true, fn () => WideChar.isLower (C 97))
  val () = eqB ("WideChar.isLower/small-e-acute", false, fn () => WideChar.isLower (C 233))
  val () = eqB ("WideChar.isPrint/space", true, fn () => WideChar.isPrint (C 32))
  val () = eqB ("WideChar.isPrint/emoji", false, fn () => WideChar.isPrint (C 0x1F600))
  val () = eqB ("WideChar.isSpace/tab", true, fn () => WideChar.isSpace (C 9))
  val () = eqB ("WideChar.isSpace/line-separator", false, fn () => WideChar.isSpace (C 0x2028))
  val () = eqB ("WideChar.isPunct/comma", true, fn () => WideChar.isPunct (C 44))
  val () = eqB ("WideChar.isPunct/em-dash", false, fn () => WideChar.isPunct (C 0x2014))
  val () = eqB ("WideChar.isUpper/capital-a", true, fn () => WideChar.isUpper (C 65))
  val () = eqB ("WideChar.isUpper/capital-e-acute", false, fn () => WideChar.isUpper (C 0xC9))
  val () = eqC ("WideChar.toLower/ascii", C 97, fn () => WideChar.toLower (C 65))
  val () = eqC ("WideChar.toLower/leaves-a-wide-character", C 0xC9, fn () => WideChar.toLower (C 0xC9))
  val () = eqC ("WideChar.toUpper/ascii", C 65, fn () => WideChar.toUpper (C 97))
  val () = eqC ("WideChar.toUpper/leaves-a-wide-character", C 0xE9, fn () => WideChar.toUpper (C 0xE9))
  (*>> classes *)

  (*<< text *)
  val () = eqS ("WideChar.toString/printable", "a", fn () => WideChar.toString (C 97))
  val () = eqS ("WideChar.toString/newline", "\\n", fn () => WideChar.toString (C 10))
  val () = eqS ("WideChar.toString/backslash", "\\\\", fn () => WideChar.toString (C 92))
  val () = eqS ("WideChar.toString/double-quote", "\\\"", fn () => WideChar.toString (C 34))
  val () = eqS ("WideChar.toString/latin-1", "\\233", fn () => WideChar.toString (C 233))
  val () = eqS ("WideChar.toString/above-255", "\\u0100", fn () => WideChar.toString (C 0x100))
  val () = eqS ("WideChar.toString/largest-of-four-digits", "\\uFFFF", fn () => WideChar.toString (C 0xFFFF))
  val () = eqS ("WideChar.toString/above-0xFFFF", "\\U00010000", fn () => WideChar.toString (C 0x10000))
  val () = eqS ("WideChar.toString/maxChar", "\\U0010FFFF", fn () => WideChar.toString WideChar.maxChar)
  val () = eqCO ("WideChar.fromString/printable", SOME (C 97), fn () => WideChar.fromString "a")
  val () = eqCO ("WideChar.fromString/escape-u", SOME (C 233), fn () => WideChar.fromString "\\u00e9")
  val () = eqCO ("WideChar.fromString/escape-u-upper-case-digits", SOME (C 0xABCD), fn () => WideChar.fromString "\\uABCD")
  val () = eqCO ("WideChar.fromString/escape-U", SOME (C 0x1F600), fn () => WideChar.fromString "\\U0001F600")
  val () = eqCO ("WideChar.fromString/escape-decimal", SOME (C 233), fn () => WideChar.fromString "\\233")
  val () = eqCO ("WideChar.fromString/escape-decimal-above-255", SOME (C 400), fn () => WideChar.fromString "\\400")
  val () = eqCO ("WideChar.fromString/escape-control", SOME (C 0), fn () => WideChar.fromString "\\^@")
  val () = eqCO ("WideChar.fromString/formatting-sequence-first", SOME (C 97), fn () => WideChar.fromString "\\ \\a")
  val () = eqCO ("WideChar.fromString/NONE-empty", NONE, fn () => WideChar.fromString "")
  val () = eqCO ("WideChar.fromString/NONE-short-escape", NONE, fn () => WideChar.fromString "\\u12")
  val () = eqCO ("WideChar.fromString/NONE-above-maxOrd", NONE, fn () => WideChar.fromString "\\U00110000")
  val () = eqS ("WideChar.toCString/printable", "a", fn () => WideChar.toCString (C 97))
  val () = eqS ("WideChar.toCString/latin-1-is-octal", "\\351", fn () => WideChar.toCString (C 233))
  val () = eqS ("WideChar.toCString/above-255", "\\u0100", fn () => WideChar.toCString (C 0x100))
  val () = eqS ("WideChar.toCString/above-0xFFFF", "\\U0001F600", fn () => WideChar.toCString (C 0x1F600))
  val () = eqCO ("WideChar.fromCString/octal", SOME (C 233), fn () => WideChar.fromCString "\\351")
  val () = eqCO ("WideChar.fromCString/hex", SOME (C 233), fn () => WideChar.fromCString "\\xe9")
  val () = eqCO ("WideChar.fromCString/escape-u", SOME (C 0x100), fn () => WideChar.fromCString "\\u0100")
  val () = eqCO ("WideChar.fromCString/escape-U", SOME (C 0x1F600), fn () => WideChar.fromCString "\\U0001F600")
  val () = eqCO ("WideChar.fromCString/NONE-empty", NONE, fn () => WideChar.fromCString "")
  (* scan reads from a stream of char, as the signature writes it *)
  val () = T.check ("WideChar.scan/takes-the-escape-and-leaves-the-rest",
                    fn () => case WideChar.scan Substring.getc (Substring.full "\\u0100rest") of
                               SOME (c, rest) => c = C 0x100 andalso Substring.string rest = "rest"
                             | NONE => false)
  val () = T.check ("WideChar.scan/NONE-on-nothing-to-read",
                    fn () => not (isSome (WideChar.scan Substring.getc (Substring.full "\\q"))))
  (*>> text *)
end
