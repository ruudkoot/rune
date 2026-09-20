(* StringCvt: the types and helpers of the fmt and scan functions. Written on
   primitives, without another structure, because most others require it. *)
structure StringCvt =
struct
  datatype radix = BIN | OCT | DEC | HEX
  datatype realfmt = SCI of int option | FIX of int option | GEN of int option | EXACT
  type ('a, 'b) reader = 'b -> ('a * 'b) option

  (* the state of scanString: the index of the next character *)
  type cs = int

  local
    val sub = _prim "string_sub" : string * int -> char
    (* n copies of c, for n > 0 *)
    fun copies (c, n) =
      let fun go (0, acc) = acc
            | go (k, acc) = go (k - 1, c :: acc)
      in implode (go (n, [])) end
    fun isSpace c =
      c = #" " orelse c = #"\t" orelse c = #"\n" orelse c = #"\r" orelse c = #"\v" orelse c = #"\f"
  in
    (* String.maxSize: "raise Size if the size of the resulting string would be greater" *)
    val maxSize = 1073741823
    fun padLeft c i s =
      if size s >= i then s else if i > maxSize then raise Size else copies (c, i - size s) ^ s
    fun padRight c i s =
      if size s >= i then s else if i > maxSize then raise Size else s ^ copies (c, i - size s)

    fun splitl p (getc : (char, 'a) reader) src =
      let
        fun go (src, acc) =
          case getc src of
            SOME (c, rest) => if p c then go (rest, c :: acc) else (implode (rev acc), src)
          | NONE => (implode (rev acc), src)
      in go (src, []) end

    fun takel p getc src = #1 (splitl p getc src)

    fun dropl p (getc : (char, 'a) reader) src =
      case getc src of
        SOME (c, rest) => if p c then dropl p getc rest else src
      | NONE => src

    fun skipWS getc src = dropl isSpace getc src

    fun scanString (scan : (char, cs) reader -> ('a, cs) reader) s =
      let
        val n = size s
        fun getc i = if i < n then SOME (sub (s, i), i + 1) else NONE
      in
        case scan getc 0 of
          SOME (v, _) => SOME v
        | NONE => NONE
      end
  end
end
