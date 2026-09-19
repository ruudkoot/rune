(* Real: IEEE double precision. *)
structure Real =
struct
  infix 4 == !=
  type real = real
  val radix = 2
  val precision = 53

  val op + = _prim "real_add" : real * real -> real
  val op - = _prim "real_sub" : real * real -> real
  val op * = _prim "real_mul" : real * real -> real
  val op / = _prim "real_div" : real * real -> real
  val ~ = _prim "real_neg" : real -> real
  val abs = _prim "real_abs" : real -> real
  val op < = _prim "real_lt" : real * real -> bool
  val op <= = _prim "real_le" : real * real -> bool
  val op > = _prim "real_gt" : real * real -> bool
  val op >= = _prim "real_ge" : real * real -> bool
  val op == = _prim "real_eq" : real * real -> bool
  fun (a != b) = not (a == b)
  val isNan = _prim "real_is_nan" : real -> bool

  val posInf = 1.0 / 0.0
  val negInf = ~1.0 / 0.0
  val maxFinite = 1.7976931348623157E308
  val minNormalPos = 2.2250738585072014E~308
  (* 2^~1074, computed: some hosts of the cross-check misread the literal
     4.9E~324 (SML/NJ 110.79 rejects it, 110.99.9 reads 0.0) *)
  val minPos = minNormalPos / 4503599627370496.0

  fun isFinite r = not (isNan r) andalso r < posInf andalso r > negInf
  fun isNormal r = isFinite r andalso abs r >= minNormalPos
  fun sign r = if isNan r then raise Domain else if r < 0.0 then ~1 else if r > 0.0 then 1 else 0

  (* the sign bit, of zeros and NaNs too *)
  val signBit = _prim "real_sign_bit" : real -> bool
  val copySign = _prim "real_copy_sign" : real * real -> real
  fun sameSign (a, b) = signBit a = signBit b

  fun min (a : real, b) = if isNan a then b else if isNan b then a else if a < b then a else b
  fun max (a : real, b) = if isNan a then b else if isNan b then a else if a > b then a else b
  fun unordered (a, b) = isNan a orelse isNan b
  fun compare (a : real, b) =
    if unordered (a, b) then raise IEEEReal.Unordered
    else if a < b then LESS else if a == b then EQUAL else GREATER
  fun compareReal (a : real, b) =
    if unordered (a, b) then IEEEReal.UNORDERED
    else if a < b then IEEEReal.LESS else if a == b then IEEEReal.EQUAL else IEEEReal.GREATER
  fun ?= (a, b) = unordered (a, b) orelse a == b

  fun class r =
    if isNan r then IEEEReal.NAN
    else if not (isFinite r) then IEEEReal.INF
    else if r == 0.0 then IEEEReal.ZERO
    else if abs r >= minNormalPos then IEEEReal.NORMAL
    else IEEEReal.SUBNORMAL

  (* x - n*y with n = trunc (x/y), exactly; NaN for an infinite x or a zero y, x for an infinite y *)
  val rem = _prim "real_rem" : real * real -> real
  fun *+ (a : real, b, c) = a * b + c
  fun *- (a : real, b, c) = a * b - c

  local
    val man = _prim "real_frexp_man" : real -> real
    val exp = _prim "real_frexp_exp" : real -> int
    val ldexp = _prim "real_ldexp" : real * int -> real
  in
    (* r = man * 2^exp with 0.5 <= |man| < 1 *)
    fun toManExp r = {man = man r, exp = exp r}
    fun fromManExp {man, exp} = ldexp (man, exp)
  end

  val realFloor = _prim "real_floor_r" : real -> real
  val realCeil = _prim "real_ceil_r" : real -> real
  val realTrunc = _prim "real_trunc_r" : real -> real
  val realRound = _prim "real_round_r" : real -> real

  (* whole and frac have the sign of r; an infinity has the fraction zero *)
  fun split r =
    if isNan r then {whole = r, frac = r}
    else
      let val whole = realTrunc r
      in {whole = whole, frac = copySign (if isFinite r then r - whole else 0.0, r)} end
  fun realMod r = #frac (split r)

  local val next = _prim "real_next_after" : real * real -> real
  in fun nextAfter (r, t) = if isFinite r orelse isNan r then next (r, t) else r end

  fun checkFloat r = if isNan r then raise Div else if isFinite r then r else raise Overflow

  val fromInt = real
  val floor = floor
  val ceil = ceil
  val round = round
  val trunc = trunc
  fun toInt IEEEReal.TO_NEGINF r = floor r
    | toInt IEEEReal.TO_POSINF r = ceil r
    | toInt IEEEReal.TO_ZERO r = trunc r
    | toInt IEEEReal.TO_NEAREST r = round r

  local
    val ldexp = _prim "real_ldexp" : real * int -> real
    val man = _prim "real_frexp_man" : real -> real
    val exp = _prim "real_frexp_exp" : real -> int
    val wordFromInt = _prim "word_from_int" : int -> word
    val two53 = 9007199254740992.0
    (* an integral real as an IntInf.int: 53 bits of mantissa, shifted. Nothing
       here needs an int of more than 56 bits. *)
    fun integral w =
      if abs w < two53 then IntInf.fromInt (trunc w)
      else
        let
          val a = abs w
          val bits = IntInf.fromInt (trunc (ldexp (man a, 53)))
          val i = IntInf.<< (bits, wordFromInt (Int.- (exp a, 53)))
        in if w < 0.0 then IntInf.~ i else i end
  in
    fun toLargeInt mode r =
      if isNan r then raise Domain
      else if not (isFinite r) then raise Overflow
      else
        integral (case mode of
                    IEEEReal.TO_NEGINF => realFloor r
                  | IEEEReal.TO_POSINF => realCeil r
                  | IEEEReal.TO_ZERO => realTrunc r
                  | IEEEReal.TO_NEAREST => realRound r)

    (* Correctly rounded: the 55 leading bits (53, a guard bit and one more),
       the lowest of them set when a lower bit is (a sticky bit), are converted
       and scaled. *)
    fun fromLargeInt (i : IntInf.int) =
      let
        val a = IntInf.abs i
        val k = if IntInf.sign a = 0 then 0 else IntInf.log2 a
      in
        (* below 2^55 the number is an int, whose conversion is correctly rounded *)
        if Int.< (k, 55) then fromInt (IntInf.toInt i)
        else
          let
            val shift = wordFromInt (Int.- (k, 54))
            val top = IntInf.~>> (a, shift)
            val top = if IntInf.compare (IntInf.<< (top, shift), a) = EQUAL then top
                      else IntInf.orb (top, IntInf.fromInt 1)
            val r = ldexp (fromInt (IntInf.toInt top), Int.- (k, 54))
          in if Int.< (IntInf.sign i, 0) then ~ r else r end
      end
  end

  (* LargeReal is Real *)
  val toLarge = fn (r : real) => r
  fun fromLarge (_ : IEEEReal.rounding_mode) (r : real) = r

  (* ---- conversion to and from text ---- *)
  local
    val fmtE = _prim "real_fmt_e" : real * int -> string
    val fmtF = _prim "real_fmt_f" : real * int -> string
    val shortest = _prim "real_shortest" : real -> string
    val parse = _prim "real_from_string" : string -> real option
    val intToString = _prim "int_to_string" : int -> string
    val charAt = _prim "string_sub" : string * int -> char

    (* < and its kin are those of real in this structure *)
    fun isDigit c = Int.<= (48, ord c) andalso Int.<= (ord c, 57)

    (* C's d.ddde[+-]xx: the digits of the mantissa and the exponent *)
    fun parseE (s : string) : char list * int =
      let
        fun go (c :: cs, ds) =
            if isDigit c then go (cs, c :: ds)
            else if c = #"e" then (rev ds, cs)
            else go (cs, ds)
          | go ([], ds) = (rev ds, [])
        val (ds, e) = go (explode s, [])
        val (negative, e) = case e of #"-" :: r => (true, r) | #"+" :: r => (false, r) | _ => (false, e)
        val v = List.foldl (fn (c, acc) => Int.+ (Int.* (acc, 10), Int.- (ord c, 48))) 0 e
      in (ds, if negative then Int.~ v else v) end

    fun stripZeros ds =
      let fun drop (#"0" :: r) = drop r | drop r = r
      in case rev (drop (rev ds)) of [] => [#"0"] | r => r end

    fun exponentText e = if Int.< (e, 0) then "~" ^ intToString (Int.~ e) else intToString e
    fun zeros n = if Int.<= (n, 0) then [] else #"0" :: zeros (Int.- (n, 1))
    fun take (ds, 0) = []
      | take ([], n) = #"0" :: take ([], Int.- (n, 1))
      | take (d :: ds, n) = d :: take (ds, Int.- (n, 1))
    fun drop (ds, 0) = ds
      | drop ([], _) = []
      | drop (_ :: ds, n) = drop (ds, Int.- (n, 1))

    fun special r = if isNan r then SOME "nan" else if r == posInf then SOME "inf" else if r == negInf then SOME "~inf" else NONE
    fun signed (r, body) = if signBit r then "~" ^ body else body

    fun sci n r =
      let val (ds, e) = parseE (fmtE (abs r, n))
      in
        signed (r, (case ds of
                      d :: [] => str d
                    | d :: rest => implode (d :: #"." :: rest)
                    | [] => "0") ^ "E" ^ exponentText e)
      end

    fun fix n r = signed (r, fmtF (abs r, n))

    (* the shorter of the two notations for at most n significant digits; a
       tie goes to the fixed-point one *)
    fun gen n r =
      let
        val (ds, e) = parseE (fmtE (abs r, Int.- (n, 1)))
        val ds = stripZeros ds
        val scientific =
          (case ds of
             d :: [] => str d
           | d :: rest => implode (d :: #"." :: rest)
           | [] => "0") ^ "E" ^ exponentText e
        val fixed =
          if Int.>= (e, 0) then
            let val whole = take (ds, Int.+ (e, 1))
                val frac = drop (ds, Int.+ (e, 1))
            in case frac of [] => implode whole | _ => implode (whole @ (#"." :: frac)) end
          else implode (#"0" :: #"." :: (zeros (Int.- (Int.~ e, 1)) @ ds))
      in signed (r, if Int.< (size scientific, size fixed) then scientific else fixed) end
  in
    fun toDecimal r : IEEEReal.decimal_approx =
      let val c = class r
      in
        case c of
          IEEEReal.NORMAL => normal (c, r)
        | IEEEReal.SUBNORMAL => normal (c, r)
        | _ => {class = c, sign = signBit r, digits = [], exp = 0}
      end
    and normal (c, r) =
      let val (ds, e) = parseE (shortest (abs r))
      in {class = c, sign = signBit r, digits = map (fn d => Int.- (ord d, 48)) (stripZeros ds), exp = Int.+ (e, 1)} end

    fun fromDecimal ({class, sign, digits, exp} : IEEEReal.decimal_approx) =
      if List.exists (fn d => Int.< (d, 0) orelse Int.> (d, 9)) digits then NONE
      else
        let
          val magnitude =
            case class of
              IEEEReal.ZERO => 0.0
            | IEEEReal.INF => posInf
            | IEEEReal.NAN => posInf - posInf
            | _ =>
                (case parse ("0." ^ implode (map (fn d => chr (Int.+ (48, d))) digits) ^ "0e" ^ intToString' exp) of
                   SOME v => v
                 | NONE => 0.0)
        in SOME (copySign (magnitude, if sign then ~1.0 else 1.0)) end
    and intToString' e = if Int.< (e, 0) then "-" ^ intToString (Int.~ e) else intToString e

    (* "The exception should be raised when fmt spec is evaluated." *)
    fun fmt spec =
      let
        fun finite f r = case special r of SOME s => s | NONE => f r
        fun precision (SOME n, least) = if Int.< (n, least) then raise Size else n
          | precision (NONE, _) = 6
      in
        case spec of
          StringCvt.SCI arg => let val n = precision (arg, 0) in finite (sci n) end
        | StringCvt.FIX arg => let val n = precision (arg, 0) in finite (fix n) end
        | StringCvt.GEN NONE => finite (gen 12)
        | StringCvt.GEN (SOME n) => if Int.< (n, 1) then raise Size else finite (gen n)
        (* "NaN values are converted to the string "nan"" in all cases, so without a sign *)
        | StringCvt.EXACT => (fn r => if isNan r then "nan" else IEEEReal.toString (toDecimal r))
      end

    fun toString r = fmt (StringCvt.GEN NONE) r

    (* The numeral is scanned by IEEEReal and handed to the C library as
       text, whatever its length, so the result is correctly rounded; too
       large a magnitude is an infinity, too small a zero. *)
    fun scan getc src =
      case IEEEReal.scanNumeral getc src of
        NONE => NONE
      | SOME ({sign, special = SOME name, ...}, rest) =>
          SOME (copySign (if name = "inf" then posInf else posInf - posInf, if sign then ~1.0 else 1.0), rest)
      | SOME ({sign, il, fl, exponent, ...}, rest) =>
          let
            fun text ds = implode (map (fn d => chr (Int.+ (48, d))) ds)
            val e = case exponent of
                      NONE => ""
                    | SOME (negative, ds) => "e" ^ (if negative then "-" else "") ^ text ds
            val magnitude = case parse (text il ^ "." ^ text fl ^ "0" ^ e) of SOME v => v | NONE => 0.0
          in SOME (copySign (magnitude, if sign then ~1.0 else 1.0), rest) end

    fun fromString s = StringCvt.scanString scan s
  end

  structure Math =
  struct
    type real = real
    val pi = 3.14159265358979323846
    val e = 2.71828182845904523536
    val sqrt = _prim "real_sqrt" : real -> real
    val sin = _prim "real_sin" : real -> real
    val cos = _prim "real_cos" : real -> real
    val tan = _prim "real_tan" : real -> real
    val atan = _prim "real_atan" : real -> real
    val atan2 = _prim "real_atan2" : real * real -> real
    val exp = _prim "real_exp" : real -> real
    val ln = _prim "real_ln" : real -> real
    (* C's pow is 1 for a base of 1 with a NaN exponent and for a base of +-1
       with an infinite one; the specification wants NaN. *)
    local val cpow = _prim "real_pow" : real * real -> real
    in
      fun pow (x, y) =
        if (x == 1.0 andalso isNan y) orelse (abs x == 1.0 andalso not (isNan y) andalso not (isFinite y))
        then posInf - posInf
        else cpow (x, y)
    end
    fun log10 r = ln r / ln 10.0
    fun asin r = atan2 (r, sqrt (1.0 - r * r))
    fun acos r = atan2 (sqrt (1.0 - r * r), r)
    val sinh = _prim "real_sinh" : real -> real
    val cosh = _prim "real_cosh" : real -> real
    val tanh = _prim "real_tanh" : real -> real
  end
end

structure Math = Real.Math
structure LargeReal = Real
structure Real64 = Real
