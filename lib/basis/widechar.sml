(* The wide character (optional in the specification): a character is a
   Unicode code point, 0 to 0x10FFFF, as MLton's WideChar has it. The code
   point sits in a type of its own, so that WideChar.char, char and int stay
   apart and the families of the wide character carry it.

   This file has what the wide family is made of: the character, its
   operations, and the vectors, slices and arrays of it as they are before
   widestring.sml seals them together with WideString, in the order of the
   specification -- the strings first, and the vectors of characters a view
   of them, as `CharVector.vector` is `String.string`. *)
structure RuneWideChar :>
sig
  eqtype char
  val maxOrd : int
  val ord : char -> int
  val chr : int -> char
  (* `decodeUtf8 (s, i, n)`: the characters that the UTF-8 of `s` from byte
     `i` encodes, at most `n`, the byte after them, and 0, or 1 where a
     sequence that is not UTF-8 begins there, or 2 where the end of `s` cuts
     one short (the primitive `utf8_decode`; WideTextIO's reader) *)
  val decodeUtf8 : string * int * int -> char vector * int * int
end =
struct
  type char = int
  val maxOrd = 1114111                       (* 0x10FFFF *)
  fun ord (c : char) : int = c
  fun chr i = if Int.< (i, 0) orelse Int.> (i, maxOrd) then raise Chr else i
  val decodeUtf8 = _prim "utf8_decode" : string * int * int -> int vector * int * int
end

(* The vectors, slices and arrays of wide characters before the seal of
   widestring.sml, where their types are those of the polymorphic vectors and
   arrays. *)
structure RuneWideCharVector = RuneMonoVectorFn (type elem = RuneWideChar.char)
structure RuneWideCharVectorSlice =
struct
  structure S = RuneMonoVectorSliceFn (structure V = RuneWideCharVector)
  open S
  (* a stretch copied in C (Vector.extract), where the functor tabulates it,
     as String.substring copies the bytes of a string *)
  fun vector (Slice (v, i, n)) = Vector.extract (v, i, n)
  fun concat l = Vector.concat (List.map vector l)
end
structure RuneWideCharArray = RuneMonoArrayFn (structure V = RuneWideCharVector)
structure RuneWideCharArraySlice =
  RuneMonoArraySliceFn (structure V = RuneWideCharVector structure A = RuneWideCharArray
                        structure VS = RuneWideCharVectorSlice)
structure RuneWideCharArray2 = RuneMonoArray2Fn (structure V = RuneWideCharVector)

structure RuneWideCharImpl =
struct
  type char = RuneWideChar.char
  type string = RuneWideCharVector.vector

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

  fun contains s c = RuneWideCharVector.exists (fn x => x = c) s
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
    (* the scanner of a wide string, one character at a time: a double quote
       that is not escaped is a character of a string (String.scan) *)
    val scanInString = scan
    fun scanWide (sml, getc, src) = wide getc (sml, src)
    (* WideChar.scan: as Char.scan, it is no character constant *)
    val scan = fn getc => fn src =>
      case getc (#2 (RuneEscape.skipFormat getc src)) of
        SOME (#"\"", _) => NONE
      | _ => scan getc src
    fun fromString s = StringCvt.scanString scan s
    fun fromCString s = StringCvt.scanString (fn getc => fn src => wide getc (false, src)) s
  end
end
