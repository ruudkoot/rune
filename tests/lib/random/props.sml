(* What lib/random promises besides its known answers: uniform draws (a
   chi-squared test at p = 0.001, with fixed seeds, so the verdict is the
   same at every run), reals from 53 bits, the errors it raises, and tokens
   that make a generator again. One line PASS or FAIL for each. *)
val failed = ref 0
fun check (name, holds) =
  if holds () handle _ => false then print ("PASS " ^ name ^ "\n")
  else (print ("FAIL " ^ name ^ "\n"); failed := !failed + 1)

(* chi-squared of k equally likely outcomes of draw, over n draws *)
fun chi2 (k, n, draw, g) =
  let
    val counts = Array.array (k, 0)
    fun go (0, _) = ()
      | go (i, g) = let val (x, g) = draw g in Array.update (counts, x, Array.sub (counts, x) + 1); go (i - 1, g) end
    val () = go (n, g)
    val e = real n / real k
  in
    Array.foldl (fn (c, s) => s + (real c - e) * (real c - e) / e) 0.0 counts
  end

val () = check ("below/chi2-6", fn () =>
  chi2 (6, 60000, fn g => let val (x, g) = Random.below 0w6 g in (Word64.toInt x, g) end, Random.fromSeed 0w1) < 20.52)
val () = check ("int/chi2-7", fn () =>
  chi2 (7, 70000, fn g => let val (x, g) = Random.int (~3, 3) g in (x + 3, g) end, Random.fromSeed 0w2) < 22.46)
val () = check ("bool/chi2", fn () =>
  chi2 (2, 100000, fn g => let val (b, g) = Random.bool g in (if b then 1 else 0, g) end, Random.fromSeed 0w3) < 10.83)
val () = check ("below/chi2-3-of-2^63+1", fn () =>
  chi2 (3, 30000, fn g => let val (x, g) = Random.below 0wx8000000000000001 g
                          in (Word64.toInt (Word64.div (x, 0wx2AAAAAAAAAAAAAAB)), g) end,
        Random.fromSeed 0w4) < 13.82)

val () = check ("real/range-and-mean", fn () =>
  let
    fun go (0, _, sum, ok) = (sum, ok)
      | go (i, g, sum, ok) = let val (x, g) = Random.real g in go (i - 1, g, sum + x, ok andalso 0.0 <= x andalso x < 1.0) end
    val (sum, ok) = go (100000, Random.fromSeed 0w5, 0.0, true)
  in
    ok andalso Real.abs (sum / 100000.0 - 0.5) < 0.005
  end)
val () = check ("real/53-high-bits", fn () =>
  let
    val g = Random.fromSeed 0w6
    val (x, _) = Random.real g
    val (w, _) = Random.word64 g
  in
    Real.== (x, Real.fromLargeInt (Word64.toLargeInt (Word64.>> (w, 0w11))) / 9007199254740992.0)
  end)

val () = check ("below/zero-raises-Domain", fn () => (ignore (Random.below 0w0 (Random.fromSeed 0w0)); false) handle Domain => true)
val () = check ("int/empty-raises-Domain", fn () => (ignore (Random.int (1, 0) (Random.fromSeed 0w0)); false) handle Domain => true)
val () = check ("int/one", fn () => #1 (Random.int (5, 5) (Random.fromSeed 0w9)) = 5)
val () = check ("int/whole-range", fn () =>
  case (Int.minInt, Int.maxInt) of
    (SOME lo, SOME hi) => let val (x, _) = Random.int (lo, hi) (Random.fromSeed 0w10) in lo <= x andalso x <= hi end
  | _ => true)

val () = check ("toString/fromString-round-trip", fn () =>
  List.all (fn s => let val g = #2 (Random.split (Random.fromSeed s))
                    in Option.map Random.toString (Random.fromString (Random.toString g)) = SOME (Random.toString g) end)
           [0w0, 0w1, 0w42, 0wxFFFFFFFFFFFFFFFF])
val () = check ("fromString/even-gamma", fn () => not (isSome (Random.fromString "12:34")))
val () = check ("fromString/no-colon", fn () => not (isSome (Random.fromString "1234")))
val () = check ("fromString/not-hex", fn () => not (isSome (Random.fromString "zz:1")))

val () = check ("split/streams-differ", fn () =>
  let
    val (a, b) = Random.split (Random.fromSeed 0w11)
    fun go (0, _, _) = true
      | go (i, a, b) = let val (x, a) = Random.word64 a val (y, b) = Random.word64 b in x <> y andalso go (i - 1, a, b) end
  in
    go (1000, a, b)
  end)
val () = check ("hashString/distinct", fn () =>
  let val hs = List.map Random.hashString ["", "a", "b", "ab", "ba", "INTEGER.div/law-1@Int8"]
  in List.all (fn h => List.length (List.filter (fn h' => h' = h) hs) = 1) hs end)
val () = check ("fromEntropy/a-token", fn () =>
  let val t = Random.toString (Random.fromEntropy ()) in String.size t = 33 andalso String.sub (t, 16) = #":" end)

val () = if !failed = 0 then () else OS.Process.exit OS.Process.failure
