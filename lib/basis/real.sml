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
  val minPos = 4.9E~324
  val minNormalPos = 2.2250738585072014E~308

  fun isFinite r = not (isNan r) andalso r < posInf andalso r > negInf
  fun isNormal r = isFinite r andalso abs r >= minNormalPos
  fun sign r = if isNan r then raise Domain else if r < 0.0 then ~1 else if r > 0.0 then 1 else 0
  fun signBit r = r < 0.0 orelse (r == 0.0 andalso 1.0 / r < 0.0)
  fun sameSign (a, b) = signBit a = signBit b
  fun copySign (a, b) = if signBit a = signBit b then a else ~a

  fun min (a : real, b) = if isNan a then b else if isNan b then a else if a < b then a else b
  fun max (a : real, b) = if isNan a then b else if isNan b then a else if a > b then a else b
  fun compare (a : real, b) =
    if isNan a orelse isNan b then raise Unordered
    else if a < b then LESS else if a == b then EQUAL else GREATER

  val fromInt = real
  val floor = floor
  val ceil = ceil
  val round = round
  val trunc = trunc
  fun realFloor r = fromInt (floor r)
  fun realCeil r = fromInt (ceil r)
  fun realRound r = fromInt (round r)
  fun realTrunc r = fromInt (trunc r)
  fun toInt r = trunc r
  val toLarge = fn (r : real) => r
  val fromLarge = fn (r : real) => r

  val toString = _prim "real_to_string" : real -> string
  val fromString = _prim "real_from_string" : string -> real option

  fun checkFloat r =
    if isNan r then raise Domain else if isFinite r then r else raise Overflow

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
    val pow = _prim "real_pow" : real * real -> real
    fun log10 r = ln r / ln 10.0
    fun asin r = atan2 (r, sqrt (1.0 - r * r))
    fun acos r = atan2 (sqrt (1.0 - r * r), r)
    fun sinh r = (exp r - exp (~r)) / 2.0
    fun cosh r = (exp r + exp (~r)) / 2.0
    fun tanh r = sinh r / cosh r
  end
end

structure Math = Real.Math
