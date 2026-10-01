structure BenchSemanticTests =
struct
  val calls = ref 0
  val delayed = BenchPrimes.delay (fn () => (calls := !calls + 1; 23))
  val _ = T.check ("benchmark.delay/value", fn () => BenchPrimes.force delayed = 23)
  val _ = T.check ("benchmark.delay/shared", fn () => BenchPrimes.force delayed = 23 andalso !calls = 1)

  fun prime n =
    let
      fun divides d = if d * d > n then false else n mod d = 0 orelse divides (d + 1)
    in n >= 2 andalso not (divides 2) end
  fun reference n =
    let fun seek (p, left) = if prime p then (if left = 0 then p else seek (p + 1, left - 1)) else seek (p + 1, left)
    in seek (2, n) end
  fun sizes n =
    if n > 80 then () else
      (T.check ("benchmark.primes/" ^ Int.toString n,
                fn () => BenchPrimes.lazy n = reference n andalso BenchPrimes.strict n = reference n);
       sizes (n + 1))
  val _ = sizes 3
  fun diagrams n =
    if n > 10 then () else
      (T.check ("benchmark.bdd/truth-" ^ Int.toString n, fn () => (Benchmark.truthTable n; true)); diagrams (n + 1))
  val _ = diagrams 1
end
