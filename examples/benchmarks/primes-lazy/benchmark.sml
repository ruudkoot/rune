structure Benchmark =
struct
  val name = "primes-lazy"
  val run = BenchPrimes.run BenchPrimes.lazy
end
