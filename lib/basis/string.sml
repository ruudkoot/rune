(* String: 8-bit byte strings. *)
structure String =
struct
  type string = string
  type char = char

  val maxSize = 1073741823
  val size = size
  val sub = _prim "string_sub" : string * int -> char
  val op ^ = op ^
  val str = str
  val implode = implode
  val explode = explode
  val concat = concat
  val extractN = _prim "string_extract" : string * int * int -> string

  fun extract (s, i, NONE) = extractN (s, i, Int.- (size s, i))
    | extract (s, i, SOME n) = extractN (s, i, n)

  val substring = substring

  fun concatWith sep [] = ""
    | concatWith sep (s :: rest) = concat (s :: List.foldr (fn (x, acc) => sep :: x :: acc) [] rest)

  fun map f s = implode (List.map f (explode s))

  fun translate f s = concat (List.map f (explode s))

  fun isPrefix p s =
    let val np = size p
    in Int.<= (np, size s) andalso extractN (s, 0, np) = p end

  fun isSuffix p s =
    let val np = size p and ns = size s
    in Int.<= (np, ns) andalso extractN (s, Int.- (ns, np), np) = p end

  fun isSubstring p s =
    let
      val np = size p and ns = size s
      fun go i = Int.<= (Int.+ (i, np), ns) andalso (extractN (s, i, np) = p orelse go (Int.+ (i, 1)))
    in go 0 end

  (* fields: every delimiter separates; tokens: runs of delimiters collapse and empties vanish *)
  fun fields isDelim s =
    let
      val n = size s
      fun go (i, start, acc) =
        if Int.>= (i, n) then List.rev (extractN (s, start, Int.- (i, start)) :: acc)
        else if isDelim (sub (s, i)) then go (Int.+ (i, 1), Int.+ (i, 1), extractN (s, start, Int.- (i, start)) :: acc)
        else go (Int.+ (i, 1), start, acc)
    in go (0, 0, []) end

  fun tokens isDelim s = List.filter (fn t => Int.> (size t, 0)) (fields isDelim s)

  val compareInt = _prim "string_compare" : string * string -> int
  fun compare (a, b) =
    let val c = compareInt (a, b)
    in if Int.< (c, 0) then LESS else if Int.> (c, 0) then GREATER else EQUAL end

  fun collate cmp (a, b) = List.collate cmp (explode a, explode b)

  val op < = _prim "string_lt" : string * string -> bool
  val op <= = _prim "string_le" : string * string -> bool
  val op > = _prim "string_gt" : string * string -> bool
  val op >= = _prim "string_ge" : string * string -> bool

  fun toString s = translate Char.toString s

  (* formatting sequences are skipped around every character *)
  fun scan getc src = RuneEscape.scanString (RuneEscape.scanSml, true) getc src
  fun fromString s = StringCvt.scanString scan s
  fun toCString s = translate Char.toCString s
  fun fromCString s = StringCvt.scanString (RuneEscape.scanString (RuneEscape.cChar, false)) s
end
