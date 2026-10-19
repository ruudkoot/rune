structure Benchmark =
struct
  val name = "gamteb-strict"
  structure Kernel = BenchGamtebFn (BenchStrict)
  structure Driver = BenchGamtebDriverFn (Kernel)
  val run = Driver.run
end
