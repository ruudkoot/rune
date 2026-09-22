(* RuneEscape: scanning the escape sequences of SML and of C character and
   string constants from a character reader, for Char and String. *)
structure RuneEscape =
struct
  fun isFormat c =
    c = #" " orelse c = #"\t" orelse c = #"\n" orelse c = #"\r" orelse c = #"\v" orelse c = #"\f"
  fun isPrint c = let val n = ord c in 32 <= n andalso n <= 126 end
  fun digit (radix, c) =
    let
      val n = ord c
      val v = if 48 <= n andalso n <= 57 then n - 48
              else if 97 <= n andalso n <= 102 then n - 87
              else if 65 <= n andalso n <= 70 then n - 55
              else 99
    in if v < radix then SOME v else NONE end

  (* Skip escaped formatting sequences, \f...f\ with one or more formatting
     characters; the result says whether there was one. *)
  fun skipFormat (getc : (char, 'a) StringCvt.reader) src =
    let
      fun close s =
        case getc s of
          SOME (c, s') => if isFormat c then close s' else if c = #"\\" then SOME s' else NONE
        | NONE => NONE
      fun go (src, any) =
        case getc src of
          SOME (#"\\", rest) =>
            (case getc rest of
               SOME (c, rest') =>
                 if isFormat c then (case close rest' of SOME after => go (after, true) | NONE => (any, src))
                 else (any, src)
             | NONE => (any, src))
        | _ => (any, src)
    in go (src, false) end

  (* exactly n digits in the radix *)
  fun fixedDigits (getc : (char, 'a) StringCvt.reader) (radix, n, src) =
    let
      fun go (0, src, acc) = SOME (acc, src)
        | go (k, src, acc) =
          (case getc src of
             SOME (c, rest) => (case digit (radix, c) of SOME d => go (k - 1, rest, acc * radix + d) | NONE => NONE)
           | NONE => NONE)
    in go (n, src, 0) end

  fun control (getc : (char, 'a) StringCvt.reader) src =
    case getc src of
      SOME (c, rest) => let val n = ord c in if 64 <= n andalso n <= 95 then SOME (chr (n - 64), rest) else NONE end
    | NONE => NONE

  fun inRange (SOME (v, rest)) = if v <= 255 then SOME (chr v, rest) else NONE
    | inRange NONE = NONE

  (* One character of an SML constant, without the formatting sequences
     around it. *)
  fun smlChar (getc : (char, 'a) StringCvt.reader) src =
    case getc src of
      NONE => NONE
    | SOME (#"\\", rest) =>
        (case getc rest of
           SOME (#"a", r) => SOME (#"\a", r) | SOME (#"b", r) => SOME (#"\b", r)
         | SOME (#"t", r) => SOME (#"\t", r) | SOME (#"n", r) => SOME (#"\n", r)
         | SOME (#"v", r) => SOME (#"\v", r) | SOME (#"f", r) => SOME (#"\f", r)
         | SOME (#"r", r) => SOME (#"\r", r) | SOME (#"\\", r) => SOME (#"\\", r)
         | SOME (#"\"", r) => SOME (#"\"", r)
         | SOME (#"^", r) => control getc r
         | SOME (#"u", r) => inRange (fixedDigits getc (16, 4, r))
         | SOME (_, _) => inRange (fixedDigits getc (10, 3, rest))
         | NONE => NONE)
    | SOME (c, rest) => if isPrint c then SOME (c, rest) else NONE

  (* Char.scan: the remaining stream never starts with a formatting sequence. *)
  fun scanSml getc src =
    case smlChar getc (#2 (skipFormat getc src)) of
      SOME (c, rest) => SOME (c, #2 (skipFormat getc rest))
    | NONE => NONE

  (* Char.scan: a character "as allowed in an SML program", where a double
     quote that no backslash precedes ends a constant and is no character.
     String.scan goes on over it (scanSml): its page names what stops a
     scan, and a double quote is none of that. *)
  fun scanSmlChar getc src =
    case getc (#2 (skipFormat getc src)) of
      SOME (#"\"", _) => NONE
    | _ => scanSml getc src

  (* One character of a C constant: no formatting sequences, no unescaped
     double quote; \ooo has one to three octal digits, \xh... any number. *)
  fun cChar (getc : (char, 'a) StringCvt.reader) src =
    let
      fun octal (src, acc, k) =
        if k = 3 then (acc, src)
        else
          case getc src of
            SOME (c, rest) => (case digit (8, c) of SOME d => octal (rest, acc * 8 + d, k + 1) | NONE => (acc, src))
          | NONE => (acc, src)
      (* a value above 255 stays above 255 without growing *)
      fun hex (src, acc, any) =
        case getc src of
          SOME (c, rest) =>
            (case digit (16, c) of
               SOME d => hex (rest, if acc > 255 then acc else acc * 16 + d, true)
             | NONE => (acc, src, any))
        | NONE => (acc, src, any)
    in
      case getc src of
        NONE => NONE
      | SOME (#"\\", rest) =>
          (case getc rest of
             SOME (#"a", r) => SOME (#"\a", r) | SOME (#"b", r) => SOME (#"\b", r)
           | SOME (#"t", r) => SOME (#"\t", r) | SOME (#"n", r) => SOME (#"\n", r)
           | SOME (#"v", r) => SOME (#"\v", r) | SOME (#"f", r) => SOME (#"\f", r)
           | SOME (#"r", r) => SOME (#"\r", r) | SOME (#"?", r) => SOME (#"?", r)
           | SOME (#"\\", r) => SOME (#"\\", r) | SOME (#"\"", r) => SOME (#"\"", r)
           | SOME (#"'", r) => SOME (#"'", r)
           | SOME (#"^", r) => control getc r
           | SOME (#"x", r) =>
               let val (v, r', any) = hex (r, 0, false)
               in if any then inRange (SOME (v, r')) else NONE end
           | SOME (c, _) =>
               (case digit (8, c) of
                  SOME _ => inRange (SOME (octal (rest, 0, 0)))
                | NONE => NONE)
           | NONE => NONE)
      | SOME (c, rest) => if isPrint c andalso c <> #"\"" then SOME (c, rest) else NONE
    end

  (* As many characters as can be scanned. The result is NONE only when
     nothing at all could be: no character and no formatting sequence. *)
  fun scanString (one : (char, 'a) StringCvt.reader -> (char, 'a) StringCvt.reader, format : bool)
                 (getc : (char, 'a) StringCvt.reader) src =
    let
      val (skipped, src) = if format then skipFormat getc src else (false, src)
      fun go (src, acc) =
        case one getc src of
          SOME (c, rest) => go (rest, c :: acc)
        | NONE => (acc, src)
      val (acc, rest) = go (src, [])
      val atEnd = case getc src of NONE => true | SOME _ => false
    in
      case acc of
        [] => if skipped orelse atEnd then SOME ("", rest) else NONE
      | _ => SOME (implode (rev acc), rest)
    end

  fun toC c =
    case c of
      #"\\" => "\\\\" | #"\"" => "\\\"" | #"?" => "\\?" | #"'" => "\\'"
    | #"\a" => "\\a" | #"\b" => "\\b" | #"\t" => "\\t" | #"\n" => "\\n"
    | #"\v" => "\\v" | #"\f" => "\\f" | #"\r" => "\\r"
    | _ =>
        if isPrint c then str c
        else
          let val n = ord c
              fun o' k = chr (48 + k)
          in implode [#"\\", o' (n div 64), o' (n div 8 mod 8), o' (n mod 8)] end
end

(* Char: 8-bit characters.

   Implements: CHAR where type char = char where type string = String.string *)
structure Char =
struct
  type char = char
  type string = string

  val ord = ord
  val chr = chr
  val minChar = #"\000"
  val maxChar = #"\255"
  val maxOrd = 255

  val op < = _prim "char_lt" : char * char -> bool
  val op <= = _prim "char_le" : char * char -> bool
  val op > = _prim "char_gt" : char * char -> bool
  val op >= = _prim "char_ge" : char * char -> bool

  fun compare (a : char, b) = if a < b then LESS else if a = b then EQUAL else GREATER

  fun succ c = if c = maxChar then raise Chr else chr (Int.+ (ord c, 1))
  fun pred c = if c = minChar then raise Chr else chr (Int.- (ord c, 1))

  fun contains s c =
    let
      val n = (_prim "string_size" : string -> int) s
      val sub = _prim "string_sub" : string * int -> char
      fun go i = Int.< (i, n) andalso (sub (s, i) = c orelse go (Int.+ (i, 1)))
    in go 0 end

  fun notContains s c = not (contains s c)

  fun isUpper c = c >= #"A" andalso c <= #"Z"
  fun isLower c = c >= #"a" andalso c <= #"z"
  fun isDigit c = c >= #"0" andalso c <= #"9"
  fun isAlpha c = isUpper c orelse isLower c
  fun isAlphaNum c = isAlpha c orelse isDigit c
  fun isHexDigit c = isDigit c orelse (c >= #"a" andalso c <= #"f") orelse (c >= #"A" andalso c <= #"F")
  fun isSpace c = c = #" " orelse c = #"\t" orelse c = #"\n" orelse c = #"\r" orelse c = #"\v" orelse c = #"\f"
  fun isGraph c = c >= #"!" andalso c <= #"~"
  fun isPrint c = c >= #" " andalso c <= #"~"
  fun isPunct c = isGraph c andalso not (isAlphaNum c)
  fun isCntrl c = c < #" " orelse c = #"\127"
  fun isAscii c = c <= #"\127"

  fun toLower c = if isUpper c then chr (Int.+ (ord c, 32)) else c
  fun toUpper c = if isLower c then chr (Int.- (ord c, 32)) else c

  (* SML escape syntax *)
  fun toString c =
    let
      val str = _prim "string_from_char" : char -> string
      val itos = _prim "int_to_string" : int -> string
      val cat = _prim "string_concat" : string * string -> string
      val n = ord c
    in
      case c of
        #"\\" => "\\\\"
      | #"\"" => "\\\""
      | #"\a" => "\\a"
      | #"\b" => "\\b"
      | #"\t" => "\\t"
      | #"\n" => "\\n"
      | #"\v" => "\\v"
      | #"\f" => "\\f"
      | #"\r" => "\\r"
      | _ =>
        if Int.< (n, 32) then cat ("\\^", str (chr (Int.+ (n, 64))))
        else if Int.>= (n, 127) then
          cat ("\\", cat (if Int.< (n, 100) then "0" else "", itos n))
        else str c
    end

  val scan = RuneEscape.scanSmlChar
  fun fromString s = StringCvt.scanString scan s
  val toCString = RuneEscape.toC
  fun fromCString s = StringCvt.scanString RuneEscape.cChar s
end
