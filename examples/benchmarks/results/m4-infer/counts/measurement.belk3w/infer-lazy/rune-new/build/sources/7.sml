structure Benchmark =
struct
  val name = "infer-lazy"
  structure Kernel = BenchInferFn (BenchNeed)
  structure Driver = BenchInferDriverFn (Kernel)
  val run = Driver.run
end
