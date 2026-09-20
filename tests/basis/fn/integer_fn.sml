(* Checks of a structure with signature INTEGER, for any precision.
   Expected values follow https://smlfamily.github.io/Basis/integer.html.

     structure R = TestIntegerFn (structure I = Int8 val name = "Int8")

   needs fn/numstr.sml. The labels are name ^ ".member/case". Nothing is
   assumed about the precision of I.int, of Int.int or of LargeInt.int beyond
   I.precision being NONE or at least 8: the bounds are computed from
   I.precision as the specification prescribes ("If precision is SOME(n), then
   we have minInt = -2^(n-1) and maxInt = 2^(n-1) - 1"), and values of type
   I.int are built with I.fromInt from numbers between ~127 and 127 and with
   I.+, I.- and I.~.

   TEST_INTEGER_CORE is INTEGER without fmt and scan, which need StringCvt;
   they are checked by fn/integer_scan_fn.sml. *)
signature TEST_INTEGER_CORE =
sig
  eqtype int
  val toLarge : int -> LargeInt.int
  val fromLarge : LargeInt.int -> int
  val toInt : int -> Int.int
  val fromInt : Int.int -> int
  val precision : Int.int option
  val minInt : int option
  val maxInt : int option
  val + : int * int -> int
  val - : int * int -> int
  val * : int * int -> int
  val div : int * int -> int
  val mod : int * int -> int
  val quot : int * int -> int
  val rem : int * int -> int
  val compare : int * int -> order
  val < : int * int -> bool
  val <= : int * int -> bool
  val > : int * int -> bool
  val >= : int * int -> bool
  val ~ : int -> int
  val abs : int -> int
  val min : int * int -> int
  val max : int * int -> int
  val sign : int -> Int.int
  val sameSign : int * int -> bool
  val toString : int -> string
  val fromString : string -> int option
end

functor TestIntegerFn (structure I : TEST_INTEGER_CORE val name : string) =
struct
  structure L = LargeInt

  fun lab s = name ^ "." ^ s
  fun showI x = I.toString x handle _ => "?"
  fun showL x = L.toString x handle _ => "?"

  (* eqv: T.eq with the expected value in a thunk as well, so that an
     exception while computing it is a failed check. *)
  fun eqv show (label, expected, f) =
    case (SOME (expected ()) handle _ => NONE) of
      SOME e => T.eq show (label, e, f)
    | NONE => T.fail (label, "the expected value raised an exception")

  val eqI = eqv showI
  val eqIO = eqv (T.option showI)
  val eqL = eqv showL
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqN = T.eq T.int
  val eqOrd = T.eq T.order
  fun overflow (label, f) = T.raises (label, T.isOverflow, f)
  fun divide (label, f) = T.raises (label, T.isDiv, f)

  (* eqK: the result is I.fromInt k, for a small k. *)
  fun eqK (label, k, f) = eqI (label, fn () => I.fromInt k, f)
  fun eqKO (label, k, f) = eqIO (label, fn () => Option.map I.fromInt k, f)

  val i = I.fromInt
  val zero = i 0
  val one = i 1
  val two = i 2
  val minusOne = i ~1
  val lzero = L.fromInt 0
  val lone = L.fromInt 1

  (* 2^k by doubling, in I.int, LargeInt.int and Int.int. *)
  fun pow2 k = if k <= 0 then one else let val h = pow2 (k - 1) in I.+ (h, h) end
  fun lpow2 k = if k <= 0 then lone else let val h = lpow2 (k - 1) in L.+ (h, h) end
  fun ipow2 k = if k <= 0 then 1 else let val h = ipow2 (k - 1) in h + h end

  (* The bounds that the specification prescribes for precision = SOME n:
     (n, -2^(n-1), 2^(n-1) - 1). *)
  val bounds =
    case I.precision of
      NONE => NONE
    | SOME n =>
        (let val h = pow2 (n - 2)
             val negH = I.~ h
         in SOME (n, I.+ (negH, negH), I.+ (h, I.- (h, one))) end
         handle _ => NONE)
  val lbounds =
    case I.precision of
      NONE => NONE
    | SOME n => (SOME (L.~ (lpow2 (n - 1)), L.- (lpow2 (n - 1), lone)) handle _ => NONE)

  val () = T.check (lab "precision/bounds-are-representable",
                    fn () => Option.isSome bounds = Option.isSome I.precision
                             andalso Option.isSome lbounds = Option.isSome I.precision)
  val () = T.check (lab "precision/at-least-8",
                    fn () => case I.precision of SOME n => n >= 8 | NONE => true)
  val () = T.check (lab "precision/NONE-iff-minInt-NONE",
                    fn () => Option.isSome I.precision = Option.isSome I.minInt)
  val () = T.check (lab "precision/NONE-iff-maxInt-NONE",
                    fn () => Option.isSome I.precision = Option.isSome I.maxInt)

  (* wider (p, q): a type of precision p has values a type of precision q lacks. *)
  fun wider (NONE, NONE) = false
    | wider (NONE, SOME _) = true
    | wider (SOME _, NONE) = false
    | wider (SOME (m : Int.int), SOME n) = m > n
  val intWider = wider (Int.precision, I.precision)
  val intNarrower = wider (I.precision, Int.precision)
  val largeWider = wider (L.precision, I.precision)

  (* ---- conversions of small numbers ---- *)
  val () = eqN (lab "toInt/zero", 0, fn () => I.toInt zero)
  val () = eqN (lab "toInt/positive", 42, fn () => I.toInt (i 42))
  val () = eqN (lab "toInt/negative", ~42, fn () => I.toInt (i ~42))
  val () = eqN (lab "toInt/sum", 100, fn () => I.toInt (I.+ (i 58, i 42)))
  val () = T.check (lab "fromInt/distinct", fn () => i 1 <> i 2 andalso i 1 <> i ~1 andalso i 0 <> i 1)
  val () = T.check (lab "fromInt/equal", fn () => i 42 = I.- (i 50, i 8))
  val () = eqK (lab "fromInt/round-trip", ~127, fn () => I.fromInt (I.toInt (i ~127)))
  val () = eqL (lab "toLarge/zero", fn () => lzero, fn () => I.toLarge zero)
  val () = eqL (lab "toLarge/positive", fn () => L.fromInt 42, fn () => I.toLarge (i 42))
  val () = eqL (lab "toLarge/negative", fn () => L.fromInt ~42, fn () => I.toLarge (i ~42))
  val () = eqK (lab "fromLarge/zero", 0, fn () => I.fromLarge lzero)
  val () = eqK (lab "fromLarge/positive", 42, fn () => I.fromLarge (L.fromInt 42))
  val () = eqK (lab "fromLarge/negative", ~42, fn () => I.fromLarge (L.fromInt ~42))
  val () = eqK (lab "fromLarge/round-trip", ~127, fn () => I.fromLarge (I.toLarge (i ~127)))

  (* ---- arithmetic on small numbers ---- *)
  (* label: the beginning of the labels, lab "member/" *)
  fun table (label, f) cases =
    List.app (fn (c, a, b, r) => eqK (label ^ c, r, fn () => f (i a, i b))) cases

  val () = table (lab "+/", fn p => I.+ p)
    [("basic", 2, 3, 5), ("negative", ~2, ~3, ~5), ("mixed", ~2, 3, 1), ("zero", 0, 0, 0),
     ("identity", 42, 0, 42), ("inverse", 42, ~42, 0)]
  val () = table (lab "-/", fn p => I.- p)
    [("basic", 5, 3, 2), ("below-zero", 5, 7, ~2), ("negative", ~5, ~7, 2), ("zero", 0, 0, 0),
     ("identity", 42, 0, 42), ("from-zero", 0, 42, ~42), ("self", 42, 42, 0)]
  val () = table (lab "*/", fn p => I.* p)
    [("basic", 6, 7, 42), ("neg-pos", ~6, 7, ~42), ("pos-neg", 6, ~7, ~42), ("neg-neg", ~6, ~7, 42),
     ("zero", 42, 0, 0), ("zero-left", 0, ~42, 0), ("identity", 1, ~42, ~42), ("minus-one", ~1, 42, ~42)]

  (* i div j is floor (i / j), and i mod j = i - j * floor (i / j) has the sign of j. *)
  val () = table (lab "div/", I.div)
    [("pos-pos", 7, 2, 3), ("neg-pos", ~7, 2, ~4), ("pos-neg", 7, ~2, ~4), ("neg-neg", ~7, ~2, 3),
     ("exact-pos-pos", 6, 3, 2), ("exact-neg-pos", ~6, 3, ~2), ("exact-pos-neg", 6, ~3, ~2),
     ("exact-neg-neg", ~6, ~3, 2),
     ("zero-dividend", 0, 5, 0), ("zero-dividend-neg", 0, ~5, 0),
     ("half", 1, 2, 0), ("minus-half", ~1, 2, ~1), ("half-neg", 1, ~2, ~1), ("minus-half-neg", ~1, ~2, 0),
     ("100-7", 100, 7, 14), ("~100-7", ~100, 7, ~15), ("100-~7", 100, ~7, ~15), ("~100-~7", ~100, ~7, 14),
     ("by-one", 5, 1, 5), ("by-minus-one", 5, ~1, ~5), ("small-by-large", 3, 5, 0),
     ("small-neg-by-large", ~3, 5, ~1), ("small-by-large-neg", 3, ~5, ~1)]
  val () = table (lab "mod/", I.mod)
    [("pos-pos", 7, 2, 1), ("neg-pos", ~7, 2, 1), ("pos-neg", 7, ~2, ~1), ("neg-neg", ~7, ~2, ~1),
     ("exact-pos-pos", 6, 3, 0), ("exact-neg-pos", ~6, 3, 0), ("exact-pos-neg", 6, ~3, 0),
     ("exact-neg-neg", ~6, ~3, 0),
     ("zero-dividend", 0, 5, 0), ("zero-dividend-neg", 0, ~5, 0),
     ("half", 1, 2, 1), ("minus-half", ~1, 2, 1), ("half-neg", 1, ~2, ~1), ("minus-half-neg", ~1, ~2, ~1),
     ("100-7", 100, 7, 2), ("~100-7", ~100, 7, 5), ("100-~7", 100, ~7, ~5), ("~100-~7", ~100, ~7, ~2),
     ("by-one", 5, 1, 0), ("by-minus-one", 5, ~1, 0), ("small-by-large", 3, 5, 3),
     ("small-neg-by-large", ~3, 5, 2), ("small-by-large-neg", 3, ~5, ~2)]
  (* quot drops the fractional part, and i rem j = i - j * quot (i, j) has the sign of i. *)
  val () = table (lab "quot/", I.quot)
    [("pos-pos", 7, 2, 3), ("neg-pos", ~7, 2, ~3), ("pos-neg", 7, ~2, ~3), ("neg-neg", ~7, ~2, 3),
     ("exact-pos-pos", 6, 3, 2), ("exact-neg-pos", ~6, 3, ~2), ("exact-pos-neg", 6, ~3, ~2),
     ("exact-neg-neg", ~6, ~3, 2),
     ("zero-dividend", 0, 5, 0), ("zero-dividend-neg", 0, ~5, 0),
     ("half", 1, 2, 0), ("minus-half", ~1, 2, 0), ("half-neg", 1, ~2, 0), ("minus-half-neg", ~1, ~2, 0),
     ("100-7", 100, 7, 14), ("~100-7", ~100, 7, ~14), ("100-~7", 100, ~7, ~14), ("~100-~7", ~100, ~7, 14),
     ("by-one", 5, 1, 5), ("by-minus-one", 5, ~1, ~5), ("small-by-large", 3, 5, 0),
     ("small-neg-by-large", ~3, 5, 0), ("small-by-large-neg", 3, ~5, 0)]
  val () = table (lab "rem/", I.rem)
    [("pos-pos", 7, 2, 1), ("neg-pos", ~7, 2, ~1), ("pos-neg", 7, ~2, 1), ("neg-neg", ~7, ~2, ~1),
     ("exact-pos-pos", 6, 3, 0), ("exact-neg-pos", ~6, 3, 0), ("exact-pos-neg", 6, ~3, 0),
     ("exact-neg-neg", ~6, ~3, 0),
     ("zero-dividend", 0, 5, 0), ("zero-dividend-neg", 0, ~5, 0),
     ("half", 1, 2, 1), ("minus-half", ~1, 2, ~1), ("half-neg", 1, ~2, 1), ("minus-half-neg", ~1, ~2, ~1),
     ("100-7", 100, 7, 2), ("~100-7", ~100, 7, ~2), ("100-~7", 100, ~7, 2), ("~100-~7", ~100, ~7, ~2),
     ("by-one", 5, 1, 0), ("by-minus-one", 5, ~1, 0), ("small-by-large", 3, 5, 3),
     ("small-neg-by-large", ~3, 5, ~3), ("small-by-large-neg", 3, ~5, 3)]

  (* "It raises ... Div when j = 0." *)
  val () = divide (lab "div/Div", fn () => I.div (i 5, zero))
  val () = divide (lab "div/Div-negative", fn () => I.div (i ~5, zero))
  val () = divide (lab "div/Div-zero-by-zero", fn () => I.div (zero, zero))
  val () = divide (lab "mod/Div", fn () => I.mod (i 5, zero))
  val () = divide (lab "mod/Div-negative", fn () => I.mod (i ~5, zero))
  val () = divide (lab "mod/Div-zero-by-zero", fn () => I.mod (zero, zero))
  val () = divide (lab "quot/Div", fn () => I.quot (i 5, zero))
  val () = divide (lab "quot/Div-negative", fn () => I.quot (i ~5, zero))
  val () = divide (lab "quot/Div-zero-by-zero", fn () => I.quot (zero, zero))
  val () = divide (lab "rem/Div", fn () => I.rem (i 5, zero))
  val () = divide (lab "rem/Div-negative", fn () => I.rem (i ~5, zero))
  val () = divide (lab "rem/Div-zero-by-zero", fn () => I.rem (zero, zero))

  (* ---- order ---- *)
  val orderCases =
    [("less", 1, 2), ("equal", 2, 2), ("greater", 2, 1), ("neg-pos", ~1, 1), ("pos-neg", 1, ~1),
     ("neg-neg-less", ~2, ~1), ("neg-neg-greater", ~1, ~2), ("neg-equal", ~2, ~2),
     ("zero-zero", 0, 0), ("zero-neg", 0, ~1), ("neg-zero", ~1, 0), ("far", ~127, 127)]
  fun orderTable (label, f, expect : int * int -> bool) =
    List.app (fn (c, a, b) => eqB (label ^ c, expect (a, b), fn () => f (i a, i b))) orderCases
  val () = List.app (fn (c, a, b) =>
             eqOrd (lab ("compare/" ^ c), if a < b then LESS else if a = b then EQUAL else GREATER,
                    fn () => I.compare (i a, i b))) orderCases
  val () = orderTable (lab "</", I.<, fn (a, b) => a < b)
  val () = orderTable (lab "<=/", I.<=, fn (a, b) => a <= b)
  val () = orderTable (lab ">/", I.>, fn (a, b) => a > b)
  val () = orderTable (lab ">=/", I.>=, fn (a, b) => a >= b)

  val () = table (lab "min/", I.min)
    [("first", 1, 2, 1), ("second", 2, 1, 1), ("equal", 2, 2, 2), ("negative", ~1, ~2, ~2),
     ("mixed", ~1, 1, ~1), ("zero", 0, ~1, ~1)]
  val () = table (lab "max/", I.max)
    [("first", 2, 1, 2), ("second", 1, 2, 2), ("equal", 2, 2, 2), ("negative", ~1, ~2, ~1),
     ("mixed", ~1, 1, 1), ("zero", 0, ~1, 0)]

  (* ---- ~, abs, sign, sameSign ---- *)
  val () = eqK (lab "~/positive", ~42, fn () => I.~ (i 42))
  val () = eqK (lab "~/negative", 42, fn () => I.~ (i ~42))
  val () = eqK (lab "~/zero", 0, fn () => I.~ zero)
  val () = eqK (lab "abs/positive", 42, fn () => I.abs (i 42))
  val () = eqK (lab "abs/negative", 42, fn () => I.abs (i ~42))
  val () = eqK (lab "abs/zero", 0, fn () => I.abs zero)
  val () = eqN (lab "sign/positive", 1, fn () => I.sign (i 42))
  val () = eqN (lab "sign/negative", ~1, fn () => I.sign (i ~42))
  val () = eqN (lab "sign/zero", 0, fn () => I.sign zero)
  val () = eqN (lab "sign/one", 1, fn () => I.sign one)
  val () = eqN (lab "sign/minus-one", ~1, fn () => I.sign minusOne)
  (* "It is equivalent to (sign i = sign j)", so zero has the sign of zero only. *)
  val () = List.app (fn (c, a, b, r) => eqB (lab ("sameSign/" ^ c), r, fn () => I.sameSign (i a, i b)))
    [("pos-pos", 1, 42, true), ("neg-neg", ~1, ~42, true), ("zero-zero", 0, 0, true),
     ("pos-neg", 1, ~1, false), ("neg-pos", ~42, 42, false), ("zero-pos", 0, 1, false),
     ("pos-zero", 1, 0, false), ("zero-neg", 0, ~1, false), ("neg-zero", ~1, 0, false)]

  (* ---- toString: decimal, with ~ for the sign ---- *)
  val () = List.app (fn (c, k, s) => eqS (lab ("toString/" ^ c), s, fn () => I.toString (i k)))
    [("zero", 0, "0"), ("one", 1, "1"), ("minus-one", ~1, "~1"), ("positive", 42, "42"),
     ("negative", ~42, "~42"), ("hundred", 100, "100"), ("127", 127, "127"), ("~127", ~127, "~127"),
     ("nine", 9, "9"), ("ten", 10, "10"), ("minus-ten", ~10, "~10")]

  (* ---- fromString: [+~-]?[0-9]+ at the start, after whitespace ---- *)
  val () = List.app (fn (c, s, r) => eqKO (lab ("fromString/" ^ c), r, fn () => I.fromString s))
    [("zero", "0", SOME 0), ("positive", "42", SOME 42), ("tilde", "~42", SOME ~42),
     ("minus", "-42", SOME ~42), ("plus", "+42", SOME 42),
     ("tilde-zero", "~0", SOME 0), ("minus-zero", "-0", SOME 0), ("plus-zero", "+0", SOME 0),
     ("leading-zeros", "007", SOME 7), ("tilde-leading-zeros", "~007", SOME ~7),
     ("whitespace-spaces", "  42", SOME 42), ("whitespace-all-six", " \t\n\v\f\r42", SOME 42),
     ("whitespace-tab", "\t42", SOME 42), ("whitespace-newline", "\n42", SOME 42),
     ("whitespace-vertical-tab", "\v42", SOME 42), ("whitespace-form-feed", "\f42", SOME 42),
     ("whitespace-return", "\r42", SOME 42),
     ("whitespace-then-sign", "\n ~42", SOME ~42),
     ("stops-at-letter", "42abc", SOME 42), ("stops-at-space", "42 17", SOME 42),
     ("stops-at-trailing-space", "42 ", SOME 42), ("stops-at-point", "12.5", SOME 12),
     ("stops-at-exponent", "1e5", SOME 1), ("stops-at-tilde", "1~2", SOME 1),
     ("stops-at-minus", "1-2", SOME 1), ("stops-at-plus", "1+2", SOME 1),
     ("no-hex-prefix", "0x1F", SOME 0), ("no-hex-digits", "1F", SOME 1),
     ("empty", "", NONE), ("only-whitespace", "   ", NONE), ("letters", "abc", NONE),
     ("only-tilde", "~", NONE), ("only-minus", "-", NONE), ("only-plus", "+", NONE),
     ("space-after-tilde", "~ 5", NONE), ("space-after-minus", "- 5", NONE),
     ("space-after-plus", "+ 5", NONE),
     ("two-tildes", "~~5", NONE), ("plus-minus", "+-5", NONE), ("minus-tilde", "-~5", NONE),
     ("two-pluses", "++5", NONE), ("letter-first", "x42", NONE), ("point-first", ".5", NONE),
     ("tilde-letter", "~x", NONE), ("hash", "#5", NONE)]

  (* ---- the bounds ---- *)
  val () =
    case (bounds, lbounds) of
      (SOME (n, lo, hi), SOME (llo, lhi)) =>
        let
          val h = pow2 (n - 2)                                  (* 2^(n-2) *)
          val loText = "~" ^ NumStr.pow2String 10 (n - 1)
          val hiText = NumStr.pow2Minus1String 10 (n - 1)
          val above = NumStr.pow2String 10 (n - 1)              (* maxInt + 1 *)
          val below = "~" ^ NumStr.toString (NumStr.succ 10 (NumStr.pow2 10 (n - 1)))   (* minInt - 1 *)
          fun v x () = x
        in
          eqIO (lab "minInt/two-complement", fn () => SOME lo, fn () => I.minInt);
          eqIO (lab "maxInt/two-complement", fn () => SOME hi, fn () => I.maxInt);
          eqI (lab "minInt/maxInt-plus-one-negated", v lo, fn () => I.- (I.~ (valOf I.maxInt), one));
          eqS (lab "minInt/toString", loText, fn () => I.toString (valOf I.minInt));
          eqS (lab "maxInt/toString", hiText, fn () => I.toString (valOf I.maxInt));

          (* "They raise Overflow when the result is not representable." *)
          overflow (lab "+/Overflow-maxInt-plus-one", fn () => I.+ (hi, one));
          overflow (lab "+/Overflow-one-plus-maxInt", fn () => I.+ (one, hi));
          overflow (lab "+/Overflow-minInt-plus-minus-one", fn () => I.+ (lo, minusOne));
          overflow (lab "+/Overflow-maxInt-twice", fn () => I.+ (hi, hi));
          overflow (lab "+/Overflow-minInt-twice", fn () => I.+ (lo, lo));
          overflow (lab "+/Overflow-half-range-twice", fn () => I.+ (h, h));
          eqI (lab "+/maxInt-plus-zero", v hi, fn () => I.+ (hi, zero));
          eqI (lab "+/up-to-maxInt", v hi, fn () => I.+ (I.- (hi, one), one));
          eqI (lab "+/minInt-plus-maxInt", v minusOne, fn () => I.+ (lo, hi));
          eqI (lab "+/down-to-minInt", v lo, fn () => I.+ (I.~ h, I.~ h));
          overflow (lab "-/Overflow-maxInt-minus-minus-one", fn () => I.- (hi, minusOne));
          overflow (lab "-/Overflow-minInt-minus-one", fn () => I.- (lo, one));
          overflow (lab "-/Overflow-zero-minus-minInt", fn () => I.- (zero, lo));
          overflow (lab "-/Overflow-maxInt-minus-minInt", fn () => I.- (hi, lo));
          overflow (lab "-/Overflow-minInt-minus-maxInt", fn () => I.- (lo, hi));
          eqI (lab "-/minus-one-minus-minInt", v hi, fn () => I.- (minusOne, lo));
          eqI (lab "-/zero-minus-maxInt", fn () => I.+ (lo, one), fn () => I.- (zero, hi));
          eqI (lab "-/minInt-minus-minInt", v zero, fn () => I.- (lo, lo));
          eqI (lab "-/maxInt-minus-maxInt", v zero, fn () => I.- (hi, hi));
          overflow (lab "*/Overflow-maxInt-times-two", fn () => I.* (hi, two));
          overflow (lab "*/Overflow-minInt-times-minus-one", fn () => I.* (lo, minusOne));
          overflow (lab "*/Overflow-minus-one-times-minInt", fn () => I.* (minusOne, lo));
          overflow (lab "*/Overflow-minInt-times-two", fn () => I.* (lo, two));
          overflow (lab "*/Overflow-half-range-times-two", fn () => I.* (h, two));
          overflow (lab "*/Overflow-minInt-squared", fn () => I.* (lo, lo));
          overflow (lab "*/Overflow-maxInt-squared", fn () => I.* (hi, hi));
          overflow (lab "*/Overflow-maxInt-times-minInt", fn () => I.* (hi, lo));
          (* 2^k * 2^k with 2k >= n - 1 *)
          overflow (lab "*/Overflow-square-of-power",
                    fn () => let val s = pow2 (n div 2) in I.* (s, s) end);
          (* 2^k * 2^k with 2k <= n - 2 *)
          eqI (lab "*/square-of-power", fn () => pow2 (2 * ((n - 2) div 2)),
               fn () => let val s = pow2 ((n - 2) div 2) in I.* (s, s) end);
          eqI (lab "*/minInt-times-one", v lo, fn () => I.* (lo, one));
          eqI (lab "*/one-times-minInt", v lo, fn () => I.* (one, lo));
          eqI (lab "*/maxInt-times-minus-one", fn () => I.+ (lo, one), fn () => I.* (hi, minusOne));
          eqI (lab "*/half-range-times-minus-two", v lo, fn () => I.* (h, i ~2));
          eqI (lab "*/minInt-times-zero", v zero, fn () => I.* (lo, zero));
          eqI (lab "*/zero-times-minInt", v zero, fn () => I.* (zero, lo));
          eqI (lab "*/zero-times-maxInt", v zero, fn () => I.* (zero, hi));

          (* "It raises Overflow when the result is not representable" *)
          overflow (lab "div/Overflow-minInt-by-minus-one", fn () => I.div (lo, minusOne));
          overflow (lab "quot/Overflow-minInt-by-minus-one", fn () => I.quot (lo, minusOne));
          (* mod and rem raise Div only; minInt mod ~1 is 0 *)
          eqI (lab "mod/minInt-by-minus-one", v zero, fn () => I.mod (lo, minusOne));
          eqI (lab "rem/minInt-by-minus-one", v zero, fn () => I.rem (lo, minusOne));
          divide (lab "div/Div-minInt", fn () => I.div (lo, zero));
          divide (lab "mod/Div-minInt", fn () => I.mod (lo, zero));
          divide (lab "quot/Div-minInt", fn () => I.quot (lo, zero));
          divide (lab "rem/Div-minInt", fn () => I.rem (lo, zero));
          eqI (lab "div/minInt-by-one", v lo, fn () => I.div (lo, one));
          eqI (lab "div/minInt-by-two", fn () => I.~ h, fn () => I.div (lo, two));
          eqI (lab "mod/minInt-by-two", v zero, fn () => I.mod (lo, two));
          eqI (lab "quot/minInt-by-two", fn () => I.~ h, fn () => I.quot (lo, two));
          eqI (lab "rem/minInt-by-two", v zero, fn () => I.rem (lo, two));
          eqI (lab "div/maxInt-by-minus-one", fn () => I.+ (lo, one), fn () => I.div (hi, minusOne));
          eqI (lab "mod/maxInt-by-minus-one", v zero, fn () => I.mod (hi, minusOne));
          eqI (lab "quot/maxInt-by-minus-one", fn () => I.+ (lo, one), fn () => I.quot (hi, minusOne));
          eqI (lab "div/maxInt-by-two", fn () => I.- (h, one), fn () => I.div (hi, two));
          eqI (lab "mod/maxInt-by-two", v one, fn () => I.mod (hi, two));
          eqI (lab "div/next-to-minInt-by-minus-one", v hi, fn () => I.div (I.+ (lo, one), minusOne));
          eqI (lab "quot/next-to-minInt-by-minus-one", v hi, fn () => I.quot (I.+ (lo, one), minusOne));
          (* -2^(n-1) / (2^(n-1) - 1) is just below ~1 *)
          eqK (lab "div/minInt-by-maxInt", ~2, fn () => I.div (lo, hi));
          eqI (lab "mod/minInt-by-maxInt", fn () => I.- (hi, one), fn () => I.mod (lo, hi));
          eqK (lab "quot/minInt-by-maxInt", ~1, fn () => I.quot (lo, hi));
          eqK (lab "rem/minInt-by-maxInt", ~1, fn () => I.rem (lo, hi));
          (* (2^(n-1) - 1) / -2^(n-1) is just above ~1 *)
          eqK (lab "div/maxInt-by-minInt", ~1, fn () => I.div (hi, lo));
          eqK (lab "mod/maxInt-by-minInt", ~1, fn () => I.mod (hi, lo));
          eqK (lab "quot/maxInt-by-minInt", 0, fn () => I.quot (hi, lo));
          eqI (lab "rem/maxInt-by-minInt", v hi, fn () => I.rem (hi, lo));
          eqK (lab "div/minInt-by-minInt", 1, fn () => I.div (lo, lo));
          eqK (lab "mod/minInt-by-minInt", 0, fn () => I.mod (lo, lo));
          eqK (lab "quot/minInt-by-minInt", 1, fn () => I.quot (lo, lo));
          eqK (lab "rem/minInt-by-minInt", 0, fn () => I.rem (lo, lo));
          eqK (lab "div/one-by-minInt", ~1, fn () => I.div (one, lo));
          eqI (lab "mod/one-by-minInt", fn () => I.+ (lo, one), fn () => I.mod (one, lo));
          eqK (lab "div/minus-one-by-minInt", 0, fn () => I.div (minusOne, lo));
          eqK (lab "mod/minus-one-by-minInt", ~1, fn () => I.mod (minusOne, lo));
          eqK (lab "quot/one-by-minInt", 0, fn () => I.quot (one, lo));
          eqK (lab "rem/one-by-minInt", 1, fn () => I.rem (one, lo));

          (* "This can happen, for example, when int is an n-bit 2's-complement
             integer type, and ~ is applied to -2^(n-1)." *)
          overflow (lab "~/Overflow-minInt", fn () => I.~ lo);
          eqI (lab "~/maxInt", fn () => I.+ (lo, one), fn () => I.~ hi);
          eqI (lab "~/next-to-minInt", v hi, fn () => I.~ (I.+ (lo, one)));
          overflow (lab "abs/Overflow-minInt", fn () => I.abs lo);
          eqI (lab "abs/next-to-minInt", v hi, fn () => I.abs (I.+ (lo, one)));
          eqI (lab "abs/maxInt", v hi, fn () => I.abs hi);

          eqOrd (lab "compare/minInt-maxInt", LESS, fn () => I.compare (lo, hi));
          eqOrd (lab "compare/maxInt-minInt", GREATER, fn () => I.compare (hi, lo));
          eqOrd (lab "compare/minInt-minInt", EQUAL, fn () => I.compare (lo, lo));
          eqOrd (lab "compare/maxInt-maxInt", EQUAL, fn () => I.compare (hi, hi));
          eqOrd (lab "compare/minInt-zero", LESS, fn () => I.compare (lo, zero));
          eqB (lab "</minInt-maxInt", true, fn () => I.< (lo, hi));
          eqB (lab "</maxInt-minInt", false, fn () => I.< (hi, lo));
          eqB (lab "</minInt-minInt", false, fn () => I.< (lo, lo));
          eqB (lab "<=/minInt-maxInt", true, fn () => I.<= (lo, hi));
          eqB (lab "<=/maxInt-minInt", false, fn () => I.<= (hi, lo));
          eqB (lab "<=/minInt-minInt", true, fn () => I.<= (lo, lo));
          eqB (lab ">/minInt-maxInt", false, fn () => I.> (lo, hi));
          eqB (lab ">/maxInt-minInt", true, fn () => I.> (hi, lo));
          eqB (lab ">/maxInt-maxInt", false, fn () => I.> (hi, hi));
          eqB (lab ">=/minInt-maxInt", false, fn () => I.>= (lo, hi));
          eqB (lab ">=/maxInt-minInt", true, fn () => I.>= (hi, lo));
          eqB (lab ">=/maxInt-maxInt", true, fn () => I.>= (hi, hi));
          eqI (lab "min/minInt-maxInt", v lo, fn () => I.min (lo, hi));
          eqI (lab "min/maxInt-minInt", v lo, fn () => I.min (hi, lo));
          eqI (lab "max/minInt-maxInt", v hi, fn () => I.max (lo, hi));
          eqI (lab "max/maxInt-minInt", v hi, fn () => I.max (hi, lo));
          eqN (lab "sign/minInt", ~1, fn () => I.sign lo);
          eqN (lab "sign/maxInt", 1, fn () => I.sign hi);
          eqB (lab "sameSign/minInt-maxInt", false, fn () => I.sameSign (lo, hi));
          eqB (lab "sameSign/minInt-minus-one", true, fn () => I.sameSign (lo, minusOne));
          eqB (lab "sameSign/maxInt-one", true, fn () => I.sameSign (hi, one));
          eqB (lab "sameSign/minInt-zero", false, fn () => I.sameSign (lo, zero));
          eqB (lab "sameSign/zero-maxInt", false, fn () => I.sameSign (zero, hi));

          eqS (lab "toString/minInt", loText, fn () => I.toString lo);
          eqS (lab "toString/maxInt", hiText, fn () => I.toString hi);
          eqS (lab "toString/next-to-minInt", "~" ^ hiText, fn () => I.toString (I.+ (lo, one)));
          eqIO (lab "fromString/minInt", fn () => SOME lo, fn () => I.fromString loText);
          eqIO (lab "fromString/minInt-with-minus", fn () => SOME lo,
                fn () => I.fromString ("-" ^ NumStr.pow2String 10 (n - 1)));
          eqIO (lab "fromString/maxInt", fn () => SOME hi, fn () => I.fromString hiText);
          eqIO (lab "fromString/maxInt-with-plus", fn () => SOME hi, fn () => I.fromString ("+" ^ hiText));
          eqIO (lab "fromString/maxInt-then-letters", fn () => SOME hi, fn () => I.fromString (hiText ^ "abc"));
          eqIO (lab "fromString/maxInt-with-leading-zeros", fn () => SOME hi,
                fn () => I.fromString ("0000000000000000000000000000000000000000" ^ hiText));
          eqIO (lab "fromString/minInt-with-leading-zeros", fn () => SOME lo,
                fn () => I.fromString ("~0000000000000000000000000000000000000000" ^ NumStr.pow2String 10 (n - 1)));
          (* "raises Overflow when an integer can be parsed, but is too large" *)
          overflow (lab "fromString/Overflow-maxInt-plus-one", fn () => I.fromString above);
          overflow (lab "fromString/Overflow-minInt-minus-one", fn () => I.fromString below);
          overflow (lab "fromString/Overflow-maxInt-times-ten", fn () => I.fromString (hiText ^ "0"));
          overflow (lab "fromString/Overflow-minInt-times-ten", fn () => I.fromString (loText ^ "0"));
          overflow (lab "fromString/Overflow-after-whitespace", fn () => I.fromString ("  +" ^ above ^ " "));
          overflow (lab "fromString/Overflow-many-digits",
                    fn () => I.fromString (hiText ^ hiText ^ hiText ^ hiText ^ hiText));

          (* conversions: "They raise Overflow if the value does not fit." *)
          if largeWider then
            (eqL (lab "toLarge/maxInt", v lhi, fn () => I.toLarge hi);
             eqL (lab "toLarge/minInt", v llo, fn () => I.toLarge lo);
             eqI (lab "fromLarge/maxInt", v hi, fn () => I.fromLarge lhi);
             eqI (lab "fromLarge/minInt", v lo, fn () => I.fromLarge llo);
             overflow (lab "fromLarge/Overflow-maxInt-plus-one", fn () => I.fromLarge (L.+ (lhi, lone)));
             overflow (lab "fromLarge/Overflow-minInt-minus-one", fn () => I.fromLarge (L.- (llo, lone)));
             overflow (lab "fromLarge/Overflow-twice-maxInt", fn () => I.fromLarge (L.+ (lhi, lhi)));
             overflow (lab "fromLarge/Overflow-twice-minInt", fn () => I.fromLarge (L.+ (llo, llo))))
          else
            (eqL (lab "toLarge/maxInt", fn () => valOf L.maxInt, fn () => I.toLarge hi);
             eqL (lab "toLarge/minInt", fn () => valOf L.minInt, fn () => I.toLarge lo);
             eqI (lab "fromLarge/maxInt", v hi, fn () => I.fromLarge (valOf L.maxInt));
             eqI (lab "fromLarge/minInt", v lo, fn () => I.fromLarge (valOf L.minInt)));
          if intWider then
            (eqN (lab "toInt/maxInt", ipow2 (n - 1) - 1, fn () => I.toInt hi);
             eqN (lab "toInt/minInt", ~ (ipow2 (n - 1)), fn () => I.toInt lo);
             eqI (lab "fromInt/maxInt", v hi, fn () => I.fromInt (ipow2 (n - 1) - 1));
             eqI (lab "fromInt/minInt", v lo, fn () => I.fromInt (~ (ipow2 (n - 1))));
             overflow (lab "fromInt/Overflow-maxInt-plus-one", fn () => I.fromInt (ipow2 (n - 1)));
             overflow (lab "fromInt/Overflow-minInt-minus-one", fn () => I.fromInt (~ (ipow2 (n - 1)) - 1)))
          else if intNarrower then ()
          else
            (eqN (lab "toInt/maxInt", valOf Int.maxInt, fn () => I.toInt hi);
             eqN (lab "toInt/minInt", valOf Int.minInt, fn () => I.toInt lo);
             eqI (lab "fromInt/maxInt", v hi, fn () => I.fromInt (valOf Int.maxInt));
             eqI (lab "fromInt/minInt", v lo, fn () => I.fromInt (valOf Int.minInt)))
        end
    | _ =>
        (* arbitrary precision: "If it is NONE, int has arbitrary precision" *)
        let
          fun big () = pow2 200
          val text200 = NumStr.pow2String 10 200
          val text201 = NumStr.pow2String 10 201
          val text400 = NumStr.pow2String 10 400
        in
          eqIO (lab "minInt/NONE", fn () => NONE, fn () => I.minInt);
          eqIO (lab "maxInt/NONE", fn () => NONE, fn () => I.maxInt);
          eqS (lab "toString/2^200", text200, fn () => I.toString (big ()));
          eqS (lab "toString/~2^200", "~" ^ text200, fn () => I.toString (I.~ (big ())));
          eqS (lab "toString/2^200-1", NumStr.pow2Minus1String 10 200, fn () => I.toString (I.- (big (), one)));
          eqIO (lab "fromString/2^200", fn () => SOME (big ()), fn () => I.fromString text200);
          eqIO (lab "fromString/~2^200", fn () => SOME (I.~ (big ())), fn () => I.fromString ("~" ^ text200));
          eqIO (lab "fromString/-2^200", fn () => SOME (I.~ (big ())), fn () => I.fromString ("-" ^ text200));
          eqIO (lab "fromString/2^200-then-letters", fn () => SOME (big ()), fn () => I.fromString (text200 ^ "x1"));
          eqS (lab "+/2^200-twice", text201, fn () => I.toString (I.+ (big (), big ())));
          eqI (lab "+/2^200-inverse", fn () => zero, fn () => I.+ (big (), I.~ (big ())));
          eqS (lab "-/zero-minus-2^200", "~" ^ text200, fn () => I.toString (I.- (zero, big ())));
          eqI (lab "-/2^201-minus-2^200", big, fn () => I.- (pow2 201, big ()));
          eqS (lab "*/2^200-squared", text400, fn () => I.toString (I.* (big (), big ())));
          eqS (lab "*/2^200-times-minus-two", "~" ^ text201, fn () => I.toString (I.* (big (), i ~2)));
          eqI (lab "*/2^200-times-zero", fn () => zero, fn () => I.* (big (), zero));
          eqI (lab "*/zero-times-2^200", fn () => zero, fn () => I.* (zero, big ()));
          eqI (lab "*/zero-times-~2^200", fn () => zero, fn () => I.* (zero, I.~ (big ())));
          eqN (lab "sign/zero-times-2^200", 0, fn () => I.sign (I.* (zero, big ())));
          eqI (lab "+/zero-times-2^200-plus-minus-six", fn () => i ~6, fn () => I.+ (I.* (zero, big ()), i ~6));
          eqI (lab "div/2^400-by-2^200", big, fn () => I.div (pow2 400, big ()));
          eqI (lab "mod/2^400-by-2^200", fn () => zero, fn () => I.mod (pow2 400, big ()));
          (* floor ((2^200 + 1) / -2^200) = ~2, and 2^200 + 1 - 2 * 2^200 = 1 - 2^200 *)
          eqK (lab "div/2^200+1-by-~2^200", ~2, fn () => I.div (I.+ (big (), one), I.~ (big ())));
          eqI (lab "mod/2^200+1-by-~2^200", fn () => I.- (one, big ()),
               fn () => I.mod (I.+ (big (), one), I.~ (big ())));
          eqK (lab "quot/2^200+1-by-~2^200", ~1, fn () => I.quot (I.+ (big (), one), I.~ (big ())));
          eqK (lab "rem/2^200+1-by-~2^200", 1, fn () => I.rem (I.+ (big (), one), I.~ (big ())));
          eqI (lab "quot/~2^400-by-2^200", fn () => I.~ (big ()), fn () => I.quot (I.~ (pow2 400), big ()));
          divide (lab "div/Div-2^200", fn () => I.div (big (), zero));
          divide (lab "mod/Div-2^200", fn () => I.mod (big (), zero));
          divide (lab "quot/Div-2^200", fn () => I.quot (big (), zero));
          divide (lab "rem/Div-2^200", fn () => I.rem (big (), zero));
          eqI (lab "~/2^200", fn () => I.- (zero, big ()), fn () => I.~ (big ()));
          eqI (lab "abs/~2^200", big, fn () => I.abs (I.~ (big ())));
          eqI (lab "abs/2^200", big, fn () => I.abs (big ()));
          eqOrd (lab "compare/2^200-and-successor", LESS, fn () => I.compare (big (), I.+ (big (), one)));
          eqOrd (lab "compare/2^200-and-~2^200", GREATER, fn () => I.compare (big (), I.~ (big ())));
          eqOrd (lab "compare/2^200-equal", EQUAL, fn () => I.compare (big (), pow2 200));
          eqOrd (lab "compare/~2^200-and-~2^201", GREATER, fn () => I.compare (I.~ (big ()), I.~ (pow2 201)));
          eqB (lab "</2^200-2^201", true, fn () => I.< (big (), pow2 201));
          eqB (lab "<=/2^200-2^200", true, fn () => I.<= (big (), big ()));
          eqB (lab ">/2^200-2^201", false, fn () => I.> (big (), pow2 201));
          eqB (lab ">=/~2^200-~2^201", true, fn () => I.>= (I.~ (big ()), I.~ (pow2 201)));
          eqI (lab "min/2^200-~2^201", fn () => I.~ (pow2 201), fn () => I.min (big (), I.~ (pow2 201)));
          eqI (lab "max/2^200-~2^201", big, fn () => I.max (big (), I.~ (pow2 201)));
          eqN (lab "sign/2^200", 1, fn () => I.sign (big ()));
          eqN (lab "sign/~2^200", ~1, fn () => I.sign (I.~ (big ())));
          eqB (lab "sameSign/2^200-one", true, fn () => I.sameSign (big (), one));
          eqB (lab "sameSign/2^200-~2^200", false, fn () => I.sameSign (big (), I.~ (big ())));
          if wider (I.precision, L.precision) then ()
          else
            (eqL (lab "toLarge/2^200", fn () => lpow2 200, fn () => I.toLarge (big ()));
             eqL (lab "toLarge/~2^200", fn () => L.~ (lpow2 200), fn () => I.toLarge (I.~ (big ())));
             eqI (lab "fromLarge/2^200", big, fn () => I.fromLarge (lpow2 200));
             eqI (lab "fromLarge/~2^200", fn () => I.~ (big ()), fn () => I.fromLarge (L.~ (lpow2 200))));
          if intNarrower then
            (overflow (lab "toInt/Overflow-2^200", fn () => I.toInt (big ()));
             overflow (lab "toInt/Overflow-~2^200", fn () => I.toInt (I.~ (big ()))))
          else ()
        end

  (* Int.int is narrower than I.int: "They raise Overflow if the value does not fit." *)
  val () =
    if intNarrower then
      (eqN (lab "toInt/Int.maxInt", valOf Int.maxInt, fn () => I.toInt (I.fromInt (valOf Int.maxInt)));
       eqN (lab "toInt/Int.minInt", valOf Int.minInt, fn () => I.toInt (I.fromInt (valOf Int.minInt)));
       overflow (lab "toInt/Overflow-Int.maxInt-plus-one",
                 fn () => I.toInt (I.+ (I.fromInt (valOf Int.maxInt), one)));
       overflow (lab "toInt/Overflow-Int.minInt-minus-one",
                 fn () => I.toInt (I.- (I.fromInt (valOf Int.minInt), one)));
       eqS (lab "fromInt/Int.maxInt-plus-one",
            NumStr.pow2String 10 (valOf Int.precision - 1),
            fn () => I.toString (I.+ (I.fromInt (valOf Int.maxInt), one)));
       eqS (lab "fromInt/Int.minInt",
            "~" ^ NumStr.pow2String 10 (valOf Int.precision - 1),
            fn () => I.toString (I.fromInt (valOf Int.minInt))))
    else ()

  (* ---- laws and models, on pseudo-random numbers ----
     A sample is built from pseudo-random binary digits, together with its
     value as a LargeInt.int and its decimal text, neither of which involves
     the structure under test. *)
  type sample = {v : I.int, l : L.int, neg : bool, digits : string}

  val samplesBuilt = ref true
  val fullBits = case I.precision of SOME n => n - 1 | NONE => 200
  val halfBits = case I.precision of SOME n => n - 2 | NONE => 200

  fun sample (maxBits : int) : sample =
    let
      val k = T.range (0, maxBits)
      val bits = List.tabulate (k, fn _ => T.range (0, 1) = 1)
      val neg = T.range (0, 1) = 1
    in
      let
        val m = List.foldl (fn (b, v) => I.+ (I.+ (v, v), if b then one else zero)) zero bits
        val lm = List.foldl (fn (b, v) => L.+ (L.+ (v, v), if b then lone else lzero)) lzero bits
        val ds = NumStr.fromBits 10 bits
      in
        (* a negative sample is ~m - 1, from minInt up to ~1 *)
        if neg then {v = I.- (I.~ m, one), l = L.- (L.~ lm, lone), neg = true,
                     digits = NumStr.toString (NumStr.succ 10 ds)}
        else {v = m, l = lm, neg = false, digits = NumStr.toString ds}
      end
      handle _ => (samplesBuilt := false; {v = zero, l = lzero, neg = false, digits = "0"})
    end

  fun text ({neg, digits, ...} : sample) = if neg then "~" ^ digits else digits
  fun signOf ({neg, digits, ...} : sample) = if neg then ~1 else if digits = "0" then 0 else 1

  fun inRange r =
    case lbounds of
      NONE => true
    | SOME (llo, lhi) => L.>= (r, llo) andalso L.<= (r, lhi)

  (* expectL (label, r, f): f () is the number r when r is representable, and
     raises Overflow otherwise. *)
  fun expectL (label, r : unit -> L.int, f : unit -> I.int) =
    case (SOME (r ()) handle _ => NONE) of
      NONE => T.fail (label, "the expected value raised an exception")
    | SOME r => if inRange r then T.eq showL (label, r, fn () => I.toLarge (f ()))
                else overflow (label, f)

  (* magLess (r, b): |r| < |b|, without computing an absolute value. *)
  fun magLess (r, b) =
    if I.>= (r, zero) then (if I.> (b, zero) then I.< (r, b) else I.> (I.~ r, b))
    else (if I.> (b, zero) then I.> (r, I.~ b) else I.> (r, b))

  val isMinInt = fn x => case bounds of SOME (_, lo, _) => x = lo | NONE => false

  val () = T.seed 3
  val () = T.repeat (40, fn k =>
    let
      val s = "-" ^ Int.toString k
      val a = sample fullBits
      val b = sample fullBits
      val c = sample halfBits
      val d = sample halfBits
      (* a divisor for a: not zero, and not ~1 when a is minInt *)
      val e = if #v b = zero orelse (#v b = minusOne andalso isMinInt (#v a))
              then {v = two, l = L.fromInt 2, neg = false, digits = "2"} : sample
              else b
      val (av, bv, cv, dv, ev) = (#v a, #v b, #v c, #v d, #v e)
      val (al, bl, el) = (#l a, #l b, #l e)
    in
      eqL (lab "toLarge/model" ^ s, fn () => al, fn () => I.toLarge av);
      eqI (lab "fromLarge/model" ^ s, fn () => av, fn () => I.fromLarge al);
      eqS (lab "toString/model" ^ s, text a, fn () => I.toString av);
      eqIO (lab "fromString/model" ^ s, fn () => SOME av, fn () => I.fromString (text a));
      eqIO (lab "fromString/other-sign" ^ s, fn () => SOME av,
            fn () => I.fromString ((if #neg a then "-" else "+") ^ #digits a));
      eqIO (lab "fromString/round-trip" ^ s, fn () => SOME bv, fn () => I.fromString (I.toString bv));

      expectL (lab "+/model" ^ s, fn () => L.+ (al, bl), fn () => I.+ (av, bv));
      expectL (lab "-/model" ^ s, fn () => L.- (al, bl), fn () => I.- (av, bv));
      expectL (lab "*/model" ^ s, fn () => L.* (al, bl), fn () => I.* (av, bv));
      expectL (lab "~/model" ^ s, fn () => L.- (lzero, al), fn () => I.~ av);
      expectL (lab "abs/model" ^ s, fn () => if #neg a then L.- (lzero, al) else al, fn () => I.abs av);

      (* (i div j) * j + (i mod j) = i, and i mod j has the sign of j; with
         |i mod j| < |j| this determines both *)
      eqL (lab "div/law" ^ s, fn () => al,
           fn () => L.+ (L.* (I.toLarge (I.div (av, ev)), el), I.toLarge (I.mod (av, ev))));
      T.check (lab "mod/sign-of-divisor" ^ s,
               fn () => let val r = I.mod (av, ev) in r = zero orelse I.sign r = signOf e end);
      T.check (lab "mod/magnitude" ^ s, fn () => magLess (I.mod (av, ev), ev));
      (* (i quot j) * j + (i rem j) = i, and i rem j has the sign of i *)
      eqL (lab "quot/law" ^ s, fn () => al,
           fn () => L.+ (L.* (I.toLarge (I.quot (av, ev)), el), I.toLarge (I.rem (av, ev))));
      T.check (lab "rem/sign-of-dividend" ^ s,
               fn () => let val r = I.rem (av, ev) in r = zero orelse I.sign r = signOf a end);
      T.check (lab "rem/magnitude" ^ s, fn () => magLess (I.rem (av, ev), ev));
      (* rounding down and rounding to zero differ by one when the quotient
         is negative and inexact *)
      eqI (lab "div/versus-quot" ^ s,
           fn () => if I.rem (av, ev) = zero orelse signOf a = signOf e then I.quot (av, ev)
                    else I.- (I.quot (av, ev), one),
           fn () => I.div (av, ev));
      eqI (lab "div/by-one" ^ s, fn () => av, fn () => I.div (av, one));
      eqI (lab "mod/by-one" ^ s, fn () => zero, fn () => I.mod (av, one));
      eqI (lab "quot/by-one" ^ s, fn () => av, fn () => I.quot (av, one));
      eqI (lab "rem/by-one" ^ s, fn () => zero, fn () => I.rem (av, one));

      eqOrd (lab "compare/model" ^ s, L.compare (al, bl), fn () => I.compare (av, bv));
      eqOrd (lab "compare/reflexive" ^ s, EQUAL, fn () => I.compare (av, av));
      eqB (lab "</model" ^ s, L.compare (al, bl) = LESS, fn () => I.< (av, bv));
      eqB (lab "<=/model" ^ s, L.compare (al, bl) <> GREATER, fn () => I.<= (av, bv));
      eqB (lab ">/model" ^ s, L.compare (al, bl) = GREATER, fn () => I.> (av, bv));
      eqB (lab ">=/model" ^ s, L.compare (al, bl) <> LESS, fn () => I.>= (av, bv));
      eqI (lab "min/model" ^ s, fn () => if L.compare (al, bl) = GREATER then bv else av,
           fn () => I.min (av, bv));
      eqI (lab "max/model" ^ s, fn () => if L.compare (al, bl) = GREATER then av else bv,
           fn () => I.max (av, bv));
      eqN (lab "sign/model" ^ s, signOf a, fn () => I.sign av);
      eqB (lab "sameSign/model" ^ s, signOf a = signOf b, fn () => I.sameSign (av, bv));

      (* half-range operands: no sum or difference overflows *)
      eqI (lab "+/commutative" ^ s, fn () => I.+ (dv, cv), fn () => I.+ (cv, dv));
      eqI (lab "+/then-minus" ^ s, fn () => cv, fn () => I.- (I.+ (cv, dv), dv));
      eqI (lab "-/plus-negation" ^ s, fn () => I.+ (cv, I.~ dv), fn () => I.- (cv, dv));
      eqI (lab "~/involution" ^ s, fn () => cv, fn () => I.~ (I.~ cv));
      eqI (lab "*/by-two" ^ s, fn () => I.+ (cv, cv), fn () => I.* (cv, two));
      eqI (lab "*/by-minus-one" ^ s, fn () => I.~ cv, fn () => I.* (minusOne, cv));
      eqI (lab "abs/law" ^ s, fn () => if #neg c then I.~ cv else cv, fn () => I.abs cv);
      eqN (lab "toInt/model" ^ s, k - 20, fn () => I.toInt (I.+ (I.fromInt (k - 20), zero)))
    end)
  val () = T.check (lab "fromInt/samples-built", fn () => !samplesBuilt)
end
