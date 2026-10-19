structure Benchmark =
struct
  val name = "eliza-strict"
  structure Kernel = BenchElizaFn (BenchStrict)
  structure Driver = BenchElizaDriverFn (Kernel)
  val run = Driver.run
end
