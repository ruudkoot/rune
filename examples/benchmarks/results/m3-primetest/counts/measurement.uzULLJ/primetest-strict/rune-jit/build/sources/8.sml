structure Benchmark =
struct
  val name = "primetest-strict"
  structure Kernel = BenchPrimeTestFn (BenchStrict)
  structure Driver = BenchPrimeTestDriverFn (Kernel)
  val run = Driver.run
end
