(* The core of lib/test/property (docs/plans/quickcheck.md, M4): what the
   generators draw, that a seed draws the same everywhere, that a node set by
   the shrinker changes its part alone, and that properties find planted
   bugs. One line PASS or FAIL for each, and a fingerprint of what a seed
   draws, which tests/lib/run-lib-tests.sh and run-hosts.sh compare with
   fingerprint.expected. *)
val failed = ref 0
fun check (name, holds) =
  if holds () handle _ => false then print ("PASS " ^ name ^ "\n")
  else (print ("FAIL " ^ name ^ "\n"); failed := !failed + 1)

fun samples (g, n, size) = List.tabulate (n, fn k => Gen.sample g (Word64.fromInt k) size)
fun count p l = List.length (List.filter p l)

(* ---- what the generators draw (the generator principles) ---- *)
(* no Int.abs: minInt is one of the edges, and its absolute value overflows *)
val ints = samples (Gen.int, 6000, 50)
val bound = case Int.maxInt of SOME m => m | NONE => valOf (Int.fromString "9223372036854775807")
val () = check ("int/small-third", fn () => count (fn x => ~50 <= x andalso x <= 50) ints > 1600)
val () = check ("int/large-values", fn () => count (fn x => x > bound div 4 orelse x < ~(bound div 4)) ints > 1200)
val () = check ("int/the-bounds", fn () =>
  case (Int.minInt, Int.maxInt) of
    (SOME lo, SOME hi) => List.exists (fn x => x = lo) ints andalso List.exists (fn x => x = hi) ints
  | _ => true)
val () = check ("intRange/stays-in-range", fn () => List.all (fn x => ~3 <= x andalso x <= 5) (samples (Gen.intRange (~3, 5), 500, 50)))
val () = check ("intRange/one-sided", fn () => List.all (fn x => 10 <= x andalso x <= 20) (samples (Gen.intRange (10, 20), 500, 50)))
val words = samples (Gen.word, 1500, 50)
val () = check ("word/zero-and-all-ones", fn () =>
  List.exists (fn w => w = 0w0) words andalso List.exists (fn w => w = Word.notb 0w0) words)
val lists = samples (Gen.list Gen.int, 1000, 50)
val () = check ("list/empty-and-singleton", fn () =>
  count (fn l => List.null l) lists > 100 andalso count (fn l => List.length l = 1) lists > 100)
val () = check ("list/up-to-the-size", fn () =>
  List.all (fn l => List.length l <= 50) lists andalso List.exists (fn l => List.length l > 25) lists)
