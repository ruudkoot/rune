(* requires: Time LargeInt StringCvt Substring *)
(* The Time structure (signature TIME). Expected values follow the text of
   https://smlfamily.github.io/Basis/time.html.

   The page leaves the resolution of time and the range of representable
   times to the implementation ("Depending on the resolution of time,
   fractions of a microsecond may be lost"; Time is raised "when the result
   ... is not representable"). So the checks use times that every resolution
   of a microsecond or finer holds exactly; a conversion that may lose a
   fraction of a microsecond is checked to within a microsecond; and where a
   time may be too large for an implementation, the check wants the exact
   result or the exception Time, never another exception or a wrong value.
   The reference point zeroTime is not specified either ("Date.fromTimeLocal
   can be used to see what time zeroTime actually represents"), so that now
   is only compared with other readings of the clock and with zeroTime. *)
structure TestTime =
struct
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val showL = LargeInt.toString
  fun showL2 (a, b) = showL a ^ ", " ^ showL b

  (* LargeInt.int has no constants and no overloaded operators on a host that
     compiles lib/basis (xc1), where it is the IntInf of lib/basis: numbers
     are made with large (of an int) and big (of decimal digits, for those
     that do not fit a 31-bit int), and computed with the functions of
     LargeInt. Expected values are written as decimal digits and made inside
     the check. *)
  val large = LargeInt.fromInt
  fun big (digits : string) : LargeInt.int = valOf (LargeInt.fromString digits)
  fun bigOpt (e : string option) = Option.map big e
  fun eqv show (label, expected : unit -> ''a, f : unit -> ''a) =
    case (SOME (expected ()) handle _ => NONE) of
      SOME e => T.eq show (label, e, f)
    | NONE => T.fail (label, "the expected value raised an exception")
  fun eqL (label, expected : string, f : unit -> LargeInt.int) = eqv showL (label, fn () => big expected, f)
  (* The expected times are given in nanoseconds, which every resolution
     converts exactly, so that the times are computed inside the check like
     everything else. *)
  val ns = Time.toNanoseconds
  fun eqN (label, expected : string, f : unit -> Time.time) = eqL (label, expected, fn () => ns (f ()))
  fun eqNO (label, expected : string option, f : unit -> Time.time option) =
    eqv (T.option showL) (label, fn () => bigOpt expected, fn () => Option.map ns (f ()))
  fun eqScan (label, expected : (string * ''r) option, showRest : ''r -> string,
              f : unit -> (Time.time * ''r) option) =
    eqv (T.option (T.pair (showL, showRest)))
        (label, fn () => Option.map (fn (e, r) => (big e, r)) expected,
         fn () => Option.map (fn (t, r) => (ns t, r)) (f ()))

  (* times of an int number of units, and of a LargeInt one *)
  fun sec (n : int) = Time.fromSeconds (large n)
  fun ms (n : int) = Time.fromMilliseconds (large n)
  fun us (n : int) = Time.fromMicroseconds (large n)
  fun secL (n : LargeInt.int) = Time.fromSeconds n
  fun msL (n : LargeInt.int) = Time.fromMilliseconds n
  fun usL (n : LargeInt.int) = Time.fromMicroseconds n
  val isTime = fn Time.Time => true | _ => false

  fun pow10 (k : int) : LargeInt.int = if k <= 0 then large 1 else LargeInt.* (large 10, pow10 (k - 1))
  fun digits (n, c) = String.implode (List.tabulate (n, fn _ => c))
  fun absL (n : LargeInt.int) = if LargeInt.< (n, large 0) then LargeInt.~ n else n

  (* law (label, n, sample, holds, show): holds x for n pseudo-random samples
     x = sample (); the first counterexample is reported. *)
  fun law (label, n, sample : unit -> 'a, holds : 'a -> bool, show : 'a -> string) : unit =
    let
      fun go i =
        if i >= n then NONE
        else let val x = sample () in if (holds x handle _ => false) then go (i + 1) else SOME x end
    in
      case (SOME (go 0) handle _ => NONE) of
        SOME NONE => T.pass label
      | SOME (SOME x) => T.fail (label, "fails for " ^ show x)
      | NONE => T.fail (label, "raised an exception")
    end
  (* a pseudo-random number of microseconds, up to 10^14 (three years) either way *)
  fun randomMicros () : LargeInt.int =
    LargeInt.+ (LargeInt.* (large (T.range (~100000000, 100000000)), large 1000000), large (T.range (0, 999999)))
  fun randomMicros2 () = (randomMicros (), randomMicros ())

  (* exactOrTime (label, f): f () is true, or f raises Time because a time is
     not representable in the implementation *)
  fun exactOrTime (label, f : unit -> bool) = T.check (label, fn () => f () handle Time.Time => true)
  (* representable f: SOME (f ()), or NONE when f raises Time *)
  fun representable (f : unit -> Time.time) = SOME (f ()) handle Time.Time => NONE

  val () = T.seed 1997

  (* ---- exception Time: "raised when the result of conversions to time or
     of operations over time is not representable, or when an illegal
     operation has been attempted" ---- *)
  val () = eqB ("Time.Time/raise-and-handle", true, fn () => (raise Time.Time) handle Time.Time => true)
  val () = eqB ("Time.Time/is-its-own-exception", true,
                fn () => (raise Time.Time) handle Overflow => false | Domain => false | Time.Time => true)
  val () = T.raises ("Time.Time/fromReal-posInf", isTime, fn () => Time.fromReal Real.posInf)

  (* ---- zeroTime: "equivalent to fromReal(0.0)" ---- *)
  val () = eqB ("Time.zeroTime/is-fromReal-0.0", true, fn () => Time.zeroTime = Time.fromReal 0.0)
  val () = eqB ("Time.zeroTime/is-zero-seconds", true, fn () => Time.zeroTime = sec 0 andalso Time.zeroTime = us 0)
  val () = eqL ("Time.zeroTime/toNanoseconds", "0", fn () => Time.toNanoseconds Time.zeroTime)
  val () = law ("Time.zeroTime/identity-of-+", 50, randomMicros,
                fn n => Time.+ (usL n, Time.zeroTime) = usL n andalso Time.+ (Time.zeroTime, usL n) = usL n, showL)

  (* ---- fromReal r: "the time value denoting r seconds ... fractions of a
     microsecond may be lost. It raises Time when the result is not
     representable." ---- *)
  val () = eqN ("Time.fromReal/one-and-a-half", "1500000000", fn () => Time.fromReal 1.5)
  val () = eqN ("Time.fromReal/binary-fraction", "15625000", fn () => Time.fromReal 0.015625)
  val () = eqN ("Time.fromReal/negative", "~2750000000", fn () => Time.fromReal ~2.75)
  val () = eqN ("Time.fromReal/negative-zero", "0", fn () => Time.fromReal ~0.0)
  val () = eqN ("Time.fromReal/whole-seconds", "1000000000000000000", fn () => Time.fromReal 1.0E9)
  val () = eqN ("Time.fromReal/spec-example-1.8", "1800000000", fn () => Time.fromReal 1.8)
  val () = eqL ("Time.fromReal/fraction-of-a-microsecond-lost", "0", fn () => Time.toMicroseconds (Time.fromReal 1.0E~7))
  val () = eqL ("Time.fromReal/milliseconds", "123", fn () => Time.toMilliseconds (Time.fromReal 0.1234))
  val () = T.raises ("Time.fromReal/posInf", isTime, fn () => Time.fromReal Real.posInf)
  val () = T.raises ("Time.fromReal/negInf", isTime, fn () => Time.fromReal Real.negInf)
  val () = T.raises ("Time.fromReal/nan", isTime, fn () => Time.fromReal (0.0 / 0.0))
  val () = exactOrTime ("Time.fromReal/huge-approximately-or-Time",
                        fn () => Real.abs (Time.toReal (Time.fromReal 1.0E30) / 1.0E30 - 1.0) < 1.0E~9)
  val () = exactOrTime ("Time.fromReal/huge-negative-approximately-or-Time",
                        fn () => Real.abs (Time.toReal (Time.fromReal ~1.0E30) / ~1.0E30 - 1.0) < 1.0E~9)
  val () = law ("Time.fromReal/binary-fractions-exactly", 200, fn () => T.range (~500000000, 500000000),
                fn k => Time.fromReal (real k / 64.0) = usL (LargeInt.* (large k, large 15625)), Int.toString)

  (* ---- toReal t: "a real number denoting the value of t in seconds" ---- *)
  val () = T.eqReal ("Time.toReal/milliseconds", 1.5, fn () => Time.toReal (ms 1500))
  val () = T.eqReal ("Time.toReal/negative", ~0.25, fn () => Time.toReal (ms ~250))
  val () = T.eqReal ("Time.toReal/zeroTime", 0.0, fn () => Time.toReal Time.zeroTime)
  val () = T.eqReal ("Time.toReal/whole-seconds", 1.0E9, fn () => Time.toReal (sec 1000000000))
  val () = T.approx ("Time.toReal/microsecond", 1.0E~6, fn () => Time.toReal (us 1))
  val () = law ("Time.toReal/binary-fractions-exactly", 200, fn () => T.range (~500000000, 500000000),
                fn k => Real.== (Time.toReal (usL (LargeInt.* (large k, large 15625))), real k / 64.0), Int.toString)
  val () = law ("Time.toReal/random-approximately", 200, randomMicros,
                fn n => let val expected = Real.fromLargeInt n / 1.0E6
                        in Real.abs (Time.toReal (usL n) - expected) <= 1.0E~12 * Real.max (1.0, Real.abs expected) end,
                showL)

  (* ---- round trips ---- *)
  val () = law ("Time.fromReal/toReal-round-trip-within-a-microsecond", 200, randomMicros,
                fn n => LargeInt.<= (absL (LargeInt.- (Time.toMicroseconds (Time.fromReal (Time.toReal (usL n))), n)), large 1), showL)
  val () = law ("Time.toReal/fromReal-round-trip-within-a-microsecond", 200,
                fn () => real (T.range (~100000000, 100000000)) + real (T.range (0, 999999999)) / 1.0E9,
                fn r => Real.abs (Time.toReal (Time.fromReal r) - r) <= 1.01E~6, Real.toString)

  (* ---- toSeconds ... toNanoseconds: "the number of full seconds
     (respectively, milliseconds, microseconds, or nanoseconds) in t;
     fractions of the time unit are dropped, i.e., the values are rounded
     towards 0. Thus, if t denotes 2.01 seconds, the functions return 2,
     2010, 2010000, and 2010000000 respectively." ---- *)
  val () = eqL ("Time.toSeconds/spec-example-2.01", "2", fn () => Time.toSeconds (ms 2010))
  val () = eqL ("Time.toMilliseconds/spec-example-2.01", "2010", fn () => Time.toMilliseconds (ms 2010))
  val () = eqL ("Time.toMicroseconds/spec-example-2.01", "2010000", fn () => Time.toMicroseconds (ms 2010))
  val () = eqL ("Time.toNanoseconds/spec-example-2.01", "2010000000", fn () => Time.toNanoseconds (ms 2010))
  val () = eqL ("Time.toSeconds/negative-towards-zero", "~2", fn () => Time.toSeconds (ms ~2010))
  val () = eqL ("Time.toMilliseconds/negative", "~2010", fn () => Time.toMilliseconds (ms ~2010))
  val () = eqL ("Time.toMicroseconds/negative", "~2010000", fn () => Time.toMicroseconds (ms ~2010))
  val () = eqL ("Time.toNanoseconds/negative", "~2010000000", fn () => Time.toNanoseconds (ms ~2010))
  val () = eqL ("Time.toSeconds/rounds-towards-zero", "1", fn () => Time.toSeconds (us 1999999))
  val () = eqL ("Time.toSeconds/rounds-negative-towards-zero", "~1", fn () => Time.toSeconds (us ~1999999))
  val () = eqL ("Time.toSeconds/less-than-a-second", "0", fn () => Time.toSeconds (ms ~999))
  val () = eqL ("Time.toMilliseconds/rounds-towards-zero", "1999", fn () => Time.toMilliseconds (us 1999999))
  val () = eqL ("Time.toMilliseconds/rounds-negative-towards-zero", "~1", fn () => Time.toMilliseconds (us ~1500))
  val () = eqL ("Time.toMicroseconds/exact", "1234567", fn () => Time.toMicroseconds (us 1234567))
  val () = eqL ("Time.toNanoseconds/microsecond", "1000", fn () => Time.toNanoseconds (us 1))
  (* A time beyond 2^63 nanoseconds: LargeInt.int holds the result, or, when
     it has a precision, may raise Overflow ("When the result is not
     representable by LargeInt.int, the exception Overflow is raised"). *)
  fun ofBigTime (f : Time.time -> LargeInt.int, expected) () =
    case representable (fn () => secL (pow10 12)) of
      NONE => true
    | SOME t => (f t = expected) handle Overflow => isSome LargeInt.precision
  val () = T.check ("Time.toNanoseconds/beyond-64-bits", ofBigTime (Time.toNanoseconds, pow10 21))
  val () = T.check ("Time.toMicroseconds/large", ofBigTime (Time.toMicroseconds, pow10 18))
  val () = T.check ("Time.toMilliseconds/large", ofBigTime (Time.toMilliseconds, pow10 15))
  val () = T.check ("Time.toSeconds/large", ofBigTime (Time.toSeconds, pow10 12))
  val () = law ("Time.toSeconds/is-toMicroseconds-quot", 200, randomMicros,
                fn n => Time.toSeconds (usL n) = LargeInt.quot (n, large 1000000)
                        andalso Time.toMilliseconds (usL n) = LargeInt.quot (n, large 1000), showL)

  (* ---- fromSeconds ... fromNanoseconds: "a time value denoting n seconds
     (respectively, milliseconds, microseconds, or nanoseconds). If the
     result is not representable by the time type, then the exception Time
     is raised." ---- *)
  val () = eqL ("Time.fromSeconds/basic", "3000", fn () => Time.toMilliseconds (sec 3))
  val () = eqN ("Time.fromSeconds/negative", "~3000000000", fn () => sec ~3)
  val () = eqL ("Time.fromMilliseconds/basic", "1000", fn () => Time.toMicroseconds (ms 1))
  val () = eqN ("Time.fromMilliseconds/negative", "~7000000", fn () => ms ~7)
  val () = eqL ("Time.fromMicroseconds/basic", "1000", fn () => Time.toNanoseconds (us 1))
  val () = eqN ("Time.fromMicroseconds/negative", "~2000000", fn () => us ~2000)
  val () = eqB ("Time.fromNanoseconds/basic", true, fn () => Time.fromNanoseconds (big "2010000000") = ms 2010)
  val () = eqB ("Time.fromNanoseconds/negative", true, fn () => Time.fromNanoseconds (large ~5000) = us ~5)
  val () = eqL ("Time.fromNanoseconds/less-than-a-microsecond", "0", fn () => Time.toMicroseconds (Time.fromNanoseconds (large 999)))
  val () = law ("Time.fromSeconds/agrees-with-finer-units", 200, fn () => large (T.range (~100000000, 100000000)),
                fn n => secL n = msL (LargeInt.* (n, large 1000)) andalso secL n = usL (LargeInt.* (n, large 1000000))
                        andalso secL n = Time.fromNanoseconds (LargeInt.* (n, large 1000000000)), showL)
  val () = law ("Time.fromMilliseconds/toMilliseconds-inverts", 200,
                fn () => LargeInt.+ (LargeInt.* (large (T.range (~100000000, 100000000)), large 1000), large (T.range (0, 999))),
                fn n => Time.toMilliseconds (msL n) = n, showL)
  val () = law ("Time.fromMicroseconds/toMicroseconds-inverts", 200, randomMicros,
                fn n => Time.toMicroseconds (usL n) = n, showL)
  val () = law ("Time.fromNanoseconds/toNanoseconds-inverts", 200, randomMicros,
                fn n => let val m = LargeInt.* (n, large 1000) in Time.toNanoseconds (Time.fromNanoseconds m) = m end, showL)
  (* 10^40 of any unit: the exact time, or Time *)
  val () = exactOrTime ("Time.fromSeconds/huge-exact-or-Time", fn () => Time.toSeconds (secL (pow10 40)) = pow10 40)
  val () = exactOrTime ("Time.fromSeconds/huge-negative-exact-or-Time",
                        fn () => Time.toSeconds (secL (LargeInt.~ (pow10 40))) = LargeInt.~ (pow10 40))
  val () = exactOrTime ("Time.fromSeconds/beyond-64-bit-microseconds-exact-or-Time",
                        fn () => Time.toSeconds (secL (pow10 16)) = pow10 16)
  val () = exactOrTime ("Time.fromMilliseconds/huge-exact-or-Time",
                        fn () => Time.toMilliseconds (msL (pow10 40)) = pow10 40)
  val () = exactOrTime ("Time.fromMicroseconds/huge-exact-or-Time",
                        fn () => Time.toMicroseconds (usL (pow10 40)) = pow10 40)
  val () = exactOrTime ("Time.fromNanoseconds/huge-exact-or-Time",
                        fn () => Time.toNanoseconds (Time.fromNanoseconds (pow10 40)) = pow10 40)
  val () = exactOrTime ("Time.fromNanoseconds/huge-negative-exact-or-Time",
                        fn () => Time.toNanoseconds (Time.fromNanoseconds (LargeInt.~ (pow10 40))) = LargeInt.~ (pow10 40))

  (* ---- + and -: "When the result is not representable as a time value, the
     exception Time is raised. This operation is commutative." ---- *)
  val () = eqN ("Time.+/basic", "4000000000", fn () => Time.+ (ms 1500, ms 2500))
  val () = eqN ("Time.+/negative", "~2000000000", fn () => Time.+ (sec 1, sec ~3))
  val () = eqN ("Time.+/microseconds", "1000001000", fn () => Time.+ (sec 1, us 1))
  val () = law ("Time.+/commutative", 200, randomMicros2,
                fn (a, b) => Time.+ (usL a, usL b) = Time.+ (usL b, usL a), showL2)
  val () = law ("Time.+/adds-microseconds", 200, randomMicros2,
                fn (a, b) => Time.toMicroseconds (Time.+ (usL a, usL b)) = LargeInt.+ (a, b), showL2)
  val () = law ("Time.+/associative", 200, fn () => (randomMicros (), randomMicros2 ()),
                fn (a, (b, c)) => Time.+ (usL a, Time.+ (usL b, usL c)) = Time.+ (Time.+ (usL a, usL b), usL c),
                fn (a, (b, c)) => showL a ^ ", " ^ showL2 (b, c))
  val () = eqN ("Time.-/basic", "500000000", fn () => Time.- (sec 2, ms 1500))
  val () = eqN ("Time.-/negative-interval", "~2000000000", fn () => Time.- (sec 1, sec 3))
  val () = eqN ("Time.-/self-is-zeroTime", "0", fn () => Time.- (ms 1234, ms 1234))
  val () = law ("Time.-/inverts-+", 200, randomMicros2,
                fn (a, b) => Time.- (Time.+ (usL a, usL b), usL b) = usL a, showL2)
  val () = law ("Time.-/subtracts-microseconds", 200, randomMicros2,
                fn (a, b) => Time.toMicroseconds (Time.- (usL a, usL b)) = LargeInt.- (a, b), showL2)
  (* doubling (double, t, n): n applications of double to t keep doubling the
     number of seconds exactly, until one raises Time *)
  fun doubling (double : Time.time -> Time.time, t : Time.time, n : int) : bool =
    let
      fun go (t, s : LargeInt.int, k) =
        k >= n orelse
        (case representable (fn () => double t) of
           NONE => true
         | SOME t' => let val s2 = LargeInt.* (large 2, s) in Time.toSeconds t' = s2 andalso go (t', s2, k + 1) end)
    in go (t, Time.toSeconds t, 0) end
  val () = eqB ("Time.+/Time-when-not-representable", true,
                fn () => doubling (fn t => Time.+ (t, t), sec 1, 300))
  val () = eqB ("Time.+/Time-when-not-representable-negative", true,
                fn () => doubling (fn t => Time.+ (t, t), sec ~1, 300))
  val () = eqB ("Time.-/Time-when-not-representable", true,
                fn () => doubling (fn t => Time.- (t, Time.- (Time.zeroTime, t)), sec ~1, 300))
  val () = eqB ("Time.-/Time-when-not-representable-positive", true,
                fn () => doubling (fn t => Time.- (t, Time.- (Time.zeroTime, t)), sec 1, 300))

  (* ---- compare and the relations ---- *)
  val () = T.eq T.order ("Time.compare/less", LESS, fn () => Time.compare (sec 1, sec 2))
  val () = T.eq T.order ("Time.compare/equal", EQUAL, fn () => Time.compare (ms 2000, sec 2))
  val () = T.eq T.order ("Time.compare/greater", GREATER, fn () => Time.compare (us 1000001, sec 1))
  val () = T.eq T.order ("Time.compare/negative", LESS, fn () => Time.compare (sec ~5, sec ~4))
  val () = T.eq T.order ("Time.compare/negative-and-zero", LESS, fn () => Time.compare (us ~1, Time.zeroTime))
  val () = law ("Time.compare/agrees-with-microseconds", 200, randomMicros2,
                fn (a, b) => Time.compare (usL a, usL b) = LargeInt.compare (a, b)
                             andalso Time.compare (usL a, usL a) = EQUAL, showL2)
  val () = eqB ("Time.</true", true, fn () => Time.< (ms 999, sec 1))
  val () = eqB ("Time.</equal", false, fn () => Time.< (sec 1, ms 1000))
  val () = eqB ("Time.</false", false, fn () => Time.< (sec 1, sec ~1))
  val () = eqB ("Time.<=/true", true, fn () => Time.<= (sec ~1, Time.zeroTime))
  val () = eqB ("Time.<=/equal", true, fn () => Time.<= (sec 1, ms 1000))
  val () = eqB ("Time.<=/false", false, fn () => Time.<= (us 1, Time.zeroTime))
  val () = eqB ("Time.>/true", true, fn () => Time.> (us 1, Time.zeroTime))
  val () = eqB ("Time.>/equal", false, fn () => Time.> (sec 1, ms 1000))
  val () = eqB ("Time.>/false", false, fn () => Time.> (sec ~2, sec ~1))
  val () = eqB ("Time.>=/true", true, fn () => Time.>= (sec 2, sec 1))
  val () = eqB ("Time.>=/equal", true, fn () => Time.>= (ms 1000, sec 1))
  val () = eqB ("Time.>=/false", false, fn () => Time.>= (sec ~1, Time.zeroTime))
  val () = law ("Time.</agrees-with-compare", 200, randomMicros2,
                fn (a, b) => let val c = Time.compare (usL a, usL b)
                             in Time.< (usL a, usL b) = (c = LESS) andalso Time.<= (usL a, usL b) = (c <> GREATER)
                                andalso Time.> (usL a, usL b) = (c = GREATER) andalso Time.>= (usL a, usL b) = (c <> LESS)
                             end, showL2)

  (* ---- now: "the time at which the function call was made". Absolute times
     are intervals from zeroTime, "a common reference point", which lies in
     the past. ---- *)
  val () = eqB ("Time.now/after-zeroTime", true, fn () => Time.> (Time.now (), Time.zeroTime))
  val () = eqB ("Time.now/does-not-go-back", true,
                fn () => let val a = Time.now () val b = Time.now () val c = Time.now ()
                         in Time.<= (a, b) andalso Time.<= (b, c) end)
  val () = eqB ("Time.now/advances", true,
                fn () => let
                           val a = Time.now ()
                           fun go k = k > 0 andalso (Time.> (Time.now (), a) orelse go (k - 1))
                         in go 10000000 end)

  (* ---- fmt n t, toString t: "a decimal number representing t in seconds.
     Using fmt, the fractional part is rounded to n decimal digits. If n = 0,
     there should be no fractional part. Having n < 0 causes the Size
     exception to be raised. toString rounds t to 3 decimal digits." Time
     values "are required to have fixed-point semantics": the digits are
     those of the exact value. Negative numbers are written with ~, as
     everywhere in the library. ---- *)
  val () = eqS ("Time.fmt/spec-example-3", "1.800", fn () => Time.fmt 3 (Time.fromReal 1.8))
  val () = eqS ("Time.fmt/spec-example-0", "2", fn () => Time.fmt 0 (Time.fromReal 1.8))
  val () = eqS ("Time.fmt/spec-example-zeroTime", "0", fn () => Time.fmt 0 Time.zeroTime)
  val () = eqS ("Time.fmt/zeroTime-3", "0.000", fn () => Time.fmt 3 Time.zeroTime)
  val () = eqS ("Time.fmt/rounds-down", "1.23", fn () => Time.fmt 2 (ms 1234))
  val () = eqS ("Time.fmt/rounds-up", "1.24", fn () => Time.fmt 2 (ms 1236))
  val () = eqS ("Time.fmt/carries-into-seconds", "2.0", fn () => Time.fmt 1 (ms 1960))
  val () = eqS ("Time.fmt/0-rounds-up", "1", fn () => Time.fmt 0 (ms 999))
  val () = eqS ("Time.fmt/0-rounds-down", "0", fn () => Time.fmt 0 (ms 400))
  val () = eqS ("Time.fmt/whole-seconds", "12.0000", fn () => Time.fmt 4 (sec 12))
  val () = eqS ("Time.fmt/microsecond", "0.000001", fn () => Time.fmt 6 (us 1))
  val () = eqS ("Time.fmt/more-digits-than-microseconds", "0.000001000", fn () => Time.fmt 9 (us 1))
  val () = eqS ("Time.fmt/20-digits", "1.00000000000000000000", fn () => Time.fmt 20 (sec 1))
  val () = eqS ("Time.fmt/20-digits-microsecond", "0.00000100000000000000", fn () => Time.fmt 20 (us 1))
  val () = eqS ("Time.fmt/40-digits", "2.5" ^ digits (39, #"0"), fn () => Time.fmt 40 (ms 2500))
  val () = eqS ("Time.fmt/negative", "~1.500", fn () => Time.fmt 3 (ms ~1500))
  val () = eqS ("Time.fmt/negative-carries", "~2.0", fn () => Time.fmt 1 (ms ~1960))
  val () = eqS ("Time.fmt/negative-0-digits", "~3", fn () => Time.fmt 0 (ms ~2600))
  val () = exactOrTime ("Time.fmt/fixed-point-semantics",
                        fn () => Time.fmt 6 (usL (big "12345678901234567")) = "12345678901.234567")
  val () = exactOrTime ("Time.fmt/fixed-point-semantics-rounded",
                        fn () => Time.fmt 3 (usL (big "12345678901234567")) = "12345678901.235")
  val () = exactOrTime ("Time.fmt/large", fn () => Time.fmt 0 (secL (big "123456789012")) = "123456789012")
  val () = T.raises ("Time.fmt/Size", T.isSize, fn () => Time.fmt ~1 (sec 1))
  val () = T.raises ("Time.fmt/Size-zeroTime", T.isSize, fn () => Time.fmt ~3 Time.zeroTime)
  val () = law ("Time.fmt/6-digits-of-microseconds", 200, randomMicros,
                fn n => let
                          val a = absL n
                          val million = large 1000000
                          val frac = LargeInt.toString (LargeInt.mod (a, million))
                          val expected = (if LargeInt.< (n, large 0) then "~" else "") ^ LargeInt.toString (LargeInt.div (a, million)) ^ "."
                                         ^ digits (6 - size frac, #"0") ^ frac
                        in Time.fmt 6 (usL n) = expected end, showL)
  val () = eqS ("Time.toString/spec-example", "1.800", fn () => Time.toString (Time.fromReal 1.8))
  val () = eqS ("Time.toString/rounds", "1.235", fn () => Time.toString (us 1234567))
  val () = eqS ("Time.toString/rounds-down", "1.234", fn () => Time.toString (us 1234432))
  val () = eqS ("Time.toString/negative", "~1.235", fn () => Time.toString (us ~1234567))
  val () = eqS ("Time.toString/zeroTime", "0.000", fn () => Time.toString Time.zeroTime)
  val () = eqS ("Time.toString/whole", "86400.000", fn () => Time.toString (sec 86400))
  val () = law ("Time.toString/is-fmt-3", 200, randomMicros,
                fn n => Time.toString (usL n) = Time.fmt 3 (usL n), showL)

  (* ---- scan, fromString: "a number of seconds specified as a string that
     matches the regular expression [+~-]?([0-9]+.[0-9]+? | .[0-9]+).
     Initial whitespace is ignored. Both functions raise Time when the value
     is syntactically correct but not representable." ---- *)
  val () = eqNO ("Time.fromString/fraction", SOME "1500000000", fn () => Time.fromString "1.5")
  val () = eqNO ("Time.fromString/whole", SOME "12000000000", fn () => Time.fromString "12")
  val () = eqNO ("Time.fromString/leading-point", SOME "500000000", fn () => Time.fromString ".5")
  val () = eqNO ("Time.fromString/leading-point-zero", SOME "0", fn () => Time.fromString ".0")
  val () = eqNO ("Time.fromString/zero", SOME "0", fn () => Time.fromString "0")
  val () = eqNO ("Time.fromString/zero-point-zero", SOME "0", fn () => Time.fromString "0.000")
  val () = eqNO ("Time.fromString/tilde", SOME "~1500000000", fn () => Time.fromString "~1.5")
  val () = eqNO ("Time.fromString/minus", SOME "~1500000000", fn () => Time.fromString "-1.5")
  val () = eqNO ("Time.fromString/plus", SOME "1500000000", fn () => Time.fromString "+1.5")
  val () = eqNO ("Time.fromString/minus-leading-point", SOME "~250000000", fn () => Time.fromString "-.25")
  val () = eqNO ("Time.fromString/negative-zero", SOME "0", fn () => Time.fromString "~0")
  val () = eqNO ("Time.fromString/whitespace", SOME "2250000000", fn () => Time.fromString " \t\n 2.25")
  val () = eqNO ("Time.fromString/prefix", SOME "3500000000", fn () => Time.fromString "3.5 seconds")
  val () = eqNO ("Time.fromString/trailing-point", SOME "1000000000", fn () => Time.fromString "1.")
  val () = eqNO ("Time.fromString/leading-zeros", SOME "12500000000", fn () => Time.fromString "0000000000000000000000000012.5")
  val () = eqNO ("Time.fromString/microsecond", SOME "1000", fn () => Time.fromString "0.000001")
  val () = eqNO ("Time.fromString/many-zero-digits", SOME "1000000000", fn () => Time.fromString "1.00000000000000000000000000000")
  val () = eqL ("Time.fromString/many-fraction-digits", "3141",
                fn () => Time.toMilliseconds (valOf (Time.fromString "3.14159265358979323846264338327950288")))
  val () = eqNO ("Time.fromString/tiny-fraction", SOME "0", fn () => Time.fromString "0.00000000000000000000000001")
  val () = eqL ("Time.fromString/nanoseconds-lost-or-kept", "0",
                fn () => Time.toMicroseconds (valOf (Time.fromString "0.000000999")))
  val () = eqNO ("Time.fromString/empty", NONE, fn () => Time.fromString "")
  val () = eqNO ("Time.fromString/blank", NONE, fn () => Time.fromString "   ")
  val () = eqNO ("Time.fromString/letters", NONE, fn () => Time.fromString "abc")
  val () = eqNO ("Time.fromString/point-only", NONE, fn () => Time.fromString ".")
  val () = eqNO ("Time.fromString/sign-only", NONE, fn () => Time.fromString "~")
  val () = eqNO ("Time.fromString/sign-and-point", NONE, fn () => Time.fromString "-.")
  val () = eqNO ("Time.fromString/space-after-sign", NONE, fn () => Time.fromString "~ 1")
  val () = eqNO ("Time.fromString/two-signs", NONE, fn () => Time.fromString "+-1")
  val () = exactOrTime ("Time.fromString/huge-exact-or-Time",
                        fn () => Option.map Time.toSeconds (Time.fromString ("1" ^ digits (40, #"0")))
                                 = SOME (pow10 40))
  val () = exactOrTime ("Time.fromString/huge-negative-exact-or-Time",
                        fn () => Option.map Time.toSeconds (Time.fromString ("~1" ^ digits (40, #"0") ^ ".5"))
                                 = SOME (LargeInt.~ (pow10 40)))
  val () = law ("Time.fromString/inverts-fmt-6", 200, randomMicros,
                fn n => Time.fromString (Time.fmt 6 (usL n)) = SOME (usL n), showL)
  val () = law ("Time.fromString/inverts-toString-for-milliseconds", 200,
                fn () => LargeInt.+ (LargeInt.* (large (T.range (~100000000, 100000000)), large 1000), large (T.range (0, 999))),
                fn n => Time.fromString (Time.toString (msL n)) = SOME (msL n), showL)

  fun scanSub s =
    case Time.scan Substring.getc (Substring.full s) of
      SOME (t, rest) => SOME (t, Substring.string rest)
    | NONE => NONE
  fun listRd [] = NONE
    | listRd (c :: cs) = SOME (c, cs)
  val () = eqScan ("Time.scan/rest", SOME ("1500000000", " rest"), T.string, fn () => scanSub "1.5 rest")
  val () = eqScan ("Time.scan/rest-after-whole", SOME ("12000000000", "abc"), T.string, fn () => scanSub "12abc")
  val () = eqScan ("Time.scan/rest-after-fraction", SOME ("500000000", ".x"), T.string, fn () => scanSub ".5.x")
  val () = eqScan ("Time.scan/skips-whitespace", SOME ("~2500000000", ""), T.string, fn () => scanSub "\n ~2.5")
  val () = eqScan ("Time.scan/rest-after-sign", SOME ("7000000000", "+"), T.string, fn () => scanSub "+7+")
  val () = eqScan ("Time.scan/NONE", NONE, T.string, fn () => scanSub "x1")
  val () = eqScan ("Time.scan/NONE-point", NONE, T.string, fn () => scanSub ". 5")
  val () = eqScan ("Time.scan/list-reader", SOME ("2500000000", [#"s"]), T.list T.char,
                   fn () => Time.scan listRd (String.explode "2.5s"))
  val () = eqScan ("Time.scan/list-reader-NONE", NONE, T.list T.char, fn () => Time.scan listRd (String.explode "s2.5"))
  val () = exactOrTime ("Time.scan/huge-exact-or-Time",
                        fn () => case scanSub (digits (30, #"9") ^ "!") of
                                   SOME (t, "!") => Time.toSeconds t = LargeInt.- (pow10 30, large 1)
                                 | _ => false)
end
