(* requires: IEEEReal Real StringCvt *)
(* IEEEReal. Expected values follow the text of
   https://smlfamily.github.io/Basis/ieee-float.html. *)
structure TestIEEEReal =
struct
  structure I = IEEEReal
  val eqS = T.eq T.string

  fun showClass I.NAN = "NAN" | showClass I.INF = "INF" | showClass I.ZERO = "ZERO"
    | showClass I.NORMAL = "NORMAL" | showClass I.SUBNORMAL = "SUBNORMAL"
  fun showD ({class, sign, digits, exp} : I.decimal_approx) =
    "{" ^ showClass class ^ ", " ^ Bool.toString sign ^ ", " ^ T.list T.int digits ^ ", " ^ T.int exp ^ "}"
  fun d (class, sign, digits, exp) : I.decimal_approx = {class = class, sign = sign, digits = digits, exp = exp}
  val eqDO = T.eq (T.option showD)

  (* ---- toString ----
     "ZERO "0.0", NORMAL "0.d(1)d(2)...d(n)", SUBNORMAL likewise, INF "inf",
     NAN "nan". If the sign field is true, a #"~" is prepended. If the exp
     field is non-zero and the class is NORMAL or SUBNORMAL, the string
     "E"^(Integer.toString exp) is appended." *)
  val () = eqS ("IEEEReal.toString/zero", "0.0", fn () => I.toString (d (I.ZERO, false, [], 0)))
  val () = eqS ("IEEEReal.toString/negative-zero", "~0.0", fn () => I.toString (d (I.ZERO, true, [], 0)))
  val () = eqS ("IEEEReal.toString/zero-ignores-digits-and-exp", "0.0", fn () => I.toString (d (I.ZERO, false, [1, 2], 7)))
  val () = eqS ("IEEEReal.toString/normal", "0.123", fn () => I.toString (d (I.NORMAL, false, [1, 2, 3], 0)))
  val () = eqS ("IEEEReal.toString/normal-exp", "0.123E5", fn () => I.toString (d (I.NORMAL, false, [1, 2, 3], 5)))
  val () = eqS ("IEEEReal.toString/normal-negative-exp", "0.5E~2", fn () => I.toString (d (I.NORMAL, false, [5], ~2)))
  val () = eqS ("IEEEReal.toString/normal-negative", "~0.25E1", fn () => I.toString (d (I.NORMAL, true, [2, 5], 1)))
  val () = eqS ("IEEEReal.toString/subnormal", "0.494E~323", fn () => I.toString (d (I.SUBNORMAL, false, [4, 9, 4], ~323)))
  val () = eqS ("IEEEReal.toString/inf", "inf", fn () => I.toString (d (I.INF, false, [], 0)))
  val () = eqS ("IEEEReal.toString/negative-inf", "~inf", fn () => I.toString (d (I.INF, true, [], 0)))
  val () = eqS ("IEEEReal.toString/inf-ignores-exp", "inf", fn () => I.toString (d (I.INF, false, [], 3)))
  val () = eqS ("IEEEReal.toString/nan", "nan", fn () => I.toString (d (I.NAN, false, [], 0)))
  val () = eqS ("IEEEReal.toString/negative-nan", "~nan", fn () => I.toString (d (I.NAN, true, [], 0)))

  (* ---- scan, fromString ----
     "Initial zeros are stripped from the integer part and trailing zeros are
     stripped from the fractional part, yielding two lists il and fl. If il
     is non-empty, then class is set to NORMAL, digits is set to il@fl with
     any trailing zeros removed and exp is set to the length of il plus the
     value of the scanned exponent. If il is empty and so is fl, then class is
     set to ZERO, digits = [] and exp = 0. Finally, if il is empty but fl is
     not, let m be the number of leading zeros in fl ... digits is set to fl'
     and exp is set to -m plus the value of the scanned exponent." *)
  val () = eqDO ("IEEEReal.fromString/integer-and-fraction", SOME (d (I.NORMAL, false, [1, 5], 1)), fn () => I.fromString "1.5")
  val () = eqDO ("IEEEReal.fromString/integer", SOME (d (I.NORMAL, false, [1], 3)), fn () => I.fromString "100")
  val () = eqDO ("IEEEReal.fromString/leading-zeros", SOME (d (I.NORMAL, false, [4, 2], 2)), fn () => I.fromString "00042")
  val () = eqDO ("IEEEReal.fromString/small-fraction", SOME (d (I.NORMAL, false, [1, 2, 5], ~2)), fn () => I.fromString "0.00125")
  val () = eqDO ("IEEEReal.fromString/point-first", SOME (d (I.NORMAL, false, [5], 0)), fn () => I.fromString ".5")
  val () = eqDO ("IEEEReal.fromString/trailing-zeros", SOME (d (I.NORMAL, false, [1, 2, 5], 2)), fn () => I.fromString "12.5000")
  val () = eqDO ("IEEEReal.fromString/exponent", SOME (d (I.NORMAL, true, [1, 2, 5], 5)), fn () => I.fromString "  ~12.50E3")
  val () = eqDO ("IEEEReal.fromString/negative-exponent", SOME (d (I.NORMAL, true, [7], ~1)), fn () => I.fromString "-7e-2")
  val () = eqDO ("IEEEReal.fromString/plus-signs", SOME (d (I.NORMAL, false, [2], 11)), fn () => I.fromString "+2E+10")
  val () = eqDO ("IEEEReal.fromString/zero", SOME (d (I.ZERO, false, [], 0)), fn () => I.fromString "0")
  val () = eqDO ("IEEEReal.fromString/zero-with-exponent", SOME (d (I.ZERO, true, [], 0)), fn () => I.fromString "~0.000E5")
  val () = eqDO ("IEEEReal.fromString/inf", SOME (d (I.INF, false, [], 0)), fn () => I.fromString "inf")
  val () = eqDO ("IEEEReal.fromString/infinity-any-case", SOME (d (I.INF, true, [], 0)), fn () => I.fromString "~InFiNiTy")
  val () = eqDO ("IEEEReal.fromString/nan", SOME (d (I.NAN, false, [], 0)), fn () => I.fromString "+NaN")
  val () = eqDO ("IEEEReal.fromString/NONE-letters", NONE, fn () => I.fromString "abc")
  val () = eqDO ("IEEEReal.fromString/NONE-empty", NONE, fn () => I.fromString "")
  val () = eqDO ("IEEEReal.fromString/NONE-bare-point", NONE, fn () => I.fromString ".")
  val () = eqDO ("IEEEReal.fromString/NONE-sign-only", NONE, fn () => I.fromString "~")

  (* scan: the rest of the stream, with a reader over a char list *)
  fun getc [] = NONE
    | getc (c :: cs) = SOME (c, cs)
  fun scanned s = case I.scan getc (String.explode s) of
                    SOME (v, rest) => SOME (showD v, String.implode rest)
                  | NONE => NONE
  val eqSO = T.eq (T.option (T.pair (T.string, T.string)))
  val () = eqSO ("IEEEReal.scan/rest", SOME (showD (d (I.NORMAL, false, [1, 5], 1)), " apples"), fn () => scanned "1.5 apples")
  val () = eqSO ("IEEEReal.scan/incomplete-exponent", SOME (showD (d (I.NORMAL, false, [1], 1)), "E"), fn () => scanned "1E")
  val () = eqSO ("IEEEReal.scan/incomplete-exponent-sign", SOME (showD (d (I.NORMAL, false, [1], 1)), "e~x"), fn () => scanned "1e~x")
  val () = eqSO ("IEEEReal.scan/point-without-fraction", SOME (showD (d (I.NORMAL, false, [3], 1)), ".x"), fn () => scanned "3.x")
  val () = eqSO ("IEEEReal.scan/second-point", SOME (showD (d (I.NORMAL, false, [1, 2], 1)), ".3"), fn () => scanned "1.2.3")
  val () = eqSO ("IEEEReal.scan/inf-then-letters", SOME (showD (d (I.INF, false, [], 0)), "init"), fn () => scanned "infinit")
  val () = eqSO ("IEEEReal.scan/whitespace", SOME (showD (d (I.NORMAL, false, [9], 1)), ""), fn () => scanned " \t\n9")
  val () = eqSO ("IEEEReal.scan/NONE", NONE, fn () => scanned "x1")

  (* "The composition toString o REAL.toDecimal is equivalent to REAL.fmt StringCvt.EXACT." *)
  val () = eqS ("IEEEReal.toString/of-toDecimal", "0.15625E1", fn () => I.toString (Real.toDecimal 1.5625))
  val () = T.check ("IEEEReal.toString/is-fmt-EXACT",
                    fn () => List.all (fn r => I.toString (Real.toDecimal r) = Real.fmt StringCvt.EXACT r)
                                      [0.0, 1.0, ~2.5, 0.1, 1E100, 1E~100, 123456.789])

  (* ---- Unordered ---- "It raises IEEEReal.Unordered on unordered arguments." (REAL.compare) *)
  val nan = Real.posInf - Real.posInf
  val () = T.raises ("IEEEReal.Unordered/raised-by-Real.compare", fn I.Unordered => true | _ => false,
                     fn () => Real.compare (nan, 1.0))

  (* ---- rounding modes ----
     The quotient is computed when the check runs, from numbers the compiler
     cannot know, in each mode; the mode is set back afterwards. *)
  fun number n = Real.fromInt (List.length (List.tabulate (n, fn _ => ())))
  fun third mode = (I.setRoundingMode mode; number 1 / number 3) before I.setRoundingMode I.TO_NEAREST
  fun showMode I.TO_NEAREST = "TO_NEAREST" | showMode I.TO_NEGINF = "TO_NEGINF"
    | showMode I.TO_POSINF = "TO_POSINF" | showMode I.TO_ZERO = "TO_ZERO"
  val eqM = T.eq showMode
  val () = eqM ("IEEEReal.getRoundingMode/default", I.TO_NEAREST, fn () => I.getRoundingMode ())
  val () = List.app (fn m => eqM ("IEEEReal.setRoundingMode/then-get-" ^ showMode m, m,
                                  fn () => (I.setRoundingMode m; I.getRoundingMode ()) before I.setRoundingMode I.TO_NEAREST))
                    [I.TO_NEGINF, I.TO_POSINF, I.TO_ZERO, I.TO_NEAREST]
  val () = T.check ("IEEEReal.setRoundingMode/up-is-above-down", fn () => third I.TO_POSINF > third I.TO_NEGINF)
  val () = T.check ("IEEEReal.setRoundingMode/zero-is-down-for-positive", fn () => Real.== (third I.TO_ZERO, third I.TO_NEGINF))
  val () = T.check ("IEEEReal.setRoundingMode/nearest-is-one-of-them",
                    fn () => let val n = third I.TO_NEAREST in Real.== (n, third I.TO_POSINF) orelse Real.== (n, third I.TO_NEGINF) end)
  val () = eqM ("IEEEReal.getRoundingMode/restored", I.TO_NEAREST, fn () => I.getRoundingMode ())
end
