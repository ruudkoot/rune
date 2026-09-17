(* Char: 8-bit characters. *)
structure Char =
struct
  type char = char
  type string = string

  val ord = _prim "char_ord" : char -> int
  val chr = _prim "int_to_char" : int -> char
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

  fun fromString s =
    let
      val cs = (_prim "string_explode" : string -> char list) s
    in
      case cs of
        [] => NONE
      | #"\\" :: rest =>
        (case rest of
           #"a" :: _ => SOME #"\a" | #"b" :: _ => SOME #"\b" | #"t" :: _ => SOME #"\t"
         | #"n" :: _ => SOME #"\n" | #"v" :: _ => SOME #"\v" | #"f" :: _ => SOME #"\f"
         | #"r" :: _ => SOME #"\r" | #"\\" :: _ => SOME #"\\" | #"\"" :: _ => SOME #"\""
         | #"^" :: d :: _ => SOME (chr (Int.- (ord d, 64)))
         | a :: b :: d :: _ =>
           if isDigit a andalso isDigit b andalso isDigit d then
             let val v = Int.+ (Int.* (Int.- (ord a, 48), 100), Int.+ (Int.* (Int.- (ord b, 48), 10), Int.- (ord d, 48)))
             in if Int.> (v, 255) then NONE else SOME (chr v) end
           else NONE
         | _ => NONE)
      | c :: _ => SOME c
    end
end
