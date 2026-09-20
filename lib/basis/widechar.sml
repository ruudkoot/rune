(* WideChar and the vectors and arrays of wide characters (optional in the
   specification): a character is a Unicode code point, 0 to 0x10FFFF, as
   MLton's WideChar has it. The code point sits in a type of its own, so that
   WideChar.char, char and int stay apart and the families of the wide
   character carry it. *)
structure RuneWideChar :>
sig
  eqtype char
  val maxOrd : int
  val ord : char -> int
  val chr : int -> char
end =
struct
  type char = int
  val maxOrd = 1114111                       (* 0x10FFFF *)
  fun ord (c : char) : int = c
  fun chr i = if Int.< (i, 0) orelse Int.> (i, maxOrd) then raise Chr else i
end

(* Sealed with a vector of its own (MONO_VECTOR_EQ), so that WideString.string
   is a type name: the constants of a type are overloaded at a name.

   Implements: MONO_VECTOR where type elem = WideChar.char

   Status: optional *)
structure WideCharVector :> MONO_VECTOR_EQ where type elem = RuneWideChar.char =
  RuneMonoVectorFn (type elem = RuneWideChar.char)
(* Implements: MONO_VECTOR_SLICE where type vector = WideCharVector.vector
   where type elem = WideChar.char

   Status: optional *)
structure WideCharVectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = WideCharVector)
(* Implements: MONO_ARRAY where type vector = WideCharVector.vector where type
   elem = WideChar.char

   Status: optional *)
structure WideCharArray : MONO_ARRAY = RuneMonoArrayFn (structure V = WideCharVector)
(* Implements: MONO_ARRAY_SLICE where type vector = WideCharVector.vector
   where type vector_slice = WideCharVectorSlice.slice where type array =
   WideCharArray.array where type elem = WideChar.char

   Status: optional *)
structure WideCharArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = WideCharVector structure A = WideCharArray structure VS = WideCharVectorSlice)

