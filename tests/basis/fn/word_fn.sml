(* Checks of a structure with signature WORD, for any word size.
   Expected values follow https://smlfamily.github.io/Basis/word.html.

     structure R = TestWordFn (structure W = Word8 val name = "Word8")

   needs fn/numstr.sml. The labels are name ^ ".member/case". Nothing is
   assumed about W.wordSize beyond its being at least 8, nor about the
   precision of Int.int; LargeInt.int is assumed to hold 2^(2 * wordSize + 1),
   which it does wherever it is IntInf.int. Words are built with W.fromInt from
   numbers between 0 and 255 and with W.+, from the binary digits that also
   give the expected values.

   TEST_WORD_CORE is WORD without toLarge, toLargeX, fromLarge and their
   synonyms, which need LargeWord (fn/word_large_fn.sml), and without fmt and
   scan, which need StringCvt (fn/word_scan_fn.sml). *)
signature TEST_WORD_CORE =
sig
  eqtype word
  val wordSize : int
  val toLargeInt : word -> LargeInt.int
  val toLargeIntX : word -> LargeInt.int
  val fromLargeInt : LargeInt.int -> word
  val toInt : word -> int
  val toIntX : word -> int
  val fromInt : int -> word
  val andb : word * word -> word
  val orb : word * word -> word
  val xorb : word * word -> word
  val notb : word -> word
  val << : word * Word.word -> word
  val >> : word * Word.word -> word
  val ~>> : word * Word.word -> word
  val + : word * word -> word
  val - : word * word -> word
  val * : word * word -> word
  val div : word * word -> word
  val mod : word * word -> word
  val compare : word * word -> order
  val < : word * word -> bool
  val <= : word * word -> bool
  val > : word * word -> bool
  val >= : word * word -> bool
  val ~ : word -> word
  val min : word * word -> word
  val max : word * word -> word
  val toString : word -> string
  val fromString : string -> word option
end

