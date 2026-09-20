(* Real32: IEEE 754 binary32. A value is kept as a real (binary64) that
   binary32 represents, and an operation rounds its result to binary32 (the
   primitive real_to_single, in the current rounding mode). For +, -, *, / and
   sqrt that is the correctly rounded binary32 result: binary64 has more than
   twice the precision of binary32, plus two bits. Numerals are read to
   binary32 at once (real_single_from_string, C's strtof), and the constants
   of type Real32.real are read from their text where they are evaluated
   (RuneReal32Lit.fromLit). *)
structure RuneReal32 =
struct
  local
    val single = _prim "real_to_single" : real -> real
    val parse = _prim "real_single_from_string" : string -> real option
    val fmtE = _prim "real_fmt_e" : real * int -> string
    val intToString = _prim "int_to_string" : int -> string
  in
    type real = real
    val radix = 2
    val precision = 24
    (* computed: Poly/ML 5.9.2 reads the constant 1.1754943508222875E~38 as 2^~127 *)
    val maxFinite = Real.fromManExp {man = Real.- (1.0, Real.fromManExp {man = 1.0, exp = ~24}), exp = 128}
    val minNormalPos = Real.fromManExp {man = 1.0, exp = ~126}
    val minPos = Real.fromManExp {man = 1.0, exp = ~149}
    val posInf = Real.posInf
    val negInf = Real.negInf

    (* exact on binary32 values *)
    val ~ = Real.~
    val abs = Real.abs
    val isNan = Real.isNan
    val isFinite = Real.isFinite
    fun isNormal r = Real.isFinite r andalso Real.>= (Real.abs r, minNormalPos)
    fun class r =
      if Real.isNan r then IEEEReal.NAN
      else if not (Real.isFinite r) then IEEEReal.INF
      else if Real.== (r, 0.0) then IEEEReal.ZERO
      else if Real.>= (Real.abs r, minNormalPos) then IEEEReal.NORMAL
      else IEEEReal.SUBNORMAL
    val sign = Real.sign
    val signBit = Real.signBit
    val sameSign = Real.sameSign
    val copySign = Real.copySign
    val min = Real.min
    val max = Real.max
    val unordered = Real.unordered
    val compare = Real.compare
    val compareReal = Real.compareReal
    val ?= = Real.?=
    val rem = Real.rem                   (* x - n*y is a binary32 value *)
    val toManExp = Real.toManExp
    val split = Real.split
    val realMod = Real.realMod
    val checkFloat = Real.checkFloat
    val realFloor = Real.realFloor
    val realCeil = Real.realCeil
    val realTrunc = Real.realTrunc
    val realRound = Real.realRound
    val floor = Real.floor
    val ceil = Real.ceil
    val trunc = Real.trunc
    val round = Real.round
    val toInt = Real.toInt
    val toLargeInt = Real.toLargeInt
    fun toLarge (r : real) : Real.real = r

    (* rounded to binary32 *)
    fun *+ (a, b, c) = single (Real.+ (Real.* (a, b), c))   (* a * b is exact *)
    fun *- (a, b, c) = single (Real.- (Real.* (a, b), c))
    fun fromManExp me = single (Real.fromManExp me)
    fun fromLarge mode r =
      let val saved = IEEEReal.getRoundingMode ()
      in IEEEReal.setRoundingMode mode; single r before IEEEReal.setRoundingMode saved end

    (* Correctly rounded: the 26 leading bits (24, a guard bit and one more),
       the lowest of them set when a lower bit is (a sticky bit), are exact in
       binary64 and rounded once. *)
    fun fromLargeInt (i : IntInf.int) =
      let
        val a = IntInf.abs i
        val k = if IntInf.sign a = 0 then 0 else IntInf.log2 a
      in
        if Int.< (k, 53) then single (Real.fromLargeInt i)   (* exact *)
        else
          let
            val shift = Word.fromInt (Int.- (k, 25))
            val top = IntInf.~>> (a, shift)
            val top = if IntInf.compare (IntInf.<< (top, shift), a) = EQUAL then top
                      else IntInf.orb (top, IntInf.fromInt 1)
            val r = Real.fromManExp {man = Real.fromInt (IntInf.toInt top), exp = Int.- (k, 25)}
          in single (if Int.< (IntInf.sign i, 0) then Real.~ r else r) end
      end
    (* exact in binary64 below 2^53 (compared as a real: a host's int may
       have 31 bits) *)
    fun fromInt i =
      let val r = Real.fromInt i
      in if Real.< (Real.abs r, 9007199254740992.0) then single r else fromLargeInt (Int.toLarge i) end

    (* The next binary32 value: away from zero the spacing at r, toward zero
       half of it at a power of two (above the subnormals). "If r = t then it
       returns r", so ~0.0 for nextAfter (~0.0, 0.0), as Real.nextAfter. *)
    fun nextAfter (r, t) =
      if Real.isNan r orelse Real.isNan t then Real.+ (r, t)
      else if not (Real.isFinite r) orelse Real.== (r, t) then r
      else if Real.== (r, 0.0) then (if Real.< (t, r) then Real.~ minPos else minPos)
      else
        let
          fun spacing e = Real.fromManExp {man = 1.0, exp = if Int.< (e, ~125) then ~149 else Int.- (e, 24)}
          val a = Real.abs r
          val {man, exp} = Real.toManExp a
          val next =
            if Real.> (t, r) = Real.> (r, 0.0) then Real.+ (a, spacing exp)
            else Real.- (a, if Real.== (man, 0.5) then spacing (Int.- (exp, 1)) else spacing exp)
          val next = if Real.> (next, maxFinite) then posInf else next
        in Real.copySign (next, r) end

    (* ---- conversion to and from text: the value is a binary64, so fmt is
       Real.fmt but for EXACT, whose digits are the fewest that read back as
       the same binary32 value ---- *)
    fun toDecimal r : IEEEReal.decimal_approx =
      let
        val c = class r
        fun digits a =
          let
            fun go k =
              let val s = fmtE (a, k)
                  val same = case parse s of SOME b => Real.== (a, b) | NONE => false
              in if Int.>= (k, 9) orelse same then s else go (Int.+ (k, 1)) end
          in
            case IEEEReal.fromString (go 0) of
              SOME {digits, exp, ...} => {class = c, sign = Real.signBit r, digits = digits, exp = exp}
            | NONE => {class = c, sign = Real.signBit r, digits = [], exp = 0}
          end
      in
        case c of
          IEEEReal.NORMAL => digits (Real.abs r)
        | IEEEReal.SUBNORMAL => digits (Real.abs r)
        | _ => {class = c, sign = Real.signBit r, digits = [], exp = 0}
      end

    fun fromDecimal ({class, sign, digits, exp} : IEEEReal.decimal_approx) =
      if List.exists (fn d => Int.< (d, 0) orelse Int.> (d, 9)) digits then NONE
      else
        let
          fun signed r = Real.copySign (r, if sign then ~1.0 else 1.0)
          fun text ds = String.implode (List.map (fn d => Char.chr (Int.+ (48, d))) ds)
          fun exponent e = if Int.< (e, 0) then "-" ^ intToString (Int.~ e) else intToString e
        in
          SOME (case class of
                  IEEEReal.ZERO => signed 0.0
                | IEEEReal.INF => signed posInf
                | IEEEReal.NAN => signed (Real.- (posInf, posInf))
                | _ =>
                    (* the sign goes to strtof, which rounds with it *)
                    case parse ((if sign then "-" else "") ^ "0." ^ text digits ^ "0e" ^ exponent exp) of
                      SOME v => v
                    | NONE => signed 0.0)
        end

    (* "The exception should be raised when fmt spec is evaluated." *)
    fun fmt StringCvt.EXACT = (fn r => if Real.isNan r then "nan" else IEEEReal.toString (toDecimal r))
      | fmt spec = Real.fmt spec

    fun toString r = Real.fmt (StringCvt.GEN NONE) r

    (* The numeral is scanned by IEEEReal and handed to strtof as text, with
       its sign, so that it is rounded once, in the current rounding mode. *)
    fun scan getc src =
      case IEEEReal.scanNumeral getc src of
        NONE => NONE
      | SOME ({sign, special = SOME name, ...}, rest) =>
          SOME (Real.copySign (if name = "inf" then posInf else Real.- (posInf, posInf), if sign then ~1.0 else 1.0),
                rest)
      | SOME ({sign, il, fl, exponent, ...}, rest) =>
          let
            fun text ds = String.implode (List.map (fn d => Char.chr (Int.+ (48, d))) ds)
            val e = case exponent of
                      NONE => ""
                    | SOME (negative, ds) => "e" ^ (if negative then "-" else "") ^ text ds
            val numeral = (if sign then "-" else "") ^ text il ^ "." ^ text fl ^ "0" ^ e
          in SOME (case parse numeral of SOME v => v | NONE => Real.copySign (0.0, if sign then ~1.0 else 1.0), rest) end

    fun fromString s = StringCvt.scanString scan s

    (* last: they hide the operators on int within the structure *)
    fun a + b = single (Real.+ (a, b))
    fun a - b = single (Real.- (a, b))
    fun a * b = single (Real.* (a, b))
    fun a / b = single (Real./ (a, b))
    val op < = Real.<
    val op <= = Real.<=
    val op > = Real.>
    val op >= = Real.>=
    val == = Real.==
    fun != (a, b) = not (Real.== (a, b))

    structure Math =
    struct
      type real = real
      val pi = single Math.pi
      val e = single Math.e
      fun sqrt x = single (Math.sqrt x)
      fun sin x = single (Math.sin x)
      fun cos x = single (Math.cos x)
      fun tan x = single (Math.tan x)
      fun asin x = single (Math.asin x)
      fun acos x = single (Math.acos x)
      fun atan x = single (Math.atan x)
      fun atan2 (y, x) = single (Math.atan2 (y, x))
      fun exp x = single (Math.exp x)
      fun pow (x, y) = single (Math.pow (x, y))
      fun ln x = single (Math.ln x)
      fun log10 x = single (Math.log10 x)
      fun sinh x = single (Math.sinh x)
      fun cosh x = single (Math.cosh x)
      fun tanh x = single (Math.tanh x)
    end
  end
end

(* Implements: REAL

   Status: optional *)
structure Real32 :> REAL = RuneReal32

structure RuneReal32Lit =
struct
  fun fromLit s = case Real32.fromString s of SOME r => r | NONE => raise Fail ("Real32 constant " ^ s)
end

_overload real Real32 via RuneReal32Lit.fromLit
