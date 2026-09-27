(* The elementary functions of a real type: roots, the trigonometric and
   hyperbolic functions, exponentials and logarithms.

   A structure of this signature belongs to a `REAL` structure and computes
   with its type, so `Math` is `Real.Math`. Angles are in radians. None of
   these functions raises: where the mathematical function has no value the
   answer is a NaN, and where it grows without bound it is an infinity, as
   IEEE 754 prescribes. A NaN as an argument gives a NaN, except where a
   function says otherwise (`pow (x, 0.0)` is 1 for every `x`).

   The results are not exact. The specification asks only that they be
   "accurate", and a program that compares them should allow for the rounding
   of the last digits; `Real.==` on two results of different routes is
   usually wrong.

   Area: Numbers

   See also: `REAL`, `IEEE_REAL` *)
signature MATH =
sig
  (* The type of the reals these functions compute with: `Real.real` for `Real.Math`. *)
  type real

  (* The ratio of a circle's circumference to its diameter, as near as the type can say.

     Implementation: `Math.pi/nearest-double`. The `real` nearest to pi,
     which differs from it by about 1.2E~16.

     Example: `Real.fmt (StringCvt.FIX (SOME 4)) pi = "3.1416"` *)
  val pi : real

  (* The base of the natural logarithm, as near as the type can say.

     Example: `Real.fmt (StringCvt.FIX (SOME 4)) e = "2.7183"` *)
  val e : real

  (* `sqrt x` is the square root of `x`.

     It is a NaN for a negative `x`, and `~0.0` for `~0.0`.

     Implementation: `Math.sqrt/four`. IEEE 754 requires the square root to
     be correctly rounded, so an exact square gives its root exactly:
     `sqrt 4.0` is `2.0`, not something near it.

     Example: `Real.isNan (sqrt ~1.0) = true` *)
  val sqrt : real -> real

  (* `sin x` is the sine of `x` radians.

     It is a NaN for an infinite `x`.

     Example: `Real.signBit (sin ~0.0) = true` *)
  val sin : real -> real

  (* `cos x` is the cosine of `x` radians.

     It is a NaN for an infinite `x`.

     Example: `Real.== (cos 0.0, 1.0) = true` *)
  val cos : real -> real

  (* `tan x` is the tangent of `x` radians.

     It is a NaN for an infinite `x`.

     Reading: `Math.tan/near-singularity`. The specification says that `tan`
     has "infinities at various finite values"; no `real` is an odd multiple
     of pi/2, so the function is finite everywhere, and what is asked of it
     is only that its magnitude near the singularity be large. *)
  val tan : real -> real

  (* `asin x` is the arc sine of `x`, in radians, between `~pi/2` and `pi/2`.

     It is a NaN for an `x` outside `[~1, 1]`.

     Reading: `Math.asin/accurate-near-one`. The specification asks for no
     particular accuracy, only "roughly the same semantics" as C. Rune's
     `asin` and `acos` are within an ulp or two of the true value everywhere,
     near 1 and ~1 too, where a computation through `1 - x * x` loses most of
     the digits; SML/NJ's `asin` is off by more there.

     Pinned by: `Math.asin/near-one-accurate`,
     `Math.asin/near-minus-one-accurate`, `Math.acos/near-one-accurate`,
     `Math.acos/near-minus-one-accurate`

     Example: `Real.isNan (asin 2.0) = true` *)
  val asin : real -> real

  (* `acos x` is the arc cosine of `x`, in radians, between 0 and `pi`.

     It is a NaN for an `x` outside `[~1, 1]`.

     Example: `Real.== (acos 1.0, 0.0) = true` *)
  val acos : real -> real

  (* `atan x` is the arc tangent of `x`, in radians, between `~pi/2` and `pi/2`.

     At an infinity it is `~pi/2` or `pi/2`.

     Example: `Real.== (atan Real.negInf, ~ (pi / 2.0)) = true` *)
  val atan : real -> real

  (* `atan2 (y, x)` is the angle in radians from the positive x axis to the point `(x, y)`, between `~pi` and `pi`.

     Unlike `atan (y / x)` it knows which quadrant the point is in, because
     it has the signs of both coordinates; the sign of a zero counts, so that
     the answer is continuous as the point crosses an axis. The special cases
     follow the table of the specification: on the y axis the angle is
     `pi/2` or `~pi/2`, `atan2 (0.0, ~0.0)` is `pi`, and two infinities give
     an odd multiple of `pi/4`.

     Law: `atan2 (y, x) = atan (y / x)` for `x > 0`

     Example: `Real.== (atan2 (0.0, ~1.0), pi) = true` *)
  val atan2 : real * real -> real

  (* `exp x` is `e` to the power `x`.

     It is 0 at negative infinity and an infinity at positive infinity, and
     it overflows to an infinity for a large enough finite `x`.

     Example: `Real.== (exp 0.0, 1.0) = true` *)
  val exp : real -> real

  (* `pow (x, y)` is `x` to the power `y`.

     The special cases follow the table of the specification: it is 1 when
     `y` is zero, whatever `x` is, and a NaN where the value would not be
     determined.

     Reading: `Math.pow/one-base-posInf`. `pow (1.0, y)` is a NaN for an
     infinite or NaN `y`, as the specification's table says; C99 and IEEE
     754-2008 make it 1 instead, and Poly/ML follows them.

     Example: `Real.round (pow (2.0, 10.0)) = 1024`

     Example: `Real.toString (pow (0.0, 0.0)) = "1"` *)
  val pow : real * real -> real

  (* `ln x` is the natural logarithm of `x`.

     It is negative infinity at zero, a NaN for a negative `x`, and positive
     infinity at positive infinity.

     Example: `Real.toString (ln 0.0) = "~inf"` *)
  val ln : real -> real

  (* `log10 x` is the logarithm of `x` to base 10.

     It is negative infinity at zero, a NaN for a negative `x`, and positive
     infinity at positive infinity.

     Reading: `Math.log10/powers-of-ten-exact`. The specification asks for no
     particular accuracy, only "roughly the same semantics" as C's `log10`.
     Rune gives the exact logarithm where a real holds it, at the powers of
     ten up to 10^22, as C does, so that `floor (log10 1000.0)` is 3. SML/NJ
     and MLKit compute `ln x / ln 10`, which misses some of them by an ulp.

     Pinned by: `Math.log10/powers-of-ten-exact`,
     `Math.log10/floor-of-a-thousand`

     Example: `Real.== (log10 1000.0, 3.0) = true` *)
  val log10 : real -> real

  (* `sinh x` is the hyperbolic sine of `x`, `(e^x - e^~x) / 2`.

     It keeps the sign of a zero, and overflows to an infinity of the sign of
     `x` for a large enough `x`.

     Example: `Real.signBit (sinh ~0.0) = true` *)
  val sinh : real -> real

  (* `cosh x` is the hyperbolic cosine of `x`, `(e^x + e^~x) / 2`.

     Reading: `Math.cosh/negInf`. It is positive infinity at either infinity,
     which is what the definition gives; the specification's table writes
     "cosh +-infinity = +-infinity", which cannot be meant, and MLton follows
     it to the letter.

     Example: `Real.== (cosh 0.0, 1.0) = true` *)
  val cosh : real -> real

  (* `tanh x` is the hyperbolic tangent of `x`, `sinh x / cosh x`, between `~1` and 1.

     It is `~1.0` and `1.0` at the infinities, and for a large enough finite
     `x` it is those values too, although `sinh` and `cosh` both overflow
     there.

     Example: `Real.== (tanh 1000.0, 1.0) = true` *)
  val tanh : real -> real
end
