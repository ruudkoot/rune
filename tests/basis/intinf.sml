(* requires: IntInf LargeInt *)
(* uses: fn/numstr.sml fn/integer_fn.sml *)
(* The IntInf structure (signature INT_INF). Expected values follow the text
   of https://smlfamily.github.io/Basis/int-inf.html and, for the members of
   INTEGER, of https://smlfamily.github.io/Basis/integer.html: those are
   checked by fn/integer_fn.sml, fmt and scan in intinf_scan.sml.

   IntInf.int has no constants and no overloaded operators on every system,
   so numbers are built with IntInf.fromInt, IntInf.fromString and
   arithmetic. *)
structure TestIntInf =
struct
  structure Generic = TestIntegerFn (structure I = IntInf val name = "IntInf")

  structure I = IntInf
  fun show x = I.toString x handle _ => "?"

  (* eqv: T.eq with the expected value in a thunk as well. *)
  fun eqv sh (label, expected, f) =
    case (SOME (expected ()) handle _ => NONE) of
      SOME e => T.eq sh (label, e, f)
    | NONE => T.fail (label, "the expected value raised an exception")
  val eqI = eqv show
  val eqP = eqv (T.pair (show, show))
  val eqN = T.eq T.int
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqOrd = T.eq T.order
  val i = I.fromInt
  fun eqK (label, k, f) = eqI (label, fn () => i k, f)
  (* eqT: the decimal text of the result *)
  fun eqT (label, text, f) = eqS (label, text, fn () => I.toString (f ()))

  val zero = i 0
  val one = i 1
  val two = i 2
  fun p2 k = if k <= 0 then one else let val h = p2 (k - 1) in I.+ (h, h) end      (* 2^k *)
  fun tenTo k = if k <= 0 then one else I.* (i 10, tenTo (k - 1))                  (* 10^k *)
  fun factorial k = if k <= 1 then one else I.* (i k, factorial (k - 1))
  fun num s = valOf (I.fromString s)

  (* "one of the possible implementations of the INTEGER interface ... arbitrarily large integers" *)
  val () = T.eq (T.option T.int) ("IntInf.precision/NONE", NONE, fn () => I.precision)
  val () = T.eq (T.option show) ("IntInf.minInt/no-least-number", NONE, fn () => I.minInt)
  val () = T.eq (T.option show) ("IntInf.maxInt/no-greatest-number", NONE, fn () => I.maxInt)

  (* ---- numbers whose decimal text is well known ---- *)
  val text2p64 = "18446744073709551616"
  val text2p100 = "1267650600228229401496703205376"
  val text2p128 = "340282366920938463463374607431768211456"
  val text20f = "2432902008176640000"
  val text25f = "15511210043330985984000000"
  val text30f = "265252859812191058636308480000000"
  val () = eqT ("IntInf.+/2^63-twice", text2p64, fn () => I.+ (p2 63, p2 63))
  val () = eqT ("IntInf.*/2^64-squared", text2p128, fn () => I.* (p2 64, p2 64))
  val () = eqT ("IntInf.*/2^50-squared", text2p100, fn () => I.* (p2 50, p2 50))
  val () = eqT ("IntInf.*/factorial-20", text20f, fn () => factorial 20)
  val () = eqT ("IntInf.*/factorial-25", text25f, fn () => factorial 25)
  val () = eqT ("IntInf.*/factorial-30", text30f, fn () => factorial 30)
  val () = eqT ("IntInf.*/negative-factorial", "~" ^ text25f, fn () => I.* (I.~ (factorial 24), i 25))
  val () = eqT ("IntInf.*/10^15+1-times-10^15-1", "999999999999999999999999999999",
                fn () => I.* (I.+ (tenTo 15, one), I.- (tenTo 15, one)))
  val () = eqT ("IntInf.-/10^30-minus-one", "999999999999999999999999999999", fn () => I.- (tenTo 30, one))
  val () = eqT ("IntInf.-/one-minus-10^30", "~999999999999999999999999999999", fn () => I.- (one, tenTo 30))
  val () = eqT ("IntInf.+/carry-chain", "1000000000000000000000000000000",
                fn () => I.+ (num "999999999999999999999999999999", one))
  val () = eqI ("IntInf.fromString/2^64", fn () => p2 64, fn () => num text2p64)
  val () = eqI ("IntInf.fromString/factorial-30", fn () => factorial 30, fn () => num text30f)
  val () = eqI ("IntInf.fromString/~2^128", fn () => I.~ (p2 128), fn () => num ("~" ^ text2p128))
  val () = eqT ("IntInf.toString/10^30", "1000000000000000000000000000000", fn () => tenTo 30)
  val () = eqT ("IntInf.toString/~10^30", "~1000000000000000000000000000000", fn () => I.~ (tenTo 30))
  (* 30!/25! = 26 * 27 * 28 * 29 * 30 *)
  val () = eqK ("IntInf.div/factorial-30-by-factorial-25", 17100720, fn () => I.div (factorial 30, factorial 25))
  val () = eqK ("IntInf.mod/factorial-30-by-factorial-25", 0, fn () => I.mod (factorial 30, factorial 25))
  (* 2^64 = 18446744073 * 10^9 + 709551616 *)
  val () = eqT ("IntInf.div/2^64-by-10^9", "18446744073", fn () => I.div (p2 64, tenTo 9))
  val () = eqK ("IntInf.mod/2^64-by-10^9", 709551616, fn () => I.mod (p2 64, tenTo 9))
  val () = eqT ("IntInf.div/~2^64-by-10^9", "~18446744074", fn () => I.div (I.~ (p2 64), tenTo 9))
  val () = eqK ("IntInf.mod/~2^64-by-10^9", 290448384, fn () => I.mod (I.~ (p2 64), tenTo 9))
  val () = eqT ("IntInf.quot/~2^64-by-10^9", "~18446744073", fn () => I.quot (I.~ (p2 64), tenTo 9))
  val () = eqK ("IntInf.rem/~2^64-by-10^9", ~709551616, fn () => I.rem (I.~ (p2 64), tenTo 9))
  val () = eqT ("IntInf.div/2^64-by-~10^9", "~18446744074", fn () => I.div (p2 64, I.~ (tenTo 9)))
  val () = eqK ("IntInf.mod/2^64-by-~10^9", ~290448384, fn () => I.mod (p2 64, I.~ (tenTo 9)))
  val () = eqT ("IntInf.quot/2^64-by-~10^9", "~18446744073", fn () => I.quot (p2 64, I.~ (tenTo 9)))
  val () = eqK ("IntInf.rem/2^64-by-~10^9", 709551616, fn () => I.rem (p2 64, I.~ (tenTo 9)))

  (* ---- divMod (i, j) = (i div j, i mod j); quotRem (i, j) = (i quot j, i rem j) ---- *)
  fun pairs (label, f) cases =
    List.app (fn (a, b, q, r) =>
      eqP (label ^ Int.toString a ^ "-by-" ^ Int.toString b,
           fn () => (i q, i r), fn () => f (i a, i b))) cases
  val () = pairs ("IntInf.divMod/", I.divMod)
    [(7, 2, 3, 1), (~7, 2, ~4, 1), (7, ~2, ~4, ~1), (~7, ~2, 3, ~1),
     (6, 3, 2, 0), (~6, 3, ~2, 0), (6, ~3, ~2, 0), (~6, ~3, 2, 0),
     (0, 5, 0, 0), (0, ~5, 0, 0), (1, 2, 0, 1), (~1, 2, ~1, 1), (1, ~2, ~1, ~1), (~1, ~2, 0, ~1),
     (100, 7, 14, 2), (~100, 7, ~15, 5), (100, ~7, ~15, ~5), (~100, ~7, 14, ~2),
     (5, 1, 5, 0), (5, ~1, ~5, 0), (3, 5, 0, 3), (~3, 5, ~1, 2), (3, ~5, ~1, ~2)]
  val () = pairs ("IntInf.quotRem/", I.quotRem)
    [(7, 2, 3, 1), (~7, 2, ~3, ~1), (7, ~2, ~3, 1), (~7, ~2, 3, ~1),
     (6, 3, 2, 0), (~6, 3, ~2, 0), (6, ~3, ~2, 0), (~6, ~3, 2, 0),
     (0, 5, 0, 0), (0, ~5, 0, 0), (1, 2, 0, 1), (~1, 2, 0, ~1), (1, ~2, 0, 1), (~1, ~2, 0, ~1),
     (100, 7, 14, 2), (~100, 7, ~14, ~2), (100, ~7, ~14, 2), (~100, ~7, 14, ~2),
     (5, 1, 5, 0), (5, ~1, ~5, 0), (3, 5, 0, 3), (~3, 5, 0, ~3), (3, ~5, 0, 3)]
  (* "It raises Div if j = 0." *)
  val () = T.raises ("IntInf.divMod/Div", T.isDiv, fn () => I.divMod (i 5, zero))
  val () = T.raises ("IntInf.divMod/Div-zero-by-zero", T.isDiv, fn () => I.divMod (zero, zero))
  val () = T.raises ("IntInf.divMod/Div-2^100", T.isDiv, fn () => I.divMod (p2 100, zero))
  val () = T.raises ("IntInf.quotRem/Div", T.isDiv, fn () => I.quotRem (i 5, zero))
  val () = T.raises ("IntInf.quotRem/Div-zero-by-zero", T.isDiv, fn () => I.quotRem (zero, zero))
  val () = T.raises ("IntInf.quotRem/Div-~2^100", T.isDiv, fn () => I.quotRem (I.~ (p2 100), zero))
  (* -(10^30 + 7) = (-10^15 - 1) * 10^15 + (10^15 - 7) = -10^15 * 10^15 - 7 *)
  val () = eqP ("IntInf.divMod/10^30+7-by-10^15", fn () => (tenTo 15, i 7),
                fn () => I.divMod (I.+ (tenTo 30, i 7), tenTo 15))
  val () = eqP ("IntInf.divMod/~10^30-7-by-10^15", fn () => (I.- (I.~ (tenTo 15), one), I.- (tenTo 15, i 7)),
                fn () => I.divMod (I.- (I.~ (tenTo 30), i 7), tenTo 15))
  val () = eqP ("IntInf.quotRem/10^30+7-by-10^15", fn () => (tenTo 15, i 7),
                fn () => I.quotRem (I.+ (tenTo 30, i 7), tenTo 15))
  val () = eqP ("IntInf.quotRem/~10^30-7-by-10^15", fn () => (I.~ (tenTo 15), i ~7),
                fn () => I.quotRem (I.- (I.~ (tenTo 30), i 7), tenTo 15))
  (* floor ((2^200 + 1) / -2^200) = ~2 *)
  val () = eqP ("IntInf.divMod/2^200+1-by-~2^200", fn () => (i ~2, I.- (one, p2 200)),
                fn () => I.divMod (I.+ (p2 200, one), I.~ (p2 200)))
  val () = eqP ("IntInf.quotRem/2^200+1-by-~2^200", fn () => (i ~1, one),
                fn () => I.quotRem (I.+ (p2 200, one), I.~ (p2 200)))
  val () = eqP ("IntInf.divMod/small-by-2^200", fn () => (i ~1, I.- (p2 200, i 5)),
                fn () => I.divMod (i ~5, p2 200))
  val () = eqP ("IntInf.quotRem/small-by-2^200", fn () => (zero, i ~5), fn () => I.quotRem (i ~5, p2 200))

  (* ---- pow ---- *)
  val () = List.app (fn (a, b, r) =>
             eqK ("IntInf.pow/" ^ Int.toString a ^ "-to-" ^ Int.toString b, r, fn () => I.pow (i a, b)))
    [(2, 10, 1024), (3, 4, 81), (7, 1, 7), (10, 9, 1000000000), (~2, 3, ~8), (~2, 4, 16), (~3, 3, ~27),
     (0, 5, 0), (1, 1000, 1), (~1, 1000, 1), (~1, 1001, ~1),
     (* "When j = 0, pow(i, j) is 1; in particular, pow(0, 0) is 1." *)
     (0, 0, 1), (5, 0, 1), (~5, 0, 1), (1, 0, 1),
     (* j < 0: |i| = 1 gives i^j, |i| > 1 gives 0 *)
     (1, ~5, 1), (1, ~1, 1), (~1, ~3, ~1), (~1, ~4, 1), (~1, ~1, ~1), (2, ~1, 0), (2, ~100, 0),
     (~3, ~2, 0), (~2, ~1, 0), (100, ~3, 0)]
  (* j < 0 and i = 0: "Raise Div" *)
  val () = T.raises ("IntInf.pow/Div-zero-to-minus-one", T.isDiv, fn () => I.pow (zero, ~1))
  val () = T.raises ("IntInf.pow/Div-zero-to-minus-five", T.isDiv, fn () => I.pow (zero, ~5))
  val () = eqT ("IntInf.pow/2-to-64", text2p64, fn () => I.pow (two, 64))
  val () = eqT ("IntInf.pow/2-to-100", text2p100, fn () => I.pow (two, 100))
  val () = eqT ("IntInf.pow/2-to-200", NumStr.pow2String 10 200, fn () => I.pow (two, 200))
  val () = eqT ("IntInf.pow/~2-to-201", "~" ^ NumStr.pow2String 10 201, fn () => I.pow (i ~2, 201))
  val () = eqT ("IntInf.pow/~2-to-200", NumStr.pow2String 10 200, fn () => I.pow (i ~2, 200))
  val () = eqT ("IntInf.pow/10-to-30", "1000000000000000000000000000000", fn () => I.pow (i 10, 30))
  val () = eqT ("IntInf.pow/2^64-squared", text2p128, fn () => I.pow (p2 64, 2))
  val () = eqI ("IntInf.pow/2^100-to-one", fn () => p2 100, fn () => I.pow (p2 100, 1))
  val () = eqK ("IntInf.pow/2^100-to-zero", 1, fn () => I.pow (p2 100, 0))
  val () = eqK ("IntInf.pow/2^100-to-minus-one", 0, fn () => I.pow (p2 100, ~1))
  val () = eqK ("IntInf.pow/~2^100-to-minus-two", 0, fn () => I.pow (I.~ (p2 100), ~2))

  (*<< log2 *)
  (* "the largest integer k for which pow(2, k) <= i" *)
  val () = List.app (fn (a, r) => eqN ("IntInf.log2/" ^ Int.toString a, r, fn () => I.log2 (i a)))
    [(1, 0), (2, 1), (3, 1), (4, 2), (5, 2), (7, 2), (8, 3), (1000, 9), (1023, 9), (1024, 10), (1025, 10)]
  val () = eqN ("IntInf.log2/2^100", 100, fn () => I.log2 (p2 100))
  val () = eqN ("IntInf.log2/2^100-1", 99, fn () => I.log2 (I.- (p2 100, one)))
  val () = eqN ("IntInf.log2/2^100+1", 100, fn () => I.log2 (I.+ (p2 100, one)))
  val () = eqN ("IntInf.log2/2^1000", 1000, fn () => I.log2 (p2 1000))
  val () = eqN ("IntInf.log2/10^30", 99, fn () => I.log2 (tenTo 30))     (* 2^99 < 10^30 < 2^100 *)
  (* "It raises Domain if i <= 0" *)
  val () = T.raises ("IntInf.log2/Domain-zero", T.isDomain, fn () => I.log2 zero)
  val () = T.raises ("IntInf.log2/Domain-minus-one", T.isDomain, fn () => I.log2 (i ~1))
  val () = T.raises ("IntInf.log2/Domain-~2^100", T.isDomain, fn () => I.log2 (I.~ (p2 100)))
  (*>> log2 *)

  (*<< bitops *)
  (* "The bit-wise operations ... treat the integer arguments as having 2's
     complement representation": ~4 is ...11100, ~2 is ...11110. *)
  val () = List.app (fn (a, b, r) =>
             eqK ("IntInf.andb/" ^ Int.toString a ^ "-" ^ Int.toString b, r, fn () => I.andb (i a, i b)))
    [(12, 10, 8), (240, 60, 48), (171, 0, 0), (171, 171, 171), (~1, 12345, 12345), (12345, ~1, 12345),
     (~4, 7, 4), (~4, ~2, ~4), (~1, ~1, ~1), (~1, 0, 0), (~256, 511, 256), (~8, ~16, ~16)]
  val () = List.app (fn (a, b, r) =>
             eqK ("IntInf.orb/" ^ Int.toString a ^ "-" ^ Int.toString b, r, fn () => I.orb (i a, i b)))
    [(12, 10, 14), (240, 60, 252), (171, 0, 171), (171, 171, 171), (~1, 12345, ~1), (~4, 1, ~3),
     (~4, ~2, ~2), (~4, 7, ~1), (0, ~5, ~5), (~256, 255, ~1), (~8, ~16, ~8)]
  val () = List.app (fn (a, b, r) =>
             eqK ("IntInf.xorb/" ^ Int.toString a ^ "-" ^ Int.toString b, r, fn () => I.xorb (i a, i b)))
    [(12, 10, 6), (240, 60, 204), (171, 0, 171), (171, 171, 0), (~1, 5, ~6), (5, ~1, ~6),
     (~4, ~2, 2), (~4, 7, ~5), (~1, ~1, 0), (~256, 255, ~1), (~8, ~16, 8)]
  (* "It is equivalent to ~(i + 1)." *)
  val () = List.app (fn (a, r) => eqK ("IntInf.notb/" ^ Int.toString a, r, fn () => I.notb (i a)))
    [(0, ~1), (~1, 0), (5, ~6), (~6, 5), (1, ~2), (255, ~256), (~256, 255)]
  val () = eqI ("IntInf.notb/2^200", fn () => I.- (I.~ (p2 200), one), fn () => I.notb (p2 200))
  val () = eqI ("IntInf.notb/~2^200", fn () => I.- (p2 200, one), fn () => I.notb (I.~ (p2 200)))
  (* "if we let bit = 2^n, we have, for all sufficiently large values of n,
     andb(i, bit) = 0 if i >= 0, andb(i, bit) = bit if i < 0" *)
  val () = List.app (fn (c, x, negative) =>
             eqI ("IntInf.andb/2^200-with-" ^ c, fn () => if negative then p2 200 else zero,
                  fn () => I.andb (x (), p2 200)))
    [("minus-one", fn () => i ~1, true), ("~12345", fn () => i ~12345, true), ("12345", fn () => i 12345, false),
     ("zero", fn () => zero, false), ("~2^100", fn () => I.~ (p2 100), true), ("2^100", fn () => p2 100, false),
     ("~2^199-1", fn () => I.- (I.~ (p2 199), one), true), ("2^200-1", fn () => I.- (p2 200, one), false)]
  val () = eqI ("IntInf.andb/2^200-1-and-2^100", fn () => p2 100, fn () => I.andb (I.- (p2 200, one), p2 100))
  val () = eqI ("IntInf.andb/~2^100-and-2^200-1", fn () => I.- (p2 200, p2 100),
                fn () => I.andb (I.~ (p2 100), I.- (p2 200, one)))
  val () = eqI ("IntInf.orb/2^200-or-2^100", fn () => I.+ (p2 200, p2 100), fn () => I.orb (p2 200, p2 100))
  val () = eqI ("IntInf.orb/~2^200-or-2^100", fn () => I.+ (I.~ (p2 200), p2 100),
                fn () => I.orb (I.~ (p2 200), p2 100))
  val () = eqI ("IntInf.orb/~2^200-or-2^200-1", fn () => i ~1, fn () => I.orb (I.~ (p2 200), I.- (p2 200, one)))
  val () = eqI ("IntInf.xorb/2^200+2^100-xor-2^100", fn () => p2 200,
                fn () => I.xorb (I.+ (p2 200, p2 100), p2 100))
  val () = eqI ("IntInf.xorb/~2^200-xor-2^200-1", fn () => i ~1, fn () => I.xorb (I.~ (p2 200), I.- (p2 200, one)))
  val () = eqI ("IntInf.xorb/minus-one-xor-2^200", fn () => I.- (I.~ (p2 200), one), fn () => I.xorb (i ~1, p2 200))
  (*>> bitops *)

  (*<< shifts *)
  (* << (i, n) = i * 2^n; ~>> (i, n) = floor (i / 2^n) *)
  val () = List.app (fn (a, n, r) =>
             eqK ("IntInf.<</" ^ Int.toString a ^ "-by-" ^ Int.toString n, r, fn () => I.<< (i a, Word.fromInt n)))
    [(5, 0, 5), (1, 3, 8), (3, 2, 12), (~3, 2, ~12), (~1, 10, ~1024), (0, 1000, 0), (1, 29, 536870912),
     (~1, 0, ~1)]
  val () = eqT ("IntInf.<</one-by-100", text2p100, fn () => I.<< (one, 0w100))
  val () = eqT ("IntInf.<</minus-one-by-100", "~" ^ text2p100, fn () => I.<< (i ~1, 0w100))
  val () = eqT ("IntInf.<</one-by-200", NumStr.pow2String 10 200, fn () => I.<< (one, 0w200))
  val () = eqT ("IntInf.<</2^36-by-64", text2p100, fn () => I.<< (p2 36, 0w64))
  val () = eqI ("IntInf.<</three-by-1000", fn () => I.+ (p2 1001, p2 1000), fn () => I.<< (i 3, 0w1000))
  val () = List.app (fn (a, n, r) =>
             eqK ("IntInf.~>>/" ^ Int.toString a ^ "-by-" ^ Int.toString n, r, fn () => I.~>> (i a, Word.fromInt n)))
    [(5, 0, 5), (8, 3, 1), (7, 1, 3), (~7, 1, ~4), (~8, 1, ~4), (~1, 5, ~1), (~1, 0, ~1), (1, 1, 0),
     (~100, 3, ~13), (100, 3, 12), (1, 1000, 0), (~1, 1000, ~1), (~2, 1, ~1), (~3, 1, ~2), (0, 7, 0)]
  val () = eqK ("IntInf.~>>/2^100-by-100", 1, fn () => I.~>> (p2 100, 0w100))
  val () = eqK ("IntInf.~>>/2^100-by-101", 0, fn () => I.~>> (p2 100, 0w101))
  val () = eqK ("IntInf.~>>/~2^100-by-100", ~1, fn () => I.~>> (I.~ (p2 100), 0w100))
  val () = eqK ("IntInf.~>>/~2^100-by-101", ~1, fn () => I.~>> (I.~ (p2 100), 0w101))
  val () = eqK ("IntInf.~>>/~2^100-by-99", ~2, fn () => I.~>> (I.~ (p2 100), 0w99))
  val () = eqK ("IntInf.~>>/~2^100-1-by-100", ~2, fn () => I.~>> (I.- (I.~ (p2 100), one), 0w100))
  val () = eqT ("IntInf.~>>/2^200-by-100", text2p100, fn () => I.~>> (p2 200, 0w100))
  val () = eqT ("IntInf.~>>/2^164-by-64", text2p100, fn () => I.~>> (p2 164, 0w64))
  (*>> shifts *)

  (*<< largeint *)
  (* "the type LargeInt.int must be the same as the type IntInf.int" *)
  val () = T.check ("LargeInt.int/is-IntInf.int",
                    fn () => (LargeInt.fromInt 5 : IntInf.int) = (IntInf.fromInt 5 : LargeInt.int))
  val () = eqT ("LargeInt.+/is-IntInf.+", text2p64, fn () => LargeInt.+ (p2 63, IntInf.toLarge (p2 63)))
  val () = T.eq (T.option T.int) ("LargeInt.precision/is-IntInf.precision", I.precision, fn () => LargeInt.precision)
  val () = eqI ("IntInf.toLarge/identity", fn () => p2 100, fn () => I.toLarge (p2 100))
  val () = eqI ("IntInf.fromLarge/identity", fn () => I.~ (p2 100), fn () => I.fromLarge (I.~ (p2 100)))
  (*>> largeint *)

  (* ---- IntInf and Int agree on small operands ---- *)
  val () = T.seed 11
  val () = T.repeat (40, fn k =>
    let
      val s = "-" ^ Int.toString k
      val a = T.range (~30000, 30000)
      val b = T.range (~30000, 30000)
      val d = if b = 0 then 7 else b
      val e = T.range (0, 4)
      val c = T.range (~60, 60)
    in
      eqK ("IntInf.+/as-Int" ^ s, a + b, fn () => I.+ (i a, i b));
      eqK ("IntInf.-/as-Int" ^ s, a - b, fn () => I.- (i a, i b));
      eqK ("IntInf.*/as-Int" ^ s, a * b, fn () => I.* (i a, i b));
      eqK ("IntInf.div/as-Int" ^ s, a div d, fn () => I.div (i a, i d));
      eqK ("IntInf.mod/as-Int" ^ s, a mod d, fn () => I.mod (i a, i d));
      eqK ("IntInf.quot/as-Int" ^ s, Int.quot (a, d), fn () => I.quot (i a, i d));
      eqK ("IntInf.rem/as-Int" ^ s, Int.rem (a, d), fn () => I.rem (i a, i d));
      eqP ("IntInf.divMod/as-Int" ^ s, fn () => (i (a div d), i (a mod d)), fn () => I.divMod (i a, i d));
      eqP ("IntInf.quotRem/as-Int" ^ s, fn () => (i (Int.quot (a, d)), i (Int.rem (a, d))),
           fn () => I.quotRem (i a, i d));
      eqK ("IntInf.~/as-Int" ^ s, ~ a, fn () => I.~ (i a));
      eqK ("IntInf.abs/as-Int" ^ s, abs a, fn () => I.abs (i a));
      eqK ("IntInf.min/as-Int" ^ s, Int.min (a, b), fn () => I.min (i a, i b));
      eqK ("IntInf.max/as-Int" ^ s, Int.max (a, b), fn () => I.max (i a, i b));
      eqN ("IntInf.sign/as-Int" ^ s, Int.sign a, fn () => I.sign (i a));
      eqB ("IntInf.sameSign/as-Int" ^ s, Int.sign a = Int.sign b, fn () => I.sameSign (i a, i b));
      eqOrd ("IntInf.compare/as-Int" ^ s, Int.compare (a, b), fn () => I.compare (i a, i b));
      eqB ("IntInf.</as-Int" ^ s, a < b, fn () => I.< (i a, i b));
      eqB ("IntInf.<=/as-Int" ^ s, a <= b, fn () => I.<= (i a, i b));
      eqB ("IntInf.>/as-Int" ^ s, a > b, fn () => I.> (i a, i b));
      eqB ("IntInf.>=/as-Int" ^ s, a >= b, fn () => I.>= (i a, i b));
      eqN ("IntInf.toInt/as-Int" ^ s, a, fn () => I.toInt (i a));
      eqS ("IntInf.toString/as-Int" ^ s, Int.toString a, fn () => I.toString (i a));
      eqI ("IntInf.fromString/as-Int" ^ s, fn () => i a, fn () => valOf (I.fromString (Int.toString a)));
      (* |c|^e <= 60^4 < 2^30 *)
      eqK ("IntInf.pow/as-Int" ^ s, List.foldl (fn (_, p) => p * c) 1 (List.tabulate (e, fn _ => ())),
           fn () => I.pow (i c, e))
    end)

  (* ---- identities on large operands ----
     A sample is a sign and up to 300 pseudo-random binary digits, most
     significant first, read as a 2's complement number with that sign
     repeated to the left: the digits d of a negative number stand for
     -(the number with the digits not d) - 1. *)
  type sample = bool * bool list
  fun natOfBits bits = List.foldl (fn (b, v) => I.+ (I.+ (v, v), if b then one else zero)) zero bits
  fun valueOf ((neg, bits) : sample) =
    if neg then I.- (I.~ (natOfBits (List.map not bits)), one) else natOfBits bits
  fun sample () : sample =
    (T.range (0, 1) = 1, List.tabulate (T.range (0, 300), fn _ => T.range (0, 1) = 1))
  fun magLess (r, b) = I.< (I.abs r, I.abs b)

  val () = T.seed 12
  val () = T.repeat (40, fn k =>
    let
      val s = "-" ^ Int.toString k
      val a = valueOf (sample ()) handle _ => zero
      val b = valueOf (sample ()) handle _ => zero
      val c = valueOf (sample ()) handle _ => zero
      val d = if b = zero then i 7 else b
      val m = T.range (0, 5)
      val n = T.range (0, 5)
    in
      eqI ("IntInf.*/difference-of-squares" ^ s, fn () => I.- (I.* (a, a), I.* (b, b)),
           fn () => I.* (I.+ (a, b), I.- (a, b)));
      eqI ("IntInf.*/distributive" ^ s, fn () => I.+ (I.* (a, b), I.* (a, c)), fn () => I.* (a, I.+ (b, c)));
      eqI ("IntInf.*/commutative" ^ s, fn () => I.* (b, a), fn () => I.* (a, b));
      eqI ("IntInf.*/associative" ^ s, fn () => I.* (a, I.* (b, c)), fn () => I.* (I.* (a, b), c));
      eqI ("IntInf.+/associative" ^ s, fn () => I.+ (a, I.+ (b, c)), fn () => I.+ (I.+ (a, b), c));
      eqI ("IntInf.-/inverse-of-plus" ^ s, fn () => a, fn () => I.- (I.+ (a, b), b));
      eqI ("IntInf.~/minus-from-zero" ^ s, fn () => I.- (zero, a), fn () => I.~ a);
      eqI ("IntInf.div/of-product" ^ s, fn () => a, fn () => I.div (I.* (a, d), d));
      eqI ("IntInf.mod/of-product" ^ s, fn () => zero, fn () => I.mod (I.* (a, d), d));
      eqI ("IntInf.quot/of-product" ^ s, fn () => a, fn () => I.quot (I.* (a, d), d));
      eqI ("IntInf.rem/of-product" ^ s, fn () => zero, fn () => I.rem (I.* (a, d), d));
      (* (i div j) * j + (i mod j) = i, with the sign of j and |i mod j| < |j| *)
      eqI ("IntInf.divMod/law" ^ s, fn () => a,
           fn () => let val (q, r) = I.divMod (a, d) in I.+ (I.* (q, d), r) end);
      T.check ("IntInf.divMod/remainder" ^ s,
               fn () => let val (_, r) = I.divMod (a, d)
                        in (r = zero orelse I.sameSign (r, d)) andalso magLess (r, d) end);
      eqP ("IntInf.divMod/div-and-mod" ^ s, fn () => (I.div (a, d), I.mod (a, d)), fn () => I.divMod (a, d));
      (* (i quot j) * j + (i rem j) = i, with the sign of i and |i rem j| < |j| *)
      eqI ("IntInf.quotRem/law" ^ s, fn () => a,
           fn () => let val (q, r) = I.quotRem (a, d) in I.+ (I.* (q, d), r) end);
      T.check ("IntInf.quotRem/remainder" ^ s,
               fn () => let val (_, r) = I.quotRem (a, d)
                        in (r = zero orelse I.sameSign (r, a)) andalso magLess (r, d) end);
      eqP ("IntInf.quotRem/quot-and-rem" ^ s, fn () => (I.quot (a, d), I.rem (a, d)), fn () => I.quotRem (a, d));
      eqOrd ("IntInf.compare/successor" ^ s, LESS, fn () => I.compare (a, I.+ (a, one)));
      eqOrd ("IntInf.compare/difference" ^ s, (I.compare (I.- (a, b), zero) handle _ => EQUAL),
             fn () => I.compare (a, b));
      eqI ("IntInf.pow/cube" ^ s, fn () => I.* (a, I.* (a, a)), fn () => I.pow (a, 3));
      eqI ("IntInf.pow/sum-of-exponents" ^ s, fn () => I.* (I.pow (a, m), I.pow (a, n)),
           fn () => I.pow (a, m + n));
      eqI ("IntInf.pow/of-product" ^ s, fn () => I.* (I.pow (a, m), I.pow (b, m)), fn () => I.pow (I.* (a, b), m));
      eqI ("IntInf.fromString/toString" ^ s, fn () => a, fn () => valOf (I.fromString (I.toString a)))
    end)

  (*<< log2-laws *)
  (* pow (2, log2 i) <= i < pow (2, log2 i + 1) *)
  val () = T.seed 13
  val () = T.repeat (40, fn k =>
    let
      val s = "-" ^ Int.toString k
      val bits = true :: List.tabulate (T.range (0, 300), fn _ => T.range (0, 1) = 1)
      val a = natOfBits bits handle _ => one
    in
      eqN ("IntInf.log2/number-of-digits" ^ s, List.length bits - 1, fn () => I.log2 a);
      T.check ("IntInf.log2/bounds" ^ s,
               fn () => let val l = I.log2 a
                        in I.<= (I.pow (two, l), a) andalso I.< (a, I.pow (two, l + 1)) end)
    end)
  (*>> log2-laws *)

  (*<< bitops-laws *)
  (* the operations digit by digit, on the 2's complement digits of the samples *)
  val () = T.seed 14
  val () = T.repeat (40, fn k =>
    let
      val s = "-" ^ Int.toString k
      val (na, abits) = sample ()
      val (nb, bbits) = sample ()
      val width = Int.max (List.length abits, List.length bbits)
      fun extend (neg, bits) = List.tabulate (width - List.length bits, fn _ => neg) @ bits
      val (abits, bbits) = (extend (na, abits), extend (nb, bbits))
      val a = valueOf (na, abits) handle _ => zero
      val b = valueOf (nb, bbits) handle _ => zero
      fun model f = valueOf (f (na, nb), ListPair.map f (abits, bbits))
    in
      eqI ("IntInf.andb/model" ^ s, fn () => model (fn (x, y) => x andalso y), fn () => I.andb (a, b));
      eqI ("IntInf.orb/model" ^ s, fn () => model (fn (x, y) => x orelse y), fn () => I.orb (a, b));
      eqI ("IntInf.xorb/model" ^ s, fn () => model (fn (x, y) => x <> y), fn () => I.xorb (a, b));
      eqI ("IntInf.notb/model" ^ s, fn () => valueOf (not na, List.map not abits), fn () => I.notb a);
      eqI ("IntInf.notb/negation-minus-one" ^ s, fn () => I.- (I.~ a, one), fn () => I.notb a);
      eqI ("IntInf.notb/involution" ^ s, fn () => a, fn () => I.notb (I.notb a));
      eqI ("IntInf.andb/de-morgan" ^ s, fn () => I.notb (I.orb (I.notb a, I.notb b)), fn () => I.andb (a, b));
      eqI ("IntInf.orb/de-morgan" ^ s, fn () => I.notb (I.andb (I.notb a, I.notb b)), fn () => I.orb (a, b));
      eqI ("IntInf.xorb/orb-minus-andb" ^ s, fn () => I.- (I.orb (a, b), I.andb (a, b)), fn () => I.xorb (a, b));
      eqI ("IntInf.orb/andb-plus-orb" ^ s, fn () => I.+ (a, b), fn () => I.+ (I.andb (a, b), I.orb (a, b)));
      eqI ("IntInf.xorb/self" ^ s, fn () => zero, fn () => I.xorb (a, a));
      eqI ("IntInf.andb/commutative" ^ s, fn () => I.andb (b, a), fn () => I.andb (a, b))
    end)
  (*>> bitops-laws *)

  (*<< shifts-laws *)
  val () = T.seed 15
  val () = T.repeat (40, fn k =>
    let
      val s = "-" ^ Int.toString k
      val (na, abits) = sample ()
      val a = valueOf (na, abits) handle _ => zero
      val n = T.range (0, 320)
      val kept = Int.max (0, List.length abits - n)
    in
      eqI ("IntInf.<</model" ^ s, fn () => valueOf (na, abits @ List.tabulate (n, fn _ => false)),
           fn () => I.<< (a, Word.fromInt n));
      eqI ("IntInf.~>>/model" ^ s, fn () => valueOf (na, List.take (abits, kept)),
           fn () => I.~>> (a, Word.fromInt n));
      eqI ("IntInf.<</times-power" ^ s, fn () => I.* (a, I.pow (two, n)), fn () => I.<< (a, Word.fromInt n));
      eqI ("IntInf.~>>/floor-by-power" ^ s, fn () => I.div (a, I.pow (two, n)), fn () => I.~>> (a, Word.fromInt n));
      eqI ("IntInf.~>>/after-shift-left" ^ s, fn () => a, fn () => I.~>> (I.<< (a, Word.fromInt n), Word.fromInt n))
    end)
  (*>> shifts-laws *)
end
