(* requires: Math Real *)
(* The Math structure (signature MATH). Expected values follow the text of
   https://smlfamily.github.io/Basis/math.html. Values of transcendental
   functions are compared with T.approx (relative error 1E~9) against the
   mathematical value, so that nothing depends on the last digits of a libm;
   exact equality (T.eqReal, which also tells 0.0 from ~0.0) is used only for
   the special cases the page spells out: infinities, NaN, signed zeros and
   pow (x, 0.0) = 1.0.

   "In the functions below, unless specified otherwise, if any argument is a
   NaN, the return value is a NaN. In a list of rules specifying the behavior of
   a function in special cases, the first matching rule defines the semantics." *)
structure TestMath =
struct
  val eqR = T.eqReal
  val approx = T.approx

  val posInf = Real.posInf
  val negInf = Real.negInf
  val nan = Real.posInf - Real.posInf

  (* The mathematical constants, to more digits than a double holds. *)
  val pi = 3.14159265358979323846
  val e = 2.71828182845904523536

  (* law (label, n, lo, hi, p): p holds for n random reals k/1000 with k in [lo, hi]. *)
  fun law (label, n : int, lo : int, hi : int, p : real -> bool) : unit =
    T.check (label, fn () =>
      let val ok = ref true
      in
        T.seed 1618;
        T.repeat (n, fn _ => if p (Real.fromInt (T.range (lo, hi)) / 1000.0) then () else ok := false);
        !ok
      end)

  (* close (a, b): equal up to a relative error of 1E~9. It is called through
     a reference so that Poly/ML 5.7.1 does not inline it: inlined into
     close (Math.tan x, Math.sin x / Math.cos x) it makes that compiler fail
     with "InternalError: asGenReg raised while compiling". *)
  val closeRef = ref (fn (a : real, b : real) =>
    Real.<= (Real.abs (a - b), 1E~9 * Real.max (1.0, Real.max (Real.abs a, Real.abs b))))
  fun close (p : real * real) : bool = !closeRef p

  (* ---- pi, e ---- *)
  val () = approx ("Math.pi/value", pi, fn () => Math.pi)
  (* The double nearest to pi differs from pi by 1.2E~16. *)
  val () = T.check ("Math.pi/nearest-double", fn () => Real.<= (Real.abs (Math.pi - pi), 4.5E~16))
  val () = T.check ("Math.pi/digits", fn () => Real.< (3.141592653, Math.pi) andalso Real.< (Math.pi, 3.141592654))
  val () = approx ("Math.e/value", e, fn () => Math.e)
  val () = T.check ("Math.e/nearest-double", fn () => Real.<= (Real.abs (Math.e - e), 4.5E~16))
  val () = T.check ("Math.e/digits", fn () => Real.< (2.718281828, Math.e) andalso Real.< (Math.e, 2.718281829))

  (* ---- sqrt ---- *)
  (* IEEE 754 requires a correctly rounded square root, so exact squares have
     exact roots. *)
  val () = eqR ("Math.sqrt/four", 2.0, fn () => Math.sqrt 4.0)
  val () = eqR ("Math.sqrt/quarter", 0.5, fn () => Math.sqrt 0.25)
  val () = eqR ("Math.sqrt/one", 1.0, fn () => Math.sqrt 1.0)
  val () = approx ("Math.sqrt/two", 1.4142135623730951, fn () => Math.sqrt 2.0)
  val () = approx ("Math.sqrt/large", 1E150, fn () => Math.sqrt 1E300)
  val () = eqR ("Math.sqrt/zero", 0.0, fn () => Math.sqrt 0.0)
  (* "sqrt (~0.0) = ~0.0" *)
  val () = eqR ("Math.sqrt/negzero", ~0.0, fn () => Math.sqrt (~0.0))
  (* "If x < 0, it returns NaN." *)
  val () = eqR ("Math.sqrt/negative", nan, fn () => Math.sqrt (~1.0))
  val () = eqR ("Math.sqrt/small-negative", nan, fn () => Math.sqrt (~ Real.minPos))
  val () = eqR ("Math.sqrt/negInf", nan, fn () => Math.sqrt negInf)
  val () = eqR ("Math.sqrt/posInf", posInf, fn () => Math.sqrt posInf)
  val () = eqR ("Math.sqrt/nan", nan, fn () => Math.sqrt nan)
  val () = T.check ("Math.sqrt/law-exact-squares", fn () =>
             let val ok = ref true
             in T.seed 2;
                T.repeat (200, fn _ =>
                  let val r = Real.fromInt (T.range (0, 30000))
                  in if Real.== (Math.sqrt (r * r), r) then () else ok := false end);
                !ok end)
  val () = law ("Math.sqrt/law-squares-back", 200, 0, 1000000,
                fn x => let val r = Math.sqrt x in Real.>= (r, 0.0) andalso close (r * r, x) end)

  (* ---- sin, cos, tan ---- *)
  val () = approx ("Math.sin/zero", 0.0, fn () => Math.sin 0.0)
  val () = approx ("Math.sin/one", 0.8414709848078965, fn () => Math.sin 1.0)
  val () = approx ("Math.sin/pi-over-six", 0.5, fn () => Math.sin (Math.pi / 6.0))
  val () = approx ("Math.sin/pi-over-two", 1.0, fn () => Math.sin (Math.pi / 2.0))
  val () = approx ("Math.sin/pi", 0.0, fn () => Math.sin Math.pi)
  val () = approx ("Math.sin/negative", ~0.8414709848078965, fn () => Math.sin (~1.0))
  val () = approx ("Math.sin/three-half-pi", ~1.0, fn () => Math.sin (1.5 * Math.pi))
  (* "If x is an infinity, these functions return NaN." *)
  val () = eqR ("Math.sin/posInf", nan, fn () => Math.sin posInf)
  val () = eqR ("Math.sin/negInf", nan, fn () => Math.sin negInf)
  val () = eqR ("Math.sin/nan", nan, fn () => Math.sin nan)
  val () = approx ("Math.cos/zero", 1.0, fn () => Math.cos 0.0)
  val () = approx ("Math.cos/one", 0.5403023058681398, fn () => Math.cos 1.0)
  val () = approx ("Math.cos/pi-over-three", 0.5, fn () => Math.cos (Math.pi / 3.0))
  val () = approx ("Math.cos/pi-over-two", 0.0, fn () => Math.cos (Math.pi / 2.0))
  val () = approx ("Math.cos/pi", ~1.0, fn () => Math.cos Math.pi)
  val () = approx ("Math.cos/negative", 0.5403023058681398, fn () => Math.cos (~1.0))
  val () = eqR ("Math.cos/posInf", nan, fn () => Math.cos posInf)
  val () = eqR ("Math.cos/negInf", nan, fn () => Math.cos negInf)
  val () = eqR ("Math.cos/nan", nan, fn () => Math.cos nan)
  val () = approx ("Math.tan/zero", 0.0, fn () => Math.tan 0.0)
  val () = approx ("Math.tan/one", 1.5574077246549023, fn () => Math.tan 1.0)
  val () = approx ("Math.tan/pi-over-four", 1.0, fn () => Math.tan (Math.pi / 4.0))
  val () = approx ("Math.tan/negative", ~1.0, fn () => Math.tan (~ Math.pi / 4.0))
  val () = approx ("Math.tan/pi", 0.0, fn () => Math.tan Math.pi)
  (* "tan will produce infinities at various finite values, roughly
     corresponding to the singularities": at the double nearest pi/2 the
     magnitude is at least huge. *)
  val () = T.check ("Math.tan/near-singularity", fn () => Real.> (Real.abs (Math.tan (Math.pi / 2.0)), 1E15))
  val () = eqR ("Math.tan/posInf", nan, fn () => Math.tan posInf)
  val () = eqR ("Math.tan/negInf", nan, fn () => Math.tan negInf)
  val () = eqR ("Math.tan/nan", nan, fn () => Math.tan nan)
  val () = law ("Math.sin/law-pythagoras", 200, ~100000, 100000,
                fn x => close (Math.sin x * Math.sin x + Math.cos x * Math.cos x, 1.0))
  val () = law ("Math.sin/law-odd", 200, ~100000, 100000, fn x => close (Math.sin (~ x), ~ (Math.sin x)))
  val () = law ("Math.cos/law-even", 200, ~100000, 100000, fn x => close (Math.cos (~ x), Math.cos x))
  val () = law ("Math.cos/law-bounded", 200, ~100000, 100000,
                fn x => Real.<= (Real.abs (Math.cos x), 1.0) andalso Real.<= (Real.abs (Math.sin x), 1.0))
  (* Away from the singularities: |x| <= 1.5. *)
  val () = law ("Math.tan/law-is-sin-over-cos", 200, ~1500, 1500, fn x => close (Math.tan x, Math.sin x / Math.cos x))

  (* ---- asin, acos ---- *)
  val () = approx ("Math.asin/zero", 0.0, fn () => Math.asin 0.0)
  val () = approx ("Math.asin/half", pi / 6.0, fn () => Math.asin 0.5)
  val () = approx ("Math.asin/one", pi / 2.0, fn () => Math.asin 1.0)
  val () = approx ("Math.asin/minus-one", ~ pi / 2.0, fn () => Math.asin (~1.0))
  val () = approx ("Math.asin/negative", ~ pi / 6.0, fn () => Math.asin (~0.5))
  (* "If the magnitude of x exceeds 1.0, they return NaN." *)
  val () = eqR ("Math.asin/above-one", nan, fn () => Math.asin 1.5)
  val () = eqR ("Math.asin/just-above-one", nan, fn () => Math.asin (1.0 + 1E~15))
  val () = eqR ("Math.asin/below-minus-one", nan, fn () => Math.asin (~1.5))
  val () = eqR ("Math.asin/posInf", nan, fn () => Math.asin posInf)
  val () = eqR ("Math.asin/negInf", nan, fn () => Math.asin negInf)
  val () = eqR ("Math.asin/nan", nan, fn () => Math.asin nan)
  val () = approx ("Math.acos/one", 0.0, fn () => Math.acos 1.0)
  val () = approx ("Math.acos/half", pi / 3.0, fn () => Math.acos 0.5)
  val () = approx ("Math.acos/zero", pi / 2.0, fn () => Math.acos 0.0)
  val () = approx ("Math.acos/negative", 2.0 * pi / 3.0, fn () => Math.acos (~0.5))
  val () = approx ("Math.acos/minus-one", pi, fn () => Math.acos (~1.0))
  val () = eqR ("Math.acos/above-one", nan, fn () => Math.acos 1.5)
  val () = eqR ("Math.acos/just-above-one", nan, fn () => Math.acos (1.0 + 1E~15))
  val () = eqR ("Math.acos/below-minus-one", nan, fn () => Math.acos (~1.5))
  val () = eqR ("Math.acos/posInf", nan, fn () => Math.acos posInf)
  val () = eqR ("Math.acos/negInf", nan, fn () => Math.acos negInf)
  val () = eqR ("Math.acos/nan", nan, fn () => Math.acos nan)
  (* "Its result is guaranteed to be in the closed interval [-pi/2,pi/2]" and
     "[0,pi]"; the inverses of sin and cos. The bounds allow for the rounding
     of pi. *)
  val () = law ("Math.asin/law-range-and-inverse", 200, ~1000, 1000,
                fn x => let val a = Math.asin x
                        in Real.<= (Real.abs a, Math.pi / 2.0 + 1E~15) andalso close (Math.sin a, x) end)
  val () = law ("Math.acos/law-range-and-inverse", 200, ~1000, 1000,
                fn x => let val a = Math.acos x
                        in Real.>= (a, 0.0) andalso Real.<= (a, Math.pi + 1E~15) andalso close (Math.cos a, x) end)
  val () = law ("Math.acos/law-complements-asin", 200, ~1000, 1000,
                fn x => close (Math.asin x + Math.acos x, pi / 2.0))

  (* ---- atan ---- *)
  val () = approx ("Math.atan/zero", 0.0, fn () => Math.atan 0.0)
  val () = approx ("Math.atan/one", pi / 4.0, fn () => Math.atan 1.0)
  val () = approx ("Math.atan/minus-one", ~ pi / 4.0, fn () => Math.atan (~1.0))
  val () = approx ("Math.atan/sqrt-three", pi / 3.0, fn () => Math.atan (Math.sqrt 3.0))
  val () = approx ("Math.atan/huge", pi / 2.0, fn () => Math.atan 1E300)
  (* "If x is +infinity, it returns pi/2; if x is -infinity, it returns -pi/2." *)
  val () = approx ("Math.atan/posInf", pi / 2.0, fn () => Math.atan posInf)
  val () = approx ("Math.atan/negInf", ~ pi / 2.0, fn () => Math.atan negInf)
  val () = eqR ("Math.atan/nan", nan, fn () => Math.atan nan)
  val () = law ("Math.atan/law-range-and-inverse", 200, ~1000000, 1000000,
                fn x => let val a = Math.atan x
                        in Real.< (Real.abs a, pi / 2.0) andalso close (Math.tan a, x) end)

  (* ---- atan2 ---- *)
  (* the quadrant of the point (x, y) *)
  val () = approx ("Math.atan2/first-quadrant", pi / 4.0, fn () => Math.atan2 (1.0, 1.0))
  val () = approx ("Math.atan2/second-quadrant", 3.0 * pi / 4.0, fn () => Math.atan2 (1.0, ~1.0))
  val () = approx ("Math.atan2/third-quadrant", ~3.0 * pi / 4.0, fn () => Math.atan2 (~1.0, ~1.0))
  val () = approx ("Math.atan2/fourth-quadrant", ~ pi / 4.0, fn () => Math.atan2 (~1.0, 1.0))
  val () = approx ("Math.atan2/ratio", pi / 6.0, fn () => Math.atan2 (1.0, Math.sqrt 3.0))
  (* y = +-0, 0 < x: +-0 *)
  val () = eqR ("Math.atan2/zero-y-positive-x", 0.0, fn () => Math.atan2 (0.0, 1.0))
  val () = eqR ("Math.atan2/negzero-y-positive-x", ~0.0, fn () => Math.atan2 (~0.0, 1.0))
  (* y = +-0, x = +0: +-0 *)
  val () = eqR ("Math.atan2/zero-y-zero-x", 0.0, fn () => Math.atan2 (0.0, 0.0))
  val () = eqR ("Math.atan2/negzero-y-zero-x", ~0.0, fn () => Math.atan2 (~0.0, 0.0))
  (* y = +-0, x < 0: +-pi *)
  val () = approx ("Math.atan2/zero-y-negative-x", pi, fn () => Math.atan2 (0.0, ~1.0))
  val () = approx ("Math.atan2/negzero-y-negative-x", ~ pi, fn () => Math.atan2 (~0.0, ~1.0))
  (* y = +-0, x = -0: +-pi *)
  val () = approx ("Math.atan2/zero-y-negzero-x", pi, fn () => Math.atan2 (0.0, ~0.0))
  val () = approx ("Math.atan2/negzero-y-negzero-x", ~ pi, fn () => Math.atan2 (~0.0, ~0.0))
  (* 0 < y, x = +-0: pi/2 *)
  val () = approx ("Math.atan2/positive-y-zero-x", pi / 2.0, fn () => Math.atan2 (1.0, 0.0))
  val () = approx ("Math.atan2/positive-y-negzero-x", pi / 2.0, fn () => Math.atan2 (1.0, ~0.0))
  (* y < 0, x = +-0: -pi/2 *)
  val () = approx ("Math.atan2/negative-y-zero-x", ~ pi / 2.0, fn () => Math.atan2 (~1.0, 0.0))
  val () = approx ("Math.atan2/negative-y-negzero-x", ~ pi / 2.0, fn () => Math.atan2 (~1.0, ~0.0))
  (* +-y, finite y > 0, x = +infinity: +-0 *)
  val () = eqR ("Math.atan2/positive-y-posInf-x", 0.0, fn () => Math.atan2 (1.0, posInf))
  val () = eqR ("Math.atan2/negative-y-posInf-x", ~0.0, fn () => Math.atan2 (~1.0, posInf))
  (* +-y, finite y > 0, x = -infinity: +-pi *)
  val () = approx ("Math.atan2/positive-y-negInf-x", pi, fn () => Math.atan2 (1.0, negInf))
  val () = approx ("Math.atan2/negative-y-negInf-x", ~ pi, fn () => Math.atan2 (~1.0, negInf))
  (* y = +-infinity, finite x: +-pi/2 *)
  val () = approx ("Math.atan2/posInf-y-finite-x", pi / 2.0, fn () => Math.atan2 (posInf, 1.0))
  val () = approx ("Math.atan2/posInf-y-negative-x", pi / 2.0, fn () => Math.atan2 (posInf, ~1E300))
  val () = approx ("Math.atan2/posInf-y-zero-x", pi / 2.0, fn () => Math.atan2 (posInf, 0.0))
  val () = approx ("Math.atan2/negInf-y-finite-x", ~ pi / 2.0, fn () => Math.atan2 (negInf, 1.0))
  val () = approx ("Math.atan2/negInf-y-negative-x", ~ pi / 2.0, fn () => Math.atan2 (negInf, ~1.0))
  (* y = +-infinity, x = +infinity: +-pi/4 *)
  val () = approx ("Math.atan2/posInf-y-posInf-x", pi / 4.0, fn () => Math.atan2 (posInf, posInf))
  val () = approx ("Math.atan2/negInf-y-posInf-x", ~ pi / 4.0, fn () => Math.atan2 (negInf, posInf))
  (* y = +-infinity, x = -infinity: +-3pi/4 *)
  val () = approx ("Math.atan2/posInf-y-negInf-x", 3.0 * pi / 4.0, fn () => Math.atan2 (posInf, negInf))
  val () = approx ("Math.atan2/negInf-y-negInf-x", ~3.0 * pi / 4.0, fn () => Math.atan2 (negInf, negInf))
  val () = eqR ("Math.atan2/nan-y", nan, fn () => Math.atan2 (nan, 1.0))
  val () = eqR ("Math.atan2/nan-x", nan, fn () => Math.atan2 (1.0, nan))
  val () = eqR ("Math.atan2/nan-both", nan, fn () => Math.atan2 (nan, nan))
  (* "sign (cos (atan2 (y,x))) = sign (x)" and "sign (sin (atan2 (y,x))) =
     sign (y)", "except for inaccuracies": the points are kept away from the
     axes. The result is in [-pi, pi] and is atan (y/x) for x > 0. *)
  val () = T.check ("Math.atan2/law-quadrant", fn () =>
             let val ok = ref true
                 fun coord () = Real.fromInt (T.oneOf [~1, 1] * T.range (1, 1000))
             in T.seed 4;
                T.repeat (300, fn _ =>
                  let val y = coord () val x = coord ()
                      val a = Math.atan2 (y, x)
                  in if Real.sign (Math.cos a) = Real.sign x andalso Real.sign (Math.sin a) = Real.sign y
                        andalso Real.<= (Real.abs a, Math.pi)
                        andalso (Real.< (x, 0.0) orelse close (a, Math.atan (y / x)))
                        andalso close (Math.tan a, y / x)
                     then () else ok := false end);
                !ok end)

  (* ---- exp ---- *)
  val () = approx ("Math.exp/zero", 1.0, fn () => Math.exp 0.0)
  val () = approx ("Math.exp/one", e, fn () => Math.exp 1.0)
  val () = approx ("Math.exp/two", 7.38905609893065, fn () => Math.exp 2.0)
  val () = approx ("Math.exp/minus-one", 0.36787944117144233, fn () => Math.exp (~1.0))
  val () = approx ("Math.exp/large", 2.6881171418161356E43, fn () => Math.exp 100.0)
  (* "If x is +infinity, it returns +infinity; if x is -infinity, it returns 0." *)
  val () = eqR ("Math.exp/posInf", posInf, fn () => Math.exp posInf)
  val () = eqR ("Math.exp/negInf", 0.0, fn () => Math.exp negInf)
  val () = eqR ("Math.exp/nan", nan, fn () => Math.exp nan)
  val () = eqR ("Math.exp/overflow", posInf, fn () => Math.exp 1000.0)
  val () = eqR ("Math.exp/underflow", 0.0, fn () => Math.exp (~1000.0))
  val () = law ("Math.exp/law-sum-is-product", 200, ~20000, 20000,
                fn x => close (Math.exp (x + 1.5), Math.exp x * Math.exp 1.5))
  val () = law ("Math.exp/law-positive-and-inverse-of-ln", 200, ~20000, 20000,
                fn x => Real.> (Math.exp x, 0.0) andalso close (Math.ln (Math.exp x), x))

  (* ---- pow ---- *)
  val () = approx ("Math.pow/integer-power", 1024.0, fn () => Math.pow (2.0, 10.0))
  val () = approx ("Math.pow/square-root", 1.4142135623730951, fn () => Math.pow (2.0, 0.5))
  val () = approx ("Math.pow/negative-exponent", 0.5, fn () => Math.pow (4.0, ~0.5))
  val () = approx ("Math.pow/fractional", 5.656854249492381, fn () => Math.pow (2.0, 2.5))
  (* "well-defined when x > 0, or when x < 0 and y is integral" *)
  val () = approx ("Math.pow/negative-base-odd", ~8.0, fn () => Math.pow (~2.0, 3.0))
  val () = approx ("Math.pow/negative-base-even", 4.0, fn () => Math.pow (~2.0, 2.0))
  val () = approx ("Math.pow/negative-base-negative-odd", ~0.125, fn () => Math.pow (~2.0, ~3.0))
  val () = approx ("Math.pow/one-base", 1.0, fn () => Math.pow (1.0, 123.5))
  (* The rows of the table, in its order. x, including NaN; y = 0: 1 *)
  val () = eqR ("Math.pow/zero-exponent", 1.0, fn () => Math.pow (2.5, 0.0))
  val () = eqR ("Math.pow/zero-exponent-negative-base", 1.0, fn () => Math.pow (~2.5, 0.0))
  val () = eqR ("Math.pow/zero-exponent-zero-base", 1.0, fn () => Math.pow (0.0, 0.0))
  val () = eqR ("Math.pow/zero-exponent-posInf-base", 1.0, fn () => Math.pow (posInf, 0.0))
  val () = eqR ("Math.pow/zero-exponent-negInf-base", 1.0, fn () => Math.pow (negInf, 0.0))
  val () = eqR ("Math.pow/zero-exponent-nan-base", 1.0, fn () => Math.pow (nan, 0.0))
  val () = eqR ("Math.pow/negzero-exponent", 1.0, fn () => Math.pow (2.5, ~0.0))
  val () = eqR ("Math.pow/negzero-exponent-nan-base", 1.0, fn () => Math.pow (nan, ~0.0))
  (* |x| > 1, y = +infinity: +infinity *)
  val () = eqR ("Math.pow/large-base-posInf", posInf, fn () => Math.pow (2.0, posInf))
  val () = eqR ("Math.pow/large-negative-base-posInf", posInf, fn () => Math.pow (~2.0, posInf))
  val () = eqR ("Math.pow/posInf-base-posInf", posInf, fn () => Math.pow (posInf, posInf))
  val () = eqR ("Math.pow/negInf-base-posInf", posInf, fn () => Math.pow (negInf, posInf))
  (* |x| < 1, y = +infinity: +0 *)
  val () = eqR ("Math.pow/small-base-posInf", 0.0, fn () => Math.pow (0.5, posInf))
  val () = eqR ("Math.pow/small-negative-base-posInf", 0.0, fn () => Math.pow (~0.5, posInf))
  val () = eqR ("Math.pow/zero-base-posInf", 0.0, fn () => Math.pow (0.0, posInf))
  val () = eqR ("Math.pow/negzero-base-posInf", 0.0, fn () => Math.pow (~0.0, posInf))
  (* |x| > 1, y = -infinity: +0 *)
  val () = eqR ("Math.pow/large-base-negInf", 0.0, fn () => Math.pow (2.0, negInf))
  val () = eqR ("Math.pow/large-negative-base-negInf", 0.0, fn () => Math.pow (~2.0, negInf))
  val () = eqR ("Math.pow/negInf-base-negInf", 0.0, fn () => Math.pow (negInf, negInf))
  (* |x| < 1, y = -infinity: +infinity *)
  val () = eqR ("Math.pow/small-base-negInf", posInf, fn () => Math.pow (0.5, negInf))
  val () = eqR ("Math.pow/small-negative-base-negInf", posInf, fn () => Math.pow (~0.5, negInf))
  val () = eqR ("Math.pow/zero-base-negInf", posInf, fn () => Math.pow (0.0, negInf))
  val () = eqR ("Math.pow/negzero-base-negInf", posInf, fn () => Math.pow (~0.0, negInf))
  (* x = +infinity, y > 0: +infinity; y < 0: +0 *)
  val () = eqR ("Math.pow/posInf-base-positive", posInf, fn () => Math.pow (posInf, 2.0))
  val () = eqR ("Math.pow/posInf-base-small-positive", posInf, fn () => Math.pow (posInf, 0.5))
  val () = eqR ("Math.pow/posInf-base-negative", 0.0, fn () => Math.pow (posInf, ~2.0))
  val () = eqR ("Math.pow/posInf-base-small-negative", 0.0, fn () => Math.pow (posInf, ~0.5))
  (* x = -infinity; y > 0: -infinity for an odd integer, otherwise +infinity *)
  val () = eqR ("Math.pow/negInf-base-positive-odd", negInf, fn () => Math.pow (negInf, 3.0))
  val () = eqR ("Math.pow/negInf-base-positive-even", posInf, fn () => Math.pow (negInf, 2.0))
  val () = eqR ("Math.pow/negInf-base-positive-fraction", posInf, fn () => Math.pow (negInf, 2.5))
  (* x = -infinity; y < 0: -0 for an odd integer, otherwise +0 *)
  val () = eqR ("Math.pow/negInf-base-negative-odd", ~0.0, fn () => Math.pow (negInf, ~3.0))
  val () = eqR ("Math.pow/negInf-base-negative-even", 0.0, fn () => Math.pow (negInf, ~2.0))
  val () = eqR ("Math.pow/negInf-base-negative-fraction", 0.0, fn () => Math.pow (negInf, ~2.5))
  (* y = NaN: NaN; x = NaN, y <> 0: NaN *)
  val () = eqR ("Math.pow/nan-exponent", nan, fn () => Math.pow (2.0, nan))
  val () = eqR ("Math.pow/nan-exponent-zero-base", nan, fn () => Math.pow (0.0, nan))
  val () = eqR ("Math.pow/nan-exponent-posInf-base", nan, fn () => Math.pow (posInf, nan))
  val () = eqR ("Math.pow/nan-both", nan, fn () => Math.pow (nan, nan))
  val () = eqR ("Math.pow/nan-base", nan, fn () => Math.pow (nan, 2.0))
  val () = eqR ("Math.pow/nan-base-posInf", nan, fn () => Math.pow (nan, posInf))
  (* The page has "x, NaN: NaN" without an exception for x = 1 (C99 has
     pow (1, NaN) = 1) ... *)
  val () = eqR ("Math.pow/one-base-nan-exponent", nan, fn () => Math.pow (1.0, nan))
  (* ... and "+-1, +-infinity: NaN" (C99 has 1). *)
  val () = eqR ("Math.pow/one-base-posInf", nan, fn () => Math.pow (1.0, posInf))
  val () = eqR ("Math.pow/one-base-negInf", nan, fn () => Math.pow (1.0, negInf))
  val () = eqR ("Math.pow/minus-one-base-posInf", nan, fn () => Math.pow (~1.0, posInf))
  val () = eqR ("Math.pow/minus-one-base-negInf", nan, fn () => Math.pow (~1.0, negInf))
  (* finite x < 0, finite non-integer y: NaN *)
  val () = eqR ("Math.pow/negative-base-fraction", nan, fn () => Math.pow (~2.0, 0.5))
  val () = eqR ("Math.pow/negative-base-negative-fraction", nan, fn () => Math.pow (~8.0, ~1.5))
  (* x = +-0, y < 0 an odd integer: +-infinity *)
  val () = eqR ("Math.pow/zero-base-negative-odd", posInf, fn () => Math.pow (0.0, ~3.0))
  val () = eqR ("Math.pow/negzero-base-negative-odd", negInf, fn () => Math.pow (~0.0, ~3.0))
  (* x = +-0, finite y < 0 not an odd integer: +infinity *)
  val () = eqR ("Math.pow/zero-base-negative-even", posInf, fn () => Math.pow (0.0, ~2.0))
  val () = eqR ("Math.pow/negzero-base-negative-even", posInf, fn () => Math.pow (~0.0, ~2.0))
  val () = eqR ("Math.pow/negzero-base-negative-fraction", posInf, fn () => Math.pow (~0.0, ~2.5))
  (* x = +-0, y > 0 an odd integer: +-0 *)
  val () = eqR ("Math.pow/zero-base-positive-odd", 0.0, fn () => Math.pow (0.0, 3.0))
  val () = eqR ("Math.pow/negzero-base-positive-odd", ~0.0, fn () => Math.pow (~0.0, 3.0))
  (* x = +-0, y > 0 not an odd integer: +0 *)
  val () = eqR ("Math.pow/zero-base-positive-even", 0.0, fn () => Math.pow (0.0, 2.0))
  val () = eqR ("Math.pow/negzero-base-positive-even", 0.0, fn () => Math.pow (~0.0, 2.0))
  val () = eqR ("Math.pow/negzero-base-positive-fraction", 0.0, fn () => Math.pow (~0.0, 0.5))
  val () = law ("Math.pow/law-exponent-one-and-two", 200, 1, 1000000,
                fn x => close (Math.pow (x, 1.0), x) andalso close (Math.pow (x, 2.0), x * x)
                        andalso close (Math.pow (x, 0.5), Math.sqrt x)
                        andalso close (Math.pow (x, ~1.0), 1.0 / x))
  val () = law ("Math.pow/law-is-exp-of-ln", 200, 1, 100000,
                fn x => close (Math.pow (x, 1.75), Math.exp (1.75 * Math.ln x)))

  (* ---- ln, log10 ---- *)
  val () = approx ("Math.ln/one", 0.0, fn () => Math.ln 1.0)
  val () = approx ("Math.ln/e", 1.0, fn () => Math.ln Math.e)
  val () = approx ("Math.ln/two", 0.6931471805599453, fn () => Math.ln 2.0)
  val () = approx ("Math.ln/ten", 2.302585092994046, fn () => Math.ln 10.0)
  val () = approx ("Math.ln/half", ~0.6931471805599453, fn () => Math.ln 0.5)
  val () = approx ("Math.ln/minPos", ~1074.0 * 0.6931471805599453, fn () => Math.ln Real.minPos)
  (* "If x < 0, they return NaN; if x = 0, they return -infinity; if x is
     infinity, they return infinity." *)
  val () = eqR ("Math.ln/negative", nan, fn () => Math.ln (~1.0))
  val () = eqR ("Math.ln/negInf", nan, fn () => Math.ln negInf)
  val () = eqR ("Math.ln/zero", negInf, fn () => Math.ln 0.0)
  val () = eqR ("Math.ln/negzero", negInf, fn () => Math.ln (~0.0))
  val () = eqR ("Math.ln/posInf", posInf, fn () => Math.ln posInf)
  val () = eqR ("Math.ln/nan", nan, fn () => Math.ln nan)
  val () = approx ("Math.log10/one", 0.0, fn () => Math.log10 1.0)
  val () = approx ("Math.log10/ten", 1.0, fn () => Math.log10 10.0)
  val () = approx ("Math.log10/thousand", 3.0, fn () => Math.log10 1000.0)
  val () = approx ("Math.log10/hundredth", ~2.0, fn () => Math.log10 0.01)
  val () = approx ("Math.log10/two", 0.3010299956639812, fn () => Math.log10 2.0)
  val () = approx ("Math.log10/large", 300.0, fn () => Math.log10 1E300)
  val () = eqR ("Math.log10/negative", nan, fn () => Math.log10 (~1.0))
  val () = eqR ("Math.log10/negInf", nan, fn () => Math.log10 negInf)
  val () = eqR ("Math.log10/zero", negInf, fn () => Math.log10 0.0)
  val () = eqR ("Math.log10/negzero", negInf, fn () => Math.log10 (~0.0))
  val () = eqR ("Math.log10/posInf", posInf, fn () => Math.log10 posInf)
  val () = eqR ("Math.log10/nan", nan, fn () => Math.log10 nan)
  val () = law ("Math.ln/law-product-is-sum", 200, 1, 1000000,
                fn x => close (Math.ln (x * 3.0), Math.ln x + Math.ln 3.0) andalso close (Math.exp (Math.ln x), x))
  val () = law ("Math.log10/law-is-ln-over-ln-ten", 200, 1, 1000000,
                fn x => close (Math.log10 x, Math.ln x / Math.ln 10.0))

  (* ---- sinh, cosh, tanh ---- *)
  (* (e - 1/e) / 2, (e + 1/e) / 2 and their quotient *)
  val () = approx ("Math.sinh/one", 1.1752011936438014, fn () => Math.sinh 1.0)
  val () = approx ("Math.sinh/negative", ~1.1752011936438014, fn () => Math.sinh (~1.0))
  val () = approx ("Math.cosh/one", 1.5430806348152437, fn () => Math.cosh 1.0)
  val () = approx ("Math.cosh/negative", 1.5430806348152437, fn () => Math.cosh (~1.0))
  val () = approx ("Math.tanh/one", 0.7615941559557649, fn () => Math.tanh 1.0)
  val () = approx ("Math.tanh/negative", ~0.7615941559557649, fn () => Math.tanh (~1.0))
  (* "sinh +-0 = +-0", "sinh +-infinity = +-infinity" *)
  val () = eqR ("Math.sinh/zero", 0.0, fn () => Math.sinh 0.0)
  val () = eqR ("Math.sinh/negzero", ~0.0, fn () => Math.sinh (~0.0))
  val () = eqR ("Math.sinh/posInf", posInf, fn () => Math.sinh posInf)
  val () = eqR ("Math.sinh/negInf", negInf, fn () => Math.sinh negInf)
  val () = eqR ("Math.sinh/nan", nan, fn () => Math.sinh nan)
  val () = eqR ("Math.sinh/overflow", posInf, fn () => Math.sinh 1000.0)
  val () = eqR ("Math.sinh/negative-overflow", negInf, fn () => Math.sinh (~1000.0))
  (* "cosh +-0 = 1" *)
  val () = eqR ("Math.cosh/zero", 1.0, fn () => Math.cosh 0.0)
  val () = eqR ("Math.cosh/negzero", 1.0, fn () => Math.cosh (~0.0))
  val () = eqR ("Math.cosh/posInf", posInf, fn () => Math.cosh posInf)
  (* The page has "cosh +-infinity = +-infinity", which cannot be meant:
     (e^x + e^-x) / 2, the definition it gives, is +infinity at -infinity. *)
  val () = eqR ("Math.cosh/negInf", posInf, fn () => Math.cosh negInf)
  val () = eqR ("Math.cosh/nan", nan, fn () => Math.cosh nan)
  val () = eqR ("Math.cosh/overflow", posInf, fn () => Math.cosh (~1000.0))
  (* "tanh +-0 = +-0", "tanh +-infinity = +-1" *)
  val () = eqR ("Math.tanh/zero", 0.0, fn () => Math.tanh 0.0)
  val () = eqR ("Math.tanh/negzero", ~0.0, fn () => Math.tanh (~0.0))
  val () = eqR ("Math.tanh/posInf", 1.0, fn () => Math.tanh posInf)
  val () = eqR ("Math.tanh/negInf", ~1.0, fn () => Math.tanh negInf)
  val () = eqR ("Math.tanh/nan", nan, fn () => Math.tanh nan)
  (* (sinh x)/(cosh x) is 1 within 1E~9 for large finite x, where both
     overflow. *)
  val () = approx ("Math.tanh/large", 1.0, fn () => Math.tanh 1000.0)
  val () = approx ("Math.tanh/large-negative", ~1.0, fn () => Math.tanh (~1000.0))
  val () = law ("Math.sinh/law-definition", 200, ~20000, 20000,
                fn x => close (Math.sinh x, (Math.exp x - Math.exp (~ x)) / 2.0))
  val () = law ("Math.cosh/law-definition", 200, ~20000, 20000,
                fn x => close (Math.cosh x, (Math.exp x + Math.exp (~ x)) / 2.0) andalso Real.>= (Math.cosh x, 1.0))
  val () = law ("Math.tanh/law-definition", 200, ~20000, 20000,
                fn x => close (Math.tanh x, Math.sinh x / Math.cosh x) andalso Real.<= (Real.abs (Math.tanh x), 1.0))

  (* ---- Real.Math is the same structure ---- *)
  val () = eqR ("Math.pi/same-as-Real.Math", Math.pi, fn () => Real.Math.pi)
  val () = eqR ("Math.sqrt/same-as-Real.Math", 3.0, fn () => Real.Math.sqrt 9.0)
end
