(* String: 8-bit byte strings. *)
structure String =
struct
  type string = string
  type char = char

  val maxSize = 1073741823
  val size = _prim "string_size" : string -> int
  val sub = _prim "string_sub" : string * int -> char
  val op ^ = _prim "string_concat" : string * string -> string
  val str = _prim "string_from_char" : char -> string
  val implode = _prim "string_implode" : char list -> string
  val explode = _prim "string_explode" : string -> char list
  val concat = _prim "string_concat_list" : string list -> string
  val extractN = _prim "string_extract" : string * int * int -> string

  fun extract (s, i, NONE) = extractN (s, i, Int.- (size s, i))
    | extract (s, i, SOME n) = extractN (s, i, n)

  fun substring (s, i, n) = extractN (s, i, n)

  fun concatWith sep [] = ""
    | concatWith sep [s] = s
    | concatWith sep (s :: rest) = s ^ sep ^ concatWith sep rest

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

  fun fromString s =
    let
      fun go [] = SOME []
        | go (#"\\" :: rest) =
          let
            fun skipGap (c :: cs) = if Char.isSpace c then skipGap cs else c :: cs
              | skipGap [] = []
          in
            case rest of
              #"a" :: cs => cont (#"\a", cs) | #"b" :: cs => cont (#"\b", cs)
            | #"t" :: cs => cont (#"\t", cs) | #"n" :: cs => cont (#"\n", cs)
            | #"v" :: cs => cont (#"\v", cs) | #"f" :: cs => cont (#"\f", cs)
            | #"r" :: cs => cont (#"\r", cs) | #"\\" :: cs => cont (#"\\", cs)
            | #"\"" :: cs => cont (#"\"", cs)
            | #"^" :: d :: cs => cont (Char.chr (Int.- (Char.ord d, 64)), cs)
            | a :: b :: d :: cs =>
              if Char.isDigit a andalso Char.isDigit b andalso Char.isDigit d then
                let val v = Int.+ (Int.* (Int.- (Char.ord a, 48), 100),
                                   Int.+ (Int.* (Int.- (Char.ord b, 48), 10), Int.- (Char.ord d, 48)))
                in if Int.> (v, 255) then NONE else cont (Char.chr v, cs) end
              else if Char.isSpace a then go (skipGapEnd (skipGap (a :: b :: d :: cs)))
              else NONE
            | c :: cs => if Char.isSpace c then go (skipGapEnd (skipGap (c :: cs))) else NONE
            | [] => NONE
          end
        | go (c :: cs) = cont (c, cs)
      and cont (c, cs) = case go cs of NONE => NONE | SOME r => SOME (c :: r)
      and skipGapEnd (#"\\" :: cs) = cs
        | skipGapEnd cs = cs
    in
      case go (explode s) of NONE => NONE | SOME cs => SOME (implode cs)
    end
end
