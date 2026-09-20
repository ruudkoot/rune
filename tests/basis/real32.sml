(* requires: Real32 IEEEReal IntInf Substring *)
(* Real32 (optional in the specification, signature REAL): IEEE 754 binary32.
   Expected values follow https://smlfamily.github.io/Basis/real.html and
   IEEE 754: an operation gives the binary32 value nearest the exact result,
   ties to even. A Real32.real is made with fromLarge from a real that binary32
   represents (no constant has the type Real32.real on a host that compiles
   Rune's library), and a result is compared as the real toLarge gives, which
   is exact. *)
structure TestReal32 =
struct
  fun s (x : real) : Real32.real = Real32.fromLarge IEEEReal.TO_NEAREST x
  val L = Real32.toLarge
  fun eq32 (label, expected : real, f : unit -> Real32.real) = T.eqReal (label, expected, fn () => L (f ()))
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val eqS = T.eq T.string
  val eqO = T.eq T.order
  val nan = Real32.- (Real32.posInf, Real32.posInf)
  fun ldexp (m, e) = Real.fromManExp {man = m, exp = e}
  val two24 = 16777216.0
  val minPos = ldexp (1.0, ~149)
  val minNormalPos = ldexp (1.0, ~126)
  val maxFinite = 3.4028234663852886E38
  val tenth = 0.100000001490116119384765625       (* 0.1 in binary32 *)
  val third = 0.3333333432674407958984375         (* 1/3 in binary32 *)
  fun classOf c = case c of IEEEReal.NAN => "NAN" | IEEEReal.INF => "INF" | IEEEReal.ZERO => "ZERO"
                          | IEEEReal.NORMAL => "NORMAL" | IEEEReal.SUBNORMAL => "SUBNORMAL"
  fun decimal ({class, sign, digits, exp} : IEEEReal.decimal_approx) =
    classOf class ^ " " ^ Bool.toString sign ^ " " ^ T.list T.int digits ^ " " ^ Int.toString exp

  (*<< constants *)
  val () = eqI ("Real32.radix/2", 2, fn () => Real32.radix)
  val () = eqI ("Real32.precision/24", 24, fn () => Real32.precision)
  val () = eq32 ("Real32.maxFinite/binary32", maxFinite, fn () => Real32.maxFinite)
  val () = eq32 ("Real32.minPos/2^-149", minPos, fn () => Real32.minPos)
  val () = eq32 ("Real32.minNormalPos/2^-126", minNormalPos, fn () => Real32.minNormalPos)
  val () = eq32 ("Real32.posInf/infinite", Real.posInf, fn () => Real32.posInf)
  val () = eq32 ("Real32.negInf/infinite", Real.negInf, fn () => Real32.negInf)
  (*>> constants *)

  (*<< arithmetic *)
  val () = eq32 ("Real32.+/exact", 3.75, fn () => Real32.+ (s 1.5, s 2.25))
  val () = eq32 ("Real32.+/tie-to-even", 1.0, fn () => Real32.+ (s 1.0, s (1.0 / two24)))
  val () = eq32 ("Real32.+/rounds-up", 1.00000011920928955078125, fn () => Real32.+ (s 1.0, s (1.5 / two24)))
  val () = eq32 ("Real32.+/overflow", Real.posInf, fn () => Real32.+ (Real32.maxFinite, Real32.maxFinite))
  val () = eq32 ("Real32.-/rounds", 0.999999940395355224609375, fn () => Real32.- (s 1.0, s 3E~8))
  val () = eq32 ("Real32.-/infinities", Real.posInf, fn () => Real32.- (Real32.posInf, Real32.negInf))
  val () = eq32 ("Real32.*/rounds", 281474943156224.0, fn () => Real32.* (s 16777215.0, s 16777215.0))
  val () = eq32 ("Real32.*/underflow", 0.0, fn () => Real32.* (Real32.minPos, s 0.25))
  val () = eq32 ("Real32.//one-third", third, fn () => Real32./ (s 1.0, s 3.0))
  val () = eq32 ("Real32.//by-zero", Real.negInf, fn () => Real32./ (s ~1.0, s 0.0))
  val () = eqB ("Real32.//zero-by-zero", true, fn () => Real32.isNan (Real32./ (s 0.0, s 0.0)))
  val () = eq32 ("Real32.rem/exact", 1.5, fn () => Real32.rem (s 7.5, s 2.0))
  val () = eq32 ("Real32.rem/sign-of-dividend", ~1.5, fn () => Real32.rem (s ~7.5, s 2.0))
  val () = eq32 ("Real32.*+/exact", 7.0, fn () => Real32.*+ (s 2.0, s 3.0, s 1.0))
  val () = eq32 ("Real32.*-/exact", 5.0, fn () => Real32.*- (s 2.0, s 3.0, s 1.0))
  val () = eq32 ("Real32.~/negates", ~1.5, fn () => Real32.~ (s 1.5))
  val () = eq32 ("Real32.~/zero", ~0.0, fn () => Real32.~ (s 0.0))
  val () = eq32 ("Real32.abs/negative", 2.5, fn () => Real32.abs (s ~2.5))
  val () = eq32 ("Real32.abs/negInf", Real.posInf, fn () => Real32.abs Real32.negInf)
  val () = eq32 ("Real32.min/smaller", ~1.0, fn () => Real32.min (s 2.0, s ~1.0))
  val () = eq32 ("Real32.min/nan", 1.0, fn () => Real32.min (nan, s 1.0))
  val () = eq32 ("Real32.max/larger", 2.0, fn () => Real32.max (s 2.0, s ~1.0))
  val () = eq32 ("Real32.max/nan", 1.0, fn () => Real32.max (s 1.0, nan))
  (*>> arithmetic *)

  (*<< sign-and-comparison *)
  val () = eqI ("Real32.sign/negative", ~1, fn () => Real32.sign (s ~0.5))
  val () = eqI ("Real32.sign/zero", 0, fn () => Real32.sign (s ~0.0))
  val () = T.raises ("Real32.sign/Domain-nan", T.isDomain, fn () => Real32.sign nan)
  val () = eqB ("Real32.signBit/negative-zero", true, fn () => Real32.signBit (s ~0.0))
  val () = eqB ("Real32.signBit/positive", false, fn () => Real32.signBit (s 3.0))
  val () = eqB ("Real32.sameSign/zeros", false, fn () => Real32.sameSign (s 0.0, s ~0.0))
  val () = eqB ("Real32.sameSign/negatives", true, fn () => Real32.sameSign (s ~1.0, Real32.negInf))
  val () = eq32 ("Real32.copySign/negative", ~2.0, fn () => Real32.copySign (s 2.0, s ~0.0))
  val () = eqO ("Real32.compare/less", LESS, fn () => Real32.compare (s 1.0, s 2.0))
  val () = eqO ("Real32.compare/zeros", EQUAL, fn () => Real32.compare (s 0.0, s ~0.0))
  val () = T.raises ("Real32.compare/Unordered-nan", fn IEEEReal.Unordered => true | _ => false,
                     fn () => Real32.compare (nan, s 1.0))
  val () = eqB ("Real32.compareReal/unordered", true,
                fn () => Real32.compareReal (s 1.0, nan) = IEEEReal.UNORDERED)
  val () = eqB ("Real32.compareReal/greater", true,
                fn () => Real32.compareReal (Real32.posInf, Real32.maxFinite) = IEEEReal.GREATER)
  val () = eqB ("Real32.</less", true, fn () => Real32.< (Real32.minPos, Real32.minNormalPos))
  val () = eqB ("Real32.</nan", false, fn () => Real32.< (nan, s 1.0))
  val () = eqB ("Real32.<=/equal", true, fn () => Real32.<= (s 1.0, s 1.0))
  val () = eqB ("Real32.>/greater", true, fn () => Real32.> (s 1.0, Real32.negInf))
  val () = eqB ("Real32.>=/nan", false, fn () => Real32.>= (nan, nan))
  val () = eqB ("Real32.==/zeros", true, fn () => Real32.== (s 0.0, s ~0.0))
  val () = eqB ("Real32.==/nan", false, fn () => Real32.== (nan, nan))
  val () = eqB ("Real32.!=/nan", true, fn () => Real32.!= (nan, nan))
  val () = eqB ("Real32.!=/equal", false, fn () => Real32.!= (s 2.0, s 2.0))
  val () = eqB ("Real32.?=/nan", true, fn () => Real32.?= (nan, s 1.0))
  val () = eqB ("Real32.?=/different", false, fn () => Real32.?= (s 2.0, s 1.0))
  val () = eqB ("Real32.unordered/nan", true, fn () => Real32.unordered (s 1.0, nan))
  val () = eqB ("Real32.unordered/numbers", false, fn () => Real32.unordered (s 1.0, Real32.posInf))
  (*>> sign-and-comparison *)

  (*<< classification *)
  val () = eqB ("Real32.isFinite/maxFinite", true, fn () => Real32.isFinite Real32.maxFinite)
  val () = eqB ("Real32.isFinite/posInf", false, fn () => Real32.isFinite Real32.posInf)
  val () = eqB ("Real32.isNan/nan", true, fn () => Real32.isNan nan)
  val () = eqB ("Real32.isNan/infinity", false, fn () => Real32.isNan Real32.negInf)
  val () = eqB ("Real32.isNormal/minNormalPos", true, fn () => Real32.isNormal Real32.minNormalPos)
  val () = eqB ("Real32.isNormal/minPos", false, fn () => Real32.isNormal Real32.minPos)
  val () = eqS ("Real32.class/subnormal", "SUBNORMAL", fn () => classOf (Real32.class (s 1E~40)))
  val () = eqS ("Real32.class/normal", "NORMAL", fn () => classOf (Real32.class Real32.maxFinite))
  val () = eqS ("Real32.class/zero", "ZERO", fn () => classOf (Real32.class (s ~0.0)))
  val () = eqS ("Real32.class/inf", "INF", fn () => classOf (Real32.class Real32.negInf))
  val () = eqS ("Real32.class/nan", "NAN", fn () => classOf (Real32.class nan))
  (*>> classification *)

  (*<< parts *)
  val () = T.check ("Real32.toManExp/six",
                    fn () => let val {man, exp} = Real32.toManExp (s 6.0) in T.sameReal (L man, 0.75) andalso exp = 3 end)
  val () = T.check ("Real32.toManExp/minPos",
                    fn () => let val {man, exp} = Real32.toManExp Real32.minPos in T.sameReal (L man, 0.5) andalso exp = ~148 end)
  val () = eq32 ("Real32.fromManExp/exact", 6.0, fn () => Real32.fromManExp {man = s 0.75, exp = 3})
  val () = eq32 ("Real32.fromManExp/overflow", Real.posInf, fn () => Real32.fromManExp {man = s 0.5, exp = 129})
  val () = eq32 ("Real32.fromManExp/rounds-to-minPos", minPos, fn () => Real32.fromManExp {man = s 0.75, exp = ~149})
  val () = T.check ("Real32.split/negative",
                    fn () => let val {whole, frac} = Real32.split (s ~2.5)
                             in T.sameReal (L whole, ~2.0) andalso T.sameReal (L frac, ~0.5) end)
  val () = eq32 ("Real32.realMod/fraction", 0.25, fn () => Real32.realMod (s 3.25))
  val () = eq32 ("Real32.nextAfter/up", 1.00000011920928955078125, fn () => Real32.nextAfter (s 1.0, s 2.0))
  val () = eq32 ("Real32.nextAfter/down", 0.999999940395355224609375, fn () => Real32.nextAfter (s 1.0, s 0.0))
  val () = eq32 ("Real32.nextAfter/maxFinite-up", Real.posInf, fn () => Real32.nextAfter (Real32.maxFinite, Real32.posInf))
  val () = eq32 ("Real32.nextAfter/zero-down", ~ minPos, fn () => Real32.nextAfter (s 0.0, s ~1.0))
  val () = eq32 ("Real32.nextAfter/minNormalPos-down", minNormalPos - minPos,
                 fn () => Real32.nextAfter (Real32.minNormalPos, s 0.0))
  val () = eq32 ("Real32.nextAfter/negative-away", ~1.00000011920928955078125, fn () => Real32.nextAfter (s ~1.0, Real32.negInf))
  val () = eqB ("Real32.nextAfter/nan", true, fn () => Real32.isNan (Real32.nextAfter (nan, s 1.0)))
  (* "If r = t then it returns r", and 0.0 = ~0.0 *)
  val () = eq32 ("Real32.nextAfter/equal-zeros-returns-r", ~0.0, fn () => Real32.nextAfter (s ~0.0, s 0.0))
  val () = eq32 ("Real32.nextAfter/equal-zeros-returns-r-positive", 0.0, fn () => Real32.nextAfter (s 0.0, s ~0.0))
  val () = eq32 ("Real32.checkFloat/finite", 1.5, fn () => Real32.checkFloat (s 1.5))
  val () = T.raises ("Real32.checkFloat/Overflow-inf", T.isOverflow, fn () => Real32.checkFloat Real32.posInf)
  val () = T.raises ("Real32.checkFloat/Div-nan", T.isDiv, fn () => Real32.checkFloat nan)
  (*>> parts *)

  (*<< integral *)
  val () = eq32 ("Real32.realFloor/negative", ~3.0, fn () => Real32.realFloor (s ~2.5))
  val () = eq32 ("Real32.realCeil/positive", 3.0, fn () => Real32.realCeil (s 2.5))
  val () = eq32 ("Real32.realTrunc/negative", ~2.0, fn () => Real32.realTrunc (s ~2.5))
  val () = eq32 ("Real32.realRound/tie-to-even", 2.0, fn () => Real32.realRound (s 2.5))
  val () = eq32 ("Real32.realRound/tie-up", 4.0, fn () => Real32.realRound (s 3.5))
  val () = eqI ("Real32.floor/negative", ~3, fn () => Real32.floor (s ~2.5))
  val () = eqI ("Real32.ceil/negative", ~2, fn () => Real32.ceil (s ~2.5))
  val () = eqI ("Real32.trunc/negative", ~2, fn () => Real32.trunc (s ~2.5))
  val () = eqI ("Real32.round/tie-to-even", 2, fn () => Real32.round (s 2.5))
  val () = T.raises ("Real32.floor/Overflow-inf", T.isOverflow, fn () => Real32.floor Real32.posInf)
  val () = T.raises ("Real32.round/Domain-nan", T.isDomain, fn () => Real32.round nan)
  val () = eqI ("Real32.toInt/TO_NEGINF", ~3, fn () => Real32.toInt IEEEReal.TO_NEGINF (s ~2.5))
  val () = eqI ("Real32.toInt/TO_NEAREST", 4, fn () => Real32.toInt IEEEReal.TO_NEAREST (s 3.5))
  val () = eqS ("Real32.toLargeInt/maxFinite", "340282346638528859811704183484516925440",
                fn () => IntInf.toString (Real32.toLargeInt IEEEReal.TO_NEAREST Real32.maxFinite))
  val () = T.raises ("Real32.toLargeInt/Overflow-inf", T.isOverflow, fn () => Real32.toLargeInt IEEEReal.TO_ZERO Real32.negInf)
  (*>> integral *)

  (*<< conversions *)
  val () = eq32 ("Real32.fromInt/exact", ~16777216.0, fn () => Real32.fromInt ~16777216)
  val () = eq32 ("Real32.fromInt/tie-to-even-down", 16777216.0, fn () => Real32.fromInt 16777217)
  val () = eq32 ("Real32.fromInt/tie-to-even-up", 16777220.0, fn () => Real32.fromInt 16777219)
  val () = eq32 ("Real32.fromLargeInt/rounds-once", 1152921642045800448.0,
                 fn () => Real32.fromLargeInt (IntInf.+ (IntInf.pow (IntInf.fromInt 2, 60),
                                                         IntInf.+ (IntInf.pow (IntInf.fromInt 2, 36), IntInf.fromInt 1))))
  val () = eq32 ("Real32.fromLargeInt/negative", ~1152921504606846976.0,
                 fn () => Real32.fromLargeInt (IntInf.~ (IntInf.pow (IntInf.fromInt 2, 60))))
  val () = eq32 ("Real32.fromLargeInt/overflow", Real.posInf,
                 fn () => Real32.fromLargeInt (IntInf.pow (IntInf.fromInt 2, 128)))
  val () = T.eqReal ("Real32.toLarge/tenth", tenth, fn () => Real32.toLarge (s 0.1))
  val () = eq32 ("Real32.fromLarge/TO_NEAREST", tenth, fn () => Real32.fromLarge IEEEReal.TO_NEAREST 0.1)
  val () = eq32 ("Real32.fromLarge/TO_ZERO", 0.0999999940395355224609375, fn () => Real32.fromLarge IEEEReal.TO_ZERO 0.1)
  val () = eq32 ("Real32.fromLarge/TO_POSINF", tenth, fn () => Real32.fromLarge IEEEReal.TO_POSINF 0.1)
  val () = eq32 ("Real32.fromLarge/TO_NEGINF-negative", ~ tenth, fn () => Real32.fromLarge IEEEReal.TO_NEGINF ~0.1)
  val () = eq32 ("Real32.fromLarge/overflow-TO_ZERO", maxFinite, fn () => Real32.fromLarge IEEEReal.TO_ZERO 1E39)
  val () = eq32 ("Real32.fromLarge/overflow-TO_NEAREST", Real.posInf, fn () => Real32.fromLarge IEEEReal.TO_NEAREST 1E39)
  val () = eq32 ("Real32.fromLarge/underflow", 0.0, fn () => Real32.fromLarge IEEEReal.TO_NEAREST 1E~50)
  val () = eq32 ("Real32.fromLarge/subnormal", minPos, fn () => Real32.fromLarge IEEEReal.TO_NEAREST 1E~45)
  (*>> conversions *)

  (*<< text *)
  val () = eqS ("Real32.toString/tenth", "0.10000000149", fn () => Real32.toString (s 0.1))
  val () = eqS ("Real32.toString/third", "0.333333343267", fn () => Real32.toString (Real32./ (s 1.0, s 3.0)))
  val () = eqS ("Real32.toString/negInf", "~inf", fn () => Real32.toString Real32.negInf)
  val () = eqS ("Real32.fmt/SCI", "1.000000E~1", fn () => Real32.fmt (StringCvt.SCI NONE) (s 0.1))
  val () = eqS ("Real32.fmt/FIX", "~2.500", fn () => Real32.fmt (StringCvt.FIX (SOME 3)) (s ~2.5))
  val () = eqS ("Real32.fmt/GEN-20", "0.10000000149011611938", fn () => Real32.fmt (StringCvt.GEN (SOME 20)) (s 0.1))
  val () = eqS ("Real32.fmt/EXACT-shortest", "0.1", fn () => Real32.fmt StringCvt.EXACT (s 0.1))
  val () = eqS ("Real32.fmt/EXACT-maxFinite", "0.34028235E39", fn () => Real32.fmt StringCvt.EXACT Real32.maxFinite)
  val () = T.raises ("Real32.fmt/Size-GEN-0", T.isSize, fn () => Real32.fmt (StringCvt.GEN (SOME 0)))
  val () = eqS ("Real32.toDecimal/tenth", "NORMAL false [1] 0", fn () => decimal (Real32.toDecimal (s 0.1)))
  val () = eqS ("Real32.toDecimal/maxFinite", "NORMAL false [3, 4, 0, 2, 8, 2, 3, 5] 39",
                fn () => decimal (Real32.toDecimal Real32.maxFinite))
  val () = eqS ("Real32.toDecimal/minPos", "SUBNORMAL false [1] ~44", fn () => decimal (Real32.toDecimal Real32.minPos))
  val () = eqS ("Real32.toDecimal/negative-zero", "ZERO true [] 0", fn () => decimal (Real32.toDecimal (s ~0.0)))
  val () = eq32 ("Real32.fromDecimal/tenth", tenth,
                 fn () => valOf (Real32.fromDecimal {class = IEEEReal.NORMAL, sign = false, digits = [1], exp = 0}))
  val () = eq32 ("Real32.fromDecimal/negative", ~ third,
                 fn () => valOf (Real32.fromDecimal {class = IEEEReal.NORMAL, sign = true,
                                                     digits = [3, 3, 3, 3, 3, 3, 3, 3, 3], exp = 0}))
  val () = eqB ("Real32.fromDecimal/NONE-bad-digit", true,
                fn () => not (isSome (Real32.fromDecimal {class = IEEEReal.NORMAL, sign = false, digits = [10], exp = 0})))
  val () = eq32 ("Real32.fromString/tenth", tenth, fn () => valOf (Real32.fromString "0.1"))
  (* above the tie 1 + 2^-24 by 2^-60, which binary64 rounds away: read at
     once to binary32, it rounds up *)
  val () = eq32 ("Real32.fromString/rounded-once", 1.00000011920928955078125,
                 fn () => valOf (Real32.fromString "1.000000059604644776257986757079"))
  val () = eq32 ("Real32.fromString/overflow", Real.posInf, fn () => valOf (Real32.fromString "3.4028236e38"))
  val () = eq32 ("Real32.fromString/largest", maxFinite, fn () => valOf (Real32.fromString "3.4028235e38"))
  val () = eq32 ("Real32.fromString/above-half-minPos", minPos, fn () => valOf (Real32.fromString "0.7006492321624087e~45"))
  val () = eq32 ("Real32.fromString/underflow", 0.0, fn () => valOf (Real32.fromString "1e~46"))
  val () = eq32 ("Real32.fromString/negative", ~ tenth, fn () => valOf (Real32.fromString "~0.1"))
  val () = eqB ("Real32.fromString/NONE", true, fn () => not (isSome (Real32.fromString "e5")))
  val () = T.check ("Real32.scan/rest",
                    fn () => case Real32.scan Substring.getc (Substring.full "  1.5x") of
                               SOME (r, rest) => T.sameReal (L r, 1.5) andalso Substring.string rest = "x"
                             | NONE => false)
  val () = eqB ("Real32.scan/inf", true,
                fn () => case Real32.scan Substring.getc (Substring.full "~inf") of
                           SOME (r, _) => Real32.== (r, Real32.negInf)
                         | NONE => false)
  (*>> text *)

  (*<< math *)
  val () = eq32 ("Real32.Math.sqrt/two", 1.41421353816986083984375, fn () => Real32.Math.sqrt (s 2.0))
  val () = eq32 ("Real32.Math.pi/binary32", 3.1415927410125732421875, fn () => Real32.Math.pi)
  val () = eq32 ("Real32.Math.exp/zero", 1.0, fn () => Real32.Math.exp (s 0.0))
  val () = eq32 ("Real32.Math.pow/exact", 1024.0, fn () => Real32.Math.pow (s 2.0, s 10.0))
  (*>> math *)

  (*<< rounding-modes *)
  fun inMode mode f =
    let val saved = IEEEReal.getRoundingMode ()
    in IEEEReal.setRoundingMode mode; (f () before IEEEReal.setRoundingMode saved)
       handle e => (IEEEReal.setRoundingMode saved; raise e)
    end
  val () = eq32 ("Real32.//TO_ZERO", 0.333333313465118408203125,
                 fn () => inMode IEEEReal.TO_ZERO (fn () => Real32./ (s 1.0, s 3.0)))
  val () = eq32 ("Real32.+/TO_POSINF", 1.00000011920928955078125,
                 fn () => inMode IEEEReal.TO_POSINF (fn () => Real32.+ (s 1.0, Real32.minPos)))
  val () = eq32 ("Real32.fromString/TO_NEGINF", 0.0999999940395355224609375,
                 fn () => inMode IEEEReal.TO_NEGINF (fn () => valOf (Real32.fromString "0.1")))
  val () = eq32 ("Real32.fromString/TO_POSINF-negative", ~0.0999999940395355224609375,
                 fn () => inMode IEEEReal.TO_POSINF (fn () => valOf (Real32.fromString "~0.1")))
  val () = eq32 ("Real32.fromDecimal/TO_NEGINF-negative", ~ tenth,
                 fn () => inMode IEEEReal.TO_NEGINF (fn () =>
                   valOf (Real32.fromDecimal {class = IEEEReal.NORMAL, sign = true, digits = [1], exp = 0})))
  (*>> rounding-modes *)
end
