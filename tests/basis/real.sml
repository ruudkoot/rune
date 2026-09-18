(* requires: Real *)
(* The Real structure (signature REAL): arithmetic, classification, comparison,
   rounding and conversions to and from integers. Formatting and scanning are in
   real_fmt.sml. Expected values follow the text of
   https://smlfamily.github.io/Basis/real.html and, where that page defers to
   it ("the semantics of floating-point numbers should follow the IEEE standard
   754-1985"), IEEE 754 double precision.

   Members that need IEEEReal, LargeInt or LargeReal, and members that Rune
   lacks, are in sections of their own. *)
structure TestReal =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqOrd = T.eq T.order
  val eqR = T.eqReal

  val posInf = Real.posInf
  val negInf = Real.negInf
  (* "Any other combination of two infinities produces NaN"; cannot raise,
     the semantics is non-trapping. *)
  val nan = Real.posInf - Real.posInf

  (* pow2 n: 2^n, exactly (every product and quotient is a power of two, down
     to the smallest subnormal 2^~1074). *)
  fun pow2 (n : int) : real =
    if n = 0 then 1.0 else if n > 0 then 2.0 * pow2 (n - 1) else pow2 (n + 1) / 2.0

  (* NaN with a given sign bit: "copySign (x, y) returns x with the sign of y". *)
  fun posNan () = Real.copySign (nan, 1.0)
  fun negNan () = Real.copySign (nan, ~1.0)

  (* checkWith (show, same) (label, expected, f): like T.eq, for a type that
     has no equality. *)
  fun checkWith (show : 'a -> string, same : 'a * 'a -> bool) (label, expected : 'a, f : unit -> 'a) : unit =
    case (SOME (f ()) handle _ => NONE) of
      SOME v => if same (v, expected) then T.pass label
                else T.fail (label, "got " ^ show v ^ ", expected " ^ show expected)
    | NONE => T.fail (label, "raised an exception, expected " ^ show expected)

  fun showPair (a : real, b : real) : string = "(" ^ T.real a ^ ", " ^ T.real b ^ ")"
  fun samePair ((a, b), (c, d)) = T.sameReal (a, c) andalso T.sameReal (b, d)

  (* randMantissa (): a multiple of 2^~53 in [0, 1), from 53 random bits. *)
  fun randMantissa () : real =
    (Real.fromInt (T.range (0, 67108863)) * 134217728.0 + Real.fromInt (T.range (0, 134217727)))
    / 9007199254740992.0

  (* randReal k: a finite non-zero real of either sign and magnitude in
     [2^~k, 2^(k+1)). *)
  fun randReal (k : int) : real =
    let
      val m = (1.0 + randMantissa ()) * pow2 (T.range (~k, k))
    in
      if T.range (0, 1) = 0 then m else ~m
    end

  (* law (label, n, k, p): p holds for n random reals of magnitude up to 2^k. *)
  fun law (label, n : int, k : int, p : real -> bool) : unit =
    T.check (label, fn () =>
      let
        val ok = ref true
      in
        T.seed 20260918;
        T.repeat (n, fn _ => if p (randReal k) then () else ok := false);
        !ok
      end)

  fun law2 (label, n : int, k : int, p : real * real -> bool) : unit =
    T.check (label, fn () =>
      let
        val ok = ref true
      in
        T.seed 918;
        T.repeat (n, fn _ => let val a = randReal k val b = randReal k
                             in if p (a, b) then () else ok := false end);
        !ok
      end)

  (* ---- radix, precision: 64-bit IEEE double ---- *)
  val () = eqI ("Real.radix/two", 2, fn () => Real.radix)
  val () = eqI ("Real.precision/double", 53, fn () => Real.precision)
  (* The precision is what the arithmetic shows: 1 + 2^~52 is representable,
     1 + 2^~53 is a tie that rounds to the even neighbour 1. *)
  val () = T.check ("Real.precision/one-plus-ulp", fn () => Real.> (1.0 + pow2 ~52, 1.0))
  val () = eqR ("Real.precision/one-plus-half-ulp", 1.0, fn () => 1.0 + pow2 ~53)
  val () = T.check ("Real.precision/no-extended-precision",
                    fn () => Real.== ((1.0 + pow2 ~53) - 1.0, 0.0))

  (* ---- maxFinite, minPos, minNormalPos, posInf, negInf ---- *)
  (* maxFinite = (2 - 2^~52) * 2^1023 *)
  val () = eqR ("Real.maxFinite/value", (2.0 - pow2 ~52) * pow2 1023, fn () => Real.maxFinite)
  val () = eqR ("Real.maxFinite/literal", 1.7976931348623157E308, fn () => Real.maxFinite)
  val () = T.check ("Real.maxFinite/is-finite", fn () => Real.isFinite Real.maxFinite)
  val () = eqR ("Real.maxFinite/doubling-overflows", posInf, fn () => Real.maxFinite * 2.0)
  val () = eqR ("Real.maxFinite/plus-ulp-overflows", posInf, fn () => Real.maxFinite + pow2 970)
  val () = eqR ("Real.maxFinite/plus-small-is-absorbed", Real.maxFinite, fn () => Real.maxFinite + 1.0)
  val () = eqR ("Real.minPos/value", pow2 ~1074, fn () => Real.minPos)
  val () = T.check ("Real.minPos/positive", fn () => Real.> (Real.minPos, 0.0))
  (* 2^~1075 is halfway between 0 and minPos: the tie rounds to even, 0. *)
  val () = eqR ("Real.minPos/half-is-zero", 0.0, fn () => Real.minPos / 2.0)
  val () = T.check ("Real.minPos/not-normal", fn () => not (Real.isNormal Real.minPos))
  val () = eqR ("Real.minNormalPos/value", pow2 ~1022, fn () => Real.minNormalPos)
  val () = eqR ("Real.minNormalPos/literal", 2.2250738585072014E~308, fn () => Real.minNormalPos)
  val () = T.check ("Real.minNormalPos/is-normal", fn () => Real.isNormal Real.minNormalPos)
  val () = T.check ("Real.minNormalPos/below-is-subnormal",
                    fn () => let val x = Real.minNormalPos - Real.minPos
                             in Real.> (x, 0.0) andalso not (Real.isNormal x) end)
  val () = eqR ("Real.minNormalPos/ratio-to-minPos", pow2 52, fn () => Real.minNormalPos / Real.minPos)
  val () = T.check ("Real.posInf/above-maxFinite", fn () => Real.> (Real.posInf, Real.maxFinite))
  val () = eqR ("Real.posInf/one-over-zero", Real.posInf, fn () => 1.0 / 0.0)
  val () = T.check ("Real.posInf/not-finite", fn () => not (Real.isFinite Real.posInf))
  val () = T.check ("Real.negInf/below-minus-maxFinite", fn () => Real.< (Real.negInf, ~ Real.maxFinite))
  val () = eqR ("Real.negInf/minus-one-over-zero", Real.negInf, fn () => ~1.0 / 0.0)
  val () = eqR ("Real.negInf/negated-posInf", Real.negInf, fn () => ~ Real.posInf)

  (* ---- +, - ---- *)
  val () = eqR ("Real.+/basic", 3.75, fn () => Real.+ (1.5, 2.25))
  val () = eqR ("Real.+/negative", ~0.75, fn () => Real.+ (1.5, ~2.25))
  (* 0.1 + 0.2 in double precision is the successor of 0.3 (the exact sum of the
     two doubles is a tie that rounds to the even mantissa above). *)
  val () = T.check ("Real.+/double-rounding", fn () => Real.> (0.1 + 0.2, 0.3))
  val () = eqR ("Real.+/finite-posInf", posInf, fn () => 5.0 + posInf)
  val () = eqR ("Real.+/finite-negInf", negInf, fn () => negInf + 5.0)
  val () = eqR ("Real.+/posInf-posInf", posInf, fn () => posInf + posInf)
  val () = eqR ("Real.+/negInf-negInf", negInf, fn () => negInf + negInf)
  val () = eqR ("Real.+/posInf-negInf", nan, fn () => posInf + negInf)
  val () = eqR ("Real.+/negInf-posInf", nan, fn () => negInf + posInf)
  val () = eqR ("Real.+/nan-left", nan, fn () => nan + 1.0)
  val () = eqR ("Real.+/nan-right", nan, fn () => 1.0 + nan)
  val () = eqR ("Real.+/overflow-is-posInf", posInf, fn () => Real.maxFinite + Real.maxFinite)
  val () = eqR ("Real.+/zero-plus-negzero", 0.0, fn () => 0.0 + ~0.0)
  val () = eqR ("Real.+/negzero-plus-negzero", ~0.0, fn () => ~0.0 + ~0.0)
  val () = eqR ("Real.-/basic", ~0.75, fn () => Real.- (1.5, 2.25))
  val () = eqR ("Real.-/finite-minus-negInf", posInf, fn () => 5.0 - negInf)
  val () = eqR ("Real.-/finite-minus-posInf", negInf, fn () => 5.0 - posInf)
  val () = eqR ("Real.-/posInf-minus-finite", posInf, fn () => posInf - 5.0)
  val () = eqR ("Real.-/posInf-minus-negInf", posInf, fn () => posInf - negInf)
  val () = eqR ("Real.-/negInf-minus-posInf", negInf, fn () => negInf - posInf)
  val () = eqR ("Real.-/posInf-minus-posInf", nan, fn () => posInf - posInf)
  val () = eqR ("Real.-/negInf-minus-negInf", nan, fn () => negInf - negInf)
  val () = eqR ("Real.-/nan", nan, fn () => 1.0 - nan)
  val () = eqR ("Real.-/equal-operands-give-plus-zero", 0.0, fn () => 2.5 - 2.5)
  val () = law2 ("Real.+/law-commutative", 200, 60, fn (a, b) => Real.== (a + b, b + a))
  val () = law2 ("Real.-/law-is-plus-negation", 200, 60, fn (a, b) => Real.== (a - b, a + ~ b))

  (* ---- *, / ---- *)
  val () = eqR ("Real.*/basic", 3.375, fn () => Real.* (1.5, 2.25))
  val () = eqR ("Real.*/signs", ~6.0, fn () => 2.0 * ~3.0)
  val () = eqR ("Real.*/zero-posInf", nan, fn () => 0.0 * posInf)
  val () = eqR ("Real.*/negInf-zero", nan, fn () => negInf * 0.0)
  val () = eqR ("Real.*/negzero-posInf", nan, fn () => ~0.0 * posInf)
  val () = eqR ("Real.*/negative-negInf", posInf, fn () => ~5.0 * negInf)
  val () = eqR ("Real.*/posInf-negInf", negInf, fn () => posInf * negInf)
  val () = eqR ("Real.*/posInf-posInf", posInf, fn () => posInf * posInf)
  val () = eqR ("Real.*/positive-negInf", negInf, fn () => 5.0 * negInf)
  val () = eqR ("Real.*/nan", nan, fn () => nan * 0.0)
  val () = eqR ("Real.*/overflow", negInf, fn () => Real.maxFinite * ~2.0)
  val () = eqR ("Real.*/underflow-to-zero", 0.0, fn () => Real.minPos * 0.25)
  val () = eqR ("Real.*/negative-underflow-to-negzero", ~0.0, fn () => Real.minPos * ~0.25)
  val () = eqR ("Real.*/signed-zero", ~0.0, fn () => 0.0 * ~3.0)
  val () = eqR ("Real.//basic", 0.75, fn () => Real./ (1.5, 2.0))
  val () = eqR ("Real.//zero-by-zero", nan, fn () => 0.0 / 0.0)
  val () = eqR ("Real.//posInf-by-posInf", nan, fn () => posInf / posInf)
  val () = eqR ("Real.//negInf-by-posInf", nan, fn () => negInf / posInf)
  val () = eqR ("Real.//posInf-by-negInf", nan, fn () => posInf / negInf)
  val () = eqR ("Real.//finite-by-zero", posInf, fn () => 3.0 / 0.0)
  val () = eqR ("Real.//negative-by-zero", negInf, fn () => ~3.0 / 0.0)
  val () = eqR ("Real.//finite-by-negzero", negInf, fn () => 3.0 / ~0.0)
  val () = eqR ("Real.//negative-by-negzero", posInf, fn () => ~3.0 / ~0.0)
  val () = eqR ("Real.//posInf-by-finite", posInf, fn () => posInf / 3.0)
  val () = eqR ("Real.//posInf-by-negative", negInf, fn () => posInf / ~3.0)
  val () = eqR ("Real.//negInf-by-zero", negInf, fn () => negInf / 0.0)
  val () = eqR ("Real.//finite-by-posInf", 0.0, fn () => 3.0 / posInf)
  val () = eqR ("Real.//negative-by-posInf", ~0.0, fn () => ~3.0 / posInf)
  val () = eqR ("Real.//finite-by-negInf", ~0.0, fn () => 3.0 / negInf)
  val () = eqR ("Real.//negative-by-negInf", 0.0, fn () => ~3.0 / negInf)
  val () = eqR ("Real.//nan", nan, fn () => nan / 1.0)
  (* 1/3 rounded to 53 bits is 6004799503160661 * 2^~54. *)
  val () = eqR ("Real.//correctly-rounded-third", 6004799503160661.0 * pow2 ~54, fn () => 1.0 / 3.0)
  val () = law ("Real.*/law-halving-doubling-exact", 200, 300, fn a => Real.== ((a * 2.0) / 2.0, a))

  (*<< rem *)
  (* "returns the remainder x - n*y, where n = trunc (x / y). The result has the
     same sign as x and has absolute value less than the absolute value of y." *)
  val () = eqR ("Real.rem/basic", 1.5, fn () => Real.rem (5.5, 2.0))
  val () = eqR ("Real.rem/negative-x", ~1.5, fn () => Real.rem (~5.5, 2.0))
  val () = eqR ("Real.rem/negative-y", 1.5, fn () => Real.rem (5.5, ~2.0))
  val () = eqR ("Real.rem/both-negative", ~1.5, fn () => Real.rem (~5.5, ~2.0))
  val () = eqR ("Real.rem/x-smaller-than-y", 0.75, fn () => Real.rem (0.75, 2.0))
  val () = eqR ("Real.rem/exact-multiple", 0.0, fn () => Real.rem (6.0, 3.0))
  (* x - n*y is +0 here while "the result has the same sign as x": the sign of
     a zero remainder is left open. *)
  val () = T.check ("Real.rem/exact-multiple-negative-x", fn () => Real.== (Real.rem (~6.0, 3.0), 0.0))
  val () = eqR ("Real.rem/fractional-y", 0.25, fn () => Real.rem (1.75, 0.5))
  val () = eqR ("Real.rem/posInf-x", nan, fn () => Real.rem (posInf, 2.0))
  val () = eqR ("Real.rem/negInf-x", nan, fn () => Real.rem (negInf, 2.0))
  val () = eqR ("Real.rem/zero-y", nan, fn () => Real.rem (5.0, 0.0))
  val () = eqR ("Real.rem/negzero-y", nan, fn () => Real.rem (5.0, ~0.0))
  val () = eqR ("Real.rem/zero-by-zero", nan, fn () => Real.rem (0.0, 0.0))
  val () = eqR ("Real.rem/posInf-y", 5.0, fn () => Real.rem (5.0, posInf))
  val () = eqR ("Real.rem/negInf-y", ~5.0, fn () => Real.rem (~5.0, negInf))
  val () = eqR ("Real.rem/zero-x-posInf-y", 0.0, fn () => Real.rem (0.0, posInf))
  val () = eqR ("Real.rem/both-infinite", nan, fn () => Real.rem (posInf, posInf))
  val () = eqR ("Real.rem/nan-x", nan, fn () => Real.rem (nan, 2.0))
  val () = eqR ("Real.rem/nan-y", nan, fn () => Real.rem (2.0, nan))
  (* The quotient need not fit in an int: (2^100 + 3 * 2^50) / 2^51 is
     2^49 + 1.5, so n = 2^49 + 1 and the remainder is 2^50; every step of
     x - n*y is exact. *)
  val () = eqR ("Real.rem/large-quotient", pow2 50, fn () => Real.rem (pow2 100 + 3.0 * pow2 50, pow2 51))
  val () = eqR ("Real.rem/huge-exact-quotient", 0.0, fn () => Real.rem (pow2 200 + pow2 150, pow2 100))
  (* On quarters of small integers x - n*y is exact and is the integer rem. *)
  val () = T.check ("Real.rem/law-agrees-with-Int-rem", fn () =>
             let val ok = ref true
             in T.seed 5;
                T.repeat (300, fn _ =>
                  let val a = T.range (~100000, 100000) val b = T.range (1, 1000)
                      val r = Real.rem (Real.fromInt a / 4.0, Real.fromInt b / 4.0)
                  in if Real.== (r, Real.fromInt (Int.rem (a, b)) / 4.0) then () else ok := false end);
                !ok end)
  val () = law2 ("Real.rem/law-sign-and-magnitude", 300, 40,
                 fn (x, y) => let val r = Real.rem (x, y)
                              in Real.< (Real.abs r, Real.abs y)
                                 andalso (Real.== (r, 0.0) orelse Real.signBit r = Real.signBit x) end)
  (*>> rem *)

  (*<< muladd *)
  (* "These return a*b + c and a*b - c"; the operands below make every
     intermediate result exact, so a fused operation gives the same value. *)
  val () = eqR ("Real.*+/basic", 10.0, fn () => Real.*+ (2.0, 3.0, 4.0))
  val () = eqR ("Real.*+/negative", ~2.5, fn () => Real.*+ (~2.0, 3.0, 3.5))
  val () = eqR ("Real.*+/posInf-product", posInf, fn () => Real.*+ (posInf, 2.0, 1.0))
  val () = eqR ("Real.*+/posInf-times-zero", nan, fn () => Real.*+ (posInf, 0.0, 1.0))
  val () = eqR ("Real.*+/posInf-plus-negInf", nan, fn () => Real.*+ (posInf, 1.0, negInf))
  val () = eqR ("Real.*+/finite-plus-negInf", negInf, fn () => Real.*+ (2.0, 3.0, negInf))
  val () = eqR ("Real.*+/nan", nan, fn () => Real.*+ (nan, 1.0, 1.0))
  val () = eqR ("Real.*-/basic", 2.0, fn () => Real.*- (2.0, 3.0, 4.0))
  val () = eqR ("Real.*-/negative", ~9.5, fn () => Real.*- (~2.0, 3.0, 3.5))
  val () = eqR ("Real.*-/posInf-minus-posInf", nan, fn () => Real.*- (posInf, 1.0, posInf))
  val () = eqR ("Real.*-/posInf-minus-negInf", posInf, fn () => Real.*- (posInf, 1.0, negInf))
  val () = eqR ("Real.*-/finite-minus-posInf", negInf, fn () => Real.*- (2.0, 3.0, posInf))
  val () = eqR ("Real.*-/nan", nan, fn () => Real.*- (1.0, 1.0, nan))
  val () = T.check ("Real.*+/law-small-integers", fn () =>
             let val ok = ref true
             in T.seed 7;
                T.repeat (200, fn _ =>
                  let val a = T.range (~1000, 1000) val b = T.range (~1000, 1000) val c = T.range (~1000, 1000)
                      val (ra, rb, rc) = (Real.fromInt a, Real.fromInt b, Real.fromInt c)
                  in if Real.== (Real.*+ (ra, rb, rc), Real.fromInt (a * b + c))
                        andalso Real.== (Real.*- (ra, rb, rc), Real.fromInt (a * b - c))
                     then () else ok := false end);
                !ok end)
  (*>> muladd *)

  (* ---- ~, abs ---- *)
  val () = eqR ("Real.~/basic", ~1.5, fn () => Real.~ 1.5)
  val () = eqR ("Real.~/negative", 1.5, fn () => Real.~ (~1.5))
  val () = eqR ("Real.~/posInf", negInf, fn () => Real.~ posInf)
  val () = eqR ("Real.~/negInf", posInf, fn () => Real.~ negInf)
  val () = eqR ("Real.~/zero", ~0.0, fn () => Real.~ 0.0)
  val () = eqR ("Real.~/negzero", 0.0, fn () => Real.~ (~0.0))
  val () = eqR ("Real.~/nan", nan, fn () => Real.~ nan)
  (* "~x ... is identical to x but with its sign bit flipped" *)
  val () = eqB ("Real.~/flips-nan-sign", true, fn () => Real.signBit (Real.~ (posNan ())))
  val () = T.check ("Real.~/zero-literal-has-sign-bit", fn () => Real.signBit (~0.0))
  val () = eqR ("Real.abs/positive", 1.5, fn () => Real.abs 1.5)
  val () = eqR ("Real.abs/negative", 1.5, fn () => Real.abs (~1.5))
  val () = eqR ("Real.abs/zero", 0.0, fn () => Real.abs 0.0)
  val () = eqR ("Real.abs/negzero", 0.0, fn () => Real.abs (~0.0))
  val () = eqR ("Real.abs/posInf", posInf, fn () => Real.abs posInf)
  val () = eqR ("Real.abs/negInf", posInf, fn () => Real.abs negInf)
  val () = eqR ("Real.abs/nan", nan, fn () => Real.abs nan)
  val () = eqB ("Real.abs/negative-nan-sign-cleared", false, fn () => Real.signBit (Real.abs (negNan ())))
  val () = eqR ("Real.abs/toplevel", 2.5, fn () => abs (~2.5))

  (* ---- min, max ---- *)
  val () = eqR ("Real.min/basic", 1.0, fn () => Real.min (1.0, 2.0))
  val () = eqR ("Real.min/swapped", 1.0, fn () => Real.min (2.0, 1.0))
  val () = eqR ("Real.min/negative", ~2.0, fn () => Real.min (~2.0, 1.0))
  val () = eqR ("Real.min/negInf", negInf, fn () => Real.min (negInf, 1.0))
  val () = eqR ("Real.min/posInf", 1.0, fn () => Real.min (posInf, 1.0))
  val () = eqR ("Real.min/nan-left", 1.0, fn () => Real.min (nan, 1.0))
  val () = eqR ("Real.min/nan-right", 1.0, fn () => Real.min (1.0, nan))
  val () = eqR ("Real.min/nan-and-posInf", posInf, fn () => Real.min (nan, posInf))
  val () = eqR ("Real.min/nan-both", nan, fn () => Real.min (nan, nan))
  val () = T.check ("Real.min/zeros", fn () => Real.== (Real.min (0.0, ~0.0), 0.0))
  val () = eqR ("Real.max/basic", 2.0, fn () => Real.max (1.0, 2.0))
  val () = eqR ("Real.max/swapped", 2.0, fn () => Real.max (2.0, 1.0))
  val () = eqR ("Real.max/negative", ~1.0, fn () => Real.max (~2.0, ~1.0))
  val () = eqR ("Real.max/posInf", posInf, fn () => Real.max (posInf, 1.0))
  val () = eqR ("Real.max/negInf", 1.0, fn () => Real.max (negInf, 1.0))
  val () = eqR ("Real.max/nan-left", 1.0, fn () => Real.max (nan, 1.0))
  val () = eqR ("Real.max/nan-right", 1.0, fn () => Real.max (1.0, nan))
  val () = eqR ("Real.max/nan-and-negInf", negInf, fn () => Real.max (negInf, nan))
  val () = eqR ("Real.max/nan-both", nan, fn () => Real.max (nan, nan))
  val () = law2 ("Real.min/law-min-le-max", 200, 100,
                 fn (a, b) => Real.<= (Real.min (a, b), Real.max (a, b))
                              andalso Real.== (Real.min (a, b) + Real.max (a, b), a + b))

  (* ---- sign, signBit, sameSign, copySign ---- *)
  val () = eqI ("Real.sign/positive", 1, fn () => Real.sign 3.5)
  val () = eqI ("Real.sign/negative", ~1, fn () => Real.sign (~3.5))
  val () = eqI ("Real.sign/zero", 0, fn () => Real.sign 0.0)
  val () = eqI ("Real.sign/negzero", 0, fn () => Real.sign (~0.0))
  val () = eqI ("Real.sign/posInf", 1, fn () => Real.sign posInf)
  val () = eqI ("Real.sign/negInf", ~1, fn () => Real.sign negInf)
  val () = eqI ("Real.sign/minPos", 1, fn () => Real.sign Real.minPos)
  val () = eqI ("Real.sign/minus-minPos", ~1, fn () => Real.sign (~ Real.minPos))
  val () = T.raises ("Real.sign/Domain-nan", T.isDomain, fn () => Real.sign nan)
  val () = eqB ("Real.signBit/positive", false, fn () => Real.signBit 1.0)
  val () = eqB ("Real.signBit/negative", true, fn () => Real.signBit (~1.0))
  val () = eqB ("Real.signBit/zero", false, fn () => Real.signBit 0.0)
  val () = eqB ("Real.signBit/negzero", true, fn () => Real.signBit (~0.0))
  val () = eqB ("Real.signBit/posInf", false, fn () => Real.signBit posInf)
  val () = eqB ("Real.signBit/negInf", true, fn () => Real.signBit negInf)
  val () = eqB ("Real.signBit/computed-negzero", true, fn () => Real.signBit (0.0 * ~1.0))
  (* "infinities, zeros, and NaN, included" *)
  val () = eqB ("Real.signBit/negative-nan-sign", true, fn () => Real.signBit (negNan ()))
  val () = eqB ("Real.signBit/positive-nan", false, fn () => Real.signBit (posNan ()))
  val () = eqB ("Real.sameSign/both-positive", true, fn () => Real.sameSign (1.0, 2.0))
  val () = eqB ("Real.sameSign/both-negative", true, fn () => Real.sameSign (~1.0, negInf))
  val () = eqB ("Real.sameSign/different", false, fn () => Real.sameSign (~1.0, 2.0))
  val () = eqB ("Real.sameSign/zeros-differ", false, fn () => Real.sameSign (~0.0, 0.0))
  val () = eqB ("Real.sameSign/negzero-negative", true, fn () => Real.sameSign (~0.0, ~5.0))
  val () = eqB ("Real.sameSign/zero-posInf", true, fn () => Real.sameSign (0.0, posInf))
  val () = eqB ("Real.sameSign/differing-nan-sign", false, fn () => Real.sameSign (negNan (), posNan ()))
  val () = eqR ("Real.copySign/to-negative", ~3.0, fn () => Real.copySign (3.0, ~1.0))
  val () = eqR ("Real.copySign/to-positive", 3.0, fn () => Real.copySign (~3.0, 1.0))
  val () = eqR ("Real.copySign/unchanged", ~3.0, fn () => Real.copySign (~3.0, ~7.0))
  val () = eqR ("Real.copySign/sign-of-negzero", ~3.0, fn () => Real.copySign (3.0, ~0.0))
  val () = eqR ("Real.copySign/sign-of-zero", 3.0, fn () => Real.copySign (~3.0, 0.0))
  val () = eqR ("Real.copySign/zero", ~0.0, fn () => Real.copySign (0.0, ~1.0))
  val () = eqR ("Real.copySign/negzero", 0.0, fn () => Real.copySign (~0.0, 1.0))
  val () = eqR ("Real.copySign/posInf", negInf, fn () => Real.copySign (posInf, ~1.0))
  val () = eqR ("Real.copySign/sign-of-negInf", ~1.0, fn () => Real.copySign (1.0, negInf))
  (* "even if y is NaN" *)
  val () = eqR ("Real.copySign/from-negative-nan-sign", ~1.0, fn () => Real.copySign (1.0, negNan ()))
  val () = eqR ("Real.copySign/sign-of-positive-nan", 1.0, fn () => Real.copySign (~1.0, posNan ()))
  val () = eqR ("Real.copySign/nan", nan, fn () => Real.copySign (nan, ~1.0))
  val () = law2 ("Real.copySign/law-sign-and-magnitude", 200, 300,
                 fn (x, y) => let val r = Real.copySign (x, y)
                              in Real.signBit r = Real.signBit y andalso Real.== (Real.abs r, Real.abs x) end)
  val () = law2 ("Real.sameSign/law-is-signBit-equality", 200, 300,
                 fn (x, y) => Real.sameSign (x, y) = (Real.signBit x = Real.signBit y))
  val () = law ("Real.signBit/law-is-negative", 200, 300, fn x => Real.signBit x = Real.< (x, 0.0))
  val () = law ("Real.sign/law-matches-comparison", 200, 300,
                fn x => Real.sign x = (if Real.< (x, 0.0) then ~1 else 1))

  (* ---- compare ---- *)
  val () = eqOrd ("Real.compare/less", LESS, fn () => Real.compare (1.0, 2.0))
  val () = eqOrd ("Real.compare/equal", EQUAL, fn () => Real.compare (2.0, 2.0))
  val () = eqOrd ("Real.compare/greater", GREATER, fn () => Real.compare (2.0, 1.0))
  val () = eqOrd ("Real.compare/zeros-equal", EQUAL, fn () => Real.compare (0.0, ~0.0))
  val () = eqOrd ("Real.compare/infinities", LESS, fn () => Real.compare (negInf, posInf))
  val () = eqOrd ("Real.compare/posInf-equal", EQUAL, fn () => Real.compare (posInf, posInf))
  val () = eqOrd ("Real.compare/maxFinite-posInf", LESS, fn () => Real.compare (Real.maxFinite, posInf))
  val () = eqOrd ("Real.compare/subnormals", GREATER, fn () => Real.compare (Real.minPos, 0.0))
  (* The exception itself is checked in section unordered-exn. *)
  val () = T.raises ("Real.compare/nan-left-raises", T.anyExn, fn () => Real.compare (nan, 1.0))
  val () = T.raises ("Real.compare/nan-right-raises", T.anyExn, fn () => Real.compare (1.0, nan))
  val () = T.raises ("Real.compare/nan-both-raises", T.anyExn, fn () => Real.compare (nan, nan))

  (*<< unordered-exn *)
  (* "It raises IEEEReal.Unordered on unordered arguments." *)
  val isUnordered = fn IEEEReal.Unordered => true | _ => false
  val () = T.raises ("Real.compare/Unordered-nan-left", isUnordered, fn () => Real.compare (nan, 1.0))
  val () = T.raises ("Real.compare/Unordered-nan-right", isUnordered, fn () => Real.compare (posInf, nan))
  val () = T.raises ("Real.compare/Unordered-nan-both", isUnordered, fn () => Real.compare (nan, nan))
  (*>> unordered-exn *)

  (*<< comparereal *)
  fun showRealOrder IEEEReal.LESS = "LESS"
    | showRealOrder IEEEReal.EQUAL = "EQUAL"
    | showRealOrder IEEEReal.GREATER = "GREATER"
    | showRealOrder IEEEReal.UNORDERED = "UNORDERED"
  val eqRO = T.eq showRealOrder
  val () = eqRO ("Real.compareReal/less", IEEEReal.LESS, fn () => Real.compareReal (1.0, 2.0))
  val () = eqRO ("Real.compareReal/equal", IEEEReal.EQUAL, fn () => Real.compareReal (2.0, 2.0))
  val () = eqRO ("Real.compareReal/greater", IEEEReal.GREATER, fn () => Real.compareReal (2.0, 1.0))
  val () = eqRO ("Real.compareReal/zeros-equal", IEEEReal.EQUAL, fn () => Real.compareReal (~0.0, 0.0))
  val () = eqRO ("Real.compareReal/infinities", IEEEReal.GREATER, fn () => Real.compareReal (posInf, negInf))
  val () = eqRO ("Real.compareReal/nan-left", IEEEReal.UNORDERED, fn () => Real.compareReal (nan, 1.0))
  val () = eqRO ("Real.compareReal/nan-right", IEEEReal.UNORDERED, fn () => Real.compareReal (1.0, nan))
  val () = eqRO ("Real.compareReal/nan-both", IEEEReal.UNORDERED, fn () => Real.compareReal (nan, nan))
  val () = law2 ("Real.compareReal/law-agrees-with-compare", 200, 5,
                 fn (a, b) => (case (Real.compareReal (a, b), Real.compare (a, b)) of
                                 (IEEEReal.LESS, LESS) => true
                               | (IEEEReal.EQUAL, EQUAL) => true
                               | (IEEEReal.GREATER, GREATER) => true
                               | _ => false))
  (*>> comparereal *)

  (* ---- <, <=, >, >= ---- *)
  val () = eqB ("Real.</less", true, fn () => Real.< (1.0, 2.0))
  val () = eqB ("Real.</equal", false, fn () => Real.< (2.0, 2.0))
  val () = eqB ("Real.</greater", false, fn () => Real.< (2.0, 1.0))
  val () = eqB ("Real.</zeros", false, fn () => Real.< (~0.0, 0.0))
  val () = eqB ("Real.</negInf-posInf", true, fn () => Real.< (negInf, posInf))
  val () = eqB ("Real.</maxFinite-posInf", true, fn () => Real.< (Real.maxFinite, posInf))
  val () = eqB ("Real.</nan-left", false, fn () => Real.< (nan, 1.0))
  val () = eqB ("Real.</nan-right", false, fn () => Real.< (1.0, nan))
  val () = eqB ("Real.</nan-posInf", false, fn () => Real.< (nan, posInf))
  val () = eqB ("Real.<=/less", true, fn () => Real.<= (1.0, 2.0))
  val () = eqB ("Real.<=/equal", true, fn () => Real.<= (2.0, 2.0))
  val () = eqB ("Real.<=/greater", false, fn () => Real.<= (2.0, 1.0))
  val () = eqB ("Real.<=/zeros", true, fn () => Real.<= (0.0, ~0.0))
  val () = eqB ("Real.<=/posInf-posInf", true, fn () => Real.<= (posInf, posInf))
  val () = eqB ("Real.<=/nan-left", false, fn () => Real.<= (nan, 1.0))
  val () = eqB ("Real.<=/nan-right", false, fn () => Real.<= (1.0, nan))
  val () = eqB ("Real.<=/nan-both", false, fn () => Real.<= (nan, nan))
  val () = eqB ("Real.>/greater", true, fn () => Real.> (2.0, 1.0))
  val () = eqB ("Real.>/equal", false, fn () => Real.> (2.0, 2.0))
  val () = eqB ("Real.>/less", false, fn () => Real.> (1.0, 2.0))
  val () = eqB ("Real.>/zeros", false, fn () => Real.> (0.0, ~0.0))
  val () = eqB ("Real.>/posInf-maxFinite", true, fn () => Real.> (posInf, Real.maxFinite))
  val () = eqB ("Real.>/nan-left", false, fn () => Real.> (nan, 1.0))
  val () = eqB ("Real.>/nan-right", false, fn () => Real.> (1.0, nan))
  val () = eqB ("Real.>=/greater", true, fn () => Real.>= (2.0, 1.0))
  val () = eqB ("Real.>=/equal", true, fn () => Real.>= (2.0, 2.0))
  val () = eqB ("Real.>=/less", false, fn () => Real.>= (1.0, 2.0))
  val () = eqB ("Real.>=/zeros", true, fn () => Real.>= (~0.0, 0.0))
  val () = eqB ("Real.>=/nan-left", false, fn () => Real.>= (nan, 1.0))
  val () = eqB ("Real.>=/nan-right", false, fn () => Real.>= (1.0, nan))
  val () = eqB ("Real.>=/nan-both", false, fn () => Real.>= (nan, nan))
  (* "a < b is not the same as not (a >= b)" *)
  val () = T.check ("Real.</no-reversal-with-nan",
                    fn () => not (Real.< (nan, 1.0)) andalso not (Real.>= (nan, 1.0)))
  val () = eqB ("Real.</toplevel-overloaded", true, fn () => 1.5 < 2.5 andalso 2.5 > 1.5 andalso 1.5 <= 1.5 andalso 1.5 >= 1.5)
  val () = law2 ("Real.</law-trichotomy", 300, 3,
                 fn (a, b) => (case Real.compare (a, b) of
                                 LESS => Real.< (a, b) andalso Real.<= (a, b) andalso not (Real.> (a, b)) andalso not (Real.>= (a, b))
                               | EQUAL => Real.<= (a, b) andalso Real.>= (a, b) andalso not (Real.< (a, b)) andalso not (Real.> (a, b))
                               | GREATER => Real.> (a, b) andalso Real.>= (a, b) andalso not (Real.< (a, b)) andalso not (Real.<= (a, b))))

  (* ---- ==, != ---- *)
  val () = eqB ("Real.==/equal", true, fn () => Real.== (1.5, 1.5))
  val () = eqB ("Real.==/different", false, fn () => Real.== (1.5, 2.5))
  val () = eqB ("Real.==/zeros", true, fn () => Real.== (0.0, ~0.0))
  val () = eqB ("Real.==/posInf", true, fn () => Real.== (posInf, posInf))
  val () = eqB ("Real.==/infinities", false, fn () => Real.== (posInf, negInf))
  val () = eqB ("Real.==/nan-nan", false, fn () => Real.== (nan, nan))
  val () = eqB ("Real.==/nan-left", false, fn () => Real.== (nan, 1.0))
  val () = eqB ("Real.==/nan-right", false, fn () => Real.== (1.0, nan))
  val () = eqB ("Real.!=/equal", false, fn () => Real.!= (1.5, 1.5))
  val () = eqB ("Real.!=/different", true, fn () => Real.!= (1.5, 2.5))
  val () = eqB ("Real.!=/zeros", false, fn () => Real.!= (0.0, ~0.0))
  val () = eqB ("Real.!=/nan-nan", true, fn () => Real.!= (nan, nan))
  val () = eqB ("Real.!=/nan-left", true, fn () => Real.!= (nan, 1.0))
  val () = eqB ("Real.!=/nan-right", true, fn () => Real.!= (1.0, nan))
  val () = law2 ("Real.!=/law-is-not-equal", 200, 2, fn (a, b) => Real.!= (a, b) = not (Real.== (a, b)))

  (*<< qeq *)
  (* "returns true if either argument is NaN or if the arguments are bitwise
     equal, ignoring signs on zeros" *)
  val () = eqB ("Real.?=/equal", true, fn () => Real.?= (1.5, 1.5))
  val () = eqB ("Real.?=/different", false, fn () => Real.?= (1.5, 2.5))
  val () = eqB ("Real.?=/zeros", true, fn () => Real.?= (0.0, ~0.0))
  val () = eqB ("Real.?=/nan-left", true, fn () => Real.?= (nan, 1.5))
  val () = eqB ("Real.?=/nan-right", true, fn () => Real.?= (1.5, nan))
  val () = eqB ("Real.?=/nan-both", true, fn () => Real.?= (nan, nan))
  val () = eqB ("Real.?=/infinities", false, fn () => Real.?= (posInf, negInf))
  val () = eqB ("Real.?=/posInf", true, fn () => Real.?= (posInf, posInf))
  (*>> qeq *)

  (*<< unordered *)
  val () = eqB ("Real.unordered/ordered", false, fn () => Real.unordered (1.0, 2.0))
  val () = eqB ("Real.unordered/infinities", false, fn () => Real.unordered (posInf, negInf))
  val () = eqB ("Real.unordered/nan-left", true, fn () => Real.unordered (nan, 1.0))
  val () = eqB ("Real.unordered/nan-right", true, fn () => Real.unordered (1.0, nan))
  val () = eqB ("Real.unordered/nan-both", true, fn () => Real.unordered (nan, nan))
  (*>> unordered *)

  (* ---- isFinite, isNan, isNormal ---- *)
  val () = eqB ("Real.isFinite/ordinary", true, fn () => Real.isFinite 1.5)
  val () = eqB ("Real.isFinite/zero", true, fn () => Real.isFinite 0.0)
  val () = eqB ("Real.isFinite/maxFinite", true, fn () => Real.isFinite (~ Real.maxFinite))
  val () = eqB ("Real.isFinite/minPos", true, fn () => Real.isFinite Real.minPos)
  val () = eqB ("Real.isFinite/posInf", false, fn () => Real.isFinite posInf)
  val () = eqB ("Real.isFinite/negInf", false, fn () => Real.isFinite negInf)
  val () = eqB ("Real.isFinite/nan", false, fn () => Real.isFinite nan)
  val () = eqB ("Real.isNan/nan", true, fn () => Real.isNan nan)
  val () = eqB ("Real.isNan/zero-by-zero", true, fn () => Real.isNan (0.0 / 0.0))
  val () = eqB ("Real.isNan/negative-nan", true, fn () => Real.isNan (negNan ()))
  val () = eqB ("Real.isNan/ordinary", false, fn () => Real.isNan 1.5)
  val () = eqB ("Real.isNan/posInf", false, fn () => Real.isNan posInf)
  val () = eqB ("Real.isNan/negInf", false, fn () => Real.isNan negInf)
  val () = eqB ("Real.isNan/zero", false, fn () => Real.isNan 0.0)
  val () = eqB ("Real.isNormal/ordinary", true, fn () => Real.isNormal ~1.5)
  val () = eqB ("Real.isNormal/maxFinite", true, fn () => Real.isNormal Real.maxFinite)
  val () = eqB ("Real.isNormal/minNormalPos", true, fn () => Real.isNormal Real.minNormalPos)
  val () = eqB ("Real.isNormal/negative-minNormalPos", true, fn () => Real.isNormal (~ Real.minNormalPos))
  val () = eqB ("Real.isNormal/zero", false, fn () => Real.isNormal 0.0)
  val () = eqB ("Real.isNormal/negzero", false, fn () => Real.isNormal (~0.0))
  val () = eqB ("Real.isNormal/largest-subnormal", false, fn () => Real.isNormal (Real.minNormalPos - Real.minPos))
  val () = eqB ("Real.isNormal/minPos", false, fn () => Real.isNormal Real.minPos)
  val () = eqB ("Real.isNormal/negative-subnormal", false, fn () => Real.isNormal (~ (pow2 ~1050)))
  val () = eqB ("Real.isNormal/posInf", false, fn () => Real.isNormal posInf)
  val () = eqB ("Real.isNormal/negInf", false, fn () => Real.isNormal negInf)
  val () = eqB ("Real.isNormal/nan", false, fn () => Real.isNormal nan)

  (*<< class *)
  fun showClass IEEEReal.NAN = "NAN"
    | showClass IEEEReal.INF = "INF"
    | showClass IEEEReal.ZERO = "ZERO"
    | showClass IEEEReal.NORMAL = "NORMAL"
    | showClass IEEEReal.SUBNORMAL = "SUBNORMAL"
  val eqC = T.eq showClass
  val () = eqC ("Real.class/nan", IEEEReal.NAN, fn () => Real.class nan)
  val () = eqC ("Real.class/negative-nan", IEEEReal.NAN, fn () => Real.class (negNan ()))
  val () = eqC ("Real.class/posInf", IEEEReal.INF, fn () => Real.class posInf)
  val () = eqC ("Real.class/negInf", IEEEReal.INF, fn () => Real.class negInf)
  val () = eqC ("Real.class/zero", IEEEReal.ZERO, fn () => Real.class 0.0)
  val () = eqC ("Real.class/negzero", IEEEReal.ZERO, fn () => Real.class (~0.0))
  val () = eqC ("Real.class/normal", IEEEReal.NORMAL, fn () => Real.class 1.5)
  val () = eqC ("Real.class/negative-normal", IEEEReal.NORMAL, fn () => Real.class (~1E300))
  val () = eqC ("Real.class/maxFinite", IEEEReal.NORMAL, fn () => Real.class Real.maxFinite)
  val () = eqC ("Real.class/minNormalPos", IEEEReal.NORMAL, fn () => Real.class Real.minNormalPos)
  val () = eqC ("Real.class/largest-subnormal", IEEEReal.SUBNORMAL, fn () => Real.class (Real.minNormalPos - Real.minPos))
  val () = eqC ("Real.class/minPos", IEEEReal.SUBNORMAL, fn () => Real.class Real.minPos)
  val () = eqC ("Real.class/negative-subnormal", IEEEReal.SUBNORMAL, fn () => Real.class (~ (pow2 ~1050)))
  val () = law ("Real.class/law-agrees-with-predicates", 200, 1000,
                fn x => (case Real.class x of
                           IEEEReal.NORMAL => Real.isNormal x andalso Real.isFinite x
                         | _ => false))
  (*>> class *)

  (*<< manexp *)
  (* "r = man * radix^exp where 1.0 <= man * radix < radix", that is
     0.5 <= |man| < 1.0 for radix 2, as with frexp. *)
  fun eqME (label, me : real * int, f : unit -> {man : real, exp : int}) : unit =
    checkWith (T.pair (T.real, T.int), fn ((m, e), (m', e')) => T.sameReal (m, m') andalso e = e')
              (label, me, fn () => let val {man, exp} = f () in (man, exp) end)
  val () = eqME ("Real.toManExp/one", (0.5, 1), fn () => Real.toManExp 1.0)
  val () = eqME ("Real.toManExp/eight", (0.5, 4), fn () => Real.toManExp 8.0)
  val () = eqME ("Real.toManExp/three-quarters", (0.75, 0), fn () => Real.toManExp 0.75)
  val () = eqME ("Real.toManExp/negative", (~0.75, 4), fn () => Real.toManExp (~12.0))
  val () = eqME ("Real.toManExp/small", (0.625, ~3), fn () => Real.toManExp 0.078125)
  val () = eqME ("Real.toManExp/zero", (0.0, 0), fn () => Real.toManExp 0.0)
  val () = eqME ("Real.toManExp/negzero", (~0.0, 0), fn () => Real.toManExp (~0.0))
  val () = eqME ("Real.toManExp/maxFinite", (1.0 - pow2 ~53, 1024), fn () => Real.toManExp Real.maxFinite)
  val () = eqME ("Real.toManExp/minNormalPos", (0.5, ~1021), fn () => Real.toManExp Real.minNormalPos)
  val () = eqME ("Real.toManExp/minPos", (0.5, ~1073), fn () => Real.toManExp Real.minPos)
  (* ~3 * 2^~1074 = ~0.75 * 2^~1072 *)
  val () = eqME ("Real.toManExp/subnormal", (~0.75, ~1072), fn () => Real.toManExp (~3.0 * Real.minPos))
  val () = eqR ("Real.toManExp/posInf-man", posInf, fn () => #man (Real.toManExp posInf))
  val () = eqR ("Real.toManExp/negInf-man", negInf, fn () => #man (Real.toManExp negInf))
  val () = eqR ("Real.toManExp/nan-man", nan, fn () => #man (Real.toManExp nan))
  val () = eqR ("Real.fromManExp/one", 1.0, fn () => Real.fromManExp {man = 0.5, exp = 1})
  val () = eqR ("Real.fromManExp/unnormalized-man", 12.0, fn () => Real.fromManExp {man = 3.0, exp = 2})
  val () = eqR ("Real.fromManExp/negative-man", ~0.375, fn () => Real.fromManExp {man = ~1.5, exp = ~2})
  val () = eqR ("Real.fromManExp/zero-exp", 1.25, fn () => Real.fromManExp {man = 1.25, exp = 0})
  val () = eqR ("Real.fromManExp/maxFinite", Real.maxFinite, fn () => Real.fromManExp {man = 1.0 - pow2 ~53, exp = 1024})
  val () = eqR ("Real.fromManExp/minPos", Real.minPos, fn () => Real.fromManExp {man = 0.5, exp = ~1073})
  (* "the result of fromManExp can be zero or infinity because of underflows and overflows" *)
  val () = eqR ("Real.fromManExp/overflow", posInf, fn () => Real.fromManExp {man = 0.5, exp = 1025})
  val () = eqR ("Real.fromManExp/negative-overflow", negInf, fn () => Real.fromManExp {man = ~1.0, exp = 100000})
  val () = eqR ("Real.fromManExp/underflow", 0.0, fn () => Real.fromManExp {man = 0.5, exp = ~1074})
  val () = eqR ("Real.fromManExp/far-underflow", 0.0, fn () => Real.fromManExp {man = 1.0, exp = ~100000})
  val () = T.check ("Real.fromManExp/negative-underflow",
                    fn () => Real.== (Real.fromManExp {man = ~1.0, exp = ~100000}, 0.0))
  (* man * 2^exp is representable although 2^exp is not. *)
  val () = eqR ("Real.fromManExp/wide-exp-up", 1.0, fn () => Real.fromManExp {man = Real.minPos, exp = 1074})
  val () = eqR ("Real.fromManExp/wide-exp-subnormal-to-large", pow2 1000, fn () => Real.fromManExp {man = Real.minPos, exp = 2074})
  val () = eqR ("Real.fromManExp/zero-man", 0.0, fn () => Real.fromManExp {man = 0.0, exp = 5})
  val () = eqR ("Real.fromManExp/negzero-man", ~0.0, fn () => Real.fromManExp {man = ~0.0, exp = 5})
  val () = eqR ("Real.fromManExp/posInf-man", posInf, fn () => Real.fromManExp {man = posInf, exp = ~5})
  val () = eqR ("Real.fromManExp/negInf-man", negInf, fn () => Real.fromManExp {man = negInf, exp = 5})
  val () = eqR ("Real.fromManExp/nan-man", nan, fn () => Real.fromManExp {man = nan, exp = 5})
  val () = law ("Real.toManExp/law-man-in-range", 300, 1000,
                fn x => let val {man, exp = _} = Real.toManExp x
                        in Real.<= (0.5, Real.abs man) andalso Real.< (Real.abs man, 1.0)
                           andalso Real.signBit man = Real.signBit x end)
  val () = law ("Real.fromManExp/law-inverts-toManExp", 300, 1000,
                fn x => T.sameReal (Real.fromManExp (Real.toManExp x), x))
  val () = law ("Real.toManExp/law-exp-is-scale", 300, 1000,
                fn x => let val {man, exp} = Real.toManExp x
                        in T.sameReal (Real.fromManExp {man = man, exp = exp + 3}, x * 8.0)
                           andalso #exp (Real.toManExp (x * 8.0)) = exp + 3 end)
  (*>> manexp *)

  (*<< manexp-huge *)
  (* A man of 2^1023 or more. SML/NJ 110.79 does not normalise such a real in
     toManExp (it returns {man = r, exp = 0}) and its fromManExp, which
     normalises man with toManExp, then loops forever; normalised is the probe
     that makes these checks fail instead of hanging there. *)
  fun normalised (x : real) : bool =
    let val {man, exp = _} = Real.toManExp x
    in Real.<= (0.5, Real.abs man) andalso Real.< (Real.abs man, 1.0) end
  fun guarded (x : real, f : unit -> real) : real =
    if normalised x then f () else raise Fail "toManExp does not normalise its argument"
  val () = T.check ("Real.toManExp/huge-two-to-the-1023rd",
                    fn () => let val {man, exp} = Real.toManExp (pow2 1023)
                             in T.sameReal (man, 0.5) andalso exp = 1024 end)
  val () = eqR ("Real.fromManExp/huge-man-wide-exp-down", 2.0 - pow2 ~52,
                fn () => guarded (Real.maxFinite, fn () => Real.fromManExp {man = Real.maxFinite, exp = ~1023}))
  val () = eqR ("Real.fromManExp/huge-man-zero-exp", ~ (pow2 1023),
                fn () => guarded (pow2 1023, fn () => Real.fromManExp {man = ~ (pow2 1023), exp = 0}))
  val () = eqR ("Real.fromManExp/huge-man-overflow", posInf,
                fn () => guarded (Real.maxFinite, fn () => Real.fromManExp {man = Real.maxFinite, exp = 1}))
  (*>> manexp-huge *)

  (*<< split *)
  (* "whole is integral, |frac| < 1.0, whole and frac have the same sign as r,
     and r = whole + frac" *)
  fun eqWF (label, wf : real * real, f : unit -> {whole : real, frac : real}) : unit =
    checkWith (showPair, samePair) (label, wf, fn () => let val {whole, frac} = f () in (whole, frac) end)
  val () = eqWF ("Real.split/basic", (3.0, 0.75), fn () => Real.split 3.75)
  val () = eqWF ("Real.split/negative", (~3.0, ~0.75), fn () => Real.split (~3.75))
  val () = eqWF ("Real.split/fraction-only", (0.0, 0.25), fn () => Real.split 0.25)
  val () = eqWF ("Real.split/negative-fraction-only", (~0.0, ~0.25), fn () => Real.split (~0.25))
  val () = eqWF ("Real.split/integral", (5.0, 0.0), fn () => Real.split 5.0)
  val () = eqWF ("Real.split/negative-integral", (~5.0, ~0.0), fn () => Real.split (~5.0))
  val () = eqWF ("Real.split/zero", (0.0, 0.0), fn () => Real.split 0.0)
  val () = eqWF ("Real.split/negzero", (~0.0, ~0.0), fn () => Real.split (~0.0))
  val () = eqWF ("Real.split/huge", (1E300, 0.0), fn () => Real.split 1E300)
  val () = eqWF ("Real.split/largest-fraction", (4503599627370495.0, 0.5), fn () => Real.split 4503599627370495.5)
  val () = eqWF ("Real.split/minPos", (0.0, Real.minPos), fn () => Real.split Real.minPos)
  val () = eqWF ("Real.split/posInf", (posInf, 0.0), fn () => Real.split posInf)
  val () = eqWF ("Real.split/negInf", (negInf, ~0.0), fn () => Real.split negInf)
  val () = eqWF ("Real.split/nan", (nan, nan), fn () => Real.split nan)
  val () = eqR ("Real.realMod/basic", 0.75, fn () => Real.realMod 3.75)
  val () = eqR ("Real.realMod/negative", ~0.75, fn () => Real.realMod (~3.75))
  val () = eqR ("Real.realMod/integral", 0.0, fn () => Real.realMod 5.0)
  val () = eqR ("Real.realMod/negative-integral", ~0.0, fn () => Real.realMod (~5.0))
  val () = eqR ("Real.realMod/huge", 0.0, fn () => Real.realMod 1E300)
  val () = eqR ("Real.realMod/posInf", 0.0, fn () => Real.realMod posInf)
  val () = eqR ("Real.realMod/negInf", ~0.0, fn () => Real.realMod negInf)
  val () = eqR ("Real.realMod/nan", nan, fn () => Real.realMod nan)
  val () = law ("Real.split/law-parts", 300, 60,
                fn x => let val {whole, frac} = Real.split x
                        in Real.== (whole + frac, x) andalso Real.< (Real.abs frac, 1.0)
                           andalso Real.signBit whole = Real.signBit x
                           andalso Real.signBit frac = Real.signBit x
                           andalso Real.== (whole, Real.realTrunc x) end)
  val () = law ("Real.realMod/law-is-frac-of-split", 300, 60,
                fn x => T.sameReal (Real.realMod x, #frac (Real.split x)))
  (*>> split *)

  (*<< nextafter *)
  val () = eqR ("Real.nextAfter/up-from-one", 1.0 + pow2 ~52, fn () => Real.nextAfter (1.0, 2.0))
  val () = eqR ("Real.nextAfter/down-from-one", 1.0 - pow2 ~53, fn () => Real.nextAfter (1.0, 0.0))
  val () = eqR ("Real.nextAfter/towards-posInf", 1.0 + pow2 ~52, fn () => Real.nextAfter (1.0, posInf))
  val () = eqR ("Real.nextAfter/towards-negInf", 1.0 - pow2 ~53, fn () => Real.nextAfter (1.0, negInf))
  val () = eqR ("Real.nextAfter/negative-up", ~1.0 + pow2 ~53, fn () => Real.nextAfter (~1.0, 0.0))
  val () = eqR ("Real.nextAfter/negative-down", ~1.0 - pow2 ~52, fn () => Real.nextAfter (~1.0, ~2.0))
  val () = eqR ("Real.nextAfter/equal", 1.0, fn () => Real.nextAfter (1.0, 1.0))
  (* "If r = t then it returns r", and "the sign of a zero is ignored in all
     comparisons"; which zero comes back is not checked (C returns t). *)
  val () = T.check ("Real.nextAfter/equal-zeros", fn () => Real.== (Real.nextAfter (0.0, ~0.0), 0.0))
  val () = eqR ("Real.nextAfter/zero-up", Real.minPos, fn () => Real.nextAfter (0.0, 1.0))
  val () = eqR ("Real.nextAfter/zero-down", ~ Real.minPos, fn () => Real.nextAfter (0.0, ~1.0))
  val () = eqR ("Real.nextAfter/negzero-up", Real.minPos, fn () => Real.nextAfter (~0.0, 1.0))
  val () = T.check ("Real.nextAfter/minPos-down", fn () => Real.== (Real.nextAfter (Real.minPos, 0.0), 0.0))
  val () = eqR ("Real.nextAfter/subnormal-to-normal", Real.minNormalPos,
                fn () => Real.nextAfter (Real.minNormalPos - Real.minPos, 1.0))
  val () = eqR ("Real.nextAfter/maxFinite-up", posInf, fn () => Real.nextAfter (Real.maxFinite, posInf))
  val () = eqR ("Real.nextAfter/maxFinite-down", Real.maxFinite - pow2 970, fn () => Real.nextAfter (Real.maxFinite, 0.0))
  val () = eqR ("Real.nextAfter/nan-first", nan, fn () => Real.nextAfter (nan, 1.0))
  val () = eqR ("Real.nextAfter/nan-second", nan, fn () => Real.nextAfter (1.0, nan))
  (* "If r is +-infinity, it returns +-infinity." *)
  val () = eqR ("Real.nextAfter/posInf-equal", posInf, fn () => Real.nextAfter (posInf, posInf))
  val () = eqR ("Real.nextAfter/negInf-equal", negInf, fn () => Real.nextAfter (negInf, negInf))
  val () = eqR ("Real.nextAfter/posInf-towards-zero", posInf, fn () => Real.nextAfter (posInf, 0.0))
  val () = eqR ("Real.nextAfter/negInf-towards-zero", negInf, fn () => Real.nextAfter (negInf, 0.0))
  val () = law ("Real.nextAfter/law-monotone", 300, 1000,
                fn x => let val up = Real.nextAfter (x, posInf) val down = Real.nextAfter (x, negInf)
                        in Real.< (down, x) andalso Real.< (x, up)
                           andalso T.sameReal (Real.nextAfter (up, negInf), x)
                           andalso T.sameReal (Real.nextAfter (down, posInf), x) end)
  (* Nothing lies between x and its successor. *)
  val () = law ("Real.nextAfter/law-adjacent", 300, 1000,
                fn x => let val up = Real.nextAfter (x, posInf)
                            val mid = x / 2.0 + up / 2.0
                        in T.sameReal (mid, x) orelse T.sameReal (mid, up) end)
  (*>> nextafter *)

  (* ---- checkFloat ---- *)
  val () = eqR ("Real.checkFloat/ordinary", 1.5, fn () => Real.checkFloat 1.5)
  val () = eqR ("Real.checkFloat/negzero", ~0.0, fn () => Real.checkFloat (~0.0))
  val () = eqR ("Real.checkFloat/maxFinite", Real.maxFinite, fn () => Real.checkFloat Real.maxFinite)
  val () = eqR ("Real.checkFloat/minPos", Real.minPos, fn () => Real.checkFloat Real.minPos)
  val () = T.raises ("Real.checkFloat/Overflow-posInf", T.isOverflow, fn () => Real.checkFloat posInf)
  val () = T.raises ("Real.checkFloat/Overflow-negInf", T.isOverflow, fn () => Real.checkFloat negInf)
  (* "raises Overflow if x is an infinity, and raises Div if x is NaN" *)
  val () = T.raises ("Real.checkFloat/Div-nan", T.isDiv, fn () => Real.checkFloat nan)

  (* ---- realFloor, realCeil, realTrunc, realRound ---- *)
  val () = eqR ("Real.realFloor/positive", 2.0, fn () => Real.realFloor 2.7)
  val () = eqR ("Real.realFloor/negative", ~3.0, fn () => Real.realFloor (~2.7))
  val () = eqR ("Real.realFloor/integral", 5.0, fn () => Real.realFloor 5.0)
  val () = eqR ("Real.realFloor/small-negative", ~1.0, fn () => Real.realFloor (~ Real.minPos))
  val () = eqR ("Real.realFloor/zero", 0.0, fn () => Real.realFloor 0.0)
  val () = eqR ("Real.realFloor/huge", 1E300, fn () => Real.realFloor 1E300)
  val () = eqR ("Real.realFloor/negative-huge", ~1E300, fn () => Real.realFloor (~1E300))
  val () = eqR ("Real.realFloor/posInf", posInf, fn () => Real.realFloor posInf)
  val () = eqR ("Real.realFloor/negInf", negInf, fn () => Real.realFloor negInf)
  val () = eqR ("Real.realFloor/nan", nan, fn () => Real.realFloor nan)
  val () = eqR ("Real.realCeil/positive", 3.0, fn () => Real.realCeil 2.1)
  val () = eqR ("Real.realCeil/negative", ~2.0, fn () => Real.realCeil (~2.1))
  val () = eqR ("Real.realCeil/integral", ~5.0, fn () => Real.realCeil (~5.0))
  val () = eqR ("Real.realCeil/small-positive", 1.0, fn () => Real.realCeil Real.minPos)
  val () = eqR ("Real.realCeil/huge", Real.maxFinite, fn () => Real.realCeil Real.maxFinite)
  val () = eqR ("Real.realCeil/posInf", posInf, fn () => Real.realCeil posInf)
  val () = eqR ("Real.realCeil/negInf", negInf, fn () => Real.realCeil negInf)
  val () = eqR ("Real.realCeil/nan", nan, fn () => Real.realCeil nan)
  val () = eqR ("Real.realTrunc/positive", 2.0, fn () => Real.realTrunc 2.7)
  val () = eqR ("Real.realTrunc/negative", ~2.0, fn () => Real.realTrunc (~2.7))
  val () = eqR ("Real.realTrunc/fraction", 0.0, fn () => Real.realTrunc 0.9)
  val () = eqR ("Real.realTrunc/huge", ~1E300, fn () => Real.realTrunc (~1E300))
  val () = eqR ("Real.realTrunc/posInf", posInf, fn () => Real.realTrunc posInf)
  val () = eqR ("Real.realTrunc/negInf", negInf, fn () => Real.realTrunc negInf)
  val () = eqR ("Real.realTrunc/nan", nan, fn () => Real.realTrunc nan)
  val () = eqR ("Real.realRound/down", 2.0, fn () => Real.realRound 2.4)
  val () = eqR ("Real.realRound/up", 3.0, fn () => Real.realRound 2.6)
  val () = eqR ("Real.realRound/negative-down", ~3.0, fn () => Real.realRound (~2.6))
  val () = eqR ("Real.realRound/negative-up", ~2.0, fn () => Real.realRound (~2.4))
  (* The page gives the rule for ties under round only ("it rounds to the
     nearest even integer"); IEEE 754 round-to-integral in the default mode
     agrees. *)
  val () = eqR ("Real.realRound/tie-half", 0.0, fn () => Real.realRound 0.5)
  val () = eqR ("Real.realRound/tie-one-and-half", 2.0, fn () => Real.realRound 1.5)
  val () = eqR ("Real.realRound/tie-two-and-half", 2.0, fn () => Real.realRound 2.5)
  val () = eqR ("Real.realRound/tie-three-and-half", 4.0, fn () => Real.realRound 3.5)
  val () = eqR ("Real.realRound/tie-negative", ~2.0, fn () => Real.realRound (~2.5))
  val () = eqR ("Real.realRound/tie-negative-odd", ~4.0, fn () => Real.realRound (~3.5))
  (* 0.5 - 2^~54 is the predecessor of 0.5: adding 0.5 and flooring is wrong. *)
  val () = T.check ("Real.realRound/just-below-half", fn () => Real.== (Real.realRound (0.5 - pow2 ~54), 0.0))
  val () = eqR ("Real.realRound/large-odd", 4503599627370497.0, fn () => Real.realRound 4503599627370497.0)
  val () = eqR ("Real.realRound/huge", 1E300, fn () => Real.realRound 1E300)
  val () = eqR ("Real.realRound/posInf", posInf, fn () => Real.realRound posInf)
  val () = eqR ("Real.realRound/negInf", negInf, fn () => Real.realRound negInf)
  val () = eqR ("Real.realRound/nan", nan, fn () => Real.realRound nan)
  (* IEEE 754: the sign of a result rounded to an integral value is the sign
     of the operand. *)
  val () = eqR ("Real.realFloor/negzero-sign", ~0.0, fn () => Real.realFloor (~0.0))
  val () = eqR ("Real.realCeil/negzero-sign", ~0.0, fn () => Real.realCeil (~0.5))
  val () = eqR ("Real.realTrunc/negzero-sign", ~0.0, fn () => Real.realTrunc (~0.9))
  val () = eqR ("Real.realRound/negzero-sign", ~0.0, fn () => Real.realRound (~0.25))
  (* Below 2^51, so that f + 1.0 and c - 1.0 are exact. *)
  val () = law ("Real.realFloor/law-bounds", 300, 50,
                fn x => let val f = Real.realFloor x
                        in Real.<= (f, x) andalso Real.< (x, f + 1.0) end)
  val () = law ("Real.realCeil/law-bounds", 300, 50,
                fn x => let val c = Real.realCeil x
                        in Real.>= (c, x) andalso Real.> (x, c - 1.0)
                           andalso Real.== (c, ~ (Real.realFloor (~ x))) end)
  val () = law ("Real.realTrunc/law-towards-zero", 300, 60,
                fn x => Real.== (Real.realTrunc x, if Real.< (x, 0.0) then Real.realCeil x else Real.realFloor x))
  val () = law ("Real.realRound/law-nearest", 300, 60,
                fn x => let val r = Real.realRound x
                        in Real.<= (Real.abs (r - x), 0.5)
                           andalso (Real.== (r, Real.realFloor x) orelse Real.== (r, Real.realCeil x)) end)

  (* ---- floor, ceil, trunc, round ---- *)
  val () = eqI ("Real.floor/positive", 2, fn () => Real.floor 2.7)
  val () = eqI ("Real.floor/negative", ~3, fn () => Real.floor (~2.7))
  val () = eqI ("Real.floor/integral", ~5, fn () => Real.floor (~5.0))
  val () = eqI ("Real.floor/negzero", 0, fn () => Real.floor (~0.0))
  val () = eqI ("Real.floor/small-negative", ~1, fn () => Real.floor (~ Real.minPos))
  val () = eqI ("Real.floor/toplevel", 2, fn () => floor 2.5)
  val () = eqI ("Real.ceil/positive", 3, fn () => Real.ceil 2.1)
  val () = eqI ("Real.ceil/negative", ~2, fn () => Real.ceil (~2.1))
  val () = eqI ("Real.ceil/integral", 5, fn () => Real.ceil 5.0)
  val () = eqI ("Real.ceil/small-positive", 1, fn () => Real.ceil Real.minPos)
  val () = eqI ("Real.ceil/negative-fraction", 0, fn () => Real.ceil (~0.5))
  val () = eqI ("Real.ceil/toplevel", 3, fn () => ceil 2.5)
  val () = eqI ("Real.trunc/positive", 2, fn () => Real.trunc 2.7)
  val () = eqI ("Real.trunc/negative", ~2, fn () => Real.trunc (~2.7))
  val () = eqI ("Real.trunc/fraction", 0, fn () => Real.trunc (~0.9))
  val () = eqI ("Real.trunc/toplevel", ~2, fn () => trunc (~2.5))
  val () = eqI ("Real.round/down", 2, fn () => Real.round 2.4)
  val () = eqI ("Real.round/up", 3, fn () => Real.round 2.6)
  val () = eqI ("Real.round/negative", ~3, fn () => Real.round (~2.6))
  (* "In the case of a tie, it rounds to the nearest even integer." *)
  val () = eqI ("Real.round/tie-half", 0, fn () => Real.round 0.5)
  val () = eqI ("Real.round/tie-one-and-half", 2, fn () => Real.round 1.5)
  val () = eqI ("Real.round/tie-two-and-half", 2, fn () => Real.round 2.5)
  val () = eqI ("Real.round/tie-three-and-half", 4, fn () => Real.round 3.5)
  val () = eqI ("Real.round/tie-negative-half", 0, fn () => Real.round (~0.5))
  val () = eqI ("Real.round/tie-negative", ~2, fn () => Real.round (~2.5))
  val () = eqI ("Real.round/tie-negative-odd", ~4, fn () => Real.round (~3.5))
  val () = eqI ("Real.round/just-below-half", 0, fn () => Real.round (0.5 - pow2 ~54))
  val () = eqI ("Real.round/toplevel", 4, fn () => round 3.5)
  val () = eqI ("Real.round/large", 536870911, fn () => Real.round 536870911.25)
  val () = eqI ("Real.floor/large-negative", ~536870912, fn () => Real.floor (~536870911.5))
  (* "They raise Overflow if the resulting value cannot be represented as an
     int, for example, on infinity. They raise Domain on NaN arguments." *)
  val () = T.raises ("Real.floor/Overflow-posInf", T.isOverflow, fn () => Real.floor posInf)
  val () = T.raises ("Real.floor/Overflow-negInf", T.isOverflow, fn () => Real.floor negInf)
  val () = T.raises ("Real.floor/Domain-nan", T.isDomain, fn () => Real.floor nan)
  val () = T.raises ("Real.ceil/Overflow-posInf", T.isOverflow, fn () => Real.ceil posInf)
  val () = T.raises ("Real.ceil/Overflow-negInf", T.isOverflow, fn () => Real.ceil negInf)
  val () = T.raises ("Real.ceil/Domain-nan", T.isDomain, fn () => Real.ceil nan)
  val () = T.raises ("Real.trunc/Overflow-posInf", T.isOverflow, fn () => Real.trunc posInf)
  val () = T.raises ("Real.trunc/Overflow-negInf", T.isOverflow, fn () => Real.trunc negInf)
  val () = T.raises ("Real.trunc/Domain-nan", T.isDomain, fn () => Real.trunc nan)
  val () = T.raises ("Real.round/Overflow-posInf", T.isOverflow, fn () => Real.round posInf)
  val () = T.raises ("Real.round/Overflow-negInf", T.isOverflow, fn () => Real.round negInf)
  val () = T.raises ("Real.round/Domain-nan", T.isDomain, fn () => Real.round nan)

  (* Where int is bounded (Int.maxInt is SOME m), whatever its precision:
     fromInt m + 1.0 is 2^(p-1), the first real that does not fit (for p > 53
     fromInt m already rounds to it), and fromInt minInt is ~2^(p-1) exactly. *)
  fun overflows (label, f : real -> int, x : int -> real) : unit =
    case Int.maxInt of
      NONE => T.check (label, fn () => true)
    | SOME m => T.raises (label, T.isOverflow, fn () => f (x m))
  fun above m = Real.fromInt m + 1.0
  fun below m = (~ (Real.fromInt m) - 1.0) * 2.0
  val () = overflows ("Real.floor/Overflow-above-maxInt", Real.floor, above)
  val () = overflows ("Real.ceil/Overflow-above-maxInt", Real.ceil, above)
  val () = overflows ("Real.trunc/Overflow-above-maxInt", Real.trunc, above)
  val () = overflows ("Real.round/Overflow-above-maxInt", Real.round, above)
  val () = overflows ("Real.floor/Overflow-below-minInt", Real.floor, below)
  val () = overflows ("Real.ceil/Overflow-below-minInt", Real.ceil, below)
  val () = overflows ("Real.trunc/Overflow-below-minInt", Real.trunc, below)
  val () = overflows ("Real.round/Overflow-below-minInt", Real.round, below)
  val () = overflows ("Real.floor/Overflow-huge", Real.floor, fn _ => 1E300)
  val () = overflows ("Real.round/Overflow-negative-huge", Real.round, fn _ => ~1E300)

  (* minInt = ~2^(p-1) is a real: every conversion gives it back, and so do
     those that round minInt - 0.5 upwards (for p > 53 that real is minInt). *)
  fun atMinInt (label, f : real -> int, d : real) : unit =
    case Int.minInt of
      NONE => T.check (label, fn () => true)
    | SOME m => eqI (label, m, fn () => f (Real.fromInt m - d))
  val () = atMinInt ("Real.floor/minInt", Real.floor, 0.0)
  val () = atMinInt ("Real.ceil/minInt", Real.ceil, 0.0)
  val () = atMinInt ("Real.trunc/minInt", Real.trunc, 0.0)
  val () = atMinInt ("Real.round/minInt", Real.round, 0.0)
  val () = atMinInt ("Real.ceil/minInt-minus-half", Real.ceil, 0.5)
  val () = atMinInt ("Real.trunc/minInt-minus-half", Real.trunc, 0.5)
  val () = atMinInt ("Real.round/minInt-minus-half-tie-to-even", Real.round, 0.5)

  (* The largest real below 2^(p-1) and the int it is: maxInt itself for
     p <= 53, otherwise 2^(p-1) - 2^(p-54). *)
  fun intPow2 (n : int) : int = if n = 0 then 1 else 2 * intPow2 (n - 1)
  fun nearMaxInt (label, f : real -> int) : unit =
    case (Int.maxInt, Int.precision) of
      (SOME m, SOME p) =>
        if p <= 53 then eqI (label, m, fn () => f (Real.fromInt m))
        else eqI (label, m - (intPow2 (p - 54) - 1), fn () => f (pow2 (p - 1) - pow2 (p - 54)))
    | _ => T.check (label, fn () => true)
  val () = nearMaxInt ("Real.floor/near-maxInt", Real.floor)
  val () = nearMaxInt ("Real.ceil/near-maxInt", Real.ceil)
  val () = nearMaxInt ("Real.trunc/near-maxInt", Real.trunc)
  val () = nearMaxInt ("Real.round/near-maxInt", Real.round)

  (* For p <= 53 the boundary is sharp: maxInt + 0.5 and minInt - 0.5 are reals. *)
  fun sharp (label, expectOverflow : bool, f : real -> int, atMax : bool) : unit =
    case (Int.maxInt, Int.minInt, Int.precision) of
      (SOME hi, SOME lo, SOME p) =>
        if p > 53 then T.check (label, fn () => true)
        else
          let val x = fn () => if atMax then Real.fromInt hi + 0.5 else Real.fromInt lo - 0.5
          in
            if expectOverflow then T.raises (label, T.isOverflow, fn () => f (x ()))
            else eqI (label, if atMax then hi else lo, fn () => f (x ()))
          end
    | _ => T.check (label, fn () => true)
  val () = sharp ("Real.floor/maxInt-plus-half", false, Real.floor, true)
  val () = sharp ("Real.trunc/maxInt-plus-half", false, Real.trunc, true)
  val () = sharp ("Real.ceil/Overflow-maxInt-plus-half", true, Real.ceil, true)
  val () = sharp ("Real.round/Overflow-maxInt-plus-half-tie-to-even", true, Real.round, true)
  val () = sharp ("Real.floor/Overflow-minInt-minus-half", true, Real.floor, false)

  val () = law ("Real.floor/law-agrees-with-realFloor", 300, 28,
                fn x => Real.== (Real.fromInt (Real.floor x), Real.realFloor x)
                        andalso Real.== (Real.fromInt (Real.ceil x), Real.realCeil x)
                        andalso Real.== (Real.fromInt (Real.trunc x), Real.realTrunc x)
                        andalso Real.== (Real.fromInt (Real.round x), Real.realRound x))
  val () = T.check ("Real.round/law-halves-to-even", fn () =>
             let val ok = ref true
             in T.seed 11;
                T.repeat (200, fn _ =>
                  let val n = T.range (~100000, 100000)
                      val r = Real.round (Real.fromInt n + 0.5)
                  in if r mod 2 = 0 andalso (r = n orelse r = n + 1) then () else ok := false end);
                !ok end)

  (*<< rounding-modes *)
  (* floor, ceil, trunc and round "are respectively equivalent to" toInt with
     TO_NEGINF, TO_POSINF, TO_ZERO and TO_NEAREST. *)
  val modes = [("TO_NEAREST", IEEEReal.TO_NEAREST), ("TO_NEGINF", IEEEReal.TO_NEGINF),
               ("TO_POSINF", IEEEReal.TO_POSINF), ("TO_ZERO", IEEEReal.TO_ZERO)]
  val () = eqI ("Real.toInt/TO_NEGINF-positive", 2, fn () => Real.toInt IEEEReal.TO_NEGINF 2.5)
  val () = eqI ("Real.toInt/TO_NEGINF-negative", ~3, fn () => Real.toInt IEEEReal.TO_NEGINF (~2.5))
  val () = eqI ("Real.toInt/TO_POSINF-positive", 3, fn () => Real.toInt IEEEReal.TO_POSINF 2.5)
  val () = eqI ("Real.toInt/TO_POSINF-negative", ~2, fn () => Real.toInt IEEEReal.TO_POSINF (~2.5))
  val () = eqI ("Real.toInt/TO_ZERO-positive", 2, fn () => Real.toInt IEEEReal.TO_ZERO 2.9)
  val () = eqI ("Real.toInt/TO_ZERO-negative", ~2, fn () => Real.toInt IEEEReal.TO_ZERO (~2.9))
  val () = eqI ("Real.toInt/TO_NEAREST-down", 2, fn () => Real.toInt IEEEReal.TO_NEAREST 2.4)
  val () = eqI ("Real.toInt/TO_NEAREST-up", 3, fn () => Real.toInt IEEEReal.TO_NEAREST 2.6)
  val () = eqI ("Real.toInt/TO_NEAREST-tie-even", 2, fn () => Real.toInt IEEEReal.TO_NEAREST 2.5)
  val () = eqI ("Real.toInt/TO_NEAREST-tie-odd", 4, fn () => Real.toInt IEEEReal.TO_NEAREST 3.5)
  val () = eqI ("Real.toInt/TO_NEAREST-tie-negative", ~2, fn () => Real.toInt IEEEReal.TO_NEAREST (~2.5))
  val () = List.app (fn (name, mode) =>
             (eqI ("Real.toInt/" ^ name ^ "-integral", ~7, fn () => Real.toInt mode (~7.0));
              eqI ("Real.toInt/" ^ name ^ "-negzero", 0, fn () => Real.toInt mode (~0.0));
              T.raises ("Real.toInt/Overflow-" ^ name ^ "-posInf", T.isOverflow, fn () => Real.toInt mode posInf);
              T.raises ("Real.toInt/Overflow-" ^ name ^ "-negInf", T.isOverflow, fn () => Real.toInt mode negInf);
              T.raises ("Real.toInt/Domain-" ^ name ^ "-nan", T.isDomain, fn () => Real.toInt mode nan);
              overflows ("Real.toInt/Overflow-" ^ name ^ "-above-maxInt", Real.toInt mode, above);
              overflows ("Real.toInt/Overflow-" ^ name ^ "-below-minInt", Real.toInt mode, below);
              atMinInt ("Real.toInt/" ^ name ^ "-minInt", Real.toInt mode, 0.0);
              nearMaxInt ("Real.toInt/" ^ name ^ "-near-maxInt", Real.toInt mode))) modes
  val () = law ("Real.toInt/law-equivalences", 300, 28,
                fn x => Real.toInt IEEEReal.TO_NEGINF x = Real.floor x
                        andalso Real.toInt IEEEReal.TO_POSINF x = Real.ceil x
                        andalso Real.toInt IEEEReal.TO_ZERO x = Real.trunc x
                        andalso Real.toInt IEEEReal.TO_NEAREST x = Real.round x)
  (*>> rounding-modes *)

  (*<< tolargeint *)
  (* The expected values need an unbounded LargeInt (all four systems have
     one); with a bounded LargeInt the checks pass vacuously. *)
  val unbounded = case LargeInt.precision of NONE => true | SOME _ => false
  fun bigPow (b : int, n : int) : LargeInt.int =
    if n = 0 then LargeInt.fromInt 1 else LargeInt.* (LargeInt.fromInt b, bigPow (b, n - 1))
  fun eqL (label, expected : unit -> LargeInt.int, f : unit -> LargeInt.int) : unit =
    T.check (label, fn () => not unbounded orelse f () = expected ())
  val () = eqL ("Real.toLargeInt/TO_NEGINF-positive", fn () => LargeInt.fromInt 2, fn () => Real.toLargeInt IEEEReal.TO_NEGINF 2.5)
  val () = eqL ("Real.toLargeInt/TO_NEGINF-negative", fn () => LargeInt.fromInt ~3, fn () => Real.toLargeInt IEEEReal.TO_NEGINF (~2.5))
  val () = eqL ("Real.toLargeInt/TO_POSINF-positive", fn () => LargeInt.fromInt 3, fn () => Real.toLargeInt IEEEReal.TO_POSINF 2.5)
  val () = eqL ("Real.toLargeInt/TO_POSINF-negative", fn () => LargeInt.fromInt ~2, fn () => Real.toLargeInt IEEEReal.TO_POSINF (~2.5))
  val () = eqL ("Real.toLargeInt/TO_ZERO-positive", fn () => LargeInt.fromInt 2, fn () => Real.toLargeInt IEEEReal.TO_ZERO 2.9)
  val () = eqL ("Real.toLargeInt/TO_ZERO-negative", fn () => LargeInt.fromInt ~2, fn () => Real.toLargeInt IEEEReal.TO_ZERO (~2.9))
  val () = eqL ("Real.toLargeInt/TO_NEAREST-tie-even", fn () => LargeInt.fromInt 2, fn () => Real.toLargeInt IEEEReal.TO_NEAREST 2.5)
  val () = eqL ("Real.toLargeInt/TO_NEAREST-tie-odd", fn () => LargeInt.fromInt 4, fn () => Real.toLargeInt IEEEReal.TO_NEAREST 3.5)
  val () = eqL ("Real.toLargeInt/TO_NEAREST-tie-negative", fn () => LargeInt.fromInt ~2, fn () => Real.toLargeInt IEEEReal.TO_NEAREST (~2.5))
  val () = eqL ("Real.toLargeInt/TO_NEAREST-up", fn () => LargeInt.fromInt 3, fn () => Real.toLargeInt IEEEReal.TO_NEAREST 2.6)
  (* 1E20 = 2^20 * 5^20 and 5^20 < 2^53, so the real 1E20 is the integer 10^20. *)
  val () = eqL ("Real.toLargeInt/ten-to-the-20th", fn () => bigPow (10, 20), fn () => Real.toLargeInt IEEEReal.TO_NEAREST 1E20)
  val () = eqL ("Real.toLargeInt/two-to-the-100th", fn () => bigPow (2, 100), fn () => Real.toLargeInt IEEEReal.TO_ZERO (pow2 100))
  val () = eqL ("Real.toLargeInt/negative-two-to-the-200th", fn () => LargeInt.~ (bigPow (2, 200)),
                fn () => Real.toLargeInt IEEEReal.TO_NEGINF (~ (pow2 200)))
  val () = eqL ("Real.toLargeInt/two-to-the-1000th", fn () => bigPow (2, 1000), fn () => Real.toLargeInt IEEEReal.TO_NEAREST (pow2 1000))
  val () = eqL ("Real.toLargeInt/large-with-fraction", fn () => LargeInt.+ (bigPow (2, 51), LargeInt.fromInt 1),
                fn () => Real.toLargeInt IEEEReal.TO_POSINF (pow2 51 + 0.5))
  val () = List.app (fn (name, mode) =>
             (T.raises ("Real.toLargeInt/Overflow-" ^ name ^ "-posInf", T.isOverflow, fn () => Real.toLargeInt mode posInf);
              T.raises ("Real.toLargeInt/Overflow-" ^ name ^ "-negInf", T.isOverflow, fn () => Real.toLargeInt mode negInf);
              T.raises ("Real.toLargeInt/Domain-" ^ name ^ "-nan", T.isDomain, fn () => Real.toLargeInt mode nan)))
             [("TO_NEAREST", IEEEReal.TO_NEAREST), ("TO_NEGINF", IEEEReal.TO_NEGINF),
              ("TO_POSINF", IEEEReal.TO_POSINF), ("TO_ZERO", IEEEReal.TO_ZERO)]
  val () = law ("Real.toLargeInt/law-agrees-with-toInt", 300, 28,
                fn x => LargeInt.toInt (Real.toLargeInt IEEEReal.TO_NEGINF x) = Real.floor x
                        andalso LargeInt.toInt (Real.toLargeInt IEEEReal.TO_POSINF x) = Real.ceil x
                        andalso LargeInt.toInt (Real.toLargeInt IEEEReal.TO_ZERO x) = Real.trunc x
                        andalso LargeInt.toInt (Real.toLargeInt IEEEReal.TO_NEAREST x) = Real.round x)
  (*>> tolargeint *)

  (*<< tolargeint-huge *)
  (* Reals of 2^1023 or more. SML/NJ 110.79 loops forever in toLargeInt on
     them, for the reason given in section manexp-huge; the same probe makes
     these checks fail instead of hanging there. maxFinite = (2^53 - 1) * 2^971. *)
  fun normalisedH (x : real) : bool =
    let val {man, exp = _} = Real.toManExp x
    in Real.<= (0.5, Real.abs man) andalso Real.< (Real.abs man, 1.0) end
  fun bigPowH (b : int, n : int) : LargeInt.int =
    if n = 0 then LargeInt.fromInt 1 else LargeInt.* (LargeInt.fromInt b, bigPowH (b, n - 1))
  fun eqH (label, x : real, expected : unit -> LargeInt.int, f : unit -> LargeInt.int) : unit =
    T.check (label, fn () =>
      case LargeInt.precision of
        SOME _ => true
      | NONE => if normalisedH x then f () = expected ()
                else raise Fail "toManExp does not normalise its argument")
  val () = eqH ("Real.toLargeInt/huge-maxFinite", Real.maxFinite,
                fn () => LargeInt.* (LargeInt.- (bigPowH (2, 53), LargeInt.fromInt 1), bigPowH (2, 971)),
                fn () => Real.toLargeInt IEEEReal.TO_POSINF Real.maxFinite)
  val () = eqH ("Real.toLargeInt/huge-negative-two-to-the-1023rd", pow2 1023,
                fn () => LargeInt.~ (bigPowH (2, 1023)),
                fn () => Real.toLargeInt IEEEReal.TO_NEAREST (~ (pow2 1023)))
  (*>> tolargeint-huge *)

  (* ---- fromInt ---- *)
  val () = eqR ("Real.fromInt/zero", 0.0, fn () => Real.fromInt 0)
  val () = eqR ("Real.fromInt/positive", 7.0, fn () => Real.fromInt 7)
  val () = eqR ("Real.fromInt/negative", ~7.0, fn () => Real.fromInt ~7)
  val () = eqR ("Real.fromInt/large", pow2 30 - 1.0, fn () => Real.fromInt 1073741823)
  val () = eqR ("Real.fromInt/large-negative", ~ (pow2 30), fn () => Real.fromInt (~1073741823 - 1))
  (* "The top-level function real is an alias for Real.fromInt." *)
  val () = eqR ("Real.fromInt/toplevel-real", 42.0, fn () => real 42)
  val () = T.check ("Real.fromInt/maxInt", fn () =>
             case (Int.maxInt, Int.precision) of
               (SOME m, SOME p) =>
                 (* 2^(p-1) - 1, exactly if p <= 54, otherwise rounded to 2^(p-1) *)
                 Real.== (Real.fromInt m, if p <= 54 then pow2 (p - 1) - 1.0 else pow2 (p - 1))
             | _ => true)
  val () = T.check ("Real.fromInt/minInt", fn () =>
             case (Int.minInt, Int.precision) of
               (SOME m, SOME p) => Real.== (Real.fromInt m, ~ (pow2 (p - 1)))
             | _ => true)
  val () = T.check ("Real.fromInt/law-round-trip", fn () =>
             let val ok = ref true
             in T.seed 3;
                T.repeat (300, fn _ =>
                  let val n = T.range (~500000000, 500000000)
                      val r = Real.fromInt n
                  in if Real.floor r = n andalso Real.ceil r = n andalso Real.round r = n andalso Real.trunc r = n
                        andalso Real.== (Real.fromInt (n + 1) - r, 1.0)
                     then () else ok := false end);
                !ok end)

  (*<< fromlargeint *)
  val unboundedL = case LargeInt.precision of NONE => true | SOME _ => false
  fun bigPowL (b : int, n : int) : LargeInt.int =
    if n = 0 then LargeInt.fromInt 1 else LargeInt.* (LargeInt.fromInt b, bigPowL (b, n - 1))
  fun eqRL (label, expected : real, f : unit -> real) : unit =
    if unboundedL then eqR (label, expected, f) else T.check (label, fn () => true)
  val () = eqR ("Real.fromLargeInt/zero", 0.0, fn () => Real.fromLargeInt (LargeInt.fromInt 0))
  val () = eqR ("Real.fromLargeInt/positive", 7.0, fn () => Real.fromLargeInt (LargeInt.fromInt 7))
  val () = eqR ("Real.fromLargeInt/negative", ~7.0, fn () => Real.fromLargeInt (LargeInt.fromInt ~7))
  val () = eqRL ("Real.fromLargeInt/ten-to-the-20th", 1E20, fn () => Real.fromLargeInt (bigPowL (10, 20)))
  val () = eqRL ("Real.fromLargeInt/two-to-the-100th", pow2 100, fn () => Real.fromLargeInt (bigPowL (2, 100)))
  val () = eqRL ("Real.fromLargeInt/negative-two-to-the-1000th", ~ (pow2 1000),
                 fn () => Real.fromLargeInt (LargeInt.~ (bigPowL (2, 1000))))
  (* "If i cannot be exactly represented as a real value, then the current
     rounding mode is used": to nearest, ties to even. *)
  val () = eqRL ("Real.fromLargeInt/tie-rounds-to-even-down", pow2 53,
                 fn () => Real.fromLargeInt (LargeInt.+ (bigPowL (2, 53), LargeInt.fromInt 1)))
  val () = eqRL ("Real.fromLargeInt/tie-rounds-to-even-up", pow2 53 + 4.0,
                 fn () => Real.fromLargeInt (LargeInt.+ (bigPowL (2, 53), LargeInt.fromInt 3)))
  (* 2^100 + 2^47 is a tie, one more is not: the low bits decide. *)
  val () = eqRL ("Real.fromLargeInt/sticky-bit", pow2 100 + pow2 48,
                 fn () => Real.fromLargeInt (LargeInt.+ (LargeInt.+ (bigPowL (2, 100), bigPowL (2, 47)), LargeInt.fromInt 1)))
  val () = eqRL ("Real.fromLargeInt/tie-without-sticky-bit", pow2 100,
                 fn () => Real.fromLargeInt (LargeInt.+ (bigPowL (2, 100), bigPowL (2, 47))))
  val () = eqRL ("Real.fromLargeInt/maxFinite", Real.maxFinite,
                 fn () => Real.fromLargeInt (LargeInt.* (LargeInt.- (bigPowL (2, 53), LargeInt.fromInt 1), bigPowL (2, 971))))
  (* "If the absolute value of i is larger than maxFinite, then the appropriate
     infinity is returned." *)
  val () = eqRL ("Real.fromLargeInt/too-large-is-posInf", posInf, fn () => Real.fromLargeInt (bigPowL (10, 400)))
  val () = eqRL ("Real.fromLargeInt/too-small-is-negInf", negInf, fn () => Real.fromLargeInt (LargeInt.~ (bigPowL (10, 400))))
  val () = eqRL ("Real.fromLargeInt/two-to-the-1024th-is-posInf", posInf, fn () => Real.fromLargeInt (bigPowL (2, 1024)))
  (*>> fromlargeint *)

  (*<< large *)
  (* LargeReal.real values are made without literals, so that this does not
     assume LargeReal.real = real. *)
  fun lr (n : int, d : int) : LargeReal.real = LargeReal./ (LargeReal.fromInt n, LargeReal.fromInt d)
  val () = T.check ("Real.toLarge/basic", fn () => LargeReal.== (Real.toLarge 1.5, lr (3, 2)))
  val () = T.check ("Real.toLarge/negative", fn () => LargeReal.== (Real.toLarge (~0.375), lr (~3, 8)))
  val () = T.check ("Real.toLarge/negzero", fn () => LargeReal.signBit (Real.toLarge (~0.0))
                                                     andalso LargeReal.== (Real.toLarge (~0.0), lr (0, 1)))
  val () = T.check ("Real.toLarge/posInf", fn () => LargeReal.== (Real.toLarge posInf, LargeReal.posInf))
  val () = T.check ("Real.toLarge/negInf", fn () => LargeReal.== (Real.toLarge negInf, LargeReal.negInf))
  val () = T.check ("Real.toLarge/nan", fn () => LargeReal.isNan (Real.toLarge nan))
  val () = List.app (fn (name, mode) =>
             (eqR ("Real.fromLarge/" ^ name ^ "-basic", 1.5, fn () => Real.fromLarge mode (lr (3, 2)));
              eqR ("Real.fromLarge/" ^ name ^ "-negative", ~0.375, fn () => Real.fromLarge mode (lr (~3, 8)));
              eqR ("Real.fromLarge/" ^ name ^ "-posInf", posInf, fn () => Real.fromLarge mode LargeReal.posInf);
              eqR ("Real.fromLarge/" ^ name ^ "-negInf", negInf, fn () => Real.fromLarge mode LargeReal.negInf);
              eqR ("Real.fromLarge/" ^ name ^ "-nan", nan, fn () => Real.fromLarge mode (LargeReal.- (LargeReal.posInf, LargeReal.posInf)))))
             [("TO_NEAREST", IEEEReal.TO_NEAREST), ("TO_NEGINF", IEEEReal.TO_NEGINF),
              ("TO_POSINF", IEEEReal.TO_POSINF), ("TO_ZERO", IEEEReal.TO_ZERO)]
  val () = law ("Real.fromLarge/law-inverts-toLarge", 300, 1000,
                fn x => T.sameReal (Real.fromLarge IEEEReal.TO_NEAREST (Real.toLarge x), x))
  (*>> large *)

  (*<< largereal *)
  (* "structure LargeReal :> REAL": at least the precision of Real. *)
  val () = eqI ("LargeReal.radix/same-as-Real", Real.radix, fn () => LargeReal.radix)
  val () = T.check ("LargeReal.precision/at-least-Real", fn () => LargeReal.precision >= Real.precision)
  val () = T.check ("LargeReal.maxFinite/at-least-Real",
                    fn () => LargeReal.>= (LargeReal.maxFinite, Real.toLarge Real.maxFinite))
  val () = T.check ("LargeReal.minPos/at-most-Real",
                    fn () => LargeReal.<= (LargeReal.minPos, Real.toLarge Real.minPos))
  val () = T.check ("LargeReal.+/basic",
                    fn () => LargeReal.== (LargeReal.+ (LargeReal.fromInt 1, LargeReal.fromInt 2), LargeReal.fromInt 3))
  val () = eqI ("LargeReal.round/tie-to-even", 2, fn () => LargeReal.round (LargeReal./ (LargeReal.fromInt 5, LargeReal.fromInt 2)))
  (*>> largereal *)
end
