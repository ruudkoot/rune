structure Benchmark =
struct
  val name = "gamteb-lazy"
  structure Kernel = BenchGamtebFn (BenchNeed)
  structure Driver = BenchGamtebDriverFn (Kernel)
  val run = Driver.run
end
