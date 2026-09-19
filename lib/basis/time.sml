(* Time: a length of time, held as microseconds. *)
structure Time =
struct
  type time = int                       (* microseconds *)
  exception Time

  val million = 1000000
  val zeroTime = 0

  local
    val now' = _prim "time_now" : unit -> int
  in
    fun now () = now' ()
  end

  (* "raises Time when the result is not representable". The conversions take
     and give LargeInt.int, as the specification prescribes. *)
  fun checked f = f () handle Overflow => raise Time
  fun ofLarge (x : LargeInt.int) = checked (fn () => IntInf.toInt x)
  fun toLarge (x : int) = IntInf.fromInt x
  fun fromSeconds s = checked (fn () => ofLarge s * million)
  fun fromMilliseconds s = checked (fn () => ofLarge s * 1000)
  fun fromMicroseconds s = ofLarge s
  fun fromNanoseconds s = ofLarge (IntInf.quot (s, IntInf.fromInt 1000))

  (* The parts are truncated towards zero. *)
  fun toSeconds t = toLarge (Int.quot (t, million))
  fun toMilliseconds t = toLarge (Int.quot (t, 1000))
  fun toMicroseconds t = toLarge t
  fun toNanoseconds t = IntInf.* (toLarge t, IntInf.fromInt 1000)

  fun fromReal r =
    if Real.isNan r orelse not (Real.isFinite r) then raise Time
    else checked (fn () => Real.toInt IEEEReal.TO_ZERO (r * 1000000.0))
  fun toReal t = Real.fromInt t / 1000000.0

  val op + = fn (a, b) => checked (fn () => Int.+ (a, b))
  val op - = fn (a, b) => checked (fn () => Int.- (a, b))
  val compare = Int.compare
  val op < = Int.<
  val op <= = Int.<=
  val op > = Int.>
  val op >= = Int.>=

  (* microseconds, for the parts of this library that work in them *)
  fun micros (t : time) = t
  fun ofMicros (n : int) : time = n

  (* "the number of seconds, a decimal point and n digits of the fraction",
     with 3 the default and no point when n is 0. The value is exact
     ("fixed-point semantics"): the digits after the sixth are zeros. The arithmetic is IntInf's, which neither the magnitude of the
     smallest int nor 10^n can overflow. *)
  fun fmt n t =
    if n < 0 then raise Size
    else
      let
        val ten = IntInf.fromInt 10
        val magnitude = IntInf.abs (IntInf.fromInt t)
        val kept = Int.min (n, 6)                  (* the digits a microsecond has *)
        val unit = IntInf.pow (ten, Int.- (6, kept))
        (* the last digit kept is rounded to nearest *)
        val scaled = IntInf.quot (IntInf.+ (magnitude, IntInf.quot (unit, IntInf.fromInt 2)), unit)
        val scale = IntInf.pow (ten, kept)
        val whole = IntInf.toString (IntInf.quot (scaled, scale))
        val zeros = String.implode (List.tabulate (Int.- (n, kept), fn _ => #"0"))
        val text =
          if n = 0 then whole
          else whole ^ "." ^ StringCvt.padLeft #"0" kept (IntInf.toString (IntInf.rem (scaled, scale))) ^ zeros
      in if Int.< (t, 0) andalso IntInf.> (scaled, IntInf.fromInt 0) then "~" ^ text else text end

  fun toString t = fmt 3 t

  (* [+~-]?(digits(.digits?)? | .digits) seconds. The number is read as an
     IntInf, so that any number of digits is read; the digits of the fraction
     after the sixth are dropped, and a number that is too large raises Time. *)
  fun scan getc src =
    let
      val src = StringCvt.skipWS getc src
      val (negative, src) =
        case getc src of
          SOME (#"~", rest) => (true, rest)
        | SOME (#"-", rest) => (true, rest)
        | SOME (#"+", rest) => (false, rest)
        | _ => (false, src)
      val ten = IntInf.fromInt 10
      (* digits (src, keep, acc, n): the number that acc and the digits at src
         make (only the first k of them for keep = SOME k), how many digits
         there are and what follows them *)
      fun digits (src, keep, acc, n) =
        case getc src of
          SOME (c, rest) =>
            if Char.isDigit c then
              digits (rest, keep,
                      case keep of
                        SOME k => if Int.< (n, k) then IntInf.+ (IntInf.* (acc, ten), IntInf.fromInt (Int.- (ord c, 48))) else acc
                      | NONE => IntInf.+ (IntInf.* (acc, ten), IntInf.fromInt (Int.- (ord c, 48))),
                      Int.+ (n, 1))
            else (acc, n, src)
        | NONE => (acc, n, src)
      val zero = IntInf.fromInt 0
      val (whole, wholeDigits, afterWhole) = digits (src, NONE, zero, 0)
      (* the fraction in microseconds *)
      val (fraction, fractionDigits, rest) =
        case getc afterWhole of
          SOME (#".", afterPoint) =>
            let val (f, n, after) = digits (afterPoint, SOME 6, zero, 0)
            in
              if n = 0 then (zero, 0, afterWhole)
              else (IntInf.* (f, IntInf.pow (ten, Int.- (6, Int.min (n, 6)))), n, after)
            end
        | _ => (zero, 0, afterWhole)
    in
      if wholeDigits = 0 andalso fractionDigits = 0 then NONE
      else
        let
          val total = IntInf.+ (IntInf.* (whole, IntInf.fromInt million), fraction)
        in SOME (checked (fn () => IntInf.toInt (if negative then IntInf.~ total else total)), rest) end
    end

  fun fromString s = StringCvt.scanString scan s
end