val () = check ("list/empty-at-size-0", fn () => List.all List.null (samples (Gen.list Gen.int, 200, 0)))
val chars = samples (Gen.char, 2000, 50)
val () = check ("char/every-family", fn () =>
  List.exists Char.isAlpha chars andalso List.exists Char.isDigit chars andalso List.exists Char.isCntrl chars
  andalso List.exists (fn c => Char.ord c > 127) chars andalso List.exists (fn c => c = #"~") chars)
val reals = samples (Gen.real, 1500, 50)
val () = check ("real/every-family", fn () =>
  List.exists Real.isNan reals andalso List.exists (fn x => Real.isFinite x = false andalso not (Real.isNan x)) reals
  andalso List.exists (fn x => Real.== (x, 0.0)) reals
  andalso List.exists (fn x => Real.isFinite x andalso Real.abs x > 1.0E100) reals
  andalso List.exists (fn x => Real.== (x * 2.0, Real.realRound (x * 2.0)) andalso Real.abs x <= 50.0
                                andalso not (Real.== (x, Real.realRound x))) reals)
(* the encoding of reals as their bits, which the library computes itself *)
val () = check ("real/bits", fn () =>
  List.all (fn (x, w) => PropertySource.bitsOf x = w andalso PropertySource.bitsOf (PropertySource.realOf w) = w)
           [(1.0, 0wx3FF0000000000000), (~2.5, 0wxC004000000000000), (0.0, 0w0), (~0.0, 0wx8000000000000000),
            (Real.minPos, 0w1), (Real.minNormalPos, 0wx10000000000000), (Real.maxFinite, 0wx7FEFFFFFFFFFFFFF),
            (Real.posInf, 0wx7FF0000000000000), (Real.negInf, 0wxFFF0000000000000), (0.1, 0wx3FB999999999999A)])
val () = check ("real/bits-round-trip", fn () =>
  let
    (* 20000 words, with every exponent from 0 to 0x7FE among them *)
    fun ok w = let val w = if Word64.andb (w, 0wx7FF0000000000000) = 0wx7FF0000000000000 then Word64.andb (w, 0wx800FFFFFFFFFFFFF) else w
               in PropertySource.bitsOf (PropertySource.realOf w) = w end
    fun go (0, _) = true
      | go (k, g) =
          let
            val (w, g) = Random.word64 g
            val w = Word64.orb (Word64.andb (w, 0wx800FFFFFFFFFFFFF), Word64.<< (Word64.fromInt (k mod 0x7FF), 0w52))
          in ok w andalso go (k - 1, g) end
  in go (20000, Random.fromSeed 0w5) end)
val () = check ("option/some-and-none", fn () =>
  let val os = samples (Gen.option Gen.int, 400, 10) in count isSome os > 200 andalso count (not o isSome) os > 50 end)
val () = check ("oneOf/every-alternative", fn () =>
  let val xs = samples (Gen.oneOf [Gen.return 1, Gen.return 2, Gen.return 3], 300, 10)
  in List.all (fn k => List.exists (fn x => x = k) xs) [1, 2, 3] end)
val () = check ("frequency/by-weight", fn () =>
  let val xs = samples (Gen.frequency [(1, Gen.return 1), (9, Gen.return 2)], 1000, 10)
  in count (fn x => x = 1) xs < 200 andalso count (fn x => x = 1) xs > 40 end)

(* ---- a seed draws the same everywhere ---- *)
(* intRange and not int: the range of Int.int is the host's, and the
   fingerprint must be the same on every compiler *)
val big = Gen.triple (Gen.list (Gen.pair (Gen.intRange (~1000000, 1000000), Gen.string)), Gen.real,
                      Gen.option (Gen.vector Gen.word64))
val showBig = Show.triple (Show.list (Show.pair (Show.int, Show.string)), Show.real, Show.option (Show.vector Show.word64))
val () = check ("sample/same-seed-same-value", fn () =>
  showBig (Gen.sample big 0w42 30) = showBig (Gen.sample big 0w42 30))
(* the fingerprint hashes what the observers make of the values, and not
   how they are printed: Real.fmt prints differently on other compilers
   (tests/basis/deviations.txt) *)
val coBig = Co.triple (Co.list (Co.pair (Co.int, Co.string)), Co.real,
                       Co.option (fn v => Co.list Co.word64 (Vector.foldr (op ::) [] v)))
val fingerprint =
  List.foldl (fn (k, h) => Random.hash (Word64.xorb (h, coBig (Gen.sample big (Word64.fromInt k) (k mod 40)))))
             0w0 (List.tabulate (200, fn k => k))
val () = print ("fingerprint " ^ StringCvt.padLeft #"0" 16 (Word64.fmt StringCvt.HEX fingerprint) ^ "\n")

(* ---- a node set by the shrinker changes its part alone ---- *)
val () = check ("tree/parts-are-independent", fn () =>
  let
    val g = Gen.pair (Gen.list Gen.int, Gen.list Gen.int)
    val s = PropertySource.new (0w7, 30, [], [])
    val (a, b) = Gen.draw g (s, PropertySource.root)
    (* the first node read is the length of the first list: set it to 0 *)
    val first = hd (PropertySource.nodes s)
    val s' = PropertySource.new (0w7, 30, [{address = #address first, path = #path first, word = 0w0, kind = #kind first}], [])
    val (a', b') = Gen.draw g (s', PropertySource.root)
  in
    List.null a' andalso b' = b andalso not (List.null a)
  end)

(* ---- properties find planted bugs ---- *)
fun myRev l = List.foldl (op ::) [] l
fun badRev [x, y] = [x, y] | badRev l = myRev l
fun badAll p [] = true | badAll p [_] = true | badAll p (x :: xs) = p x andalso badAll p xs
fun failed' r = case r of Check.Failed _ => true | _ => false
fun passed' r = Check.passed r
val () = check ("check/true-property-passes", fn () =>
  passed' (Check.check Check.default "rev twice" (Prop.forAll (Arb.list Arb.int) (fn l => Prop.holds (myRev (myRev l) = l)))))
val () = check ("check/planted-list-bug", fn () =>
  failed' (Check.check Check.default "bad rev" (Prop.forAll (Arb.list Arb.int) (fn l => Prop.holds (badRev l = myRev l)))))
val () = check ("check/planted-function-bug", fn () =>
  failed' (Check.check Check.default "bad all"
             (Prop.forAll (Arb.pair (Arb.pureFunction (Arb.int, Arb.bool), Arb.list Arb.int))
                          (fn (p, l) => Prop.holds (badAll p l = List.all p l)))))
val () = check ("check/an-exception-fails", fn () =>
  case Check.check Check.default "div" (Prop.forAll Arb.int (fn i => Prop.holds (100 div i >= ~100))) of
    Check.Failed {class, ...} => class = "exception Div"
  | _ => false)
val () = check ("equal/same-exception-passes", fn () =>
  passed' (Check.check Check.default "both raise" (Prop.equal Arb.int (fn () => raise Div, fn () => 1 div 0))))
val () = check ("equal/one-side-raises", fn () =>
  case Check.check Check.default "one raises" (Prop.equal Arb.int (fn () => raise Div, fn () => 1)) of
    Check.Failed {class, ...} => class = "left raised Div"
  | _ => false)
val () = check ("law/fresh-arrays-for-each-side", fn () =>
  failed' (Check.check Check.default "fresh"
             (Prop.law (Arb.array Arb.int, Arb.int)
                       (fn a => (Array.modify (fn _ => 7) a; Array.length a),
                        fn a => Array.foldl (fn (x, n) => if x = 7 then n + 1 else n) 0 a))))
val () = check ("==>/discards", fn () =>
  case Check.check Check.default "even" (Prop.forAll Arb.int (fn i => Prop.==> (i mod 2 = 0, fn () => Prop.holds (i mod 2 = 0)))) of
    Check.Passed {discarded, ...} => discarded > 20
  | _ => false)
val () = check ("==>/gives-up", fn () =>
  case Check.check Check.default "never" (Prop.forAll Arb.int (fn _ => Prop.==> (false, fn () => Prop.holds true))) of
    Check.GaveUp _ => true
  | _ => false)
val () = check ("cover/short-fails", fn () =>
  not (passed' (Check.check Check.default "rare"
                  (Prop.forAll Arb.int (fn i => Prop.cover 90.0 (i = 7) "seven" (Prop.holds true))))))
val () = check ("cover/met-passes", fn () =>
  passed' (Check.check Check.default "common"
             (Prop.forAll Arb.int (fn i => Prop.cover 10.0 (i <> 7) "not seven" (Prop.holds true)))))
val () = check ("replay/the-same-case", fn () =>
  let
    val p = Prop.forAll (Arb.list Arb.int) (fn l => Prop.holds (badRev l = myRev l))
  in
    case Check.check Check.default "bad rev" p of
      Check.Failed {replay, counterexample, ...} =>
        (case Check.replay replay p of
           SOME {verdict = Prop.Fail _, shown, ...} => shown = counterexample
         | _ => false)
    | _ => false
  end)

val () = if !failed = 0 then () else OS.Process.exit OS.Process.failure
