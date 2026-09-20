(* Int: fixed precision integers with Overflow checking: 64 bits on the VM.
   The bounds are found with the arithmetic itself (2n + 1 until it overflows),
   so that this file means the same to a system whose int is narrower; see
   tests/basis/README.md on the xc1 configurations. *)
structure Int =
struct
  type int = int

  local
    val add = _prim "int_add" : int * int -> int
    (* (2^k - 1, k) for the largest k without overflow *)
    fun grow (n, k) = grow (add (add (n, n), 1), add (k, 1)) handle Overflow => (n, k)
    val (largest, bits) = grow (0, 0)
  in
    val precision = SOME (add (bits, 1))
    val maxInt = SOME largest
    val minInt = SOME ((_prim "int_sub" : int * int -> int) ((_prim "int_neg" : int -> int) largest, 1))
  end

  val toInt = fn (x : int) => x
  val fromInt = fn (x : int) => x
  val toLarge = IntInf.fromInt
  val fromLarge = IntInf.toInt

  val op + = _prim "int_add" : int * int -> int
  val op - = _prim "int_sub" : int * int -> int
  val op * = _prim "int_mul" : int * int -> int
  val op div = _prim "int_div" : int * int -> int
  val op mod = _prim "int_mod" : int * int -> int
  val quot = _prim "int_quot" : int * int -> int
  val rem = _prim "int_rem" : int * int -> int
  val ~ = _prim "int_neg" : int -> int
  val abs = _prim "int_abs" : int -> int
  val op < = _prim "int_lt" : int * int -> bool
  val op <= = _prim "int_le" : int * int -> bool
  val op > = _prim "int_gt" : int * int -> bool
  val op >= = _prim "int_ge" : int * int -> bool

  fun min (a : int, b) = if a < b then a else b
  fun max (a : int, b) = if a > b then a else b
  fun sign (a : int) = if a < 0 then ~1 else if a > 0 then 1 else 0
  fun sameSign (a, b) = sign a = sign b
  fun compare (a : int, b) = if a < b then LESS else if a = b then EQUAL else GREATER

  val toString = _prim "int_to_string" : int -> string

  (* The value of a digit in the radix, if it is one. *)
  fun digitValue (radix, c) =
    let
      val n = ord c
      val v = if 48 <= n andalso n <= 57 then n - 48
              else if 97 <= n andalso n <= 102 then n - 87
              else if 65 <= n andalso n <= 70 then n - 55
              else 99
    in if v < radix then SOME v else NONE end

  fun base StringCvt.BIN = 2
    | base StringCvt.OCT = 8
    | base StringCvt.DEC = 10
    | base StringCvt.HEX = 16

  (* Digits are produced from the negated number, which exists for minInt too. *)
  fun fmt radix (i : int) =
    let
      val r = base radix
      fun digit d = chr (if d < 10 then 48 + d else 55 + d)
      fun go (n, acc) =      (* n <= 0 *)
        let val acc = digit (~ (rem (n, r))) :: acc
            val n = quot (n, r)
        in if n = 0 then acc else go (n, acc) end
    in
      if i < 0 then implode (#"~" :: go (i, [])) else implode (go (~ i, []))
    end

  (* [+~-]?[0-9]+ and its analogues; in radix HEX an optional 0x or 0X, which
     counts only when a digit follows ("0xg" is 0 and leaves "xg"). The
     number is accumulated negated, so that minInt does not overflow. *)
  fun scan radix (getc : (char, 'a) StringCvt.reader) src =
    let
      val r = base radix
      val src = StringCvt.skipWS getc src
      val (negative, src) =
        case getc src of
          SOME (#"~", rest) => (true, rest)
        | SOME (#"-", rest) => (true, rest)
        | SOME (#"+", rest) => (false, rest)
        | _ => (false, src)
      fun isDigitNext src =
        case getc src of SOME (c, _) => (case digitValue (r, c) of SOME _ => true | NONE => false) | NONE => false
      val src =
        if r <> 16 then src
        else
          case getc src of
            SOME (#"0", rest) =>
              (case getc rest of
                 SOME (c, rest') => if (c = #"x" orelse c = #"X") andalso isDigitNext rest' then rest' else src
               | NONE => src)
          | _ => src
      fun digits (src, acc) =
        case getc src of
          SOME (c, rest) =>
            (case digitValue (r, c) of
               SOME d => digits (rest, acc * r - d)
             | NONE => (acc, src))
        | NONE => (acc, src)
    in
      if isDigitNext src then
        let val (v, rest) = digits (src, 0)
        in SOME (if negative then v else ~ v, rest) end
      else NONE
    end

  fun fromString s = StringCvt.scanString (scan StringCvt.DEC) s
end
