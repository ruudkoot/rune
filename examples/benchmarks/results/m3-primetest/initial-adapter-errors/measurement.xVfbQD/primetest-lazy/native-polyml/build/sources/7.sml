structure Benchmark =
struct
  val name = "primetest-lazy"
  structure Kernel = BenchPrimeTestFn (BenchNeed)
  structure Driver = BenchPrimeTestDriverFn (Kernel)
  val run = Driver.run
end
