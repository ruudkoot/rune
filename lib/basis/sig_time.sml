(* A length of time, and a point in time counted from a fixed reference.

   A `time` is a duration. It is also how a moment is named: `now ()` is the
   time since `zeroTime`, and a moment and a duration have one type, so
   `now () + fromSeconds 10` is ten seconds hence and a difference of two
   moments is a duration. Times may be negative.

   The conversions take and give `LargeInt.int`, so that the range of a time
   is not tied to `Int.int`; going the other way they truncate towards zero.
   How fine a time is and how far it reaches is left to the implementation,
   and a conversion or an addition whose result does not fit raises `Time`
   rather than `Overflow`.

   Area: The operating system

   See also: `DATE`, `TIMER`, `OS_PROCESS`

   Implementation: `TIME.time/is-microseconds`. A time is a number of
   microseconds held in an `int`, which reaches about 292,000 years either
   way. Anything finer than a microsecond is lost, and `zeroTime` is the
   epoch of the system's clock, 1 January 1970 UTC. *)
signature TIME =
sig
  (* The type of a length of time.

     Two times are equal when they are the same length.

     Deviation: `TIME.time/not-abstract`. The specification leaves the type
     abstract. In Rune it is `int`, the number of microseconds, and the
     structure is not sealed, so the representation shows; `Time` also has
     `micros` and `ofMicros` beyond the signature, for the parts of the
     library that count in microseconds. *)
  eqtype time

  (* Raised when a time cannot be made or converted: the value does not fit. *)
  exception Time

  (* The zero of the arithmetic, and the reference point that `now` counts from.

     Reading: `Time.zeroTime/lies-in-the-past`. It is "a common reference
     point for all time values"; the suite takes it to lie in the past, so
     `now ()` is greater.

     Pinned by: `Time.now/after-zeroTime` *)
  val zeroTime : time

  (* `fromReal r` is `r` seconds, its fraction truncated towards zero.

     Raises: `Time` if `r` is not a number, is infinite, or does not fit. *)
  val fromReal : LargeReal.real -> time

  (* `toReal t` is `t` as a number of seconds, which may lose precision. *)
  val toReal : time -> LargeReal.real

  (* `toSeconds t` is the whole seconds of `t`, truncated towards zero. *)
  val toSeconds : time -> LargeInt.int

  (* `toMilliseconds t` is the whole milliseconds of `t`, truncated towards zero. *)
  val toMilliseconds : time -> LargeInt.int

  (* `toMicroseconds t` is the whole microseconds of `t`, truncated towards zero. *)
  val toMicroseconds : time -> LargeInt.int

  (* `toNanoseconds t` is the whole nanoseconds of `t`, truncated towards zero.

     Implementation: `Time.toNanoseconds/beyond-64-bits`. The result is a
     `LargeInt.int` and is exact however large it is; a `LargeInt` of bounded
     precision would raise `Overflow` instead.

     Pinned by: `Time.toNanoseconds/beyond-64-bits`, `Time.toMicroseconds/large` *)
  val toNanoseconds : time -> LargeInt.int

  (* `fromSeconds n` is `n` seconds.

     Raises: `Time` if the time does not fit.

     Implementation: `Time.fromSeconds/range-is-open`. Where the range ends
     is not fixed; the suite asks only that a value either come out exact or
     raise `Time`, never something else and never a wrong number.

     Pinned by: `Time.from*/huge-*` *)
  val fromSeconds : LargeInt.int -> time

  (* `fromMilliseconds n` is `n` milliseconds.

     Raises: `Time` if the time does not fit. *)
  val fromMilliseconds : LargeInt.int -> time

  (* `fromMicroseconds n` is `n` microseconds.

     Raises: `Time` if the time does not fit. *)
  val fromMicroseconds : LargeInt.int -> time

  (* `fromNanoseconds n` is `n` nanoseconds, truncated to what a time can hold.

     Raises: `Time` if the time does not fit. *)
  val fromNanoseconds : LargeInt.int -> time

  (* `t + u` is the sum of two times.

     Raises: `Time` if the sum does not fit.

     Implementation: `Time.+/exact-until-it-raises`. Wherever the range ends,
     doubling a time over and over stays exact until one step raises `Time`;
     no step gives a wrong value or another exception.

     Pinned by: `Time.+/Time-when-not-representable*` *)
  val + : time * time -> time

  (* `t - u` is `t` less `u`, which may be negative.

     Raises: `Time` if the difference does not fit.

     Implementation: `Time.-/exact-until-it-raises`. As for `+`: exact until
     a step raises `Time`.

     Pinned by: `Time.-/Time-when-not-representable*` *)
  val - : time * time -> time

  (* `compare (t, u)` orders two times, the shorter first. *)
  val compare : time * time -> order

  (* `t < u` is `true` when `t` is the shorter time. *)
  val < : time * time -> bool

  (* `t <= u` is `true` when `t` is no longer than `u`. *)
  val <= : time * time -> bool

  (* `t > u` is `true` when `t` is the longer time. *)
  val > : time * time -> bool

  (* `t >= u` is `true` when `t` is no shorter than `u`. *)
  val >= : time * time -> bool

  (* `now ()` is the time since `zeroTime`, by the clock of the system. *)
  val now : unit -> time

  (* `fmt n t` is `t` in seconds, with `n` digits after the decimal point and none when `n` is 0.

     Raises: `Size` if `n < 0`.

     Reading: `Time.fmt/fixed-point`. The text has "fixed-point semantics":
     the digit last kept is rounded to nearest, and since a time holds
     microseconds every digit past the sixth is a zero.

     Pinned by: `Time.fmt/fixed-point-semantics*`,
     `Time.fmt/more-digits-than-microseconds` *)
  val fmt : int -> time -> string

  (* `toString t` is `fmt 3 t`: seconds with three digits of the fraction. *)
  val toString : time -> string

  (* `scan getc src` reads a number of seconds, after leading whitespace, and is the time and what is left.

     What it reads is an optional sign, then digits, then optionally a point
     and digits, or a point and digits alone.

     Raises: `Time` if the number does not fit.

     Reading: `Time.scan/digits-past-the-sixth`. Any number of digits may be
     written; those of the fraction after the sixth are dropped rather than
     rounded, and a number too large for a time raises `Time`.

     Pinned by: `Time.fmt/40-digits` *)
  val scan : (char, 'a) StringCvt.reader -> (time, 'a) StringCvt.reader

  (* `fromString s` is `SOME` of the time that `s` begins with, after whitespace, or `NONE`.

     Law: `fromString s = StringCvt.scanString scan s`

     Raises: `Time` if the number does not fit. *)
  val fromString : string -> time option
end
