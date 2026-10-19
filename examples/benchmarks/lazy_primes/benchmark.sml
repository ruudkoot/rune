structure Benchmark =
struct
  val name = "lazy_primes"
  fun run [size] =
    let val n = BenchInput.between (1,10000) (BenchInput.integer size)
    in Int.toString(BenchOcamlPrimes.nth n) end
    | run _ = raise Fail "lazy_primes expects one-based prime index"
end
