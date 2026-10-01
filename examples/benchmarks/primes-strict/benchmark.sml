structure Benchmark =
struct
  val name = "primes-strict"
  val run = BenchPrimes.run BenchPrimes.strict
end
