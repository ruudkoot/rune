(* Int64: the 64-bit integers, and FixedInt, the largest of the
   fixed-precision ones, which is the same structure.

   The type is the VM's own 64-bit integer and not `Int.int`, whose width the
   VM decides (63 bits: an int is a word of the VM with a bit taken for its
   tag). A number here is kept in such a word where it fits and in a small
   object where it needs the 64th bit, so arithmetic that stays small costs
   what `Int`'s does; `toInt` and `fromInt` are the way between the two types.

   Implements: INTEGER

   Status: optional *)
structure Int64 =
struct
  type int = _prim "int64"

  local
    (* in Int.int, before the operators below are this structure's *)
    fun digitChar (d : Int.int) = chr (if d < 10 then 48 + d else 55 + d)
    fun radixOf StringCvt.BIN = 2
      | radixOf StringCvt.OCT = 8
      | radixOf StringCvt.DEC = 10
      | radixOf StringCvt.HEX = (16 : Int.int)
    val two32 = IntInf.fromInt 4294967296
  in

  val precision = SOME (64 : Int.int)
  val maxInt = SOME (9223372036854775807 : int)
  val minInt = SOME (~9223372036854775808 : int)

  val toInt = _prim "int64_to_int" : int -> Int.int
  val fromInt = _prim "int64_from_int" : Int.int -> int

  val op + = _prim "int64_add" : int * int -> int
  val op - = _prim "int64_sub" : int * int -> int
  val op * = _prim "int64_mul" : int * int -> int
  val op div = _prim "int64_div" : int * int -> int
  val op mod = _prim "int64_mod" : int * int -> int
  val quot = _prim "int64_quot" : int * int -> int
  val rem = _prim "int64_rem" : int * int -> int
  val ~ = _prim "int64_neg" : int -> int
  val abs = _prim "int64_abs" : int -> int
  val op < = _prim "int64_lt" : int * int -> bool
  val op <= = _prim "int64_le" : int * int -> bool
  val op > = _prim "int64_gt" : int * int -> bool
  val op >= = _prim "int64_ge" : int * int -> bool

  (* through the two halves, each of which an Int.int holds: x is
     (x div 2^32) * 2^32 + x mod 2^32, the first signed, the second not *)
  fun toLarge (x : int) : IntInf.int =
    IntInf.+ (IntInf.* (IntInf.fromInt (toInt (x div 4294967296)), two32), IntInf.fromInt (toInt (x mod 4294967296)))
  (* Overflow from IntInf.toInt where the upper half is no Int.int, and from
     the arithmetic where the number is one bit too wide *)
  fun fromLarge (n : IntInf.int) : int =
    let val (q, r) = IntInf.divMod (n, two32)
    in fromInt (IntInf.toInt q) * 4294967296 + fromInt (IntInf.toInt r) end

  fun min (a : int, b) = if a < b then a else b
  fun max (a : int, b) = if a > b then a else b
  fun sign (a : int) : Int.int = if a < 0 then ~1 else if a > 0 then 1 else 0
  fun sameSign (a, b) = sign a = sign b
  val compare = _prim "int64_order" : int * int -> order

  val toString = _prim "int64_to_string" : int -> string

  (* Digits are produced from the negated number, which exists for minInt too. *)
  fun fmt radix (i : int) =
    let
      val r = fromInt (radixOf radix)
      fun go (n : int, acc) =      (* n <= 0 *)
        let val acc = digitChar (toInt (~ (rem (n, r)))) :: acc
            val n = quot (n, r)
        in if n = 0 then acc else go (n, acc) end
    in
      if i < 0 then implode (#"~" :: go (i, [])) else implode (go (~ i, []))
    end

  (* As Int.scan: [+~-]?[0-9]+ and its analogues, in radix HEX an optional 0x
     or 0X that counts only when a digit follows. The number is accumulated
     negated, so that minInt does not overflow. *)
  fun scan radix (getc : (char, 'a) StringCvt.reader) src =
    let
      val radix' = radixOf radix
      val r = fromInt radix'
      val src = StringCvt.skipWS getc src
      val (negative, src) =
        case getc src of
          SOME (#"~", rest) => (true, rest)
        | SOME (#"-", rest) => (true, rest)
        | SOME (#"+", rest) => (false, rest)
        | _ => (false, src)
      fun isDigitNext src =
        case getc src of SOME (c, _) => (case Int.digitValue (radix', c) of SOME _ => true | NONE => false) | NONE => false
      val src =
        if radix' <> 16 then src
        else
          case getc src of
            SOME (#"0", rest) =>
              (case getc rest of
                 SOME (c, rest') => if (c = #"x" orelse c = #"X") andalso isDigitNext rest' then rest' else src
               | NONE => src)
          | _ => src
      fun digits (src, acc : int) =
        case getc src of
          SOME (c, rest) =>
            (case Int.digitValue (radix', c) of
               SOME d => digits (rest, acc * r - fromInt d)
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
end
(* The largest fixed-precision integer: `Int` is the VM's word less a bit,
   so it is the 64-bit one.

   Implements: INTEGER where type int = Int64.int

   Status: optional *)
structure FixedInt = Int64
