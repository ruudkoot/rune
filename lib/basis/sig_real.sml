(* Floating-point numbers: IEEE 754 arithmetic, the numbers that are not
   ordinary (the infinities, the NaNs and the negative zero), and the
   conversions to and from integers and text.

   `Real` is the default structure, `LargeReal` the widest, and the sized
   ones are `Real32` and `Real64`. A NaN, "not a number", is what an
   operation answers where there is no value to give: it is equal to nothing,
   itself included, so `==` is `false` for it and `compare` raises
   `Unordered`. Because of that the equality of the language is not available
   at `real`; use `==` where equality is meant and `Real.compare` where an
   order is.

   There are two zeros, which `==` says are equal and `signBit` tells apart;
   a computation that underflows keeps the sign it came from.

   The functions that round come in two kinds: `realFloor` and its like stay
   in `real`, `floor` and its like give an `int` and raise where the result
   would not fit.

   Area: Numbers

   See also: `MATH`, `IEEE_REAL`, `INTEGER`, `STRING_CVT`, `PACK_REAL`

   Implementation: `Real.real/binary64`. `Real.real` is the top-level `real`,
   the 64-bit IEEE double (`radix` 2, `precision` 53), and so are `LargeReal`
   and `Real64`; the optional `Real32` is binary32. The conversions to and
   from text are correctly rounded, through the C library. *)
