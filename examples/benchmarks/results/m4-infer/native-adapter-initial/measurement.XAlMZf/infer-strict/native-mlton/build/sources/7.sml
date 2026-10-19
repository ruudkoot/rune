structure Benchmark =
struct
  val name = "infer-strict"
  structure Kernel = BenchInferFn (BenchStrict)
  structure Driver = BenchInferDriverFn (Kernel)
  val run = Driver.run
end
