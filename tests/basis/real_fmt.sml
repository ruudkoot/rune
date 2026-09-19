(* requires: Real StringCvt IEEEReal *)
(* Real: conversions to and from text and decimal approximations (fmt,
   toString, scan, fromString, toDecimal, fromDecimal). Expected values follow
   the text of https://smlfamily.github.io/Basis/real.html, of the description
   of realfmt (with its reference implementation of GEN) in
   https://smlfamily.github.io/Basis/string-cvt.html, and of IEEEReal.toString
   in https://smlfamily.github.io/Basis/ieee-float.html.

   The formats, with the grouping the pages lost restored:
     SCI    [~]?[0-9](.[0-9]+)?E[~]?[0-9]+
     FIX    [~]?[0-9]+(.[0-9]+)?
     scan   [+~-]?([0-9]+(.[0-9]+)? | .[0-9]+)((e|E)[+~-]?[0-9]+)?
            [+~-]?(inf | infinity | nan), case-insensitive
   Every expected string was worked out by hand. Where a decimal expansion is
   rounded, the digit that decides is far from a tie, so the expectation does
   not depend on the last bits of the binary value. *)
structure TestRealFmt =
struct
  val eqS = T.eq T.string

  val posInf = Real.posInf
  val negInf = Real.negInf
  val nan = Real.posInf - Real.posInf
  fun posNan () = Real.copySign (nan, 1.0)
  fun negNan () = Real.copySign (nan, ~1.0)

  fun pow2 (n : int) : real =
    if n = 0 then 1.0 else if n > 0 then 2.0 * pow2 (n - 1) else pow2 (n + 1) / 2.0

  val SCI = StringCvt.SCI
  val FIX = StringCvt.FIX
  val GEN = StringCvt.GEN
  val EXACT = StringCvt.EXACT

  (* checkWith (show, same) (label, expected, f): like T.eq, for a type that
     has no equality. *)
  fun checkWith (show : 'a -> string, same : 'a * 'a -> bool) (label, expected : 'a, f : unit -> 'a) : unit =
    case (SOME (f ()) handle _ => NONE) of
      SOME v => if same (v, expected) then T.pass label
                else T.fail (label, "got " ^ show v ^ ", expected " ^ show expected)
    | NONE => T.fail (label, "raised an exception, expected " ^ show expected)

  fun sameOpt (NONE, NONE) = true
    | sameOpt (SOME a, SOME b) = T.sameReal (a, b)
    | sameOpt _ = false
  val eqRO : string * real option * (unit -> real option) -> unit = checkWith (T.option T.real, sameOpt)

  (* Random finite reals, as in real.sml. *)
  fun randMantissa () : real =
    (Real.fromInt (T.range (0, 67108863)) * 134217728.0 + Real.fromInt (T.range (0, 134217727)))
    / 9007199254740992.0
  fun randReal (k : int) : real =
    let val m = (1.0 + randMantissa ()) * pow2 (T.range (~k, k))
    in if T.range (0, 1) = 0 then m else ~m end
  fun law (label, n : int, k : int, p : real -> bool) : unit =
    T.check (label, fn () =>
      let val ok = ref true
      in T.seed 20260918; T.repeat (n, fn _ => if p (randReal k) then () else ok := false); !ok end)

  (* ---- fmt (SCI arg) ----
     "there is always one digit before the decimal point, nonzero if the number
     is nonzero. arg specifies the number of digits to appear after the decimal
     point, with 6 the default if arg is NONE. If arg is SOME(0), no fractional
     digits and no decimal point are printed." "The exponent is zero if the
     value is zero." *)
  val () = eqS ("Real.fmt/SCI-default-one", "1.000000E0", fn () => Real.fmt (SCI NONE) 1.0)
  val () = eqS ("Real.fmt/SCI-default-zero", "0.000000E0", fn () => Real.fmt (SCI NONE) 0.0)
  (* 1.23456789E5: the seventh digit after the point is 8 *)
  val () = eqS ("Real.fmt/SCI-default-rounds", "1.234568E5", fn () => Real.fmt (SCI NONE) 123456.789)
  val () = eqS ("Real.fmt/SCI-default-negative", "~1.500000E1", fn () => Real.fmt (SCI NONE) (~15.0))
  val () = eqS ("Real.fmt/SCI-two-digits", "1.23E2", fn () => Real.fmt (SCI (SOME 2)) 123.456)
  val () = eqS ("Real.fmt/SCI-zero-digits", "5E10", fn () => Real.fmt (SCI (SOME 0)) 5E10)
  val () = eqS ("Real.fmt/SCI-zero-digits-one", "1E0", fn () => Real.fmt (SCI (SOME 0)) 1.0)
  val () = eqS ("Real.fmt/SCI-zero-digits-zero", "0E0", fn () => Real.fmt (SCI (SOME 0)) 0.0)
  val () = eqS ("Real.fmt/SCI-zero-digits-rounds", "3E0", fn () => Real.fmt (SCI (SOME 0)) 2.7)
  val () = eqS ("Real.fmt/SCI-negative-exponent", "1.250E~3", fn () => Real.fmt (SCI (SOME 3)) 0.00125)
  val () = eqS ("Real.fmt/SCI-negative-both", "~5.0E~1", fn () => Real.fmt (SCI (SOME 1)) (~0.5))
  val () = eqS ("Real.fmt/SCI-pads-with-zeros", "2.50E~1", fn () => Real.fmt (SCI (SOME 2)) 0.25)
  val () = eqS ("Real.fmt/SCI-ten-digits", "5.0000000000E~1", fn () => Real.fmt (SCI (SOME 10)) 0.5)
  val () = eqS ("Real.fmt/SCI-twenty-digits", "1.00000000000000000000E0", fn () => Real.fmt (SCI (SOME 20)) 1.0)
  (* 9.96 rounds to 10.0: the mantissa is renormalized to one digit *)
  val () = eqS ("Real.fmt/SCI-carry", "1.0E1", fn () => Real.fmt (SCI (SOME 1)) 9.96)
  val () = eqS ("Real.fmt/SCI-carry-zero-digits", "1E3", fn () => Real.fmt (SCI (SOME 0)) 999.9)
  val () = eqS ("Real.fmt/SCI-power-of-ten", "1.00E10", fn () => Real.fmt (SCI (SOME 2)) 1E10)
  val () = eqS ("Real.fmt/SCI-small-power-of-ten", "1.00E~10", fn () => Real.fmt (SCI (SOME 2)) 1E~10)
  val () = eqS ("Real.fmt/SCI-large-exponent", "1.0E300", fn () => Real.fmt (SCI (SOME 1)) 1E300)
  (* maxFinite = 1.7976931348623157...E308, minPos = 4.9406564584124654...E~324 *)
  val () = eqS ("Real.fmt/SCI-maxFinite", "1.797693E308", fn () => Real.fmt (SCI NONE) Real.maxFinite)
  val () = eqS ("Real.fmt/SCI-minPos", "4.940656E~324", fn () => Real.fmt (SCI NONE) Real.minPos)
  val () = eqS ("Real.fmt/SCI-minNormalPos", "2.2251E~308", fn () => Real.fmt (SCI (SOME 4)) Real.minNormalPos)

  (* ---- fmt (FIX arg) ---- *)
  val () = eqS ("Real.fmt/FIX-default-one", "1.000000", fn () => Real.fmt (FIX NONE) 1.0)
  val () = eqS ("Real.fmt/FIX-default-zero", "0.000000", fn () => Real.fmt (FIX NONE) 0.0)
  val () = eqS ("Real.fmt/FIX-default-rounds", "3.141593", fn () => Real.fmt (FIX NONE) 3.14159265)
  val () = eqS ("Real.fmt/FIX-default-negative", "~123.500000", fn () => Real.fmt (FIX NONE) (~123.5))
  val () = eqS ("Real.fmt/FIX-zero-digits", "3", fn () => Real.fmt (FIX (SOME 0)) 3.0)
  val () = eqS ("Real.fmt/FIX-zero-digits-rounds-up", "3", fn () => Real.fmt (FIX (SOME 0)) 2.7)
  val () = eqS ("Real.fmt/FIX-zero-digits-rounds-down", "2", fn () => Real.fmt (FIX (SOME 0)) 2.2)
  val () = eqS ("Real.fmt/FIX-zero-digits-negative", "~3", fn () => Real.fmt (FIX (SOME 0)) (~2.7))
  (* "there is always at least one digit before the decimal point" *)
  val () = eqS ("Real.fmt/FIX-zero-digits-fraction-up", "1", fn () => Real.fmt (FIX (SOME 0)) 0.75)
  val () = eqS ("Real.fmt/FIX-zero-digits-fraction-down", "0", fn () => Real.fmt (FIX (SOME 0)) 0.25)
  val () = eqS ("Real.fmt/FIX-zero-digits-zero", "0", fn () => Real.fmt (FIX (SOME 0)) 0.0)
  val () = eqS ("Real.fmt/FIX-one-digit", "123456.8", fn () => Real.fmt (FIX (SOME 1)) 123456.789)
  val () = eqS ("Real.fmt/FIX-pads-with-zeros", "0.50", fn () => Real.fmt (FIX (SOME 2)) 0.5)
  val () = eqS ("Real.fmt/FIX-integral", "2.000", fn () => Real.fmt (FIX (SOME 3)) 2.0)
  val () = eqS ("Real.fmt/FIX-exact-fraction", "~0.0625", fn () => Real.fmt (FIX (SOME 4)) (~0.0625))
  val () = eqS ("Real.fmt/FIX-power-of-ten", "10000000000.00", fn () => Real.fmt (FIX (SOME 2)) 1E10)
  (* 1E20 = 2^20 * 5^20 is an integer that is a real *)
  val () = eqS ("Real.fmt/FIX-ten-to-the-20th", "100000000000000000000", fn () => Real.fmt (FIX (SOME 0)) 1E20)
  val () = eqS ("Real.fmt/FIX-rounds-to-zero", "0.000", fn () => Real.fmt (FIX (SOME 3)) 0.0001)
  val () = eqS ("Real.fmt/FIX-small", "0.0001", fn () => Real.fmt (FIX (SOME 4)) 0.0001)
  val () = eqS ("Real.fmt/FIX-carry", "1.0", fn () => Real.fmt (FIX (SOME 1)) 0.96)
  val () = eqS ("Real.fmt/FIX-carry-adds-digit", "100.0", fn () => Real.fmt (FIX (SOME 1)) 99.96)
  val () = eqS ("Real.fmt/FIX-carry-zero-digits", "1000", fn () => Real.fmt (FIX (SOME 0)) 999.9)
  val () = eqS ("Real.fmt/FIX-twenty-digits", "0.50000000000000000000", fn () => Real.fmt (FIX (SOME 20)) 0.5)
  (* 2^~10 = 0.0009765625 exactly *)
  val () = eqS ("Real.fmt/FIX-exact-binary-fraction", "0.0009765625", fn () => Real.fmt (FIX (SOME 10)) (pow2 ~10))
  val () = eqS ("Real.fmt/FIX-exact-binary-fraction-rounded", "0.00098", fn () => Real.fmt (FIX (SOME 5)) (pow2 ~10))
  val () = eqS ("Real.fmt/FIX-minPos", "0.000000", fn () => Real.fmt (FIX NONE) Real.minPos)

  (* ---- fmt (GEN arg), toString ----
     "either the scientific or fixed-point notation, whichever is shorter,
     breaking ties in favor of fixed-point. The optional integer value
     specifies the maximum number of significant digits used, with 12 the
     default. The string should display as many significant digits as
     possible, subject to this maximum. There should not be any trailing zeros
     after the decimal point. There should not be a decimal point unless a
     fractional part is included." *)
  val () = eqS ("Real.fmt/GEN-half", "0.5", fn () => Real.fmt (GEN NONE) 0.5)
  val () = eqS ("Real.fmt/GEN-eighth", "0.125", fn () => Real.fmt (GEN NONE) 0.125)
  val () = eqS ("Real.fmt/GEN-negative", "~2.5", fn () => Real.fmt (GEN NONE) (~2.5))
  val () = eqS ("Real.fmt/GEN-nine-digits", "123456.789", fn () => Real.fmt (GEN NONE) 123456.789)
  val () = eqS ("Real.fmt/GEN-tenth", "0.1", fn () => Real.fmt (GEN NONE) 0.1)
  (* twelve significant digits *)
  val () = eqS ("Real.fmt/GEN-third", "0.333333333333", fn () => Real.fmt (GEN NONE) (1.0 / 3.0))
  val () = eqS ("Real.fmt/GEN-two-thirds", "0.666666666667", fn () => Real.fmt (GEN NONE) (2.0 / 3.0))
  val () = eqS ("Real.fmt/GEN-pi", "3.14159265359", fn () => Real.fmt (GEN NONE) 3.14159265358979)
  (* "0.01" and "1E~2" tie, fixed-point wins; "0.001" is longer than "1E~3" *)
  val () = eqS ("Real.fmt/GEN-notation-hundredth", "0.01", fn () => Real.fmt (GEN NONE) 0.01)
  val () = eqS ("Real.fmt/GEN-notation-thousandth", "1E~3", fn () => Real.fmt (GEN NONE) 0.001)
  val () = eqS ("Real.fmt/GEN-notation-small-tie", "0.00125", fn () => Real.fmt (GEN NONE) 0.00125)
  val () = eqS ("Real.fmt/GEN-notation-small-scientific", "1.25E~4", fn () => Real.fmt (GEN NONE) 0.000125)
  val () = eqS ("Real.fmt/GEN-notation-large", "1E10", fn () => Real.fmt (GEN NONE) 1E10)
  val () = eqS ("Real.fmt/GEN-notation-large-fraction", "1.5E10", fn () => Real.fmt (GEN NONE) 1.5E10)
  val () = eqS ("Real.fmt/GEN-notation-large-mantissa", "1.2345E8", fn () => Real.fmt (GEN NONE) 1.2345E8)
  val () = eqS ("Real.fmt/GEN-notation-huge", "1E100", fn () => Real.fmt (GEN NONE) 1E100)
  val () = eqS ("Real.fmt/GEN-notation-tiny", "1E~100", fn () => Real.fmt (GEN NONE) 1E~100)
  val () = eqS ("Real.fmt/GEN-notation-negative", "~1.5E~7", fn () => Real.fmt (GEN NONE) (~1.5E~7))
  val () = eqS ("Real.fmt/GEN-maxFinite", "1.79769313486E308", fn () => Real.fmt (GEN NONE) Real.maxFinite)
  val () = eqS ("Real.fmt/GEN-minPos", "4.94065645841E~324", fn () => Real.fmt (GEN NONE) Real.minPos)
  (* a maximum number of significant digits *)
  val () = eqS ("Real.fmt/GEN-five-digits", "3.1416", fn () => Real.fmt (GEN (SOME 5)) 3.14159265)
  val () = eqS ("Real.fmt/GEN-two-digits", "0.12", fn () => Real.fmt (GEN (SOME 2)) 0.123)
  val () = eqS ("Real.fmt/GEN-no-trailing-zeros", "0.5", fn () => Real.fmt (GEN (SOME 3)) 0.5)
  val () = eqS ("Real.fmt/GEN-notation-one-digit", "3E~5", fn () => Real.fmt (GEN (SOME 1)) 2.7E~5)
  (* 0.1 = 0.1000000000000000055511151231257827...: seventeen digits show it *)
  val () = eqS ("Real.fmt/GEN-seventeen-digits", "0.10000000000000001", fn () => Real.fmt (GEN (SOME 17)) 0.1)
  val () = eqS ("Real.fmt/GEN-sixteen-digits", "0.1", fn () => Real.fmt (GEN (SOME 16)) 0.1)

  (* Integral values: "There should not be a decimal point unless a fractional
     part is included", and the reference implementation gcvt of the StringCvt
     page gives "1" for 1.0. "100" and "1E2" tie, "1000" is longer than "1E3". *)
  val () = eqS ("Real.fmt/GEN-integral-one", "1", fn () => Real.fmt (GEN NONE) 1.0)
  val () = eqS ("Real.fmt/GEN-integral-zero", "0", fn () => Real.fmt (GEN NONE) 0.0)
  val () = eqS ("Real.fmt/GEN-integral-negative", "~42", fn () => Real.fmt (GEN NONE) (~42.0))
  val () = eqS ("Real.fmt/GEN-integral-hundred", "100", fn () => Real.fmt (GEN NONE) 100.0)
  val () = eqS ("Real.fmt/GEN-integral-five-digits", "12345", fn () => Real.fmt (GEN NONE) 12345.0)
  val () = eqS ("Real.fmt/GEN-integral-rounded", "3", fn () => Real.fmt (GEN (SOME 1)) 2.6)
  val () = eqS ("Real.fmt/GEN-integral-carry", "10", fn () => Real.fmt (GEN (SOME 1)) 9.6)
  (* "whichever is shorter": trailing zeros of an integer make the scientific
     notation the shorter one from "1E3" on; with more digits the fixed-point
     notation stays shorter for longer ("12345000" ties with "1.2345E7"). *)
  val () = eqS ("Real.fmt/GEN-notation-thousand", "1E3", fn () => Real.fmt (GEN NONE) 1000.0)
  val () = eqS ("Real.fmt/GEN-notation-tie-is-fixed", "12345000", fn () => Real.fmt (GEN NONE) 1.2345E7)
  (* Digits beyond the maximum are zeros in fixed-point notation: gcvt gives
     "123500", which is shorter than "1.235E5". *)
  val () = eqS ("Real.fmt/GEN-notation-padded", "123500", fn () => Real.fmt (GEN (SOME 4)) 123456.789)
  val () = eqS ("Real.fmt/GEN-notation-padded-integer", "1230", fn () => Real.fmt (GEN (SOME 3)) 1234.0)

  (* "The value returned by toString is equivalent to (fmt (StringCvt.GEN NONE) r)" *)
  val () = eqS ("Real.toString/half", "0.5", fn () => Real.toString 0.5)
  val () = eqS ("Real.toString/negative", "~2.5", fn () => Real.toString (~2.5))
  val () = eqS ("Real.toString/twelve-digits", "0.333333333333", fn () => Real.toString (1.0 / 3.0))
  val () = eqS ("Real.toString/nine-digits", "123456.789", fn () => Real.toString 123456.789)
  val () = eqS ("Real.toString/notation-large", "1E10", fn () => Real.toString 1E10)
  val () = eqS ("Real.toString/notation-small", "1.25E~4", fn () => Real.toString 0.000125)
  val () = eqS ("Real.toString/maxFinite", "1.79769313486E308", fn () => Real.toString Real.maxFinite)
  val () = eqS ("Real.toString/posInf", "inf", fn () => Real.toString posInf)
  val () = eqS ("Real.toString/negInf", "~inf", fn () => Real.toString negInf)
  val () = eqS ("Real.toString/nan", "nan", fn () => Real.toString (posNan ()))
  val () = eqS ("Real.toString/integral-one", "1", fn () => Real.toString 1.0)
  val () = eqS ("Real.toString/integral-zero", "0", fn () => Real.toString 0.0)
  val () = eqS ("Real.toString/integral-negative", "~42", fn () => Real.toString (~42.0))
  val () = law ("Real.toString/law-is-fmt-GEN-NONE", 300, 300, fn x => Real.toString x = Real.fmt (GEN NONE) x)

  (* ---- fmt EXACT: "refer to IEEEReal.toString", where
     "toString o REAL.toDecimal is equivalent to REAL.fmt StringCvt.EXACT":
     [~]0.d1d2...dn[E exp] with the fewest digits that give the real back. *)
  val () = eqS ("Real.fmt/EXACT-half", "0.5", fn () => Real.fmt EXACT 0.5)
  val () = eqS ("Real.fmt/EXACT-quarter", "0.25", fn () => Real.fmt EXACT 0.25)
  val () = eqS ("Real.fmt/EXACT-one", "0.1E1", fn () => Real.fmt EXACT 1.0)
  val () = eqS ("Real.fmt/EXACT-tenth", "0.1", fn () => Real.fmt EXACT 0.1)
  val () = eqS ("Real.fmt/EXACT-negative", "~0.25E1", fn () => Real.fmt EXACT (~2.5))
  val () = eqS ("Real.fmt/EXACT-six-digits", "0.123456E3", fn () => Real.fmt EXACT 123.456)
  val () = eqS ("Real.fmt/EXACT-negative-exponent", "0.1E~2", fn () => Real.fmt EXACT 0.001)
  val () = eqS ("Real.fmt/EXACT-sixteenth", "0.625E~1", fn () => Real.fmt EXACT 0.0625)
  val () = eqS ("Real.fmt/EXACT-power-of-ten", "0.1E11", fn () => Real.fmt EXACT 1E10)
  val () = eqS ("Real.fmt/EXACT-maxFinite", "0.17976931348623157E309", fn () => Real.fmt EXACT Real.maxFinite)
  val () = eqS ("Real.fmt/EXACT-zero", "0.0", fn () => Real.fmt EXACT 0.0)
  val () = eqS ("Real.fmt/EXACT-negzero", "~0.0", fn () => Real.fmt EXACT (~0.0))

  (* ---- infinities and NaN: "In all cases, positive and negative infinities
     are converted to "inf" and "~inf", respectively, and NaN values are
     converted to the string "nan"." ---- *)
  val formats = [("SCI", SCI NONE), ("SCI-digits", SCI (SOME 2)), ("FIX", FIX NONE), ("FIX-digits", FIX (SOME 0)),
                 ("GEN", GEN NONE), ("GEN-digits", GEN (SOME 3)), ("EXACT", EXACT)]
  val () = List.app (fn (name, spec) =>
             (eqS ("Real.fmt/" ^ name ^ "-posInf", "inf", fn () => Real.fmt spec posInf);
              eqS ("Real.fmt/" ^ name ^ "-negInf", "~inf", fn () => Real.fmt spec negInf);
              eqS ("Real.fmt/" ^ name ^ "-nan", "nan", fn () => Real.fmt spec (posNan ()));
              eqS ("Real.fmt/" ^ name ^ "-negative-nan", "nan", fn () => Real.fmt spec (negNan ())))) formats

  (* The sign of a negative zero: "[~]?" is the sign of the number, and signBit
     (~0.0) is true ("zeros ... included"); IEEEReal.toString is explicit ("If
     the sign field is true, a #"~" is prepended"). *)
  val () = eqS ("Real.fmt/SCI-negzero", "~0.0E0", fn () => Real.fmt (SCI (SOME 1)) (~0.0))
  val () = eqS ("Real.fmt/FIX-negzero", "~0.0", fn () => Real.fmt (FIX (SOME 1)) (~0.0))
  val () = eqS ("Real.fmt/GEN-integral-negzero", "~0", fn () => Real.fmt (GEN NONE) (~0.0))

  (* ---- fmt raises Size: "if spec is SCI (SOME i) with i < 0, FIX (SOME i)
     with i < 0, GEN (SOME i) with i < 1. The exception should be raised when
     fmt spec is evaluated." ---- *)
  val () = T.raises ("Real.fmt/Size-SCI-negative", T.isSize, fn () => Real.fmt (SCI (SOME ~1)) 1.0)
  val () = T.raises ("Real.fmt/Size-FIX-negative", T.isSize, fn () => Real.fmt (FIX (SOME ~1)) 1.0)
  val () = T.raises ("Real.fmt/Size-GEN-zero", T.isSize, fn () => Real.fmt (GEN (SOME 0)) 1.0)
  val () = T.raises ("Real.fmt/Size-GEN-negative", T.isSize, fn () => Real.fmt (GEN (SOME ~5)) 1.0)
  val () = T.raises ("Real.fmt/Size-SCI-infinite-argument", T.isSize, fn () => Real.fmt (SCI (SOME ~1)) posInf)
  val () = T.raises ("Real.fmt/Size-SCI-when-spec-is-evaluated", T.isSize, fn () => Real.fmt (SCI (SOME ~1)))
  val () = T.raises ("Real.fmt/Size-FIX-when-spec-is-evaluated", T.isSize, fn () => Real.fmt (FIX (SOME ~1)))
  val () = T.raises ("Real.fmt/Size-GEN-when-spec-is-evaluated", T.isSize, fn () => Real.fmt (GEN (SOME 0)))
  val () = eqS ("Real.fmt/GEN-one-is-valid", "0.3", fn () => Real.fmt (GEN (SOME 1)) 0.3)

  (* ---- scan, fromString ---- *)
  (* A reader over a list of characters shows what scan leaves unused. *)
  fun getc ([] : char list) = NONE
    | getc (c :: cs) = SOME (c, cs)
  fun scanRest (s : string) : (real * string) option =
    case Real.scan getc (String.explode s) of
      NONE => NONE
    | SOME (r, rest) => SOME (r, String.implode rest)
  fun sameScan (NONE, NONE) = true
    | sameScan (SOME (a, s : string), SOME (b, t)) = T.sameReal (a, b) andalso s = t
    | sameScan _ = false
  val eqScan : string * (real * string) option * (unit -> (real * string) option) -> unit =
    checkWith (T.option (T.pair (T.real, T.string)), sameScan)

  val () = eqRO ("Real.fromString/basic", SOME 1.5, fn () => Real.fromString "1.5")
  val () = eqRO ("Real.fromString/integer", SOME 12.0, fn () => Real.fromString "12")
  val () = eqRO ("Real.fromString/zero", SOME 0.0, fn () => Real.fromString "0")
  val () = eqRO ("Real.fromString/leading-zeros", SOME 7.5, fn () => Real.fromString "007.50")
  val () = eqRO ("Real.fromString/exact-many-digits", SOME 0.1, fn () => Real.fromString "0.1000000000000000000000000000000")
  (* [+~-]? *)
  val () = eqRO ("Real.fromString/tilde", SOME ~1.5, fn () => Real.fromString "~1.5")
  val () = eqRO ("Real.fromString/minus", SOME ~1.5, fn () => Real.fromString "-1.5")
  val () = eqRO ("Real.fromString/plus", SOME 1.5, fn () => Real.fromString "+1.5")
  val () = eqRO ("Real.fromString/negative-zero", SOME ~0.0, fn () => Real.fromString "~0.0")
  val () = eqRO ("Real.fromString/minus-zero", SOME ~0.0, fn () => Real.fromString "-0")
  (* .[0-9]+ *)
  val () = eqRO ("Real.fromString/no-integer-part", SOME 0.5, fn () => Real.fromString ".5")
  val () = eqRO ("Real.fromString/negative-no-integer-part", SOME ~0.25, fn () => Real.fromString "~.25")
  (* (e|E)[+~-]?[0-9]+ *)
  val () = eqRO ("Real.fromString/exponent", SOME 100000.0, fn () => Real.fromString "1E5")
  val () = eqRO ("Real.fromString/lowercase-exponent", SOME 100000.0, fn () => Real.fromString "1e5")
  val () = eqRO ("Real.fromString/tilde-exponent", SOME 0.25, fn () => Real.fromString "25e~2")
  val () = eqRO ("Real.fromString/minus-exponent", SOME 0.015, fn () => Real.fromString "1.5E-2")
  val () = eqRO ("Real.fromString/plus-exponent", SOME 150.0, fn () => Real.fromString "1.5e+2")
  val () = eqRO ("Real.fromString/fraction-and-exponent", SOME 50.0, fn () => Real.fromString ".5E2")
  val () = eqRO ("Real.fromString/exponent-leading-zeros", SOME 1.5E7, fn () => Real.fromString "1.5E007")
  val () = eqRO ("Real.fromString/zero-exponent", SOME 2.0, fn () => Real.fromString "2E0")
  val () = eqRO ("Real.fromString/small", SOME 1E~5, fn () => Real.fromString "1e~5")
  (* "ignoring initial whitespace" *)
  val () = eqRO ("Real.fromString/leading-space", SOME 1.5, fn () => Real.fromString "  1.5")
  val () = eqRO ("Real.fromString/leading-whitespace", SOME ~2.0, fn () => Real.fromString " \t\n\r~2.0")
  (* "returns SOME(r) if a real value can be scanned from a prefix of s" *)
  val () = eqRO ("Real.fromString/trailing-text", SOME 1.5, fn () => Real.fromString "1.5abc")
  val () = eqRO ("Real.fromString/trailing-space", SOME 1.5, fn () => Real.fromString "1.5 ")
  val () = eqRO ("Real.fromString/empty", NONE, fn () => Real.fromString "")
  val () = eqRO ("Real.fromString/only-whitespace", NONE, fn () => Real.fromString "   ")
  val () = eqRO ("Real.fromString/letters", NONE, fn () => Real.fromString "abc")
  val () = eqRO ("Real.fromString/bare-point", NONE, fn () => Real.fromString ".")
  val () = eqRO ("Real.fromString/only-sign", NONE, fn () => Real.fromString "~")
  val () = eqRO ("Real.fromString/only-exponent", NONE, fn () => Real.fromString "E5")
  val () = eqRO ("Real.fromString/bare-point-exponent", NONE, fn () => Real.fromString ".E5")
  val () = eqRO ("Real.fromString/two-signs", NONE, fn () => Real.fromString "+~1")
  val () = eqRO ("Real.fromString/sign-then-space", NONE, fn () => Real.fromString "~ 1")
  (* non-finite values: "[+~-]?(inf | infinity | nan) where the alphabetic
     characters are case-insensitive" *)
  val () = eqRO ("Real.fromString/nonfinite-inf", SOME posInf, fn () => Real.fromString "inf")
  val () = eqRO ("Real.fromString/nonfinite-infinity", SOME posInf, fn () => Real.fromString "infinity")
  val () = eqRO ("Real.fromString/nonfinite-inf-uppercase", SOME posInf, fn () => Real.fromString "INF")
  val () = eqRO ("Real.fromString/nonfinite-infinity-mixed-case", SOME posInf, fn () => Real.fromString "InFiNiTy")
  val () = eqRO ("Real.fromString/nonfinite-tilde-inf", SOME negInf, fn () => Real.fromString "~inf")
  val () = eqRO ("Real.fromString/nonfinite-minus-infinity", SOME negInf, fn () => Real.fromString "-Infinity")
  val () = eqRO ("Real.fromString/nonfinite-plus-inf", SOME posInf, fn () => Real.fromString "+inf")
  val () = eqRO ("Real.fromString/nonfinite-whitespace-inf", SOME negInf, fn () => Real.fromString "  ~inf")
  val () = eqRO ("Real.fromString/nonfinite-nan", SOME nan, fn () => Real.fromString "nan")
  val () = eqRO ("Real.fromString/nonfinite-nan-mixed-case", SOME nan, fn () => Real.fromString "NaN")
  val () = eqRO ("Real.fromString/nonfinite-tilde-nan", SOME nan, fn () => Real.fromString "~nan")
  val () = eqRO ("Real.fromString/nonfinite-plus-nan", SOME nan, fn () => Real.fromString "+NAN")
  val () = eqRO ("Real.fromString/in", NONE, fn () => Real.fromString "in")
  val () = eqRO ("Real.fromString/na", NONE, fn () => Real.fromString "na")
  (* "Values of too large a magnitude are represented as infinities; values of
     too small a magnitude are represented as zeros." *)
  val () = eqRO ("Real.fromString/too-large", SOME posInf, fn () => Real.fromString "1E400")
  val () = eqRO ("Real.fromString/too-large-negative", SOME negInf, fn () => Real.fromString "~1E400")
  val () = eqRO ("Real.fromString/too-large-digits", SOME posInf, fn () => Real.fromString ("1" ^ String.implode (List.tabulate (400, fn _ => #"0"))))
  val () = eqRO ("Real.fromString/too-small", SOME 0.0, fn () => Real.fromString "1E~400")
  val () = T.check ("Real.fromString/too-small-negative",
                    fn () => (case Real.fromString "~1E~400" of SOME r => Real.== (r, 0.0) | NONE => false))
  (* also when the exponent is not an int *)
  val () = eqRO ("Real.fromString/huge-exponent", SOME posInf, fn () => Real.fromString "1E100000000000000000000")
  val () = eqRO ("Real.fromString/huge-negative-exponent", SOME 0.0, fn () => Real.fromString "1E~100000000000000000000")
  val () = eqRO ("Real.fromString/huge-exponent-of-zero", SOME 0.0, fn () => Real.fromString "0E100000000000000000000")
  (* the extremes are reals *)
  val () = eqRO ("Real.fromString/exact-maxFinite", SOME Real.maxFinite, fn () => Real.fromString "1.7976931348623157E308")
  val () = eqRO ("Real.fromString/exact-minPos", SOME Real.minPos, fn () => Real.fromString "4.9406564584124654E~324")
  val () = eqRO ("Real.fromString/exact-minNormalPos", SOME Real.minNormalPos, fn () => Real.fromString "2.2250738585072014E~308")
  val () = eqRO ("Real.fromString/exact-subnormal-long-form", SOME (pow2 ~1074),
                 fn () => Real.fromString ("0." ^ String.implode (List.tabulate (323, fn _ => #"0")) ^ "5"))
  (* 2^53 + 1 is a tie between 2^53 and 2^53 + 2: the even one; one more digit breaks the tie *)
  val () = eqRO ("Real.fromString/exact-round-half-even", SOME 9007199254740992.0, fn () => Real.fromString "9007199254740993")
  val () = eqRO ("Real.fromString/exact-round-above-half", SOME 9007199254740994.0, fn () => Real.fromString "9007199254740993.000000000000000000001")
  (* "This function is equivalent to StringCvt.scanString scan." *)
  val () = T.check ("Real.fromString/law-is-scanString-scan", fn () =>
             List.all (fn s => sameOpt (Real.fromString s, StringCvt.scanString Real.scan s))
                      ["1.5", " ~2.5E3x", "", "abc", ".5", "1.", "inf", "nanx", "1E", "~.E"])

  (* scan: what is consumed *)
  val () = eqScan ("Real.scan/all", SOME (1.5, ""), fn () => scanRest "1.5")
  val () = eqScan ("Real.scan/rest", SOME (1.5, "abc"), fn () => scanRest "1.5abc")
  val () = eqScan ("Real.scan/rest-space", SOME (~2.0, " 3"), fn () => scanRest "  ~2 3")
  val () = eqScan ("Real.scan/none", NONE, fn () => scanRest "x1.5")
  val () = eqScan ("Real.scan/empty", NONE, fn () => scanRest "")
  (* [0-9]+(.[0-9]+)?: a point needs digits after it *)
  val () = eqScan ("Real.scan/point-without-digits", SOME (1.0, "."), fn () => scanRest "1.")
  val () = eqScan ("Real.scan/point-then-exponent", SOME (1.0, ".E5"), fn () => scanRest "1.E5")
  val () = eqScan ("Real.scan/second-point", SOME (1.5, ".5"), fn () => scanRest "1.5.5")
  (* an exponent needs digits *)
  val () = eqScan ("Real.scan/exponent-without-digits", SOME (1.0, "E"), fn () => scanRest "1E")
  val () = eqScan ("Real.scan/exponent-sign-without-digits", SOME (1.5, "E~"), fn () => scanRest "1.5E~")
  val () = eqScan ("Real.scan/exponent-letter", SOME (1.0, "Ex"), fn () => scanRest "1Ex")
  val () = eqScan ("Real.scan/after-exponent-point", SOME (100.0, ".5"), fn () => scanRest "1E2.5")
  val () = eqScan ("Real.scan/after-exponent-letter", SOME (100.0, "E3"), fn () => scanRest "1E2E3")
  val () = eqScan ("Real.scan/hexadecimal-is-zero", SOME (0.0, "x10"), fn () => scanRest "0x10")
  val () = eqScan ("Real.scan/sign-after-number", SOME (1.0, "~2"), fn () => scanRest "1~2")
  (* inf | infinity: the longest match *)
  val () = eqScan ("Real.scan/nonfinite-infinity-all", SOME (posInf, ""), fn () => scanRest "infinity")
  val () = eqScan ("Real.scan/nonfinite-infinity-rest", SOME (posInf, "x"), fn () => scanRest "infinityx")
  val () = eqScan ("Real.scan/nonfinite-inf-rest", SOME (negInf, "x"), fn () => scanRest "~infx")
  val () = eqScan ("Real.scan/nonfinite-infinit", SOME (posInf, "init"), fn () => scanRest "infinit")
  val () = eqScan ("Real.scan/nonfinite-nan-rest", SOME (nan, "o"), fn () => scanRest "nano")
  val () = T.check ("Real.scan/no-number", fn () =>
             List.all (fn s => not (isSome (scanRest s))) ["", " ", "~", "+", "e1", "i", "n", "-x", "~e", "+-1"])
  (* .[0-9]+: a point needs digits after it here too *)
  val () = T.check ("Real.scan/bare-point", fn () =>
             List.all (fn s => not (isSome (scanRest s))) [".", "~.", " .x", ".e1", "+.E~1"])

  (* round trips *)
  val () = law ("Real.fromString/law-inverts-toString-to-12-digits", 300, 300,
                fn x => (case Real.fromString (Real.toString x) of
                           SOME y => Real.<= (Real.abs (y - x), 1E~11 * Real.abs x)
                         | NONE => false))
  val () = law ("Real.fmt/EXACT-law-fromString-inverts", 300, 300,
                fn x => sameOpt (Real.fromString (Real.fmt EXACT x), SOME x))
  (* 17 significant digits determine a double *)
  val () = law ("Real.fromString/exact-law-inverts-fmt-SCI-16", 300, 300,
                fn x => sameOpt (Real.fromString (Real.fmt (SCI (SOME 16)) x), SOME x))
  val () = law ("Real.fromString/exact-law-inverts-fmt-GEN-17", 300, 300,
                fn x => sameOpt (Real.fromString (Real.fmt (GEN (SOME 17)) x), SOME x))
  val () = law ("Real.fmt/law-FIX-of-integers", 300, 28,
                fn x => Real.< (Real.abs x, 1.0)
                        orelse Real.fmt (FIX (SOME 0)) (Real.realTrunc x) = Int.toString (Real.trunc x))

  (*<< decimal *)
  (* ---- toDecimal, fromDecimal ----
     A decimal_approx with digits [d1, ..., dn] is s * 0.d1...dn * 10^exp.
     "toDecimal should produce only as many digits as are necessary for
     fromDecimal to convert back to the same number." "When the r is not normal
     or subnormal, then the exp field is set to 0 and the digits field is the
     empty list. In all cases, the sign and class field capture the sign and
     class of r." (The NaN class is in section decimal-nan.) *)
  fun showClass c =
    if c = IEEEReal.INF then "INF" else if c = IEEEReal.ZERO then "ZERO"
    else if c = IEEEReal.NORMAL then "NORMAL" else if c = IEEEReal.SUBNORMAL then "SUBNORMAL" else "NAN"
  fun showDec ({class, sign, digits, exp} : IEEEReal.decimal_approx) : string =
    "{class=" ^ showClass class ^ ", sign=" ^ T.bool sign ^ ", digits=" ^ T.list T.int digits ^ ", exp=" ^ T.int exp ^ "}"
  val eqD = T.eq showDec
  fun dec (class, sign, digits, exp) : IEEEReal.decimal_approx =
    {class = class, sign = sign, digits = digits, exp = exp}
  val NORMAL = IEEEReal.NORMAL
  val () = eqD ("Real.toDecimal/half", dec (NORMAL, false, [5], 0), fn () => Real.toDecimal 0.5)
  val () = eqD ("Real.toDecimal/one", dec (NORMAL, false, [1], 1), fn () => Real.toDecimal 1.0)
  val () = eqD ("Real.toDecimal/tenth", dec (NORMAL, false, [1], 0), fn () => Real.toDecimal 0.1)
  val () = eqD ("Real.toDecimal/three-tenths", dec (NORMAL, false, [3], 0), fn () => Real.toDecimal 0.3)
  val () = eqD ("Real.toDecimal/negative", dec (NORMAL, true, [2, 5], 1), fn () => Real.toDecimal (~2.5))
  val () = eqD ("Real.toDecimal/six-digits", dec (NORMAL, false, [1, 2, 3, 4, 5, 6], 3), fn () => Real.toDecimal 123.456)
  val () = eqD ("Real.toDecimal/negative-exponent", dec (NORMAL, true, [1], ~2), fn () => Real.toDecimal (~0.001))
  val () = eqD ("Real.toDecimal/power-of-ten", dec (NORMAL, false, [1], 11), fn () => Real.toDecimal 1E10)
  val () = eqD ("Real.toDecimal/no-trailing-zeros", dec (NORMAL, false, [1, 2], 4), fn () => Real.toDecimal 1200.0)
  (* 1/3 as a double is 0.333333333333333314829616256247...; sixteen 3s are
     within half an ulp (2.8E~17) of it, fifteen are not *)
  val () = eqD ("Real.toDecimal/third", dec (NORMAL, false, List.tabulate (16, fn _ => 3), 0), fn () => Real.toDecimal (1.0 / 3.0))
  (* 0.1 + 0.2 is the successor of 0.3 *)
  val () = eqD ("Real.toDecimal/seventeen-digits", dec (NORMAL, false, [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4], 0),
                fn () => Real.toDecimal (0.1 + 0.2))
  val () = eqD ("Real.toDecimal/maxFinite", dec (NORMAL, false, [1, 7, 9, 7, 6, 9, 3, 1, 3, 4, 8, 6, 2, 3, 1, 5, 7], 309),
                fn () => Real.toDecimal Real.maxFinite)
  val () = eqD ("Real.toDecimal/minNormalPos", dec (NORMAL, false, [2, 2, 2, 5, 0, 7, 3, 8, 5, 8, 5, 0, 7, 2, 0, 1, 4], ~307),
                fn () => Real.toDecimal Real.minNormalPos)
  (* minPos = 4.94...E~324; one digit is enough (both 4E~324 and 5E~324 read
     back as minPos, so only the length is checked) *)
  val () = T.check ("Real.toDecimal/minPos", fn () =>
             let val {class, sign, digits, exp} = Real.toDecimal Real.minPos
             in class = IEEEReal.SUBNORMAL andalso not sign andalso List.length digits = 1 andalso exp = ~323 end)
  val () = T.check ("Real.toDecimal/subnormal-class", fn () => #class (Real.toDecimal (~ (pow2 ~1050))) = IEEEReal.SUBNORMAL
                                                               andalso #sign (Real.toDecimal (~ (pow2 ~1050))))
  val () = eqD ("Real.toDecimal/zero", dec (IEEEReal.ZERO, false, [], 0), fn () => Real.toDecimal 0.0)
  val () = eqD ("Real.toDecimal/negzero", dec (IEEEReal.ZERO, true, [], 0), fn () => Real.toDecimal (~0.0))
  val () = eqD ("Real.toDecimal/posInf", dec (IEEEReal.INF, false, [], 0), fn () => Real.toDecimal posInf)
  val () = eqD ("Real.toDecimal/negInf", dec (IEEEReal.INF, true, [], 0), fn () => Real.toDecimal negInf)

  val () = eqRO ("Real.fromDecimal/half", SOME 0.5, fn () => Real.fromDecimal (dec (NORMAL, false, [5], 0)))
  val () = eqRO ("Real.fromDecimal/quarter", SOME 0.25, fn () => Real.fromDecimal (dec (NORMAL, false, [2, 5], 0)))
  val () = eqRO ("Real.fromDecimal/positive-exponent", SOME 125.0, fn () => Real.fromDecimal (dec (NORMAL, false, [1, 2, 5], 3)))
  val () = eqRO ("Real.fromDecimal/large-exponent", SOME 1.25E7, fn () => Real.fromDecimal (dec (NORMAL, false, [1, 2, 5], 8)))
  val () = eqRO ("Real.fromDecimal/negative-exponent", SOME 0.00125, fn () => Real.fromDecimal (dec (NORMAL, false, [1, 2, 5], ~2)))
  val () = eqRO ("Real.fromDecimal/negative", SOME ~2.5, fn () => Real.fromDecimal (dec (NORMAL, true, [2, 5], 1)))
  val () = eqRO ("Real.fromDecimal/leading-zero-digits", SOME 0.0625, fn () => Real.fromDecimal (dec (NORMAL, false, [0, 6, 2, 5], 0)))
  val () = eqRO ("Real.fromDecimal/trailing-zero-digits", SOME 0.5, fn () => Real.fromDecimal (dec (NORMAL, false, [5, 0, 0], 0)))
  val () = eqRO ("Real.fromDecimal/seventeen-digits", SOME (0.1 + 0.2),
                 fn () => Real.fromDecimal (dec (NORMAL, false, [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4], 0)))
  val () = eqRO ("Real.fromDecimal/maxFinite", SOME Real.maxFinite,
                 fn () => Real.fromDecimal (dec (NORMAL, false, [1, 7, 9, 7, 6, 9, 3, 1, 3, 4, 8, 6, 2, 3, 1, 5, 7], 309)))
  val () = eqRO ("Real.fromDecimal/minPos", SOME Real.minPos, fn () => Real.fromDecimal (dec (IEEEReal.SUBNORMAL, false, [5], ~323)))
  (* "If class is ZERO or INF, the resulting real is the appropriate signed
     zero or infinity." *)
  val () = eqRO ("Real.fromDecimal/zero", SOME 0.0, fn () => Real.fromDecimal (dec (IEEEReal.ZERO, false, [], 0)))
  val () = eqRO ("Real.fromDecimal/negzero", SOME ~0.0, fn () => Real.fromDecimal (dec (IEEEReal.ZERO, true, [], 0)))
  val () = eqRO ("Real.fromDecimal/posInf", SOME posInf, fn () => Real.fromDecimal (dec (IEEEReal.INF, false, [], 0)))
  val () = eqRO ("Real.fromDecimal/negInf", SOME negInf, fn () => Real.fromDecimal (dec (IEEEReal.INF, true, [], 0)))
  val () = eqRO ("Real.fromDecimal/zero-class-decides", SOME 0.0, fn () => Real.fromDecimal (dec (IEEEReal.ZERO, false, [5], 3)))
  val () = eqRO ("Real.fromDecimal/inf-class-decides", SOME negInf, fn () => Real.fromDecimal (dec (IEEEReal.INF, true, [5], 3)))
  (* "the conversion itself should ignore the class field, so that the
     resulting value might have class NORMAL, SUBNORMAL, ZERO, or INF. For
     example, if digits is empty or a list of all 0's, the result should be a
     signed zero. More generally, very large or small magnitudes are converted
     to infinities or zeros." *)
  val () = eqRO ("Real.fromDecimal/no-digits-is-zero", SOME 0.0, fn () => Real.fromDecimal (dec (NORMAL, false, [], 5)))
  val () = eqRO ("Real.fromDecimal/no-digits-is-negzero", SOME ~0.0, fn () => Real.fromDecimal (dec (NORMAL, true, [], 0)))
  val () = eqRO ("Real.fromDecimal/zero-digits-is-zero", SOME 0.0, fn () => Real.fromDecimal (dec (NORMAL, false, [0, 0, 0], 2)))
  val () = eqRO ("Real.fromDecimal/zero-digits-is-negzero", SOME ~0.0, fn () => Real.fromDecimal (dec (IEEEReal.SUBNORMAL, true, [0], 0)))
  val () = eqRO ("Real.fromDecimal/subnormal-class-ignored", SOME 1.0, fn () => Real.fromDecimal (dec (IEEEReal.SUBNORMAL, false, [1], 1)))
  val () = eqRO ("Real.fromDecimal/normal-class-ignored", SOME (pow2 ~1074), fn () => Real.fromDecimal (dec (NORMAL, false, [5], ~323)))
  val () = eqRO ("Real.fromDecimal/too-large", SOME posInf, fn () => Real.fromDecimal (dec (NORMAL, false, [1], 400)))
  val () = eqRO ("Real.fromDecimal/too-large-negative", SOME negInf, fn () => Real.fromDecimal (dec (NORMAL, true, [1], 400)))
  val () = eqRO ("Real.fromDecimal/too-small", SOME 0.0, fn () => Real.fromDecimal (dec (NORMAL, false, [1], ~400)))
  val () = eqRO ("Real.fromDecimal/too-small-negative", SOME ~0.0, fn () => Real.fromDecimal (dec (NORMAL, true, [1], ~400)))
  (* "if the digits field contains integers outside the range [0,9], it returns NONE" *)
  val () = eqRO ("Real.fromDecimal/digit-ten", NONE, fn () => Real.fromDecimal (dec (NORMAL, false, [1, 10], 0)))
  val () = eqRO ("Real.fromDecimal/digit-negative", NONE, fn () => Real.fromDecimal (dec (NORMAL, false, [~1], 0)))
  val () = eqRO ("Real.fromDecimal/digit-large", NONE, fn () => Real.fromDecimal (dec (IEEEReal.SUBNORMAL, true, [5, 123, 5], 0)))
  (* "for any normal or subnormal real value r, we have the bit-wise equality
     fromDecimal (toDecimal r) = r" *)
  val () = law ("Real.fromDecimal/law-inverts-toDecimal", 300, 1000,
                fn x => sameOpt (Real.fromDecimal (Real.toDecimal x), SOME x))
  val () = T.check ("Real.fromDecimal/law-inverts-toDecimal-subnormal", fn () =>
             let val ok = ref true
             in T.seed 6;
                T.repeat (100, fn _ =>
                  let val x = randMantissa () * pow2 (T.range (~1073, ~1022))
                  in if sameOpt (Real.fromDecimal (Real.toDecimal x), SOME x) then () else ok := false end);
                !ok end)
  val () = law ("Real.toDecimal/law-digits-are-minimal-form", 300, 1000,
                fn x => let val {class, sign, digits, exp = _} = Real.toDecimal x
                        in class = NORMAL andalso sign = Real.signBit x
                           andalso not (List.null digits) andalso List.length digits <= 17
                           andalso List.all (fn d => 0 <= d andalso d <= 9) digits
                           andalso List.hd digits <> 0 andalso List.last digits <> 0 end)
  (* "toString o REAL.toDecimal is equivalent to REAL.fmt StringCvt.EXACT" *)
  val () = law ("Real.fmt/law-EXACT-is-IEEEReal.toString-of-toDecimal", 300, 1000,
                fn x => Real.fmt EXACT x = IEEEReal.toString (Real.toDecimal x))
  (*>> decimal *)

  (*<< decimal-nan *)
  val () = T.check ("Real.toDecimal/nan", fn () =>
             let val {class, sign, digits, exp} = Real.toDecimal (Real.copySign (nan, 1.0))
             in class = IEEEReal.NAN andalso not sign andalso List.null digits andalso exp = 0 end)
  (* "In all cases, the sign and class field capture the sign and class of r." *)
  val () = T.check ("Real.toDecimal/negative-nan", fn () =>
             let val {class, sign, digits, exp} = Real.toDecimal (Real.copySign (nan, ~1.0))
             in class = IEEEReal.NAN andalso sign andalso List.null digits andalso exp = 0 end)
  val () = eqRO ("Real.fromDecimal/nan", SOME nan,
                 fn () => Real.fromDecimal {class = IEEEReal.NAN, sign = false, digits = [], exp = 0})
  val () = eqRO ("Real.fromDecimal/nan-class-decides", SOME nan,
                 fn () => Real.fromDecimal {class = IEEEReal.NAN, sign = false, digits = [1, 2], exp = 3})
  (* "If class is NAN, a signed NaN is generated." *)
  val () = T.check ("Real.fromDecimal/negative-nan", fn () =>
             (case Real.fromDecimal {class = IEEEReal.NAN, sign = true, digits = [], exp = 0} of
                SOME r => Real.isNan r andalso Real.signBit r
              | NONE => false))
  val () = T.check ("Real.fromDecimal/positive-nan", fn () =>
             (case Real.fromDecimal {class = IEEEReal.NAN, sign = false, digits = [], exp = 0} of
                SOME r => Real.isNan r andalso not (Real.signBit r)
              | NONE => false))
  (*>> decimal-nan *)

  (* A numeral is rounded in the current rounding mode, with its sign: a
     negative one rounds down to the more negative real under TO_NEGINF.
     0.1 is not a real; the nearest, 0.1 itself here, is above it, and below
     is the real under that (0.1 less its spacing, 2^~56; nextAfter would do,
     but SML/NJ 110.79 lacks it). *)
  fun inMode mode f =
    let val saved = IEEEReal.getRoundingMode ()
    in IEEEReal.setRoundingMode mode; (f () before IEEEReal.setRoundingMode saved)
       handle e => (IEEEReal.setRoundingMode saved; raise e)
    end
  val below = 0.1 - Real.fromManExp {man = 1.0, exp = ~56}

  (*<< scan-rounding-mode *)
  val () = T.eqReal ("Real.fromString/TO_NEGINF-negative", ~0.1,
                     fn () => inMode IEEEReal.TO_NEGINF (fn () => valOf (Real.fromString "~0.1")))
  val () = T.eqReal ("Real.fromString/TO_POSINF-negative", Real.~ below,
                     fn () => inMode IEEEReal.TO_POSINF (fn () => valOf (Real.fromString "~0.1")))
  val () = T.eqReal ("Real.fromString/TO_ZERO-negative", Real.~ below,
                     fn () => inMode IEEEReal.TO_ZERO (fn () => valOf (Real.fromString "-0.1")))
  val () = T.eqReal ("Real.fromString/TO_NEGINF-positive", below,
                     fn () => inMode IEEEReal.TO_NEGINF (fn () => valOf (Real.fromString "0.1")))
  val () = T.eqReal ("Real.scan/TO_NEGINF-negative", ~0.1,
                     fn () => inMode IEEEReal.TO_NEGINF (fn () => valOf (StringCvt.scanString Real.scan "~0.1")))
  (*>> scan-rounding-mode *)

  (*<< decimal-rounding-mode *)
  (* here the nearest is also the result of rounding down *)
  val () = T.eqReal ("Real.fromDecimal/TO_NEGINF-negative", ~0.1,
                     fn () => inMode IEEEReal.TO_NEGINF (fn () =>
                       valOf (Real.fromDecimal {class = IEEEReal.NORMAL, sign = true, digits = [1], exp = 0})))
  (*>> decimal-rounding-mode *)
end