signature REAL =
sig
  (* ---- The type ---- *)

  (* The type of floating-point numbers of this structure.

     It does not admit equality: `=` would say that a NaN is equal to itself
     and that the two zeros are different, and neither is what IEEE 754
     means. *)
  type real

  (* The elementary functions at this type: `sqrt`, `sin`, `ln` and the rest. *)
  structure Math : MATH where type real = real

  (* ---- The format ---- *)

  (* The base in which the significand is written: 2 for every binary format. *)
  val radix : int

  (* The number of digits of the significand, in base `radix`.

     Implementation: `Real.precision/double`. 53 for binary64, which is 52
     stored bits and the leading one that is not stored. The arithmetic must
     show that precision and no more: `1.0 + 2^~52` is greater than `1.0`,
     and `1.0 + 2^~53` rounds back to `1.0`. *)
  val precision : int

  (* The largest finite number of this type. *)
  val maxFinite : real

  (* The smallest positive number of this type, which is subnormal and has few digits of precision. *)
  val minPos : real

  (* The smallest positive normal number: the smallest with the full `precision` digits. *)
  val minNormalPos : real

  (* Positive infinity, what a computation that grows without bound gives. *)
  val posInf : real

  (* Negative infinity. *)
  val negInf : real

  (* ---- Arithmetic ---- *)

  (* `x + y` is the sum, correctly rounded. *)
  val + : real * real -> real

  (* `x - y` is the difference, correctly rounded. *)
  val - : real * real -> real

  (* `x * y` is the product, correctly rounded. *)
  val * : real * real -> real

  (* `x / y` is the quotient, correctly rounded.

     Division by zero is not an error here: it gives an infinity of the
     right sign, and `0.0 / 0.0` gives a NaN. *)
  val / : real * real -> real

  (* `rem (x, y)` is what is left of `x` after taking away a whole number of `y`: `x - n * y` with `n` the quotient rounded towards zero.

     It is computed exactly, whatever the magnitudes, and is a NaN when `x`
     is infinite or `y` is zero; for an infinite `y` it is `x`.

     Reading: `Real.rem/exact-multiple-negative-x`. The sign of a zero
     remainder is left open: the specification asks for the sign of `x`, and
     the definition `x - n * y` gives a positive zero. *)
  val rem : real * real -> real

  (* `*+ (x, y, z)` is `x * y + z`.

     Implementation: `Real.*+/fused`. Whether the multiplication and the
     addition are rounded once or twice is left to the implementation. *)
  val *+ : real * real * real -> real

  (* `*- (x, y, z)` is `x * y - z`. *)
  val *- : real * real * real -> real

  (* `~x` is `x` with its sign bit inverted, the zeros and the NaNs included. *)
  val ~ : real -> real

  (* `abs x` is `x` with its sign bit clear. *)
  val abs : real -> real

  (* ---- Choosing ---- *)

  (* `min (x, y)` is the smaller of the two, or the one that is not a NaN when the other is. *)
  val min : real * real -> real

  (* `max (x, y)` is the larger of the two, or the one that is not a NaN when the other is. *)
  val max : real * real -> real

  (* ---- Signs ---- *)

  (* `sign x` is ~1, 0 or 1, as `x` is negative, zero or positive.

     Raises: `Domain` if `x` is a NaN. *)
  val sign : real -> int

  (* `signBit x` is `true` when the sign bit of `x` is set.

     Reading: `Real.signBit/zeros`. It looks at the bit and not at the value,
     so it tells the two zeros apart and answers for a NaN as well. *)
  val signBit : real -> bool

  (* `sameSign (x, y)` is `true` when `x` and `y` have the same sign bit.

     Law: `sameSign (x, y) = (signBit x = signBit y)` *)
  val sameSign : real * real -> bool

  (* `copySign (x, y)` is `x` with the sign bit of `y`. *)
  val copySign : real * real -> real

  (* ---- Comparing ---- *)

  (* `compare (x, y)` orders two reals.

     Raises: `IEEEReal.Unordered` if either is a NaN, which is the top-level
     `Unordered`. *)
  val compare : real * real -> order

  (* `compareReal (x, y)` orders two reals, and answers `UNORDERED` where a NaN makes the question meaningless. *)
  val compareReal : real * real -> IEEEReal.real_order

  (* `x < y`, `x <= y`, `x > y` and `x >= y` compare two reals.

     Every one of them is `false` when either side is a NaN, so `x <= y` is
     not the negation of `x > y`. *)
  val < : real * real -> bool
  val <= : real * real -> bool
  val > : real * real -> bool
  val >= : real * real -> bool

  (* `== (x, y)` is `true` when `x` and `y` are the same number.

     The two zeros are the same number; a NaN is not even equal to itself.
     This is the equality of IEEE 754 and what a program should use at
     `real`. The specification writes it infix, which a program must declare
     (`infix 4 ==`) before it can do the same. *)
  val == : real * real -> bool

  (* `!= (x, y)` is the negation of `== (x, y)`, so it is `true` when either is a NaN. *)
  val != : real * real -> bool

  (* `?= (x, y)` is `true` when `x` and `y` are equal or either is a NaN: "unordered or equal".

     Law: `?= (x, y) = (unordered (x, y) orelse == (x, y))` *)
  val ?= : real * real -> bool

  (* `unordered (x, y)` is `true` when either is a NaN, so that no order relates them. *)
  val unordered : real * real -> bool

  (* ---- Classifying ---- *)

  (* `isFinite x` is `true` when `x` is neither an infinity nor a NaN. *)
  val isFinite : real -> bool

  (* `isNan x` is `true` when `x` is a NaN. *)
  val isNan : real -> bool

  (* `isNormal x` is `true` when `x` is an ordinary number: finite, not zero and not subnormal. *)
  val isNormal : real -> bool

  (* `class x` is which of the five kinds of number `x` is. *)
  val class : real -> IEEEReal.float_class

  (* ---- Taking a real apart ---- *)

  (* `toManExp x` is the significand and the exponent of `x`: the `man` and `exp` for which `x` is `man * radix^exp`.

     Reading: `Real.toManExp/one`. The specification writes the range of the
     significand as "1.0 <= man * radix < radix", which for radix 2 means
     `0.5 <= |man| < 1.0`: the convention of C's `frexp`, and not the one
     that puts the point after the first digit. For a zero, an infinity or a
     NaN the significand is `x` itself. *)
  val toManExp : real -> {man : real, exp : int}

  (* `fromManExp {man, exp}` is `man * radix^exp`.

     Law: `fromManExp (toManExp x) == x` for a finite `x` *)
  val fromManExp : {man : real, exp : int} -> real

  (* `split x` is the whole part and the fractional part of `x`, each with the sign of `x`.

     The whole part is `x` rounded towards zero. For an infinity the
     fractional part is a zero, and for a NaN both are NaNs.

     Law: `#whole (split x) + #frac (split x) == x` *)
  val split : real -> {whole : real, frac : real}

  (* `realMod x` is the fractional part of `x`, with its sign.

     Law: `realMod x = #frac (split x)` *)
  val realMod : real -> real

  (* `nextAfter (x, y)` is the number of this type next to `x` in the direction of `y`.

     Reading: `Real.nextAfter/equal-zeros-returns-r`. "If `r = t` then it
     returns `r`": the two zeros are equal, so `nextAfter (~0.0, 0.0)` is
     `~0.0`. C's `nextafter` returns `t` there, and MLton and Poly/ML follow
     C. *)
  val nextAfter : real * real -> real

  (* `checkFloat x` is `x` when it is finite, and raises otherwise.

     It is how a program turns the silent results of IEEE arithmetic into
     exceptions at the point it chooses.

     Raises: `Overflow` if `x` is an infinity; `Div` if `x` is a NaN. *)
  val checkFloat : real -> real

  (* ---- Rounding to a whole number ---- *)

  (* `realFloor x` is the largest whole number that is not greater than `x`, as a `real`.

     Reading: `Real.realFloor/negzero-sign`. The specification is silent
     about the sign of a zero result; IEEE 754 keeps the sign of the operand,
     so `realFloor ~0.5` is `~0.0`. The same holds for `realCeil`,
     `realTrunc` and `realRound`. *)
  val realFloor : real -> real

  (* `realCeil x` is the smallest whole number that is not less than `x`, as a `real`. *)
  val realCeil : real -> real

  (* `realTrunc x` is `x` rounded towards zero, as a `real`. *)
  val realTrunc : real -> real

  (* `realRound x` is `x` rounded to the nearest whole number, as a `real`.

     Reading: `Real.realRound/tie-half`. A value exactly between two whole
     numbers goes to the even one, as it does for `round`: the specification
     states the rule under `round` alone, and IEEE 754's rounding to an
     integral value agrees. *)
  val realRound : real -> real

  (* `floor x` is the largest whole number that is not greater than `x`, as an `int`.

     Raises: `Overflow` if that number is outside the range of `Int.int`;
     `Domain` if `x` is a NaN. *)
  val floor : real -> int

  (* `ceil x` is the smallest whole number that is not less than `x`, as an `int`.

     Raises: `Overflow` if it does not fit; `Domain` if `x` is a NaN. *)
  val ceil : real -> int

  (* `trunc x` is `x` rounded towards zero, as an `int`.

     Raises: `Overflow` if it does not fit; `Domain` if `x` is a NaN. *)
  val trunc : real -> int

  (* `round x` is `x` rounded to the nearest whole number, ties to even, as an `int`.

     Raises: `Overflow` if it does not fit; `Domain` if `x` is a NaN. *)
  val round : real -> int

  (* `toInt mode x` is `x` rounded to an `int` in the given rounding mode.

     Raises: `Overflow` if it does not fit; `Domain` if `x` is a NaN. *)
  val toInt : IEEEReal.rounding_mode -> real -> int

  (* `toLargeInt mode x` is `x` rounded to a `LargeInt.int` in the given rounding mode.

     Where `LargeInt` has no bounds this loses nothing, however large `x` is.

     Raises: `Overflow` if `x` is an infinity, or if the result does not fit
     a bounded `LargeInt.int`; `Domain` if `x` is a NaN. *)
  val toLargeInt : IEEEReal.rounding_mode -> real -> LargeInt.int

  (* `fromInt i` is `i` as a real, correctly rounded when the type cannot hold it exactly. *)
  val fromInt : int -> real

  (* `fromLargeInt i` is `i` as a real, correctly rounded.

     Reading: `Real.fromLargeInt/tie-rounds-to-even-down`. The current
     rounding mode is used; under the default one a value exactly between two
     reals goes to the one whose last digit is even, and the digits that are
     dropped decide the rest. *)
  val fromLargeInt : LargeInt.int -> real

  (* `toLarge x` is `x` as a `LargeReal.real`, which loses nothing. *)
  val toLarge : real -> LargeReal.real

  (* `fromLarge mode x` is the number of this type nearest to `x`, rounded in the given mode.

     Reading: `LargeReal/at-least-Real`. `LargeReal` is at least as wide as
     `Real`, so this rounds only where it is wider. *)
  val fromLarge : IEEEReal.rounding_mode -> LargeReal.real -> real

  (* ---- Text ---- *)

  (* `fmt spec x` is the text of `x` in the given notation.

     `StringCvt.SCI`, `FIX` and `GEN` take a number of digits, and `EXACT`
     writes as many as are needed to read the same number back. An infinity
     is `"inf"` or `"~inf"` and a NaN is `"nan"`.

     Raises: `Size` if the number of digits is negative. The specification
     says this happens "when `fmt spec` is evaluated", before a real is
     given, so a partial application already raises.

     Reading: `Real.fmt/SCI-negzero`. A negative zero is written with its
     sign, because the formats are described as `[~]?` and `signBit` is set;
     MLton leaves the sign out.

     Reading: `Real.fmt/GEN-integral-one`. In `GEN`, a number with no
     fractional part is written without a point, as C's `gcvt` does, and the
     shorter of the scientific and the fixed form is taken, a tie going to
     the fixed one: `fmt (GEN NONE) 1.0` is `"1"` and `fmt (GEN NONE) 1000.0`
     is `"1E3"`. *)
  val fmt : StringCvt.realfmt -> real -> string

  (* `toString x` is the text of `x` in the general notation with the default number of digits.

     Law: `toString x = fmt (StringCvt.GEN NONE) x` *)
  val toString : real -> string

  (* `scan getc strm` reads a real from `strm`.

     It skips initial white space and then takes an optional sign and either
     a decimal numeral with an optional point and exponent, or one of the
     words `inf`, `infinity` and `nan` in any case. The answer is
     `SOME (x, rest)`, or `NONE` when no numeral is there.

     A numeral whose value is too large becomes an infinity and one too small
     a zero; nothing is raised. A numeral that no real holds exactly is
     rounded as `fromString` rounds it. *)
  val scan : (char, 'a) StringCvt.reader -> (real, 'a) StringCvt.reader

  (* `fromString s` is the real that the text `s` begins with, or `NONE`.

     Law: `fromString s = StringCvt.scanString scan s`

     Reading: `Real.fromString/TO_NEGINF-negative`. The numeral is rounded in
     the rounding mode that is in force, as in MLton and in C's `strtod`;
     SML/NJ and Poly/ML always round to nearest. `Real32.fromString` rounds
     once, straight to binary32, and not first to binary64. *)
  val fromString : string -> real option

  (* `toDecimal x` is `x` written out in decimal digits, exactly.

     Every real has an exact decimal form, so nothing is lost; `IEEEReal.toString`
     turns the result into text. *)
  val toDecimal : real -> IEEEReal.decimal_approx

  (* `fromDecimal d` is the real nearest to the decimal number `d`, or `NONE` when `d` is not a number a real can describe.

     The current rounding mode is used. A `d` whose value is too large gives
     an infinity and one too small a zero. *)
  val fromDecimal : IEEEReal.decimal_approx -> real option
end