structure RuneWideCharImpl =
struct
  type char = RuneWideChar.char
  type string = WideCharVector.vector

  val maxOrd = RuneWideChar.maxOrd
  val ord = RuneWideChar.ord
  val chr = RuneWideChar.chr
  val minChar = chr 0
  val maxChar = chr maxOrd
  fun succ c = chr (Int.+ (ord c, 1))
  fun pred c = chr (Int.- (ord c, 1))

  fun compare (a, b) = Int.compare (ord a, ord b)
  fun op < (a, b) = Int.< (ord a, ord b)
  fun op <= (a, b) = Int.<= (ord a, ord b)
  fun op > (a, b) = Int.> (ord a, ord b)
  fun op >= (a, b) = Int.>= (ord a, ord b)

  fun contains s c = WideCharVector.exists (fn x => x = c) s
  fun notContains s c = not (contains s c)

  (* the classes of ASCII, through Char; a character above 127 is in none *)
  fun ascii f c = let val n = ord c in Int.<= (n, 127) andalso f (Char.chr n) end
  fun isAscii c = Int.<= (ord c, 127)
  val isAlpha = ascii Char.isAlpha
  val isAlphaNum = ascii Char.isAlphaNum
  val isCntrl = ascii Char.isCntrl
  val isDigit = ascii Char.isDigit
  val isGraph = ascii Char.isGraph
  val isHexDigit = ascii Char.isHexDigit
  val isLower = ascii Char.isLower
  val isPrint = ascii Char.isPrint
  val isSpace = ascii Char.isSpace
  val isPunct = ascii Char.isPunct
  val isUpper = ascii Char.isUpper
  fun mapAscii f c =
    let val n = ord c
    in if Int.<= (n, 127) then chr (Char.ord (f (Char.chr n))) else c end
  val toLower = mapAscii Char.toLower
  val toUpper = mapAscii Char.toUpper

  (* ---- text ---- *)
  local
    val digits = "0123456789ABCDEF"
    fun hex (n, width) =
      let
        fun go (0, _, acc) = acc
          | go (k, i, acc) =
            go (Int.- (k, 1), Int.div (i, 16), String.str (String.sub (digits, Int.mod (i, 16))) ^ acc)
      in go (width, n, "") end
  in
    (* above 255 the escapes of MLton: \uXXXX, and \UXXXXXXXX above 0xFFFF *)
    fun escape narrow c =
      let val n = ord c
      in
        if Int.<= (n, 255) then narrow (Char.chr n)
        else if Int.<= (n, 65535) then "\\u" ^ hex (n, 4)
        else "\\U" ^ hex (n, 8)
      end
    val toString = escape Char.toString
    val toCString = escape Char.toCString
  end

  (* One character of a constant, in SML syntax (sml = true) or in C syntax,
     as a code point: the escapes of Char with \u and \U widened. *)
  local
    fun wide (getc : (Char.char, 'a) StringCvt.reader) (sml, src) =
      let
        fun code (SOME (v, rest)) = if Int.<= (v, maxOrd) then SOME (chr v, rest) else NONE
          | code NONE = NONE
        fun narrow one src = case one getc src of SOME (c, rest) => SOME (chr (Char.ord c), rest) | NONE => NONE
      in
        case getc src of
          SOME (#"\\", rest) =>
            (case getc rest of
               SOME (#"u", r) => code (RuneEscape.fixedDigits getc (16, 4, r))
             | SOME (#"U", r) => code (RuneEscape.fixedDigits getc (16, 8, r))
             | SOME (c, r) =>
                 if sml andalso Int.<= (48, Char.ord c) andalso Int.<= (Char.ord c, 57)
                 then code (RuneEscape.fixedDigits getc (10, 3, rest))
                 else narrow (if sml then RuneEscape.smlChar else RuneEscape.cChar) src
             | NONE => NONE)
        | _ => narrow (if sml then RuneEscape.smlChar else RuneEscape.cChar) src
      end
  in
    (* "\U" takes eight hexadecimal digits, "\u" four; a \ddd of three decimal
       digits may name any code point (MLton reads it so). *)
    fun scan getc src =
      let val (_, after) = RuneEscape.skipFormat getc src
      in
        case wide getc (true, after) of
          SOME (c, rest) => SOME (c, #2 (RuneEscape.skipFormat getc rest))
        | NONE => NONE
      end
    fun fromString s = StringCvt.scanString scan s
    fun fromCString s = StringCvt.scanString (fn getc => fn src => wide getc (false, src)) s
    (* the scanner of a wide string, one character at a time *)
    fun scanWide (sml, getc, src) = wide getc (sml, src)
  end
end

(* Implements: CHAR where type char = WideChar.char where type string =
   WideString.string

   Status: optional

   Reading: `WideChar.isAlpha/ascii-classes`. "In WideChar, the functions
   toLower, toUpper, isAlpha, ... and, in general, the definition of a letter
   are locale-dependent": here they are those of ASCII, so a character above
   127 is in no class and is its own upper and lower case. MLton reads it so
   too.

   Pinned by: `WideChar.isAscii/above-127`, `WideChar.isAlpha/e-acute`,
   `WideChar.toLower/leaves-a-wide-character`,
   `WideChar.toUpper/leaves-a-wide-character`

   Implementation: `WideChar.toString/escapes-above-255`. `toString` and
   `toCString` write a character above 255 as `\uXXXX`, or `\UXXXXXXXX` above
   0xFFFF, as MLton writes them, and `fromString` and `fromCString` read those
   escapes. `fromString` also reads `\ddd` of exactly three decimal digits,
   and `fromCString` the escapes of C, whose digits are octal; an octal or a
   `\x` escape of C names a character up to 255 only, so that
   `fromCString "\\x1F600"` is `NONE`. The text they take and
   give is of `char`, the 8-bit one, as the signature writes it, and `scan`
   reads from a stream of `char` and yields a wide character.

   Pinned by: `WideChar:CHAR/toString-gives-a-string-of-char`,
   `WideChar.scan/takes-the-escape-and-leaves-the-rest` *)
structure WideChar :> CHAR
  where type char = RuneWideChar.char
  where type string = WideCharVector.vector = RuneWideCharImpl

(* A character constant of the type WideChar.char is read from its text where
   it is evaluated, as the constants of IntInf and Real32 are. *)
structure RuneWideCharLit =
struct
  fun fromLit s = case WideChar.fromString s of SOME c => c | NONE => raise Fail ("wide character constant " ^ s)
end

_overload char WideChar via RuneWideCharLit.fromLit