functor TestWordFn (structure W : TEST_WORD_CORE val name : string) =
struct
  structure L = LargeInt

  val ws = W.wordSize
  fun lab s = name ^ "." ^ s
  fun showW x = "0wx" ^ W.toString x handle _ => "?"
  fun showL x = L.toString x handle _ => "?"

  (* eqv: T.eq with the expected value in a thunk as well, so that an
     exception while computing it is a failed check. *)
  fun eqv show (label, expected, f) =
    case (SOME (expected ()) handle _ => NONE) of
      SOME e => T.eq show (label, e, f)
    | NONE => T.fail (label, "the expected value raised an exception")

  val eqW = eqv showW
  val eqWO = eqv (T.option showW)
  val eqL = eqv showL
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  val eqN = eqv T.int
  val eqOrd = T.eq T.order
  fun overflow (label, f) = T.raises (label, T.isOverflow, f)
  fun divide (label, f) = T.raises (label, T.isDiv, f)

  (* eqK: the result is W.fromInt k, for a k from 0 to 255. *)
  fun eqK (label, k, f) = eqW (label, fn () => W.fromInt k, f)

  val w = W.fromInt
  val zero = w 0
  val one = w 1
  val lzero = L.fromInt 0
  val lone = L.fromInt 1
  val ltwo = L.fromInt 2

  (* 2^k by doubling: in W.word (k < wordSize), LargeInt.int, Int.int and Word.word. *)
  fun pow2 k = if k <= 0 then one else let val h = pow2 (k - 1) in W.+ (h, h) end
  fun lpow2 k = if k <= 0 then lone else let val h = lpow2 (k - 1) in L.+ (h, h) end
  fun ipow2 k = if k <= 0 then 1 else let val h = ipow2 (k - 1) in h + h end
  fun amountPow2 k = if k <= 0 then Word.fromInt 1 else let val h = amountPow2 (k - 1) in Word.+ (h, h) end

  (* A word as its wordSize binary digits, most significant first. *)
  fun wordOfBits bits = List.foldl (fn (b, v) => W.+ (W.+ (v, v), if b then one else zero)) zero bits
  fun largeOfBits bits = List.foldl (fn (b, v) => L.+ (L.+ (v, v), if b then lone else lzero)) lzero bits
  fun intOfBits bits = List.foldl (fn (b, v) => v + v + (if b then 1 else 0)) 0 bits
  fun copies (n, b : bool) = List.tabulate (if n < 0 then 0 else n, fn _ => b)
  (* the digits of r, for 0 <= r < 2^wordSize *)
  fun bitsOfLarge r =
    let fun go (0, _, acc) = acc
          | go (k, r, acc) = go (k - 1, L.div (r, ltwo), (L.mod (r, ltwo) = lone) :: acc)
    in go (ws, r, []) end
  fun wordOfLarge r = wordOfBits (bitsOfLarge r)
  fun significant (true :: bits) = List.length bits + 1
    | significant (false :: bits) = significant bits
    | significant [] = 0

  val built = ref true
  fun build f = f () handle _ => (built := false; zero)
  val allOnes = build (fn () => wordOfBits (copies (ws, true)))       (* 2^wordSize - 1 *)
  val top = build (fn () => pow2 (ws - 1))                             (* 2^(wordSize-1) *)
  val belowTop = build (fn () => wordOfBits (false :: copies (ws - 1, true)))   (* 2^(wordSize-1) - 1 *)
  fun modulus () = lpow2 ws                                            (* 2^wordSize *)

  (* fitsInt k: the numbers below 2^k are values of Int.int. *)
  fun fitsInt k = case Int.precision of NONE => true | SOME p => k <= p - 1

  (* shift amounts *)
  val sh = Word.fromInt
  val hugeAmounts =
    [("wordSize", sh ws), ("wordSize-plus-one", sh (ws + 1)), ("twice-wordSize", sh (2 * ws)),
     ("four-times-wordSize", sh (4 * ws)), ("256", sh 256), ("1024", sh 1024),
     ("top-bit", amountPow2 (Word.wordSize - 1)), ("all-ones", Word.- (sh 0, sh 1))]

  (* ---- wordSize ---- *)
  val () = T.check (lab "wordSize/at-least-8", fn () => ws >= 8)
  val () = T.check (lab "wordSize/top-bit-is-not-zero", fn () => pow2 (ws - 1) <> zero)
  val () = eqK (lab "wordSize/two-to-the-wordSize-is-zero", 0, fn () => pow2 ws)
  val () = T.check (lab "wordSize/all-ones-is-not-zero", fn () => allOnes <> zero)

  (* ---- conversions ---- *)
  val () = eqN (lab "toInt/zero", fn () => 0, fn () => W.toInt zero)
  val () = eqN (lab "toInt/200", fn () => 200, fn () => W.toInt (w 200))
  val () = eqN (lab "toInt/sum", fn () => 255, fn () => W.toInt (W.+ (w 200, w 55)))
  val () = eqN (lab "toIntX/zero", fn () => 0, fn () => W.toIntX zero)
  val () = eqN (lab "toIntX/100", fn () => 100, fn () => W.toIntX (w 100))
  val () = eqN (lab "toIntX/all-ones", fn () => ~1, fn () => W.toIntX allOnes)
  val () = eqN (lab "toIntX/all-ones-but-one", fn () => ~2, fn () => W.toIntX (W.- (allOnes, one)))
  val () = eqN (lab "toIntX/fromInt-negative", fn () => ~100, fn () => W.toIntX (w ~100))
  val () = T.check (lab "fromInt/distinct", fn () => w 0 <> w 1 andalso w 1 <> w 2 andalso w 255 <> w 0)
  val () = eqW (lab "fromInt/minus-one", fn () => allOnes, fn () => w ~1)
  val () = eqW (lab "fromInt/minus-two", fn () => W.- (allOnes, one), fn () => w ~2)
  val () = eqW (lab "fromInt/minus-128", fn () => wordOfBits (copies (ws - 7, true) @ copies (7, false)),
                fn () => w ~128)
  val () = eqK (lab "fromInt/round-trip", 255, fn () => w (W.toInt (w 255)))
  (* "They raise Overflow if the target integer value cannot be represented as an Int.int." *)
  val () =
    if fitsInt ws then
      (eqN (lab "toInt/all-ones", fn () => ipow2 (ws - 1) - 1 + ipow2 (ws - 1), fn () => W.toInt allOnes);
       eqN (lab "toInt/top-bit", fn () => ipow2 (ws - 1), fn () => W.toInt top))
    else
      (overflow (lab "toInt/Overflow-all-ones", fn () => W.toInt allOnes);
       overflow (lab "toInt/Overflow-top-bit", fn () => W.toInt top))
  val () =
    if fitsInt (ws - 1) then
      (eqN (lab "toInt/below-top-bit", fn () => ipow2 (ws - 2) - 1 + ipow2 (ws - 2), fn () => W.toInt belowTop);
       eqN (lab "toIntX/below-top-bit", fn () => ipow2 (ws - 2) - 1 + ipow2 (ws - 2), fn () => W.toIntX belowTop);
       eqN (lab "toIntX/top-bit", fn () => ~ (ipow2 (ws - 2)) - ipow2 (ws - 2), fn () => W.toIntX top))
    else
      (overflow (lab "toInt/Overflow-below-top-bit", fn () => W.toInt belowTop);
       overflow (lab "toIntX/Overflow-below-top-bit", fn () => W.toIntX belowTop);
       overflow (lab "toIntX/Overflow-top-bit", fn () => W.toIntX top))
  (* "the low-order wordSize bits of the 2's complement representation of i.
     If the precision of Int.int is less than wordSize, then i is sign-extended" *)
  val () =
    case (Int.maxInt, Int.minInt, Int.precision) of
      (SOME hi, SOME lo, SOME p) =>
        (* 2^(p-1) - 1 is p - 1 ones; -2^(p-1) is ones from bit p - 1 upwards *)
        (eqW (lab "fromInt/Int.maxInt",
              fn () => wordOfBits (copies (ws - (p - 1), false) @ copies (Int.min (p - 1, ws), true)),
              fn () => w hi);
         eqW (lab "fromInt/Int.minInt",
              fn () => wordOfBits (copies (ws - (p - 1), true) @ copies (Int.min (p - 1, ws), false)),
              fn () => w lo))
    | _ => ()

  val () = eqL (lab "toLargeInt/zero", fn () => lzero, fn () => W.toLargeInt zero)
  val () = eqL (lab "toLargeInt/200", fn () => L.fromInt 200, fn () => W.toLargeInt (w 200))
  val () = eqL (lab "toLargeInt/all-ones", fn () => L.- (modulus (), lone), fn () => W.toLargeInt allOnes)
  val () = eqL (lab "toLargeInt/top-bit", fn () => lpow2 (ws - 1), fn () => W.toLargeInt top)
  val () = eqL (lab "toLargeIntX/zero", fn () => lzero, fn () => W.toLargeIntX zero)
  val () = eqL (lab "toLargeIntX/100", fn () => L.fromInt 100, fn () => W.toLargeIntX (w 100))
  val () = eqL (lab "toLargeIntX/all-ones", fn () => L.fromInt ~1, fn () => W.toLargeIntX allOnes)
  val () = eqL (lab "toLargeIntX/top-bit", fn () => L.~ (lpow2 (ws - 1)), fn () => W.toLargeIntX top)
  val () = eqL (lab "toLargeIntX/below-top-bit", fn () => L.- (lpow2 (ws - 1), lone), fn () => W.toLargeIntX belowTop)
  val () = eqK (lab "fromLargeInt/zero", 0, fn () => W.fromLargeInt lzero)
  val () = eqK (lab "fromLargeInt/200", 200, fn () => W.fromLargeInt (L.fromInt 200))
  val () = eqW (lab "fromLargeInt/minus-one", fn () => allOnes, fn () => W.fromLargeInt (L.fromInt ~1))
  val () = eqW (lab "fromLargeInt/minus-three", fn () => W.- (allOnes, w 2), fn () => W.fromLargeInt (L.fromInt ~3))
  val () = eqW (lab "fromLargeInt/all-ones", fn () => allOnes, fn () => W.fromLargeInt (L.- (modulus (), lone)))
  val () = eqK (lab "fromLargeInt/two-to-the-wordSize", 0, fn () => W.fromLargeInt (modulus ()))
  val () = eqK (lab "fromLargeInt/two-to-the-wordSize-plus-five", 5,
                fn () => W.fromLargeInt (L.+ (modulus (), L.fromInt 5)))
  val () = eqW (lab "fromLargeInt/minus-two-to-the-wordSize-minus-three", fn () => W.- (allOnes, w 2),
                fn () => W.fromLargeInt (L.- (L.~ (modulus ()), L.fromInt 3)))
  val () = eqK (lab "fromLargeInt/two-to-twice-the-wordSize-plus-seven", 7,
                fn () => W.fromLargeInt (L.+ (L.* (modulus (), modulus ()), L.fromInt 7)))
  val () = eqW (lab "fromLargeInt/minus-two-to-twice-the-wordSize-minus-one", fn () => allOnes,
                fn () => W.fromLargeInt (L.- (L.~ (L.* (modulus (), modulus ())), lone)))
  val () = eqW (lab "fromLargeInt/minus-top-bit", fn () => top, fn () => W.fromLargeInt (L.~ (lpow2 (ws - 1))))

  (* ---- bit-wise operations ---- *)
  fun table (member, f) cases =
    List.app (fn (c, a, b, r) => eqK (lab (member ^ "/" ^ c), r, fn () => f (w a, w b))) cases
  val () = table ("andb", W.andb)
    [("1100-1010", 12, 10, 8), ("11110000-00111100", 240, 60, 48), ("zero", 171, 0, 0),
     ("self", 171, 171, 171), ("disjoint", 170, 85, 0)]
  val () = table ("orb", W.orb)
    [("1100-1010", 12, 10, 14), ("11110000-00111100", 240, 60, 252), ("zero", 171, 0, 171),
     ("self", 171, 171, 171), ("disjoint", 170, 85, 255)]
  val () = table ("xorb", W.xorb)
    [("1100-1010", 12, 10, 6), ("11110000-00111100", 240, 60, 204), ("zero", 171, 0, 171),
     ("self", 171, 171, 0), ("disjoint", 170, 85, 255)]
  val () = eqK (lab "andb/all-ones", 171, fn () => W.andb (allOnes, w 171))
  val () = eqW (lab "orb/all-ones", fn () => allOnes, fn () => W.orb (allOnes, w 171))
  val () = eqW (lab "orb/top-bit", fn () => allOnes, fn () => W.orb (top, belowTop))
  val () = eqK (lab "andb/top-bit", 0, fn () => W.andb (top, belowTop))
  val () = eqW (lab "xorb/top-bit", fn () => belowTop, fn () => W.xorb (top, allOnes))
  val () = eqW (lab "notb/zero", fn () => allOnes, fn () => W.notb zero)
  val () = eqK (lab "notb/all-ones", 0, fn () => W.notb allOnes)
  val () = eqW (lab "notb/top-bit", fn () => belowTop, fn () => W.notb top)
  val () = eqW (lab "notb/ten", fn () => W.- (allOnes, w 10), fn () => W.notb (w 10))

  (* ---- shifts ---- *)
  val () = List.app (fn (c, a, n, r) => eqK (lab ("<</" ^ c), r, fn () => W.<< (w a, sh n)))
    [("by-zero", 171, 0, 171), ("one-by-three", 1, 3, 8), ("five-by-two", 5, 2, 20),
     ("zero", 0, 5, 0), ("by-one", 100, 1, 200)]
  val () = eqW (lab "<</one-to-top-bit", fn () => top, fn () => W.<< (one, sh (ws - 1)))
  val () = eqW (lab "<</three-to-top-bit", fn () => top, fn () => W.<< (w 3, sh (ws - 1)))
  val () = eqW (lab "<</all-ones-to-top-bit", fn () => top, fn () => W.<< (allOnes, sh (ws - 1)))
  val () = eqW (lab "<</all-ones-by-one", fn () => W.- (allOnes, one), fn () => W.<< (allOnes, sh 1))
  val () = eqW (lab "<</top-bit-by-one", fn () => zero, fn () => W.<< (top, sh 1))
  val () = List.app (fn (c, a, n, r) => eqK (lab (">>/" ^ c), r, fn () => W.>> (w a, sh n)))
    [("by-zero", 171, 0, 171), ("eight-by-three", 8, 3, 1), ("twenty-by-two", 20, 2, 5),
     ("seven-by-one", 7, 1, 3), ("one-by-one", 1, 1, 0), ("zero", 0, 5, 0), ("255-by-four", 255, 4, 15)]
  val () = eqK (lab ">>/top-bit-to-one", 1, fn () => W.>> (top, sh (ws - 1)))
  val () = eqK (lab ">>/all-ones-to-one", 1, fn () => W.>> (allOnes, sh (ws - 1)))
  val () = eqW (lab ">>/all-ones-by-one", fn () => belowTop, fn () => W.>> (allOnes, sh 1))
  val () = eqW (lab ">>/all-ones-by-zero", fn () => allOnes, fn () => W.>> (allOnes, sh 0))
  val () = eqK (lab ">>/below-top-bit", 0, fn () => W.>> (belowTop, sh (ws - 1)))
  val () = List.app (fn (c, a, n, r) => eqK (lab ("~>>/" ^ c), r, fn () => W.~>> (w a, sh n)))
    [("by-zero", 100, 0, 100), ("eight-by-three", 8, 3, 1), ("twenty-by-two", 20, 2, 5),
     ("seven-by-one", 7, 1, 3), ("one-by-one", 1, 1, 0), ("zero", 0, 5, 0)]
  (* the leftmost bit stays: floor (i / 2^n) of the 2's-complement number *)
  val () = eqW (lab "~>>/top-bit-to-all-ones", fn () => allOnes, fn () => W.~>> (top, sh (ws - 1)))
  val () = eqW (lab "~>>/top-bit-by-one", fn () => W.+ (top, pow2 (ws - 2)), fn () => W.~>> (top, sh 1))
  val () = eqW (lab "~>>/all-ones-by-one", fn () => allOnes, fn () => W.~>> (allOnes, sh 1))
  val () = eqW (lab "~>>/all-ones-by-zero", fn () => allOnes, fn () => W.~>> (allOnes, sh 0))
  val () = eqW (lab "~>>/minus-two-by-one", fn () => allOnes, fn () => W.~>> (W.- (allOnes, one), sh 1))
  val () = eqW (lab "~>>/minus-three-by-one", fn () => W.- (allOnes, one), fn () => W.~>> (W.- (allOnes, w 2), sh 1))
  (* floor (-100 / 8) = -13 *)
  val () = eqW (lab "~>>/minus-100-by-three", fn () => W.- (zero, w 13), fn () => W.~>> (W.- (zero, w 100), sh 3))
  val () = eqK (lab "~>>/below-top-bit-to-one", 1, fn () => W.~>> (belowTop, sh (ws - 2)))
  val () = eqK (lab "~>>/below-top-bit-to-zero", 0, fn () => W.~>> (belowTop, sh (ws - 1)))
  (* "shifting by greater than or equal to wordSize results in 0", and for
     ~>> "in either 0 or all 1's" *)
  val () = List.app (fn (c, n) =>
             (eqK (lab ("<</by-" ^ c), 0, fn () => W.<< (allOnes, n));
              eqK (lab ("<</one-by-" ^ c), 0, fn () => W.<< (one, n));
              eqK (lab (">>/by-" ^ c), 0, fn () => W.>> (allOnes, n));
              eqK (lab (">>/top-bit-by-" ^ c), 0, fn () => W.>> (top, n));
              eqW (lab ("~>>/negative-by-" ^ c), fn () => allOnes, fn () => W.~>> (top, n));
              eqW (lab ("~>>/all-ones-by-" ^ c), fn () => allOnes, fn () => W.~>> (allOnes, n));
              eqK (lab ("~>>/non-negative-by-" ^ c), 0, fn () => W.~>> (belowTop, n));
              eqK (lab ("~>>/one-by-" ^ c), 0, fn () => W.~>> (one, n))))
             hugeAmounts

  (* ---- arithmetic modulo 2^wordSize ---- *)
  val () = table ("+", fn p => W.+ p) [("basic", 2, 3, 5), ("zero", 0, 0, 0), ("identity", 200, 0, 200), ("255", 200, 55, 255)]
  val () = eqK (lab "+/all-ones-plus-one", 0, fn () => W.+ (allOnes, one))
  val () = eqK (lab "+/one-plus-all-ones", 0, fn () => W.+ (one, allOnes))
  val () = eqW (lab "+/all-ones-twice", fn () => W.- (allOnes, one), fn () => W.+ (allOnes, allOnes))
  val () = eqK (lab "+/top-bit-twice", 0, fn () => W.+ (top, top))
  val () = eqW (lab "+/below-top-bit-plus-one", fn () => top, fn () => W.+ (belowTop, one))
  val () = table ("-", fn p => W.- p) [("basic", 5, 3, 2), ("zero", 0, 0, 0), ("identity", 200, 0, 200), ("self", 200, 200, 0)]
  val () = eqW (lab "-/zero-minus-one", fn () => allOnes, fn () => W.- (zero, one))
  val () = eqW (lab "-/three-minus-five", fn () => W.notb one, fn () => W.- (w 3, w 5))
  val () = eqW (lab "-/top-bit-minus-one", fn () => belowTop, fn () => W.- (top, one))
  val () = eqK (lab "-/zero-minus-all-ones", 1, fn () => W.- (zero, allOnes))
  val () = eqW (lab "-/below-top-bit-minus-all-ones", fn () => top, fn () => W.- (belowTop, allOnes))
  val () = table ("*", fn p => W.* p) [("basic", 6, 7, 42), ("zero", 200, 0, 0), ("identity", 1, 200, 200), ("156", 12, 13, 156)]
  val () = eqK (lab "*/all-ones-squared", 1, fn () => W.* (allOnes, allOnes))
  val () = eqW (lab "*/all-ones-times-two", fn () => W.- (allOnes, one), fn () => W.* (allOnes, w 2))
  val () = eqK (lab "*/top-bit-times-two", 0, fn () => W.* (top, w 2))
  val () = eqW (lab "*/top-bit-times-three", fn () => top, fn () => W.* (top, w 3))
  val () = eqK (lab "*/top-bit-squared", 0, fn () => W.* (top, top))
  val () = eqW (lab "*/all-ones-times-five", fn () => W.- (allOnes, w 4), fn () => W.* (allOnes, w 5))
  (* unsigned division *)
  val () = table ("div", W.div)
    [("basic", 7, 2, 3), ("200-7", 200, 7, 28), ("zero-dividend", 0, 5, 0), ("small-by-large", 5, 7, 0),
     ("by-one", 200, 1, 200), ("self", 200, 200, 1), ("exact", 255, 5, 51)]
  val () = table ("mod", W.mod)
    [("basic", 7, 2, 1), ("200-7", 200, 7, 4), ("zero-dividend", 0, 5, 0), ("small-by-large", 5, 7, 5),
     ("by-one", 200, 1, 0), ("self", 200, 200, 0), ("exact", 255, 5, 0)]
  val () = eqW (lab "div/all-ones-by-one", fn () => allOnes, fn () => W.div (allOnes, one))
  val () = eqK (lab "div/all-ones-by-all-ones", 1, fn () => W.div (allOnes, allOnes))
  val () = eqW (lab "div/all-ones-by-two", fn () => belowTop, fn () => W.div (allOnes, w 2))
  val () = eqK (lab "div/one-by-all-ones", 0, fn () => W.div (one, allOnes))
  val () = eqK (lab "div/top-bit-by-all-ones", 0, fn () => W.div (top, allOnes))
  val () = eqK (lab "div/all-ones-by-top-bit", 1, fn () => W.div (allOnes, top))
  val () = eqW (lab "div/top-bit-by-two", fn () => pow2 (ws - 2), fn () => W.div (top, w 2))
  val () = eqK (lab "mod/all-ones-by-two", 1, fn () => W.mod (allOnes, w 2))
  val () = eqW (lab "mod/all-ones-by-top-bit", fn () => belowTop, fn () => W.mod (allOnes, top))
  val () = eqW (lab "mod/top-bit-by-all-ones", fn () => top, fn () => W.mod (top, allOnes))
  val () = eqK (lab "mod/all-ones-by-all-ones", 0, fn () => W.mod (allOnes, allOnes))
  val () = eqK (lab "mod/one-by-all-ones", 1, fn () => W.mod (one, allOnes))
  val () = divide (lab "div/Div", fn () => W.div (w 5, zero))
  val () = divide (lab "div/Div-zero-by-zero", fn () => W.div (zero, zero))
  val () = divide (lab "div/Div-all-ones", fn () => W.div (allOnes, zero))
  val () = divide (lab "mod/Div", fn () => W.mod (w 5, zero))
  val () = divide (lab "mod/Div-zero-by-zero", fn () => W.mod (zero, zero))
  val () = divide (lab "mod/Div-all-ones", fn () => W.mod (allOnes, zero))

  (* ---- order: as unsigned numbers ---- *)
  val orderCases =
    [("less", fn () => (w 1, w 2), LESS), ("equal", fn () => (w 2, w 2), EQUAL),
     ("greater", fn () => (w 2, w 1), GREATER), ("zero-zero", fn () => (zero, zero), EQUAL),
     ("all-ones-zero", fn () => (allOnes, zero), GREATER), ("zero-all-ones", fn () => (zero, allOnes), LESS),
     ("all-ones-one", fn () => (allOnes, one), GREATER), ("one-all-ones", fn () => (one, allOnes), LESS),
     ("top-bit-and-below", fn () => (top, belowTop), GREATER), ("below-and-top-bit", fn () => (belowTop, top), LESS),
     ("all-ones-top-bit", fn () => (allOnes, top), GREATER), ("all-ones-all-ones", fn () => (allOnes, allOnes), EQUAL),
     ("minus-one-one", fn () => (w ~1, w 1), GREATER)]
  val () = List.app (fn (c, p, r) => eqOrd (lab ("compare/" ^ c), r, fn () => W.compare (p ()))) orderCases
  val () = List.app (fn (c, p, r) => eqB (lab ("</" ^ c), r = LESS, fn () => W.< (p ()))) orderCases
  val () = List.app (fn (c, p, r) => eqB (lab ("<=/" ^ c), r <> GREATER, fn () => W.<= (p ()))) orderCases
  val () = List.app (fn (c, p, r) => eqB (lab (">/" ^ c), r = GREATER, fn () => W.> (p ()))) orderCases
  val () = List.app (fn (c, p, r) => eqB (lab (">=/" ^ c), r <> LESS, fn () => W.>= (p ()))) orderCases
  val () = List.app (fn (c, p, r) =>
             eqW (lab ("min/" ^ c), fn () => let val (a, b) = p () in if r = GREATER then b else a end,
                  fn () => W.min (p ()))) orderCases
  val () = List.app (fn (c, p, r) =>
             eqW (lab ("max/" ^ c), fn () => let val (a, b) = p () in if r = GREATER then a else b end,
                  fn () => W.max (p ()))) orderCases

  (* ---- ~: the 2's complement ---- *)
  val () = eqK (lab "~/zero", 0, fn () => W.~ zero)
  val () = eqW (lab "~/one", fn () => allOnes, fn () => W.~ one)
  val () = eqK (lab "~/all-ones", 1, fn () => W.~ allOnes)
  val () = eqW (lab "~/top-bit", fn () => top, fn () => W.~ top)
  val () = eqW (lab "~/five", fn () => W.- (allOnes, w 4), fn () => W.~ (w 5))
  val () = eqW (lab "~/fromInt-negative", fn () => w ~100, fn () => W.~ (w 100))

  (* ---- toString: hexadecimal, digits A to F, no prefix ---- *)
  val () = List.app (fn (c, k, s) => eqS (lab ("toString/" ^ c), s, fn () => W.toString (w k)))
    [("zero", 0, "0"), ("one", 1, "1"), ("nine", 9, "9"), ("ten", 10, "A"), ("eleven", 11, "B"),
     ("twelve", 12, "C"), ("thirteen", 13, "D"), ("fourteen", 14, "E"), ("fifteen", 15, "F"),
     ("sixteen", 16, "10"), ("171", 171, "AB"), ("205", 205, "CD"), ("239", 239, "EF"), ("255", 255, "FF"),
     ("160", 160, "A0")]
  val () = eqS (lab "toString/all-ones", NumStr.pow2Minus1String 16 ws, fn () => W.toString allOnes)
  val () = eqS (lab "toString/top-bit", NumStr.pow2String 16 (ws - 1), fn () => W.toString top)
  val () = eqS (lab "toString/below-top-bit", NumStr.pow2Minus1String 16 (ws - 1), fn () => W.toString belowTop)

  (* ---- fromString: (0wx | 0wX | 0x | 0X)?[0-9a-fA-F]+ at the start, after whitespace ---- *)
  val () = List.app (fn (c, s, r) =>
             eqWO (lab ("fromString/" ^ c), fn () => Option.map w r, fn () => W.fromString s))
    [("lower", "ff", SOME 255), ("upper", "FF", SOME 255), ("mixed", "aB", SOME 171),
     ("decimal-digits", "10", SOME 16), ("zero", "0", SOME 0), ("leading-zeros", "00ff", SOME 255),
     ("prefix-0wx", "0wxff", SOME 255), ("prefix-0wX", "0wXff", SOME 255),
     ("prefix-0x", "0xff", SOME 255), ("prefix-0X", "0Xff", SOME 255), ("prefix-then-zero", "0wx0", SOME 0),
     ("whitespace-spaces", "  ff", SOME 255), ("whitespace-all-six", " \t\n\v\f\rff", SOME 255),
     ("whitespace-tab", "\tff", SOME 255), ("whitespace-newline", "\nff", SOME 255),
     ("whitespace-vertical-tab", "\vff", SOME 255), ("whitespace-form-feed", "\fff", SOME 255),
     ("whitespace-return", "\rff", SOME 255), ("whitespace-then-prefix", " 0wxff", SOME 255),
     ("stops-at-g", "ffg", SOME 255), ("stops-at-space", "f f", SOME 15), ("stops-at-x", "1x2", SOME 1),
     ("stops-at-tilde", "1~2", SOME 1),
     (* 0w is a prefix of the other radices only, so the number is the 0.
        (SML/NJ 110.79 and Poly/ML 5.7.1 read 0w12 as 0wx12; the format of
        the specification, (0wx | 0wX | 0x | 0X)?[0-9a-fA-F]+, does not.) *)
     ("0w-is-no-prefix", "0w12", SOME 0),
     (* a prefix without digits after it is not part of the number, but its 0 is one *)
     ("bare-prefix-0wx-then-non-digit", "0wxg", SOME 0), ("bare-prefix-0wx", "0wx", SOME 0),
     ("bare-prefix-0x", "0x", SOME 0), ("bare-prefix-0x-then-space", "0x 12", SOME 0),
     ("prefix-twice", "0x0wx1", SOME 0),
     ("empty", "", NONE), ("only-whitespace", "  ", NONE), ("letter", "g", NONE),
     ("tilde", "~1", NONE), ("minus", "-1", NONE), ("plus", "+1", NONE),
     ("x-first", "x1", NONE), ("w-first", "wx1", NONE), ("hash", "#1", NONE)]
  val () =
    let
      val onesText = NumStr.pow2Minus1String 16 ws
      val above = NumStr.pow2String 16 ws          (* 2^wordSize *)
    in
      eqWO (lab "fromString/all-ones", fn () => SOME allOnes, fn () => W.fromString onesText);
      eqWO (lab "fromString/all-ones-lower-case", fn () => SOME allOnes, fn () => W.fromString (NumStr.lower onesText));
      eqWO (lab "fromString/all-ones-with-prefix", fn () => SOME allOnes, fn () => W.fromString ("0wx" ^ onesText));
      eqWO (lab "fromString/all-ones-with-leading-zeros", fn () => SOME allOnes,
            fn () => W.fromString ("0000000000000000000000000000000000000000" ^ onesText));
      eqWO (lab "fromString/top-bit", fn () => SOME top, fn () => W.fromString (NumStr.pow2String 16 (ws - 1)));
      (* "raises Overflow when a hexadecimal numeral can be parsed, but is too large" *)
      overflow (lab "fromString/Overflow-two-to-the-wordSize", fn () => W.fromString above);
      overflow (lab "fromString/Overflow-with-prefix", fn () => W.fromString ("0wx" ^ above));
      overflow (lab "fromString/Overflow-two-to-the-wordSize-plus-one",
                fn () => W.fromString (NumStr.toString (NumStr.succ 16 (NumStr.pow2 16 ws))));
      overflow (lab "fromString/Overflow-one-more-digit", fn () => W.fromString (onesText ^ "0"));
      overflow (lab "fromString/Overflow-after-whitespace", fn () => W.fromString ("  " ^ onesText ^ "F "));
      overflow (lab "fromString/Overflow-many-digits",
                fn () => W.fromString (onesText ^ onesText ^ onesText ^ onesText))
    end

  (* ---- models and laws, on pseudo-random words ----
     A sample is wordSize pseudo-random binary digits; the word is built from
     them by doubling, and so are its value as a LargeInt.int and the expected
     results of the bit-wise operations and shifts. *)
  fun sampleBits () =
    let val k = if T.range (0, 2) = 0 then ws else T.range (0, ws)
    in copies (ws - k, false) @ List.tabulate (k, fn _ => T.range (0, 1) = 1) end
  fun take (l, n) = List.take (l, n)
  fun drop (l, n) = List.drop (l, n)
  fun zipWith f (a, b) = ListPair.map f (a, b)

  val () = T.seed 7
  val () = T.repeat (40, fn k =>
    let
      val s = "-" ^ Int.toString k
      val abits = sampleBits ()
      val bbits = sampleBits ()
      val a = build (fn () => wordOfBits abits)
      val b = build (fn () => wordOfBits bbits)
      fun al () = largeOfBits abits
      fun bl () = largeOfBits bbits
      val d = if b = zero then one else b                     (* a divisor *)
      fun dl () = if b = zero then lone else bl ()
      val n = T.range (0, ws + 2)
      val m = Int.min (n, ws)
      val negative = List.hd abits
      val notA = List.map not abits
      val hex = NumStr.toString (NumStr.fromBits 16 abits)
      val j = (if T.range (0, 1) = 0 then 1 else ~1) * T.range (0, 1000000000)
      val j8 = T.range (~128, 127)
      fun modular r = wordOfLarge (L.mod (r, modulus ()))
    in
      (* conversions *)
      eqL (lab "toLargeInt/model" ^ s, al, fn () => W.toLargeInt a);
      eqL (lab "toLargeIntX/model" ^ s, fn () => if negative then L.- (al (), modulus ()) else al (),
           fn () => W.toLargeIntX a);
      eqW (lab "fromLargeInt/model" ^ s, fn () => a, fn () => W.fromLargeInt (al ()));
      eqW (lab "fromLargeInt/plus-multiple" ^ s, fn () => a,
           fn () => W.fromLargeInt (L.+ (al (), L.* (L.fromInt (k + 1), modulus ()))));
      eqW (lab "fromLargeInt/minus-multiple" ^ s, fn () => a,
           fn () => W.fromLargeInt (L.- (al (), L.* (L.fromInt (k + 1), modulus ()))));
      eqW (lab "fromLargeInt/signed" ^ s, fn () => a,
           fn () => W.fromLargeInt (if negative then L.- (al (), modulus ()) else al ()));
      (if fitsInt (significant abits)
       then eqN (lab "toInt/model" ^ s, fn () => intOfBits abits, fn () => W.toInt a)
       else overflow (lab "toInt/model" ^ s, fn () => W.toInt a));
      (if negative then
         (if fitsInt (significant notA)
          then eqN (lab "toIntX/model" ^ s, fn () => ~ (intOfBits notA) - 1, fn () => W.toIntX a)
          else overflow (lab "toIntX/model" ^ s, fn () => W.toIntX a))
       else
         (if fitsInt (significant abits)
          then eqN (lab "toIntX/model" ^ s, fn () => intOfBits abits, fn () => W.toIntX a)
          else overflow (lab "toIntX/model" ^ s, fn () => W.toIntX a)));
      eqW (lab "fromInt/model" ^ s, fn () => modular (Int.toLarge j), fn () => W.fromInt j);
      eqN (lab "toIntX/fromInt" ^ s, fn () => j8, fn () => W.toIntX (W.fromInt j8));

      (* bit-wise operations and shifts, digit by digit *)
      eqW (lab "andb/model" ^ s, fn () => wordOfBits (zipWith (fn (x, y) => x andalso y) (abits, bbits)),
           fn () => W.andb (a, b));
      eqW (lab "orb/model" ^ s, fn () => wordOfBits (zipWith (fn (x, y) => x orelse y) (abits, bbits)),
           fn () => W.orb (a, b));
      eqW (lab "xorb/model" ^ s, fn () => wordOfBits (zipWith (fn (x, y) => x <> y) (abits, bbits)),
           fn () => W.xorb (a, b));
      eqW (lab "notb/model" ^ s, fn () => wordOfBits notA, fn () => W.notb a);
      eqW (lab "<</model" ^ s, fn () => wordOfBits (drop (abits, m) @ copies (m, false)),
           fn () => W.<< (a, sh n));
      eqW (lab ">>/model" ^ s, fn () => wordOfBits (copies (m, false) @ take (abits, ws - m)),
           fn () => W.>> (a, sh n));
      eqW (lab "~>>/model" ^ s, fn () => wordOfBits (copies (m, negative) @ take (abits, ws - m)),
           fn () => W.~>> (a, sh n));
      (* the same as arithmetic: (i * 2^n) mod 2^wordSize and floor (i / 2^n) *)
      eqW (lab "<</times-power" ^ s, fn () => modular (L.* (al (), lpow2 n)), fn () => W.<< (a, sh n));
      eqW (lab ">>/by-power" ^ s, fn () => modular (L.div (al (), lpow2 n)), fn () => W.>> (a, sh n));
      eqW (lab "~>>/floor-by-power" ^ s,
           fn () => modular (L.div (if negative then L.- (al (), modulus ()) else al (), lpow2 n)),
           fn () => W.~>> (a, sh n));

      (* arithmetic *)
      eqW (lab "+/model" ^ s, fn () => modular (L.+ (al (), bl ())), fn () => W.+ (a, b));
      eqW (lab "-/model" ^ s, fn () => modular (L.- (L.+ (modulus (), al ()), bl ())), fn () => W.- (a, b));
      eqW (lab "*/model" ^ s, fn () => modular (L.* (al (), bl ())), fn () => W.* (a, b));
      eqW (lab "div/model" ^ s, fn () => modular (L.div (al (), dl ())), fn () => W.div (a, d));
      eqW (lab "mod/model" ^ s, fn () => modular (L.- (al (), L.* (dl (), L.div (al (), dl ())))),
           fn () => W.mod (a, d));
      eqW (lab "~/model" ^ s, fn () => modular (L.- (modulus (), al ())), fn () => W.~ a);
      eqW (lab "div/law" ^ s, fn () => a, fn () => W.+ (W.* (W.div (a, d), d), W.mod (a, d)));
      eqB (lab "mod/less-than-divisor" ^ s, true, fn () => W.< (W.mod (a, d), d));

      (* order *)
      eqOrd (lab "compare/model" ^ s, (L.compare (al (), bl ()) handle _ => EQUAL), fn () => W.compare (a, b));
      eqOrd (lab "compare/reflexive" ^ s, EQUAL, fn () => W.compare (a, a));
      eqv T.bool (lab "</model" ^ s, fn () => L.< (al (), bl ()), fn () => W.< (a, b));
      eqv T.bool (lab "<=/model" ^ s, fn () => L.<= (al (), bl ()), fn () => W.<= (a, b));
      eqv T.bool (lab ">/model" ^ s, fn () => L.> (al (), bl ()), fn () => W.> (a, b));
      eqv T.bool (lab ">=/model" ^ s, fn () => L.>= (al (), bl ()), fn () => W.>= (a, b));
      eqW (lab "min/model" ^ s, fn () => if L.> (al (), bl ()) then b else a, fn () => W.min (a, b));
      eqW (lab "max/model" ^ s, fn () => if L.> (al (), bl ()) then a else b, fn () => W.max (a, b));

      (* text *)
      eqS (lab "toString/model" ^ s, hex, fn () => W.toString a);
      eqWO (lab "fromString/model" ^ s, fn () => SOME a, fn () => W.fromString hex);
      eqWO (lab "fromString/model-lower-case-with-prefix" ^ s, fn () => SOME a,
            fn () => W.fromString ("0wx" ^ NumStr.lower hex ^ "!"));
      eqWO (lab "fromString/round-trip" ^ s, fn () => SOME b, fn () => W.fromString (W.toString b));

      (* laws *)
      eqW (lab "notb/plus-self-is-all-ones" ^ s, fn () => allOnes, fn () => W.+ (a, W.notb a));
      eqW (lab "~/notb-plus-one" ^ s, fn () => W.+ (W.notb a, one), fn () => W.~ a);
      eqW (lab "-/plus-complement" ^ s, fn () => W.+ (a, W.~ b), fn () => W.- (a, b));
      eqW (lab "andb/de-morgan" ^ s, fn () => W.notb (W.orb (W.notb a, W.notb b)), fn () => W.andb (a, b));
      eqW (lab "orb/de-morgan" ^ s, fn () => W.notb (W.andb (W.notb a, W.notb b)), fn () => W.orb (a, b));
      eqW (lab "xorb/orb-minus-andb" ^ s, fn () => W.- (W.orb (a, b), W.andb (a, b)), fn () => W.xorb (a, b));
      eqW (lab "+/andb-plus-orb" ^ s, fn () => W.+ (W.andb (a, b), W.orb (a, b)), fn () => W.+ (a, b))
    end)
  val () = T.check (lab "fromInt/samples-built", fn () => !built)
end
