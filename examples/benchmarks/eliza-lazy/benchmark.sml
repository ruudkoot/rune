structure Benchmark =
struct
  val name = "eliza-lazy"
  structure Kernel = BenchElizaFn (BenchNeed)
  structure Driver = BenchElizaDriverFn (Kernel)
  val run = Driver.run
end
