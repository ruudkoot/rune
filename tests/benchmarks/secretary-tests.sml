structure SecretaryTests =
struct
  structure B = BenchSecretary
  structure R = BenchHaskellRandomOne
  structure I = IntInf
  fun read path = let val f = TextIO.openIn path val text = TextIO.inputAll f
                  in TextIO.closeIn f; text end
  fun lines path = String.tokens (fn c => c = #"\n") (read path)
  fun stateIntegers (a, b) = (Word32.toLargeInt a, Word32.toLargeInt b)
  fun number s = valOf (I.fromString s)
  fun small s = valOf (Int.fromString s)
  val _ = List.app (fn text => case String.tokens Char.isSpace text of
      [seed, step, output, first, second, ranged] =>
        T.check ("secretary/rng-" ^ seed ^ "-" ^ step, fn () =>
          let fun advance 1 state = (R.next state, state)
                | advance n state = advance (n - 1) (#2 (R.next state))
              val ((value, state), beforeState) = advance (small step) (R.seed (small seed))
              val (draw, after) = R.range (1, 100) beforeState
          in value = number output andalso stateIntegers state = (number first, number second)
             andalso draw = number ranged andalso after = state end)
    | _ => raise Fail "bad RNG fixture") (lines "random.expected")
  val _ = List.app (fn (index, text) => case String.tokens Char.isSpace text of
      [lo, hi, output, first, second] => T.check ("secretary/integer-range-" ^ Int.toString index, fn () =>
        let val (value, state) = R.range (number lo, number hi) (R.seed 42)
        in value = number output andalso stateIntegers state = (number first, number second) end)
    | _ => raise Fail "bad range fixture") (ListPair.zip (List.tabulate (5, fn i => i), lines "range.expected"))
  val _ = List.app (fn seed =>
    let val expected = List.map number (String.tokens Char.isSpace (read ("permutation-" ^ Int.toString seed ^ ".expected")))
    in T.check ("secretary/lazy-complete-permutation-" ^ Int.toString seed, fn () =>
         BenchStream.take 100 (B.nub [] (B.randoms (R.seed seed))) = expected);
       T.check ("secretary/strict-complete-permutation-" ^ Int.toString seed, fn () =>
         B.strictPermutation (R.range (1, 100)) (R.seed seed) = expected) end)
    [1, 2, 42, 50, 5000, 50000]
  val _ = List.app (fn text => case String.tokens Char.isSpace text of
      [seed, k, success, lazyCount, strictCount] =>
        let val label = seed ^ "-" ^ k val expected = small success = 1
        in T.check ("secretary/lazy-demand-" ^ label, fn () =>
             let val calls = ref 0
                 fun randoms state = BenchLazy.delay (fn () =>
                   let val (value, next) = R.range (1, 100) state val _ = calls := !calls + 1
                   in BenchStream.Cons (BenchLazy.delay (fn () => value), randoms next) end)
                 val raw = randoms (R.seed (small seed))
                 val result = B.lazyTrial (small k) raw
                 val count = !calls
                 val again = B.lazyTrial (small k) raw
             in result = expected andalso count = small lazyCount andalso again = result andalso !calls = count end);
           T.check ("secretary/strict-demand-" ^ label, fn () =>
             let val calls = ref 0
                 fun draw state = (calls := !calls + 1; R.range (1, 100) state)
                 val permutation = B.strictPermutation draw (R.seed (small seed))
             in B.strictTrial (small k) permutation = expected andalso !calls = small strictCount end)
        end
    | _ => raise Fail "bad demand fixture") (lines "demand.expected")
  val lazyResult = List.map (B.lazy 50) [35, 36, 37, 38, 39]
  val strictResult = List.map (B.strict 50) [35, 36, 37, 38, 39]
  val _ = T.check ("secretary/full-lazy-smoke", fn () => (SecretaryCheck.validate 50 lazyResult "50.results"; true))
  val _ = T.check ("secretary/full-strict-smoke", fn () => (SecretaryCheck.validate 50 strictResult "50.results"; true))
  val _ = T.check ("secretary/lazy-strict-counts-agree", fn () => List.map #1 lazyResult = List.map #1 strictResult)
  fun rejects path = (SecretaryCheck.validate 50 lazyResult path; false) handle Fail _ => true
  val _ = T.check ("secretary/wrong-count-rejected", fn () => rejects "wrong-count.results")
  val _ = T.check ("secretary/wrong-probability-rejected", fn () => rejects "wrong-probability.results")
  val _ = T.check ("secretary/truncated-rejected", fn () => rejects "truncated.results")
  val _ = T.check ("secretary/extra-rejected", fn () => rejects "extra.results")
  val _ = T.check ("secretary/nonfinite-rejected", fn () =>
    ((SecretaryCheck.validate 50 [(14, 0.0 / 0.0)] "50.results"; false) handle Fail _ => true))
end
