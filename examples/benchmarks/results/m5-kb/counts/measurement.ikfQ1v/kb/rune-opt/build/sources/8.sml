structure Benchmark =
struct
  val name = "kb"
  structure Kernel = BenchSandmarkKBCompletionFn (BenchSandmarkKBRaise)
  structure Driver = BenchSandmarkKBDriverFn (Kernel)
  val run = Driver.run
end
