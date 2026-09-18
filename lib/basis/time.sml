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
  fun toNanoseconds t = toLarge (checked (fn () => t * 1000))

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

  (* "the number of seconds, a decimal point and n digits of the fraction",
     with 3 the default and no point when n is 0. *)
  (* microseconds, for the parts of this library that work in them *)
  fun micros (t : time) = t
  fun ofMicros (n : int) : time = n

  fun fmt n t =
    if n < 0 then raise Size
    else
      let
        val negative = Int.< (t, 0)
        val whole = Int.quot (Int.abs t, million)
        val fraction = Int.rem (Int.abs t, million)
        fun digits (k, f, acc) =
          if k = 0 then String.implode (List.rev acc)
          else
            let val f = Int.* (f, 10)
            in digits (Int.- (k, 1), Int.rem (f, million), chr (Int.+ (48, Int.quot (f, million))) :: acc) end
        (* the last digit kept is rounded to nearest *)
        fun rounded () =
          let
            val scale = List.foldl (fn (_, p) => Int.* (p, 10)) 1 (List.tabulate (n, fn i => i))
            val scaled = Int.quot (Int.+ (Int.* (fraction, scale), Int.quot (million, 2)), million)
          in
            if Int.>= (scaled, scale) then (Int.+ (whole, 1), 0) else (whole, scaled)
          end
        val (whole, scaled) = rounded ()
        val text =
          if n = 0 then Int.toString whole
          else
            Int.toString whole ^ "." ^
            StringCvt.padLeft #"0" n (Int.toString scaled)
      in if negative andalso (Int.> (whole, 0) orelse Int.> (scaled, 0)) then "~" ^ text else text end

  fun toString t = fmt 3 t

  (* [+~-]?(digits(.digits?)? | .digits) seconds *)
  fun scan getc src =
    let
      val src = StringCvt.skipWS getc src
      val (negative, src) =
        case getc src of
          SOME (#"~", rest) => (true, rest)
        | SOME (#"-", rest) => (true, rest)
        | SOME (#"+", rest) => (false, rest)
        | _ => (false, src)
      fun digits (src, acc, n) =
        case getc src of
          SOME (c, rest) =>
            if Char.isDigit c then digits (rest, Int.+ (Int.* (acc, 10), Int.- (ord c, 48)), Int.+ (n, 1))
            else (acc, n, src)
        | NONE => (acc, n, src)
      val (whole, wholeDigits, src) = digits (src, 0, 0)
      val (fraction, src) =
        case getc src of
          SOME (#".", rest) =>
            let val (f, n, after) = digits (rest, 0, 0)
            in
              if n = 0 then (0, src)
              else
                let
                  fun scale (f, n) =
                    if Int.>= (n, 6) then Int.quot (f, List.foldl (fn (_, p) => Int.* (p, 10)) 1 (List.tabulate (Int.- (n, 6), fn i => i)))
                    else Int.* (f, List.foldl (fn (_, p) => Int.* (p, 10)) 1 (List.tabulate (Int.- (6, n), fn i => i)))
                in (scale (f, n), after) end
            end
        | _ => (0, src)
    in
      if wholeDigits = 0 andalso fraction = 0 andalso
         (case getc src of SOME (#".", _) => true | _ => false) then NONE
      else if wholeDigits = 0 andalso fraction = 0 then NONE
      else
        let val t = checked (fn () => Int.+ (Int.* (whole, million), fraction))
        in SOME (if negative then Int.~ t else t, src) end
    end

  fun fromString s = StringCvt.scanString scan s
end
